import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/backup/services/share_temp_cleanup.dart';

void main() {
  group('ShareTempCleanup', () {
    test('应清理过期文件并保留最新文件', () async {
      final root = await Directory.systemTemp.createTemp('share_cleanup_test_');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final now = DateTime.now();
      final oldFile = File('${root.path}/life_tools_backup_old.txt')
        ..writeAsStringSync('old');
      final latestFile = File('${root.path}/life_tools_backup_latest.txt')
        ..writeAsStringSync('latest');
      final midFile = File('${root.path}/life_tools_backup_mid.txt')
        ..writeAsStringSync('mid');

      await oldFile.setLastModified(now.subtract(const Duration(days: 3)));
      await midFile.setLastModified(now.subtract(const Duration(hours: 3)));
      await latestFile.setLastModified(now.subtract(const Duration(hours: 1)));

      final deleted = await cleanupShareTempFiles(
        directory: root,
        filePrefix: 'life_tools_backup_',
        keepLatest: 1,
        maxAge: const Duration(days: 1),
        now: now,
      );

      expect(deleted, 2);
      expect(await oldFile.exists(), isFalse);
      expect(await midFile.exists(), isFalse);
      expect(await latestFile.exists(), isTrue);
    });

    test('应仅处理匹配前缀的 txt 文件', () async {
      final root = await Directory.systemTemp.createTemp('share_cleanup_test_');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final now = DateTime.now();
      final target = File('${root.path}/life_tools_share_keep.txt')
        ..writeAsStringSync('1');
      final ignoredPrefix = File('${root.path}/another_share.txt')
        ..writeAsStringSync('2');
      final ignoredExt = File('${root.path}/life_tools_share_keep.json')
        ..writeAsStringSync('3');

      await target.setLastModified(now.subtract(const Duration(days: 5)));
      await ignoredPrefix.setLastModified(
        now.subtract(const Duration(days: 5)),
      );
      await ignoredExt.setLastModified(now.subtract(const Duration(days: 5)));

      await cleanupShareTempFiles(
        directory: root,
        filePrefix: 'life_tools_share_',
        keepLatest: 0,
        maxAge: const Duration(days: 1),
        now: now,
      );

      expect(await target.exists(), isFalse);
      expect(await ignoredPrefix.exists(), isTrue);
      expect(await ignoredExt.exists(), isTrue);
    });
  });
}
