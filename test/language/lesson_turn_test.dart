import 'package:flutter_test/flutter_test.dart';
import '../../lib/language/lesson_turn.dart';
import '../../lib/language/gemma_coach_service.dart';

void main() {
  test('normalizes Ollama addresses and prevents duplicate v1', () {
    expect(GemmaCoachService.normalizeBase('http://192.168.0.7:11434'), 'http://192.168.0.7:11434/v1');
    expect(GemmaCoachService.normalizeBase('http://localhost:11434/v1/'), 'http://localhost:11434/v1');
  });

  test('a single model reply contains all lesson sections', () {
    const raw = '''{"intent":"correction","was_correct":false,"corrected":"I agree with you.","upgraded":"I wholeheartedly agree with your assessment.","grammar_rule":"Agree is a verb","explanation_fa":"بعد از I نیازی به am نیست.","vocabulary":[{"word":"wholeheartedly","meaning_fa":"با تمام وجود","collocation":"wholeheartedly endorse","example":"I wholeheartedly endorse this proposal.","level":"C1"},{"word":"assessment","meaning_fa":"ارزیابی","collocation":"an accurate assessment","example":"We need an accurate assessment.","level":"B2"}],"practice":"Write a new sentence.","quiz_question":"Correct: I am agree.","quiz_answer":"I agree.","quiz_feedback":"","spoken_english":"A natural version is: I agree with you. Now correct: I am agree.","estimated_level":"B1"}''';
    final lesson = LessonTurn.fromModel(raw, 'I am agree.', 'B1');
    expect(lesson.wasCorrect, false);
    expect(lesson.corrected, 'I agree with you.');
    expect(lesson.vocabulary.length, 2);
    expect(lesson.quizAnswer, 'I agree.');
    expect(lesson.explanationFa, contains('نیازی'));
  });

  test('correct user sentence remains correct', () {
    final lesson = LessonTurn.fromModel('{"was_correct":true,"corrected":"I agree."}', 'I agree.', 'A1');
    expect(lesson.wasCorrect, true);
    expect(lesson.corrected, 'I agree.');
  });
}
