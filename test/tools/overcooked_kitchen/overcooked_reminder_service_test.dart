import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/notifications/app_notification_service.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:life_tools/tools/overcooked_kitchen/services/overcooked_reminder_service.dart';
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
  group('OvercookedReminderService', () {
    late Database db;
    late OvercookedRepository repository;
    late TagRepository tagRepository;
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
      repository = OvercookedRepository.withDatabase(db);
      tagRepository = TagRepository.withDatabase(db);
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

    test('当天愿望单会写入首页消息并推送系统通知（内容含食材/酱料汇总）', () async {
      final ingredientId = await tagRepository.createTag(
        name: '鸡蛋',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final sauceId = await tagRepository.createTag(
        name: '盐',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );

      final now = DateTime(2026, 1, 10, 9);
      final recipeId = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '番茄炒蛋',
          coverImageKey: null,
          typeTagId: null,
          ingredientTagIds: [ingredientId],
          sauceTagIds: [sauceId],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );

      await repository.addWish(date: now, recipeId: recipeId, now: now);

      final service = OvercookedReminderService(
        repository: repository,
        tagRepository: tagRepository,
      );
      await service.pushDueReminders(messageService: messageService, now: now);

      expect(messageService.messages.length, 1);
      expect(notificationService.shown.length, 1);

      final body = messageService.messages.single.body;
      expect(body, contains('番茄炒蛋'));
      expect(body, contains('鸡蛋'));
      expect(body, contains('盐'));

      await service.pushDueReminders(messageService: messageService, now: now);
      expect(messageService.messages.length, 1);
      expect(notificationService.shown.length, 1);
    });

    test('同一天重复检查时，不应把已读重置为未读', () async {
      final now = DateTime(2026, 1, 10, 9);
      final recipeId = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '拍黄瓜',
          coverImageKey: null,
          typeTagId: null,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );
      await repository.addWish(date: now, recipeId: recipeId, now: now);

      final service = OvercookedReminderService(repository: repository);
      await service.pushDueReminders(messageService: messageService, now: now);

      final id = messageService.messages.single.id;
      expect(id, isNotNull);
      await messageService.markMessageRead(
        id!,
        readAt: DateTime(2026, 1, 10, 10),
      );
      expect(messageService.unreadMessages, isEmpty);

      await service.pushDueReminders(
        messageService: messageService,
        now: DateTime(2026, 1, 10, 20),
      );

      expect(messageService.messages.single.isRead, isTrue);
      expect(messageService.unreadMessages, isEmpty);
      expect(notificationService.shown.length, 1);
    });
  });
}
