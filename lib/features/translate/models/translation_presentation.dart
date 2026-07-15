class TranslationPresentation {
  static const int outputContractVersion = 2;

  final String primaryMeaning;
  final List<String> secondaryMeanings;

  const TranslationPresentation({
    required this.primaryMeaning,
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

    return TranslationPresentation(
      primaryMeaning: lines.first,
      secondaryMeanings: lines
          .skip(1)
          .map(_stripListMarker)
          .where((meaning) => meaning.isNotEmpty)
          .toList(growable: false),
    );
  }

  static String _stripListMarker(String line) =>
      line.replaceFirst(RegExp(r'^(?:[-*•·]\s*|\d+[.)、]\s*)'), '').trim();
}
