import '../domain/review_identity.dart';

class ReviewEntryContent {
  final String sourceText;
  final String translationText;
  final String primaryMeaning;
  final String? partOfSpeech;
  final String? pronunciation;
  final List<String> secondaryMeanings;

  factory ReviewEntryContent({
    required String sourceText,
    required String translationText,
    required String primaryMeaning,
    String? partOfSpeech,
    String? pronunciation,
    required Iterable<String> secondaryMeanings,
  }) {
    final normalizedSourceText = sourceText.trim();
    final normalizedTranslationText = translationText.trim();
    final normalizedPrimaryMeaning = primaryMeaning.trim();
    if (normalizedSourceText.isEmpty ||
        normalizedTranslationText.isEmpty ||
        normalizedPrimaryMeaning.isEmpty) {
      throw ArgumentError(
        'Review entry content requires source text and a translation.',
      );
    }

    return ReviewEntryContent._(
      sourceText: normalizedSourceText,
      translationText: normalizedTranslationText,
      primaryMeaning: normalizedPrimaryMeaning,
      partOfSpeech: _optionalText(partOfSpeech),
      pronunciation: _optionalText(pronunciation),
      secondaryMeanings: List.unmodifiable(
        secondaryMeanings
            .map((meaning) => meaning.trim())
            .where((meaning) => meaning.isNotEmpty),
      ),
    );
  }

  const ReviewEntryContent._({
    required this.sourceText,
    required this.translationText,
    required this.primaryMeaning,
    required this.partOfSpeech,
    required this.pronunciation,
    required this.secondaryMeanings,
  });

  static String? _optionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class ReviewEntry {
  final ReviewIdentity identity;
  final Set<String> aliases;
  final DateTime createdAt;
  final DateTime latestTranslatedAt;
  final int translationCount;
  final ReviewEntryContent latestContent;
  final int consecutiveRememberedCount;
  final int forgetCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final bool forcedDue;
  final int generation;
  final Set<String> appliedFeedbackEventIds;

  factory ReviewEntry({
    required ReviewIdentity identity,
    required Iterable<String> aliases,
    required DateTime createdAt,
    required DateTime latestTranslatedAt,
    required int translationCount,
    required ReviewEntryContent latestContent,
    int consecutiveRememberedCount = 0,
    int forgetCount = 0,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    bool forcedDue = false,
    int generation = 0,
    Iterable<String> appliedFeedbackEventIds = const [],
  }) {
    final aliasSnapshot = _aliasSnapshot(aliases);
    if (aliasSnapshot.isEmpty) {
      throw ArgumentError('At least one alias is required.');
    }
    final contentIdentity = ReviewIdentity.create(
      correctedTerm: latestContent.sourceText,
      actualSourceLanguage: identity.actualSourceLanguage,
      targetLanguage: identity.targetLanguage,
    );
    if (contentIdentity != identity) {
      throw ArgumentError('Latest content must belong to the review identity.');
    }
    if (createdAt.isAfter(latestTranslatedAt)) {
      throw ArgumentError.value(
        latestTranslatedAt,
        'latestTranslatedAt',
        'Latest translation cannot precede creation.',
      );
    }
    if (translationCount < 1 ||
        consecutiveRememberedCount < 0 ||
        forgetCount < 0 ||
        generation < 0) {
      throw ArgumentError(
        'Translation count must be positive and other counters non-negative.',
      );
    }
    final feedbackEventIds = _feedbackEventIdSnapshot(appliedFeedbackEventIds);

    return ReviewEntry._(
      identity: identity,
      aliases: aliasSnapshot,
      createdAt: createdAt,
      latestTranslatedAt: latestTranslatedAt,
      translationCount: translationCount,
      latestContent: latestContent,
      consecutiveRememberedCount: consecutiveRememberedCount,
      forgetCount: forgetCount,
      lastReviewedAt: lastReviewedAt,
      nextReviewAt: nextReviewAt,
      forcedDue: forcedDue,
      generation: generation,
      appliedFeedbackEventIds: feedbackEventIds,
    );
  }

  factory ReviewEntry.firstTranslation({
    required ReviewIdentity identity,
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
    int generation = 0,
  }) {
    return ReviewEntry(
      identity: identity,
      aliases: [originalAlias],
      createdAt: translatedAt,
      latestTranslatedAt: translatedAt,
      translationCount: 1,
      latestContent: content,
      generation: generation,
    );
  }

  const ReviewEntry._({
    required this.identity,
    required this.aliases,
    required this.createdAt,
    required this.latestTranslatedAt,
    required this.translationCount,
    required this.latestContent,
    required this.consecutiveRememberedCount,
    required this.forgetCount,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.forcedDue,
    required this.generation,
    required this.appliedFeedbackEventIds,
  });

  ReviewEntry recordTranslation({
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
  }) {
    final isLatest = !translatedAt.isBefore(latestTranslatedAt);
    return ReviewEntry(
      identity: identity,
      aliases: {...aliases, originalAlias},
      createdAt: createdAt,
      latestTranslatedAt: isLatest ? translatedAt : latestTranslatedAt,
      translationCount: translationCount + 1,
      latestContent: isLatest ? content : latestContent,
      consecutiveRememberedCount: consecutiveRememberedCount,
      forgetCount: forgetCount,
      lastReviewedAt: lastReviewedAt,
      nextReviewAt: nextReviewAt,
      forcedDue: forcedDue,
      generation: generation,
      appliedFeedbackEventIds: appliedFeedbackEventIds,
    );
  }

  static Set<String> _aliasSnapshot(Iterable<String> aliases) {
    return Set.unmodifiable(
      aliases.map((alias) => alias.trim()).where((alias) => alias.isNotEmpty),
    );
  }

  static Set<String> _feedbackEventIdSnapshot(Iterable<String> eventIds) {
    final normalized = eventIds.map((eventId) => eventId.trim()).toSet();
    if (normalized.any((eventId) => eventId.isEmpty)) {
      throw ArgumentError('Feedback event ids must not be empty.');
    }
    return Set.unmodifiable(normalized);
  }
}
