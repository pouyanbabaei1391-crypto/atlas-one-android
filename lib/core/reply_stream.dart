import 'dart:convert';

/// Only complete, decoded reply characters are exposed; action JSON is never spoken.
String streamedReply(String raw) {
  final match = RegExp(r'"reply"\s*:\s*"').firstMatch(raw);
  if (match == null) return '';
  final out = StringBuffer();
  var i = match.end;
  while (i < raw.length) {
    final char = raw[i++];
    if (char == '"') break;
    if (char != r'\') {
      out.write(char);
      continue;
    }
    if (i >= raw.length) break;
    final escaped = raw[i++];
    if (escaped == 'u') {
      if (i + 4 > raw.length) break;
      var end = i + 4;
      final code = int.tryParse(raw.substring(i, end), radix: 16);
      if (code == null) break;
      if (code >= 0xD800 && code <= 0xDBFF) {
        if (end + 6 > raw.length) break;
        end += 6;
      }
      try {
        out.write(jsonDecode('"\\u${raw.substring(i, end)}"'));
      } catch (_) { break; }
      i = end;
    } else {
      try {
        out.write(jsonDecode('"\\$escaped"'));
      } catch (_) { break; }
    }
  }
  return out.toString();
}

class SpeechChunks {
  String _seen = '';
  String _pending = '';
  final void Function(String) emit;
  SpeechChunks(this.emit);

  void add(String reply) {
    if (!reply.startsWith(_seen)) return;
    _pending += reply.substring(_seen.length);
    _seen = reply;
    while (true) {
      final end = RegExp(r'[.!?؟\n؛]').firstMatch(_pending);
      if (end != null) {
        _emitThrough(end.end);
      } else if (_pending.length >= 100 && _pending.lastIndexOf(' ') > 30) {
        _emitThrough(_pending.lastIndexOf(' ') + 1);
      } else {
        break;
      }
    }
  }

  void _emitThrough(int end) {
    final text = _pending.substring(0, end).trim();
    _pending = _pending.substring(end);
    if (text.isNotEmpty) emit(text);
  }

  void finish() => _emitThrough(_pending.length);
}
