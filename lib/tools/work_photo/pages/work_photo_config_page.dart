import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_capture_item.dart';
import '../models/work_photo_hierarchy_level.dart';
import '../models/work_photo_template.dart';
import '../repository/work_photo_repository.dart';

class WorkPhotoConfigPage extends StatefulWidget {
  final WorkPhotoConfigRepository? repository;

  const WorkPhotoConfigPage({super.key, this.repository});

  @override
  State<WorkPhotoConfigPage> createState() => _WorkPhotoConfigPageState();
}

class _WorkPhotoConfigPageState extends State<WorkPhotoConfigPage> {
  late final WorkPhotoConfigRepository _repository;
  bool _loading = true;
  List<WorkPhotoTemplate> _templates = const [];
  List<WorkPhotoHierarchyLevel> _allLevels = const [];
  List<WorkPhotoCaptureItem> _allItems = const [];
  int? _editingTemplateId;

  WorkPhotoTemplate? get _editingTemplate {
    final id = _editingTemplateId;
    if (id == null) return null;
    for (final template in _templates) {
      if (template.id == id) return template;
    }
    return null;
  }

  List<WorkPhotoHierarchyLevel> get _editingLevels {
    final id = _editingTemplateId;
    if (id == null) return const [];
    return _allLevels.where((e) => e.templateId == id).toList();
  }

  List<WorkPhotoCaptureItem> get _editingItems {
    final id = _editingTemplateId;
    if (id == null) return const [];
    return _allItems.where((e) => e.templateId == id).toList();
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkPhotoRepository();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final templates = await _repository.listTemplates();
    final allLevels = await _repository.listHierarchyLevels();
    final allItems = await _repository.listCaptureItems();
    var editingTemplateId = _editingTemplateId;
    if (!templates.any((e) => e.id == editingTemplateId)) {
      editingTemplateId = null;
    }
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _allLevels = allLevels;
      _allItems = allItems;
      _editingTemplateId = editingTemplateId;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: l10n.work_photo_config_title,
        showBackButton: true,
        onBackPressed: _editingTemplateId == null
            ? null
            : () => setState(() => _editingTemplateId = null),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingXxl,
                ),
                children: [
                  if (_editingTemplate == null)
                    _buildTemplateList(l10n)
                  else
                    _buildTemplateEditor(_editingTemplate!, l10n),
                ],
              ),
            ),
    );
  }

  Widget _buildTemplateList(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.work_photo_templates_section),
        if (_templates.isEmpty)
          _emptyText(l10n.work_photo_no_templates)
        else
          for (final template in _templates) _buildTemplateRow(template, l10n),
        const SizedBox(height: IOS26Theme.spacingMd),
        IOS26Button(
          onPressed: _addTemplate,
          variant: IOS26ButtonVariant.secondary,
          child: IOS26ButtonLabel(l10n.work_photo_add_template),
        ),
      ],
    );
  }

  Widget _buildTemplateEditor(
    WorkPhotoTemplate template,
    AppLocalizations l10n,
  ) {
    final templateId = template.id;
    final rootLevels = _childLevels(null);
    final rootItems = _childItems(null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassContainer(
          borderRadius: IOS26Theme.radiusLg,
          padding: const EdgeInsets.all(IOS26Theme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IOS26Button.plain(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => setState(() => _editingTemplateId = null),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IOS26Icon(
                      CupertinoIcons.chevron_left,
                      tone: IOS26IconTone.accent,
                      size: 16,
                    ),
                    const SizedBox(width: IOS26Theme.spacingXs),
                    IOS26ButtonLabel(l10n.work_photo_template_list_back),
                  ],
                ),
              ),
              const SizedBox(height: IOS26Theme.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name, style: IOS26Theme.headlineSmall),
                        const SizedBox(height: IOS26Theme.spacingXs),
                        Text(
                          l10n.work_photo_templates_summary(
                            _editingLevels.length,
                            _editingItems.length,
                          ),
                          style: IOS26Theme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IOS26IconButton(
                    icon: CupertinoIcons.ellipsis,
                    semanticLabel: l10n.work_photo_config_actions,
                    onPressed: () => _showTemplateActions(template),
                    tone: IOS26IconTone.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: IOS26Theme.spacingXl),
        _sectionTitle(l10n.work_photo_capture_items_section),
        GlassContainer(
          borderRadius: IOS26Theme.radiusLg,
          padding: const EdgeInsets.all(IOS26Theme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRootActions(l10n, templateId),
              if (rootLevels.isEmpty && rootItems.isEmpty) ...[
                const SizedBox(height: IOS26Theme.spacingMd),
                Text(
                  l10n.work_photo_template_tree_empty,
                  style: IOS26Theme.bodyMedium,
                ),
              ] else ...[
                const SizedBox(height: IOS26Theme.spacingMd),
                for (final row in _treeRows(null, 0, l10n)) row,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: IOS26Theme.spacingSm),
      child: Text(title, style: IOS26Theme.titleMedium),
    );
  }

  Widget _emptyText(String text) {
    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Text(text, style: IOS26Theme.bodyMedium),
    );
  }

  Widget _buildTemplateRow(WorkPhotoTemplate template, AppLocalizations l10n) {
    final id = template.id;
    if (id == null) return const SizedBox.shrink();
    final levelCount = _allLevels.where((e) => e.templateId == id).length;
    final itemCount = _allItems.where((e) => e.templateId == id).length;
    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
      child: IOS26Button.plain(
        padding: const EdgeInsets.all(IOS26Theme.spacingLg),
        onPressed: () => setState(() => _editingTemplateId = id),
        child: Row(
          children: [
            const IOS26Icon(
              CupertinoIcons.square_stack_3d_up,
              tone: IOS26IconTone.accent,
              size: 22,
            ),
            const SizedBox(width: IOS26Theme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.name, style: IOS26Theme.titleMedium),
                  const SizedBox(height: IOS26Theme.spacingXs),
                  Text(
                    l10n.work_photo_templates_summary(levelCount, itemCount),
                    style: IOS26Theme.bodySmall,
                  ),
                ],
              ),
            ),
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

  Widget _buildRootActions(AppLocalizations l10n, int? templateId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.work_photo_root_directory, style: IOS26Theme.titleSmall),
        const SizedBox(height: IOS26Theme.spacingSm),
        Wrap(
          spacing: IOS26Theme.spacingSm,
          runSpacing: IOS26Theme.spacingSm,
          children: [
            IOS26Button(
              onPressed: templateId == null
                  ? null
                  : () => _addLevel(parentLevelId: null),
              variant: IOS26ButtonVariant.secondary,
              child: IOS26ButtonLabel(l10n.work_photo_add_level),
            ),
            IOS26Button(
              onPressed: templateId == null
                  ? null
                  : () => _addCaptureItem(parentLevelId: null),
              variant: IOS26ButtonVariant.secondary,
              child: IOS26ButtonLabel(l10n.work_photo_add_capture_item),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _treeRows(int? parentLevelId, int depth, AppLocalizations l10n) {
    final entries = <_TemplateTreeEntry>[
      for (final level in _childLevels(parentLevelId))
        _TemplateTreeEntry.level(level),
      for (final item in _childItems(parentLevelId))
        _TemplateTreeEntry.item(item),
    ]..sort(_TemplateTreeEntry.compare);

    final rows = <Widget>[];
    for (final entry in entries) {
      final level = entry.level;
      if (level != null) {
        rows.add(_buildLevelRow(level, depth, l10n));
        final levelId = level.id;
        if (levelId != null) {
          rows.addAll(_treeRows(levelId, depth + 1, l10n));
        }
      } else {
        rows.add(_buildItemRow(entry.item!, depth, l10n));
      }
    }
    return rows;
  }

  Widget _buildLevelRow(
    WorkPhotoHierarchyLevel level,
    int depth,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: depth * IOS26Theme.spacingLg,
        bottom: IOS26Theme.spacingSm,
      ),
      child: Row(
        children: [
          const IOS26Icon(
            CupertinoIcons.folder,
            tone: IOS26IconTone.secondary,
            size: 20,
          ),
          const SizedBox(width: IOS26Theme.spacingSm),
          Expanded(child: Text(level.name, style: IOS26Theme.titleSmall)),
          IOS26IconButton(
            icon: CupertinoIcons.ellipsis,
            semanticLabel: l10n.work_photo_config_actions,
            onPressed: () => _showLevelActions(level),
            tone: IOS26IconTone.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    WorkPhotoCaptureItem item,
    int depth,
    AppLocalizations l10n,
  ) {
    final max = item.maxCount == null ? '' : ' / ${item.maxCount}';
    return Padding(
      padding: EdgeInsets.only(
        left: depth * IOS26Theme.spacingLg,
        bottom: IOS26Theme.spacingSm,
      ),
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
                Text(item.name, style: IOS26Theme.titleSmall),
                Text(
                  '${l10n.work_photo_min_count_title}: ${item.minCount}$max',
                  style: IOS26Theme.bodySmall,
                ),
              ],
            ),
          ),
          IOS26IconButton(
            icon: CupertinoIcons.ellipsis,
            semanticLabel: l10n.work_photo_config_actions,
            onPressed: () => _showCaptureItemActions(item),
            tone: IOS26IconTone.secondary,
          ),
        ],
      ),
    );
  }

  List<WorkPhotoHierarchyLevel> _childLevels(int? parentLevelId) {
    return _editingLevels
        .where((e) => e.parentLevelId == parentLevelId)
        .toList()
      ..sort((a, b) => _compareTreeNode(a.sortIndex, a.id, b.sortIndex, b.id));
  }

  List<WorkPhotoCaptureItem> _childItems(int? parentLevelId) {
    return _editingItems.where((e) => e.parentLevelId == parentLevelId).toList()
      ..sort((a, b) => _compareTreeNode(a.sortIndex, a.id, b.sortIndex, b.id));
  }

  int _nextSortIndex(int? parentLevelId) {
    final sortIndexes = [
      for (final level in _childLevels(parentLevelId)) level.sortIndex,
      for (final item in _childItems(parentLevelId)) item.sortIndex,
    ];
    if (sortIndexes.isEmpty) return 0;
    return sortIndexes.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _addTemplate() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_template_name_title,
      placeholder: l10n.work_photo_template_name_placeholder,
    );
    if (name == null || name.trim().isEmpty) return;
    final id = await _repository.createTemplate(
      WorkPhotoTemplate.create(
        name: name,
        sortIndex: _templates.length,
        now: DateTime.now(),
      ),
    );
    _editingTemplateId = id;
    await _reload();
  }

  Future<void> _addLevel({required int? parentLevelId}) async {
    final l10n = AppLocalizations.of(context)!;
    final templateId = _editingTemplateId;
    if (templateId == null) return;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_level_name_title,
      placeholder: l10n.work_photo_level_name_placeholder,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repository.createHierarchyLevel(
      WorkPhotoHierarchyLevel.create(
        templateId: templateId,
        parentLevelId: parentLevelId,
        name: name,
        sortIndex: _nextSortIndex(parentLevelId),
        now: DateTime.now(),
      ),
    );
    await _reload();
  }

  Future<void> _addCaptureItem({required int? parentLevelId}) async {
    final l10n = AppLocalizations.of(context)!;
    final templateId = _editingTemplateId;
    if (templateId == null) return;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_capture_item_name_title,
      placeholder: l10n.work_photo_capture_item_name_placeholder,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repository.createCaptureItem(
      WorkPhotoCaptureItem.create(
        templateId: templateId,
        parentLevelId: parentLevelId,
        name: name,
        sortIndex: _nextSortIndex(parentLevelId),
        minCount: 1,
        maxCount: null,
        now: DateTime.now(),
      ),
    );
    await _reload();
  }

  Future<void> _showTemplateActions(WorkPhotoTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await AppDialogs.showActionSheet<_ConfigAction>(
      context,
      title: template.name,
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, _ConfigAction.rename),
          child: Text(l10n.common_rename),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, _ConfigAction.delete),
          child: Text(l10n.common_delete),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.common_cancel),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ConfigAction.rename) {
      await _renameTemplate(template);
    } else if (action == _ConfigAction.delete) {
      await _confirmDeleteTemplate(template);
    }
  }

  Future<void> _showLevelActions(WorkPhotoHierarchyLevel level) async {
    final action = await _showConfigActionSheet(
      title: level.name,
      canMoveUp: _canMove(level),
      canMoveDown: _canMove(level, direction: 1),
      includeChildActions: true,
    );
    if (!mounted || action == null) return;

    if (action == _ConfigAction.rename) {
      await _renameLevel(level);
    } else if (action == _ConfigAction.addChildLevel) {
      await _addLevel(parentLevelId: level.id);
    } else if (action == _ConfigAction.addChildCaptureItem) {
      await _addCaptureItem(parentLevelId: level.id);
    } else if (action == _ConfigAction.moveUp) {
      await _moveLevel(level, -1);
    } else if (action == _ConfigAction.moveDown) {
      await _moveLevel(level, 1);
    } else if (action == _ConfigAction.delete) {
      await _confirmDeleteLevel(level);
    }
  }

  Future<void> _showCaptureItemActions(WorkPhotoCaptureItem item) async {
    final action = await _showConfigActionSheet(
      title: item.name,
      canMoveUp: _canMove(item),
      canMoveDown: _canMove(item, direction: 1),
      includeCounts: true,
    );
    if (!mounted || action == null) return;

    if (action == _ConfigAction.rename) {
      await _renameCaptureItem(item);
    } else if (action == _ConfigAction.editCounts) {
      await _editCaptureItemCounts(item);
    } else if (action == _ConfigAction.moveUp) {
      await _moveCaptureItem(item, -1);
    } else if (action == _ConfigAction.moveDown) {
      await _moveCaptureItem(item, 1);
    } else if (action == _ConfigAction.delete) {
      await _confirmDeleteCaptureItem(item);
    }
  }

  Future<_ConfigAction?> _showConfigActionSheet({
    required String title,
    required bool canMoveUp,
    required bool canMoveDown,
    bool includeCounts = false,
    bool includeChildActions = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return AppDialogs.showActionSheet<_ConfigAction>(
      context,
      title: title,
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, _ConfigAction.rename),
          child: Text(l10n.common_rename),
        ),
        if (includeChildActions) ...[
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(context, _ConfigAction.addChildLevel),
            child: Text(l10n.work_photo_add_child_level),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(context, _ConfigAction.addChildCaptureItem),
            child: Text(l10n.work_photo_add_child_capture_item),
          ),
        ],
        if (includeCounts)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _ConfigAction.editCounts),
            child: Text(l10n.work_photo_edit_counts),
          ),
        if (canMoveUp)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _ConfigAction.moveUp),
            child: Text(l10n.work_photo_move_up),
          ),
        if (canMoveDown)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _ConfigAction.moveDown),
            child: Text(l10n.work_photo_move_down),
          ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, _ConfigAction.delete),
          child: Text(l10n.common_delete),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.common_cancel),
      ),
    );
  }

  Future<void> _renameTemplate(WorkPhotoTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_template_name_title,
      placeholder: l10n.work_photo_template_name_placeholder,
      defaultValue: template.name,
    );
    if (name == null || name.trim().isEmpty || template.id == null) return;
    await _repository.updateTemplate(
      template.copyWith(name: name, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  Future<void> _renameLevel(WorkPhotoHierarchyLevel level) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_level_name_title,
      placeholder: l10n.work_photo_level_name_placeholder,
      defaultValue: level.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repository.updateHierarchyLevel(
      level.copyWith(name: name, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  Future<void> _renameCaptureItem(WorkPhotoCaptureItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_capture_item_name_title,
      placeholder: l10n.work_photo_capture_item_name_placeholder,
      defaultValue: item.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repository.updateCaptureItem(
      item.copyWith(name: name, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  Future<void> _editCaptureItemCounts(WorkPhotoCaptureItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final defaultValue = '${item.minCount}/${item.maxCount ?? ''}';
    final input = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_edit_counts,
      placeholder: l10n.work_photo_count_input_placeholder,
      defaultValue: defaultValue,
    );
    if (input == null) return;
    final counts = _parseCounts(input);
    if (counts == null) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_edit_counts,
        content: l10n.work_photo_invalid_count,
      );
      return;
    }
    await _repository.updateCaptureItem(
      item.copyWith(
        minCount: counts.min,
        maxCount: counts.max,
        clearMaxCount: counts.max == null,
        updatedAt: DateTime.now(),
      ),
    );
    await _reload();
  }

  _CaptureCounts? _parseCounts(String input) {
    final parts = input.trim().split('/');
    if (parts.isEmpty || parts.length > 2) return null;
    final min = int.tryParse(parts.first.trim());
    if (min == null || min < 0) return null;

    int? max;
    if (parts.length == 2 && parts.last.trim().isNotEmpty) {
      max = int.tryParse(parts.last.trim());
      if (max == null || max < min) return null;
    }
    return _CaptureCounts(min, max);
  }

  Future<void> _confirmDeleteTemplate(WorkPhotoTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.work_photo_delete_template_title,
      content: l10n.work_photo_delete_template_content,
      confirmText: l10n.common_delete,
      isDestructive: true,
    );
    if (!ok || template.id == null) return;
    await _repository.updateTemplate(
      template.copyWith(isArchived: true, updatedAt: DateTime.now()),
    );
    _editingTemplateId = null;
    await _reload();
  }

  Future<void> _confirmDeleteLevel(WorkPhotoHierarchyLevel level) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.work_photo_delete_level_title,
      content: l10n.work_photo_delete_level_content,
      confirmText: l10n.common_delete,
      isDestructive: true,
    );
    if (!ok) return;
    await _archiveLevelTree(level);
    await _reload();
  }

  Future<void> _confirmDeleteCaptureItem(WorkPhotoCaptureItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.work_photo_delete_capture_item_title,
      content: l10n.work_photo_delete_capture_item_content,
      confirmText: l10n.common_delete,
      isDestructive: true,
    );
    if (!ok) return;
    await _repository.updateCaptureItem(
      item.copyWith(isArchived: true, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  Future<void> _archiveLevelTree(WorkPhotoHierarchyLevel root) async {
    final rootId = root.id;
    if (rootId == null) return;
    final ids = <int>{rootId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final level in _editingLevels) {
        final id = level.id;
        if (id == null || ids.contains(id)) continue;
        if (ids.contains(level.parentLevelId)) {
          ids.add(id);
          changed = true;
        }
      }
    }

    final now = DateTime.now();
    for (final level in _editingLevels) {
      final id = level.id;
      if (id != null && ids.contains(id)) {
        await _repository.updateHierarchyLevel(
          level.copyWith(isArchived: true, updatedAt: now),
        );
      }
    }
    for (final item in _editingItems) {
      if (ids.contains(item.parentLevelId)) {
        await _repository.updateCaptureItem(
          item.copyWith(isArchived: true, updatedAt: now),
        );
      }
    }
  }

  bool _canMove(Object node, {int direction = -1}) {
    final siblings = _siblingsOf(node);
    final index = siblings.indexWhere((entry) => entry.matches(node));
    final targetIndex = index + direction;
    return index >= 0 && targetIndex >= 0 && targetIndex < siblings.length;
  }

  Future<void> _moveLevel(WorkPhotoHierarchyLevel level, int direction) async {
    await _moveNode(level, direction);
  }

  Future<void> _moveCaptureItem(
    WorkPhotoCaptureItem item,
    int direction,
  ) async {
    await _moveNode(item, direction);
  }

  Future<void> _moveNode(Object node, int direction) async {
    final siblings = _siblingsOf(node);
    final index = siblings.indexWhere((entry) => entry.matches(node));
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= siblings.length) return;
    final current = siblings[index];
    final target = siblings[targetIndex];
    final now = DateTime.now();
    await _updateTreeEntrySort(current, target.sortIndex, now);
    await _updateTreeEntrySort(target, current.sortIndex, now);
    await _reload();
  }

  List<_TemplateTreeEntry> _siblingsOf(Object node) {
    final int? parentLevelId = switch (node) {
      WorkPhotoHierarchyLevel() => node.parentLevelId,
      WorkPhotoCaptureItem() => node.parentLevelId,
      _ => null,
    };
    return <_TemplateTreeEntry>[
      for (final level in _childLevels(parentLevelId))
        _TemplateTreeEntry.level(level),
      for (final item in _childItems(parentLevelId))
        _TemplateTreeEntry.item(item),
    ]..sort(_TemplateTreeEntry.compare);
  }

  Future<void> _updateTreeEntrySort(
    _TemplateTreeEntry entry,
    int sortIndex,
    DateTime now,
  ) async {
    final level = entry.level;
    if (level != null) {
      await _repository.updateHierarchyLevel(
        level.copyWith(sortIndex: sortIndex, updatedAt: now),
      );
      return;
    }
    final item = entry.item;
    if (item != null) {
      await _repository.updateCaptureItem(
        item.copyWith(sortIndex: sortIndex, updatedAt: now),
      );
    }
  }

  static int _compareTreeNode(int aSort, int? aId, int bSort, int? bId) {
    final sortCompared = aSort.compareTo(bSort);
    if (sortCompared != 0) return sortCompared;
    return (aId ?? 0).compareTo(bId ?? 0);
  }
}

enum _ConfigAction {
  rename,
  editCounts,
  addChildLevel,
  addChildCaptureItem,
  moveUp,
  moveDown,
  delete,
}

class _CaptureCounts {
  final int min;
  final int? max;

  const _CaptureCounts(this.min, this.max);
}

class _TemplateTreeEntry {
  final WorkPhotoHierarchyLevel? level;
  final WorkPhotoCaptureItem? item;
  final int sortIndex;
  final int id;
  final int typeOrder;

  const _TemplateTreeEntry._({
    required this.level,
    required this.item,
    required this.sortIndex,
    required this.id,
    required this.typeOrder,
  });

  factory _TemplateTreeEntry.level(WorkPhotoHierarchyLevel level) {
    return _TemplateTreeEntry._(
      level: level,
      item: null,
      sortIndex: level.sortIndex,
      id: level.id ?? 0,
      typeOrder: 0,
    );
  }

  factory _TemplateTreeEntry.item(WorkPhotoCaptureItem item) {
    return _TemplateTreeEntry._(
      level: null,
      item: item,
      sortIndex: item.sortIndex,
      id: item.id ?? 0,
      typeOrder: 1,
    );
  }

  bool matches(Object node) {
    return switch (node) {
      WorkPhotoHierarchyLevel() => level?.id == node.id,
      WorkPhotoCaptureItem() => item?.id == node.id,
      _ => false,
    };
  }

  static int compare(_TemplateTreeEntry a, _TemplateTreeEntry b) {
    final sortCompared = a.sortIndex.compareTo(b.sortIndex);
    if (sortCompared != 0) return sortCompared;
    final typeCompared = a.typeOrder.compareTo(b.typeOrder);
    if (typeCompared != 0) return typeCompared;
    return a.id.compareTo(b.id);
  }
}
