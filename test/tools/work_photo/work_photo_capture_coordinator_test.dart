import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_capture_coordinator.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_media_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('WorkPhotoCaptureCoordinator', () {
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
        'work_photo_capture_test_',
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
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('拍照成功后自动落盘并写入图片记录', () async {
      final now = DateTime(2026, 6, 1, 10);
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          name: '门头',
          sortIndex: 0,
          minCount: 1,
          maxCount: null,
          now: now,
        ),
      );
      final projectId = await repository.createProject(
        name: '项目',
        note: '',
        hierarchySelections: const [],
        now: now,
      );
      final itemId = (await repository.getProjectDetail(
        projectId,
      ))!.items.single.id!;
      final source = File('${tempDir.path}/camera.jpg');
      await source.writeAsBytes([1, 2, 3], flush: true);

      final coordinator = WorkPhotoCaptureCoordinator(
        repository: repository,
        mediaStore: mediaStore,
        cameraCapture: _FakeCameraCapture(source),
        now: () => now,
      );

      final asset = await coordinator.captureToItem(
        projectId: projectId,
        projectItemId: itemId,
      );

      expect(asset.relativePath, startsWith('photos/$projectId/'));
      expect(mediaStore.resolveFile(asset.relativePath).existsSync(), isTrue);
      final detail = await repository.getProjectDetail(projectId);
      expect(detail!.assets.single.relativePath, asset.relativePath);
    });

    test('数据库写入失败时清理已保存图片', () async {
      final source = File('${tempDir.path}/camera.jpg');
      await source.writeAsBytes([1], flush: true);
      final coordinator = WorkPhotoCaptureCoordinator(
        repository: repository,
        mediaStore: mediaStore,
        cameraCapture: _FakeCameraCapture(source),
        now: () => DateTime(2026, 6, 1, 10),
      );

      await expectLater(
        coordinator.captureToItem(projectId: 404, projectItemId: 404),
        throwsA(isA<DatabaseException>()),
      );

      final photosDir = Directory('${tempDir.path}/photos/404');
      final files = photosDir.existsSync()
          ? photosDir.listSync(recursive: true).whereType<File>().toList()
          : <File>[];
      expect(files, isEmpty);
    });
  });
}

class _FakeCameraCapture implements WorkPhotoCameraCapture {
  final File file;

  const _FakeCameraCapture(this.file);

  @override
  Future<File> takePictureFile() async => file;
}
