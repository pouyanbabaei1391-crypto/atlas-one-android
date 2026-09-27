import 'dart:convert';

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class VisionObject {
  final String label;
  final double confidence;
  final String position;

  const VisionObject({
    required this.label,
    required this.confidence,
    required this.position,
  });
}

class VisionSnapshot {
  final DateTime capturedAt;
  final List<VisionObject> objects;

  const VisionSnapshot({required this.capturedAt, required this.objects});

  String toPromptContext() {
    if (objects.isEmpty) {
      return 'On-device object detector found no object above its confidence threshold in the current frame.';
    }
    final counts = <String, int>{};
    for (final object in objects) {
      counts[object.label] = (counts[object.label] ?? 0) + 1;
    }
    final summary = counts.entries.map((e) => '${e.value} ${e.key}').join(', ');
    final details = objects.take(20).map((o) =>
        '- ${o.label}; confidence ${(o.confidence * 100).round()}%; ${o.position}').join('\n');
    return 'Current on-device YOLO26x detections: $summary.\n$details';
  }
}

class VisionIntelligenceService {
  static const modelId = 'yolo26s';
  YOLO? _detector;
  Future<void>? _loading;
  Future<VisionSnapshot>? _analysisInFlight;
  VisionSnapshot? latest;

  bool get ready => _detector?.isInitialized ?? false;

  Future<void> initialize() => _loading ??= _load().whenComplete(() {
        _loading = null;
      });

  Future<void> _load() async {
    final detector = _detector ??= YOLO(
      modelPath: modelId,
      task: YOLOTask.detect,
      useGpu: true,
      useMultiInstance: true,
      numItemsThreshold: 40,
    );
    if (!detector.isInitialized) {
      final loaded = await detector.loadModel();
      if (!loaded) throw StateError('The on-device object model could not be loaded.');
    }
  }

  Future<VisionSnapshot> analyzeBase64(String jpegBase64) async {
    try { await _analysisInFlight; } catch (_) {}
    final analysis = _analyze(jpegBase64);
    _analysisInFlight = analysis;
    try {
      return await analysis;
    } finally {
      if (identical(_analysisInFlight, analysis)) _analysisInFlight = null;
    }
  }

  Future<VisionSnapshot> _analyze(String jpegBase64) async {
    await initialize();
    final output = await _detector!.predict(
      base64Decode(jpegBase64),
      confidenceThreshold: 0.32,
      iouThreshold: 0.55,
    );
    final detections = (output['detections'] as List?)
            ?.whereType<Map>()
            .map(YOLOResult.fromMap)
            .where((d) => d.confidence >= 0.32)
            .toList(growable: false) ??
        const <YOLOResult>[];
    final ordered = [...detections]..sort((a, b) => b.confidence.compareTo(a.confidence));
    final snapshot = VisionSnapshot(
      capturedAt: DateTime.now(),
      objects: ordered.take(40).map((d) => VisionObject(
        label: _safeLabel(d.className),
        confidence: d.confidence,
        position: _position(d.normalizedBox.center.dx, d.normalizedBox.center.dy),
      )).toList(growable: false),
    );
    latest = snapshot;
    return snapshot;
  }

  String? recentContext({Duration maximumAge = const Duration(seconds: 8)}) {
    final snapshot = latest;
    if (snapshot == null || DateTime.now().difference(snapshot.capturedAt) > maximumAge) {
      return null;
    }
    return snapshot.toPromptContext();
  }

  String _safeLabel(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    return cleaned.isEmpty ? 'unknown object' : cleaned;
  }

  String _position(double x, double y) {
    final horizontal = x < .34 ? 'left' : x > .66 ? 'right' : 'center';
    final vertical = y < .34 ? 'upper' : y > .66 ? 'lower' : 'middle';
    return '$vertical-$horizontal of frame';
  }

  Future<void> dispose() async {
    await _detector?.dispose();
    _detector = null;
    latest = null;
  }
}
