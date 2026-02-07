import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/ai/work_log_ai_context.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';

void main() {
  group('buildWorkLogAiContext', () {
    test('应输出当前日期与任务列表，且忽略无 id 任务', () {
      final now = DateTime(2026, 2, 7, 9);
      final taskNow = DateTime(2026, 2, 1);
      final text = buildWorkLogAiContext(
        now: now,
        tasks: [
          WorkTask(
            id: 1,
            title: '任务A',
            description: '',
            startAt: null,
            endAt: null,
            status: WorkTaskStatus.todo,
            estimatedMinutes: 0,
            createdAt: taskNow,
            updatedAt: taskNow,
          ),
          WorkTask(
            id: null,
            title: '临时任务',
            description: '',
            startAt: null,
            endAt: null,
            status: WorkTaskStatus.todo,
            estimatedMinutes: 0,
            createdAt: taskNow,
            updatedAt: taskNow,
          ),
        ],
      );

      expect(text.contains('当前日期：2026-02-07'), isTrue);
      expect(text.contains('[id=1] 任务A'), isTrue);
      expect(text.contains('临时任务'), isFalse);
    });

    test('无任务时应输出 (无)', () {
      final text = buildWorkLogAiContext(
        now: DateTime(2026, 2, 7),
        tasks: const [],
      );

      expect(text.contains('- (无)'), isTrue);
    });
  });
}
