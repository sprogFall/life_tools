import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/app_build_info.dart';
import 'package:life_tools/core/update/app_update.dart';
import 'package:life_tools/pages/about_page.dart';

void main() {
  group('AboutPage', () {
    testWidgets('应展示基础功能介绍', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutPage()));
      await tester.pumpAndSettle();

      expect(find.text('关于'), findsOneWidget);
      expect(find.text('版本更新'), findsOneWidget);
      expect(find.text('当前版本 ${AppBuildInfo.version}'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('about_check_update_button')),
        findsOneWidget,
      );
      expect(find.text('基础功能'), findsOneWidget);
      expect(find.textContaining('工作记录'), findsOneWidget);
      expect(find.textContaining('囤货助手'), findsOneWidget);
      expect(find.textContaining('胡闹厨房'), findsOneWidget);
      expect(find.textContaining('数据同步'), findsOneWidget);
    });

    testWidgets('点击提交编号应悬浮显示提交信息并自动隐藏', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutPage()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('about_commit_floating_message')),
        findsNothing,
      );
      expect(
        find.text('commit ${AppBuildInfo.shortCommitSha}'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('about_commit_hash_tap_target')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('about_commit_floating_message')),
        findsOneWidget,
      );
      expect(find.text(AppBuildInfo.commitMessage), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('about_commit_floating_message')),
        findsNothing,
      );
    });

    testWidgets('手动检查更新应展示立即更新、稍后与忽略入口', (tester) async {
      final service = _FakeUpdateService(
        result: AppUpdateCheckResult.updateAvailable(_release),
      );
      await tester.pumpWidget(
        MaterialApp(home: AboutPage(updateService: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('about_check_update_button')));
      await tester.pumpAndSettle();

      expect(find.text('发现新版本 9.9.9'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
      expect(find.text('稍后'), findsOneWidget);
      expect(find.text('忽略此版本'), findsOneWidget);
    });

    testWidgets('点击忽略此版本应记录版本号', (tester) async {
      final service = _FakeUpdateService(
        result: AppUpdateCheckResult.updateAvailable(_release),
      );
      await tester.pumpWidget(
        MaterialApp(home: AboutPage(updateService: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('about_check_update_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('忽略此版本'));
      await tester.pumpAndSettle();

      expect(service.ignoredVersion, '9.9.9');
    });
  });
}

final _release = AppReleaseInfo(
  tagName: 'v9.9.9',
  version: '9.9.9',
  name: 'v9.9.9',
  body: '更新说明',
  pageUrl: Uri.parse(
    'https://github.com/sprogFall/life_tools/releases/tag/v9.9.9',
  ),
  apkDownloadUrl: Uri.parse(
    'https://github.com/sprogFall/life_tools/releases/download/v9.9.9/life_tools.apk',
  ),
);

class _FakeUpdateService extends AppUpdateService {
  final AppUpdateCheckResult result;
  String? ignoredVersion;

  _FakeUpdateService({required this.result});

  @override
  Future<AppUpdateCheckResult> checkForUpdate({
    bool includeIgnored = false,
  }) async {
    expect(includeIgnored, isTrue);
    return result;
  }

  @override
  Future<void> ignoreVersion(String version) async {
    ignoredVersion = version;
  }
}
