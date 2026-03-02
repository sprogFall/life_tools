import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/database/database_schema.dart';
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

    test('send 应流式更新助手内容并保存思考过程', () async {
      var now = DateTime(2026, 1, 1, 8, 0, 0);
      DateTime nextNow() {
        final value = now;
        now = now.add(const Duration(seconds: 1));
        return value;
      }

      final aiService = AiService(
        configService: configService,
        client: FakeOpenAiClient(
          replyText: 'unused',
          streamReply: const [
            AiChatStreamChunk(textDelta: '第一', reasoningDelta: '先分析'),
            AiChatStreamChunk(textDelta: '段', reasoningDelta: '再归纳'),
          ],
          streamChunkDelay: Duration(milliseconds: 5),
        ),
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

      final sendFuture = service.send('你好');
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
