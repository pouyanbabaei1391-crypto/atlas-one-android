import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('atlas.one/voice');
  const codec = StandardMethodCodec();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late VoiceService voice;
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    voice = VoiceService(android: true);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });
  Future<void> event(Map<String, dynamic> value) async {
    final done = Completer<void>();
    // Simulate messages from the native service, including stale callbacks.
    messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('event', value)), (_) => done.complete());
    await done.future;
  }
  int lastId() => (calls.lastWhere((c) => c.method == 'listen').arguments as Map)['id'] as int;

  test('Final text clears listening; stale results after cancellation are ignored', () async {
    final text = <String>[];
    await voice.listen(onText: (s, _) => text.add(s));
    final id = lastId();
    expect(voice.isListening, isTrue);
    await event({'type': 'text', 'id': id, 'text': 'Hello Atlas', 'final': false});
    expect(voice.isListening, isTrue);
    await event({'type': 'text', 'id': id, 'text': 'Hello Atlas.', 'final': true});
    expect(voice.isListening, isFalse);
    await voice.cancelListening();
    await event({'type': 'text', 'id': id, 'text': 'stale', 'final': true});
    expect(text, ['Hello Atlas', 'Hello Atlas.']);
  });
  test('Transient service errors retain the retry code; fatal errors stay explicit', () async {
    final errors = <String>[];
    await voice.listen(onText: (_, __) {}, onError: errors.add);
    await event({'type': 'error', 'id': lastId(), 'code': 8, 'message': 'Recognizer busy', 'retry': true});
    expect(errors.single, 'retry:8:Recognizer busy');
    expect(voice.isListening, isFalse);
    await voice.listen(onText: (_, __) {}, onError: errors.add);
    await event({'type': 'error', 'id': lastId(), 'code': 9, 'message': 'Microphone denied', 'retry': false});
    expect(errors.last, 'Microphone denied');
  });
  test('Native stop reaches the controller even without a visible screen', () async {
    var stopped = 0;
    voice.onSessionStopped = () => stopped++;
    await voice.listen(onText: (_, __) {});
    await event({'type': 'stopped'});
    expect(stopped, 1);
    expect(voice.isListening, isFalse);
  });
  test('Missing TTS can be retried without disabling recognition', () async {
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareOutput' && attempts++ == 0) {
        throw PlatformException(code: 'TTS_UNAVAILABLE', message: 'Install English voice');
      }
      return null;
    });
    await expectLater(voice.prepareOutput(), throwsA(isA<PlatformException>()));
    await voice.listen(onText: (_, __) {});
    expect(voice.isListening, isTrue);
    await voice.prepareOutput();
    expect(voice.englishVoiceAvailable, isTrue);
  });
  test('Stopping while the voice initializes prevents delayed playback', () async {
    final preparing = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareOutput') await preparing.future;
      return null;
    });
    final speaking = voice.speak('Do not play after stop');
    await Future<void>.delayed(Duration.zero);
    await voice.stopSpeaking();
    preparing.complete();
    await speaking;
    expect(calls.where((call) => call.method == 'speak'), isEmpty);
  });
}
