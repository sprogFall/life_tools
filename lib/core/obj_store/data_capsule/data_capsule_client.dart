import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../obj_store_errors.dart';

typedef DateTimeProvider = DateTime Function();

class DataCapsuleClient {
  final http.Client _httpClient;
  final DateTimeProvider _nowUtc;

  DataCapsuleClient({http.Client? httpClient, DateTimeProvider? nowUtc})
    : _httpClient = httpClient ?? http.Client(),
      _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<void> putObject({
    required String accessKey,
    required String secretKey,
    required String region,
    required String endpoint,
    required String bucket,
    required String key,
    required Uint8List bytes,
    required bool useHttps,
    required bool forcePathStyle,
  }) async {
    final endpointUri = normalizeBaseUri(endpoint, useHttps: useHttps);
    if (endpointUri.host.isEmpty) {
      throw const ObjStoreUploadException('数据胶囊上传失败：Endpoint 无效');
    }

    final uri = _buildObjectUri(
      base: endpointUri,
      bucket: bucket,
      key: key,
      forcePathStyle: forcePathStyle,
    );

    final payloadHash = sha256.convert(bytes).toString();
    final signedHeaders = _buildSignedHeaders(
      method: 'PUT',
      uri: uri,
      region: region,
      accessKey: accessKey,
      secretKey: secretKey,
      payloadHash: payloadHash,
    );

    final req = http.Request('PUT', uri)
      ..headers.addAll(signedHeaders)
      ..bodyBytes = bytes;

    final resp = await _httpClient.send(req);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;

    final body = await resp.stream.bytesToString();
    throw ObjStoreUploadException(
      body.trim().isEmpty ? '数据胶囊上传失败' : body,
      statusCode: resp.statusCode,
    );
  }

  String buildPublicUrl({
    required String base,
    required String bucket,
    required String key,
    required bool useHttps,
    required bool forcePathStyle,
  }) {
    final baseUri = normalizeBaseUri(base, useHttps: useHttps);
    if (baseUri.host.isEmpty) return '';
    return _buildObjectUri(
      base: baseUri,
      bucket: bucket,
      key: key,
      forcePathStyle: forcePathStyle,
    ).toString();
  }

  String buildPrivateGetUrl({
    required String base,
    required String bucket,
    required String key,
    required String accessKey,
    required String secretKey,
    required String region,
    required Duration expires,
    required bool useHttps,
    required bool forcePathStyle,
  }) {
    final baseUri = normalizeBaseUri(base, useHttps: useHttps);
    if (baseUri.host.isEmpty) return '';

    final uri = _buildObjectUri(
      base: baseUri,
      bucket: bucket,
      key: key,
      forcePathStyle: forcePathStyle,
    );

    final now = _nowUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);
    final scope = '$dateStamp/$region/s3/aws4_request';

    final queryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$accessKey/$scope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expires.inSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final canonicalUri = _canonicalPath(uri);
    final canonicalQuery = _canonicalQueryString(queryParams);
    final hostHeader = _hostHeaderValue(uri);
    final canonicalHeaders = 'host:$hostHeader\n';
    const signedHeaders = 'host';
    const payloadHash = 'UNSIGNED-PAYLOAD';

    final canonicalRequest =
        'GET\n'
        '$canonicalUri\n'
        '$canonicalQuery\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';

    final stringToSign =
        'AWS4-HMAC-SHA256\n'
        '$amzDate\n'
        '$scope\n'
        '${sha256.convert(utf8.encode(canonicalRequest))}';

    final signingKey = _deriveSigningKey(
      secretKey: secretKey,
      dateStamp: dateStamp,
      region: region,
      service: 's3',
    );
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

    final signedParams = <String, String>{
      ...queryParams,
      'X-Amz-Signature': signature,
    };
    return uri.replace(queryParameters: signedParams).toString();
  }

  Future<bool> probePublicUrl({
    required String url,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final uri = Uri.parse(url);

      Future<int> send({required bool withRange}) async {
        final req = http.Request('GET', uri);
        if (withRange) req.headers['Range'] = 'bytes=0-0';
        final resp = await _httpClient.send(req).timeout(timeout);
        _cancelStreamedResponse(resp);
        return resp.statusCode;
      }

      // 预签名 URL 通常只对 GET 生效，直接 HEAD 可能会返回签名不匹配（误判不可访问）。
      // 先尝试 GET + Range（避免下载大文件），若部分 S3 兼容服务对额外 Header 校验较严格，
      // 可能会拒绝 Range，从而误判不可访问，因此对 400/403 做一次纯 GET 回退。
      final code = await send(withRange: true);
      if (code == 416) return true; // 空文件等情况：Range 不可满足但对象存在
      if (code >= 200 && code < 400) return true;

      if (code == 400 || code == 403) {
        final code2 = await send(withRange: false);
        if (code2 == 416) return true;
        return code2 >= 200 && code2 < 400;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> probePrivateObject({
    required String accessKey,
    required String secretKey,
    required String region,
    required String endpoint,
    required String bucket,
    required String key,
    required bool useHttps,
    required bool forcePathStyle,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final endpointUri = normalizeBaseUri(endpoint, useHttps: useHttps);
      if (endpointUri.host.isEmpty) return false;

      final uri = _buildObjectUri(
        base: endpointUri,
        bucket: bucket,
        key: key,
        forcePathStyle: forcePathStyle,
      );

      final payloadHash = sha256.convert(const <int>[]).toString();
      final signedHeaders = _buildSignedHeaders(
        method: 'GET',
        uri: uri,
        region: region,
        accessKey: accessKey,
        secretKey: secretKey,
        payloadHash: payloadHash,
      );

      final req = http.Request('GET', uri)
        ..headers.addAll(signedHeaders)
        ..headers['Range'] = 'bytes=0-0';

      final resp = await _httpClient.send(req).timeout(timeout);
      _cancelStreamedResponse(resp);
      final code = resp.statusCode;
      if (code == 416) return true;
      return code >= 200 && code < 400;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> getPrivateObjectBytes({
    required String accessKey,
    required String secretKey,
    required String region,
    required String endpoint,
    required String bucket,
    required String key,
    required bool useHttps,
    required bool forcePathStyle,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final endpointUri = normalizeBaseUri(endpoint, useHttps: useHttps);
      if (endpointUri.host.isEmpty) return null;

      final uri = _buildObjectUri(
        base: endpointUri,
        bucket: bucket,
        key: key,
        forcePathStyle: forcePathStyle,
      );

      final payloadHash = sha256.convert(const <int>[]).toString();
      final signedHeaders = _buildSignedHeaders(
        method: 'GET',
        uri: uri,
        region: region,
        accessKey: accessKey,
        secretKey: secretKey,
        payloadHash: payloadHash,
      );

      final req = http.Request('GET', uri)..headers.addAll(signedHeaders);
      final resp = await _httpClient.send(req).timeout(timeout);
      final code = resp.statusCode;
      if (code < 200 || code >= 300) return null;

      final bytes = await resp.stream.toBytes();
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static void _cancelStreamedResponse(http.StreamedResponse resp) {
    try {
      resp.stream.listen((_) {}).cancel();
    } catch (_) {}
  }

  static Uri normalizeBaseUri(String base, {required bool useHttps}) {
    final raw = base.trim();
    if (raw.isEmpty) return Uri();

    final scheme = useHttps ? 'https' : 'http';
    final parsed = (raw.startsWith('http://') || raw.startsWith('https://'))
        ? Uri.parse(raw)
        : Uri.parse('$scheme://$raw');

    final normalizedPathSegments = parsed.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parsed.replace(
      scheme: scheme,
      pathSegments: normalizedPathSegments,
      query: null,
      fragment: null,
    );
  }

  static Uri _buildObjectUri({
    required Uri base,
    required String bucket,
    required String key,
    required bool forcePathStyle,
  }) {
    final cleanBucket = bucket.trim();
    final rawKey = key.trim();
    final normalizedKey = rawKey.startsWith('/') ? rawKey.substring(1) : rawKey;
    final keySegments = normalizedKey
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (forcePathStyle) {
      final segments = <String>[
        ...base.pathSegments.where((s) => s.trim().isNotEmpty),
        cleanBucket,
        ...keySegments,
      ];
      return base.replace(pathSegments: segments);
    }

    final host = base.host.startsWith('$cleanBucket.')
        ? base.host
        : '$cleanBucket.${base.host}';
    final segments = <String>[
      ...base.pathSegments.where((s) => s.trim().isNotEmpty),
      ...keySegments,
    ];
    return base.replace(host: host, pathSegments: segments);
  }

  static String _hostHeaderValue(Uri uri) {
    final port = uri.hasPort ? uri.port : null;
    final isDefault =
        port == null ||
        (uri.scheme == 'https' && port == 443) ||
        (uri.scheme == 'http' && port == 80);
    return isDefault ? uri.host : '${uri.host}:$port';
  }

  static String _canonicalPath(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return '/';
    final encoded = segments.map(_encodePathSegment).join('/');
    return '/$encoded';
  }

  static String _canonicalQueryString(Map<String, String> queryParams) {
    final sortedKeys = queryParams.keys.toList()..sort();
    final pairs = <String>[];
    for (final k in sortedKeys) {
      final v = queryParams[k] ?? '';
      pairs.add('${_encodeQueryComponent(k)}=${_encodeQueryComponent(v)}');
    }
    return pairs.join('&');
  }

  static String _encodePathSegment(String input) => Uri.encodeComponent(input);

  static String _encodeQueryComponent(String input) =>
      Uri.encodeQueryComponent(input);

  Map<String, String> _buildSignedHeaders({
    required String method,
    required Uri uri,
    required String region,
    required String accessKey,
    required String secretKey,
    required String payloadHash,
  }) {
    final now = _nowUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);
    final hostHeader = _hostHeaderValue(uri);
    final canonicalUri = _canonicalPath(uri);
    const canonicalQuery = '';

    final canonicalHeaders = StringBuffer()
      ..writeln('host:$hostHeader')
      ..writeln('x-amz-content-sha256:$payloadHash')
      ..writeln('x-amz-date:$amzDate');

    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
        '${method.toUpperCase()}\n'
        '$canonicalUri\n'
        '$canonicalQuery\n'
        '${canonicalHeaders.toString()}\n'
        '$signedHeaders\n'
        '$payloadHash';

    final scope = '$dateStamp/$region/s3/aws4_request';
    final stringToSign =
        'AWS4-HMAC-SHA256\n'
        '$amzDate\n'
        '$scope\n'
        '${sha256.convert(utf8.encode(canonicalRequest))}';

    final signingKey = _deriveSigningKey(
      secretKey: secretKey,
      dateStamp: dateStamp,
      region: region,
      service: 's3',
    );
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        'AWS4-HMAC-SHA256 '
        'Credential=$accessKey/$scope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    return {
      'host': hostHeader,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization': authorization,
    };
  }

  static Uint8List _deriveSigningKey({
    required String secretKey,
    required String dateStamp,
    required String region,
    required String service,
  }) {
    final kSecret = utf8.encode('AWS4$secretKey');
    final kDate = _hmacSha256(kSecret, utf8.encode(dateStamp));
    final kRegion = _hmacSha256(kDate, utf8.encode(region));
    final kService = _hmacSha256(kRegion, utf8.encode(service));
    final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
    return Uint8List.fromList(kSigning);
  }

  static List<int> _hmacSha256(List<int> key, List<int> msg) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(msg).bytes;
  }

  static String _formatDateStamp(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static String _formatAmzDate(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return '$y$m${d}T$hh$mm${ss}Z';
  }
}
