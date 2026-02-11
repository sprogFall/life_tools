import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_call_history_service.dart';
import 'package:life_tools/core/sync/services/app_config_updated_at.dart';
import 'package:life_tools/core/ai/ai_call_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiCallHistoryService', () {
    const source = AiCallSource(
      toolId: 'work_log',
      toolName: '工作记录',
      featureId: 'summary',
      featureName: '生成总结',
    );

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('默认应保留最近5条记录', () async {
      final service = AiCallHistoryService();
      await service.init();

      expect(
        service.retentionLimit,
        AiCallHistoryService.defaultRetentionLimit,
      );
      expect(service.records, isEmpty);
    });

    test('追加记录后应按新到旧排序并按保留条数裁剪', () async {
      final service = AiCallHistoryService();
      await service.init();

      for (var i = 1; i <= 7; i++) {
        await service.addRecord(
          source: source,
          model: 'gpt-test',
          prompt: 'prompt-$i',
          response: 'response-$i',
          createdAt: DateTime(2026, 1, 1, 12, i),
        );
      }

      expect(service.records.length, 5);
      expect(service.records.first.prompt, 'prompt-7');
      expect(service.records.last.prompt, 'prompt-3');
    });

    test('应支持导出并从 map 还原历史记录', () async {
      final service = AiCallHistoryService();
      await service.init();
      await service.updateRetentionLimit(10);

      await service.addRecord(
        source: source,
        model: 'gpt-test',
        prompt: 'prompt-restore',
        response: 'response-restore',
        createdAt: DateTime(2026, 1, 2, 9, 30),
      );

      final snapshot = service.exportAsMap();

      SharedPreferences.setMockInitialValues({});
      final reloaded = AiCallHistoryService();
      await reloaded.init();
      await reloaded.restoreFromMap(snapshot);

      expect(reloaded.retentionLimit, 10);
      expect(reloaded.records.length, 1);
      expect(reloaded.records.first.prompt, 'prompt-restore');
      expect(reloaded.records.first.response, 'response-restore');
    });

    test('记录变化后应更新 app_config_updated_at 时间戳', () async {
      final service = AiCallHistoryService();
      await service.init();

      final prefs = await SharedPreferences.getInstance();
      final before = AppConfigUpdatedAt.readFrom(prefs);

      await service.addRecord(
        source: source,
        model: 'gpt-test',
        prompt: 'prompt-touch',
        response: 'response-touch',
      );

      final after = AppConfigUpdatedAt.readFrom(prefs);
      expect(after, greaterThan(before));
    });
    test('更新保留条数后应立即生效并持久化', () async {
      final service = AiCallHistoryService();
      await service.init();

      await service.updateRetentionLimit(10);

      for (var i = 1; i <= 7; i++) {
        await service.addRecord(
          source: source,
          model: 'gpt-test',
          prompt: 'prompt-$i',
          response: 'response-$i',
          createdAt: DateTime(2026, 1, 1, 13, i),
        );
      }

      expect(service.retentionLimit, 10);
      expect(service.records.length, 7);

      final reloaded = AiCallHistoryService();
      await reloaded.init();
      expect(reloaded.retentionLimit, 10);
      expect(reloaded.records.length, 7);
    });
  });
}
