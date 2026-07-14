import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_springs.dart';
import '../../../shared/widgets/copy_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_view.dart';
import '../logic/translate_controller.dart';
import '../models/translate_state.dart';

/// 结果文档：英雄译文 sticky + 向下滚动的三个辅助分节。
///
/// 取代旧 TabBar 结构。译文常驻顶部，辅助内容靠留白分组，无硬分割线。
class ResultDocument extends ConsumerWidget {
  const ResultDocument({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translateState = ref.watch(translateControllerProvider);
    final auxiliary = ref.watch(auxiliaryControllerProvider);

    // scroll-edge 渐隐：内容滚到顶部时在边缘淡出，取代硬分割线。
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.black, Colors.black],
          stops: [0.0, 0.02, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: CustomScrollView(
        slivers: [
          // empty/loading/error 时让 hero 区填满并垂直居中；
          // 有译文/辅助内容时保持自然高度可滚动。
          if (_isFillState(translateState, auxiliary))
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: HeroTranslation(state: translateState),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: HeroTranslation(state: translateState),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (auxiliary.examples.isNotEmpty)
                    _Section(
                      title: '场景例句',
                      count: auxiliary.examples.length,
                      children: [
                        for (final e in auxiliary.examples)
                          ExampleCard(example: e),
                      ],
                    ),
                  if (auxiliary.movieQuotes.isNotEmpty)
                    _Section(
                      title: '电影台词',
                      count: auxiliary.movieQuotes.length,
                      children: [
                        for (final q in auxiliary.movieQuotes)
                          MovieQuoteCard(quote: q),
                      ],
                    ),
                  if (auxiliary.examItems.isNotEmpty)
                    _Section(
                      title: '考试真题',
                      count: auxiliary.examItems.length,
                      children: [
                        for (final item in auxiliary.examItems)
                          ExamItemCard(item: item),
                      ],
                    ),
                  // 辅助内容加载中、但还没数据时给一个低调提示。
                  if (auxiliary.isLoading &&
                      auxiliary.examples.isEmpty &&
                      auxiliary.movieQuotes.isEmpty &&
                      auxiliary.examItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: StateView.loading(),
                    ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 当 hero 处于 empty/loading/error 且无辅助内容时，用 SliverFillRemaining
  /// 让占位视图填满并垂直居中。
  static bool _isFillState(TranslateState s, AuxiliaryState a) =>
      (s is TranslateEmpty || s is TranslateLoading || s is TranslateError) &&
      a.examples.isEmpty &&
      a.movieQuotes.isEmpty &&
      a.examItems.isEmpty;
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, count: count),
          ...children,
        ],
      ),
    );
  }
}

/// 英雄译文区：按状态渲染。
class HeroTranslation extends StatelessWidget {
  final TranslateState state;
  const HeroTranslation({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _build(context, base),
    );
  }

  Widget _build(BuildContext context, TextTheme base) {
    switch (state) {
      case TranslateEmpty():
        return const StateView.empty(message: '输入文本开始翻译');
      case TranslateLoading():
        return const StateView.loading();
      case TranslateStreaming(:final text):
        return _result(
          context,
          text,
          isStreaming: true,
          fadeKey: const ValueKey('streaming'),
        );
      case TranslateComplete(:final text):
        return _result(
          context,
          text,
          isStreaming: false,
          fadeKey: const ValueKey('complete'),
        );
      case TranslateError(:final message):
        return StateView.error(message: message);
    }
  }

  Widget _result(
    BuildContext context,
    String text, {
    required bool isStreaming,
    required Key fadeKey,
  }) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return SpringFadeIn(
      fadeKey: fadeKey,
      child: Column(
        key: fadeKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text,
            style: AppTypography.hero(
              base.displayMedium!,
            ).copyWith(color: palette.inkPrimary),
          ),
          if (!isStreaming && text.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                CopyButton(text: text),
                // 朗读占位：保留可扩展位，未来接入 TTS。
                _GhostAction(
                  icon: Icons.volume_up_rounded,
                  label: '朗读',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GhostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GhostAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: palette.inkSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.caption(
                base.labelMedium!,
              ).copyWith(color: palette.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ 卡片组件（无框、纯留白分组） ============

class ExampleCard extends StatelessWidget {
  final Example example;
  const ExampleCard({super.key, required this.example});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(label: example.scene),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            example.original,
            style: AppTypography.body(
              base.bodyLarge!,
            ).copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 2),
          SelectableText(
            example.translation,
            style: AppTypography.bodyMuted(
              base.bodyMedium!,
            ).copyWith(color: palette.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class MovieQuoteCard extends StatelessWidget {
  final MovieQuote quote;
  const MovieQuoteCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie_outlined, size: 13, color: palette.inkTertiary),
              const SizedBox(width: 4),
              Text(
                quote.movie,
                style: AppTypography.caption(
                  base.labelSmall!,
                ).copyWith(color: palette.inkTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            '"${quote.quote}"',
            style: AppTypography.body(
              base.bodyLarge!,
            ).copyWith(fontStyle: FontStyle.italic, color: palette.inkPrimary),
          ),
          const SizedBox(height: 2),
          SelectableText(
            quote.translation,
            style: AppTypography.bodyMuted(
              base.bodyMedium!,
            ).copyWith(color: palette.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class ExamItemCard extends StatelessWidget {
  final ExamItem item;
  const ExamItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tag(label: item.source, muted: true),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            item.question,
            style: AppTypography.body(
              base.bodyLarge!,
            ).copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: palette.surfaceElevated.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: SelectableText(
              item.answer,
              style: AppTypography.bodyMuted(
                base.bodyMedium!,
              ).copyWith(color: palette.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool muted;
  const _Tag({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    final bg = muted ? palette.surfaceElevated : palette.accentMuted;
    final fg = muted ? palette.inkSecondary : palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          base.labelSmall!,
        ).copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
