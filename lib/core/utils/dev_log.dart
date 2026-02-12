import 'dart:developer' as developer;

/// 仅在 Debug 模式输出的日志（Release 下 assert 不执行）。
///
/// 注意：禁止在 message/error 中包含密钥/令牌等敏感信息。
void devLog(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String name = 'life_tools',
}) {
  assert(() {
    developer.log(message, name: name, error: error, stackTrace: stackTrace);
    return true;
  }());
}
