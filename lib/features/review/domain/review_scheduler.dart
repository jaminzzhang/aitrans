import '../models/review_entry.dart';
import 'review_feedback.dart';

class ReviewScheduleState {
  factory ReviewScheduleState({
    required ReviewEntry entry,
    Iterable<String>? appliedFeedbackEventIds,
  }) {
    final normalizedIds =
        (appliedFeedbackEventIds ?? entry.appliedFeedbackEventIds)
            .map((eventId) => eventId.trim())
            .toSet();
    if (normalizedIds.any((eventId) => eventId.isEmpty)) {
      throw ArgumentError('Feedback event ids must not be empty.');
    }
    return ReviewScheduleState._(
      entry: entry,
      appliedFeedbackEventIds: Set.unmodifiable(normalizedIds),
    );
  }

  const ReviewScheduleState._({
    required this.entry,
    required this.appliedFeedbackEventIds,
  });

  final ReviewEntry entry;
  final Set<String> appliedFeedbackEventIds;
}

class ReviewScheduler {
  ReviewScheduler({required DateTime Function() now}) : _now = now;

  static const initialReviewDelay = Duration(hours: 24);
  static const rememberedIntervals = <Duration>[
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 14),
    Duration(days: 30),
    Duration(days: 60),
    Duration(days: 90),
  ];

  final DateTime Function() _now;

  DateTime dueAt(ReviewEntry entry) {
    return (entry.nextReviewAt ?? entry.createdAt.add(initialReviewDelay))
        .toUtc();
  }

  bool isDue(ReviewEntry entry) {
    if (entry.forcedDue) return true;
    return !_now().toUtc().isBefore(dueAt(entry));
  }

  ReviewScheduleState markRetranslated(ReviewScheduleState state) {
    if (state.entry.forcedDue) return state;
    final entry = state.entry;
    return ReviewScheduleState(
      entry: _withSchedule(
        entry,
        consecutiveRememberedCount: entry.consecutiveRememberedCount,
        forgetCount: entry.forgetCount,
        lastReviewedAt: entry.lastReviewedAt,
        nextReviewAt: entry.nextReviewAt,
        forcedDue: true,
        appliedFeedbackEventIds: state.appliedFeedbackEventIds,
      ),
      appliedFeedbackEventIds: state.appliedFeedbackEventIds,
    );
  }

  ReviewScheduleState applyFeedback({
    required ReviewScheduleState state,
    required ReviewFeedbackEvent event,
  }) {
    if (state.appliedFeedbackEventIds.contains(event.id)) return state;

    final entry = state.entry;
    final reviewedAt = _effectiveReviewTime(entry);
    late final int consecutiveRememberedCount;
    late final int forgetCount;
    late final Duration delay;
    switch (event.feedback) {
      case ReviewFeedback.forgotten:
        consecutiveRememberedCount = 0;
        forgetCount = entry.forgetCount + 1;
        delay = const Duration(minutes: 10);
        break;
      case ReviewFeedback.fuzzy:
        consecutiveRememberedCount = entry.consecutiveRememberedCount;
        forgetCount = entry.forgetCount;
        delay = const Duration(days: 1);
        break;
      case ReviewFeedback.remembered:
        consecutiveRememberedCount = entry.consecutiveRememberedCount + 1;
        forgetCount = entry.forgetCount;
        final intervalIndex =
            consecutiveRememberedCount <= rememberedIntervals.length
            ? consecutiveRememberedCount - 1
            : rememberedIntervals.length - 1;
        delay = rememberedIntervals[intervalIndex];
        break;
    }
    final updatedEntry = _withSchedule(
      entry,
      consecutiveRememberedCount: consecutiveRememberedCount,
      forgetCount: forgetCount,
      lastReviewedAt: reviewedAt,
      nextReviewAt: reviewedAt.add(delay),
      forcedDue: false,
      appliedFeedbackEventIds: {...state.appliedFeedbackEventIds, event.id},
    );
    return ReviewScheduleState(
      entry: updatedEntry,
      appliedFeedbackEventIds: {...state.appliedFeedbackEventIds, event.id},
    );
  }

  DateTime _effectiveReviewTime(ReviewEntry entry) {
    // A clock rollback must not make a committed review or the translation
    // that produced this entry appear to happen in the future.
    var effective = _now().toUtc();
    final latestTranslation = entry.latestTranslatedAt.toUtc();
    if (effective.isBefore(latestTranslation)) effective = latestTranslation;
    final lastReview = entry.lastReviewedAt?.toUtc();
    if (lastReview != null && effective.isBefore(lastReview)) {
      effective = lastReview;
    }
    return effective;
  }

  ReviewEntry _withSchedule(
    ReviewEntry entry, {
    required int consecutiveRememberedCount,
    required int forgetCount,
    required DateTime? lastReviewedAt,
    required DateTime? nextReviewAt,
    required bool forcedDue,
    required Iterable<String> appliedFeedbackEventIds,
  }) {
    return ReviewEntry(
      identity: entry.identity,
      aliases: entry.aliases,
      createdAt: entry.createdAt,
      latestTranslatedAt: entry.latestTranslatedAt,
      translationCount: entry.translationCount,
      latestContent: entry.latestContent,
      consecutiveRememberedCount: consecutiveRememberedCount,
      forgetCount: forgetCount,
      lastReviewedAt: lastReviewedAt,
      nextReviewAt: nextReviewAt,
      forcedDue: forcedDue,
      generation: entry.generation,
      appliedFeedbackEventIds: appliedFeedbackEventIds,
    );
  }
}
