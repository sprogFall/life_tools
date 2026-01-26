import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/storage/local_obj_store.dart';

void main() {
  group('LocalObjStore', () {
    test('saveBytes 应写入 .nomedia 避免相册扫描', () async {
      final tmp = await Directory.systemTemp.createTemp('life_tools_test_');
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });

      final store = LocalObjStore(baseDirProvider: () async => tmp);
      final stored = await store.saveBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'a.png',
      );

      expect(stored.key, startsWith('media/'));
      expect(Uri.parse(stored.uri).scheme, 'file');
      expect(File('${tmp.path}/${stored.key}').existsSync(), isTrue);
      expect(File('${tmp.path}/media/.nomedia').existsSync(), isTrue);
    });

    test('resolveUri 不应允许通过 ../ 读取 baseDir 之外的文件', () async {
      final root = await Directory.systemTemp.createTemp('life_tools_test_');
      addTearDown(() async {
        try {
          await root.delete(recursive: true);
        } catch (_) {}
      });

      final baseDir = Directory('${root.path}/base')..createSync();
      final outside = File('${root.path}/secret.txt')
        ..writeAsStringSync('secret', flush: true);

      final store = LocalObjStore(baseDirProvider: () async => baseDir);
      final uri = await store.resolveUri(key: '../secret.txt');

      expect(outside.existsSync(), isTrue);
      expect(uri, isNull);
    });
  });
}
