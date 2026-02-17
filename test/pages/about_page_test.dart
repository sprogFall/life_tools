import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/app_build_info.dart';
import 'package:life_tools/pages/about_page.dart';

void main() {
  group('AboutPage', () {
    testWidgets('应展示基础功能介绍', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutPage()));
      await tester.pumpAndSettle();

      expect(find.text('关于'), findsOneWidget);
      expect(find.text('基础功能'), findsOneWidget);
      expect(find.textContaining('工作记录'), findsOneWidget);
      expect(find.textContaining('囤货助手'), findsOneWidget);
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
  });
}
