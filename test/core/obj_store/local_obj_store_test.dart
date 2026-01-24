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
  });
}
