import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/utils/picked_file_cleanup.dart';

void main() {
  group('PickedFileCleanup', () {
    test('外部缓存目录内的 file_picker 复制文件应被判定为可清理', () {
      final ok = shouldCleanupPickedFilePath(
        filePath:
            '/storage/emulated/0/Android/data/com.example.app/cache/file_picker/a.jpg',
        temporaryDirPath: '/data/user/0/com.example.app/cache',
        externalCacheDirPaths: const [
          '/storage/emulated/0/Android/data/com.example.app/cache',
        ],
      );
      expect(ok, isTrue);
    });

    test('相册目录（如 DCIM）内的原始图片不应被判定为可清理', () {
      final ok = shouldCleanupPickedFilePath(
        filePath: '/storage/emulated/0/DCIM/Camera/a.jpg',
        temporaryDirPath: '/data/user/0/com.example.app/cache',
        externalCacheDirPaths: const [
          '/storage/emulated/0/Android/data/com.example.app/cache',
        ],
      );
      expect(ok, isFalse);
    });
  });
}
