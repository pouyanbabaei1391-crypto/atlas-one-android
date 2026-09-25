import '../models/chat_message.dart';

String gemmaPrompt(String instructions, List<ChatMessage> history, String message,
    {bool fastVoice = false}) {
  String clean(String text) => text.replaceAll('<|im_start|>', '[start]')
      .replaceAll('<|im_end|>', '[end]');
  final recent = <ChatMessage>[];
  var budget = fastVoice ? 600 : 2200;
  for (final item in history.reversed) {
    if (item.content.length > budget || recent.length >= (fastVoice ? 2 : 4)) break;
    recent.insert(0, item);
    budget -= item.content.length;
  }
  final out = StringBuffer('<|im_start|>system\n${clean(instructions)}\n/no_think<|im_end|>\n');
  for (final item in recent) {
    final role = item.role == 'assistant' ? 'assistant' : 'user';
    out.write('<|im_start|>$role\n${clean(item.content)}<|im_end|>\n');
  }
  out.write('<|im_start|>user\n${clean(message)}\n/no_think<|im_end|>\n<|im_start|>assistant\n');
  return out.toString();
}
