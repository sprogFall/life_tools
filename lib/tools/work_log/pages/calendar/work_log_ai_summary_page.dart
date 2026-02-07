import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/ai/ai_service.dart';
import '../../../../core/backup/services/share_service.dart';
import '../../../../core/tags/models/tag.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../../../core/ui/app_dialogs.dart';
import '../../../../core/utils/dev_log.dart';
import '../../../../l10n/app_localizations.dart';
import '../../ai/work_log_ai_summary_prompts.dart';
import '../../models/work_task.dart';
import '../../models/work_time_entry.dart';
import '../../services/work_log_service.dart';

class WorkLogAiSummaryPage extends StatefulWidget {
  const WorkLogAiSummaryPage({super.key});

  @override
  State<WorkLogAiSummaryPage> createState() => _WorkLogAiSummaryPageState();
}

class _WorkLogAiSummaryPageState extends State<WorkLogAiSummaryPage> {
  bool _loading = true;
  bool _generating = false;

  late DateTime _startDate;
  late DateTime _endDate;

  List<WorkTask> _allTasks = const [];
  List<WorkTimeEntry> _rangeEntries = const [];
  List<Tag> _allAffiliations = const [];
  Map<int, List<Tag>> _taskAffiliationsByTaskId = const {};

  Set<int> _selectedTaskIds = <int>{};
  Set<int> _selectedAffiliationIds = <int>{};
  String _selectedStyleId = WorkLogAiSummaryPrompts.defaultStyle().id;

  String _summaryText = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month, now.day);
    _reloadRangeData();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            IOS26AppBar(
              title: l10n.work_log_ai_summary_title,
              showBackButton: true,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(IOS26Theme.spacingXl),
                      child: Column(
                        key: const ValueKey('work_log_ai_summary_page'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRangeCard(l10n),
                          const SizedBox(height: IOS26Theme.spacingLg),
                          _buildTaskCard(l10n),
                          const SizedBox(height: IOS26Theme.spacingLg),
                          _buildAffiliationCard(l10n),
                          const SizedBox(height: IOS26Theme.spacingLg),
                          _buildStyleCard(l10n),
                          const SizedBox(height: IOS26Theme.spacingLg),
                          _buildActionCard(l10n),
                          if (_summaryText.trim().isNotEmpty) ...[
                            const SizedBox(height: IOS26Theme.spacingLg),
                            _buildResultCard(l10n),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard(AppLocalizations l10n) {
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.work_log_ai_summary_range_title,
            style: IOS26Theme.titleSmall,
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildDateRow(
            label: l10n.work_log_ai_summary_start_date_label,
            value: _startDate,
            onTap: () => _pickDate(
              initial: _startDate,
              onPicked: (value) {
                final start = _startOfDay(value);
                if (start.isAfter(_endDate)) {
                  setState(() {
                    _startDate = start;
                    _endDate = start;
                  });
                } else {
                  setState(() => _startDate = start);
                }
                _reloadRangeData();
              },
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingSm),
          _buildDateRow(
            label: l10n.work_log_ai_summary_end_date_label,
            value: _endDate,
            onTap: () => _pickDate(
              initial: _endDate,
              onPicked: (value) {
                final end = _startOfDay(value);
                if (end.isBefore(_startDate)) {
                  setState(() {
                    _endDate = end;
                    _startDate = end;
                  });
                } else {
                  setState(() => _endDate = end);
                }
                _reloadRangeData();
              },
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingSm),
          Text(
            l10n.work_log_ai_summary_range_hint,
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(AppLocalizations l10n) {
    final taskMinutes = _minutesByTaskId;
    final selectableTaskIds = _selectableTaskIds;

    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.work_log_ai_summary_task_title,
                style: IOS26Theme.titleSmall,
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: IOS26Theme.minimumTapSize,
                onPressed: selectableTaskIds.isEmpty
                    ? null
                    : () => setState(
                        () => _selectedTaskIds = {...selectableTaskIds},
                      ),
                child: Text(l10n.common_all, style: IOS26Theme.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          if (_allTasks.isEmpty)
            Text(
              l10n.work_log_ai_summary_task_empty,
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: IOS26Theme.spacingSm,
              runSpacing: IOS26Theme.spacingSm,
              children: _allTasks
                  .where((task) => task.id != null)
                  .map(
                    (task) => _buildTaskChip(
                      l10n: l10n,
                      task: task,
                      minutes: taskMinutes[task.id!] ?? 0,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskChip({
    required AppLocalizations l10n,
    required WorkTask task,
    required int minutes,
  }) {
    final taskId = task.id!;
    final enabled = minutes > 0;
    final selected = _selectedTaskIds.contains(taskId);
    final label = enabled
        ? '${task.title} (${_minutesToHours(minutes)})'
        : '${task.title} · ${l10n.work_log_ai_summary_task_no_hours}';

    return CupertinoButton(
      key: ValueKey('work_log_ai_summary_task_$taskId'),
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingSm,
      ),
      minimumSize: IOS26Theme.minimumTapSize,
      color: selected
          ? IOS26Theme.primaryColor.withValues(alpha: 0.14)
          : IOS26Theme.surfaceColor.withValues(alpha: enabled ? 0.7 : 0.45),
      borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
      onPressed: !enabled
          ? null
          : () {
              setState(() {
                if (!_selectedTaskIds.add(taskId)) {
                  _selectedTaskIds.remove(taskId);
                }
                _selectedAffiliationIds = _selectedAffiliationIds
                    .where(_selectableAffiliationIds.contains)
                    .toSet();
              });
            },
      child: Text(
        label,
        style: IOS26Theme.bodySmall.copyWith(
          color: selected
              ? IOS26Theme.primaryColor
              : (enabled
                    ? IOS26Theme.textPrimary
                    : IOS26Theme.textSecondary.withValues(alpha: 0.7)),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAffiliationCard(AppLocalizations l10n) {
    final selectable = _selectableAffiliationIds;
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.work_log_ai_summary_affiliation_title,
                style: IOS26Theme.titleSmall,
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: IOS26Theme.minimumTapSize,
                onPressed: selectable.isEmpty
                    ? null
                    : () => setState(() => _selectedAffiliationIds = {}),
                child: Text(
                  l10n.work_log_ai_summary_all_affiliations,
                  style: IOS26Theme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          if (_allAffiliations.isEmpty)
            Text(
              l10n.work_log_ai_summary_affiliation_empty,
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: IOS26Theme.spacingSm,
              runSpacing: IOS26Theme.spacingSm,
              children: _allAffiliations
                  .where((tag) => tag.id != null)
                  .map((tag) => _buildAffiliationChip(tag: tag))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAffiliationChip({required Tag tag}) {
    final tagId = tag.id!;
    final selectable = _selectableAffiliationIds.contains(tagId);
    final selected = _selectedAffiliationIds.contains(tagId);
    return CupertinoButton(
      key: ValueKey('work_log_ai_summary_affiliation_$tagId'),
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingSm,
      ),
      minimumSize: IOS26Theme.minimumTapSize,
      color: selected
          ? IOS26Theme.primaryColor.withValues(alpha: 0.14)
          : IOS26Theme.surfaceColor.withValues(alpha: selectable ? 0.7 : 0.45),
      borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
      onPressed: !selectable
          ? null
          : () {
              setState(() {
                if (!_selectedAffiliationIds.add(tagId)) {
                  _selectedAffiliationIds.remove(tagId);
                }
              });
            },
      child: Text(
        tag.name,
        style: IOS26Theme.bodySmall.copyWith(
          color: selected
              ? IOS26Theme.primaryColor
              : (selectable
                    ? IOS26Theme.textPrimary
                    : IOS26Theme.textSecondary.withValues(alpha: 0.7)),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStyleCard(AppLocalizations l10n) {
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.work_log_ai_summary_style_title,
            style: IOS26Theme.titleSmall,
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          Wrap(
            spacing: IOS26Theme.spacingSm,
            runSpacing: IOS26Theme.spacingSm,
            children: WorkLogAiSummaryPrompts.styles.map((style) {
              final selected = style.id == _selectedStyleId;
              return CupertinoButton(
                key: ValueKey('work_log_ai_summary_style_${style.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: IOS26Theme.spacingMd,
                  vertical: IOS26Theme.spacingSm,
                ),
                minimumSize: IOS26Theme.minimumTapSize,
                color: selected
                    ? IOS26Theme.primaryColor.withValues(alpha: 0.14)
                    : IOS26Theme.surfaceColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
                onPressed: () => setState(() => _selectedStyleId = style.id),
                child: Text(
                  _styleNameFromL10n(l10n, style.l10nKey),
                  style: IOS26Theme.bodySmall.copyWith(
                    color: selected
                        ? IOS26Theme.primaryColor
                        : IOS26Theme.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(AppLocalizations l10n) {
    final canGenerate = _selectedTaskIds.isNotEmpty;
    final entries = _filteredEntries;
    final totalMinutes = entries.fold<int>(0, (sum, e) => sum + e.minutes);

    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.work_log_ai_summary_data_hint(entries.length, totalMinutes),
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textSecondary,
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              key: const ValueKey('work_log_ai_summary_generate_button'),
              color: IOS26Theme.primaryColor,
              borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
              onPressed: !canGenerate || _generating ? null : _generateSummary,
              child: _generating
                  ? const CupertinoActivityIndicator(
                      color: IOS26Theme.surfaceColor,
                    )
                  : Text(
                      l10n.work_log_ai_summary_generate_button,
                      style: IOS26Theme.labelLarge.copyWith(
                        color: IOS26Theme.surfaceColor,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(AppLocalizations l10n) {
    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.work_log_ai_summary_result_title,
            style: IOS26Theme.titleSmall,
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          SelectableText(
            _summaryText,
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  key: const ValueKey('work_log_ai_summary_copy_button'),
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
                  onPressed: _copySummary,
                  child: Text(
                    l10n.work_log_ai_summary_copy_button,
                    style: IOS26Theme.labelLarge.copyWith(
                      color: IOS26Theme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: IOS26Theme.spacingMd),
              Expanded(
                child: CupertinoButton(
                  key: const ValueKey('work_log_ai_summary_share_button'),
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
                  onPressed: _shareSummary,
                  child: Text(
                    l10n.work_log_ai_summary_share_button,
                    style: IOS26Theme.labelLarge.copyWith(
                      color: IOS26Theme.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingSm,
      ),
      minimumSize: IOS26Theme.minimumTapSize,
      color: IOS26Theme.surfaceColor.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
      onPressed: onTap,
      child: Row(
        children: [
          Text(label, style: IOS26Theme.bodySmall),
          const Spacer(),
          Text(_formatDateDisplay(value), style: IOS26Theme.bodyMedium),
          const SizedBox(width: IOS26Theme.spacingXs),
          const Icon(
            CupertinoIcons.chevron_down,
            size: 14,
            color: IOS26Theme.textSecondary,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) {
        var temp = initial;
        final l10n = AppLocalizations.of(context)!;
        return Container(
          height: 310,
          color: IOS26Theme.surfaceColor,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(popupContext),
                      child: Text(l10n.common_cancel),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        onPicked(temp);
                        Navigator.pop(popupContext);
                      },
                      child: Text(l10n.common_confirm),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  onDateTimeChanged: (value) => temp = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reloadRangeData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final service = context.read<WorkLogService>();
    final entries = await service.listTimeEntriesInRange(
      _startDate,
      _endDate.add(const Duration(days: 1)),
    );

    final tasks = service.allTasks.where((task) => task.id != null).toList();
    final affiliations = service.availableTags
        .where((tag) => tag.id != null)
        .toList();
    final tagById = {for (final tag in affiliations) tag.id!: tag};

    final taskAffiliationsByTaskId = <int, List<Tag>>{};
    final relevantTaskIds = entries.map((entry) => entry.taskId).toSet();
    for (final taskId in relevantTaskIds) {
      final tagIds = await service.listTagIdsForTask(taskId);
      taskAffiliationsByTaskId[taskId] = tagIds
          .where(tagById.containsKey)
          .map((id) => tagById[id]!)
          .toList();
    }

    final selectableTaskIds = entries
        .where((entry) => entry.minutes > 0)
        .map((entry) => entry.taskId)
        .toSet();

    final nextSelectedTaskIds = _selectedTaskIds.isEmpty
        ? {...selectableTaskIds}
        : _selectedTaskIds.where(selectableTaskIds.contains).toSet();

    final nextSelectableAffiliations = _collectSelectableAffiliationIds(
      selectedTaskIds: nextSelectedTaskIds,
      selectableTaskIds: selectableTaskIds,
      taskAffiliationsByTaskId: taskAffiliationsByTaskId,
    );

    if (!mounted) return;
    setState(() {
      _rangeEntries = entries;
      _allTasks = tasks;
      _allAffiliations = affiliations;
      _taskAffiliationsByTaskId = taskAffiliationsByTaskId;
      _selectedTaskIds = nextSelectedTaskIds;
      _selectedAffiliationIds = _selectedAffiliationIds
          .where(nextSelectableAffiliations.contains)
          .toSet();
      _loading = false;
    });
  }

  Future<void> _generateSummary() async {
    final l10n = AppLocalizations.of(context)!;
    final entries = _filteredEntries;
    if (entries.isEmpty) {
      await AppDialogs.showInfo(
        context,
        title: l10n.work_log_ai_summary_no_data_title,
        content: l10n.work_log_ai_summary_no_data_content,
      );
      return;
    }

    AiService aiService;
    try {
      aiService = context.read<AiService>();
    } on ProviderNotFoundException {
      await AppDialogs.showInfo(
        context,
        title: l10n.work_log_ai_summary_ai_missing_title,
        content: l10n.work_log_ai_summary_ai_missing_content,
      );
      return;
    }

    final style = WorkLogAiSummaryPrompts.resolveStyle(_selectedStyleId);
    final taskTitleById = {
      for (final task in _allTasks)
        if (task.id != null) task.id!: task.title,
    };
    final selectedTasks = _allTasks
        .where((task) => task.id != null && _selectedTaskIds.contains(task.id))
        .toList();
    final selectedAffiliationNames = _allAffiliations
        .where(
          (tag) => tag.id != null && _selectedAffiliationIds.contains(tag.id),
        )
        .map((tag) => tag.name)
        .toList();
    final taskAffiliationNames = {
      for (final entry in _taskAffiliationsByTaskId.entries)
        entry.key: entry.value.map((tag) => tag.name).toList(),
    };

    final prompt = WorkLogAiSummaryPrompts.buildPrompt(
      startDate: _startDate,
      endDate: _endDate,
      style: style,
      selectedTasks: selectedTasks,
      selectedAffiliationNames: selectedAffiliationNames,
      filteredEntries: entries,
      taskTitleById: taskTitleById,
      taskAffiliationNames: taskAffiliationNames,
    );

    setState(() => _generating = true);
    try {
      final summary = await aiService.chatText(
        prompt: prompt,
        systemPrompt: WorkLogAiSummaryPrompts.systemPrompt,
        temperature: 0.2,
        maxOutputTokens: 1600,
      );
      if (!mounted) return;
      setState(() => _summaryText = summary.trim());
    } catch (error, stackTrace) {
      devLog(
        'work_log_ai_summary_generate_failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.work_log_ai_summary_generate_failed_title,
        content: l10n.work_log_ai_summary_generate_failed_content,
      );
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _copySummary() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _summaryText.trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    await AppDialogs.showInfo(
      context,
      title: l10n.work_log_ai_summary_copy_done_title,
      content: l10n.work_log_ai_summary_copy_done_content,
    );
  }

  Future<void> _shareSummary() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _summaryText.trim();
    if (text.isEmpty) return;

    final fileName =
        'work_log_summary_${_formatDateCompact(_startDate)}_${_formatDateCompact(_endDate)}.txt';

    try {
      await ShareService.shareBackup(text, fileName);
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.work_log_ai_summary_share_done_title,
        content: l10n.work_log_ai_summary_share_done_content,
      );
    } catch (error, stackTrace) {
      devLog(
        'work_log_ai_summary_share_failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.work_log_ai_summary_share_failed_title,
        content: l10n.work_log_ai_summary_share_failed_content,
      );
    }
  }

  Map<int, int> get _minutesByTaskId {
    final map = <int, int>{};
    for (final entry in _rangeEntries) {
      map[entry.taskId] = (map[entry.taskId] ?? 0) + entry.minutes;
    }
    return map;
  }

  Set<int> get _selectableTaskIds => _minutesByTaskId.entries
      .where((entry) => entry.value > 0)
      .map((entry) => entry.key)
      .toSet();

  Set<int> get _selectableAffiliationIds => _collectSelectableAffiliationIds(
    selectedTaskIds: _selectedTaskIds,
    selectableTaskIds: _selectableTaskIds,
    taskAffiliationsByTaskId: _taskAffiliationsByTaskId,
  );

  List<WorkTimeEntry> get _filteredEntries {
    if (_selectedTaskIds.isEmpty) return const [];

    final taskFiltered = _rangeEntries
        .where((entry) => _selectedTaskIds.contains(entry.taskId))
        .toList();
    if (_selectedAffiliationIds.isEmpty) return taskFiltered;

    final allowedTaskIds = _selectedTaskIds.where((taskId) {
      final tags = _taskAffiliationsByTaskId[taskId] ?? const <Tag>[];
      for (final tag in tags) {
        final tagId = tag.id;
        if (tagId != null && _selectedAffiliationIds.contains(tagId)) {
          return true;
        }
      }
      return false;
    }).toSet();

    return taskFiltered
        .where((entry) => allowedTaskIds.contains(entry.taskId))
        .toList();
  }

  static Set<int> _collectSelectableAffiliationIds({
    required Set<int> selectedTaskIds,
    required Set<int> selectableTaskIds,
    required Map<int, List<Tag>> taskAffiliationsByTaskId,
  }) {
    final baseTaskIds = selectedTaskIds.isEmpty
        ? selectableTaskIds
        : selectedTaskIds.where(selectableTaskIds.contains).toSet();

    final result = <int>{};
    for (final taskId in baseTaskIds) {
      final tags = taskAffiliationsByTaskId[taskId] ?? const <Tag>[];
      for (final tag in tags) {
        final id = tag.id;
        if (id != null) {
          result.add(id);
        }
      }
    }
    return result;
  }

  static String _styleNameFromL10n(AppLocalizations l10n, String key) {
    return switch (key) {
      'work_log_ai_summary_style_concise' =>
        l10n.work_log_ai_summary_style_concise,
      'work_log_ai_summary_style_review' =>
        l10n.work_log_ai_summary_style_review,
      'work_log_ai_summary_style_risk' => l10n.work_log_ai_summary_style_risk,
      'work_log_ai_summary_style_highlight' =>
        l10n.work_log_ai_summary_style_highlight,
      'work_log_ai_summary_style_management' =>
        l10n.work_log_ai_summary_style_management,
      _ => l10n.work_log_ai_summary_style_concise,
    };
  }

  static DateTime _startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static String _minutesToHours(int minutes) {
    final hours = minutes / 60;
    if ((hours - hours.roundToDouble()).abs() < 0.001) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  static String _formatDateDisplay(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
  }

  static String _formatDateCompact(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}${two(dateTime.month)}${two(dateTime.day)}';
  }
}
