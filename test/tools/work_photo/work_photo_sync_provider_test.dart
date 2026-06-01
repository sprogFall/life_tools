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

      final repo2 = WorkPhotoRepository.withDatabase(db2);
      await WorkPhotoSyncProvider(repository: repo2).importData(exported);

      final restored = await repo2.getProjectDetail(projectId);
      expect(restored, isNotNull);
      expect(restored!.project.name, '项目');
      expect(restored.project.templateNameSnapshot, '巡拍模板');
      expect(restored.assets.single.relativePath, 'photos/$projectId/a.jpg');
      expect((await repo2.listTemplates()).single.name, '巡拍模板');
    });

    test('兼容导入旧版无模板快照并迁入默认模板', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(db.close);

      final now = DateTime(2026, 6, 1, 9).millisecondsSinceEpoch;
      final repo = WorkPhotoRepository.withDatabase(db);
      await WorkPhotoSyncProvider(repository: repo).importData({
        'version': 1,
        'data': {
          'hierarchy_levels': [
            {
              'id': 1,
              'name': '区域',
              'sort_index': 0,
              'is_required': 1,
              'is_archived': 0,
              'created_at': now,
              'updated_at': now,
            },
          ],
          'hierarchy_options': [
            {
              'id': 1,
              'level_id': 1,
              'parent_option_id': null,
              'name': '东区',
              'sort_index': 0,
              'is_archived': 0,
              'created_at': now,
              'updated_at': now,
            },
          ],
          'capture_items': [
            {
              'id': 1,
              'name': '门头',
              'sort_index': 0,
              'min_count': 1,
              'max_count': null,
              'is_archived': 0,
              'created_at': now,
              'updated_at': now,
            },
          ],
          'export_profiles': [],
          'projects': [],
          'project_hierarchy_values': [],
          'project_items': [],
          'assets': [],
        },
      });

      final template = (await repo.listTemplates()).single;
      expect(template.name, '默认模板');
      expect(
        (await repo.listHierarchyLevels(templateId: template.id)).single.name,
        '区域',
      );
      expect(
        (await repo.listCaptureItems(templateId: template.id)).single.name,
        '门头',
      );
    });
  });
}
