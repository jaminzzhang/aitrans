import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/config/ai_config.dart';
import 'package:test/test.dart';

void main() {
  group('ProviderFactory.resolveConfig', () {
    test('resolves OpenAI-compatible provider defaults', () {
      final cases = <ProviderType, ({String baseUrl, String model})>{
        ProviderType.openai: (
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
        ),
        ProviderType.deepseek: (
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-v4-flash',
        ),
        ProviderType.qwen: (
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          model: 'qwen-plus',
        ),
        ProviderType.ollama: (
          baseUrl: 'http://127.0.0.1:11434/v1',
          model: 'llama3.2',
        ),
      };

      for (final entry in cases.entries) {
        final resolved = ProviderFactory.resolveConfig(
          AIConfig(providerType: entry.key),
        );

        expect(resolved.baseUrl, entry.value.baseUrl);
        expect(resolved.model, entry.value.model);
        expect(resolved.supportsTools, isTrue);
      }
    });

    test('preserves existing ProviderType indexes when Qwen is added', () {
      expect(ProviderType.custom.index, 4);
      expect(ProviderType.qwen.index, 5);
    });

    test('rejects the retired DeepSeek chat model', () {
      expect(
        () => ProviderFactory.resolveConfig(
          AIConfig(providerType: ProviderType.deepseek, model: 'deepseek-chat'),
        ),
        throwsA(isA<AIConfigurationException>()),
      );
    });

    test('keeps explicit custom endpoint and model', () {
      final resolved = ProviderFactory.resolveConfig(
        AIConfig(
          providerType: ProviderType.custom,
          apiKey: 'test-key',
          baseUrl: 'http://localhost:8080/v1/',
          model: 'test-model',
        ),
      );

      expect(resolved.baseUrl, 'http://localhost:8080/v1');
      expect(resolved.model, 'test-model');
      expect(resolved.apiKey, 'test-key');
    });

    test('rejects a missing key before creating a remote provider', () {
      expect(
        () => ProviderFactory.create(AIConfig(providerType: ProviderType.qwen)),
        throwsA(isA<AIConfigurationException>()),
      );
    });
  });
}
