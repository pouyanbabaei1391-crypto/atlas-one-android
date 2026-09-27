import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

enum AtcsThermalLevel { cool, normal, warm, hot, critical, emergency }

class AtcsTelemetry {
  final double? batteryCelsius;
  final double? thermalHeadroom;
  final int thermalStatus;
  final int batteryPercent;
  final bool charging;
  final bool powerSave;
  final int elapsedRealtimeMs;

  const AtcsTelemetry({
    required this.batteryCelsius,
    required this.thermalHeadroom,
    required this.thermalStatus,
    required this.batteryPercent,
    required this.charging,
    required this.powerSave,
    required this.elapsedRealtimeMs,
  });

  factory AtcsTelemetry.fromMap(Map<Object?, Object?> value) => AtcsTelemetry(
    batteryCelsius: (value['batteryCelsius'] as num?)?.toDouble(),
    thermalHeadroom: (value['thermalHeadroom'] as num?)?.toDouble(),
    thermalStatus: (value['thermalStatus'] as num?)?.toInt() ?? 0,
    batteryPercent: (value['batteryPercent'] as num?)?.toInt() ?? -1,
    charging: value['charging'] == true,
    powerSave: value['powerSave'] == true,
    elapsedRealtimeMs: (value['elapsedRealtimeMs'] as num?)?.toInt() ?? 0,
  );
}

/// Predictive, hysteretic thermal governor for continuous on-device vision.
///
/// ATCS never changes model answers or disables user controls. It only reduces
/// silent background inference before Android must apply harsh system throttling.
class AdaptiveThermalControlSystem {
  static const _channel = MethodChannel('atlas.one/atcs');
  static const _samplePeriod = Duration(seconds: 2);

  Timer? _timer;
  bool _sampling = false;
  bool _disposed = false;
  double? _filteredTemperature;
  double _temperatureTrendPerMinute = 0;
  DateTime? _lastSampleAt;
  double? _lastFilteredTemperature;
  DateTime _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastFrameSignature;
  int _recoveryVotes = 0;
  AtcsTelemetry? telemetry;
  AtcsThermalLevel level = AtcsThermalLevel.normal;

  double? get filteredTemperature => _filteredTemperature;
  double get predictedTemperature =>
      (_filteredTemperature ?? 34) +
      math.max(0, _temperatureTrendPerMinute) * 0.75;

  Duration get visionInterval {
    switch (level) {
      case AtcsThermalLevel.cool:
      case AtcsThermalLevel.normal:
        return const Duration(seconds: 3);
      case AtcsThermalLevel.warm:
        return const Duration(seconds: 5);
      case AtcsThermalLevel.hot:
        return const Duration(seconds: 9);
      case AtcsThermalLevel.critical:
        return const Duration(seconds: 18);
      case AtcsThermalLevel.emergency:
        return const Duration(seconds: 30);
    }
  }

  Future<void> start() async {
    if (_disposed || _timer != null) return;
    await _sample();
    _timer = Timer.periodic(_samplePeriod, (_) => _sample());
  }

  Future<void> _sample() async {
    if (_disposed || _sampling) return;
    _sampling = true;
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>('telemetry');
      if (raw == null) return;
      final sample = AtcsTelemetry.fromMap(raw);
      telemetry = sample;
      _updateTemperature(sample);
      _updateLevel(sample);
    } on MissingPluginException {
      // Non-Android builds retain the conservative three-second baseline.
    } on PlatformException {
      // A transient sensor read must not affect the assistant turn.
    } finally {
      _sampling = false;
    }
  }

  void _updateTemperature(AtcsTelemetry sample) {
    final value = sample.batteryCelsius;
    if (value == null || value < -10 || value > 90) return;
    final now = DateTime.now();
    final previous = _filteredTemperature;
    _filteredTemperature = previous == null
        ? value
        : previous * 0.72 + value * 0.28;
    final beforeAt = _lastSampleAt;
    final beforeValue = _lastFilteredTemperature;
    if (beforeAt != null && beforeValue != null) {
      final minutes = now.difference(beforeAt).inMilliseconds / 60000.0;
      if (minutes > 0.005) {
        final rawTrend = ((_filteredTemperature! - beforeValue) / minutes)
            .clamp(-8.0, 8.0)
            .toDouble();
        _temperatureTrendPerMinute =
            _temperatureTrendPerMinute * 0.7 + rawTrend * 0.3;
      }
    }
    _lastSampleAt = now;
    _lastFilteredTemperature = _filteredTemperature;
  }

  void _updateLevel(AtcsTelemetry sample) {
    final t = _filteredTemperature ?? 34;
    final predicted = predictedTemperature;
    final headroom = sample.thermalHeadroom;
    final status = sample.thermalStatus;
    var target = AtcsThermalLevel.normal;
    if (t < 32 && status == 0) target = AtcsThermalLevel.cool;
    if (t >= 37.5 || predicted >= 39 || status >= 1 || sample.powerSave) {
      target = AtcsThermalLevel.warm;
    }
    if (t >= 40.5 ||
        predicted >= 42 ||
        status >= 2 ||
        (headroom != null && headroom >= .72)) {
      target = AtcsThermalLevel.hot;
    }
    if (t >= 43.5 ||
        predicted >= 45 ||
        status >= 3 ||
        (headroom != null && headroom >= .88)) {
      target = AtcsThermalLevel.critical;
    }
    if (t >= 46.5 || status >= 4 || (headroom != null && headroom >= .97)) {
      target = AtcsThermalLevel.emergency;
    }

    if (target.index >= level.index) {
      level = target;
      _recoveryVotes = 0;
      return;
    }
    // Three cooler samples and a 1.5 C margin prevent rapid mode oscillation.
    final boundary = <AtcsThermalLevel, double>{
      AtcsThermalLevel.emergency: 45.0,
      AtcsThermalLevel.critical: 42.0,
      AtcsThermalLevel.hot: 39.0,
      AtcsThermalLevel.warm: 36.0,
      AtcsThermalLevel.normal: 31.0,
      AtcsThermalLevel.cool: 0.0,
    }[level]!;
    if (t <= boundary && status < level.index) {
      _recoveryVotes++;
      if (_recoveryVotes >= 3) {
        level = AtcsThermalLevel.values[level.index - 1];
        _recoveryVotes = 0;
      }
    } else {
      _recoveryVotes = 0;
    }
  }

  Future<bool> allowVisionInference(String jpegBase64) async {
    if (_disposed) return false;
    if (_timer == null) await start();
    if (level == AtcsThermalLevel.emergency) return false;
    final now = DateTime.now();
    if (now.difference(_lastInferenceAt) < visionInterval) return false;

    final signature = _signature(jpegBase64);
    final unchanged = signature == _lastFrameSignature;
    _lastFrameSignature = signature;
    // Static scenes need only a periodic refresh; this avoids wasting YOLO work.
    if (unchanged &&
        now.difference(_lastInferenceAt) < const Duration(seconds: 24)) {
      return false;
    }
    return true;
  }

  void recordVisionInference() {
    _lastInferenceAt = DateTime.now();
  }

  int _signature(String value) {
    var hash = 0x811c9dc5;
    if (value.isEmpty) return hash;
    final stride = math.max(1, value.length ~/ 192);
    for (var index = 0; index < value.length; index += stride) {
      hash ^= value.codeUnitAt(index);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
