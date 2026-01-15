import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// 分享备份文件
  static Future<ShareResult> shareBackup(
    String jsonText,
    String fileName,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonText, encoding: utf8);

    return Share.shareXFiles([
      XFile(file.path, mimeType: 'text/plain'),
    ], subject: '小蜜备份文件');
  }
}
