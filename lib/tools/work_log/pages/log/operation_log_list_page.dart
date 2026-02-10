import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/ios26_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/operation_log.dart';
import '../../services/work_log_service.dart';
import '../../work_log_constants.dart';

class OperationLogListPage extends StatefulWidget {
  const OperationLogListPage({super.key});

  @override
  State<OperationLogListPage> createState() => _OperationLogListPageState();
}

class _OperationLogListPageState extends State<OperationLogListPage> {
  bool _loading = true;
  int _retentionLimit = WorkLogConstants.defaultOperationLogRetentionLimit;
  List<OperationLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _logs = [];
    });

    final service = context.read<WorkLogService>();
    final retentionLimit = await service.getOperationLogRetentionLimit();
    final newLogs = await service.listOperationLogs(
      limit: retentionLimit,
      offset: 0,
    );

    if (!mounted) return;
    setState(() {
      _retentionLimit = retentionLimit;
      _logs = newLogs;
      _loading = false;
    });
  }

  Future<void> _openRetentionLimitSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(
          l10n.work_log_operation_logs_limit_sheet_title,
          style: IOS26Theme.titleSmall,
        ),
        message: Text(
          l10n.work_log_operation_logs_limit_sheet_message,
          style: IOS26Theme.bodySmall,
        ),
        actions: [
          for (final option
              in WorkLogConstants.operationLogRetentionLimitOptions)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(option),
              child: Text(l10n.work_log_operation_logs_limit_option(option)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.common_cancel),
        ),
      ),
    );

    if (selected == null || selected == _retentionLimit) {
      return;
    }

    if (!mounted) return;
    final service = context.read<WorkLogService>();
    await service.updateOperationLogRetentionLimit(selected);
    if (!mounted) return;
    await _loadInitial();
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
              title: l10n.work_log_operation_logs_title,
              showBackButton: true,
              actions: [
                CupertinoButton(
                  key: const ValueKey('work_log_operation_logs_limit_button'),
                  padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                  minimumSize: IOS26Theme.minimumTapSize,
                  onPressed: _openRetentionLimitSheet,
                  child: IOS26Icon(
                    CupertinoIcons.slider_horizontal_3,
                    color: IOS26Theme.primaryColor,
                    size: 22,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: IOS26Theme.spacingLg,
                vertical: IOS26Theme.spacingSm,
              ),
              child: Text(
                l10n.work_log_operation_logs_limit_hint(_retentionLimit),
                style: IOS26Theme.bodySmall.copyWith(
                  color: IOS26Theme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _logs.isEmpty
                  ? _buildEmptyState(l10n)
                  : _buildLogList(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Text(
        l10n.work_log_operation_logs_empty,
        style: IOS26Theme.bodyMedium.copyWith(
          color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildLogList(AppLocalizations l10n) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(IOS26Theme.spacingLg),
      itemCount: _logs.length,
      itemBuilder: (context, index) => _buildLogItem(_logs[index], l10n),
    );
  }

  Widget _buildLogItem(OperationLog log, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
      child: GlassContainer(
        padding: const EdgeInsets.all(IOS26Theme.spacingLg - 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildOperationIcon(log.operationType),
                const SizedBox(width: IOS26Theme.spacingMd - 2),
                Expanded(
                  child: Text(
                    log.operationType.displayName,
                    style: IOS26Theme.titleSmall,
                  ),
                ),
                Text(
                  _formatDateTime(log.createdAt, l10n),
                  style: IOS26Theme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: IOS26Theme.spacingSm),
            Text(
              log.summary,
              style: IOS26Theme.bodyMedium.copyWith(height: 1.4),
            ),
            if (log.targetTitle.isNotEmpty) ...[
              const SizedBox(height: IOS26Theme.spacingXs + 2),
              Text(
                log.targetTitle,
                style: IOS26Theme.bodySmall,
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
    return IOS26Icon(icon, color: color, size: 24);
  }

  static String _formatDateTime(DateTime dt, AppLocalizations l10n) {
    String two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDate = DateTime(dt.year, dt.month, dt.day);

    if (logDate == today) {
      return '${l10n.work_log_operation_logs_today} ${two(dt.hour)}:${two(dt.minute)}';
    } else if (logDate == today.subtract(const Duration(days: 1))) {
      return '${l10n.work_log_operation_logs_yesterday} ${two(dt.hour)}:${two(dt.minute)}';
    } else if (dt.year == now.year) {
      return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
    } else {
      return '${dt.year}/${dt.month}/${dt.day}';
    }
  }
}
