import 'ai_provider.dart';
import 'claude_provider.dart';
import 'openai_compatible_provider.dart';
import '../config/ai_config.dart';

/// Provider 类型枚举
enum ProviderType { openai, claude, ollama, deepseek, custom, qwen }

extension ProviderTypePersistence on ProviderType {
  String get persistenceId => switch (this) {
    ProviderType.openai => 'openai',
    ProviderType.claude => 'claude',
    ProviderType.ollama => 'ollama',
    ProviderType.deepseek => 'deepseek',
    ProviderType.custom => 'custom',
    ProviderType.qwen => 'qwen',
  };
}

ProviderType? providerTypeFromPersistenceId(String value) {
  for (final type in ProviderType.values) {
    if (type.persistenceId == value) return type;
  }
  return null;
}

class AIConfigurationException implements Exception {
  final String message;

  const AIConfigurationException(this.message);

  @override
  String toString() => message;
}

class AIEndpointConfig {
  final ProviderType providerType;
  final String providerName;
  final String apiKey;
  final String baseUrl;
  final String model;
  final bool supportsTools;
  final bool requiresApiKey;

  const AIEndpointConfig({
    required this.providerType,
    required this.providerName,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.supportsTools,
    required this.requiresApiKey,
  });
}

/// AI Provider 工厂类
class ProviderFactory {
  static String providerName(ProviderType type) => switch (type) {
    ProviderType.openai => 'OpenAI',
    ProviderType.claude => 'Claude',
    ProviderType.ollama => 'Ollama',
    ProviderType.deepseek => 'DeepSeek',
    ProviderType.custom => 'Custom',
    ProviderType.qwen => 'Qwen',
  };

  static AIEndpointConfig resolveConfig(AIConfig config) {
    final defaults = switch (config.providerType) {
      ProviderType.openai => const (
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        supportsTools: true,
        requiresApiKey: true,
      ),
      ProviderType.claude => const (
        name: 'Claude',
        baseUrl: 'https://api.anthropic.com/v1',
        model: 'claude-3-haiku-20240307',
        supportsTools: false,
        requiresApiKey: true,
      ),
      ProviderType.ollama => const (
        name: 'Ollama',
        baseUrl: 'http://127.0.0.1:11434/v1',
        model: 'llama3.2',
        supportsTools: true,
        requiresApiKey: false,
      ),
      ProviderType.deepseek => const (
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-v4-flash',
        supportsTools: true,
        requiresApiKey: true,
      ),
      ProviderType.qwen => const (
        name: 'Qwen',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        model: 'qwen-plus',
        supportsTools: true,
        requiresApiKey: true,
      ),
      ProviderType.custom => const (
        name: 'Custom',
        baseUrl: '',
        model: '',
        supportsTools: true,
        requiresApiKey: false,
      ),
    };

    final baseUrl = (config.baseUrl ?? defaults.baseUrl).trim();
    final model = (config.model ?? defaults.model).trim();
    if (baseUrl.isEmpty) {
      throw const AIConfigurationException('Base URL is required.');
    }
    if (model.isEmpty) {
      throw const AIConfigurationException('Model is required.');
    }
    if (config.providerType == ProviderType.deepseek &&
        const {'deepseek-chat', 'deepseek-reasoner'}.contains(model)) {
      throw const AIConfigurationException(
        'The configured DeepSeek model is retired. Select a supported model.',
      );
    }

    return AIEndpointConfig(
      providerType: config.providerType,
      providerName: defaults.name,
      apiKey: config.apiKey?.trim() ?? '',
      baseUrl: baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      model: model,
      supportsTools: defaults.supportsTools,
      requiresApiKey: defaults.requiresApiKey,
    );
  }

  /// 根据配置创建对应的 Provider
  static AIProvider create(AIConfig config) {
    final resolved = resolveConfig(config);
    if (resolved.requiresApiKey && resolved.apiKey.isEmpty) {
      throw const AIConfigurationException(
        'An API key is required for the selected provider.',
      );
    }
    switch (config.providerType) {
      case ProviderType.openai:
        return OpenAICompatibleProvider(
          providerName: resolved.providerName,
          apiKey: resolved.apiKey,
          baseUrl: resolved.baseUrl,
          model: resolved.model,
        );

      case ProviderType.claude:
        return ClaudeProvider(
          apiKey: resolved.apiKey,
          baseUrl: resolved.baseUrl,
          model: resolved.model,
        );

      case ProviderType.ollama:
        return OpenAICompatibleProvider(
          providerName: resolved.providerName,
          apiKey: resolved.apiKey,
          baseUrl: resolved.baseUrl,
          model: resolved.model,
        );

      case ProviderType.deepseek:
        return OpenAICompatibleProvider(
          providerName: resolved.providerName,
          apiKey: resolved.apiKey,
          baseUrl: resolved.baseUrl,
          model: resolved.model,
        );

      case ProviderType.custom:
        // 自定义使用 OpenAI 兼容接口
        return OpenAICompatibleProvider(
          providerName: resolved.providerName,
          apiKey: resolved.apiKey,
          baseUrl: resolved.baseUrl,
          model: resolved.model,
        );

      case ProviderType.qwen:
        return OpenAICompatibleProvider(
          providerName: resolved.providerName,
          apiKey: resolved.apiKey,
          baseUrl: resolved.baseUrl,
          model: resolved.model,
        );
    }
  }
}
