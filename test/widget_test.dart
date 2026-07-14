import 'package:aitrans/app.dart';
import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/platform/external_translation_request.dart';
import 'package:aitrans/features/translate/logic/external_translation_coordinator.dart';
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

  testWidgets('overlong external selection shows a safe error', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AITransApp()));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AITransApp)),
      listen: false,
    );

    container
        .read(externalTranslationCoordinatorProvider.notifier)
        .handle(
          sequence: 1,
          source: ExternalTranslationSource.macosService,
          text: List.filled(5001, 'a').join(),
        );
    await tester.pump();

    expect(find.text('所选文本过长，请缩短至 5,000 字符以内'), findsOneWidget);
  });

  testWidgets('bridge failure shows a safe error without native details', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AITransApp()));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AITransApp)),
      listen: false,
    );

    container.read(externalTranslationBridgeStatusProvider.notifier).state =
        ExternalTranslationBridgeStatus.unavailable;
    await tester.pump();

    expect(find.text('无法启用系统翻译服务，请重新启动 AITrans。'), findsOneWidget);
  });

  testWidgets('accepted external selection closes settings and shows input', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiProviderProvider.overrideWith((_) => _NullAIProvider())],
        child: const AITransApp(),
      ),
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AITransApp)),
      listen: false,
    );

    container
        .read(externalTranslationCoordinatorProvider.notifier)
        .handle(
          sequence: 1,
          source: ExternalTranslationSource.macosService,
          text: 'selected text',
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('设置'), findsNothing);
    expect(find.text('selected text'), findsOneWidget);
  });
}
