import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 同步本地状态服务：用于记录“当前本地数据属于哪个同步用户”。
///
/// 设计目的：
/// - 防止用户切换 userId 后，本地旧用户数据覆盖服务端新用户数据。
/// - 自动同步遇到不匹配时可直接阻止并提示用户手动处理。
class SyncLocalStateService extends ChangeNotifier {
  static const _localUserIdKey = 'sync_local_user_id_v1';

  SharedPreferences? _prefs;
  String? _localUserId;

  String? get localUserId => _localUserId;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _localUserId = _prefs?.getString(_localUserIdKey);
  }

  Future<void> setLocalUserId(String? userId) async {
    final normalized = userId?.trim();
    final next = (normalized == null || normalized.isEmpty) ? null : normalized;
    _localUserId = next;

    if (next == null) {
      await _prefs?.remove(_localUserIdKey);
    } else {
      await _prefs?.setString(_localUserIdKey, next);
    }
    notifyListeners();
  }

  Future<void> clear() => setLocalUserId(null);
}
