import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/work_photo_asset.dart';
import '../repository/work_photo_repository.dart';
import 'work_photo_media_store.dart';

abstract class WorkPhotoCameraCapture {
  Future<File> takePictureFile();
}

class WorkPhotoCaptureCoordinator {
  final WorkPhotoRepository _repository;
  final WorkPhotoMediaStore _mediaStore;
  final WorkPhotoCameraCapture _cameraCapture;
  final DateTime Function() _now;

  WorkPhotoCaptureCoordinator({
    required WorkPhotoRepository repository,
    required WorkPhotoMediaStore mediaStore,
    required WorkPhotoCameraCapture cameraCapture,
    DateTime Function()? now,
  }) : _repository = repository,
       _mediaStore = mediaStore,
       _cameraCapture = cameraCapture,
       _now = now ?? DateTime.now;

  Future<WorkPhotoAsset> captureToItem({
    required int projectId,
    required int projectItemId,
  }) async {
    final takenAt = _now();
    final source = await _cameraCapture.takePictureFile();
    final stored = await _mediaStore.savePhoto(
      projectId: projectId,
      sourceFile: source,
      now: takenAt,
    );

    try {
      final assetId = await _repository.createAsset(
        projectId: projectId,
        projectItemId: projectItemId,
        relativePath: stored.relativePath,
        originalFilename: p.basename(source.path),
        mimeType: 'image/jpeg',
        fileSize: stored.fileSize,
        width: null,
        height: null,
        takenAt: takenAt,
        now: takenAt,
      );
      return WorkPhotoAsset(
        id: assetId,
        projectId: projectId,
        projectItemId: projectItemId,
        relativePath: stored.relativePath,
        originalFilename: p.basename(source.path),
        mimeType: 'image/jpeg',
        fileSize: stored.fileSize,
        width: null,
        height: null,
        takenAt: takenAt,
        createdAt: takenAt,
        updatedAt: takenAt,
      );
    } catch (_) {
      await _mediaStore.deleteStoredFile(stored.relativePath);
      rethrow;
    }
  }
}
