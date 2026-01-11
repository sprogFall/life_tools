import 'package:flutter/cupertino.dart';
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
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        final tasks = service.tasks;
        if (tasks.isEmpty) {
          return Center(
            child: Text(
              '暂无任务，点击右上角 + 创建',
              style: TextStyle(
                fontSize: 15,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
          itemCount: tasks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final WorkTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final taskId = task.id;
    return GestureDetector(
      onTap: taskId == null
          ? null
          : () => _openDetail(context, taskId, task.title),
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
            if (task.estimatedMinutes > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: IOS26Theme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_minutesToHoursText(task.estimatedMinutes)} 预计',
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
