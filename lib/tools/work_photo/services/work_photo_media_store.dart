import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../work_photo_constants.dart';

class WorkPhotoStoredFile {
  final String relativePath;
  final int fileSize;

  const WorkPhotoStoredFile({
    required this.relativePath,
    required this.fileSize,
  });
}

class WorkPhotoMediaStore {
  final Directory? _baseDirectory;

  WorkPhotoMediaStore({Directory? baseDirectory})
    : _baseDirectory = baseDirectory;

  Future<Directory> get rootDirectory async {
    final injected = _baseDirectory;
    if (injected != null) {
      await injected.create(recursive: true);
      return injected;
    }
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(
      p.join(documents.path, WorkPhotoConstants.mediaRootFolder),
    );
    await root.create(recursive: true);
    return root;
  }

  Directory get baseDirectory {
    final injected = _baseDirectory;
    if (injected == null) {
      throw StateError('baseDirectory 仅在注入目录时可同步读取');
    }
    return injected;
  }

  Future<WorkPhotoStoredFile> savePhoto({
    required int projectId,
    required File sourceFile,
    DateTime? now,
  }) async {
    final root = await rootDirectory;
    final time = now ?? DateTime.now();
    final photosDir = Directory(
      p.join(root.path, WorkPhotoConstants.photosFolder, '$projectId'),
    );
    await photosDir.create(recursive: true);

    final originalName = sourceFile.uri.pathSegments.isEmpty
        ? 'photo'
        : p.basenameWithoutExtension(sourceFile.path);
    final safeName = _sanitizeFileNameStem(originalName);
    final fileName = '${time.microsecondsSinceEpoch}_$safeName.jpg';
    final target = File(p.join(photosDir.path, fileName));
    await sourceFile.copy(target.path);
    final size = await target.length();
    return WorkPhotoStoredFile(
      relativePath: p
          .join(WorkPhotoConstants.photosFolder, '$projectId', fileName)
          .replaceAll(p.separator, '/'),
      fileSize: size,
    );
  }

  Future<void> deleteStoredFile(String relativePath) async {
    final file = await resolveStoredFile(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  File resolveFile(String relativePath) {
    final injected = _baseDirectory;
    if (injected == null) {
      throw StateError('resolveFile 需要注入 baseDirectory，或改用 resolveStoredFile');
    }
    return _resolve(injected, relativePath);
  }

  Future<File> resolveStoredFile(String relativePath) async {
    final root = await rootDirectory;
    return _resolve(root, relativePath);
  }

  File _resolve(Directory root, String relativePath) {
    final normalizedRelative = relativePath.trim().replaceAll('\\', '/');
    if (normalizedRelative.isEmpty ||
        p.isAbsolute(normalizedRelative) ||
        normalizedRelative.split('/').contains('..')) {
      throw ArgumentError('非法外拍图片路径');
    }

    final rootPath = p.normalize(root.absolute.path);
    final targetPath = p.normalize(p.join(rootPath, normalizedRelative));
    if (!p.isWithin(rootPath, targetPath) && targetPath != rootPath) {
      throw ArgumentError('非法外拍图片路径');
    }
    return File(targetPath);
  }

  static String _sanitizeFileNameStem(String raw) {
    var value = raw.trim();
    value = value.replaceAll('..', '');
    value = value.replaceAll(RegExp(r'[\\/<>\:"|?*\x00-\x1F]'), '_');
    value = value.replaceAll(RegExp(r'_+'), '_').trim();
    while (value.startsWith('_')) {
      value = value.substring(1);
    }
    while (value.endsWith('_')) {
      value = value.substring(0, value.length - 1);
    }
    return value.isEmpty ? 'photo' : value;
  }
}
