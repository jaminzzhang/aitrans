import 'package:flutter/services.dart';

enum ApplicationCommand { showTranslation, showSettings }

final class ApplicationCommandEvent {
  final ApplicationCommand command;

  const ApplicationCommandEvent(this.command);
}

final class ApplicationCommandPlatformBridge {
  ApplicationCommandPlatformBridge({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.aitrans/application_commands');

  final MethodChannel _channel;

  Future<void> start(
    void Function(ApplicationCommandEvent event) onCommand,
  ) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'applicationCommand') {
        throw PlatformException(
          code: 'unsupported_application_command_method',
          message: '不支持的应用命令。',
        );
      }
      final event = decode(call.arguments);
      if (event == null) {
        throw PlatformException(
          code: 'invalid_application_command',
          message: '应用命令格式无效。',
        );
      }
      onCommand(event);
    });
    await _channel.invokeMethod<void>('ready');
  }

  void stop() => _channel.setMethodCallHandler(null);

  static ApplicationCommandEvent? decode(Object? arguments) {
    if (arguments is! Map) return null;
    return switch (arguments['command']) {
      'showTranslation' => ApplicationCommandEvent(
        ApplicationCommand.showTranslation,
      ),
      'showSettings' => ApplicationCommandEvent(
        ApplicationCommand.showSettings,
      ),
      _ => null,
    };
  }
}
