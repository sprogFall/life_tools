import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_option.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('WorkPhotoRepository', () {
    late Database db;
    late WorkPhotoRepository repository;

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
      repository = WorkPhotoRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('创建项目时保存层级值和拍摄项快照', () async {
      final now = DateTime(2026, 6, 1, 9);
      final levelId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(name: '区域', sortIndex: 0, now: now),
      );
      final optionId = await repository.createHierarchyOption(
        WorkPhotoHierarchyOption.create(
          levelId: levelId,
          parentOptionId: null,
          name: 'A 区',
          sortIndex: 0,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          name: '桌面',
          sortIndex: 1,
          minCount: 2,
          maxCount: 4,
          now: now,
        ),
      );

      final projectId = await repository.createProject(
        name: '项目 A',
        note: '首拍',
        hierarchySelections: [
          WorkPhotoHierarchySelection(levelId: levelId, optionId: optionId),
        ],
        now: now,
      );

      await repository.updateHierarchyLevel(
        (await repository.getHierarchyLevel(levelId))!.copyWith(
          name: '新区域',
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.updateCaptureItem(
        (await repository.getCaptureItem(1))!.copyWith(
          name: '新门头',
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      final detail = await repository.getProjectDetail(projectId);
      expect(detail, isNotNull);
      expect(detail!.project.name, '项目 A');
      expect(detail.hierarchyValues.single.levelNameSnapshot, '区域');
      expect(detail.hierarchyValues.single.optionNameSnapshot, 'A 区');
      expect(detail.items.map((e) => e.nameSnapshot), ['门头', '桌面']);
      expect(detail.items.map((e) => e.minCount), [1, 2]);
      expect(detail.items.last.maxCount, 4);
    });

    test('照片记录参与完成度统计，删除项目会级联删除关联记录', () async {
      final now = DateTime(2026, 6, 1, 9);
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          name: '人物',
          sortIndex: 1,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      final projectId = await repository.createProject(
        name: '项目 B',
        note: '',
        hierarchySelections: const [],
        now: now,
      );
      final detail = (await repository.getProjectDetail(projectId))!;

      await repository.createAsset(
        projectId: projectId,
        projectItemId: detail.items.first.id!,
        relativePath: 'photos/$projectId/a.jpg',
        originalFilename: 'a.jpg',
        mimeType: 'image/jpeg',
        fileSize: 12,
        width: 100,
        height: 80,
        takenAt: now,
        now: now,
      );

      final summaries = await repository.listProjectSummaries();
      expect(summaries.single.requiredItemCount, 2);
      expect(summaries.single.completedItemCount, 1);
      expect(summaries.single.assetCount, 1);

      await repository.deleteProject(projectId);
      expect(await db.query('work_photo_project_items'), isEmpty);
      expect(await db.query('work_photo_assets'), isEmpty);
    });

    test('配置维护支持重命名、调整顺序和归档', () async {
      final now = DateTime(2026, 6, 1, 9);
      final levelAId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(name: '区域', sortIndex: 0, now: now),
      );
      final levelBId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(name: '门店', sortIndex: 1, now: now),
      );
      final optionId = await repository.createHierarchyOption(
        WorkPhotoHierarchyOption.create(
          levelId: levelAId,
          parentOptionId: null,
          name: 'A 区',
          sortIndex: 0,
          now: now,
        ),
      );
      final itemId = await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );

      await repository.updateHierarchyLevel(
        (await repository.getHierarchyLevel(levelAId))!.copyWith(
          name: '大区',
          sortIndex: 1,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.updateHierarchyLevel(
        (await repository.getHierarchyLevel(levelBId))!.copyWith(
          sortIndex: 0,
          isArchived: true,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.updateHierarchyOption(
        (await repository.getHierarchyOption(optionId))!.copyWith(
          name: '华东',
          isArchived: true,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      await repository.updateCaptureItem(
        (await repository.getCaptureItem(itemId))!.copyWith(
          name: '门头照',
          minCount: 2,
          maxCount: 5,
          isArchived: true,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );

      expect((await repository.listHierarchyLevels()).map((e) => e.name), [
        '大区',
      ]);
      expect(
        (await repository.listHierarchyLevels(
          includeArchived: true,
        )).map((e) => '${e.name}:${e.sortIndex}:${e.isArchived}'),
        ['门店:0:true', '大区:1:false'],
      );
      expect(await repository.listHierarchyOptions(levelId: levelAId), isEmpty);
      expect(
        (await repository.listHierarchyOptions(
          levelId: levelAId,
          includeArchived: true,
        )).single.name,
        '华东',
      );
      expect(await repository.listCaptureItems(), isEmpty);
      final archivedItem = (await repository.listCaptureItems(
        includeArchived: true,
      )).single;
      expect(archivedItem.name, '门头照');
      expect(archivedItem.minCount, 2);
      expect(archivedItem.maxCount, 5);
    });
  });
}
