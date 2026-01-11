import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'input_field.dart';
import 'auxiliary_tabs.dart';

/// 翻译主页面
class TranslatePage extends ConsumerWidget {
  const TranslatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 输入框
              const TranslateInputField(),
              const SizedBox(height: 16),

              // 结果区域 (4个Tab: 翻译、例句、台词、真题)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
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
      ),
    );
  }
}
