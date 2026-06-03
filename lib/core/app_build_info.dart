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
  static const String _versionEnv = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const String _isPreReleaseEnv = String.fromEnvironment(
    'APP_IS_PRERELEASE',
    defaultValue: 'false',
  );

  static String get version {
    final value = _versionEnv.trim();
    return value.isEmpty ? '1.0.0' : value;
  }

  /// 当前构建是否为预发布版本（体验版）
  static bool get isPreRelease {
    return _isPreReleaseEnv.toLowerCase() == 'true';
  }

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
