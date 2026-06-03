import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

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
  final String? sha256; // APK SHA-256 校验和（可选）
  final bool isPrerelease; // 是否为预发布版本（体验版）
  final String? commitMessage; // 提交信息
  final String? commitSha; // 提交 SHA

  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.pageUrl,
    required this.apkDownloadUrl,
    this.apkSize,
    this.publishedAt,
    this.sha256,
    this.isPrerelease = false,
    this.commitMessage,
    this.commitSha,
  });
}

class AppUpdateService {
  static const String defaultRepository = 'sprogFall/life_tools';
  static const String _ignoredVersionKey = 'app_update_ignored_version';
  static const Duration _defaultTimeout = Duration(seconds: 30);
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
    String? currentVersion,
    bool? currentIsPrerelease,
  }) async {
    try {
      final release = await fetchLatestRelease();
      if (release == null) {
        return const AppUpdateCheckResult.unavailable('没有找到可下载的正式安装包');
      }

      final effectiveCurrentVersion = currentVersion ?? AppBuildInfo.version;
      final effectiveCurrentIsPrerelease =
          currentIsPrerelease ?? AppBuildInfo.isPreRelease;
      final shouldOfferPrereleaseToRelease =
          effectiveCurrentIsPrerelease && !release.isPrerelease;
      if (!shouldOfferPrereleaseToRelease &&
          !AppVersion.parse(
            release.version,
          ).isNewerThan(effectiveCurrentVersion)) {
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
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(_defaultTimeout);

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

  /// 获取最新的预发布版本（体验版）
  /// 包含所有成功构建的 APK，不限制是否为正式 tag
  Future<AppReleaseInfo?> fetchLatestPrerelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$repository/releases',
      {'per_page': '50'}, // GitHub 返回顺序不保证等同于发布时间，扩大扫描范围
    );
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(_defaultTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('GitHub Release 请求失败: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('GitHub Release 响应格式错误');
    }

    AppReleaseInfo? latest;
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;

      // 跳过正式发布版本，只要预发布
      if (item['prerelease'] != true) continue;

      final release = AppReleaseParser.parse(item);
      if (release == null) continue;
      if (latest == null || _isNewerPrerelease(release, latest)) {
        latest = release;
      }
    }

    return latest;
  }

  bool _isNewerPrerelease(AppReleaseInfo candidate, AppReleaseInfo current) {
    final versionDiff = AppVersion.parse(
      candidate.version,
    ).compareTo(AppVersion.parse(current.version));
    if (versionDiff != 0) return versionDiff > 0;

    final candidateTime = candidate.publishedAt;
    final currentTime = current.publishedAt;
    if (candidateTime != null && currentTime != null) {
      return candidateTime.isAfter(currentTime);
    }
    if (candidateTime != null) return true;
    return false;
  }

  Future<File> downloadApk(
    AppReleaseInfo release, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final request = http.Request('GET', release.apkDownloadUrl);
    final response = await _client.send(request).timeout(_defaultTimeout);
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
    var lastCallTime = DateTime.now();
    const throttle = Duration(milliseconds: 100);

    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);

        // 限流：避免过多 UI 更新
        final now = DateTime.now();
        if (now.difference(lastCallTime) > throttle || received == total) {
          onProgress?.call(received, total);
          lastCallTime = now;
        }
      }
    } finally {
      await sink.close();
    }

    // 确保最终进度回调
    if (received > 0) {
      onProgress?.call(received, total);
    }

    // 验证文件完整性
    if (release.sha256 != null) {
      final actualHash = await _computeSha256(file);
      final expectedHash = release.sha256!.toLowerCase();
      if (actualHash != expectedHash) {
        await file.delete();
        throw StateError('安装包校验失败，文件可能已损坏');
      }
    }

    return file;
  }

  /// 计算文件的 SHA-256 哈希值
  Future<String> _computeSha256(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
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
    // 跳过草稿，但保留预发布版本
    if (json['draft'] == true) return null;

    final tagName = (json['tag_name'] as String? ?? '').trim();
    final isPrerelease = json['prerelease'] == true;

    // 对于预发布版本，tag 格式可能不是 vX.Y.Z，需要特殊处理
    final body = (json['body'] as String? ?? '').trim();
    String? version;
    if (isPrerelease) {
      // 尝试从 tag 提取版本号，如 "apk-main-abc123" 提取不出来就用 tag 本身
      version = AppVersion.normalizeReleaseTag(tagName);
      // 如果提取失败，使用 name 中的版本号或 tag 本身
      version ??= _extractVersionFromName(json['name'] as String? ?? '');
      version ??= _extractVersionFromBody(body);
      version ??= tagName;
    } else {
      version = AppVersion.normalizeReleaseTag(tagName);
      if (version == null) return null;
    }

    final assets = json['assets'];
    if (assets is! List) return null;

    Map<String, dynamic>? apkAsset;
    String? sha256Hash;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkAsset = asset;
      } else if (name.endsWith('.apk.sha256')) {
        // 尝试提取 SHA-256（如果 Release 包含 .sha256 文件）
        // 注意：此处仅记录 URL，实际校验需要下载该文件
        // 暂不实现自动下载 .sha256 文件，留作后续优化
      }
    }
    if (apkAsset == null) return null;

    final downloadUrl = apkAsset['browser_download_url'] as String?;
    final pageUrl = json['html_url'] as String?;
    if (downloadUrl == null || pageUrl == null) return null;

    // 提取提交信息
    final commitMessage = _extractCommitMessage(body);
    final commitSha = _extractCommitSha(tagName, body);

    return AppReleaseInfo(
      tagName: tagName,
      version: version,
      name: (json['name'] as String? ?? tagName).trim(),
      body: body,
      pageUrl: Uri.parse(pageUrl),
      apkDownloadUrl: Uri.parse(downloadUrl),
      apkSize: (apkAsset['size'] as num?)?.toInt(),
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      sha256: sha256Hash,
      isPrerelease: isPrerelease,
      commitMessage: commitMessage,
      commitSha: commitSha,
    );
  }

  /// 从 release name 中提取版本号
  static String? _extractVersionFromName(String name) {
    final match = RegExp(
      r'\b(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\b',
    ).firstMatch(name);
    final version = match?.group(1);
    return version == null ? null : AppVersion.normalizeTag(version);
  }

  static String? _extractVersionFromBody(String body) {
    final versionLine = RegExp(
      r'^\s*Version:\s*([^\s]+)\s*$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(body);
    final version = versionLine?.group(1);
    if (version == null) return null;
    return AppVersion.normalizeTag(version);
  }

  /// 从 release body 中提取提交信息
  static String? _extractCommitMessage(String body) {
    if (body.isEmpty) return null;

    // 提取第一行作为提交信息（通常是 commit message）
    final firstLine = body.split('\n').first.trim();
    if (firstLine.isEmpty) return null;

    // 移除常见的前缀
    final cleaned = firstLine.replaceFirst(
      RegExp(
        r'^(commit|chore|feat|fix|docs|refactor):\s*',
        caseSensitive: false,
      ),
      '',
    );

    return cleaned.isEmpty ? null : cleaned;
  }

  /// 提取 commit SHA
  static String? _extractCommitSha(String tagName, String body) {
    // 从 tag 中提取，如 "apk-main-abc1234"
    final tagMatch = RegExp(r'-([0-9a-f]{7,40})$').firstMatch(tagName);
    if (tagMatch != null) return tagMatch.group(1);

    // 从 body 中提取
    final bodyMatch = RegExp(r'\b([0-9a-f]{7,40})\b').firstMatch(body);
    return bodyMatch?.group(1);
  }
}

class AppVersion implements Comparable<AppVersion> {
  final List<int> parts;
  final List<String> prereleaseParts;

  AppVersion(this.parts, {this.prereleaseParts = const []});

  factory AppVersion.parse(String raw) {
    final normalized = normalizeTag(raw) ?? '0.0.0';
    final withoutBuildMetadata = normalized.split('+').first;
    final prereleaseSeparator = withoutBuildMetadata.indexOf('-');
    final core = prereleaseSeparator >= 0
        ? withoutBuildMetadata.substring(0, prereleaseSeparator)
        : withoutBuildMetadata;
    final prerelease = prereleaseSeparator >= 0
        ? withoutBuildMetadata.substring(prereleaseSeparator + 1)
        : '';
    final prereleaseParts = prerelease.isNotEmpty
        ? prerelease
              .split('.')
              .where((part) => part.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final parts = core
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: true);
    while (parts.length < 3) {
      parts.add(0);
    }
    return AppVersion(parts.take(3).toList(), prereleaseParts: prereleaseParts);
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

  static bool isSame(String first, String second) {
    final normalizedFirst = normalizeTag(first);
    final normalizedSecond = normalizeTag(second);
    return normalizedFirst != null &&
        normalizedSecond != null &&
        normalizedFirst == normalizedSecond;
  }

  static bool isSameCore(String first, String second) {
    final normalizedFirst = normalizeTag(first);
    final normalizedSecond = normalizeTag(second);
    if (normalizedFirst == null || normalizedSecond == null) return false;
    return normalizedFirst.split(RegExp(r'[-+]')).first ==
        normalizedSecond.split(RegExp(r'[-+]')).first;
  }

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final diff = parts[i].compareTo(other.parts[i]);
      if (diff != 0) return diff;
    }
    if (prereleaseParts.isEmpty && other.prereleaseParts.isEmpty) return 0;
    if (prereleaseParts.isEmpty) return 1;
    if (other.prereleaseParts.isEmpty) return -1;

    final maxLength = prereleaseParts.length > other.prereleaseParts.length
        ? prereleaseParts.length
        : other.prereleaseParts.length;
    for (var i = 0; i < maxLength; i++) {
      if (i >= prereleaseParts.length) return -1;
      if (i >= other.prereleaseParts.length) return 1;
      final diff = _comparePrereleaseIdentifier(
        prereleaseParts[i],
        other.prereleaseParts[i],
      );
      if (diff != 0) return diff;
    }
    return 0;
  }

  static int _comparePrereleaseIdentifier(String first, String second) {
    final firstNumber = int.tryParse(first);
    final secondNumber = int.tryParse(second);
    if (firstNumber != null && secondNumber != null) {
      return firstNumber.compareTo(secondNumber);
    }
    if (firstNumber != null) return -1;
    if (secondNumber != null) return 1;
    return first.compareTo(second);
  }
}
