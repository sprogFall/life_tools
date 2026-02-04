import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// 包含图片文件名和二进制数据的简单封装
class PickedImageBytes {
  final String filename;
  final Uint8List bytes;

  const PickedImageBytes({required this.filename, required this.bytes});
}

/// 图片选择工具类
///
/// 封装了 [ImagePicker] 和 [FilePicker] 的差异，提供统一的图片选择接口。
/// - 移动端：优先使用系统相册 (ImagePicker)，并自动进行压缩
/// - 桌面端/Web：使用文件选择器 (FilePicker)
class ImageSelector {
  static final _imagePicker = ImagePicker();

  /// 选择单张图片
  ///
  /// [compressQuality] 图片压缩质量 (0-100)，仅在移动端生效，默认 80
  /// [maxWidth] 图片最大宽度，仅在移动端生效，默认 1920
  static Future<PickedImageBytes?> pickSingle({
    int compressQuality = 80,
    double maxWidth = 1920,
  }) async {
    if (_useImagePicker) {
      return _pickSingleByImagePicker(
        quality: compressQuality,
        maxWidth: maxWidth,
      );
    } else {
      return _pickSingleByFilePicker();
    }
  }

  /// 选择多张图片
  ///
  /// [compressQuality] 图片压缩质量 (0-100)，仅在移动端生效，默认 80
  /// [maxWidth] 图片最大宽度，仅在移动端生效，默认 1920
  static Future<List<PickedImageBytes>> pickMulti({
    int compressQuality = 80,
    double maxWidth = 1920,
  }) async {
    if (_useImagePicker) {
      return _pickMultiByImagePicker(
        quality: compressQuality,
        maxWidth: maxWidth,
      );
    } else {
      return _pickMultiByFilePicker();
    }
  }

  static bool get _useImagePicker {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<PickedImageBytes?> _pickSingleByImagePicker({
    required int quality,
    required double maxWidth,
  }) async {
    try {
      final x = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: quality,
        maxWidth: maxWidth,
      );
      if (x == null) return null;
      final bytes = await x.readAsBytes();
      if (bytes.isEmpty) return null;
      return PickedImageBytes(filename: x.name, bytes: bytes);
    } catch (e) {
      if (kDebugMode) print('ImageSelector pickSingle error: $e');
      return null;
    }
  }

  static Future<List<PickedImageBytes>> _pickMultiByImagePicker({
    required int quality,
    required double maxWidth,
  }) async {
    try {
      final list = await _imagePicker.pickMultiImage(
        imageQuality: quality,
        maxWidth: maxWidth,
      );
      if (list.isEmpty) return const [];

      final out = <PickedImageBytes>[];
      for (final x in list) {
        final bytes = await x.readAsBytes();
        if (bytes.isEmpty) continue;
        out.add(PickedImageBytes(filename: x.name, bytes: bytes));
      }
      return out;
    } catch (e) {
      if (kDebugMode) print('ImageSelector pickMulti error: $e');
      return const [];
    }
  }

  static Future<PickedImageBytes?> _pickSingleByFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final bytes = await _readPickedFileBytes(file);
      if (bytes == null || bytes.isEmpty) return null;

      return PickedImageBytes(filename: file.name, bytes: bytes);
    } catch (e) {
      if (kDebugMode) print('ImageSelector pickSingle (FilePicker) error: $e');
      return null;
    } finally {
      _cleanupFilePickerTemps();
    }
  }

  static Future<List<PickedImageBytes>> _pickMultiByFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return const [];

      final out = <PickedImageBytes>[];
      for (final f in result.files) {
        final bytes = await _readPickedFileBytes(f);
        if (bytes == null || bytes.isEmpty) continue;
        out.add(PickedImageBytes(filename: f.name, bytes: bytes));
      }
      return out;
    } catch (e) {
      if (kDebugMode) print('ImageSelector pickMulti (FilePicker) error: $e');
      return const [];
    } finally {
      _cleanupFilePickerTemps();
    }
  }

  static Future<Uint8List?> _readPickedFileBytes(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    final path = file.path;
    if (path == null || path.trim().isEmpty) return null;
    try {
      return await XFile(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _cleanupFilePickerTemps() async {
    if (kIsWeb) return;
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {}
  }
}
