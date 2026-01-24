import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/utils/pending_upload_file.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PendingUploadFile', () {
    test('可将外部文件暂存到应用临时目录以便预览/稍后上传', () async {
      final temp = await Directory.systemTemp.createTemp('life_tools_test_');
      addTearDown(() async {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      });

      final src = File('${temp.path}/src.png');
      await src.writeAsBytes(Uint8List.fromList([1, 2, 3]), flush: true);

      final staged = await stageFileToPendingUploadDir(
        sourcePath: src.path,
        filename: 'cover.png',
        temporaryDirPath: temp.path,
        nowMicros: 123,
      );

      expect(File(staged.path).existsSync(), isTrue);
      expect(staged.filename, 'cover.png');
      expect(await File(staged.path).readAsBytes(), [1, 2, 3]);
      expect(staged.path.contains('life_tools_pending_uploads'), isTrue);
      expect(
        File(p.join(p.dirname(staged.path), '.nomedia')).existsSync(),
        isTrue,
      );
    });
  });
}
