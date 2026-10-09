import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings_service.dart';
import 'english_voice_service.dart';
import 'gemma_coach_service.dart';
import 'lesson_turn.dart';

enum CoachState { idle, listening, thinking, speaking, error }

class EnglishCoachController extends ChangeNotifier {
  final SettingsService settings = SettingsService();
  final EnglishVoiceService voice = EnglishVoiceService();
  final GemmaCoachService model = GemmaCoachService();
  final List<LessonTurn> lessons = [];
  final List<Map<String, String>> _history = [];

  String currentLevel = 'B1';
  String endpoint = 'http://192.168.1.10:11434/v1';
  String partialTranscript = '';
  String currentInput = '';
  String errorMessage = '';
  String message = 'Ready to explore English.';
  int tokenCount = 0;
  bool voiceEnabled = true;
  bool handsFree = false;
  bool modelAvailable = false;
  CoachState state = CoachState.idle;
  LessonTurn? get latest => lessons.isEmpty ? null : lessons.last;

  int _operation = 0;
  bool _disposed = false;
  bool _listeningHandled = false;
  String? _quizQuestion;
  String? _quizAnswer;

  void _emit() { if (!_disposed) notifyListeners(); }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currentLevel = prefs.getString('veltrix_cefr') ?? 'B1';
      voiceEnabled = prefs.getBool('veltrix_voice') ?? true;
      handsFree = prefs.getBool('veltrix_hands_free') ?? false;
      endpoint = await settings.baseUrl;
      // Connection checks must never block the first frame.
      unawaited(refreshConnection());
    } catch (error) {
      errorMessage = 'Settings could not load: $error';
    }
    _emit();
  }

  Future<void> refreshConnection() async {
    modelAvailable = await model.checkConnection(endpoint);
    _emit();
  }

  Future<void> setEndpoint(String value) async {
    final clean = value.trim();
    final uri = Uri.tryParse(clean);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      errorMessage = 'Enter a valid http:// or https:// Ollama server URL.';
      state = CoachState.error;
      _emit();
      return;
    }
    endpoint = clean;
    await settings.setBaseUrl(clean);
    modelAvailable = false;
    state = CoachState.idle;
    errorMessage = '';
    _emit();
    await refreshConnection();
  }

  Future<void> setLevel(String level) async {
    if (!const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].contains(level)) return;
    currentLevel = level;
    _emit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('veltrix_cefr', level);
  }

  Future<void> setVoice(bool enabled) async {
    voiceEnabled = enabled;
    if (!enabled) await voice.stopSpeaking();
    _emit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('veltrix_voice', enabled);
  }

  Future<void> setHandsFree(bool enabled) async {
    handsFree = enabled;
    _emit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('veltrix_hands_free', enabled);
    if (enabled && state == CoachState.idle) await startListening();
  }

  Future<void> send(String text) async {
    final input = text.trim();
    if (input.isEmpty) return;
    final op = ++_operation;
    model.cancel();
    await voice.cancelListening();
    await voice.stopSpeaking();
    state = CoachState.thinking;
    currentInput = input;
    partialTranscript = '';
    tokenCount = 0;
    errorMessage = '';
    message = 'Gemma 3 is building your lesson…';
    _emit();
    try {
      final key = await settings.apiKey;
      final lesson = await model.teach(
        input: input, level: currentLevel, baseUrl: endpoint, apiKey: key,
        recentTurns: _history.length <= 6 ? List.of(_history) : _history.sublist(_history.length - 6),
        previousQuestion: _quizQuestion, previousAnswer: _quizAnswer,
        onProgress: (count) { if (op == _operation) { tokenCount = count; _emit(); } },
      );
      if (op != _operation || _disposed) return;
      modelAvailable = true;
      lessons.add(lesson);
      _quizQuestion = lesson.quizQuestion;
      _quizAnswer = lesson.quizAnswer;
      _history.add({'role': 'user', 'content': input});
      // Compact structured recap instead of a full JSON replay: low context cost.
      _history.add({'role': 'assistant', 'content':
        'Correction: ${lesson.corrected}. Upgrade: ${lesson.upgraded}. Grammar: ${lesson.grammarRule}. New quiz: ${lesson.quizQuestion}'});
      if (_history.length > 8) _history.removeRange(0, _history.length - 8);
      state = CoachState.idle;
      message = 'Your lesson is ready. Answer the quiz to continue.';
      _emit();
      if (voiceEnabled) {
        state = CoachState.speaking;
        message = 'VELTRIX is speaking…';
        _emit();
        try {
          await voice.speak(lesson.spokenEnglish);
        } catch (e) {
          if (op == _operation) {
            errorMessage = 'TTS is unavailable: $e';
            _emit();
          }
        }
      }
      if (op != _operation || _disposed) return;
      state = CoachState.idle;
      message = 'Your turn. Try the new quiz.';
      _emit();
      if (handsFree) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (op == _operation && handsFree && !_disposed) await startListening();
      }
    } catch (error) {
      if (op != _operation || _disposed) return;
      modelAvailable = false;
      state = CoachState.error;
      errorMessage = error.toString().replaceFirst('Bad state: ', '');
      message = 'Check the Gemma 3 connection and try again.';
      _emit();
    }
  }

  Future<void> startListening() async {
    if (state == CoachState.thinking || state == CoachState.speaking) return;
    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw StateError('Microphone permission is required for speaking practice.');
      }
      await voice.stopSpeaking();
      _listeningHandled = false;
      partialTranscript = '';
      state = CoachState.listening;
      message = 'Listening in English…';
      errorMessage = '';
      _emit();
      await voice.listen(
        onText: (text, isFinal) {
          if (state != CoachState.listening || _listeningHandled) return;
          partialTranscript = text;
          _emit();
          if (isFinal && text.trim().isNotEmpty) _finishListening(text);
        },
        onError: (error) {
          if (state != CoachState.listening) return;
          if (error == 'error_no_match' || error == 'error_speech_timeout') {
            _finishListening(partialTranscript);
          } else {
            state = CoachState.error;
            errorMessage = 'Speech recognition: $error';
            _emit();
          }
        },
        onStopped: () {
          if (state == CoachState.listening && !_listeningHandled) _finishListening(partialTranscript);
        },
      );
    } catch (error) {
      state = CoachState.error;
      errorMessage = '$error';
      _emit();
    }
  }

  void _finishListening(String captured) {
    if (_listeningHandled) return;
    _listeningHandled = true;
    state = CoachState.idle;
    _emit();
    if (captured.trim().isNotEmpty) {
      unawaited(send(captured));
    } else {
      message = 'No speech detected. Tap Speak to try again.';
      _emit();
    }
  }

  Future<void> stop() async {
    ++_operation;
    model.cancel();
    handsFree = false;
    _listeningHandled = true;
    await voice.cancelListening();
    await voice.stopSpeaking();
    state = CoachState.idle;
    message = 'Stopped. You can continue whenever you like.';
    _emit();
  }

  void clear() {
    model.cancel();
    ++_operation;
    _listeningHandled = true;
    unawaited(voice.cancelListening());
    unawaited(voice.stopSpeaking());
    lessons.clear();
    _history.clear();
    _quizQuestion = null;
    _quizAnswer = null;
    partialTranscript = '';
    state = CoachState.idle;
    message = 'New English learning session.';
    errorMessage = '';
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    model.cancel();
    unawaited(voice.cancelListening());
    unawaited(voice.stopSpeaking());
    super.dispose();
  }
}
