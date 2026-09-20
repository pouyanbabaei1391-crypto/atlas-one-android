import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/app_target.dart';
import '../models/chat_message.dart';
import 'ai_service.dart';
import 'app_action_service.dart';
import 'camera_service.dart';
import 'memory_service.dart';
import 'native_bridge.dart';
import 'settings_service.dart';
import 'voice_service.dart';

class AssistantController extends ChangeNotifier {
  final SettingsService settings = SettingsService();
  final MemoryService memory = MemoryService();
  final VoiceService voice = VoiceService();
  final NativeBridge bridge = NativeBridge();
  late final AiService ai = AiService(settings);
  late final AppActionService appActions = AppActionService(bridge);
  final CameraService camera = CameraService();
  final _uuid = const Uuid();

  final List<ChatMessage> messages = [];
  List<AppTarget> apps = [];
  bool microphoneEnabled = false;
  bool screenVisionEnabled = false;
  bool cameraEnabled = false;
  bool memoryEnabled = true;
  bool busy = false;
  String liveTranscript = '';
  String status = 'آماده';

  static const shutdownPhrases = [
    'خاموش شو',
    'خاموشش کن',
    'خاموش بشو',
    'خداحافظ اطلس',
    'اطلس خداحافظ',
    'دیگه گوش نده',
    'دیگر گوش نده',
    'همه چیز رو خاموش کن',
    'همه چیز را خاموش کن',
    'توقف کامل',
    'stop atlas',
    'shut down atlas',
  ];

  Future<void> init() async {
    await memory.init();
    await voice.init();
    messages.addAll(await memory.recent(limit: 30));
    notifyListeners();
  }

  Future<void> toggleMicrophone(bool value) async {
    if (value) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        status = 'مجوز میکروفون داده نشد';
        notifyListeners();
        return;
      }
      microphoneEnabled = true;
      status = 'میکروفون فعال است';
      notifyListeners();
      await _listenLoop();
    } else {
      microphoneEnabled = false;
      await voice.cancelListening();
      status = 'میکروفون خاموش است';
      notifyListeners();
    }
  }

  Future<void> _listenLoop() async {
    if (!microphoneEnabled || voice.isListening || busy) return;
    await voice.listen(
      onText: (text, finalResult) async {
        liveTranscript = text;
        notifyListeners();
        if (finalResult && text.trim().isNotEmpty) {
          await voice.stopListening();
          if (_isShutdown(text)) {
            await shutdownByVoice();
            return;
          }
          await send(text.trim());
          liveTranscript = '';
          notifyListeners();
          if (microphoneEnabled) {
            Timer(const Duration(milliseconds: 300), _listenLoop);
          }
        }
      },
      onError: (error) {
        status = 'خطای تشخیص گفتار: $error';
        notifyListeners();
      },
    );
  }

  bool _isShutdown(String text) {
    final normalized = text.toLowerCase().trim();
    return shutdownPhrases.any(normalized.contains);
  }

  Map<String, String> get allowedApps => {
        for (final app in apps)
          if (app.selected) app.id: app.name,
      };

  Future<void> send(String text, {String? imageBase64}) async {
    if (busy || text.trim().isEmpty) return;
    if (imageBase64 == null && screenVisionEnabled) {
      imageBase64 = await bridge.captureScreenFrame();
    } else if (imageBase64 == null && cameraEnabled) {
      try {
        imageBase64 = await camera.captureBase64();
      } catch (_) {
        // Keep voice/text conversation available even if the camera cannot
        // produce a frame at this exact moment.
      }
    }

    busy = true;
    status = 'در حال پردازش…';
    notifyListeners();

    try {
      final user = ChatMessage(
        id: _uuid.v4(),
        role: 'user',
        content: text.trim(),
        createdAt: DateTime.now(),
      );
      messages.add(user);

      List<double>? embedding;
      String? memoryContext;
      if (memoryEnabled) {
        embedding = await ai.embedding(user.content);
        if (embedding != null) {
          final hits = await memory.semanticSearch(embedding);
          memoryContext = hits
              .where((hit) => hit.score > 0.25)
              .map((hit) => '${hit.message.role}: ${hit.message.content}')
              .join('\n');
        }
        await memory.save(user, embedding: embedding);
      }

      final turn = await ai.chat(
        history: messages.length > 1
            ? messages.sublist(0, messages.length - 1)
            : const [],
        userText: user.content,
        imageBase64: imageBase64,
        memoryContext: memoryContext,
        allowedApps: allowedApps,
      );

      final actionNotes = await _executeSafeActions(turn.actions);
      final finalReply = actionNotes.isEmpty
          ? turn.reply
          : '${turn.reply}\n\n${actionNotes.join('\n')}';

      final assistant = ChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: finalReply,
        createdAt: DateTime.now(),
      );
      messages.add(assistant);
      if (memoryEnabled) {
        await memory.save(
          assistant,
          embedding: await ai.embedding(finalReply),
        );
      }

      status = 'آماده';
      notifyListeners();
      if (microphoneEnabled) await voice.speak(turn.reply);
    } catch (error) {
      status = 'خطا: $error';
      notifyListeners();
    } finally {
      busy = false;
      notifyListeners();
      if (microphoneEnabled && !voice.isListening) {
        Timer(const Duration(milliseconds: 350), _listenLoop);
      }
    }
  }

  Future<List<String>> _executeSafeActions(List<AiAction> actions) async {
    final notes = <String>[];
    for (final action in actions.take(3)) {
      if (action.type == 'open_app' && action.appId != null) {
        final id = action.appId!;
        if (!appActions.allowedAppIds.contains(id)) {
          notes.add('⛔ اپ درخواست‌شده در فهرست مجاز کاربر نیست.');
          continue;
        }
        final ok = await appActions.openSelectedApp(id);
        notes.add(ok ? '✓ اپ انتخاب‌شده باز شد.' : '⚠️ باز کردن اپ ممکن نشد.');
      } else if (action.type == 'open_uri' && action.uri != null) {
        final ok = await appActions.openUri(action.uri!);
        notes.add(ok ? '✓ لینک/عملیات مجاز باز شد.' : '⚠️ URI مجاز یا قابل اجرا نبود.');
      }
    }
    return notes;
  }

  Future<void> toggleScreenVision(bool value) async {
    if (value) {
      if (Platform.isAndroid) {
        final notification = await Permission.notification.request();
        if (!notification.isGranted && !notification.isLimited) {
          // MediaProjection can still be requested; Android may display the
          // foreground service in system UI even when notification permission is denied.
        }
      }
      screenVisionEnabled = await bridge.startScreenVision();
      status = screenVisionEnabled
          ? 'Screen Vision فعال است'
          : 'Screen Vision فعال نشد';
    } else {
      await bridge.stopScreenVision();
      screenVisionEnabled = false;
      status = 'Screen Vision خاموش است';
    }
    notifyListeners();
  }

  Future<void> inspectScreen(String question) async {
    if (!screenVisionEnabled) return;
    final frame = await bridge.captureScreenFrame();
    if (frame == null || frame.isEmpty) {
      status = 'هنوز فریم صفحه دریافت نشده است';
      notifyListeners();
      return;
    }
    await send(question, imageBase64: frame);
  }

  Future<void> toggleCamera(bool value) async {
    if (value) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        status = 'مجوز دوربین داده نشد';
        notifyListeners();
        return;
      }
      await camera.start();
      cameraEnabled = true;
      status = 'Camera Vision فعال است';
    } else {
      await camera.stop();
      cameraEnabled = false;
      status = 'Camera Vision خاموش است';
    }
    notifyListeners();
  }

  Future<void> inspectCamera(String question) async {
    if (!cameraEnabled) return;
    await send(question, imageBase64: await camera.captureBase64());
  }

  Future<void> loadApps() async {
    apps = await bridge.listApps();
    notifyListeners();
  }

  void setAppSelected(String id, bool selected) {
    apps = apps
        .map((app) => app.id == id ? app.copyWith(selected: selected) : app)
        .toList();
    if (selected) {
      appActions.allowedAppIds.add(id);
    } else {
      appActions.allowedAppIds.remove(id);
    }
    appActions.enabled = appActions.allowedAppIds.isNotEmpty;
    notifyListeners();
  }

  Future<bool> openApp(String id) => appActions.openSelectedApp(id);

  Future<void> shutdownByVoice() async {
    final name = (await settings.userName).trim();
    microphoneEnabled = false;
    await voice.stopListening();
    await voice.speak('خداحافظ ${name.isEmpty ? 'دوست من' : name}');
    await killSwitch(revokeOsPermissions: true);
  }

  Future<void> killSwitch({bool revokeOsPermissions = false}) async {
    microphoneEnabled = false;
    screenVisionEnabled = false;
    cameraEnabled = false;
    appActions.disable();
    apps = apps.map((app) => app.copyWith(selected: false)).toList();

    await voice.cancelListening();
    await voice.stopSpeaking();
    await camera.stop();
    await bridge.stopScreenVision();

    if (revokeOsPermissions) {
      try {
        await bridge.revokeSensitivePermissions();
      } catch (_) {}
    }

    liveTranscript = '';
    status = 'تمام قابلیت‌های فعال خاموش شدند';
    notifyListeners();
  }

  void setMemoryEnabled(bool value) {
    memoryEnabled = value;
    notifyListeners();
  }

  Future<void> wipeMemory() async {
    await memory.wipe();
    messages.clear();
    notifyListeners();
  }
}
