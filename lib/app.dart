import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_tokens.dart';
import 'features/translate/ui/translate_page.dart';
import 'features/settings/ui/settings_page.dart';
import 'features/translate/logic/external_translation_coordinator.dart';
import 'features/translate/logic/translate_controller.dart';

/// 应用根组件。
class AITransApp extends ConsumerWidget {
  const AITransApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(externalTranslationPlatformBridgeProvider);
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
/// 布局自上而下两条独立的行，避免齿轮与输入条在右上角相撞：
///   1. 顶部标题栏：macOS 拖拽区 + 左侧红绿灯让位 + 右侧齿轮。
///   2. 翻译内容区（输入条 + 结果文档）。
///
/// 设置不再是常驻页面，由齿轮弹出的浮层承载。
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
    return const Scaffold(
      body: Column(
        children: [
          _TitleBar(),
          Expanded(child: TranslatePage()),
        ],
      ),
    );
  }
}

/// 顶部标题栏。
///
/// macOS 窗口为透明标题栏（titleBarStyle.hidden），内容从最顶端开始。
/// 此栏既是窗口拖拽区，又给左上红绿灯让位、把齿轮固定到右端，
/// 使齿轮与下方输入条分处两行，永不重叠。
class _TitleBar extends ConsumerWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceLanguage = ref.watch(sourceLanguageProvider);
    final targetLanguage = ref.watch(targetLanguageProvider);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 44,
        // 拖拽区作为底层背景；齿轮置于其上，确保点击不被拖拽层吞掉。
        child: Stack(
          children: [
            Positioned.fill(
              child: DragToMoveArea(child: const SizedBox.expand()),
            ),
            Positioned(
              left: 76,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  _LanguageButton(
                    language: sourceLanguage,
                    onPressed: () => _showLanguageSelector(
                      context,
                      ref,
                      isSource: true,
                      currentLanguage: sourceLanguage,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    tooltip: '交换语言',
                    onPressed: sourceLanguage == Languages.auto
                        ? null
                        : () => _swapLanguages(ref),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                  ),
                  _LanguageButton(
                    language: targetLanguage,
                    onPressed: () => _showLanguageSelector(
                      context,
                      ref,
                      isSource: false,
                      currentLanguage: targetLanguage,
                    ),
                  ),
                ],
              ),
            ),
            // 齿轮固定在右端；左上红绿灯由 macOS 自绘，宽度内隐式让位。
            const Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: _SettingsIconButton(),
            ),
          ],
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
      builder: (dialogContext) => SimpleDialog(
        title: Text(isSource ? '选择源语言' : '选择目标语言'),
        children: (isSource ? Languages.source : Languages.target)
            .map(
              (language) => SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(language),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: language == currentLanguage
                          ? const Icon(Icons.check_rounded, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(language.nativeName),
                    const SizedBox(width: 8),
                    Text(
                      language.name,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
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

  const _LanguageButton({required this.language, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    return TextButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: Icon(
        Icons.arrow_drop_down_rounded,
        size: 16,
        color: palette.inkTertiary,
      ),
      label: Text(
        language.nativeName,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: palette.inkSecondary),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SettingsIconButton extends StatelessWidget {
  const _SettingsIconButton();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    return Tooltip(
      message: '设置',
      child: IconButton(
        icon: Icon(
          Icons.settings_outlined,
          size: 20,
          color: palette.inkTertiary,
        ),
        onPressed: () => _openSettings(context),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
    );
  }

  void _openSettings(BuildContext context) {
    // 带 scrim 变暗的居中浮层。
    showDialog<void>(
      context: context,
      barrierColor: AppColors.of(Theme.of(context).brightness).scrim,
      builder: (_) => const SettingsSheet(),
    );
  }
}
