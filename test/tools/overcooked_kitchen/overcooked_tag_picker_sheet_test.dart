import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/tools/overcooked_kitchen/widgets/overcooked_tag_picker_sheet.dart';

void main() {
  group('OvercookedTagPickerSheet', () {
    Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('等待组件超时: $finder');
    }

    testWidgets('多选模式使用 chip（无开关）且可新增标签', (tester) async {
      final now = DateTime(2026, 1, 1);
      final tags = [
        Tag(
          id: 1,
          name: '下饭',
          color: null,
          sortIndex: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final completer = Completer<OvercookedTagPickerResult?>();
      int nextId = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () async {
                    final result = await OvercookedTagPickerSheet.show(
                      context,
                      title: '选择风格搭配',
                      tags: tags,
                      selectedIds: const <int>{},
                      multi: true,
                      createHint: '下饭/快手/宴客/减脂',
                      onCreateTag: (name) async {
                        final id = nextId++;
                        return Tag(
                          id: id,
                          name: name,
                          color: null,
                          sortIndex: 0,
                          createdAt: now,
                          updatedAt: now,
                        );
                      },
                    );
                    completer.complete(result);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoSwitch), findsNothing);
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('overcooked-tag-1')),
      );

      await tester.tap(find.byKey(const ValueKey('overcooked-tag-1')));
      await tester.pump();

      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('overcooked-tag-quick-add-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('overcooked-tag-quick-add-button')),
      );
      await tester.pump();

      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('overcooked-tag-quick-add-field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('overcooked-tag-quick-add-field')),
        '快手',
      );
      await tester.tap(
        find.byKey(const ValueKey('overcooked-tag-quick-add-button')),
      );
      await tester.pump();

      await pumpUntilFound(tester, find.text('快手'));

      await tester.tap(find.byKey(const ValueKey('overcooked-tag-done')));
      await tester.pump();

      final result = await completer.future;
      expect(result, isNotNull);
      expect(result!.tagsChanged, isTrue);
      expect(result.selectedIds, containsAll(<int>{1, 2}));
    });

    testWidgets('可禁用无菜品标签且不可选中', (tester) async {
      final now = DateTime(2026, 1, 1);
      final tags = [
        Tag(
          id: 1,
          name: '主菜',
          color: null,
          sortIndex: 0,
          createdAt: now,
          updatedAt: now,
        ),
        Tag(
          id: 2,
          name: '甜品',
          color: null,
          sortIndex: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final completer = Completer<OvercookedTagPickerResult?>();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () async {
                    final result = await OvercookedTagPickerSheet.show(
                      context,
                      title: '选择风格搭配',
                      tags: tags,
                      selectedIds: const <int>{2},
                      multi: true,
                      disabledTagIds: const <int>{2},
                    );
                    completer.complete(result);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('甜品'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final result = await completer.future;
      expect(result, isNotNull);
      expect(result!.selectedIds.contains(2), isFalse);
      expect(result.selectedIds, isEmpty);
    });

    testWidgets('键盘弹出时新增标签输入框不被遮挡', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      addTearDown(() => tester.view.resetViewInsets());

      final now = DateTime(2026, 1, 1);
      final tags = List<Tag>.generate(
        120,
        (i) => Tag(
          id: i + 1,
          name: '标签${i + 1}',
          color: null,
          sortIndex: i,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () async {
                    await OvercookedTagPickerSheet.show(
                      context,
                      title: '选择标签',
                      tags: tags,
                      selectedIds: const <int>{},
                      multi: true,
                      onCreateTag: (name) async {
                        return Tag(
                          id: 999,
                          name: name,
                          color: null,
                          sortIndex: 0,
                          createdAt: now,
                          updatedAt: now,
                        );
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      final scrollable = find.byType(SingleChildScrollView);
      final quickAddButton = find.byKey(
        const ValueKey('overcooked-tag-quick-add-button'),
      );
      final quickAddField = find.byKey(
        const ValueKey('overcooked-tag-quick-add-field'),
      );

      await tester.dragUntilVisible(
        quickAddButton,
        scrollable,
        const Offset(0, -300),
      );
      await tester.pump();

      for (int i = 0; i < 30; i++) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      await tester.tap(quickAddButton);
      await tester.pump();
      await pumpUntilFound(tester, quickAddField);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      final screenHeight = tester.view.physicalSize.height;
      final keyboardHeight = tester.view.viewInsets.bottom;
      final sheetRect = tester.getRect(find.byType(OvercookedTagPickerSheet));
      final fieldRect = tester.getRect(quickAddField);

      // 关键点：键盘出现时，整个 bottom sheet 本身也应上移，避免被键盘覆盖。
      expect(
        sheetRect.bottom,
        lessThanOrEqualTo(screenHeight - keyboardHeight),
      );
      expect(
        fieldRect.bottom,
        lessThanOrEqualTo(screenHeight - keyboardHeight),
      );
    });
  });
}
