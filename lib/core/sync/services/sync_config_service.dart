import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_config.dart';

/// 同步配置服务
class SyncConfigService extends ChangeNotifier {
  static const _storageKey = 'sync_config_v1';

  SharedPreferences? _prefs;
  SyncConfig? _config;

  SyncConfig? get config => _config;
  bool get isConfigured => _config?.isValid ?? false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _config = SyncConfig.tryFromJsonString(_prefs?.getString(_storageKey));
  }

  Future<void> save(SyncConfig config) async {
    _config = config;
    await _prefs?.setString(_storageKey, config.toJsonString());
    notifyListeners();
  }

  Future<void> clear() async {
    _config = null;
    await _prefs?.remove(_storageKey);
    notifyListeners();
  }

  /// 更新上次同步时间
  Future<void> updateLastSyncTime(DateTime time) async {
    if (_config == null) return;
    _config = _config!.copyWith(lastSyncTime: time);
    await _prefs?.setString(_storageKey, _config!.toJsonString());
    notifyListeners();
  }
}
