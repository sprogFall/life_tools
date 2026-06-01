import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';
import 'package:life_tools/tools/work_photo/sync/work_photo_sync_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('WorkPhotoSyncProvider', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('只同步元数据并可恢复外拍项目与图片记录', () async {
      final db1 = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final db2 = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(() async {
        await db1.close();
        await db2.close();
      });

      final now = DateTime(2026, 6, 1, 9);
      final repo1 = WorkPhotoRepository.withDatabase(db1);
      await repo1.createCaptureItem(
        WorkPhotoCaptureItem.create(
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      final projectId = await repo1.createProject(
        name: '项目',
        note: '',
        hierarchySelections: const [],
        now: now,
      );
      final itemId = (await repo1.getProjectDetail(
        projectId,
      ))!.items.single.id!;
      await repo1.createAsset(
        projectId: projectId,
        projectItemId: itemId,
        relativePath: 'photos/$projectId/a.jpg',
        originalFilename: 'a.jpg',
        mimeType: 'image/jpeg',
        fileSize: 8,
        width: null,
        height: null,
        takenAt: now,
        now: now,
      );

      final exported = await WorkPhotoSyncProvider(
        repository: repo1,
      ).exportData();
      expect(exported['version'], 1);
      expect(exported.toString(), isNot(contains('imageBytes')));

      final repo2 = WorkPhotoRepository.withDatabase(db2);
      await WorkPhotoSyncProvider(repository: repo2).importData(exported);

      final restored = await repo2.getProjectDetail(projectId);
      expect(restored, isNotNull);
      expect(restored!.project.name, '项目');
      expect(restored.assets.single.relativePath, 'photos/$projectId/a.jpg');
    });
  });
}
