import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../../tag_manager/pages/tag_manager_tool_page.dart';
import '../../models/overcooked_meal.dart';
import '../../models/overcooked_recipe.dart';
import '../../overcooked_constants.dart';
import '../../repository/overcooked_repository.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_date_bar.dart';
import '../../widgets/overcooked_recipe_picker_sheet.dart';
import '../../widgets/overcooked_tag_picker_sheet.dart';

class OvercookedMealTab extends StatefulWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  const OvercookedMealTab({
    super.key,
    required this.date,
    required this.onDateChanged,
  });

  @override
  State<OvercookedMealTab> createState() => _OvercookedMealTabState();
}

class _OvercookedMealTabState extends State<OvercookedMealTab> {
  bool _loading = false;

  List<OvercookedMeal> _meals = const [];
  Map<int, OvercookedRecipe> _recipesById = const {};

  List<OvercookedRecipe> _allRecipes = const [];
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

      setState(() {
        _meals = meals;
        _recipesById = {
          for (final r in recipes)
            if (r.id != null) r.id!: r,
        };
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
    final cookedRecipes = _meals
        .expand((m) => m.recipeIds)
        .map((id) => _recipesById[id])
        .whereType<OvercookedRecipe>()
        .toList();
    final distinctTypeCount = {
      for (final r in cookedRecipes)
        (r.typeTagId == null ? 'r:${r.id}' : 't:${r.typeTagId}'): true,
    }.length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '三餐记录',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: IOS26Theme.textPrimary,
                  ),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: IOS26Theme.primaryColor,
                borderRadius: BorderRadius.circular(14),
                onPressed: _loading ? null : _addMealFlow,
                child: const Text(
                  '新增餐次',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日做菜量（类型去重）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: IOS26Theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$distinctTypeCount',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: IOS26Theme.textPrimary,
                        ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_meals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Center(
                child: Text(
                  '今天还没记录，点右上角「新增餐次」开始',
                  style: TextStyle(
                    fontSize: 15,
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
                missingRecipeCount:
                    meal.recipeIds.where((id) => !_recipesById.containsKey(id)).length,
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
              ),
        ],
      ),
    );
  }

  Future<List<OvercookedRecipe>> _loadLatestRecipes() async {
    final repo = context.read<OvercookedRepository>();
    final latest = await repo.listRecipes();
    if (!mounted) return latest;
    setState(() => _allRecipes = latest);
    return latest;
  }

  Future<void> _addMealFlow() async {
    if (_mealSlotTags.isEmpty) {
      final go = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('还没有“餐次”标签'),
          content: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('请先到「标签管理 -> 胡闹厨房 -> 餐次」创建，例如：早餐/午餐/晚餐。'),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去创建'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) =>
                const TagManagerToolPage(initialToolId: OvercookedConstants.toolId),
          ),
        );
        if (!mounted) return;
        await _refresh();
      }
      return;
    }

    final picked = await OvercookedTagPickerSheet.show(
      context,
      title: '选择餐次',
      tags: _mealSlotTags,
      selectedIds: const {},
      multi: false,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final tagId = picked.first;

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
    await _refresh();
  }

  Future<void> _pickMealTagForMeal(OvercookedMeal meal) async {
    if (_mealSlotTags.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '暂无可用餐次标签',
        content: '请先到「标签管理 -> 胡闹厨房 -> 餐次」创建标签。',
      );
      return;
    }

    final current = meal.mealTagId == null ? const <int>{} : {meal.mealTagId!};
    final picked = await OvercookedTagPickerSheet.show(
      context,
      title: '修改餐次',
      tags: _mealSlotTags,
      selectedIds: current,
      multi: false,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final tagId = picked.first;

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
    await _refresh();
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

  final VoidCallback? onPickMealTag;
  final VoidCallback? onPickRecipes;
  final VoidCallback? onImportWishes;
  final VoidCallback? onEditNote;
  final VoidCallback? onDelete;

  const _MealCard({
    required this.meal,
    required this.tagName,
    required this.recipes,
    required this.missingRecipeCount,
    required this.onPickMealTag,
    required this.onPickRecipes,
    required this.onImportWishes,
    required this.onEditNote,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = tagName?.trim().isNotEmpty == true
        ? tagName!.trim()
        : (meal.mealTagId == null ? '未标记' : '（标签已删除）');

    final recipeNames = [
      for (final r in recipes) r.name,
      for (int i = 0; i < missingRecipeCount; i++) '（菜谱已删除）',
    ];

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
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  color: IOS26Theme.primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  onPressed: onPickMealTag,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: IOS26Theme.primaryColor,
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
            const Text(
              '做了什么菜',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: IOS26Theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (recipeNames.isEmpty)
              Text(
                '还没选择菜谱，点右上角「选择菜谱」添加',
                style: TextStyle(
                  fontSize: 14,
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in recipeNames) _recipeChip(name),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  '评价',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onEditNote,
                  child: const Text(
                    '编辑',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: IOS26Theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              meal.note.trim().isEmpty ? '（暂无评价）' : meal.note.trim(),
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: meal.note.trim().isEmpty
                    ? IOS26Theme.textSecondary.withValues(alpha: 0.85)
                    : IOS26Theme.textPrimary,
                fontWeight:
                    meal.note.trim().isEmpty ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _recipeChip(String text) {
    final bg = IOS26Theme.surfaceColor.withValues(alpha: 0.65);
    final border = IOS26Theme.textTertiary.withValues(alpha: 0.35);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: IOS26Theme.textPrimary,
          ),
        ),
      ),
    );
  }

  static Widget _iconButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    Color iconColor = IOS26Theme.textSecondary,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onPressed: onPressed,
        color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}
