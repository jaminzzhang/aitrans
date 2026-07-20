import 'package:hive/hive.dart';

class ReviewPreferences {
  const ReviewPreferences({
    required this.captureEnabled,
    required this.privacyNoticeAcknowledged,
  });

  static const defaults = ReviewPreferences(
    captureEnabled: true,
    privacyNoticeAcknowledged: false,
  );

  final bool captureEnabled;
  final bool privacyNoticeAcknowledged;

  ReviewPreferences copyWith({
    bool? captureEnabled,
    bool? privacyNoticeAcknowledged,
  }) {
    return ReviewPreferences(
      captureEnabled: captureEnabled ?? this.captureEnabled,
      privacyNoticeAcknowledged:
          privacyNoticeAcknowledged ?? this.privacyNoticeAcknowledged,
    );
  }
}

class ReviewPreferencesUnavailableException implements Exception {
  const ReviewPreferencesUnavailableException();

  @override
  String toString() => 'ReviewPreferencesUnavailableException';
}

abstract interface class ReviewPreferencesStore {
  Future<ReviewPreferences> load();

  Future<void> save(ReviewPreferences preferences);
}

class UnavailableReviewPreferencesStore implements ReviewPreferencesStore {
  const UnavailableReviewPreferencesStore();

  Future<T> _unavailable<T>() {
    return Future<T>.error(const ReviewPreferencesUnavailableException());
  }

  @override
  Future<ReviewPreferences> load() => _unavailable();

  @override
  Future<void> save(ReviewPreferences preferences) => _unavailable();
}

class MemoryReviewPreferencesStore implements ReviewPreferencesStore {
  MemoryReviewPreferencesStore([
    ReviewPreferences initial = ReviewPreferences.defaults,
  ]) : _preferences = initial;

  ReviewPreferences _preferences;

  @override
  Future<ReviewPreferences> load() async => _preferences;

  @override
  Future<void> save(ReviewPreferences preferences) async {
    _preferences = preferences;
  }
}

class HiveReviewPreferencesStore implements ReviewPreferencesStore {
  HiveReviewPreferencesStore(this._box);

  static const preferencesKey = 'review_preferences';
  static const _schemaVersion = 1;

  final Box<dynamic> _box;

  @override
  Future<ReviewPreferences> load() async {
    Object? value;
    try {
      value = _box.get(preferencesKey);
    } on Object {
      throw const ReviewPreferencesUnavailableException();
    }
    if (value == null) return ReviewPreferences.defaults;
    if (value is! Map ||
        value['schemaVersion'] != _schemaVersion ||
        value['captureEnabled'] is! bool ||
        value['privacyNoticeAcknowledged'] is! bool) {
      throw const ReviewPreferencesUnavailableException();
    }
    return ReviewPreferences(
      captureEnabled: value['captureEnabled'] as bool,
      privacyNoticeAcknowledged: value['privacyNoticeAcknowledged'] as bool,
    );
  }

  @override
  Future<void> save(ReviewPreferences preferences) async {
    try {
      await _box.put(preferencesKey, <String, Object>{
        'schemaVersion': _schemaVersion,
        'captureEnabled': preferences.captureEnabled,
        'privacyNoticeAcknowledged': preferences.privacyNoticeAcknowledged,
      });
    } on Object {
      throw const ReviewPreferencesUnavailableException();
    }
  }
}
