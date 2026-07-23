import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_asset.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_project_item.dart';
import 'package:life_tools/tools/work_photo/widgets/work_photo_item_bar.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkPhotoItemBar', () {
    testWidgets('拍摄项选择框用颜色和图标提示状态，不展示缺失或达标文案', (tester) async {
      await tester.pumpWidget(
        TestAppWrapper(
          child: WorkPhotoItemBar(
            items: [
              const WorkPhotoProjectItem(
                id: 1,
                projectId: 1,
                sourceItemId: 1,
                nameSnapshot: '门头',
                hierarchyPathSnapshot: ['门店', '入口'],
                sortIndex: 0,
                minCount: 2,
                maxCount: null,
              ),
              const WorkPhotoProjectItem(
                id: 2,
                projectId: 1,
                sourceItemId: 2,
                nameSnapshot: '收银台',
                sortIndex: 1,
                minCount: 1,
                maxCount: null,
              ),
            ],
            assetsByItemId: {
              2: [
                WorkPhotoAsset(
                  id: 1,
                  projectId: 1,
                  projectItemId: 2,
                  relativePath: 'photos/1/a.jpg',
                  originalFilename: 'a.jpg',
                  mimeType: 'image/jpeg',
                  fileSize: 1,
                  width: null,
                  height: null,
                  takenAt: DateTime(2026, 6, 1),
                  createdAt: DateTime(2026, 6, 1),
                  updatedAt: DateTime(2026, 6, 1),
                ),
              ],
            },
            selectedItemId: 1,
            onSelected: (_) {},
          ),
        ),
      );

      expect(find.text('门头'), findsOneWidget);
      expect(find.text('收银台'), findsOneWidget);
      expect(find.bySemanticsLabel('门店 / 入口 / 门头'), findsOneWidget);
      expect(find.text('0 张 / 2'), findsOneWidget);
      expect(find.text('1 张 / 1'), findsOneWidget);
      expect(find.text('缺失'), findsNothing);
      expect(find.text('达标'), findsNothing);

      final hierarchyText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.textSpan?.toPlainText() == '门店 / 入口',
        ),
      );
      final hierarchySpans = (hierarchyText.textSpan! as TextSpan).children!
          .whereType<TextSpan>()
          .where((span) => span.text?.trim() != '/')
          .toList();
      expect(hierarchyText.maxLines, 1);
      expect(hierarchyText.overflow, TextOverflow.ellipsis);
      expect(
        hierarchySpans.first.style!.color,
        isNot(hierarchySpans.last.style!.color),
      );
      final itemNameText = tester.widget<Text>(find.text('门头'));
      expect(
        hierarchySpans.first.style!.fontSize,
        lessThan(itemNameText.style!.fontSize!),
      );
    });
  });
}
