import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:life_tools/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../theme/ios26_theme.dart';
import '../../ui/app_dialogs.dart';
import '../../ui/app_navigator.dart';
import '../../ui/app_scaffold.dart';
import '../logic/sync_diff_presenter.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final config = context.read<SyncConfigService>().config;
    if (config == null || !config.isValid) {
      setState(() {
        _error = l10n.sync_records_config_missing_error;
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
    final l10n = AppLocalizations.of(context)!;
    final config = context.watch<SyncConfigService>().config;
    final serverText = config == null
        ? l10n.common_not_configured
        : config.fullServerUrl;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(
            title: l10n.sync_records_title,
            showBackButton: true,
            actions: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onPressed: _loading ? null : _refresh,
                child: Text(l10n.common_refresh, style: IOS26Theme.labelLarge),
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
    final l10n = AppLocalizations.of(context)!;
    final configured = config != null && config.isValid;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sync_server_label, style: IOS26Theme.titleMedium),
          const SizedBox(height: 8),
          Text(serverText, style: IOS26Theme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            l10n.sync_user_label(
              (config?.userId.trim().isEmpty ?? true)
                  ? l10n.common_not_configured
                  : config!.userId,
            ),
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              AppNavigator.push(context, const SyncSettingsPage());
            },
            child: Text(
              configured
                  ? l10n.sync_open_settings_button
                  : l10n.sync_go_config_button,
              style: IOS26Theme.labelLarge.copyWith(
                color: IOS26Theme.primaryColor,
              ),
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
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Text(
        l10n.sync_records_empty_hint,
        style: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
      ),
    );
  }

  Widget _buildLoadMoreCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(6),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _loading
            ? null
            : () => _load(beforeId: _nextBeforeId, append: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(l10n.common_load_more, style: IOS26Theme.labelLarge),
        ),
      ),
    );
  }

  Widget _buildRecordCard(SyncRecord record) {
    final l10n = AppLocalizations.of(context)!;
    final summary = record.diffSummary;
    final changedTools = summary['changed_tools'];
    final diffItems = summary['diff_items'];
    final truncated = summary['truncated'] == true;

    final directionText = switch (record.decision) {
      SyncDecision.useClient => l10n.sync_direction_client_to_server,
      SyncDecision.useServer => l10n.sync_direction_server_to_client,
      SyncDecision.rollback => l10n.sync_direction_rollback,
      _ => l10n.sync_direction_unknown,
    };

    final summaryParts = <String>[];
    if (changedTools != null) {
      summaryParts.add(
        l10n.sync_summary_changed_tools(changedTools.toString()),
      );
    }
    if (diffItems != null) {
      summaryParts.add(
        l10n.sync_summary_changed_items(
          diffItems.toString(),
          truncated ? '+' : '',
        ),
      );
    }
    final summaryText = summaryParts.isEmpty
        ? l10n.sync_summary_no_major_changes
        : summaryParts.join(' · ');

    final iconData = switch (record.decision) {
      SyncDecision.useClient => CupertinoIcons.arrow_up_circle_fill,
      SyncDecision.useServer => CupertinoIcons.arrow_down_circle_fill,
      SyncDecision.rollback =>
        CupertinoIcons.arrow_counterclockwise_circle_fill,
      _ => CupertinoIcons.info_circle_fill,
    };

    final iconTone = switch (record.decision) {
      SyncDecision.useClient => IOS26IconTone.success,
      SyncDecision.useServer => IOS26IconTone.accent,
      SyncDecision.rollback => IOS26IconTone.warning,
      _ => IOS26IconTone.secondary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          AppNavigator.push(context, SyncRecordDetailPage(recordId: record.id));
        },
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IOS26Icon(iconData, tone: iconTone, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(directionText, style: IOS26Theme.titleMedium),
                  ),
                  Text(
                    _timeFormat.format(record.serverTime),
                    style: IOS26Theme.bodySmall.copyWith(
                      color: IOS26Theme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  summaryText,
                  style: IOS26Theme.bodySmall.copyWith(
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
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
    final l10n = AppLocalizations.of(context)!;
    final config = context.read<SyncConfigService>().config;
    if (config == null || !config.isValid) {
      setState(() {
        _error = l10n.sync_details_config_missing_error;
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
    final l10n = AppLocalizations.of(context)!;
    final record = _record;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(title: l10n.sync_details_title, showBackButton: true),
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
                      l10n.common_loading,
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
    final l10n = AppLocalizations.of(context)!;
    final directionText = switch (record.decision) {
      SyncDecision.useClient => l10n.sync_action_client_updates_server,
      SyncDecision.useServer => l10n.sync_action_server_updates_client,
      SyncDecision.rollback => l10n.sync_action_rollback_server,
      _ => l10n.sync_action_unknown,
    };

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(directionText, style: IOS26Theme.titleMedium),
          const SizedBox(height: 8),
          Text(
            l10n.sync_details_time_label(_timeFormat.format(record.serverTime)),
            style: IOS26Theme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.sync_details_client_updated_at_label(record.clientUpdatedAtMs),
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.sync_details_server_updated_at_label(
              record.serverUpdatedAtMsBefore,
              record.serverUpdatedAtMsAfter,
            ),
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.sync_details_server_revision_label(
              record.serverRevisionBefore,
              record.serverRevisionAfter,
            ),
            style: IOS26Theme.bodySmall.copyWith(
              color: IOS26Theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRollbackCard(SyncRecord record) {
    final l10n = AppLocalizations.of(context)!;
    final canRollback = record.serverRevisionBefore > 0;
    final targetRevision = record.serverRevisionBefore;
    final targetText = canRollback
        ? l10n.sync_rollback_target_revision(targetRevision)
        : l10n.sync_rollback_no_target;

    Widget buildOption({
      required IconData icon,
      required String title,
      required String subtitle,
      required String value,
      required VoidCallback? onTap,
    }) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                decoration: BoxDecoration(
                  color: IOS26Theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IOS26Icon(icon, tone: IOS26IconTone.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: IOS26Theme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: IOS26Theme.bodySmall.copyWith(
                        color: IOS26Theme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(value, style: IOS26Theme.bodyMedium),
              const SizedBox(width: 8),
              IOS26Icon(
                CupertinoIcons.chevron_right,
                color: IOS26Theme.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      );
    }

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              l10n.sync_rollback_section_title,
              style: IOS26Theme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              l10n.sync_rollback_section_hint,
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textSecondary,
              ),
            ),
          ),
          buildOption(
            icon: CupertinoIcons.arrow_counterclockwise_circle,
            title: l10n.sync_rollback_to_version_title,
            subtitle: l10n.sync_rollback_to_version_subtitle,
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
          buildOption(
            icon: CupertinoIcons.device_phone_portrait,
            title: l10n.sync_rollback_local_only_title,
            subtitle: l10n.sync_rollback_local_only_subtitle,
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
    final l10n = AppLocalizations.of(context)!;
    final config = context.read<SyncConfigService>().config;
    if (config == null || !config.isValid) {
      final go = await AppDialogs.showConfirm(
        context,
        title: l10n.sync_not_configured_title,
        content: l10n.sync_not_configured_content,
        cancelText: l10n.common_cancel,
        confirmText: l10n.sync_go_config_button,
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
        title: l10n.sync_network_precheck_failed_title,
        content: precheckError,
      );
      return null;
    }

    return config;
  }

  Future<void> _confirmAndRollbackServer(int targetRevision) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.sync_confirm_rollback_server_title,
      content: l10n.sync_confirm_rollback_server_content(targetRevision),
      cancelText: l10n.common_cancel,
      confirmText: l10n.sync_confirm_rollback_server_confirm,
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
        title: l10n.sync_rollback_done_title,
        content: applyError == null
            ? l10n.sync_rollback_done_content(
                targetRevision,
                result.serverRevision,
              )
            : l10n.sync_rollback_done_partial_content(applyError),
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.sync_rollback_failed_title,
        content: _stringifyError(e),
      );
    } finally {
      if (mounted) {
        setState(() => _rollbackBusy = false);
      }
    }
  }

  Future<void> _confirmAndRollbackLocal(int targetRevision) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await AppDialogs.showConfirm(
      context,
      title: l10n.sync_confirm_rollback_local_title,
      content: l10n.sync_confirm_rollback_local_content(targetRevision),
      cancelText: l10n.common_cancel,
      confirmText: l10n.sync_confirm_rollback_local_confirm,
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
        title: l10n.sync_overwrite_local_done_title,
        content: applyError == null
            ? l10n.sync_overwrite_local_done_content(targetRevision)
            : l10n.sync_overwrite_local_done_partial_content(applyError),
      );
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showInfo(
        context,
        title: l10n.sync_overwrite_local_failed_title,
        content: _stringifyError(e),
      );
    } finally {
      if (mounted) {
        setState(() => _rollbackBusy = false);
      }
    }
  }

  List<Widget> _buildDiffCards(SyncRecord record) {
    final l10n = AppLocalizations.of(context)!;
    final diff = record.diff;
    if (diff == null) {
      return [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.sync_diff_none,
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.textSecondary,
            ),
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
            l10n.sync_diff_format_error,
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.textSecondary,
            ),
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

      // Filter out length_changed
      final filteredItems = diffItems.where((e) {
        if (e is! Map) return false;
        return e['change'] != 'length_changed';
      }).toList();

      if (filteredItems.isEmpty) continue;

      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SyncDiffPresenter.getToolName(toolId),
                  style: IOS26Theme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...filteredItems.take(80).map((e) => _buildDiffLine(toolId, e)),
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
            l10n.sync_diff_no_substantive,
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.textSecondary,
            ),
          ),
        ),
      ];
    }

    return cards;
  }

  Widget _buildDiffLine(String toolId, dynamic raw) {
    if (raw is! Map) {
      final l10n = AppLocalizations.of(context)!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          l10n.sync_diff_unknown_item,
          style: IOS26Theme.bodySmall.copyWith(color: IOS26Theme.textSecondary),
        ),
      );
    }

    final display = SyncDiffPresenter.formatDiffItem(toolId, raw);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: display.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              display.label,
              style: IOS26Theme.bodySmall.copyWith(
                color: display.color,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              display.details.isNotEmpty
                  ? '${display.path} (${display.details})'
                  : display.path,
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textSecondary,
              ),
            ),
          ),
        ],
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
