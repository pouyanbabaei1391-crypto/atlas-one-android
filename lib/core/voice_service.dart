import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    _ready = await _stt.initialize();
    await _tts.setLanguage('fa-IR');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  bool get isListening => _stt.isListening;

  Future<void> listen({required void Function(String text, bool finalResult) onText}) async {
    if (!_ready) await init();
    await _stt.listen(
      localeId: 'fa_IR',
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> stopListening() => _stt.stop();
  Future<void> cancelListening() => _stt.cancel();

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() => _tts.stop();
}
