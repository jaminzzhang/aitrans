import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';

import '../ai/provider_factory.dart';
import '../config/ai_config.dart';
import '../config/settings_preferences_store.dart';
import '../config/settings_repository.dart';
import 'local_master_key_store.dart';
import 'provider_credential_store.dart';

class EncryptedProviderCredentialStore
    implements ProviderCredentialStore, SettingsPersistenceStore {
  EncryptedProviderCredentialStore(
    this._box,
    this._keyStore, {
    SettingsPreferencesStore? legacyPreferences,
  }) : _legacyPreferences = legacyPreferences;

  static const credentialsKey = 'provider_credentials';
  static const settingsStateKey = credentialsKey;
  static const _stateSchemaVersion = 2;
  static const _credentialSchemaVersion = 2;

  final Box<dynamic> _box;
  final MasterKeyProvider _keyStore;
  final SettingsPreferencesStore? _legacyPreferences;
  final _cipher = AesGcm.with256bits();
  SecretKey? _secretKey;
  Future<void> _writeTail = Future<void>.value();

  @override
  Future<ProviderPreferences> loadPreferences() async {
    await _writeTail;
    final state = _state;
    if (state != null) return _decodePreferences(state['preferences']);
    return await _legacyPreferences?.load() ??
        const ProviderPreferences(providerType: ProviderType.ollama);
  }

  @override
  Future<String?> readCredential(ProviderType providerType) =>
      read(providerType);

  @override
  Future<String?> read(ProviderType providerType) async {
    await _writeTail;
    final records = _credentialRecords;
    final raw = records[providerType.persistenceId];
    if (raw == null) return null;
    if (raw is! Map) throw StateError('Encrypted credential is invalid.');
    try {
      final entry = raw.cast<String, dynamic>();
      final schemaVersion = entry['schemaVersion'];
      if (schemaVersion != 1 && schemaVersion != _credentialSchemaVersion) {
        throw StateError('Encrypted credential is invalid.');
      }
      final box = SecretBox(
        base64Decode(entry['cipherText'] as String),
        nonce: base64Decode(entry['nonce'] as String),
        mac: Mac(base64Decode(entry['mac'] as String)),
      );
      final key = await _loadKey(records, allowCreate: false);
      if (schemaVersion == _credentialSchemaVersion) {
        final storedKeyId = entry['keyId'];
        if (storedKeyId is! String || storedKeyId != await _keyId(key)) {
          throw StateError('Encrypted credential is invalid.');
        }
      }
      return utf8.decode(
        await _cipher.decrypt(
          box,
          secretKey: key,
          aad: _aad(providerType, schemaVersion: schemaVersion as int),
        ),
      );
    } catch (error) {
      if (error is MasterKeyMissingException) rethrow;
      throw StateError('Encrypted credential is invalid.');
    }
  }

  @override
  Future<void> write(ProviderType providerType, String? credential) {
    return _serializeWrite(() async {
      final preferences = await _loadPreferencesUnlocked();
      await _saveState(
        preferences: preferences,
        credentialProvider: providerType,
        credential: credential,
      );
    });
  }

  @override
  Future<void> saveConfig(AIConfig config) {
    return _serializeWrite(() {
      return _saveState(
        preferences: ProviderPreferences.fromConfig(config),
        credentialProvider: config.providerType,
        credential: config.apiKey,
      );
    });
  }

  @override
  Future<void> resetCredentials() {
    return _serializeWrite(() async {
      final preferences = await _loadPreferencesUnlocked();
      await _box.put(settingsStateKey, <String, Object?>{
        'schemaVersion': _stateSchemaVersion,
        'preferences': _encodePreferences(preferences),
        'credentials': <String, Object?>{},
      });
      await _keyStore.reset();
      _secretKey = null;
    });
  }

  Future<void> _saveState({
    required ProviderPreferences preferences,
    required ProviderType credentialProvider,
    required String? credential,
  }) async {
    final records = Map<String, dynamic>.from(_credentialRecords);
    final normalized = credential?.trim() ?? '';

    // Existing ciphertext must always have its original key. Missing keys are
    // never regenerated implicitly, including credential deletion paths.
    if (records.isNotEmpty) {
      await _loadKey(records, allowCreate: false);
    }

    if (normalized.isEmpty) {
      records.remove(credentialProvider.persistenceId);
    } else {
      final key = await _loadKey(records, allowCreate: true);
      final encrypted = await _cipher.encrypt(
        utf8.encode(normalized),
        secretKey: key,
        aad: _aad(credentialProvider, schemaVersion: _credentialSchemaVersion),
      );
      records[credentialProvider.persistenceId] = <String, Object?>{
        'schemaVersion': _credentialSchemaVersion,
        'keyId': await _keyId(key),
        'nonce': base64Encode(encrypted.nonce),
        'cipherText': base64Encode(encrypted.cipherText),
        'mac': base64Encode(encrypted.mac.bytes),
      };
    }

    await _box.put(settingsStateKey, <String, Object?>{
      'schemaVersion': _stateSchemaVersion,
      'preferences': _encodePreferences(preferences),
      'credentials': records,
    });
  }

  Future<SecretKey> _loadKey(
    Map<dynamic, dynamic> records, {
    required bool allowCreate,
  }) async {
    final cached = _secretKey;
    if (cached != null) return cached;

    final existing = await _keyStore.loadExisting();
    if (existing != null) {
      _secretKey = existing;
      return existing;
    }
    if (records.isNotEmpty || !allowCreate) {
      throw const MasterKeyMissingException();
    }

    final created = await _keyStore.create();
    _secretKey = created;
    return created;
  }

  Future<String> _keyId(SecretKey key) async {
    final bytes = await key.extractBytes();
    final digest = await Sha256().hash(bytes);
    return base64Encode(digest.bytes.sublist(0, 8));
  }

  Future<T> _serializeWrite<T>(Future<T> Function() operation) async {
    final previous = _writeTail;
    final release = Completer<void>();
    _writeTail = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  Future<ProviderPreferences> _loadPreferencesUnlocked() async {
    final state = _state;
    if (state != null) return _decodePreferences(state['preferences']);
    return await _legacyPreferences?.load() ??
        const ProviderPreferences(providerType: ProviderType.ollama);
  }

  Map<dynamic, dynamic>? get _state {
    final value = _box.get(settingsStateKey);
    if (value == null) return null;
    if (value is! Map) {
      throw StateError('Encrypted settings are invalid.');
    }
    final schemaVersion = value['schemaVersion'];
    if (schemaVersion == null) return null;
    if (schemaVersion != _stateSchemaVersion) {
      throw StateError('Encrypted settings are invalid.');
    }
    return value;
  }

  Map<dynamic, dynamic> get _credentialRecords {
    final state = _state;
    if (state != null) {
      final credentials = state['credentials'];
      if (credentials is! Map) {
        throw StateError('Encrypted credentials are invalid.');
      }
      return credentials;
    }

    final legacy = _box.get(credentialsKey);
    if (legacy == null) return <dynamic, dynamic>{};
    if (legacy is! Map) {
      throw StateError('Encrypted credentials are invalid.');
    }
    return legacy;
  }

  ProviderPreferences _decodePreferences(Object? raw) {
    if (raw is! Map) throw StateError('Settings preferences are invalid.');
    final providerId = raw['providerType'];
    final baseUrl = raw['baseUrl'];
    final model = raw['model'];
    if (providerId is! String ||
        (baseUrl != null && baseUrl is! String) ||
        (model != null && model is! String)) {
      throw StateError('Settings preferences are invalid.');
    }
    final providerType = providerTypeFromPersistenceId(providerId);
    if (providerType == null) {
      throw StateError('Settings preferences are invalid.');
    }
    return ProviderPreferences(
      providerType: providerType,
      baseUrl: baseUrl as String?,
      model: model as String?,
    );
  }

  Map<String, Object?> _encodePreferences(ProviderPreferences preferences) {
    return <String, Object?>{
      'providerType': preferences.providerType.persistenceId,
      'baseUrl': preferences.baseUrl,
      'model': preferences.model,
    };
  }

  List<int> _aad(ProviderType providerType, {required int schemaVersion}) {
    final value = schemaVersion == 1
        ? 'provider:${providerType.persistenceId}'
        : 'aitrans:credential:v$schemaVersion:${providerType.persistenceId}';
    return Uint8List.fromList(utf8.encode(value));
  }
}
