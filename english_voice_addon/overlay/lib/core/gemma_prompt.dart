import '../models/chat_message.dart';

String gemmaPrompt(String instructions, List<ChatMessage> history, String message) {
  String clean(String text) => text.replaceAll('<start_of_turn>', '[start of turn]')
      .replaceAll('<end_of_turn>', '[end of turn]').replaceAll('<bos>', '');
  final recent = <ChatMessage>[];
  var budget = 2200;
  for (final item in history.reversed) {
    if (item.content.length > budget || recent.length >= 4) break;
    recent.insert(0, item);
    budget -= item.content.length;
  }
  final out = StringBuffer('<start_of_turn>user\n${clean(instructions)}\n');
  // Gemma expects alternating user/model turns; embed compact history as context.
  if (recent.isNotEmpty) {
    out.writeln('Recent conversation (context only):');
    for (final item in recent) { out.writeln('${item.role}: ${clean(item.content)}'); }
  }
  out.write('\nCurrent request: ${clean(message)}<end_of_turn>\n<start_of_turn>model\n');
  return out.toString();
}
