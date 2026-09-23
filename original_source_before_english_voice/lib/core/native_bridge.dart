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
  Future<void> revokeSensitivePermissions() => _channel.invokeMethod('revokeSensitivePermissions');
}
