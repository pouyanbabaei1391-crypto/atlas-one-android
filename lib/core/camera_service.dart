import 'dart:convert';
import 'package:camera/camera.dart';

class CameraService {
  CameraController? controller;

  Future<void> start() async {
    if (controller != null) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No camera available');
    final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();
    controller = CameraController(
      front.isNotEmpty ? front.first : cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller!.initialize();
  }

  Future<String> captureBase64() async {
    final file = await controller!.takePicture();
    return base64Encode(await file.readAsBytes());
  }

  Future<void> stop() async {
    await controller?.dispose();
    controller = null;
  }
}
