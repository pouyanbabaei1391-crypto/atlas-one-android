import 'package:flutter_test/flutter_test.dart';
import '../lib/core/memory_intent_router.dart';

void main() {
  test('ordinary questions do not trigger memory retrieval', () {
    expect(MemoryIntentRouter.shouldRecall('What is the weather today?'), isFalse);
    expect(MemoryIntentRouter.shouldRecall('Explain gradient descent.'), isFalse);
  });

  test('history-dependent requests trigger memory retrieval', () {
    expect(MemoryIntentRouter.shouldRecall('What did I tell you about my project?'), isTrue);
    expect(MemoryIntentRouter.shouldRecall('Continue the same work as before.'), isTrue);
    expect(MemoryIntentRouter.shouldRecall('Remember my preferred model?'), isTrue);
  });
}
