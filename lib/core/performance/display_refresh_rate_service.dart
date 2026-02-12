import 'package:flutter/services.dart';

import '../utils/dev_log.dart';

/// 请求设备使用更高刷新率（例如 90Hz）。
///
/// - 非 Android 或不支持的平台会返回 false
/// - 不抛异常，避免影响启动流程
class DisplayRefreshRateService {
  static const MethodChannel _channel = MethodChannel('life_tools/display');

  Future<bool> tryRequestPreferredHz(double hz) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'requestFrameRate',
        <String, dynamic>{'hz': hz},
      );
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } catch (e, st) {
      devLog('请求刷新率失败: ${e.runtimeType}', error: e, stackTrace: st);
      return false;
    }
  }
}
