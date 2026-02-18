import 'dart:io';

Future<int> cleanupShareTempFiles({
  required Directory directory,
  required String filePrefix,
  int keepLatest = 3,
  Duration maxAge = const Duration(days: 2),
  Set<String> excludePaths = const <String>{},
  DateTime? now,
}) async {
  if (!await directory.exists()) return 0;

  final cutoff = (now ?? DateTime.now()).subtract(maxAge);
  final entries = <FileSystemEntity>[];
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.isEmpty
        ? ''
        : entity.uri.pathSegments.last;
    if (!name.startsWith(filePrefix) || !name.endsWith('.txt')) continue;
    entries.add(entity);
  }

  final sorted = <({File file, DateTime modified})>[];
  for (final entity in entries) {
    try {
      final stat = await entity.stat();
      sorted.add((file: entity as File, modified: stat.modified));
    } catch (_) {
      // 文件可能在并发清理中被移除，忽略即可。
    }
  }

  sorted.sort((a, b) => b.modified.compareTo(a.modified));

  var deleted = 0;
  for (var i = 0; i < sorted.length; i++) {
    final item = sorted[i];
    if (excludePaths.contains(item.file.path)) continue;

    final shouldDeleteByCount = i >= keepLatest;
    final shouldDeleteByAge = item.modified.isBefore(cutoff);
    if (!shouldDeleteByCount && !shouldDeleteByAge) continue;

    try {
      await item.file.delete();
      deleted++;
    } catch (_) {
      // 删除失败时跳过，避免影响分享主流程。
    }
  }

  return deleted;
}
