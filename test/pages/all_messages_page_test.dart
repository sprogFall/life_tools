import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/messages/pages/all_messages_page.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('AllMessagesPage', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    testWidgets('右滑可标记为已读', (tester) async {
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
          child: const MaterialApp(home: AllMessagesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('测试消息'), findsOneWidget);
      expect(messageService.unreadMessages.length, 1);

      final messageId = messageService.messages.single.id!;
      final tile = find.byKey(ValueKey('all_messages_item_$messageId'));
      expect(tile, findsOneWidget);

      await tester.fling(tile, const Offset(1000, 0), 3000);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(messageService.unreadMessages, isEmpty);
    });
  });
}
