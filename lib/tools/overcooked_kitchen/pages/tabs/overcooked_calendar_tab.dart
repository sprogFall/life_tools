import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/ios26_theme.dart';
import '../../models/overcooked_recipe.dart';
import '../../repository/overcooked_repository.dart';
import '../../utils/overcooked_utils.dart';

class OvercookedCalendarTab extends StatefulWidget {
  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onOpenDay;
  final int refreshToken;

  const OvercookedCalendarTab({
    super.key,
    required this.month,
    required this.onMonthChanged,
    required this.onOpenDay,
    this.refreshToken = 0,
  });

  @override
  State<OvercookedCalendarTab> createState() => _OvercookedCalendarTabState();
}

class _OvercookedCalendarTabState extends State<OvercookedCalendarTab> {
  bool _loading = false;
  bool _pendingLoad = false;
  Map<int, int> _countsByDayKey = const {};
  List<({DateTime cookedDate, OvercookedRecipe recipe, int cookCount})>
  _recentCookedRecipes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OvercookedCalendarTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _load();
      return;
    }
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) {
      _pendingLoad = true;
      return;
    }

    setState(() {
      _loading = true;
      _recentCookedRecipes = const [];
    });
    try {
      final repo = context.read<OvercookedRepository>();
      final statsFuture = repo.getMonthlyCookCountsByTypeDistinct(
        year: widget.month.year,
        month: widget.month.month,
      );
      final recentFuture = repo.listRecentCookedRecipesForMonth(
        year: widget.month.year,
        month: widget.month.month,
      );
      final stats = await statsFuture;
      final recent = await recentFuture;
      if (!mounted) return;
      setState(() {
        _countsByDayKey = stats;
        _recentCookedRecipes = recent;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_pendingLoad) {
          _pendingLoad = false;
          unawaited(_load());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(widget.month.year, widget.month.month, 1);
    final daysInMonth = DateTime(
      widget.month.year,
      widget.month.month + 1,
      0,
    ).day;
    final offset = monthStart.weekday - 1;

    final cells = <Widget>[];
    for (var i = 0; i < offset; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(widget.month.year, widget.month.month, day);
      final key = OvercookedRepository.dayKey(date);
      final count = _countsByDayKey[key] ?? 0;
      cells.add(_dayCell(date: date, count: count));
    }

    final hasRecentCookedRecipes = _recentCookedRecipes.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Row(
          children: [
            Expanded(child: Text('厨房日历', style: IOS26Theme.headlineMedium)),
            _monthButton(
              icon: CupertinoIcons.chevron_left,
              onPressed: () => widget.onMonthChanged(
                DateTime(widget.month.year, widget.month.month - 1),
              ),
              label: '上月',
            ),
            const SizedBox(width: 8),
            _monthChip(text: OvercookedFormat.yearMonth(widget.month)),
            const SizedBox(width: 8),
            _monthButton(
              icon: CupertinoIcons.chevron_right,
              onPressed: () => widget.onMonthChanged(
                DateTime(widget.month.year, widget.month.month + 1),
              ),
              label: '下月',
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('热力图', style: IOS26Theme.titleSmall),
              const SizedBox(height: 10),
              _weekdayHeader(),
              const SizedBox(height: 10),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: CupertinoActivityIndicator(),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: cells,
                ),
              const SizedBox(height: 12),
              _legend(),
            ],
          ),
        ),
        if (hasRecentCookedRecipes) ...[
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildRecentCookedRecipesCard(),
        ],
      ],
    );
  }

  Widget _weekdayHeader() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map(
            (e) => Expanded(
              child: Text(
                e,
                textAlign: TextAlign.center,
                style: IOS26Theme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _dayCell({required DateTime date, required int count}) {
    final intensity = count <= 0
        ? 0.0
        : count == 1
        ? 0.25
        : count == 2
        ? 0.42
        : count == 3
        ? 0.58
        : 0.72;
    final bg = count <= 0
        ? IOS26Theme.textTertiary.withValues(alpha: 0.20)
        : IOS26Theme.toolGreen.withValues(alpha: intensity);
    final border = count <= 0
        ? IOS26Theme.textTertiary.withValues(alpha: 0.25)
        : IOS26Theme.toolGreen.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: () => widget.onOpenDay(date),
      child: Container(
        key: ValueKey(
          'overcooked_calendar_day_${OvercookedRepository.dayKey(date)}',
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: IOS26Theme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: count <= 0
                ? IOS26Theme.textSecondary
                : IOS26Theme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        Text(
          '少',
          style: IOS26Theme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 8),
        ...[0.20, 0.25, 0.42, 0.58, 0.72].map(
          (a) => Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: IOS26Theme.toolGreen.withValues(alpha: a),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        Text(
          '多',
          style: IOS26Theme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCookedRecipesCard() {
    return GlassContainer(
      key: const ValueKey('overcooked_calendar_recent_recipes_card'),
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近做的菜', style: IOS26Theme.titleSmall),
          const SizedBox(height: IOS26Theme.spacingSm),
          ..._recentCookedRecipes.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _recentCookedRecipes.length - 1
                    ? 0
                    : IOS26Theme.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IOS26Theme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: IOS26Theme.spacingSm),
                  Text(
                    '${_formatMonthDay(item.cookedDate)} · ${_formatCookCount(item.cookCount)}',
                    style: IOS26Theme.bodySmall.copyWith(
                      color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatMonthDay(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  String _formatCookCount(int cookCount) {
    if (cookCount <= 1) return '做过1次';
    return '做过$cookCount次';
  }

  Widget _monthChip({required String text}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: IOS26Theme.titleSmall),
    );
  }

  Widget _monthButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String label,
  }) {
    final ghostButton = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 44,
        width: 44,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          color: ghostButton.background,
          borderRadius: BorderRadius.circular(14),
          child: Icon(icon, size: 18, color: IOS26Theme.textPrimary),
        ),
      ),
    );
  }
}
