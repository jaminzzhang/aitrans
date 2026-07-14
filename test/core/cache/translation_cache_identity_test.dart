import 'package:aitrans/core/cache/translation_cache.dart';
import 'package:test/test.dart';

void main() {
  test('cache identity isolates every result-changing input', () {
    const baseline = TranslationCacheIdentity(
      providerNamespace: 'OpenAI|https://api.openai.com/v1|gpt-4o-mini',
      text: 'hello',
      from: 'en',
      to: 'zh',
      options: {'temperature': 0},
    );

    final variants = [
      const TranslationCacheIdentity(
        providerNamespace: 'Qwen|https://example.test/v1|qwen-plus',
        text: 'hello',
        from: 'en',
        to: 'zh',
        options: {'temperature': 0},
      ),
      const TranslationCacheIdentity(
        providerNamespace: 'OpenAI|https://api.openai.com/v1|gpt-4o',
        text: 'hello',
        from: 'en',
        to: 'zh',
        options: {'temperature': 0},
      ),
      const TranslationCacheIdentity(
        providerNamespace: 'OpenAI|https://api.openai.com/v1|gpt-4o-mini',
        text: 'hello',
        from: 'auto',
        to: 'zh',
        options: {'temperature': 0},
      ),
      const TranslationCacheIdentity(
        providerNamespace: 'OpenAI|https://api.openai.com/v1|gpt-4o-mini',
        text: 'hello',
        from: 'en',
        to: 'ja',
        options: {'temperature': 0},
      ),
      const TranslationCacheIdentity(
        providerNamespace: 'OpenAI|https://api.openai.com/v1|gpt-4o-mini',
        text: 'hello',
        from: 'en',
        to: 'zh',
        options: {'temperature': 0.1},
      ),
    ];

    for (final variant in variants) {
      expect(variant.key, isNot(baseline.key));
    }
  });

  test('cache identity canonicalizes option order', () {
    const first = TranslationCacheIdentity(
      providerNamespace: 'provider|endpoint|model',
      text: 'hello',
      from: 'en',
      to: 'zh',
      options: {'temperature': 0, 'format': 'text'},
    );
    const second = TranslationCacheIdentity(
      providerNamespace: 'provider|endpoint|model',
      text: 'hello',
      from: 'en',
      to: 'zh',
      options: {'format': 'text', 'temperature': 0},
    );

    expect(first.key, second.key);
  });
}
