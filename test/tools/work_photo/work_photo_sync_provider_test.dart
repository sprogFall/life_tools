import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_template.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';
import 'package:life_tools/tools/work_photo/sync/work_photo_sync_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('WorkPhotoSyncProvider', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('只同步模板配置，不同步外拍项目与图片记录', () async {
      final db1 = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
        singleInstance: false,
      );
      final db2 = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
        singleInstance: false,
      );
      addTearDown(() async {
        await db1.close();
        await db2.close();
      });

      final now = DateTime(2026, 6, 1, 9);
      final repo1 = WorkPhotoRepository.withDatabase(db1);
      final templateId = await repo1.createTemplate(
        WorkPhotoTemplate.create(name: '巡拍模板', sortIndex: 0, now: now),
      );
      await repo1.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      final projectId = await repo1.createProjectFromTemplate(
        name: '项目',
        note: '',
        templateId: templateId,
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
      expect(exported['version'], 2);
      expect(exported.toString(), isNot(contains('imageBytes')));
      final data = exported['data'] as Map<String, dynamic>;
      expect(data.keys, [
        'templates',
        'hierarchy_levels',
        'hierarchy_options',
        'capture_items',
      ]);
      expect(data.toString(), isNot(contains('projects')));
      expect(data.toString(), isNot(contains('assets')));

      final repo2 = WorkPhotoRepository.withDatabase(db2);
      await WorkPhotoSyncProvider(repository: repo2).importData(exported);

      expect(await repo2.getProjectDetail(projectId), isNull);
      expect((await repo2.listTemplates()).single.name, '巡拍模板');
      expect(
        (await repo2.listCaptureItems(templateId: templateId)).single.name,
        '门头',
      );
    });

    test('导入模板配置时保留本地外拍项目与图片记录', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(db.close);

      final now = DateTime(2026, 6, 1, 9);
      final repo = WorkPhotoRepository.withDatabase(db);
      final localTemplateId = await repo.createTemplate(
        WorkPhotoTemplate.create(name: '本地模板', sortIndex: 0, now: now),
      );
      await repo.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: localTemplateId,
          name: '本地拍摄项',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      final projectId = await repo.createProjectFromTemplate(
        name: '本地项目',
        note: '',
        templateId: localTemplateId,
        hierarchySelections: const [],
        now: now,
      );
      final itemId = (await repo.getProjectDetail(projectId))!.items.single.id!;
      await repo.createAsset(
        projectId: projectId,
        projectItemId: itemId,
        relativePath: 'photos/$projectId/local.jpg',
        originalFilename: 'local.jpg',
        mimeType: 'image/jpeg',
        fileSize: 8,
        width: null,
        height: null,
        takenAt: now,
        now: now,
      );

      await WorkPhotoSyncProvider(repository: repo).importData({
        'version': 2,
        'data': {
          'templates': [
            {
              'id': 100,
              'name': '服务端模板',
              'sort_index': 0,
              'is_archived': 0,
              'created_at': now.millisecondsSinceEpoch,
              'updated_at': now.millisecondsSinceEpoch,
            },
          ],
          'hierarchy_levels': const [],
          'hierarchy_options': const [],
          'capture_items': [
            {
              'id': 101,
              'template_id': 100,
              'parent_level_id': null,
              'name': '服务端拍摄项',
              'sort_index': 0,
              'min_count': 1,
              'max_count': null,
              'is_archived': 0,
              'created_at': now.millisecondsSinceEpoch,
              'updated_at': now.millisecondsSinceEpoch,
            },
          ],
        },
      });

      expect((await repo.listTemplates()).single.name, '服务端模板');
      expect(
        (await repo.listCaptureItems(templateId: 100)).single.name,
        '服务端拍摄项',
      );

      final detail = await repo.getProjectDetail(projectId);
      expect(detail, isNotNull);
      expect(detail!.project.name, '本地项目');
      expect(detail.project.templateNameSnapshot, '本地模板');
      expect(detail.items.single.nameSnapshot, '本地拍摄项');
      expect(detail.assets.single.relativePath, 'photos/$projectId/local.jpg');
    });

    test('拒绝导入旧版同步快照', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(db.close);

      final repo = WorkPhotoRepository.withDatabase(db);
      final provider = WorkPhotoSyncProvider(repository: repo);

      await expectLater(
        provider.importData(const {'version': 1, 'data': {}}),
        throwsA(
          predicate((Object error) => error.toString().contains('不支持的数据版本: 1')),
        ),
      );
      expect(await repo.listTemplates(), isEmpty);
    });
  });
}
