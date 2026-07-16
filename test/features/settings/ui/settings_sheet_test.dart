import 'dart:async';

import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/config/ai_config.dart';
import 'package:aitrans/core/config/settings_repository.dart';
import 'package:aitrans/core/platform/menu_bar_preference_service.dart';
import 'package:aitrans/features/settings/ui/settings_page.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:aitrans/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _openSheet(
  WidgetTester tester, {
  required AIConfig initialConfig,
  required _FakeSettingsRepository repository,
  _FakeMenuBarPreferenceService? menuBarPreferenceService,
  String? storageError,
}) async {
  // 设置页以 dialog 形式呈现：直接 pump 一个 SettingsSheet。
  // 给足视口高度，让 sheet 内容（含底部「保存」按钮）可见可点击。
  tester.view.physicalSize = const Size(1400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiConfigProvider.overrideWith((ref) => initialConfig),
        settingsRepositoryProvider.overrideWithValue(repository),
        menuBarPreferenceServiceProvider.overrideWithValue(
          menuBarPreferenceService ?? _FakeMenuBarPreferenceService(),
        ),
        initialSettingsStorageErrorProvider.overrideWithValue(storageError),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(builder: (context) => Center(child: SettingsSheet())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SettingsSheet)),
    listen: false,
  );
}

void main() {
  group('SettingsSheet', () {
    testWidgets('shows and applies the macOS menu bar visibility preference', (
      tester,
    ) async {
      final service = _FakeMenuBarPreferenceService(initialVisibility: true);
      await _openSheet(
        tester,
        initialConfig: AIConfig(providerType: ProviderType.ollama),
        repository: _FakeSettingsRepository(),
        menuBarPreferenceService: service,
      );

      expect(find.text('在状态栏显示 AITrans'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('menu-bar-visibility-switch')),
            )
            .value,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey('menu-bar-visibility-switch')),
      );
      await tester.pumpAndSettle();

      expect(service.appliedValues, [false]);
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('menu-bar-visibility-switch')),
            )
            .value,
        isFalse,
      );
    });

    testWidgets('keeps the previous menu bar value when native update fails', (
      tester,
    ) async {
      final service = _FakeMenuBarPreferenceService(
        initialVisibility: true,
        failSet: true,
      );
      await _openSheet(
        tester,
        initialConfig: AIConfig(providerType: ProviderType.ollama),
        repository: _FakeSettingsRepository(),
        menuBarPreferenceService: service,
      );

      await tester.tap(
        find.byKey(const ValueKey('menu-bar-visibility-switch')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('menu-bar-visibility-switch')),
            )
            .value,
        isTrue,
      );
      expect(find.text('无法更新状态栏设置，请重试'), findsOneWidget);
    });

    testWidgets('does not show the menu bar preference when unsupported', (
      tester,
    ) async {
      await _openSheet(
        tester,
        initialConfig: AIConfig(providerType: ProviderType.ollama),
        repository: _FakeSettingsRepository(),
        menuBarPreferenceService: _FakeMenuBarPreferenceService(
          isSupported: false,
        ),
      );

      expect(find.text('在状态栏显示 AITrans'), findsNothing);
    });

    testWidgets('lists all providers including Qwen (6 total)', (tester) async {
      await _openSheet(
        tester,
        initialConfig: AIConfig(providerType: ProviderType.ollama),
        repository: _FakeSettingsRepository(),
      );

      // 打开下拉，菜单展开后断言每一项都渲染。
      await tester.tap(find.byType(DropdownButton<ProviderType>));
      await tester.pumpAndSettle();

      for (final type in ProviderType.values) {
        final name = ProviderFactory.providerName(type);
        expect(
          find.text(name),
          findsWidgets,
          reason: 'provider item $name missing in dropdown',
        );
      }
    });

    testWidgets(
      'selecting a provider changes only the draft and loads its credential',
      (tester) async {
        final repository = _FakeSettingsRepository(
          drafts: {
            ProviderType.qwen: AIConfig(
              providerType: ProviderType.qwen,
              apiKey: 'qwen-test-key',
            ),
          },
        );
        final container = await _openSheet(
          tester,
          initialConfig: AIConfig(providerType: ProviderType.ollama),
          repository: repository,
        );

        // 打开下拉并选择 Qwen 项。
        await tester.tap(find.byType(DropdownButton<ProviderType>));
        await tester.pumpAndSettle();
        final qwenName = ProviderFactory.providerName(ProviderType.qwen);
        await tester.tap(find.text(qwenName).last);
        await tester.pumpAndSettle();

        expect(
          container.read(aiConfigProvider).providerType,
          ProviderType.ollama,
        );
        final apiKeyField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(apiKeyField.controller?.text, 'qwen-test-key');
      },
    );

    testWidgets('save persists the draft before updating global state', (
      tester,
    ) async {
      final repository = _FakeSettingsRepository();
      final container = await _openSheet(
        tester,
        initialConfig: AIConfig(
          providerType: ProviderType.qwen,
          apiKey: 'old-test-key',
          baseUrl: 'https://old.invalid/v1',
          model: 'old-model',
        ),
        repository: repository,
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'new-test-key');
      await tester.enterText(fields.at(1), '');
      await tester.enterText(fields.at(2), '');
      await tester.pumpAndSettle();

      // 收起输入焦点（enterText 后输入框持有焦点，直接点按钮会被拦截）。
      await tester.tapAt(const Offset(700, 100));
      await tester.pumpAndSettle();

      // 「保存」位于可滚动列表底部，向上拖动使其可见后再点击。
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(repository.saved, isNotNull);
      expect(repository.saved?.apiKey, 'new-test-key');
      expect(repository.saved?.baseUrl, isNull);
      expect(repository.saved?.model, isNull);
      expect(container.read(aiConfigProvider).apiKey, 'new-test-key');
      expect(container.read(aiConfigProvider).baseUrl, isNull);
      expect(container.read(aiConfigProvider).model, isNull);
    });

    testWidgets('save failure keeps the active config and draft visible', (
      tester,
    ) async {
      final repository = _FakeSettingsRepository(failSave: true);
      final container = await _openSheet(
        tester,
        initialConfig: AIConfig(providerType: ProviderType.ollama),
        repository: repository,
      );
      await tester.tap(find.byType(DropdownButton<ProviderType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qwen').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(
        container.read(aiConfigProvider).providerType,
        ProviderType.ollama,
      );
      expect(find.text('保存失败，请重试'), findsOneWidget);
    });

    testWidgets(
      'connection test uses the draft without changing active config',
      (tester) async {
        final container = await _openSheet(
          tester,
          initialConfig: AIConfig(providerType: ProviderType.ollama),
          repository: _FakeSettingsRepository(),
        );
        await tester.tap(find.byType(DropdownButton<ProviderType>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Qwen').last);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();

        await tester.tap(find.text('测试连接'));
        await tester.pumpAndSettle();

        expect(
          container.read(aiConfigProvider).providerType,
          ProviderType.ollama,
        );
        expect(find.text('连接失败，请检查配置'), findsOneWidget);
      },
    );

    testWidgets(
      'provider loading disables save and does not overwrite user input',
      (tester) async {
        final completer = Completer<AIConfig>();
        final repository = _FakeSettingsRepository(
          draftCompleters: {ProviderType.qwen: completer},
        );
        await _openSheet(
          tester,
          initialConfig: AIConfig(providerType: ProviderType.ollama),
          repository: repository,
        );

        await tester.tap(find.byType(DropdownButton<ProviderType>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Qwen').last);
        await tester.pump();

        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await tester.pump();
        final saveInkWell = tester.widget<InkWell>(
          find.ancestor(of: find.text('保存'), matching: find.byType(InkWell)),
        );
        expect(saveInkWell.onTap, isNull);

        await tester.enterText(find.byType(TextField).first, 'typed-key');
        completer.complete(
          AIConfig(providerType: ProviderType.qwen, apiKey: 'stored-key'),
        );
        await tester.pumpAndSettle();

        final apiKeyField = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(apiKeyField.controller?.text, 'typed-key');
      },
    );

    testWidgets(
      'storage failure offers an explicit confirmed credential reset',
      (tester) async {
        final repository = _FakeSettingsRepository();
        await _openSheet(
          tester,
          initialConfig: AIConfig(
            providerType: ProviderType.qwen,
            apiKey: 'runtime-key',
          ),
          repository: repository,
          storageError: '本地设置读取失败，请在设置中重试或重置凭证',
        );

        await tester.tap(find.text('重置凭证'));
        await tester.pumpAndSettle();
        expect(find.text('重置本地凭证？'), findsOneWidget);
        await tester.tap(find.text('确认重置'));
        await tester.pumpAndSettle();

        expect(repository.resetCount, 1);
        expect(find.text('本地凭证已重置'), findsOneWidget);
        expect(find.text('重置凭证'), findsNothing);
      },
    );
  });
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({
    this.drafts = const {},
    this.draftCompleters = const {},
    this.failSave = false,
  });

  final Map<ProviderType, AIConfig> drafts;
  final Map<ProviderType, Completer<AIConfig>> draftCompleters;
  final bool failSave;
  AIConfig? saved;
  int resetCount = 0;

  @override
  Future<AIConfig> load() async {
    return AIConfig(providerType: ProviderType.ollama);
  }

  @override
  Future<AIConfig> loadProviderDraft(ProviderType providerType) async {
    final completer = draftCompleters[providerType];
    if (completer != null) return completer.future;
    return drafts[providerType] ?? AIConfig(providerType: providerType);
  }

  @override
  Future<void> save(AIConfig config) async {
    if (failSave) throw StateError('synthetic settings failure');
    saved = config;
  }

  @override
  Future<void> resetCredentials() async => resetCount++;
}

class _FakeMenuBarPreferenceService implements MenuBarPreferenceService {
  _FakeMenuBarPreferenceService({
    this.isSupported = true,
    this.initialVisibility = true,
    this.failSet = false,
  });

  @override
  final bool isSupported;
  final bool initialVisibility;
  final bool failSet;
  final List<bool> appliedValues = [];

  @override
  Future<bool> getVisibility() async => initialVisibility;

  @override
  Future<void> setVisibility(bool visible) async {
    if (failSet) throw StateError('synthetic menu bar update failure');
    appliedValues.add(visible);
  }
}
