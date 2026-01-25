import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/tags/models/tag_category.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/tag_manager/pages/tag_manager_tool_page.dart';
import 'package:life_tools/tools/tag_manager/pages/tag_rename_page.dart';
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

    Future<void> pumpUntilNotFound(WidgetTester tester, Finder finder) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isEmpty) return;
      }
      fail('等待组件消失超时: $finder');
    }

    testWidgets('支持按工具分类查看标签（不再提供“全部”入口）', (tester) async {
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
        await deps.service.refreshToolTags('work_log');
        await deps.service.refreshToolTags('stockpile_assistant');
      });

      await tester.pumpWidget(wrap(deps.service, const TagManagerToolPage()));
      await pumpUntilFound(tester, find.text('紧急'));

      // 默认应选中首个工具（work_log），且不应再出现“全部”
      expect(find.text('全部'), findsNothing);

      // 工具视图应切换为“类别列表”，默认至少包含“默认”类别
      expect(find.text('默认'), findsOneWidget);
      expect(find.text('紧急'), findsOneWidget);
      expect(find.text('复盘'), findsOneWidget);
      expect(find.text('采购'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('tag-filter-stockpile_assistant')),
      );
      await tester.pump();

      expect(find.text('默认'), findsOneWidget);
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
        await deps.service.refreshToolTags('work_log');
      });

      await tester.pumpWidget(
        wrap(deps.service, const TagManagerToolPage(initialToolId: 'work_log')),
      );
      await pumpUntilFound(tester, find.text('紧急'));

      expect(find.text('默认'), findsOneWidget);
      expect(find.text('紧急'), findsOneWidget);
      expect(find.text('采购'), findsNothing);
    });

    testWidgets('点击标签行进入编辑页（筛选后：仅允许改名）', (tester) async {
      final deps = await createTagService(tester);
      late int id1;
      await tester.runAsync(() async {
        id1 = await deps.repository.createTag(
          name: '紧急',
          toolIds: const ['work_log'],
        );
        await deps.repository.createTag(
          name: '采购',
          toolIds: const ['stockpile_assistant'],
        );
        await deps.service.refreshAll();
        await deps.service.refreshToolTags('work_log');
      });

      await tester.pumpWidget(
        wrap(deps.service, const TagManagerToolPage(initialToolId: 'work_log')),
      );
      await pumpUntilFound(tester, find.byKey(ValueKey('tag-item-$id1')));
      expect(find.text('采购'), findsNothing);

      await tester.tap(find.byKey(ValueKey('tag-item-$id1')));
      await tester.pump();

      await pumpUntilFound(tester, find.byType(TagRenamePage));
      expect(find.byType(TagRenamePage), findsOneWidget);
    });

    testWidgets('在类别内点击管理后可删除标签（需确认）', (tester) async {
      final deps = await createTagService(tester);
      late int id;
      await tester.runAsync(() async {
        id = await deps.repository.createTag(
          name: '紧急',
          toolIds: const ['work_log'],
        );
        await deps.service.refreshAll();
        await deps.service.refreshToolTags('work_log');
      });

      await tester.pumpWidget(
        wrap(deps.service, const TagManagerToolPage(initialToolId: 'work_log')),
      );
      await pumpUntilFound(tester, find.byKey(ValueKey('tag-item-$id')));

      await tester.tap(
        find.byKey(const ValueKey('tag-category-manage-work_log-default')),
      );
      await tester.pump();
      await pumpUntilFound(
        tester,
        find.byKey(ValueKey('tag-remove-work_log-default-$id')),
      );

      await tester.tap(find.byKey(ValueKey('tag-remove-work_log-default-$id')));
      await tester.pump();
      await pumpUntilFound(tester, find.text('确认删除'));

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pump();
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (DateTime.now().isBefore(deadline)) {
          final exists = deps.service.allTags.any((e) => e.tag.id == id);
          if (!deps.service.loading && !exists) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        fail('等待删除完成超时: tagId=$id');
      });
      await pumpUntilNotFound(tester, find.byKey(ValueKey('tag-item-$id')));
    });

    testWidgets('点击类别加号应进入管理并展示正确 placeholder', (tester) async {
      final deps = await createTagService(tester);
      deps.service.registerToolTagCategories('work_log', const [
        TagCategory(id: 'priority', name: '优先级', createHint: '紧急/重要'),
      ]);
      await tester.runAsync(() async {
        // 预置一条标签并提前刷新缓存，避免 TagManagerToolPage 在测试结束后仍发起异步查询。
        await deps.repository.createTag(
          name: '占位',
          toolIds: const ['work_log'],
        );
        await deps.service.refreshAll();
        await deps.service.refreshToolTags('work_log');
      });

      await tester.pumpWidget(
        wrap(deps.service, const TagManagerToolPage(initialToolId: 'work_log')),
      );
      await pumpUntilFound(tester, find.text('优先级'));

      await tester.tap(
        find.byKey(const ValueKey('tag-category-add-work_log-priority')),
      );
      await tester.pump();

      const inputKey = ValueKey('tag-quick-add-field-work_log-priority');
      await pumpUntilFound(tester, find.byKey(inputKey));
      final field = tester.widget<CupertinoTextField>(find.byKey(inputKey));
      expect(field.placeholder, '如：紧急/重要');
    });

    testWidgets('管理模式支持快速连续添加标签（chip 输入 + 加号）', (tester) async {
      final deps = await createTagService(tester);
      deps.service.registerToolTagCategories('work_log', const [
        TagCategory(id: 'priority', name: '优先级', createHint: '紧急/重要'),
      ]);
      await tester.runAsync(() async {
        // 预置数据并提前刷新缓存，避免页面构建后仍触发异步查询影响测试稳定性。
        await deps.repository.createTag(
          name: '占位',
          toolIds: const ['work_log'],
        );
        await deps.service.refreshAll();
        await deps.service.refreshToolTags('work_log');
      });

      await tester.pumpWidget(
        wrap(deps.service, const TagManagerToolPage(initialToolId: 'work_log')),
      );
      await pumpUntilFound(tester, find.text('优先级'));

      await tester.tap(
        find.byKey(const ValueKey('tag-category-manage-work_log-priority')),
      );
      await tester.pump();

      final inputKey = const ValueKey('tag-quick-add-field-work_log-priority');
      final addKey = const ValueKey('tag-quick-add-button-work_log-priority');
      await pumpUntilFound(tester, find.byKey(inputKey));

      final field = tester.widget<CupertinoTextField>(find.byKey(inputKey));
      expect(field.placeholder, '如：紧急/重要');

      await tester.enterText(find.byKey(inputKey), '重要');
      await tester.tap(find.byKey(addKey));
      await tester.pump();
      await pumpUntilFound(tester, find.text('重要'));

      await tester.enterText(find.byKey(inputKey), '紧急');
      await tester.tap(find.byKey(addKey));
      await tester.pump();
      await tester.runAsync(() async {
        final tagsBeforeCommit = await deps.repository
            .listTagsForToolWithCategory('work_log');
        expect(tagsBeforeCommit.any((e) => e.tag.name == '重要'), isFalse);
        expect(tagsBeforeCommit.any((e) => e.tag.name == '紧急'), isFalse);
      });
      await pumpUntilFound(tester, find.text('紧急'));

      await tester.tap(
        find.byKey(const ValueKey('tag-category-manage-work_log-priority')),
      );
      await tester.pump();

      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 8));
        while (DateTime.now().isBefore(deadline)) {
          final tags = await deps.repository.listTagsForToolWithCategory(
            'work_log',
          );
          final inPriority = tags
              .where((e) => e.categoryId == 'priority')
              .toList();
          final names = inPriority.map((e) => e.tag.name).toSet();
          if (names.containsAll({'重要', '紧急'})) return;
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        fail('等待提交完成超时');
      });

      await pumpUntilFound(tester, find.text('重要'));
      await pumpUntilFound(tester, find.text('紧急'));
    });
  });
}
