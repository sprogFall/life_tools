import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/ai/work_photo_ai_context.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_template.dart';

void main() {
  group('buildWorkPhotoAiContext', () {
    test('空树时输出 (空)', () {
      final now = DateTime(2026, 7, 24, 10);
      final text = buildWorkPhotoAiContext(
        now: now,
        template: WorkPhotoTemplate(
          id: 1,
          name: '门店模板',
          sortIndex: 0,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
        levels: const [],
        items: const [],
      );

      expect(text.contains('当前日期：2026-07-24'), isTrue);
      expect(text.contains('模板：门店模板'), isTrue);
      expect(text.contains('- (空)'), isTrue);
      expect(text.contains('整体覆盖'), isTrue);
    });

    test('输出层级与拍摄项树，忽略已归档节点', () {
      final now = DateTime(2026, 7, 24);
      final text = buildWorkPhotoAiContext(
        now: now,
        template: WorkPhotoTemplate(
          id: 2,
          name: '巡拍',
          sortIndex: 0,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
        levels: [
          WorkPhotoHierarchyLevel(
            id: 10,
            templateId: 2,
            parentLevelId: null,
            name: '区域',
            sortIndex: 0,
            isRequired: true,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          WorkPhotoHierarchyLevel(
            id: 11,
            templateId: 2,
            parentLevelId: 10,
            name: '门店',
            sortIndex: 0,
            isRequired: true,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          WorkPhotoHierarchyLevel(
            id: 99,
            templateId: 2,
            parentLevelId: null,
            name: '旧层级',
            sortIndex: 1,
            isRequired: true,
            isArchived: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        items: [
          WorkPhotoCaptureItem(
            id: 21,
            templateId: 2,
            parentLevelId: 11,
            name: '门头',
            sortIndex: 0,
            minCount: 1,
            maxCount: 3,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          WorkPhotoCaptureItem(
            id: 22,
            templateId: 2,
            parentLevelId: null,
            name: '签到照',
            sortIndex: 0,
            minCount: 1,
            maxCount: null,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
          WorkPhotoCaptureItem(
            id: 23,
            templateId: 2,
            parentLevelId: null,
            name: '废弃项',
            sortIndex: 1,
            minCount: 1,
            maxCount: null,
            isArchived: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(text.contains('[id=10] 区域'), isTrue);
      expect(text.contains('[id=11] 门店'), isTrue);
      expect(text.contains('[id=21] 门头'), isTrue);
      expect(text.contains('min=1, max=3'), isTrue);
      expect(text.contains('[id=22] 签到照'), isTrue);
      expect(text.contains('max=不限'), isTrue);
      expect(text.contains('旧层级'), isFalse);
      expect(text.contains('废弃项'), isFalse);
    });
  });
}
