import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../logic/review_history_controller.dart';
import '../logic/review_providers.dart';
import '../models/review_entry.dart';
import '../services/review_content_service.dart';
import '../services/review_image_service.dart';
import 'history_view.dart';
import 'review_card.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  bool _privacyNoticeScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(reviewHistoryControllerProvider.notifier).loadTodayGroup();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final state = ref.watch(reviewHistoryControllerProvider);
    _schedulePrivacyNotice(state);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: const ValueKey('review-page'),
        backgroundColor: palette.bg,
        appBar: AppBar(
          backgroundColor: palette.bg,
          foregroundColor: palette.inkPrimary,
          title: const Text('复习'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '今日复习'),
              Tab(text: '历史记录'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TodayReviewView(
              state: state,
              contentService: ref.watch(reviewContentServiceProvider),
              imageService: ref.watch(reviewImageServiceProvider),
              onFeedback: (entry, feedback) => ref
                  .read(reviewHistoryControllerProvider.notifier)
                  .submitFeedback(entry, feedback),
              onLoadNextGroup: () => ref
                  .read(reviewHistoryControllerProvider.notifier)
                  .loadTodayGroup(),
              onRebuild: _confirmRebuild,
            ),
            HistoryView(
              state: state,
              onDelete: _confirmDelete,
              onClear: _confirmClear,
              onRebuild: _confirmRebuild,
            ),
          ],
        ),
      ),
    );
  }

  void _schedulePrivacyNotice(ReviewHistoryState state) {
    if (_privacyNoticeScheduled ||
        state.status == ReviewHistoryStatus.loading ||
        !state.preferencesAvailable ||
        state.privacyNoticeAcknowledged) {
      return;
    }
    _privacyNoticeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final disableCapture = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('关于复习记录'),
          content: const Text(
            'AITrans 会在本机加密保存符合条件的单词和短语，长句不会记录。'
            '你可以随时关闭自动记录、单独删除或清空历史。'
            '易忘排序只向当前 AI 服务发送必要摘要。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('关闭自动记录'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('了解并继续'),
            ),
          ],
        ),
      );
      if (!mounted || disableCapture == null) return;
      final saved = await ref
          .read(reviewHistoryControllerProvider.notifier)
          .acknowledgePrivacy(disableCapture: disableCapture);
      if (!saved && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('复习设置无法保存，已暂停自动记录')));
      }
    });
  }

  Future<void> _confirmDelete(ReviewEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('这会同时删除该词条的复习进度和派生内容，且无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await ref
        .read(reviewHistoryControllerProvider.notifier)
        .deleteEntry(entry.identity);
    if (!deleted && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法删除复习记录，请重试')));
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部复习记录？'),
        content: const Text('所有历史、复习进度和派生内容都会被安全删除，且无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cleared = await ref
        .read(reviewHistoryControllerProvider.notifier)
        .clearHistory();
    if (!cleared && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法清空复习记录，请重试')));
    }
  }

  Future<void> _confirmRebuild() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('安全清空并重建？'),
        content: const Text('现有复习密文和派生内容会被删除，并重新建立本地安全存储。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认重建'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final rebuilt = await ref
        .read(reviewHistoryControllerProvider.notifier)
        .secureRebuild();
    if (!rebuilt && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('安全存储仍不可用，请稍后重试')));
    }
  }
}

class _TodayReviewView extends StatelessWidget {
  const _TodayReviewView({
    required this.state,
    required this.contentService,
    required this.imageService,
    required this.onFeedback,
    required this.onLoadNextGroup,
    required this.onRebuild,
  });

  final ReviewHistoryState state;
  final ReviewContentService contentService;
  final ReviewImageService imageService;
  final ReviewFeedbackCallback onFeedback;
  final VoidCallback onLoadNextGroup;
  final VoidCallback onRebuild;

  @override
  Widget build(BuildContext context) {
    if (state.status == ReviewHistoryStatus.loading || state.isLoadingGroup) {
      return const StateView.loading();
    }
    if (state.status == ReviewHistoryStatus.unavailable) {
      return UnavailableReviewView(onRebuild: onRebuild);
    }
    final items = state.group?.items ?? const [];
    if (state.groupCompleted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('本组复习完成'),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('next-review-group'),
              onPressed: onLoadNextGroup,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始下一组'),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return const StateView.empty(message: '今天没有需要复习的内容');
    }
    return ReviewDeck(
      items: items,
      contentService: contentService,
      imageService: imageService,
      onFeedback: onFeedback,
    );
  }
}
