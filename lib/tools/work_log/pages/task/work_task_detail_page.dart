import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/work_task.dart';
import '../../models/work_time_entry.dart';
import '../../services/work_log_service.dart';
import '../time/work_time_entry_edit_page.dart';

class WorkTaskDetailPage extends StatefulWidget {
  final int taskId;
  final String title;

  const WorkTaskDetailPage({super.key, required this.taskId, required this.title});

  @override
  State<WorkTaskDetailPage> createState() => _WorkTaskDetailPageState();
}

class _WorkTaskDetailPageState extends State<WorkTaskDetailPage> {
  bool _loading = true;
  WorkTask? _task;
  List<WorkTimeEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = context.read<WorkLogService>();
    final task = await service.getTask(widget.taskId);
    final entries = await service.listTimeEntriesForTask(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = task;
      _entries = entries;
      _loading = false;
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
            Expanded(
              child: _loading ? _buildLoading() : _buildContent(),
            ),
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
                onPressed: _openAddTimeEntry,
                child: const Icon(
                  CupertinoIcons.clock,
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

    final totalMinutes =
        _entries.fold<int>(0, (sum, e) => sum + e.minutes);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
        if (_entries.isEmpty)
          Text(
            '暂无工时记录，点击右上角时钟添加',
            style: TextStyle(
              fontSize: 15,
              color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
            ),
          )
        else
          ..._entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.content.trim().isEmpty ? '（无内容）' : e.content,
                              style: const TextStyle(
                                fontSize: 15,
                                color: IOS26Theme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(e.workDate),
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
                        _minutesToHoursText(e.minutes),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: IOS26Theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  void _openAddTimeEntry() {
    final service = context.read<WorkLogService>();
    Navigator.of(context)
        .push<bool>(
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: service,
              child: WorkTimeEntryEditPage(taskId: widget.taskId),
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
          style: const TextStyle(
            fontSize: 14,
            color: IOS26Theme.textSecondary,
          ),
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
