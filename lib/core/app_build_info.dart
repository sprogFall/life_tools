import 'dart:convert';

class AppBuildInfo {
  AppBuildInfo._();

  static const String _commitShaEnv = String.fromEnvironment(
    'APP_COMMIT_SHA',
    defaultValue: '',
  );
  static const String _commitMessageEnv = String.fromEnvironment(
    'APP_COMMIT_MESSAGE',
    defaultValue: '',
  );
  static const String _commitMessageBase64Env = String.fromEnvironment(
    'APP_COMMIT_MESSAGE_BASE64',
    defaultValue: '',
  );

  static String get commitSha {
    final value = _commitShaEnv.trim();
    return value.isEmpty ? 'local-dev' : value;
  }

  static String get shortCommitSha {
    final value = commitSha;
    if (value == 'local-dev') return value;
    return value.length <= 8 ? value : value.substring(0, 8);
  }

  static String get commitMessage {
    final decoded = _tryDecodeBase64(_commitMessageBase64Env);
    if ((decoded ?? '').isNotEmpty) return decoded!;

    final plain = _commitMessageEnv.trim();
    if (plain.isNotEmpty) return plain;

    return '本地开发构建';
  }

  static String? _tryDecodeBase64(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      final normalized = base64.normalize(value);
      return utf8.decode(base64Decode(normalized), allowMalformed: true).trim();
    } catch (_) {
      return null;
    }
  }
}
