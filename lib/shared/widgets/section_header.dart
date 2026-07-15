import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// 分节标题：衬线小字、正字距，右侧可挂朱砂计数，下方暖纸发丝细线。
///
/// 用留白分组而非硬分割线；标题本身是层级线索，下方极淡发丝线呼应出版物分节。
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const SectionHeader({super.key, required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                title,
                style: AppTypography.sectionHeader(
                  base.titleMedium!,
                ).copyWith(color: palette.inkSecondary),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: AppTypography.caption(
                    base.labelSmall!,
                  ).copyWith(color: palette.seal),
                ),
              ],
            ],
          ),
        ),
        // 暖纸发丝细线：极淡，仅作分节呼吸的视觉锚点。
        Container(height: 0.5, color: palette.divider),
      ],
    );
  }
}
