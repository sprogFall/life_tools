import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_schema.dart';

/// 数据库帮助类，管理SQLite数据库连接
class DatabaseHelper {
  static const String _databaseName = 'life_tools.db';
  static const int _databaseVersion = DatabaseSchema.version;

  static Database? _database;
  static Future<Database>? _opening;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final opening = _opening;
    if (opening != null) return opening;

    final future = _initDatabase();
    _opening = future;
    try {
      final db = await future;
      _database = db;
      return db;
    } catch (_) {
      // 初始化失败时允许后续重试
      if (identical(_opening, future)) {
        _opening = null;
      }
      rethrow;
    } finally {
      if (_database != null && identical(_opening, future)) {
        _opening = null;
      }
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: DatabaseSchema.onConfigure,
      onCreate: DatabaseSchema.onCreate,
      onUpgrade: DatabaseSchema.onUpgrade,
      onOpen: (db) async {
        // 兼容升级场景：某些迁移需要在 onConfigure 阶段临时关闭外键，
        // 这里统一在打开完成后确保外键约束启用。
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// 关闭数据库连接
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _opening = null;
    }
  }
}
