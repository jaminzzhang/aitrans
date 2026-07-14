import 'package:aitrans/app.dart';
import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 空实现 AIProvider，避免启动时发起真实网络请求。
class _NullAIProvider extends AIProvider {
  @override
  String get name => 'null';
  @override
  Future<bool> testConnection() async => false;
  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) => const Stream.empty();
  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();
  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();
  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}

void main() {
  testWidgets('App launches and renders AppShell with command bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiProviderProvider.overrideWith((_) => _NullAIProvider())],
        child: const AITransApp(),
      ),
    );
    await tester.pump();

    // AppShell 渲染了命令条与输入提示。
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('输入要翻译的文本…'), findsOneWidget);
    // 右上角齿轮。
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('tapping gear opens SettingsSheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiProviderProvider.overrideWith((_) => _NullAIProvider())],
        child: const AITransApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('AI 服务'), findsOneWidget);
  });
}
