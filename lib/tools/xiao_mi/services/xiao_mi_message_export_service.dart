import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/backup/services/share_service.dart';
import '../../../core/utils/dev_log.dart';
import '../models/xiao_mi_message.dart';

enum XiaoMiMessageExportFormat { markdown, pdf }

typedef XiaoMiShareTextFile =
    Future<void> Function({
      required String text,
      required String fileName,
      required String subject,
      required String mimeType,
    });

typedef XiaoMiShareBinaryFile =
    Future<void> Function({
      required Uint8List bytes,
      required String fileName,
      required String subject,
      required String mimeType,
    });

typedef XiaoMiBuildPdfBytes = Future<Uint8List> Function(String markdown);
typedef XiaoMiResolvePdfFont = Future<pw.Font?> Function();

class XiaoMiMessageExportService {
  XiaoMiMessageExportService({
    DateTime Function()? now,
    XiaoMiShareTextFile? shareTextFile,
    XiaoMiShareBinaryFile? shareBinaryFile,
    XiaoMiBuildPdfBytes? buildPdfBytes,
    XiaoMiResolvePdfFont? resolvePdfFont,
  }) : _now = now ?? DateTime.now,
       _shareTextFile = shareTextFile ?? _defaultShareTextFile,
       _shareBinaryFile = shareBinaryFile ?? _defaultShareBinaryFile,
       _customBuildPdfBytes = buildPdfBytes,
       _resolvePdfFont = resolvePdfFont ?? _defaultResolvePdfFont;

  static const String _shareSubject = '小蜜消息导出';

  final DateTime Function() _now;
  final XiaoMiShareTextFile _shareTextFile;
  final XiaoMiShareBinaryFile _shareBinaryFile;
  final XiaoMiBuildPdfBytes? _customBuildPdfBytes;
  final XiaoMiResolvePdfFont _resolvePdfFont;
  Future<pw.Font?>? _bundledFontFuture;

  static const String _bundledFontAssetPath =
      'assets/fonts/NotoSansSC-Regular.ttf';

  Future<void> exportMessage({
    required XiaoMiMessage message,
    required XiaoMiMessageExportFormat format,
  }) async {
    final markdown = buildMarkdown(message);
    final fileName = _buildFileName(format);
    if (format == XiaoMiMessageExportFormat.markdown) {
      await _shareTextFile(
        text: markdown,
        fileName: fileName,
        subject: _shareSubject,
        mimeType: 'text/markdown',
      );
      return;
    }

    final customBuildPdfBytes = _customBuildPdfBytes;
    final pdfBytes = customBuildPdfBytes != null
        ? await customBuildPdfBytes(markdown)
        : await _buildPdfBytes(markdown);
    await _shareBinaryFile(
      bytes: pdfBytes,
      fileName: fileName,
      subject: _shareSubject,
      mimeType: 'application/pdf',
    );
  }

  String buildMarkdown(XiaoMiMessage message) {
    final roleText = switch (message.role) {
      XiaoMiMessageRole.user => '用户',
      XiaoMiMessageRole.assistant => '小蜜',
      XiaoMiMessageRole.system => '系统',
    };
    final createdAt = _formatDateTime(message.createdAt);
    final content = message.content.trim();
    return '''
# 小蜜聊天消息

- 角色：$roleText
- 时间：$createdAt

---

$content
''';
  }

  String _buildFileName(XiaoMiMessageExportFormat format) {
    final now = _now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final ext = format == XiaoMiMessageExportFormat.markdown ? 'md' : 'pdf';
    return 'xiao_mi_message_$y$m$d'
        '_$hh$mm$ss.$ext';
  }

  static String _formatDateTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  static Future<void> _defaultShareTextFile({
    required String text,
    required String fileName,
    required String subject,
    required String mimeType,
  }) async {
    await ShareService.shareTextFile(
      text,
      fileName,
      subject: subject,
      mimeType: mimeType,
    );
  }

  static Future<void> _defaultShareBinaryFile({
    required Uint8List bytes,
    required String fileName,
    required String subject,
    required String mimeType,
  }) async {
    await ShareService.shareBinaryFile(
      bytes,
      fileName,
      subject: subject,
      mimeType: mimeType,
    );
  }

  static bool _isType1Font(pw.Font font) => font.font != null;

  static Future<pw.Font?> _defaultResolvePdfFont() async => null;

  Future<pw.Font?> _loadBundledPdfFont() {
    return _bundledFontFuture ??= _tryLoadBundledPdfFont();
  }

  static Future<pw.Font?> _tryLoadBundledPdfFont() async {
    try {
      final data = await rootBundle.load(_bundledFontAssetPath);
      return pw.Font.ttf(data);
    } catch (error, stackTrace) {
      devLog(
        'xiao_mi_pdf_bundled_font_load_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<pw.Font?> _resolvePdfFontOrFallback() async {
    pw.Font? resolved;
    try {
      resolved = await _resolvePdfFont();
    } catch (error, stackTrace) {
      devLog(
        'xiao_mi_pdf_font_resolve_failed',
        error: error,
        stackTrace: stackTrace,
      );
      resolved = null;
    }

    if (resolved != null && !_isType1Font(resolved)) return resolved;

    final bundled = await _loadBundledPdfFont();
    return bundled ?? resolved;
  }

  Future<Uint8List> _buildPdfBytes(String markdown) async {
    final document = pw.Document();
    final font = await _resolvePdfFontOrFallback();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: font == null
            ? null
            : pw.ThemeData.withFont(
                base: font,
                bold: font,
                italic: font,
                boldItalic: font,
              ),
        build: (context) => [pw.Text(markdown)],
      ),
    );
    return document.save();
  }
}
