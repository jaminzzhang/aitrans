import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/config/ai_config.dart';
import 'package:aitrans/core/config/settings_repository.dart';
import 'package:aitrans/features/settings/ui/settings_page.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects Qwen and shows its endpoint and model defaults', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          _UnusedSettingsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    await tester.tap(find.byType(DropdownButton<ProviderType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qwen').last);
    await tester.pumpAndSettle();

    expect(container.read(aiConfigProvider).providerType, ProviderType.ollama);
    expect(
      find.text('https://dashscope.aliyuncs.com/compatible-mode/v1'),
      findsOneWidget,
    );
    expect(find.text('qwen-plus'), findsOneWidget);
  });
}

class _UnusedSettingsRepository implements SettingsRepository {
  @override
  Future<AIConfig> load() async => AIConfig(providerType: ProviderType.ollama);

  @override
  Future<AIConfig> loadProviderDraft(ProviderType providerType) async {
    return AIConfig(providerType: providerType);
  }

  @override
  Future<void> save(AIConfig config) async {}

  @override
  Future<void> resetCredentials() async {}
}
