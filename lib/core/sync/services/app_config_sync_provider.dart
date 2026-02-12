import 'package:shared_preferences/shared_preferences.dart';

import '../interfaces/tool_sync_provider.dart';
import 'app_config_updated_at.dart';
import 'backup_restore_service.dart';

class AppConfigSyncProvider implements ToolSyncProvider {
  static const int snapshotVersion = 1;

  final BackupRestoreService _backupRestoreService;

  AppConfigSyncProvider({required BackupRestoreService backupRestoreService})
    : _backupRestoreService = backupRestoreService;

  @override
  String get toolId => 'app_config';

  @override
  Future<Map<String, dynamic>> exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final updatedAtMs = AppConfigUpdatedAt.readFrom(prefs);
    final data = await _backupRestoreService.exportConfigAsMap(
      includeSensitive: true,
    );

    return <String, dynamic>{
      'version': snapshotVersion,
      'updated_at_ms': updatedAtMs,
      'data': data,
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> snapshot) async {
    final version = (snapshot['version'] as num?)?.toInt();
    if (version != snapshotVersion) return;

    final dataRaw = snapshot['data'];
    if (dataRaw is! Map) return;

    final data = Map<String, dynamic>.from(dataRaw);
    await _backupRestoreService.restoreConfigFromMap(data);

    final incomingUpdatedAtMs =
        (snapshot['updated_at_ms'] as num?)?.toInt() ?? 0;
    if (incomingUpdatedAtMs <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    await AppConfigUpdatedAt.setTo(prefs, incomingUpdatedAtMs);
  }
}
