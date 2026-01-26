import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  DatabaseSchema._();

  static const int version = 16;

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
    await _createOvercookedTablesV15(db);
    await _createOvercookedRatingTable(db);
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
    if (oldVersion < 10) {
      await _upgradeToVersion10(db);
    }
    if (oldVersion < 11) {
      await _upgradeToVersion11(db);
    }
    if (oldVersion < 12) {
      await _upgradeToVersion12(db);
    }
    if (oldVersion < 13) {
      await _createOvercookedTablesV14(db);
    }
    if (oldVersion < 14) {
      await _upgradeToVersion14(db);
    }
    if (oldVersion < 15) {
      await _upgradeToVersion15(db);
    }
    if (oldVersion < 16) {
      await _upgradeToVersion16(db);
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
        is_pinned INTEGER NOT NULL DEFAULT 0,
        sort_index INTEGER NOT NULL DEFAULT 0,
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

  static Future<void> _upgradeToVersion11(Database db) async {
    // v11: 为 work_tasks 增加 is_pinned / sort_index 用于列表置顶与排序
    await _createWorkLogTables(db);

    final columns = await db.rawQuery('PRAGMA table_info(work_tasks)');
    final names = columns.map((e) => e['name']).whereType<String>().toSet();

    if (!names.contains('is_pinned')) {
      await db.execute(
        'ALTER TABLE work_tasks ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('sort_index')) {
      await db.execute(
        'ALTER TABLE work_tasks ADD COLUMN sort_index INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  static Future<void> _upgradeToVersion12(Database db) async {
    // v12: 为 tool_tags 增加 category_id（工具内标签分类）
    await _createTagTables(db);

    final columns = await db.rawQuery('PRAGMA table_info(tool_tags)');
    final names = columns.map((e) => e['name']).whereType<String>().toSet();
    if (!names.contains('category_id')) {
      await db.execute(
        "ALTER TABLE tool_tags ADD COLUMN category_id TEXT NOT NULL DEFAULT 'default'",
      );
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tool_tags_tool_id_category_id ON tool_tags(tool_id, category_id)',
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
        category_id TEXT NOT NULL DEFAULT 'default',
        sort_index INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (tool_id, tag_id),
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tool_tags_tool_id ON tool_tags(tool_id)',
    );
    final toolTagColumns = await db.rawQuery('PRAGMA table_info(tool_tags)');
    final toolTagNames = toolTagColumns
        .map((e) => e['name'])
        .whereType<String>()
        .toSet();
    if (toolTagNames.contains('category_id')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tool_tags_tool_id_category_id ON tool_tags(tool_id, category_id)',
      );
    }
    if (toolTagNames.contains('sort_index')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tool_tags_tool_id_category_sort_index ON tool_tags(tool_id, category_id, sort_index)',
      );
    }

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
        restock_remind_date INTEGER,
        restock_remind_quantity REAL,
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
            restock_remind_date INTEGER,
            restock_remind_quantity REAL,
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

  static Future<void> _upgradeToVersion10(Database db) async {
    // v10: stock_items 增加补货提醒字段 restock_remind_date / restock_remind_quantity
    await _createStockpileTables(db);

    final columns = await db.rawQuery('PRAGMA table_info(stock_items)');
    final names = columns.map((e) => e['name']).whereType<String>().toSet();

    if (!names.contains('restock_remind_date')) {
      await db.execute(
        'ALTER TABLE stock_items ADD COLUMN restock_remind_date INTEGER',
      );
    }
    if (!names.contains('restock_remind_quantity')) {
      await db.execute(
        'ALTER TABLE stock_items ADD COLUMN restock_remind_quantity REAL',
      );
    }
  }

  static Future<void> _createOvercookedBaseTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        cover_image_key TEXT,
        type_tag_id INTEGER,
        intro TEXT NOT NULL DEFAULT '',
        flavors_mask INTEGER NOT NULL DEFAULT 0,
        content TEXT NOT NULL DEFAULT '',
        detail_image_keys TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (type_tag_id) REFERENCES tags(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_recipe_ingredient_tags (
        recipe_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (recipe_id, tag_id),
        FOREIGN KEY (recipe_id) REFERENCES overcooked_recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_recipe_sauce_tags (
        recipe_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (recipe_id, tag_id),
        FOREIGN KEY (recipe_id) REFERENCES overcooked_recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_wish_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day_key INTEGER NOT NULL,
        recipe_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(day_key, recipe_id),
        FOREIGN KEY (recipe_id) REFERENCES overcooked_recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_recipes_updated_at ON overcooked_recipes(updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_recipes_type_tag_id ON overcooked_recipes(type_tag_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_wish_items_day_key ON overcooked_wish_items(day_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_wish_items_recipe_id ON overcooked_wish_items(recipe_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_recipe_flavor_tags (
        recipe_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (recipe_id, tag_id),
        FOREIGN KEY (recipe_id) REFERENCES overcooked_recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_recipe_flavor_tags_recipe_id ON overcooked_recipe_flavor_tags(recipe_id)',
    );
  }

  static Future<void> _createOvercookedMealTablesV14(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_meal_days (
        day_key INTEGER PRIMARY KEY,
        note TEXT NOT NULL DEFAULT '',
        meal_slot TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_meal_items (
        day_key INTEGER NOT NULL,
        recipe_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (day_key, recipe_id),
        FOREIGN KEY (day_key) REFERENCES overcooked_meal_days(day_key) ON DELETE CASCADE,
        FOREIGN KEY (recipe_id) REFERENCES overcooked_recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_meal_items_day_key ON overcooked_meal_items(day_key)',
    );
  }

  static Future<void> _createOvercookedMealTablesV15(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day_key INTEGER NOT NULL,
        meal_tag_id INTEGER,
        note TEXT NOT NULL DEFAULT '',
        sort_index INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(day_key, meal_tag_id),
        FOREIGN KEY (meal_tag_id) REFERENCES tags(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_meal_items (
        meal_id INTEGER NOT NULL,
        recipe_id INTEGER NOT NULL,
        sort_index INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (meal_id, recipe_id),
        FOREIGN KEY (meal_id) REFERENCES overcooked_meals(id) ON DELETE CASCADE,
        FOREIGN KEY (recipe_id) REFERENCES overcooked_recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_meals_day_key ON overcooked_meals(day_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_meal_items_meal_id ON overcooked_meal_items(meal_id)',
    );
  }

  static Future<void> _createOvercookedTablesV14(DatabaseExecutor db) async {
    await _createOvercookedBaseTables(db);
    await _createOvercookedMealTablesV14(db);
  }

  static Future<void> _createOvercookedTablesV15(DatabaseExecutor db) async {
    await _createOvercookedBaseTables(db);
    await _createOvercookedMealTablesV15(db);
  }

  static Future<void> _upgradeToVersion14(Database db) async {
    // v14:
    // 1) overcooked_meal_days 增加 meal_slot（中班午餐/中班晚餐等标记）
    // 2) overcooked_recipe_flavor_tags：菜谱口味改为标签维度（兼容旧 flavors_mask）
    await _createOvercookedTablesV14(db);

    final mealDayColumns = await db.rawQuery(
      'PRAGMA table_info(overcooked_meal_days)',
    );
    final mealDayNames = mealDayColumns
        .map((e) => e['name'])
        .whereType<String>()
        .toSet();
    if (!mealDayNames.contains('meal_slot')) {
      await db.execute(
        "ALTER TABLE overcooked_meal_days ADD COLUMN meal_slot TEXT NOT NULL DEFAULT ''",
      );
    }

    // 将旧的 flavors_mask 迁移到 flavor 标签表（最多 5 个标签），避免历史数据丢失。
    final recipeColumns = await db.rawQuery(
      'PRAGMA table_info(overcooked_recipes)',
    );
    final recipeNames = recipeColumns
        .map((e) => e['name'])
        .whereType<String>()
        .toSet();
    if (!recipeNames.contains('flavors_mask')) return;

    final rows = await db.rawQuery(
      'SELECT id, flavors_mask FROM overcooked_recipes WHERE flavors_mask != 0',
    );
    if (rows.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    const toolId = 'overcooked_kitchen';
    const categoryId = 'flavor';
    const flavorBits = <({int bit, String name})>[
      (bit: 1 << 0, name: '酸'),
      (bit: 1 << 1, name: '甜'),
      (bit: 1 << 2, name: '辣'),
      (bit: 1 << 3, name: '咸'),
      (bit: 1 << 4, name: '苦'),
    ];

    final flavorTagIdByName = <String, int>{};

    Future<int> ensureFlavorTag(String name) async {
      final existing = await db.rawQuery(
        '''
SELECT t.id AS id
FROM tags t
INNER JOIN tool_tags tt ON tt.tag_id = t.id
WHERE tt.tool_id = ? AND tt.category_id = ? AND t.name = ?
LIMIT 1
''',
        [toolId, categoryId, name],
      );
      if (existing.isNotEmpty) {
        final id = existing.single['id'] as int;
        flavorTagIdByName[name] = id;
        return id;
      }

      final maxSortIndexRows = await db.rawQuery(
        'SELECT MAX(sort_index) AS max_sort_index FROM tags',
      );
      final maxSortIndex =
          (maxSortIndexRows.first['max_sort_index'] as int?) ?? -1;

      final tagId = await db.insert('tags', {
        'name': name,
        'color': null,
        'sort_index': maxSortIndex + 1,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('tool_tags', {
        'tool_id': toolId,
        'tag_id': tagId,
        'category_id': categoryId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      flavorTagIdByName[name] = tagId;
      return tagId;
    }

    for (final f in flavorBits) {
      await ensureFlavorTag(f.name);
    }

    for (final row in rows) {
      final recipeId = row['id'] as int?;
      final mask = row['flavors_mask'] as int?;
      if (recipeId == null || mask == null || mask == 0) continue;
      for (final f in flavorBits) {
        if ((mask & f.bit) == 0) continue;
        final tagId = await ensureFlavorTag(f.name);
        await db.insert(
          'overcooked_recipe_flavor_tags',
          {'recipe_id': recipeId, 'tag_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  static Future<void> _upgradeToVersion15(Database db) async {
    // v15:
    // 1) tool_tags 增加 sort_index（支持“工具/分类”内拖拽排序）
    // 2) 三餐记录改为「每个餐次一条记录」（餐次改用标签，评价跟随餐次）
    await _createTagTables(db);
    await _upgradeToolTagsSortIndex(db);

    await _createOvercookedBaseTables(db);
    await _upgradeOvercookedMealsToV15(db);
  }

  static Future<void> _upgradeToolTagsSortIndex(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(tool_tags)');
    final names = columns.map((e) => e['name']).whereType<String>().toSet();
    if (!names.contains('sort_index')) {
      await db.execute(
        "ALTER TABLE tool_tags ADD COLUMN sort_index INTEGER NOT NULL DEFAULT 0",
      );
    }

    // 将已有的 tags.sort_index 同步到 tool_tags.sort_index，保证升级后展示顺序尽量稳定。
    await db.execute('''
UPDATE tool_tags
SET sort_index = (
  SELECT t.sort_index
  FROM tags t
  WHERE t.id = tool_tags.tag_id
)
''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tool_tags_tool_id_category_sort_index ON tool_tags(tool_id, category_id, sort_index)',
    );
  }

  static Future<void> _upgradeOvercookedMealsToV15(Database db) async {
    final oldDaysColumns = await db.rawQuery(
      'PRAGMA table_info(overcooked_meal_days)',
    );
    if (oldDaysColumns.isEmpty) {
      // 极端情况：旧表不存在，直接确保新表存在即可
      await _createOvercookedMealTablesV15(db);
      return;
    }

    final itemColumns = await db.rawQuery(
      'PRAGMA table_info(overcooked_meal_items)',
    );
    final itemNames = itemColumns
        .map((e) => e['name'])
        .whereType<String>()
        .toSet();
    final isLegacyItems = itemNames.contains('day_key');

    // 新表已存在且旧 items 不是 legacy，说明已迁移过
    final mealsColumns = await db.rawQuery(
      'PRAGMA table_info(overcooked_meals)',
    );
    final hasMealsTable = mealsColumns.isNotEmpty;
    if (hasMealsTable && !isLegacyItems) return;

    await db.transaction((txn) async {
      // 先把旧表重命名出来，避免与新表同名冲突
      if (isLegacyItems) {
        await txn.execute(
          'ALTER TABLE overcooked_meal_items RENAME TO overcooked_meal_items_v14',
        );
      }
      await txn.execute(
        'ALTER TABLE overcooked_meal_days RENAME TO overcooked_meal_days_v14',
      );

      await _createOvercookedMealTablesV15(txn);

      final dayRows = await txn.query(
        'overcooked_meal_days_v14',
        orderBy: 'day_key ASC',
      );
      if (dayRows.isEmpty) {
        await txn.execute('DROP TABLE IF EXISTS overcooked_meal_items_v14');
        await txn.execute('DROP TABLE IF EXISTS overcooked_meal_days_v14');
        return;
      }

      final slots = <String>{};
      for (final row in dayRows) {
        final raw = row['meal_slot'] as String?;
        final slot = raw?.trim() ?? '';
        if (slot.isNotEmpty) slots.add(slot);
      }

      // 迁移历史 meal_slot -> 标签（tool_tags.category_id = meal_slot）
      const toolId = 'overcooked_kitchen';
      const categoryId = 'meal_slot';
      final now = DateTime.now().millisecondsSinceEpoch;

      String slotToName(String slot) {
        switch (slot) {
          case 'mid_lunch':
            return '中班午餐';
          case 'mid_dinner':
            return '中班晚餐';
          default:
            return slot;
        }
      }

      Future<int> ensureSlotTag(String slot) async {
        final name = slotToName(slot);
        final existing = await txn.query(
          'tags',
          columns: const ['id'],
          where: 'name = ?',
          whereArgs: [name],
          limit: 1,
        );
        int tagId;
        if (existing.isNotEmpty) {
          tagId = existing.single['id'] as int;
        } else {
          final maxRows = await txn.rawQuery(
            'SELECT MAX(sort_index) AS max_sort_index FROM tags',
          );
          final maxSortIndex = (maxRows.first['max_sort_index'] as int?) ?? -1;
          tagId = await txn.insert('tags', {
            'name': name,
            'color': null,
            'sort_index': maxSortIndex + 1,
            'created_at': now,
            'updated_at': now,
          });
        }

        final maxLinkRows = await txn.rawQuery(
          '''
SELECT MAX(sort_index) AS max_sort_index
FROM tool_tags
WHERE tool_id = ? AND category_id = ?
''',
          [toolId, categoryId],
        );
        final maxLinkSortIndex =
            (maxLinkRows.first['max_sort_index'] as int?) ?? -1;

        await txn.insert('tool_tags', {
          'tool_id': toolId,
          'tag_id': tagId,
          'category_id': categoryId,
          'sort_index': maxLinkSortIndex + 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        return tagId;
      }

      final slotTagIdBySlot = <String, int>{};
      for (final slot in slots) {
        slotTagIdBySlot[slot] = await ensureSlotTag(slot);
      }

      for (final day in dayRows) {
        final dayKey = day['day_key'] as int;
        final note = (day['note'] as String?) ?? '';
        final rawSlot = (day['meal_slot'] as String?) ?? '';
        final slot = rawSlot.trim();
        final mealTagId = slot.isEmpty ? null : slotTagIdBySlot[slot];

        final createdAt = (day['created_at'] as int?) ?? now;
        final updatedAt = (day['updated_at'] as int?) ?? now;

        final mealId = await txn.insert('overcooked_meals', {
          'day_key': dayKey,
          'meal_tag_id': mealTagId,
          'note': note,
          'sort_index': 0,
          'created_at': createdAt,
          'updated_at': updatedAt,
        });

        final legacyItems = await txn.query(
          'overcooked_meal_items_v14',
          where: 'day_key = ?',
          whereArgs: [dayKey],
          orderBy: 'created_at ASC, recipe_id ASC',
        );
        for (int i = 0; i < legacyItems.length; i++) {
          final row = legacyItems[i];
          await txn.insert('overcooked_meal_items', {
            'meal_id': mealId,
            'recipe_id': row['recipe_id'] as int,
            'sort_index': i,
            'created_at': (row['created_at'] as int?) ?? now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      await txn.execute('DROP TABLE IF EXISTS overcooked_meal_items_v14');
      await txn.execute('DROP TABLE IF EXISTS overcooked_meal_days_v14');
    });
  }

  static Future<void> _upgradeToVersion16(Database db) async {
    // v16: 添加菜谱打分表
    await _createOvercookedRatingTable(db);
  }

  static Future<void> _createOvercookedRatingTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS overcooked_meal_item_ratings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER NOT NULL,
        recipe_id INTEGER NOT NULL,
        rating INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(meal_id, recipe_id),
        FOREIGN KEY (meal_id) REFERENCES overcooked_meals(id) ON DELETE CASCADE,
        FOREIGN KEY (recipe_id) REFERENCES overcooked_recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_overcooked_meal_item_ratings_recipe_id ON overcooked_meal_item_ratings(recipe_id)',
    );
  }
}
