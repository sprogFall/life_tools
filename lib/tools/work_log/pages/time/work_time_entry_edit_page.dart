import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/work_log_drafts.dart';
import '../../models/work_time_entry.dart';
import '../../services/work_log_service.dart';

class WorkTimeEntryEditPage extends StatefulWidget {
  final int taskId;
  final WorkTimeEntry? entry;
  final WorkTimeEntryDraft? draft;
  final String? taskTitle;

  const WorkTimeEntryEditPage({
    super.key,
    required this.taskId,
    this.entry,
    this.draft,
    this.taskTitle,
  });

  @override
  State<WorkTimeEntryEditPage> createState() => _WorkTimeEntryEditPageState();
}

class _WorkTimeEntryEditPageState extends State<WorkTimeEntryEditPage> {
  final _minutesController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime _workDate = DateTime.now();

  bool get _isEditMode => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _minutesController.text = widget.entry!.minutes.toString();
      _contentController.text = widget.entry!.content;
      _workDate = widget.entry!.workDate;
    } else if (widget.draft != null) {
      final draft = widget.draft!;
      _minutesController.text = draft.minutes.toString();
      _contentController.text = draft.content;
      _workDate = draft.workDate;
    }
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            IOS26AppBar(
              title: _isEditMode ? '编辑工时' : '记录工时',
              showBackButton: true,
              onBackPressed: () => Navigator.pop(context, false),
              actions: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () => _save(context),
                  child: Text('保存', style: IOS26Theme.labelLarge),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (widget.taskTitle != null) ...[
                      _buildTaskInfoCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildDateCard(),
                    const SizedBox(height: 16),
                    _buildFormCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfoCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('关联任务', style: IOS26Theme.bodySmall),
          const SizedBox(height: 8),
          Text(widget.taskTitle!, style: IOS26Theme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text('日期', style: IOS26Theme.titleSmall),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _pickDate,
            child: Text(_formatDate(_workDate), style: IOS26Theme.labelLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('内容与用时', style: IOS26Theme.titleSmall),
          const SizedBox(height: 12),
          _buildTextField(
            key: const ValueKey('time_entry_minutes_field'),
            controller: _minutesController,
            placeholder: '花费时间（分钟，例如 90）',
            keyboardType: TextInputType.number,
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            key: const ValueKey('time_entry_content_field'),
            controller: _contentController,
            placeholder: '工作内容',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: CupertinoTextField(
        key: key,
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        maxLines: maxLines,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: null,
      ),
    );
  }

  void _pickDate() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        var temp = DateTime(_workDate.year, _workDate.month, _workDate.day);
        return Container(
          height: 300,
          color: IOS26Theme.surfaceColor,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        setState(() => _workDate = temp);
                        Navigator.pop(context);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: temp,
                  onDateTimeChanged: (value) => temp = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(BuildContext context) async {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes <= 0) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('请填写正确的分钟数'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    final service = context.read<WorkLogService>();
    final navigator = Navigator.of(context);

    if (_isEditMode) {
      await service.updateTimeEntry(
        widget.entry!.copyWith(
          workDate: _workDate,
          minutes: minutes,
          content: _contentController.text.trim(),
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await service.createTimeEntry(
        WorkTimeEntry.create(
          taskId: widget.taskId,
          workDate: _workDate,
          minutes: minutes,
          content: _contentController.text.trim(),
        ),
      );
    }

    if (!mounted) return;
    navigator.pop(true);
  }

  static String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
