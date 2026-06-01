import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';

import '../models/work_photo_asset.dart';
import '../models/work_photo_project_detail.dart';
import '../models/work_photo_project_item.dart';
import '../repository/work_photo_repository.dart';
import 'work_photo_media_store.dart';

class WorkPhotoExportResult {
  final String fileName;
  final Uint8List bytes;
  final List<String> missingFiles;

  const WorkPhotoExportResult({
    required this.fileName,
    required this.bytes,
    required this.missingFiles,
  });
}

class WorkPhotoExportService {
  final WorkPhotoRepository _repository;
  final WorkPhotoMediaStore _mediaStore;
  final DateTime Function() _now;

  WorkPhotoExportService({
    required WorkPhotoRepository repository,
    required WorkPhotoMediaStore mediaStore,
    DateTime Function()? now,
  }) : _repository = repository,
       _mediaStore = mediaStore,
       _now = now ?? DateTime.now;

  Future<WorkPhotoExportResult> buildZip({
    required List<int> projectIds,
  }) async {
    if (projectIds.isEmpty) {
      throw ArgumentError('导出至少需要选择一个项目');
    }

    final archive = Archive();
    final missing = <String>[];
    final usedNames = <String, int>{};

    for (final projectId in projectIds) {
      final detail = await _repository.getProjectDetail(projectId);
      if (detail == null) continue;
      await _appendProject(archive, detail, missing, usedNames);
    }

    if (missing.isNotEmpty) {
      final report = '以下图片记录对应的本地文件缺失，已跳过：\n${missing.join('\n')}';
      final bytes = Uint8List.fromList(utf8.encode(report));
      archive.addFile(ArchiveFile('导出说明.txt', bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('ZIP 生成失败');
    }

    return WorkPhotoExportResult(
      fileName: _buildZipFileName(_now()),
      bytes: Uint8List.fromList(encoded),
      missingFiles: List.unmodifiable(missing),
    );
  }

  Future<String?> saveZip(WorkPhotoExportResult result) {
    final name = result.fileName.endsWith('.zip')
        ? result.fileName.substring(0, result.fileName.length - 4)
        : result.fileName;
    return FileSaver.instance.saveFile(
      name: name,
      bytes: result.bytes,
      ext: 'zip',
      mimeType: MimeType.zip,
    );
  }

  Future<void> _appendProject(
    Archive archive,
    WorkPhotoProjectDetail detail,
    List<String> missing,
    Map<String, int> usedNames,
  ) async {
    final projectName = sanitizePathSegment(detail.project.name);
    final levelSegments = detail.hierarchyValues
        .map((e) => e.optionNameSnapshot.trim())
        .where((e) => e.isNotEmpty)
        .map(sanitizePathSegment)
        .where((e) => e.isNotEmpty)
        .toList();
    final itemById = {
      for (final item in detail.items)
        if (item.id != null) item.id!: item,
    };
    final itemAssetIndex = <int, int>{};

    final assets = List<WorkPhotoAsset>.from(detail.assets)
      ..sort((a, b) {
        final byItem = a.projectItemId.compareTo(b.projectItemId);
        if (byItem != 0) return byItem;
        final byTaken = a.takenAt.compareTo(b.takenAt);
        if (byTaken != 0) return byTaken;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

    for (final asset in assets) {
      final file = await _mediaStore.resolveStoredFile(asset.relativePath);
      if (!await file.exists()) {
        missing.add(asset.relativePath);
        continue;
      }

      final item = itemById[asset.projectItemId];
      final itemName = sanitizePathSegment(item?.nameSnapshot ?? '未命名');
      final itemHierarchySegments = await _itemHierarchySegments(item);
      final index = itemAssetIndex.update(
        asset.projectItemId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      final baseSegments = <String>[
        projectName,
        ...levelSegments,
        ...itemHierarchySegments,
        itemName,
      ];
      final fileName =
          '${_formatDateTime(asset.takenAt)}_${itemName}_${index.toString().padLeft(3, '0')}.jpg';
      final zipPath = _dedupePath(
        [...baseSegments, sanitizePathSegment(fileName)].join('/'),
        usedNames,
      );
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
    }
  }

  Future<List<String>> _itemHierarchySegments(
    WorkPhotoProjectItem? item,
  ) async {
    final snapshot = item?.hierarchyPathSnapshot ?? const <String>[];
    if (snapshot.isNotEmpty) {
      return _sanitizePathSegments(snapshot);
    }
    final sourceItemId = item?.sourceItemId;
    if (sourceItemId == null) return const [];
    final fallback = await _repository.resolveCaptureItemHierarchyPath(
      sourceItemId,
    );
    return _sanitizePathSegments(fallback);
  }

  static List<String> _sanitizePathSegments(Iterable<String> segments) {
    return segments
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(sanitizePathSegment)
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static String sanitizePathSegment(String raw) {
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
    return value.isEmpty ? '未命名' : value;
  }

  static String _dedupePath(String path, Map<String, int> usedNames) {
    final existing = usedNames[path] ?? 0;
    usedNames[path] = existing + 1;
    if (existing == 0) return path;

    final slash = path.lastIndexOf('/');
    final folder = slash < 0 ? '' : path.substring(0, slash + 1);
    final file = slash < 0 ? path : path.substring(slash + 1);
    final dot = file.lastIndexOf('.');
    final stem = dot < 0 ? file : file.substring(0, dot);
    final ext = dot < 0 ? '' : file.substring(dot);
    return '$folder$stem-${existing + 1}$ext';
  }

  static String _buildZipFileName(DateTime time) {
    return '外拍导出_${_date(time)}_${_hourMinute(time)}.zip';
  }

  static String _formatDateTime(DateTime time) {
    return '${_date(time)}_${_hourMinute(time)}${time.second.toString().padLeft(2, '0')}';
  }

  static String _date(DateTime time) {
    return '${time.year.toString().padLeft(4, '0')}'
        '${time.month.toString().padLeft(2, '0')}'
        '${time.day.toString().padLeft(2, '0')}';
  }

  static String _hourMinute(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}
