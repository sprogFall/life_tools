import 'dart:typed_data';

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
        shareBinaryFile:
            ({
              required Uint8List bytes,
              required String fileName,
              required String subject,
              required String mimeType,
            }) async {
              fail('Markdown 导出不应调用二进制分享');
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
        format: XiaoMiMessageExportFormat.markdown,
      );

      expect(sharedFileName, 'xiao_mi_message_20260305_123456.md');
      expect(sharedSubject, '小蜜消息导出');
      expect(sharedMimeType, 'text/markdown');
      expect(sharedText, contains('角色：用户'));
      expect(sharedText, contains('今天完成了接口联调'));
    });

    test('导出 PDF 应先生成 PDF 字节并走二进制分享', () async {
      String? pdfSourceMarkdown;
      Uint8List? sharedBytes;
      String? sharedFileName;
      String? sharedSubject;
      String? sharedMimeType;

      final service = XiaoMiMessageExportService(
        now: () => DateTime(2026, 3, 5, 12, 34, 56),
        buildPdfBytes: (markdown) async {
          pdfSourceMarkdown = markdown;
          return Uint8List.fromList([1, 2, 3, 4]);
        },
        shareTextFile:
            ({
              required String text,
              required String fileName,
              required String subject,
              required String mimeType,
            }) async {
              fail('PDF 导出不应调用文本分享');
            },
        shareBinaryFile:
            ({
              required Uint8List bytes,
              required String fileName,
              required String subject,
              required String mimeType,
            }) async {
              sharedBytes = bytes;
              sharedFileName = fileName;
              sharedSubject = subject;
              sharedMimeType = mimeType;
            },
      );

      await service.exportMessage(
        message: XiaoMiMessage(
          id: 2,
          conversationId: 1,
          role: XiaoMiMessageRole.assistant,
          content: '建议先补测试再实现功能。',
          metadata: null,
          createdAt: messageTime,
        ),
        format: XiaoMiMessageExportFormat.pdf,
      );

      expect(pdfSourceMarkdown, contains('角色：小蜜'));
      expect(pdfSourceMarkdown, contains('建议先补测试再实现功能。'));
      expect(sharedBytes, Uint8List.fromList([1, 2, 3, 4]));
      expect(sharedFileName, 'xiao_mi_message_20260305_123456.pdf');
      expect(sharedSubject, '小蜜消息导出');
      expect(sharedMimeType, 'application/pdf');
    });

    test('默认 PDF 构建在中文内容下也应导出成功', () async {
      Uint8List? sharedBytes;

      final service = XiaoMiMessageExportService(
        now: () => DateTime(2026, 3, 5, 12, 34, 56),
        resolvePdfFont: () async => null,
        shareTextFile:
            ({
              required String text,
              required String fileName,
              required String subject,
              required String mimeType,
            }) async {
              fail('PDF 导出不应调用文本分享');
            },
        shareBinaryFile:
            ({
              required Uint8List bytes,
              required String fileName,
              required String subject,
              required String mimeType,
            }) async {
              sharedBytes = bytes;
            },
      );

      await service.exportMessage(
        message: XiaoMiMessage(
          id: 3,
          conversationId: 1,
          role: XiaoMiMessageRole.assistant,
          content: '这是一段中文内容，用于验证 PDF 导出。',
          metadata: null,
          createdAt: messageTime,
        ),
        format: XiaoMiMessageExportFormat.pdf,
      );

      expect(sharedBytes, isNotNull);
      expect(sharedBytes, isNotEmpty);
    });
  });
}
