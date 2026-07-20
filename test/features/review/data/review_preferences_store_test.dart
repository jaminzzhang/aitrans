import 'dart:io';

import 'package:aitrans/features/review/data/review_preferences_store.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'aitrans-review-preferences-',
    );
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('review_preferences');
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('persists capture and privacy choices across store instances', () async {
    final first = HiveReviewPreferencesStore(box);
    expect((await first.load()).captureEnabled, isTrue);
    expect((await first.load()).privacyNoticeAcknowledged, isFalse);

    await first.save(
      const ReviewPreferences(
        captureEnabled: false,
        privacyNoticeAcknowledged: true,
      ),
    );

    final reopened = HiveReviewPreferencesStore(box);
    final restored = await reopened.load();
    expect(restored.captureEnabled, isFalse);
    expect(restored.privacyNoticeAcknowledged, isTrue);
  });

  test(
    'rejects malformed preferences instead of silently enabling capture',
    () async {
      await box.put(HiveReviewPreferencesStore.preferencesKey, {
        'schemaVersion': 1,
        'captureEnabled': 'not-a-boolean',
        'privacyNoticeAcknowledged': true,
      });

      await expectLater(
        HiveReviewPreferencesStore(box).load,
        throwsA(isA<ReviewPreferencesUnavailableException>()),
      );
    },
  );
}
