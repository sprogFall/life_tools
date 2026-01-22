import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../obj_store_errors.dart';
import 'qiniu_auth.dart';

typedef QiniuAuthFactory =
    QiniuAuth Function(String accessKey, String secretKey);

class QiniuUploadResult {
  final String key;
  final String hash;
  const QiniuUploadResult({required this.key, required this.hash});
}

class QiniuClient {
  final http.Client _httpClient;
  final QiniuAuthFactory _authFactory;

  QiniuClient({http.Client? httpClient, QiniuAuthFactory? authFactory})
    : _httpClient = httpClient ?? http.Client(),
      _authFactory =
          authFactory ?? ((ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk));

  Future<QiniuUploadResult> uploadBytes({
    required String accessKey,
    required String secretKey,
    required String bucket,
    required String uploadHost,
    required String key,
    required Uint8List bytes,
    required String filename,
  }) async {
    final host = _normalizeUploadHost(uploadHost);
    final uri = Uri.parse('$host/');

    final auth = _authFactory(accessKey, secretKey);
    final token = auth.createUploadToken(
      scope: '$bucket:$key',
      deadlineUnixSeconds: _defaultDeadline(),
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['token'] = token
      ..fields['key'] = key
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final response = await _httpClient.send(request);
    final body = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ObjStoreUploadException(
        body.isEmpty ? '七牛上传失败' : body,
        statusCode: response.statusCode,
      );
    }

    final map = jsonDecode(body) as Map<String, dynamic>;
    final respKey = (map['key'] as String?)?.trim();
    final hash = (map['hash'] as String?)?.trim() ?? '';
    if (respKey == null || respKey.isEmpty) {
      throw const ObjStoreUploadException('七牛上传成功但未返回 key');
    }
    return QiniuUploadResult(key: respKey, hash: hash);
  }

  String buildPublicUrl({
    required String domain,
    required String key,
    bool useHttps = true,
  }) {
    final d = _normalizeDomain(domain, useHttps: useHttps);
    final k = key.startsWith('/') ? key.substring(1) : key;
    return '$d/$k';
  }

  String buildPrivateUrl({
    required String domain,
    required String key,
    required String accessKey,
    required String secretKey,
    required int deadlineUnixSeconds,
    bool useHttps = true,
  }) {
    final baseUrl = buildPublicUrl(
      domain: domain,
      key: key,
      useHttps: useHttps,
    );
    final auth = _authFactory(accessKey, secretKey);
    return auth.createPrivateDownloadUrl(
      baseUrl: baseUrl,
      deadlineUnixSeconds: deadlineUnixSeconds,
    );
  }

  Future<bool> probePublicUrl({
    required String url,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final resp = await _httpClient.head(Uri.parse(url)).timeout(timeout);
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  static int _defaultDeadline() {
    final now = DateTime.now().toUtc();
    return now.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  }

  static String _normalizeUploadHost(String host) {
    final h = host.trim();
    if (h.isEmpty) return 'https://upload.qiniup.com';
    if (h.startsWith('http://') || h.startsWith('https://')) return h;
    return 'https://$h';
  }

  static String _normalizeDomain(String domain, {required bool useHttps}) {
    final d = domain.trim();
    if (d.isEmpty) return '';
    if (d.startsWith('http://') || d.startsWith('https://')) {
      return d.replaceAll(RegExp(r'/$'), '');
    }
    final scheme = useHttps ? 'https' : 'http';
    return '$scheme://${d.replaceAll(RegExp(r'/$'), '')}';
  }
}
