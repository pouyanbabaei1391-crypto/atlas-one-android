import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  Future<void>? _initializing;
  Future<void>? _ttsInitializing;
  String? _persianLocale;
  bool persianVoiceAvailable = false;
  bool isSpeaking = false;
  int _speechGeneration = 0;
  Completer<void>? _speechStopped;
  void Function(String error)? _onError;
  void Function()? _onDone;

  Future<void> init() async {
    try {
      await (_initializing ??= _init());
    } catch (_) {
      _initializing = null;
      rethrow;
    }
    if (!_ready) _initializing = null;
  }

  Future<void> _init() async {
    _ready = await _stt.initialize(
      onError: (error) => _onError?.call(error.errorMsg),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _onDone?.call();
      },
      debugLogging: false,
      finalTimeout: const Duration(milliseconds: 350),
    );
    if (_ready) {
      for (final locale in await _stt.locales()) {
        if (locale.localeId.toLowerCase().startsWith('fa')) {
          _persianLocale = locale.localeId;
          break;
        }
      }
    }
    await _ensureTts();
  }

  Future<void> _ensureTts() async {
    try {
      await (_ttsInitializing ??= _initTts());
    } catch (_) {
      _ttsInitializing = null;
      rethrow;
    }
    if (!persianVoiceAvailable) _ttsInitializing = null;
  }

  Future<void> _initTts() async {
    final languages = await _tts.getLanguages;
    if (languages is List) {
      final fa = languages.map((e) => e.toString())
          .where((e) => e.toLowerCase().startsWith('fa')).toList();
      if (fa.isNotEmpty) {
        await _tts.setLanguage(fa.first);
        persianVoiceAvailable = true;
      }
    }
    await _tts.setSpeechRate(0.56);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  bool get isListening => _stt.isListening;

  Future<void> listen({
    required void Function(String text, bool finalResult) onText,
    void Function(String error)? onError,
    void Function()? onDone,
  }) async {
    _onError = onError;
    _onDone = onDone;
    await init();
    if (!_ready || _persianLocale == null) {
      onError?.call('تشخیص گفتار فارسی روی این دستگاه در دسترس نیست.');
      return;
    }
    await _stt.listen(
      localeId: _persianLocale,
      pauseFor: const Duration(milliseconds: 800),
      listenFor: const Duration(minutes: 2),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) => onText(result.recognizedWords, result.finalResult),
    );
  }

  Future<void> stopListening() async {
    if (_stt.isListening) await _stt.stop();
  }

  Future<void> cancelListening() async {
    if (_stt.isListening) await _stt.cancel();
  }

  Future<void> speak(String text) async {
    final generation = _speechGeneration;
    await _ensureTts();
    if (generation != _speechGeneration) return;
    if (!persianVoiceAvailable) {
      throw StateError('صدای فارسی در موتور گفتار گوشی نصب یا فعال نیست.');
    }
    if (text.trim().isEmpty) return;
    isSpeaking = true;
    final stopped = Completer<void>();
    _speechStopped = stopped;
    try {
      await Future.any<void>([
        _tts.speak(text.trim()).then<void>((_) {}),
        stopped.future,
      ]).timeout(const Duration(seconds: 45));
    } finally {
      if (generation == _speechGeneration) {
        isSpeaking = false;
        _speechStopped = null;
      }
    }
  }

  Future<void> stopSpeaking() async {
    _speechGeneration++;
    final stopped = _speechStopped;
    _speechStopped = null;
    if (stopped != null && !stopped.isCompleted) stopped.complete();
    await _tts.stop();
    isSpeaking = false;
  }
}
