import 'package:hive/hive.dart';

import '../ai/provider_factory.dart';
import 'ai_config.dart';

class ProviderPreferences {
  const ProviderPreferences({
    required this.providerType,
    this.baseUrl,
    this.model,
  });

  factory ProviderPreferences.fromConfig(AIConfig config) {
    return ProviderPreferences(
      providerType: config.providerType,
      baseUrl: config.baseUrl,
      model: config.model,
    );
  }

  final ProviderType providerType;
  final String? baseUrl;
  final String? model;

  AIConfig toConfig({String? apiKey}) {
    return AIConfig(
      providerType: providerType,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProviderPreferences &&
        other.providerType == providerType &&
        other.baseUrl == baseUrl &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(providerType, baseUrl, model);
}

abstract interface class SettingsPreferencesStore {
  Future<ProviderPreferences> load();

  Future<void> save(ProviderPreferences preferences);
}

class HiveSettingsPreferencesStore implements SettingsPreferencesStore {
  HiveSettingsPreferencesStore(this._box);

  static const preferencesKey = 'provider_preferences';
  static const _schemaVersion = 1;

  final Box<dynamic> _box;

  @override
  Future<ProviderPreferences> load() async {
    final value = _box.get(preferencesKey);
    if (value is! Map) return _defaults;

    final schemaVersion = value['schemaVersion'];
    final providerName = value['providerType'];
    final baseUrl = value['baseUrl'];
    final model = value['model'];
    if (schemaVersion != _schemaVersion ||
        providerName is! String ||
        (baseUrl != null && baseUrl is! String) ||
        (model != null && model is! String)) {
      return _defaults;
    }

    final providerType = providerTypeFromPersistenceId(providerName);
    if (providerType == null) return _defaults;

    return ProviderPreferences(
      providerType: providerType,
      baseUrl: baseUrl as String?,
      model: model as String?,
    );
  }

  @override
  Future<void> save(ProviderPreferences preferences) {
    return _box.put(preferencesKey, <String, Object?>{
      'schemaVersion': _schemaVersion,
      'providerType': preferences.providerType.persistenceId,
      'baseUrl': preferences.baseUrl,
      'model': preferences.model,
    });
  }

  static const _defaults = ProviderPreferences(
    providerType: ProviderType.ollama,
  );
}
