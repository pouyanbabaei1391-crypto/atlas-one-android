import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/reply_stream.dart';

void main() {
  testWidgets('English speech starts before full JSON and actions stay silent', (tester) async {
    const reply = 'Here is your answer with more detail to follow.';
    final raw = jsonEncode({'reply': reply, 'actions': [{'type': 'open_app', 'app_id': 'private-action'}]});
    final spoken = <String>[];
    final chunks = SpeechChunks(spoken.add);
    final first = raw.indexOf(' with');
    chunks.add(streamedReply(raw.substring(0, first)));
    await tester.pump(const Duration(milliseconds: 141));
    expect(spoken, isNotEmpty);
    chunks.add(streamedReply(raw));
    chunks.finish();
    expect(spoken.join(' '), reply);
    expect(spoken.join(' '), isNot(contains('private-action')));
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('Interrupted English output never speaks queued words', (tester) async {
    final spoken = <String>[];
    final chunks = SpeechChunks(spoken.add);
    chunks.add('Here is your answer');
    chunks.dispose();
    await tester.pump(const Duration(seconds: 1));
    chunks.add('Here is your answer.');
    chunks.finish();
    expect(spoken, isEmpty);
  });
}
