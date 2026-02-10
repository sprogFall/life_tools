import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/tags/models/tag.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/work_task.dart';
import '../../services/work_log_service.dart';
import 'work_task_detail_page.dart';

class WorkTaskListView extends StatefulWidget {
  const WorkTaskListView({super.key});

  @override
  State<WorkTaskListView> createState() => _WorkTaskListViewState();
}

class _WorkTaskListViewState extends State<WorkTaskListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      final service = context.read<WorkLogService>();
      if (!service.loadingTasks && service.hasMoreTasks) {
        service.loadMoreTasks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkLogService>(
      builder: (context, service, child) {
        final tasks = service.tasks;
        final isInitialLoading = service.loadingTasks && tasks.isEmpty;

        if (isInitialLoading) {
          return const Center(child: CupertinoActivityIndicator());
        }

        return Column(
          children: [
            _StatusFilterBar(service: service),
            if (service.availableTags.isNotEmpty)
              _TagFilterBar(service: service),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        '暂无符合条件的任务',
                        style: IOS26Theme.bodyMedium.copyWith(
                          color: IOS26Theme.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      itemCount: tasks.length + (service.hasMoreTasks ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index >= tasks.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CupertinoActivityIndicator()),
                          );
                        }
                        return _TaskCard(task: tasks[index], service: service);
                      },
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
      child: Row(
        children: [
          Text('状态', style: IOS26Theme.bodySmall),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: '待办',
                    status: WorkTaskStatus.todo,
                    count: service.getTaskCountByStatus(WorkTaskStatus.todo),
                    isSelected: currentFilters.contains(WorkTaskStatus.todo),
                    onTap: () => _toggleStatus(WorkTaskStatus.todo),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '进行中',
                    status: WorkTaskStatus.doing,
                    count: service.getTaskCountByStatus(WorkTaskStatus.doing),
                    isSelected: currentFilters.contains(WorkTaskStatus.doing),
                    onTap: () => _toggleStatus(WorkTaskStatus.doing),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '已完成',
                    status: WorkTaskStatus.done,
                    count: service.getTaskCountByStatus(WorkTaskStatus.done),
                    isSelected: currentFilters.contains(WorkTaskStatus.done),
                    onTap: () => _toggleStatus(WorkTaskStatus.done),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '已取消',
                    status: WorkTaskStatus.canceled,
                    count: service.getTaskCountByStatus(
                      WorkTaskStatus.canceled,
                    ),
                    isSelected: currentFilters.contains(
                      WorkTaskStatus.canceled,
                    ),
                    onTap: () => _toggleStatus(WorkTaskStatus.canceled),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.status,
    required this.count,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: IOS26Theme.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? _statusColor(status)
                    : IOS26Theme.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _statusColor(status).withValues(alpha: 0.2)
                      : IOS26Theme.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: IOS26Theme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? _statusColor(status)
                        : IOS26Theme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
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

class _TagFilterBar extends StatelessWidget {
  final WorkLogService service;

  const _TagFilterBar({required this.service});

  @override
  Widget build(BuildContext context) {
    final tags = service.availableTags.where((t) => t.id != null).toList();
    if (tags.isEmpty) return const SizedBox.shrink();

    final selected = service.tagFilters.toSet();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Text('归属', style: IOS26Theme.bodySmall),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < tags.length; i++) ...[
                    _TagChip(
                      label: tags[i].name,
                      isSelected: selected.contains(tags[i].id),
                      onTap: () {
                        final next = {...selected};
                        final id = tags[i].id!;
                        if (!next.add(id)) next.remove(id);
                        service.setTagFilters(next.toList());
                      },
                    ),
                    if (i < tags.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? IOS26Theme.primaryColor.withValues(alpha: 0.15)
              : IOS26Theme.surfaceColor.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? IOS26Theme.primaryColor.withValues(alpha: 0.35)
                : IOS26Theme.glassBorderColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: IOS26Theme.bodySmall.copyWith(
            color: isSelected
                ? IOS26Theme.primaryColor
                : IOS26Theme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final WorkTask task;
  final WorkLogService service;

  const _TaskCard({required this.task, required this.service});

  @override
  Widget build(BuildContext context) {
    return _buildCardContent(context);
  }

  Widget _buildCardContent(BuildContext context) {
    final taskId = task.id;
    final totalMinutes = taskId != null
        ? service.getTaskTotalMinutes(taskId)
        : 0;
    final tags = taskId != null
        ? service.getTagsForTask(taskId)
        : const <Tag>[];

    return GestureDetector(
      onTap: taskId == null
          ? null
          : () => _openDetail(context, taskId, task.title),
      onLongPress: taskId == null ? null : () => _showDeleteDialog(context),
      child: GlassContainer(
        child: Stack(
          children: [
            Padding(
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IOS26Theme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusLabel(task.status),
                          style: IOS26Theme.bodySmall.copyWith(
                            color: IOS26Theme.textSecondary.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags.take(3).map(_tagChip).toList(),
                          ),
                        ],
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
                        _formatTimeProgress(
                          totalMinutes,
                          task.estimatedMinutes,
                        ),
                        style: IOS26Theme.bodySmall.copyWith(
                          color: IOS26Theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IOS26Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: IOS26Theme.textTertiary,
                  ),
                ],
              ),
            ),
            if (task.isPinned)
              Positioned(
                left: 0,
                top: 0,
                child: _PinnedCornerMark(taskId: taskId),
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

  Future<void> _showDeleteDialog(BuildContext context) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除任务'),
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

  static Widget _tagChip(Tag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag.name,
        style: IOS26Theme.bodySmall.copyWith(
          color: IOS26Theme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PinnedCornerMark extends StatelessWidget {
  final int? taskId;

  const _PinnedCornerMark({required this.taskId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: ClipPath(
        clipper: _CornerTriangleClipper(),
        child: Container(
          key: ValueKey('task-pinned-corner-$taskId'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                IOS26Theme.toolOrange.withValues(alpha: 0.98),
                IOS26Theme.toolPink.withValues(alpha: 0.88),
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: IOS26Icon(
                CupertinoIcons.pin_fill,
                size: 11,
                color: IOS26Theme.onPrimaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
