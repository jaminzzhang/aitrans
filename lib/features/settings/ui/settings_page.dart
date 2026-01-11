import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/provider_factory.dart';
import '../../../core/config/ai_config.dart';
import '../../translate/logic/translate_controller.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _isTestingConnection = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
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

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final provider = ref.read(aiProviderProvider);
      final success = await provider.testConnection();
      setState(() {
        _connectionStatus = success ? '连接成功' : '连接失败';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = '连接失败: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  void _saveConfig() {
    final currentConfig = ref.read(aiConfigProvider);
    ref.read(aiConfigProvider.notifier).state = currentConfig.copyWith(
      apiKey: _apiKeyController.text,
      baseUrl:
          _baseUrlController.text.isEmpty ? null : _baseUrlController.text,
      model: _modelController.text.isEmpty ? null : _modelController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('设置已保存'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(aiConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI 服务选择
          _SectionTitle(title: 'AI 服务'),
          const SizedBox(height: 8),
          _buildProviderSelector(config, theme),
          const SizedBox(height: 24),

          // API 配置
          _SectionTitle(title: 'API 配置'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _apiKeyController,
            label: 'API Key',
            hint: '输入你的 API Key',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _baseUrlController,
            label: 'Base URL (可选)',
            hint: _getDefaultBaseUrl(config.providerType),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _modelController,
            label: '模型 (可选)',
            hint: _getDefaultModel(config.providerType),
          ),
          const SizedBox(height: 24),

          // 操作按钮
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save),
                label: const Text('保存'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isTestingConnection ? null : _testConnection,
                icon: _isTestingConnection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: const Text('测试连接'),
              ),
            ],
          ),

          // 连接状态
          if (_connectionStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              _connectionStatus!,
              style: TextStyle(
                color: _connectionStatus!.contains('成功')
                    ? Colors.green
                    : theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 32),

          // 快捷键说明
          _SectionTitle(title: '快捷键'),
          const SizedBox(height: 8),
          _buildShortcutItem('Cmd + Shift + T', '唤起/隐藏窗口'),
          _buildShortcutItem('Enter', '立即翻译'),
          _buildShortcutItem('Cmd + K', '清空输入'),
          const SizedBox(height: 32),

          // 关于
          _SectionTitle(title: '关于'),
          const SizedBox(height: 8),
          Text(
            'AITrans v1.0.0',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            '一个精巧好用的 AI 翻译应用',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector(AIConfig config, ThemeData theme) {
    return SegmentedButton<ProviderType>(
      segments: const [
        ButtonSegment(
          value: ProviderType.openai,
          label: Text('OpenAI'),
        ),
        ButtonSegment(
          value: ProviderType.claude,
          label: Text('Claude'),
        ),
        ButtonSegment(
          value: ProviderType.deepseek,
          label: Text('DeepSeek'),
        ),
        ButtonSegment(
          value: ProviderType.ollama,
          label: Text('Ollama'),
        ),
        ButtonSegment(
          value: ProviderType.custom,
          label: Text('自定义'),
        ),
      ],
      selected: {config.providerType},
      onSelectionChanged: (selected) {
        ref.read(aiConfigProvider.notifier).state = config.copyWith(
          providerType: selected.first,
        );
        // 更新默认值
        _baseUrlController.text = '';
        _modelController.text = '';
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildShortcutItem(String shortcut, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(description),
        ],
      ),
    );
  }

  String _getDefaultBaseUrl(ProviderType type) {
    return switch (type) {
      ProviderType.openai => 'https://api.openai.com/v1',
      ProviderType.claude => 'https://api.anthropic.com/v1',
      ProviderType.deepseek => 'https://api.deepseek.com/v1',
      ProviderType.ollama => 'http://127.0.0.1:11434',
      ProviderType.custom => '输入自定义 API 地址',
    };
  }

  String _getDefaultModel(ProviderType type) {
    return switch (type) {
      ProviderType.openai => 'gpt-4o-mini',
      ProviderType.claude => 'claude-3-haiku-20240307',
      ProviderType.deepseek => 'deepseek-chat',
      ProviderType.ollama => 'llama3.2',
      ProviderType.custom => '输入模型名称',
    };
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
