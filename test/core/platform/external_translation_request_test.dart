import 'package:aitrans/core/config/external_translation_config.dart';
import 'package:aitrans/core/platform/external_translation_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'accepts a valid macOS service request and trims boundary whitespace',
    () {
      final validator = ExternalTranslationRequestValidator(
        ExternalTranslationConfig(),
      );

      final result = validator.validate(
        sequence: 1,
        source: ExternalTranslationSource.macosService,
        text: '  translate me  ',
      );

      expect(result, isA<AcceptedExternalTranslationRequest>());
      final request = (result as AcceptedExternalTranslationRequest).request;
      expect(request.sequence, 1);
      expect(request.source, ExternalTranslationSource.macosService);
      expect(request.text, 'translate me');
    },
  );

  test('uses 5000 Unicode code points as the default code-level limit', () {
    expect(ExternalTranslationConfig().maxCharacters, 5000);
  });

  test('rejects non-positive configured limits', () {
    expect(
      () => ExternalTranslationConfig(maxCharacters: 0),
      throwsArgumentError,
    );
    expect(
      () => ExternalTranslationConfig(maxCharacters: -1),
      throwsArgumentError,
    );
  });

  test('rejects a non-positive service sequence', () {
    final validator = ExternalTranslationRequestValidator(
      ExternalTranslationConfig(),
    );

    final result = validator.validate(
      sequence: 0,
      source: ExternalTranslationSource.macosService,
      text: 'translate me',
    );

    expect(result, isA<RejectedExternalTranslationRequest>());
    expect(
      (result as RejectedExternalTranslationRequest).reason,
      ExternalTranslationRejectionReason.invalidSequence,
    );
  });

  test('rejects text that is empty after trimming', () {
    final validator = ExternalTranslationRequestValidator(
      ExternalTranslationConfig(),
    );

    final result = validator.validate(
      sequence: 1,
      source: ExternalTranslationSource.macosService,
      text: ' \n\t ',
    );

    expect(result, isA<RejectedExternalTranslationRequest>());
    expect(
      (result as RejectedExternalTranslationRequest).reason,
      ExternalTranslationRejectionReason.emptyText,
    );
  });

  test('accepts the configured limit and rejects the next code point', () {
    final validator = ExternalTranslationRequestValidator(
      ExternalTranslationConfig(maxCharacters: 2),
    );

    final accepted = validator.validate(
      sequence: 1,
      source: ExternalTranslationSource.macosService,
      text: 'ab',
    );
    final rejected = validator.validate(
      sequence: 2,
      source: ExternalTranslationSource.macosService,
      text: 'abc',
    );

    expect(accepted, isA<AcceptedExternalTranslationRequest>());
    expect(rejected, isA<RejectedExternalTranslationRequest>());
    final rejection = rejected as RejectedExternalTranslationRequest;
    expect(rejection.reason, ExternalTranslationRejectionReason.textTooLong);
    expect(rejection.maxCharacters, 2);
    expect(rejection.userMessage, '所选文本过长，请缩短至 2 字符以内');
  });

  test('enforces the default 4999, 5000, and 5001 code point boundary', () {
    final validator = ExternalTranslationRequestValidator(
      ExternalTranslationConfig(),
    );
    String textOfLength(int length) => List.filled(length, 'x').join();

    final belowLimit = validator.validate(
      sequence: 1,
      source: ExternalTranslationSource.macosService,
      text: textOfLength(4999),
    );
    final atLimit = validator.validate(
      sequence: 2,
      source: ExternalTranslationSource.macosService,
      text: textOfLength(5000),
    );
    final overLimit = validator.validate(
      sequence: 3,
      source: ExternalTranslationSource.macosService,
      text: textOfLength(5001),
    );

    expect(belowLimit, isA<AcceptedExternalTranslationRequest>());
    expect(atLimit, isA<AcceptedExternalTranslationRequest>());
    expect(overLimit, isA<RejectedExternalTranslationRequest>());
    expect(
      (overLimit as RejectedExternalTranslationRequest).userMessage,
      '所选文本过长，请缩短至 5,000 字符以内',
    );
  });

  test('counts Unicode code points instead of UTF-16 code units', () {
    final validator = ExternalTranslationRequestValidator(
      ExternalTranslationConfig(maxCharacters: 2),
    );

    final supplementaryCharacters = validator.validate(
      sequence: 1,
      source: ExternalTranslationSource.macosService,
      text: '😀😀',
    );
    final combiningSequence = validator.validate(
      sequence: 2,
      source: ExternalTranslationSource.macosService,
      text: 'e\u0301',
    );

    expect(supplementaryCharacters, isA<AcceptedExternalTranslationRequest>());
    expect(combiningSequence, isA<AcceptedExternalTranslationRequest>());
  });
}
