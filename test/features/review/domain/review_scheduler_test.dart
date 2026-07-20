import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a new word becomes due at the exact 24 hour boundary', () {
    final createdAt = DateTime.utc(2026, 7, 19, 8);
    var now = createdAt.add(
      const Duration(hours: 23, minutes: 59, seconds: 59),
    );
    final scheduler = ReviewScheduler(now: () => now);
    final entry = _entry(createdAt: createdAt);

    expect(scheduler.dueAt(entry), createdAt.add(const Duration(hours: 24)));
    expect(scheduler.isDue(entry), isFalse);

    now = createdAt.add(const Duration(hours: 24));
    expect(scheduler.isDue(entry), isTrue);
  });

  test('forgotten feedback resets the streak and is due in 10 minutes', () {
    final now = DateTime.utc(2026, 7, 20, 9, 15);
    final scheduler = ReviewScheduler(now: () => now);
    final state = ReviewScheduleState(
      entry: _entry(
        createdAt: DateTime.utc(2026, 7, 18),
        consecutiveRememberedCount: 3,
        forgetCount: 2,
        forcedDue: true,
      ),
    );

    final updated = scheduler.applyFeedback(
      state: state,
      event: ReviewFeedbackEvent(
        id: 'feedback-forgotten-1',
        feedback: ReviewFeedback.forgotten,
      ),
    );

    expect(updated.entry.consecutiveRememberedCount, 0);
    expect(updated.entry.forgetCount, 3);
    expect(updated.entry.lastReviewedAt, now);
    expect(updated.entry.nextReviewAt, now.add(const Duration(minutes: 10)));
    expect(updated.entry.forcedDue, isFalse);
    expect(updated.appliedFeedbackEventIds, contains('feedback-forgotten-1'));
  });

  test('fuzzy feedback preserves counters and is due in one day', () {
    final now = DateTime.utc(2026, 7, 20, 10);
    final scheduler = ReviewScheduler(now: () => now);
    final state = ReviewScheduleState(
      entry: _entry(
        createdAt: DateTime.utc(2026, 7, 18),
        consecutiveRememberedCount: 2,
        forgetCount: 1,
        forcedDue: true,
      ),
    );

    final updated = scheduler.applyFeedback(
      state: state,
      event: ReviewFeedbackEvent(
        id: 'feedback-fuzzy-1',
        feedback: ReviewFeedback.fuzzy,
      ),
    );

    expect(updated.entry.consecutiveRememberedCount, 2);
    expect(updated.entry.forgetCount, 1);
    expect(updated.entry.lastReviewedAt, now);
    expect(updated.entry.nextReviewAt, now.add(const Duration(days: 1)));
    expect(updated.entry.forcedDue, isFalse);
  });

  test(
    'remembered feedback follows the interval ladder and caps at 90 days',
    () {
      final now = DateTime.utc(2026, 7, 20, 11);
      final scheduler = ReviewScheduler(now: () => now);
      final cases = <({int previousStreak, int expectedDays})>[
        (previousStreak: 0, expectedDays: 3),
        (previousStreak: 1, expectedDays: 7),
        (previousStreak: 2, expectedDays: 14),
        (previousStreak: 3, expectedDays: 30),
        (previousStreak: 4, expectedDays: 60),
        (previousStreak: 5, expectedDays: 90),
        (previousStreak: 6, expectedDays: 90),
      ];

      for (final testCase in cases) {
        final state = ReviewScheduleState(
          entry: _entry(
            createdAt: DateTime.utc(2026, 7, 18),
            consecutiveRememberedCount: testCase.previousStreak,
            forgetCount: 2,
            forcedDue: true,
          ),
        );

        final updated = scheduler.applyFeedback(
          state: state,
          event: ReviewFeedbackEvent(
            id: 'feedback-remembered-${testCase.previousStreak}',
            feedback: ReviewFeedback.remembered,
          ),
        );

        expect(
          updated.entry.consecutiveRememberedCount,
          testCase.previousStreak + 1,
        );
        expect(updated.entry.forgetCount, 2);
        expect(
          updated.entry.nextReviewAt,
          now.add(Duration(days: testCase.expectedDays)),
        );
        expect(updated.entry.forcedDue, isFalse);
      }
    },
  );

  test('the same feedback event id is applied only once', () {
    final now = DateTime.utc(2026, 7, 20, 12);
    final scheduler = ReviewScheduler(now: () => now);
    final initial = ReviewScheduleState(
      entry: _entry(
        createdAt: DateTime.utc(2026, 7, 18),
        consecutiveRememberedCount: 1,
        forgetCount: 1,
      ),
    );
    final event = ReviewFeedbackEvent(
      id: 'feedback-idempotent-1',
      feedback: ReviewFeedback.remembered,
    );

    final first = scheduler.applyFeedback(state: initial, event: event);
    final duplicate = scheduler.applyFeedback(state: first, event: event);

    expect(duplicate, same(first));
    expect(duplicate.entry.consecutiveRememberedCount, 2);
    expect(duplicate.entry.forgetCount, 1);
    expect(duplicate.appliedFeedbackEventIds, {'feedback-idempotent-1'});
  });

  test(
    'schedule state restores the feedback ledger from the entry by default',
    () {
      final scheduler = ReviewScheduler(
        now: () => DateTime.utc(2026, 7, 20, 12),
      );
      final entry = _entry(
        createdAt: DateTime.utc(2026, 7, 18),
        forgetCount: 1,
        appliedFeedbackEventIds: const {'feedback-restored-default'},
      );
      final state = ReviewScheduleState(entry: entry);

      final duplicate = scheduler.applyFeedback(
        state: state,
        event: ReviewFeedbackEvent(
          id: 'feedback-restored-default',
          feedback: ReviewFeedback.forgotten,
        ),
      );

      expect(duplicate, same(state));
      expect(duplicate.entry.forgetCount, 1);
    },
  );

  test('retranslation makes an entry due without resetting progress', () {
    final now = DateTime.utc(2026, 7, 20, 13);
    final lastReviewedAt = DateTime.utc(2026, 7, 19, 13);
    final nextReviewAt = DateTime.utc(2026, 7, 26, 13);
    final scheduler = ReviewScheduler(now: () => now);
    final state = ReviewScheduleState(
      entry: _entry(
        createdAt: DateTime.utc(2026, 7, 10),
        consecutiveRememberedCount: 2,
        forgetCount: 3,
        lastReviewedAt: lastReviewedAt,
        nextReviewAt: nextReviewAt,
      ),
      appliedFeedbackEventIds: const {'feedback-before-retranslation'},
    );
    expect(scheduler.isDue(state.entry), isFalse);

    final updated = scheduler.markRetranslated(state);

    expect(updated.entry.forcedDue, isTrue);
    expect(scheduler.isDue(updated.entry), isTrue);
    expect(updated.entry.consecutiveRememberedCount, 2);
    expect(updated.entry.forgetCount, 3);
    expect(updated.entry.lastReviewedAt, lastReviewedAt);
    expect(updated.entry.nextReviewAt, nextReviewAt);
    expect(updated.appliedFeedbackEventIds, {'feedback-before-retranslation'});
  });

  test(
    'a system clock rollback cannot move committed review time backward',
    () {
      final committedAt = DateTime.utc(2026, 7, 20, 14);
      final rolledBackNow = DateTime.utc(2026, 7, 20, 13);
      final scheduler = ReviewScheduler(now: () => rolledBackNow);
      final state = ReviewScheduleState(
        entry: _entry(
          createdAt: DateTime.utc(2026, 7, 10),
          consecutiveRememberedCount: 2,
          lastReviewedAt: committedAt,
          nextReviewAt: committedAt.add(const Duration(days: 7)),
        ),
      );

      final updated = scheduler.applyFeedback(
        state: state,
        event: ReviewFeedbackEvent(
          id: 'feedback-after-clock-rollback',
          feedback: ReviewFeedback.forgotten,
        ),
      );

      expect(updated.entry.lastReviewedAt, committedAt);
      expect(
        updated.entry.nextReviewAt,
        committedAt.add(const Duration(minutes: 10)),
      );
      expect(updated.entry.forgetCount, 1);
    },
  );

  test('restored feedback event ids are normalized immutable snapshots', () {
    final ids = <String>{' feedback-restored-1 '};
    final state = ReviewScheduleState(
      entry: _entry(createdAt: DateTime.utc(2026, 7, 19)),
      appliedFeedbackEventIds: ids,
    );
    ids.add('feedback-late-mutation');

    expect(state.appliedFeedbackEventIds, {'feedback-restored-1'});
    expect(
      () => ReviewScheduleState(
        entry: state.entry,
        appliedFeedbackEventIds: const {'   '},
      ),
      throwsArgumentError,
    );
  });

  test('schedule instants are normalized to UTC', () {
    final localCreatedAt = DateTime(2026, 7, 19, 8);
    final localNow = localCreatedAt.add(const Duration(hours: 24));
    final scheduler = ReviewScheduler(now: () => localNow);
    final entry = _entry(createdAt: localCreatedAt);

    expect(scheduler.dueAt(entry).isUtc, isTrue);
    final updated = scheduler.applyFeedback(
      state: ReviewScheduleState(entry: entry),
      event: ReviewFeedbackEvent(
        id: 'feedback-utc-1',
        feedback: ReviewFeedback.fuzzy,
      ),
    );

    expect(updated.entry.lastReviewedAt, localNow.toUtc());
    expect(updated.entry.lastReviewedAt?.isUtc, isTrue);
    expect(updated.entry.nextReviewAt?.isUtc, isTrue);
  });

  test('feedback events reject an empty id', () {
    expect(
      () => ReviewFeedbackEvent(id: '  ', feedback: ReviewFeedback.remembered),
      throwsArgumentError,
    );
  });
}

ReviewEntry _entry({
  required DateTime createdAt,
  int consecutiveRememberedCount = 0,
  int forgetCount = 0,
  DateTime? lastReviewedAt,
  DateTime? nextReviewAt,
  bool forcedDue = false,
  Iterable<String> appliedFeedbackEventIds = const [],
}) {
  final identity = ReviewIdentity.create(
    correctedTerm: 'otter',
    actualSourceLanguage: TranslationSourceLanguage.en,
    targetLanguage: TranslationSourceLanguage.zh,
  );
  return ReviewEntry(
    identity: identity,
    aliases: const {'otter'},
    createdAt: createdAt,
    latestTranslatedAt: createdAt,
    translationCount: 1,
    latestContent: ReviewEntryContent(
      sourceText: 'otter',
      translationText: '水獭',
      primaryMeaning: '水獭',
      secondaryMeanings: const [],
    ),
    consecutiveRememberedCount: consecutiveRememberedCount,
    forgetCount: forgetCount,
    lastReviewedAt: lastReviewedAt,
    nextReviewAt: nextReviewAt,
    forcedDue: forcedDue,
    appliedFeedbackEventIds: appliedFeedbackEventIds,
  );
}
