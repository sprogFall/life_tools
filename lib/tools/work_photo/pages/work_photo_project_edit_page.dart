import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_capture_item.dart';
import '../models/work_photo_hierarchy_level.dart';
import '../models/work_photo_template.dart';
import '../repository/work_photo_repository.dart';

class WorkPhotoProjectEditPage extends StatefulWidget {
  final WorkPhotoProjectCreateRepository? repository;

  const WorkPhotoProjectEditPage({super.key, this.repository});

  @override
  State<WorkPhotoProjectEditPage> createState() =>
      _WorkPhotoProjectEditPageState();
}

class _WorkPhotoProjectEditPageState extends State<WorkPhotoProjectEditPage> {
  late final WorkPhotoProjectCreateRepository _repository;
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loading = true;
  List<WorkPhotoTemplate> _templates = const [];
  List<WorkPhotoHierarchyLevel> _levels = const [];
  List<WorkPhotoCaptureItem> _items = const [];
  final Map<int, int> _levelCountByTemplateId = {};
  final Map<int, int> _itemCountByTemplateId = {};
  int? _selectedTemplateId;

  List<WorkPhotoHierarchyLevel> get _selectedLevels {
    return _levels.where((e) => e.templateId == _selectedTemplateId).toList();
  }

  List<WorkPhotoCaptureItem> get _selectedItems {
    return _items.where((e) => e.templateId == _selectedTemplateId).toList();
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WorkPhotoRepository();
    _loadConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final templates = await _repository.listTemplates();
    final selectedTemplateId = templates.isEmpty ? null : templates.first.id;
    final counts = await _loadTemplateCounts(templates);
    final config = selectedTemplateId == null
        ? const _TemplateConfig.empty()
        : await _loadTemplateConfig(selectedTemplateId);
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _levelCountByTemplateId
        ..clear()
        ..addAll(counts.levels);
      _itemCountByTemplateId
        ..clear()
        ..addAll(counts.items);
      _selectedTemplateId = selectedTemplateId;
      _applyTemplateConfig(config);
      _loading = false;
    });
  }

  Future<_TemplateCounts> _loadTemplateCounts(
    List<WorkPhotoTemplate> templates,
  ) async {
    final levels = <int, int>{};
    final items = <int, int>{};
    for (final template in templates) {
      final id = template.id;
      if (id == null) continue;
      levels[id] = (await _repository.listHierarchyLevels(
        templateId: id,
      )).length;
      items[id] = (await _repository.listCaptureItemsInTemplateTree(id)).length;
    }
    return _TemplateCounts(levels: levels, items: items);
  }

  Future<_TemplateConfig> _loadTemplateConfig(int templateId) async {
    final levels = await _repository.listHierarchyLevels(
      templateId: templateId,
    );
    final items = await _repository.listCaptureItemsInTemplateTree(templateId);
    return _TemplateConfig(levels: levels, items: items);
  }

  void _applyTemplateConfig(_TemplateConfig config) {
    _levels = config.levels;
    _items = config.items;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: l10n.work_photo_project_new_title,
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
                  IOS26Theme.spacingXxl,
                ),
                children: [
                  _buildSection(
                    key: const ValueKey('work-photo-project-template-section'),
                    title: l10n.work_photo_project_template_label,
                    child: _buildTemplateSelector(l10n),
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  _buildSection(
                    key: const ValueKey('work-photo-project-structure-section'),
                    title: l10n.work_photo_project_structure_section,
                    child: _buildTemplateStructure(l10n),
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  _buildSection(
                    key: const ValueKey('work-photo-project-name-section'),
                    title: l10n.work_photo_project_name_label,
                    child: _buildTextField(
                      controller: _nameController,
                      placeholder: l10n.work_photo_project_name_placeholder,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  _buildSection(
                    key: const ValueKey('work-photo-project-note-section'),
                    title: l10n.work_photo_note_label,
                    child: _buildTextField(
                      controller: _noteController,
                      placeholder: l10n.work_photo_note_placeholder,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
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
            onPressed: _save,
            variant: IOS26ButtonVariant.primary,
            child: IOS26ButtonLabel(l10n.common_save),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    Key? key,
    required String title,
    required Widget child,
  }) {
    return GlassContainer(
      key: key,
      borderRadius: IOS26Theme.radiusLg,
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: IOS26Theme.titleSmall),
          const SizedBox(height: IOS26Theme.spacingSm),
          child,
        ],
      ),
    );
  }

  Widget _buildTemplateSelector(AppLocalizations l10n) {
    if (_templates.isEmpty) {
      return Text(l10n.work_photo_no_templates, style: IOS26Theme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final template in _templates) _buildTemplateChoice(template, l10n),
      ],
    );
  }

  Widget _buildTemplateChoice(
    WorkPhotoTemplate template,
    AppLocalizations l10n,
  ) {
    final id = template.id;
    if (id == null) return const SizedBox.shrink();
    final selected = id == _selectedTemplateId;
    final levelCount = _levelCountByTemplateId[id] ?? 0;
    final itemCount = _itemCountByTemplateId[id] ?? 0;
    return IOS26Button.plain(
      padding: const EdgeInsets.symmetric(vertical: IOS26Theme.spacingSm),
      onPressed: () => _selectTemplate(id),
      child: Row(
        children: [
          IOS26Icon(
            selected
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.circle,
            tone: selected ? IOS26IconTone.accent : IOS26IconTone.secondary,
            size: 22,
          ),
          const SizedBox(width: IOS26Theme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: IOS26Theme.titleSmall),
                Text(
                  l10n.work_photo_templates_summary(levelCount, itemCount),
                  style: IOS26Theme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTemplate(int templateId) async {
    if (templateId == _selectedTemplateId) return;
    final config = await _loadTemplateConfig(templateId);
    if (!mounted) return;
    setState(() {
      _selectedTemplateId = templateId;
      _applyTemplateConfig(config);
    });
  }

  Widget _buildTemplateStructure(AppLocalizations l10n) {
    if (_selectedTemplateId == null) {
      return Text(l10n.work_photo_no_templates, style: IOS26Theme.bodyMedium);
    }
    if (_selectedLevels.isEmpty && _selectedItems.isEmpty) {
      return Text(
        l10n.work_photo_template_tree_empty,
        style: IOS26Theme.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRootRow(l10n),
        const SizedBox(height: IOS26Theme.spacingSm),
        for (final row in _treeRows(null, 1, l10n)) row,
      ],
    );
  }

  Widget _buildRootRow(AppLocalizations l10n) {
    return Row(
      children: [
        const IOS26Icon(
          CupertinoIcons.folder,
          tone: IOS26IconTone.secondary,
          size: 20,
        ),
        const SizedBox(width: IOS26Theme.spacingSm),
        Expanded(
          child: Text(
            l10n.work_photo_root_directory,
            style: IOS26Theme.titleSmall,
          ),
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
        rows.add(_buildLevelRow(level, depth));
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

  Widget _buildLevelRow(WorkPhotoHierarchyLevel level, int depth) {
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
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    TextInputAction? textInputAction,
    int maxLines = 1,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      textInputAction: textInputAction,
      maxLines: maxLines,
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingLg,
        vertical: IOS26Theme.spacingMd,
      ),
      decoration: IOS26Theme.textFieldDecoration(),
    );
  }

  List<WorkPhotoHierarchyLevel> _childLevels(int? parentLevelId) {
    return _selectedLevels
        .where((e) => e.parentLevelId == parentLevelId)
        .toList()
      ..sort((a, b) => _compareTreeNode(a.sortIndex, a.id, b.sortIndex, b.id));
  }

  List<WorkPhotoCaptureItem> _childItems(int? parentLevelId) {
    return _selectedItems
        .where((e) => e.parentLevelId == parentLevelId)
        .toList()
      ..sort((a, b) => _compareTreeNode(a.sortIndex, a.id, b.sortIndex, b.id));
  }

  static int _compareTreeNode(int aSort, int? aId, int bSort, int? bId) {
    final sortCompared = aSort.compareTo(bSort);
    if (sortCompared != 0) return sortCompared;
    return (aId ?? 0).compareTo(bId ?? 0);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final templateId = _selectedTemplateId;
    if (templateId == null) {
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_template_name_title,
        content: l10n.work_photo_no_templates_warning,
      );
      return;
    }
    if (_selectedItems.isEmpty) {
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_capture_items_section,
        content: l10n.work_photo_no_capture_items_warning,
      );
      return;
    }
    await _repository.createProjectFromTemplate(
      name: name,
      note: _noteController.text,
      templateId: templateId,
      hierarchySelections: const [],
      now: DateTime.now(),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}

class _TemplateCounts {
  final Map<int, int> levels;
  final Map<int, int> items;

  const _TemplateCounts({required this.levels, required this.items});
}

class _TemplateConfig {
  final List<WorkPhotoHierarchyLevel> levels;
  final List<WorkPhotoCaptureItem> items;

  const _TemplateConfig({required this.levels, required this.items});

  const _TemplateConfig.empty() : levels = const [], items = const [];
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

  static int compare(_TemplateTreeEntry a, _TemplateTreeEntry b) {
    final sortCompared = a.sortIndex.compareTo(b.sortIndex);
    if (sortCompared != 0) return sortCompared;
    final typeCompared = a.typeOrder.compareTo(b.typeOrder);
    if (typeCompared != 0) return typeCompared;
    return a.id.compareTo(b.id);
  }
}
