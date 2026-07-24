import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/ai/work_photo_ai_assistant.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_template.dart';
import 'package:life_tools/tools/work_photo/pages/work_photo_config_page.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkPhotoConfigPage AI 配置', () {
    testWidgets('模板编辑页显示 AI 按钮；生成后可预览并应用覆盖', (tester) async {
      final repository = _FakeWorkPhotoConfigRepository();
      final now = DateTime(2026, 7, 24, 9);
      final templateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '门店模板', sortIndex: 0, now: now),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          name: '旧门头',
          sortIndex: 0,
          now: now,
        ),
      );

      final aiAssistant = _FakeWorkPhotoAiAssistant(
        response: '''
{
  "type": "replace_template_tree",
  "nodes": [
    {
      "kind": "level",
      "name": "区域",
      "children": [
        {"kind": "item", "name": "门头", "min_count": 1, "max_count": 3}
      ]
    },
    {"kind": "item", "name": "签到照", "min_count": 1}
  ]
}
''',
      );

      await tester.pumpWidget(
        TestAppWrapper(
          child: WorkPhotoConfigPage(
            repository: repository,
            aiAssistant: aiAssistant,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('门店模板'));
      await tester.pump();

      expect(find.text('旧门头'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('work_photo_ai_config_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('work_photo_ai_config_button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('work_photo_ai_text_field')),
        '区域下拍门头，根目录签到照',
      );
      await tester.tap(find.text('提交给AI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('预览 AI 配置'), findsOneWidget);
      expect(find.text('区域'), findsOneWidget);
      expect(find.text('门头'), findsOneWidget);
      expect(find.text('签到照'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('work_photo_ai_preview_apply')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('已应用'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      expect(find.text('区域'), findsOneWidget);
      expect(find.text('门头'), findsOneWidget);
      expect(find.text('签到照'), findsOneWidget);
      expect(find.text('旧门头'), findsNothing);

      final activeItems = await repository.listCaptureItems(
        templateId: templateId,
      );
      expect(activeItems.map((e) => e.name).toSet(), {'门头', '签到照'});
      final activeLevels = await repository.listHierarchyLevels(
        templateId: templateId,
      );
      expect(activeLevels.map((e) => e.name).toList(), ['区域']);
    });

    testWidgets('预览页取消不会覆盖现有配置', (tester) async {
      final repository = _FakeWorkPhotoConfigRepository();
      final now = DateTime(2026, 7, 24, 9);
      final templateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '门店模板', sortIndex: 0, now: now),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          name: '旧门头',
          sortIndex: 0,
          now: now,
        ),
      );

      final aiAssistant = _FakeWorkPhotoAiAssistant(
        response: '''
{"type":"replace_template_tree","nodes":[{"kind":"item","name":"新门头","min_count":1}]}
''',
      );

      await tester.pumpWidget(
        TestAppWrapper(
          child: WorkPhotoConfigPage(
            repository: repository,
            aiAssistant: aiAssistant,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('门店模板'));
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('work_photo_ai_config_button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('work_photo_ai_text_field')),
        '只拍新门头',
      );
      await tester.tap(find.text('提交给AI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('work_photo_ai_preview_cancel')),
      );
      await tester.pumpAndSettle();

      expect(find.text('旧门头'), findsOneWidget);
      expect(find.text('新门头'), findsNothing);
      final activeItems = await repository.listCaptureItems(
        templateId: templateId,
      );
      expect(activeItems.single.name, '旧门头');
    });
  });
}

class _FakeWorkPhotoAiAssistant implements WorkPhotoAiAssistant {
  final String response;
  String? lastText;
  String? lastContext;

  _FakeWorkPhotoAiAssistant({required this.response});

  @override
  Future<String> textToTemplateTreeJson({
    required String text,
    required String context,
  }) async {
    lastText = text;
    lastContext = context;
    return response;
  }
}

class _FakeWorkPhotoConfigRepository implements WorkPhotoConfigRepository {
  int _templateId = 1;
  int _levelId = 1;
  int _itemId = 1;
  final List<WorkPhotoTemplate> _templates = [];
  final List<WorkPhotoHierarchyLevel> _levels = [];
  final List<WorkPhotoCaptureItem> _items = [];

  @override
  Future<int> createTemplate(WorkPhotoTemplate template) async {
    final id = _templateId++;
    _templates.add(template.copyWith(id: id));
    return id;
  }

  @override
  Future<List<WorkPhotoTemplate>> listTemplates({
    bool includeArchived = false,
  }) async {
    return _templates.where((e) => includeArchived || !e.isArchived).toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
  }

  @override
  Future<void> updateTemplate(WorkPhotoTemplate template) async {
    final index = _templates.indexWhere((e) => e.id == template.id);
    if (index >= 0) _templates[index] = template;
  }

  @override
  Future<int> createHierarchyLevel(WorkPhotoHierarchyLevel level) async {
    final id = _levelId++;
    _levels.add(level.copyWith(id: id));
    return id;
  }

  @override
  Future<List<WorkPhotoHierarchyLevel>> listHierarchyLevels({
    int? templateId,
    bool includeArchived = false,
  }) async {
    return _levels
        .where((e) => templateId == null || e.templateId == templateId)
        .where((e) => includeArchived || !e.isArchived)
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
  }

  @override
  Future<void> updateHierarchyLevel(WorkPhotoHierarchyLevel level) async {
    final index = _levels.indexWhere((e) => e.id == level.id);
    if (index >= 0) _levels[index] = level;
  }

  @override
  Future<int> createCaptureItem(WorkPhotoCaptureItem item) async {
    final id = _itemId++;
    _items.add(item.copyWith(id: id));
    return id;
  }

  @override
  Future<List<WorkPhotoCaptureItem>> listCaptureItems({
    int? templateId,
    bool includeArchived = false,
  }) async {
    return _items
        .where((e) => templateId == null || e.templateId == templateId)
        .where((e) => includeArchived || !e.isArchived)
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
  }

  @override
  Future<void> updateCaptureItem(WorkPhotoCaptureItem item) async {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index >= 0) _items[index] = item;
  }
}
