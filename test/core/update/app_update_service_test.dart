import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_tools/core/app_build_info.dart';
import 'package:life_tools/core/update/app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppVersion', () {
    test('当前构建版本应可用于更新比较', () {
      expect(AppVersion.normalizeTag(AppBuildInfo.version), isNotNull);
    });

    test('应支持 v 前缀 tag 并比较语义化版本', () {
      expect(AppVersion.normalizeTag('v1.2.3'), '1.2.3');
      expect(AppVersion.parse('v1.2.4').isNewerThan('1.2.3'), isTrue);
      expect(AppVersion.parse('v1.2.3').isNewerThan('1.2.3'), isFalse);
      expect(AppVersion.parse('v1.2.2').isNewerThan('1.2.3'), isFalse);
      expect(
        AppVersion.parse('1.2.3-beta.259').isNewerThan('1.2.3-beta.258'),
        isTrue,
      );
      expect(
        AppVersion.parse('1.2.3-beta.258').isNewerThan('1.2.3-beta.259'),
        isFalse,
      );
      expect(AppVersion.parse('1.2.3').isNewerThan('1.2.3-beta.259'), isTrue);
    });

    test('非版本 tag 不应被识别为客户端更新', () {
      expect(AppVersion.normalizeTag('apk-main-abcdef'), isNull);
      expect(AppVersion.normalizeTag('release'), isNull);
    });

    test('客户端 Release tag 必须带 v 前缀', () {
      expect(AppVersion.normalizeReleaseTag('v1.2.3'), '1.2.3');
      expect(AppVersion.normalizeReleaseTag('1.2.3'), isNull);
    });

    test('应按规范化版本判断同版本', () {
      expect(AppVersion.isSame('v1.2.3', '1.2.3'), isTrue);
      expect(AppVersion.isSame('1.2.3-beta.4', 'v1.2.3-beta.4'), isTrue);
      expect(AppVersion.isSame('1.2.3-beta.4', '1.2.3'), isFalse);
    });
  });

  group('AppReleaseParser', () {
    test('应从正式 GitHub Release 中提取 APK 安装包', () {
      final release = AppReleaseParser.parse({
        'tag_name': 'v1.2.3',
        'name': 'v1.2.3',
        'body': '更新说明',
        'html_url':
            'https://github.com/sprogFall/life_tools/releases/tag/v1.2.3',
        'draft': false,
        'prerelease': false,
        'published_at': '2026-06-02T00:00:00Z',
        'assets': [
          {
            'name': 'life_tools-release-v1.2.3.apk',
            'size': 1024,
            'browser_download_url':
                'https://github.com/sprogFall/life_tools/releases/download/v1.2.3/life_tools-release-v1.2.3.apk',
          },
        ],
      });

      expect(release, isNotNull);
      expect(release!.version, '1.2.3');
      expect(release.apkSize, 1024);
      expect(release.apkDownloadUrl.path, contains('.apk'));
    });

    test('应忽略预发布与没有 APK 的 Release', () {
      expect(
        AppReleaseParser.parse({
          'tag_name': 'v1.2.3',
          'html_url': 'https://example.com',
          'prerelease': true,
          'assets': const [],
        }),
        isNull,
      );
      expect(
        AppReleaseParser.parse({
          'tag_name': 'v1.2.3',
          'html_url': 'https://example.com',
          'assets': const [],
        }),
        isNull,
      );
      expect(
        AppReleaseParser.parse({
          'tag_name': '1.2.3',
          'html_url': 'https://example.com',
          'assets': [
            {
              'name': 'life_tools.apk',
              'browser_download_url': 'https://example.com/life_tools.apk',
            },
          ],
        }),
        isNull,
      );
    });

    test('应从预发布 Release body 中提取完整体验版版本号', () {
      final release = AppReleaseParser.parse({
        'tag_name': 'apk-main-abcdef123456',
        'name': 'APK release main abcdef123456',
        'body': '''
Automated release APK build.

Version: 1.2.3-beta.456
Ref: main

Commit: abcdef1234567890
''',
        'html_url':
            'https://github.com/sprogFall/life_tools/releases/tag/apk-main-abcdef123456',
        'draft': false,
        'prerelease': true,
        'published_at': '2026-06-02T00:00:00Z',
        'assets': [
          {
            'name': 'life_tools-release-abcdef123456.apk',
            'size': 1024,
            'browser_download_url':
                'https://github.com/sprogFall/life_tools/releases/download/apk-main-abcdef123456/life_tools-release-abcdef123456.apk',
          },
        ],
      });

      expect(release, isNotNull);
      expect(release!.version, '1.2.3-beta.456');
      expect(release.isPrerelease, isTrue);
    });
  });

  group('AppUpdateService', () {
    test('latest release 新于当前版本时返回可更新', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AppUpdateService(
        client: MockClient((_) async => _jsonResponse(_releaseJson('v9.9.9'))),
      );

      final release = await service.fetchLatestRelease();
      expect(release, isNotNull);
      expect(release!.version, '9.9.9');

      final result = await service.checkForUpdate();

      expect(result.availability, AppUpdateAvailability.updateAvailable);
      expect(result.release!.version, '9.9.9');
    });

    test('被忽略的版本默认不再提示，但主动检查可以绕过忽略', () async {
      SharedPreferences.setMockInitialValues({
        'app_update_ignored_version': '9.9.9',
      });
      final service = AppUpdateService(
        client: MockClient((_) async => _jsonResponse(_releaseJson('v9.9.9'))),
      );

      final normal = await service.checkForUpdate();
      final manual = await service.checkForUpdate(includeIgnored: true);

      expect(normal.availability, AppUpdateAvailability.ignored);
      expect(manual.availability, AppUpdateAvailability.updateAvailable);
    });

    test('体验版检查正式更新时相同核心版本也应返回正式包', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AppUpdateService(
        client: MockClient((_) async => _jsonResponse(_releaseJson('v1.2.3'))),
      );

      final result = await service.checkForUpdate(
        currentVersion: '1.2.3-beta.456',
        currentIsPrerelease: true,
      );

      expect(result.availability, AppUpdateAvailability.updateAvailable);
      expect(result.release!.version, '1.2.3');
    });

    test('体验版核心版本高于正式版时也应返回最新正式包', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AppUpdateService(
        client: MockClient((_) async => _jsonResponse(_releaseJson('v1.2.3'))),
      );

      final result = await service.checkForUpdate(
        currentVersion: '1.2.4-beta.456',
        currentIsPrerelease: true,
      );

      expect(result.availability, AppUpdateAvailability.updateAvailable);
      expect(result.release!.version, '1.2.3');
    });

    test('正式版检查正式更新时相同版本应返回已是最新', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AppUpdateService(
        client: MockClient((_) async => _jsonResponse(_releaseJson('v1.2.3'))),
      );

      final result = await service.checkForUpdate(
        currentVersion: '1.2.3',
        currentIsPrerelease: false,
      );

      expect(result.availability, AppUpdateAvailability.upToDate);
    });

    test('下载 APK 时应保存到缓存目录并汇报进度', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'life_tools_update_test_',
      );
      final service = AppUpdateService(
        client: MockClient((request) async {
          expect(request.url.toString(), contains('.apk'));
          return http.Response.bytes([1, 2, 3, 4], 200);
        }),
        cacheDirProvider: () async => tempDir,
      );
      final progress = <int>[];

      final file = await service.downloadApk(
        AppReleaseInfo(
          tagName: 'v9.9.9',
          version: '9.9.9',
          name: 'v9.9.9',
          body: '',
          pageUrl: Uri.parse('https://example.com/release'),
          apkDownloadUrl: Uri.parse('https://example.com/app.apk'),
          sha256: null, // 无校验和，跳过校验
        ),
        onProgress: (received, _) => progress.add(received),
      );

      expect(await file.readAsBytes(), [1, 2, 3, 4]);
      expect(file.path, contains('life_tools-9.9.9.apk'));
      expect(progress.last, 4);
      await tempDir.delete(recursive: true);
    });

    test('下载 APK 时应验证 SHA-256 校验和', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'life_tools_update_test_',
      );
      final testData = [1, 2, 3, 4];
      // SHA-256 of [1, 2, 3, 4]
      const validSha256 =
          '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a';
      const invalidSha256 = 'deadbeef';

      final service = AppUpdateService(
        client: MockClient((request) async {
          return http.Response.bytes(testData, 200);
        }),
        cacheDirProvider: () async => tempDir,
      );

      // 正确的校验和应该成功
      final validFile = await service.downloadApk(
        AppReleaseInfo(
          tagName: 'v9.9.9',
          version: '9.9.9',
          name: 'v9.9.9',
          body: '',
          pageUrl: Uri.parse('https://example.com/release'),
          apkDownloadUrl: Uri.parse('https://example.com/app.apk'),
          sha256: validSha256,
        ),
      );
      expect(await validFile.exists(), isTrue);
      await validFile.delete();

      // 错误的校验和应该抛出异常并删除文件
      expect(
        () => service.downloadApk(
          AppReleaseInfo(
            tagName: 'v9.9.9',
            version: '9.9.9',
            name: 'v9.9.9',
            body: '',
            pageUrl: Uri.parse('https://example.com/release'),
            apkDownloadUrl: Uri.parse('https://example.com/app2.apk'),
            sha256: invalidSha256,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      await tempDir.delete(recursive: true);
    });
  });
}

Map<String, Object?> _releaseJson(String tag) {
  return {
    'tag_name': tag,
    'name': tag,
    'body': '更新说明',
    'html_url': 'https://github.com/sprogFall/life_tools/releases/tag/$tag',
    'draft': false,
    'prerelease': false,
    'published_at': '2026-06-02T00:00:00Z',
    'assets': [
      {
        'name': 'life_tools-release-$tag.apk',
        'size': 1024,
        'browser_download_url':
            'https://github.com/sprogFall/life_tools/releases/download/$tag/life_tools-release-$tag.apk',
      },
    ],
  };
}

http.Response _jsonResponse(Object body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
