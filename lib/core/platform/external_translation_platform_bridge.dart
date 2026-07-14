import 'package:flutter/services.dart';

import 'external_translation_request.dart';

final class ExternalTranslationPlatformEvent {
  final int sequence;
  final ExternalTranslationSource source;
  final String text;

  const ExternalTranslationPlatformEvent({
    required this.sequence,
    required this.source,
    required this.text,
  });
}

final class ExternalTranslationPlatformBridge {
  ExternalTranslationPlatformBridge({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.aitrans/external_translation');

  final MethodChannel _channel;

  Future<void> start(
    void Function(ExternalTranslationPlatformEvent event) onRequest,
  ) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'externalTranslationRequest') {
        throw PlatformException(
          code: 'unsupported_external_translation_method',
          message: '不支持的外部翻译请求。',
        );
      }
      final event = decode(call.arguments);
      if (event == null) {
        throw PlatformException(
          code: 'invalid_external_translation_request',
          message: '外部翻译请求格式无效。',
        );
      }
      onRequest(event);
    });
    await _channel.invokeMethod<void>('ready');
  }

  void stop() => _channel.setMethodCallHandler(null);

  static ExternalTranslationPlatformEvent? decode(Object? arguments) {
    if (arguments is! Map) return null;
    final sequence = arguments['sequence'];
    final source = arguments['source'];
    final text = arguments['text'];
    if (sequence is! int || source != 'macosService' || text is! String) {
      return null;
    }
    return ExternalTranslationPlatformEvent(
      sequence: sequence,
      source: ExternalTranslationSource.macosService,
      text: text,
    );
  }
}
