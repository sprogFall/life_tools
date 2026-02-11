import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_call_history_service.dart';
import 'package:life_tools/core/ai/ai_call_source.dart';
import 'package:life_tools/pages/ai_call_history_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiCallHistoryPage', () {
    const source = AiCallSource(
      toolId: 'stockpile_assistant',
      toolName: '囤货助手',
      featureId: 'text_to_intent',
      featureName: '文本解析',
    );

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    Future<AiCallHistoryService> createService() async {
      final service = AiCallHistoryService();
      await service.init();
      return service;
    }

    testWidgets('应展示记录并支持查看详情与Markdown切换', (tester) async {
      final service = await createService();
      await service.addRecord(
        source: source,
        model: 'gpt-4o-mini',
        prompt: '# 标题\n\n这是提示词',
        response: '## 返回\n\n这是AI回复',
        createdAt: DateTime(2026, 2, 11, 10, 30),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: AiCallHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('囤货助手 · 文本解析'), findsOneWidget);
      expect(find.textContaining('模型：gpt-4o-mini'), findsOneWidget);

      await tester.tap(find.text('查看详情').first);
      await tester.pumpAndSettle();

      expect(find.text('提示词详情'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ai_history_plain_text_view')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('ai_history_markdown_switch')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ai_history_markdown_view')),
        findsOneWidget,
      );
    });

    testWidgets('应支持调整历史记录保留条数', (tester) async {
      final service = await createService();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: AiCallHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('仅保留最近5条记录'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ai_history_limit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('10 条'));
      await tester.pumpAndSettle();

      expect(find.text('仅保留最近10条记录'), findsOneWidget);
    });
  });
}
