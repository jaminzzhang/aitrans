import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'input_field.dart';
import 'result_tabs.dart';

/// 翻译主页面
class TranslatePage extends ConsumerWidget {
  const TranslatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // 输入框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: const TranslateInputField(),
            ),
            Divider(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              height: 0.5,
            ),

            // 结果区域 (4个Tab: 翻译、例句、台词、真题)
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  child: ResultTabs(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
