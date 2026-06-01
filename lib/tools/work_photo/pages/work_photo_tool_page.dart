import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_navigator.dart';
import '../../../core/widgets/ios26_home_leading_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/home_page.dart';
import '../models/work_photo_project_detail.dart';
import '../repository/work_photo_repository.dart';
import '../services/work_photo_media_store.dart';
import 'work_photo_config_page.dart';
import 'work_photo_export_page.dart';
import 'work_photo_project_detail_page.dart';
import 'work_photo_project_edit_page.dart';

class WorkPhotoToolPage extends StatefulWidget {
  final WorkPhotoRepository? repository;
  final WorkPhotoMediaStore? mediaStore;

  const WorkPhotoToolPage({super.key, this.repository, this.mediaStore});

  @override
  State<WorkPhotoToolPage> createState() => _WorkPhotoToolPageState();
}

class _WorkPhotoToolPageState extends State<WorkPhotoToolPage> {
  late final WorkPhotoRepository _repository;
  late final WorkPhotoMediaStore _mediaStore;
  bool _loading = true;
  List<WorkPhotoProjectSummary> _projects = const [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkPhotoRepository();
    _mediaStore = widget.mediaStore ?? WorkPhotoMediaStore();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final projects = await _repository.listProjectSummaries();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: BackdropGroup(
        child: SafeArea(
          child: Column(
            children: [
              IOS26AppBar(
                title: l10n.tool_work_photo_name,
                useSafeArea: false,
                leading: IOS26HomeLeadingButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  ),
                ),
                actions: [
                  IOS26IconButton(
                    icon: CupertinoIcons.slider_horizontal_3,
                    semanticLabel: l10n.work_photo_config_entry,
                    onPressed: _openConfig,
                    tone: IOS26IconTone.accent,
                  ),
                  IOS26IconButton(
                    icon: CupertinoIcons.square_arrow_up,
                    semanticLabel: l10n.work_photo_export_entry,
                    onPressed: _projects.isEmpty ? null : _openExport,
                    tone: IOS26IconTone.accent,
                  ),
                  IOS26IconButton(
                    icon: CupertinoIcons.add,
                    semanticLabel: l10n.work_photo_create_project,
                    onPressed: _openCreateProject,
                    tone: IOS26IconTone.accent,
                  ),
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _buildProjectList(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectList(AppLocalizations l10n) {
    if (_projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(IOS26Theme.spacingXl),
          child: Text(
            l10n.work_photo_empty_projects,
            textAlign: TextAlign.center,
            style: IOS26Theme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        IOS26Theme.spacingLg,
        IOS26Theme.spacingMd,
        IOS26Theme.spacingLg,
        IOS26Theme.spacingXxl,
      ),
      itemCount: _projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: IOS26Theme.spacingMd),
      itemBuilder: (context, index) => _buildProjectRow(_projects[index], l10n),
    );
  }

  Widget _buildProjectRow(
    WorkPhotoProjectSummary summary,
    AppLocalizations l10n,
  ) {
    final project = summary.project;
    final subtitle = [
      if (summary.hierarchySummary.trim().isNotEmpty) summary.hierarchySummary,
      l10n.work_photo_project_progress(
        summary.completedItemCount,
        summary.requiredItemCount,
        summary.assetCount,
      ),
    ].join('\n');

    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: EdgeInsets.zero,
      child: IOS26Button.plain(
        padding: const EdgeInsets.all(IOS26Theme.spacingLg),
        onPressed: project.id == null ? null : () => _openDetail(project.id!),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: IOS26Theme.toolBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
              ),
              child: const IOS26Icon(
                CupertinoIcons.camera_viewfinder,
                tone: IOS26IconTone.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: IOS26Theme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name, style: IOS26Theme.titleMedium),
                  const SizedBox(height: IOS26Theme.spacingXs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: IOS26Theme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: IOS26Theme.spacingSm),
            const IOS26Icon(
              CupertinoIcons.chevron_right,
              tone: IOS26IconTone.secondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openConfig() async {
    await AppNavigator.push(
      context,
      WorkPhotoConfigPage(repository: _repository),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openExport() async {
    await AppNavigator.push(
      context,
      WorkPhotoExportPage(repository: _repository, mediaStore: _mediaStore),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openCreateProject() async {
    final created = await AppNavigator.push<bool>(
      context,
      WorkPhotoProjectEditPage(repository: _repository),
    );
    if (!mounted) return;
    if (created == true) await _reload();
  }

  Future<void> _openDetail(int projectId) async {
    await AppNavigator.push(
      context,
      WorkPhotoProjectDetailPage(
        projectId: projectId,
        repository: _repository,
        mediaStore: _mediaStore,
      ),
    );
    if (!mounted) return;
    await _reload();
  }
}
