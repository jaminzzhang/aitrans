import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_tokens.dart';
import 'features/translate/ui/translate_page.dart';
import 'features/settings/ui/settings_page.dart';
import 'features/review/ui/review_page.dart';
import 'features/review/logic/review_providers.dart';
import 'features/translate/logic/external_translation_coordinator.dart';
import 'features/translate/logic/translate_controller.dart';
import 'core/platform/application_command_platform_bridge.dart';
import 'features/app/logic/application_command_coordinator.dart';
import 'features/translate/logic/translation_input_focus.dart';

/// 应用根组件。
class AITransApp extends ConsumerWidget {
  const AITransApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(externalTranslationPlatformBridgeProvider);
    ref.watch(applicationCommandPlatformBridgeProvider);
    return MaterialApp(
      title: 'AITrans',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

/// 单画布外壳。
///
/// 布局自上而下三段，让译文区成为绝对主角：
///   1. 顶部拖拽区：仅 macOS 窗口拖拽 + 红绿灯让位，无功能控件。
///   2. 翻译内容区（输入条 + 结果文档）。
///   3. 底部悬浮胶囊工具条：语言切换 + 设置，沉到底部、低视觉权重。
///
/// 语言切换和设置不再是顶部常驻控件，由底部胶囊承载。
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ExternalTranslationHandlingState>(
      externalTranslationCoordinatorProvider,
      (previous, next) {
        if (next is ExternalTranslationAccepted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        }
        if (next case ExternalTranslationRejected(:final userMessage?)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(userMessage)));
        }
      },
    );
    ref.listen<ExternalTranslationBridgeStatus>(
      externalTranslationBridgeStatusProvider,
      (previous, next) {
        if (next == ExternalTranslationBridgeStatus.unavailable) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('无法启用系统翻译服务，请重新启动 AITrans。')),
            );
        }
      },
    );
    ref.listen<ApplicationCommandEvent?>(applicationCommandEventProvider, (
      previous,
      next,
    ) {
      if (next == null) return;
      _handleApplicationCommand(context, ref, next.command);
    });
    ref.listen<ApplicationCommandBridgeStatus>(
      applicationCommandBridgeStatusProvider,
      (previous, next) {
        if (next == ApplicationCommandBridgeStatus.unavailable) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('无法启用状态栏菜单，请重新启动 AITrans。')),
            );
        }
      },
    );
    final platform = Theme.of(context).platform;
    final isMacOS = platform == TargetPlatform.macOS;
    final isMobile = platform.isMobile;
    return Scaffold(
      key: ValueKey(isMobile ? 'mobile-app-shell' : 'desktop-app-shell'),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: isMobile,
        bottom: false,
        child: Column(
          children: [
            if (isMacOS) const _TitleBar(),
            const Expanded(child: TranslatePage()),
            const _BottomToolBar(),
          ],
        ),
      ),
    );
  }

  void _handleApplicationCommand(
    BuildContext context,
    WidgetRef ref,
    ApplicationCommand command,
  ) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
    switch (command) {
      case ApplicationCommand.showTranslation:
        ref.read(translationInputFocusRequestProvider.notifier).state++;
      case ApplicationCommand.showSettings:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) showAITransSettingsDialog(context);
        });
    }
  }
}

/// 顶部拖拽区。
///
/// macOS 窗口为透明标题栏（titleBarStyle.hidden），内容从最顶端开始。
/// 此区仅作窗口拖拽 + 左上红绿灯让位，不再承载任何功能控件，
/// 使译文区可以延伸到最顶端，成为视觉主角。
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 16,
        // 拖拽区占满整栏；红绿灯由 macOS 自绘，宽度内隐式让位。
        // 收窄到 16：仅保留最小拖拽热区与红绿灯让位。
        child: DragToMoveArea(child: const SizedBox.expand()),
      ),
    );
  }
}

/// 底部悬浮胶囊工具条。
///
/// 语言切换（源 ↔ 目标 + 交换）与设置齿轮沉到窗口底部，居中悬浮的描边胶囊
/// 承载，与译文区用留白分离，像浮在纸面上的印章，视觉权重极低。
class _BottomToolBar extends ConsumerWidget {
  const _BottomToolBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceLanguage = ref.watch(sourceLanguageProvider);
    final targetLanguage = ref.watch(targetLanguageProvider);
    final palette = AppColors.of(Theme.of(context).brightness);
    final isCompact =
        Theme.of(context).platform.isMobile ||
        MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final isNarrow = MediaQuery.sizeOf(context).width < 360;
    final languageControls = <Widget>[
      _LanguageButton(
        key: const ValueKey('source-language-button'),
        language: sourceLanguage,
        isCompact: isCompact,
        onPressed: () => _showLanguageSelector(
          context,
          ref,
          isSource: true,
          currentLanguage: sourceLanguage,
        ),
      ),
      IconButton(
        key: const ValueKey('swap-language-button'),
        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
        tooltip: '交换语言',
        onPressed: sourceLanguage == Languages.auto
            ? null
            : () => _swapLanguages(ref),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? AppSpacing.sm : 2,
        ),
        constraints: isCompact
            ? const BoxConstraints.tightFor(
                width: AppTouchTargets.mobile,
                height: AppTouchTargets.mobile,
              )
            : const BoxConstraints(),
        color: palette.inkTertiary,
      ),
      _LanguageButton(
        key: const ValueKey('target-language-button'),
        language: targetLanguage,
        isCompact: isCompact,
        onPressed: () => _showLanguageSelector(
          context,
          ref,
          isSource: false,
          currentLanguage: targetLanguage,
        ),
      ),
    ];
    final actionControls = <Widget>[
      _ReviewIconButton(isCompact: isCompact),
      _SettingsIconButton(isCompact: isCompact),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isCompact ? AppSpacing.sm + 2 : AppSpacing.md,
          AppSpacing.sm,
          isCompact ? AppSpacing.sm + 2 : AppSpacing.md,
          AppSpacing.md,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            // 描边胶囊：暖纸半透明底 + 发丝描边 + 极淡投影，浮在纸面感。
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.82),
                borderRadius: AppRadii.pillRadius,
                border: Border.all(color: palette.divider),
                boxShadow: [
                  BoxShadow(
                    color: palette.inkPrimary.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? AppSpacing.sm : AppSpacing.sm + 2,
                  vertical: AppSpacing.xs + 1,
                ),
                child: isNarrow
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: languageControls,
                          ),
                          Container(
                            width: 96,
                            height: 0.5,
                            color: palette.divider,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actionControls,
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...languageControls,
                          // 发丝竖分隔：语言区与功能入口之间的极淡呼吸。
                          Container(
                            width: 0.5,
                            height: 16,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            color: palette.divider,
                          ),
                          ...actionControls,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageSelector(
    BuildContext context,
    WidgetRef ref, {
    required bool isSource,
    required Language currentLanguage,
  }) async {
    final selected = await showDialog<Language>(
      context: context,
      builder: (dialogContext) {
        final palette = AppColors.of(Theme.of(dialogContext).brightness);
        final base = Theme.of(dialogContext).textTheme;
        return SimpleDialog(
          title: Text(
            isSource ? '选择源语言' : '选择目标语言',
            style: AppTypography.editorial(
              base.titleLarge!,
            ).copyWith(fontSize: 18, color: palette.inkPrimary),
          ),
          children: (isSource ? Languages.source : Languages.target)
              .map(
                (language) => SimpleDialogOption(
                  onPressed: () => Navigator.of(dialogContext).pop(language),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: language == currentLanguage
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: palette.seal,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      // 语言名用衬线，呼应译文区书卷气。
                      Text(
                        language.nativeName,
                        style: AppTypography.serifBody(
                          base.bodyLarge!,
                        ).copyWith(color: palette.inkPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        language.name,
                        style: AppTypography.caption(
                          base.labelSmall!,
                        ).copyWith(color: palette.inkTertiary),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
    if (selected == null || selected == currentLanguage) return;

    if (isSource) {
      ref.read(sourceLanguageProvider.notifier).state = selected;
    } else {
      ref.read(targetLanguageProvider.notifier).state = selected;
    }
    _retranslateCurrentInput(ref);
  }

  void _swapLanguages(WidgetRef ref) {
    final source = ref.read(sourceLanguageProvider);
    if (source == Languages.auto) return;
    final target = ref.read(targetLanguageProvider);
    ref.read(sourceLanguageProvider.notifier).state = target;
    ref.read(targetLanguageProvider.notifier).state = source;
    _retranslateCurrentInput(ref);
  }

  void _retranslateCurrentInput(WidgetRef ref) {
    final input = ref.read(inputTextProvider);
    if (input.trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(translateControllerProvider.notifier).translateNow(input);
    });
  }
}

class _LanguageButton extends StatelessWidget {
  final Language language;
  final VoidCallback onPressed;
  final bool isCompact;

  const _LanguageButton({
    super.key,
    required this.language,
    required this.onPressed,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return TextButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: Icon(
        Icons.arrow_drop_down_rounded,
        size: 16,
        color: palette.inkTertiary,
      ),
      // 语言名用衬线，呼应译文区书卷气。
      label: Text(
        language.nativeName,
        style: AppTypography.serifSubtitle(
          base.labelMedium!,
        ).copyWith(color: palette.inkSecondary),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size(0, isCompact ? AppTouchTargets.mobile : 30),
        tapTargetSize: isCompact
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SettingsIconButton extends StatelessWidget {
  final bool isCompact;

  const _SettingsIconButton({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    return Tooltip(
      message: '设置',
      child: IconButton(
        key: const ValueKey('settings-button'),
        icon: Icon(
          Icons.settings_outlined,
          size: 20,
          color: palette.inkTertiary,
        ),
        onPressed: () => showAITransSettingsDialog(context),
        constraints: isCompact
            ? const BoxConstraints.tightFor(
                width: AppTouchTargets.mobile,
                height: AppTouchTargets.mobile,
              )
            : null,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
    );
  }
}

class _ReviewIconButton extends ConsumerWidget {
  const _ReviewIconButton({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final dueCount = ref.watch(
      reviewHistoryControllerProvider.select((state) => state.dueCount),
    );
    return Tooltip(
      message: '复习',
      child: IconButton(
        key: const ValueKey('review-button'),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 20,
              color: palette.inkTertiary,
            ),
            if (dueCount > 0)
              Positioned(
                key: const ValueKey('review-badge'),
                right: -10,
                top: -9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.seal,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    child: Text(
                      dueCount > 99 ? '99+' : '$dueCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        onPressed: () => showAITransReviewPage(context),
        constraints: isCompact
            ? const BoxConstraints.tightFor(
                width: AppTouchTargets.mobile,
                height: AppTouchTargets.mobile,
              )
            : null,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
    );
  }
}

Future<void> showAITransReviewPage(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const ReviewPage(),
    ),
  );
}

Future<void> showAITransSettingsDialog(BuildContext context) {
  final isMobile = Theme.of(context).platform.isMobile;
  final isCompact =
      isMobile || MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
  if (isCompact) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const Material(child: SettingsSheet()),
      ),
    );
  }

  // 桌面保留带 scrim 变暗的居中浮层。
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.of(Theme.of(context).brightness).scrim,
    builder: (_) => const SettingsSheet(),
  );
}
