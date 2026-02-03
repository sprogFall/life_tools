import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/services/app_config_updated_at.dart';
import 'ai_config.dart';

class AiConfigService extends ChangeNotifier {
  static const _storageKey = 'ai_config_v1';

  SharedPreferences? _prefs;
  AiConfig? _config;

  AiConfig? get config => _config;
  bool get isConfigured => _config?.isValid ?? false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _config = AiConfig.tryFromJsonString(_prefs?.getString(_storageKey));
  }

  Future<void> save(AiConfig config) async {
    _config = config;
    await _prefs?.setString(_storageKey, config.toJsonString());
    final prefs = _prefs;
    if (prefs != null) {
      await AppConfigUpdatedAt.touch(prefs);
    }
    notifyListeners();
  }

  Future<void> clear() async {
    _config = null;
    await _prefs?.remove(_storageKey);
    final prefs = _prefs;
    if (prefs != null) {
      await AppConfigUpdatedAt.touch(prefs);
    }
    notifyListeners();
  }
}
