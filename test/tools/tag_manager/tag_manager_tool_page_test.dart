import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/tag_manager/pages/tag_manager_tool_page.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('TagManagerToolPage', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      ToolRegistry.instance.registerAll();
    });

    Future<({Database db, TagService service, TagRepository repository})>
    createTagService(WidgetTester tester) async {
      late Database db;
      late TagRepository repository;
      late TagService service;
      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        repository = TagRepository.withDatabase(db);
        service = TagService(repository: repository);
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });
      return (db: db, service: service, repository: repository);
    }

    Widget wrap(TagService service, Widget child) {
      return MultiProvider(
        providers: [ChangeNotifierProvider<TagService>.value(value: service)],
        child: MaterialApp(home: child),
      );
    }

    Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
      // 避免对包含持续动画组件（如 ReorderableListView / ActivityIndicator）的页面使用 pumpAndSettle。
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('等待组件超时: $finder');
    }

    testWidgets('支持按关联工具筛选标签', (tester) async {
      final deps = await createTagService(tester);
      await tester.runAsync(() async {
        await deps.repository.createTag(
          name: '紧急',
          toolIds: const ['work_log'],
        );
        await deps.repository.createTag(
          name: '采购',
          toolIds: const ['stockpile_assistant'],
        );
        await deps.repository.createTag(
          name: '复盘',
          toolIds: const ['work_log', 'stockpile_assistant'],
        );
        await deps.service.refreshAll();
      });

      await tester.pumpWidget(wrap(deps.service, const TagManagerToolPage()));
      await pumpUntilFound(tester, find.text('紧急'));

      expect(find.text('紧急'), findsOneWidget);
      expect(find.text('采购'), findsOneWidget);
      expect(find.text('复盘'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tag-filter-work_log')));
      await tester.pump();

      expect(find.text('紧急'), findsOneWidget);
      expect(find.text('复盘'), findsOneWidget);
      expect(find.text('采购'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('tag-filter-stockpile_assistant')),
      );
      await tester.pump();

      expect(find.text('采购'), findsOneWidget);
      expect(find.text('复盘'), findsOneWidget);
      expect(find.text('紧急'), findsNothing);
    });

    testWidgets('传入 initialToolId 时默认按工具筛选', (tester) async {
      final deps = await createTagService(tester);
      await tester.runAsync(() async {
        await deps.repository.createTag(
          name: '紧急',
          toolIds: const ['work_log'],
        );
        await deps.repository.createTag(
          name: '采购',
          toolIds: const ['stockpile_assistant'],
        );
        await deps.service.refreshAll();
      });

      await tester.pumpWidget(
        wrap(deps.service, const TagManagerToolPage(initialToolId: 'work_log')),
      );
      await pumpUntilFound(tester, find.text('紧急'));

      expect(find.text('紧急'), findsOneWidget);
      expect(find.text('采购'), findsNothing);
    });
  });
}
