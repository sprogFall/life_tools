import 'dart:convert';
import 'dart:io';

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
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory('${tempDir.path}/$_shareTempFolder');
    await shareDir.create(recursive: true);

    await cleanupShareTempFiles(
      directory: shareDir,
      filePrefix: _shareTempPrefix,
    );

    final file = File('${shareDir.path}/$fileName');
    await file.writeAsString(jsonText, encoding: utf8);

    final result = await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/plain'),
    ], subject: '小蜜备份文件');

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
