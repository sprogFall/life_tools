import '../../../core/backup/services/share_service.dart';
import '../models/xiao_mi_message.dart';

typedef XiaoMiShareTextFile =
    Future<void> Function({
      required String text,
      required String fileName,
      required String subject,
      required String mimeType,
    });

enum XiaoMiMessageExportFormat { markdown, text }

class XiaoMiMessageExportService {
  XiaoMiMessageExportService({
    DateTime Function()? now,
    XiaoMiShareTextFile? shareTextFile,
  }) : _now = now ?? DateTime.now,
       _shareTextFile = shareTextFile ?? _defaultShareTextFile;

  static const String _shareSubject = '小蜜消息导出';

  final DateTime Function() _now;
  final XiaoMiShareTextFile _shareTextFile;

  Future<void> exportMessage({
    required XiaoMiMessage message,
    required XiaoMiMessageExportFormat format,
  }) async {
    final content = _buildExportContent(message, format);
    final fileName = _buildFileName(format);
    final mimeType = _mimeTypeFor(format);
    await _shareTextFile(
      text: content,
      fileName: fileName,
      subject: _shareSubject,
      mimeType: mimeType,
    );
  }

  String _buildExportContent(
    XiaoMiMessage message,
    XiaoMiMessageExportFormat format,
  ) {
    return switch (format) {
      XiaoMiMessageExportFormat.markdown => buildMarkdown(message),
      XiaoMiMessageExportFormat.text => buildText(message),
    };
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

  String buildText(XiaoMiMessage message) {
    final roleText = switch (message.role) {
      XiaoMiMessageRole.user => '用户',
      XiaoMiMessageRole.assistant => '小蜜',
      XiaoMiMessageRole.system => '系统',
    };
    final createdAt = _formatDateTime(message.createdAt);
    final content = message.content.trim();
    return '''
小蜜聊天消息

角色：$roleText
时间：$createdAt

--------------------

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
    final ext = switch (format) {
      XiaoMiMessageExportFormat.markdown => 'md',
      XiaoMiMessageExportFormat.text => 'txt',
    };
    return 'xiao_mi_message_$y$m$d'
        '_$hh$mm$ss.$ext';
  }

  static String _mimeTypeFor(XiaoMiMessageExportFormat format) {
    return switch (format) {
      XiaoMiMessageExportFormat.markdown => 'text/markdown',
      XiaoMiMessageExportFormat.text => 'text/plain',
    };
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
}
