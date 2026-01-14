import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../main.dart';
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
  void initState() {
    super.initState();
    _checkSharedFile();
  }

  /// 检查是否有从外部分享的文件
  void _checkSharedFile() {
    // 延迟一帧执行，确保组件已挂载
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sharedFilePath = SharedFileImportService.instance
          .getAndClearSharedFilePath();
      if (sharedFilePath != null && mounted) {
        await _loadSharedFile(sharedFilePath);
      }
    });
  }

  Future<void> _loadSharedFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      setState(() {
        _restoreController.text = content;
      });

      if (mounted) {
        await _showDialog(
          title: '已加载备份文件',
          content: '文件内容已自动填充，请检查后点击"开始还原"按钮',
        );
      }
    } catch (e) {
      if (mounted) {
        await _showDialog(title: '加载失败', content: '无法读取分享的文件：$e');
      }
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
          _buildHint('将以下内容导出为 JSON（大数据量推荐导出为 TXT 文件）：'),
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
              onPressed: _exportAndShare,
              child: const Text(
                '导出并分享',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
                  onPressed: _exportToSelectedDirectory,
                  child: const Text(
                    '保存到指定目录',
                    style: TextStyle(
                      color: IOS26Theme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
                  onPressed: _exportToClipboard,
                  child: const Text(
                    '复制到剪切板',
                    style: TextStyle(
                      color: IOS26Theme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.24,
                    ),
                  ),
                ),
              ),
            ],
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
                  onPressed: _isRestoring ? null : _importFromTxtFile,
                  child: const Text(
                    '从 TXT 文件导入',
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

  /// 导出并分享
  Future<void> _exportAndShare() async {
    try {
      final service = _buildService(context);
      final jsonText = await service.exportAsJson(pretty: false);

      final fileName = _buildBackupFileName(DateTime.now());

      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonText, encoding: utf8);

      if (!mounted) return;

      // 分享文件
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: '生活工具箱备份文件', subject: fileName);

      if (!mounted) return;

      final kb = (jsonText.length / 1024).toStringAsFixed(1);
      await _showDialog(title: '已导出', content: '文件已准备好分享（约 $kb KB）');
    } catch (e) {
      if (!mounted) return;
      await _showDialog(title: '导出失败', content: e.toString());
    }
  }

  /// 导出到用户选择的目录
  Future<void> _exportToSelectedDirectory() async {
    try {
      // 在移动端，使用 FileSaver（系统文件选择器）
      // 在桌面端，使用目录选择器
      final service = _buildService(context);
      final jsonText = await service.exportAsJson(pretty: false);
      final fileName = _buildBackupFileName(DateTime.now());
      final bytes = Uint8List.fromList(utf8.encode(jsonText));

      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        // Web和移动端：使用 file_saver
        final path = await FileSaver.instance.saveFile(
          name: fileName.replaceAll('.txt', ''),
          bytes: bytes,
          ext: 'txt',
          mimeType: MimeType.text,
        );

        if (!mounted) return;
        final kb = (jsonText.length / 1024).toStringAsFixed(1);
        await _showDialog(
          title: '已保存',
          content: '已保存到：\n$path\n\n内容为紧凑 JSON（约 $kb KB）',
        );
      } else {
        // 桌面端：选择目录
        final directoryPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '选择保存目录',
        );

        if (directoryPath == null) {
          // 用户取消选择
          return;
        }

        final filePath = '$directoryPath/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        if (!mounted) return;
        final kb = (jsonText.length / 1024).toStringAsFixed(1);
        await _showDialog(
          title: '已保存',
          content: '已保存到：\n$filePath\n\n内容为紧凑 JSON（约 $kb KB）',
        );
      }
    } catch (e) {
      if (!mounted) return;
      await _showDialog(title: '保存失败', content: e.toString());
    }
  }

  Future<void> _exportToClipboard() async {
    final service = _buildService(context);
    final jsonText = await service.exportAsJson(pretty: false);
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
