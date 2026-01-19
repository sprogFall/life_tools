import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/stock_consumption.dart';
import '../models/stock_item.dart';

class StockpileRepository {
  final Future<Database> _database;

  StockpileRepository({DatabaseHelper? dbHelper})
    : _database = (dbHelper ?? DatabaseHelper.instance).database;

  StockpileRepository.withDatabase(Database database)
    : _database = Future.value(database);

  Future<int> createItem(StockItem item) async {
    final db = await _database;
    return db.insert('stock_items', item.toMap(includeId: false));
  }

  Future<StockItem?> getItem(int id) async {
    final db = await _database;
    final rows = await db.query(
      'stock_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StockItem.fromMap(rows.first);
  }

  Future<List<StockItem>> listItems({
    StockItemStockStatus stockStatus = StockItemStockStatus.inStock,
  }) async {
    final db = await _database;
    String? where;
    if (stockStatus == StockItemStockStatus.inStock) {
      where = 'remaining_quantity > 0';
    } else if (stockStatus == StockItemStockStatus.depleted) {
      where = 'remaining_quantity <= 0';
    }

    final rows = await db.query(
      'stock_items',
      where: where,
      orderBy: _orderByForStatus(stockStatus),
    );
    return rows.map(StockItem.fromMap).toList();
  }

  Future<void> updateItem(StockItem item) async {
    final id = item.id;
    if (id == null) {
      throw ArgumentError('updateItem 需要 item.id');
    }
    final db = await _database;
    await db.update(
      'stock_items',
      item.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(int id) async {
    final db = await _database;
    await db.delete('stock_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createConsumption(StockConsumption consumption) async {
    final db = await _database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'stock_items',
        columns: const ['id', 'remaining_quantity'],
        where: 'id = ?',
        whereArgs: [consumption.itemId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw ArgumentError('未找到物品 id=${consumption.itemId}');
      }

      final remaining = (rows.first['remaining_quantity'] as num).toDouble();
      if (consumption.quantity > remaining) {
        throw ArgumentError('消耗数量不能超过剩余库存');
      }

      final logId = await txn.insert(
        'stock_consumptions',
        consumption.toMap(includeId: false),
      );

      final newRemaining = remaining - consumption.quantity;
      await txn.update(
        'stock_items',
        {
          'remaining_quantity': newRemaining,
          'updated_at': consumption.createdAt.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [consumption.itemId],
      );

      return logId;
    });
  }

  Future<List<StockConsumption>> listConsumptionsForItem(int itemId) async {
    final db = await _database;
    final rows = await db.query(
      'stock_consumptions',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'consumed_at DESC, id DESC',
    );
    return rows.map(StockConsumption.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> exportItems() async {
    final db = await _database;
    final rows = await db.query('stock_items', orderBy: 'id ASC');
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportConsumptions() async {
    final db = await _database;
    final rows = await db.query(
      'stock_consumptions',
      orderBy: 'item_id ASC, consumed_at ASC, id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<void> importFromServer({
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> consumptions,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('stock_consumptions');
      await txn.delete('stock_items');

      for (final item in items) {
        await txn.insert('stock_items', _normalizeItemMap(item));
      }

      for (final log in consumptions) {
        final itemId = log['item_id'];
        if (itemId is! int) continue;

        await txn.rawInsert(
          '''
INSERT INTO stock_consumptions (id, item_id, consumed_at, quantity, method, note, created_at)
SELECT ?, ?, ?, ?, ?, ?, ?
WHERE EXISTS(SELECT 1 FROM stock_items WHERE id = ?)
''',
          [
            log['id'],
            itemId,
            log['consumed_at'],
            log['quantity'],
            log['method'],
            log['note'],
            log['created_at'],
            itemId,
          ],
        );
      }
    });
  }

  static String _orderByForStatus(StockItemStockStatus status) {
    if (status == StockItemStockStatus.depleted) {
      return 'updated_at DESC, id DESC';
    }
    // 在库/全部：临期优先，其次按创建时间倒序
    return 'CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END ASC, expiry_date ASC, created_at DESC';
  }

  static Map<String, Object?> _normalizeItemMap(Map<String, dynamic> raw) {
    // 兼容旧版本字段（如 category），只保留当前表结构存在的列
    const allowed = {
      'id',
      'name',
      'location',
      'total_quantity',
      'remaining_quantity',
      'unit',
      'purchase_date',
      'expiry_date',
      'remind_days',
      'restock_remind_date',
      'restock_remind_quantity',
      'note',
      'created_at',
      'updated_at',
    };
    return {
      for (final e in raw.entries)
        if (allowed.contains(e.key)) e.key: e.value,
    };
  }
}
