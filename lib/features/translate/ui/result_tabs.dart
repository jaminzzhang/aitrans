import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../logic/translate_controller.dart';
import '../models/translate_state.dart';

/// 整合结果页面 - 包含 4 个 Tab：翻译、例句、台词、真题
class ResultTabs extends ConsumerWidget {
  const ResultTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Tab 栏
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: TabBar(
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.5),
              indicatorColor: theme.colorScheme.primary,
              dividerHeight: 0.2,
              tabs: const [
                Tab(text: '翻译'),
                Tab(text: '例句'),
                Tab(text: '台词'),
                Tab(text: '真题'),
              ],
            ),
          ),
          // Tab 内容
          Expanded(
            child: TabBarView(
              children: [
                const TranslationTabView(),
                const ExamplesTabView(),
                const MovieQuotesTabView(),
                const ExamItemsTabView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 翻译结果 Tab
class TranslationTabView extends ConsumerWidget {
  const TranslationTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateControllerProvider);
    final theme = Theme.of(context);

    return switch (state) {
      TranslateEmpty() => _buildEmptyHint(theme, '输入文本开始翻译'),
      TranslateLoading() => _buildLoading(),
      TranslateStreaming(:final text) => _buildTranslationContent(context, text, isStreaming: true),
      TranslateComplete(:final text) => _buildTranslationContent(context, text, isStreaming: false),
      TranslateError(:final message) => _buildError(theme, message),
    };
  }

  Widget _buildEmptyHint(ThemeData theme, String hint) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.translate,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildTranslationContent(BuildContext context, String text, {required bool isStreaming}) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text,
            style: theme.textTheme.headlineSmall?.copyWith(height: 1.5),
          ),
          if (!isStreaming && text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CopyButton(text: text),
          ],
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 复制按钮
class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _copy,
      icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
      label: Text(_copied ? '已复制' : '复制'),
    );
  }
}

/// 例句 Tab
class ExamplesTabView extends ConsumerWidget {
  const ExamplesTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auxiliaryControllerProvider);
    final theme = Theme.of(context);

    if (state.isLoading) return _buildLoading();
    if (state.examples.isEmpty) return _buildEmptyHint(theme, '输入单词后查看场景例句');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.examples.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) => ExampleCard(example: state.examples[index]),
    );
  }
}

/// 电影台词 Tab
class MovieQuotesTabView extends ConsumerWidget {
  const MovieQuotesTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auxiliaryControllerProvider);
    final theme = Theme.of(context);

    if (state.isLoading) return _buildLoading();
    if (state.movieQuotes.isEmpty) return _buildEmptyHint(theme, '输入单词后查看电影台词');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.movieQuotes.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) => MovieQuoteCard(quote: state.movieQuotes[index]),
    );
  }
}

/// 考试真题 Tab
class ExamItemsTabView extends ConsumerWidget {
  const ExamItemsTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auxiliaryControllerProvider);
    final theme = Theme.of(context);

    if (state.isLoading) return _buildLoading();
    if (state.examItems.isEmpty) return _buildEmptyHint(theme, '输入单词后查看考试真题');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.examItems.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) => ExamItemCard(item: state.examItems[index]),
    );
  }
}

// ============ 卡片组件 ============

/// 例句卡片
class ExampleCard extends StatelessWidget {
  final Example example;
  const ExampleCard({super.key, required this.example});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 场景标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            example.scene,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 英文原句
        SelectableText(example.original, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        // 中文翻译
        SelectableText(
          example.translation,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// 电影台词卡片
class MovieQuoteCard extends StatelessWidget {
  final MovieQuote quote;
  const MovieQuoteCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 电影名
        Row(
          children: [
            Icon(Icons.movie_outlined, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              quote.movie,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 台词原文
        SelectableText(
          '"${quote.quote}"',
          style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 4),
        // 中文翻译
        SelectableText(
          quote.translation,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// 考试真题卡片
class ExamItemCard extends StatelessWidget {
  final ExamItem item;
  const ExamItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 来源标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item.source,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 题目
        SelectableText(item.question, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        // 答案解析
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(item.answer, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

// ============ 通用组件 ============

Widget _buildLoading() {
  return const Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

Widget _buildEmptyHint(ThemeData theme, String hint) {
  return Center(
    child: Text(
      hint,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    ),
  );
}
