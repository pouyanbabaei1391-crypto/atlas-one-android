import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// English-first speech input/output using the Android system engines.
/// On some devices STT uses a network service; it is not guaranteed offline.
class EnglishVoiceService {
  final SpeechToText _recognizer = SpeechToText();
  final FlutterTts _speaker = FlutterTts();
  String _locale = 'en_US';
  bool _initialized = false;
  bool _ttsInitialized = false;
  bool isSpeaking = false;
  Future<void>? _initialization;
  void Function(String)? _onError;
  void Function()? _onStopped;

  bool get isListening => _recognizer.isListening;

  Future<bool> initialize() async {
    try {
      await (_initialization ??= _prepare());
      return _initialized;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _prepare() async {
    _initialized = await _recognizer.initialize(
      debugLogging: false,
      onError: (e) => _onError?.call(e.errorMsg),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _onStopped?.call();
      },
      finalTimeout: const Duration(milliseconds: 500),
    );
    if (_initialized) {
      final locales = await _recognizer.locales();
      String? selected;
      for (final wanted in ['en_US', 'en_GB', 'en']) {
        for (final locale in locales) {
          if (locale.localeId.toLowerCase().startsWith(wanted.toLowerCase())) {
            selected = locale.localeId;
            break;
          }
        }
        if (selected != null) break;
      }
      _locale = selected ?? _locale;
    }
    await prepareTts();
  }

  Future<void> prepareTts() async {
    if (_ttsInitialized) return;
    await _speaker.setLanguage('en-US');
    await _speaker.setSpeechRate(0.47); // Clear enough for beginners.
    await _speaker.setPitch(1.02);
    await _speaker.setVolume(1.0);
    await _speaker.awaitSpeakCompletion(true);
    _ttsInitialized = true;
  }

  Future<void> setSpeakingRate(double rate) async {
    await prepareTts();
    await _speaker.setSpeechRate(rate.clamp(0.3, 0.65).toDouble());
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
    required void Function(String message) onError,
    required void Function() onStopped,
  }) async {
    _onError = onError;
    _onStopped = onStopped;
    if (!await initialize()) {
      throw StateError('English speech recognition is unavailable on this device.');
    }
    if (_recognizer.isListening) await _recognizer.cancel();
    await _recognizer.listen(
      localeId: _locale,
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 2),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) => onText(result.recognizedWords, result.finalResult),
    );
  }

  Future<void> stopListening() async {
    if (isListening) await _recognizer.stop();
  }

  Future<void> cancelListening() async {
    if (isListening) await _recognizer.cancel();
  }

  Future<void> speak(String words) async {
    if (words.trim().isEmpty) return;
    await prepareTts();
    isSpeaking = true;
    try {
      await _speaker.speak(words.trim()).timeout(const Duration(seconds: 75));
    } finally {
      isSpeaking = false;
    }
  }

  Future<void> stopSpeaking() async {
    await _speaker.stop();
    isSpeaking = false;
  }
}
