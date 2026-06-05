import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_project.dart';
import 'package:life_tools/tools/work_photo/models/work_photo_project_detail.dart';
import 'package:life_tools/tools/work_photo/pages/work_photo_tool_page.dart';
import 'package:life_tools/tools/work_photo/repository/work_photo_repository.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_media_store.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkPhotoToolPage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('work_photo_page_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('首页按模板分组项目，并允许收起和展开模板项目', (tester) async {
      final now = DateTime(2026, 6, 1, 9);
      final repository = _FakeWorkPhotoProjectListRepository([
        WorkPhotoProjectSummary(
          project: WorkPhotoProject.create(
            templateId: 1,
            templateNameSnapshot: '模板 A',
            name: '项目 A1',
            note: '',
            now: now,
          ).copyWith(id: 1),
          hierarchySummary: '',
          requiredItemCount: 1,
          completedItemCount: 0,
          assetCount: 0,
        ),
        WorkPhotoProjectSummary(
          project: WorkPhotoProject.create(
            templateId: 2,
            templateNameSnapshot: '模板 B',
            name: '项目 B1',
            note: '',
            now: now.add(const Duration(minutes: 1)),
          ).copyWith(id: 2),
          hierarchySummary: '',
          requiredItemCount: 1,
          completedItemCount: 0,
          assetCount: 0,
        ),
      ]);

      await tester.pumpWidget(
        TestAppWrapper(
          child: WorkPhotoToolPage(
            repository: repository,
            mediaStore: WorkPhotoMediaStore(baseDirectory: tempDir),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('模板 A'), findsOneWidget);
      expect(find.text('模板 B'), findsOneWidget);
      expect(find.text('项目 A1'), findsOneWidget);
      expect(find.text('项目 B1'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('模板 A'),
          matching: find.byType(GlassContainer),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('项目 A1'),
          matching: find.byType(GlassContainer),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('模板 A'));
      await tester.pump();

      expect(find.text('项目 A1'), findsNothing);
      expect(find.text('项目 B1'), findsOneWidget);

      await tester.tap(find.text('模板 A'));
      await tester.pump();

      expect(find.text('项目 A1'), findsOneWidget);
    });
  });
}

class _FakeWorkPhotoProjectListRepository
    implements WorkPhotoProjectListRepository {
  final List<WorkPhotoProjectSummary> _projects;

  const _FakeWorkPhotoProjectListRepository(this._projects);

  @override
  Future<List<WorkPhotoProjectSummary>> listProjectSummaries() async {
    return _projects;
  }
}
