enum TranslationSourceLanguage {
  zh,
  en,
  ja,
  ko,
  fr,
  de,
  es,
  ru,
  pt,
  it,
  unknown;

  static TranslationSourceLanguage parse(String? value) {
    final normalized = value?.trim().toLowerCase();
    return values
            .where((language) => language.name == normalized)
            .firstOrNull ??
        unknown;
  }
}

enum TranslationSemanticClass {
  word,
  phrase,
  sentence,
  paragraph,
  unknown;

  static TranslationSemanticClass parse(String? value) {
    final normalized = value?.trim().toLowerCase();
    return values
            .where((semanticClass) => semanticClass.name == normalized)
            .firstOrNull ??
        unknown;
  }
}

class TranslationPresentation {
  static const int outputContractVersion = 5;
  static const int reviewClassificationContractVersion = 1;

  final String? correctedSource;
  final String adoptedSource;
  final TranslationSourceLanguage actualSourceLanguage;
  final int? reviewClassificationVersion;
  final TranslationSemanticClass semanticClass;
  final String translationText;
  final String primaryMeaning;
  final String? partOfSpeech;
  final String? pronunciation;
  final List<String> secondaryMeanings;

  const TranslationPresentation({
    this.correctedSource,
    this.adoptedSource = '',
    this.actualSourceLanguage = TranslationSourceLanguage.unknown,
    this.reviewClassificationVersion,
    this.semanticClass = TranslationSemanticClass.unknown,
    this.translationText = '',
    required this.primaryMeaning,
    this.partOfSpeech,
    this.pronunciation,
    required this.secondaryMeanings,
  });

  factory TranslationPresentation.parse(
    String text, {
    String originalSource = '',
  }) {
    final rawLines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    const correctionPrefix = 'CORRECTION:';
    final hasIncompleteCorrectionPrefix =
        !text.contains(RegExp(r'[\r\n]')) &&
        rawLines.length == 1 &&
        rawLines.first.length < correctionPrefix.length &&
        correctionPrefix.startsWith(rawLines.first.toUpperCase());
    if (hasIncompleteCorrectionPrefix) {
      return TranslationPresentation(
        adoptedSource: originalSource.trim(),
        primaryMeaning: '',
        secondaryMeanings: const [],
      );
    }

    String? correctedSource;
    var lines = rawLines;
    if (rawLines.isNotEmpty) {
      final correctionMatch = RegExp(
        r'^(?:CORRECTION|更正)\s*[:：]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(rawLines.first);
      if (correctionMatch != null) {
        final candidate = _metadataValue(correctionMatch.group(1));
        if (candidate != null &&
            originalSource.trim().isNotEmpty &&
            candidate != originalSource.trim() &&
            _preservesProtectedTokens(originalSource, candidate)) {
          correctedSource = candidate;
        }
        lines = rawLines.skip(1).toList();
      }
    }

    var actualSourceLanguage = TranslationSourceLanguage.unknown;
    int? reviewClassificationVersion;
    var declaredSemanticClass = TranslationSemanticClass.unknown;
    var sawSourceLanguage = false;
    var sawClassificationVersion = false;
    var sawSemanticClass = false;
    var reviewMetadataMalformed = false;
    final contentLines = <String>[];
    for (final line in lines) {
      final sourceLanguageMatch = RegExp(
        r'^SOURCE_LANGUAGE\s*:\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (sourceLanguageMatch != null) {
        if (sawSourceLanguage) reviewMetadataMalformed = true;
        sawSourceLanguage = true;
        final rawLanguage = sourceLanguageMatch.group(1)?.trim().toLowerCase();
        actualSourceLanguage = TranslationSourceLanguage.parse(rawLanguage);
        if (actualSourceLanguage == TranslationSourceLanguage.unknown &&
            rawLanguage != TranslationSourceLanguage.unknown.name) {
          reviewMetadataMalformed = true;
        }
        continue;
      }

      final classificationVersionMatch = RegExp(
        r'^REVIEW_CLASSIFICATION_VERSION\s*:\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (classificationVersionMatch != null) {
        if (sawClassificationVersion) reviewMetadataMalformed = true;
        sawClassificationVersion = true;
        reviewClassificationVersion = int.tryParse(
          classificationVersionMatch.group(1)?.trim() ?? '',
        );
        if (reviewClassificationVersion == null) {
          reviewMetadataMalformed = true;
        }
        continue;
      }

      final classificationMatch = RegExp(
        r'^REVIEW_CLASSIFICATION\s*:\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (classificationMatch != null) {
        if (sawSemanticClass) reviewMetadataMalformed = true;
        sawSemanticClass = true;
        final rawSemanticClass = classificationMatch
            .group(1)
            ?.trim()
            .toLowerCase();
        declaredSemanticClass = TranslationSemanticClass.parse(
          rawSemanticClass,
        );
        if (declaredSemanticClass == TranslationSemanticClass.unknown &&
            rawSemanticClass != TranslationSemanticClass.unknown.name) {
          reviewMetadataMalformed = true;
        }
        continue;
      }

      if (_isIncompleteReviewMetadataPrefix(line) ||
          _looksLikeMalformedReviewMetadata(line)) {
        reviewMetadataMalformed = true;
        continue;
      }

      contentLines.add(line);
    }
    lines = contentLines;

    final hasCurrentReviewMetadata =
        !reviewMetadataMalformed &&
        sawSourceLanguage &&
        sawClassificationVersion &&
        sawSemanticClass &&
        actualSourceLanguage != TranslationSourceLanguage.unknown &&
        reviewClassificationVersion == reviewClassificationContractVersion;
    final semanticClass = hasCurrentReviewMetadata
        ? declaredSemanticClass
        : TranslationSemanticClass.unknown;
    if (reviewMetadataMalformed) {
      actualSourceLanguage = TranslationSourceLanguage.unknown;
    }
    final adoptedSource = correctedSource ?? originalSource.trim();

    if (lines.isEmpty) {
      return TranslationPresentation(
        correctedSource: correctedSource,
        adoptedSource: adoptedSource,
        actualSourceLanguage: actualSourceLanguage,
        reviewClassificationVersion: reviewClassificationVersion,
        semanticClass: semanticClass,
        translationText: '',
        primaryMeaning: '',
        secondaryMeanings: const [],
      );
    }

    String? partOfSpeech;
    String? pronunciation;
    final secondaryMeanings = <String>[];
    for (final line in lines.skip(1)) {
      final partOfSpeechMatch = RegExp(
        r'^(?:POS|词性)\s*[:：]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (partOfSpeechMatch != null) {
        partOfSpeech = _metadataValue(partOfSpeechMatch.group(1));
        continue;
      }

      final pronunciationMatch = RegExp(
        r'^(?:PRON|读音|音标)\s*[:：]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (pronunciationMatch != null) {
        pronunciation = _metadataValue(pronunciationMatch.group(1));
        continue;
      }

      final meaning = _stripListMarker(line);
      if (meaning.isNotEmpty) secondaryMeanings.add(meaning);
    }

    return TranslationPresentation(
      correctedSource: correctedSource,
      adoptedSource: adoptedSource,
      actualSourceLanguage: actualSourceLanguage,
      reviewClassificationVersion: reviewClassificationVersion,
      semanticClass: semanticClass,
      translationText: lines.join('\n'),
      primaryMeaning: lines.first,
      partOfSpeech: partOfSpeech,
      pronunciation: pronunciation,
      secondaryMeanings: List.unmodifiable(secondaryMeanings),
    );
  }

  static String? _metadataValue(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty ||
        const {'-', 'null', 'n/a', '无'}.contains(value.toLowerCase())) {
      return null;
    }
    return value;
  }

  static String _stripListMarker(String line) =>
      line.replaceFirst(RegExp(r'^(?:[-*•·]\s*|\d+[.)、]\s*)'), '').trim();

  static bool _isIncompleteReviewMetadataPrefix(String line) {
    final value = line.trim().toUpperCase();
    if (!value.startsWith('SOURCE_') && !value.startsWith('REVIEW_')) {
      return false;
    }
    return const [
      'SOURCE_LANGUAGE:',
      'REVIEW_CLASSIFICATION_VERSION:',
      'REVIEW_CLASSIFICATION:',
    ].any((prefix) => value.length < prefix.length && prefix.startsWith(value));
  }

  static bool _looksLikeMalformedReviewMetadata(String line) {
    final value = line.trim().toUpperCase();
    return value.startsWith('SOURCE_LANGUAGE') ||
        value.startsWith('REVIEW_CLASSIFICATION');
  }

  static bool _preservesProtectedTokens(String original, String candidate) {
    final originalTokens = _protectedTokens(original)..sort();
    final candidateTokens = _protectedTokens(candidate)..sort();
    if (originalTokens.length != candidateTokens.length) return false;
    for (var index = 0; index < originalTokens.length; index++) {
      if (originalTokens[index] != candidateTokens[index]) return false;
    }
    return true;
  }

  static List<String> _protectedTokens(String text) {
    final pattern = RegExp(
      r'https?://[^\s]+|\b\d+(?:[.,]\d+)*\b|\b[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)+\b|\b[A-Za-z]+[A-Z][A-Za-z0-9]*\b',
    );
    return pattern.allMatches(text).map((match) => match.group(0)!).toList();
  }
}
