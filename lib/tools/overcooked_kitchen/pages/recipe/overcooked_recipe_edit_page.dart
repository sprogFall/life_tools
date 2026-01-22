import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/obj_store/obj_store_errors.dart';
import '../../../../core/obj_store/obj_store_service.dart';
import '../../../../core/registry/tool_registry.dart';
import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../../../pages/obj_store_settings_page.dart';
import '../../../tag_manager/pages/tag_manager_tool_page.dart';
import '../../overcooked_constants.dart';
import '../../models/overcooked_flavor.dart';
import '../../models/overcooked_recipe.dart';
import '../../repository/overcooked_repository.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_image.dart';
import '../../widgets/overcooked_tag_picker_sheet.dart';

class OvercookedRecipeEditPage extends StatefulWidget {
  final OvercookedRecipe? initial;

  const OvercookedRecipeEditPage({super.key, this.initial});

  @override
  State<OvercookedRecipeEditPage> createState() => _OvercookedRecipeEditPageState();
}

class _OvercookedRecipeEditPageState extends State<OvercookedRecipeEditPage> {
  final _nameController = TextEditingController();
  final _introController = TextEditingController();
  final _contentController = TextEditingController();

  bool _saving = false;
  bool _loading = false;

  String? _coverKey;
  List<String> _detailKeys = [];

  int? _typeTagId;
  Set<int> _ingredientTagIds = {};
  Set<int> _sauceTagIds = {};
  Set<OvercookedFlavor> _flavors = {};

  List<Tag> _typeTags = const [];
  List<Tag> _ingredientTags = const [];
  List<Tag> _sauceTags = const [];
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
      _flavors = {...initial.flavors};
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
      final all = <Tag>[...typeTags, ...ingredientTags, ...sauceTags];
      setState(() {
        _typeTags = typeTags;
        _ingredientTags = ingredientTags;
        _sauceTags = sauceTags;
        _tagsById = {for (final t in all) if (t.id != null) t.id!: t};
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: widget.initial == null ? '新建菜谱' : '编辑菜谱',
        showBackButton: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '保存中…' : '保存',
              style: TextStyle(
                color: _saving ? IOS26Theme.textTertiary : IOS26Theme.primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final objStore = context.read<ObjStoreService>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
                child: OvercookedImageByKey(
                  objStoreService: objStore,
                  objectKey: _coverKey,
                  borderRadius: 20,
                ),
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
                      color: IOS26Theme.primaryColor,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _saving ? null : _pickCover,
                      child: const Text(
                        '上传',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                      onPressed:
                          _coverKey == null || _saving
                              ? null
                              : () => setState(() => _coverKey = null),
                      child: const Icon(
                        CupertinoIcons.trash,
                        color: IOS26Theme.textSecondary,
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
        _fieldTitle('菜的类型（来自标签）'),
        const SizedBox(height: 8),
        _tagSingleField(
          label:
              _typeTagId == null
                  ? '未选择'
                  : (_tagsById[_typeTagId!]?.name ?? '未选择'),
          onPressed:
              _saving
                  ? null
                  : () async {
                    final selected = await OvercookedTagPickerSheet.show(
                      context,
                      title: '选择菜的类型',
                      tags: _typeTags,
                      selectedIds: _typeTagId == null ? {} : {_typeTagId!},
                      multi: false,
                    );
                    if (selected == null) return;
                    setState(
                      () => _typeTagId = selected.isEmpty ? null : selected.first,
                    );
                  },
        ),
        const SizedBox(height: 14),
        _fieldTitle('食材（来自标签）'),
        const SizedBox(height: 8),
        _tagMultiField(
          selectedIds: _ingredientTagIds,
          tagsById: _tagsById,
          emptyText: '未选择',
          onPressed:
              _saving
                  ? null
                  : () async {
                    final selected = await OvercookedTagPickerSheet.show(
                      context,
                      title: '选择食材',
                      tags: _ingredientTags,
                      selectedIds: _ingredientTagIds,
                      multi: true,
                    );
                    if (selected == null) return;
                    setState(() => _ingredientTagIds = selected);
                  },
        ),
        const SizedBox(height: 14),
        _fieldTitle('酱料（来自标签）'),
        const SizedBox(height: 8),
        _tagMultiField(
          selectedIds: _sauceTagIds,
          tagsById: _tagsById,
          emptyText: '未选择',
          onPressed:
              _saving
                  ? null
                  : () async {
                    final selected = await OvercookedTagPickerSheet.show(
                      context,
                      title: '选择酱料',
                      tags: _sauceTags,
                      selectedIds: _sauceTagIds,
                      multi: true,
                    );
                    if (selected == null) return;
                    setState(() => _sauceTagIds = selected);
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
        _fieldTitle('口味（可多选）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              OvercookedFlavor.values.map((f) {
                final selected = _flavors.contains(f);
                return _chip(
                  label: f.label,
                  selected: selected,
                  color: IOS26Theme.toolPink,
                  onTap:
                      _saving
                          ? null
                          : () => setState(() {
                            if (selected) {
                              _flavors.remove(f);
                            } else {
                              _flavors.add(f);
                            }
                          }),
                );
              }).toList(),
        ),
        const SizedBox(height: 14),
        _fieldTitle('详细内容'),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _contentController,
          placeholder: '写下步骤、火候、注意事项…',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          maxLines: 8,
        ),
        const SizedBox(height: 14),
        _fieldTitle('详细图片（可多选）'),
        const SizedBox(height: 8),
        if (_detailKeys.isEmpty)
          Container(
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '暂无图片',
              style: TextStyle(color: IOS26Theme.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _detailKeys.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final key = _detailKeys[index];
                return Stack(
                  children: [
                    SizedBox(
                      width: 140,
                      child: OvercookedImageByKey(
                        objStoreService: objStore,
                        objectKey: key,
                        borderRadius: 18,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap:
                            _saving
                                ? null
                                : () => setState(() {
                                  _detailKeys.removeAt(index);
                                }),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: IOS26Theme.toolRed.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            size: 14,
                            color: Colors.white,
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
          color: IOS26Theme.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onPressed: _saving ? null : _pickDetailImages,
          child: const Text(
            '添加图片',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 18),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 10),
              child: CircularProgressIndicator(),
            ),
          ),
        if (_typeTags.isEmpty && _ingredientTags.isEmpty && _sauceTags.isEmpty)
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
                const Icon(
                  CupertinoIcons.tag,
                  size: 18,
                  color: IOS26Theme.toolPurple,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '暂无可用标签，请先在“标签管理”中创建并关联到“胡闹厨房”',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: IOS26Theme.textPrimary,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final tool =
                        ToolRegistry.instance.getById('tag_manager')?.pageBuilder();
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
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: IOS26Theme.textPrimary,
      ),
    );
  }

  Widget _tagSingleField({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        onPressed: onPressed,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: label == '未选择'
                      ? IOS26Theme.textSecondary
                      : IOS26Theme.textPrimary,
                ),
              ),
            ),
            const Icon(
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
    final names =
        selectedIds
            .map((id) => tagsById[id]?.name)
            .whereType<String>()
            .toList()
          ..sort();
    final text = names.isEmpty ? emptyText : names.join('、');
    return SizedBox(
      height: 48,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        onPressed: onPressed,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: names.isEmpty
                      ? IOS26Theme.textSecondary
                      : IOS26Theme.textPrimary,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: IOS26Theme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Future<void> _pickCover() async {
    final key = await _pickAndUploadOneImage();
    if (key == null) return;
    setState(() => _coverKey = key);
  }

  Future<void> _pickDetailImages() async {
    final keys = await _pickAndUploadManyImages();
    if (keys.isEmpty) return;
    setState(() => _detailKeys.addAll(keys));
  }

  Future<String?> _pickAndUploadOneImage() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    if (!mounted) return null;
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '无法读取图片内容，请重新选择',
      );
      return null;
    }
    return _uploadBytes(bytes: bytes, filename: file.name);
  }

  Future<List<String>> _pickAndUploadManyImages() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.image,
    );
    if (!mounted) return const [];
    if (result == null || result.files.isEmpty) return const [];
    final objStore = context.read<ObjStoreService>();

    setState(() => _saving = true);
    try {
      final keys = <String>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        final uploaded = await objStore.uploadBytes(
          bytes: bytes,
          filename: f.name,
        );
        keys.add(uploaded.key);
      }
      return keys;
    } on ObjStoreNotConfiguredException catch (_) {
      if (!mounted) return const [];
      await _openObjStoreSettings();
      return const [];
    } catch (e) {
      if (!mounted) return const [];
      await OvercookedDialogs.showMessage(
        context,
        title: '上传失败',
        content: e.toString(),
      );
      return const [];
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _uploadBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final objStore = context.read<ObjStoreService>();
    setState(() => _saving = true);
    try {
      final uploaded = await objStore.uploadBytes(
        bytes: bytes,
        filename: filename,
      );
      return uploaded.key;
    } on ObjStoreNotConfiguredException catch (_) {
      if (!mounted) return null;
      await _openObjStoreSettings();
      return null;
    } catch (e) {
      if (!mounted) return null;
      await OvercookedDialogs.showMessage(
        context,
        title: '上传失败',
        content: e.toString(),
      );
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      final repo = context.read<OvercookedRepository>();
      final now = DateTime.now();

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
            flavors: _flavors,
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
          flavors: _flavors,
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
}
