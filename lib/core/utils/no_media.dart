import 'dart:io';

import 'package:path/path.dart' as p;

import 'dev_log.dart';

/// 在目录内创建一个空的 `.nomedia` 文件，用于告知 Android 媒体库不要扫描该目录，
/// 避免临时图片（如 file_picker 复制文件、上传暂存文件）出现在系统相册里。
Future<void> ensureNoMediaFileInDir(String dirPath) async {
  final normalized = p.normalize(dirPath).trim();
  if (normalized.isEmpty) return;
  try {
    final dir = Directory(normalized);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, '.nomedia'));
    if (file.existsSync()) return;
    await file.writeAsBytes(const [], flush: true);
  } catch (e, st) {
    devLog('创建 .nomedia 文件失败: $normalized', error: e, stackTrace: st);
  }
}

Future<void> ensureNoMediaFilesInDirs(Iterable<String> dirPaths) async {
  for (final dirPath in dirPaths) {
    await ensureNoMediaFileInDir(dirPath);
  }
}
