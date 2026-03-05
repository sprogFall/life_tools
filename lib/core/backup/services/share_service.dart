import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'share_temp_cleanup.dart';

class ShareService {
  static const _shareTempFolder = 'life_tools_share';
  static const _shareTempPrefix = '';

  /// 分享备份文件
  static Future<ShareResult> shareBackup(
    String jsonText,
    String fileName,
  ) async {
    return shareTextFile(
      jsonText,
      fileName,
      subject: '小蜜备份文件',
      mimeType: 'text/plain',
    );
  }

  static Future<ShareResult> shareTextFile(
    String text,
    String fileName, {
    String subject = '小蜜导出文件',
    String mimeType = 'text/plain',
  }) async {
    final bytes = utf8.encode(text);
    return shareBinaryFile(
      Uint8List.fromList(bytes),
      fileName,
      subject: subject,
      mimeType: mimeType,
    );
  }

  static Future<ShareResult> shareBinaryFile(
    Uint8List bytes,
    String fileName, {
    String subject = '小蜜导出文件',
    String mimeType = 'application/octet-stream',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory('${tempDir.path}/$_shareTempFolder');
    await shareDir.create(recursive: true);

    await cleanupShareTempFiles(
      directory: shareDir,
      filePrefix: _shareTempPrefix,
    );

    final file = File('${shareDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final result = await Share.shareXFiles([
      XFile(file.path, mimeType: mimeType),
    ], subject: subject);

    await cleanupShareTempFiles(
      directory: shareDir,
      filePrefix: _shareTempPrefix,
      keepLatest: 1,
      maxAge: const Duration(hours: 12),
      excludePaths: {file.path},
    );

    return result;
  }
}
