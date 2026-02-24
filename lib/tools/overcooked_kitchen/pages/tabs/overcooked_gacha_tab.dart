import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../../core/obj_store/obj_store_service.dart';
import '../../../../core/tags/models/tag.dart';
import '../../../../core/tags/tag_service.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../overcooked_constants.dart';
import '../../models/overcooked_recipe.dart';
import '../../repository/overcooked_repository.dart';
import '../../services/overcooked_gacha_service.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_date_bar.dart';
import '../../widgets/overcooked_image.dart';
import '../../widgets/overcooked_tag_picker_sheet.dart';

class OvercookedGachaTab extends StatefulWidget {
  final DateTime targetDate;
  final ValueChanged<DateTime> onTargetDateChanged;
  final ValueChanged<DateTime> onImportToWish;
  final int refreshToken;
  final ObjStoreService? objStoreService;

  const OvercookedGachaTab({
    super.key,
    required this.targetDate,
    required this.onTargetDateChanged,
    required this.onImportToWish,
    this.refreshToken = 0,
    this.objStoreService,
  });

  @override
  State<OvercookedGachaTab> createState() => _OvercookedGachaTabState();
}

class _OvercookedGachaTabState extends State<OvercookedGachaTab>
    with TickerProviderStateMixin {
  static const _singleCardFlowDuration = Duration(milliseconds: 3000);

  bool _loading = false;
  List<Tag> _typeTags = const [];
  Map<int, Tag> _tagsById = const {};
  Set<int> _selectedTypeIds = {};
  Map<int, int> _typeCountById = {};
  Map<int, int> _typeRecipeTotalById = {};
  List<OvercookedRecipe> _picked = const [];
  bool _showDrawOverlay = false;
  List<OvercookedRecipe> _drawQueue = const [];
  int _drawCurrentIndex = -1;
  int _drawSession = 0;
  late final AnimationController _drawCardController;
  late final AnimationController _rollBurstController;

  ObjStoreService? _resolveObjStoreService() {
    if (widget.objStoreService != null) return widget.objStoreService;
    try {
      return context.read<ObjStoreService>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _drawCardController = AnimationController(
      vsync: this,
      duration: _singleCardFlowDuration,
    );
    _rollBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _loadTypes();
  }

  @override
  void dispose() {
    _drawCardController.dispose();
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
    final objStoreService = _resolveObjStoreService();

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
                  key: ValueKey('overcooked_gacha_picked_card-${r.id}'),
                  recipe: r,
                  objStoreService: objStoreService,
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
        if (_showDrawOverlay)
          _buildDrawOverlay(objStoreService: objStoreService),
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

  OvercookedRecipe? get _drawCurrentRecipe {
    if (_drawCurrentIndex < 0 || _drawCurrentIndex >= _drawQueue.length) {
      return null;
    }
    return _drawQueue[_drawCurrentIndex];
  }

  double _segment(double value, {required double start, required double end}) {
    if (value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }

  void _startDrawEffects({
    required List<OvercookedRecipe> queue,
    required bool reducedMotion,
  }) {
    if (reducedMotion) return;
    _drawCardController.stop();
    if (!mounted) return;
    setState(() {
      _showDrawOverlay = true;
      _drawQueue = queue;
      _drawCurrentIndex = queue.isEmpty ? -1 : 0;
    });
  }

  Future<void> _revealDrawEffects({
    required List<OvercookedRecipe> picked,
    required bool reducedMotion,
  }) async {
    final session = ++_drawSession;
    if (reducedMotion || picked.isEmpty) {
      if (!mounted) return;
      setState(() {
        _picked = [..._picked, ...picked];
        _showDrawOverlay = false;
        _drawQueue = const [];
        _drawCurrentIndex = -1;
      });
      return;
    }

    for (int i = 0; i < picked.length; i++) {
      if (!mounted || session != _drawSession) return;
      setState(() => _drawCurrentIndex = i);
      await _drawCardController.forward(from: 0);
      if (!mounted || session != _drawSession) return;
      setState(() {
        _picked = [..._picked, picked[i]];
      });
    }

    if (!mounted || session != _drawSession) return;
    setState(() {
      _showDrawOverlay = false;
      _drawQueue = const [];
      _drawCurrentIndex = -1;
    });
  }

  void _dismissDrawEffects() {
    _drawSession++;
    _drawCardController.stop();
    if (!mounted) return;
    setState(() {
      _showDrawOverlay = false;
      _drawQueue = const [];
      _drawCurrentIndex = -1;
    });
  }

  Widget _buildDrawOverlay({required ObjStoreService? objStoreService}) {
    final recipe = _drawCurrentRecipe;
    final total = _drawQueue.length;
    final joined = _picked.length.clamp(0, total);
    final drawText = total <= 0
        ? '抽卡准备中'
        : '抽卡进行中 ${_drawCurrentIndex + 1}/$total';

    return Positioned.fill(
      child: ColoredBox(
        color: IOS26Theme.overlayColor.withValues(alpha: 0.26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassContainer(
                key: const ValueKey('overcooked_gacha_draw_overlay'),
                borderRadius: 22,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(drawText, style: IOS26Theme.titleMedium),
                    const SizedBox(height: 12),
                    if (recipe == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CupertinoActivityIndicator(),
                      )
                    else
                      _buildAnimatedDrawCard(
                        recipe: recipe,
                        objStoreService: objStoreService,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '已加入列表 $joined/$total',
                      key: const ValueKey('overcooked_gacha_draw_progress'),
                      style: IOS26Theme.bodySmall.copyWith(
                        color: IOS26Theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDrawCard({
    required OvercookedRecipe recipe,
    required ObjStoreService? objStoreService,
  }) {
    return AnimatedBuilder(
      animation: _drawCardController,
      builder: (context, child) {
        final t = _drawCardController.value;
        final entrance = Curves.easeOutCubic.transform(
          _segment(t, start: 0, end: 0.22),
        );
        final flip = Curves.easeInOutCubic.transform(
          _segment(t, start: 0.22, end: 0.58),
        );
        final highlight = Curves.easeOutBack.transform(
          _segment(t, start: 0.58, end: 0.82),
        );
        final settle = Curves.easeInOut.transform(
          _segment(t, start: 0.82, end: 1),
        );

        final angle = math.pi * (1 - flip);
        final showFront = angle <= (math.pi / 2);
        final baseScale = 0.84 + (1 - 0.84) * entrance;
        final focusScale = 1 + (0.10 * math.sin(math.pi * highlight));
        final settleScale = 1 - (0.04 * settle);
        final scale = baseScale * focusScale * settleScale;
        final offsetY =
            (56 * (1 - entrance)) + (-18 * highlight) + (16 * settle);
        final glowAlpha = (0.10 + highlight * 0.22).clamp(0.0, 0.32);
        final glowBlur = 16 + highlight * 16;
        final typeName = recipe.typeTagId == null
            ? null
            : _tagsById[recipe.typeTagId!]?.name.trim();

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: Transform.scale(
              scale: scale,
              child: Container(
                key: const ValueKey('overcooked_gacha_draw_card'),
                width: 232,
                height: 296,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: IOS26Theme.surfaceColor.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: IOS26Theme.primaryColor.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: IOS26Theme.primaryColor.withValues(
                        alpha: glowAlpha,
                      ),
                      blurRadius: glowBlur,
                      spreadRadius: 1.5,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: showFront
                          ? _buildDrawCardFront(
                              recipe: recipe,
                              typeName: typeName,
                              objStoreService: objStoreService,
                            )
                          : _buildDrawCardBack(),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          key: const ValueKey(
                            'overcooked_gacha_draw_card_highlight',
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: RadialGradient(
                              colors: [
                                IOS26Theme.toolOrange.withValues(
                                  alpha: 0.16 * highlight,
                                ),
                                IOS26Theme.primaryColor.withValues(
                                  alpha: 0.10 * highlight,
                                ),
                                IOS26Theme.surfaceColor.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.62, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawCardFront({
    required OvercookedRecipe recipe,
    required String? typeName,
    required ObjStoreService? objStoreService,
  }) {
    final type = typeName?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 168,
          width: double.infinity,
          child: _RecipeImage(
            objStoreService: objStoreService,
            objectKey: recipe.coverImageKey,
            borderRadius: 14,
            cacheOnly: true,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          recipe.name,
          key: const ValueKey('overcooked_gacha_draw_card_name'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: IOS26Theme.titleMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        if (type != null && type.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: IOS26Theme.toolPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: IOS26Theme.toolPurple.withValues(alpha: 0.24),
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
      ],
    );
  }

  Widget _buildDrawCardBack() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              IOS26Theme.toolPurple.withValues(alpha: 0.28),
              IOS26Theme.primaryColor.withValues(alpha: 0.30),
            ],
          ),
          border: Border.all(
            color: IOS26Theme.primaryColor.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IOS26Icon(
              CupertinoIcons.sparkles,
              size: 26,
              tone: IOS26IconTone.accent,
            ),
            const SizedBox(height: 10),
            Text('咔哒... 抽卡中', style: IOS26Theme.titleSmall),
          ],
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
    setState(() {
      _loading = true;
      _picked = const [];
      if (!reducedMotion) {
        _showDrawOverlay = true;
        _drawQueue = const [];
        _drawCurrentIndex = -1;
      }
    });
    _rollBurstController.forward(from: 0);
    try {
      final service = OvercookedGachaService(repository: repository);
      final seed = DateTime.now().millisecondsSinceEpoch;
      final picked = await service.pickByTypeCounts(
        typeCounts: typeCounts,
        seed: seed,
      );
      if (!mounted) return;
      setState(() {
        _typeCountById = typeCounts;
      });
      _startDrawEffects(queue: picked, reducedMotion: reducedMotion);
      await _revealDrawEffects(picked: picked, reducedMotion: reducedMotion);
    } catch (e) {
      _dismissDrawEffects();
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
  final ObjStoreService? objStoreService;
  final String? typeName;

  const _PickedCard({
    super.key,
    required this.recipe,
    required this.objStoreService,
    required this.typeName,
  });

  @override
  Widget build(BuildContext context) {
    final type = typeName?.trim();
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: _RecipeImage(
              objStoreService: objStoreService,
              objectKey: recipe.coverImageKey,
              borderRadius: 14,
              cacheOnly: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name, style: IOS26Theme.titleMedium),
                if (type != null && type.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
          ),
        ],
      ),
    );
  }
}

class _RecipeImage extends StatelessWidget {
  final ObjStoreService? objStoreService;
  final String? objectKey;
  final double borderRadius;
  final bool cacheOnly;

  const _RecipeImage({
    required this.objStoreService,
    required this.objectKey,
    required this.borderRadius,
    this.cacheOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final service = objStoreService;
    if (service == null) {
      return Container(
        decoration: BoxDecoration(
          color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        alignment: Alignment.center,
        child: Text('无图片', style: IOS26Theme.bodySmall.copyWith(fontSize: 12)),
      );
    }

    return OvercookedImageByKey(
      objStoreService: service,
      objectKey: objectKey,
      borderRadius: borderRadius,
      cacheOnly: cacheOnly,
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
