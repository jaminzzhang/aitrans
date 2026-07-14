import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_tokens.dart';
import 'features/translate/ui/translate_page.dart';
import 'features/settings/ui/settings_page.dart';

/// 应用根组件。
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
      home: const AppShell(),
    );
  }
}

/// 单画布外壳：内容区右上角一个低调齿轮，点击弹出设置 sheet。
///
/// 取代旧 NavigationRail。设置非常驻，从齿轮锚点浮入。
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const TranslatePage(),
            Positioned(top: 4, right: 8, child: _SettingsIconButton()),
          ],
        ),
      ),
    );
  }
}

class _SettingsIconButton extends StatelessWidget {
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
    // 从齿轮锚点弹出居中浮层；带 scrim 变暗。
    showDialog<void>(
      context: context,
      barrierColor: AppColors.of(Theme.of(context).brightness).scrim,
      builder: (_) => const SettingsSheet(),
    );
  }
}
