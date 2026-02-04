import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../overcooked_constants.dart';
import '../../models/overcooked_recipe.dart';
import '../../repository/overcooked_repository.dart';
import '../../services/overcooked_gacha_service.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_date_bar.dart';
import '../../widgets/overcooked_tag_picker_sheet.dart';

class OvercookedGachaTab extends StatefulWidget {
  final DateTime targetDate;
  final ValueChanged<DateTime> onTargetDateChanged;
  final ValueChanged<DateTime> onImportToWish;

  const OvercookedGachaTab({
    super.key,
    required this.targetDate,
    required this.onTargetDateChanged,
    required this.onImportToWish,
  });

  @override
  State<OvercookedGachaTab> createState() => _OvercookedGachaTabState();
}

class _OvercookedGachaTabState extends State<OvercookedGachaTab> {
  bool _loading = false;
  List<Tag> _typeTags = const [];
  Map<int, Tag> _tagsById = const {};
  Set<int> _selectedTypeIds = {};
  Map<int, int> _typeCountById = {};
  List<OvercookedRecipe> _picked = const [];

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final tags = await context.read<TagService>().listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.dishType,
      );
      setState(() {
        _typeTags = tags;
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
    final entries =
        _selectedTypeIds
            .map((id) {
              final name = _tagsById[id]?.name;
              final trimmed = name?.trim();
              if (trimmed == null || trimmed.isEmpty) return null;
              final count = _typeCountById[id] ?? 1;
              return (id: id, name: trimmed, count: count);
            })
            .whereType<({int id, String name, int count})>()
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final totalCount = entries.fold<int>(
      0,
      (sum, e) => sum + (e.count <= 0 ? 0 : e.count),
    );
    final typeText = entries.isEmpty
        ? '未选择'
        : entries.map((e) => '${e.name}×${e.count}').join('、');
    final canRoll = !_loading && _selectedTypeIds.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Row(
          children: [
            Expanded(child: Text('扭蛋机', style: IOS26Theme.headlineMedium)),
            CupertinoButton(
              key: const ValueKey('overcooked_gacha_roll_button'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: canRoll
                  ? IOS26Theme.primaryColor
                  : IOS26Theme.textTertiary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              onPressed: canRoll ? _roll : null,
              child: Text(
                '扭蛋',
                style: IOS26Theme.labelLarge.copyWith(
                  color: IOS26Theme.surfaceColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _fieldTitle('菜品风格搭配（来自标签）'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: CupertinoButton(
            key: const ValueKey('overcooked_gacha_pick_types_button'),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            onPressed: _typeTags.isEmpty || _loading ? null : _pickTypes,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    typeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IOS26Theme.titleSmall.copyWith(
                      color: entries.isEmpty
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
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 10),
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('每种风格抽取份数', style: IOS26Theme.bodySmall),
                    ),
                    Text(
                      '共 $totalCount 道',
                      style: IOS26Theme.bodySmall.copyWith(
                        color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...entries.map(
                  (e) => _TypeCountRow(
                    name: e.name,
                    count: e.count,
                    onChanged: _loading
                        ? null
                        : (next) => setState(() {
                            _typeCountById = {..._typeCountById, e.id: next};
                          }),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        OvercookedDateBar(
          title: '导入到哪天的愿望单',
          date: widget.targetDate,
          onPrev: () => widget.onTargetDateChanged(
            widget.targetDate.subtract(const Duration(days: 1)),
          ),
          onNext: () => widget.onTargetDateChanged(
            widget.targetDate.add(const Duration(days: 1)),
          ),
          onPick: () => _pickDate(initial: widget.targetDate),
        ),
        const SizedBox(height: 12),
        if (_typeTags.isEmpty)
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            color: IOS26Theme.toolPurple.withValues(alpha: 0.10),
            border: Border.all(
              color: IOS26Theme.toolPurple.withValues(alpha: 0.25),
              width: 1,
            ),
            child: Text(
              '暂无“菜品风格”标签：请先在“标签管理”创建标签并关联到“胡闹厨房”后再来抽取。',
              style: IOS26Theme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        if (_picked.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Center(
              child: Text(
                '先选好风格搭配，再点“扭蛋”开抽',
                style: IOS26Theme.bodyMedium.copyWith(
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ),
          )
        else ...[
          ..._picked.map(
            (r) => _PickedCard(
              recipe: r,
              typeName: r.typeTagId == null
                  ? null
                  : _tagsById[r.typeTagId!]?.name,
            ),
          ),
          const SizedBox(height: 10),
          CupertinoButton(
            key: const ValueKey('overcooked_gacha_import_button'),
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: IOS26Theme.primaryColor,
            borderRadius: BorderRadius.circular(14),
            onPressed: _loading ? null : _importToWish,
            child: Text(
              '就你了',
              style: IOS26Theme.labelLarge.copyWith(
                color: IOS26Theme.surfaceColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _fieldTitle(String text) {
    return Text(text, style: IOS26Theme.titleSmall);
  }

  Future<void> _pickTypes() async {
    final selected = await OvercookedTagPickerSheet.show(
      context,
      title: '选择风格搭配',
      tags: _typeTags,
      selectedIds: _selectedTypeIds,
      multi: true,
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
      await _loadTypes();
      if (!mounted) return;
    }
    setState(() {
      _selectedTypeIds = selected.selectedIds;
      final next = <int, int>{};
      for (final id in _selectedTypeIds) {
        next[id] = _typeCountById[id] ?? 1;
      }
      _typeCountById = next;
      _picked = const [];
    });
  }

  Future<void> _roll() async {
    if (_selectedTypeIds.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '请先选择“菜品风格搭配”',
      );
      return;
    }
    if (_typeCountById.isEmpty || _typeCountById.values.every((c) => c <= 0)) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '请为至少 1 种风格设置抽取数量',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = OvercookedGachaService(
        repository: context.read<OvercookedRepository>(),
      );
      final seed = DateTime.now().millisecondsSinceEpoch;
      final picked = await service.pickByTypeCounts(
        typeCounts: _typeCountById,
        seed: seed,
      );
      setState(() => _picked = picked);
    } catch (e) {
      if (!mounted) return;
      await OvercookedDialogs.showMessage(
        context,
        title: '抽取失败',
        content: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importToWish() async {
    if (_picked.isEmpty) return;
    final repo = context.read<OvercookedRepository>();
    final now = DateTime.now();
    for (final r in _picked) {
      final id = r.id;
      if (id == null) continue;
      await repo.addWish(date: widget.targetDate, recipeId: id, now: now);
    }
    widget.onImportToWish(widget.targetDate);

    if (!mounted) return;
    await OvercookedDialogs.showMessage(
      context,
      title: '已导入',
      content: '已将本次抽取结果加入 ${OvercookedFormat.date(widget.targetDate)} 的愿望单。',
    );
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
                        widget.onTargetDateChanged(temp);
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

class _PickedCard extends StatelessWidget {
  final OvercookedRecipe recipe;
  final String? typeName;

  const _PickedCard({required this.recipe, required this.typeName});

  @override
  Widget build(BuildContext context) {
    final type = typeName?.trim();
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipe.name, style: IOS26Theme.titleMedium),
          if (type != null && type.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: IOS26Theme.toolPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: IOS26Theme.toolPurple.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Text(
                type,
                style: IOS26Theme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: IOS26Theme.toolPurple,
                ),
              ),
            ),
          ],
          if (recipe.intro.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              recipe.intro.trim(),
              style: IOS26Theme.bodySmall.copyWith(
                height: 1.25,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeCountRow extends StatelessWidget {
  final String name;
  final int count;
  final ValueChanged<int>? onChanged;

  const _TypeCountRow({
    required this.name,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = count <= 0 ? 0 : count;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IOS26Theme.titleSmall,
            ),
          ),
          _iconButton(
            icon: CupertinoIcons.minus,
            enabled: onChanged != null && c > 1,
            onPressed: () => onChanged?.call(c - 1),
          ),
          const SizedBox(width: 10),
          Text('$c', style: IOS26Theme.titleSmall),
          const SizedBox(width: 10),
          _iconButton(
            icon: CupertinoIcons.add,
            enabled: onChanged != null,
            onPressed: () => onChanged?.call(c + 1),
          ),
        ],
      ),
    );
  }

  static Widget _iconButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: enabled ? onPressed : null,
      color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      child: Icon(
        icon,
        size: 16,
        color: enabled ? IOS26Theme.primaryColor : IOS26Theme.textTertiary,
      ),
    );
  }
}
