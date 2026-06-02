import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_build_info.dart';
import '../utils/dev_log.dart';

enum AppUpdateAvailability { updateAvailable, upToDate, ignored, unavailable }

class AppUpdateCheckResult {
  final AppUpdateAvailability availability;
  final AppReleaseInfo? release;
  final String? message;

  const AppUpdateCheckResult._(this.availability, this.release, this.message);

  const AppUpdateCheckResult.updateAvailable(AppReleaseInfo release)
    : this._(AppUpdateAvailability.updateAvailable, release, null);

  const AppUpdateCheckResult.upToDate()
    : this._(AppUpdateAvailability.upToDate, null, null);

  const AppUpdateCheckResult.ignored(AppReleaseInfo release)
    : this._(AppUpdateAvailability.ignored, release, null);

  const AppUpdateCheckResult.unavailable(String message)
    : this._(AppUpdateAvailability.unavailable, null, message);
}

class AppReleaseInfo {
  final String tagName;
  final String version;
  final String name;
  final String body;
  final Uri pageUrl;
  final Uri apkDownloadUrl;
  final int? apkSize;
  final DateTime? publishedAt;

  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.pageUrl,
    required this.apkDownloadUrl,
    this.apkSize,
    this.publishedAt,
  });
}

class AppUpdateService {
  static const String defaultRepository = 'sprogFall/life_tools';
  static const String _ignoredVersionKey = 'app_update_ignored_version';
  static const MethodChannel _installerChannel = MethodChannel(
    'life_tools/app_update',
  );

  final http.Client _client;
  final String repository;
  final Future<SharedPreferences> Function() _prefsProvider;
  final Future<Directory> Function() _cacheDirProvider;

  AppUpdateService({
    http.Client? client,
    this.repository = defaultRepository,
    Future<SharedPreferences> Function()? prefsProvider,
    Future<Directory> Function()? cacheDirProvider,
  }) : _client = client ?? http.Client(),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _cacheDirProvider = cacheDirProvider ?? getTemporaryDirectory;

  Future<AppUpdateCheckResult> checkForUpdate({
    bool includeIgnored = false,
  }) async {
    try {
      final release = await fetchLatestRelease();
      if (release == null) {
        return const AppUpdateCheckResult.unavailable('没有找到可下载的正式安装包');
      }

      final currentVersion = AppBuildInfo.version;
      if (!AppVersion.parse(release.version).isNewerThan(currentVersion)) {
        return const AppUpdateCheckResult.upToDate();
      }

      if (!includeIgnored && await isIgnored(release.version)) {
        return AppUpdateCheckResult.ignored(release);
      }

      return AppUpdateCheckResult.updateAvailable(release);
    } catch (error, stackTrace) {
      devLog('检查 GitHub 更新失败', error: error, stackTrace: stackTrace);
      return const AppUpdateCheckResult.unavailable('检查更新失败，请稍后再试');
    }
  }

  Future<AppReleaseInfo?> fetchLatestRelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$repository/releases/latest',
    );
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('GitHub Release 请求失败: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('GitHub Release 响应格式错误');
    }
    return AppReleaseParser.parse(decoded);
  }

  Future<File> downloadApk(
    AppReleaseInfo release, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final request = http.Request('GET', release.apkDownloadUrl);
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('安装包下载失败: ${response.statusCode}');
    }

    final cacheDir = await _cacheDirProvider();
    final updateDir = Directory(p.join(cacheDir.path, 'updates'));
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    final file = File(
      p.join(updateDir.path, 'life_tools-${release.version}.apk'),
    );
    final sink = file.openWrite();
    var received = 0;
    final total = response.contentLength;

    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }

    return file;
  }

  Future<void> installApk(File apkFile) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('当前平台暂不支持应用内安装 APK');
    }
    await _installerChannel.invokeMethod<void>('installApk', {
      'path': apkFile.path,
    });
  }

  Future<void> ignoreVersion(String version) async {
    final prefs = await _prefsProvider();
    await prefs.setString(_ignoredVersionKey, version);
  }

  Future<bool> isIgnored(String version) async {
    final prefs = await _prefsProvider();
    return prefs.getString(_ignoredVersionKey) == version;
  }

  Future<void> clearIgnoredVersion() async {
    final prefs = await _prefsProvider();
    await prefs.remove(_ignoredVersionKey);
  }

  void close() => _client.close();
}

class AppReleaseParser {
  AppReleaseParser._();

  static AppReleaseInfo? parse(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) return null;

    final tagName = (json['tag_name'] as String? ?? '').trim();
    final version = AppVersion.normalizeReleaseTag(tagName);
    if (version == null) return null;

    final assets = json['assets'];
    if (assets is! List) return null;

    Map<String, dynamic>? apkAsset;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkAsset = asset;
        break;
      }
    }
    if (apkAsset == null) return null;

    final downloadUrl = apkAsset['browser_download_url'] as String?;
    final pageUrl = json['html_url'] as String?;
    if (downloadUrl == null || pageUrl == null) return null;

    return AppReleaseInfo(
      tagName: tagName,
      version: version,
      name: (json['name'] as String? ?? tagName).trim(),
      body: (json['body'] as String? ?? '').trim(),
      pageUrl: Uri.parse(pageUrl),
      apkDownloadUrl: Uri.parse(downloadUrl),
      apkSize: (apkAsset['size'] as num?)?.toInt(),
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
}

class AppVersion implements Comparable<AppVersion> {
  final List<int> parts;

  AppVersion(this.parts);

  factory AppVersion.parse(String raw) {
    final normalized = normalizeTag(raw) ?? '0.0.0';
    final core = normalized.split(RegExp(r'[-+]')).first;
    final parts = core
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: true);
    while (parts.length < 3) {
      parts.add(0);
    }
    return AppVersion(parts.take(3).toList());
  }

  static String? normalizeTag(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final normalized = value.startsWith(RegExp('[vV]'))
        ? value.substring(1)
        : value;
    return _normalizeVersion(normalized);
  }

  static String? normalizeReleaseTag(String raw) {
    final value = raw.trim();
    if (!value.startsWith(RegExp('[vV]'))) return null;
    return normalizeTag(value);
  }

  static String? _normalizeVersion(String raw) {
    final normalized = raw.trim();
    if (!RegExp(r'^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$').hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  bool isNewerThan(String other) => compareTo(AppVersion.parse(other)) > 0;

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final diff = parts[i].compareTo(other.parts[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }
}
