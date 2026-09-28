import 'package:flutter/services.dart';
import '../models/app_target.dart';

class NativeBridge {
  static const _channel = MethodChannel('atlas.one/native');

  Future<bool> startScreenVision() async => (await _channel.invokeMethod<bool>('startScreenVision')) ?? false;
  Future<void> stopScreenVision() => _channel.invokeMethod('stopScreenVision');
  Future<String?> captureScreenFrame() => _channel.invokeMethod<String>('captureScreenFrame');

  Future<List<AppTarget>> listApps() async {
    final list = await _channel.invokeListMethod<dynamic>('listApps') ?? [];
    return list.map((e) => AppTarget.fromMap(Map<dynamic, dynamic>.from(e as Map))).toList();
  }

  Future<bool> launchApp(String id) async => (await _channel.invokeMethod<bool>('launchApp', {'id': id})) ?? false;
  Future<bool> accessibilityEnabled() async => (await _channel.invokeMethod<bool>('accessibilityEnabled')) ?? false;
  Future<void> openAccessibilitySettings() => _channel.invokeMethod('openAccessibilitySettings');
  Future<String> observeUi() async => (await _channel.invokeMethod<String>('observeUi')) ?? '';
  Future<bool> clickText(String text) async => (await _channel.invokeMethod<bool>('clickText', {'text': text})) ?? false;
  Future<bool> setFocusedText(String text) async => (await _channel.invokeMethod<bool>('setFocusedText', {'text': text})) ?? false;
  Future<bool> scrollUi(int direction) async => (await _channel.invokeMethod<bool>('scrollUi', {'direction': direction})) ?? false;
  Future<bool> globalBack() async => (await _channel.invokeMethod<bool>('globalBack')) ?? false;
  Future<bool> globalHome() async => (await _channel.invokeMethod<bool>('globalHome')) ?? false;
  Future<bool> pressEnter() async => (await _channel.invokeMethod<bool>('pressEnter')) ?? false;
  Future<bool> pressTab() async => (await _channel.invokeMethod<bool>('pressTab')) ?? false;

  Future<void> revokeSensitivePermissions() => _channel.invokeMethod('revokeSensitivePermissions');
}
