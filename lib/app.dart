import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
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

/// 单画布外壳。
///
/// 布局自上而下两条独立的行，避免齿轮与输入条在右上角相撞：
///   1. 顶部标题栏：macOS 拖拽区 + 左侧红绿灯让位 + 右侧齿轮。
///   2. 翻译内容区（输入条 + 结果文档）。
///
/// 设置不再是常驻页面，由齿轮弹出的浮层承载。
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
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
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
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
