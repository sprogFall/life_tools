import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/ios26_theme.dart';
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
  Map<int, int> _countsByDayKey = const {};

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
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = context.read<OvercookedRepository>();
      final stats = await repo.getMonthlyCookCountsByTypeDistinct(
        year: widget.month.year,
        month: widget.month.month,
      );
      setState(() => _countsByDayKey = stats);
    } finally {
      if (mounted) setState(() => _loading = false);
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '厨房日历',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
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
              const Text(
                '热力图（按"菜谱去重"的每日做菜量）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: IOS26Theme.textPrimary,
                ),
              ),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
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
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: IOS26Theme.textPrimary,
        ),
      ),
    );
  }

  Widget _monthButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 44,
        width: 44,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          child: Icon(icon, size: 18, color: IOS26Theme.textPrimary),
        ),
      ),
    );
  }
}
