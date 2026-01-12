import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../ai/ai_config_service.dart';
import '../../services/settings_service.dart';
import '../../sync/services/backup_restore_service.dart';
import '../../sync/services/sync_config_service.dart';
import '../../theme/ios26_theme.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final _restoreController = TextEditingController();
  bool _isRestoring = false;

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
            const IOS26AppBar(
              title: '备份与还原',
              showBackButton: true,
            ),
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
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: IOS26Theme.textPrimary,
      ),
    );
  }

  Widget _buildHint(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
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
          _buildHint('将以下内容导出为 JSON 并复制到剪切板：'),
          const SizedBox(height: 6),
          _buildHint('1) AI 配置（含 API Key）'),
          _buildHint('2) 数据同步配置'),
          _buildHint('3) 默认打开工具/工具排序等应用配置'),
          _buildHint('4) 各工具数据（通过 ToolSyncProvider 导出）'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: IOS26Theme.primaryColor,
              onPressed: _exportToClipboard,
              child: const Text(
                '导出 JSON 到剪切板',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.24,
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
                  onPressed: _pasteFromClipboard,
                  child: const Text(
                    '从剪切板粘贴',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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
                  onPressed: _restoreController.text.isEmpty
                      ? null
                      : () => _restoreController.clear(),
                  child: const Text(
                    '清空',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
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
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '开始还原（覆盖本地）',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.24,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToClipboard() async {
    final service = _buildService(context);
    final jsonText = await service.exportAsJson(pretty: true);
    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!mounted) return;

    final kb = (jsonText.length / 1024).toStringAsFixed(1);
    await _showDialog(title: '已导出', content: 'JSON 已复制到剪切板（约 $kb KB）');
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    setState(() => _restoreController.text = data?.text ?? '');
  }

  Future<void> _confirmAndRestore() async {
    final text = _restoreController.text.trim();
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

