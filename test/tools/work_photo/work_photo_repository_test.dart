import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_option.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_template.dart';
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

    test('从模板创建项目时保存层级值和拍摄项快照', () async {
      final now = DateTime(2026, 6, 1, 9);
      final templateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '门店模板', sortIndex: 0, now: now),
      );
      final levelId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(
          templateId: templateId,
          name: '区域',
          sortIndex: 0,
          now: now,
        ),
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
          templateId: templateId,
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          name: '桌面',
          sortIndex: 1,
          minCount: 2,
          maxCount: 4,
          now: now,
        ),
      );

      final otherTemplateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '无关模板', sortIndex: 1, now: now),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: otherTemplateId,
          name: '不应进入项目',
          sortIndex: 0,
          now: now,
        ),
      );

      final projectId = await repository.createProjectFromTemplate(
        name: '项目 A',
        note: '首拍',
        templateId: templateId,
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
      expect(detail.project.templateId, templateId);
      expect(detail.project.templateNameSnapshot, '门店模板');
      expect(detail.hierarchyValues.single.levelNameSnapshot, '区域');
      expect(detail.hierarchyValues.single.optionNameSnapshot, 'A 区');
      expect(detail.items.map((e) => e.nameSnapshot), ['门头', '桌面']);
      expect(detail.items.map((e) => e.minCount), [1, 2]);
      expect(detail.items.last.maxCount, 4);
    });

    test('全自定义项目不依赖模板，直接保存自定义层级和拍摄项快照', () async {
      final now = DateTime(2026, 6, 1, 9);

      final projectId = await repository.createCustomProject(
        name: '临时巡拍',
        note: '一次性',
        hierarchyValues: const [
          WorkPhotoCustomHierarchyValue(levelName: '商圈', optionName: '东区'),
          WorkPhotoCustomHierarchyValue(levelName: '点位', optionName: 'A001'),
        ],
        captureItems: const [
          WorkPhotoCustomCaptureItem(name: '门头', sortIndex: 0, minCount: 1),
          WorkPhotoCustomCaptureItem(
            name: '陈列',
            sortIndex: 1,
            minCount: 2,
            maxCount: 3,
          ),
        ],
        now: now,
      );

      final detail = await repository.getProjectDetail(projectId);
      expect(detail, isNotNull);
      expect(detail!.project.templateId, isNull);
      expect(detail.project.templateNameSnapshot, isEmpty);
      expect(detail.hierarchySummary, '东区 / A001');
      expect(detail.hierarchyValues.map((e) => e.levelNameSnapshot), [
        '商圈',
        '点位',
      ]);
      expect(detail.items.map((e) => e.nameSnapshot), ['门头', '陈列']);
      expect(detail.items.map((e) => e.sourceItemId), [null, null]);
      expect(detail.items.last.minCount, 2);
      expect(detail.items.last.maxCount, 3);
    });

    test('模板树支持层级嵌套，创建项目时拍摄项仍打平保存', () async {
      final now = DateTime(2026, 6, 1, 9);
      final templateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '树形模板', sortIndex: 0, now: now),
      );
      final storeLevelId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(
          templateId: templateId,
          parentLevelId: null,
          name: '门店',
          sortIndex: 0,
          now: now,
        ),
      );
      final entranceLevelId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(
          templateId: templateId,
          parentLevelId: storeLevelId,
          name: '入口',
          sortIndex: 0,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          parentLevelId: entranceLevelId,
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          parentLevelId: storeLevelId,
          name: '收银台',
          sortIndex: 1,
          minCount: 2,
          maxCount: 3,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          parentLevelId: null,
          name: '总览',
          sortIndex: 1,
          minCount: 1,
          now: now,
        ),
      );

      final orderedItems = await repository.listCaptureItemsInTemplateTree(
        templateId,
      );
      expect(orderedItems.map((e) => e.name), ['门头', '收银台', '总览']);

      final projectId = await repository.createProjectFromTemplate(
        name: '项目树',
        note: '',
        templateId: templateId,
        hierarchySelections: const [],
        now: now,
      );

      final detail = await repository.getProjectDetail(projectId);
      expect(detail, isNotNull);
      expect(detail!.hierarchyValues, isEmpty);
      expect(detail.items.map((e) => e.nameSnapshot), ['门头', '收银台', '总览']);
      expect(detail.items.map((e) => e.hierarchyPathSnapshot), [
        ['门店', '入口'],
        ['门店'],
        <String>[],
      ]);
      expect(detail.items.map((e) => e.minCount), [1, 2, 1]);
      expect(detail.items[1].maxCount, 3);
    });

    test('照片记录参与完成度统计，删除项目会级联删除关联记录', () async {
      final now = DateTime(2026, 6, 1, 9);
      final templateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '巡拍模板', sortIndex: 0, now: now),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          name: '人物',
          sortIndex: 1,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      final projectId = await repository.createProjectFromTemplate(
        name: '项目 B',
        note: '',
        templateId: templateId,
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
      final templateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '模板 A', sortIndex: 0, now: now),
      );
      final otherTemplateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '模板 B', sortIndex: 1, now: now),
      );
      final levelAId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(
          templateId: templateId,
          name: '区域',
          sortIndex: 0,
          now: now,
        ),
      );
      final levelBId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(
          templateId: templateId,
          name: '门店',
          sortIndex: 1,
          now: now,
        ),
      );
      await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(
          templateId: otherTemplateId,
          name: '不应混入',
          sortIndex: 0,
          now: now,
        ),
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
          templateId: templateId,
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );

      await repository.updateTemplate(
        (await repository.getTemplate(templateId))!.copyWith(
          name: '门店模板',
          updatedAt: now.add(const Duration(minutes: 1)),
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

      expect((await repository.listTemplates()).map((e) => e.name), [
        '门店模板',
        '模板 B',
      ]);
      expect(
        (await repository.listHierarchyLevels(
          templateId: templateId,
        )).map((e) => e.name),
        ['大区'],
      );
      expect(
        (await repository.listHierarchyLevels(
          templateId: templateId,
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
      expect(
        await repository.listCaptureItems(templateId: templateId),
        isEmpty,
      );
      final archivedItem = (await repository.listCaptureItems(
        templateId: templateId,
        includeArchived: true,
      )).single;
      expect(archivedItem.name, '门头照');
      expect(archivedItem.minCount, 2);
      expect(archivedItem.maxCount, 5);
    });

    test('旧版全局外拍配置升级时不再迁入默认模板', () async {
      final path = await databaseFactory.getDatabasesPath();
      final dbPath = '$path/work_photo_v20_upgrade_test.db';
      await databaseFactory.deleteDatabase(dbPath);
      addTearDown(() => databaseFactory.deleteDatabase(dbPath));

      final v20 = await openDatabase(
        dbPath,
        version: 20,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE work_photo_hierarchy_levels (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              sort_index INTEGER NOT NULL DEFAULT 0,
              is_required INTEGER NOT NULL DEFAULT 1,
              is_archived INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE work_photo_capture_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              sort_index INTEGER NOT NULL DEFAULT 0,
              min_count INTEGER NOT NULL DEFAULT 1,
              max_count INTEGER,
              is_archived INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE work_photo_projects (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              status INTEGER NOT NULL DEFAULT 0,
              note TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE work_photo_hierarchy_options (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              level_id INTEGER NOT NULL,
              parent_option_id INTEGER,
              name TEXT NOT NULL,
              sort_index INTEGER NOT NULL DEFAULT 0,
              is_archived INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE work_photo_export_profiles (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              folder_template TEXT NOT NULL DEFAULT '',
              file_template TEXT NOT NULL DEFAULT '',
              is_default INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE work_photo_project_hierarchy_values (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              project_id INTEGER NOT NULL,
              level_id INTEGER,
              option_id INTEGER,
              level_name_snapshot TEXT NOT NULL,
              option_name_snapshot TEXT NOT NULL,
              sort_index INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE work_photo_project_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              project_id INTEGER NOT NULL,
              source_item_id INTEGER,
              name_snapshot TEXT NOT NULL,
              sort_index INTEGER NOT NULL DEFAULT 0,
              min_count INTEGER NOT NULL DEFAULT 1,
              max_count INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE work_photo_assets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              project_id INTEGER NOT NULL,
              project_item_id INTEGER NOT NULL,
              relative_path TEXT NOT NULL,
              original_filename TEXT NOT NULL DEFAULT '',
              mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
              file_size INTEGER NOT NULL DEFAULT 0,
              width INTEGER,
              height INTEGER,
              taken_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      );
      final now = DateTime(2026, 6, 1, 9).millisecondsSinceEpoch;
      await v20.insert('work_photo_hierarchy_levels', {
        'id': 1,
        'name': '区域',
        'sort_index': 0,
        'is_required': 1,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });
      await v20.insert('work_photo_capture_items', {
        'id': 1,
        'name': '门头',
        'sort_index': 0,
        'min_count': 1,
        'max_count': null,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });
      await v20.close();

      final upgraded = await openDatabase(
        dbPath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(upgraded.close);

      final repo = WorkPhotoRepository.withDatabase(upgraded);
      expect(await repo.listTemplates(), isEmpty);
      expect(await repo.listHierarchyLevels(), isEmpty);
      expect(await repo.listCaptureItems(), isEmpty);
    });
  });
}
