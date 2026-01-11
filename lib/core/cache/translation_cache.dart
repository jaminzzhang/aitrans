import 'package:hive/hive.dart';

/// 缓存的翻译结果
@HiveType(typeId: 2)
class CachedTranslation extends HiveObject {
  @HiveField(0)
  String result;

  @HiveField(1)
  DateTime lastAccessed;

  CachedTranslation({
    required this.result,
    required this.lastAccessed,
  });
}

/// 翻译缓存 (LRU策略)
class TranslationCache {
  final Box<CachedTranslation> _box;
  static const int maxCacheSize = 100;

  TranslationCache(this._box);

  /// 获取缓存
  Future<String?> get(String key) async {
    final hash = _hashKey(key);
    final cached = _box.get(hash);

    if (cached != null) {
      // 更新访问时间 (LRU)
      cached.lastAccessed = DateTime.now();
      await cached.save();
      return cached.result;
    }
    return null;
  }

  /// 设置缓存
  Future<void> set(String key, String value) async {
    // 超过限制时清理最旧的
    if (_box.length >= maxCacheSize) {
      await _evictOldest();
    }

    final hash = _hashKey(key);
    await _box.put(
      hash,
      CachedTranslation(
        result: value,
        lastAccessed: DateTime.now(),
      ),
    );
  }

  /// 清空缓存
  Future<void> clear() async {
    await _box.clear();
  }

  /// 生成缓存键的哈希
  String _hashKey(String key) {
    return key.hashCode.toString();
  }

  /// 清理最旧的缓存条目
  Future<void> _evictOldest() async {
    if (_box.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final key in _box.keys) {
      final item = _box.get(key);
      if (item != null) {
        if (oldestTime == null || item.lastAccessed.isBefore(oldestTime)) {
          oldestTime = item.lastAccessed;
          oldestKey = key as String;
        }
      }
    }

    if (oldestKey != null) {
      await _box.delete(oldestKey);
    }
  }
}

/// CachedTranslation 的 Hive 适配器
class CachedTranslationAdapter extends TypeAdapter<CachedTranslation> {
  @override
  final int typeId = 2;

  @override
  CachedTranslation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedTranslation(
      result: fields[0] as String,
      lastAccessed: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedTranslation obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.result)
      ..writeByte(1)
      ..write(obj.lastAccessed);
  }
}
