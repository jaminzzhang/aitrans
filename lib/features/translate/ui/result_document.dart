import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/theme/app_springs.dart';
import '../../../shared/widgets/copy_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_view.dart';
import '../logic/translate_controller.dart';
import '../models/translation_presentation.dart';
import '../models/translate_state.dart';

/// 结果文档：英雄译文 sticky + 向下滚动的三个辅助分节。
///
/// 取代旧 TabBar 结构。译文常驻顶部，辅助内容靠留白分组，无硬分割线。
/// 墨笺版式：衬线译文 + 朱砂细线 + 出版物级留白。
class ResultDocument extends ConsumerWidget {
  const ResultDocument({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translateState = ref.watch(translateControllerProvider);
    final auxiliary = ref.watch(auxiliaryControllerProvider);

    // scroll-edge 渐隐：内容滚到顶部时在边缘淡出，取代硬分割线。
    // 调淡到几乎不可见，避免破坏暖纸纯净感。
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.black, Colors.black],
          stops: [0.0, 0.015, 1.0],
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
                padding: const EdgeInsets.all(AppSpacing.xlg),
                child: HeroTranslation(state: translateState),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: HeroTranslation(state: translateState),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxl,
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
      padding: const EdgeInsets.only(top: AppSpacing.lg),
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
    final presentation = TranslationPresentation.parse(text);
    // 朱砂细下划线：译文下方的精装书扉页式分隔，宽约 36pt，极细。
    return SpringFadeIn(
      fadeKey: fadeKey,
      child: Column(
        key: fadeKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            presentation.primaryMeaning,
            style: AppTypography.editorial(
              base.displayMedium!,
            ).copyWith(color: palette.inkPrimary),
          ),
          if (presentation.secondaryMeanings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final meaning in presentation.secondaryMeanings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.seal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SelectableText(
                        meaning,
                        style: AppTypography.serifBody(
                          base.bodyLarge!,
                        ).copyWith(color: palette.inkSecondary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          // 朱砂细线：紧贴译文下方，留白后再放操作行。
          if (!isStreaming && text.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 36,
              height: 1.5,
              decoration: BoxDecoration(
                color: palette.seal,
                borderRadius: AppRadii.pillRadius,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
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

/// 描边细胶囊：墨绿描边 + 墨色文字，按下轻填充。
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
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.pillRadius,
        side: BorderSide(color: palette.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: palette.inkSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption(
                  base.labelMedium!,
                ).copyWith(color: palette.inkSecondary),
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SealTag(label: example.scene),
          const SizedBox(height: AppSpacing.sm),
          // 原文用衬线，释义用无衬线，形成层级。
          SelectableText(
            example.original,
            style: AppTypography.serifBody(
              base.bodyLarge!,
            ).copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie_outlined, size: 13, color: palette.inkTertiary),
              const SizedBox(width: 6),
              Text(
                quote.movie,
                style: AppTypography.caption(
                  base.labelSmall!,
                ).copyWith(color: palette.inkTertiary, letterSpacing: 0.06),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 台词用衬线斜体，带书卷气；保留外层引号以匹配测试断言。
          SelectableText(
            '"${quote.quote}"',
            style: AppTypography.serifQuote(
              base.bodyLarge!,
            ).copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SealTag(label: item.source, muted: true),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            item.question,
            style: AppTypography.serifBody(
              base.bodyLarge!,
            ).copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 答案区：暖纸 elevated 底 + 墨绿左边发丝线，书页批注感。
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: palette.surfaceElevated.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border(left: BorderSide(color: palette.accent, width: 2)),
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

/// 印章式标签：圆角小标签，普通态墨绿描边，muted 态朱砂描边。
class _SealTag extends StatelessWidget {
  final String label;
  final bool muted;
  const _SealTag({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    final fg = muted ? palette.inkSecondary : palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: fg.withValues(alpha: 0.4)),
        borderRadius: AppRadii.pillRadius,
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
