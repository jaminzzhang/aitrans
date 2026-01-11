import 'ai_provider.dart';
import 'openai_provider.dart';
import 'claude_provider.dart';
import 'ollama_provider.dart';
import 'deepseek_provider.dart';
import '../config/ai_config.dart';

/// Provider 类型枚举
enum ProviderType {
  openai,
  claude,
  ollama,
  deepseek,
  custom,
}

/// AI Provider 工厂类
class ProviderFactory {
  /// 根据配置创建对应的 Provider
  static AIProvider create(AIConfig config) {
    switch (config.providerType) {
      case ProviderType.openai:
        return OpenAIProvider(
          apiKey: config.apiKey ?? '',
          baseUrl: config.baseUrl ?? 'https://api.openai.com/v1',
          model: config.model ?? 'gpt-4o-mini',
        );

      case ProviderType.claude:
        return ClaudeProvider(
          apiKey: config.apiKey ?? '',
          baseUrl: config.baseUrl ?? 'https://api.anthropic.com/v1',
          model: config.model ?? 'claude-3-haiku-20240307',
        );

      case ProviderType.ollama:
        return OllamaProvider(
          baseUrl: config.baseUrl ?? 'http://127.0.0.1:11434',
          model: config.model ?? 'llama3.2',
        );

      case ProviderType.deepseek:
        return DeepSeekProvider(
          apiKey: config.apiKey ?? '',
          baseUrl: config.baseUrl ?? 'https://api.deepseek.com/v1',
          model: config.model ?? 'deepseek-chat',
        );

      case ProviderType.custom:
        // 自定义使用 OpenAI 兼容接口
        return OpenAIProvider(
          apiKey: config.apiKey ?? '',
          baseUrl: config.baseUrl ?? '',
          model: config.model ?? 'gpt-3.5-turbo',
        );
    }
  }
}
