import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';
import 'package:life_tools/tools/xiao_mi/models/xiao_mi_message.dart';
import 'package:life_tools/tools/xiao_mi/repository/xiao_mi_repository.dart';
import 'package:life_tools/tools/xiao_mi/services/xiao_mi_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/fake_openai_client.dart';
import '../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('XiaoMiChatService', () {
    late Database db;
    late XiaoMiRepository repository;
    late AiConfigService configService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      configService = AiConfigService();
      await configService.init();
      await configService.save(
        const AiConfig(
          baseUrl: 'https://example.com',
          apiKey: 'k',
          model: 'm',
          temperature: 0.2,
          maxOutputTokens: 128,
        ),
      );

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

    test('send 非特殊调用时应直接使用预选回答', () async {
      var now = DateTime(2026, 1, 1, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final fakeClient = FakeOpenAiClient(
        replyText: '这是预选阶段直接回答',
        streamReply: const [AiChatStreamChunk(textDelta: '不应走到这里')],
      );
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );

      final service = XiaoMiChatService(
        repository: repository,
        aiService: aiService,
        nowProvider: nextNow,
        promptResolver: XiaoMiPromptResolver(
          workLogRepository: FakeWorkLogRepository(),
        ),
      );
      await service.init();
      await service.send('你好');

      expect(service.messages.length, 2);
      expect(service.messages.first.role, XiaoMiMessageRole.user);
      expect(service.messages.first.content, '你好');
      expect(service.messages.last.role, XiaoMiMessageRole.assistant);
      expect(service.messages.last.content, '这是预选阶段直接回答');
    });

    test('send 预选返回 special_call 时应注入年度总结数据并流式回答', () async {
      var now = DateTime(2026, 1, 1, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final workLogRepository = FakeWorkLogRepository();
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 9),
        ),
      );
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 2, 3),
          minutes: 45,
          content: '完成核心模块',
          now: DateTime(2026, 2, 3, 9),
        ),
      );

      final fakeClient = FakeOpenAiClient(
        replyText: '{"type":"special_call","call":"work_log_year_summary"}',
        streamReply: const [
          AiChatStreamChunk(textDelta: '第一', reasoningDelta: '先分析'),
          AiChatStreamChunk(textDelta: '段', reasoningDelta: '再归纳'),
        ],
      );
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );

      final service = XiaoMiChatService(
        repository: repository,
        aiService: aiService,
        nowProvider: nextNow,
        promptResolver: XiaoMiPromptResolver(
          workLogRepository: workLogRepository,
        ),
      );
      await service.init();

      final sendFuture = service.send('请基于今年记录写一个工作总结');
      addTearDown(() async {
        await sendFuture;
      });
      await _waitUntil(
        () =>
            service.messages.any((m) => m.role == XiaoMiMessageRole.assistant),
      );

      final streamingAssistant = service.messages
          .where((m) => m.role == XiaoMiMessageRole.assistant)
          .toList();
      expect(streamingAssistant, isNotEmpty);
      expect(streamingAssistant.single.content, isNotEmpty);
      expect(
        (streamingAssistant.single.metadata ?? const {})['thinking'],
        isNotEmpty,
      );

      await sendFuture;

      final finalAssistant = service.messages.last;
      expect(finalAssistant.role, XiaoMiMessageRole.assistant);
      expect(finalAssistant.content, '第一段');
      expect((finalAssistant.metadata ?? const {})['thinking'], '先分析再归纳');

      final activeConversationId = service.currentConversation!.id!;
      final persisted = await repository.listMessages(activeConversationId);
      expect(persisted.length, 2);
      final persistedAssistant = persisted.last;
      expect(persistedAssistant.content, '第一段');
      expect((persistedAssistant.metadata ?? const {})['thinking'], '先分析再归纳');

      expect(
        (service.messages.first.metadata ?? const {})['presetId'],
        'work_log_year_summary',
      );
      expect(
        (service.messages.first.metadata ?? const {})['triggerSource'],
        'pre_route',
      );
      expect(fakeClient.lastRequest, isNotNull);
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('时间范围：2026-01-01'),
      );
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('内容：完成核心模块'),
      );
    });

    test('deleteMessages 应支持删除多条消息并更新内存列表', () async {
      final base = DateTime(2026, 1, 1, 8, 0, 0);
      var now = base;
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final aiService = AiService(
        configService: configService,
        client: FakeOpenAiClient(replyText: 'ok'),
      );

      final service = XiaoMiChatService(
        repository: repository,
        aiService: aiService,
        nowProvider: nextNow,
        promptResolver: XiaoMiPromptResolver(
          workLogRepository: FakeWorkLogRepository(),
        ),
      );
      await service.init();
      final convoId = service.currentConversation!.id!;

      final firstId = await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.user,
          content: 'A',
          createdAt: base.add(const Duration(seconds: 10)),
        ),
      );
      await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.assistant,
          content: 'B',
          createdAt: base.add(const Duration(seconds: 11)),
        ),
      );
      final thirdId = await repository.addMessage(
        XiaoMiMessage.create(
          conversationId: convoId,
          role: XiaoMiMessageRole.user,
          content: 'C',
          createdAt: base.add(const Duration(seconds: 12)),
        ),
      );

      await service.openConversation(convoId);
      expect(service.messages.length, 3);

      await service.deleteMessages({firstId, thirdId});

      expect(service.messages.length, 1);
      expect(service.messages.single.content, 'B');
      final persisted = await repository.listMessages(convoId);
      expect(persisted.length, 1);
      expect(persisted.single.content, 'B');
    });
  });
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(milliseconds: 500),
  Duration interval = const Duration(milliseconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('等待条件超时');
    }
    await Future<void>.delayed(interval);
  }
}
