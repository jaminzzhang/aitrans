import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:aitrans/features/translate/models/translate_state.dart';
import 'package:aitrans/features/translate/ui/result_document.dart';
import 'package:aitrans/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试用的空实现 AIProvider：extends 以继承接口默认实现，不发起真实请求。
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

/// 固定 translate 状态的 controller，用于断言各状态渲染。
class _FixedTranslateController extends TranslateController {
  final TranslateState fixed;
  _FixedTranslateController(this.fixed) : super(_NullAIProvider(), null);

  @override
  TranslateState get state => fixed;
  @override
  set state(TranslateState value) {}
}

/// 固定辅助内容状态的 controller。
class _FixedAuxiliaryController extends AuxiliaryController {
  final AuxiliaryState fixed;
  _FixedAuxiliaryController(this.fixed) : super(_NullAIProvider());
  @override
  AuxiliaryState get state => fixed;
  @override
  set state(AuxiliaryState value) {}
}

Widget _wrap(TranslateState t, AuxiliaryState a) {
  return ProviderScope(
    overrides: [
      translateControllerProvider.overrideWith(
        (ref) => _FixedTranslateController(t),
      ),
      auxiliaryControllerProvider.overrideWith(
        (ref) => _FixedAuxiliaryController(a),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: ResultDocument()),
    ),
  );
}

void main() {
  group('ResultDocument', () {
    testWidgets('renders empty hint in TranslateEmpty', (tester) async {
      await tester.pumpWidget(
        _wrap(const TranslateEmpty(), const AuxiliaryState()),
      );
      await tester.pumpAndSettle();
      expect(find.text('输入文本开始翻译'), findsOneWidget);
    });

    testWidgets('renders error message in TranslateError', (tester) async {
      await tester.pumpWidget(
        _wrap(const TranslateError('网络异常'), const AuxiliaryState()),
      );
      await tester.pumpAndSettle();
      expect(find.text('网络异常'), findsOneWidget);
    });

    testWidgets('renders hero translation text in TranslateComplete', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TranslateComplete('意外发现'), const AuxiliaryState()),
      );
      await tester.pumpAndSettle();
      expect(find.text('意外发现'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('shows lexical metadata without competing with the meaning', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TranslateComplete(
            '意外发现\nPOS: noun\nPRON: /ˌserənˈdɪpəti/\n- 偶然发现\n- 机缘巧合',
          ),
          const AuxiliaryState(),
        ),
      );
      await tester.pumpAndSettle();

      final primary = tester.widget<SelectableText>(
        find.widgetWithText(SelectableText, '意外发现'),
      );
      final secondary = tester.widget<SelectableText>(
        find.widgetWithText(SelectableText, '偶然发现'),
      );

      expect(find.text('noun'), findsOneWidget);
      expect(find.text('/ˌserənˈdɪpəti/'), findsOneWidget);
      expect(find.text('机缘巧合'), findsOneWidget);
      expect(primary.style!.fontSize, greaterThan(secondary.style!.fontSize!));
    });

    testWidgets('renders streaming text without copy button', (tester) async {
      await tester.pumpWidget(
        _wrap(const TranslateStreaming('流式中'), const AuxiliaryState()),
      );
      await tester.pumpAndSettle();
      expect(find.text('流式中'), findsOneWidget);
      // 流式中不显示复制按钮。
      expect(find.text('复制'), findsNothing);
    });

    testWidgets('renders examples section with header and count', (
      tester,
    ) async {
      final aux = AuxiliaryState(
        examples: [
          Example(scene: '日常', original: 'serendipity', translation: '机缘巧合'),
        ],
      );
      await tester.pumpWidget(_wrap(const TranslateComplete('译文'), aux));
      await tester.pumpAndSettle();
      expect(find.text('场景例句'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('serendipity'), findsOneWidget);
      expect(find.text('机缘巧合'), findsOneWidget);
    });

    testWidgets('renders movie quotes and exam items sections', (tester) async {
      final aux = AuxiliaryState(
        movieQuotes: [MovieQuote(movie: 'Once', quote: 'hi', translation: '嗨')],
        examItems: [ExamItem(source: 'CET-6', question: 'Q?', answer: 'A')],
      );
      await tester.pumpWidget(_wrap(const TranslateComplete('译文'), aux));
      await tester.pumpAndSettle();
      expect(find.text('电影台词'), findsOneWidget);
      expect(find.text('考试真题'), findsOneWidget);
      expect(find.text('Once'), findsOneWidget);
      expect(find.text('"hi"'), findsOneWidget);
      expect(find.text('CET-6'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });
  });
}
