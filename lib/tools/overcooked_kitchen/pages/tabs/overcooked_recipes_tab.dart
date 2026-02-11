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
  final VoidCallback? onRecipesChanged;

  const OvercookedRecipesTab({
    super.key,
    this.onJumpToGacha,
    this.onRecipesChanged,
  });

  @override
  State<OvercookedRecipesTab> createState() => _OvercookedRecipesTabState();
}

class _OvercookedRecipesTabState extends State<OvercookedRecipesTab> {
  bool _loading = false;
  String _query = '';
  List<OvercookedRecipe> _recipes = const [];
  Map<int, Tag> _tagsById = const {};
  Map<int, ({int cookCount, double avgRating, int ratingCount})> _statsById =
      const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _notifyRecipesChanged() {
    widget.onRecipesChanged?.call();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final repo = context.read<OvercookedRepository>();
      final tagService = context.read<TagService>();
      final recipes = await repo.listRecipes();
      final tags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.dishType,
      );
      final stats = await repo.getRecipeStats();
      if (mounted) {
        setState(() {
          _recipes = recipes;
          _tagsById = {
            for (final t in tags)
              if (t.id != null) t.id!: t,
          };
          _statsById = stats;
        });
      }
    } finally {
      _loading = false;
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
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Center(
                child: Text(
                  _recipes.isEmpty ? '暂无菜谱，点右上角 + 新建' : '没有匹配的菜谱',
                  style: IOS26Theme.bodyMedium,
                ),
              ),
            )
          else
            ...filtered.map(
              (r) => _RecipeCard(
                recipe: r,
                typeTagName: _tagsById[r.typeTagId]?.name,
                stats: r.id != null ? _statsById[r.id!] : null,
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
                  if (!mounted) return;
                  _notifyRecipesChanged();
                },
              ),
            ),
          const SizedBox(height: 8),
          if (widget.onJumpToGacha != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassContainer(
                key: const ValueKey('overcooked_recipes_gacha_entry_card'),
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                color: IOS26Theme.toolOrange.withValues(alpha: 0.10),
                border: Border.all(
                  color: IOS26Theme.toolOrange.withValues(alpha: 0.25),
                  width: 1,
                ),
                child: Row(
                  children: [
                    IOS26Icon(
                      CupertinoIcons.shuffle,
                      size: 18,
                      color: IOS26Theme.toolOrange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '不知道吃什么？去扭蛋机抽一个',
                        style: IOS26Theme.bodyMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.textPrimary,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      pressedOpacity: 1,
                      onPressed: widget.onJumpToGacha,
                      child: Text('去扭蛋', style: IOS26Theme.labelLarge),
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
        Expanded(
          child: Text(
            '菜谱',
            style: IOS26Theme.headlineMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IOS26Button(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          variant: IOS26ButtonVariant.primary,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
          onPressed: () async {
            final repo = context.read<OvercookedRepository>();
            await Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => OvercookedRecipeEditPage(repository: repo),
              ),
            );
            if (!mounted) return;
            await _refresh();
            if (!mounted) return;
            _notifyRecipesChanged();
          },
          child: IOS26ButtonLabel(
            '+ 新建',
            style: IOS26Theme.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final OvercookedRecipe recipe;
  final String? typeTagName;
  final ({int cookCount, double avgRating, int ratingCount})? stats;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.typeTagName,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final objStore = context.read<ObjStoreService>();
    final typeText = typeTagName?.trim();
    final cookCount = stats?.cookCount ?? 0;
    final avgRating = stats?.avgRating ?? 0.0;
    final ratingCount = stats?.ratingCount ?? 0;

    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
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
                    style: IOS26Theme.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (typeText != null && typeText.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: IOS26Theme.toolPurple.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: IOS26Theme.toolPurple.withValues(
                                alpha: 0.25,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            typeText,
                            style: IOS26Theme.bodySmall.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: IOS26Theme.toolPurple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (cookCount > 0)
                        Text(
                          '做过$cookCount次',
                          style: IOS26Theme.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: IOS26Theme.textSecondary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      if (ratingCount > 0) ...[
                        const SizedBox(width: 8),
                        IOS26Icon(
                          CupertinoIcons.star_fill,
                          size: 14,
                          color: IOS26Theme.toolOrange,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: IOS26Theme.bodySmall.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: IOS26Theme.toolOrange,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (recipe.intro.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.intro.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IOS26Theme.bodySmall.copyWith(
                        fontSize: 12,
                        height: 1.25,
                        color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IOS26Icon(
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
