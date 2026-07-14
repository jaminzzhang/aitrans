import '../ai/provider_factory.dart';

/// AI 配置模型
class AIConfig {
  final ProviderType providerType;

  final String? apiKey;

  final String? baseUrl;

  final String? model;

  AIConfig({
    this.providerType = ProviderType.openai,
    this.apiKey,
    this.baseUrl,
    this.model,
  });
}
