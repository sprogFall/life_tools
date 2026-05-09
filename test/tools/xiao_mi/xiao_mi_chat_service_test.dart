import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
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

    test('send 非特殊调用时应先路由再走流式回答', () async {
      var now = DateTime(2026, 1, 1, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final fakeClient = FakeOpenAiClient(
        replyText: '{"type":"no_special_call"}',
        streamReply: const [
          AiChatStreamChunk(textDelta: '流式'),
          AiChatStreamChunk(textDelta: '回答'),
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
          workLogRepository: FakeWorkLogRepository(),
        ),
      );
      await service.init();
      await service.send('你好');

      expect(service.messages.length, 2);
      expect(service.messages.first.role, XiaoMiMessageRole.user);
      expect(service.messages.first.content, '你好');
      expect(service.messages.last.role, XiaoMiMessageRole.assistant);
      expect(service.messages.last.content, '流式回答');
      expect(fakeClient.lastChatRequest, isNotNull);
      expect(
        fakeClient.lastChatRequest!.responseFormat,
        AiResponseFormat.jsonObject,
      );
      expect(fakeClient.chatCompletionsCallCount, 1);
      expect(fakeClient.chatCompletionsStreamCallCount, 1);
    });

    test('send 应把 AI 回复 token 与耗时写入 assistant metadata', () async {
      final now = DateTime(2026, 1, 1, 8, 0, 0);
      final fakeClient = FakeOpenAiClient(
        replyText: '{"type":"no_special_call"}',
        streamReply: const [
          AiChatStreamChunk(textDelta: '统计完成'),
          AiChatStreamChunk(
            usage: AiTokenUsage(
              promptTokens: 1234,
              completionTokens: 56,
              totalTokens: 1290,
            ),
          ),
        ],
      );
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );

      final service = XiaoMiChatService(
        repository: repository,
        aiService: aiService,
        nowProvider: () => now,
        promptResolver: XiaoMiPromptResolver(
          workLogRepository: FakeWorkLogRepository(),
        ),
      );
      await service.init();
      await service.send('你好');

      final metadata = service.messages.last.metadata ?? const {};
      final usage =
          metadata[XiaoMiChatService.assistantUsageMetadataKey] as Map;
      expect(usage['promptTokens'], 1234);
      expect(usage['completionTokens'], 56);
      expect(usage['totalTokens'], 1290);
      expect(usage['durationMs'], 0);

      final persisted = await repository.listMessages(
        service.currentConversation!.id!,
      );
      final persistedUsage =
          (persisted.last.metadata ??
                  const {})[XiaoMiChatService.assistantUsageMetadataKey]
              as Map;
      expect(persistedUsage['promptTokens'], 1234);
      expect(persistedUsage['completionTokens'], 56);
      expect(persistedUsage['totalTokens'], 1290);
      expect(persistedUsage['durationMs'], 0);
    });

    test('send 命中内置预置词时应跳过预选路由并直接注入上下文', () async {
      var now = DateTime(2026, 5, 20, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final workLogRepository = FakeWorkLogRepository();
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '任务预置',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 5, 20, 9),
        ),
      );
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 5, 19),
          minutes: 50,
          content: '本周预置记录',
          now: DateTime(2026, 5, 19, 9),
        ),
      );

      final fakeClient = FakeOpenAiClient(
        replyText: '{"type":"no_special_call"}',
        streamReply: const [AiChatStreamChunk(textDelta: '直接完成')],
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
          nowProvider: () => DateTime(2026, 5, 20, 8),
        ),
      );
      await service.init();
      await service.send(' 本周工作总结 ');

      expect(fakeClient.chatCompletionsCallCount, 0);
      expect(fakeClient.chatCompletionsStreamCallCount, 1);
      expect(fakeClient.lastStreamRequest, isNotNull);
      expect(
        fakeClient.lastStreamRequest!.messages.last.content,
        contains('时间范围：2026-05-18 至 2026-05-24（含）'),
      );
      expect(
        fakeClient.lastStreamRequest!.messages.last.content,
        contains('内容：本周预置记录'),
      );
      expect(
        (service.messages.first.metadata ?? const {})['triggerSource'],
        'preset',
      );
      expect(
        (service.messages.first.metadata ?? const {})['queryStartDate'],
        '2026-05-18',
      );
      expect(
        (service.messages.first.metadata ?? const {})['queryEndDate'],
        '2026-05-24',
      );
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
        (service.messages.first.metadata ?? const {})['queryStartDate'],
        '2026-01-01',
      );
      expect(
        (service.messages.first.metadata ?? const {})['queryEndDate'],
        '2026-12-31',
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
      expect(fakeClient.chatCompletionsCallCount, 1);
      expect(fakeClient.chatCompletionsStreamCallCount, 1);
    });

    test('send 命中年度总结预置词时应直接按日期区间注入工作记录', () async {
      var now = DateTime(2026, 1, 1, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final workLogRepository = FakeWorkLogRepository();
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '任务范围',
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
          content: '年度范围内',
          now: DateTime(2026, 2, 3, 9),
        ),
      );
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2025, 12, 31),
          minutes: 30,
          content: '年度范围外',
          now: DateTime(2025, 12, 31, 9),
        ),
      );

      final fakeClient = FakeOpenAiClient(
        replyText:
            '{"type":"special_call","call":"work_log_range_summary","arguments":{"start_date":"20260101","end_date":"20261231"}}',
        streamReply: const [AiChatStreamChunk(textDelta: '范围总结完成')],
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
      await service.send('今年工作总结');

      expect(service.messages.length, 2);
      expect(service.messages.last.content, '范围总结完成');
      expect(
        (service.messages.first.metadata ?? const {})['queryStartDate'],
        '2026-01-01',
      );
      expect(
        (service.messages.first.metadata ?? const {})['queryEndDate'],
        '2026-12-31',
      );
      expect(
        (service.messages.first.metadata ?? const {})['triggerSource'],
        'preset',
      );
      expect(fakeClient.lastRequest, isNotNull);
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('时间范围：2026-01-01 至 2026-12-31（含）'),
      );
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('内容：年度范围内'),
      );
      expect(
        fakeClient.lastRequest!.messages.last.content,
        isNot(contains('内容：年度范围外')),
      );
      expect(fakeClient.chatCompletionsCallCount, 0);
      expect(fakeClient.chatCompletionsStreamCallCount, 1);
    });

    test('send 预选返回 overcooked_context_query 时应注入胡闹厨房菜谱信息', () async {
      var now = DateTime(2026, 1, 1, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final overcookedRepository = OvercookedRepository.withDatabase(db);
      await overcookedRepository.createRecipe(
        OvercookedRecipe.create(
          name: '宫保鸡丁',
          coverImageKey: null,
          typeTagId: null,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '下饭菜',
          content: '步骤1：滑油。步骤2：爆香。',
          detailImageKeys: const [],
          now: DateTime(2026, 1, 2, 9),
        ),
      );

      final fakeClient = FakeOpenAiClient(
        replyText:
            '{"type":"special_call","call":"overcooked_context_query","arguments":{"query_type":"recipe_lookup","recipe_name":"宫保鸡丁"}}',
        streamReply: const [AiChatStreamChunk(textDelta: '按已有菜谱回复')],
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
          overcookedRepository: overcookedRepository,
        ),
      );
      await service.init();
      await service.send('宫保鸡丁怎么做');

      expect(service.messages.length, 2);
      expect(service.messages.last.content, '按已有菜谱回复');
      expect(
        (service.messages.first.metadata ?? const {})['triggerSource'],
        'pre_route',
      );
      expect(fakeClient.lastRequest, isNotNull);
      expect(fakeClient.lastRequest!.messages.last.content, contains('宫保鸡丁'));
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('胡闹厨房菜谱查询结果'),
      );
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('菜谱正文：步骤1：滑油。步骤2：爆香。'),
      );
      expect(fakeClient.chatCompletionsCallCount, 1);
      expect(fakeClient.chatCompletionsStreamCallCount, 1);
    });

    test('send 预选返回 work_log_query 时应按组合条件注入精简字段', () async {
      var now = DateTime(2026, 4, 20, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final workLogRepository = WorkLogRepository.withDatabase(db);
      final tagRepository = TagRepository.withDatabase(db);
      final projectAId = await tagRepository.createTagForToolCategory(
        name: '项目A',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final taskAId = await workLogRepository.createTask(
        WorkTask.create(
          title: '接口联调',
          description: '支付回调对齐',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 4, 20, 9),
        ),
      );
      final taskBId = await workLogRepository.createTask(
        WorkTask.create(
          title: '月度复盘',
          description: '收尾',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.done,
          estimatedMinutes: 0,
          now: DateTime(2026, 4, 20, 9),
        ),
      );
      await tagRepository.setTagsForWorkTask(taskAId, [projectAId]);
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskAId,
          workDate: DateTime(2026, 4, 12),
          minutes: 90,
          content: '完成支付接口联调并验证回调',
          now: DateTime(2026, 4, 12, 9),
        ),
      );
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskBId,
          workDate: DateTime(2026, 4, 15),
          minutes: 45,
          content: '接口问题复盘',
          now: DateTime(2026, 4, 15, 9),
        ),
      );

      final fakeClient = FakeOpenAiClient(
        replyText:
            '{"type":"special_call","call":"work_log_query","arguments":{"start_date":"20260401","end_date":"20260430","keyword":"接口","statuses":["doing"],"affiliation_names":["项目A"],"fields":["work_date","task_title","minutes"],"limit":1}}',
        streamReply: const [AiChatStreamChunk(textDelta: '查询结果已整理')],
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
          tagRepository: tagRepository,
          nowProvider: () => DateTime(2026, 4, 20, 8),
        ),
      );
      await service.init();
      await service.send('查下四月项目A里跟接口相关且进行中的工作记录');

      expect(service.messages.length, 2);
      expect(service.messages.last.content, '查询结果已整理');
      expect(
        (service.messages.first.metadata ?? const {})['triggerSource'],
        'pre_route',
      );
      expect(
        (service.messages.first.metadata ?? const {})['queryStartDate'],
        '2026-04-01',
      );
      expect(
        (service.messages.first.metadata ?? const {})['queryEndDate'],
        '2026-04-30',
      );
      expect(fakeClient.lastRequest, isNotNull);
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('工作记录查询结果'),
      );
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('work_date=2026-04-12 | task_title=接口联调 | minutes=90'),
      );
      expect(
        fakeClient.lastRequest!.messages.last.content,
        isNot(contains('content=')),
      );
      expect(
        fakeClient.lastRequest!.messages.last.content,
        isNot(contains('月度复盘')),
      );
      expect(fakeClient.chatCompletionsCallCount, 1);
      expect(fakeClient.chatCompletionsStreamCallCount, 1);
    });

    test('send 预选返回 work_task_query 时应注入任务列表结果', () async {
      var now = DateTime(2026, 4, 20, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final workLogRepository = WorkLogRepository.withDatabase(db);
      await workLogRepository.createTask(
        WorkTask.create(
          title: '防汛巡查',
          description: '河道排查',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 180,
          now: DateTime(2026, 4, 20, 9),
        ),
      );

      final fakeClient = FakeOpenAiClient(
        replyText:
            '{"type":"special_call","call":"work_task_query","arguments":{"keyword":"防汛","statuses":["doing"],"fields":["task_title","task_status","estimated_minutes"],"limit":1}}',
        streamReply: const [AiChatStreamChunk(textDelta: '任务结果已整理')],
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
          nowProvider: () => DateTime(2026, 4, 20, 8),
        ),
      );
      await service.init();
      await service.send('查一下防汛相关任务');

      expect(service.messages.length, 2);
      expect(service.messages.last.content, '任务结果已整理');
      expect(
        (service.messages.first.metadata ?? const {})['triggerSource'],
        'pre_route',
      );
      expect(fakeClient.lastRequest, isNotNull);
      expect(fakeClient.lastRequest!.messages.last.content, contains('任务查询结果'));
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('task_title=防汛巡查 | task_status=doing | estimated_minutes=180'),
      );
      expect(
        fakeClient.lastRequest!.messages.last.content,
        isNot(contains('工作记录查询结果')),
      );
      expect(fakeClient.chatCompletionsCallCount, 1);
      expect(fakeClient.chatCompletionsStreamCallCount, 1);
    });

    test('send 失败时应在会话中写入错误消息并附带原因', () async {
      var now = DateTime(2026, 1, 1, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      await configService.clear();
      final fakeClient = FakeOpenAiClient(
        replyText: '{"type":"no_special_call"}',
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

      await service.send('测试错误展示');

      expect(service.messages.length, 2);
      expect(service.messages.first.role, XiaoMiMessageRole.user);
      expect(service.messages.last.role, XiaoMiMessageRole.assistant);
      expect(service.messages.last.content, 'AI 未配置，请先到设置中完成配置后再试。');
      final errorMeta =
          (service.messages.last.metadata ??
          const <String, dynamic>{})[XiaoMiChatService
              .assistantErrorMetadataKey];
      expect(errorMeta, isA<Map>());
      final errorMap = (errorMeta as Map).cast<String, dynamic>();
      expect(errorMap['type'], 'ai_not_configured');
      expect((errorMap['reason'] as String), contains('请先在设置中完成 AI 配置'));
      expect(fakeClient.chatCompletionsCallCount, 0);
      expect(fakeClient.chatCompletionsStreamCallCount, 0);
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

    test('deleteConversations 应支持批量删除并在当前会话被删时切到剩余会话', () async {
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
      final firstConvoId = service.currentConversation!.id!;
      await repository.updateConversationTitle(
        conversationId: firstConvoId,
        title: 'A',
        now: base,
      );

      await service.newConversation();
      final secondConvoId = service.currentConversation!.id!;
      await repository.updateConversationTitle(
        conversationId: secondConvoId,
        title: 'B',
        now: base.add(const Duration(seconds: 1)),
      );

      await service.newConversation();
      final thirdConvoId = service.currentConversation!.id!;
      await repository.updateConversationTitle(
        conversationId: thirdConvoId,
        title: 'C',
        now: base.add(const Duration(seconds: 2)),
      );

      await service.openConversation(secondConvoId);
      expect(service.currentConversation!.id, secondConvoId);

      await service.deleteConversations({firstConvoId, secondConvoId});

      expect(service.conversations.map((item) => item.id).toList(), [
        thirdConvoId,
      ]);
      expect(service.currentConversation, isNotNull);
      expect(service.currentConversation!.id, thirdConvoId);
      expect(await repository.getConversation(firstConvoId), isNull);
      expect(await repository.getConversation(secondConvoId), isNull);
      expect(await repository.getConversation(thirdConvoId), isNotNull);
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
