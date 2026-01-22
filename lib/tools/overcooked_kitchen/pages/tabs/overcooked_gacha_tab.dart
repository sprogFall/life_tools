import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
        _tagsById = {for (final t in tags) if (t.id != null) t.id!: t};
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedNames =
        _selectedTypeIds
            .map((id) => _tagsById[id]?.name)
            .whereType<String>()
            .toList()
          ..sort();
    final typeText = selectedNames.isEmpty ? '未选择' : selectedNames.join('、');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '扭蛋机',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: IOS26Theme.primaryColor,
              borderRadius: BorderRadius.circular(14),
              onPressed: _loading ? null : _roll,
              child: const Text(
                '换一批',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _fieldTitle('菜的类型搭配（来自标签）'),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: CupertinoButton(
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selectedNames.isEmpty
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
        const SizedBox(height: 12),
        OvercookedDateBar(
          title: '导入到哪天的愿望单',
          date: widget.targetDate,
          onPrev: () => widget.onTargetDateChanged(
            widget.targetDate.subtract(const Duration(days: 1)),
          ),
          onNext: () =>
              widget.onTargetDateChanged(widget.targetDate.add(const Duration(days: 1))),
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
            child: const Text(
              '暂无“菜的类型”标签：请先在“标签管理”创建标签并关联到“胡闹厨房”后再来抽取。',
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: IOS26Theme.textPrimary,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_picked.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Center(
              child: Text(
                '先选好类型搭配，再点“换一批”开抽',
                style: TextStyle(
                  fontSize: 15,
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ),
          )
        else ...[
          ..._picked.map((r) => _PickedCard(
            recipe: r,
            typeName: r.typeTagId == null ? null : _tagsById[r.typeTagId!]?.name,
          )),
          const SizedBox(height: 10),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: IOS26Theme.primaryColor,
            borderRadius: BorderRadius.circular(14),
            onPressed: _loading ? null : _importToWish,
            child: const Text(
              '就要这个（导入愿望单）',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
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

  Future<void> _pickTypes() async {
    final selected = await OvercookedTagPickerSheet.show(
      context,
      title: '选择类型搭配',
      tags: _typeTags,
      selectedIds: _selectedTypeIds,
      multi: true,
    );
    if (selected == null) return;
    setState(() => _selectedTypeIds = selected);
  }

  Future<void> _roll() async {
    if (_selectedTypeIds.isEmpty) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '请先选择“菜的类型搭配”',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = OvercookedGachaService(repository: context.read<OvercookedRepository>());
      final seed = DateTime.now().millisecondsSinceEpoch;
      final picked = await service.pick(typeTagIds: _selectedTypeIds.toList(), seed: seed);
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
          Text(
            recipe.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: IOS26Theme.textPrimary,
            ),
          ),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: IOS26Theme.toolPurple,
                ),
              ),
            ),
          ],
          if (recipe.intro.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              recipe.intro.trim(),
              style: TextStyle(
                fontSize: 12,
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

