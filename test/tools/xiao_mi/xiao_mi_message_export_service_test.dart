import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/xiao_mi/models/xiao_mi_message.dart';
import 'package:life_tools/tools/xiao_mi/services/xiao_mi_message_export_service.dart';

void main() {
  group('XiaoMiMessageExportService', () {
    final messageTime = DateTime(2026, 3, 5, 8, 30, 0);

    test('导出 Markdown 应走文本分享并生成 md 文件', () async {
      String? sharedText;
      String? sharedFileName;
      String? sharedSubject;
      String? sharedMimeType;

      final service = XiaoMiMessageExportService(
        now: () => DateTime(2026, 3, 5, 12, 34, 56),
        shareTextFile:
            ({
              required String text,
              required String fileName,
              required String subject,
              required String mimeType,
            }) async {
              sharedText = text;
              sharedFileName = fileName;
              sharedSubject = subject;
              sharedMimeType = mimeType;
            },
      );

      await service.exportMessage(
        message: XiaoMiMessage(
          id: 1,
          conversationId: 1,
          role: XiaoMiMessageRole.user,
          content: '今天完成了接口联调',
          metadata: null,
          createdAt: messageTime,
        ),
      );

      expect(sharedFileName, 'xiao_mi_message_20260305_123456.md');
      expect(sharedSubject, '小蜜消息导出');
      expect(sharedMimeType, 'text/markdown');
      expect(sharedText, contains('角色：用户'));
      expect(sharedText, contains('今天完成了接口联调'));
    });

    test('导出内容应保留 Markdown 标题与时间信息', () async {
      String? sharedText;

      final service = XiaoMiMessageExportService(
        now: () => DateTime(2026, 3, 5, 12, 34, 56),
        shareTextFile:
            ({
              required String text,
              required String fileName,
              required String subject,
              required String mimeType,
            }) async {
              sharedText = text;
            },
      );

      await service.exportMessage(
        message: XiaoMiMessage(
          id: 8,
          conversationId: 1,
          role: XiaoMiMessageRole.assistant,
          content: '  输出一段带前后空白的正文  ',
          metadata: null,
          createdAt: messageTime,
        ),
      );

      expect(sharedText, isNotNull);
      expect(sharedText, startsWith('# 小蜜聊天消息'));
      expect(sharedText, contains('- 时间：2026-03-05 08:30:00'));
      expect(sharedText, contains('输出一段带前后空白的正文'));
    });
  });
}
