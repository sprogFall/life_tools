import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
  final int refreshToken;

  const OvercookedGachaTab({
    super.key,
    required this.targetDate,
    required this.onTargetDateChanged,
    required this.onImportToWish,
    this.refreshToken = 0,
  });

  @override
  State<OvercookedGachaTab> createState() => _OvercookedGachaTabState();
}

class _OvercookedGachaTabState extends State<OvercookedGachaTab>
    with TickerProviderStateMixin {
  static const _defaultSlotTickerLabels = ['热锅中', '翻炒中', '香味暴击'];
  static const _slotSpinMinimumDuration = Duration(milliseconds: 1500);

  bool _loading = false;
  List<Tag> _typeTags = const [];
  Map<int, Tag> _tagsById = const {};
  Set<int> _selectedTypeIds = {};
  Map<int, int> _typeCountById = {};
  Map<int, int> _typeRecipeTotalById = {};
  List<OvercookedRecipe> _picked = const [];
  bool _showSlotOverlay = false;
  bool _showSlotResult = false;
  List<OvercookedRecipe> _slotResultRecipes = const [];
  List<String> _slotTickerLabels = _defaultSlotTickerLabels;
  List<_SlotRollDatum> _slotRollData = const [];
  late final AnimationController _slotSpinController;
  late final AnimationController _slotRevealController;
  late final AnimationController _rollBurstController;
  late final Animation<double> _slotRevealAnimation;

  @override
  void initState() {
    super.initState();
    _slotSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1120),
    );
    _slotRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _rollBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slotRevealAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: CurveTween(curve: Curves.easeOutCubic),
        weight: 35,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(1), weight: 65),
    ]).animate(_slotRevealController);
    _loadTypes();
  }

  @override
  void dispose() {
    _slotSpinController.dispose();
    _slotRevealController.dispose();
    _rollBurstController.dispose();
    super.dispose();
  }

  bool get _prefersReducedMotion {
    final mediaQuery = MediaQuery.maybeOf(context);
    return (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);
  }

  @override
  void didUpdateWidget(covariant OvercookedGachaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadTypes();
    }
  }

  Future<void> _loadTypes() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final tagService = context.read<TagService>();
      final repository = context.read<OvercookedRepository>();
      final tags = await tagService.listTagsForToolCategory(
        toolId: OvercookedConstants.toolId,
        categoryId: OvercookedTagCategories.dishType,
      );
      final tagIds = tags
          .map((tag) => tag.id)
          .whereType<int>()
          .toSet()
          .toList(growable: false);
      final recipeTotals = await repository.countRecipesByTypeTagIds(tagIds);

      final normalizedTotals = <int, int>{
        for (final id in tagIds)
          id: ((recipeTotals[id] ?? 0) < 0 ? 0 : (recipeTotals[id] ?? 0)),
      };

      final nextSelectedTypeIds = _selectedTypeIds
          .where((id) => (normalizedTotals[id] ?? 0) > 0)
          .toSet();
      final nextTypeCountById = _buildTypeCountMap(
        selectedTypeIds: nextSelectedTypeIds,
        recipeTotals: normalizedTotals,
        currentCounts: _typeCountById,
      );

      if (!mounted) return;
      setState(() {
        _typeTags = tags;
        _tagsById = {
          for (final t in tags)
            if (t.id != null) t.id!: t,
        };
        _typeRecipeTotalById = normalizedTotals;
        _selectedTypeIds = nextSelectedTypeIds;
        _typeCountById = nextTypeCountById;
        _picked = const [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<int> get _disabledTypeIds {
    return _typeRecipeTotalById.entries
        .where((entry) => entry.value <= 0)
        .map((entry) => entry.key)
        .toSet();
  }

  int _recipeTotalForType(int typeId) {
    final total = _typeRecipeTotalById[typeId] ?? 0;
    return total < 0 ? 0 : total;
  }

  Map<int, int> _buildTypeCountMap({
    required Set<int> selectedTypeIds,
    required Map<int, int> recipeTotals,
    required Map<int, int> currentCounts,
  }) {
    final next = <int, int>{};
    for (final id in selectedTypeIds) {
      final max = recipeTotals[id] ?? 0;
      if (max <= 0) continue;
      final current = currentCounts[id] ?? 1;
      next[id] = current.clamp(1, max).toInt();
    }
    return next;
  }

  Map<int, int> _effectiveTypeCounts() {
    return _buildTypeCountMap(
      selectedTypeIds: _selectedTypeIds,
      recipeTotals: _typeRecipeTotalById,
      currentCounts: _typeCountById,
    );
  }

  Future<void> _onTypeCountChanged({
    required int typeId,
    required String typeName,
    required int next,
  }) async {
    final max = _recipeTotalForType(typeId);
    if (max <= 0) return;

    final current = (_typeCountById[typeId] ?? 1).clamp(1, max).toInt();
    if (next > max) {
      if (current != max && mounted) {
        setState(() {
          _typeCountById = {..._typeCountById, typeId: max};
        });
      }
      if (!mounted) return;
      await OvercookedDialogs.showMessage(
        context,
        title: '已达到上限',
        content: '当前风格“$typeName”只有 $max 道可抽菜品，不能再加啦。',
      );
      return;
    }

    final clamped = next.clamp(1, max).toInt();
    if (clamped == current || !mounted) return;
    setState(() {
      _typeCountById = {..._typeCountById, typeId: clamped};
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        _selectedTypeIds
            .map((id) {
              final name = _tagsById[id]?.name;
              final trimmed = name?.trim();
              if (trimmed == null || trimmed.isEmpty) return null;
              final maxCount = _recipeTotalForType(id);
              if (maxCount <= 0) return null;
              final count = (_typeCountById[id] ?? 1)
                  .clamp(1, maxCount)
                  .toInt();
              return (id: id, name: trimmed, count: count, maxCount: maxCount);
            })
            .whereType<({int id, String name, int count, int maxCount})>()
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final totalCount = entries.fold<int>(0, (sum, e) => sum + e.count);
    final typeText = entries.isEmpty
        ? '未选择'
        : entries.map((e) => '${e.name}×${e.count}').join('、');
    final canRoll = !_loading && entries.isNotEmpty && totalCount > 0;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            Row(
              children: [
                Expanded(child: Text('扭蛋机', style: IOS26Theme.headlineMedium)),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IOS26Button(
                      key: const ValueKey('overcooked_gacha_roll_button'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      variant: canRoll
                          ? IOS26ButtonVariant.primary
                          : IOS26ButtonVariant.ghost,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: canRoll ? _roll : null,
                      child: IOS26ButtonLabel(
                        '扭蛋',
                        style: IOS26Theme.labelLarge,
                      ),
                    ),
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _rollBurstController,
                        builder: (context, child) {
                          if (!_rollBurstController.isAnimating) {
                            return const SizedBox.shrink();
                          }
                          final progress = _rollBurstController.value;
                          return CustomPaint(
                            key: const ValueKey(
                              'overcooked_gacha_roll_particle_burst',
                            ),
                            size: const Size(116, 58),
                            painter: _RollParticleBurstPainter(
                              progress: progress,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _fieldTitle('菜品风格搭配'),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: IOS26Button(
                key: const ValueKey('overcooked_gacha_pick_types_button'),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                variant: IOS26ButtonVariant.ghost,
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
                    IOS26Icon(
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
                            color: IOS26Theme.textSecondary.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...entries.map(
                      (e) => _TypeCountRow(
                        typeId: e.id,
                        name: e.name,
                        count: e.count,
                        onChanged: _loading
                            ? null
                            : (next) => _onTypeCountChanged(
                                typeId: e.id,
                                typeName: e.name,
                                next: next,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            OvercookedDateBar(
              title: '导入愿望单',
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
              IOS26Button(
                key: const ValueKey('overcooked_gacha_import_button'),
                padding: const EdgeInsets.symmetric(vertical: 14),
                variant: IOS26ButtonVariant.primary,
                borderRadius: BorderRadius.circular(14),
                onPressed: _loading ? null : _importToWish,
                child: IOS26ButtonLabel('就你了', style: IOS26Theme.labelLarge),
              ),
            ],
          ],
        ),
        if (_showSlotOverlay) _buildSlotOverlay(),
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
      disabledTagIds: _disabledTypeIds,
    );
    if (selected == null || !mounted) return;
    if (selected.tagsChanged) {
      await _loadTypes();
      if (!mounted) return;
    }

    final nextSelectedTypeIds = selected.selectedIds
        .where((id) => _recipeTotalForType(id) > 0)
        .toSet();
    setState(() {
      _selectedTypeIds = nextSelectedTypeIds;
      _typeCountById = _buildTypeCountMap(
        selectedTypeIds: _selectedTypeIds,
        recipeTotals: _typeRecipeTotalById,
        currentCounts: _typeCountById,
      );
      _picked = const [];
    });
  }

  List<String> _buildSlotFallbackTickerLabels(Map<int, int> typeCounts) {
    final labels = <String>[];
    final sortedEntries = typeCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedEntries) {
      final name = _tagsById[entry.key]?.name.trim();
      if (name == null || name.isEmpty) continue;
      final repeat = entry.value.clamp(1, 3).toInt();
      for (int i = 0; i < repeat; i++) {
        labels.add('$name·准备上桌');
      }
    }

    if (labels.isEmpty) {
      return _defaultSlotTickerLabels;
    }
    labels.shuffle(math.Random(DateTime.now().microsecondsSinceEpoch));
    if (labels.length >= 3) return labels;
    return [...labels, '大火翻炒', '随机上菜'].take(3).toList(growable: false);
  }

  List<_SlotRollDatum> _buildSlotRollData({
    required List<OvercookedRecipe> candidates,
    required Map<int, ({int cookCount, double avgRating, int ratingCount})>
    recipeStats,
  }) {
    final byType = <int, List<OvercookedRecipe>>{};
    for (final recipe in candidates) {
      final typeId = recipe.typeTagId;
      if (typeId == null || !_selectedTypeIds.contains(typeId)) continue;
      (byType[typeId] ??= <OvercookedRecipe>[]).add(recipe);
    }
    if (byType.isEmpty) return const [];

    final data = <_SlotRollDatum>[];
    final typeIds = byType.keys.toList()..sort();
    for (final typeId in typeIds) {
      final typeName = _tagsById[typeId]?.name.trim();
      final recipes = byType[typeId] ?? const <OvercookedRecipe>[];
      if (recipes.isEmpty) continue;

      final weighted = <({OvercookedRecipe recipe, double weight})>[];
      var totalWeight = 0.0;
      for (final recipe in recipes) {
        final id = recipe.id;
        final stat = id == null ? null : recipeStats[id];
        final avgRating = (stat?.avgRating ?? 0).clamp(0, 5).toDouble();
        final weight = OvercookedGachaService.weightForAverageRating(avgRating);
        weighted.add((recipe: recipe, weight: weight));
        totalWeight += weight;
      }

      for (final item in weighted) {
        final recipe = item.recipe;
        final name = recipe.name.trim();
        if (name.isEmpty) continue;
        final probability = totalWeight <= 0
            ? (1 / weighted.length)
            : (item.weight / totalWeight);
        data.add(
          _SlotRollDatum(
            name: name,
            typeName: typeName,
            probability: probability,
          ),
        );
      }
    }

    data.sort((a, b) {
      final byProbability = b.probability.compareTo(a.probability);
      if (byProbability != 0) return byProbability;
      return a.name.compareTo(b.name);
    });
    return data;
  }

  List<String> _buildSlotTickerLabelsFromRollData(List<_SlotRollDatum> data) {
    if (data.isEmpty) return _defaultSlotTickerLabels;
    final labels = data.map((entry) => entry.reelLabel).toList();
    if (labels.length == 1) {
      return [labels.first, labels.first, labels.first];
    }
    if (labels.length == 2) {
      return [...labels, ...labels];
    }
    return labels;
  }

  void _startRollEffects({
    required Map<int, int> typeCounts,
    required bool reducedMotion,
    required List<_SlotRollDatum> slotRollData,
  }) {
    _rollBurstController.forward(from: 0);
    _slotRevealController.value = 0;
    if (!mounted) return;
    setState(() {
      _showSlotOverlay = true;
      _showSlotResult = false;
      _slotResultRecipes = const [];
      _slotRollData = slotRollData;
      _slotTickerLabels = slotRollData.isEmpty
          ? _buildSlotFallbackTickerLabels(typeCounts)
          : _buildSlotTickerLabelsFromRollData(slotRollData);
    });
    if (reducedMotion) {
      _slotSpinController
        ..stop()
        ..value = 0;
    } else {
      _slotSpinController.repeat();
    }
  }

  Future<void> _revealRollEffects({
    required List<OvercookedRecipe> picked,
    required bool reducedMotion,
  }) async {
    _slotSpinController.stop();
    if (!mounted) return;
    setState(() {
      _showSlotResult = true;
      _slotResultRecipes = picked;
    });
    if (reducedMotion) {
      _slotRevealController.value = 1;
    } else {
      await _slotRevealController.forward(from: 0);
    }
    if (!mounted) return;
    setState(() {
      _showSlotOverlay = false;
      _showSlotResult = false;
      _slotResultRecipes = const [];
      _slotRollData = const [];
      _slotTickerLabels = _defaultSlotTickerLabels;
    });
  }

  void _dismissRollEffects() {
    _slotSpinController.stop();
    if (!mounted) return;
    setState(() {
      _showSlotOverlay = false;
      _showSlotResult = false;
      _slotResultRecipes = const [];
      _slotRollData = const [];
      _slotTickerLabels = _defaultSlotTickerLabels;
    });
  }

  Widget _buildSlotOverlay() {
    final bool showingResult = _showSlotResult;
    final title = showingResult ? '开盖啦' : '扭蛋机高速运转中';

    return Positioned.fill(
      child: ColoredBox(
        color: IOS26Theme.overlayColor.withValues(alpha: 0.20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassContainer(
                key: const ValueKey('overcooked_gacha_slot_overlay'),
                borderRadius: 22,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: IOS26Theme.titleMedium),
                    const SizedBox(height: 12),
                    if (showingResult)
                      FadeTransition(
                        opacity: _slotRevealAnimation,
                        child: Container(
                          key: const ValueKey(
                            'overcooked_gacha_slot_result_reveal',
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          decoration: BoxDecoration(
                            color: IOS26Theme.surfaceColor.withValues(
                              alpha: 0.90,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: IOS26Theme.toolOrange.withValues(
                                alpha: 0.30,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '本次抽中',
                                style: IOS26Theme.titleSmall.copyWith(
                                  color: IOS26Theme.toolOrange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_slotResultRecipes.isEmpty)
                                Text(
                                  '这轮没有抽到菜品，换个风格再试试。',
                                  style: IOS26Theme.bodySmall,
                                )
                              else
                                ..._slotResultRecipes
                                    .take(4)
                                    .map(
                                      (recipe) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          '• ${recipe.name}',
                                          style: IOS26Theme.bodyMedium,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      _buildSlotDataBasisCard(),
                      const SizedBox(height: 10),
                      _SlotMachineReel(
                        labels: _slotTickerLabels,
                        spin: _slotSpinController,
                      ),
                    ],
                    if (!showingResult) ...[
                      const SizedBox(height: 10),
                      Text(
                        '咕噜咕噜... 按候选权重滚动中',
                        style: IOS26Theme.bodySmall.copyWith(
                          color: IOS26Theme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotDataBasisCard() {
    final topItems = _slotRollData.take(3).toList(growable: false);
    return Container(
      key: const ValueKey('overcooked_gacha_slot_data_basis'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: IOS26Theme.toolBlue.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本轮候选 ${_slotRollData.length} 道菜（评分越高概率越高）',
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (topItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topItems.map(_buildSlotDataPill).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotDataPill(_SlotRollDatum item) {
    final typePrefix = item.typeName == null || item.typeName!.isEmpty
        ? ''
        : '${item.typeName}·';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: IOS26Theme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: IOS26Theme.primaryColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        '$typePrefix${item.name} ${item.percentLabel}',
        style: IOS26Theme.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: IOS26Theme.primaryColor,
        ),
      ),
    );
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

    final typeCounts = _effectiveTypeCounts();
    if (typeCounts.isEmpty || typeCounts.values.every((c) => c <= 0)) {
      await OvercookedDialogs.showMessage(
        context,
        title: '提示',
        content: '请至少选择 1 个有可抽菜品的风格，并设置抽取数量',
      );
      return;
    }

    final repository = context.read<OvercookedRepository>();
    final reducedMotion = _prefersReducedMotion;
    setState(() => _loading = true);
    try {
      final typeIds = typeCounts.keys.toList()..sort();
      final slotCandidates = await repository.listRecipesByTypeTagIds(typeIds);
      final recipeStats = await repository.getRecipeStats();
      final slotRollData = _buildSlotRollData(
        candidates: slotCandidates,
        recipeStats: recipeStats,
      );
      _startRollEffects(
        typeCounts: typeCounts,
        reducedMotion: reducedMotion,
        slotRollData: slotRollData,
      );

      final spinStartTime = DateTime.now();
      final service = OvercookedGachaService(repository: repository);
      final seed = DateTime.now().millisecondsSinceEpoch;
      final picked = await service.pickByTypeCounts(
        typeCounts: typeCounts,
        seed: seed,
      );
      if (!reducedMotion) {
        final elapsed = DateTime.now().difference(spinStartTime);
        final remain = _slotSpinMinimumDuration - elapsed;
        if (remain > Duration.zero) {
          await Future<void>.delayed(remain);
        }
      }
      if (!mounted) return;
      setState(() {
        _typeCountById = typeCounts;
        _picked = picked;
      });
      await _revealRollEffects(picked: picked, reducedMotion: reducedMotion);
    } catch (e) {
      _dismissRollEffects();
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
  final int typeId;
  final String name;
  final int count;
  final ValueChanged<int>? onChanged;

  const _TypeCountRow({
    required this.typeId,
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
            key: ValueKey('overcooked_gacha_count_minus-$typeId'),
            icon: CupertinoIcons.minus,
            enabled: onChanged != null && c > 1,
            onPressed: () => onChanged?.call(c - 1),
          ),
          const SizedBox(width: 10),
          Text('$c', style: IOS26Theme.titleSmall),
          const SizedBox(width: 10),
          _iconButton(
            key: ValueKey('overcooked_gacha_count_add-$typeId'),
            icon: CupertinoIcons.add,
            enabled: onChanged != null,
            onPressed: () => onChanged?.call(c + 1),
          ),
        ],
      ),
    );
  }

  static Widget _iconButton({
    Key? key,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IOS26Button(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: IOS26Theme.minimumTapSize,
      onPressed: enabled ? onPressed : null,
      variant: IOS26ButtonVariant.ghost,
      borderRadius: BorderRadius.circular(14),
      child: IOS26Icon(
        icon,
        size: 16,
        tone: enabled ? IOS26IconTone.accent : IOS26IconTone.secondary,
      ),
    );
  }
}

class _SlotRollDatum {
  final String name;
  final String? typeName;
  final double probability;

  const _SlotRollDatum({
    required this.name,
    required this.typeName,
    required this.probability,
  });

  String get percentLabel {
    final normalized = probability.clamp(0, 1).toDouble();
    final percent = (normalized * 100).round().clamp(0, 100);
    return '$percent%';
  }

  String get reelLabel {
    if (typeName == null || typeName!.isEmpty) {
      return '$name $percentLabel';
    }
    return '${typeName!}·$name $percentLabel';
  }
}

class _SlotMachineReel extends StatelessWidget {
  final List<String> labels;
  final Animation<double> spin;

  const _SlotMachineReel({required this.labels, required this.spin});

  @override
  Widget build(BuildContext context) {
    final reelLabels = labels.isEmpty ? const ['热锅中', '翻炒中', '香味暴击'] : labels;
    return Container(
      height: 98,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: IOS26Theme.toolPurple.withValues(alpha: 0.24),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildColumn(reelLabels, index),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: IOS26Theme.toolOrange.withValues(alpha: 0.26),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    IOS26Theme.toolOrange.withValues(alpha: 0.04),
                    IOS26Theme.primaryColor.withValues(alpha: 0.09),
                    IOS26Theme.toolOrange.withValues(alpha: 0.04),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(List<String> labels, int columnIndex) {
    const itemHeight = 28.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              IOS26Theme.surfaceVariant.withValues(alpha: 0.75),
              IOS26Theme.surfaceColor.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: spin,
          builder: (context, child) {
            final speedFactor = labels.length * 3.8;
            final raw = spin.value * speedFactor + columnIndex * 1.37;
            final current = raw.floor() % labels.length;
            final next = (current + 1) % labels.length;
            final shift = (raw - raw.floor()) * itemHeight;
            return Transform.translate(
              offset: Offset(0, -shift),
              child: Column(
                children: [
                  _buildCell(labels[current], itemHeight),
                  _buildCell(labels[next], itemHeight),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCell(String label, double height) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RollParticleBurstPainter extends CustomPainter {
  final double progress;

  const _RollParticleBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1 - progress).clamp(0.0, 1.0);
    final glowPaint = Paint()
      ..color = IOS26Theme.toolOrange.withValues(alpha: 0.35 * fade);
    canvas.drawCircle(center, 8 + progress * 16, glowPaint);

    final colors = [
      IOS26Theme.toolOrange,
      IOS26Theme.toolPink,
      IOS26Theme.toolPurple,
      IOS26Theme.primaryColor,
    ];

    const particleCount = 14;
    for (int i = 0; i < particleCount; i++) {
      final angle = (math.pi * 2 / particleCount) * i + progress * 0.45;
      final distance = 14 + progress * 30 + (i % 3) * 2;
      final radius = 1.4 + ((particleCount - i) % 3) * 0.7;
      final particleAlpha = (0.86 - progress * 0.8).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: particleAlpha);
      final position = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      canvas.drawCircle(position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RollParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
