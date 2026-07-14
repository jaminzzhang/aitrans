import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/provider_factory.dart';
import '../../../core/config/ai_config.dart';
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
  String? _connectionStatus;
  bool _connectionOk = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiConfigProvider);
    _apiKeyController.text = config.apiKey ?? '';
    _baseUrlController.text = config.baseUrl ?? '';
    _modelController.text = config.model ?? '';
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
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });
    try {
      _persistToMemory();
      final provider = ref.read(aiProviderProvider);
      final ok = await provider.testConnection();
      setState(() {
        _connectionOk = ok;
        _connectionStatus = ok ? '连接成功' : '连接失败';
      });
    } catch (_) {
      setState(() {
        _connectionOk = false;
        // 不向用户暴露原始异常/路径，给出友好提示。
        _connectionStatus = '连接失败，请检查配置';
      });
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  void _persistToMemory() {
    final current = ref.read(aiConfigProvider);
    ref.read(aiConfigProvider.notifier).state = current.copyWith(
      apiKey: _apiKeyController.text,
      baseUrl: _baseUrlController.text.isEmpty ? null : _baseUrlController.text,
      model: _modelController.text.isEmpty ? null : _modelController.text,
    );
  }

  void _selectProvider(ProviderType type) {
    final current = ref.read(aiConfigProvider);
    ref.read(aiConfigProvider.notifier).state = current.copyWith(
      providerType: type,
    );
    // 切换 provider 时清空自定义 endpoint/model，让默认值重新生效。
    _baseUrlController.clear();
    _modelController.clear();
    setState(() => _connectionStatus = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    final config = ref.watch(aiConfigProvider);

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
                    _ProviderList(
                      selected: config.providerType,
                      onSelect: _selectProvider,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    _SectionLabel(text: 'API 配置'),
                    const SizedBox(height: AppSpacing.sm),
                    _Field(
                      controller: _apiKeyController,
                      label: 'API Key',
                      hint: '输入你的 API Key',
                      obscure: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Field(
                      controller: _baseUrlController,
                      label: 'Base URL（可选）',
                      hint: _defaultHint(config.providerType, (c) => c.baseUrl),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Field(
                      controller: _modelController,
                      label: '模型（可选）',
                      hint: _defaultHint(config.providerType, (c) => c.model),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryButton(
                            label: '测试连接',
                            loading: _isTestingConnection,
                            onTap: _isTestingConnection
                                ? null
                                : _testConnection,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _PrimaryButton(
                            label: '保存',
                            onTap: () {
                              _persistToMemory();
                              Navigator.of(context).maybePop();
                            },
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

class _ProviderList extends StatelessWidget {
  final ProviderType selected;
  final ValueChanged<ProviderType> onSelect;
  const _ProviderList({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final type in ProviderType.values)
          _ProviderRow(
            type: type,
            selected: type == selected,
            onTap: () => onSelect(type),
          ),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final ProviderType type;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderRow({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme;
    final name = ProviderFactory.providerName(type);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? palette.accent : palette.inkTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                name,
                style: AppTypography.body(base.bodyLarge!).copyWith(
                  color: selected ? palette.inkPrimary : palette.inkSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
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
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
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
  final VoidCallback onTap;
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
