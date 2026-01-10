import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  DatabaseSchema._();

  static const int version = 3;

  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database db, int version) async {
    await _createCoreTables(db);
    await _createWorkLogTables(db);
    await _createOperationLogTables(db);
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
}

