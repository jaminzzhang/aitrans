import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/theme/app_theme.dart';
import 'features/translate/ui/translate_page.dart';
import 'features/settings/ui/settings_page.dart';
import 'features/translate/logic/translate_controller.dart';

/// 应用根组件
class AITransApp extends ConsumerWidget {
  const AITransApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'AITrans',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      darkTheme: AppTheme.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      themeMode: ThemeMode.system,
      home: const MainPage(),
    );
  }
}

/// 主页面 (包含导航)
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  bool _isSettingsOpen = false;

  void _openSettings() {
    if (_isSettingsOpen) return;
    _isSettingsOpen = true;

    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    ).then((_) {
      _isSettingsOpen = false;
    });
  }

  void _showLanguageSelector({
    required bool isSource,
    required Language currentLanguage,
  }) {
    final languages = isSource ? Languages.sourceLanguages : Languages.targetLanguages;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(isSource ? '选择源语言' : '选择目标语言'),
        children: languages.map((lang) {
          final isSelected = lang == currentLanguage;
          return SimpleDialogOption(
            onPressed: () {
              if (isSource) {
                ref.read(sourceLanguageProvider.notifier).state = lang;
              } else {
                ref.read(targetLanguageProvider.notifier).state = lang;
              }
              Navigator.of(context).pop();
            },
            child: Row(
              children: [
                if (isSelected)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(lang.nativeName),
                const SizedBox(width: 8),
                Text(
                  lang.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _swapLanguages() {
    final source = ref.read(sourceLanguageProvider);
    final target = ref.read(targetLanguageProvider);

    // 如果源语言是自动检测，不能交换
    if (source == Languages.auto) return;

    ref.read(sourceLanguageProvider.notifier).state = target;
    ref.read(targetLanguageProvider.notifier).state = source;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceLanguage = ref.watch(sourceLanguageProvider);
    final targetLanguage = ref.watch(targetLanguageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 页面内容
          const Expanded(
            child: TranslatePage(),
          ),
          // 底部栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                // 语言选择器
                _LanguageButton(
                  language: sourceLanguage,
                  onTap: () => _showLanguageSelector(
                    isSource: true,
                    currentLanguage: sourceLanguage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  onPressed: sourceLanguage == Languages.auto ? null : _swapLanguages,
                  tooltip: '交换语言',
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
                _LanguageButton(
                  language: targetLanguage,
                  onTap: () => _showLanguageSelector(
                    isSource: false,
                    currentLanguage: targetLanguage,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _openSettings,
                  tooltip: '设置',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 语言选择按钮
class _LanguageButton extends StatelessWidget {
  final Language language;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.language,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              language.nativeName,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置弹窗
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            AppBar(
              title: const Text('设置'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Expanded(child: SettingsPage()),
          ],
        ),
      ),
    );
  }
}

