import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../core/widgets/ios26_select_field.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_hierarchy_level.dart';
import '../models/work_photo_hierarchy_option.dart';
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
  List<WorkPhotoHierarchyLevel> _levels = const [];
  List<WorkPhotoHierarchyOption> _options = const [];
  final Map<int, int?> _selectionByLevelId = {};

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
    final levels = await _repository.listHierarchyLevels();
    final options = await _repository.listHierarchyOptions();
    if (!mounted) return;
    setState(() {
      _levels = levels;
      _options = options;
      for (final level in levels) {
        final id = level.id;
        if (id != null) _selectionByLevelId.putIfAbsent(id, () => null);
      }
      _loading = false;
    });
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
                  _buildFormCard(
                    title: l10n.work_photo_project_name_label,
                    child: _buildTextField(
                      controller: _nameController,
                      placeholder: l10n.work_photo_project_name_placeholder,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  _buildFormCard(
                    title: l10n.work_photo_hierarchy_section,
                    child: Column(
                      children: [
                        if (_levels.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.work_photo_no_hierarchy,
                              style: IOS26Theme.bodyMedium,
                            ),
                          )
                        else
                          for (final level in _levels) _buildLevelField(level),
                      ],
                    ),
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  _buildFormCard(
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

  Widget _buildFormCard({required String title, required Widget child}) {
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

  Widget _buildLevelField(WorkPhotoHierarchyLevel level) {
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final captureItems = await _repository.listCaptureItems();
    if (captureItems.isEmpty) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.work_photo_capture_items_section,
        content: l10n.work_photo_no_capture_items_warning,
      );
      return;
    }
    final selections = _selectionByLevelId.entries
        .map(
          (entry) => WorkPhotoHierarchySelection(
            levelId: entry.key,
            optionId: entry.value,
          ),
        )
        .toList();
    await _repository.createProject(
      name: name,
      note: _noteController.text,
      hierarchySelections: selections,
      now: DateTime.now(),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
