import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/overcooked_meal.dart';
import '../../models/overcooked_recipe.dart';
import '../../overcooked_constants.dart';
import '../../repository/overcooked_repository.dart';
import '../../utils/overcooked_meal_stats.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_date_bar.dart';
import '../../widgets/overcooked_recipe_picker_sheet.dart';
import '../../widgets/overcooked_tag_picker_sheet.dart';

class OvercookedMealTab extends StatefulWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback? onMealsChanged;

  const OvercookedMealTab({
    super.key,
    required this.date,
    required this.onDateChanged,
    this.onMealsChanged,
  });

  @override
  State<OvercookedMealTab> createState() => _OvercookedMealTabState();
}

class _OvercookedMealTabState extends State<OvercookedMealTab> {
  bool _loading = false;

  List<OvercookedMeal> _meals = const [];
  Map<int, OvercookedRecipe> _recipesById = const {};
  Map<int, Map<int, int>> _ratingsByMealId =
      const {}; // mealId -> {recipeId -> rating}

  List<Tag> _mealSlotTags = const [];
  Map<int, Tag> _mealSlotTagsById = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant OvercookedMealTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (OvercookedRepository.dayKey(oldWidget.date) !=
        OvercookedRepository.dayKey(widget.date)) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = context.read<OvercookedRepository>();
      final tagService = context.read<TagService>();

      final meals = await repo.listMealsForDate(widget.date);
      final recipeIds = <int>{
        for (final m in meals) ...m.recipeIds,
      }.toList(growable: false);
      final recipes = await repo.listRecipesByIds(recipeIds);

      final mealSlotTags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.mealSlot,
      );

      // 加载每个餐次的评分
      final ratingsByMealId = <int, Map<int, int>>{};
      for (final meal in meals) {
        ratingsByMealId[meal.id] = await repo.getRatingsForMeal(meal.id);
      }

      setState(() {
        _meals = meals;
        _recipesById = {
          for (final r in recipes)
            if (r.id != null) r.id!: r,
        };
        _ratingsByMealId = ratingsByMealId;
        _mealSlotTags = mealSlotTags;
        _mealSlotTagsById = {
          for (final t in mealSlotTags)
            if (t.id != null) t.id!: t,
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distinctTypeCount = distinctRecipeCount(_meals);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(
            children: [
              Expanded(child: Text('三餐记录', style: IOS26Theme.headlineMedium)),
              IOS26Button(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                variant: IOS26ButtonVariant.primary,
                borderRadius: BorderRadius.circular(14),
                onPressed: _loading ? null : _addMealFlow,
                child: IOS26ButtonLabel('新增餐次', style: IOS26Theme.labelLarge),
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('今日菜量', style: IOS26Theme.bodySmall),
                      const SizedBox(height: 6),
                      Text(
                        '$distinctTypeCount',
                        style: IOS26Theme.headlineLarge,
                      ),
                    ],
                  ),
                ),
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
                    '餐次 ${_meals.length}',
                    style: IOS26Theme.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.toolPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading && _meals.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 36),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_meals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Center(
                child: Text(
                  '今天还没记录，点右上角「新增餐次」开始',
                  style: IOS26Theme.bodyMedium.copyWith(
                    color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            )
          else
            for (final meal in _meals)
              _MealCard(
                meal: meal,
                tagName: _mealSlotTagsById[meal.mealTagId]?.name,
                recipes: meal.recipeIds
                    .map((id) => _recipesById[id])
                    .whereType<OvercookedRecipe>()
                    .toList(),
                missingRecipeCount: meal.recipeIds
                    .where((id) => !_recipesById.containsKey(id))
                    .length,
                ratings: _ratingsByMealId[meal.id] ?? const {},
                onPickMealTag: _loading
                    ? null
                    : () => _pickMealTagForMeal(meal),
                onPickRecipes: _loading
                    ? null
                    : () => _pickRecipesForMeal(meal),
                onImportWishes: _loading
                    ? null
                    : () => _importWishesToMeal(meal),
                onEditNote: _loading ? null : () => _editNoteForMeal(meal),
                onDelete: _loading ? null : () => _deleteMeal(meal),
                onRatingChanged: _loading
                    ? null
                    : (recipeId, rating) =>
                          _updateRating(meal.id, recipeId, rating),
              ),
        ],
      ),
    );
  }

  Future<List<OvercookedRecipe>> _loadLatestRecipes() async {
    final repo = context.read<OvercookedRepository>();
    return repo.listRecipes();
  }

  Future<void> _addMealFlow() async {
    final picked = await OvercookedTagPickerSheet.show(
      context,
      title: '选择餐次',
      tags: _mealSlotTags,
      selectedIds: const {},
      multi: false,
      createHint: OvercookedTagUtils.createHint(
        context,
        OvercookedTagCategories.mealSlot,
      ),
      onCreateTag: (name) => OvercookedTagUtils.createTag(
        context,
        categoryId: OvercookedTagCategories.mealSlot,
        name: name,
      ),
    );
    if (picked == null || picked.selectedIds.isEmpty || !mounted) return;
    if (picked.tagsChanged) {
      await _refresh();
      if (!mounted) return;
    }
    final tagId = picked.selectedIds.first;

    final existed = _meals.any((m) => m.mealTagId == tagId);
    if (existed) {
      await OvercookedDialogs.showMessage(
        context,
        title: '已存在',
        content: '该餐次今天已创建，可在下方直接编辑。',
      );
      return;
    }

    final latest = await _loadLatestRecipes();
    if (!mounted) return;
    if (latest.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '暂无菜谱，请先去“菜谱”创建。',
      );
      return;
    }

    final selected = await OvercookedRecipePickerSheet.show(
      context,
      title: '选择该餐次做了什么菜',
      recipes: latest,
      selectedRecipeIds: const {},
    );
    if (selected == null || !mounted) return;

    await context.read<OvercookedRepository>().replaceMeal(
      date: widget.date,
      mealTagId: tagId,
      recipeIds: selected.toList(),
      now: DateTime.now(),
    );
    widget.onMealsChanged?.call();
    await _refresh();
  }

  Future<void> _pickMealTagForMeal(OvercookedMeal meal) async {
    final current = meal.mealTagId == null ? const <int>{} : {meal.mealTagId!};
    final picked = await OvercookedTagPickerSheet.show(
      context,
      title: '修改餐次',
      tags: _mealSlotTags,
      selectedIds: current,
      multi: false,
      createHint: OvercookedTagUtils.createHint(
        context,
        OvercookedTagCategories.mealSlot,
      ),
      onCreateTag: (name) => OvercookedTagUtils.createTag(
        context,
        categoryId: OvercookedTagCategories.mealSlot,
        name: name,
      ),
    );
    if (picked == null || picked.selectedIds.isEmpty || !mounted) return;
    if (picked.tagsChanged) {
      await _refresh();
      if (!mounted) return;
    }
    final tagId = picked.selectedIds.first;

    final existed = _meals.any((m) => m.id != meal.id && m.mealTagId == tagId);
    if (existed) {
      await OvercookedDialogs.showMessage(
        context,
        title: '已存在',
        content: '该餐次今天已创建，请选择其它标签。',
      );
      return;
    }

    try {
      await context.read<OvercookedRepository>().updateMealTag(
        mealId: meal.id,
        mealTagId: tagId,
        now: DateTime.now(),
      );
      widget.onMealsChanged?.call();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      await OvercookedDialogs.showMessage(
        context,
        title: '修改失败',
        content: e.toString(),
      );
    }
  }

  Future<void> _pickRecipesForMeal(OvercookedMeal meal) async {
    final latest = await _loadLatestRecipes();
    if (!mounted) return;
    if (latest.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '暂无菜谱，请先去“菜谱”创建。',
      );
      return;
    }

    final selected = await OvercookedRecipePickerSheet.show(
      context,
      title: '选择该餐次做了什么菜',
      recipes: latest,
      selectedRecipeIds: meal.recipeIds.toSet(),
    );
    if (selected == null || !mounted) return;

    await context.read<OvercookedRepository>().replaceMealItems(
      mealId: meal.id,
      recipeIds: selected.toList(),
      now: DateTime.now(),
    );
    widget.onMealsChanged?.call();
    await _refresh();
  }

  Future<void> _importWishesToMeal(OvercookedMeal meal) async {
    final ok = await OvercookedDialogs.confirm(
      context,
      title: '确认覆盖',
      content: '将用愿望单覆盖该餐次的菜谱选择，当前餐次已选菜谱会被清空。',
      confirmText: '覆盖',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final repo = context.read<OvercookedRepository>();
    final wishes = await repo.listWishesForDate(widget.date);
    await repo.replaceMealItems(
      mealId: meal.id,
      recipeIds: wishes.map((e) => e.recipeId).toList(),
      now: DateTime.now(),
    );
    widget.onMealsChanged?.call();
    await _refresh();
  }

  Future<void> _editNoteForMeal(OvercookedMeal meal) async {
    final controller = TextEditingController(text: meal.note);

    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('餐次评价'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('评价内容')),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: controller,
              placeholder: '如：超下饭 / 太咸了下次少放盐…',
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<OvercookedRepository>().updateMealNote(
      mealId: meal.id,
      note: controller.text,
      now: DateTime.now(),
    );
    widget.onMealsChanged?.call();
    await _refresh();
  }

  Future<void> _deleteMeal(OvercookedMeal meal) async {
    final ok = await OvercookedDialogs.confirm(
      context,
      title: '确认删除',
      content: '确认删除该餐次记录？该餐次下的菜谱选择与评价会同时删除。',
      confirmText: '删除',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    await context.read<OvercookedRepository>().deleteMeal(meal.id);
    widget.onMealsChanged?.call();
    await _refresh();
  }

  Future<void> _updateRating(int mealId, int recipeId, int? rating) async {
    final repo = context.read<OvercookedRepository>();
    if (rating == null) {
      await repo.deleteRating(mealId: mealId, recipeId: recipeId);
    } else {
      await repo.upsertRating(
        mealId: mealId,
        recipeId: recipeId,
        rating: rating,
      );
    }
    // 更新本地状态
    setState(() {
      final mealRatings = Map<int, int>.from(_ratingsByMealId[mealId] ?? {});
      if (rating == null) {
        mealRatings.remove(recipeId);
      } else {
        mealRatings[recipeId] = rating;
      }
      _ratingsByMealId = {..._ratingsByMealId, mealId: mealRatings};
    });
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

class _MealCard extends StatelessWidget {
  final OvercookedMeal meal;
  final String? tagName;
  final List<OvercookedRecipe> recipes;
  final int missingRecipeCount;
  final Map<int, int> ratings; // recipeId -> rating

  final VoidCallback? onPickMealTag;
  final VoidCallback? onPickRecipes;
  final VoidCallback? onImportWishes;
  final VoidCallback? onEditNote;
  final VoidCallback? onDelete;
  final void Function(int recipeId, int? rating)? onRatingChanged;

  const _MealCard({
    required this.meal,
    required this.tagName,
    required this.recipes,
    required this.missingRecipeCount,
    required this.ratings,
    required this.onPickMealTag,
    required this.onPickRecipes,
    required this.onImportWishes,
    required this.onEditNote,
    required this.onDelete,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = tagName?.trim().isNotEmpty == true
        ? tagName!.trim()
        : (meal.mealTagId == null ? '未标记' : '（标签已删除）');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IOS26Button(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  variant: IOS26ButtonVariant.secondary,
                  borderRadius: BorderRadius.circular(999),
                  onPressed: onPickMealTag,
                  child: IOS26ButtonLabel(
                    title,
                    style: IOS26Theme.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                _iconButton(
                  label: '选择菜谱',
                  icon: CupertinoIcons.list_bullet,
                  onPressed: onPickRecipes,
                ),
                const SizedBox(width: 8),
                _iconButton(
                  label: '用愿望单覆盖',
                  icon: CupertinoIcons.heart,
                  onPressed: onImportWishes,
                ),
                const SizedBox(width: 8),
                _iconButton(
                  label: '删除餐次',
                  icon: CupertinoIcons.trash,
                  iconColor: IOS26Theme.toolRed,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('做了什么菜（点击打分）', style: IOS26Theme.bodySmall),
            const SizedBox(height: 8),
            if (recipes.isEmpty && missingRecipeCount == 0)
              Text(
                '还没选择菜谱，点右上角「选择菜谱」添加',
                style: IOS26Theme.bodyMedium.copyWith(
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                ),
              )
            else
              Column(
                children: [
                  for (final r in recipes)
                    _RecipeRatingRow(
                      recipeName: r.name,
                      rating: ratings[r.id],
                      onRatingChanged: onRatingChanged == null || r.id == null
                          ? null
                          : (rating) => onRatingChanged!(r.id!, rating),
                    ),
                  for (int i = 0; i < missingRecipeCount; i++)
                    _RecipeRatingRow(
                      recipeName: '（菜谱已删除）',
                      rating: null,
                      onRatingChanged: null,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('评价', style: IOS26Theme.bodySmall),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onEditNote,
                  child: Text('编辑', style: IOS26Theme.labelLarge),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              meal.note.trim().isEmpty ? '（暂无评价）' : meal.note.trim(),
              style: IOS26Theme.bodyMedium.copyWith(
                height: 1.35,
                color: meal.note.trim().isEmpty
                    ? IOS26Theme.textSecondary.withValues(alpha: 0.85)
                    : IOS26Theme.textPrimary,
                fontWeight: meal.note.trim().isEmpty
                    ? FontWeight.w600
                    : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _iconButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? iconColor,
  }) {
    final resolvedIconColor = iconColor ?? IOS26Theme.textSecondary;
    return Semantics(
      button: true,
      label: label,
      child: IOS26Button(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onPressed: onPressed,
        variant: IOS26ButtonVariant.ghost,
        borderRadius: BorderRadius.circular(14),
        child: Icon(icon, size: 18, color: resolvedIconColor),
      ),
    );
  }
}

class _RecipeRatingRow extends StatelessWidget {
  final String recipeName;
  final int? rating;
  final void Function(int? rating)? onRatingChanged;

  const _RecipeRatingRow({
    required this.recipeName,
    required this.rating,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              recipeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IOS26Theme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          _StarRating(rating: rating, onChanged: onRatingChanged),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int? rating;
  final void Function(int? rating)? onChanged;

  const _StarRating({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null
                ? null
                : () {
                    // 点击已选中的星星则取消评分
                    if (rating == i) {
                      onChanged!(null);
                    } else {
                      onChanged!(i);
                    }
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                rating != null && i <= rating!
                    ? CupertinoIcons.star_fill
                    : CupertinoIcons.star,
                size: 20,
                color: rating != null && i <= rating!
                    ? IOS26Theme.toolOrange
                    : IOS26Theme.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}
