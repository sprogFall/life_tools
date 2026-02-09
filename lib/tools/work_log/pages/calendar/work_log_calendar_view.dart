import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/ios26_theme.dart';
import '../../../../l10n/app_localizations.dart';
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
      padding: const EdgeInsets.fromLTRB(
        IOS26Theme.spacingXl,
        0,
        IOS26Theme.spacingXl,
        IOS26Theme.spacingXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildModeSegment(),
          const SizedBox(height: IOS26Theme.spacingMd),
          if (_loading)
            const Center(child: CupertinoActivityIndicator())
          else
            _buildBody(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final title = switch (_mode) {
      WorkCalendarMode.month => l10n.work_log_calendar_month_title(
        _focusedMonth.month,
      ),
      WorkCalendarMode.week => _formatDate(_startOfWeek(_selectedDate)),
      WorkCalendarMode.day => _formatDate(_selectedDate),
    };

    final subtitle = switch (_mode) {
      WorkCalendarMode.month => l10n.work_log_calendar_month_subtitle(
        _countDaysWithRecords(),
      ),
      WorkCalendarMode.week => l10n.work_log_calendar_week_subtitle,
      WorkCalendarMode.day => l10n.work_log_calendar_day_subtitle,
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
            const SizedBox(height: IOS26Theme.spacingXs),
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
              minimumSize: IOS26Theme.minimumTapSize,
              onPressed: _goPrev,
              child: Container(
                padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                decoration: BoxDecoration(
                  color: IOS26Theme.surfaceColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: IOS26Theme.glassBorderColor,
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 20,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: IOS26Theme.spacingMd),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: IOS26Theme.minimumTapSize,
              onPressed: _goNext,
              child: Container(
                padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                decoration: BoxDecoration(
                  color: IOS26Theme.surfaceColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: IOS26Theme.glassBorderColor,
                    width: 0.5,
                  ),
                ),
                child: Icon(
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
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<WorkCalendarMode>(
        groupValue: _mode,
        backgroundColor: IOS26Theme.surfaceColor.withValues(alpha: 0.5),
        thumbColor: IOS26Theme.surfaceColor,
        children: {
          WorkCalendarMode.month: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: IOS26Theme.spacingSm,
            ),
            child: Text(l10n.work_log_calendar_month_mode),
          ),
          WorkCalendarMode.week: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: IOS26Theme.spacingSm,
            ),
            child: Text(l10n.work_log_calendar_week_mode),
          ),
          WorkCalendarMode.day: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: IOS26Theme.spacingSm,
            ),
            child: Text(l10n.work_log_calendar_day_mode),
          ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          setState(() {
            _mode = value;
            if (value == WorkCalendarMode.month) {
              _focusedMonth = _startOfMonth(_selectedDate);
            }
          });
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
    final monthGrid = _buildMonthGrid(_focusedMonth);
    final firstOfMonth = monthGrid.firstOfMonth;

    final selectedDay = _startOfDay(_selectedDate);
    final selectedEntries =
        _entries.where((e) => _isSameDay(e.workDate, selectedDay)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final selectedTotal = selectedEntries.fold<int>(
      0,
      (sum, e) => sum + e.minutes,
    );

    final taskTitleById = _taskTitleMap(
      context.watch<WorkLogService>().allTasks,
    );
    final recentDays =
        _dailyMinutes.entries
            .where(
              (entry) => entry.value > 0 && !_isSameDay(entry.key, selectedDay),
            )
            .toList()
          ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      children: [
        GlassContainer(
          borderRadius: IOS26Theme.radiusXxl,
          padding: const EdgeInsets.fromLTRB(
            IOS26Theme.spacingLg,
            IOS26Theme.spacingLg,
            IOS26Theme.spacingLg,
            IOS26Theme.spacingMd,
          ),
          child: Column(
            children: [
              _buildWeekdayHeader(),
              const SizedBox(height: IOS26Theme.spacingSm),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: monthGrid.totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 64,
                  crossAxisSpacing: 0,
                  mainAxisSpacing: 0,
                ),
                itemBuilder: (context, index) {
                  final date = monthGrid.startCell.add(Duration(days: index));
                  final inMonth = date.month == firstOfMonth.month;
                  final minutes = _dailyMinutes[_startOfDay(date)] ?? 0;
                  final selected = _isSameDay(date, _selectedDate);
                  return _DayCell(
                    key: ValueKey(_dayCellKey(date)),
                    date: date,
                    inMonth: inMonth,
                    selected: selected,
                    minutes: minutes,
                    onTap: () {
                      final nextDate = _startOfDay(date);
                      final shouldReload = !inMonth;
                      setState(() {
                        _selectedDate = nextDate;
                        if (!inMonth) {
                          _focusedMonth = _startOfMonth(nextDate);
                        }
                      });
                      if (shouldReload) {
                        _load();
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: IOS26Theme.spacingMd),
        _buildSelectedDayCard(
          selectedEntries: selectedEntries,
          selectedTotal: selectedTotal,
          taskTitleById: taskTitleById,
        ),
        const SizedBox(height: IOS26Theme.spacingMd),
        _buildRecentDaysCard(recentDays),
      ],
    );
  }

  Widget _buildSelectedDayCard({
    required List<WorkTimeEntry> selectedEntries,
    required int selectedTotal,
    required Map<int, String> taskTitleById,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return GlassContainer(
      key: const ValueKey('work_log_calendar_selected_day_card'),
      borderRadius: IOS26Theme.radiusXl,
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.work_log_calendar_selected_day_title,
                style: IOS26Theme.titleSmall.copyWith(
                  color: IOS26Theme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                selectedTotal > 0 ? _minutesToHoursText(selectedTotal) : '0h',
                style: IOS26Theme.titleSmall.copyWith(
                  color: IOS26Theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: IOS26Theme.spacingXs),
          Text(
            _formatSelectedDayLabel(_selectedDate),
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textSecondary,
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          if (selectedEntries.isEmpty)
            Text(
              l10n.work_log_calendar_no_entries_today,
              style: IOS26Theme.bodyMedium.copyWith(
                color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
              ),
            )
          else
            ...selectedEntries.take(3).map((entry) {
              final taskTitle =
                  taskTitleById[entry.taskId] ?? '任务#${entry.taskId}';
              return Padding(
                padding: const EdgeInsets.only(bottom: IOS26Theme.spacingSm),
                child: _buildEntryRow(entry: entry, taskTitle: taskTitle),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEntryRow({
    required WorkTimeEntry entry,
    required String taskTitle,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final content = entry.content.trim().isEmpty
        ? l10n.work_log_calendar_no_content
        : entry.content;

    return GestureDetector(
      onTap: () => _openTaskDetail(context, entry.taskId, taskTitle),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.work_log_calendar_content_label}：$content',
                  style: IOS26Theme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: IOS26Theme.spacingXs),
                Text(
                  '${l10n.work_log_calendar_task_label}：$taskTitle',
                  style: IOS26Theme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: IOS26Theme.spacingMd),
          Text(
            _minutesToHoursText(entry.minutes),
            style: IOS26Theme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: IOS26Theme.primaryColor,
            ),
          ),
          const SizedBox(width: IOS26Theme.spacingXs),
          Icon(
            CupertinoIcons.chevron_right,
            size: 18,
            color: IOS26Theme.textTertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDaysCard(List<MapEntry<DateTime, int>> recentDays) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      width: double.infinity,
      child: GlassContainer(
        key: const ValueKey('work_log_calendar_recent_days_card'),
        borderRadius: IOS26Theme.radiusXl,
        padding: const EdgeInsets.all(IOS26Theme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.work_log_calendar_recent_days_title,
              style: IOS26Theme.titleSmall,
            ),
            const SizedBox(height: IOS26Theme.spacingSm),
            if (recentDays.isEmpty)
              Text(
                l10n.work_log_calendar_recent_days_empty,
                style: IOS26Theme.bodyMedium.copyWith(
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                ),
              )
            else
              ...recentDays.take(5).map((entry) {
                final day = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: IOS26Theme.spacingSm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatRecentDayTitle(day),
                          style: IOS26Theme.bodyMedium.copyWith(
                            color: IOS26Theme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _minutesToHoursText(entry.value),
                        style: IOS26Theme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView() {
    final start = _startOfWeek(_selectedDate);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final selectedDay = _startOfDay(_selectedDate);
    final selectedEntries =
        _entries.where((e) => _isSameDay(e.workDate, selectedDay)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final selectedTotal = selectedEntries.fold<int>(
      0,
      (sum, e) => sum + e.minutes,
    );
    final taskTitleById = _taskTitleMap(
      context.watch<WorkLogService>().allTasks,
    );
    final recentDays =
        _dailyMinutes.entries
            .where(
              (entry) => entry.value > 0 && !_isSameDay(entry.key, selectedDay),
            )
            .toList()
          ..sort((a, b) => b.key.compareTo(a.key));

    final weekDayRows = days
        .map((d) {
          final minutes = _dailyMinutes[_startOfDay(d)] ?? 0;
          final selected = _isSameDay(d, _selectedDate);
          return Padding(
            padding: const EdgeInsets.only(bottom: IOS26Theme.spacingSm),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = _startOfDay(d);
                });
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
                    Text(_formatWeekdayLong(d), style: IOS26Theme.titleSmall),
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
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 18,
                      color: IOS26Theme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          );
        })
        .toList(growable: false);

    return Column(
      children: [
        ...weekDayRows,
        const SizedBox(height: IOS26Theme.spacingMd),
        _buildSelectedDayCard(
          selectedEntries: selectedEntries,
          selectedTotal: selectedTotal,
          taskTitleById: taskTitleById,
        ),
        const SizedBox(height: IOS26Theme.spacingMd),
        _buildRecentDaysCard(recentDays),
      ],
    );
  }

  Widget _buildDayView() {
    final l10n = AppLocalizations.of(context)!;
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
          padding: const EdgeInsets.all(IOS26Theme.spacingLg),
          child: Row(
            children: [
              Text(
                l10n.work_log_calendar_total_label,
                style: IOS26Theme.titleSmall,
              ),
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
        const SizedBox(height: IOS26Theme.spacingMd),
        if (todaysEntries.isEmpty)
          Text(
            l10n.work_log_calendar_no_entries_today,
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
            ),
          )
        else
          ...todaysEntries.map((e) {
            final taskTitle = taskTitleById[e.taskId] ?? '任务#${e.taskId}';
            final content = e.content.trim().isEmpty
                ? l10n.work_log_calendar_no_content
                : e.content;
            return Padding(
              padding: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
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
                            Text(
                              '${l10n.work_log_calendar_content_label}：$content',
                              style: IOS26Theme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${l10n.work_log_calendar_task_label}：$taskTitle',
                              style: IOS26Theme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: IOS26Theme.spacingMd),
                      Text(
                        _minutesToHoursText(e.minutes),
                        style: IOS26Theme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: IOS26Theme.spacingXs),
                      Icon(
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
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.work_log_calendar_weekday_mon,
      l10n.work_log_calendar_weekday_tue,
      l10n.work_log_calendar_weekday_wed,
      l10n.work_log_calendar_weekday_thu,
      l10n.work_log_calendar_weekday_fri,
      l10n.work_log_calendar_weekday_sat,
      l10n.work_log_calendar_weekday_sun,
    ];

    return Row(
      children: labels
          .map(
            (text) => Expanded(
              child: Center(
                child: Text(
                  text,
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
        _selectedDate = _alignDateToMonth(_selectedDate, _focusedMonth);
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
        _selectedDate = _alignDateToMonth(_selectedDate, _focusedMonth);
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

  int _countDaysWithRecords() {
    var count = 0;
    for (final minutes in _dailyMinutes.values) {
      if (minutes > 0) {
        count += 1;
      }
    }
    return count;
  }

  String _formatSelectedDayLabel(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    return l10n.work_log_calendar_selected_day_label(
      date.month,
      date.day,
      _formatWeekdayLong(date),
    );
  }

  String _formatRecentDayTitle(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    return l10n.work_log_calendar_selected_day_label(
      date.month,
      date.day,
      _formatWeekdayLong(date),
    );
  }

  String _formatWeekdayLong(DateTime date) {
    final localeName = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('EEE', localeName).format(date);
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

  static DateTime _alignDateToMonth(DateTime dateTime, DateTime month) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final day = dateTime.day <= daysInMonth ? dateTime.day : daysInMonth;
    return DateTime(month.year, month.month, day);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dayCellKey(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'work_log_calendar_day_cell_${date.year}${two(date.month)}${two(date.day)}';
  }

  static String _minutesToHoursText(int minutes) {
    final hours = minutes / 60.0;
    if ((hours - hours.roundToDouble()).abs() < 0.001) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  static String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  static ({DateTime firstOfMonth, DateTime startCell, int totalCells})
  _buildMonthGrid(DateTime focusedMonth) {
    final firstOfMonth = _startOfMonth(focusedMonth);
    final leading = (firstOfMonth.weekday - DateTime.monday) % 7;
    final startCell = firstOfMonth.subtract(Duration(days: leading));
    final daysInMonth = DateUtils.getDaysInMonth(
      firstOfMonth.year,
      firstOfMonth.month,
    );
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    return (
      firstOfMonth: firstOfMonth,
      startCell: startCell,
      totalCells: totalCells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool inMonth;
  final bool selected;
  final int minutes;
  final VoidCallback onTap;

  const _DayCell({
    super.key,
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
    final indicatorWidget = _buildIndicator(
      minutesText: minutesText,
      isToday: isToday,
      selected: selected,
      minutesColor: minutesColor,
    );

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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                '${date.day}',
                style: IOS26Theme.titleMedium.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(height: 14, child: Center(child: indicatorWidget)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator({
    required String? minutesText,
    required bool isToday,
    required bool selected,
    required Color minutesColor,
  }) {
    if (minutesText != null) {
      return Text(
        minutesText,
        style: IOS26Theme.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: minutesColor,
          height: 1.0,
        ),
      );
    }
    if (isToday && !selected) {
      return Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: IOS26Theme.primaryColor,
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  static String _minutesToHoursText(int minutes) {
    final hours = minutes / 60.0;
    if ((hours - hours.roundToDouble()).abs() < 0.001) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }
}
