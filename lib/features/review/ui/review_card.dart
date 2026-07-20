import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/ai/review_ai_models.dart';
import '../../../shared/theme/app_tokens.dart';
import '../logic/review_queue_controller.dart';
import '../domain/review_feedback.dart';
import '../models/review_content.dart';
import '../models/review_entry.dart';
import '../services/review_content_service.dart';
import '../services/review_image_service.dart';

typedef ReviewFeedbackCallback =
    Future<bool> Function(ReviewEntry entry, ReviewFeedback feedback);

class ReviewDeck extends StatefulWidget {
  const ReviewDeck({
    super.key,
    required this.items,
    required this.contentService,
    this.imageService,
    this.onFeedback,
  });

  final List<ReviewQueueItem> items;
  final ReviewContentService contentService;
  final ReviewImageService? imageService;
  final ReviewFeedbackCallback? onFeedback;

  @override
  State<ReviewDeck> createState() => _ReviewDeckState();
}

class _ReviewDeckState extends State<ReviewDeck> {
  int _index = 0;
  bool _submittingFeedback = false;

  @override
  void didUpdateWidget(covariant ReviewDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.items.length) {
      _index = widget.items.isEmpty ? 0 : widget.items.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final item = widget.items[_index];
    return Column(
      children: [
        Expanded(
          child: ReviewCard(
            key: ValueKey(
              'review-card-${item.entry.identity.normalizedTerm}-$_index',
            ),
            entry: item.entry,
            recommendationReason: item.recommendationReason,
            contentService: widget.contentService,
            imageService: widget.imageService,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('feedback-forgotten'),
                  onPressed: _feedbackHandler(item, ReviewFeedback.forgotten),
                  child: const Text('忘记了'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('feedback-fuzzy'),
                  onPressed: _feedbackHandler(item, ReviewFeedback.fuzzy),
                  child: const Text('有点模糊'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('feedback-remembered'),
                  onPressed: _feedbackHandler(item, ReviewFeedback.remembered),
                  child: const Text('记住了'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('previous-review-card'),
                  onPressed: _index == 0
                      ? null
                      : () => setState(() => _index--),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('上一个'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('${_index + 1} / ${widget.items.length}'),
              ),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('next-review-card'),
                  onPressed: _index + 1 >= widget.items.length
                      ? null
                      : () => setState(() => _index++),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('下一个'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  VoidCallback? _feedbackHandler(
    ReviewQueueItem item,
    ReviewFeedback feedback,
  ) {
    final callback = widget.onFeedback;
    if (callback == null || _submittingFeedback) return null;
    return () async {
      setState(() => _submittingFeedback = true);
      try {
        await callback(item.entry, feedback);
      } finally {
        if (mounted) setState(() => _submittingFeedback = false);
      }
    };
  }
}

class ReviewCard extends StatefulWidget {
  const ReviewCard({
    super.key,
    required this.entry,
    required this.contentService,
    this.imageService,
    this.recommendationReason,
  });

  final ReviewEntry entry;
  final String? recommendationReason;
  final ReviewContentService contentService;
  final ReviewImageService? imageService;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  ReviewContentLoadResult? _result;
  bool _loading = true;
  int _loadRevision = 0;
  ReviewImageLoadResult? _imageResult;
  bool _imageLoading = true;
  int _imageLoadRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant ReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.identity != widget.entry.identity ||
        oldWidget.entry.generation != widget.entry.generation ||
        !identical(oldWidget.contentService, widget.contentService)) {
      _load();
    }
    if (oldWidget.entry.identity != widget.entry.identity ||
        oldWidget.entry.generation != widget.entry.generation ||
        !identical(oldWidget.imageService, widget.imageService)) {
      _loadImage();
    }
  }

  Future<void> _loadImage({bool manualRetry = false}) async {
    final revision = ++_imageLoadRevision;
    final service = widget.imageService;
    if (service == null) {
      setState(() {
        _imageLoading = false;
        _imageResult = const ReviewImageLoadResult(
          status: ReviewImageLoadStatus.fallback,
          failure: ReviewImageFailure.unsupported,
        );
      });
      return;
    }
    setState(() {
      _imageLoading = true;
      if (manualRetry) _imageResult = null;
    });
    final result = await service.load(widget.entry, manualRetry: manualRetry);
    if (!mounted || revision != _imageLoadRevision) return;
    setState(() {
      _imageLoading = false;
      _imageResult = result;
    });
  }

  Future<void> _load({bool manualRetry = false}) async {
    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      if (manualRetry) _result = null;
    });
    final result = await widget.contentService.load(
      widget.entry,
      manualRetry: manualRetry,
    );
    if (!mounted || revision != _loadRevision) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entryContent = widget.entry.latestContent;
    final palette = AppColors.of(Theme.of(context).brightness);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewImage(
                result: _imageResult,
                loading: _imageLoading,
                canRetry:
                    widget.imageService?.capability ==
                    ReviewAIImageCapability.supported,
                onRetry: () => _loadImage(manualRetry: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.entry.identity.normalizedTerm,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.inkPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                entryContent.primaryMeaning,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (entryContent.partOfSpeech != null ||
                  entryContent.pronunciation != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (entryContent.partOfSpeech case final partOfSpeech?)
                      Chip(label: Text(partOfSpeech)),
                    if (entryContent.pronunciation case final pronunciation?)
                      Chip(label: Text(pronunciation)),
                  ],
                ),
              ],
              if (entryContent.secondaryMeanings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  entryContent.secondaryMeanings.join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (widget.recommendationReason case final reason?) ...[
                const SizedBox(height: AppSpacing.md),
                Text('复习提示：$reason'),
              ],
              const Divider(height: AppSpacing.xl),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(
                      key: ValueKey('review-text-loading'),
                    ),
                  ),
                )
              else if (_result?.status == ReviewContentLoadStatus.ready &&
                  _result?.content != null)
                _GeneratedTextContent(content: _result!.content!)
              else
                _DegradedTextContent(onRetry: () => _load(manualRetry: true)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewImage extends StatelessWidget {
  const _ReviewImage({
    required this.result,
    required this.loading,
    required this.canRetry,
    required this.onRetry,
  });

  final ReviewImageLoadResult? result;
  final bool loading;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final image = result?.image;
    if (!loading &&
        result?.status == ReviewImageLoadStatus.ready &&
        image != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'AI 生成的记忆插图',
            image: true,
            child: ClipRRect(
              borderRadius: AppRadii.mdRadius,
              child: Image.memory(
                Uint8List.fromList(image.bytes),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('AI 生成插图', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    return Column(
      children: [
        Semantics(
          label: '记忆插图，当前使用主题图标',
          image: true,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: AppRadii.mdRadius,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              semanticLabel: null,
            ),
          ),
        ),
        if (loading) ...[
          const SizedBox(height: AppSpacing.xs),
          const LinearProgressIndicator(key: ValueKey('review-image-loading')),
        ] else if (canRetry &&
            result?.failure != ReviewImageFailure.unsupported) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('retry-review-image'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试插图'),
          ),
        ],
      ],
    );
  }
}

class _GeneratedTextContent extends StatelessWidget {
  const _GeneratedTextContent({required this.content});

  final ReviewTextContent content;

  @override
  Widget build(BuildContext context) {
    final movie = content.movieContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('生活常用语', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final usage in content.everydayUsages) ...[
          Text(usage.situation, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(usage.original),
          Text(usage.translation),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          movie.displayLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (movie.workTitle case final workTitle?) Text(workTitle),
        Text(movie.dialogue),
        Text(movie.translation),
        const SizedBox(height: AppSpacing.sm),
        if (movie.kind == ReviewMovieContentKind.fictionalScene)
          Text(
            'AI 创作的虚构对白，与任何真实作品无关。',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Text(
            '来源：${movie.sourceReference} · 授权：${movie.rightsReference}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _DegradedTextContent extends StatelessWidget {
  const _DegradedTextContent({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('扩展内容暂不可用，已显示保存的词义'),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('retry-review-text'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试文字内容'),
        ),
      ],
    );
  }
}
