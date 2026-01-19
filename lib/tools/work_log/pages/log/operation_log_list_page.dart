import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/operation_log.dart';
import '../../services/work_log_service.dart';

class OperationLogListPage extends StatefulWidget {
  const OperationLogListPage({super.key});

  @override
  State<OperationLogListPage> createState() => _OperationLogListPageState();
}

class _OperationLogListPageState extends State<OperationLogListPage> {
  bool _loading = true;
  List<OperationLog> _logs = [];
  static const int _pageSize = 10;
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _logs = [];
      _offset = 0;
      _hasMore = true;
    });

    final service = context.read<WorkLogService>();
    final newLogs = await service.listOperationLogs(
      limit: _pageSize,
      offset: 0,
    );

    if (!mounted) return;
    setState(() {
      _logs = newLogs;
      _offset = newLogs.length;
      _hasMore = newLogs.length >= _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;

    final service = context.read<WorkLogService>();
    final newLogs = await service.listOperationLogs(
      limit: _pageSize,
      offset: _offset,
    );

    if (!mounted) return;
    setState(() {
      _logs.addAll(newLogs);
      _offset += newLogs.length;
      _hasMore = newLogs.length >= _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const IOS26AppBar(title: '操作日志', showBackButton: true),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _logs.isEmpty
                  ? _buildEmptyState()
                  : _buildLogList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        '暂无操作记录',
        style: TextStyle(
          fontSize: 15,
          color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _logs.length) {
          _loadMore();
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return _buildLogItem(_logs[index]);
      },
    );
  }

  Widget _buildLogItem(OperationLog log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildOperationIcon(log.operationType),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    log.operationType.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _formatDateTime(log.createdAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              log.summary,
              style: const TextStyle(
                fontSize: 14,
                color: IOS26Theme.textPrimary,
                height: 1.4,
              ),
            ),
            if (log.targetTitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                log.targetTitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: IOS26Theme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOperationIcon(OperationType type) {
    final (IconData icon, Color color) = switch (type) {
      OperationType.createTask => (
        CupertinoIcons.add_circled_solid,
        IOS26Theme.toolGreen,
      ),
      OperationType.updateTask => (
        CupertinoIcons.pencil_circle_fill,
        IOS26Theme.toolBlue,
      ),
      OperationType.deleteTask => (
        CupertinoIcons.minus_circle_fill,
        IOS26Theme.toolRed,
      ),
      OperationType.createTimeEntry => (
        CupertinoIcons.clock_fill,
        IOS26Theme.toolGreen,
      ),
      OperationType.updateTimeEntry => (
        CupertinoIcons.clock_fill,
        IOS26Theme.toolOrange,
      ),
      OperationType.deleteTimeEntry => (
        CupertinoIcons.clock_fill,
        IOS26Theme.toolRed,
      ),
    };
    return Icon(icon, color: color, size: 24);
  }

  static String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDate = DateTime(dt.year, dt.month, dt.day);

    if (logDate == today) {
      return '今天 ${two(dt.hour)}:${two(dt.minute)}';
    } else if (logDate == today.subtract(const Duration(days: 1))) {
      return '昨天 ${two(dt.hour)}:${two(dt.minute)}';
    } else if (dt.year == now.year) {
      return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
    } else {
      return '${dt.year}/${dt.month}/${dt.day}';
    }
  }
}
