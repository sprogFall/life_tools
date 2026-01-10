import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/ios26_theme.dart';
import '../../models/work_task.dart';
import '../../services/work_log_service.dart';

class WorkTaskEditPage extends StatefulWidget {
  final WorkTask? task;

  const WorkTaskEditPage({super.key, this.task});

  @override
  State<WorkTaskEditPage> createState() => _WorkTaskEditPageState();
}

class _WorkTaskEditPageState extends State<WorkTaskEditPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedHoursController = TextEditingController();

  WorkTaskStatus _status = WorkTaskStatus.todo;
  DateTime? _startAt;
  DateTime? _endAt;

  bool get _isEditMode => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      if (widget.task!.estimatedMinutes > 0) {
        final hours = widget.task!.estimatedMinutes / 60.0;
        _estimatedHoursController.text =
            hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toString();
      }
      _status = widget.task!.status;
      _startAt = widget.task!.startAt;
      _endAt = widget.task!.endAt;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedHoursController.dispose();
    super.dispose();
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildFormCard(),
                    const SizedBox(height: 16),
                    _buildTimeCard(),
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                  ],
                ),
              ),
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
                onPressed: () => Navigator.pop(context, false),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: IOS26Theme.primaryColor,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  _isEditMode ? '编辑任务' : '创建任务',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                    color: IOS26Theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onPressed: () => _save(context),
                child: const Text(
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
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本信息',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            key: const ValueKey('task_title_field'),
            controller: _titleController,
            placeholder: '任务名（必填）',
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            key: const ValueKey('task_description_field'),
            controller: _descriptionController,
            placeholder: '任务描述',
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            key: const ValueKey('task_estimated_hours_field'),
            controller: _estimatedHoursController,
            placeholder: '预计工时（小时，例如 1.5）',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '时间范围',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _TimeRow(
            label: '开始时间',
            value: _startAt,
            onTap: () => _pickDateTime((value) => setState(() => _startAt = value),
                initial: _startAt),
            onClear: _startAt == null ? null : () => setState(() => _startAt = null),
          ),
          const SizedBox(height: 10),
          _TimeRow(
            label: '结束时间',
            value: _endAt,
            onTap:
                () => _pickDateTime((value) => setState(() => _endAt = value),
                    initial: _endAt ?? _startAt),
            onClear: _endAt == null ? null : () => setState(() => _endAt = null),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务状态',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: IOS26Theme.surfaceColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CupertinoSlidingSegmentedControl<WorkTaskStatus>(
              groupValue: _status,
              thumbColor: IOS26Theme.surfaceColor,
              children: const {
                WorkTaskStatus.todo: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text('待办'),
                ),
                WorkTaskStatus.doing: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text('进行中'),
                ),
                WorkTaskStatus.done: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text('完成'),
                ),
                WorkTaskStatus.canceled: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text('取消'),
                ),
              },
              onValueChanged: (value) {
                if (value == null) return;
                setState(() => _status = value);
              },
            ),
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

  void _pickDateTime(
    ValueChanged<DateTime> onPicked, {
    DateTime? initial,
  }) {
    final initialValue = initial ?? DateTime.now();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        var temp = initialValue;
        return Container(
          height: 320,
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
                        onPicked(temp);
                        Navigator.pop(context);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: initialValue,
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
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('请填写任务名'),
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

    final estimatedHours = double.tryParse(_estimatedHoursController.text.trim());
    final estimatedMinutes = estimatedHours == null
        ? 0
        : (estimatedHours * 60).round().clamp(0, 1000000);

    if (_startAt != null && _endAt != null && _endAt!.isBefore(_startAt!)) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('结束时间不能早于开始时间'),
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
      await service.updateTask(
        widget.task!.copyWith(
          title: title,
          description: _descriptionController.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          clearStartAt: _startAt == null && widget.task!.startAt != null,
          clearEndAt: _endAt == null && widget.task!.endAt != null,
          status: _status,
          estimatedMinutes: estimatedMinutes,
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await service.createTask(
        WorkTask.create(
          title: title,
          description: _descriptionController.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          status: _status,
          estimatedMinutes: estimatedMinutes,
        ),
      );
    }

    if (!mounted) return;
    navigator.pop(true);
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: IOS26Theme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              value == null ? '未设置' : _format(value!),
              style: const TextStyle(
                fontSize: 15,
                color: IOS26Theme.textSecondary,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 18,
                  color: IOS26Theme.textTertiary,
                ),
              ),
            ] else ...[
              const SizedBox(width: 10),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: IOS26Theme.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _format(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }
}
