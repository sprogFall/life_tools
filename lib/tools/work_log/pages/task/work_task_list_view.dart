import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/work_task.dart';
import '../../services/work_log_service.dart';
import 'work_task_detail_page.dart';

class WorkTaskListView extends StatelessWidget {
  const WorkTaskListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkLogService>(
      builder: (context, service, child) {
        if (service.loadingTasks) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final tasks = service.tasks;

        return Column(
          children: [
            _StatusFilterBar(service: service),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        '暂无符合条件的任务',
                        style: TextStyle(
                          fontSize: 15,
                          color: IOS26Theme.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _TaskCard(task: tasks[index], service: service),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final WorkLogService service;

  const _StatusFilterBar({required this.service});

  @override
  Widget build(BuildContext context) {
    final currentFilters = service.statusFilters;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: '待办',
              status: WorkTaskStatus.todo,
              isSelected: currentFilters.contains(WorkTaskStatus.todo),
              onTap: () => _toggleStatus(WorkTaskStatus.todo),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '进行中',
              status: WorkTaskStatus.doing,
              isSelected: currentFilters.contains(WorkTaskStatus.doing),
              onTap: () => _toggleStatus(WorkTaskStatus.doing),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '已完成',
              status: WorkTaskStatus.done,
              isSelected: currentFilters.contains(WorkTaskStatus.done),
              onTap: () => _toggleStatus(WorkTaskStatus.done),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '已取消',
              status: WorkTaskStatus.canceled,
              isSelected: currentFilters.contains(WorkTaskStatus.canceled),
              onTap: () => _toggleStatus(WorkTaskStatus.canceled),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus(WorkTaskStatus status) {
    final current = List<WorkTaskStatus>.from(service.statusFilters);
    if (current.contains(status)) {
      current.remove(status);
      if (current.isEmpty) return;
    } else {
      current.add(status);
    }
    service.setStatusFilters(current);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final WorkTaskStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _statusColor(status).withValues(alpha: 0.15)
              : IOS26Theme.textTertiary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _statusColor(status).withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? _statusColor(status) : IOS26Theme.textSecondary,
          ),
        ),
      ),
    );
  }

  static Color _statusColor(WorkTaskStatus status) {
    return switch (status) {
      WorkTaskStatus.todo => IOS26Theme.toolOrange,
      WorkTaskStatus.doing => IOS26Theme.toolBlue,
      WorkTaskStatus.done => IOS26Theme.toolGreen,
      WorkTaskStatus.canceled => IOS26Theme.textTertiary,
    };
  }
}

class _TaskCard extends StatelessWidget {
  final WorkTask task;
  final WorkLogService service;

  const _TaskCard({required this.task, required this.service});

  @override
  Widget build(BuildContext context) {
    final taskId = task.id;
    if (taskId == null) {
      return _buildCardContent(context);
    }

    return Dismissible(
      key: ValueKey('task_$taskId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: IOS26Theme.toolRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      child: _buildCardContent(context),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final taskId = task.id;
    final totalMinutes = taskId != null
        ? service.getTaskTotalMinutes(taskId)
        : 0;

    return GestureDetector(
      onTap: taskId == null
          ? null
          : () => _openDetail(context, taskId, task.title),
      onLongPress: task.status == WorkTaskStatus.done
          ? null
          : () => _showCompleteDialog(context),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _statusColor(task.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.textPrimary,
                      letterSpacing: -0.24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusLabel(task.status),
                    style: TextStyle(
                      fontSize: 13,
                      color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            if (task.estimatedMinutes > 0 || totalMinutes > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: IOS26Theme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatTimeProgress(totalMinutes, task.estimatedMinutes),
                  style: const TextStyle(
                    fontSize: 12,
                    color: IOS26Theme.primaryColor,
                    fontWeight: FontWeight.w600,
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
    );
  }

  String _formatTimeProgress(int usedMinutes, int estimatedMinutes) {
    if (estimatedMinutes <= 0) {
      return '${_minutesToHoursText(usedMinutes)} 已用';
    }
    return '${_minutesToHoursText(usedMinutes)}/${_minutesToHoursText(estimatedMinutes)}';
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务「${task.title}」吗？\n相关的工时记录也会被删除。'),
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

    if (result == true && context.mounted) {
      final taskId = task.id;
      if (taskId != null) {
        await service.deleteTask(taskId);
      }
    }

    return result ?? false;
  }

  void _openDetail(BuildContext context, int taskId, String title) {
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

  Future<void> _showCompleteDialog(BuildContext context) async {
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

    if (result == true && context.mounted) {
      await _completeTask(context);
    }
  }

  Future<void> _completeTask(BuildContext context) async {
    final service = context.read<WorkLogService>();
    try {
      final updatedTask = task.copyWith(status: WorkTaskStatus.done);
      await service.updateTask(updatedTask);
    } catch (e) {
      if (!context.mounted) return;
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

  static String _minutesToHoursText(int minutes) {
    final hours = minutes / 60.0;
    if ((hours - hours.roundToDouble()).abs() < 0.001) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  static String _statusLabel(WorkTaskStatus status) {
    return switch (status) {
      WorkTaskStatus.todo => '待办',
      WorkTaskStatus.doing => '进行中',
      WorkTaskStatus.done => '已完成',
      WorkTaskStatus.canceled => '已取消',
    };
  }

  static Color _statusColor(WorkTaskStatus status) {
    return switch (status) {
      WorkTaskStatus.todo => IOS26Theme.toolOrange,
      WorkTaskStatus.doing => IOS26Theme.toolBlue,
      WorkTaskStatus.done => IOS26Theme.toolGreen,
      WorkTaskStatus.canceled => IOS26Theme.textTertiary,
    };
  }
}
