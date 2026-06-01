import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../core/widgets/ios26_select_field.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_capture_item.dart';
import '../models/work_photo_hierarchy_level.dart';
import '../models/work_photo_hierarchy_option.dart';
import '../models/work_photo_template.dart';
import '../repository/work_photo_repository.dart';

class WorkPhotoProjectEditPage extends StatefulWidget {
  final WorkPhotoRepository? repository;

  const WorkPhotoProjectEditPage({super.key, this.repository});

  @override
  State<WorkPhotoProjectEditPage> createState() =>
      _WorkPhotoProjectEditPageState();
}

class _WorkPhotoProjectEditPageState extends State<WorkPhotoProjectEditPage> {
  late final WorkPhotoRepository _repository;
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loading = true;
  bool _customMode = false;
  List<WorkPhotoTemplate> _templates = const [];
  List<WorkPhotoHierarchyLevel> _levels = const [];
  List<WorkPhotoHierarchyOption> _options = const [];
  List<WorkPhotoCaptureItem> _items = const [];
  final Map<int, int> _levelCountByTemplateId = {};
  final Map<int, int> _itemCountByTemplateId = {};
  int? _selectedTemplateId;
  final Map<int, int?> _selectionByLevelId = {};
  final List<_CustomHierarchyDraft> _customHierarchy = [];
  final List<_CustomCaptureItemDraft> _customItems = [];

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
    final options = <WorkPhotoHierarchyOption>[];
    for (final level in levels) {
      final id = level.id;
      if (id == null) continue;
      options.addAll(await _repository.listHierarchyOptions(levelId: id));
    }
    final items = await _repository.listCaptureItemsInTemplateTree(templateId);
    return _TemplateConfig(levels: levels, options: options, items: items);
  }

  void _applyTemplateConfig(_TemplateConfig config) {
    _levels = config.levels;
    _options = config.options;
    _items = config.items;
    _selectionByLevelId
      ..clear()
      ..addEntries(
        config.levels
            .map((level) => level.id)
            .whereType<int>()
            .map((id) => MapEntry(id, null)),
      );
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
                    title: l10n.work_photo_project_mode_title,
                    child: _buildModeSelector(l10n),
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  if (_customMode)
                    _buildCustomConfig(l10n)
                  else
                    _buildTemplateConfig(l10n),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  _buildSection(
                    title: l10n.work_photo_project_name_label,
                    child: _buildTextField(
                      controller: _nameController,
                      placeholder: l10n.work_photo_project_name_placeholder,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  _buildSection(
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

  Widget _buildSection({required String title, required Widget child}) {
    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: IOS26Theme.titleSmall),
          const SizedBox(height: IOS26Theme.spacingSm),
          child,
        ],
      ),
    );
  }

  Widget _buildModeSelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoSlidingSegmentedControl<bool>(
          groupValue: _customMode,
          children: {
            false: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: IOS26Theme.spacingMd,
                vertical: IOS26Theme.spacingSm,
              ),
              child: Text(l10n.work_photo_project_mode_template),
            ),
            true: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: IOS26Theme.spacingMd,
                vertical: IOS26Theme.spacingSm,
              ),
              child: Text(l10n.work_photo_project_mode_custom),
            ),
          },
          onValueChanged: (value) {
            if (value == null) return;
            setState(() => _customMode = value);
          },
        ),
        const SizedBox(height: IOS26Theme.spacingSm),
        Text(
          _customMode
              ? l10n.work_photo_project_mode_custom_hint
              : l10n.work_photo_project_mode_template_hint,
          style: IOS26Theme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTemplateConfig(AppLocalizations l10n) {
    final levels = _selectedLevels;
    final items = _selectedItems;
    final hasSelectableHierarchy = _options.isNotEmpty;
    return Column(
      children: [
        _buildSection(
          title: l10n.work_photo_project_template_label,
          child: _templates.isEmpty
              ? Text(l10n.work_photo_no_templates, style: IOS26Theme.bodyMedium)
              : Column(
                  children: [
                    for (final template in _templates)
                      _buildTemplateChoice(template, l10n),
                  ],
                ),
        ),
        if (hasSelectableHierarchy) ...[
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildSection(
            title: l10n.work_photo_hierarchy_section,
            child: levels.isEmpty
                ? Text(
                    l10n.work_photo_no_hierarchy,
                    style: IOS26Theme.bodyMedium,
                  )
                : Column(
                    children: [for (final level in levels) _levelField(level)],
                  ),
          ),
        ],
        const SizedBox(height: IOS26Theme.spacingMd),
        _buildSection(
          title: l10n.work_photo_capture_items_section,
          child: items.isEmpty
              ? Text(
                  l10n.work_photo_no_capture_items,
                  style: IOS26Theme.bodyMedium,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: IOS26Theme.spacingXs,
                        ),
                        child: Text(item.name, style: IOS26Theme.bodySmall),
                      ),
                  ],
                ),
        ),
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

  Widget _buildCustomConfig(AppLocalizations l10n) {
    return Column(
      children: [
        _buildSection(
          title: l10n.work_photo_hierarchy_section,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_customHierarchy.isEmpty)
                Text(
                  l10n.work_photo_no_custom_hierarchy,
                  style: IOS26Theme.bodyMedium,
                )
              else
                for (final draft in _customHierarchy)
                  _buildCustomHierarchyRow(draft),
              const SizedBox(height: IOS26Theme.spacingSm),
              IOS26Button(
                onPressed: _addCustomHierarchy,
                variant: IOS26ButtonVariant.secondary,
                child: IOS26ButtonLabel(l10n.work_photo_add_level),
              ),
            ],
          ),
        ),
        const SizedBox(height: IOS26Theme.spacingMd),
        _buildSection(
          title: l10n.work_photo_capture_items_section,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_customItems.isEmpty)
                Text(
                  l10n.work_photo_no_custom_capture_items,
                  style: IOS26Theme.bodyMedium,
                )
              else
                for (final draft in _customItems) _buildCustomItemRow(draft),
              const SizedBox(height: IOS26Theme.spacingSm),
              IOS26Button(
                onPressed: _addCustomItem,
                variant: IOS26ButtonVariant.secondary,
                child: IOS26ButtonLabel(l10n.work_photo_add_capture_item),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomHierarchyRow(_CustomHierarchyDraft draft) {
    return Padding(
      padding: const EdgeInsets.only(bottom: IOS26Theme.spacingXs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${draft.levelName}：${draft.optionName}',
              style: IOS26Theme.bodySmall,
            ),
          ),
          IOS26IconButton(
            icon: CupertinoIcons.trash,
            semanticLabel: AppLocalizations.of(context)!.common_delete,
            onPressed: () => setState(() => _customHierarchy.remove(draft)),
            tone: IOS26IconTone.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomItemRow(_CustomCaptureItemDraft draft) {
    final max = draft.maxCount == null ? '' : ' / ${draft.maxCount}';
    return Padding(
      padding: const EdgeInsets.only(bottom: IOS26Theme.spacingXs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${draft.name} · ${draft.minCount}$max',
              style: IOS26Theme.bodySmall,
            ),
          ),
          IOS26IconButton(
            icon: CupertinoIcons.trash,
            semanticLabel: AppLocalizations.of(context)!.common_delete,
            onPressed: () => setState(() => _customItems.remove(draft)),
            tone: IOS26IconTone.danger,
          ),
        ],
      ),
    );
  }

  Widget _levelField(WorkPhotoHierarchyLevel level) {
    final l10n = AppLocalizations.of(context)!;
    final levelId = level.id;
    final selectedId = levelId == null ? null : _selectionByLevelId[levelId];
    WorkPhotoHierarchyOption? selected;
    for (final option in _options) {
      if (option.id == selectedId) {
        selected = option;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(level.name, style: IOS26Theme.bodySmall),
          const SizedBox(height: IOS26Theme.spacingXs),
          IOS26SelectField(
            text: selected?.name ?? l10n.work_photo_not_selected,
            isPlaceholder: selected == null,
            onPressed: levelId == null ? null : () => _pickOption(level),
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

  Future<void> _pickOption(WorkPhotoHierarchyLevel level) async {
    final levelId = level.id;
    if (levelId == null) return;
    final options = _options.where((e) => e.levelId == levelId).toList();
    final selected = await showCupertinoModalPopup<int?>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(level.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, null),
            child: Text(AppLocalizations.of(context)!.work_photo_not_selected),
          ),
          for (final option in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, option.id),
              child: Text(option.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.common_cancel),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _selectionByLevelId[levelId] = selected);
  }

  Future<void> _addCustomHierarchy() async {
    final l10n = AppLocalizations.of(context)!;
    final input = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_custom_hierarchy_title,
      placeholder: l10n.work_photo_custom_hierarchy_placeholder,
    );
    if (input == null || input.trim().isEmpty) return;
    final parts = input.split('/');
    final levelName = parts.first.trim();
    final optionName = parts.length > 1
        ? parts.sublist(1).join('/').trim()
        : '';
    if (levelName.isEmpty && optionName.isEmpty) return;
    setState(() {
      _customHierarchy.add(
        _CustomHierarchyDraft(
          levelName: levelName.isEmpty
              ? l10n.work_photo_custom_level_default
              : levelName,
          optionName: optionName,
        ),
      );
    });
  }

  Future<void> _addCustomItem() async {
    final l10n = AppLocalizations.of(context)!;
    final input = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_capture_item_name_title,
      placeholder: l10n.work_photo_custom_capture_item_placeholder,
    );
    if (input == null || input.trim().isEmpty) return;
    final parts = input.split('/');
    final name = parts.first.trim();
    if (name.isEmpty) return;
    var min = 1;
    int? max;
    if (parts.length > 1) {
      final parsed = int.tryParse(parts[1].trim());
      if (parsed != null && parsed >= 0) min = parsed;
    }
    if (parts.length > 2 && parts[2].trim().isNotEmpty) {
      final parsed = int.tryParse(parts[2].trim());
      if (parsed != null && parsed >= min) max = parsed;
    }
    setState(() {
      _customItems.add(
        _CustomCaptureItemDraft(
          name: name,
          sortIndex: _customItems.length,
          minCount: min,
          maxCount: max,
        ),
      );
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_customMode) {
      if (_customItems.isEmpty) {
        await AppDialogs.showInfo(
          context,
          title: l10n.work_photo_capture_items_section,
          content: l10n.work_photo_no_custom_capture_items_warning,
        );
        return;
      }
      await _repository.createCustomProject(
        name: name,
        note: _noteController.text,
        hierarchyValues: _customHierarchy
            .map(
              (draft) => WorkPhotoCustomHierarchyValue(
                levelName: draft.levelName,
                optionName: draft.optionName,
              ),
            )
            .toList(),
        captureItems: _customItems
            .map(
              (draft) => WorkPhotoCustomCaptureItem(
                name: draft.name,
                sortIndex: draft.sortIndex,
                minCount: draft.minCount,
                maxCount: draft.maxCount,
              ),
            )
            .toList(),
        now: DateTime.now(),
      );
    } else {
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
      final optionLevelIds = _options.map((e) => e.levelId).toSet();
      final selectedLevelIds = _selectedLevels
          .where((e) => optionLevelIds.contains(e.id))
          .map((e) => e.id)
          .whereType<int>()
          .toSet();
      final selections = _selectionByLevelId.entries
          .where((entry) => selectedLevelIds.contains(entry.key))
          .map(
            (entry) => WorkPhotoHierarchySelection(
              levelId: entry.key,
              optionId: entry.value,
            ),
          )
          .toList();
      await _repository.createProjectFromTemplate(
        name: name,
        note: _noteController.text,
        templateId: templateId,
        hierarchySelections: selections,
        now: DateTime.now(),
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}

class _CustomHierarchyDraft {
  final String levelName;
  final String optionName;

  const _CustomHierarchyDraft({
    required this.levelName,
    required this.optionName,
  });
}

class _CustomCaptureItemDraft {
  final String name;
  final int sortIndex;
  final int minCount;
  final int? maxCount;

  const _CustomCaptureItemDraft({
    required this.name,
    required this.sortIndex,
    required this.minCount,
    required this.maxCount,
  });
}

class _TemplateCounts {
  final Map<int, int> levels;
  final Map<int, int> items;

  const _TemplateCounts({required this.levels, required this.items});
}

class _TemplateConfig {
  final List<WorkPhotoHierarchyLevel> levels;
  final List<WorkPhotoHierarchyOption> options;
  final List<WorkPhotoCaptureItem> items;

  const _TemplateConfig({
    required this.levels,
    required this.options,
    required this.items,
  });

  const _TemplateConfig.empty()
    : levels = const [],
      options = const [],
      items = const [];
}
