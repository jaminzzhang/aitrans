import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/review_repository.dart';
import '../data/review_preferences_store.dart';
import '../domain/review_identity.dart';
import '../domain/review_feedback.dart';
import '../domain/review_scheduler.dart';
import '../models/review_entry.dart';
import '../services/review_content_service.dart';
import '../services/review_image_service.dart';
import 'review_queue_controller.dart';

enum ReviewHistoryStatus { loading, ready, unavailable }

class ReviewHistoryState {
  ReviewHistoryState({
    required this.status,
    Iterable<ReviewEntry> entries = const [],
    this.dueCount = 0,
    this.group,
    this.isLoadingGroup = false,
    this.captureEnabled = false,
    this.privacyNoticeAcknowledged = false,
    this.preferencesAvailable = true,
    this.groupCompleted = false,
  }) : entries = List.unmodifiable(entries);

  factory ReviewHistoryState.loading() {
    return ReviewHistoryState(status: ReviewHistoryStatus.loading);
  }

  final ReviewHistoryStatus status;
  final List<ReviewEntry> entries;
  final int dueCount;
  final ReviewQueueSnapshot? group;
  final bool isLoadingGroup;
  final bool captureEnabled;
  final bool privacyNoticeAcknowledged;
  final bool preferencesAvailable;
  final bool groupCompleted;

  ReviewHistoryState copyWith({
    ReviewHistoryStatus? status,
    Iterable<ReviewEntry>? entries,
    int? dueCount,
    ReviewQueueSnapshot? group,
    bool? isLoadingGroup,
    bool? captureEnabled,
    bool? privacyNoticeAcknowledged,
    bool? preferencesAvailable,
    bool? groupCompleted,
  }) {
    return ReviewHistoryState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      dueCount: dueCount ?? this.dueCount,
      group: group ?? this.group,
      isLoadingGroup: isLoadingGroup ?? this.isLoadingGroup,
      captureEnabled: captureEnabled ?? this.captureEnabled,
      privacyNoticeAcknowledged:
          privacyNoticeAcknowledged ?? this.privacyNoticeAcknowledged,
      preferencesAvailable: preferencesAvailable ?? this.preferencesAvailable,
      groupCompleted: groupCompleted ?? this.groupCompleted,
    );
  }
}

class ReviewHistoryController extends StateNotifier<ReviewHistoryState> {
  ReviewHistoryController({
    required ReviewRepository repository,
    required ReviewScheduler scheduler,
    required ReviewQueueController queueController,
    required ReviewContentService contentService,
    ReviewImageService? imageService,
    required ReviewPreferencesStore preferencesStore,
    required void Function(bool enabled) onCaptureEnabledChanged,
  }) : _repository = repository,
       _scheduler = scheduler,
       _queueController = queueController,
       _contentService = contentService,
       _imageService = imageService,
       _preferencesStore = preferencesStore,
       _onCaptureEnabledChanged = onCaptureEnabledChanged,
       super(ReviewHistoryState.loading()) {
    _initialize();
  }

  final ReviewRepository _repository;
  final ReviewScheduler _scheduler;
  final ReviewQueueController _queueController;
  final ReviewContentService _contentService;
  final ReviewImageService? _imageService;
  final ReviewPreferencesStore _preferencesStore;
  final void Function(bool enabled) _onCaptureEnabledChanged;
  int _reloadGeneration = 0;
  int _groupGeneration = 0;

  Future<void> _initialize() async {
    try {
      final preferences = await _preferencesStore.load();
      if (!mounted) return;
      _onCaptureEnabledChanged(preferences.captureEnabled);
      state = state.copyWith(
        captureEnabled: preferences.captureEnabled,
        privacyNoticeAcknowledged: preferences.privacyNoticeAcknowledged,
      );
    } on Object {
      if (!mounted) return;
      _onCaptureEnabledChanged(false);
      state = state.copyWith(
        captureEnabled: false,
        preferencesAvailable: false,
      );
    }
    await reload();
  }

  Future<void> reload({bool preserveGroup = true}) async {
    final generation = ++_reloadGeneration;
    final retainedGroup = preserveGroup ? state.group : null;
    if (_repository.state == ReviewRepositoryState.unavailable) {
      _onCaptureEnabledChanged(false);
      state = ReviewHistoryState(
        status: ReviewHistoryStatus.unavailable,
        captureEnabled: false,
        privacyNoticeAcknowledged: state.privacyNoticeAcknowledged,
        preferencesAvailable: state.preferencesAvailable,
      );
      return;
    }
    try {
      final entries = await _repository.all();
      if (!mounted || generation != _reloadGeneration) return;
      final sorted = entries.toList()
        ..sort((left, right) {
          final byLatest = right.latestTranslatedAt.compareTo(
            left.latestTranslatedAt,
          );
          if (byLatest != 0) return byLatest;
          return left.identity.normalizedTerm.compareTo(
            right.identity.normalizedTerm,
          );
        });
      state = ReviewHistoryState(
        status: ReviewHistoryStatus.ready,
        entries: sorted,
        dueCount: sorted.where(_scheduler.isDue).length,
        group: retainedGroup,
        captureEnabled: state.captureEnabled,
        privacyNoticeAcknowledged: state.privacyNoticeAcknowledged,
        preferencesAvailable: state.preferencesAvailable,
      );
    } on Object {
      if (!mounted || generation != _reloadGeneration) return;
      _onCaptureEnabledChanged(false);
      state = ReviewHistoryState(
        status: ReviewHistoryStatus.unavailable,
        entries: state.entries,
        captureEnabled: false,
        privacyNoticeAcknowledged: state.privacyNoticeAcknowledged,
        preferencesAvailable: state.preferencesAvailable,
      );
    }
  }

  Future<void> loadTodayGroup() async {
    if (_repository.state == ReviewRepositoryState.unavailable) return;
    final generation = ++_groupGeneration;
    state = state.copyWith(isLoadingGroup: true);
    try {
      final group = await _queueController.buildGroup();
      if (!mounted || generation != _groupGeneration) return;
      state = state.copyWith(
        group: group,
        isLoadingGroup: false,
        groupCompleted: false,
      );
    } on Object {
      if (!mounted || generation != _groupGeneration) return;
      state = ReviewHistoryState(
        status: ReviewHistoryStatus.unavailable,
        entries: state.entries,
      );
    }
  }

  Future<bool> acknowledgePrivacy({bool disableCapture = false}) async {
    final updated = ReviewPreferences(
      captureEnabled: disableCapture ? false : state.captureEnabled,
      privacyNoticeAcknowledged: true,
    );
    try {
      await _preferencesStore.save(updated);
      if (!mounted) return false;
      _onCaptureEnabledChanged(updated.captureEnabled);
      state = state.copyWith(
        captureEnabled: updated.captureEnabled,
        privacyNoticeAcknowledged: true,
      );
      return true;
    } on Object {
      if (!mounted) return false;
      _onCaptureEnabledChanged(false);
      state = state.copyWith(
        captureEnabled: false,
        preferencesAvailable: false,
      );
      return false;
    }
  }

  Future<bool> setCaptureEnabled(bool enabled) async {
    if (!state.preferencesAvailable ||
        (enabled && _repository.state == ReviewRepositoryState.unavailable)) {
      _onCaptureEnabledChanged(false);
      state = state.copyWith(captureEnabled: false);
      return false;
    }
    final updated = ReviewPreferences(
      captureEnabled: enabled,
      privacyNoticeAcknowledged: state.privacyNoticeAcknowledged,
    );
    try {
      await _preferencesStore.save(updated);
      if (!mounted) return false;
      _onCaptureEnabledChanged(enabled);
      state = state.copyWith(captureEnabled: enabled);
      return true;
    } on Object {
      if (!mounted) return false;
      _onCaptureEnabledChanged(false);
      state = state.copyWith(
        captureEnabled: false,
        preferencesAvailable: false,
      );
      return false;
    }
  }

  Future<bool> deleteEntry(ReviewIdentity identity) async {
    if (_repository.state == ReviewRepositoryState.unavailable) return false;
    await _queueController.invalidate();
    await _contentService.invalidate();
    await _imageService?.invalidate();
    try {
      await _repository.delete(identity);
      await reload(preserveGroup: false);
      return state.status == ReviewHistoryStatus.ready;
    } on Object {
      await reload(preserveGroup: false);
      return false;
    }
  }

  Future<bool> clearHistory() async {
    await _queueController.invalidate();
    await _contentService.invalidate();
    await _imageService?.invalidate();
    try {
      await _repository.clearAndReset();
      await reload(preserveGroup: false);
      return _repository.state == ReviewRepositoryState.ready &&
          state.status == ReviewHistoryStatus.ready;
    } on Object {
      await reload(preserveGroup: false);
      return false;
    }
  }

  Future<bool> secureRebuild() async {
    await _queueController.invalidate();
    await _contentService.invalidate();
    await _imageService?.invalidate();
    try {
      await _repository.clearAndReset();
      if (_repository.state != ReviewRepositoryState.ready) {
        _onCaptureEnabledChanged(false);
        state = state.copyWith(captureEnabled: false);
        return false;
      }
      final preferences = await _preferencesStore.load();
      if (!mounted) return false;
      _onCaptureEnabledChanged(preferences.captureEnabled);
      state = state.copyWith(
        captureEnabled: preferences.captureEnabled,
        privacyNoticeAcknowledged: preferences.privacyNoticeAcknowledged,
        preferencesAvailable: true,
      );
      await reload(preserveGroup: false);
      return state.status == ReviewHistoryStatus.ready;
    } on Object {
      if (!mounted) return false;
      _onCaptureEnabledChanged(false);
      state = ReviewHistoryState(
        status: ReviewHistoryStatus.unavailable,
        entries: state.entries,
        captureEnabled: false,
        privacyNoticeAcknowledged: state.privacyNoticeAcknowledged,
        preferencesAvailable: state.preferencesAvailable,
      );
      return false;
    }
  }

  Future<bool> submitFeedback(
    ReviewEntry entry,
    ReviewFeedback feedback, {
    String? eventId,
  }) async {
    if (_repository.state == ReviewRepositoryState.unavailable) return false;
    final normalizedEventId = eventId?.trim();
    if (normalizedEventId != null && normalizedEventId.isEmpty) return false;
    final feedbackEvent = ReviewFeedbackEvent(
      id: normalizedEventId ?? _nextFeedbackEventId(),
      feedback: feedback,
    );
    await _queueController.invalidate();
    try {
      final updated = await _repository.applyFeedback(
        identity: entry.identity,
        event: feedbackEvent,
        scheduler: _scheduler,
      );
      if (!mounted || updated == null) return false;
      final updatedEntries = state.entries
          .map(
            (candidate) =>
                candidate.identity == updated.identity ? updated : candidate,
          )
          .toList();
      final currentGroup = state.group;
      ReviewQueueSnapshot? nextGroup = currentGroup;
      var completed = false;
      if (currentGroup != null) {
        final remaining = currentGroup.items
            .where((item) => item.entry.identity != updated.identity)
            .toList();
        completed = currentGroup.items.isNotEmpty && remaining.isEmpty;
        nextGroup = ReviewQueueSnapshot(
          items: remaining,
          totalDueCount: currentGroup.totalDueCount > 0
              ? currentGroup.totalDueCount - 1
              : 0,
          candidateCount: currentGroup.candidateCount,
          source: currentGroup.source,
        );
      }
      state = state.copyWith(
        entries: updatedEntries,
        dueCount: updatedEntries.where(_scheduler.isDue).length,
        group: nextGroup,
        groupCompleted: completed,
      );
      return true;
    } on Object {
      return false;
    }
  }

  int _feedbackEventSequence = 0;

  String _nextFeedbackEventId() {
    _feedbackEventSequence++;
    return 'review-feedback-${DateTime.now().toUtc().microsecondsSinceEpoch}'
        '-$_feedbackEventSequence';
  }
}
