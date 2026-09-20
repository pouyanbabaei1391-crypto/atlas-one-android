import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _persianLocale;
  void Function(String error)? _onError;

  Future<void> init() async {
    if (_ready) return;
    _ready = await _stt.initialize(
      onError: (error) => _onError?.call(error.errorMsg),
      debugLogging: false,
      finalTimeout: const Duration(seconds: 2),
    );

    if (_ready) {
      final locales = await _stt.locales();
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id == 'fa_ir' || id == 'fa-ir' || id.startsWith('fa')) {
          _persianLocale = locale.localeId;
          break;
        }
      }
    }

    final languages = await _tts.getLanguages;
    if (languages is List) {
      final fa = languages.map((e) => e.toString()).where((e) => e.toLowerCase().startsWith('fa')).toList();
      if (fa.isNotEmpty) {
        await _tts.setLanguage(fa.first);
      } else {
        await _tts.setLanguage('fa-IR');
      }
    } else {
      await _tts.setLanguage('fa-IR');
    }
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  bool get isListening => _stt.isListening;

  Future<void> listen({
    required void Function(String text, bool finalResult) onText,
    void Function(String error)? onError,
  }) async {
    _onError = onError;
    if (!_ready) await init();
    if (!_ready) {
      onError?.call('Speech recognition is not available on this device.');
      return;
    }
    await _stt.listen(
      localeId: _persianLocale,
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(minutes: 2),
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
    if (!_ready) await init();
    await _tts.stop();
    if (text.trim().isNotEmpty) await _tts.speak(text.trim());
  }

  Future<void> stopSpeaking() => _tts.stop();
}
