import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'app.dart';
import 'core/cache/translation_cache.dart';
import 'core/config/ai_config.dart';
import 'core/config/settings_preferences_store.dart';
import 'core/config/settings_repository.dart';
import 'core/platform/hotkey_service.dart';
import 'core/platform/local_storage_bootstrap.dart';
import 'core/platform/local_storage_protection.dart';
import 'core/security/encrypted_provider_credential_store.dart';
import 'core/security/local_master_key_store.dart';
import 'core/ai/provider_factory.dart';
import 'features/translate/logic/translate_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SettingsRepository settingsRepository = const UnavailableSettingsRepository();
  AIConfig initialConfig = AIConfig(providerType: ProviderType.ollama);
  String? settingsStorageError;
  var hiveReady = false;
  late Directory storageDirectory;

  try {
    storageDirectory = await LocalStorageBootstrap(
      getApplicationSupportDirectory: getApplicationSupportDirectory,
      initializeHive: Hive.init,
    ).initialize();

    // 注册 Hive 适配器 (检查是否已注册)
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CachedTranslationAdapter());
    }
    hiveReady = true;
  } catch (_) {
    debugPrint('Local database initialization failed.');
  }

  if (hiveReady) {
    try {
      await Hive.openBox<CachedTranslation>('translation_cache');
    } catch (_) {
      debugPrint('Translation cache initialization failed.');
    }

    try {
      final preferencesBox = await Hive.openBox<dynamic>(
        'settings_preferences',
      );
      final credentialsBox = await Hive.openBox<dynamic>(
        'provider_credentials',
      );
      final keyFile = File('${storageDirectory.path}/.aitrans.provider.key');
      await const LocalStorageProtection().excludeFromBackup([
        storageDirectory.path,
        if (credentialsBox.path != null) credentialsBox.path!,
      ]);
      final settingsStore = EncryptedProviderCredentialStore(
        credentialsBox,
        LocalMasterKeyStore(keyFile),
        legacyPreferences: HiveSettingsPreferencesStore(preferencesBox),
      );
      settingsRepository = PersistentSettingsRepository(settingsStore);
      initialConfig = await settingsRepository.load();
    } catch (_) {
      settingsStorageError = '本地设置读取失败，请在设置中重试或重置凭证';
      debugPrint('Local settings initialization failed.');
    }
  }

  // macOS 窗口配置
  if (Platform.isMacOS) {
    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(800, 450),
        minimumSize: Size(400, 225),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setTitle('');
        await windowManager.show();
        await windowManager.focus();
      });

      // 设置玻璃效果 (macOS 原生材质)
      await WindowManipulator.initialize();
      await WindowManipulator.makeTitlebarTransparent();
      await WindowManipulator.enableFullSizeContentView();
      await WindowManipulator.setMaterial(
        NSVisualEffectViewMaterial.underWindowBackground,
      );

      // 注册全局快捷键
      await HotkeyService().register();
    } catch (e) {
      debugPrint('Window/Hotkey initialization error: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        initialAIConfigProvider.overrideWithValue(initialConfig),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        initialSettingsStorageErrorProvider.overrideWithValue(
          settingsStorageError,
        ),
      ],
      child: const AITransApp(),
    ),
  );
}
