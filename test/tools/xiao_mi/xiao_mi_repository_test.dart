import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/xiao_mi/models/xiao_mi_conversation.dart';
import 'package:life_tools/tools/xiao_mi/models/xiao_mi_message.dart';
import 'package:life_tools/tools/xiao_mi/repository/xiao_mi_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('XiaoMiRepository', () {
    late Database db;
    late XiaoMiRepository repository;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      repository = XiaoMiRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('应该可以创建并读取会话', () async {
      final now = DateTime(2026, 1, 1, 8);
      final id = await repository.createConversation(
        XiaoMiConversation.create(title: '新会话', now: now),
      );

      final convo = await repository.getConversation(id);
      expect(convo, isNotNull);
      expect(convo!.title, '新会话');
      expect(convo.createdAt, now);
      expect(convo.updatedAt, now);
    });

    test('应该可以追加消息并读取消息列表', () async {
      final now = DateTime(2026, 1, 1, 8);
      final convoId = await repository.createConversation(
        XiaoMiConversation.create(title: '', now: now),
      );

      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.user,
          content: '你好',
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      );
      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.assistant,
          content: '你好～',
          createdAt: now.add(const Duration(seconds: 2)),
        ),
      );

      final messages = await repository.listMessages(convoId);
      expect(messages.length, 2);
      expect(messages.first.role, XiaoMiMessageRole.user);
      expect(messages.last.role, XiaoMiMessageRole.assistant);
    });

    test('会话列表应按 updatedAt 倒序', () async {
      final base = DateTime(2026, 1, 1, 8);
      final a = await repository.createConversation(
        XiaoMiConversation.create(title: 'A', now: base),
      );
      final b = await repository.createConversation(
        XiaoMiConversation.create(
          title: 'B',
          now: base.add(const Duration(seconds: 1)),
        ),
      );

      // 给会话 A 追加一条较晚消息，使其 updatedAt 更新到更晚
      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: a,
          role: XiaoMiMessageRole.user,
          content: 'later',
          createdAt: base.add(const Duration(minutes: 1)),
        ),
      );

      final convos = await repository.listConversations();
      expect(convos.map((c) => c.id).toList(), [a, b]);
    });

    test('删除会话应级联删除消息', () async {
      final now = DateTime(2026, 1, 1, 8);
      final convoId = await repository.createConversation(
        XiaoMiConversation.create(title: '', now: now),
      );
      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.user,
          content: 'msg',
          createdAt: now,
        ),
      );

      await repository.deleteConversation(convoId);

      final messages = await repository.listMessages(convoId);
      expect(messages, isEmpty);
    });

    test('应支持批量删除会话并级联移除对应消息', () async {
      final now = DateTime(2026, 1, 1, 8);
      final firstConvoId = await repository.createConversation(
        XiaoMiConversation.create(title: 'A', now: now),
      );
      final secondConvoId = await repository.createConversation(
        XiaoMiConversation.create(
          title: 'B',
          now: now.add(const Duration(seconds: 1)),
        ),
      );
      final thirdConvoId = await repository.createConversation(
        XiaoMiConversation.create(
          title: 'C',
          now: now.add(const Duration(seconds: 2)),
        ),
      );
      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: firstConvoId,
          role: XiaoMiMessageRole.user,
          content: '会话A消息',
          createdAt: now.add(const Duration(seconds: 3)),
        ),
      );
      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: secondConvoId,
          role: XiaoMiMessageRole.user,
          content: '会话B消息',
          createdAt: now.add(const Duration(seconds: 4)),
        ),
      );
      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: thirdConvoId,
          role: XiaoMiMessageRole.user,
          content: '会话C消息',
          createdAt: now.add(const Duration(seconds: 5)),
        ),
      );

      final deletedCount = await repository.deleteConversations([
        firstConvoId,
        thirdConvoId,
      ]);

      expect(deletedCount, 2);
      final conversations = await repository.listConversations();
      expect(conversations.map((item) => item.id).toList(), [secondConvoId]);
      expect(await repository.listMessages(firstConvoId), isEmpty);
      expect(await repository.listMessages(thirdConvoId), isEmpty);
      expect(await repository.listMessages(secondConvoId), hasLength(1));
    });

    test('应支持按 id 批量删除会话内消息', () async {
      final now = DateTime(2026, 1, 1, 8);
      final convoId = await repository.createConversation(
        XiaoMiConversation.create(title: '', now: now),
      );

      final firstId = await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.user,
          content: '第一条',
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      );
      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.assistant,
          content: '第二条',
          createdAt: now.add(const Duration(seconds: 2)),
        ),
      );
      final thirdId = await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.user,
          content: '第三条',
          createdAt: now.add(const Duration(seconds: 3)),
        ),
      );

      final touchedAt = now.add(const Duration(minutes: 1));
      final deletedCount = await repository.deleteMessages(
        conversationId: convoId,
        messageIds: [firstId, thirdId],
        now: touchedAt,
      );

      expect(deletedCount, 2);
      final messages = await repository.listMessages(convoId);
      expect(messages.length, 1);
      expect(messages.single.content, '第二条');

      final convo = await repository.getConversation(convoId);
      expect(convo, isNotNull);
      expect(convo!.updatedAt, touchedAt);
    });
  });
}
