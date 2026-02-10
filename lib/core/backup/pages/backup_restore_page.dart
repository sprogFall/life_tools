import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:life_tools/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ai/ai_config_service.dart';
import '../../obj_store/obj_store_config_service.dart';
import '../../services/settings_service.dart';
import '../../sync/services/backup_restore_service.dart';
import '../../sync/services/sync_config_service.dart';
import '../../theme/ios26_theme.dart';
import '../../ui/app_dialogs.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/section_header.dart';
import '../../utils/text_editing_safety.dart';
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
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        AppDialogs.showInfo(
          context,
          title: l10n.backup_received_title,
          content: l10n.backup_received_content,
        );
      });
    }
  }

  @override
  void dispose() {
    _restoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(title: l10n.backup_restore_title, showBackButton: true),
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

  Widget _buildHint(String text) {
    return Text(
      text,
      style: IOS26Theme.bodySmall.copyWith(
        color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildExportCard() {
    final l10n = AppLocalizations.of(context)!;
    final primaryButton = IOS26Theme.buttonColors(IOS26ButtonVariant.primary);
    final ghostButton = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.common_export, padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          _buildHint(l10n.backup_export_hint_intro),
          const SizedBox(height: 6),
          _buildHint(l10n.backup_export_hint_items),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.backup_include_sensitive_label,
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
                ? l10n.backup_include_sensitive_on_hint
                : l10n.backup_include_sensitive_off_hint,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: primaryButton.background,
              onPressed: _exportAndShare,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.share,
                    color: primaryButton.foreground,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.backup_export_share_button,
                    style: IOS26Theme.labelLarge.copyWith(
                      color: primaryButton.foreground,
                    ),
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
              color: ghostButton.background,
              onPressed: _exportToTxtFile,
              child: Text(
                l10n.backup_export_save_txt_button,
                style: IOS26Theme.labelLarge.copyWith(
                  color: ghostButton.foreground,
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
              color: ghostButton.background,
              onPressed: _exportToClipboard,
              child: Text(
                l10n.backup_export_copy_clipboard_button,
                style: IOS26Theme.labelLarge.copyWith(
                  color: ghostButton.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreCard() {
    final l10n = AppLocalizations.of(context)!;
    final ghostButton = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);
    final destructiveButton = IOS26Theme.buttonColors(
      IOS26ButtonVariant.destructivePrimary,
    );
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.common_restore, padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          _buildHint(l10n.backup_restore_hint),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: _restoreController,
            placeholder: l10n.backup_restore_placeholder,
            maxLines: 8,
            autocorrect: false,
            decoration: IOS26Theme.textFieldDecoration(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(14),
                  color: ghostButton.background,
                  onPressed: _isRestoring ? null : _pasteFromClipboard,
                  child: Text(
                    l10n.backup_restore_paste_button,
                    style: IOS26Theme.labelLarge.copyWith(
                      color: ghostButton.foreground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(14),
                  color: ghostButton.background,
                  onPressed: _isRestoring ? null : _importFromTxtFile,
                  child: Text(
                    l10n.backup_restore_import_txt_button,
                    style: IOS26Theme.labelLarge.copyWith(
                      color: ghostButton.foreground,
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
              color: ghostButton.background,
              onPressed: _isRestoring || _restoreController.text.isEmpty
                  ? null
                  : () => setControllerTextWhenComposingIdle(
                      _restoreController,
                      '',
                      shouldContinue: () => mounted,
                    ),
              child: Text(
                l10n.common_clear,
                style: IOS26Theme.labelLarge.copyWith(
                  color: ghostButton.foreground,
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
              color: destructiveButton.background,
              onPressed: _isRestoring ? null : _confirmAndRestore,
              child: _isRestoring
                  ? CupertinoActivityIndicator(
                      radius: 9,
                      color: destructiveButton.foreground,
                    )
                  : Text(
                      l10n.backup_restore_start_button,
                      style: IOS26Theme.labelLarge.copyWith(
                        color: destructiveButton.foreground,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAndShare() async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final service = _buildService(context);
      final jsonText = await service.exportAsJson(
        pretty: false,
        includeSensitive: _includeSensitive,
      );
      final fileName = _buildBackupFileName(DateTime.now());

      final result = await ShareService.shareBackup(jsonText, fileName);

      if (!mounted) return;

      if (result.status == ShareResultStatus.success) {
        await AppDialogs.showInfo(
          context,
          title: l10n.backup_share_success_title,
          content: l10n.backup_share_success_content,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await AppDialogs.showInfo(
        context,
        title: l10n.backup_share_failed_title,
        content: e.toString(),
      );
    }
  }

  Future<void> _exportToTxtFile() async {
    try {
      final l10n = AppLocalizations.of(context)!;
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
      await AppDialogs.showInfo(
        context,
        title: l10n.backup_exported_title,
        content: l10n.backup_exported_saved_content(path, kb),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await AppDialogs.showInfo(
        context,
        title: l10n.backup_export_failed_title,
        content: e.toString(),
      );
    }
  }

  Future<void> _exportToClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    final service = _buildService(context);
    final jsonText = await service.exportAsJson(
      pretty: false,
      includeSensitive: _includeSensitive,
    );
    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!mounted) return;

    final kb = (jsonText.length / 1024).toStringAsFixed(1);
    await AppDialogs.showInfo(
      context,
      title: l10n.backup_exported_title,
      content: l10n.backup_exported_copied_content(kb),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    setControllerTextWhenComposingIdle(
      _restoreController,
      data?.text ?? '',
      shouldContinue: () => mounted,
    );
    setState(() {});
  }

  Future<void> _importFromTxtFile() async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.backup_file_picker_title,
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
      final l10n = AppLocalizations.of(context)!;
      await AppDialogs.showInfo(
        context,
        title: l10n.backup_import_failed_title,
        content: e.toString(),
      );
    }
  }

  Future<void> _confirmAndRestore() async {
    await _restoreFromJsonText(_restoreController.text);
  }

  Future<void> _restoreFromJsonText(String jsonText) async {
    final text = jsonText.trim();
    if (text.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmRestore();
    if (!confirmed) return;
    if (!mounted) return;

    setState(() => _isRestoring = true);
    try {
      final service = _buildService(context);
      final result = await service.restoreFromJson(text);
      if (!mounted) return;

      final summary = [
        l10n.backup_restore_summary_imported(result.importedTools),
        l10n.backup_restore_summary_skipped(result.skippedTools),
        if (result.failedTools.isNotEmpty)
          l10n.backup_restore_summary_failed(
            result.failedTools.keys.join(', '),
          ),
      ].join('\n');

      await AppDialogs.showInfo(
        context,
        title: l10n.backup_restore_complete_title,
        content: summary,
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await AppDialogs.showInfo(
        context,
        title: l10n.backup_restore_failed_title,
        content: e.toString(),
      );
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
    final l10n = AppLocalizations.of(context)!;
    return AppDialogs.showConfirm(
      context,
      title: l10n.backup_confirm_restore_title,
      content: l10n.backup_confirm_restore_content,
      cancelText: l10n.common_cancel,
      confirmText: l10n.common_continue,
      isDestructive: true,
    );
  }
}
