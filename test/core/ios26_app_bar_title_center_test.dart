import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  group('IOS26AppBar 标题居中', () {
    Future<void> pumpWithAppBar(
      WidgetTester tester, {
      required IOS26AppBar appBar,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(appBar: appBar, body: const SizedBox.shrink()),
        ),
      );
      await tester.pump();
    }

    void expectTitleCentered(WidgetTester tester, String title) {
      final barRect = tester.getRect(find.byType(IOS26AppBar));
      final titleRect = tester.getRect(find.text(title));
      final expectedCenterX = barRect.left + barRect.width / 2;
      expect(
        titleRect.center.dx,
        moreOrLessEquals(expectedCenterX, epsilon: 0.5),
      );
    }

    testWidgets('无 actions 时标题仍应居中', (tester) async {
      await pumpWithAppBar(
        tester,
        appBar: const IOS26AppBar(title: '全部消息', showBackButton: true),
      );

      expectTitleCentered(tester, '全部消息');
    });

    testWidgets('左右宽度不对称时标题仍应居中', (tester) async {
      await pumpWithAppBar(
        tester,
        appBar: IOS26AppBar(
          title: '工作记录',
          leading: SizedBox(
            width: 140,
            child: CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: () {},
              child: const Text('首页'),
            ),
          ),
          actions: const [
            SizedBox(width: 10),
            SizedBox(width: 44, height: 44),
            SizedBox(width: 44, height: 44),
          ],
        ),
      );

      expectTitleCentered(tester, '工作记录');
    });

    testWidgets('右侧双 action 且标题较长时，标题中心仍对齐屏幕中线', (tester) async {
      // 模拟外拍拍摄页：左侧返回，右侧翻转摄像头 + 闪光灯。
      // 标题较宽时 NavigationToolbar 会为避让 trailing 整体左偏。
      await pumpWithAppBar(
        tester,
        appBar: IOS26AppBar(
          title: '门店入口门头全景特写',
          showBackButton: true,
          actions: [
            IOS26IconButton(
              icon: CupertinoIcons.camera_rotate,
              onPressed: () {},
              tone: IOS26IconTone.onAccent,
            ),
            IOS26IconButton(
              icon: CupertinoIcons.bolt_slash,
              onPressed: () {},
              tone: IOS26IconTone.onAccent,
            ),
          ],
        ),
      );

      expectTitleCentered(tester, '门店入口门头全景特写');
    });

    testWidgets('自定义 titleWidget 双行标签时，整体水平中心仍对齐屏幕中线', (tester) async {
      const titleKey = ValueKey('camera-title-label');
      await pumpWithAppBar(
        tester,
        appBar: IOS26AppBar(
          title: 'fallback',
          showBackButton: true,
          titleWidget: const Column(
            key: titleKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('门店 / 入口', textAlign: TextAlign.center),
              Text('门头全景特写', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            IOS26IconButton(
              icon: CupertinoIcons.camera_rotate,
              onPressed: () {},
            ),
            IOS26IconButton(icon: CupertinoIcons.bolt_slash, onPressed: () {}),
          ],
        ),
      );

      final barRect = tester.getRect(find.byType(IOS26AppBar));
      final titleRect = tester.getRect(find.byKey(titleKey));
      expect(
        titleRect.center.dx,
        moreOrLessEquals(barRect.left + barRect.width / 2, epsilon: 0.5),
      );
    });

    testWidgets('titleWidget 横向撑满时，文本中心仍对齐屏幕中线', (tester) async {
      // 外拍拍摄页 WorkPhotoItemLabel 会 width: infinity 撑满 middle。
      // NavigationToolbar 在 trailing 更宽时会把 middle 槽整体左偏，
      // 仅靠 TextAlign.center 只能在槽内居中，视觉上偏离屏幕中线。
      await pumpWithAppBar(
        tester,
        appBar: IOS26AppBar(
          title: 'fallback',
          showBackButton: true,
          titleWidget: const SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('门店 / 入口', textAlign: TextAlign.center),
                Text('门头', textAlign: TextAlign.center),
              ],
            ),
          ),
          actions: [
            IOS26IconButton(
              icon: CupertinoIcons.camera_rotate,
              onPressed: () {},
            ),
            IOS26IconButton(icon: CupertinoIcons.bolt_slash, onPressed: () {}),
          ],
        ),
      );

      final barRect = tester.getRect(find.byType(IOS26AppBar));
      final nameRect = tester.getRect(find.text('门头'));
      final pathRect = tester.getRect(find.text('门店 / 入口'));
      final expectedCenterX = barRect.left + barRect.width / 2;
      expect(
        nameRect.center.dx,
        moreOrLessEquals(expectedCenterX, epsilon: 0.5),
      );
      expect(
        pathRect.center.dx,
        moreOrLessEquals(expectedCenterX, epsilon: 0.5),
      );
    });
  });
}
