import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'obj_store_config.dart';
import 'obj_store_config_service.dart';
import 'obj_store_errors.dart';
import 'obj_store_key.dart';
import 'obj_store_secrets.dart';
import 'qiniu/qiniu_client.dart';
import 'storage/local_obj_store.dart';
import '../utils/no_media.dart';

class ObjStoreObject {
  final ObjStoreType storageType;
  final String key;
  final String uri;

  const ObjStoreObject({
    required this.storageType,
    required this.key,
    required this.uri,
  });
}

class ObjStoreService {
  final ObjStoreConfigService _configService;
  final LocalObjStore _localStore;
  final QiniuClient _qiniuClient;
  final int Function() _qiniuPrivateDeadlineUnixSeconds;
  final BaseDirProvider? _cacheBaseDirProvider;
  final http.Client _cacheHttpClient;
  final Map<String, Future<File?>> _inflightCache = {};
  final Map<String, File> _memoryCache = {};

  ObjStoreService({
    required ObjStoreConfigService configService,
    required LocalObjStore localStore,
    required QiniuClient qiniuClient,
    int Function()? qiniuPrivateDeadlineUnixSeconds,
    BaseDirProvider? cacheBaseDirProvider,
    http.Client? cacheHttpClient,
  }) : _configService = configService,
       _localStore = localStore,
       _qiniuClient = qiniuClient,
       _qiniuPrivateDeadlineUnixSeconds =
           qiniuPrivateDeadlineUnixSeconds ?? _defaultPrivateDeadline,
       _cacheBaseDirProvider = cacheBaseDirProvider,
       _cacheHttpClient = cacheHttpClient ?? http.Client();

  Future<ObjStoreObject> uploadBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final cfg = _configService.config;
    if (cfg == null || cfg.type == ObjStoreType.none) {
      throw const ObjStoreNotConfiguredException();
    }

    return uploadBytesWithConfig(
      config: cfg,
      secrets: _configService.qiniuSecrets,
      bytes: bytes,
      filename: filename,
    );
  }

  Future<String> resolveUri({required String key}) async {
    final cfg = _configService.config;
    if (cfg == null || cfg.type == ObjStoreType.none) {
      throw const ObjStoreNotConfiguredException();
    }

    return resolveUriWithConfig(
      config: cfg,
      key: key,
      secrets: _configService.qiniuSecrets,
    );
  }

  /// 从本地“可用文件”中查询（不触发下载）：
  /// - 本地存储：尝试 `baseDir/key`（兼容未配置时也能用缓存/本地文件展示）
  /// - 云存储：尝试下载缓存目录（key -> hash.ext）
  /// - key 若是 URL：会尝试按 URL path 归一化后查询缓存
  ///
  /// 找不到返回 null，不抛异常。
  Future<File?> getCachedFile({required String key}) async {
    final normalizedKey = _normalizeCacheKey(key);
    if (normalizedKey.isEmpty) return null;

    final memory = _memoryCache[normalizedKey];
    if (memory != null && memory.existsSync()) return memory;

    final baseDirProvider = _cacheBaseDirProvider;
    if (baseDirProvider == null) return null;

    // 1) key 为 file://：直接返回
    final parsed = Uri.tryParse(key.trim());
    if (parsed != null && parsed.scheme == 'file') {
      final f = File.fromUri(parsed);
      if (f.existsSync()) {
        _memoryCache[normalizedKey] = f;
        return f;
      }
    }

    // 2) 尝试本地存储文件（baseDir/key）
    final local = await _localFileIfExists(
      baseDirProvider: baseDirProvider,
      objectKey: normalizedKey,
    );
    if (local != null) {
      _memoryCache[normalizedKey] = local;
      return local;
    }

    // 3) 尝试下载缓存文件
    final cached = await _cacheFileIfExists(
      baseDirProvider: baseDirProvider,
      cacheKey: normalizedKey,
    );
    if (cached != null) {
      _memoryCache[normalizedKey] = cached;
      return cached;
    }
    return null;
  }

  /// 查询并确保可用文件（必要时会下载到缓存目录）。
  ///
  /// - 命中缓存时不会触发网络请求
  /// - 未命中且需要下载时：默认调用 [resolveUri] 获取下载链接
  /// - 若你已经有最终 URL（例如工具侧拿到的外部 URL），可通过 [resolveUriWhenMiss] 传入
  ///
  /// 返回 null 表示资源不可用或缓存能力未启用。
  Future<File?> ensureCachedFile({
    required String key,
    Duration timeout = const Duration(seconds: 12),
    Future<String> Function()? resolveUriWhenMiss,
  }) {
    final normalizedKey = _normalizeCacheKey(key);
    if (normalizedKey.isEmpty) return Future.value(null);

    // 先命中缓存，避免未配置时仍可离线使用
    final existing = _memoryCache[normalizedKey];
    if (existing != null && existing.existsSync()) {
      return Future.value(existing);
    }

    final inflight = _inflightCache[normalizedKey];
    if (inflight != null) return inflight;

    final future = _ensureCachedFileInner(
      key: key,
      normalizedKey: normalizedKey,
      timeout: timeout,
      resolveUriWhenMiss: resolveUriWhenMiss,
    );
    _inflightCache[normalizedKey] = future;
    future
        .whenComplete(() => _inflightCache.remove(normalizedKey))
        .catchError((_) => null);
    return future;
  }

  Future<File?> _ensureCachedFileInner({
    required String key,
    required String normalizedKey,
    required Duration timeout,
    required Future<String> Function()? resolveUriWhenMiss,
  }) async {
    final cached = await getCachedFile(key: normalizedKey);
    if (cached != null) return cached;

    final baseDirProvider = _cacheBaseDirProvider;
    if (baseDirProvider == null) {
      // 未启用磁盘缓存：退化为“尽力返回本地 file://”
      final uriText =
          (await (resolveUriWhenMiss ?? (() => resolveUri(key: key)))()).trim();
      final uri = Uri.tryParse(uriText);
      if (uri != null && uri.scheme == 'file') {
        final f = File.fromUri(uri);
        if (f.existsSync()) {
          _memoryCache[normalizedKey] = f;
          return f;
        }
      }
      return null;
    }

    final uriText =
        (await (resolveUriWhenMiss ?? (() => resolveUri(key: key)))()).trim();
    if (uriText.isEmpty) return null;

    final uri = Uri.tryParse(uriText);
    if (uri != null && uri.scheme == 'file') {
      final f = File.fromUri(uri);
      if (f.existsSync()) {
        _memoryCache[normalizedKey] = f;
        return f;
      }
      return null;
    }

    // 下载并写入缓存（key 的归一化保证 token 变化不影响缓存命中）
    final file = await _cacheFileForKey(
      baseDirProvider: baseDirProvider,
      cacheKey: normalizedKey,
      extHint: _extractExt(uriText),
    );
    final tmp = File('${file.path}.tmp');
    if (tmp.existsSync()) {
      try {
        tmp.deleteSync();
      } catch (_) {}
    }

    final resp = await _cacheHttpClient
        .get(Uri.parse(uriText))
        .timeout(timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    if (resp.bodyBytes.isEmpty) return null;

    await tmp.writeAsBytes(resp.bodyBytes, flush: true);
    await tmp.rename(file.path);
    _memoryCache[normalizedKey] = file;
    return file;
  }

  Future<ObjStoreObject> uploadBytesWithConfig({
    required ObjStoreConfig config,
    required Uint8List bytes,
    required String filename,
    ObjStoreQiniuSecrets? secrets,
  }) async {
    switch (config.type) {
      case ObjStoreType.none:
        throw const ObjStoreNotConfiguredException();
      case ObjStoreType.local:
        final stored = await _localStore.saveBytes(
          bytes: bytes,
          filename: filename,
        );
        return ObjStoreObject(
          storageType: ObjStoreType.local,
          key: stored.key,
          uri: stored.uri,
        );
      case ObjStoreType.qiniu:
        if (!config.isValid) {
          throw const ObjStoreConfigInvalidException(
            '七牛云配置不完整，请检查 Bucket / 域名 / 上传域名',
          );
        }
        if (secrets == null || !secrets.isValid) {
          throw const ObjStoreNotConfiguredException('请先填写七牛云 AK/SK');
        }
        final key = ObjStoreKey.generate(
          filename: filename,
          prefix: config.keyPrefix ?? '',
        );
        final result = await _qiniuClient.uploadBytes(
          accessKey: secrets.accessKey,
          secretKey: secrets.secretKey,
          bucket: config.bucket!.trim(),
          uploadHost: config.uploadHost!.trim(),
          key: key,
          bytes: bytes,
          filename: filename,
        );
        final isPrivate = config.qiniuIsPrivate ?? false;
        final useHttps = config.qiniuUseHttps ?? true;
        final url = isPrivate
            ? _qiniuClient.buildPrivateUrl(
                domain: config.domain!.trim(),
                key: result.key,
                accessKey: secrets.accessKey,
                secretKey: secrets.secretKey,
                deadlineUnixSeconds: _qiniuPrivateDeadlineUnixSeconds(),
                useHttps: useHttps,
              )
            : _qiniuClient.buildPublicUrl(
                domain: config.domain!.trim(),
                key: result.key,
                useHttps: useHttps,
              );
        return ObjStoreObject(
          storageType: ObjStoreType.qiniu,
          key: result.key,
          uri: url,
        );
    }
  }

  Future<String> resolveUriWithConfig({
    required ObjStoreConfig config,
    required String key,
    ObjStoreQiniuSecrets? secrets,
  }) async {
    final trimmed = key.trim();
    final parsed = Uri.tryParse(trimmed);
    final isFileUri = parsed != null && parsed.scheme == 'file';
    final isHttpUrl =
        parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https');

    switch (config.type) {
      case ObjStoreType.none:
        throw const ObjStoreNotConfiguredException();
      case ObjStoreType.local:
        // 兼容历史数据：字段可能误存为 file://（或外部链接）。
        if (isFileUri || isHttpUrl) return trimmed;

        final uri = await _localStore.resolveUri(key: key);
        if (uri == null) {
          throw const ObjStoreQueryException('本地文件不存在或已被清理');
        }
        return uri;
      case ObjStoreType.qiniu:
        // 兼容历史数据：字段可能误存为 file://（或已拼好的 URL）。
        if (isFileUri) return trimmed;

        if (!config.isValid) {
          throw const ObjStoreConfigInvalidException('七牛云配置不完整，请检查访问域名');
        }
        final isPrivate = config.qiniuIsPrivate ?? false;
        final useHttps = config.qiniuUseHttps ?? true;

        // 如果 key 已经是 URL：
        // - 公有空间：直接使用该 URL
        // - 私有空间：提取 objectKey 后重新签名，避免导入后 token 过期导致无法下载
        if (isHttpUrl) {
          if (!isPrivate) return trimmed;
          if (secrets == null || !secrets.isValid) {
            throw const ObjStoreNotConfiguredException('私有空间查询需要填写七牛云 AK/SK');
          }

          final objectKey = parsed.pathSegments.join('/');
          return _qiniuClient.buildPrivateUrl(
            domain: config.domain!.trim(),
            key: objectKey,
            accessKey: secrets.accessKey,
            secretKey: secrets.secretKey,
            deadlineUnixSeconds: _qiniuPrivateDeadlineUnixSeconds(),
            useHttps: useHttps,
          );
        }

        if (!isPrivate) {
          return _qiniuClient.buildPublicUrl(
            domain: config.domain!.trim(),
            key: key,
            useHttps: useHttps,
          );
        }
        if (secrets == null || !secrets.isValid) {
          throw const ObjStoreNotConfiguredException('私有空间查询需要填写七牛云 AK/SK');
        }
        return _qiniuClient.buildPrivateUrl(
          domain: config.domain!.trim(),
          key: key,
          accessKey: secrets.accessKey,
          secretKey: secrets.secretKey,
          deadlineUnixSeconds: _qiniuPrivateDeadlineUnixSeconds(),
          useHttps: useHttps,
        );
    }
  }

  Future<bool> probeWithConfig({
    required ObjStoreConfig config,
    required String key,
    Duration timeout = const Duration(seconds: 8),
    ObjStoreQiniuSecrets? secrets,
  }) async {
    switch (config.type) {
      case ObjStoreType.none:
        throw const ObjStoreNotConfiguredException();
      case ObjStoreType.local:
        final uri = await _localStore.resolveUri(key: key);
        return uri != null;
      case ObjStoreType.qiniu:
        final url = await resolveUriWithConfig(
          config: config,
          key: key,
          secrets: secrets,
        );
        return _qiniuClient.probePublicUrl(url: url, timeout: timeout);
    }
  }

  static int _defaultPrivateDeadline() {
    final now = DateTime.now().toUtc();
    return now.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  }

  static String _normalizeCacheKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed.replaceAll('\\', '/');

    if (uri.scheme == 'file') return trimmed;

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final segments = uri.pathSegments
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (segments.isEmpty) return '';
      final mediaIndex = segments.indexOf('media');
      if (mediaIndex >= 0) {
        return segments.sublist(mediaIndex).join('/');
      }
      return segments.join('/');
    }

    return trimmed.replaceAll('\\', '/');
  }

  static String _extractExt(String keyOrUrl) {
    final trimmed = keyOrUrl.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'file')) {
      return p.extension(uri.path);
    }

    final noQuery = trimmed.split('?').first.split('#').first;
    return p.extension(noQuery);
  }

  static String _normalizeExt(String raw) {
    final ext = raw.trim();
    if (ext.isEmpty) return '.img';
    final cleaned = ext.split('?').first.split('#').first.trim();
    if (cleaned.isEmpty) return '.img';
    if (cleaned.startsWith('.')) return cleaned;
    return '.$cleaned';
  }

  static Future<File?> _localFileIfExists({
    required BaseDirProvider baseDirProvider,
    required String objectKey,
  }) async {
    if (objectKey.isEmpty) return null;
    if (objectKey.startsWith('http://') || objectKey.startsWith('https://')) {
      return null;
    }
    final baseDir = await baseDirProvider();
    final safeKey = objectKey.replaceAll('\\', '/').trim();
    if (safeKey.isEmpty) return null;
    if (p.isAbsolute(safeKey)) return null;

    final base = p.normalize(baseDir.path);
    final path = p.normalize(p.join(base, safeKey));
    if (!p.isWithin(base, path)) return null;
    final f = File(path);
    if (!f.existsSync()) return null;
    return f;
  }

  static Future<File?> _cacheFileIfExists({
    required BaseDirProvider baseDirProvider,
    required String cacheKey,
  }) async {
    final f = await _cacheFileForKey(
      baseDirProvider: baseDirProvider,
      cacheKey: cacheKey,
      extHint: _extractExt(cacheKey),
    );
    return f.existsSync() ? f : null;
  }

  static Future<File> _cacheFileForKey({
    required BaseDirProvider baseDirProvider,
    required String cacheKey,
    required String extHint,
  }) async {
    final baseDir = await baseDirProvider();
    final dir = Directory(p.join(baseDir.path, 'cache'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    await ensureNoMediaFileInDir(dir.path);

    final ext = _normalizeExt(extHint);
    final digest = sha1.convert(utf8.encode(cacheKey)).toString();
    return File(p.join(dir.path, '$digest$ext'));
  }
}
