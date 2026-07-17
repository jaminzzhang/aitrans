import 'package:aitrans/core/platform/external_translation_platform_bridge.dart';
import 'package:aitrans/core/platform/external_translation_request.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes the typed macOS service method payload', () {
    final event = ExternalTranslationPlatformBridge.decode({
      'sequence': 7,
      'source': 'macosService',
      'text': 'selected text',
    });

    expect(event, isNotNull);
    expect(event!.sequence, 7);
    expect(event.source, ExternalTranslationSource.macosService);
    expect(event.text, 'selected text');
  });

  test('decodes the typed macOS hotkey payload', () {
    final event = ExternalTranslationPlatformBridge.decode({
      'sequence': 8,
      'source': 'macosHotkey',
      'text': 'selected by hotkey',
    });

    expect(event, isNotNull);
    expect(event!.source, ExternalTranslationSource.macosHotkey);
  });

  test('rejects malformed or unsupported method payloads', () {
    expect(ExternalTranslationPlatformBridge.decode(null), isNull);
    expect(
      ExternalTranslationPlatformBridge.decode({
        'sequence': '7',
        'source': 'macosService',
        'text': 'selected text',
      }),
      isNull,
    );
    expect(
      ExternalTranslationPlatformBridge.decode({
        'sequence': 7,
        'source': 'unknown',
        'text': 'selected text',
      }),
      isNull,
    );
  });

  test('announces readiness only after installing the Dart handler', () async {
    const channel = MethodChannel('test.external_translation');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var readyCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'ready');
      readyCalls++;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final bridge = ExternalTranslationPlatformBridge(channel: channel);

    await bridge.start((event) {});

    expect(readyCalls, 1);
  });
}
