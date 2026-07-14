import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// 分节标题：小字、正字距，右侧可挂计数。
///
/// 用留白分组而非分割线；标题本身是层级线索。
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const SectionHeader({super.key, required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Padding(
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
            const SizedBox(width: 6),
            Text(
              '$count',
              style: AppTypography.caption(
                base.labelSmall!,
              ).copyWith(color: palette.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
