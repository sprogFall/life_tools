import 'dart:io';

import 'package:path/path.dart' as p;

class PendingUploadFile {
  final String path;
  final String filename;

  const PendingUploadFile({required this.path, required this.filename});
}

Future<PendingUploadFile> stageFileToPendingUploadDir({
  required String sourcePath,
  required String filename,
  required String temporaryDirPath,
  required int nowMicros,
}) async {
  final normalizedTemp = p.normalize(temporaryDirPath);
  final dir = Directory(p.join(normalizedTemp, 'life_tools_pending_uploads'));
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final ext = p.extension(filename.trim().isEmpty ? sourcePath : filename);
  final safeExt = ext.trim().isEmpty ? '.bin' : ext;
  final destPath = p.join(dir.path, '$nowMicros$safeExt');

  final src = File(sourcePath);
  if (!src.existsSync()) {
    throw FileSystemException('source file not exists', sourcePath);
  }
  final dest = await src.copy(destPath);

  return PendingUploadFile(path: dest.path, filename: filename);
}
