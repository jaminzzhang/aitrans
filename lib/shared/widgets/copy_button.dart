import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

/// 通用复制按钮。
///
/// 复制成功即时变 ✓ 并触发触觉反馈（同一帧），2s 复原。
/// 不弹 SnackBar——完成态以按钮自身反馈表达，避免喧宾夺主。
class CopyButton extends StatefulWidget {
  final String text;
  final String? copiedLabel;
  final String? copyLabel;

  const CopyButton({
    super.key,
    required this.text,
    this.copiedLabel,
    this.copyLabel,
  });

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    // 同帧触觉 + 视觉反馈。
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final copied = _copied;
    return _ChipButton(
      icon: Icon(
        copied ? Icons.check_rounded : Icons.copy_rounded,
        size: 15,
        color: copied ? palette.success : palette.inkSecondary,
      ),
      label: Text(
        copied ? (widget.copiedLabel ?? '已复制') : (widget.copyLabel ?? '复制'),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: copied ? palette.success : palette.inkSecondary,
        ),
      ),
      onTap: _copy,
    );
  }
}

/// 极简胶囊按钮：无填充背景、按下时轻高亮。
class _ChipButton extends StatelessWidget {
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;

  const _ChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [icon, const SizedBox(width: 5), label],
        ),
      ),
    );
  }
}
