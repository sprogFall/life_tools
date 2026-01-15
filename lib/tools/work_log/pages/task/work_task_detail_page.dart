import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/work_task.dart';
import '../../models/work_time_entry.dart';
import '../../services/work_log_service.dart';
import '../time/work_time_entry_edit_page.dart';
import 'work_task_edit_page.dart';

class WorkTaskDetailPage extends StatefulWidget {
  final int taskId;
  final String title;

  const WorkTaskDetailPage({
    super.key,
    required this.taskId,
    required this.title,
  });

  @override
  State<WorkTaskDetailPage> createState() => _WorkTaskDetailPageState();
}

class _WorkTaskDetailPageState extends State<WorkTaskDetailPage> {
  bool _loading = true;
  WorkTask? _task;
  List<WorkTimeEntry> _entries = const [];
  int _totalMinutes = 0;

  // 工时记录分页
  static const int _pageSize = 10;
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) {
        _loadMoreEntries();
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offset = 0;
      _hasMore = true;
      _loadingMore = false;
      _entries = [];
    });

    final service = context.read<WorkLogService>();
    final task = await service.getTask(widget.taskId);
    final totalMinutes = await service.getTotalMinutesForTask(widget.taskId);

    if (!mounted) return;

    setState(() {
      _task = task;
      _totalMinutes = totalMinutes;
      _loading = false;
    });

    await _loadMoreEntries();
  }

  Future<void> _loadMoreEntries() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);

    final service = context.read<WorkLogService>();
    final newEntries = await service.listTimeEntriesForTask(
      widget.taskId,
      limit: _pageSize,
      offset: _offset,
    );

    if (!mounted) return;

    setState(() {
      _entries = [..._entries, ...newEntries];
      _offset += newEntries.length;
      _hasMore = newEntries.length >= _pageSize;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(child: _loading ? _buildLoading() : _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: IOS26Theme.glassColor,
            border: Border(
              bottom: BorderSide(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: IOS26Theme.primaryColor,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  _task?.title ?? widget.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                    color: IOS26Theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: _task != null ? _openEditTask : null,
                child: const Icon(
                  CupertinoIcons.pencil,
                  color: IOS26Theme.primaryColor,
                  size: 22,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: _showMoreOptions,
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: IOS26Theme.primaryColor,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CupertinoActivityIndicator());
  }

  Widget _buildContent() {
    final task = _task;
    if (task == null) {
      return Center(
        child: Text(
          '任务不存在或已删除',
          style: TextStyle(
            fontSize: 15,
            color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      );
    }

    final totalMinutes = _totalMinutes;
    final canAddTimeEntry = _canAddTimeEntry(task.status);

    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: IOS26Theme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '任务信息',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: '状态', value: _statusLabel(task.status)),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: '预计',
                    value: task.estimatedMinutes <= 0
                        ? '未设置'
                        : _minutesToHoursText(task.estimatedMinutes),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: '已记录',
                    value: totalMinutes <= 0
                        ? '0h'
                        : _minutesToHoursText(totalMinutes),
                  ),
                  if (task.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      task.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: IOS26Theme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '工时记录',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: IOS26Theme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (canAddTimeEntry)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _openAddTimeEntry,
                    child: const Text(
                      '添加',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: IOS26Theme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_entries.isEmpty && !_loadingMore)
              Text(
                '暂无工时记录${canAddTimeEntry ? '，点击右上角时钟添加' : ''}',
                style: TextStyle(
                  fontSize: 15,
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                ),
              )
            else ...[
              ..._entries.map((e) => _buildTimeEntryItem(e)),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
            ],
          ],
        ),
        if (canAddTimeEntry)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: IOS26Theme.primaryColor,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _openAddTimeEntry,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.clock_fill,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '记录工时',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: IOS26Theme.toolGreen,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _showCompleteTaskDialog,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '完成',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeEntryItem(WorkTimeEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('time_entry_${entry.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: IOS26Theme.toolRed,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(CupertinoIcons.delete, color: Colors.white),
        ),
        confirmDismiss: (_) => _confirmDeleteTimeEntry(entry),
        child: GestureDetector(
          onTap: () => _openEditTimeEntry(entry),
          child: GlassContainer(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.content.trim().isEmpty ? '（无内容）' : entry.content,
                        style: const TextStyle(
                          fontSize: 15,
                          color: IOS26Theme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(entry.workDate),
                        style: const TextStyle(
                          fontSize: 13,
                          color: IOS26Theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _minutesToHoursText(entry.minutes),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: IOS26Theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEditTask() {
    final service = context.read<WorkLogService>();
    Navigator.of(context)
        .push<bool>(
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: service,
              child: WorkTaskEditPage(task: _task),
            ),
          ),
        )
        .then((saved) {
          if (saved == true && mounted) {
            _load();
          }
        });
  }

  void _showMoreOptions() {
    final task = _task;
    final canAddTimeEntry = task != null && _canAddTimeEntry(task.status);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (canAddTimeEntry)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _openAddTimeEntry();
              },
              child: const Text('添加工时'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteTask();
            },
            child: const Text('删除任务'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _confirmDeleteTask() {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除任务将同时删除所有相关的工时记录，此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final service = context.read<WorkLogService>();
              await service.deleteTask(widget.taskId);
              if (mounted) Navigator.pop(context, true);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompleteTaskDialog() async {
    final task = _task;
    if (task == null) return;

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('完成任务'),
        content: Text('确认将「${task.title}」标记为已完成？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('完成'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _completeTask();
    }
  }

  Future<void> _completeTask() async {
    final task = _task;
    if (task == null) return;

    final service = context.read<WorkLogService>();
    try {
      final updatedTask = task.copyWith(status: WorkTaskStatus.done);
      await service.updateTask(updatedTask);
      await _load(); // 重新加载数据以更新UI
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('操作失败'),
          content: Text('无法完成任务：$e'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  void _openEditTimeEntry(WorkTimeEntry entry) {
    final service = context.read<WorkLogService>();
    Navigator.of(context)
        .push<bool>(
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: service,
              child: WorkTimeEntryEditPage(
                taskId: widget.taskId,
                entry: entry,
                taskTitle: _task?.title,
              ),
            ),
          ),
        )
        .then((saved) {
          if (saved == true && mounted) {
            _load();
          }
        });
  }

  Future<bool> _confirmDeleteTimeEntry(WorkTimeEntry entry) async {
    final service = context.read<WorkLogService>();
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这条 ${entry.minutes} 分钟的工时记录吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true) {
      await service.deleteTimeEntry(entry.id!);
      if (mounted) _load();
    }
    return false;
  }

  void _openAddTimeEntry() {
    final service = context.read<WorkLogService>();
    Navigator.of(context)
        .push<bool>(
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: service,
              child: WorkTimeEntryEditPage(
                taskId: widget.taskId,
                taskTitle: _task?.title,
              ),
            ),
          ),
        )
        .then((saved) {
          if (saved == true && mounted) {
            _load();
          }
        });
  }

  static String _minutesToHoursText(int minutes) {
    final hours = minutes / 60.0;
    if ((hours - hours.roundToDouble()).abs() < 0.001) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  static bool _canAddTimeEntry(WorkTaskStatus status) {
    return status != WorkTaskStatus.done && status != WorkTaskStatus.canceled;
  }

  static String _statusLabel(WorkTaskStatus status) {
    return switch (status) {
      WorkTaskStatus.todo => '待办',
      WorkTaskStatus.doing => '进行中',
      WorkTaskStatus.done => '已完成',
      WorkTaskStatus.canceled => '已取消',
    };
  }

  static String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: IOS26Theme.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: IOS26Theme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
