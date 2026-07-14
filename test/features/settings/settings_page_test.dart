import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/features/settings/ui/settings_page.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects Qwen and shows its endpoint and model defaults', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    expect(find.text('Qwen'), findsOneWidget);
    await tester.ensureVisible(find.text('Qwen'));
    await tester.tap(find.text('Qwen'));
    await tester.pump();

    expect(container.read(aiConfigProvider).providerType, ProviderType.qwen);
    expect(
      find.text('https://dashscope.aliyuncs.com/compatible-mode/v1'),
      findsOneWidget,
    );
    expect(find.text('qwen-plus'), findsOneWidget);
  });
}
