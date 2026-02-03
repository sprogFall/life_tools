import 'package:shared_preferences/shared_preferences.dart';

class AppConfigUpdatedAt {
  static const String storageKey = 'app_config_updated_at_ms_v1';

  static int readFrom(SharedPreferences prefs) {
    return prefs.getInt(storageKey) ?? 0;
  }

  static Future<int> touch(SharedPreferences prefs, {int? nowMs}) async {
    final value = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(storageKey, value);
    return value;
  }

  static Future<void> setTo(SharedPreferences prefs, int value) async {
    await prefs.setInt(storageKey, value);
  }
}

