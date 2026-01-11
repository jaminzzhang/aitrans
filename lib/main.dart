import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/cache/translation_cache.dart';
import 'core/config/ai_config.dart';
import 'core/platform/hotkey_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 初始化 Hive
    await Hive.initFlutter();

    // 注册 Hive 适配器 (检查是否已注册)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AIConfigAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ProviderTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CachedTranslationAdapter());
    }

    // 打开 Hive boxes
    await Hive.openBox<AIConfig>('ai_config');
    await Hive.openBox<CachedTranslation>('translation_cache');
  } catch (e) {
    debugPrint('Hive initialization error: $e');
  }

  // macOS 窗口配置
  if (Platform.isMacOS) {
    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(500, 700),
        minimumSize: Size(400, 500),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: true,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      // 注册全局快捷键
      await HotkeyService().register();
    } catch (e) {
      debugPrint('Window/Hotkey initialization error: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: AITransApp(),
    ),
  );
}
