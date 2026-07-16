import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/provider_factory.dart';
import '../../../core/config/ai_config.dart';
import '../../../core/platform/menu_bar_preference_service.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../translate/logic/translate_controller.dart';

/// 设置浮层（作为 Dialog 呈现）。
///
/// 从齿轮锚点浮入，带 scrim 变暗；Esc 原路关闭。
/// provider 列表数据驱动：遍历 ProviderType.values，显示名与默认值取自工厂，
/// 不再手写易漂移的重复默认值表。
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _isTestingConnection = false;
  bool _isSaving = false;
  bool _isResettingCredentials = false;
  bool _isLoadingProvider = false;
  bool _credentialEditedWhileLoading = false;
  bool? _menuBarVisible;
  bool _isChangingMenuBarVisibility = false;
  String? _menuBarVisibilityError;
  int _providerLoadGeneration = 0;
  String? _connectionStatus;
  bool _connectionOk = false;
  late ProviderType _selectedProvider;
  late final MenuBarPreferenceService _menuBarPreferenceService;
  final Map<ProviderType, AIConfig> _drafts = {};

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiConfigProvider);
    _selectedProvider = config.providerType;
    _apiKeyController.text = config.apiKey ?? '';
    _baseUrlController.text = config.baseUrl ?? '';
    _modelController.text = config.model ?? '';
    _drafts[config.providerType] = config;
    _menuBarPreferenceService = ref.read(menuBarPreferenceServiceProvider);
    if (_menuBarPreferenceService.isSupported) {
      _loadMenuBarVisibility();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// 从工厂解析默认值作为 hint（单一来源，避免与工厂漂移）。
  String _defaultHint(
    ProviderType type,
    String Function(AIEndpointConfig) pick,
  ) {
    try {
      return pick(ProviderFactory.resolveConfig(AIConfig(providerType: type)));
    } catch (_) {
      return '';
    }
  }

  Future<void> _testConnection() async {
    if (_isLoadingProvider) return;
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });
    AIProvider? provider;
    try {
      provider = ProviderFactory.create(_buildDraft());
      final ok = await provider.testConnection();
      if (!mounted) return;
      setState(() {
        _connectionOk = ok;
        _connectionStatus = ok ? '连接成功' : '连接失败';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connectionOk = false;
        // 不向用户暴露原始异常/路径，给出友好提示。
        _connectionStatus = '连接失败，请检查配置';
      });
    } finally {
      provider?.close();
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  AIConfig _buildDraft() {
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    return AIConfig(
      providerType: _selectedProvider,
      apiKey: _apiKeyController.text,
      baseUrl: baseUrl.isEmpty ? null : baseUrl,
      model: model.isEmpty ? null : model,
    );
  }

  Future<void> _selectProvider(ProviderType type) async {
    if (type == _selectedProvider) return;
    _drafts[_selectedProvider] = _buildDraft();
    final generation = ++_providerLoadGeneration;
    setState(() {
      _selectedProvider = type;
      _connectionStatus = null;
      _credentialEditedWhileLoading = false;
    });

    final cached = _drafts[type];
    if (cached != null) {
      _applyDraft(cached);
      return;
    }

    setState(() => _isLoadingProvider = true);
    _baseUrlController.clear();
    _modelController.clear();
    _apiKeyController.clear();

    try {
      final draft = await ref
          .read(settingsRepositoryProvider)
          .loadProviderDraft(type);
      if (!mounted ||
          _selectedProvider != type ||
          generation != _providerLoadGeneration) {
        return;
      }
      if (!_credentialEditedWhileLoading) {
        _apiKeyController.text = draft.apiKey ?? '';
      }
      _drafts[type] = _buildDraft();
    } catch (_) {
      if (!mounted ||
          _selectedProvider != type ||
          generation != _providerLoadGeneration) {
        return;
      }
      setState(() {
        _connectionOk = false;
        _connectionStatus = '凭证读取失败，请重试';
      });
    } finally {
      if (mounted &&
          _selectedProvider == type &&
          generation == _providerLoadGeneration) {
        setState(() => _isLoadingProvider = false);
      }
    }
  }

  void _applyDraft(AIConfig draft) {
    _apiKeyController.text = draft.apiKey ?? '';
    _baseUrlController.text = draft.baseUrl ?? '';
    _modelController.text = draft.model ?? '';
    if (mounted) setState(() => _isLoadingProvider = false);
  }

  Future<void> _loadMenuBarVisibility() async {
    try {
      final visible = await _menuBarPreferenceService.getVisibility();
      if (!mounted) return;
      setState(() {
        _menuBarVisible = visible;
        _menuBarVisibilityError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _menuBarVisibilityError = '无法读取状态栏设置，请重试';
      });
    }
  }

  Future<void> _setMenuBarVisibility(bool visible) async {
    if (_isChangingMenuBarVisibility || _menuBarVisible == null) return;
    setState(() {
      _isChangingMenuBarVisibility = true;
      _menuBarVisibilityError = null;
    });
    try {
      await _menuBarPreferenceService.setVisibility(visible);
      if (!mounted) return;
      setState(() => _menuBarVisible = visible);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _menuBarVisibilityError = '无法更新状态栏设置，请重试';
      });
    } finally {
      if (mounted) {
        setState(() => _isChangingMenuBarVisibility = false);
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving || _isLoadingProvider) return;
    final draft = _buildDraft();
    setState(() {
      _isSaving = true;
      _connectionStatus = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).save(draft);
      if (!mounted) return;
      ref.read(aiConfigProvider.notifier).state = draft;
      ref.read(settingsStorageErrorProvider.notifier).state = null;
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connectionOk = false;
        _connectionStatus = '保存失败，请重试';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetCredentials() async {
    if (_isResettingCredentials) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置本地凭证？'),
        content: const Text('这会删除所有本地 API Key。Provider、Base URL 和模型设置会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResettingCredentials = true);
    try {
      await ref.read(settingsRepositoryProvider).resetCredentials();
      if (!mounted) return;
      _apiKeyController.clear();
      _drafts.clear();
      final current = ref.read(aiConfigProvider);
      final resetConfig = AIConfig(
        providerType: current.providerType,
        baseUrl: current.baseUrl,
        model: current.model,
      );
      _drafts[current.providerType] = resetConfig;
      ref.read(aiConfigProvider.notifier).state = resetConfig;
      ref.read(settingsStorageErrorProvider.notifier).state = null;
      setState(() {
        _connectionOk = true;
        _connectionStatus = '本地凭证已重置';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connectionOk = false;
        _connectionStatus = '凭证重置失败，请重试';
      });
    } finally {
      if (mounted) setState(() => _isResettingCredentials = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    final storageError = ref.watch(settingsStorageErrorProvider);

    return Center(
      child: Container(
        width: 440,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(text: 'AI 服务'),
                    const SizedBox(height: AppSpacing.sm),
                    _ProviderDropdown(
                      selected: _selectedProvider,
                      onSelect: _selectProvider,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    _SectionLabel(text: 'API 配置'),
                    const SizedBox(height: AppSpacing.sm),
                    if (storageError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: palette.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                storageError,
                                style: AppTypography.caption(
                                  base.labelSmall!,
                                ).copyWith(color: palette.error),
                              ),
                            ),
                            TextButton(
                              onPressed: _isResettingCredentials
                                  ? null
                                  : _resetCredentials,
                              child: const Text('重置凭证'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _Field(
                      controller: _apiKeyController,
                      label: 'API Key',
                      hint: '输入你的 API Key',
                      obscure: true,
                      onChanged: (_) {
                        if (_isLoadingProvider) {
                          _credentialEditedWhileLoading = true;
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Field(
                      controller: _baseUrlController,
                      label: 'Base URL（可选）',
                      hint: _defaultHint(_selectedProvider, (c) => c.baseUrl),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Field(
                      controller: _modelController,
                      label: '模型（可选）',
                      hint: _defaultHint(_selectedProvider, (c) => c.model),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryButton(
                            label: '测试连接',
                            loading: _isTestingConnection,
                            onTap: _isTestingConnection || _isLoadingProvider
                                ? null
                                : _testConnection,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _PrimaryButton(
                            label: _isSaving ? '保存中…' : '保存',
                            onTap: _isSaving || _isLoadingProvider
                                ? null
                                : _save,
                          ),
                        ),
                      ],
                    ),
                    if (_connectionStatus != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _connectionStatus!,
                        style: AppTypography.caption(base.labelSmall!).copyWith(
                          color: _connectionOk
                              ? palette.success
                              : palette.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),

                    if (_menuBarPreferenceService.isSupported) ...[
                      _SectionLabel(text: 'macOS'),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '在状态栏显示 AITrans',
                                  style: AppTypography.bodyMuted(
                                    base.bodyMedium!,
                                  ).copyWith(color: palette.inkPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '关闭主窗口后，可从状态栏重新打开',
                                  style: AppTypography.caption(
                                    base.labelSmall!,
                                  ).copyWith(color: palette.inkTertiary),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: Switch(
                              key: const ValueKey('menu-bar-visibility-switch'),
                              value: _menuBarVisible ?? false,
                              onChanged:
                                  _menuBarVisible == null ||
                                      _isChangingMenuBarVisibility
                                  ? null
                                  : _setMenuBarVisibility,
                            ),
                          ),
                        ],
                      ),
                      if (_menuBarVisibilityError != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _menuBarVisibilityError!,
                          style: AppTypography.caption(
                            base.labelSmall!,
                          ).copyWith(color: palette.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    _SectionLabel(text: '快捷键'),
                    const SizedBox(height: AppSpacing.sm),
                    const _ShortcutRow(
                      shortcut: '⌘⇧T',
                      description: '唤起 / 隐藏窗口',
                    ),
                    const _ShortcutRow(shortcut: '↩', description: '立即翻译'),
                    const _ShortcutRow(shortcut: '⌘K', description: '清空输入'),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'AITrans v1.0.0',
                      style: AppTypography.caption(
                        base.labelSmall!,
                      ).copyWith(color: palette.inkTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '设置',
            style: AppTypography.hero(
              base.titleLarge!,
            ).copyWith(fontSize: 20, color: palette.inkPrimary),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: palette.inkTertiary),
            onPressed: () => Navigator.of(context).maybePop(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Text(
      text,
      style: AppTypography.sectionHeader(
        base.titleMedium!,
      ).copyWith(color: palette.inkSecondary),
    );
  }
}

/// AI 服务下拉选择框。
///
/// 用与输入框一致的 elevated 容器，内嵌无边框 DropdownButton，保持极简。
class _ProviderDropdown extends StatelessWidget {
  final ProviderType selected;
  final ValueChanged<ProviderType> onSelect;
  const _ProviderDropdown({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Material(
      color: palette.surfaceElevated.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ProviderType>(
            value: selected,
            isExpanded: true,
            autofocus: false,
            icon: Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: palette.inkTertiary,
            ),
            style: AppTypography.bodyMuted(
              base.bodyMedium!,
            ).copyWith(color: palette.inkPrimary),
            dropdownColor: palette.surface,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            items: [
              for (final type in ProviderType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(ProviderFactory.providerName(type)),
                ),
            ],
            onChanged: (value) {
              if (value != null) onSelect(value);
            },
          ),
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.onChanged,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    final obscure = widget.obscure && !_show;
    return Material(
      color: palette.surfaceElevated.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: AppTypography.caption(
                      base.labelSmall!,
                    ).copyWith(color: palette.inkTertiary),
                  ),
                  TextField(
                    controller: widget.controller,
                    onChanged: widget.onChanged,
                    obscureText: obscure,
                    style: AppTypography.bodyMuted(
                      base.bodyMedium!,
                    ).copyWith(color: palette.inkPrimary),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.only(top: 4),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.obscure)
              IconButton(
                icon: Icon(
                  _show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: palette.inkTertiary,
                ),
                onPressed: () => setState(() => _show = !_show),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Material(
      color: palette.accent,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.caption(base.labelMedium!).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _SecondaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Material(
      color: palette.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.inkSecondary,
                  ),
                )
              : Text(
                  label,
                  style: AppTypography.caption(base.labelMedium!).copyWith(
                    color: palette.inkPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String description;
  const _ShortcutRow({required this.shortcut, required this.description});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              shortcut,
              style: AppTypography.caption(
                base.labelSmall!,
              ).copyWith(fontFamily: 'monospace', color: palette.inkSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            description,
            style: AppTypography.bodyMuted(
              base.bodyMedium!,
            ).copyWith(color: palette.inkSecondary),
          ),
        ],
      ),
    );
  }
}
