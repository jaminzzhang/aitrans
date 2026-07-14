import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/features/settings/ui/settings_page.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:aitrans/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openSheet(WidgetTester tester) async {
  // 设置页以 dialog 形式呈现：直接 pump 一个 SettingsSheet。
  // 给足视口高度，让 sheet 内容（含底部「保存」按钮）可见可点击。
  tester.view.physicalSize = const Size(1400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(builder: (context) => Center(child: SettingsSheet())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsSheet', () {
    testWidgets('lists all providers including Qwen (6 total)', (tester) async {
      await _openSheet(tester);

      // 通过工厂期望的 providerName 断言每一项都渲染。
      for (final type in ProviderType.values) {
        final name = ProviderFactory.providerName(type);
        expect(
          find.text(name),
          findsWidgets,
          reason: 'provider row $name missing',
        );
      }
    });

    testWidgets(
      'selecting a provider writes providerType to aiConfigProvider',
      (tester) async {
        late ProviderContainer container;
        await _openSheet(tester);
        container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsSheet)),
          listen: false,
        );

        // 当前默认为 openai（aiConfigProvider 初始值）。点选 Qwen 行。
        final qwenName = ProviderFactory.providerName(ProviderType.qwen);
        await tester.tap(find.text(qwenName).first);
        await tester.pump();

        expect(
          container.read(aiConfigProvider).providerType,
          ProviderType.qwen,
        );
      },
    );

    testWidgets('save persists API key to aiConfigProvider', (tester) async {
      late ProviderContainer container;
      await _openSheet(tester);
      container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsSheet)),
        listen: false,
      );

      // 第一处可编辑 TextField 是 API Key。
      await tester.enterText(find.byType(TextField).first, 'sk-test-key');
      await tester.pumpAndSettle();

      // 收起输入焦点（enterText 后输入框持有焦点，直接点按钮会被拦截）。
      await tester.tapAt(const Offset(700, 100));
      await tester.pumpAndSettle();

      // 「保存」位于可滚动列表底部，向上拖动使其可见后再点击。
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(container.read(aiConfigProvider).apiKey, 'sk-test-key');
    });
  });
}
