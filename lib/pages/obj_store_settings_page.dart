import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  final _qiniuAccessKeyController = TextEditingController();
  final _qiniuSecretKeyController = TextEditingController();
  final _qiniuBucketController = TextEditingController();
  final _qiniuDomainController = TextEditingController();
  final _qiniuUploadHostController = TextEditingController();
  final _qiniuKeyPrefixController = TextEditingController();

  bool _showAk = false;
  bool _showSk = false;

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
      _qiniuBucketController.text = cfg?.bucket ?? '';
      _qiniuDomainController.text = cfg?.domain ?? '';
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
      _qiniuUploadHostController.text = 'https://upload.qiniup.com';
      _qiniuKeyPrefixController.text = 'media/';
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
            label: 'AccessKey（AK）',
            child: CupertinoTextField(
              controller: _qiniuAccessKeyController,
              placeholder: '如：xxxxx',
              obscureText: !_showAk,
              autocorrect: false,
              decoration: _fieldDecoration(),
              suffix: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () => setState(() => _showAk = !_showAk),
                child: Icon(
                  _showAk ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  color: IOS26Theme.textSecondary,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: 'SecretKey（SK）',
            child: CupertinoTextField(
              controller: _qiniuSecretKeyController,
              placeholder: '如：xxxxx',
              obscureText: !_showSk,
              autocorrect: false,
              decoration: _fieldDecoration(),
              suffix: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () => setState(() => _showSk = !_showSk),
                child: Icon(
                  _showSk ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  color: IOS26Theme.textSecondary,
                  size: 18,
                ),
              ),
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
              placeholder: '如：https://cdn.example.com',
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
              '上传结果：\nKey: ${_lastUploaded!.key}\nURI: ${_lastUploaded!.uri}',
              style: const TextStyle(
                fontSize: 13,
                color: IOS26Theme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildLabeledField(
            label: '查询 Key（用于测试查询/拼接URL）',
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
            '4. AK/SK 属于敏感信息，仅建议自用场景配置；如需更安全的方案，建议由服务端下发上传凭证（uploadToken）。',
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
      } else {
        final cfg = _readQiniuConfig();
        final secrets = _readQiniuSecrets();
        await cfgService.save(cfg, secrets: secrets);
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
      domain: _qiniuDomainController.text.trim(),
      uploadHost: _qiniuUploadHostController.text.trim().isEmpty
          ? 'https://upload.qiniup.com'
          : _qiniuUploadHostController.text.trim(),
      keyPrefix: _qiniuKeyPrefixController.text.trim(),
      isPrivate: _qiniuIsPrivate,
    );
  }

  ObjStoreQiniuSecrets _readQiniuSecrets() {
    return ObjStoreQiniuSecrets(
      accessKey: _qiniuAccessKeyController.text.trim(),
      secretKey: _qiniuSecretKeyController.text.trim(),
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
      final config = _type == ObjStoreType.qiniu
          ? _readQiniuConfig()
          : const ObjStoreConfig.local();
      final secrets = _type == ObjStoreType.qiniu ? _readQiniuSecrets() : null;

      final uploaded = await service.uploadBytesWithConfig(
        config: config,
        secrets: secrets,
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() {
        _lastUploaded = uploaded;
        _queryKeyController.text = uploaded.key;
      });
      await _showInfo('上传成功', 'Key: ${uploaded.key}\nURI: ${uploaded.uri}');
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
      final config = _type == ObjStoreType.qiniu
          ? _readQiniuConfig()
          : const ObjStoreConfig.local();
      final secrets = _type == ObjStoreType.qiniu ? _readQiniuSecrets() : null;

      final uri = await service.resolveUriWithConfig(
        config: config,
        key: key,
        secrets: secrets,
      );
      final ok = await service.probeWithConfig(
        config: config,
        key: key,
        secrets: secrets,
      );
      await _showInfo('查询结果', 'URI: $uri\n可访问: ${ok ? '是' : '否'}');
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
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
