import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/backup/services/share_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_project_detail.dart';
import '../repository/work_photo_repository.dart';
import '../services/work_photo_export_service.dart';
import '../services/work_photo_media_store.dart';

class WorkPhotoExportPage extends StatefulWidget {
  final WorkPhotoRepository? repository;
  final WorkPhotoMediaStore? mediaStore;

  const WorkPhotoExportPage({super.key, this.repository, this.mediaStore});

  @override
  State<WorkPhotoExportPage> createState() => _WorkPhotoExportPageState();
}

class _WorkPhotoExportPageState extends State<WorkPhotoExportPage> {
  late final WorkPhotoRepository _repository;
  late final WorkPhotoMediaStore _mediaStore;
  bool _loading = true;
  bool _exporting = false;
  List<WorkPhotoProjectSummary> _projects = const [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkPhotoRepository();
    _mediaStore = widget.mediaStore ?? WorkPhotoMediaStore();
    _reload();
  }

  Future<void> _reload() async {
    final projects = await _repository.listProjectSummaries();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _selectedIds
        ..clear()
        ..addAll(projects.map((e) => e.project.id).whereType<int>());
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: l10n.work_photo_export_title,
        showBackButton: true,
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingXxxl,
                ),
                children: [
                  Text(
                    l10n.work_photo_selected_count(_selectedIds.length),
                    style: IOS26Theme.titleMedium,
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  for (final summary in _projects) _buildProjectRow(summary),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            IOS26Theme.spacingLg,
            IOS26Theme.spacingMd,
            IOS26Theme.spacingLg,
            IOS26Theme.spacingLg,
          ),
          child: IOS26Button(
            onPressed: _selectedIds.isEmpty || _exporting ? null : _export,
            variant: IOS26ButtonVariant.primary,
            child: _exporting
                ? const IOS26ButtonLoadingIndicator()
                : IOS26ButtonLabel(l10n.work_photo_share_zip),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectRow(WorkPhotoProjectSummary summary) {
    final l10n = AppLocalizations.of(context)!;
    final id = summary.project.id;
    final selected = id != null && _selectedIds.contains(id);
    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
      child: IOS26Button.plain(
        padding: const EdgeInsets.all(IOS26Theme.spacingLg),
        onPressed: id == null
            ? null
            : () {
                setState(() {
                  if (selected) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                });
              },
        child: Row(
          children: [
            IOS26Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              tone: selected ? IOS26IconTone.accent : IOS26IconTone.secondary,
              size: 24,
            ),
            const SizedBox(width: IOS26Theme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.project.name, style: IOS26Theme.titleMedium),
                  const SizedBox(height: IOS26Theme.spacingXs),
                  Text(
                    l10n.work_photo_project_progress(
                      summary.completedItemCount,
                      summary.requiredItemCount,
                      summary.assetCount,
                    ),
                    style: IOS26Theme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      final service = WorkPhotoExportService(
        repository: _repository,
        mediaStore: _mediaStore,
      );
      final result = await service.buildZip(projectIds: _selectedIds.toList());
      final savedPath = await service.saveZip(result);
      await ShareService.shareBinaryFile(
        result.bytes,
        result.fileName,
        subject: l10n.work_photo_export_title,
        mimeType: 'application/zip',
      );
      if (!mounted || result.missingFiles.isEmpty) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_export_title,
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
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
