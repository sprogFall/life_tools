import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ai/ai_config_service.dart';
import '../../obj_store/obj_store_config_service.dart';
import '../../services/settings_service.dart';
import '../../sync/services/backup_restore_service.dart';
import '../../sync/services/sync_config_service.dart';
import '../../theme/ios26_theme.dart';
import '../services/share_service.dart';

class BackupRestorePage extends StatefulWidget {
  final String? initialJson;

  const BackupRestorePage({super.key, this.initialJson});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final _restoreController = TextEditingController();
  bool _isRestoring = false;
  bool _includeSensitive = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialJson != null && widget.initialJson!.isNotEmpty) {
      _restoreController.text = widget.initialJson!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDialog(title: '已接收备份文件', content: '备份内容已填入，请检查后点击"开始还原"按钮。');
      });
    }
  }

  @override
  void dispose() {
    _restoreController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const IOS26AppBar(title: '备份与还原', showBackButton: true),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildExportCard(),
                    const SizedBox(height: 16),
                    _buildRestoreCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BackupRestoreService _buildService(BuildContext context) {
    return BackupRestoreService(
      aiConfigService: context.read<AiConfigService>(),
      syncConfigService: context.read<SyncConfigService>(),
      settingsService: context.read<SettingsService>(),
      objStoreConfigService: context.read<ObjStoreConfigService>(),
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: IOS26Theme.titleSmall,
    );
  }

  Widget _buildHint(String text) {
    return Text(
      text,
      style: IOS26Theme.bodySmall.copyWith(
        color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildExportCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('导出'),
          const SizedBox(height: 10),
          _buildHint('将以下内容导出为 JSON（大数据量推荐导出为 TXT 文件）：'),
          const SizedBox(height: 6),
          _buildHint('1) AI 配置（Base URL / 模型 / 参数）'),
          _buildHint('2) 数据同步配置（服务器/网络模式等）'),
          _buildHint('3) 资源存储配置（七牛/本地）'),
          _buildHint('4) 工具管理（默认进入/首页显示/工具排序等应用配置）'),
          _buildHint('5) 各工具数据（通过 ToolSyncProvider 导出）'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '包含敏感信息（AI Key / Token / 七牛 AKSK）',
                  style: IOS26Theme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: _includeSensitive,
                onChanged: (v) => setState(() => _includeSensitive = v),
                activeTrackColor: IOS26Theme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildHint(
            _includeSensitive
                ? '默认已开启：导出内容会包含密钥/Token，分享前请确认接收方可信。'
                : '已关闭：不会导出密钥/Token（更安全，导入后可在设置页重新填写）。',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: IOS26Theme.primaryColor,
              onPressed: _exportAndShare,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.share, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '导出并分享',
                    style: IOS26Theme.labelLarge.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
              onPressed: _exportToTxtFile,
              child: Text(
                '保存为 TXT 文件',
                style: IOS26Theme.labelLarge.copyWith(
                  color: IOS26Theme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
              onPressed: _exportToClipboard,
              child: Text(
                '导出 JSON 到剪切板',
                style: IOS26Theme.labelLarge.copyWith(
                  color: IOS26Theme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('还原'),
          const SizedBox(height: 10),
          _buildHint('粘贴 JSON 并覆盖写入本地（请谨慎操作，建议先导出备份）。'),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: _restoreController,
            placeholder: '在此粘贴备份 JSON…',
            maxLines: 8,
            autocorrect: false,
            decoration: _fieldDecoration(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(14),
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
                  onPressed: _isRestoring ? null : _pasteFromClipboard,
                  child: Text(
                    '从剪切板粘贴',
                    style: IOS26Theme.labelLarge.copyWith(
                      color: IOS26Theme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(14),
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
                  onPressed: _isRestoring ? null : _importFromTxtFile,
                  child: Text(
                    '从 TXT 文件导入',
                    style: IOS26Theme.labelLarge.copyWith(
                      color: IOS26Theme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              borderRadius: BorderRadius.circular(14),
              color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
              onPressed: _isRestoring || _restoreController.text.isEmpty
                  ? null
                  : () => _restoreController.clear(),
              child: Text(
                '清空',
                style: IOS26Theme.labelLarge.copyWith(
                  color: IOS26Theme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: IOS26Theme.toolRed.withValues(alpha: 0.9),
              onPressed: _isRestoring ? null : _confirmAndRestore,
              child: _isRestoring
                  ? const CupertinoActivityIndicator(radius: 9, color: Colors.white)
                  : Text(
                      '开始还原（覆盖本地）',
                      style: IOS26Theme.labelLarge.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAndShare() async {
    try {
      final service = _buildService(context);
      final jsonText = await service.exportAsJson(
        pretty: false,
        includeSensitive: _includeSensitive,
      );
      final fileName = _buildBackupFileName(DateTime.now());

      final result = await ShareService.shareBackup(jsonText, fileName);

      if (!mounted) return;

      if (result.status == ShareResultStatus.success) {
        await _showDialog(title: '分享成功', content: '备份文件已分享');
      }
    } catch (e) {
      if (!mounted) return;
      await _showDialog(title: '分享失败', content: e.toString());
    }
  }

  Future<void> _exportToTxtFile() async {
    try {
      final service = _buildService(context);
      final jsonText = await service.exportAsJson(
        pretty: false,
        includeSensitive: _includeSensitive,
      );

      final fileName = _buildBackupFileName(DateTime.now());
      final bytes = Uint8List.fromList(utf8.encode(jsonText));

      // 使用 file_saver 来保存文件，支持所有平台
      final path = await FileSaver.instance.saveFile(
        name: fileName.replaceAll('.txt', ''), // file_saver 会自动添加扩展名
        bytes: bytes,
        ext: 'txt',
        mimeType: MimeType.text,
      );

      if (!mounted) return;

      final kb = (jsonText.length / 1024).toStringAsFixed(1);
      await _showDialog(
        title: '已导出',
        content: '已保存到：\n$path\n\n内容为紧凑 JSON（约 $kb KB）',
      );
    } catch (e) {
      if (!mounted) return;
      await _showDialog(title: '导出失败', content: e.toString());
    }
  }

  Future<void> _exportToClipboard() async {
    final service = _buildService(context);
    final jsonText = await service.exportAsJson(
      pretty: false,
      includeSensitive: _includeSensitive,
    );
    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!mounted) return;

    final kb = (jsonText.length / 1024).toStringAsFixed(1);
    await _showDialog(title: '已导出', content: '紧凑 JSON 已复制到剪切板（约 $kb KB）');
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    setState(() => _restoreController.text = data?.text ?? '');
  }

  Future<void> _importFromTxtFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择备份 TXT 文件',
        type: FileType.custom,
        allowedExtensions: const ['txt', 'json'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes;
      final path = picked.path;

      final jsonText = bytes != null
          ? utf8.decode(bytes)
          : path != null
          ? await XFile(path).readAsString(encoding: utf8)
          : '';
      await _restoreFromJsonText(jsonText);
    } catch (e) {
      if (!mounted) return;
      await _showDialog(title: '导入失败', content: e.toString());
    }
  }

  Future<void> _confirmAndRestore() async {
    await _restoreFromJsonText(_restoreController.text);
  }

  Future<void> _restoreFromJsonText(String jsonText) async {
    final text = jsonText.trim();
    if (text.isEmpty) return;

    final confirmed = await _confirmRestore();
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _isRestoring = true);
    try {
      final service = _buildService(context);
      final result = await service.restoreFromJson(text);
      if (!mounted) return;

      final summary = [
        '已导入工具：${result.importedTools}',
        '已跳过工具：${result.skippedTools}',
        if (result.failedTools.isNotEmpty)
          '失败工具：${result.failedTools.keys.join("，")}',
      ].join('\n');

      await _showDialog(title: '还原完成', content: summary);
    } catch (e) {
      if (!mounted) return;
      await _showDialog(title: '还原失败', content: e.toString());
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  static String _buildBackupFileName(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    final y = time.year.toString().padLeft(4, '0');
    final m = two(time.month);
    final d = two(time.day);
    final hh = two(time.hour);
    final mm = two(time.minute);
    final ss = two(time.second);
    return 'life_tools_backup_$y$m${d}_$hh$mm$ss.txt';
  }

  Future<bool> _confirmRestore() async {
    var confirmed = false;
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认还原？'),
        content: const Text('该操作会覆盖本地配置与数据，建议先导出备份。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              confirmed = true;
              Navigator.pop(context);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
    return confirmed;
  }

  Future<void> _showDialog({
    required String title,
    required String content,
  }) async {
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
