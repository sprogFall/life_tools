import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/utils/temp_file_cleanup.dart';

void main() {
  group('TempFileCleanup', () {
    test('命中临时目录时应返回 true', () {
      final ok = isPathWithinAnyDir(
        filePath: '/tmp/life_tools/cache/file_picker/a.png',
        dirPaths: const ['/tmp/life_tools/cache'],
      );
      expect(ok, isTrue);
    });

    test('不在临时目录时应返回 false', () {
      final ok = isPathWithinAnyDir(
        filePath: '/home/user/Pictures/a.png',
        dirPaths: const ['/tmp/life_tools/cache', '/var/tmp'],
      );
      expect(ok, isFalse);
    });
  });
}

