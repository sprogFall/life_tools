import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/backup/services/share_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../core/ui/app_navigator.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_asset.dart';
import '../models/work_photo_project_detail.dart';
import '../repository/work_photo_repository.dart';
import '../services/work_photo_export_service.dart';
import '../services/work_photo_media_store.dart';
import '../widgets/work_photo_asset_grid.dart';
import 'work_photo_camera_page.dart';

class WorkPhotoProjectDetailPage extends StatefulWidget {
  final int projectId;
  final WorkPhotoRepository? repository;
  final WorkPhotoMediaStore? mediaStore;

  const WorkPhotoProjectDetailPage({
    super.key,
    required this.projectId,
    this.repository,
    this.mediaStore,
  });

  @override
  State<WorkPhotoProjectDetailPage> createState() =>
      _WorkPhotoProjectDetailPageState();
}

class _WorkPhotoProjectDetailPageState
    extends State<WorkPhotoProjectDetailPage> {
  late final WorkPhotoRepository _repository;
  late final WorkPhotoMediaStore _mediaStore;
  bool _loading = true;
  WorkPhotoProjectDetail? _detail;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkPhotoRepository();
    _mediaStore = widget.mediaStore ?? WorkPhotoMediaStore();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final detail = await _repository.getProjectDetail(widget.projectId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: l10n.work_photo_project_detail_title,
        showBackButton: true,
        actions: [
          IOS26IconButton(
            icon: CupertinoIcons.square_arrow_up,
            semanticLabel: l10n.work_photo_export_project,
            onPressed: _detail == null ? null : _exportProject,
            tone: IOS26IconTone.accent,
          ),
          IOS26IconButton(
            icon: CupertinoIcons.delete,
            semanticLabel: l10n.common_delete,
            onPressed: _detail == null ? null : _deleteProject,
            tone: IOS26IconTone.danger,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: _detail == null
                  ? Center(child: Text(l10n.work_photo_no_assets))
                  : _buildContent(_detail!, l10n),
            ),
      bottomNavigationBar: _detail == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingMd,
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingLg,
                ),
                child: IOS26Button(
                  onPressed: _openCamera,
                  variant: IOS26ButtonVariant.primary,
                  child: IOS26ButtonLabel(l10n.work_photo_continue_capture),
                ),
              ),
            ),
    );
  }

  Widget _buildContent(WorkPhotoProjectDetail detail, AppLocalizations l10n) {
    final assetsByItem = detail.assetsByItemId;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        IOS26Theme.spacingLg,
        IOS26Theme.spacingLg,
        IOS26Theme.spacingLg,
        IOS26Theme.spacingXxxl,
      ),
      children: [
        GlassContainer(
          borderRadius: IOS26Theme.radiusLg,
          padding: const EdgeInsets.all(IOS26Theme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.project.name, style: IOS26Theme.headlineSmall),
              if (detail.hierarchySummary.isNotEmpty) ...[
                const SizedBox(height: IOS26Theme.spacingSm),
                Text(detail.hierarchySummary, style: IOS26Theme.bodyMedium),
              ],
              const SizedBox(height: IOS26Theme.spacingSm),
              Text(
                l10n.work_photo_project_progress(
                  detail.completedItemCount,
                  detail.requiredItemCount,
                  detail.assetCount,
                ),
                style: IOS26Theme.bodySmall,
              ),
              if (detail.project.note.trim().isNotEmpty) ...[
                const SizedBox(height: IOS26Theme.spacingMd),
                Text(detail.project.note, style: IOS26Theme.bodyMedium),
              ],
            ],
          ),
        ),
        const SizedBox(height: IOS26Theme.spacingLg),
        for (final item in detail.items) ...[
          _buildItemSection(
            itemName: item.nameSnapshot,
            assets: assetsByItem[item.id] ?? const [],
          ),
          const SizedBox(height: IOS26Theme.spacingLg),
        ],
      ],
    );
  }

  Widget _buildItemSection({
    required String itemName,
    required List<WorkPhotoAsset> assets,
  }) {
    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(itemName, style: IOS26Theme.titleMedium)),
              Text(
                AppLocalizations.of(
                  context,
                )!.work_photo_photo_count(assets.length),
                style: IOS26Theme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          WorkPhotoAssetGrid(
            assets: assets,
            mediaStore: _mediaStore,
            onTap: _confirmDeleteAsset,
          ),
        ],
      ),
    );
  }

  Future<void> _openCamera() async {
    await AppNavigator.push(
      context,
      WorkPhotoCameraPage(
        projectId: widget.projectId,
        repository: _repository,
        mediaStore: _mediaStore,
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _confirmDeleteAsset(WorkPhotoAsset asset) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.work_photo_delete_photo_title,
      content: l10n.work_photo_delete_photo_content,
      confirmText: l10n.common_delete,
      isDestructive: true,
    );
    if (!ok || asset.id == null) return;
    await _repository.deleteAsset(asset.id!);
    await _mediaStore.deleteStoredFile(asset.relativePath);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _deleteProject() async {
    final l10n = AppLocalizations.of(context)!;
    final detail = _detail;
    if (detail == null) return;
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.work_photo_delete_project_title,
      content: l10n.work_photo_delete_project_content,
      confirmText: l10n.common_delete,
      isDestructive: true,
    );
    if (!ok) return;
    for (final asset in detail.assets) {
      await _mediaStore.deleteStoredFile(asset.relativePath);
    }
    await _repository.deleteProject(widget.projectId);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _exportProject() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final service = WorkPhotoExportService(
        repository: _repository,
        mediaStore: _mediaStore,
      );
      final result = await service.buildZip(projectIds: [widget.projectId]);
      final savedPath = await service.saveZip(result);
      await ShareService.shareBinaryFile(
        result.bytes,
        result.fileName,
        subject: l10n.work_photo_export_project,
        mimeType: 'application/zip',
      );
      if (!mounted || result.missingFiles.isEmpty) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_export_project,
        content: savedPath == null
            ? l10n.work_photo_export_missing(result.missingFiles.length)
            : '${l10n.work_photo_export_saved(savedPath)}\n${l10n.work_photo_export_missing(result.missingFiles.length)}',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_export_failed,
        content: e.toString(),
      );
    }
  }
}
