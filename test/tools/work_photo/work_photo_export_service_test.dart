import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_option.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_export_service.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_media_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('WorkPhotoExportService', () {
    late Database db;
    late Directory tempDir;
    late WorkPhotoRepository repository;
    late WorkPhotoMediaStore mediaStore;
    late WorkPhotoExportService service;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'work_photo_export_test_',
      );
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      repository = WorkPhotoRepository.withDatabase(db);
      mediaStore = WorkPhotoMediaStore(baseDirectory: tempDir);
      service = WorkPhotoExportService(
        repository: repository,
        mediaStore: mediaStore,
        now: () => DateTime(2026, 6, 1, 14, 30),
      );
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('按项目、层级、拍摄项生成 ZIP 路径并清理危险名称', () async {
      final projectId = await _seedProjectWithOneAsset(
        repository: repository,
        mediaStore: mediaStore,
        levelName: '门店',
        optionName: '../A/店',
        projectName: '项目/一',
        itemName: '门头',
        imageBytes: [1, 2, 3],
      );

      final result = await service.buildZip(projectIds: [projectId]);
      final archive = ZipDecoder().decodeBytes(result.bytes);
      final names = archive.files.map((e) => e.name).toList();

      expect(result.fileName, '外拍导出_20260601_1430.zip');
      expect(names, contains('项目_一/A_店/门头/20260601_143000_门头_001.jpg'));
      expect(names.any((name) => name.contains('..')), isFalse);
    });

    test('图片记录对应文件缺失时写入导出说明', () async {
      final now = DateTime(2026, 6, 1, 9);
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          name: '桌面',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      final projectId = await repository.createProject(
        name: '项目二',
        note: '',
        hierarchySelections: const [],
        now: now,
      );
      final item = (await repository.getProjectDetail(projectId))!.items.single;
      await repository.createAsset(
        projectId: projectId,
        projectItemId: item.id!,
        relativePath: 'photos/$projectId/missing.jpg',
        originalFilename: 'missing.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1,
        width: null,
        height: null,
        takenAt: now,
        now: now,
      );

      final result = await service.buildZip(projectIds: [projectId]);
      final archive = ZipDecoder().decodeBytes(result.bytes);
      final report = archive.findFile('导出说明.txt');

      expect(result.missingFiles.length, 1);
      expect(report, isNotNull);
      expect(
        utf8.decode(report!.content as List<int>),
        contains('以下图片记录对应的本地文件缺失'),
      );
      expect(utf8.decode(report.content as List<int>), contains('missing.jpg'));
    });
  });
}

Future<int> _seedProjectWithOneAsset({
  required WorkPhotoRepository repository,
  required WorkPhotoMediaStore mediaStore,
  required String levelName,
  required String optionName,
  required String projectName,
  required String itemName,
  required List<int> imageBytes,
}) async {
  final now = DateTime(2026, 6, 1, 9);
  final levelId = await repository.createHierarchyLevel(
    WorkPhotoHierarchyLevel.create(name: levelName, sortIndex: 0, now: now),
  );
  final optionId = await repository.createHierarchyOption(
    WorkPhotoHierarchyOption.create(
      levelId: levelId,
      parentOptionId: null,
      name: optionName,
      sortIndex: 0,
      now: now,
    ),
  );
  await repository.createCaptureItem(
    WorkPhotoCaptureItem.create(
      name: itemName,
      sortIndex: 0,
      minCount: 1,
      maxCount: null,
      now: now,
    ),
  );
  final projectId = await repository.createProject(
    name: projectName,
    note: '',
    hierarchySelections: [
      WorkPhotoHierarchySelection(levelId: levelId, optionId: optionId),
    ],
    now: now,
  );
  final item = (await repository.getProjectDetail(projectId))!.items.single;
  final source = File('${mediaStore.baseDirectory.path}/source.jpg');
  await source.writeAsBytes(imageBytes, flush: true);
  final stored = await mediaStore.savePhoto(
    projectId: projectId,
    sourceFile: source,
    now: now,
  );
  await repository.createAsset(
    projectId: projectId,
    projectItemId: item.id!,
    relativePath: stored.relativePath,
    originalFilename: 'source.jpg',
    mimeType: 'image/jpeg',
    fileSize: imageBytes.length,
    width: null,
    height: null,
    takenAt: DateTime(2026, 6, 1, 14, 30),
    now: now,
  );
  return projectId;
}
