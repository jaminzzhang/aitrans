import 'package:flutter/material.dart';
import '../../../shared/theme/app_tokens.dart';
import 'command_bar.dart';
import 'result_document.dart';

/// 翻译主页面：命令条 + 滚动结果文档。
///
/// 结果区直接是滚动文档，不再外层套填充容器。
class TranslatePage extends StatelessWidget {
  const TranslatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isCompact =
        Theme.of(context).platform.isMobile ||
        MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontalPadding = isCompact ? AppSpacing.md : AppSpacing.lg;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 0),
      child: const Column(
        children: [
          CommandBar(),
          SizedBox(height: AppSpacing.sm),
          Expanded(child: ResultDocument()),
        ],
      ),
    );
  }
}
