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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
  int _currentIndex = 0;

  final _pages = const [
    TranslatePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // 侧边导航栏 (macOS风格)
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: theme.colorScheme.surface,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.translate_outlined),
                selectedIcon: Icon(Icons.translate),
                label: Text('翻译'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          // 页面内容
          Expanded(
            child: _pages[_currentIndex],
          ),
        ],
      ),
    );
  }
}
