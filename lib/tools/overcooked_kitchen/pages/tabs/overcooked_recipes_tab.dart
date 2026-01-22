import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/obj_store/obj_store_service.dart';
import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../overcooked_constants.dart';
import '../../models/overcooked_recipe.dart';
import '../../repository/overcooked_repository.dart';
import '../recipe/overcooked_recipe_detail_page.dart';
import '../recipe/overcooked_recipe_edit_page.dart';
import '../../widgets/overcooked_image.dart';

class OvercookedRecipesTab extends StatefulWidget {
  final VoidCallback? onJumpToGacha;

  const OvercookedRecipesTab({super.key, this.onJumpToGacha});

  @override
  State<OvercookedRecipesTab> createState() => _OvercookedRecipesTabState();
}

class _OvercookedRecipesTabState extends State<OvercookedRecipesTab> {
  bool _loading = false;
  String _query = '';
  List<OvercookedRecipe> _recipes = const [];
  Map<int, Tag> _tagsById = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = context.read<OvercookedRepository>();
      final tagService = context.read<TagService>();
      final recipes = await repo.listRecipes();
      final tags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.dishType,
      );
      setState(() {
        _recipes = recipes;
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
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _recipes
        : _recipes.where((r) => r.name.toLowerCase().contains(q)).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          CupertinoSearchTextField(
            placeholder: '搜索菜谱',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (_loading && _recipes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Center(
                child: Text(
                  _recipes.isEmpty ? '暂无菜谱，点右上角 + 新建' : '没有匹配的菜谱',
                  style: const TextStyle(
                    fontSize: 15,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...filtered.map(
              (r) => _RecipeCard(
                recipe: r,
                typeTagName: _tagsById[r.typeTagId]?.name,
                onTap: () async {
                  final repo = context.read<OvercookedRepository>();
                  await Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => OvercookedRecipeDetailPage(
                        recipeId: r.id!,
                        repository: repo,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  await _refresh();
                },
              ),
            ),
          const SizedBox(height: 8),
          if (widget.onJumpToGacha != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                color: IOS26Theme.toolOrange.withValues(alpha: 0.10),
                border: Border.all(
                  color: IOS26Theme.toolOrange.withValues(alpha: 0.25),
                  width: 1,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.casino_rounded,
                      size: 18,
                      color: IOS26Theme.toolOrange,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '不知道吃什么？去扭蛋机抽一抽',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.textPrimary,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: widget.onJumpToGacha,
                      child: const Text('去抽取'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '菜谱',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: IOS26Theme.textPrimary,
            ),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: IOS26Theme.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onPressed: () async {
            final repo = context.read<OvercookedRepository>();
            await Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => OvercookedRecipeEditPage(repository: repo),
              ),
            );
            if (!mounted) return;
            await _refresh();
          },
          child: const Text(
            '+ 新建',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final OvercookedRecipe recipe;
  final String? typeTagName;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.typeTagName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final objStore = context.read<ObjStoreService>();
    final typeText = typeTagName?.trim();
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: OvercookedImageByKey(
                objStoreService: objStore,
                objectKey: recipe.coverImageKey,
                borderRadius: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: IOS26Theme.textPrimary,
                    ),
                  ),
                  if (typeText != null && typeText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: IOS26Theme.toolPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: IOS26Theme.toolPurple.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        typeText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: IOS26Theme.toolPurple,
                        ),
                      ),
                    ),
                  ],
                  if (recipe.intro.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.intro.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: IOS26Theme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
