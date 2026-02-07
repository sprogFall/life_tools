import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/work_task.dart';
import '../../models/work_time_entry.dart';
import '../../services/work_log_service.dart';
import '../task/work_task_detail_page.dart';

enum WorkCalendarMode { month, week, day }

class WorkLogCalendarView extends StatefulWidget {
  const WorkLogCalendarView({super.key});

  @override
  State<WorkLogCalendarView> createState() => _WorkLogCalendarViewState();
}

class _WorkLogCalendarViewState extends State<WorkLogCalendarView> {
  WorkCalendarMode _mode = WorkCalendarMode.month;

  DateTime _focusedMonth = _startOfMonth(DateTime.now());
  DateTime _selectedDate = _startOfDay(DateTime.now());

  bool _loading = false;
  List<WorkTimeEntry> _entries = const [];
  Map<DateTime, int> _dailyMinutes = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildModeSegment(),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CupertinoActivityIndicator())
          else
            _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final title = switch (_mode) {
      WorkCalendarMode.month => '${_focusedMonth.month}月',
      WorkCalendarMode.week =>
        _formatDate(_startOfWeek(_selectedDate)),
      WorkCalendarMode.day => _formatDate(_selectedDate),
    };

    final subtitle = switch (_mode) {
      WorkCalendarMode.month => '${_focusedMonth.year}年',
      WorkCalendarMode.week => '周视图',
      WorkCalendarMode.day => '日视图',
    };

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: IOS26Theme.displayMedium.copyWith(
                height: 1.0,
                color: IOS26Theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textTertiary,
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _goPrev,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IOS26Theme.surfaceColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: IOS26Theme.glassBorderColor,
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.chevron_left,
                  size: 20,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _goNext,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IOS26Theme.surfaceColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: IOS26Theme.glassBorderColor,
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.chevron_right,
                  size: 20,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSegment() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<WorkCalendarMode>(
        groupValue: _mode,
        backgroundColor: IOS26Theme.surfaceColor.withValues(alpha: 0.5),
        thumbColor: IOS26Theme.surfaceColor,
        children: const {
          WorkCalendarMode.month: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text('月'),
          ),
          WorkCalendarMode.week: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text('周'),
          ),
          WorkCalendarMode.day: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text('日'),
          ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          setState(() => _mode = value);
          _load();
        },
      ),
    );
  }

  Widget _buildBody() {
    return switch (_mode) {
      WorkCalendarMode.month => _buildMonthView(),
      WorkCalendarMode.week => _buildWeekView(),
      WorkCalendarMode.day => _buildDayView(),
    };
  }

  Widget _buildMonthView() {
    final firstOfMonth = _startOfMonth(_focusedMonth);
    final leading = (firstOfMonth.weekday - DateTime.monday) % 7;
    final startCell = firstOfMonth.subtract(Duration(days: leading));
    final daysInMonth = DateUtils.getDaysInMonth(
      firstOfMonth.year,
      firstOfMonth.month,
    );
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        _buildWeekdayHeader(),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 64,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
          ),
          itemBuilder: (context, index) {
            final date = startCell.add(Duration(days: index));
            final inMonth = date.month == firstOfMonth.month;
            final minutes = _dailyMinutes[_startOfDay(date)] ?? 0;
            final selected = _isSameDay(date, _selectedDate);
            return _DayCell(
              date: date,
              inMonth: inMonth,
              selected: selected,
              minutes: minutes,
              onTap: () {
                setState(() {
                  _selectedDate = _startOfDay(date);
                  _mode = WorkCalendarMode.day;
                });
                _load();
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeekView() {
    final start = _startOfWeek(_selectedDate);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return Column(
      children: [
        ...days.map((d) {
          final minutes = _dailyMinutes[_startOfDay(d)] ?? 0;
          final selected = _isSameDay(d, _selectedDate);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = _startOfDay(d);
                  _mode = WorkCalendarMode.day;
                });
                _load();
              },
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                color: selected
                    ? IOS26Theme.primaryColor.withValues(alpha: 0.10)
                    : null,
                child: Row(
                  children: [
                    Text(_formatWeekday(d), style: IOS26Theme.titleSmall),
                    const SizedBox(width: 10),
                    Text(_formatDate(d), style: IOS26Theme.bodySmall),
                    const Spacer(),
                    if (minutes > 0)
                      Text(
                        _minutesToHoursText(minutes),
                        style: IOS26Theme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.primaryColor,
                        ),
                      )
                    else
                      Text(
                        '0h',
                        style: IOS26Theme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 18,
                      color: IOS26Theme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDayView() {
    final day = _startOfDay(_selectedDate);
    final todaysEntries =
        _entries.where((e) => _isSameDay(e.workDate, day)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final total = todaysEntries.fold<int>(0, (sum, e) => sum + e.minutes);
    final taskTitleById = _taskTitleMap(
      context.watch<WorkLogService>().allTasks,
    );

    return Column(
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('总计', style: IOS26Theme.titleSmall),
              const Spacer(),
              Text(
                total > 0 ? _minutesToHoursText(total) : '0h',
                style: IOS26Theme.titleSmall.copyWith(
                  color: IOS26Theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (todaysEntries.isEmpty)
          Text(
            '当天暂无工时记录',
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
            ),
          )
        else
          ...todaysEntries.map((e) {
            final taskTitle = taskTitleById[e.taskId] ?? '任务#${e.taskId}';
            final content = e.content.trim().isEmpty ? '（无内容）' : e.content;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _openTaskDetail(context, e.taskId, taskTitle),
                child: GlassContainer(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('工作内容：$content', style: IOS26Theme.titleSmall),
                            const SizedBox(height: 6),
                            Text(
                              '任务：$taskTitle',
                              style: IOS26Theme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _minutesToHoursText(e.minutes),
                        style: IOS26Theme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 18,
                        color: IOS26Theme.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map(
            (t) => Expanded(
              child: Center(
                child: Text(
                  t,
                  style: IOS26Theme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final (start, end) = _rangeForMode();
    final service = context.read<WorkLogService>();
    final entries = await service.listTimeEntriesInRange(start, end);
    if (!mounted) return;

    final daily = <DateTime, int>{};
    for (final e in entries) {
      final day = _startOfDay(e.workDate);
      daily[day] = (daily[day] ?? 0) + e.minutes;
    }

    setState(() {
      _entries = entries;
      _dailyMinutes = daily;
      _loading = false;
    });
  }

  (DateTime, DateTime) _rangeForMode() {
    return switch (_mode) {
      WorkCalendarMode.month => (
        _startOfMonth(_focusedMonth),
        _startOfMonth(_addMonths(_focusedMonth, 1)),
      ),
      WorkCalendarMode.week => (
        _startOfWeek(_selectedDate),
        _startOfWeek(_selectedDate).add(const Duration(days: 7)),
      ),
      WorkCalendarMode.day => (
        _startOfDay(_selectedDate),
        _startOfDay(_selectedDate).add(const Duration(days: 1)),
      ),
    };
  }

  void _goPrev() {
    setState(() {
      if (_mode == WorkCalendarMode.month) {
        _focusedMonth = _addMonths(_focusedMonth, -1);
      } else if (_mode == WorkCalendarMode.week) {
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
      } else {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      }
    });
    _load();
  }

  void _goNext() {
    setState(() {
      if (_mode == WorkCalendarMode.month) {
        _focusedMonth = _addMonths(_focusedMonth, 1);
      } else if (_mode == WorkCalendarMode.week) {
        _selectedDate = _selectedDate.add(const Duration(days: 7));
      } else {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      }
    });
    _load();
  }

  void _openTaskDetail(BuildContext context, int taskId, String title) {
    final service = context.read<WorkLogService>();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: service,
          child: WorkTaskDetailPage(taskId: taskId, title: title),
        ),
      ),
    );
  }

  static Map<int, String> _taskTitleMap(List<WorkTask> tasks) {
    return {
      for (final t in tasks)
        if (t.id != null) t.id!: t.title,
    };
  }

  static DateTime _startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static DateTime _startOfWeek(DateTime dateTime) {
    final d = _startOfDay(dateTime);
    final diff = (d.weekday - DateTime.monday) % 7;
    return d.subtract(Duration(days: diff));
  }

  static DateTime _startOfMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month);
  }

  static DateTime _addMonths(DateTime dateTime, int deltaMonths) {
    return DateTime(dateTime.year, dateTime.month + deltaMonths);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _minutesToHoursText(int minutes) {
    final hours = minutes / 60.0;
    if ((hours - hours.roundToDouble()).abs() < 0.001) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  static String _formatWeekday(DateTime date) {
    const map = {
      DateTime.monday: '周一',
      DateTime.tuesday: '周二',
      DateTime.wednesday: '周三',
      DateTime.thursday: '周四',
      DateTime.friday: '周五',
      DateTime.saturday: '周六',
      DateTime.sunday: '周日',
    };
    return map[date.weekday] ?? '';
  }

  static String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool inMonth;
  final bool selected;
  final int minutes;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.selected,
    required this.minutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    Color textColor;
    if (selected) {
      textColor = IOS26Theme.surfaceColor;
    } else if (isToday) {
      textColor = IOS26Theme.primaryColor;
    } else if (!inMonth) {
      textColor = IOS26Theme.textTertiary.withValues(alpha: 0.3);
    } else if (isWeekend) {
      textColor = IOS26Theme.textPrimary.withValues(alpha: 0.9);
    } else {
      textColor = IOS26Theme.textPrimary;
    }

    final minutesText = minutes > 0 ? _minutesToHoursText(minutes) : null;
    final minutesColor = selected
        ? IOS26Theme.surfaceColor.withValues(alpha: 0.9)
        : IOS26Theme.textSecondary.withValues(alpha: 0.8);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 46,
          height: 54,
          decoration: selected
              ? BoxDecoration(
                  color: IOS26Theme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: IOS26Theme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              if (minutesText != null)
                Text(
                  minutesText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: minutesColor,
                    height: 1.0,
                  ),
                )
              else if (isToday && !selected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: IOS26Theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 10 + 4),
            ],
          ),
        ),
      ),
    );
  }

  static String _minutesToHoursText(int minutes) {
    final hours = minutes / 60.0;
    if ((hours - hours.roundToDouble()).abs() < 0.001) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }
}
