import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  final Future<Directory> Function()? _visibleGalleryRootDirectoryProvider;
  final WorkPhotoMediaIndexer _mediaIndexer;
  final int _sourceReadMaxAttempts;
  final Duration _sourceReadRetryDelay;

  WorkPhotoMediaStore({
    Directory? baseDirectory,
    Future<Directory> Function()? visibleGalleryRootDirectoryProvider,
    WorkPhotoMediaIndexer? mediaIndexer,
    int sourceReadMaxAttempts = 8,
    Duration sourceReadRetryDelay = const Duration(milliseconds: 120),
  }) : _baseDirectory = baseDirectory,
       _visibleGalleryRootDirectoryProvider =
           visibleGalleryRootDirectoryProvider,
       _mediaIndexer = mediaIndexer ?? const WorkPhotoMediaChannelIndexer(),
       _sourceReadMaxAttempts = sourceReadMaxAttempts,
       _sourceReadRetryDelay = sourceReadRetryDelay;

  Future<Directory> get rootDirectory async {
    final injected = _baseDirectory;
    if (injected != null) {
      await injected.create(recursive: true);
      return injected;
    }
    final galleryRoot =
        await (_visibleGalleryRootDirectoryProvider?.call() ??
            WorkPhotoMediaDirectories.visibleGalleryRootDirectory());
    final root = Directory(
      p.join(galleryRoot.path, WorkPhotoConstants.mediaRootFolder),
    );
    try {
      await root.create(recursive: true);
    } on FileSystemException {
      if (!Platform.isAndroid) rethrow;
    }
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
    final readableSource = await _waitForReadableSourceFile(sourceFile);
    final root = await rootDirectory;
    final time = now ?? DateTime.now();
    final usePlatformGallery = _baseDirectory == null && Platform.isAndroid;
    final photosDir = Directory(
      p.join(root.path, WorkPhotoConstants.photosFolder, '$projectId'),
    );
    if (!usePlatformGallery) {
      await photosDir.create(recursive: true);
    }

    final originalName = readableSource.uri.pathSegments.isEmpty
        ? 'photo'
        : p.basenameWithoutExtension(readableSource.path);
    final safeName = _sanitizeFileNameStem(originalName);
    final fileName = '${time.microsecondsSinceEpoch}_$safeName.jpg';
    final relativePath = p
        .join(WorkPhotoConstants.photosFolder, '$projectId', fileName)
        .replaceAll(p.separator, '/');
    final target = File(p.join(photosDir.path, fileName));

    final platformPath = usePlatformGallery
        ? await _mediaIndexer.saveImage(
            sourcePath: readableSource.path,
            albumRelativePath: p
                .join(
                  WorkPhotoConstants.mediaRootFolder,
                  WorkPhotoConstants.photosFolder,
                  '$projectId',
                )
                .replaceAll(p.separator, '/'),
            displayName: fileName,
          )
        : null;
    final storedFile = platformPath == null ? target : File(platformPath);
    if (platformPath == null) {
      await readableSource.copy(target.path);
      await _mediaIndexer.scanFile(target.path);
    }
    final size = await storedFile.exists()
        ? await storedFile.length()
        : await readableSource.length();
    return WorkPhotoStoredFile(relativePath: relativePath, fileSize: size);
  }

  Future<File> _waitForReadableSourceFile(File sourceFile) async {
    final attempts = _sourceReadMaxAttempts < 1 ? 1 : _sourceReadMaxAttempts;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        if (await sourceFile.exists() && await sourceFile.length() > 0) {
          return sourceFile;
        }
      } on FileSystemException {
        // 部分 Android 机型拍照返回后临时文件短时间内不可读，稍后重试。
      }
      if (attempt < attempts - 1) {
        await Future<void>.delayed(_sourceReadRetryDelay);
      }
    }
    throw WorkPhotoSourcePhotoUnavailableException();
  }

  Future<void> deleteStoredFile(String relativePath) async {
    final file = await resolveStoredFile(relativePath);
    final mediaStoreDeleted = await _mediaIndexer.deleteFile(file.path);
    if (!mediaStoreDeleted && await file.exists()) {
      await file.delete();
      await _mediaIndexer.scanFile(file.path);
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

class WorkPhotoSourcePhotoUnavailableException implements Exception {
  @override
  String toString() => '相机临时照片不可读取，请重新拍摄。';
}

abstract class WorkPhotoMediaIndexer {
  Future<String?> saveImage({
    required String sourcePath,
    required String albumRelativePath,
    required String displayName,
  });

  Future<void> scanFile(String path);

  Future<bool> deleteFile(String path);
}

class WorkPhotoMediaChannelIndexer implements WorkPhotoMediaIndexer {
  static const MethodChannel _channel = MethodChannel('life_tools/media_store');

  const WorkPhotoMediaChannelIndexer();

  @override
  Future<String?> saveImage({
    required String sourcePath,
    required String albumRelativePath,
    required String displayName,
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveImage', {
        'sourcePath': sourcePath,
        'albumRelativePath': albumRelativePath,
        'displayName': displayName,
      });
    } on FlutterError {
      return null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> scanFile(String path) async {
    await _invokeSafely('scanFile', path);
  }

  @override
  Future<bool> deleteFile(String path) async {
    try {
      return await _channel.invokeMethod<bool>('deleteFile', {'path': path}) ??
          false;
    } on FlutterError {
      return false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> _invokeSafely(String method, String path) async {
    try {
      await _channel.invokeMethod<void>(method, {'path': path});
    } on FlutterError {
      // 纯 Dart 测试未初始化 ServicesBinding 时安全降级。
    } on MissingPluginException {
      // 单元测试、桌面平台或旧包未注册通道时，不影响应用内文件管理。
    } on PlatformException {
      // 媒体库索引失败不应阻断拍照保存/删除本地文件。
    }
  }
}

class WorkPhotoMediaDirectories {
  WorkPhotoMediaDirectories._();

  static Future<Directory> visibleGalleryRootDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Pictures');
    }
    final documents = await getApplicationDocumentsDirectory();
    return documents;
  }
}
