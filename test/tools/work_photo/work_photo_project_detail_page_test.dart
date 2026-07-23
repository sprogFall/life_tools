import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_template.dart';
import 'package:life_tools/tools/work_photo/pages/work_photo_project_detail_page.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_media_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkPhotoProjectDetailPage', () {
    late Directory tempDir;
    late Database db;
    late WorkPhotoRepository repository;
    late WorkPhotoMediaStore mediaStore;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'work_photo_detail_page_test_',
      );
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      repository = WorkPhotoRepository.withDatabase(db);
      mediaStore = WorkPhotoMediaStore(
        baseDirectory: tempDir,
        mediaIndexer: const _NoopMediaIndexer(),
      );
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('按项目拍摄项快照树展示，缩略图点击预览且底部显示开始拍摄', (tester) async {
      final data = (await tester.runAsync(
        () => _seedTreeProject(repository, mediaStore),
      ))!;

      await tester.pumpWidget(
        TestAppWrapper(
          child: WorkPhotoProjectDetailPage(
            projectId: data.projectId,
            repository: repository,
            mediaStore: mediaStore,
          ),
        ),
      );
      await tester.runAsync(_drainRealAsync);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('门店'), findsOneWidget);
      expect(find.text('入口'), findsOneWidget);
      expect(find.text('门头'), findsOneWidget);
      expect(find.text('收银台'), findsOneWidget);
      expect(find.text('总览'), findsOneWidget);
      expect(find.text('开始拍摄'), findsOneWidget);
      expect(find.text('继续拍摄'), findsNothing);

      await tester.tap(find.bySemanticsLabel('门头照片.jpg'));
      await tester.pump();
      await tester.runAsync(_drainRealAsync);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('删除照片？'), findsNothing);
    });

    testWidgets('长按目录会二次确认并删除该目录范围内图片', (tester) async {
      final data = (await tester.runAsync(
        () => _seedTreeProject(repository, mediaStore),
      ))!;

      await tester.pumpWidget(
        TestAppWrapper(
          child: WorkPhotoProjectDetailPage(
            projectId: data.projectId,
            repository: repository,
            mediaStore: mediaStore,
          ),
        ),
      );
      await tester.runAsync(_drainRealAsync);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.longPress(find.text('门店'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('删除照片？'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.runAsync(_drainRealAsync);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final assets = (await tester.runAsync(
        () => repository.listAssetsForProject(data.projectId),
      ))!;
      expect(assets.map((e) => e.originalFilename), ['总览照片.jpg']);
    });

    testWidgets('项目详情允许重命名并刷新项目名称', (tester) async {
      final data = (await tester.runAsync(
        () => _seedTreeProject(repository, mediaStore),
      ))!;

      await tester.pumpWidget(
        TestAppWrapper(
          child: WorkPhotoProjectDetailPage(
            projectId: data.projectId,
            repository: repository,
            mediaStore: mediaStore,
          ),
        ),
      );
      await tester.runAsync(_drainRealAsync);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('work-photo-rename-project')));
      await tester.pump();
      expect(find.byType(CupertinoTextField), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), '重命名后的项目');
      await tester.tap(find.text('保存'));
      await tester.runAsync(_drainRealAsync);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('重命名后的项目'), findsOneWidget);
      final project = await tester.runAsync(
        () => repository.getProject(data.projectId),
      );
      expect(project!.name, '重命名后的项目');
    });
  });
}

Future<void> _drainRealAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
}

Future<_SeededTreeProject> _seedTreeProject(
  WorkPhotoRepository repository,
  WorkPhotoMediaStore mediaStore,
) async {
  final now = DateTime(2026, 6, 1, 9);
  final templateId = await repository.createTemplate(
    WorkPhotoTemplate.create(name: '树形模板', sortIndex: 0, now: now),
  );
  final storeLevelId = await repository.createHierarchyLevel(
    WorkPhotoHierarchyLevel.create(
      templateId: templateId,
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
      minCount: 1,
      now: now,
    ),
  );
  await repository.createCaptureItem(
    WorkPhotoCaptureItem.create(
      templateId: templateId,
      name: '总览',
      sortIndex: 1,
      minCount: 1,
      now: now,
    ),
  );

  final projectId = await repository.createProjectFromTemplate(
    name: '项目树',
    note: '',
    templateId: templateId,
    hierarchySelections: const [],
    now: now,
  );
  final detail = (await repository.getProjectDetail(projectId))!;
  final headItem = detail.items.firstWhere((e) => e.nameSnapshot == '门头');
  final cashierItem = detail.items.firstWhere((e) => e.nameSnapshot == '收银台');
  final overviewItem = detail.items.firstWhere((e) => e.nameSnapshot == '总览');

  await _createPhotoAsset(
    repository: repository,
    mediaStore: mediaStore,
    projectId: projectId,
    itemId: headItem.id!,
    relativePath: 'photos/$projectId/head.jpg',
    originalFilename: '门头照片.jpg',
    now: now,
  );
  await _createPhotoAsset(
    repository: repository,
    mediaStore: mediaStore,
    projectId: projectId,
    itemId: cashierItem.id!,
    relativePath: 'photos/$projectId/cashier.jpg',
    originalFilename: '收银台照片.jpg',
    now: now.add(const Duration(minutes: 1)),
  );
  await _createPhotoAsset(
    repository: repository,
    mediaStore: mediaStore,
    projectId: projectId,
    itemId: overviewItem.id!,
    relativePath: 'photos/$projectId/overview.jpg',
    originalFilename: '总览照片.jpg',
    now: now.add(const Duration(minutes: 2)),
  );

  return _SeededTreeProject(projectId: projectId);
}

Future<void> _createPhotoAsset({
  required WorkPhotoRepository repository,
  required WorkPhotoMediaStore mediaStore,
  required int projectId,
  required int itemId,
  required String relativePath,
  required String originalFilename,
  required DateTime now,
}) async {
  final file = mediaStore.resolveFile(relativePath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(_onePixelPng, flush: true);
  await repository.createAsset(
    projectId: projectId,
    projectItemId: itemId,
    relativePath: relativePath,
    originalFilename: originalFilename,
    mimeType: 'image/jpeg',
    fileSize: await file.length(),
    width: 1,
    height: 1,
    takenAt: now,
    now: now,
  );
}

class _SeededTreeProject {
  final int projectId;

  const _SeededTreeProject({required this.projectId});
}

class _NoopMediaIndexer implements WorkPhotoMediaIndexer {
  const _NoopMediaIndexer();

  @override
  Future<bool> deleteFile(String path) async => false;

  @override
  Future<void> scanFile(String path) async {}

  @override
  Future<String?> saveImage({
    required String sourcePath,
    required String albumRelativePath,
    required String displayName,
  }) async {
    return null;
  }
}

const _onePixelPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
