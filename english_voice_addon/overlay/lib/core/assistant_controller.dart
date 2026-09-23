import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
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
  String status = 'Ready';
  bool localAiEnabled = Platform.isAndroid;

  Future<void> setLocalAiEnabled(bool value) async {
    if (busy || microphoneEnabled || voiceStarting) return;
    await settings.setUseLocalAi(value);
    localAiEnabled = value;
    notifyListeners();
  }

  Future<void> prepareLocalAi() async {
    try { await ai.local.prepare(); status = 'Gemma 3 4B is ready on this phone'; }
    catch (e) { status = _voiceError(e); }
    notifyListeners();
  }
  double microphoneLevel = 0;
  bool voiceStarting = false;
  bool testingSpeaker = false;
  int _recognitionRetries = 0;
  String _lastNotificationStatus = '';

  String _voiceError(Object error) => error is PlatformException
      ? (error.message ?? error.code) : error.toString();

  Future<void> testSpeaker() async {
    if (testingSpeaker || busy || microphoneEnabled || voiceStarting) return;
    testingSpeaker = true;
    notifyListeners();
    try {
      await voice.speak('Hello. This is Atlas. My English voice is ready.');
      status = 'Speaker test finished. If silent, check media volume and Bluetooth output.';
      voiceWarning = null;
    } catch (e) { voiceWarning = _voiceError(e); status = 'Speaker test failed'; }
    finally { testingSpeaker = false; notifyListeners(); }
  }

  Future<void> testAiConnection() async {
    status = 'Checking AI server…';
    notifyListeners();
    try { status = await ai.checkConnection(); }
    catch (e) { status = 'AI server unavailable: ${_voiceError(e)}'; }
    notifyListeners();
  }


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
  int? firstSpeechMilliseconds;
  Stopwatch? _responseWatch;
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
    'stop listening',
    'goodbye atlas',
    'turn everything off',
    'stop atlas',
    'shut down atlas',
  ];

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    voice.onSpeechStarted = () {
      if (busy && _responseWatch != null && firstSpeechMilliseconds == null) {
        firstSpeechMilliseconds = _responseWatch!.elapsedMilliseconds;
        notifyListeners();
      }
    };
    voice.onLevel = (level) {
      microphoneLevel = ((level + 2) / 14).clamp(0.0, 1.0).toDouble();
      notifyListeners();
    };
    voice.onReady = () {
      if (microphoneEnabled && !busy) {
        status = 'Listening in English…';
        notifyListeners();
      }
    };
    voice.onSessionStopped = () {
      if (!microphoneEnabled) return;
      microphoneEnabled = false;
      _listenEpoch++;
      _listenTimer?.cancel();
      unawaited(_cancelTurn());
      microphoneLevel = 0;
      status = 'Voice chat stopped';
      notifyListeners();
    };
    unawaited(voice.prepareOutput().catchError((Object _) {}));
    localAiEnabled = await settings.useLocalAi;
    if (localAiEnabled) {
      try {
        await ai.local.refresh();
        final accepted = await settings.modelTermsAccepted;
        if (!ai.local.ready && (ai.local.installed || accepted)) {
          status = ai.local.installed
              ? 'Loading your existing Gemma model…'
              : 'Preparing Gemma while Hybrid cloud stays available…';
          unawaited(ai.local.prepare().then((_) {
            if (_disposed) return;
            status = 'Hybrid ready · fast cloud with private local fallback';
            notifyListeners();
          }).catchError((Object error) {
            if (_disposed) return;
            status = 'Cloud remains available · local setup needs attention';
            notifyListeners();
          }));
        }
      } catch (e) { status = _voiceError(e); }
    }
    await memory.init();
    messages.addAll(await memory.recent(limit: 30));
    notifyListeners();
  }

  Future<void> toggleMicrophone(bool value) async {
    if (value && (voiceStarting || microphoneEnabled || testingSpeaker)) return;
    if (value && localAiEnabled && !ai.local.ready) {
      final cloudReady = await settings.cloudConfigured;
      if (ai.local.installed && !ai.local.preparing) {
        unawaited(ai.local.prepare().catchError((Object _) {}));
      }
      if (!cloudReady && !ai.local.installed) {
        status = 'Install Gemma or add a Groq API key / secure Gateway in Settings.';
        notifyListeners();
        return;
      }
    }
    final request = ++_microphoneRequest;
    _listenTimer?.cancel();
    if (!value) {
      microphoneEnabled = false;
      voiceStarting = false;
      _listenEpoch++;
      await _cancelTurn();
      await voice.cancelListening();
      await voice.endSession();
      microphoneLevel = 0;
      status = 'Microphone is off';
      notifyListeners();
      return;
    }
    voiceStarting = true;
    final access = _accessEpoch;
    status = 'Starting microphone…';
    voiceWarning = null;
    notifyListeners();
    try {
      final permission = await Permission.microphone.request();
      if (request != _microphoneRequest || access != _accessEpoch) return;
      if (!permission.isGranted) throw StateError('Microphone permission was denied. Enable it in Android app settings.');
      if (Platform.isAndroid) await Permission.notification.request();
      if (request != _microphoneRequest || access != _accessEpoch) return;
      await voice.startSession();
      if (request != _microphoneRequest || access != _accessEpoch) return;
      await voice.init();
      microphoneEnabled = true;
      _recognitionRetries = 0;
      // A local spoken greeting proves TTS works independently of the AI server.
      status = 'Preparing English voice…';
      notifyListeners();
      try { await voice.speak('Ready.'); }
      catch (e) { voiceWarning = _voiceError(e); }
      if (request != _microphoneRequest || access != _accessEpoch || !microphoneEnabled) return;
      await _listenLoop();
    } catch (e) {
      if (request != _microphoneRequest || access != _accessEpoch) return;
      microphoneEnabled = false;
      status = _voiceError(e);
      voiceWarning = status;
      await voice.endSession();
    } finally {
      if (request == _microphoneRequest) { voiceStarting = false; notifyListeners(); }
    }
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
      status = voiceWarning ?? 'Listening…';
      notifyListeners();
      await voice.listen(
        onText: (text, finalResult) {
          if (epoch != _listenEpoch || !microphoneEnabled || busy) return;
          if (text.trim().isNotEmpty) _recognitionRetries = 0;
          liveTranscript = text;
          notifyListeners();
          if (finalResult) _acceptSpeech(text, epoch);
        },
        onDone: () {
          if (epoch == _listenEpoch) _scheduleListen(150);
        },
        onError: (error) {
          if (epoch != _listenEpoch || !microphoneEnabled) return;
          if (error.startsWith('retry:') || error == 'error_no_match' || error == 'error_speech_timeout') {
            liveTranscript = '';
            final code = error.startsWith('retry:') ? int.tryParse(error.split(':')[1]) : 7;
            final silent = code == 6 || code == 7;
            _recognitionRetries = silent ? 0 : _recognitionRetries + 1;
            final delay = silent ? 250 : code == 10 ? 15000 : (600 * (1 << _recognitionRetries.clamp(0, 4).toInt())).clamp(600, 10000).toInt();
            status = silent ? 'Listening…' : error.split(':').skip(2).join(':');
            _scheduleListen(delay);
          } else {
            microphoneEnabled = false;
            status = error;
            voiceWarning = error;
            unawaited(voice.endSession());
          }
          notifyListeners();
        },
      );
    } catch (e) {
      microphoneEnabled = false;
      status = _voiceError(e);
      unawaited(voice.endSession());
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
    firstSpeechMilliseconds = null;
    _responseWatch = watch;
    streamingReply = '';
    _listenEpoch++;
    _listenTimer?.cancel();
    _visionTurn = imageBase64 != null || screenVisionEnabled || cameraEnabled;
    status = 'Thinking…';
    notifyListeners();
    Future<void> speechQueue = Future.value();
    final chunks = SpeechChunks((chunk) {
      if (!shouldSpeak) return;
      speechQueue = speechQueue.then((_) async {
        if (epoch != _turnEpoch || speechEpoch != _speechEpoch) return;
        try {
          await voice.speak(chunk);
        } catch (e) {
          voiceWarning = _voiceError(e);
          notifyListeners();
        }
      });
    });
    try {
      await voice.cancelListening();
      String? secondImage;
      if (imageBase64 == null && screenVisionEnabled) {
        imageBase64 = await bridge.captureScreenFrame();
        if (imageBase64 == null || imageBase64.isEmpty) {
          throw StateError('No current screen image is available. Check screen sharing.');
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
            ? await retrieval.timeout(const Duration(milliseconds: 40), onTimeout: () => null)
            : await retrieval;
      }
      if (epoch != _turnEpoch) return;
      var receivedReply = false;
      Future<AiTurn> requestAnswer({required bool forceCloud}) => ai.chat(
        history: messages.length > 1 ? messages.sublist(0, messages.length - 1) : const [],
        userText: user.content,
        imageBase64: imageBase64,
        secondImageBase64: secondImage,
        memoryContext: memoryContext,
        allowedApps: allowedApps,
        voiceMode: shouldSpeak,
        forceCloud: forceCloud,
        onReply: (reply) {
          if (epoch != _turnEpoch || reply.isEmpty) return;
          receivedReply = true;
          firstReplyMilliseconds ??= watch.elapsedMilliseconds;
          streamingReply = reply;
          chunks.add(reply);
          status = shouldSpeak ? 'Responding…' : 'Writing…';
          notifyListeners();
        },
      );
      final cloudConfigured = await settings.cloudConfigured;
      final cloudFirst = shouldSpeak && cloudConfigured;
      late AiTurn turn;
      try {
        turn = await requestAnswer(forceCloud: cloudFirst);
      } catch (primaryError) {
        if (receivedReply) rethrow;
        await ai.local.refresh();
        if (cloudFirst && ai.local.ready) {
          status = 'Cloud delayed · answering privately on this phone…';
          notifyListeners();
          turn = await requestAnswer(forceCloud: false);
        } else if (!cloudFirst && cloudConfigured) {
          status = 'Local engine delayed · switching to fast cloud…';
          notifyListeners();
          turn = await requestAnswer(forceCloud: true);
        } else {
          throw primaryError;
        }
      }
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
      if (epoch == _turnEpoch) status = voiceWarning ?? 'Ready';
    } catch (e) {
      chunks.dispose();
      await speechQueue;
      if (epoch == _turnEpoch) {
        status = '${localAiEnabled ? 'Local Gemma' : 'AI connection'}: ${_voiceError(e)}';
        voiceWarning = status;
        if (shouldSpeak && speechEpoch == _speechEpoch) {
          try { await voice.speak(
              'I heard you, but neither available AI route completed this turn. Please check the status on screen.'); }
          catch (audioError) { voiceWarning = '$status Voice: ${_voiceError(audioError)}'; }
        }
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
    status = microphoneEnabled ? 'Listening…' : 'Response stopped';
    notifyListeners();
    _scheduleListen(80);
  }

  Future<void> _cancelTurn() async {
    _turnEpoch++;
    _speechEpoch++;
    ai.cancelTurn();
    _responseWatch = null;
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
          notes.add('⛔ This app is not in your allowed list.');
          continue;
        }
        final ok = await appActions.openSelectedApp(id);
        notes.add(ok ? '✓ Selected app opened.' : '⚠️ Could not open the app.');
      } else if (action.type == 'open_uri' && action.uri != null) {
        final ok = await appActions.openUri(action.uri!);
        notes.add(ok ? '✓ Allowed link opened.' : '⚠️ This link is not allowed or could not be opened.');
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
        ? 'Review the current screen. Briefly describe readable text, the current state, and the most useful next step. Say when something is unclear.'
        : 'Briefly describe what is visible in the camera frame. Report only clear observations.',
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
        status = screenVisionEnabled ? 'Screen vision is on' : 'Screen sharing was not approved.';
      } else {
        screenVisionEnabled = false;
        if (_visionTurn) await _cancelTurn();
        await bridge.stopScreenVision();
        status = 'Screen vision is off';
      }
    } catch (_) {
      screenVisionEnabled = false;
      status = 'Screen sharing is unavailable.';
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
          status = 'Could not capture the screen. Enable screen sharing again.';
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
        status = 'No current screen image is available. Check screen sharing.';
        notifyListeners();
        return;
      }
      await send(question, imageBase64: frame, speakReply: true);
    } catch (_) {
      status = 'Could not capture the screen. Enable screen sharing again.';
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
          status = 'Camera permission was denied.';
          return;
        }
        if (access != _accessEpoch) return;
        await camera.start();
        if (access != _accessEpoch) {
          await camera.stop();
          return;
        }
        cameraEnabled = true;
        status = 'Camera is on; preview is hidden.';
      } else {
        cameraEnabled = false;
        if (_visionTurn) await _cancelTurn();
        await camera.stop();
        status = 'Camera is off';
      }
    } catch (_) {
      cameraEnabled = false;
      status = 'Camera is unavailable. Check permissions and whether another app is using it.';
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
      status = 'Camera switched';
    } catch (_) {
      cameraEnabled = false;
      status = 'Could not switch cameras.';
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
      status = 'Could not capture a camera image.';
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
    try { await voice.speak('Goodbye, ${name.isEmpty ? 'friend' : name}'); } catch (_) {}
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
    voiceStarting = false;
    await voice.endSession();
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
    status = 'All active features are off.';
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
    if (!_disposed) {
      if (microphoneEnabled && status != _lastNotificationStatus) {
        _lastNotificationStatus = status;
        unawaited(voice.updateStatus(status));
      }
      super.notifyListeners();
    }
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
    unawaited(voice.endSession());
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
