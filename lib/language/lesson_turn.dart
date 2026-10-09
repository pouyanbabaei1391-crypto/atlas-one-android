import 'dart:convert';

/// One complete educational cycle, not a generic chat message.
class VocabularyItem {
  final String word;
  final String meaningFa;
  final String collocation;
  final String example;
  final String level;

  const VocabularyItem({required this.word, required this.meaningFa,
    required this.collocation, required this.example, required this.level});

  factory VocabularyItem.fromJson(dynamic data) {
    final map = data is Map ? data : const <String, dynamic>{};
    String read(String key) => (map[key] ?? '').toString().trim();
    return VocabularyItem(word: read('word'), meaningFa: read('meaning_fa'),
      collocation: read('collocation'), example: read('example'), level: read('level'));
  }
}

class LessonTurn {
  final String userSentence;
  final String intent;
  final String corrected;
  final String upgraded;
  final String grammarRule;
  final String explanationFa;
  final String practice;
  final String quizQuestion;
  final String quizAnswer;
  final String quizFeedback;
  final String spokenEnglish;
  final String level;
  final bool wasCorrect;
  final List<VocabularyItem> vocabulary;

  const LessonTurn({required this.userSentence, required this.intent,
    required this.corrected, required this.upgraded, required this.grammarRule,
    required this.explanationFa, required this.practice,
    required this.quizQuestion, required this.quizAnswer,
    required this.quizFeedback, required this.spokenEnglish,
    required this.level, required this.wasCorrect, required this.vocabulary});

  factory LessonTurn.fromModel(String raw, String userSentence, String targetLevel) {
    var cleaned = raw.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '').trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) cleaned = cleaned.substring(start, end + 1);
    try {
      final json = jsonDecode(cleaned);
      if (json is! Map) throw const FormatException('Expected JSON object');
      String read(String key, [String fallback = '']) =>
          (json[key] ?? fallback).toString().trim();
      final items = json['vocabulary'];
      final vocabulary = items is List
          ? items.take(4).map(VocabularyItem.fromJson).where((v) => v.word.isNotEmpty).toList()
          : <VocabularyItem>[];
      final correction = read('corrected', userSentence);
      final upgraded = read('upgraded', correction);
      final explanation = read('explanation_fa', 'ساختار جمله را با نمونه‌های بیشتر تمرین کن.');
      final quiz = read('quiz_question', 'Rewrite your original sentence in more natural English.');
      return LessonTurn(
        userSentence: userSentence,
        intent: read('intent', 'Practice'),
        corrected: correction,
        upgraded: upgraded,
        grammarRule: read('grammar_rule', 'Natural English sentence structure'),
        explanationFa: explanation,
        practice: read('practice', 'Make another sentence using the improved structure.'),
        quizQuestion: quiz,
        quizAnswer: read('quiz_answer'),
        quizFeedback: read('quiz_feedback'),
        spokenEnglish: read('spoken_english', 'A natural version is: $upgraded. $quiz'),
        level: read('estimated_level', targetLevel),
        wasCorrect: json['was_correct'] == true,
        vocabulary: vocabulary,
      );
    } on FormatException {
      return LessonTurn(
        userSentence: userSentence, intent: 'Speaking practice',
        corrected: userSentence, upgraded: userSentence,
        grammarRule: 'Structured feedback was unavailable',
        explanationFa: 'مدل پاسخ ساختاریافته نداد؛ متن خام نمایش داده می‌شود. برای ارزیابی دقیق‌تر دوباره تلاش کن.',
        practice: 'Try using a longer sentence with a clear subject and verb.',
        quizQuestion: 'Can you restate your sentence using different words?',
        quizAnswer: '', quizFeedback: '',
        spokenEnglish: 'Let us practice that sentence again.',
        level: targetLevel, wasCorrect: false, vocabulary: const [],
      );
    }
  }
}
