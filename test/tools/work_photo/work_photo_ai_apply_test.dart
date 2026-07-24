import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/ai/work_photo_ai_apply.dart';
import 'package:life_tools/tools/work_photo/ai/work_photo_ai_intent.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_template.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';

void main() {
  group('applyWorkPhotoTemplateTree', () {
    test('归档旧节点并按 AI 树重建', () async {
      final repository = _FakeWorkPhotoConfigRepository();
      final now = DateTime(2026, 7, 24, 12);
      final templateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '门店模板', sortIndex: 0, now: now),
      );
      final oldLevelId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(
          templateId: templateId,
          name: '旧区域',
          sortIndex: 0,
          now: now,
        ),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          parentLevelId: oldLevelId,
          name: '旧门头',
          sortIndex: 0,
          now: now,
        ),
      );

      const nodes = [
        WorkPhotoAiTemplateNode(
          kind: WorkPhotoAiNodeKind.level,
          name: '区域',
          children: [
            WorkPhotoAiTemplateNode(
              kind: WorkPhotoAiNodeKind.item,
              name: '门头',
              minCount: 1,
              maxCount: 2,
            ),
          ],
        ),
        WorkPhotoAiTemplateNode(
          kind: WorkPhotoAiNodeKind.item,
          name: '签到照',
          minCount: 1,
        ),
      ];

      await applyWorkPhotoTemplateTree(
        repository: repository,
        templateId: templateId,
        nodes: nodes,
        existingLevels: await repository.listHierarchyLevels(
          templateId: templateId,
          includeArchived: true,
        ),
        existingItems: await repository.listCaptureItems(
          templateId: templateId,
          includeArchived: true,
        ),
        now: now,
      );

      final levels = await repository.listHierarchyLevels(
        templateId: templateId,
        includeArchived: true,
      );
      final items = await repository.listCaptureItems(
        templateId: templateId,
        includeArchived: true,
      );

      final oldLevel = levels.firstWhere((e) => e.name == '旧区域');
      final oldItem = items.firstWhere((e) => e.name == '旧门头');
      expect(oldLevel.isArchived, isTrue);
      expect(oldItem.isArchived, isTrue);

      final activeLevels = levels.where((e) => !e.isArchived).toList();
      final activeItems = items.where((e) => !e.isArchived).toList();
      expect(activeLevels, hasLength(1));
      expect(activeLevels.single.name, '区域');
      expect(activeItems, hasLength(2));

      final door = activeItems.firstWhere((e) => e.name == '门头');
      expect(door.parentLevelId, activeLevels.single.id);
      expect(door.minCount, 1);
      expect(door.maxCount, 2);

      final signIn = activeItems.firstWhere((e) => e.name == '签到照');
      expect(signIn.parentLevelId, isNull);
      expect(signIn.minCount, 1);
      expect(signIn.maxCount, isNull);
    });
  });
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
