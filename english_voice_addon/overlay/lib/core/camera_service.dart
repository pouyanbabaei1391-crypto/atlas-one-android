import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;
  Future<String>? _captureInFlight;
  CameraLensDirection _direction = CameraLensDirection.front;

  Future<void> start() async {
    if (controller != null) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('No camera is available.');
    final preferred = cameras.where((c) => c.lensDirection == _direction);
    final next = CameraController(
      preferred.isNotEmpty ? preferred.first : cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await next.initialize();
      await next.setFlashMode(FlashMode.off);
      controller = next;
    } catch (_) {
      await next.dispose();
      rethrow;
    }
  }

  Future<void> switchLens() async {
    await stop();
    _direction = _direction == CameraLensDirection.front
        ? CameraLensDirection.back : CameraLensDirection.front;
    await start();
  }

  Future<String> captureBase64() {
    return _captureInFlight ??= _captureFrame().whenComplete(() {
      _captureInFlight = null;
    });
  }

  Future<String> _captureFrame() async {
    final current = controller;
    if (current == null || !current.value.isInitialized) {
      throw StateError('Camera is not ready.');
    }
    final file = await current.takePicture();
    try {
      return base64Encode(await file.readAsBytes());
    } finally {
      // This temporary capture belongs to this turn; no user files are removed.
      try { await File(file.path).delete(); } catch (_) {}
    }
  }

  Future<void> stop() async {
    final current = controller;
    controller = null;
    try { await _captureInFlight; } catch (_) {}
    await current?.dispose();
  }
}
