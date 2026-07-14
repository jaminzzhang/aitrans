import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// 统一的空/加载/错误占位视图。
///
/// 替代各处重复的 empty/loading/error builder。图标 + 文案，居中，克制。
class StateView extends StatelessWidget {
  final IconData? icon;
  final String? message;
  final Color? messageColor;
  final Widget? child;

  const StateView.empty({
    super.key,
    this.icon = Icons.translate_rounded,
    required this.message,
  }) : messageColor = null,
       child = null;

  const StateView.loading({super.key})
    : icon = null,
      message = null,
      messageColor = null,
      child = null;

  const StateView.error({super.key, required this.message, this.messageColor})
    : icon = Icons.error_outline_rounded,
      child = null;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;

    if (icon == null && child == null && message == null) {
      // loading
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: palette.accent,
          ),
        ),
      );
    }

    final isError = icon == Icons.error_outline_rounded;
    final iconColor = isError ? palette.error : palette.inkTertiary;
    final textCol =
        messageColor ?? (isError ? palette.error : palette.inkTertiary);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (message != null)
              Text(
                message!,
                style: AppTypography.bodyMuted(
                  base.bodyMedium!,
                ).copyWith(color: textCol),
                textAlign: TextAlign.center,
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
