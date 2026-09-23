import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
import 'reply_stream.dart';

class AssistantController extends ChangeNotifier with WidgetsBindingObserver {
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

  Timer? _listenTimer;
  Timer? _visionTimer;
  bool _startingListen = false;
  bool _sensorChanging = false;
  int _turnEpoch = 0;
  int _listenEpoch = 0;
  int _microphoneRequest = 0;
  int _memoryEpoch = 0;
  int _speechEpoch = 0;
  int _accessEpoch = 0;
  bool _visionTurn = false;
  bool _disposed = false;
  String streamingReply = '';
  String? voiceWarning;
  int? firstReplyMilliseconds;
  final Set<Future<void>> _indexJobs = {};

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
    WidgetsBinding.instance.addObserver(this);
    await memory.init();
    messages.addAll(await memory.recent(limit: 30));
    notifyListeners();
  }

  Future<void> toggleMicrophone(bool value) async {
    final request = ++_microphoneRequest;
    _listenTimer?.cancel();
    if (!value) {
      microphoneEnabled = false;
      _listenEpoch++;
      _speechEpoch++;
      await voice.cancelListening();
      await voice.stopSpeaking();
      status = 'میکروفون خاموش است';
      notifyListeners();
      return;
    }
    final access = _accessEpoch;
    final result = await Permission.microphone.request();
    if (access != _accessEpoch || request != _microphoneRequest) return;
    if (!result.isGranted) {
      status = 'مجوز میکروفون داده نشد';
      notifyListeners();
      return;
    }
    try {
      await voice.init();
    } catch (_) {
      if (access != _accessEpoch || request != _microphoneRequest) return;
      status = 'آماده‌سازی گفتار ممکن نشد؛ موتور گفتار گوشی را بررسی کنید.';
      notifyListeners();
      return;
    }
    if (access != _accessEpoch || request != _microphoneRequest) return;
    microphoneEnabled = true;
    voiceWarning = voice.persianVoiceAvailable ? null
        : 'برای پاسخ صوتی، صدای فارسی را در موتور گفتار گوشی فعال کنید.';
    status = voiceWarning ?? 'گوش می‌دهم…';
    notifyListeners();
    await _listenLoop();
  }

  void _scheduleListen([int delay = 120]) {
    _listenTimer?.cancel();
    if (!microphoneEnabled || busy) return;
    _listenTimer = Timer(Duration(milliseconds: delay), () {
      if (!microphoneEnabled || busy) return;
      if (!voice.isListening && liveTranscript.trim().isNotEmpty) {
        _acceptSpeech(liveTranscript, _listenEpoch);
      } else {
        _listenLoop();
      }
    });
  }

  Future<void> _acceptSpeech(String text, int epoch) async {
    if (epoch != _listenEpoch || !microphoneEnabled || busy || text.trim().isEmpty) return;
    _listenEpoch++;
    _listenTimer?.cancel();
    liveTranscript = '';
    if (_isShutdown(text)) {
      await shutdownByVoice();
      return;
    }
    await send(text.trim(), speakReply: true);
  }

  Future<void> _listenLoop() async {
    if (!microphoneEnabled || voice.isListening || busy || _startingListen || voice.isSpeaking) return;
    _startingListen = true;
    final epoch = ++_listenEpoch;
    try {
      await voice.listen(
        onText: (text, finalResult) {
          if (epoch != _listenEpoch || !microphoneEnabled || busy) return;
          liveTranscript = text;
          notifyListeners();
          if (finalResult) _acceptSpeech(text, epoch);
        },
        onDone: () {
          if (epoch == _listenEpoch) _scheduleListen(150);
        },
        onError: (error) {
          if (epoch != _listenEpoch || !microphoneEnabled) return;
          if (error == 'error_no_match' || error == 'error_speech_timeout') {
            liveTranscript = '';
            _scheduleListen(450);
          } else {
            microphoneEnabled = false;
            status = 'تشخیص گفتار در دسترس نیست؛ مجوز، اینترنت و زبان فارسی گوشی را بررسی کنید.';
          }
          notifyListeners();
        },
      );
    } catch (_) {
      microphoneEnabled = false;
      status = 'شروع میکروفون ممکن نشد؛ مجوز و موتور گفتار را بررسی کنید.';
      notifyListeners();
    } finally {
      _startingListen = false;
    }
  }

  bool _isShutdown(String text) {
    final normalized = text.toLowerCase().trim();
    return shutdownPhrases.any(normalized.contains);
  }

  Map<String, String> get allowedApps => {
        for (final app in apps)
          if (app.selected) app.id: app.name,
      };

  Future<void> send(String text, {String? imageBase64, bool? speakReply}) async {
    if (busy || text.trim().isEmpty) return;
    busy = true;
    final epoch = ++_turnEpoch;
    final speechEpoch = _speechEpoch;
    final shouldSpeak = speakReply ?? microphoneEnabled;
    final watch = Stopwatch()..start();
    firstReplyMilliseconds = null;
    streamingReply = '';
    _listenEpoch++;
    _listenTimer?.cancel();
    _visionTurn = imageBase64 != null || screenVisionEnabled || cameraEnabled;
    status = 'در حال پردازش…';
    notifyListeners();
    Future<void> speechQueue = Future.value();
    final chunks = SpeechChunks((chunk) {
      if (!shouldSpeak) return;
      speechQueue = speechQueue.then((_) async {
        if (epoch != _turnEpoch || speechEpoch != _speechEpoch) return;
        try {
          await voice.speak(chunk);
        } catch (_) {
          voiceWarning = 'پخش صدای فارسی ممکن نشد؛ موتور گفتار گوشی را بررسی کنید.';
        }
      });
    });
    try {
      await voice.cancelListening();
      String? secondImage;
      if (imageBase64 == null && screenVisionEnabled) {
        imageBase64 = await bridge.captureScreenFrame();
        if (imageBase64 == null || imageBase64.isEmpty) {
          throw StateError('فریم تازهٔ صفحه در دسترس نیست؛ اشتراک صفحه را بررسی کنید.');
        }
        if (cameraEnabled) secondImage = await camera.captureBase64();
      } else if (imageBase64 == null && cameraEnabled) {
        imageBase64 = await camera.captureBase64();
      }
      if (epoch != _turnEpoch) return;
      final user = ChatMessage(
        id: _uuid.v4(), role: 'user', content: text.trim(), createdAt: DateTime.now(),
      );
      messages.add(user);
      notifyListeners();
      final memoryEpoch = _memoryEpoch;
      // Persist locally first. Remote embedding work must not block spoken answers.
      if (memoryEnabled) await memory.save(user);
      Future<String?> recall() async {
        final embedding = await ai.embedding(user.content);
        if (!memoryEnabled || memoryEpoch != _memoryEpoch || embedding == null) return null;
        await memory.save(user, embedding: embedding);
        final hits = await memory.semanticSearch(embedding);
        return hits.where((hit) => hit.score > 0.25 && hit.message.id != user.id)
            .map((hit) => '${hit.message.role}: ${hit.message.content}').join('\n');
      }
      String? memoryContext;
      if (memoryEnabled) {
        final retrieval = recall().catchError((Object _) => null);
        memoryContext = shouldSpeak
            ? await retrieval.timeout(const Duration(milliseconds: 150), onTimeout: () => null)
            : await retrieval;
      }
      if (epoch != _turnEpoch) return;
      final turn = await ai.chat(
        history: messages.length > 1 ? messages.sublist(0, messages.length - 1) : const [],
        userText: user.content,
        imageBase64: imageBase64,
        secondImageBase64: secondImage,
        memoryContext: memoryContext,
        allowedApps: allowedApps,
        voiceMode: shouldSpeak,
        onReply: (reply) {
          if (epoch != _turnEpoch || reply.isEmpty) return;
          firstReplyMilliseconds ??= watch.elapsedMilliseconds;
          streamingReply = reply;
          chunks.add(reply);
          status = shouldSpeak ? 'در حال پاسخ…' : 'در حال نوشتن…';
          notifyListeners();
        },
      );
      if (epoch != _turnEpoch) return;
      chunks.finish();
      final actionNotes = await _executeSafeActions(turn.actions);
      if (epoch != _turnEpoch) return;
      final finalReply = actionNotes.isEmpty ? turn.reply : '${turn.reply}\n\n${actionNotes.join('\n')}';
      final assistant = ChatMessage(
        id: _uuid.v4(), role: 'assistant', content: finalReply, createdAt: DateTime.now(),
      );
      messages.add(assistant);
      streamingReply = '';
      notifyListeners();
      if (memoryEnabled && memoryEpoch == _memoryEpoch) {
        await memory.save(assistant);
        _indexLater(assistant, memoryEpoch);
      }
      await speechQueue;
      if (epoch == _turnEpoch) status = voiceWarning ?? 'آماده';
    } catch (_) {
      chunks.dispose();
      await speechQueue;
      if (epoch == _turnEpoch) {
        status = 'پاسخ کامل دریافت نشد؛ اتصال سرور، مدل بینایی و مجوزهای فعال را بررسی کنید.';
      }
    } finally {
      chunks.dispose();
      if (epoch == _turnEpoch) {
        streamingReply = '';
        _visionTurn = false;
        busy = false;
        notifyListeners();
        _scheduleListen();
      }
    }
  }

  void _indexLater(ChatMessage message, int memoryEpoch) {
    // A small bound prevents slow embedding servers accumulating unlimited work.
    if (_indexJobs.length >= 2) return;
    late Future<void> job;
    job = (() async {
      try {
        final embedding = await ai.embedding(message.content);
        if (memoryEnabled && memoryEpoch == _memoryEpoch && embedding != null) {
          await memory.save(message, embedding: embedding);
        }
      } catch (_) {
        // The encrypted message was already saved without an embedding.
      }
    })().whenComplete(() => _indexJobs.remove(job));
    _indexJobs.add(job);
  }

  Future<void> interruptAndListen() async {
    _listenTimer?.cancel();
    _listenEpoch++;
    liveTranscript = '';
    await voice.cancelListening();
    await _cancelTurn();
    status = microphoneEnabled ? 'گوش می‌دهم…' : 'پاسخ متوقف شد';
    notifyListeners();
    _scheduleListen(80);
  }

  Future<void> _cancelTurn() async {
    _turnEpoch++;
    _speechEpoch++;
    ai.cancelTurn();
    busy = false;
    streamingReply = '';
    _visionTurn = false;
    await voice.stopSpeaking();
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

  void _startVisionLoop() {
    if (_disposed) return;
    _visionTimer?.cancel();
    if (!screenVisionEnabled && !cameraEnabled) return;
    // No preview is mounted. Fresh frames accompany each user turn; when the
    // microphone is off, periodically describe the active visual source aloud.
    _visionTimer = Timer(const Duration(seconds: 4), () async {
      if (!busy && !microphoneEnabled && !voice.isSpeaking) {
        await _inspectActiveVision();
      }
      _startVisionLoop();
    });
  }

  Future<void> _inspectActiveVision() async {
    if (busy || (!screenVisionEnabled && !cameraEnabled)) return;
    await send(screenVisionEnabled
        ? 'تصویر فعلی صفحه را بررسی کن؛ متن خوانا، وضعیت و مهم‌ترین نکتهٔ کاربردی را کوتاه بگو. اگر چیزی مبهم است، صریح بگو.'
        : 'آنچه اکنون در کادر دوربین دیده می‌شود را کوتاه و دقیق توصیف کن؛ دربارهٔ محیط و فرد حاضر فقط مشاهدات روشن را بگو.',
        speakReply: true);
  }

  Future<void> toggleScreenVision(bool value) async {
    if (_sensorChanging) return;
    _sensorChanging = true;
    final access = _accessEpoch;
    try {
      if (value) {
        if (Platform.isAndroid) await Permission.notification.request();
        if (access != _accessEpoch) return;
        final granted = await bridge.startScreenVision();
        if (access != _accessEpoch) {
          await bridge.stopScreenVision();
          return;
        }
        screenVisionEnabled = granted;
        status = screenVisionEnabled ? 'دیدن صفحه فعال است' : 'اشتراک صفحه تأیید نشد';
      } else {
        screenVisionEnabled = false;
        if (_visionTurn) await _cancelTurn();
        await bridge.stopScreenVision();
        status = 'دیدن صفحه خاموش است';
      }
    } catch (_) {
      screenVisionEnabled = false;
      status = 'اشتراک صفحه در دسترس نیست';
    } finally {
      _sensorChanging = false;
      notifyListeners();
      _startVisionLoop();
      _scheduleListen();
    }
    if (value && screenVisionEnabled && !busy) {
      // Consent can complete before the native service has produced its first frame.
      for (var i = 0; i < 12 && screenVisionEnabled; i++) {
        try {
          final frame = await bridge.captureScreenFrame();
          if (frame != null && frame.isNotEmpty) break;
        } catch (_) {
          status = 'دریافت صفحه ممکن نشد؛ اشتراک صفحه را دوباره فعال کنید.';
          notifyListeners();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (screenVisionEnabled) await _inspectActiveVision();
    }
  }

  Future<void> inspectScreen(String question) async {
    if (!screenVisionEnabled || busy) return;
    try {
      final frame = await bridge.captureScreenFrame();
      if (!screenVisionEnabled || busy) return;
      if (frame == null || frame.isEmpty) {
        status = 'فریم تازهٔ صفحه در دسترس نیست؛ اشتراک صفحه را بررسی کنید.';
        notifyListeners();
        return;
      }
      await send(question, imageBase64: frame, speakReply: true);
    } catch (_) {
      status = 'دریافت صفحه ممکن نشد؛ اشتراک صفحه را دوباره فعال کنید.';
      notifyListeners();
    }
  }

  Future<void> toggleCamera(bool value) async {
    if (_sensorChanging) return;
    _sensorChanging = true;
    final access = _accessEpoch;
    try {
      if (value) {
        if (!(await Permission.camera.request()).isGranted) {
          status = 'مجوز دوربین داده نشد';
          return;
        }
        if (access != _accessEpoch) return;
        await camera.start();
        if (access != _accessEpoch) {
          await camera.stop();
          return;
        }
        cameraEnabled = true;
        status = 'دوربین فعال است؛ بدون پیش‌نمایش';
      } else {
        cameraEnabled = false;
        if (_visionTurn) await _cancelTurn();
        await camera.stop();
        status = 'دوربین خاموش است';
      }
    } catch (_) {
      cameraEnabled = false;
      status = 'دوربین در دسترس نیست؛ مجوز یا استفادهٔ برنامهٔ دیگر را بررسی کنید.';
    } finally {
      _sensorChanging = false;
      notifyListeners();
      _startVisionLoop();
      _scheduleListen();
    }
    if (value && cameraEnabled && !busy) await _inspectActiveVision();
  }

  Future<void> switchCamera() async {
    if (!cameraEnabled || busy || _sensorChanging) return;
    _sensorChanging = true;
    try {
      await camera.switchLens();
      status = 'دوربین جابه‌جا شد';
    } catch (_) {
      cameraEnabled = false;
      status = 'جابه‌جایی دوربین ممکن نشد';
    } finally {
      _sensorChanging = false;
      notifyListeners();
    }
  }

  Future<void> inspectCamera(String question) async {
    if (!cameraEnabled || busy) return;
    try {
      final frame = await camera.captureBase64();
      if (cameraEnabled) await send(question, imageBase64: frame, speakReply: true);
    } catch (_) {
      status = 'دریافت تصویر دوربین ممکن نشد';
      notifyListeners();
    }
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
    await _cancelTurn();
    try { await voice.speak('خداحافظ ${name.isEmpty ? 'دوست من' : name}'); } catch (_) {}
    await killSwitch(revokeOsPermissions: true);
  }

  Future<void> killSwitch({bool revokeOsPermissions = false}) async {
    _accessEpoch++;
    _microphoneRequest++;
    _listenTimer?.cancel();
    _visionTimer?.cancel();
    _listenEpoch++;
    await _cancelTurn();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && cameraEnabled) {
      // Camera plugins require releasing the device while the app is backgrounded.
      // Screen sharing continues through its existing foreground service.
      toggleCamera(false);
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    microphoneEnabled = false;
    screenVisionEnabled = false;
    cameraEnabled = false;
    WidgetsBinding.instance.removeObserver(this);
    _listenTimer?.cancel();
    _visionTimer?.cancel();
    _turnEpoch++;
    _listenEpoch++;
    _speechEpoch++;
    _accessEpoch++;
    ai.cancelTurn();
    unawaited(voice.cancelListening());
    unawaited(voice.stopSpeaking());
    unawaited(camera.stop());
    super.dispose();
  }

  void setMemoryEnabled(bool value) {
    _memoryEpoch++;
    memoryEnabled = value;
    notifyListeners();
  }

  Future<void> wipeMemory() async {
    _memoryEpoch++;
    await memory.wipe();
    messages.clear();
    notifyListeners();
  }
}
