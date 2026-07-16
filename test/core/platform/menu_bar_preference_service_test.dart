import 'package:aitrans/core/platform/menu_bar_preference_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads the native menu bar visibility as a typed bool', () async {
    const channel = MethodChannel('test.menu_bar_preferences.get');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getVisibility');
      expect(call.arguments, isNull);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final service = MethodChannelMenuBarPreferenceService(
      channel: channel,
      isSupported: true,
    );

    expect(await service.getVisibility(), isTrue);
  });

  test(
    'sets visibility only after native confirms the requested value',
    () async {
      const channel = MethodChannel('test.menu_bar_preferences.set');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'setVisibility');
        expect(call.arguments, isFalse);
        return false;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final service = MethodChannelMenuBarPreferenceService(
        channel: channel,
        isSupported: true,
      );

      await service.setVisibility(false);
    },
  );

  test('rejects malformed native visibility results', () async {
    const channel = MethodChannel('test.menu_bar_preferences.invalid');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final service = MethodChannelMenuBarPreferenceService(
      channel: channel,
      isSupported: true,
    );

    await expectLater(
      service.getVisibility(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_menu_bar_visibility',
        ),
      ),
    );
  });

  test('unsupported platforms never call the macOS channel', () async {
    const channel = MethodChannel('test.menu_bar_preferences.unsupported');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var callCount = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      callCount++;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final service = MethodChannelMenuBarPreferenceService(
      channel: channel,
      isSupported: false,
    );

    await expectLater(service.getVisibility(), throwsUnsupportedError);
    await expectLater(service.setVisibility(true), throwsUnsupportedError);
    expect(callCount, 0);
  });
}
