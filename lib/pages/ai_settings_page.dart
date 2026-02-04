import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'package:life_tools/core/ai/ai_config.dart';
import '../core/ai/ai_config_service.dart';
import '../core/ai/ai_service.dart';
import '../core/theme/ios26_theme.dart';
import '../core/ui/app_dialogs.dart';
import '../core/ui/app_navigator.dart';
import '../core/ui/app_scaffold.dart';
import '../core/ui/section_header.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _maxOutputTokensController = TextEditingController();

  bool _showApiKey = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();

    final config = context.read<AiConfigService>().config;
    _baseUrlController.text = config?.baseUrl ?? 'https://api.openai.com/v1';
    _apiKeyController.text = config?.apiKey ?? '';
    _modelController.text = config?.model ?? 'gpt-4o-mini';
    _temperatureController.text = (config?.temperature ?? 0.7).toString();
    _maxOutputTokensController.text = (config?.maxOutputTokens ?? 1024)
        .toString();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _temperatureController.dispose();
    _maxOutputTokensController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(
            title: 'AI配置',
            showBackButton: true,
            actions: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onPressed: () => _save(context),
                child: Text('保存', style: IOS26Theme.labelLarge),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigCard(),
                  const SizedBox(height: 16),
                  _buildTipsCard(),
                  const SizedBox(height: 16),
                  _buildDangerZoneCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'OpenAI 兼容配置', padding: EdgeInsets.zero),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '接口地址（Base URL）',
            child: CupertinoTextField(
              key: const ValueKey('ai_baseUrl_field'),
              controller: _baseUrlController,
              placeholder: 'https://api.openai.com/v1',
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'API 密钥（Key）',
            child: CupertinoTextField(
              key: const ValueKey('ai_apiKey_field'),
              controller: _apiKeyController,
              placeholder: 'sk-...',
              obscureText: !_showApiKey,
              autocorrect: false,
              decoration: _fieldDecoration(),
              suffix: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
                child: Icon(
                  _showApiKey ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  size: 18,
                  color: IOS26Theme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '模型（Model）',
            child: CupertinoTextField(
              key: const ValueKey('ai_model_field'),
              controller: _modelController,
              placeholder: 'gpt-4o-mini',
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLabeledField(
                  label: '温度（Temperature）',
                  child: CupertinoTextField(
                    key: const ValueKey('ai_temperature_field'),
                    controller: _temperatureController,
                    placeholder: '0.7',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _fieldDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLabeledField(
                  label: '最大输出（Max Tokens）',
                  child: CupertinoTextField(
                    key: const ValueKey('ai_maxTokens_field'),
                    controller: _maxOutputTokensController,
                    placeholder: '1024',
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              key: const ValueKey('ai_test_button'),
              color: IOS26Theme.primaryColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: _isTesting ? null : () => _testConnection(context),
              child: Text(
                _isTesting ? '测试中...' : '测试连接',
                style: IOS26Theme.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '说明', padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          Text(
            '1. 接口地址支持填写到域名（如 https://example.com），也可直接填写到 /v1。\n'
            '2. 当前使用 OpenAI 兼容接口：/v1/chat/completions。\n'
            '3. API 密钥将保存在本机（SharedPreferences）。',
            style: IOS26Theme.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '危险区', padding: EdgeInsets.zero),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: IOS26Theme.toolRed.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () => _confirmAndClear(context),
              child: Text(
                '清除AI配置',
                style: IOS26Theme.labelLarge.copyWith(
                  color: IOS26Theme.toolRed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: IOS26Theme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: IOS26Theme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  static BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
        width: 0.5,
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final config = _readConfigFromFields();

    if (!config.isValid) {
      await AppDialogs.showInfo(
        context,
        title: '提示',
        content: '请检查配置项：接口地址 / API 密钥 / 模型不能为空；温度范围 0~2；最大输出 > 0。',
      );
      return;
    }

    final configService = context.read<AiConfigService>();
    await configService.save(config);
    if (!context.mounted) return;

    await AppDialogs.showInfo(
      context,
      title: '已保存',
      content: '当前模型：${config.model}',
    );
  }

  AiConfig _readConfigFromFields() {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    final temperature = double.tryParse(_temperatureController.text.trim());
    final maxTokens = int.tryParse(_maxOutputTokensController.text.trim());

    return AiConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      temperature: temperature ?? 0.7,
      maxOutputTokens: maxTokens ?? 1024,
    );
  }

  Future<void> _testConnection(BuildContext context) async {
    final config = _readConfigFromFields();
    if (!config.isValid) {
      await AppDialogs.showInfo(
        context,
        title: '提示',
        content: '请先填写合法的 AI 配置，再进行测试。',
      );
      return;
    }

    setState(() => _isTesting = true);

    final aiService = context.read<AiService>();
    // 显示 loading
    AppDialogs.showLoading(context, title: '测试中');

    try {
      final text = await aiService.chatTextWithConfig(
        config: config,
        prompt: '你好，请介绍一下你是什么模型',
        systemPrompt: '请用中文简要回答，不要输出多余内容。',
      );

      if (!context.mounted) return;
      // 关闭 loading
      AppNavigator.pop(context);
      
      await AppDialogs.showInfo(
        context,
        title: '测试结果',
        content: text,
      );
    } catch (e) {
      if (!context.mounted) return;
      // 关闭 loading
      AppNavigator.pop(context);

      await AppDialogs.showInfo(
        context,
        title: '测试失败',
        content: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _confirmAndClear(BuildContext context) async {
    final configService = context.read<AiConfigService>();
    final navigator = Navigator.of(context);

    final result = await AppDialogs.showConfirm(
      context,
      title: '确认清除？',
      content: '清除后将无法使用 AI 相关功能，直到重新配置。',
      confirmText: '清除',
      isDestructive: true,
    );

    if (!result) return;
    await configService.clear();
    if (!mounted) return;
    navigator.pop();
  }
}
