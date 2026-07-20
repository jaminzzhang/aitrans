// Flutter publicly re-exports the Unicode grapheme extension used here.
import 'package:flutter/widgets.dart' show StringCharacters;

import '../../translate/models/translation_presentation.dart';

enum ReviewEligibilityExclusionReason {
  emptySource,
  unsupportedClassificationVersion,
  unknownSourceLanguage,
  semanticClassNotReviewable,
  containsLineBreak,
  exceedsGraphemeLimit,
  multipleSentenceBoundaries,
}

class ReviewEligibilityResult {
  final bool isEligible;
  final ReviewEligibilityExclusionReason? exclusionReason;

  const ReviewEligibilityResult._({
    required this.isEligible,
    this.exclusionReason,
  });

  const ReviewEligibilityResult.eligible() : this._(isEligible: true);

  const ReviewEligibilityResult.excluded(
    ReviewEligibilityExclusionReason reason,
  ) : this._(isEligible: false, exclusionReason: reason);
}

abstract final class ReviewEligibility {
  static const int maxGraphemeCount = 80;

  static ReviewEligibilityResult evaluate({
    required String originalSource,
    required String adoptedSource,
    required TranslationSourceLanguage actualSourceLanguage,
    required TranslationSemanticClass semanticClass,
    required int? classificationVersion,
  }) {
    if (originalSource.trim().isEmpty || adoptedSource.trim().isEmpty) {
      return const ReviewEligibilityResult.excluded(
        ReviewEligibilityExclusionReason.emptySource,
      );
    }
    if (classificationVersion !=
        TranslationPresentation.reviewClassificationContractVersion) {
      return const ReviewEligibilityResult.excluded(
        ReviewEligibilityExclusionReason.unsupportedClassificationVersion,
      );
    }
    if (actualSourceLanguage == TranslationSourceLanguage.unknown) {
      return const ReviewEligibilityResult.excluded(
        ReviewEligibilityExclusionReason.unknownSourceLanguage,
      );
    }
    if (semanticClass != TranslationSemanticClass.word &&
        semanticClass != TranslationSemanticClass.phrase) {
      return const ReviewEligibilityResult.excluded(
        ReviewEligibilityExclusionReason.semanticClassNotReviewable,
      );
    }

    for (final text in {originalSource, adoptedSource}) {
      if (text.contains(RegExp(r'[\r\n]'))) {
        return const ReviewEligibilityResult.excluded(
          ReviewEligibilityExclusionReason.containsLineBreak,
        );
      }
      if (text.trim().characters.length > maxGraphemeCount) {
        return const ReviewEligibilityResult.excluded(
          ReviewEligibilityExclusionReason.exceedsGraphemeLimit,
        );
      }
      if (_sentenceBoundaryCount(text) > 1) {
        return const ReviewEligibilityResult.excluded(
          ReviewEligibilityExclusionReason.multipleSentenceBoundaries,
        );
      }
    }
    return const ReviewEligibilityResult.eligible();
  }

  static int _sentenceBoundaryCount(String text) {
    // Punctuation inside these lexical forms is not a sentence boundary.
    var masked = text.replaceAllMapped(
      RegExp(
        r'\b(?:e\.g|i\.e|mr|mrs|ms|dr|prof|sr|jr|vs|etc)\.',
        caseSensitive: false,
      ),
      (match) => match.group(0)!.replaceAll('.', ' '),
    );
    masked = masked.replaceAllMapped(
      RegExp(r'\b(?:[A-Za-z]\.){2,}'),
      (match) => match.group(0)!.replaceAll('.', ' '),
    );

    final characters = masked.split('');
    for (var index = 1; index < characters.length - 1; index++) {
      if (characters[index] == '.' &&
          _isAsciiDigit(characters[index - 1]) &&
          _isAsciiDigit(characters[index + 1])) {
        characters[index] = ' ';
      }
    }
    masked = characters.join();

    return RegExp(r'(?:[.!?…]+|[。！？]+)').allMatches(masked).length;
  }

  static bool _isAsciiDigit(String value) {
    final codeUnit = value.codeUnitAt(0);
    return codeUnit >= 0x30 && codeUnit <= 0x39;
  }
}
