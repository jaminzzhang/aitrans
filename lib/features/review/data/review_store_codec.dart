import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

import '../domain/review_identity.dart';
import '../models/review_entry.dart';
import 'review_repository.dart';

class ReviewStoreCorruptedException implements Exception {
  const ReviewStoreCorruptedException();

  @override
  String toString() => 'ReviewStoreCorruptedException';
}

class ReviewStoreCodec {
  static const int schemaVersion = 1;
  static const String generationStorageKey = 'meta:generation-v1';
  static const String _algorithmName = 'AES-256-GCM';

  ReviewStoreCodec({AesGcm? cipher}) : _cipher = cipher ?? AesGcm.with256bits();

  final AesGcm _cipher;

  String entryStorageKey(ReviewIdentity identity) {
    final canonicalIdentity = jsonEncode(identity.toJson());
    final digest = hashes.sha256.convert(utf8.encode(canonicalIdentity));
    return 'entry:${base64UrlEncode(digest.bytes).replaceAll('=', '')}';
  }

  String contentStoragePrefix(ReviewIdentity identity) =>
      'content:${entryStorageKey(identity).substring('entry:'.length)}:';

  String contentStorageKey(ReviewIdentity identity, String contentId) {
    final digest = hashes.sha256.convert(utf8.encode(contentId));
    return '${contentStoragePrefix(identity)}'
        '${base64UrlEncode(digest.bytes).replaceAll('=', '')}';
  }

  Future<Map<String, Object>> encryptEntry({
    required ReviewEntry entry,
    required SecretKey key,
  }) => _encryptPayload(
    dataType: 'entry',
    storageKey: entryStorageKey(entry.identity),
    payload: _entryToJson(entry),
    key: key,
  );

  Future<Map<String, Object>> encryptDerivedContent({
    required ReviewDerivedContent content,
    required SecretKey key,
  }) => _encryptPayload(
    dataType: 'derived-content',
    storageKey: contentStorageKey(content.identity, content.contentId),
    payload: <String, Object>{
      'identity': content.identity.toJson(),
      'contentId': content.contentId,
      'mediaType': content.mediaType,
      'bytes': base64Encode(content.bytes),
      'generation': content.generation,
      'lastAccessedAt': content.lastAccessedAt.toUtc().toIso8601String(),
    },
    key: key,
  );

  Future<Map<String, Object>> encryptNextGeneration({
    required int nextGeneration,
    required SecretKey key,
  }) {
    if (nextGeneration < 0) {
      throw ArgumentError.value(nextGeneration, 'nextGeneration');
    }
    return _encryptPayload(
      dataType: 'generation',
      storageKey: generationStorageKey,
      payload: <String, Object>{'nextGeneration': nextGeneration},
      key: key,
    );
  }

  Future<ReviewEntry> decryptEntry({
    required Map<Object?, Object?> envelope,
    required ReviewIdentity expectedIdentity,
    required SecretKey key,
  }) async {
    final entry = await decryptEntryAtStorageKey(
      envelope: envelope,
      storageKey: entryStorageKey(expectedIdentity),
      key: key,
    );
    if (entry.identity != expectedIdentity) {
      throw const ReviewStoreCorruptedException();
    }
    return entry;
  }

  Future<ReviewEntry> decryptEntryAtStorageKey({
    required Map<Object?, Object?> envelope,
    required String storageKey,
    required SecretKey key,
  }) async {
    try {
      final decoded = await _decryptPayload(
        dataType: 'entry',
        storageKey: storageKey,
        envelope: envelope,
        key: key,
      );
      final entry = _entryFromJson(decoded);
      if (entryStorageKey(entry.identity) != storageKey) {
        throw const ReviewStoreCorruptedException();
      }
      return entry;
    } on ReviewStoreCorruptedException {
      rethrow;
    } catch (_) {
      throw const ReviewStoreCorruptedException();
    }
  }

  Future<ReviewDerivedContent> decryptDerivedContentAtStorageKey({
    required Map<Object?, Object?> envelope,
    required String storageKey,
    required SecretKey key,
  }) async {
    try {
      final decoded = await _decryptPayload(
        dataType: 'derived-content',
        storageKey: storageKey,
        envelope: envelope,
        key: key,
      );
      final identityJson = decoded['identity'];
      final contentId = decoded['contentId'];
      final mediaType = decoded['mediaType'];
      final bytes = decoded['bytes'];
      final generation = decoded['generation'];
      final lastAccessedAt = decoded['lastAccessedAt'];
      if (identityJson is! Map<String, dynamic> ||
          contentId is! String ||
          mediaType is! String ||
          bytes is! String ||
          generation is! int ||
          lastAccessedAt is! String) {
        throw const ReviewStoreCorruptedException();
      }
      final content = ReviewDerivedContent(
        identity: ReviewIdentity.fromJson(identityJson.cast<String, Object?>()),
        contentId: contentId,
        mediaType: mediaType,
        bytes: base64Decode(bytes),
        generation: generation,
        lastAccessedAt: DateTime.parse(lastAccessedAt).toUtc(),
      );
      if (contentStorageKey(content.identity, content.contentId) !=
          storageKey) {
        throw const ReviewStoreCorruptedException();
      }
      return content;
    } on ReviewStoreCorruptedException {
      rethrow;
    } catch (_) {
      throw const ReviewStoreCorruptedException();
    }
  }

  Future<int> decryptNextGeneration({
    required Map<Object?, Object?> envelope,
    required SecretKey key,
  }) async {
    try {
      final decoded = await _decryptPayload(
        dataType: 'generation',
        storageKey: generationStorageKey,
        envelope: envelope,
        key: key,
      );
      final nextGeneration = decoded['nextGeneration'];
      if (nextGeneration is! int || nextGeneration < 0) {
        throw const ReviewStoreCorruptedException();
      }
      return nextGeneration;
    } on ReviewStoreCorruptedException {
      rethrow;
    } catch (_) {
      throw const ReviewStoreCorruptedException();
    }
  }

  Future<Map<String, Object>> _encryptPayload({
    required String dataType,
    required String storageKey,
    required Map<String, Object?> payload,
    required SecretKey key,
  }) async {
    final nonce = _cipher.newNonce();
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
      nonce: nonce,
      aad: _aad(dataType, storageKey),
    );
    return <String, Object>{
      'schemaVersion': schemaVersion,
      'algorithm': _algorithmName,
      'keyId': await _keyId(key),
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> _decryptPayload({
    required String dataType,
    required String storageKey,
    required Map<Object?, Object?> envelope,
    required SecretKey key,
  }) async {
    if (envelope['schemaVersion'] != schemaVersion ||
        envelope['algorithm'] != _algorithmName ||
        envelope['keyId'] != await _keyId(key)) {
      throw const ReviewStoreCorruptedException();
    }
    final clearText = await _cipher.decrypt(
      SecretBox(
        _decodeBytes(envelope['cipherText']),
        nonce: _decodeBytes(envelope['nonce']),
        mac: Mac(_decodeBytes(envelope['mac'])),
      ),
      secretKey: key,
      aad: _aad(dataType, storageKey),
    );
    final decoded = jsonDecode(utf8.decode(clearText));
    if (decoded is! Map<String, dynamic>) {
      throw const ReviewStoreCorruptedException();
    }
    return decoded;
  }

  List<int> _aad(String dataType, String storageKey) =>
      utf8.encode('aitrans:review:$dataType:v$schemaVersion:$storageKey');

  Future<String> _keyId(SecretKey key) async {
    final keyBytes = await key.extractBytes();
    if (keyBytes.length != 32) {
      throw const ReviewStoreCorruptedException();
    }
    final digest = hashes.sha256.convert(keyBytes);
    return base64UrlEncode(digest.bytes.take(8).toList()).replaceAll('=', '');
  }

  static List<int> _decodeBytes(Object? value) {
    if (value is! String) {
      throw const ReviewStoreCorruptedException();
    }
    return base64Decode(value);
  }

  static Map<String, Object?> _entryToJson(ReviewEntry entry) => {
    'identity': entry.identity.toJson(),
    'aliases': entry.aliases.toList()..sort(),
    'createdAt': entry.createdAt.toUtc().toIso8601String(),
    'latestTranslatedAt': entry.latestTranslatedAt.toUtc().toIso8601String(),
    'translationCount': entry.translationCount,
    'latestContent': <String, Object?>{
      'sourceText': entry.latestContent.sourceText,
      'translationText': entry.latestContent.translationText,
      'primaryMeaning': entry.latestContent.primaryMeaning,
      'partOfSpeech': entry.latestContent.partOfSpeech,
      'pronunciation': entry.latestContent.pronunciation,
      'secondaryMeanings': entry.latestContent.secondaryMeanings,
    },
    'consecutiveRememberedCount': entry.consecutiveRememberedCount,
    'forgetCount': entry.forgetCount,
    'lastReviewedAt': entry.lastReviewedAt?.toUtc().toIso8601String(),
    'nextReviewAt': entry.nextReviewAt?.toUtc().toIso8601String(),
    'forcedDue': entry.forcedDue,
    'generation': entry.generation,
    'appliedFeedbackEventIds': entry.appliedFeedbackEventIds.toList()..sort(),
  };

  static ReviewEntry _entryFromJson(Map<String, dynamic> json) {
    final identityJson = json['identity'];
    final aliases = json['aliases'];
    final content = json['latestContent'];
    final createdAt = json['createdAt'];
    final latestTranslatedAt = json['latestTranslatedAt'];
    final translationCount = json['translationCount'];
    final consecutiveRememberedCount = json['consecutiveRememberedCount'];
    final forgetCount = json['forgetCount'];
    final forcedDue = json['forcedDue'];
    final generation = json['generation'];
    final appliedFeedbackEventIds = json['appliedFeedbackEventIds'];
    if (identityJson is! Map<String, dynamic> ||
        aliases is! List<dynamic> ||
        content is! Map<String, dynamic> ||
        createdAt is! String ||
        latestTranslatedAt is! String ||
        translationCount is! int ||
        consecutiveRememberedCount is! int ||
        forgetCount is! int ||
        forcedDue is! bool ||
        generation is! int ||
        (appliedFeedbackEventIds != null &&
            (appliedFeedbackEventIds is! List<dynamic> ||
                appliedFeedbackEventIds.any(
                  (eventId) => eventId is! String,
                ))) ||
        aliases.any((alias) => alias is! String)) {
      throw const ReviewStoreCorruptedException();
    }

    final sourceText = content['sourceText'];
    final translationText = content['translationText'];
    final primaryMeaning = content['primaryMeaning'];
    final partOfSpeech = content['partOfSpeech'];
    final pronunciation = content['pronunciation'];
    final secondaryMeanings = content['secondaryMeanings'];
    if (sourceText is! String ||
        translationText is! String ||
        primaryMeaning is! String ||
        (partOfSpeech != null && partOfSpeech is! String) ||
        (pronunciation != null && pronunciation is! String) ||
        secondaryMeanings is! List<dynamic> ||
        secondaryMeanings.any((meaning) => meaning is! String)) {
      throw const ReviewStoreCorruptedException();
    }

    return ReviewEntry(
      identity: ReviewIdentity.fromJson(identityJson.cast<String, Object?>()),
      aliases: aliases.cast<String>(),
      createdAt: DateTime.parse(createdAt).toUtc(),
      latestTranslatedAt: DateTime.parse(latestTranslatedAt).toUtc(),
      translationCount: translationCount,
      latestContent: ReviewEntryContent(
        sourceText: sourceText,
        translationText: translationText,
        primaryMeaning: primaryMeaning,
        partOfSpeech: partOfSpeech as String?,
        pronunciation: pronunciation as String?,
        secondaryMeanings: secondaryMeanings.cast<String>(),
      ),
      consecutiveRememberedCount: consecutiveRememberedCount,
      forgetCount: forgetCount,
      lastReviewedAt: _optionalDateTime(json['lastReviewedAt']),
      nextReviewAt: _optionalDateTime(json['nextReviewAt']),
      forcedDue: forcedDue,
      generation: generation,
      appliedFeedbackEventIds:
          (appliedFeedbackEventIds as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
    );
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw const ReviewStoreCorruptedException();
    }
    return DateTime.parse(value).toUtc();
  }
}
