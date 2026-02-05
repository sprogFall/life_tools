import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(
            title: l10n.ai_settings_title,
            showBackButton: true,
            actions: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onPressed: () => _save(context),
                child: Text(l10n.common_save, style: IOS26Theme.labelLarge),
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
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.ai_settings_openai_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.ai_settings_base_url_label,
            child: CupertinoTextField(
              key: const ValueKey('ai_baseUrl_field'),
              controller: _baseUrlController,
              placeholder: l10n.ai_settings_base_url_placeholder,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: IOS26Theme.textFieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.ai_settings_api_key_label,
            child: CupertinoTextField(
              key: const ValueKey('ai_apiKey_field'),
              controller: _apiKeyController,
              placeholder: l10n.ai_settings_api_key_placeholder,
              obscureText: !_showApiKey,
              autocorrect: false,
              decoration: IOS26Theme.textFieldDecoration(),
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
            label: l10n.ai_settings_model_label,
            child: CupertinoTextField(
              key: const ValueKey('ai_model_field'),
              controller: _modelController,
              placeholder: l10n.ai_settings_model_placeholder,
              autocorrect: false,
              decoration: IOS26Theme.textFieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLabeledField(
                  label: l10n.ai_settings_temperature_label,
                  child: CupertinoTextField(
                    key: const ValueKey('ai_temperature_field'),
                    controller: _temperatureController,
                    placeholder: l10n.ai_settings_temperature_placeholder,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: IOS26Theme.textFieldDecoration(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLabeledField(
                  label: l10n.ai_settings_max_tokens_label,
                  child: CupertinoTextField(
                    key: const ValueKey('ai_maxTokens_field'),
                    controller: _maxOutputTokensController,
                    placeholder: l10n.ai_settings_max_tokens_placeholder,
                    keyboardType: TextInputType.number,
                    decoration: IOS26Theme.textFieldDecoration(),
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
                _isTesting
                    ? l10n.ai_settings_testing_button
                    : l10n.ai_settings_test_button,
                style: IOS26Theme.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.ai_settings_tips_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.ai_settings_tips_content,
            style: IOS26Theme.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.ai_settings_danger_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: IOS26Theme.toolRed.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () => _confirmAndClear(context),
              child: Text(
                l10n.ai_settings_clear_button,
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

  Future<void> _save(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final config = _readConfigFromFields();

    if (!config.isValid) {
      await AppDialogs.showInfo(
        context,
        title: l10n.ai_settings_invalid_title,
        content: l10n.ai_settings_invalid_content,
      );
      return;
    }

    final configService = context.read<AiConfigService>();
    await configService.save(config);
    if (!context.mounted) return;

    await AppDialogs.showInfo(
      context,
      title: l10n.ai_settings_saved_title,
      content: l10n.ai_settings_saved_content(config.model),
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
    final l10n = AppLocalizations.of(context)!;
    final config = _readConfigFromFields();
    if (!config.isValid) {
      await AppDialogs.showInfo(
        context,
        title: l10n.ai_settings_invalid_title,
        content: l10n.ai_settings_test_invalid_content,
      );
      return;
    }

    setState(() => _isTesting = true);

    final aiService = context.read<AiService>();
    // 显示 loading
    AppDialogs.showLoading(context, title: l10n.ai_settings_testing_loading_title);

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
        title: l10n.ai_settings_test_result_title,
        content: text,
      );
    } catch (e) {
      if (!context.mounted) return;
      // 关闭 loading
      AppNavigator.pop(context);

      await AppDialogs.showInfo(
        context,
        title: l10n.ai_settings_test_failed_title,
        content: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _confirmAndClear(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final configService = context.read<AiConfigService>();
    final navigator = Navigator.of(context);

    final result = await AppDialogs.showConfirm(
      context,
      title: l10n.ai_settings_clear_confirm_title,
      content: l10n.ai_settings_clear_confirm_content,
      cancelText: l10n.common_cancel,
      confirmText: l10n.ai_settings_clear_confirm_button,
      isDestructive: true,
    );

    if (!result) return;
    await configService.clear();
    if (!mounted) return;
    navigator.pop();
  }
}
