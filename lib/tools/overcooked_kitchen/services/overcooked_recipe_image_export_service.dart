import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

enum OvercookedGallerySaveStatus {
  saved,
  unsupported,
  permissionDenied,
  failed,
}

class OvercookedGallerySaveResult {
  final OvercookedGallerySaveStatus status;
  final String? path;
  final String? errorMessage;

  const OvercookedGallerySaveResult._({
    required this.status,
    this.path,
    this.errorMessage,
  });

  const OvercookedGallerySaveResult.saved({String? path})
    : this._(status: OvercookedGallerySaveStatus.saved, path: path);

  const OvercookedGallerySaveResult.unsupported()
    : this._(status: OvercookedGallerySaveStatus.unsupported);

  const OvercookedGallerySaveResult.permissionDenied()
    : this._(status: OvercookedGallerySaveStatus.permissionDenied);

  const OvercookedGallerySaveResult.failed([String? errorMessage])
    : this._(
        status: OvercookedGallerySaveStatus.failed,
        errorMessage: errorMessage,
      );

  factory OvercookedGallerySaveResult.fromPluginResult(dynamic result) {
    if (result is Map) {
      final success = _toBool(_pick(result, const ['isSuccess', 'success']));
      final path = _toString(_pick(result, const ['filePath', 'path']));
      final error = _toString(
        _pick(result, const ['errorMessage', 'message', 'error']),
      );
      final normalizedPath = path?.trim();
      final normalizedError = error?.trim();
      if (success == true || (success == null && _isNotBlank(normalizedPath))) {
        return OvercookedGallerySaveResult.saved(path: normalizedPath);
      }
      return OvercookedGallerySaveResult.failed(normalizedError);
    }
    if (result is bool) {
      return result
          ? const OvercookedGallerySaveResult.saved()
          : const OvercookedGallerySaveResult.failed();
    }
    if (result is String) {
      final normalized = result.trim();
      if (normalized.isEmpty) {
        return const OvercookedGallerySaveResult.failed();
      }
      return OvercookedGallerySaveResult.saved(path: normalized);
    }
    if (result is num) {
      return result > 0
          ? const OvercookedGallerySaveResult.saved()
          : const OvercookedGallerySaveResult.failed();
    }
    return const OvercookedGallerySaveResult.failed();
  }

  static bool _isNotBlank(String? value) => value != null && value.isNotEmpty;

  static Object? _pick(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        return map[key];
      }
      for (final entry in map.entries) {
        if (entry.key.toString() == key) {
          return entry.value;
        }
      }
    }
    return null;
  }

  static bool? _toBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  static String? _toString(Object? value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class OvercookedRecipeImageExportResult {
  final String filePath;
  final OvercookedGallerySaveResult galleryResult;

  const OvercookedRecipeImageExportResult({
    required this.filePath,
    required this.galleryResult,
  });
}

typedef OvercookedFileExportDelegate =
    Future<String> Function({required String name, required Uint8List bytes});
typedef OvercookedGallerySaveDelegate =
    Future<OvercookedGallerySaveResult> Function({
      required String name,
      required Uint8List bytes,
    });

class OvercookedRecipeImageExportService {
  final OvercookedFileExportDelegate _fileExporter;
  final OvercookedGallerySaveDelegate _gallerySaver;

  OvercookedRecipeImageExportService({
    OvercookedFileExportDelegate? fileExporter,
    OvercookedGallerySaveDelegate? gallerySaver,
  }) : _fileExporter = fileExporter ?? _defaultFileExporter,
       _gallerySaver = gallerySaver ?? _defaultGallerySaver;

  Future<OvercookedRecipeImageExportResult> exportPng({
    required String name,
    required Uint8List bytes,
  }) async {
    final filePath = await _fileExporter(name: name, bytes: bytes);
    OvercookedGallerySaveResult galleryResult;
    try {
      galleryResult = await _gallerySaver(name: name, bytes: bytes);
    } catch (error) {
      galleryResult = OvercookedGallerySaveResult.failed(error.toString());
    }
    return OvercookedRecipeImageExportResult(
      filePath: filePath,
      galleryResult: galleryResult,
    );
  }

  static Future<String> _defaultFileExporter({
    required String name,
    required Uint8List bytes,
  }) async {
    return FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: 'png',
      mimeType: MimeType.png,
    );
  }

  static Future<OvercookedGallerySaveResult> _defaultGallerySaver({
    required String name,
    required Uint8List bytes,
  }) async {
    if (kIsWeb || !_isMobilePlatform()) {
      return const OvercookedGallerySaveResult.unsupported();
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.photosAddOnly.request();
      if (!status.isGranted && !status.isLimited) {
        return const OvercookedGallerySaveResult.permissionDenied();
      }
    }

    try {
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: name,
      );
      return OvercookedGallerySaveResult.fromPluginResult(result);
    } catch (error) {
      return OvercookedGallerySaveResult.failed(error.toString());
    }
  }

  static bool _isMobilePlatform() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
