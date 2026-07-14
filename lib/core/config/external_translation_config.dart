/// Code-level limits for translation requests received from other apps.
final class ExternalTranslationConfig {
  static const int defaultMaxCharacters = 5000;

  final int maxCharacters;

  factory ExternalTranslationConfig({
    int maxCharacters = defaultMaxCharacters,
  }) {
    if (maxCharacters <= 0) {
      throw ArgumentError.value(
        maxCharacters,
        'maxCharacters',
        'must be greater than zero',
      );
    }
    return ExternalTranslationConfig._(maxCharacters);
  }

  const ExternalTranslationConfig._(this.maxCharacters);
}
