import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_template.dart';
import 'package:life_tools/tools/work_photo/pages/work_photo_config_page.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkPhotoConfigPage', () {
    testWidgets('打开配置页时只展示模板列表，点击模板后进入模板配置', (tester) async {
      final repository = _FakeWorkPhotoConfigRepository();
      final now = DateTime(2026, 6, 1, 9);
      final templateId = await repository.createTemplate(
        WorkPhotoTemplate.create(name: '门店模板', sortIndex: 0, now: now),
      );
      await repository.createCaptureItem(
        WorkPhotoCaptureItem.create(
          templateId: templateId,
          name: '门头',
          sortIndex: 0,
          now: now,
        ),
      );

      await tester.pumpWidget(
        TestAppWrapper(child: WorkPhotoConfigPage(repository: repository)),
      );
      await tester.pump();

      expect(find.text('模板'), findsOneWidget);
      expect(find.text('门店模板'), findsOneWidget);
      expect(find.text('拍摄项'), findsNothing);
      expect(find.text('门头'), findsNothing);

      await tester.tap(find.text('门店模板'));
      await tester.pump();

      expect(find.text('拍摄项'), findsOneWidget);
      expect(find.text('门头'), findsOneWidget);
      expect(find.text('模板列表'), findsOneWidget);
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
