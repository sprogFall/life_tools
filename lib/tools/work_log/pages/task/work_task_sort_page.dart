import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/work_task.dart';
import '../../services/work_log_service.dart';
import '../../services/work_task_sort_controller.dart';

class WorkTaskSortPage extends StatefulWidget {
  const WorkTaskSortPage({super.key});

  @override
  State<WorkTaskSortPage> createState() => _WorkTaskSortPageState();
}

class _WorkTaskSortPageState extends State<WorkTaskSortPage> {
  bool _loading = true;
  bool _saving = false;
  WorkTaskSortController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = context.read<WorkLogService>();
    final tasks = await service.listAllFilteredTasksForSorting();
    if (!mounted) return;
    setState(() {
      _controller = WorkTaskSortController.fromTasks(tasks);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final controller = _controller;
    if (controller == null || _saving) return;

    setState(() => _saving = true);
    try {
      final service = context.read<WorkLogService>();
      await service.saveTaskSorting(controller.buildSortOrders());
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            IOS26AppBar(
              title: '排序任务',
              showBackButton: true,
              actions: [
                CupertinoButton(
                  key: const ValueKey('work_task_sort_save_button'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CupertinoActivityIndicator(radius: 9),
                        )
                      : const Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: IOS26Theme.primaryColor,
                          ),
                        ),
                ),
              ],
            ),
            Expanded(
              child: _loading ? _buildLoading() : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CupertinoActivityIndicator());
  }

  Widget _buildContent() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    if (controller.all.isEmpty) {
      return Center(
        child: Text(
          '暂无可排序的任务',
          style: TextStyle(
            fontSize: 15,
            color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          sliver: SliverToBoxAdapter(child: _buildHintCard()),
        ),
        if (controller.pinned.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(
                title: '置顶',
                subtitle: '置顶任务仅可在本区拖拽',
                count: controller.pinned.length,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            sliver: SliverReorderableList(
              itemCount: controller.pinned.length,
              onReorder: (oldIndex, newIndex) {
                setState(() => controller.reorderPinned(oldIndex, newIndex));
              },
              itemBuilder: (context, index) {
                final task = controller.pinned[index];
                return Padding(
                  key: ValueKey('pinned-${task.id}'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaskSortRow(
                    task: task,
                    reorderIndex: index,
                    onTogglePin: () {
                      final id = task.id;
                      if (id == null) return;
                      setState(() => controller.togglePin(id));
                    },
                  ),
                );
              },
            ),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          sliver: SliverToBoxAdapter(
            child: _SectionTitle(
              title: '未置顶',
              subtitle: '未置顶任务仅可在本区拖拽',
              count: controller.unpinned.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
          sliver: SliverReorderableList(
            itemCount: controller.unpinned.length,
            onReorder: (oldIndex, newIndex) {
              setState(() => controller.reorderUnpinned(oldIndex, newIndex));
            },
            itemBuilder: (context, index) {
              final task = controller.unpinned[index];
              return Padding(
                key: ValueKey('unpinned-${task.id}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: _TaskSortRow(
                  task: task,
                  reorderIndex: index,
                  onTogglePin: () {
                    final id = task.id;
                    if (id == null) return;
                    setState(() => controller.togglePin(id));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHintCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.arrow_up_arrow_down,
            size: 18,
            color: IOS26Theme.primaryColor.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '拖拽调整顺序，点击图钉可置顶/取消置顶。\n排序仅对当前筛选结果生效。',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.95),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: IOS26Theme.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: IOS26Theme.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TaskSortRow extends StatelessWidget {
  final WorkTask task;
  final int reorderIndex;
  final VoidCallback onTogglePin;

  const _TaskSortRow({
    required this.task,
    required this.reorderIndex,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final taskId = task.id;
    final isPinned = task.isPinned;
    final pinIcon = isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin;
    final pinColor = isPinned ? IOS26Theme.toolOrange : IOS26Theme.textSecondary;

    return GlassContainer(
      key: ValueKey('work-task-sort-row-${task.id ?? task.title}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ReorderableDelayedDragStartListener(
            index: reorderIndex,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                size: 18,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: IOS26Theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(task.status),
                  style: TextStyle(
                    fontSize: 12,
                    color: IOS26Theme.textSecondary.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoButton(
            key: ValueKey('task-pin-$taskId'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(44, 44),
            onPressed: taskId == null ? null : onTogglePin,
            child: Icon(pinIcon, size: 20, color: pinColor),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(WorkTaskStatus status) {
    return switch (status) {
      WorkTaskStatus.todo => '待办',
      WorkTaskStatus.doing => '进行中',
      WorkTaskStatus.done => '已完成',
      WorkTaskStatus.canceled => '已取消',
    };
  }
}
