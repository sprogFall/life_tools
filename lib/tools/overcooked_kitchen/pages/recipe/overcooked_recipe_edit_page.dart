import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ai/ai_errors.dart';
import '../../../../core/ai/ai_service.dart';
import '../../../../core/obj_store/obj_store_errors.dart';
import '../../../../core/obj_store/obj_store_service.dart';
import '../../../../core/registry/tool_registry.dart';
import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../../../core/utils/dev_log.dart';
import '../../../../core/utils/image_selector.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../pages/obj_store_settings_page.dart';
import '../../../tag_manager/pages/tag_manager_tool_page.dart';
import '../../ai/overcooked_recipe_ai_assistant.dart';
import '../../overcooked_constants.dart';
import '../../models/overcooked_recipe.dart';
import '../../repository/overcooked_repository.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_image.dart';
import '../../widgets/overcooked_tag_picker_sheet.dart';

class OvercookedRecipeEditPage extends StatefulWidget {
  final OvercookedRecipe? initial;
  final OvercookedRepository? repository;
  final OvercookedRecipeAiAssistant? aiAssistant;

  const OvercookedRecipeEditPage({
    super.key,
    this.initial,
    this.repository,
    this.aiAssistant,
  });

  @override
  State<OvercookedRecipeEditPage> createState() =>
      _OvercookedRecipeEditPageState();
}

class _OvercookedRecipeEditPageState extends State<OvercookedRecipeEditPage> {
  final _nameController = TextEditingController();
  final _introController = TextEditingController();
  final _contentController = TextEditingController();

  bool _saving = false;
  bool _loading = false;
  bool _generatingContent = false;

  String? _coverKey;
  List<String> _detailKeys = [];

  PickedImageBytes? _pendingCover;
  final List<PickedImageBytes> _pendingDetailImages = [];

  int? _typeTagId;
  Set<int> _ingredientTagIds = {};
  Set<int> _sauceTagIds = {};
  Set<int> _flavorTagIds = {};

  List<Tag> _typeTags = const [];
  List<Tag> _ingredientTags = const [];
  List<Tag> _sauceTags = const [];
  List<Tag> _flavorTags = const [];
  Map<int, Tag> _tagsById = const {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _nameController.text = initial.name;
      _introController.text = initial.intro;
      _contentController.text = initial.content;
      _coverKey = initial.coverImageKey;
      _detailKeys = [...initial.detailImageKeys];
      _typeTagId = initial.typeTagId;
      _ingredientTagIds = initial.ingredientTagIds.toSet();
      _sauceTagIds = initial.sauceTagIds.toSet();
      _flavorTagIds = initial.flavorTagIds.toSet();
    }
    _loadTags();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final tagService = context.read<TagService>();
      final typeTags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.dishType,
      );
      final ingredientTags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.ingredient,
      );
      final sauceTags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.sauce,
      );
      final flavorTags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.flavor,
      );
      final all = <Tag>[
        ...typeTags,
        ...ingredientTags,
        ...sauceTags,
        ...flavorTags,
      ];
      setState(() {
        _typeTags = typeTags;
        _ingredientTags = ingredientTags;
        _sauceTags = sauceTags;
        _flavorTags = flavorTags;
        _tagsById = {
          for (final t in all)
            if (t.id != null) t.id!: t,
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: widget.initial == null ? '新建菜谱' : '编辑菜谱',
        showBackButton: true,
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: IOS26Theme.minimumTapSize,
            onPressed: _saving || _generatingContent ? null : _save,
            child: Text(
              _saving ? '保存中…' : '保存',
              style: IOS26Theme.labelLarge.copyWith(
                color: _saving
                    ? IOS26Theme.textTertiary
                    : IOS26Theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(context),
          if (_saving || _generatingContent)
            Positioned.fill(
              child: Container(
                color: IOS26Theme.overlayColor,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 14),
                    const SizedBox(height: IOS26Theme.spacingSm),
                    Text(
                      _saving
                          ? '保存中…'
                          : l10n.overcooked_recipe_edit_ai_generating_overlay,
                      style: IOS26Theme.bodyMedium.copyWith(
                        color: IOS26Theme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final objStore = context.read<ObjStoreService>();
    final primaryButton = IOS26Theme.buttonColors(IOS26ButtonVariant.primary);
    final ghostButton = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);
    final highlightButton = IOS26Theme.buttonColors(
      IOS26ButtonVariant.highlight,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        IOS26Theme.spacingLg,
        IOS26Theme.spacingMd,
        IOS26Theme.spacingLg,
        IOS26Theme.spacingXxl,
      ),
      children: [
        _fieldTitle('菜名'),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _nameController,
          placeholder: '如：宫保鸡丁',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        const SizedBox(height: 14),
        _fieldTitle('菜的图片（封面）'),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child: Stack(
            children: [
              Positioned.fill(
                child: _pendingCover == null
                    ? OvercookedImageByKey(
                        objStoreService: objStore,
                        objectKey: _coverKey,
                        borderRadius: 20,
                      )
                    : _buildPendingImage(_pendingCover!, borderRadius: 20),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      color: primaryButton.background,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _saving ? null : _pickCover,
                      child: Text(
                        '上传',
                        style: IOS26Theme.labelLarge.copyWith(
                          color: primaryButton.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      color: ghostButton.background,
                      borderRadius: BorderRadius.circular(14),
                      onPressed:
                          _saving ||
                              (_coverKey == null && _pendingCover == null)
                          ? null
                          : () async {
                              final pending = _pendingCover;
                              if (pending != null) {
                                if (!mounted) return;
                                setState(() => _pendingCover = null);
                              } else {
                                setState(() => _coverKey = null);
                              }
                            },
                      child: Icon(
                        CupertinoIcons.trash,
                        color: ghostButton.foreground,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _fieldTitle('菜品风格（来自标签）'),
        const SizedBox(height: 8),
        _tagSingleField(
          label: _typeTagId == null
              ? '未选择'
              : (_tagsById[_typeTagId!]?.name ?? '未选择'),
          onPressed: _saving
              ? null
              : () async {
                  final selected = await OvercookedTagPickerSheet.show(
                    context,
                    title: '选择菜品风格',
                    tags: _typeTags,
                    selectedIds: _typeTagId == null ? {} : {_typeTagId!},
                    multi: false,
                    createHint: OvercookedTagUtils.createHint(
                      context,
                      OvercookedTagCategories.dishType,
                    ),
                    onCreateTag: (name) => OvercookedTagUtils.createTag(
                      context,
                      categoryId: OvercookedTagCategories.dishType,
                      name: name,
                    ),
                  );
                  if (selected == null || !mounted) return;
                  if (selected.tagsChanged) {
                    await _loadTags();
                    if (!mounted) return;
                  }
                  setState(() {
                    _typeTagId = selected.selectedIds.isEmpty
                        ? null
                        : selected.selectedIds.first;
                  });
                },
        ),
        const SizedBox(height: 14),
        _fieldTitle('主料（来自标签）'),
        const SizedBox(height: 8),
        _tagMultiField(
          selectedIds: _ingredientTagIds,
          tagsById: _tagsById,
          emptyText: '未选择',
          onPressed: _saving
              ? null
              : () async {
                  final selected = await OvercookedTagPickerSheet.show(
                    context,
                    title: '选择主料',
                    tags: _ingredientTags,
                    selectedIds: _ingredientTagIds,
                    multi: true,
                    createHint: OvercookedTagUtils.createHint(
                      context,
                      OvercookedTagCategories.ingredient,
                    ),
                    onCreateTag: (name) => OvercookedTagUtils.createTag(
                      context,
                      categoryId: OvercookedTagCategories.ingredient,
                      name: name,
                    ),
                  );
                  if (selected == null || !mounted) return;
                  if (selected.tagsChanged) {
                    await _loadTags();
                    if (!mounted) return;
                  }
                  setState(() => _ingredientTagIds = selected.selectedIds);
                },
        ),
        const SizedBox(height: 14),
        _fieldTitle('调味（来自标签）'),
        const SizedBox(height: 8),
        _tagMultiField(
          selectedIds: _sauceTagIds,
          tagsById: _tagsById,
          emptyText: '未选择',
          onPressed: _saving
              ? null
              : () async {
                  final selected = await OvercookedTagPickerSheet.show(
                    context,
                    title: '选择调味',
                    tags: _sauceTags,
                    selectedIds: _sauceTagIds,
                    multi: true,
                    createHint: OvercookedTagUtils.createHint(
                      context,
                      OvercookedTagCategories.sauce,
                    ),
                    onCreateTag: (name) => OvercookedTagUtils.createTag(
                      context,
                      categoryId: OvercookedTagCategories.sauce,
                      name: name,
                    ),
                  );
                  if (selected == null || !mounted) return;
                  if (selected.tagsChanged) {
                    await _loadTags();
                    if (!mounted) return;
                  }
                  setState(() => _sauceTagIds = selected.selectedIds);
                },
        ),
        const SizedBox(height: 14),
        _fieldTitle('简介'),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _introController,
          placeholder: '如：下饭神器 / 15分钟搞定…',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        _fieldTitle('风味（来自标签，可多选）'),
        const SizedBox(height: 8),
        _tagMultiField(
          selectedIds: _flavorTagIds,
          tagsById: _tagsById,
          emptyText: '未选择',
          onPressed: _saving || _flavorTags.isEmpty
              ? null
              : () async {
                  final selected = await OvercookedTagPickerSheet.show(
                    context,
                    title: '选择风味',
                    tags: _flavorTags,
                    selectedIds: _flavorTagIds,
                    multi: true,
                    createHint: OvercookedTagUtils.createHint(
                      context,
                      OvercookedTagCategories.flavor,
                    ),
                    onCreateTag: (name) => OvercookedTagUtils.createTag(
                      context,
                      categoryId: OvercookedTagCategories.flavor,
                      name: name,
                    ),
                  );
                  if (selected == null || !mounted) return;
                  if (selected.tagsChanged) {
                    await _loadTags();
                    if (!mounted) return;
                  }
                  setState(() => _flavorTagIds = selected.selectedIds);
                },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _fieldTitle('详细内容')),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: IOS26Theme.spacingSm,
                vertical: IOS26Theme.spacingXs,
              ),
              minimumSize: IOS26Theme.minimumTapSize,
              borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
              color: highlightButton.background,
              onPressed: _saving || _generatingContent
                  ? null
                  : _generateContentByAi,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 14,
                    color: highlightButton.foreground,
                  ),
                  const SizedBox(width: IOS26Theme.spacingXs),
                  Text(
                    l10n.overcooked_recipe_edit_ai_generate,
                    style: IOS26Theme.bodySmall.copyWith(
                      color: highlightButton.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _contentController,
          placeholder: '写下步骤、火候、注意事项…',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          maxLines: 8,
        ),
        const SizedBox(height: IOS26Theme.spacingXs),
        Text(
          l10n.overcooked_recipe_edit_markdown_hint,
          style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
        ),
        const SizedBox(height: 14),
        _fieldTitle('详细图片（可多选）'),
        const SizedBox(height: 8),
        if (_detailKeys.isEmpty && _pendingDetailImages.isEmpty)
          Container(
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ghostButton.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text('暂无图片', style: IOS26Theme.bodySmall),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _detailKeys.length + _pendingDetailImages.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isUploaded = index < _detailKeys.length;
                return Stack(
                  children: [
                    SizedBox(
                      width: 140,
                      child: isUploaded
                          ? OvercookedImageByKey(
                              objStoreService: objStore,
                              objectKey: _detailKeys[index],
                              borderRadius: 18,
                            )
                          : _buildPendingImage(
                              _pendingDetailImages[index - _detailKeys.length],
                              borderRadius: 18,
                            ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: _saving
                            ? null
                            : () => setState(() {
                                if (isUploaded) {
                                  _detailKeys.removeAt(index);
                                } else {
                                  final pendingIndex =
                                      index - _detailKeys.length;
                                  _pendingDetailImages.removeAt(pendingIndex);
                                }
                              }),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: IOS26Theme.toolRed.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 14,
                            color: primaryButton.foreground,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: primaryButton.background,
          borderRadius: BorderRadius.circular(14),
          onPressed: _saving ? null : _pickDetailImages,
          child: Text(
            '添加图片',
            style: IOS26Theme.labelLarge.copyWith(
              color: primaryButton.foreground,
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 10),
              child: CupertinoActivityIndicator(),
            ),
          ),
        if (_typeTags.isEmpty &&
            _ingredientTags.isEmpty &&
            _sauceTags.isEmpty &&
            _flavorTags.isEmpty)
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            color: IOS26Theme.toolPurple.withValues(alpha: 0.10),
            border: Border.all(
              color: IOS26Theme.toolPurple.withValues(alpha: 0.25),
              width: 1,
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.tag,
                  size: 18,
                  color: IOS26Theme.toolPurple,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '暂无可用标签，请先在“标签管理”中创建并关联到“胡闹厨房”',
                    style: IOS26Theme.bodySmall.copyWith(height: 1.25),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final tool = ToolRegistry.instance
                        .getById('tag_manager')
                        ?.pageBuilder();
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => tool ?? const TagManagerToolPage(),
                      ),
                    );
                  },
                  child: const Text('去管理'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _fieldTitle(String text) {
    return Text(text, style: IOS26Theme.titleSmall);
  }

  Widget _buildPendingImage(
    PickedImageBytes img, {
    required double borderRadius,
    BoxFit fit = BoxFit.cover,
  }) {
    if (img.bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(img.bytes, fit: fit),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text('暂无图片', style: IOS26Theme.bodySmall),
    );
  }

  Widget _tagSingleField({
    required String label,
    required VoidCallback? onPressed,
  }) {
    final ghostButton = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);
    return SizedBox(
      height: 48,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: ghostButton.background,
        borderRadius: BorderRadius.circular(14),
        onPressed: onPressed,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IOS26Theme.titleSmall.copyWith(
                  color: label == '未选择'
                      ? IOS26Theme.textSecondary
                      : IOS26Theme.textPrimary,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: IOS26Theme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagMultiField({
    required Set<int> selectedIds,
    required Map<int, Tag> tagsById,
    required String emptyText,
    required VoidCallback? onPressed,
  }) {
    final ghostButton = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);
    final names =
        selectedIds.map((id) => tagsById[id]?.name).whereType<String>().toList()
          ..sort();
    final text = names.isEmpty ? emptyText : names.join('、');
    return SizedBox(
      height: 48,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: ghostButton.background,
        borderRadius: BorderRadius.circular(14),
        onPressed: onPressed,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IOS26Theme.titleSmall.copyWith(
                  color: names.isEmpty
                      ? IOS26Theme.textSecondary
                      : IOS26Theme.textPrimary,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: IOS26Theme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCover() async {
    final picked = await ImageSelector.pickSingle();
    if (!mounted) return;
    if (picked == null) return;
    setState(() => _pendingCover = picked);
  }

  Future<void> _pickDetailImages() async {
    final picked = await ImageSelector.pickMulti();
    if (!mounted) return;
    if (picked.isEmpty) return;
    setState(() => _pendingDetailImages.addAll(picked));
  }

  Future<void> _openObjStoreSettings() async {
    await OvercookedDialogs.showMessage(
      context,
      title: '未配置资源存储',
      content: '请先到“设置 -> 资源存储”完成配置后再上传图片。',
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const ObjStoreSettingsPage()),
    );
  }

  Future<bool> _commitPendingUploads() async {
    final objStore = context.read<ObjStoreService>();

    try {
      final cover = _pendingCover;
      if (cover != null) {
        final uploadedKey = await _uploadPendingImage(
          objStore: objStore,
          img: cover,
        );
        if (!mounted) return false;
        setState(() {
          _coverKey = uploadedKey;
          _pendingCover = null;
        });
      }

      while (_pendingDetailImages.isNotEmpty) {
        final img = _pendingDetailImages.first;
        final uploadedKey = await _uploadPendingImage(
          objStore: objStore,
          img: img,
        );
        if (!mounted) return false;
        setState(() {
          _detailKeys.add(uploadedKey);
          _pendingDetailImages.removeAt(0);
        });
      }

      return true;
    } on ObjStoreNotConfiguredException catch (_) {
      if (!mounted) return false;
      await _openObjStoreSettings();
      return false;
    } catch (e) {
      if (!mounted) return false;
      await OvercookedDialogs.showMessage(
        context,
        title: '上传失败',
        content: e.toString(),
      );
      return false;
    }
  }

  Future<String> _uploadPendingImage({
    required ObjStoreService objStore,
    required PickedImageBytes img,
  }) async {
    final uploaded = await objStore.uploadBytes(
      bytes: img.bytes,
      filename: img.filename,
    );
    return uploaded.key;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '请填写菜名',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = widget.repository ?? context.read<OvercookedRepository>();
      final now = DateTime.now();

      final ok = await _commitPendingUploads();
      if (!ok) return;

      final base = widget.initial;
      if (base == null) {
        final id = await repo.createRecipe(
          OvercookedRecipe.create(
            name: name,
            coverImageKey: _coverKey,
            typeTagId: _typeTagId,
            ingredientTagIds: _ingredientTagIds.toList(),
            sauceTagIds: _sauceTagIds.toList(),
            intro: _introController.text,
            flavorTagIds: _flavorTagIds.toList(),
            content: _contentController.text,
            detailImageKeys: _detailKeys,
            now: now,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(id);
        return;
      }

      await repo.updateRecipe(
        base.copyWith(
          name: name,
          coverImageKey: _coverKey,
          typeTagId: _typeTagId,
          ingredientTagIds: _ingredientTagIds.toList(),
          sauceTagIds: _sauceTagIds.toList(),
          intro: _introController.text,
          flavorTagIds: _flavorTagIds.toList(),
          content: _contentController.text,
          detailImageKeys: _detailKeys,
        ),
        now: now,
      );
      if (!mounted) return;
      Navigator.of(context).pop(base.id);
    } catch (e) {
      if (!mounted) return;
      await OvercookedDialogs.showMessage(
        context,
        title: '保存失败',
        content: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  OvercookedRecipeAiAssistant? _createAiAssistant() {
    if (widget.aiAssistant != null) {
      return widget.aiAssistant;
    }

    try {
      final aiService = context.read<AiService>();
      return DefaultOvercookedRecipeAiAssistant(aiService: aiService);
    } on ProviderNotFoundException catch (error, stackTrace) {
      devLog(
        'OvercookedRecipeEditPage 未注入 AiService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  List<String> _tagNames(Set<int> selectedIds) {
    final names =
        selectedIds
            .map((id) => _tagsById[id]?.name.trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toList(growable: false)
          ..sort();
    return names;
  }

  Future<void> _generateContentByAi() async {
    final l10n = AppLocalizations.of(context)!;
    if (_saving || _generatingContent) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: l10n.overcooked_recipe_edit_ai_need_name_content,
      );
      return;
    }

    final assistant = _createAiAssistant();
    if (assistant == null) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: l10n.overcooked_recipe_edit_ai_service_missing_content,
      );
      return;
    }

    final style = _typeTagId == null ? null : _tagsById[_typeTagId!]?.name;

    setState(() => _generatingContent = true);
    try {
      final generated = await assistant.generateRecipeMarkdown(
        name: name,
        style: style,
        ingredients: _tagNames(_ingredientTagIds),
        sauces: _tagNames(_sauceTagIds),
        flavors: _tagNames(_flavorTagIds),
        intro: _introController.text.trim(),
      );
      if (!mounted) return;
      final content = generated.trim();
      if (content.isEmpty) {
        await OvercookedDialogs.showMessage(
          context,
          title: '生成失败',
          content: l10n.overcooked_recipe_edit_ai_empty_content,
        );
        return;
      }
      setState(() {
        _contentController.text = content;
        _contentController.selection = TextSelection.fromPosition(
          TextPosition(offset: content.length),
        );
      });
    } on AiNotConfiguredException {
      if (!mounted) return;
      await OvercookedDialogs.showMessage(
        context,
        title: 'AI 未配置',
        content: l10n.overcooked_recipe_edit_ai_not_configured_content,
      );
    } catch (error, stackTrace) {
      devLog('胡闹厨房菜谱 AI 生成失败', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      await OvercookedDialogs.showMessage(
        context,
        title: 'AI 生成失败',
        content: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _generatingContent = false);
    }
  }
}
