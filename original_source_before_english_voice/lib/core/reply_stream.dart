import 'dart:async';
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
  Timer? _flushTimer;
  bool _closed = false;
  bool _hasEmitted = false;
  SpeechChunks(this.emit);

  void _scheduleFlush() {
    if (_closed || _pending.isEmpty || _flushTimer != null) return;
    _flushTimer = Timer(const Duration(milliseconds: 220), () {
      _flushTimer = null;
      if (_closed) return;
      final boundary = _pending.lastIndexOf(' ');
      if (boundary >= 12) _emitThrough(boundary + 1);
      _scheduleFlush();
    });
  }

  void dispose() {
    _closed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void add(String reply) {
    if (_closed || !reply.startsWith(_seen)) return;
    _pending += reply.substring(_seen.length);
    _seen = reply;
    while (true) {
      final end = RegExp(r'[.!?؟\n؛]').firstMatch(_pending);
      if (end != null) {
        _emitThrough(end.end);
      } else if (_pending.length >= (_hasEmitted ? 100 : 36) && _pending.lastIndexOf(' ') > 12) {
        _emitThrough(_pending.lastIndexOf(' ') + 1);
      } else {
        break;
      }
    }
    _scheduleFlush();
  }

  void _emitThrough(int end) {
    final text = _pending.substring(0, end).trim();
    _pending = _pending.substring(end);
    if (text.isNotEmpty) {
      _hasEmitted = true;
      emit(text);
    }
  }

  void finish() {
    if (_closed) return;
    _emitThrough(_pending.length);
    dispose();
  }
}
