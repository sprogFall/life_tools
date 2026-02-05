import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_tools/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/obj_store/obj_store_config.dart';
import '../core/obj_store/obj_store_config_service.dart';
import '../core/obj_store/obj_store_errors.dart';
import '../core/obj_store/obj_store_secrets.dart';
import '../core/obj_store/obj_store_service.dart';
import '../core/theme/ios26_theme.dart';
import '../core/ui/app_dialogs.dart';
import '../core/ui/app_scaffold.dart';
import '../core/ui/section_header.dart';

class ObjStoreSettingsPage extends StatefulWidget {
  const ObjStoreSettingsPage({super.key});

  @override
  State<ObjStoreSettingsPage> createState() => _ObjStoreSettingsPageState();
}

class _ObjStoreSettingsPageState extends State<ObjStoreSettingsPage> {
  ObjStoreType _type = ObjStoreType.none;
  bool _qiniuIsPrivate = false;
  bool _qiniuUseHttps = true;
  bool _qiniuSecretVisible = false;

  final _qiniuAccessKeyController = TextEditingController();
  final _qiniuSecretKeyController = TextEditingController();
  final _qiniuBucketController = TextEditingController();
  final _qiniuDomainController = TextEditingController();
  final _qiniuUploadHostController = TextEditingController();
  final _qiniuKeyPrefixController = TextEditingController();

  final _dataCapsuleAccessKeyController = TextEditingController();
  final _dataCapsuleSecretKeyController = TextEditingController();
  final _dataCapsuleBucketController = TextEditingController();
  final _dataCapsuleEndpointController = TextEditingController();
  final _dataCapsuleDomainController = TextEditingController();
  final _dataCapsuleKeyPrefixController = TextEditingController();
  bool _dataCapsuleSecretVisible = false;

  PlatformFile? _selectedFile;
  ObjStoreObject? _lastUploaded;
  final _queryKeyController = TextEditingController();

  bool _isTestingUpload = false;
  bool _isTestingQuery = false;

  @override
  void initState() {
    super.initState();

    final cfgService = context.read<ObjStoreConfigService>();
    final cfg = cfgService.config;
    _type = cfg?.type ?? ObjStoreType.none;

    if (cfg?.type == ObjStoreType.qiniu) {
      _qiniuIsPrivate = cfg?.qiniuIsPrivate ?? false;
      _qiniuUseHttps = cfg?.qiniuUseHttps ?? _guessUseHttps(cfg?.domain);
      _qiniuBucketController.text = cfg?.bucket ?? '';
      _qiniuDomainController.text = _stripDomainScheme(cfg?.domain ?? '');
      _qiniuUploadHostController.text =
          (cfg?.uploadHost?.trim().isNotEmpty ?? false)
          ? cfg!.uploadHost!
          : 'https://upload.qiniup.com';
      _qiniuKeyPrefixController.text = cfg?.keyPrefix ?? 'media/';

      final secrets = cfgService.qiniuSecrets;
      _qiniuAccessKeyController.text = secrets?.accessKey ?? '';
      _qiniuSecretKeyController.text = secrets?.secretKey ?? '';
    } else {
      _qiniuIsPrivate = false;
      _qiniuUseHttps = true;
      _qiniuUploadHostController.text = 'https://upload.qiniup.com';
      _qiniuKeyPrefixController.text = 'media/';
    }

    if (cfg?.type == ObjStoreType.dataCapsule) {
      _dataCapsuleBucketController.text = cfg?.dataCapsuleBucket ?? '';
      _dataCapsuleEndpointController.text = _stripDomainScheme(
        cfg?.dataCapsuleEndpoint ?? '',
      );
      _dataCapsuleDomainController.text = _stripDomainScheme(
        cfg?.dataCapsuleDomain ?? '',
      );
      _dataCapsuleKeyPrefixController.text =
          cfg?.dataCapsuleKeyPrefix ?? 'media/';

      final secrets = cfgService.dataCapsuleSecrets;
      _dataCapsuleAccessKeyController.text = secrets?.accessKey ?? '';
      _dataCapsuleSecretKeyController.text = secrets?.secretKey ?? '';
    } else {
      _dataCapsuleKeyPrefixController.text = 'media/';
    }
  }

  @override
  void dispose() {
    _qiniuAccessKeyController.dispose();
    _qiniuSecretKeyController.dispose();
    _qiniuBucketController.dispose();
    _qiniuDomainController.dispose();
    _qiniuUploadHostController.dispose();
    _qiniuKeyPrefixController.dispose();
    _dataCapsuleAccessKeyController.dispose();
    _dataCapsuleSecretKeyController.dispose();
    _dataCapsuleBucketController.dispose();
    _dataCapsuleEndpointController.dispose();
    _dataCapsuleDomainController.dispose();
    _dataCapsuleKeyPrefixController.dispose();
    _queryKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(
            title: l10n.obj_store_settings_title,
            showBackButton: true,
            actions: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: IOS26Theme.spacingMd,
                  vertical: IOS26Theme.spacingSm,
                ),
                onPressed: () => _save(context),
                child: Text(l10n.common_save, style: IOS26Theme.labelLarge),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(IOS26Theme.spacingXl),
              child: Column(
                children: [
                  _buildTypeCard(),
                  const SizedBox(height: IOS26Theme.spacingLg),
                  if (_type == ObjStoreType.qiniu) ...[
                    _buildQiniuConfigCard(),
                    const SizedBox(height: IOS26Theme.spacingLg),
                  ],
                  if (_type == ObjStoreType.dataCapsule) ...[
                    _buildDataCapsuleConfigCard(),
                    const SizedBox(height: IOS26Theme.spacingLg),
                  ],
                  if (_type != ObjStoreType.none) ...[
                    _buildTestCard(),
                    const SizedBox(height: IOS26Theme.spacingLg),
                  ],
                  _buildTipsCard(),
                  const SizedBox(height: IOS26Theme.spacingLg),
                  _buildDangerZoneCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.obj_store_settings_type_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          CupertinoSlidingSegmentedControl<ObjStoreType>(
            groupValue: _type,
            children: {
              ObjStoreType.none: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: IOS26Theme.spacingSm,
                ),
                child: Text(l10n.obj_store_settings_type_none_label),
              ),
              ObjStoreType.local: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: IOS26Theme.spacingSm,
                ),
                child: Text(l10n.obj_store_settings_type_local_label),
              ),
              ObjStoreType.qiniu: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: IOS26Theme.spacingSm,
                ),
                child: Text(l10n.obj_store_settings_type_qiniu_label),
              ),
              ObjStoreType.dataCapsule: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: IOS26Theme.spacingSm,
                ),
                child: Text(l10n.obj_store_settings_type_data_capsule_label),
              ),
            },
            onValueChanged: (v) {
              if (v == null) return;
              setState(() {
                _type = v;
                _selectedFile = null;
                _lastUploaded = null;
                _queryKeyController.text = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQiniuConfigCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.obj_store_settings_qiniu_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_bucket_type_label,
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _qiniuIsPrivate,
              children: {
                false: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: IOS26Theme.spacingSm,
                  ),
                  child: Text(l10n.common_public),
                ),
                true: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: IOS26Theme.spacingSm,
                  ),
                  child: Text(l10n.common_private),
                ),
              },
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _qiniuIsPrivate = v);
              },
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_protocol_label,
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _qiniuUseHttps,
              children: {
                true: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: IOS26Theme.spacingSm,
                  ),
                  child: Text(l10n.obj_store_settings_protocol_https_label),
                ),
                false: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: IOS26Theme.spacingSm,
                  ),
                  child: Text(l10n.obj_store_settings_protocol_http_label),
                ),
              },
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _qiniuUseHttps = v);
              },
            ),
          ),
          if (!_qiniuUseHttps) ...[
            const SizedBox(height: IOS26Theme.spacingSm),
            Text(
              l10n.obj_store_settings_http_security_warning,
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.toolRed,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_access_key_label,
            child: CupertinoTextField(
              controller: _qiniuAccessKeyController,
              placeholder: l10n.obj_store_settings_placeholder_example_short,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_secret_key_label,
            child: CupertinoTextField(
              key: const Key('obj_store_qiniu_secret'),
              controller: _qiniuSecretKeyController,
              placeholder: l10n.obj_store_settings_placeholder_example_short,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              obscureText: !_qiniuSecretVisible,
              suffixMode: OverlayVisibilityMode.always,
              suffix: CupertinoButton(
                key: const Key('obj_store_qiniu_secret_toggle'),
                padding: EdgeInsets.zero,
                minimumSize: IOS26Theme.minimumTapSize,
                onPressed: () {
                  setState(() => _qiniuSecretVisible = !_qiniuSecretVisible);
                },
                child: Icon(
                  _qiniuSecretVisible
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  color: IOS26Theme.textSecondary,
                  size: 18,
                ),
              ),
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_bucket_label,
            child: CupertinoTextField(
              controller: _qiniuBucketController,
              placeholder: l10n.obj_store_settings_placeholder_bucket,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_domain_label,
            child: CupertinoTextField(
              controller: _qiniuDomainController,
              placeholder: l10n.obj_store_settings_placeholder_domain,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_upload_host_label,
            child: CupertinoTextField(
              controller: _qiniuUploadHostController,
              placeholder: l10n.obj_store_settings_placeholder_upload_host,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_key_prefix_label,
            child: CupertinoTextField(
              controller: _qiniuKeyPrefixController,
              placeholder: l10n.obj_store_settings_placeholder_key_prefix,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCapsuleConfigCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.obj_store_settings_data_capsule_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_bucket_type_label,
            child: _buildFixedValue(
              l10n.obj_store_settings_fixed_private_value,
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_protocol_label,
            child: _buildFixedValue(l10n.obj_store_settings_fixed_https_value),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_url_style_label,
            child: _buildFixedValue(
              l10n.obj_store_settings_fixed_path_style_value,
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_access_key_ak_label,
            child: CupertinoTextField(
              controller: _dataCapsuleAccessKeyController,
              placeholder: l10n.obj_store_settings_placeholder_example_short,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_secret_key_sk_label,
            child: CupertinoTextField(
              key: const Key('obj_store_data_capsule_secret'),
              controller: _dataCapsuleSecretKeyController,
              placeholder: l10n.obj_store_settings_placeholder_example_short,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              obscureText: !_dataCapsuleSecretVisible,
              suffixMode: OverlayVisibilityMode.always,
              suffix: CupertinoButton(
                key: const Key('obj_store_data_capsule_secret_toggle'),
                padding: EdgeInsets.zero,
                minimumSize: IOS26Theme.minimumTapSize,
                onPressed: () {
                  setState(
                    () =>
                        _dataCapsuleSecretVisible = !_dataCapsuleSecretVisible,
                  );
                },
                child: Icon(
                  _dataCapsuleSecretVisible
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  color: IOS26Theme.textSecondary,
                  size: 18,
                ),
              ),
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_bucket_label,
            child: CupertinoTextField(
              controller: _dataCapsuleBucketController,
              placeholder: l10n.obj_store_settings_placeholder_bucket,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_endpoint_label,
            child: CupertinoTextField(
              controller: _dataCapsuleEndpointController,
              placeholder: l10n.obj_store_settings_placeholder_endpoint,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_domain_optional_label,
            child: CupertinoTextField(
              controller: _dataCapsuleDomainController,
              placeholder: l10n.obj_store_settings_placeholder_domain,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_region_label,
            child: _buildFixedValue(
              l10n.obj_store_settings_fixed_region_value(
                ObjStoreConfig.dataCapsuleFixedRegion,
              ),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildLabeledField(
            label: l10n.obj_store_settings_key_prefix_label,
            child: CupertinoTextField(
              controller: _dataCapsuleKeyPrefixController,
              placeholder: l10n.obj_store_settings_placeholder_key_prefix,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.obj_store_settings_test_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedFile == null
                      ? l10n.obj_store_settings_test_file_not_selected
                      : l10n.obj_store_settings_test_file_selected(
                          _selectedFile!.name,
                          _selectedFile!.size,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IOS26Theme.bodySmall,
                ),
              ),
              const SizedBox(width: IOS26Theme.spacingMd),
              CupertinoButton(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(
                  horizontal: IOS26Theme.spacingLg,
                  vertical: IOS26Theme.spacingMd,
                ),
                onPressed: _pickFile,
                child: Text(
                  l10n.obj_store_settings_choose_file_button,
                  style: IOS26Theme.labelLarge.copyWith(
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: IOS26Theme.primaryColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: _isTestingUpload ? null : () => _testUpload(context),
              child: Text(
                _isTestingUpload
                    ? l10n.obj_store_settings_test_uploading_button
                    : l10n.obj_store_settings_test_upload_button,
                style: IOS26Theme.labelLarge,
              ),
            ),
          ),
          if (_lastUploaded != null) ...[
            const SizedBox(height: IOS26Theme.spacingMd),
            Text(
              l10n.obj_store_settings_test_upload_result(
                _lastUploaded!.key,
                _redactSensitiveUrl(_lastUploaded!.uri),
              ),
              style: IOS26Theme.bodySmall.copyWith(height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          _buildLabeledField(
            label: l10n.obj_store_settings_query_key_label,
            child: CupertinoTextField(
              controller: _queryKeyController,
              placeholder:
                  _lastUploaded?.key ??
                  l10n.obj_store_settings_placeholder_query,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: IOS26Theme.primaryColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: _isTestingQuery ? null : () => _testQuery(context),
              child: Text(
                _isTestingQuery
                    ? l10n.obj_store_settings_test_querying_button
                    : l10n.obj_store_settings_test_query_button,
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
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.obj_store_settings_tips_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.obj_store_settings_tips_content,
            style: IOS26Theme.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.obj_store_settings_danger_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: IOS26Theme.toolRed.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () => _confirmAndClear(context),
              child: Text(
                l10n.obj_store_settings_clear_button,
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

  static Widget _buildFixedValue(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingMd,
      ),
      decoration: _fieldDecoration(),
      child: Text(
        value,
        style: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textPrimary),
      ),
    );
  }

  static BoxDecoration _fieldDecoration() {
    return IOS26Theme.textFieldDecoration();
  }

  Future<void> _save(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cfgService = context.read<ObjStoreConfigService>();

    if (_type == ObjStoreType.none) {
      await cfgService.clear();
      if (!context.mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_cleared_title,
        content: l10n.obj_store_settings_cleared_content,
      );
      return;
    }

    try {
      if (_type == ObjStoreType.local) {
        await cfgService.save(const ObjStoreConfig.local());
      } else if (_type == ObjStoreType.qiniu) {
        final cfg = _readQiniuConfig();
        final secrets = _readQiniuSecrets();
        if (!cfg.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content: l10n.obj_store_settings_qiniu_config_incomplete_error,
          );
          return;
        }
        if (!secrets.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content: l10n.obj_store_settings_qiniu_missing_credentials_error,
          );
          return;
        }
        await cfgService.save(cfg, secrets: secrets);
      } else if (_type == ObjStoreType.dataCapsule) {
        final cfg = _readDataCapsuleConfig();
        final secrets = _readDataCapsuleSecrets();
        if (!cfg.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content:
                l10n.obj_store_settings_data_capsule_config_incomplete_error,
          );
          return;
        }
        if (!secrets.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content:
                l10n.obj_store_settings_data_capsule_missing_credentials_error,
          );
          return;
        }
        await cfgService.save(cfg, dataCapsuleSecrets: secrets);
      } else {
        throw StateError('Unknown ObjStoreType: $_type');
      }
      if (!context.mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_saved_title,
        content: l10n.obj_store_settings_saved_content,
      );
    } catch (e) {
      if (!context.mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_save_failed_title,
        content: _redactSensitiveUrl(e.toString()),
      );
    }
  }

  ObjStoreConfig _readQiniuConfig() {
    return ObjStoreConfig.qiniu(
      bucket: _qiniuBucketController.text.trim(),
      domain: _normalizeDomainInput(_qiniuDomainController.text),
      uploadHost: _qiniuUploadHostController.text.trim().isEmpty
          ? 'https://upload.qiniup.com'
          : _qiniuUploadHostController.text.trim(),
      keyPrefix: _qiniuKeyPrefixController.text.trim(),
      isPrivate: _qiniuIsPrivate,
      useHttps: _qiniuUseHttps,
    );
  }

  ObjStoreQiniuSecrets _readQiniuSecrets() {
    return ObjStoreQiniuSecrets(
      accessKey: _qiniuAccessKeyController.text.trim(),
      secretKey: _qiniuSecretKeyController.text.trim(),
    );
  }

  ObjStoreConfig _readDataCapsuleConfig() {
    final domain = _normalizeDomainInput(_dataCapsuleDomainController.text);
    return ObjStoreConfig.dataCapsule(
      bucket: _dataCapsuleBucketController.text.trim(),
      endpoint: _normalizeDomainInput(_dataCapsuleEndpointController.text),
      domain: domain.isEmpty ? null : domain,
      keyPrefix: _dataCapsuleKeyPrefixController.text.trim(),
    );
  }

  ObjStoreDataCapsuleSecrets _readDataCapsuleSecrets() {
    return ObjStoreDataCapsuleSecrets(
      accessKey: _dataCapsuleAccessKeyController.text.trim(),
      secretKey: _dataCapsuleSecretKeyController.text.trim(),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    setState(() => _selectedFile = result.files.first);
  }

  Future<Uint8List?> _readSelectedFileBytes() async {
    final f = _selectedFile;
    if (f == null) return null;
    if (f.bytes != null) return f.bytes!;
    if (f.path == null || f.path!.trim().isEmpty) return null;
    return File(f.path!).readAsBytes();
  }

  Future<void> _testUpload(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final file = _selectedFile;
    if (file == null) {
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_invalid_title,
        content: l10n.obj_store_settings_test_upload_select_file_hint,
      );
      return;
    }
    final service = context.read<ObjStoreService>();
    final bytes = await _readSelectedFileBytes();
    if (!context.mounted) return;
    if (bytes == null) {
      // ignore: use_build_context_synchronously
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_invalid_title,
        content: l10n.obj_store_settings_test_upload_read_failed_hint,
      );
      return;
    }

    setState(() => _isTestingUpload = true);
    try {
      final config = switch (_type) {
        ObjStoreType.qiniu => _readQiniuConfig(),
        ObjStoreType.dataCapsule => _readDataCapsuleConfig(),
        _ => const ObjStoreConfig.local(),
      };
      final secrets = _type == ObjStoreType.qiniu ? _readQiniuSecrets() : null;
      final dataCapsuleSecrets = _type == ObjStoreType.dataCapsule
          ? _readDataCapsuleSecrets()
          : null;
      if (_type == ObjStoreType.qiniu) {
        if (!config.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content: l10n.obj_store_settings_qiniu_config_incomplete_error,
          );
          return;
        }
        if (secrets == null || !secrets.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content: l10n.obj_store_settings_qiniu_missing_credentials_error,
          );
          return;
        }
      }
      if (_type == ObjStoreType.dataCapsule) {
        if (!config.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content:
                l10n.obj_store_settings_data_capsule_config_incomplete_error,
          );
          return;
        }
        if (dataCapsuleSecrets == null || !dataCapsuleSecrets.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content:
                l10n.obj_store_settings_data_capsule_missing_credentials_error,
          );
          return;
        }
      }

      final uploaded = await service.uploadBytesWithConfig(
        config: config,
        secrets: secrets,
        dataCapsuleSecrets: dataCapsuleSecrets,
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() {
        _lastUploaded = uploaded;
        _queryKeyController.text = uploaded.key;
      });
      await _showObjResult(
        title: l10n.obj_store_settings_upload_success_title,
        key: uploaded.key,
        uri: uploaded.uri,
      );
    } on ObjStoreNotConfiguredException catch (e) {
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      await AppDialogs.showInfo(
        context,
        title: l10n.common_not_configured,
        content: _type == ObjStoreType.qiniu
            ? l10n.obj_store_settings_qiniu_missing_credentials_error
            : _type == ObjStoreType.dataCapsule
            ? l10n.obj_store_settings_data_capsule_missing_credentials_error
            : _redactSensitiveUrl(e.toString()),
      );
    } on ObjStoreConfigInvalidException catch (e) {
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_invalid_title,
        content: _type == ObjStoreType.qiniu
            ? l10n.obj_store_settings_qiniu_config_incomplete_error
            : _type == ObjStoreType.dataCapsule
            ? l10n.obj_store_settings_data_capsule_config_incomplete_error
            : _redactSensitiveUrl(e.toString()),
      );
    } catch (e) {
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_upload_failed_title,
        content: _redactSensitiveUrl(e.toString()),
      );
    } finally {
      if (mounted) setState(() => _isTestingUpload = false);
    }
  }

  Future<void> _testQuery(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final key = _queryKeyController.text.trim().isNotEmpty
        ? _queryKeyController.text.trim()
        : _lastUploaded?.key;
    if (key == null || key.trim().isEmpty) {
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_invalid_title,
        content: l10n.obj_store_settings_test_query_key_required_hint,
      );
      return;
    }

    setState(() => _isTestingQuery = true);
    try {
      final service = context.read<ObjStoreService>();
      final config = switch (_type) {
        ObjStoreType.qiniu => _readQiniuConfig(),
        ObjStoreType.dataCapsule => _readDataCapsuleConfig(),
        _ => const ObjStoreConfig.local(),
      };
      final secrets = _type == ObjStoreType.qiniu ? _readQiniuSecrets() : null;
      final dataCapsuleSecrets = _type == ObjStoreType.dataCapsule
          ? _readDataCapsuleSecrets()
          : null;
      if (_type == ObjStoreType.qiniu) {
        if (!config.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content: l10n.obj_store_settings_qiniu_config_incomplete_error,
          );
          return;
        }
        if (_qiniuIsPrivate && (secrets == null || !secrets.isValid)) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content: l10n.obj_store_settings_qiniu_missing_credentials_error,
          );
          return;
        }
      }
      if (_type == ObjStoreType.dataCapsule) {
        if (!config.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content:
                l10n.obj_store_settings_data_capsule_config_incomplete_error,
          );
          return;
        }
        if (dataCapsuleSecrets == null || !dataCapsuleSecrets.isValid) {
          await AppDialogs.showInfo(
            // ignore: use_build_context_synchronously
            context,
            title: l10n.obj_store_settings_invalid_title,
            content:
                l10n.obj_store_settings_data_capsule_missing_credentials_error,
          );
          return;
        }
      }

      final uri = await service.resolveUriWithConfig(
        config: config,
        key: key,
        secrets: secrets,
        dataCapsuleSecrets: dataCapsuleSecrets,
      );
      final ok = await service.probeWithConfig(
        config: config,
        key: key,
        secrets: secrets,
        dataCapsuleSecrets: dataCapsuleSecrets,
      );
      await _showQueryResult(uri: uri, ok: ok);
    } on ObjStoreNotConfiguredException catch (e) {
      if (!context.mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.common_not_configured,
        content: _type == ObjStoreType.qiniu && _qiniuIsPrivate
            ? l10n.obj_store_settings_qiniu_missing_credentials_error
            : _type == ObjStoreType.dataCapsule
            ? l10n.obj_store_settings_data_capsule_missing_credentials_error
            : _redactSensitiveUrl(e.toString()),
      );
    } on ObjStoreConfigInvalidException catch (e) {
      if (!context.mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_invalid_title,
        content: _type == ObjStoreType.qiniu
            ? l10n.obj_store_settings_qiniu_config_incomplete_error
            : _type == ObjStoreType.dataCapsule
            ? l10n.obj_store_settings_data_capsule_config_incomplete_error
            : _redactSensitiveUrl(e.toString()),
      );
    } catch (e) {
      if (!context.mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.obj_store_settings_query_failed_title,
        content: _redactSensitiveUrl(e.toString()),
      );
    } finally {
      if (mounted) setState(() => _isTestingQuery = false);
    }
  }

  Future<void> _confirmAndClear(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cfgService = context.read<ObjStoreConfigService>();
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.obj_store_settings_clear_confirm_title,
      content: l10n.obj_store_settings_clear_confirm_content,
      confirmText: l10n.common_clear,
      isDestructive: true,
    );

    if (!ok) return;

    await cfgService.clear();
    if (!context.mounted) return;
    setState(() {
      _type = ObjStoreType.none;
      _selectedFile = null;
      _lastUploaded = null;
      _queryKeyController.text = '';
    });
    // ignore: use_build_context_synchronously
    await AppDialogs.showInfo(
      context,
      title: l10n.obj_store_settings_cleared_title,
      content: l10n.obj_store_settings_cleared_content,
    );
  }

  Future<void> _showObjResult({
    required String title,
    required String key,
    required String uri,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final safeUri = _redactSensitiveUrl(uri);
    final safeContent = l10n.obj_store_settings_dialog_obj_content(
      key,
      safeUri,
    );
    final rawContent = l10n.obj_store_settings_dialog_obj_content(key, uri);
    if (!mounted) return;

    // 自定义弹窗逻辑太复杂，AppDialogs.showInfo 不够用，保留 showCupertinoDialog 但使用 AppDialogs 风格
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: SelectableText(safeContent),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: safeContent));
            },
            child: Text(l10n.obj_store_settings_copy_redacted_action),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final ok = await AppDialogs.showConfirm(
                context,
                title: l10n.obj_store_settings_copy_original_confirm_title,
                content: l10n.obj_store_settings_copy_original_confirm_content,
                confirmText: l10n.common_copy,
              );
              if (!ok) return;
              await Clipboard.setData(ClipboardData(text: rawContent));
            },
            child: Text(l10n.obj_store_settings_copy_original_action),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _showQueryResult({required String uri, required bool ok}) async {
    final l10n = AppLocalizations.of(context)!;
    final safeUri = _redactSensitiveUrl(uri);
    final accessibleText = ok ? l10n.common_yes : l10n.common_no;
    final safeContent = l10n.obj_store_settings_dialog_query_content(
      safeUri,
      accessibleText,
    );
    final rawContent = l10n.obj_store_settings_dialog_query_content(
      uri,
      accessibleText,
    );
    if (!mounted) return;

    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(l10n.obj_store_settings_query_result_title),
        content: SelectableText(safeContent),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: safeContent));
            },
            child: Text(l10n.obj_store_settings_copy_redacted_result_action),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final confirmed = await AppDialogs.showConfirm(
                context,
                title: l10n.obj_store_settings_copy_original_confirm_title,
                content: l10n.obj_store_settings_copy_original_confirm_content,
                confirmText: l10n.common_copy,
              );
              if (!confirmed) return;
              await Clipboard.setData(ClipboardData(text: rawContent));
            },
            child: Text(l10n.obj_store_settings_copy_original_result_action),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  static String _redactSensitiveUrl(String input) {
    final raw = input.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null) return input;
    if (uri.scheme != 'http' && uri.scheme != 'https') return input;
    if (uri.query.trim().isEmpty) return input;

    const sensitiveKeys = <String>{
      'X-Amz-Credential',
      'X-Amz-Signature',
      'X-Amz-Security-Token',
      'token',
      'e',
      'uploadToken',
      'access_token',
    };

    String mask(String v) {
      final s = v.trim();
      if (s.isEmpty) return '***';
      if (s.length <= 8) return '***';
      return '${s.substring(0, 4)}***${s.substring(s.length - 4)}';
    }

    final qpAll = uri.queryParametersAll;
    final redacted = <String, String>{};
    for (final e in qpAll.entries) {
      final key = e.key;
      final values = e.value;
      if (values.isEmpty) continue;
      final value = values.first;
      redacted[key] = sensitiveKeys.contains(key) ? mask(value) : value;
    }
    return uri.replace(queryParameters: redacted).toString();
  }

  static bool _guessUseHttps(String? domain) {
    final d = (domain ?? '').trim();
    if (d.startsWith('http://')) return false;
    return true;
  }

  static String _stripDomainScheme(String domain) {
    final d = domain.trim();
    if (d.startsWith('http://')) return d.substring('http://'.length);
    if (d.startsWith('https://')) return d.substring('https://'.length);
    return d;
  }

  String _normalizeDomainInput(String input) {
    final text = input.trim();
    if (text.isEmpty) return '';

    if (text.startsWith('http://') || text.startsWith('https://')) {
      final uri = Uri.tryParse(text);
      if (uri == null || uri.authority.isEmpty) return text;
      final base = '${uri.authority}${uri.path}';
      return base.replaceAll(RegExp(r'/$'), '');
    }

    return text.replaceAll(RegExp(r'/$'), '');
  }
}
