import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_consumption.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/sync/stockpile_sync_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('StockpileSyncProvider', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('导出后可在新库中导入，并同步物品标签关联', () async {
      final sourceDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final sourceRepo = StockpileRepository.withDatabase(sourceDb);
      final sourceTags = TagRepository.withDatabase(sourceDb);

      final itemId = await sourceRepo.createItem(
        StockItem.create(
          name: '牛奶',
          location: '冰箱',
          unit: '盒',
          totalQuantity: 2,
          remainingQuantity: 2,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 5),
          remindDays: 2,
          note: '',
          now: DateTime(2026, 1, 1, 8),
        ),
      );

      await sourceRepo.createConsumption(
        StockConsumption.create(
          itemId: itemId,
          quantity: 1,
          method: '喝掉',
          consumedAt: DateTime(2026, 1, 2, 9),
          note: '',
          now: DateTime(2026, 1, 2, 9),
        ),
      );

      final tagId = await sourceTags.createTag(
        name: '冷藏',
        toolIds: const ['stockpile_assistant'],
      );
      await sourceTags.setTagsForStockItem(itemId, [tagId]);

      final provider = StockpileSyncProvider(
        repository: sourceRepo,
        tagRepository: sourceTags,
      );
      final exported = await provider.exportData();

      final targetDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final targetRepo = StockpileRepository.withDatabase(targetDb);
      final targetTags = TagRepository.withDatabase(targetDb);
      final targetProvider = StockpileSyncProvider(
        repository: targetRepo,
        tagRepository: targetTags,
      );

      // 先导入标签，再导入囤货助手数据（与真实备份/还原一致）
      await targetTags.importTagsFromServer(
        tags: await sourceTags.exportTags(),
        toolTags: await sourceTags.exportToolTags(),
      );
      await targetProvider.importData(exported);

      final items = await targetRepo.listItems(stockStatus: StockItemStockStatus.all);
      expect(items.length, 1);
      expect(items.first.id, itemId);
      expect(items.first.remainingQuantity, 1);

      final logs = await targetRepo.listConsumptionsForItem(itemId);
      expect(logs.length, 1);
      expect(logs.first.method, '喝掉');
      expect(logs.first.quantity, 1);

      final itemTags = await targetTags.listTagIdsForStockItem(itemId);
      expect(itemTags, [tagId]);

      await sourceDb.close();
      await targetDb.close();
    });
  });
}

