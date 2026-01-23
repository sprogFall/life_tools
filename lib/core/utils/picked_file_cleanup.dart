import 'package:path/path.dart' as p;

import 'temp_file_cleanup.dart';

/// 用于判断通过选择器（如 file_picker）拿到的文件路径，是否属于“临时复制文件”，
/// 以便在读取/上传后安全删除，避免在系统相册中出现多余的重复图片。
bool shouldCleanupPickedFilePath({
  required String filePath,
  required String temporaryDirPath,
  List<String> externalCacheDirPaths = const [],
  String? externalStorageDirPath,
}) {
  return isPathWithinAnyDir(
    filePath: filePath,
    dirPaths: buildPickedFileCleanupDirPaths(
      temporaryDirPath: temporaryDirPath,
      externalCacheDirPaths: externalCacheDirPaths,
      externalStorageDirPath: externalStorageDirPath,
    ),
  );
}

List<String> buildPickedFileCleanupDirPaths({
  required String temporaryDirPath,
  List<String> externalCacheDirPaths = const [],
  String? externalStorageDirPath,
}) {
  final raw = <String>[
    temporaryDirPath,
    ...externalCacheDirPaths,
    if (externalStorageDirPath != null) externalStorageDirPath,
  ];

  final out = <String>{};
  for (final v in raw) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) continue;
    out.add(p.normalize(trimmed));
  }
  return out.toList(growable: false);
}
