import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/core/tags/models/tag_in_tool_category.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/overcooked_kitchen/overcooked_constants.dart';
import 'package:life_tools/tools/overcooked_kitchen/utils/overcooked_utils.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('OvercookedTagUtils.createTag', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    testWidgets('可直接新增标签并写入标签管理数据表', (tester) async {
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

      late BuildContext captured;
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<TagService>.value(value: service)],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      late int createdId;
      await tester.runAsync(() async {
        final tag = await OvercookedTagUtils.createTag(
          captured,
          categoryId: OvercookedTagCategories.dishType,
          name: '快手',
        );
        createdId = tag.id!;
      });

      final links =
          (await tester.runAsync<List<TagInToolCategory>?>(
            () => repository.listTagsForToolWithCategory(
              OvercookedConstants.toolId,
            ),
          )) ??
          <TagInToolCategory>[];
      expect(
        links.any(
          (e) =>
              e.categoryId == OvercookedTagCategories.dishType &&
              e.tag.id == createdId &&
              e.tag.name == '快手',
        ),
        isTrue,
      );

      final tags =
          (await tester.runAsync<List<Tag>?>(
            () => service.listTagsForToolCategory(
              toolId: OvercookedConstants.toolId,
              categoryId: OvercookedTagCategories.dishType,
            ),
          )) ??
          <Tag>[];
      expect(tags.any((t) => t.id == createdId && t.name == '快手'), isTrue);
    });
  });
}
