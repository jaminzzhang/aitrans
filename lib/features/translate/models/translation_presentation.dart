class TranslationPresentation {
  static const int outputContractVersion = 3;

  final String primaryMeaning;
  final String? partOfSpeech;
  final String? pronunciation;
  final List<String> secondaryMeanings;

  const TranslationPresentation({
    required this.primaryMeaning,
    this.partOfSpeech,
    this.pronunciation,
    required this.secondaryMeanings,
  });

  factory TranslationPresentation.parse(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const TranslationPresentation(
        primaryMeaning: '',
        secondaryMeanings: [],
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
}
