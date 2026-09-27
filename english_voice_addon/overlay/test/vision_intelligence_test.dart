import 'package:flutter_test/flutter_test.dart';
import '../lib/core/vision_intelligence_service.dart';

void main() {
  test('camera observations become compact transferable LLM data', () {
    final snapshot = VisionSnapshot(
      capturedAt: DateTime(2026),
      objects: const [
        VisionObject(label: 'person', confidence: .94, position: 'middle-center of frame'),
        VisionObject(label: 'chair', confidence: .81, position: 'lower-left of frame'),
      ],
    );
    final context = snapshot.toPromptContext();
    expect(context, contains('1 person'));
    expect(context, contains('confidence 94%'));
    expect(context, contains('lower-left'));
  });
}
