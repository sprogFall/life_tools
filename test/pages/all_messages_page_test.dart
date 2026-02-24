import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/models/tool_info.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/messages/pages/all_messages_page.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test_helpers/test_app_wrapper.dart';

void main() {
  group('AllMessagesPage', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    testWidgets('右滑出现已读按钮并可标记为已读', (tester) async {
      late Database db;
      late MessageService messageService;
      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        messageService = MessageService(
          repository: MessageRepository.withDatabase(db),
        );
        await messageService.init();
        await messageService.upsertMessage(
          toolId: 'work_log',
          title: '工作记录',
          body: '测试消息',
          createdAt: DateTime(2026, 1, 1, 9),
        );
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<MessageService>.value(
          value: messageService,
          child: TestAppWrapper(child: const AllMessagesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('测试消息'), findsOneWidget);
      expect(messageService.unreadMessages.length, 1);

      final messageId = messageService.messages.single.id!;
      final tile = find.byKey(ValueKey('all_messages_item_$messageId'));
      expect(tile, findsOneWidget);

      await tester.drag(tile, const Offset(240, 0));
      await tester.pumpAndSettle();

      expect(find.text('已读'), findsOneWidget);
      await tester.tap(find.text('已读'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(messageService.unreadMessages, isEmpty);
    });

    testWidgets('左滑出现删除按钮并可删除消息', (tester) async {
      late Database db;
      late MessageService messageService;
      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        messageService = MessageService(
          repository: MessageRepository.withDatabase(db),
        );
        await messageService.init();
        await messageService.upsertMessage(
          toolId: 'work_log',
          title: '工作记录',
          body: '待删除消息',
          createdAt: DateTime(2026, 1, 1, 9),
        );
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<MessageService>.value(
          value: messageService,
          child: TestAppWrapper(child: const AllMessagesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('待删除消息'), findsOneWidget);
      expect(messageService.messages.length, 1);

      final messageId = messageService.messages.single.id!;
      final tile = find.byKey(ValueKey('all_messages_item_$messageId'));
      expect(tile, findsOneWidget);

      await tester.drag(tile, const Offset(-240, 0));
      await tester.pumpAndSettle();

      expect(find.text('删除'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text('待删除消息'), findsNothing);
      expect(messageService.messages, isEmpty);
      expect(messageService.unreadMessages, isEmpty);
    });

    testWidgets('点击前往工具直接跳转工具页，点击内容进入详情页', (tester) async {
      ToolRegistry.instance.registerAll();
      ToolRegistry.instance.register(
        ToolInfo(
          id: 'test_tool_page',
          name: '测试工具',
          description: '测试工具',
          icon: Icons.extension,
          color: Colors.blue,
          pageBuilder: () => const Scaffold(body: Center(child: Text('测试工具页'))),
        ),
      );

      late Database db;
      late MessageService messageService;
      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        messageService = MessageService(
          repository: MessageRepository.withDatabase(db),
        );
        await messageService.init();
        await messageService.upsertMessage(
          toolId: 'test_tool_page',
          title: '跳转验证',
          body: '仅点内容进详情',
          createdAt: DateTime(2026, 1, 1, 9),
        );
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<MessageService>.value(
          value: messageService,
          child: TestAppWrapper(child: const AllMessagesPage()),
        ),
      );
      await tester.pumpAndSettle();

      final messageId = messageService.messages.single.id!;

      await tester.tap(
        find.byKey(ValueKey('all_messages_open_tool_$messageId')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text('测试工具页'), findsOneWidget);
      expect(find.text('消息详情'), findsNothing);
      expect(messageService.unreadMessages, isEmpty);

      Navigator.of(tester.element(find.text('测试工具页'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('all_messages_content_$messageId')));
      await tester.pumpAndSettle();

      expect(find.text('消息详情'), findsOneWidget);
    });
  });
}
