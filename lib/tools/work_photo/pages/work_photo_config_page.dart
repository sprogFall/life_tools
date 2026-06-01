import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_capture_item.dart';
import '../models/work_photo_hierarchy_level.dart';
import '../models/work_photo_hierarchy_option.dart';
import '../models/work_photo_template.dart';
import '../repository/work_photo_repository.dart';

class WorkPhotoConfigPage extends StatefulWidget {
  final WorkPhotoRepository? repository;

  const WorkPhotoConfigPage({super.key, this.repository});

  @override
  State<WorkPhotoConfigPage> createState() => _WorkPhotoConfigPageState();
}

class _WorkPhotoConfigPageState extends State<WorkPhotoConfigPage> {
  late final WorkPhotoRepository _repository;
  bool _loading = true;
  List<WorkPhotoTemplate> _templates = const [];
  List<WorkPhotoHierarchyLevel> _allLevels = const [];
  List<WorkPhotoCaptureItem> _allItems = const [];
  List<WorkPhotoHierarchyLevel> _levels = const [];
  List<WorkPhotoHierarchyOption> _options = const [];
  List<WorkPhotoCaptureItem> _items = const [];
  int? _selectedTemplateId;

  WorkPhotoTemplate? get _selectedTemplate {
    final selectedId = _selectedTemplateId;
    if (selectedId == null) return null;
    for (final template in _templates) {
      if (template.id == selectedId) return template;
    }
    return null;
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
    var selectedTemplateId = _selectedTemplateId;
    final selectedStillExists = templates.any(
      (e) => e.id == selectedTemplateId,
    );
    if (!selectedStillExists) {
      selectedTemplateId = templates.isEmpty ? null : templates.first.id;
    }
    final levels = selectedTemplateId == null
        ? <WorkPhotoHierarchyLevel>[]
        : allLevels.where((e) => e.templateId == selectedTemplateId).toList();
    final options = <WorkPhotoHierarchyOption>[];
    for (final level in levels) {
      final levelId = level.id;
      if (levelId == null) continue;
      options.addAll(await _repository.listHierarchyOptions(levelId: levelId));
    }
    final items = selectedTemplateId == null
        ? <WorkPhotoCaptureItem>[]
        : allItems.where((e) => e.templateId == selectedTemplateId).toList();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _allLevels = allLevels;
      _allItems = allItems;
      _selectedTemplateId = selectedTemplateId;
      _levels = levels;
      _options = options;
      _items = items;
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
                  _sectionTitle(l10n.work_photo_templates_section),
                  _buildTemplateSelector(l10n),
                  IOS26Button(
                    onPressed: _addTemplate,
                    variant: IOS26ButtonVariant.secondary,
                    child: IOS26ButtonLabel(l10n.work_photo_add_template),
                  ),
                  const SizedBox(height: IOS26Theme.spacingXl),
                  if (_selectedTemplate != null) ...[
                    _sectionTitle(l10n.work_photo_levels_section),
                    if (_levels.isEmpty)
                      _emptyText(l10n.work_photo_no_hierarchy)
                    else
                      for (final level in _levels)
                        _buildLevelBlock(level, l10n),
                    const SizedBox(height: IOS26Theme.spacingMd),
                    IOS26Button(
                      onPressed: _addLevel,
                      variant: IOS26ButtonVariant.secondary,
                      child: IOS26ButtonLabel(l10n.work_photo_add_level),
                    ),
                    const SizedBox(height: IOS26Theme.spacingXl),
                    _sectionTitle(l10n.work_photo_capture_items_section),
                    if (_items.isEmpty)
                      _emptyText(l10n.work_photo_no_capture_items)
                    else
                      for (final item in _items) _buildItemRow(item, l10n),
                    const SizedBox(height: IOS26Theme.spacingMd),
                    IOS26Button(
                      onPressed: _addCaptureItem,
                      variant: IOS26ButtonVariant.secondary,
                      child: IOS26ButtonLabel(l10n.work_photo_add_capture_item),
                    ),
                  ],
                ],
              ),
            ),
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

  Widget _buildLevelBlock(
    WorkPhotoHierarchyLevel level,
    AppLocalizations l10n,
  ) {
    final levelIndex = _levels.indexWhere((e) => e.id == level.id);
    final options = _options.where((e) => e.levelId == level.id).toList();
    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      margin: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(level.name, style: IOS26Theme.titleMedium)),
              IOS26IconButton(
                icon: CupertinoIcons.ellipsis,
                semanticLabel: l10n.work_photo_config_actions,
                onPressed: () => _showLevelActions(level, levelIndex),
                tone: IOS26IconTone.secondary,
              ),
              IOS26Button.plain(
                padding: const EdgeInsets.symmetric(
                  horizontal: IOS26Theme.spacingSm,
                  vertical: IOS26Theme.spacingXs,
                ),
                onPressed: () => _addOption(level),
                child: IOS26ButtonLabel(l10n.work_photo_add_option),
              ),
            ],
          ),
          const SizedBox(height: IOS26Theme.spacingSm),
          if (options.isEmpty)
            Text(l10n.work_photo_no_hierarchy, style: IOS26Theme.bodySmall)
          else
            Wrap(
              spacing: IOS26Theme.spacingSm,
              runSpacing: IOS26Theme.spacingSm,
              children: [
                for (final option in options)
                  _buildOptionChip(option, options.indexOf(option)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector(AppLocalizations l10n) {
    if (_templates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
        child: _emptyText(l10n.work_photo_no_templates),
      );
    }

    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      margin: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final template in _templates) _buildTemplateRow(template, l10n),
        ],
      ),
    );
  }

  Widget _buildTemplateRow(WorkPhotoTemplate template, AppLocalizations l10n) {
    final id = template.id;
    if (id == null) return const SizedBox.shrink();
    final selected = id == _selectedTemplateId;
    final levelCount = _allLevels.where((e) => e.templateId == id).length;
    final itemCount = _allItems.where((e) => e.templateId == id).length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IOS26Theme.spacingXs),
      child: Row(
        children: [
          Expanded(
            child: IOS26Button.plain(
              padding: const EdgeInsets.symmetric(
                vertical: IOS26Theme.spacingSm,
              ),
              onPressed: () async {
                setState(() => _selectedTemplateId = id);
                await _reload();
              },
              child: Row(
                children: [
                  IOS26Icon(
                    selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    tone: selected
                        ? IOS26IconTone.accent
                        : IOS26IconTone.secondary,
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
                          l10n.work_photo_templates_summary(
                            levelCount,
                            itemCount,
                          ),
                          style: IOS26Theme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: IOS26Theme.spacingSm),
          IOS26IconButton(
            icon: CupertinoIcons.ellipsis,
            semanticLabel: l10n.work_photo_config_actions,
            onPressed: () => _showTemplateActions(template),
            tone: IOS26IconTone.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip(WorkPhotoHierarchyOption option, int optionIndex) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceVariant,
        borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
      ),
      child: IOS26Button.plain(
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingMd,
          vertical: IOS26Theme.spacingSm,
        ),
        minimumSize: Size.zero,
        borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
        onPressed: () => _showOptionActions(option, optionIndex),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.name, style: IOS26Theme.bodySmall),
            const SizedBox(width: IOS26Theme.spacingXs),
            IOS26Icon(
              CupertinoIcons.ellipsis,
              tone: IOS26IconTone.secondary,
              size: 14,
              semanticLabel: l10n.work_photo_config_actions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(WorkPhotoCaptureItem item, AppLocalizations l10n) {
    final itemIndex = _items.indexWhere((e) => e.id == item.id);
    final max = item.maxCount == null ? '' : ' / ${item.maxCount}';
    return GlassContainer(
      borderRadius: IOS26Theme.radiusLg,
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      margin: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
      child: Row(
        children: [
          const IOS26Icon(
            CupertinoIcons.camera,
            tone: IOS26IconTone.accent,
            size: 22,
          ),
          const SizedBox(width: IOS26Theme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: IOS26Theme.titleMedium),
                const SizedBox(height: IOS26Theme.spacingXs),
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
            onPressed: () => _showCaptureItemActions(item, itemIndex),
            tone: IOS26IconTone.secondary,
          ),
        ],
      ),
    );
  }

  Future<void> _addLevel() async {
    final l10n = AppLocalizations.of(context)!;
    final templateId = _selectedTemplateId;
    if (templateId == null) {
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_template_name_title,
        content: l10n.work_photo_no_templates_warning,
      );
      return;
    }
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_level_name_title,
      placeholder: l10n.work_photo_level_name_placeholder,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repository.createHierarchyLevel(
      WorkPhotoHierarchyLevel.create(
        templateId: templateId,
        name: name,
        sortIndex: _levels.length,
        now: DateTime.now(),
      ),
    );
    await _reload();
  }

  Future<void> _addOption(WorkPhotoHierarchyLevel level) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_option_name_title,
      placeholder: l10n.work_photo_option_name_placeholder,
    );
    if (name == null || name.trim().isEmpty || level.id == null) return;
    final currentCount = _options.where((e) => e.levelId == level.id).length;
    await _repository.createHierarchyOption(
      WorkPhotoHierarchyOption.create(
        levelId: level.id!,
        parentOptionId: null,
        name: name,
        sortIndex: currentCount,
        now: DateTime.now(),
      ),
    );
    await _reload();
  }

  Future<void> _addCaptureItem() async {
    final l10n = AppLocalizations.of(context)!;
    final templateId = _selectedTemplateId;
    if (templateId == null) {
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_template_name_title,
        content: l10n.work_photo_no_templates_warning,
      );
      return;
    }
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_capture_item_name_title,
      placeholder: l10n.work_photo_capture_item_name_placeholder,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repository.createCaptureItem(
      WorkPhotoCaptureItem.create(
        templateId: templateId,
        name: name,
        sortIndex: _items.length,
        minCount: 1,
        maxCount: null,
        now: DateTime.now(),
      ),
    );
    await _reload();
  }

  Future<void> _showLevelActions(
    WorkPhotoHierarchyLevel level,
    int index,
  ) async {
    final action = await _showConfigActionSheet(
      title: level.name,
      canMoveUp: index > 0,
      canMoveDown: index >= 0 && index < _levels.length - 1,
    );
    if (!mounted || action == null) return;

    if (action == _ConfigAction.rename) {
      await _renameLevel(level);
    } else if (action == _ConfigAction.moveUp) {
      await _moveLevel(level, -1);
    } else if (action == _ConfigAction.moveDown) {
      await _moveLevel(level, 1);
    } else if (action == _ConfigAction.archive) {
      await _archiveLevel(level);
    }
  }

  Future<void> _addTemplate() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_template_name_title,
      placeholder: l10n.work_photo_template_name_placeholder,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repository.createTemplate(
      WorkPhotoTemplate.create(
        name: name,
        sortIndex: _templates.length,
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
          onPressed: () => Navigator.pop(context, _ConfigAction.archive),
          child: Text(l10n.work_photo_archive),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.common_cancel),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ConfigAction.rename) {
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
    } else if (action == _ConfigAction.archive && template.id != null) {
      await _repository.updateTemplate(
        template.copyWith(isArchived: true, updatedAt: DateTime.now()),
      );
      await _reload();
    }
  }

  Future<void> _showOptionActions(
    WorkPhotoHierarchyOption option,
    int index,
  ) async {
    final siblings = _options
        .where((e) => e.levelId == option.levelId)
        .toList();
    final action = await _showConfigActionSheet(
      title: option.name,
      canMoveUp: index > 0,
      canMoveDown: index >= 0 && index < siblings.length - 1,
    );
    if (!mounted || action == null) return;

    if (action == _ConfigAction.rename) {
      await _renameOption(option);
    } else if (action == _ConfigAction.moveUp) {
      await _moveOption(option, -1);
    } else if (action == _ConfigAction.moveDown) {
      await _moveOption(option, 1);
    } else if (action == _ConfigAction.archive) {
      await _archiveOption(option);
    }
  }

  Future<void> _showCaptureItemActions(
    WorkPhotoCaptureItem item,
    int index,
  ) async {
    final action = await _showConfigActionSheet(
      title: item.name,
      canMoveUp: index > 0,
      canMoveDown: index >= 0 && index < _items.length - 1,
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
    } else if (action == _ConfigAction.archive) {
      await _archiveCaptureItem(item);
    }
  }

  Future<_ConfigAction?> _showConfigActionSheet({
    required String title,
    required bool canMoveUp,
    required bool canMoveDown,
    bool includeCounts = false,
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
          onPressed: () => Navigator.pop(context, _ConfigAction.archive),
          child: Text(l10n.work_photo_archive),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.common_cancel),
      ),
    );
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

  Future<void> _renameOption(WorkPhotoHierarchyOption option) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.work_photo_option_name_title,
      placeholder: l10n.work_photo_option_name_placeholder,
      defaultValue: option.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repository.updateHierarchyOption(
      option.copyWith(name: name, updatedAt: DateTime.now()),
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

  Future<void> _moveLevel(WorkPhotoHierarchyLevel level, int direction) async {
    final siblings = _levels
        .where((e) => e.templateId == level.templateId)
        .toList();
    final index = siblings.indexWhere((e) => e.id == level.id);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= siblings.length) {
      return;
    }
    final target = siblings[targetIndex];
    final now = DateTime.now();
    await _repository.updateHierarchyLevel(
      level.copyWith(sortIndex: target.sortIndex, updatedAt: now),
    );
    await _repository.updateHierarchyLevel(
      target.copyWith(sortIndex: level.sortIndex, updatedAt: now),
    );
    await _reload();
  }

  Future<void> _moveOption(
    WorkPhotoHierarchyOption option,
    int direction,
  ) async {
    final siblings = _options
        .where((e) => e.levelId == option.levelId)
        .toList();
    final index = siblings.indexWhere((e) => e.id == option.id);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= siblings.length) return;
    final target = siblings[targetIndex];
    final now = DateTime.now();
    await _repository.updateHierarchyOption(
      option.copyWith(sortIndex: target.sortIndex, updatedAt: now),
    );
    await _repository.updateHierarchyOption(
      target.copyWith(sortIndex: option.sortIndex, updatedAt: now),
    );
    await _reload();
  }

  Future<void> _moveCaptureItem(
    WorkPhotoCaptureItem item,
    int direction,
  ) async {
    final siblings = _items
        .where((e) => e.templateId == item.templateId)
        .toList();
    final index = siblings.indexWhere((e) => e.id == item.id);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= siblings.length) {
      return;
    }
    final target = siblings[targetIndex];
    final now = DateTime.now();
    await _repository.updateCaptureItem(
      item.copyWith(sortIndex: target.sortIndex, updatedAt: now),
    );
    await _repository.updateCaptureItem(
      target.copyWith(sortIndex: item.sortIndex, updatedAt: now),
    );
    await _reload();
  }

  Future<void> _archiveLevel(WorkPhotoHierarchyLevel level) async {
    await _repository.updateHierarchyLevel(
      level.copyWith(isArchived: true, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  Future<void> _archiveOption(WorkPhotoHierarchyOption option) async {
    await _repository.updateHierarchyOption(
      option.copyWith(isArchived: true, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  Future<void> _archiveCaptureItem(WorkPhotoCaptureItem item) async {
    await _repository.updateCaptureItem(
      item.copyWith(isArchived: true, updatedAt: DateTime.now()),
    );
    await _reload();
  }
}

enum _ConfigAction { rename, editCounts, moveUp, moveDown, archive }

class _CaptureCounts {
  final int min;
  final int? max;

  const _CaptureCounts(this.min, this.max);
}
