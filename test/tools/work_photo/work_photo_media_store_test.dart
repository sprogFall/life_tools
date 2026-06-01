import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_media_store.dart';

void main() {
  group('WorkPhotoMediaStore', () {
    late Directory tempDir;
    late WorkPhotoMediaStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('work_photo_media_test_');
      store = WorkPhotoMediaStore(baseDirectory: tempDir);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('保存图片到工具目录并返回安全相对路径', () async {
      final source = File('${tempDir.path}/危险..source?.jpg');
      await source.writeAsBytes([1, 2, 3, 4], flush: true);

      final stored = await store.savePhoto(
        projectId: 7,
        sourceFile: source,
        now: DateTime(2026, 6, 1, 10, 30),
      );

      expect(stored.relativePath.startsWith('photos/7/'), isTrue);
      expect(stored.relativePath.endsWith('.jpg'), isTrue);
      expect(stored.relativePath.contains('..'), isFalse);
      expect(stored.relativePath.split('/').length, 3);
      expect(await store.resolveFile(stored.relativePath).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
    });

    test('解析相对路径时禁止越过工具根目录', () {
      expect(() => store.resolveFile('../secret.jpg'), throwsArgumentError);
      expect(
        () => store.resolveFile('photos/1/../../secret.jpg'),
        throwsArgumentError,
      );
      expect(() => store.resolveFile('/tmp/secret.jpg'), throwsArgumentError);
    });

    test('数据库写入失败后可清理已写入图片', () async {
      final source = File('${tempDir.path}/source.jpg');
      await source.writeAsBytes([9], flush: true);
      final stored = await store.savePhoto(
        projectId: 2,
        sourceFile: source,
        now: DateTime(2026, 6, 1, 10),
      );

      final file = store.resolveFile(stored.relativePath);
      expect(file.existsSync(), isTrue);

      await store.deleteStoredFile(stored.relativePath);
      expect(file.existsSync(), isFalse);
    });
  });
}
