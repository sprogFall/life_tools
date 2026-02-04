import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../overcooked_constants.dart';
import '../../models/overcooked_recipe.dart';
import '../../models/overcooked_wish_item.dart';
import '../../repository/overcooked_repository.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_date_bar.dart';
import '../../widgets/overcooked_recipe_picker_sheet.dart';

class OvercookedWishlistTab extends StatefulWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onWishesChanged;

  const OvercookedWishlistTab({
    super.key,
    required this.date,
    required this.onDateChanged,
    required this.onWishesChanged,
  });

  @override
  State<OvercookedWishlistTab> createState() => _OvercookedWishlistTabState();
}

class _OvercookedWishlistTabState extends State<OvercookedWishlistTab> {
  bool _loading = false;
  List<OvercookedWishItem> _wishes = const [];
  Map<int, OvercookedRecipe> _recipesById = const {};
  Map<int, Tag> _tagsById = const {};

  @override
  void didUpdateWidget(covariant OvercookedWishlistTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (OvercookedRepository.dayKey(oldWidget.date) !=
        OvercookedRepository.dayKey(widget.date)) {
      _refresh();
    }
  }

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
      final wishes = await repo.listWishesForDate(widget.date);
      final recipeIds = wishes.map((e) => e.recipeId).toList();
      final selectedRecipes = await repo.listRecipesByIds(recipeIds);

      final ingredientTags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.ingredient,
      );
      final sauceTags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.sauce,
      );
      final tags = <Tag>[...ingredientTags, ...sauceTags];

      setState(() {
        _wishes = wishes;
        _recipesById = {
          for (final r in selectedRecipes)
            if (r.id != null) r.id!: r,
        };
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
    final wishRecipes = _wishes
        .map((w) => _recipesById[w.recipeId])
        .whereType<OvercookedRecipe>()
        .toList();

    final ingredientNames = <String>{};
    final sauceNames = <String>{};
    for (final r in wishRecipes) {
      for (final id in r.ingredientTagIds) {
        final name = _tagsById[id]?.name;
        if (name != null && name.trim().isNotEmpty) {
          ingredientNames.add(name.trim());
        }
      }
      for (final id in r.sauceTagIds) {
        final name = _tagsById[id]?.name;
        if (name != null && name.trim().isNotEmpty) {
          sauceNames.add(name.trim());
        }
      }
    }

    final ingredientText = ingredientNames.isEmpty
        ? '（暂无）'
        : (ingredientNames.toList()..sort()).join('、');
    final sauceText = sauceNames.isEmpty
        ? '（暂无）'
        : (sauceNames.toList()..sort()).join('、');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(
            children: [
              Expanded(child: Text('愿望单', style: IOS26Theme.headlineMedium)),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: IOS26Theme.primaryColor,
                borderRadius: BorderRadius.circular(14),
                onPressed: _editWishes,
                child: Text(
                  '选择菜谱',
                  style: IOS26Theme.labelLarge.copyWith(
                    color: IOS26Theme.surfaceColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OvercookedDateBar(
            title: '日期',
            date: widget.date,
            onPrev: () => widget.onDateChanged(
              widget.date.subtract(const Duration(days: 1)),
            ),
            onNext: () =>
                widget.onDateChanged(widget.date.add(const Duration(days: 1))),
            onPick: () => _pickDate(initial: widget.date),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('准备清单（自动汇总）', style: IOS26Theme.titleSmall),
                const SizedBox(height: 10),
                Text(
                  '主料：$ingredientText',
                  style: IOS26Theme.bodySmall.copyWith(height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(
                  '调味：$sauceText',
                  style: IOS26Theme.bodySmall.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading && _wishes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 36),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_wishes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Center(
                child: Text(
                  '这天还没想好吃什么，点“选择菜谱”添加',
                  style: IOS26Theme.bodyMedium.copyWith(
                    color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            )
          else
            ..._wishes.map((w) {
              final recipe = _recipesById[w.recipeId];
              return _WishRow(
                title: recipe?.name ?? '（菜谱已删除）',
                onRemove: _loading
                    ? null
                    : () async {
                        await context.read<OvercookedRepository>().removeWish(
                          date: widget.date,
                          recipeId: w.recipeId,
                        );
                        await _refresh();
                        widget.onWishesChanged();
                      },
              );
            }),
        ],
      ),
    );
  }

  Future<void> _editWishes() async {
    // IndexedStack 下 tab 不会重建：这里每次打开都从库里取最新菜谱，确保新建后立即可选
    final repo = context.read<OvercookedRepository>();
    final latestRecipes = await repo.listRecipes();
    if (!mounted) return;

    if (latestRecipes.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '暂无菜谱，请先去“菜谱”创建。',
      );
      return;
    }

    final current = _wishes.map((e) => e.recipeId).toSet();
    final selected = await OvercookedRecipePickerSheet.show(
      context,
      title: '选择愿望单菜谱',
      recipes: latestRecipes,
      selectedRecipeIds: current,
    );
    if (selected == null) return;
    if (!mounted) return;

    await context.read<OvercookedRepository>().replaceWishes(
      date: widget.date,
      recipeIds: selected.toList(),
      now: DateTime.now(),
    );
    await _refresh();
    widget.onWishesChanged();
  }

  Future<void> _pickDate({required DateTime initial}) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        var temp = DateTime(initial.year, initial.month, initial.day);
        return Container(
          height: 300,
          color: IOS26Theme.surfaceColor,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        widget.onDateChanged(temp);
                        Navigator.pop(context);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: temp,
                  onDateTimeChanged: (value) => temp = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WishRow extends StatelessWidget {
  final String title;
  final VoidCallback? onRemove;

  const _WishRow({required this.title, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IOS26Theme.titleSmall,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
            onPressed: onRemove,
            child: const Icon(
              CupertinoIcons.trash,
              size: 18,
              color: IOS26Theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
