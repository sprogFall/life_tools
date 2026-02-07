import '../models/work_task.dart';

String buildWorkLogAiContext({
  required DateTime now,
  required Iterable<WorkTask> tasks,
  int maxTasks = 60,
}) {
  final taskLines = tasks
      .where((task) => task.id != null)
      .take(maxTasks)
      .map((task) => '- [id=${task.id}] ${task.title}')
      .join('\n');

  return [
    '当前日期：${_formatDate(now)}',
    '现有任务列表（可能为空，供你在 task_ref 里选用 id/title）：',
    taskLines.isEmpty ? '- (无)' : taskLines,
  ].join('\n');
}

String _formatDate(DateTime dateTime) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
}
