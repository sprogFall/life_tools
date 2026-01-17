import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/notifications/app_notification_service.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_reminder_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeNotificationService implements AppNotificationService {
  final List<({String title, String body})> shown = [];
  final List<({int id, String title, String body, DateTime scheduledAt})> scheduled =
      [];
  final List<int> canceled = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showMessage({required String title, required String body}) async {
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
  group('StockpileReminderService', () {
    late Database db;
    late StockpileRepository stockpileRepository;
    late MessageService messageService;
    late _FakeNotificationService notificationService;

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
      stockpileRepository = StockpileRepository.withDatabase(db);
      notificationService = _FakeNotificationService();
      messageService = MessageService(
        repository: MessageRepository.withDatabase(db),
        notificationService: notificationService,
      );
      await messageService.init();
    });

    tearDown(() async {
      await db.close();
    });

    test('会为临期/过期且未耗尽的物品推送消息，并去重', () async {
      final now = DateTime(2026, 1, 10, 9);

      await stockpileRepository.createItem(
        StockItem.create(
          name: '牛奶',
          location: '冰箱',
          unit: '盒',
          totalQuantity: 2,
          remainingQuantity: 2,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 11),
          remindDays: 3,
          note: '',
          now: now,
        ),
      );
      await stockpileRepository.createItem(
        StockItem.create(
          name: '面包',
          location: '',
          unit: '袋',
          totalQuantity: 1,
          remainingQuantity: 1,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 25),
          remindDays: 3,
          note: '',
          now: now,
        ),
      );
      await stockpileRepository.createItem(
        StockItem.create(
          name: '酸奶',
          location: '冰箱',
          unit: '瓶',
          totalQuantity: 1,
          remainingQuantity: 0,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 11),
          remindDays: 3,
          note: '',
          now: now,
        ),
      );
      await stockpileRepository.createItem(
        StockItem.create(
          name: '鸡蛋',
          location: '厨房',
          unit: '个',
          totalQuantity: 12,
          remainingQuantity: 6,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 9),
          remindDays: 2,
          note: '',
          now: now,
        ),
      );

      final service = StockpileReminderService(repository: stockpileRepository);
      await service.pushDueReminders(messageService: messageService, now: now);

      expect(messageService.messages.length, 2);
      expect(notificationService.shown.length, 2);

      final bodies = messageService.messages.map((e) => e.body).join('\n');
      expect(bodies, contains('牛奶'));
      expect(bodies, contains('鸡蛋'));
      expect(bodies, isNot(contains('面包')));
      expect(bodies, isNot(contains('酸奶')));

      await service.pushDueReminders(messageService: messageService, now: now);
      expect(messageService.messages.length, 2);
      expect(notificationService.shown.length, 2);
    });

    test('已读的提醒在同一天内重复检查时，不应被重置为未读', () async {
      final now = DateTime(2026, 1, 10, 9);
      final itemId = await stockpileRepository.createItem(
        StockItem.create(
          name: '牛奶',
          location: '冰箱',
          unit: '盒',
          totalQuantity: 2,
          remainingQuantity: 2,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 11),
          remindDays: 3,
          note: '',
          now: now,
        ),
      );

      final service = StockpileReminderService(repository: stockpileRepository);
      await service.pushDueReminders(messageService: messageService, now: now);

      final messageId = messageService.messages.single.id;
      expect(messageId, isNotNull);
      await messageService.markMessageRead(
        messageId!,
        readAt: DateTime(2026, 1, 10, 10),
      );

      expect(messageService.unreadMessages, isEmpty);

      await service.pushDueReminders(
        messageService: messageService,
        now: DateTime(2026, 1, 10, 18),
      );

      expect(messageService.messages.single.dedupeKey, isNotNull);
      expect(
        messageService.messages.single.dedupeKey,
        StockpileReminderService.dedupeKeyForItem(itemId: itemId),
      );
      expect(messageService.messages.single.isRead, isTrue);
      expect(messageService.unreadMessages, isEmpty);
      expect(notificationService.shown.length, 1);
    });

    test('会为未来的提醒窗口预定系统通知（即使应用不在前台）', () async {
      final now = DateTime(2026, 1, 1, 8);
      final itemId = await stockpileRepository.createItem(
        StockItem.create(
          name: '牛奶',
          location: '冰箱',
          unit: '盒',
          totalQuantity: 2,
          remainingQuantity: 2,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 3),
          remindDays: 2,
          note: '',
          now: now,
        ),
      );

      final service = StockpileReminderService(repository: stockpileRepository);
      await service.pushDueReminders(messageService: messageService, now: now);

      expect(notificationService.scheduled.length, 3);
      expect(notificationService.scheduled.first.id, 1000000 + itemId * 100);
      expect(notificationService.scheduled.first.scheduledAt.hour, 9);

      final days = notificationService.scheduled
          .map((e) => DateTime(e.scheduledAt.year, e.scheduledAt.month, e.scheduledAt.day))
          .toSet()
          .toList()
        ..sort((a, b) => a.compareTo(b));
      expect(
        days,
        [
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 2),
          DateTime(2026, 1, 3),
        ],
      );
    });
  });
}

