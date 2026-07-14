import '../config/external_translation_config.dart';

enum ExternalTranslationSource { macosService }

final class ExternalTranslationRequest {
  final int sequence;
  final ExternalTranslationSource source;
  final String text;

  const ExternalTranslationRequest._({
    required this.sequence,
    required this.source,
    required this.text,
  });
}

sealed class ExternalTranslationValidationResult {
  const ExternalTranslationValidationResult();
}

final class AcceptedExternalTranslationRequest
    extends ExternalTranslationValidationResult {
  final ExternalTranslationRequest request;

  const AcceptedExternalTranslationRequest._(this.request);
}

enum ExternalTranslationRejectionReason {
  invalidSequence,
  emptyText,
  textTooLong,
}

final class RejectedExternalTranslationRequest
    extends ExternalTranslationValidationResult {
  final ExternalTranslationRejectionReason reason;
  final int? maxCharacters;
  final String? userMessage;

  const RejectedExternalTranslationRequest._({
    required this.reason,
    this.maxCharacters,
    this.userMessage,
  });
}

final class ExternalTranslationRequestValidator {
  final ExternalTranslationConfig config;

  const ExternalTranslationRequestValidator(this.config);

  ExternalTranslationValidationResult validate({
    required int sequence,
    required ExternalTranslationSource source,
    required String text,
  }) {
    if (sequence <= 0) {
      return const RejectedExternalTranslationRequest._(
        reason: ExternalTranslationRejectionReason.invalidSequence,
      );
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return const RejectedExternalTranslationRequest._(
        reason: ExternalTranslationRejectionReason.emptyText,
      );
    }

    if (_exceedsCodePointLimit(trimmedText, config.maxCharacters)) {
      return RejectedExternalTranslationRequest._(
        reason: ExternalTranslationRejectionReason.textTooLong,
        maxCharacters: config.maxCharacters,
        userMessage: '所选文本过长，请缩短至 ${_formatCount(config.maxCharacters)} 字符以内',
      );
    }

    return AcceptedExternalTranslationRequest._(
      ExternalTranslationRequest._(
        sequence: sequence,
        source: source,
        text: trimmedText,
      ),
    );
  }
}

bool _exceedsCodePointLimit(String text, int limit) {
  var count = 0;
  for (final _ in text.runes) {
    count++;
    if (count > limit) return true;
  }
  return false;
}

String _formatCount(int value) {
  final digits = value.toString();
  final formatted = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      formatted.write(',');
    }
    formatted.write(digits[index]);
  }
  return formatted.toString();
}
