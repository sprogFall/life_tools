import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/sync/stockpile_sync_provider.dart';
import 'package:life_tools/tools/work_log/sync/work_log_sync_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('ToolSyncProvider 导入空列表时应能清空关联表', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('WorkLogSyncProvider：task_tags 为空也应触发导入（用于清空）', () async {
      final tagRepo = _RecordingTagRepository();
      final provider = WorkLogSyncProvider(
        repository: FakeWorkLogRepository(),
        tagRepository: tagRepo,
      );

      await provider.importData({
        'version': 1,
        'data': {
          'tasks': [],
          'time_entries': [],
          'task_tags': [],
          'operation_logs': [],
        },
      });

      expect(tagRepo.workTaskTagsImportCalls, 1);
      expect(tagRepo.lastWorkTaskLinks, isEmpty);
    });

    test('WorkLogSyncProvider：缺少 task_tags 字段时不应清空（兼容旧快照）', () async {
      final tagRepo = _RecordingTagRepository();
      final provider = WorkLogSyncProvider(
        repository: FakeWorkLogRepository(),
        tagRepository: tagRepo,
      );

      await provider.importData({
        'version': 1,
        'data': {'tasks': [], 'time_entries': [], 'operation_logs': []},
      });

      expect(tagRepo.workTaskTagsImportCalls, 0);
    });

    test('StockpileSyncProvider：item_tags 为空也应触发导入（用于清空）', () async {
      final tagRepo = _RecordingTagRepository();
      final provider = StockpileSyncProvider(
        repository: _FakeStockpileRepository(),
        tagRepository: tagRepo,
      );

      await provider.importData({
        'version': 2,
        'data': {'items': [], 'consumptions': [], 'item_tags': []},
      });

      expect(tagRepo.stockItemTagsImportCalls, 1);
      expect(tagRepo.lastStockItemLinks, isEmpty);
    });

    test('StockpileSyncProvider：缺少 item_tags 字段时不应清空（兼容旧快照）', () async {
      final tagRepo = _RecordingTagRepository();
      final provider = StockpileSyncProvider(
        repository: _FakeStockpileRepository(),
        tagRepository: tagRepo,
      );

      await provider.importData({
        'version': 2,
        'data': {'items': [], 'consumptions': []},
      });

      expect(tagRepo.stockItemTagsImportCalls, 0);
    });
  });
}

class _FakeStockpileRepository extends StockpileRepository {
  bool imported = false;

  @override
  Future<void> importFromServer({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> consumptions,
  }) async {
    imported = true;
  }
}

class _RecordingTagRepository extends TagRepository {
  int workTaskTagsImportCalls = 0;
  int stockItemTagsImportCalls = 0;

  List<Map<String, dynamic>> lastWorkTaskLinks = const [];
  List<Map<String, dynamic>> lastStockItemLinks = const [];

  @override
  Future<void> importWorkTaskTagsFromServer(
    List<Map<String, dynamic>> links,
  ) async {
    workTaskTagsImportCalls++;
    lastWorkTaskLinks = List<Map<String, dynamic>>.from(links);
  }

  @override
  Future<void> importStockItemTagsFromServer(
    List<Map<String, dynamic>> links,
  ) async {
    stockItemTagsImportCalls++;
    lastStockItemLinks = List<Map<String, dynamic>>.from(links);
  }
}
