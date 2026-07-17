import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

typedef AsyncWindowAction = Future<void> Function();
typedef AsyncWindowVisibility = Future<bool> Function();

/// Coordinates the observable window behavior of the global shortcut.
class HotkeyWindowController {
  HotkeyWindowController({
    required this.isWindowVisible,
    required this.hideWindow,
    required this.captureSelection,
    required this.showWindow,
    required this.focusWindow,
  });

  final AsyncWindowVisibility isWindowVisible;
  final AsyncWindowAction hideWindow;
  final AsyncWindowAction captureSelection;
  final AsyncWindowAction showWindow;
  final AsyncWindowAction focusWindow;

  Future<bool> toggle() async {
    if (await isWindowVisible()) {
      await hideWindow();
      return false;
    }

    // Capture before activating AITrans; focusing our window would replace the
    // accessibility system's focused element and lose the external selection.
    try {
      await captureSelection();
    } catch (_) {
      // Window toggling remains available when Accessibility or the native
      // bridge cannot provide text.
    }
    await showWindow();
    await focusWindow();
    return true;
  }
}

class HotkeySelectionCaptureService {
  static const _channel = MethodChannel('com.aitrans/hotkey_selection');

  Future<void> capture() async {
    await _channel.invokeMethod<bool>('captureSelection');
  }
}

/// 快捷键服务 (仅 macOS)
class HotkeyService {
  static final HotkeyService _instance = HotkeyService._internal();
  factory HotkeyService() => _instance;
  HotkeyService._internal();

  VoidCallback? _onToggleWindow;

  late final HotkeyWindowController _windowController = HotkeyWindowController(
    isWindowVisible: windowManager.isVisible,
    hideWindow: windowManager.hide,
    captureSelection: HotkeySelectionCaptureService().capture,
    showWindow: windowManager.show,
    focusWindow: windowManager.focus,
  );

  /// 设置窗口切换回调
  void setToggleWindowCallback(VoidCallback callback) {
    _onToggleWindow = callback;
  }

  /// 注册全局快捷键
  Future<void> register() async {
    if (!Platform.isMacOS) return;

    // Cmd + Shift + T: 唤起/隐藏窗���
    final hotkey = HotKey(
      key: PhysicalKeyboardKey.keyT,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      hotkey,
      keyDownHandler: (hotKey) async {
        await _toggleWindow();
      },
    );
  }

  /// 取消注册
  Future<void> unregister() async {
    await hotKeyManager.unregisterAll();
  }

  /// 切换窗口显示/隐藏
  Future<void> _toggleWindow() async {
    final didOpen = await _windowController.toggle();
    if (didOpen) {
      _onToggleWindow?.call();
    }
  }
}

/// 窗口管理服务
class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  /// 初始化窗口配置 (仅 macOS)
  Future<void> init() async {
    if (!Platform.isMacOS) return;

    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(500, 700),
      minimumSize: Size(400, 500),
      center: true,
      backgroundColor: Color(0x00000000),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  /// 设置始终置顶
  Future<void> setAlwaysOnTop(bool value) async {
    if (!Platform.isMacOS) return;
    await windowManager.setAlwaysOnTop(value);
  }

  /// 显示窗口
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// 隐藏窗口
  Future<void> hide() async {
    await windowManager.hide();
  }
}
