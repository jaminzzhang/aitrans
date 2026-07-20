import 'package:hive/hive.dart';

import 'review_repository.dart';

class HiveReviewCiphertextStore implements ReviewCiphertextStore {
  const HiveReviewCiphertextStore(this._box);

  final Box<dynamic> _box;

  @override
  bool get isEmpty => _box.isEmpty;

  @override
  Iterable<String> get keys => List<String>.unmodifiable(
    _box.keys.map((key) {
      if (key is! String) {
        throw StateError('Review ciphertext storage has an invalid key.');
      }
      return key;
    }),
  );

  @override
  Object? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, Object value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<void> clear() async {
    await _box.clear();
  }
}
