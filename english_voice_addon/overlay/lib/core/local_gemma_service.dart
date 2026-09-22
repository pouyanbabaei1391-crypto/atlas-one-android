import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocalGemmaService extends ChangeNotifier {
  static final LocalGemmaService instance = LocalGemmaService();
  final bool _android;
  LocalGemmaService({bool? android}) : _android = android ?? Platform.isAndroid {
    if (_android) _channel.setMethodCallHandler((call) async {
      if (call.method == 'state') {
        _apply(Map<String, dynamic>.from(call.arguments as Map));
      } else if (call.method == 'token') {
        final value = Map<String, dynamic>.from(call.arguments as Map);
        if (value['id'] == _request && _bytes != null) {
          _bytes!.add(List<int>.from(value['bytes'] as List));
        }
      }
    });
  }
  static const _channel = MethodChannel('atlas.one/local_gemma');
  String state = 'not_installed';
  String? error;
  bool installed = false;
  bool ready = false;
  double progress = 0;
  int ramBytes = 0;
  int _request = 0;
  bool _generating = false;
  StreamController<List<int>>? _bytes;
  bool get preparing => state == 'installing' || state == 'verifying' || state == 'loading';
  void _apply(Map<String, dynamic> value) {
    state = value['state'] as String? ?? state;
    installed = value['installed'] == true;
    ready = value['ready'] == true;
    progress = (value['progress'] as num?)?.toDouble() ?? progress;
    ramBytes = (value['ramBytes'] as num?)?.toInt() ?? ramBytes;
    error = value['error'] as String?;
    notifyListeners();
  }
  Future<void> refresh() async {
    if (!_android) return;
    final value = await _channel.invokeMapMethod<String, dynamic>('status');
    if (value != null) _apply(value);
  }
  Future<void> prepare() async {
    if (preparing) return;
    error = null;
    state = installed ? 'loading' : 'installing';
    notifyListeners();
    try {
      if (!installed) {
        final value = await _channel.invokeMapMethod<String, dynamic>('install');
        if (value != null) _apply(value);
      }
      state = 'loading'; notifyListeners();
      final loaded = await _channel.invokeMapMethod<String, dynamic>('load');
      if (loaded != null) _apply(loaded);
    } catch (e) {
      error = e is PlatformException ? e.message : e.toString();
      state = installed ? 'installed' : 'not_installed';
      notifyListeners();
      rethrow;
    }
  }
  Future<void> cancel() async {
    _request++;
    if (_android) await _channel.invokeMethod<void>('cancel');
  }
  Future<String> generate(String prompt, void Function(String)? onText) async {
    if (!ready) throw StateError('Prepare Gemma 3 4B using Local AI setup before speaking.');
    if (_generating) throw StateError('The previous local answer is still stopping. Try again in a moment.');
    _generating = true;
    final id = ++_request;
    final bytes = StreamController<List<int>>();
    _bytes = bytes;
    var result = '';
    // Decode across token boundaries, including split multi-byte UTF-8 characters.
    final decoded = bytes.stream.transform(const Utf8Decoder(allowMalformed: true)).listen((part) {
      result += part;
      if (id == _request) onText?.call(result);
    });
    try {
      await _channel.invokeMethod<void>('generate', {'prompt': prompt, 'maxTokens': 192, 'id': id});
      await bytes.close();
      if (id != _request) throw StateError('Generation cancelled.');
      if (result.trim().isEmpty) throw StateError('Gemma returned no answer. Try a shorter question.');
      return result;
    } finally {
      if (!bytes.isClosed) await bytes.close();
      await decoded.cancel();
      if (identical(_bytes, bytes)) _bytes = null;
      _generating = false;
    }
  }
}
