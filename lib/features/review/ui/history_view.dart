import 'package:flutter/material.dart';

import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../logic/review_history_controller.dart';
import '../models/review_entry.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({
    super.key,
    required this.state,
    required this.onDelete,
    required this.onClear,
    required this.onRebuild,
  });

  final ReviewHistoryState state;
  final ValueChanged<ReviewEntry> onDelete;
  final VoidCallback onClear;
  final VoidCallback onRebuild;

  @override
  Widget build(BuildContext context) {
    if (state.status == ReviewHistoryStatus.loading) {
      return const StateView.loading();
    }
    if (state.status == ReviewHistoryStatus.unavailable) {
      return UnavailableReviewView(onRebuild: onRebuild);
    }
    if (state.entries.isEmpty) {
      return const StateView.empty(message: '翻译过的单词和短语会显示在这里');
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: TextButton.icon(
              key: const ValueKey('clear-review-history'),
              onPressed: onClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('清空历史'),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            itemCount: state.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final entry = state.entries[index];
              return ReviewEntryTile(
                term: entry.identity.normalizedTerm,
                meaning: entry.latestContent.primaryMeaning,
                trailing: IconButton(
                  key: const ValueKey('delete-review-entry'),
                  tooltip: '删除记录',
                  onPressed: () => onDelete(entry),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class UnavailableReviewView extends StatelessWidget {
  const UnavailableReviewView({super.key, required this.onRebuild});

  final VoidCallback onRebuild;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StateView.error(message: '复习记录暂时不可用'),
          FilledButton.tonalIcon(
            key: const ValueKey('rebuild-review-history'),
            onPressed: onRebuild,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('安全清空并重建'),
          ),
        ],
      ),
    );
  }
}

class ReviewEntryTile extends StatelessWidget {
  const ReviewEntryTile({
    super.key,
    required this.term,
    required this.meaning,
    this.supportingText,
    this.trailing,
  });

  final String term;
  final String meaning;
  final String? supportingText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadii.mdRadius,
        border: Border.all(color: palette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    term,
                    style: AppTypography.serifBody(
                      base.titleMedium!,
                    ).copyWith(color: palette.inkPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    meaning,
                    style: AppTypography.bodyMuted(
                      base.bodyMedium!,
                    ).copyWith(color: palette.inkSecondary),
                  ),
                  if (supportingText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      supportingText!,
                      style: AppTypography.caption(
                        base.labelSmall!,
                      ).copyWith(color: palette.seal),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
