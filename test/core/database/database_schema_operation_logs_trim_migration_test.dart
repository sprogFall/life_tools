import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('DatabaseSchema - 操作日志迁移', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('从 v17 升级时应仅保留最近10条操作日志', () async {
      final tmp = await Directory.systemTemp.createTemp('life_tools_db_test_');
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });

      final path = '${tmp.path}/life_tools_test.db';

      final oldDb = await openDatabase(
        path,
        version: 17,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: (db, version) async {
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
        },
      );

      final start = DateTime(2026, 1, 1, 8);
      for (int i = 0; i < 15; i++) {
        await oldDb.insert('operation_logs', {
          'operation_type': 0,
          'target_type': 0,
          'target_id': i + 1,
          'target_title': '任务${i + 1}',
          'before_snapshot': null,
          'after_snapshot': null,
          'summary': '测试日志 ${i + 1}',
          'created_at': start.add(Duration(minutes: i)).millisecondsSinceEpoch,
        });
      }
      await oldDb.close();

      final db = await openDatabase(
        path,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(() async => db.close());

      final rows = await db.query(
        'operation_logs',
        orderBy: 'created_at DESC, id DESC',
      );
      expect(rows.length, 10);
      expect(rows.first['target_id'], 15);
      expect(rows.last['target_id'], 6);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
