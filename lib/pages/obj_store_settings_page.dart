import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/obj_store/obj_store_config.dart';
import '../core/obj_store/obj_store_config_service.dart';
import '../core/obj_store/obj_store_errors.dart';
import '../core/obj_store/obj_store_secrets.dart';
import '../core/obj_store/obj_store_service.dart';
import '../core/theme/ios26_theme.dart';

class ObjStoreSettingsPage extends StatefulWidget {
  const ObjStoreSettingsPage({super.key});

  @override
  State<ObjStoreSettingsPage> createState() => _ObjStoreSettingsPageState();
}

class _ObjStoreSettingsPageState extends State<ObjStoreSettingsPage> {
  ObjStoreType _type = ObjStoreType.none;
  bool _qiniuIsPrivate = false;
  bool _qiniuUseHttps = true;

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
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            IOS26AppBar(
              title: '资源存储',
              showBackButton: true,
              actions: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () => _save(context),
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildTypeCard(),
                    const SizedBox(height: 16),
                    if (_type == ObjStoreType.qiniu) ...[
                      _buildQiniuConfigCard(),
                      const SizedBox(height: 16),
                    ],
                    if (_type == ObjStoreType.dataCapsule) ...[
                      _buildDataCapsuleConfigCard(),
                      const SizedBox(height: 16),
                    ],
                    if (_type != ObjStoreType.none) ...[
                      _buildTestCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildTipsCard(),
                    const SizedBox(height: 16),
                    _buildDangerZoneCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '存储方式',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoSlidingSegmentedControl<ObjStoreType>(
            groupValue: _type,
            children: const {
              ObjStoreType.none: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('未选择'),
              ),
              ObjStoreType.local: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('本地存储'),
              ),
              ObjStoreType.qiniu: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('七牛云'),
              ),
              ObjStoreType.dataCapsule: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('数据胶囊'),
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
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '七牛云配置',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '空间类型',
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _qiniuIsPrivate,
              children: const {
                false: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('公有'),
                ),
                true: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('私有'),
                ),
              },
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _qiniuIsPrivate = v);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '访问协议',
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _qiniuUseHttps,
              children: const {
                true: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('https'),
                ),
                false: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('http'),
                ),
              },
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _qiniuUseHttps = v);
              },
            ),
          ),
          if (!_qiniuUseHttps) ...[
            const SizedBox(height: 8),
            const Text(
              '安全提示：HTTP 为明文传输，AK/SK/文件内容可能被截获，仅建议内网调试使用。',
              style: TextStyle(
                fontSize: 12,
                color: IOS26Theme.toolRed,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'AccessKey（AK）',
            child: CupertinoTextField(
              controller: _qiniuAccessKeyController,
              placeholder: '如：xxxxx',
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'SecretKey（SK）',
            child: CupertinoTextField(
              controller: _qiniuSecretKeyController,
              placeholder: '如：xxxxx',
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'Bucket',
            child: CupertinoTextField(
              controller: _qiniuBucketController,
              placeholder: '如：my-bucket',
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '访问域名（用于拼接图片URL）',
            child: CupertinoTextField(
              controller: _qiniuDomainController,
              placeholder: '如：cdn.example.com',
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '上传域名（可选）',
            child: CupertinoTextField(
              controller: _qiniuUploadHostController,
              placeholder: '默认：https://upload.qiniup.com',
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'Key 前缀（可选）',
            child: CupertinoTextField(
              controller: _qiniuKeyPrefixController,
              placeholder: '如：media/',
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCapsuleConfigCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据胶囊配置',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(label: '空间类型', child: _buildFixedValue('私有（固定）')),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '访问协议',
            child: _buildFixedValue('https（固定）'),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'URL 风格',
            child: _buildFixedValue('路径风格（固定）'),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'AccessKey（AK）',
            child: CupertinoTextField(
              controller: _dataCapsuleAccessKeyController,
              placeholder: '如：xxxxx',
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'SecretKey（SK）',
            child: CupertinoTextField(
              controller: _dataCapsuleSecretKeyController,
              placeholder: '如：xxxxx',
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'Bucket',
            child: CupertinoTextField(
              controller: _dataCapsuleBucketController,
              placeholder: '如：my-bucket',
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'Endpoint（上传/访问）',
            child: CupertinoTextField(
              controller: _dataCapsuleEndpointController,
              placeholder: '如：s3.example.com',
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '访问域名（可选）',
            child: CupertinoTextField(
              controller: _dataCapsuleDomainController,
              placeholder: '如：cdn.example.com',
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'Region',
            child: _buildFixedValue(
              '${ObjStoreConfig.dataCapsuleFixedRegion}（固定）',
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'Key 前缀（可选）',
            child: CupertinoTextField(
              controller: _dataCapsuleKeyPrefixController,
              placeholder: '如：media/',
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '测试',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedFile == null
                      ? '未选择文件'
                      : '${_selectedFile!.name}（${_selectedFile!.size} bytes）',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                onPressed: _pickFile,
                child: const Text(
                  '选择文件',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: IOS26Theme.primaryColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: _isTestingUpload ? null : () => _testUpload(context),
              child: Text(
                _isTestingUpload ? '测试上传中...' : '测试上传',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: IOS26Theme.primaryColor,
                ),
              ),
            ),
          ),
          if (_lastUploaded != null) ...[
            const SizedBox(height: 12),
            Text(
              '上传结果：\nKey: ${_lastUploaded!.key}\nURI: ${_redactSensitiveUrl(_lastUploaded!.uri)}',
              style: const TextStyle(
                fontSize: 13,
                color: IOS26Theme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildLabeledField(
            label: '查询 Key / URL（用于测试查询/拼接URL，支持粘贴完整 URL）',
            child: CupertinoTextField(
              controller: _queryKeyController,
              placeholder: _lastUploaded?.key ?? '如：media/xxx.png',
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: IOS26Theme.primaryColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: _isTestingQuery ? null : () => _testQuery(context),
              child: Text(
                _isTestingQuery ? '查询中...' : '测试查询',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: IOS26Theme.primaryColor,
                ),
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
        children: const [
          Text(
            '说明',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '1. 本地存储会将文件写入应用私有目录（卸载应用后会被清理）。\n'
            '2. 七牛云存储会在本机生成上传 Token 并直接上传到七牛。\n'
            '3. 七牛私有空间查询会生成带签名的临时下载链接（带 e/token）。\n'
            '4. 数据胶囊固定使用 HTTPS + 路径风格 + 私有空间，Region 固定 us-east-1；上传使用 PUT 直传，私有查询会生成带 X-Amz-* 的临时链接（默认 30 分钟）。\n'
            '5. AK/SK 属于敏感信息，仅建议自用场景配置；如需更安全的方案，建议由服务端下发上传凭证（uploadToken）。\n'
            '6. 若数据胶囊配置了 Domain（自定义访问域名），私有空间建议使用与 Endpoint 同源的域名，否则可能因签名校验导致“可访问=否”。',
            style: TextStyle(
              fontSize: 13,
              color: IOS26Theme.textSecondary,
              height: 1.5,
            ),
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
          const Text(
            '危险区',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: IOS26Theme.toolRed.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onPressed: () => _confirmAndClear(context),
              child: const Text(
                '清除资源存储配置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
          style: const TextStyle(
            fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: _fieldDecoration(),
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, color: IOS26Theme.textPrimary),
      ),
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
    final cfgService = context.read<ObjStoreConfigService>();

    if (_type == ObjStoreType.none) {
      await cfgService.clear();
      if (!mounted) return;
      await _showInfo('已清除', '已将资源存储恢复为未选择');
      return;
    }

    try {
      if (_type == ObjStoreType.local) {
        await cfgService.save(const ObjStoreConfig.local());
      } else if (_type == ObjStoreType.qiniu) {
        final cfg = _readQiniuConfig();
        final secrets = _readQiniuSecrets();
        await cfgService.save(cfg, secrets: secrets);
      } else if (_type == ObjStoreType.dataCapsule) {
        final cfg = _readDataCapsuleConfig();
        final secrets = _readDataCapsuleSecrets();
        await cfgService.save(cfg, dataCapsuleSecrets: secrets);
      } else {
        throw StateError('Unknown ObjStoreType: $_type');
      }
      if (!mounted) return;
      await _showInfo('已保存', '资源存储配置已保存');
    } catch (e) {
      await _showInfo('保存失败', e.toString());
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
    final file = _selectedFile;
    if (file == null) {
      await _showInfo('提示', '请先选择一个要测试上传的图片/视频文件');
      return;
    }
    final service = context.read<ObjStoreService>();
    final bytes = await _readSelectedFileBytes();
    if (bytes == null) {
      await _showInfo('提示', '无法读取文件内容，请重新选择');
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
      await _showObjResult(title: '上传成功', key: uploaded.key, uri: uploaded.uri);
    } on ObjStoreNotConfiguredException catch (e) {
      await _showInfo('未配置', e.message);
    } catch (e) {
      await _showInfo('上传失败', e.toString());
    } finally {
      if (mounted) setState(() => _isTestingUpload = false);
    }
  }

  Future<void> _testQuery(BuildContext context) async {
    final key = _queryKeyController.text.trim().isNotEmpty
        ? _queryKeyController.text.trim()
        : _lastUploaded?.key;
    if (key == null || key.trim().isEmpty) {
      await _showInfo('提示', '请填写要查询的 Key');
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
      await _showInfo('未配置', e.message);
    } catch (e) {
      await _showInfo('查询失败', e.toString());
    } finally {
      if (mounted) setState(() => _isTestingQuery = false);
    }
  }

  Future<void> _confirmAndClear(BuildContext context) async {
    final cfgService = context.read<ObjStoreConfigService>();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认清除'),
        content: const Text('将清除资源存储的所有配置（包括 AK/SK）'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await cfgService.clear();
    if (!mounted) return;
    setState(() {
      _type = ObjStoreType.none;
      _selectedFile = null;
      _lastUploaded = null;
      _queryKeyController.text = '';
    });
    await _showInfo('已清除', '资源存储配置已清除');
  }

  Future<void> _showInfo(String title, String content) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: SelectableText(content),
        actions: [
          if (content.trim().isNotEmpty)
            CupertinoDialogAction(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
              },
              child: const Text('复制内容'),
            ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showObjResult({
    required String title,
    required String key,
    required String uri,
  }) async {
    final safeUri = _redactSensitiveUrl(uri);
    final safeContent = 'Key: $key\nURI: $safeUri';
    if (!mounted) return;
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
            child: const Text('复制脱敏内容'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final ok = await _confirmCopySensitive(
                title: '复制原始 URI？',
                content: '原始 URI 可能包含签名/Token 等敏感信息，复制后请勿截图或分享。',
              );
              if (ok != true) return;
              await Clipboard.setData(
                ClipboardData(text: 'Key: $key\nURI: $uri'),
              );
            },
            child: const Text('复制原始内容'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showQueryResult({required String uri, required bool ok}) async {
    final safeUri = _redactSensitiveUrl(uri);
    final safeContent = 'URI: $safeUri\n可访问: ${ok ? '是' : '否'}';
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('查询结果'),
        content: SelectableText(safeContent),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: safeContent));
            },
            child: const Text('复制脱敏结果'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final confirmed = await _confirmCopySensitive(
                title: '复制原始 URI？',
                content: '原始 URI 可能包含签名/Token 等敏感信息，复制后请勿截图或分享。',
              );
              if (confirmed != true) return;
              await Clipboard.setData(
                ClipboardData(text: 'URI: $uri\n可访问: ${ok ? '是' : '否'}'),
              );
            },
            child: const Text('复制原始结果'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmCopySensitive({
    required String title,
    required String content,
  }) async {
    if (!mounted) return false;
    return showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
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
