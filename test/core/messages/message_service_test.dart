import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/notifications/app_notification_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeNotificationService implements AppNotificationService {
  final List<({String title, String body})> shown = [];
  final List<({int id, String title, String body, DateTime scheduledAt})>
  scheduled = [];
  final List<int> canceled = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showMessage({
    required String title,
    required String body,
  }) async {
    shown.add((title: title, body: body));
  }

  @override
  Future<void> scheduleMessage({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    scheduled.add((id: id, title: title, body: body, scheduledAt: scheduledAt));
  }

  @override
  Future<void> cancel(int id) async {
    canceled.add(id);
  }
}

void main() {
  group('MessageService / MessageRepository', () {
    late Database db;
    late MessageRepository repository;
    late _FakeNotificationService notificationService;
    late MessageService service;

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
      repository = MessageRepository.withDatabase(db);
      notificationService = _FakeNotificationService();
      service = MessageService(
        repository: repository,
        notificationService: notificationService,
      );
      await service.init();
    });

    tearDown(() async {
      await db.close();
    });

    test('upsertMessage 会写入数据库并出现在 messages 中', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      await service.upsertMessage(
        toolId: 'work_log',
        title: '测试标题',
        body: '测试内容',
        createdAt: now,
      );

      expect(service.messages.length, 1);
      expect(service.messages.first.body, '测试内容');

      final loaded = await repository.listMessages(limit: 10);
      expect(loaded.length, 1);
      expect(loaded.first.body, '测试内容');
    });

    test('dedupeKey 相同的消息应更新而不是新增', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      await service.upsertMessage(
        toolId: 'work_log',
        title: '标题',
        body: '内容 A',
        dedupeKey: 'k1',
        createdAt: now,
      );
      await service.upsertMessage(
        toolId: 'work_log',
        title: '标题',
        body: '内容 B',
        dedupeKey: 'k1',
        createdAt: now.add(const Duration(minutes: 1)),
      );

      final loaded = await repository.listMessages(limit: 10);
      expect(loaded.length, 1);
      expect(loaded.first.body, '内容 B');
      expect(loaded.first.createdAt, now.add(const Duration(minutes: 1)));
    });

    test('notify=true 会触发系统通知能力', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      await service.upsertMessage(
        toolId: 'work_log',
        title: '工作记录',
        body: '你有 1 条新消息',
        createdAt: now,
        notify: true,
      );

      expect(notificationService.shown.length, 1);
      expect(notificationService.shown.first.title, '工作记录');
      expect(notificationService.shown.first.body, '你有 1 条新消息');
    });

    test('listMessages 默认按时间倒序返回', () async {
      await repository.upsertMessage(
        toolId: 't',
        title: '',
        body: 'old',
        createdAt: DateTime(2026, 1, 1, 9, 0),
      );
      await repository.upsertMessage(
        toolId: 't',
        title: '',
        body: 'new',
        createdAt: DateTime(2026, 1, 1, 10, 0),
      );

      final loaded = await repository.listMessages(limit: 10);
      expect(loaded.first.body, 'new');
      expect(loaded.last.body, 'old');
    });

    test('markMessageRead 会让消息从 unreadMessages 中消失', () async {
      final now = DateTime(2026, 1, 1, 9, 0);
      await service.upsertMessage(
        toolId: 'work_log',
        title: '标题',
        body: '内容',
        dedupeKey: 'k_read',
        createdAt: now,
      );

      expect(service.unreadMessages.length, 1);

      final id = service.messages.single.id;
      expect(id, isNotNull);
      await service.markMessageRead(id!);

      expect(service.unreadMessages, isEmpty);
      final loaded = await repository.listMessages(limit: 10);
      expect(loaded.single.isRead, isTrue);
      expect(loaded.single.readAt, isNotNull);
    });

    test('dedupeKey 内容未变时，不应把已读重置为未读（也不应重复推送系统通知）', () async {
      final t1 = DateTime(2026, 1, 1, 9, 0);
      await service.upsertMessage(
        toolId: 'stockpile_assistant',
        title: '囤货助手',
        body: '牛奶 将在 2 天后到期',
        dedupeKey: 'stockpile:expiry:1',
        createdAt: t1,
        notify: true,
      );
      expect(notificationService.shown.length, 1);

      final id = service.messages.single.id;
      expect(id, isNotNull);
      await service.markMessageRead(id!, readAt: DateTime(2026, 1, 1, 10, 0));

      // 同一天内重复触发同一条 dedupeKey 的 upsert（createdAt 不同，但内容不变）
      await service.upsertMessage(
        toolId: 'stockpile_assistant',
        title: '囤货助手',
        body: '牛奶 将在 2 天后到期',
        dedupeKey: 'stockpile:expiry:1',
        createdAt: DateTime(2026, 1, 1, 12, 0),
        notify: true,
      );

      expect(service.messages.single.isRead, isTrue);
      expect(service.unreadMessages, isEmpty);
      expect(notificationService.shown.length, 1);

      final loaded = await repository.listMessages(limit: 10);
      expect(loaded.single.isRead, isTrue);
      expect(loaded.single.readAt, isNotNull);
    });

    test(
      'refreshDaily=true 时：跨天但内容未变，也应刷新 createdAt、重置未读并再次推送系统通知（同一天不重复）',
      () async {
        final day1 = DateTime(2026, 1, 1, 9, 0);
        await service.upsertMessage(
          toolId: 'stockpile_assistant',
          title: '囤货助手',
          body: '【囤货助手】洗衣液 需要补货，剩余 1 瓶。',
          dedupeKey: 'stockpile:restock:1',
          createdAt: day1,
          notify: true,
          refreshDaily: true,
        );
        expect(notificationService.shown.length, 1);

        final id = service.messages.single.id;
        expect(id, isNotNull);
        await service.markMessageRead(id!, readAt: DateTime(2026, 1, 1, 10, 0));

        await service.upsertMessage(
          toolId: 'stockpile_assistant',
          title: '囤货助手',
          body: '【囤货助手】洗衣液 需要补货，剩余 1 瓶。',
          dedupeKey: 'stockpile:restock:1',
          createdAt: DateTime(2026, 1, 1, 18, 0),
          notify: true,
          refreshDaily: true,
        );
        expect(service.messages.single.isRead, isTrue);
        expect(notificationService.shown.length, 1);

        final day2 = DateTime(2026, 1, 2, 9, 0);
        await service.upsertMessage(
          toolId: 'stockpile_assistant',
          title: '囤货助手',
          body: '【囤货助手】洗衣液 需要补货，剩余 1 瓶。',
          dedupeKey: 'stockpile:restock:1',
          createdAt: day2,
          notify: true,
          refreshDaily: true,
        );

        expect(service.messages.single.isRead, isFalse);
        expect(service.messages.single.createdAt, day2);
        expect(notificationService.shown.length, 2);

        await service.upsertMessage(
          toolId: 'stockpile_assistant',
          title: '囤货助手',
          body: '【囤货助手】洗衣液 需要补货，剩余 1 瓶。',
          dedupeKey: 'stockpile:restock:1',
          createdAt: DateTime(2026, 1, 2, 18, 0),
          notify: true,
          refreshDaily: true,
        );
        expect(notificationService.shown.length, 2);
      },
    );
  });
}
