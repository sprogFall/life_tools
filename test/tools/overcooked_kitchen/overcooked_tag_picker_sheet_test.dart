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

    Future<void> pumpUntilNotFound(WidgetTester tester, Finder finder) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isEmpty) return;
      }
      fail('等待组件消失超时: $finder');
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

      await tester.tap(find.byKey(const ValueKey('overcooked-tag-add')));
      await tester.pump();
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('overcooked-tag-add-field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('overcooked-tag-add-field')),
        '快手',
      );
      await tester.tap(find.text('添加'));
      await tester.pump();

      await pumpUntilNotFound(
        tester,
        find.byKey(const ValueKey('overcooked-tag-add-field')),
      );
      await pumpUntilFound(tester, find.text('快手'));

      await tester.tap(find.byKey(const ValueKey('overcooked-tag-done')));
      await tester.pump();

      final result = await completer.future;
      expect(result, isNotNull);
      expect(result!.tagsChanged, isTrue);
      expect(result.selectedIds, containsAll(<int>{1, 2}));
    });
  });
}
