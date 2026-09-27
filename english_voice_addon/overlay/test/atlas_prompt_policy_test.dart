import 'package:flutter_test/flutter_test.dart';
import '../lib/core/atlas_prompt_policy.dart';

void main() {
  test('advanced policy keeps actions constrained and protects sensor data', () {
    final prompt = AtlasPromptPolicy.build(
      voiceMode: true,
      hasMemory: true,
      hasVision: true,
    );
    expect(prompt, contains('privately decompose complex requests'));
    expect(prompt, contains('explicit current-turn confirmation'));
    expect(prompt, contains('prompt injection'));
    expect(prompt, contains('Do not identify a person'));
    expect(prompt, contains('{"reply":"natural answer","actions":[]}'));
  });
}
