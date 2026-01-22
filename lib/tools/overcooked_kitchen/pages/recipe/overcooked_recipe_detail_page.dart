import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/obj_store/obj_store_service.dart';
import '../../../../core/registry/tool_registry.dart';
import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../../tag_manager/pages/tag_manager_tool_page.dart';
import '../../overcooked_constants.dart';
import '../../models/overcooked_recipe.dart';
import '../../repository/overcooked_repository.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_image.dart';
import 'overcooked_recipe_edit_page.dart';

class OvercookedRecipeDetailPage extends StatefulWidget {
  final int recipeId;
  final OvercookedRepository? repository;

  const OvercookedRecipeDetailPage({
    super.key,
    required this.recipeId,
    this.repository,
  });

  @override
  State<OvercookedRecipeDetailPage> createState() =>
      _OvercookedRecipeDetailPageState();
}

class _OvercookedRecipeDetailPageState
    extends State<OvercookedRecipeDetailPage> {
  OvercookedRecipe? _recipe;
  Map<int, Tag> _tagsById = const {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = widget.repository ?? context.read<OvercookedRepository>();
      final tagService = context.read<TagService>();
      final r = await repo.getRecipe(widget.recipeId);
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
      final tags = <Tag>[
        ...typeTags,
        ...ingredientTags,
        ...sauceTags,
        ...flavorTags,
      ];
      setState(() {
        _recipe = r;
        _tagsById = {
          for (final t in tags)
            if (t.id != null) t.id!: t,
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    final repo = widget.repository ?? context.read<OvercookedRepository>();
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: '菜谱详情',
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: '编辑',
            onPressed: recipe == null
                ? null
                : () async {
                    await Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => OvercookedRecipeEditPage(
                          initial: recipe,
                          repository: repo,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    await _refresh();
                  },
            icon: const Icon(
              CupertinoIcons.pencil,
              color: IOS26Theme.primaryColor,
            ),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: recipe == null
                ? null
                : () async {
                    final ok = await OvercookedDialogs.confirm(
                      context,
                      title: '删除菜谱？',
                      content: '将同时移除相关愿望单与三餐记录引用。',
                      confirmText: '删除',
                      isDestructive: true,
                    );
                    if (!ok) return;
                    if (!context.mounted) return;
                    await repo.deleteRecipe(recipe.id!);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
            icon: const Icon(CupertinoIcons.delete, color: IOS26Theme.toolRed),
          ),
        ],
      ),
      body: _loading && recipe == null
          ? const Center(child: CircularProgressIndicator())
          : recipe == null
          ? const Center(
              child: Text(
                '未找到菜谱',
                style: TextStyle(color: IOS26Theme.textSecondary),
              ),
            )
          : _buildContent(context, recipe),
    );
  }

  Widget _buildContent(BuildContext context, OvercookedRecipe recipe) {
    final objStore = context.read<ObjStoreService>();
    final typeName = recipe.typeTagId == null
        ? null
        : _tagsById[recipe.typeTagId!]?.name;
    final ingredients = recipe.ingredientTagIds
        .map((id) => _tagsById[id]?.name)
        .whereType<String>()
        .toList();
    final sauces = recipe.sauceTagIds
        .map((id) => _tagsById[id]?.name)
        .whereType<String>()
        .toList();
    final flavors =
        recipe.flavorTagIds
            .map((id) => _tagsById[id]?.name)
            .whereType<String>()
            .toList()
          ..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SizedBox(
          height: 220,
          child: OvercookedImageByKey(
            objStoreService: objStore,
            objectKey: recipe.coverImageKey,
            borderRadius: 20,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          recipe.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: IOS26Theme.textPrimary,
          ),
        ),
        if (typeName != null && typeName.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _chipsRow(title: '风格', values: [typeName]),
        ],
        if (flavors.isNotEmpty) ...[
          const SizedBox(height: 8),
          _chipsRow(title: '风味', values: flavors, color: IOS26Theme.toolPink),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 10),
          _chipsRow(
            title: '主料',
            values: ingredients,
            color: IOS26Theme.toolGreen,
          ),
        ],
        if (sauces.isNotEmpty) ...[
          const SizedBox(height: 10),
          _chipsRow(title: '调味', values: sauces, color: IOS26Theme.toolOrange),
        ],
        if (recipe.intro.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _sectionTitle('简介'),
          const SizedBox(height: 8),
          Text(
            recipe.intro.trim(),
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: IOS26Theme.textPrimary,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _sectionTitle('详细内容'),
        const SizedBox(height: 8),
        Text(
          recipe.content.trim().isEmpty ? '（暂无）' : recipe.content.trim(),
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: recipe.content.trim().isEmpty
                ? IOS26Theme.textSecondary
                : IOS26Theme.textPrimary,
          ),
        ),
        if (recipe.detailImageKeys.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('详细图片'),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recipe.detailImageKeys.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final key = recipe.detailImageKeys[index];
                return SizedBox(
                  width: 140,
                  child: OvercookedImageByKey(
                    objStoreService: objStore,
                    objectKey: key,
                    borderRadius: 18,
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (_tagsById.isEmpty)
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: IOS26Theme.textPrimary,
      ),
    );
  }

  Widget _chipsRow({
    required String title,
    required List<String> values,
    Color color = IOS26Theme.toolPurple,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$title：',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: IOS26Theme.textSecondary,
          ),
        ),
        ...values.map(
          (v) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Text(
              v,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
