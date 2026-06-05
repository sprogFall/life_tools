import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_capture_item.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_hierarchy_level.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_template.dart';
import 'package:life_tools/tools/work_photo/pages/work_photo_project_edit_page.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkPhotoProjectEditPage', () {
    testWidgets('新建项目只允许从模板创建，并展示缩进模板结构', (tester) async {
      tester.view.physicalSize = const Size(1080, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 6, 1, 9);
      final template = WorkPhotoTemplate.create(
        name: '门店模板',
        sortIndex: 0,
        now: now,
      ).copyWith(id: 1);
      final storeLevel = WorkPhotoHierarchyLevel.create(
        templateId: template.id,
        name: '门店',
        sortIndex: 0,
        now: now,
      ).copyWith(id: 1);
      final entranceLevel = WorkPhotoHierarchyLevel.create(
        templateId: template.id,
        parentLevelId: storeLevel.id,
        name: '入口',
        sortIndex: 0,
        now: now,
      ).copyWith(id: 2);
      final signItem = WorkPhotoCaptureItem.create(
        templateId: template.id,
        parentLevelId: entranceLevel.id,
        name: '门头',
        sortIndex: 0,
        minCount: 1,
        now: now,
      ).copyWith(id: 1);
      final counterItem = WorkPhotoCaptureItem.create(
        templateId: template.id,
        parentLevelId: storeLevel.id,
        name: '收银台',
        sortIndex: 1,
        minCount: 2,
        maxCount: 4,
        now: now,
      ).copyWith(id: 2);
      final overviewItem = WorkPhotoCaptureItem.create(
        templateId: template.id,
        name: '总览',
        sortIndex: 1,
        minCount: 1,
        now: now,
      ).copyWith(id: 3);
      final repository = _FakeWorkPhotoProjectCreateRepository(
        templates: [template],
        levels: [storeLevel, entranceLevel],
        items: [signItem, counterItem, overviewItem],
      );

      await tester.pumpWidget(
        TestAppWrapper(child: WorkPhotoProjectEditPage(repository: repository)),
      );
      await _pumpRealAsync(tester);

      expect(find.text('创建方式'), findsNothing);
      expect(find.text('全自定义'), findsNothing);
      expect(find.text('未选择'), findsNothing);
      expect(find.text('层级'), findsNothing);
      expect(find.text('项目模板'), findsOneWidget);
      expect(find.text('模板结构'), findsOneWidget);
      expect(find.text('模板根目录'), findsOneWidget);
      expect(find.text('门店'), findsOneWidget);
      expect(find.text('入口'), findsOneWidget);
      expect(find.text('门头'), findsOneWidget);
      expect(find.text('收银台'), findsOneWidget);
      expect(find.text('总览'), findsOneWidget);

      final rootLeft = tester.getTopLeft(find.text('模板根目录')).dx;
      final storeLeft = tester.getTopLeft(find.text('门店')).dx;
      final entranceLeft = tester.getTopLeft(find.text('入口')).dx;
      final itemLeft = tester.getTopLeft(find.text('门头')).dx;
      expect(storeLeft, greaterThan(rootLeft));
      expect(entranceLeft, greaterThan(storeLeft));
      expect(itemLeft, greaterThan(entranceLeft));

      final sectionWidths = [
        'work-photo-project-template-section',
        'work-photo-project-structure-section',
        'work-photo-project-name-section',
        'work-photo-project-note-section',
      ].map((key) => tester.getSize(find.byKey(ValueKey(key))).width).toList();
      for (final width in sectionWidths.skip(1)) {
        expect(width, sectionWidths.first);
      }

      await tester.enterText(find.byType(CupertinoTextField).at(0), '项目树');
      await tester.enterText(find.byType(CupertinoTextField).at(1), '现场备注');
      await tester.tap(find.text('保存'));
      await _pumpRealAsync(tester);

      expect(repository.createdProjects, hasLength(1));
      final project = repository.createdProjects.single;
      expect(project.name, '项目树');
      expect(project.note, '现场备注');
      expect(project.templateId, template.id);
      expect(project.hierarchySelections, isEmpty);
    });
  });
}

Future<void> _pumpRealAsync(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

class _FakeWorkPhotoProjectCreateRepository
    implements WorkPhotoProjectCreateRepository {
  final List<WorkPhotoTemplate> templates;
  final List<WorkPhotoHierarchyLevel> levels;
  final List<WorkPhotoCaptureItem> items;
  final List<_CreatedProject> createdProjects = [];

  _FakeWorkPhotoProjectCreateRepository({
    required this.templates,
    required this.levels,
    required this.items,
  });

  @override
  Future<List<WorkPhotoTemplate>> listTemplates({
    bool includeArchived = false,
  }) async {
    return templates.where((e) => includeArchived || !e.isArchived).toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
  }

  @override
  Future<List<WorkPhotoHierarchyLevel>> listHierarchyLevels({
    int? templateId,
    bool includeArchived = false,
  }) async {
    return levels
        .where((e) => templateId == null || e.templateId == templateId)
        .where((e) => includeArchived || !e.isArchived)
        .toList()
      ..sort((a, b) => _compareTreeNode(a.sortIndex, a.id, b.sortIndex, b.id));
  }

  @override
  Future<List<WorkPhotoCaptureItem>> listCaptureItemsInTemplateTree(
    int templateId, {
    bool includeArchived = false,
  }) async {
    return items
        .where((e) => e.templateId == templateId)
        .where((e) => includeArchived || !e.isArchived)
        .toList()
      ..sort((a, b) => _compareTreeNode(a.sortIndex, a.id, b.sortIndex, b.id));
  }

  @override
  Future<int> createProjectFromTemplate({
    required String name,
    required String note,
    required int templateId,
    required List<WorkPhotoHierarchySelection> hierarchySelections,
    DateTime? now,
  }) async {
    createdProjects.add(
      _CreatedProject(
        name: name,
        note: note,
        templateId: templateId,
        hierarchySelections: hierarchySelections,
      ),
    );
    return createdProjects.length;
  }

  static int _compareTreeNode(int aSort, int? aId, int bSort, int? bId) {
    final sortCompared = aSort.compareTo(bSort);
    if (sortCompared != 0) return sortCompared;
    return (aId ?? 0).compareTo(bId ?? 0);
  }
}

class _CreatedProject {
  final String name;
  final String note;
  final int templateId;
  final List<WorkPhotoHierarchySelection> hierarchySelections;

  const _CreatedProject({
    required this.name,
    required this.note,
    required this.templateId,
    required this.hierarchySelections,
  });
}
