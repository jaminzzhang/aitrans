import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/theme/app_theme.dart';
import 'features/translate/ui/translate_page.dart';
import 'features/settings/ui/settings_page.dart';

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
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}


class _MainPageState extends State<MainPage> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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

