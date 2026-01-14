import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/translate_controller.dart';

/// 输入框组件
class TranslateInputField extends ConsumerStatefulWidget {
  const TranslateInputField({super.key});

  @override
  ConsumerState<TranslateInputField> createState() =>
      _TranslateInputFieldState();
}

class _TranslateInputFieldState extends ConsumerState<TranslateInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 自动聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
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
    // 加载辅助内容
    ref.read(auxiliaryControllerProvider.notifier).loadContent(value);
  }

  void _clear() {
    _controller.clear();
    ref.read(inputTextProvider.notifier).state = '';
    ref.read(translateControllerProvider.notifier).clear();
    ref.read(auxiliaryControllerProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputText = ref.watch(inputTextProvider);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        // Cmd+K 或 Ctrl+K 清空
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyK &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          _clear();
        }
      },
      child: Container(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                onSubmitted: _onSubmitted,
                maxLines: 3,
                minLines: 1,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: '输入要翻译的文本...',
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(0),
                ),
              ),
            ),
            if (inputText.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: _clear,
                tooltip: '清空 (Cmd+K)',
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// 全局输入焦点通知器 (用于快捷键唤起时聚焦)
class InputFocusNotifier extends ChangeNotifier {
  void requestFocus() {
    notifyListeners();
  }
}

final inputFocusNotifierProvider = Provider<InputFocusNotifier>((ref) {
  return InputFocusNotifier();
});
