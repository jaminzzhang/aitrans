class TranslationPresentation {
  static const int outputContractVersion = 4;

  final String? correctedSource;
  final String adoptedSource;
  final String translationText;
  final String primaryMeaning;
  final String? partOfSpeech;
  final String? pronunciation;
  final List<String> secondaryMeanings;

  const TranslationPresentation({
    this.correctedSource,
    this.adoptedSource = '',
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

    final adoptedSource = correctedSource ?? originalSource.trim();

    if (lines.isEmpty) {
      return TranslationPresentation(
        correctedSource: correctedSource,
        adoptedSource: adoptedSource,
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
