import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/backup/services/share_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../core/ui/app_navigator.dart';
import '../../../core/widgets/ios26_image.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_asset.dart';
import '../models/work_photo_project_detail.dart';
import '../models/work_photo_project_item.dart';
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
                  child: IOS26ButtonLabel(l10n.work_photo_start_capture),
                ),
              ),
            ),
    );
  }

  Widget _buildContent(WorkPhotoProjectDetail detail, AppLocalizations l10n) {
    final treeRoots = _ProjectDetailTreeNode.buildRoots(detail.items);
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      detail.project.name,
                      style: IOS26Theme.headlineSmall,
                    ),
                  ),
                  Semantics(
                    key: const ValueKey('work-photo-rename-project'),
                    container: true,
                    label: l10n.common_rename,
                    button: true,
                    excludeSemantics: true,
                    child: IOS26IconButton(
                      icon: CupertinoIcons.pencil,
                      onPressed: _renameProject,
                      tone: IOS26IconTone.accent,
                    ),
                  ),
                ],
              ),
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
        Text(
          l10n.work_photo_capture_items_section,
          style: IOS26Theme.titleMedium,
        ),
        const SizedBox(height: IOS26Theme.spacingSm),
        GlassContainer(
          borderRadius: IOS26Theme.radiusLg,
          padding: const EdgeInsets.all(IOS26Theme.spacingLg),
          child: treeRoots.isEmpty
              ? Text(l10n.work_photo_no_capture_items)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildTreeRows(treeRoots, 0, detail, l10n),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildTreeRows(
    List<_ProjectDetailTreeNode> nodes,
    int depth,
    WorkPhotoProjectDetail detail,
    AppLocalizations l10n,
  ) {
    final rows = <Widget>[];
    for (final node in nodes) {
      if (node.isFolder) {
        rows.add(_buildFolderRow(node, depth, detail, l10n));
        rows.addAll(_buildTreeRows(node.children, depth + 1, detail, l10n));
      } else {
        rows.add(_buildItemRow(node, depth, detail, l10n));
      }
    }
    return rows;
  }

  Widget _buildFolderRow(
    _ProjectDetailTreeNode node,
    int depth,
    WorkPhotoProjectDetail detail,
    AppLocalizations l10n,
  ) {
    final assets = _assetsForItems(detail, node.itemsInScope);
    return Padding(
      padding: EdgeInsets.only(
        left: depth * IOS26Theme.spacingLg,
        bottom: IOS26Theme.spacingSm,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _confirmDeleteAssets(assets),
        child: Row(
          children: [
            const IOS26Icon(
              CupertinoIcons.folder,
              tone: IOS26IconTone.secondary,
              size: 20,
            ),
            const SizedBox(width: IOS26Theme.spacingSm),
            Expanded(child: Text(node.name, style: IOS26Theme.titleSmall)),
            Text(
              l10n.work_photo_photo_count(assets.length),
              style: IOS26Theme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(
    _ProjectDetailTreeNode node,
    int depth,
    WorkPhotoProjectDetail detail,
    AppLocalizations l10n,
  ) {
    final item = node.item!;
    final itemId = item.id;
    final assets = itemId == null
        ? const <WorkPhotoAsset>[]
        : (detail.assetsByItemId[itemId] ?? const <WorkPhotoAsset>[]);
    final max = item.maxCount == null ? '' : ' / ${item.maxCount}';
    return Padding(
      padding: EdgeInsets.only(
        left: depth * IOS26Theme.spacingLg,
        bottom: IOS26Theme.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _confirmDeleteAssets(assets),
            child: Row(
              children: [
                const IOS26Icon(
                  CupertinoIcons.camera,
                  tone: IOS26IconTone.accent,
                  size: 20,
                ),
                const SizedBox(width: IOS26Theme.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nameSnapshot, style: IOS26Theme.titleSmall),
                      Text(
                        '${l10n.work_photo_photo_count(assets.length)} / ${item.minCount}$max',
                        style: IOS26Theme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingSm),
          WorkPhotoAssetGrid(
            assets: assets,
            mediaStore: _mediaStore,
            onTap: _previewAsset,
            onLongPress: _confirmDeleteAsset,
          ),
        ],
      ),
    );
  }

  List<WorkPhotoAsset> _assetsForItems(
    WorkPhotoProjectDetail detail,
    List<WorkPhotoProjectItem> items,
  ) {
    final assetsByItem = detail.assetsByItemId;
    return [
      for (final item in items)
        if (item.id != null)
          ...(assetsByItem[item.id] ?? const <WorkPhotoAsset>[]),
    ];
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

  Future<void> _renameProject() async {
    final detail = _detail;
    if (detail == null) return;
    final l10n = AppLocalizations.of(context)!;
    final input = await AppDialogs.showInput(
      context,
      title: l10n.common_rename,
      defaultValue: detail.project.name,
      placeholder: l10n.work_photo_project_name_placeholder,
      cancelText: l10n.common_cancel,
      confirmText: l10n.common_save,
    );
    final name = input?.trim();
    if (name == null || name.isEmpty || name == detail.project.name) return;
    await _repository.updateProject(
      detail.project.copyWith(name: name, updatedAt: DateTime.now()),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _previewAsset(WorkPhotoAsset asset) async {
    final l10n = AppLocalizations.of(context)!;
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return CupertinoPageScaffold(
          backgroundColor: CupertinoColors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: FutureBuilder<File>(
                    future: _mediaStore.resolveStoredFile(asset.relativePath),
                    builder: (context, snapshot) {
                      final file = snapshot.data;
                      if (file == null) {
                        return const CupertinoActivityIndicator();
                      }
                      return InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: IOS26Image.file(
                          file,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              Container(color: CupertinoColors.black),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: IOS26Theme.spacingMd,
                  right: IOS26Theme.spacingMd,
                  child: IOS26IconButton(
                    icon: CupertinoIcons.xmark_circle_fill,
                    semanticLabel: l10n.common_close,
                    onPressed: () => Navigator.pop(dialogContext),
                    tone: IOS26IconTone.onAccent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAsset(WorkPhotoAsset asset) {
    return _confirmDeleteAssets([asset]);
  }

  Future<void> _confirmDeleteAssets(List<WorkPhotoAsset> assets) async {
    final targetAssets = <WorkPhotoAsset>[];
    final seenIds = <int>{};
    for (final asset in assets) {
      final id = asset.id;
      if (id == null || !seenIds.add(id)) continue;
      targetAssets.add(asset);
    }
    if (targetAssets.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.work_photo_delete_photo_title,
      content: l10n.work_photo_delete_photo_content,
      confirmText: l10n.common_delete,
      isDestructive: true,
    );
    if (!ok) return;
    for (final asset in targetAssets) {
      await _repository.deleteAsset(asset.id!);
    }
    for (final asset in targetAssets) {
      try {
        await _deleteStoredAssetFile(asset);
      } catch (_) {
        // 单张文件清理失败不应阻断同一范围内其他图片继续删除。
      }
    }
    if (!mounted) return;
    await _reload();
  }

  Future<void> _deleteStoredAssetFile(WorkPhotoAsset asset) async {
    try {
      final file = await _mediaStore.resolveStoredFile(asset.relativePath);
      await FileImage(file).evict();
    } catch (_) {
      // 缓存驱逐失败时仍继续执行媒体存储删除。
    }
    await _mediaStore.deleteStoredFile(asset.relativePath);
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

class _ProjectDetailTreeNode {
  final String name;
  final WorkPhotoProjectItem? item;
  final List<_ProjectDetailTreeNode> children;

  _ProjectDetailTreeNode.folder(this.name) : item = null, children = [];

  _ProjectDetailTreeNode.item(WorkPhotoProjectItem projectItem)
    : name = projectItem.nameSnapshot,
      item = projectItem,
      children = const [];

  bool get isFolder => item == null;

  List<WorkPhotoProjectItem> get itemsInScope {
    final ownItem = item;
    if (ownItem != null) return [ownItem];
    return [for (final child in children) ...child.itemsInScope];
  }

  static List<_ProjectDetailTreeNode> buildRoots(
    List<WorkPhotoProjectItem> items,
  ) {
    final roots = <_ProjectDetailTreeNode>[];
    for (final item in items) {
      var siblings = roots;
      for (final folderName in item.hierarchyPathSnapshot) {
        final folder = siblings.firstWhere(
          (node) => node.isFolder && node.name == folderName,
          orElse: () {
            final created = _ProjectDetailTreeNode.folder(folderName);
            siblings.add(created);
            return created;
          },
        );
        siblings = folder.children;
      }
      siblings.add(_ProjectDetailTreeNode.item(item));
    }
    return roots;
  }
}
