import 'package:aitrans/core/platform/application_command_platform_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes supported typed application commands', () {
    expect(
      ApplicationCommandPlatformBridge.decode({
        'command': 'showTranslation',
      })?.command,
      ApplicationCommand.showTranslation,
    );
    expect(
      ApplicationCommandPlatformBridge.decode({
        'command': 'showSettings',
      })?.command,
      ApplicationCommand.showSettings,
    );
  });

  test('rejects malformed and unsupported application commands', () {
    expect(ApplicationCommandPlatformBridge.decode(null), isNull);
    expect(
      ApplicationCommandPlatformBridge.decode({'command': 'quit'}),
      isNull,
    );
    expect(ApplicationCommandPlatformBridge.decode({'command': 1}), isNull);
  });

  test('repeated commands decode to distinct events', () {
    final first = ApplicationCommandPlatformBridge.decode({
      'command': 'showSettings',
    });
    final second = ApplicationCommandPlatformBridge.decode({
      'command': 'showSettings',
    });

    expect(identical(first, second), isFalse);
  });

  test('announces readiness after installing the Dart handler', () async {
    const channel = MethodChannel('test.application_commands');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var readyCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'ready');
      readyCalls++;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final bridge = ApplicationCommandPlatformBridge(channel: channel);

    await bridge.start((event) {});

    expect(readyCalls, 1);
  });
}
