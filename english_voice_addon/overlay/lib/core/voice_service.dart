import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'legacy_voice_service.dart';

/// Android uses a process-owned engine and a visible microphone foreground service.
/// Other platforms retain their original speech implementation.
class VoiceService extends LegacyVoiceService {
  static const _channel = MethodChannel('atlas.one/voice');
  bool _listening = false;
  bool _outputReady = false;
  bool _speaking = false;
  int _request = 0;
  int _outputEpoch = 0;
  Future<void>? _preparing;
  void Function(String, bool)? _text;
  void Function(String)? _error;
  void Function()? _done;
  void Function()? onSessionStopped;
  void Function(double)? onLevel;
  void Function()? onReady;

  final bool _android;

  VoiceService({bool? android}) : _android = android ?? Platform.isAndroid {
    if (_android) {
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'event') return;
        final event = Map<String, dynamic>.from(call.arguments as Map);
        final type = event['type'];
        if (type == 'stopped') {
          _listening = false;
          _request++;
          onSessionStopped?.call();
          return;
        }
        if (event['id'] != _request) return;
        switch (type) {
          case 'ready':
            onReady?.call();
            break;
          case 'level':
            onLevel?.call(((event['value'] as num?)?.toDouble() ?? 0).clamp(-2, 12).toDouble());
            break;
          case 'text':
            final finalResult = event['final'] == true;
            if (finalResult) _listening = false;
            _text?.call(event['text'] as String? ?? '', finalResult);
            break;
          case 'done':
            _listening = false;
            _done?.call();
            break;
          case 'error':
            _listening = false;
            final code = event['code'];
            if (event['retry'] == true) {
              _error?.call('retry:$code:${event['message']}');
            } else {
              _error?.call(event['message'] as String? ?? 'Speech recognition is unavailable.');
            }
            break;
        }
      });
    }
  }

  Future<void> startSession() async {
    if (_android) await _channel.invokeMethod<void>('startSession');
  }

  Future<void> endSession() async {
    if (_android) await _channel.invokeMethod<void>('endSession');
  }

  Future<void> updateStatus(String text) async {
    if (_android) {
      try { await _channel.invokeMethod<void>('status', {'text': text}); } catch (_) {}
    }
  }

  @override
  bool get englishVoiceAvailable => _android ? _outputReady : super.englishVoiceAvailable;
  @override
  bool get isListening => _android ? _listening : super.isListening;
  @override
  bool get isSpeaking => _android ? _speaking : super.isSpeaking;

  @override
  Future<void> init() async {
    // STT must not fail merely because a TTS voice is unavailable.
    if (!_android) await super.init();
  }

  @override
  Future<void> prepareOutput() async {
    if (!_android) { await super.prepareOutput(); return; }
    if (_outputReady) return;
    await (_preparing ??= _prepareNative());
  }

  Future<void> _prepareNative() async {
    try {
      await _channel.invokeMethod<void>('prepareOutput');
      _outputReady = true;
    } finally { _preparing = null; }
  }

  @override
  Future<void> listen({required void Function(String, bool) onText,
      void Function(String)? onError, void Function()? onDone}) async {
    if (!_android) {
      await super.listen(onText: onText, onError: onError, onDone: onDone);
      return;
    }
    _text = onText;
    _error = onError;
    _done = onDone;
    final request = ++_request;
    _listening = true;
    try { await _channel.invokeMethod<void>('listen', {'id': request}); }
    catch (e) {
      if (request != _request) return;
      _listening = false;
      onError?.call(e is PlatformException ? (e.message ?? e.code) : e.toString());
    }
  }

  @override
  Future<void> stopListening() => cancelListening();

  @override
  Future<void> cancelListening() async {
    if (!_android) { await super.cancelListening(); return; }
    _request++;
    _listening = false;
    await _channel.invokeMethod<void>('cancelListening');
  }

  @override
  Future<void> speak(String text) async {
    if (!_android) { await super.speak(text); return; }
    final epoch = _outputEpoch;
    await prepareOutput();
    if (epoch != _outputEpoch || text.trim().isEmpty) return;
    _speaking = true;
    try { await _channel.invokeMethod<void>('speak', {'text': text.trim()}); }
    catch (_) { _outputReady = false; rethrow; }
    finally { if (epoch == _outputEpoch) _speaking = false; }
  }

  @override
  Future<void> stopSpeaking() async {
    if (!_android) { await super.stopSpeaking(); return; }
    _outputEpoch++;
    _speaking = false;
    await _channel.invokeMethod<void>('stopSpeaking');
  }
}
