import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/ios26_theme.dart';
import '../../models/overcooked_meal.dart';
import '../../models/overcooked_recipe.dart';
import '../../repository/overcooked_repository.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_date_bar.dart';
import '../../widgets/overcooked_recipe_picker_sheet.dart';

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
  final _noteController = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  String _mealSlot = '';

  OvercookedMeal? _meal;
  Map<int, OvercookedRecipe> _recipesById = const {};
  List<OvercookedRecipe> _allRecipes = const [];

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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = context.read<OvercookedRepository>();
      final meal = await repo.getMealForDate(widget.date);
      final ids = meal?.recipeIds ?? const <int>[];
      final recipes = await repo.listRecipesByIds(ids);
      final allRecipes = await repo.listRecipes();

      setState(() {
        _meal = meal;
        _recipesById = {
          for (final r in recipes)
            if (r.id != null) r.id!: r,
        };
        _allRecipes = allRecipes;
        _noteController.text = meal?.note ?? '';
        _mealSlot = meal?.mealSlot ?? '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = _meal;
    final recipeIds = meal?.recipeIds ?? const <int>[];
    final slotLabel = _mealSlotLabel(_mealSlot);
    final recipes = recipeIds
        .map((id) => _recipesById[id])
        .whereType<OvercookedRecipe>()
        .toList();

    final distinctTypeCount = {
      for (final r in recipes)
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
                onPressed: _loading ? null : _editMealRecipes,
                child: const Text(
                  '选择菜谱',
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
          const Text(
            '餐次标记',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(10),
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: _mealSlot,
              thumbColor: IOS26Theme.primaryColor.withValues(alpha: 0.16),
              backgroundColor: IOS26Theme.surfaceColor.withValues(alpha: 0.0),
              children: const {
                '': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Text(
                    '不标记',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                'mid_lunch': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Text(
                    '中班午餐',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                'mid_dinner': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Text(
                    '中班晚餐',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              },
              onValueChanged: (v) {
                if (_saving) return;
                setState(() => _mealSlot = v ?? '');
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(14),
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
                      if (slotLabel != null) ...[
                        const SizedBox(height: 6),
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
                            slotLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: IOS26Theme.toolPurple,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                onPressed: _loading ? null : _replaceWithWishes,
                child: const Text(
                  '用愿望单覆盖',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: IOS26Theme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading && meal == null)
            const Padding(
              padding: EdgeInsets.only(top: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recipeIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  '今天还没记录做了什么，点“选择菜谱”添加',
                  style: TextStyle(
                    fontSize: 15,
                    color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            )
          else
            ...recipeIds.map((id) {
              final name = _recipesById[id]?.name ?? '（菜谱已删除）';
              return GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: IOS26Theme.textPrimary,
                  ),
                ),
              );
            }),
          const SizedBox(height: 14),
          const Text(
            '当天评价',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _noteController,
            placeholder: '如：超下饭 / 太咸了下次少放盐…',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: IOS26Theme.primaryColor,
            borderRadius: BorderRadius.circular(14),
            onPressed: _saving ? null : _saveNote,
            child: Text(
              _saving ? '保存中…' : '保存评价',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _replaceWithWishes() async {
    final repo = context.read<OvercookedRepository>();
    await repo.replaceMealWithWishes(date: widget.date, now: DateTime.now());
    await _refresh();
  }

  Future<void> _editMealRecipes() async {
    if (_allRecipes.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '暂无菜谱，请先去“菜谱”创建。',
      );
      return;
    }

    final current = (_meal?.recipeIds ?? const <int>[]).toSet();
    final selected = await OvercookedRecipePickerSheet.show(
      context,
      title: '选择今日做了什么菜',
      recipes: _allRecipes,
      selectedRecipeIds: current,
    );
    if (selected == null) return;
    if (!mounted) return;

    await context.read<OvercookedRepository>().replaceMeal(
      date: widget.date,
      recipeIds: selected.toList(),
      mealSlot: _mealSlot,
      now: DateTime.now(),
    );
    await _refresh();
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    try {
      await context.read<OvercookedRepository>().upsertMealNote(
        date: widget.date,
        note: _noteController.text,
        mealSlot: _mealSlot,
        now: DateTime.now(),
      );
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

  static String? _mealSlotLabel(String slot) {
    final s = slot.trim();
    if (s.isEmpty) return null;
    switch (s) {
      case 'mid_lunch':
        return '中班午餐';
      case 'mid_dinner':
        return '中班晚餐';
      default:
        return s;
    }
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
