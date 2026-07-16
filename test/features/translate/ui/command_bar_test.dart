import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:aitrans/features/translate/ui/command_bar.dart';
import 'package:aitrans/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录调用以断言交互触发。
class _RecordingTranslateController extends TranslateController {
  _RecordingTranslateController() : super(_NullAIProvider(), null);
  int translateNowCalls = 0;
  int onTextChangedCalls = 0;
  String? lastSubmitted;

  @override
  void onTextChanged(String text) {
    onTextChangedCalls++;
  }

  @override
  void translateNow(String text) {
    translateNowCalls++;
    lastSubmitted = text;
  }
}

/// loadContent 为空操作的辅助控制器，避免提交翻译时触发真实 provider。
class _NoopAuxiliaryController extends AuxiliaryController {
  _NoopAuxiliaryController() : super(_NullAIProvider());
  @override
  void loadContent(String word) {}
}

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
  group('CommandBar', () {
    testWidgets('typing updates inputTextProvider', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: CommandBar()),
          ),
        ),
      );
      // 取到注入的 container。
      container = ProviderScope.containerOf(
        tester.element(find.byType(CommandBar)),
        listen: false,
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(container.read(inputTextProvider), 'hello');
    });

    testWidgets('clear button empties input', (tester) async {
      final controller = _RecordingTranslateController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translateControllerProvider.overrideWith((_) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CommandBar()),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'word');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(find.text('word'), findsNothing);
    });

    testWidgets('translate chip triggers translateNow with current input', (
      tester,
    ) async {
      final controller = _RecordingTranslateController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // 提供 null AI provider，避免 _onSubmitted 触发的 loadContent
            // 调用真实 provider 抛错污染测试。
            aiProviderProvider.overrideWith((_) => _NullAIProvider()),
            translateControllerProvider.overrideWith((_) => controller),
            auxiliaryControllerProvider.overrideWith(
              (_) => _NoopAuxiliaryController(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CommandBar()),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'translate me');
      await tester.pump();

      // 点击「翻译」按钮。
      await tester.tap(find.text('翻译'));
      await tester.pump();

      expect(controller.translateNowCalls, greaterThan(0));
      expect(controller.lastSubmitted, 'translate me');
    });

    testWidgets('enter triggers the same immediate translation as the chip', (
      tester,
    ) async {
      final controller = _RecordingTranslateController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiProviderProvider.overrideWith((_) => _NullAIProvider()),
            translateControllerProvider.overrideWith((_) => controller),
            auxiliaryControllerProvider.overrideWith(
              (_) => _NoopAuxiliaryController(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CommandBar()),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'translate me');
      await tester.pump();
      final callsBeforeEnter = controller.translateNowCalls;

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.translateNowCalls, callsBeforeEnter + 1);
      expect(controller.lastSubmitted, 'translate me');
    });

    testWidgets('enter commits active IME composition without translating', (
      tester,
    ) async {
      final controller = _RecordingTranslateController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiProviderProvider.overrideWith((_) => _NullAIProvider()),
            translateControllerProvider.overrideWith((_) => controller),
            auxiliaryControllerProvider.overrideWith(
              (_) => _NoopAuxiliaryController(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CommandBar()),
          ),
        ),
      );

      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.showKeyboard(field);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'nihao',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();
      final callsBeforeEnter = controller.translateNowCalls;
      final changesBeforeEnter = controller.onTextChangedCalls;

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.translateNowCalls, callsBeforeEnter);
      expect(controller.onTextChangedCalls, changesBeforeEnter);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '你好',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(controller.translateNowCalls, callsBeforeEnter);
      expect(controller.onTextChangedCalls, changesBeforeEnter);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.translateNowCalls, callsBeforeEnter + 1);
      expect(controller.lastSubmitted, '你好');
    });

    testWidgets('shows clear button only when there is input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CommandBar()),
          ),
        ),
      );
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets(
      'external input state updates the field without simulating manual typing',
      (tester) async {
        final controller = _RecordingTranslateController();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translateControllerProvider.overrideWith((_) => controller),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: CommandBar()),
            ),
          ),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CommandBar)),
          listen: false,
        );

        container.read(inputTextProvider.notifier).state = 'selected elsewhere';
        await tester.pump();

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, 'selected elsewhere');
        expect(field.controller!.selection.baseOffset, 18);
        expect(controller.onTextChangedCalls, 0);
      },
    );
  });
}
