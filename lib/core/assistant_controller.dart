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
    'خاموش شو', 'خاموشش کن', 'خداحافظ اطلس', 'اطلس خداحافظ',
    'دیگه گوش نده', 'همه چیز رو خاموش کن', 'توقف کامل', 'stop atlas'
  ];

  Future<void> init() async {
    await memory.init();
    await voice.init();
    messages.addAll(await memory.recent(limit: 20));
    notifyListeners();
  }

  Future<void> toggleMicrophone(bool value) async {
    if (value) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) return;
      microphoneEnabled = true;
      await _listenLoop();
    } else {
      microphoneEnabled = false;
      await voice.cancelListening();
    }
    notifyListeners();
  }

  Future<void> _listenLoop() async {
    if (!microphoneEnabled || voice.isListening) return;
    await voice.listen(onText: (text, finalResult) async {
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
        if (microphoneEnabled) Future.delayed(const Duration(milliseconds: 350), _listenLoop);
      }
    });
  }

  bool _isShutdown(String text) {
    final t = text.toLowerCase().trim();
    return shutdownPhrases.any(t.contains);
  }

  Future<void> send(String text, {String? imageBase64}) async {
    if (busy) return;
    if (imageBase64 == null && screenVisionEnabled) {
      imageBase64 = await bridge.captureScreenFrame();
    }
    busy = true;
    status = 'در حال فکر کردن…';
    notifyListeners();
    try {
      final user = ChatMessage(id: _uuid.v4(), role: 'user', content: text, createdAt: DateTime.now());
      messages.add(user);
      List<double>? emb;
      String? memoryContext;
      if (memoryEnabled) {
        emb = await ai.embedding(text);
        if (emb != null) {
          final hits = await memory.semanticSearch(emb);
          memoryContext = hits.where((h) => h.score > 0.25).map((h) => '${h.message.role}: ${h.message.content}').join('\n');
        }
        await memory.save(user, embedding: emb);
      }
      final answer = await ai.chat(
        history: messages.length > 1 ? messages.sublist(0, messages.length - 1) : const [],
        userText: text,
        imageBase64: imageBase64,
        memoryContext: memoryContext,
      );
      final assistant = ChatMessage(id: _uuid.v4(), role: 'assistant', content: answer, createdAt: DateTime.now());
      messages.add(assistant);
      if (memoryEnabled) await memory.save(assistant, embedding: await ai.embedding(answer));
      status = 'آماده';
      notifyListeners();
      if (microphoneEnabled) await voice.speak(answer);
    } catch (e) {
      status = 'خطا: $e';
      notifyListeners();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> toggleScreenVision(bool value) async {
    if (value) {
      screenVisionEnabled = await bridge.startScreenVision();
    } else {
      await bridge.stopScreenVision();
      screenVisionEnabled = false;
    }
    notifyListeners();
  }

  Future<void> inspectScreen(String question) async {
    if (!screenVisionEnabled) return;
    final frame = await bridge.captureScreenFrame();
    if (frame != null) await send(question, imageBase64: frame);
  }

  Future<void> toggleCamera(bool value) async {
    if (value) {
      final result = await Permission.camera.request();
      if (!result.isGranted) return;
      await camera.start();
      cameraEnabled = true;
    } else {
      await camera.stop();
      cameraEnabled = false;
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
    apps = apps.map((a) => a.id == id ? a.copyWith(selected: selected) : a).toList();
    if (selected) {
      appActions.allowedAppIds.add(id);
    } else {
      appActions.allowedAppIds.remove(id);
    }
    appActions.enabled = appActions.allowedAppIds.isNotEmpty;
    notifyListeners();
  }

  Future<void> shutdownByVoice() async {
    final name = await settings.userName;
    await voice.stopListening();
    await voice.speak('خداحافظ $name');
    await killSwitch(revokeOsPermissions: true);
  }

  Future<void> killSwitch({bool revokeOsPermissions = false}) async {
    microphoneEnabled = false;
    screenVisionEnabled = false;
    cameraEnabled = false;
    appActions.disable();
    apps = apps.map((a) => a.copyWith(selected: false)).toList();
    await voice.cancelListening();
    await voice.stopSpeaking();
    await camera.stop();
    await bridge.stopScreenVision();
    if (revokeOsPermissions) {
      try { await bridge.revokeSensitivePermissions(); } catch (_) {}
    }
    status = 'همه قابلیت‌های فعال متوقف شدند';
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
