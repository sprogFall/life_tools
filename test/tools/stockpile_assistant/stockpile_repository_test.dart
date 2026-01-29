import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_consumption.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('StockpileRepository', () {
    late StockpileRepository repository;
    late TagRepository tagRepository;
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      repository = StockpileRepository.withDatabase(db);
      tagRepository = TagRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('可以创建并读取囤货物品', () async {
      final now = DateTime(2026, 1, 1, 8);
      final id = await repository.createItem(
        StockItem.create(
          name: '牛奶',
          location: '冰箱',
          unit: '盒',
          totalQuantity: 2,
          remainingQuantity: 2,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 5),
          remindDays: 2,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '早餐',
          now: now,
        ),
      );

      final item = await repository.getItem(id);
      expect(item, isNotNull);
      expect(item!.name, '牛奶');
      expect(item.remainingQuantity, 2);
      expect(item.createdAt, now);
    });

    test('可以按库存状态筛选列表（在库/已耗尽）', () async {
      final now = DateTime(2026, 1, 1, 8);
      final inStockId = await repository.createItem(
        StockItem.create(
          name: '抽纸',
          location: '客厅',
          unit: '包',
          totalQuantity: 3,
          remainingQuantity: 1,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: null,
          remindDays: 3,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
          now: now,
        ),
      );
      final depletedId = await repository.createItem(
        StockItem.create(
          name: '矿泉水',
          location: '家里',
          unit: '瓶',
          totalQuantity: 2,
          remainingQuantity: 0,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: null,
          remindDays: 3,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
          now: now,
        ),
      );

      final inStock = await repository.listItems(
        stockStatus: StockItemStockStatus.inStock,
      );
      expect(inStock.map((e) => e.id), contains(inStockId));
      expect(inStock.map((e) => e.id), isNot(contains(depletedId)));

      final depleted = await repository.listItems(
        stockStatus: StockItemStockStatus.depleted,
      );
      expect(depleted.map((e) => e.id), contains(depletedId));
      expect(depleted.map((e) => e.id), isNot(contains(inStockId)));
    });

    test('消耗记录会减少库存并可被查询', () async {
      final itemId = await repository.createItem(
        StockItem.create(
          name: '牛奶',
          location: '冰箱',
          unit: '盒',
          totalQuantity: 2,
          remainingQuantity: 2,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 5),
          remindDays: 2,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
          now: DateTime(2026, 1, 1, 8),
        ),
      );

      await repository.createConsumption(
        StockConsumption.create(
          itemId: itemId,
          quantity: 1,
          method: '喝掉',
          consumedAt: DateTime(2026, 1, 2, 9),
          note: '早餐',
          now: DateTime(2026, 1, 2, 9),
        ),
      );

      final updated = (await repository.getItem(itemId))!;
      expect(updated.remainingQuantity, 1);

      final logs = await repository.listConsumptionsForItem(itemId);
      expect(logs.length, 1);
      expect(logs.first.quantity, 1);
      expect(logs.first.method, '喝掉');
    });

    test('不允许消耗数量超过剩余库存', () async {
      final itemId = await repository.createItem(
        StockItem.create(
          name: '抽纸',
          location: '客厅',
          unit: '包',
          totalQuantity: 2,
          remainingQuantity: 1,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: null,
          remindDays: 3,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
          now: DateTime(2026, 1, 1, 8),
        ),
      );

      await expectLater(
        repository.createConsumption(
          StockConsumption.create(
            itemId: itemId,
            quantity: 2,
            method: '用完',
            consumedAt: DateTime(2026, 1, 2, 9),
            note: '',
            now: DateTime(2026, 1, 2, 9),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('物品可关联标签（物品标签）并可查询', () async {
      final itemId = await repository.createItem(
        StockItem.create(
          name: '牛奶',
          location: '冰箱',
          unit: '盒',
          totalQuantity: 1,
          remainingQuantity: 1,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: null,
          remindDays: 3,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
          now: DateTime(2026, 1, 1, 8),
        ),
      );

      final tagId = await tagRepository.createTagForToolCategory(
        name: '冷藏',
        toolId: 'stockpile_assistant',
        categoryId: 'location',
      );

      await tagRepository.setTagsForStockItem(itemId, [tagId]);
      final ids = await tagRepository.listTagIdsForStockItem(itemId);
      expect(ids, [tagId]);

      final map = await tagRepository.listTagsForStockItems([itemId]);
      expect(map[itemId]!.map((t) => t.id), [tagId]);
    });
  });
}
