import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  DatabaseSchema._();

  static const int version = 9;

  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database db, int version) async {
    await _createCoreTables(db);
    await _createMessageTables(db);
    await _createWorkLogTables(db);
    await _createTagTables(db);
    await _createOperationLogTables(db);
    await _createStockpileTables(db);
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createWorkLogTables(db);
    }
    if (oldVersion < 3) {
      await _upgradeToVersion3(db);
    }
    if (oldVersion < 4) {
      await _createTagTables(db);
    }
    if (oldVersion < 5) {
      await _upgradeToVersion5(db);
    }
    if (oldVersion < 6) {
      await _createStockpileTables(db);
    }
    if (oldVersion < 7) {
      await _upgradeToVersion7(db);
    }
    if (oldVersion < 8) {
      await _createMessageTables(db);
    }
    if (oldVersion < 9) {
      await _upgradeToVersion9(db);
    }
  }

  static Future<void> _createCoreTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tool_order (
        tool_id TEXT PRIMARY KEY,
        sort_index INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createMessageTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tool_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL,
        route TEXT,
        dedupe_key TEXT UNIQUE,
        created_at INTEGER NOT NULL,
        expires_at INTEGER,
        is_read INTEGER NOT NULL DEFAULT 0,
        read_at INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_messages_created_at ON app_messages(created_at DESC)',
    );

    // 兼容旧版本升级：旧表可能还没有 is_read 字段，此时不能创建依赖该字段的索引。
    final columns = await db.rawQuery('PRAGMA table_info(app_messages)');
    final names = columns.map((e) => e['name']).whereType<String>().toSet();
    if (names.contains('is_read')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_app_messages_is_read_created_at ON app_messages(is_read, created_at DESC)',
      );
    }
  }

  static Future<void> _upgradeToVersion9(Database db) async {
    // v9: 为 app_messages 增加 route / expires_at / is_read / read_at
    // 由于旧版本可能没有 app_messages 表（<8），这里需要先确保表存在。
    await _createMessageTables(db);

    final columns = await db.rawQuery('PRAGMA table_info(app_messages)');
    final names = columns.map((e) => e['name']).whereType<String>().toSet();

    if (!names.contains('route')) {
      await db.execute('ALTER TABLE app_messages ADD COLUMN route TEXT');
    }
    if (!names.contains('expires_at')) {
      await db.execute(
        'ALTER TABLE app_messages ADD COLUMN expires_at INTEGER',
      );
    }
    if (!names.contains('is_read')) {
      await db.execute(
        'ALTER TABLE app_messages ADD COLUMN is_read INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('read_at')) {
      await db.execute('ALTER TABLE app_messages ADD COLUMN read_at INTEGER');
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_messages_is_read_created_at ON app_messages(is_read, created_at DESC)',
    );
  }

  static Future<void> _createWorkLogTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        start_at INTEGER,
        end_at INTEGER,
        status INTEGER NOT NULL,
        estimated_minutes INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_time_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        work_date INTEGER NOT NULL,
        minutes INTEGER NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        FOREIGN KEY (task_id) REFERENCES work_tasks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_work_time_entries_task_id ON work_time_entries(task_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_work_time_entries_work_date ON work_time_entries(work_date)',
    );
  }

  static Future<void> _upgradeToVersion3(Database db) async {
    // 为 work_time_entries 添加 updated_at 列
    await db.execute(
      'ALTER TABLE work_time_entries ADD COLUMN updated_at INTEGER',
    );
    await db.execute(
      'UPDATE work_time_entries SET updated_at = created_at WHERE updated_at IS NULL',
    );

    // 创建操作日志表
    await _createOperationLogTables(db);
  }

  static Future<void> _createOperationLogTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operation_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type INTEGER NOT NULL,
        target_type INTEGER NOT NULL,
        target_id INTEGER NOT NULL,
        target_title TEXT NOT NULL DEFAULT '',
        before_snapshot TEXT,
        after_snapshot TEXT,
        summary TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_operation_logs_created_at ON operation_logs(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_operation_logs_target ON operation_logs(target_type, target_id)',
    );
  }

  static Future<void> _upgradeToVersion5(Database db) async {
    await db.execute(
      'ALTER TABLE tags ADD COLUMN sort_index INTEGER NOT NULL DEFAULT 0',
    );
  }

  static Future<void> _createTagTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER,
        sort_index INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(name)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tool_tags (
        tool_id TEXT NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (tool_id, tag_id),
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tool_tags_tool_id ON tool_tags(tool_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_task_tags (
        task_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (task_id, tag_id),
        FOREIGN KEY (task_id) REFERENCES work_tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_work_task_tags_task_id ON work_task_tags(task_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_work_task_tags_tag_id ON work_task_tags(tag_id)',
    );
  }

  static Future<void> _createStockpileTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location TEXT NOT NULL DEFAULT '',
        total_quantity REAL NOT NULL DEFAULT 1,
        remaining_quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT '',
        purchase_date INTEGER NOT NULL,
        expiry_date INTEGER,
        remind_days INTEGER NOT NULL DEFAULT 3,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_consumptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL,
        consumed_at INTEGER NOT NULL,
        quantity REAL NOT NULL,
        method TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (item_id) REFERENCES stock_items(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_item_tags (
        item_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (item_id, tag_id),
        FOREIGN KEY (item_id) REFERENCES stock_items(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_items_expiry_date ON stock_items(expiry_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_items_name ON stock_items(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_consumptions_item_id ON stock_consumptions(item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_consumptions_consumed_at ON stock_consumptions(consumed_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_item_tags_item_id ON stock_item_tags(item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_item_tags_tag_id ON stock_item_tags(tag_id)',
    );
  }

  static Future<void> _upgradeToVersion7(Database db) async {
    // 1) 新增 stock_item_tags 表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_item_tags (
        item_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (item_id, tag_id),
        FOREIGN KEY (item_id) REFERENCES stock_items(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_item_tags_item_id ON stock_item_tags(item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_item_tags_tag_id ON stock_item_tags(tag_id)',
    );

    // 2) 移除 stock_items.category（SQLite 需要重建表）
    final columns = await db.rawQuery('PRAGMA table_info(stock_items)');
    final hasCategory = columns.any((c) => c['name'] == 'category');
    if (hasCategory) {
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE stock_items RENAME TO stock_items_old');

        await txn.execute('''
          CREATE TABLE stock_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            location TEXT NOT NULL DEFAULT '',
            total_quantity REAL NOT NULL DEFAULT 1,
            remaining_quantity REAL NOT NULL DEFAULT 1,
            unit TEXT NOT NULL DEFAULT '',
            purchase_date INTEGER NOT NULL,
            expiry_date INTEGER,
            remind_days INTEGER NOT NULL DEFAULT 3,
            note TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        await txn.execute('''
          INSERT INTO stock_items (
            id, name, location, total_quantity, remaining_quantity, unit,
            purchase_date, expiry_date, remind_days, note, created_at, updated_at
          )
          SELECT
            id, name, location, total_quantity, remaining_quantity, unit,
            purchase_date, expiry_date, remind_days, note, created_at, updated_at
          FROM stock_items_old
        ''');

        await txn.execute('DROP TABLE stock_items_old');
      });
      await db.execute('PRAGMA foreign_keys = ON');
    }

    // 3) 清理旧索引并确保现有索引存在
    await db.execute('DROP INDEX IF EXISTS idx_stock_items_category');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_items_expiry_date ON stock_items(expiry_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_items_name ON stock_items(name COLLATE NOCASE)',
    );
  }
}
