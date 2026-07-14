import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

class TranslationCacheIdentity {
  final String providerNamespace;
  final String text;
  final String from;
  final String to;
  final Map<String, Object?> options;

  const TranslationCacheIdentity({
    required this.providerNamespace,
    required this.text,
    required this.from,
    required this.to,
    this.options = const {},
  });

  String get key {
    final sortedOptions = Map<String, Object?>.fromEntries(
      options.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final canonical = jsonEncode({
      'provider': providerNamespace,
      'text': text,
      'from': from,
      'to': to,
      'options': sortedOptions,
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}

/// 缓存的翻译结果
@HiveType(typeId: 2)
class CachedTranslation extends HiveObject {
  @HiveField(0)
  String result;

  @HiveField(1)
  DateTime lastAccessed;

  CachedTranslation({required this.result, required this.lastAccessed});
}

/// 翻译缓存 (LRU策略)
abstract interface class TranslationCacheStore {
  Future<String?> get(String key);

  Future<void> set(String key, String value);
}

class TranslationCache implements TranslationCacheStore {
  final Box<CachedTranslation> _box;
  static const int maxCacheSize = 100;

  TranslationCache(this._box);

  /// 获取缓存条目数量
  int get count => _box.length;

  /// 获取缓存
  @override
  Future<String?> get(String key) async {
    final cached = _box.get(key);

    if (cached != null) {
      // 更新访问时间 (LRU)
      cached.lastAccessed = DateTime.now();
      await cached.save();
      return cached.result;
    }
    return null;
  }

  /// 设置缓存
  @override
  Future<void> set(String key, String value) async {
    // 超过限制时清理最旧的
    if (_box.length >= maxCacheSize) {
      await _evictOldest();
    }

    await _box.put(
      key,
      CachedTranslation(result: value, lastAccessed: DateTime.now()),
    );
  }

  /// 清空缓存
  Future<void> clear() async {
    await _box.clear();
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
