import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../core/utils/no_media.dart';

typedef OvercookedCacheBaseDirProvider = Future<Directory> Function();

class OvercookedImageCacheService {
  final OvercookedCacheBaseDirProvider _baseDirProvider;
  final http.Client _httpClient;

  final Map<String, Future<File?>> _inflight = {};
  final Map<String, File> _memoryCache = {};

  OvercookedImageCacheService({
    required OvercookedCacheBaseDirProvider baseDirProvider,
    http.Client? httpClient,
  }) : _baseDirProvider = baseDirProvider,
       _httpClient = httpClient ?? http.Client();

  File? getCachedFileSync({required String key}) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;
    return _memoryCache[trimmed];
  }

  Future<File?> getCachedFile({required String key}) async {
    final file = await _fileForKey(key: key);
    if (file.existsSync()) {
      _memoryCache[key.trim()] = file;
      return file;
    }
    return null;
  }

  Future<File?> ensureCached({
    required String key,
    required Future<String> Function() resolveUri,
    Duration timeout = const Duration(seconds: 12),
  }) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return Future.value(null);

    // 先检查内存缓存
    final memoryCached = _memoryCache[trimmed];
    if (memoryCached != null && memoryCached.existsSync()) {
      return Future.value(memoryCached);
    }

    final existingFuture = _inflight[trimmed];
    if (existingFuture != null) return existingFuture;

    final future = _ensureCachedInner(
      key: trimmed,
      resolveUri: resolveUri,
      timeout: timeout,
    );
    _inflight[trimmed] = future;
    future.whenComplete(() => _inflight.remove(trimmed));
    return future;
  }

  Future<File?> _ensureCachedInner({
    required String key,
    required Future<String> Function() resolveUri,
    required Duration timeout,
  }) async {
    final cached = await getCachedFile(key: key);
    if (cached != null) return cached;

    final uriText = (await resolveUri()).trim();
    if (uriText.isEmpty) return null;

    final uri = Uri.tryParse(uriText);
    if (uri != null && uri.scheme == 'file') {
      final f = File.fromUri(uri);
      if (f.existsSync()) {
        _memoryCache[key] = f;
        return f;
      }
      return null;
    }

    final resp = await _httpClient.get(Uri.parse(uriText)).timeout(timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    if (resp.bodyBytes.isEmpty) return null;

    final file = await _fileForKey(key: key);
    final tmp = File('${file.path}.tmp');
    if (tmp.existsSync()) {
      try {
        tmp.deleteSync();
      } catch (_) {}
    }
    await tmp.writeAsBytes(resp.bodyBytes, flush: true);
    await tmp.rename(file.path);
    _memoryCache[key] = file;
    return file;
  }

  Future<File> _fileForKey({required String key}) async {
    final baseDir = await _baseDirProvider();
    final dir = Directory(p.join(baseDir.path, 'overcooked_image_cache'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    await ensureNoMediaFileInDir(dir.path);

    final ext = _normalizeExt(p.extension(key));
    final digest = sha1.convert(utf8.encode(key)).toString();
    return File(p.join(dir.path, '$digest$ext'));
  }

  static String _normalizeExt(String raw) {
    final ext = raw.trim();
    if (ext.isEmpty) return '.img';
    if (ext.startsWith('.')) return ext;
    return '.$ext';
  }
}
