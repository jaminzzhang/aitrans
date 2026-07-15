import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_tokens.dart';
import '../logic/translate_controller.dart';

/// 顶部命令条：暖纸毛玻璃材质 + 搜索图标 + 输入 + 内联翻译/清空。
///
/// 替代旧 TranslateInputField。保留现有 controller 接入（防抖、translateNow、
/// loadContent、Cmd+K 清空），只重构视觉。修复旧代码每次 build 新建 FocusNode 的 bug。
class CommandBar extends ConsumerStatefulWidget {
  const CommandBar({super.key});

  @override
  ConsumerState<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends ConsumerState<CommandBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(inputTextProvider.notifier).state = value;
    ref.read(translateControllerProvider.notifier).onTextChanged(value);
  }

  void _onSubmitted(String value) {
    ref.read(translateControllerProvider.notifier).translateNow(value);
    ref.read(auxiliaryControllerProvider.notifier).loadContent(value);
  }

  void _clear() {
    _controller.clear();
    ref.read(inputTextProvider.notifier).state = '';
    ref.read(translateControllerProvider.notifier).clear();
    ref.read(auxiliaryControllerProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  void _syncExternalInput(String inputText) {
    if (_controller.text == inputText) return;
    _controller.value = TextEditingValue(
      text: inputText,
      selection: TextSelection.collapsed(offset: inputText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    final inputText = ref.watch(inputTextProvider);
    _syncExternalInput(inputText);
    // Android 退化：BackdropFilter 在低端机掉帧，改纯色 + 亮边。
    final useBlur = !Platform.isAndroid;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _clear,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _clear,
      },
      child: Container(
        decoration: BoxDecoration(
          color: useBlur ? palette.materialBar : palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border(
            top: BorderSide(color: palette.materialTopEdge, width: 1),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Stack(
            children: [
              if (useBlur)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: const SizedBox.expand(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: palette.inkTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        focusNode: _focusNode,
                        controller: _controller,
                        onChanged: _onChanged,
                        onSubmitted: _onSubmitted,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.search,
                        style: AppTypography.input(
                          base.bodyLarge!,
                        ).copyWith(color: palette.inkPrimary),
                        decoration: InputDecoration(
                          hintText: '输入要翻译的文本…',
                          hintStyle: AppTypography.input(
                            base.bodyLarge!,
                          ).copyWith(color: palette.inkTertiary),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                    if (inputText.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _IconAction(
                        icon: Icons.close_rounded,
                        onTap: _clear,
                        tooltip: '清空 (⌘K)',
                      ),
                    ],
                    const SizedBox(width: AppSpacing.xs),
                    _TranslateChip(onSubmit: () => _onSubmitted(inputText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: palette.inkTertiary),
        ),
      ),
    );
  }
}

/// 翻译主胶囊：墨绿填充 + 白字，主操作。
class _TranslateChip extends StatelessWidget {
  final VoidCallback onSubmit;
  const _TranslateChip({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Material(
      color: palette.accent,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onSubmit,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '翻译',
                style: AppTypography.caption(base.labelMedium!).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.06,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.keyboard_return_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
