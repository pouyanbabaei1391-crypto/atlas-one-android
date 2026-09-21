import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/reply_stream.dart';

void main() {
  test('Every network split preserves Persian, quotes, newlines and action isolation', () {
    const reply = 'سلام دوست من!\nاو گفت: "خوش آمدی"؛ مسیر \\ و 😀';
    final payload = jsonEncode({
      'reply': reply,
      'actions': [{'type': 'open_app', 'app_id': 'must-not-be-spoken'}],
    });
    var previous = '';
    for (var end = 0; end <= payload.length; end++) {
      final partial = streamedReply(payload.substring(0, end));
      expect(reply.startsWith(partial), isTrue);
      expect(partial.startsWith(previous), isTrue);
      previous = partial;
    }
    expect(previous, reply);
  });

  test('Split unicode escapes and surrogate pairs do not leak JSON escapes', () {
    const payload = r'{"reply":"\u0633\u0644\u0627\u0645 \ud83d\ude00","actions":[]}';
    const reply = 'سلام 😀';
    for (var end = 0; end <= payload.length; end++) {
      expect(reply.startsWith(streamedReply(payload.substring(0, end))), isTrue);
    }
    expect(streamedReply(payload), reply);
  });

  test('Speech starts before the response completes and never repeats text', () {
    final emitted = <String>[];
    final chunks = SpeechChunks(emitted.add);
    chunks.add('سلام.');
    expect(emitted, ['سلام.']);
    chunks.add('سلام.');
    chunks.add('سلام. خوبی؟ ادامه');
    expect(emitted, ['سلام.', 'خوبی؟']);
    chunks.finish();
    expect(emitted, ['سلام.', 'خوبی؟', 'ادامه']);
  });

  test('No reply field means no partial speech', () {
    expect(streamedReply(r'{"actions":[{"type":"open_uri","uri":"https://example.com"}]}'), '');
  });
}
