import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/ios26_theme.dart';
import '../../ui/app_dialogs.dart';
import '../../ui/app_navigator.dart';
import '../../ui/app_scaffold.dart';
import '../../widgets/ios26_settings_row.dart';
import '../models/sync_config.dart';
import '../models/sync_record.dart';
import '../models/sync_response_v2.dart';
import '../services/sync_api_client.dart';
import '../services/sync_config_service.dart';
import '../services/sync_service.dart';
import '../services/sync_network_precheck.dart';
import '../services/wifi_service.dart';
import 'sync_settings_page.dart';

class SyncRecordsPage extends StatefulWidget {
  const SyncRecordsPage({super.key});

  @override
  State<SyncRecordsPage> createState() => _SyncRecordsPageState();
}

class _SyncRecordsPageState extends State<SyncRecordsPage> {
  final SyncApiClient _apiClient = SyncApiClient();
  final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  late final WifiService _wifiService;

  bool _loading = false;
  String? _error;
  List<SyncRecord> _records = const [];
  int? _nextBeforeId;

  @override
  void initState() {
    super.initState();
    try {
      _wifiService = context.read<WifiService>();
    } catch (_) {
      _wifiService = WifiService();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await _load(beforeId: null, append: false);
  }

  Future<void> _load({required int? beforeId, required bool append}) async {
    if (_loading) return;
    final config = context.read<SyncConfigService>().config;
    if (config == null || !config.isValid) {
      setState(() {
        _error = '同步配置未设置或不完整，请先完成配置后再查看同步记录。';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final precheckError = await SyncNetworkPrecheck.check(
        config: config,
        wifiService: _wifiService,
      );
      if (precheckError != null) {
        if (!mounted) return;
        setState(() {
          _error = precheckError;
        });
        return;
      }

      final result = await _apiClient.listSyncRecords(
        config: config,
        limit: 50,
        beforeId: beforeId,
      );
      if (!mounted) return;
      setState(() {
        _records = append ? [..._records, ...result.records] : result.records;
        _nextBeforeId = result.nextBeforeId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _stringifyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SyncConfigService>().config;
    final serverText = config == null ? '未配置' : config.fullServerUrl;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(
            title: '同步记录',
            showBackButton: true,
            actions: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onPressed: _loading ? null : _refresh,
                child: Text('刷新', style: IOS26Theme.labelLarge),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _buildConfigCard(serverText: serverText, config: config),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  _buildErrorCard(_error!),
                  const SizedBox(height: 16),
                ],
                if (_records.isEmpty && !_loading)
                  _buildEmptyCard()
                else ...[
                  ..._records.map(_buildRecordCard),
                  if (_nextBeforeId != null) ...[
                    const SizedBox(height: 12),
                    _buildLoadMoreCard(),
                  ],
                ],
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CupertinoActivityIndicator()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard({
    required String serverText,
    required SyncConfig? config,
  }) {
    final configured = config != null && config.isValid;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('服务端', style: IOS26Theme.titleMedium),
          const SizedBox(height: 8),
          Text(serverText, style: IOS26Theme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            '用户：${config?.userId.trim().isEmpty ?? true ? "未配置" : config!.userId}',
            style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              AppNavigator.push(context, const SyncSettingsPage());
            },
            child: Text(
              configured ? '同步设置' : '去配置数据同步',
              style: IOS26Theme.labelLarge.copyWith(color: IOS26Theme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String text) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Text(
        '暂无同步记录（仅记录发生“客户端更新/服务端更新/回退”的同步行为）',
        style: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
      ),
    );
  }

  Widget _buildLoadMoreCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(6),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _loading
            ? null
            : () => _load(beforeId: _nextBeforeId, append: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text('加载更多', style: IOS26Theme.labelLarge),
        ),
      ),
    );
  }

  Widget _buildRecordCard(SyncRecord record) {
    final summary = record.diffSummary;
    final changedTools = summary['changed_tools'];
    final diffItems = summary['diff_items'];
    final truncated = summary['truncated'] == true;

    final directionText = switch (record.decision) {
      SyncDecision.useClient => '客户端 → 服务端',
      SyncDecision.useServer => '服务端 → 客户端',
      SyncDecision.rollback => '回退（服务端）',
      _ => '未知',
    };

    final valueText = [
      _timeFormat.format(record.serverTime),
      if (changedTools != null) '变更工具 $changedTools',
      if (diffItems != null) '差异 $diffItems${truncated ? "+" : ""}',
    ].join(' · ');

    final icon = switch (record.decision) {
      SyncDecision.useClient => CupertinoIcons.arrow_up_circle,
      SyncDecision.useServer => CupertinoIcons.arrow_down_circle,
      SyncDecision.rollback => CupertinoIcons.arrow_counterclockwise_circle,
      _ => CupertinoIcons.info_circle,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: IOS26SettingsRow(
          icon: icon,
          title: directionText,
          value: valueText,
          onTap: () {
            AppNavigator.push(
              context,
              SyncRecordDetailPage(recordId: record.id),
            );
          },
        ),
      ),
    );
  }
}

class SyncRecordDetailPage extends StatefulWidget {
  final int recordId;

  const SyncRecordDetailPage({super.key, required this.recordId});

  @override
  State<SyncRecordDetailPage> createState() => _SyncRecordDetailPageState();
}

class _SyncRecordDetailPageState extends State<SyncRecordDetailPage> {
  final SyncApiClient _apiClient = SyncApiClient();
  final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  late final WifiService _wifiService;

  bool _loading = false;
  bool _rollbackBusy = false;
  String? _error;
  SyncRecord? _record;

  @override
  void initState() {
    super.initState();
    try {
      _wifiService = context.read<WifiService>();
    } catch (_) {
      _wifiService = WifiService();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final config = context.read<SyncConfigService>().config;
    if (config == null || !config.isValid) {
      setState(() {
        _error = '同步配置未设置或不完整，请先完成配置后再查看同步详情。';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final precheckError = await SyncNetworkPrecheck.check(
        config: config,
        wifiService: _wifiService,
      );
      if (precheckError != null) {
        if (!mounted) return;
        setState(() {
          _error = precheckError;
        });
        return;
      }

      final record = await _apiClient.getSyncRecord(
        config: config,
        id: widget.recordId,
      );
      if (!mounted) return;
      setState(() {
        _record = record;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _stringifyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(title: '同步详情', showBackButton: true),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (_loading) ...[
                  const SizedBox(height: 40),
                  const Center(child: CupertinoActivityIndicator()),
                ] else if (_error != null) ...[
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: IOS26Theme.bodyMedium.copyWith(
                        color: IOS26Theme.textSecondary,
                      ),
                    ),
                  ),
                ] else if (record == null) ...[
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '记录不存在或尚未加载',
                      style: IOS26Theme.bodyMedium.copyWith(
                        color: IOS26Theme.textSecondary,
                      ),
                    ),
                  ),
                ] else ...[
                  _buildSummaryCard(record),
                  const SizedBox(height: 16),
                  _buildRollbackCard(record),
                  const SizedBox(height: 16),
                  ..._buildDiffCards(record),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(SyncRecord record) {
    final directionText = switch (record.decision) {
      SyncDecision.useClient => '客户端更新服务端',
      SyncDecision.useServer => '服务端更新客户端',
      SyncDecision.rollback => '回退（服务端）',
      _ => '未知',
    };

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(directionText, style: IOS26Theme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '时间：${_timeFormat.format(record.serverTime)}',
            style: IOS26Theme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '客户端更新时间：${record.clientUpdatedAtMs}',
            style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '服务端更新时间：${record.serverUpdatedAtMsBefore} → ${record.serverUpdatedAtMsAfter}',
            style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '服务端游标：${record.serverRevisionBefore} → ${record.serverRevisionAfter}',
            style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRollbackCard(SyncRecord record) {
    final canRollback = record.serverRevisionBefore > 0;
    final targetRevision = record.serverRevisionBefore;
    final targetText = canRollback ? 'rev $targetRevision' : '无可回退版本';

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('回退', style: IOS26Theme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '仅在你明确知道要恢复到哪个历史版本时使用。回退会产生新的服务端版本，并记录到同步记录。',
              style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
            ),
          ),
          IOS26SettingsRow(
            icon: CupertinoIcons.arrow_counterclockwise_circle,
            title: '回退服务端并覆盖本地（推荐）',
            value: targetText,
            onTap: (!_rollbackBusy && canRollback)
                ? () => _confirmAndRollbackServer(targetRevision)
                : null,
          ),
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: IOS26Theme.textTertiary.withValues(alpha: 0.15),
          ),
          IOS26SettingsRow(
            icon: CupertinoIcons.device_phone_portrait,
            title: '仅覆盖本地（不修改服务端）',
            value: targetText,
            onTap: (!_rollbackBusy && canRollback)
                ? () => _confirmAndRollbackLocal(targetRevision)
                : null,
          ),
          if (_rollbackBusy) ...[
            const SizedBox(height: 10),
            const Center(child: CupertinoActivityIndicator()),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<SyncConfig?> _ensureReadyConfig() async {
    final config = context.read<SyncConfigService>().config;
    if (config == null || !config.isValid) {
      final go = await AppDialogs.showConfirm(
        context,
        title: '同步未配置',
        content: '请先完成服务器地址/端口与用户标识配置，然后再进行回退操作。',
        cancelText: '取消',
        confirmText: '去配置',
      );
      if (!mounted) return null;
      if (go) {
        AppNavigator.push(context, const SyncSettingsPage());
      }
      return null;
    }

    final precheckError = await SyncNetworkPrecheck.check(
      config: config,
      wifiService: _wifiService,
    );
    if (precheckError != null) {
      if (!mounted) return null;
      await AppDialogs.showInfo(
        context,
        title: '网络预检失败',
        content: precheckError,
      );
      return null;
    }

    return config;
  }

  Future<void> _confirmAndRollbackServer(int targetRevision) async {
    final ok = await AppDialogs.showConfirm(
      context,
      title: '确认回退服务端？',
      content: '将服务端回退到 $targetRevision，并覆盖本地数据。该操作会产生新的服务端版本。',
      cancelText: '取消',
      confirmText: '回退',
      isDestructive: true,
    );
    if (!mounted || !ok) return;

    final config = await _ensureReadyConfig();
    if (!mounted || config == null) return;

    final syncService = context.read<SyncService>();
    final configService = context.read<SyncConfigService>();

    setState(() => _rollbackBusy = true);
    try {
      final result = await _apiClient.rollbackToRevision(
        config: config,
        targetRevision: targetRevision,
      );
      if (!mounted) return;

      final applyError = await syncService.applyServerSnapshot(
        result.toolsData,
      );
      await configService.updateLastSyncState(
        time: result.serverTime,
        serverRevision: result.serverRevision,
      );

      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: '回退完成',
        content: applyError == null
            ? '已回退到 $targetRevision，并覆盖本地。新的服务端版本：${result.serverRevision}'
            : '服务端已回退，但部分工具导入失败：\n$applyError',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: '回退失败',
        content: _stringifyError(e),
      );
    } finally {
      if (mounted) {
        setState(() => _rollbackBusy = false);
      }
    }
  }

  Future<void> _confirmAndRollbackLocal(int targetRevision) async {
    final ok = await AppDialogs.showConfirm(
      context,
      title: '确认仅回退本地？',
      content: [
        '将本地数据覆盖为服务端历史版本 $targetRevision，但不会修改服务端当前版本。',
        '注意：下次同步时本地可能被服务端覆盖（建议改用“回退服务端并覆盖本地”）。',
      ].join('\n'),
      cancelText: '取消',
      confirmText: '覆盖本地',
      isDestructive: true,
    );
    if (!mounted || !ok) return;

    final config = await _ensureReadyConfig();
    if (!mounted || config == null) return;

    final syncService = context.read<SyncService>();

    setState(() => _rollbackBusy = true);
    try {
      final snapshot = await _apiClient.getSnapshotByRevision(
        config: config,
        revision: targetRevision,
      );
      if (!mounted) return;

      final applyError = await syncService.applyServerSnapshot(
        snapshot.toolsData,
      );

      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: '已覆盖本地',
        content: applyError == null ? '本地已覆盖为 $targetRevision' : '部分工具导入失败：\n$applyError',
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: '覆盖失败',
        content: _stringifyError(e),
      );
    } finally {
      if (mounted) {
        setState(() => _rollbackBusy = false);
      }
    }
  }

  List<Widget> _buildDiffCards(SyncRecord record) {
    final diff = record.diff;
    if (diff == null) {
      return [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Text(
            '无差异详情',
            style: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
          ),
        ),
      ];
    }

    final tools = diff['tools'];
    if (tools is! Map) {
      return [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Text(
            '差异数据格式错误',
            style: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
          ),
        ),
      ];
    }

    final cards = <Widget>[];
    for (final entry in tools.entries) {
      final toolId = entry.key;
      final toolData = entry.value;
      if (toolId is! String || toolData is! Map) continue;

      final same = toolData['same'] == true;
      if (same) continue;

      final diffItems = (toolData['diff_items'] as List?) ?? const [];
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toolId, style: IOS26Theme.titleMedium),
                const SizedBox(height: 8),
                if (diffItems.isEmpty)
                  Text(
                    '无可展示的差异条目（可能已截断）',
                    style: IOS26Theme.bodySmall.copyWith(
                      color: IOS26Theme.textSecondary,
                    ),
                  )
                else
                  ...diffItems.take(80).map((e) => _buildDiffLine(e)),
              ],
            ),
          ),
        ),
      );
    }

    if (cards.isEmpty) {
      return [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Text(
            '无差异（或差异已被截断）',
            style: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
          ),
        ),
      ];
    }

    return cards;
  }

  Widget _buildDiffLine(dynamic raw) {
    if (raw is! Map) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '• 未知差异项',
          style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
        ),
      );
    }

    final path = (raw['path'] as String?) ?? '';
    final change = (raw['change'] as String?) ?? '';

    final label = switch (change) {
      'added' => '新增',
      'removed' => '删除',
      'type_changed' => '类型变化',
      'length_changed' => '长度变化',
      'value_changed' => '值变化',
      'list_truncated' => '列表截断',
      'depth_truncated' => '深度截断',
      _ => change.isEmpty ? '变化' : change,
    };

    final extra = <String>[];
    if (change == 'length_changed') {
      extra.add('${raw['server']} → ${raw['client']}');
    }
    if (change == 'type_changed') {
      final st = raw['server_type'];
      final ct = raw['client_type'];
      if (st != null && ct != null) {
        extra.add('$st → $ct');
      }
    }

    final text = extra.isEmpty
        ? '• [$label] $path'
        : '• [$label] $path（${extra.join("，")}）';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
      ),
    );
  }
}

String _stringifyError(Object e) {
  final text = e.toString();
  if (text.startsWith('SyncApiException: ')) {
    return text.substring('SyncApiException: '.length);
  }
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text;
}
