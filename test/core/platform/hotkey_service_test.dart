import 'package:aitrans/core/platform/hotkey_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'opening from the hotkey captures selection before showing the window',
    () async {
      final events = <String>[];
      final controller = HotkeyWindowController(
        isWindowVisible: () async => false,
        hideWindow: () async => events.add('hide'),
        captureSelection: () async => events.add('capture'),
        showWindow: () async => events.add('show'),
        focusWindow: () async => events.add('focus'),
      );

      await controller.toggle();

      expect(events, ['capture', 'show', 'focus']);
    },
  );

  test('closing from the hotkey does not capture selection', () async {
    final events = <String>[];
    final controller = HotkeyWindowController(
      isWindowVisible: () async => true,
      hideWindow: () async => events.add('hide'),
      captureSelection: () async => events.add('capture'),
      showWindow: () async => events.add('show'),
      focusWindow: () async => events.add('focus'),
    );

    await controller.toggle();

    expect(events, ['hide']);
  });

  test(
    'selection capture failure does not prevent opening the window',
    () async {
      final events = <String>[];
      final controller = HotkeyWindowController(
        isWindowVisible: () async => false,
        hideWindow: () async => events.add('hide'),
        captureSelection: () async {
          events.add('capture');
          throw StateError('synthetic capture failure');
        },
        showWindow: () async => events.add('show'),
        focusWindow: () async => events.add('focus'),
      );

      await controller.toggle();

      expect(events, ['capture', 'show', 'focus']);
    },
  );
}
