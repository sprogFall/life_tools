import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/obj_store/obj_store_config.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_secrets.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/sync/interfaces/tool_sync_provider.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/services/backup_restore_service.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeToolSyncProvider implements ToolSyncProvider {
  @override
  final String toolId;

  final Map<String, dynamic> exportPayload;
  final void Function(Map<String, dynamic> data)? onImport;
  Map<String, dynamic>? lastImported;

  _FakeToolSyncProvider({
    required this.toolId,
    required this.exportPayload,
    this.onImport,
  });

  @override
  Future<Map<String, dynamic>> exportData() async => exportPayload;

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    lastImported = data;
    onImport?.call(data);
  }
}

class _ThrowingToolSyncProvider implements ToolSyncProvider {
  @override
  final String toolId;

  _ThrowingToolSyncProvider({required this.toolId});

  @override
  Future<Map<String, dynamic>> exportData() async {
    throw StateError('export failed');
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {}
}

void main() {
  group('BackupRestoreService', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      ToolRegistry.instance.registerAll();
    });

    test('exportAsJson 默认应避免导出敏感信息（AI Key/同步 Headers/七牛 AKSK）', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();
      await aiConfigService.save(
        const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'k1',
          model: 'm1',
          temperature: 0.7,
          maxOutputTokens: 256,
        ),
      );

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();
      await syncConfigService.save(
        const SyncConfig(
          userId: 'u1',
          networkType: SyncNetworkType.public,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {'X-Test': '1'},
          allowedWifiNames: [],
          autoSyncOnStartup: false,
        ),
      );

      final settingsService = SettingsService();
      await settingsService.init();
      await settingsService.setDefaultTool('work_log');

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();
      await objStoreConfigService.save(
        const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'https://cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
          isPrivate: true,
        ),
        secrets: const ObjStoreQiniuSecrets(accessKey: 'ak', secretKey: 'sk'),
      );

      final tool = _FakeToolSyncProvider(
        toolId: 'work_log',
        exportPayload: const {
          'version': 1,
          'data': {'tasks': []},
        },
      );

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: [tool],
      );

      final jsonText = await service.exportAsJson();
      final map = jsonDecode(jsonText) as Map<String, dynamic>;

      expect(map['version'], isA<int>());
      expect(map['ai_config'], isA<Map>());
      final ai = Map<String, dynamic>.from(map['ai_config'] as Map);
      expect(ai.containsKey('apiKey'), isFalse);

      expect(map['sync_config'], isA<Map>());
      final sync = Map<String, dynamic>.from(map['sync_config'] as Map);
      expect(sync.containsKey('customHeaders'), isFalse);

      expect(map['obj_store_config'], isA<Map>());
      expect(map['obj_store_secrets'], isNull);
      expect(map['settings'], isA<Map>());
      expect(map['tools'], isA<Map>());
      expect((map['tools'] as Map).containsKey('work_log'), isTrue);
    });

    test('exportAsJson includeSensitive=true 时应包含敏感信息', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();
      await aiConfigService.save(
        const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'k1',
          model: 'm1',
          temperature: 0.7,
          maxOutputTokens: 256,
        ),
      );

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();
      await syncConfigService.save(
        const SyncConfig(
          userId: 'u1',
          networkType: SyncNetworkType.public,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {'X-Test': '1'},
          allowedWifiNames: [],
          autoSyncOnStartup: false,
        ),
      );

      final settingsService = SettingsService();
      await settingsService.init();

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();
      await objStoreConfigService.save(
        const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'https://cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
          isPrivate: true,
        ),
        secrets: const ObjStoreQiniuSecrets(accessKey: 'ak', secretKey: 'sk'),
      );

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: const [],
      );

      final jsonText = await service.exportAsJson(includeSensitive: true);
      final map = jsonDecode(jsonText) as Map<String, dynamic>;

      final ai = Map<String, dynamic>.from(map['ai_config'] as Map);
      expect(ai['apiKey'], 'k1');

      final sync = Map<String, dynamic>.from(map['sync_config'] as Map);
      expect(sync['customHeaders'], isA<Map>());

      expect(map['obj_store_secrets'], isA<Map>());
    });

    test('exportAsJson 遇到任一工具导出失败时应直接报错，避免生成不完整备份', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      final tool = _ThrowingToolSyncProvider(toolId: 'work_log');

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: [tool],
      );

      await expectLater(
        service.exportAsJson(),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('work_log') &&
                e.toString().contains('导出'),
          ),
        ),
      );
    });

    test('导出/还原应包含工具管理信息（首页隐藏工具）', () async {
      final db1 = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(() async => db1.close());

      final aiConfigService = AiConfigService();
      await aiConfigService.init();
      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService(
        databaseProvider: () async => db1,
      );
      await settingsService.init();
      await settingsService.setToolHidden('overcooked_kitchen', true);

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: const [],
      );

      final jsonText = await service.exportAsJson();
      final map = jsonDecode(jsonText) as Map<String, dynamic>;
      final settings = Map<String, dynamic>.from(map['settings'] as Map);
      final hidden =
          (settings['hidden_tool_ids'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      expect(hidden, contains('overcooked_kitchen'));

      SharedPreferences.setMockInitialValues({});

      final db2 = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(() async => db2.close());

      final aiConfigService2 = AiConfigService();
      await aiConfigService2.init();
      final syncConfigService2 = SyncConfigService();
      await syncConfigService2.init();
      final objStoreConfigService2 = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService2.init();

      final settingsService2 = SettingsService(
        databaseProvider: () async => db2,
      );
      await settingsService2.init();

      final service2 = BackupRestoreService(
        aiConfigService: aiConfigService2,
        syncConfigService: syncConfigService2,
        settingsService: settingsService2,
        objStoreConfigService: objStoreConfigService2,
        toolProviders: const [],
      );

      await service2.restoreFromJson(jsonText);

      expect(settingsService2.hiddenToolIds, contains('overcooked_kitchen'));
      expect(
        settingsService2.getHomeTools().any(
          (t) => t.id == 'overcooked_kitchen',
        ),
        isFalse,
      );
    });

    test('导出为 TXT 文件时应使用紧凑 JSON（不换行）', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: const [],
      );

      final compact = await service.exportAsJson(pretty: false);
      expect(compact, isNot(contains('\n')));
      expect(compact, isNot(contains('\r')));

      final pretty = await service.exportAsJson(pretty: true);
      expect(pretty, contains('\n'));
    });

    test('restoreFromJson 应还原 AI 配置/同步配置/默认工具配置，并调用工具导入', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      final tool = _FakeToolSyncProvider(
        toolId: 'work_log',
        exportPayload: const {
          'version': 1,
          'data': {'tasks': []},
        },
      );

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: [tool],
      );

      final payload = {
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'k2',
          model: 'm2',
          temperature: 0.2,
          maxOutputTokens: 512,
        ).toMap(),
        'sync_config': const SyncConfig(
          userId: 'u2',
          networkType: SyncNetworkType.privateWifi,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: ['MyWifi'],
        ).toMap(),
        'obj_store_config': const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'https://cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
          isPrivate: true,
        ).toJson(),
        'obj_store_secrets': const {'accessKey': 'ak2', 'secretKey': 'sk2'},
        'settings': {
          'default_tool_id': 'work_log',
          'tool_order': ['work_log', 'review', 'expense', 'income'],
        },
        'tools': {
          'work_log': {
            'version': 1,
            'data': {'tasks': []},
          },
        },
      };

      await service.restoreFromJson(jsonEncode(payload));

      expect(aiConfigService.config, isNotNull);
      expect(aiConfigService.config!.model, 'm2');
      expect(syncConfigService.config, isNotNull);
      expect(syncConfigService.config!.userId, 'u2');
      expect(objStoreConfigService.config, isNotNull);
      expect(objStoreConfigService.config!.type, ObjStoreType.qiniu);
      expect(objStoreConfigService.config!.qiniuIsPrivate, isTrue);
      expect(objStoreConfigService.qiniuSecrets, isNotNull);
      expect(objStoreConfigService.qiniuSecrets!.accessKey, 'ak2');
      expect(settingsService.defaultToolId, 'work_log');
      expect(tool.lastImported, isNotNull);
      expect(tool.lastImported!['version'], 1);
    });

    test('restoreFromJson 缺失敏感字段时不应覆盖本地敏感信息', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();
      await aiConfigService.save(
        const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'keep_ai_key',
          model: 'm_old',
          temperature: 0.7,
          maxOutputTokens: 256,
        ),
      );

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();
      await syncConfigService.save(
        const SyncConfig(
          userId: 'u_old',
          networkType: SyncNetworkType.public,
          serverUrl: 'old.example.com',
          serverPort: 443,
          customHeaders: {'Authorization': 'Bearer keep'},
          allowedWifiNames: [],
          autoSyncOnStartup: false,
        ),
      );

      final settingsService = SettingsService();
      await settingsService.init();

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();
      await objStoreConfigService.save(
        const ObjStoreConfig.qiniu(
          bucket: 'bkt_old',
          domain: 'https://cdn.old.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
          isPrivate: true,
        ),
        secrets: const ObjStoreQiniuSecrets(
          accessKey: 'keep_ak',
          secretKey: 'keep_sk',
        ),
      );

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: const [],
      );

      final payload = {
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': const {
          'baseUrl': 'https://example.com/v1',
          // 故意不包含 apiKey
          'model': 'm_new',
          'temperature': 0.2,
          'maxOutputTokens': 512,
        },
        'sync_config': const {
          'userId': 'u_new',
          'networkType': 0,
          'serverUrl': 'new.example.com',
          'serverPort': 443,
          // 故意不包含 customHeaders
          'allowedWifiNames': <String>[],
          'autoSyncOnStartup': true,
        },
        'obj_store_config': const ObjStoreConfig.qiniu(
          bucket: 'bkt_new',
          domain: 'https://cdn.new.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
          isPrivate: true,
        ).toJson(),
        // 故意不包含 obj_store_secrets
        'settings': {'default_tool_id': null, 'tool_order': const <String>[]},
        'tools': const <String, dynamic>{},
      };

      await service.restoreFromJson(jsonEncode(payload));

      expect(aiConfigService.config, isNotNull);
      expect(aiConfigService.config!.model, 'm_new');
      expect(aiConfigService.config!.apiKey, 'keep_ai_key');

      expect(syncConfigService.config, isNotNull);
      expect(syncConfigService.config!.userId, 'u_new');
      expect(
        syncConfigService.config!.customHeaders['Authorization'],
        'Bearer keep',
      );

      expect(objStoreConfigService.config, isNotNull);
      expect(objStoreConfigService.config!.bucket, 'bkt_new');
      expect(objStoreConfigService.qiniuSecrets, isNotNull);
      expect(objStoreConfigService.qiniuSecrets!.accessKey, 'keep_ak');
    });

    test('restoreFromJson：七牛配置缺失 AKSK 时应仍保留配置（secrets 为空）', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: const [],
      );

      final payload = {
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': null,
        'sync_config': null,
        'obj_store_config': const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'https://cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
          isPrivate: true,
        ).toJson(),
        // 不提供 obj_store_secrets
        'settings': {'default_tool_id': null, 'tool_order': const <String>[]},
        'tools': const <String, dynamic>{},
      };

      await service.restoreFromJson(jsonEncode(payload));

      expect(objStoreConfigService.config, isNotNull);
      expect(objStoreConfigService.config!.type, ObjStoreType.qiniu);
      expect(objStoreConfigService.qiniuSecrets, isNull);
    });

    test('restoreFromJson 应优先导入 tag_manager，避免其它工具的标签关联丢失', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      var tagsImported = false;
      final tagProvider = _FakeToolSyncProvider(
        toolId: 'tag_manager',
        exportPayload: const {
          'version': 1,
          'data': {'tags': [], 'tool_tags': []},
        },
        onImport: (_) => tagsImported = true,
      );

      final dependentProvider = _FakeToolSyncProvider(
        toolId: 'work_log',
        exportPayload: const {'version': 1, 'data': {}},
        onImport: (_) {
          if (!tagsImported) {
            throw Exception('tags 未先导入');
          }
        },
      );

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: [tagProvider, dependentProvider],
      );

      // tools 节点的插入顺序是 work_log -> tag_manager（模拟历史导出顺序）
      final payload = {
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': null,
        'sync_config': null,
        'settings': {
          'default_tool_id': null,
          'tool_order': ['work_log', 'tag_manager'],
        },
        'tools': {
          'work_log': {'version': 1, 'data': {}},
          'tag_manager': {
            'version': 1,
            'data': {'tags': [], 'tool_tags': []},
          },
        },
      };

      await service.restoreFromJson(jsonEncode(payload));

      expect(tagsImported, isTrue);
      expect(tagProvider.lastImported, isNotNull);
      expect(dependentProvider.lastImported, isNotNull);
    });

    test(
      'restoreFromJson 应支持 ai_config/sync_config 为 JSON 字符串（避免偶现跳过导入）',
      () async {
        final aiConfigService = AiConfigService();
        await aiConfigService.init();

        final syncConfigService = SyncConfigService();
        await syncConfigService.init();

        final settingsService = SettingsService();
        await settingsService.init();

        final objStoreConfigService = ObjStoreConfigService(
          secretStore: InMemorySecretStore(),
        );
        await objStoreConfigService.init();

        final service = BackupRestoreService(
          aiConfigService: aiConfigService,
          syncConfigService: syncConfigService,
          settingsService: settingsService,
          objStoreConfigService: objStoreConfigService,
          toolProviders: const [],
        );

        final aiConfigJson = jsonEncode(
          const AiConfig(
            baseUrl: 'https://api.openai.com/v1',
            apiKey: 'k_json_string',
            model: 'm_json_string',
            temperature: 0.7,
            maxOutputTokens: 256,
          ).toMap(),
        );

        final syncConfigJson = jsonEncode(
          const SyncConfig(
            userId: 'u_json_string',
            networkType: SyncNetworkType.privateWifi,
            serverUrl: 'sync.example.com',
            serverPort: 443,
            customHeaders: {'X-Test': '1'},
            allowedWifiNames: ['MyWifi'],
            autoSyncOnStartup: true,
          ).toMap(),
        );

        final payload = {
          'version': 1,
          'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          'ai_config': aiConfigJson,
          'sync_config': syncConfigJson,
          'settings': {'default_tool_id': null, 'tool_order': const <String>[]},
          'tools': const <String, dynamic>{},
        };

        await service.restoreFromJson(jsonEncode(payload));

        expect(aiConfigService.config, isNotNull);
        expect(aiConfigService.config!.apiKey, 'k_json_string');
        expect(syncConfigService.config, isNotNull);
        expect(syncConfigService.config!.userId, 'u_json_string');
        expect(
          syncConfigService.config!.networkType,
          SyncNetworkType.privateWifi,
        );
      },
    );

    test('restoreFromJson 应容错 sync_config 数字字段为小数/字符串', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      final objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        toolProviders: const [],
      );

      final jsonText = jsonEncode({
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': null,
        'sync_config': {
          'userId': 'u_num_loose',
          'networkType': 1.0,
          'serverUrl': 'sync.example.com',
          'serverPort': '443',
          'customHeaders': {'X-Test': '1'},
          'allowedWifiNames': ['MyWifi'],
          'autoSyncOnStartup': true,
          'lastSyncTime': 1700000000000.0,
        },
        'settings': {'default_tool_id': null, 'tool_order': const <String>[]},
        'tools': const <String, dynamic>{},
      });

      await service.restoreFromJson(jsonText);

      expect(syncConfigService.config, isNotNull);
      expect(syncConfigService.config!.userId, 'u_num_loose');
      expect(
        syncConfigService.config!.networkType,
        SyncNetworkType.privateWifi,
      );
      expect(syncConfigService.config!.serverPort, 443);
      expect(
        syncConfigService.config!.lastSyncTime,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });
  });
}
