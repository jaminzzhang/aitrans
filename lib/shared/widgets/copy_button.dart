import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

/// 通用复制按钮（描边细胶囊族）。
///
/// 复制成功即时变 ✓ 并触发触觉反馈（同一帧），墨绿实色，2s 复原。
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
    // 默认描边胶囊；已复制时切墨绿实色 + 白字。
    final fill = copied ? palette.accent : Colors.transparent;
    final fg = copied ? Colors.white : palette.inkSecondary;
    final side = copied ? BorderSide.none : BorderSide(color: palette.divider);
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.pillRadius,
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _copy,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 15,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                copied
                    ? (widget.copiedLabel ?? '已复制')
                    : (widget.copyLabel ?? '复制'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
