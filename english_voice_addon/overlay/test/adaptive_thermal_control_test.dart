import 'package:flutter_test/flutter_test.dart';

import '../lib/core/adaptive_thermal_control_service.dart';

void main() {
  test('ATCS telemetry accepts complete native samples', () {
    final sample = AtcsTelemetry.fromMap(const {
      'batteryCelsius': 39.4,
      'thermalHeadroom': .51,
      'thermalStatus': 1,
      'batteryPercent': 72,
      'charging': true,
      'powerSave': false,
      'elapsedRealtimeMs': 12345,
    });
    expect(sample.batteryCelsius, 39.4);
    expect(sample.thermalHeadroom, .51);
    expect(sample.thermalStatus, 1);
    expect(sample.batteryPercent, 72);
    expect(sample.charging, isTrue);
  });

  test('ATCS intervals become progressively more conservative', () {
    final atcs = AdaptiveThermalControlSystem();
    final intervals = AtcsThermalLevel.values.map((thermalLevel) {
      atcs.level = thermalLevel;
      return atcs.visionInterval.inSeconds;
    }).toList();
    expect(intervals, orderedEquals(const [3, 3, 5, 9, 18, 30]));
    atcs.dispose();
  });
}
