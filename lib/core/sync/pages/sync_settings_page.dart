import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:life_tools/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../theme/ios26_theme.dart';
import '../../utils/text_editing_safety.dart';
import 'package:life_tools/core/ui/app_dialogs.dart';
import 'package:life_tools/core/ui/app_scaffold.dart';
import 'package:life_tools/core/ui/section_header.dart';
import '../models/sync_force_decision.dart';
import '../models/sync_config.dart';
import '../services/sync_config_service.dart';
import '../services/sync_local_state_service.dart';
import '../services/sync_service.dart';
import '../services/wifi_service.dart';

/// 数据同步配置页（iOS 26 风格）
class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  late final TextEditingController _userIdController;
  late final TextEditingController _serverUrlController;
  late final TextEditingController _portController;

  SyncNetworkType _networkType = SyncNetworkType.public;
  List<String> _wifiNames = const [];
  bool _autoSyncOnStartup = true;

  String? _currentWifiName;
  String? _currentWifiHint;

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController();
    _serverUrlController = TextEditingController();
    _portController = TextEditingController(text: '443');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfigFromService();
      _refreshCurrentWifi();
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _serverUrlController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _loadConfigFromService() {
    final config = context.read<SyncConfigService>().config;
    if (config == null) return;

    setControllerTextWhenComposingIdle(
      _userIdController,
      config.userId,
      shouldContinue: () => mounted,
    );
    setControllerTextWhenComposingIdle(
      _serverUrlController,
      config.serverUrl,
      shouldContinue: () => mounted,
    );
    setControllerTextWhenComposingIdle(
      _portController,
      config.serverPort.toString(),
      shouldContinue: () => mounted,
    );

    setState(() {
      _networkType = config.networkType;
      _wifiNames = List<String>.from(config.allowedWifiNames);
      _autoSyncOnStartup = config.autoSyncOnStartup;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(
            title: l10n.sync_settings_title,
            showBackButton: true,
            actions: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onPressed: _saveConfig,
                child: Text(l10n.common_save, style: IOS26Theme.labelLarge),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNetworkCard(),
                  const SizedBox(height: 16),
                  _buildBasicConfigCard(),
                  const SizedBox(height: 16),
                  if (_networkType == SyncNetworkType.privateWifi) ...[
                    _buildWifiCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildAdvancedCard(),
                  const SizedBox(height: 16),
                  _buildSyncActionCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(String text) {
    return Text(
      text,
      style: IOS26Theme.bodySmall.copyWith(
        color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: IOS26Theme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: IOS26Theme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildNetworkCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.sync_network_type_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          CupertinoSlidingSegmentedControl<SyncNetworkType>(
            groupValue: _networkType,
            children: {
              SyncNetworkType.public: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(l10n.sync_network_public_label),
              ),
              SyncNetworkType.privateWifi: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(l10n.sync_network_private_label),
              ),
            },
            onValueChanged: (value) {
              if (value == null) return;
              setState(() => _networkType = value);
            },
          ),
          const SizedBox(height: 10),
          _buildHint(
            _networkType == SyncNetworkType.public
                ? l10n.sync_network_public_hint
                : l10n.sync_network_private_hint,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicConfigCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.sync_basic_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.sync_user_id_label,
            child: CupertinoTextField(
              controller: _userIdController,
              placeholder: l10n.sync_user_id_placeholder,
              autocorrect: false,
              decoration: IOS26Theme.textFieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.sync_server_url_label,
            child: CupertinoTextField(
              controller: _serverUrlController,
              placeholder: l10n.sync_server_url_placeholder,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: IOS26Theme.textFieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: l10n.sync_port_label,
            child: CupertinoTextField(
              controller: _portController,
              placeholder: l10n.sync_port_placeholder,
              keyboardType: TextInputType.number,
              autocorrect: false,
              decoration: IOS26Theme.textFieldDecoration(),
            ),
          ),
          const SizedBox(height: 10),
          _buildHint(l10n.sync_server_url_tip),
        ],
      ),
    );
  }

  Widget _buildWifiCard() {
    final l10n = AppLocalizations.of(context)!;
    final accentIconColor = IOS26Theme.iconColor(IOS26IconTone.accent);
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: l10n.sync_allowed_wifi_section_title,
                  padding: EdgeInsets.zero,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                onPressed: _refreshCurrentWifi,
                child: Icon(
                  CupertinoIcons.refresh,
                  size: 18,
                  color: accentIconColor,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                onPressed: _addWifiName,
                child: Icon(
                  CupertinoIcons.add_circled,
                  size: 20,
                  color: accentIconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_currentWifiName != null)
            _buildHint(l10n.sync_current_wifi_label(_currentWifiName!))
          else if (_currentWifiHint != null)
            _buildHint(_currentWifiHint!)
          else
            _buildHint(l10n.sync_current_wifi_unknown_hint),
          const SizedBox(height: 12),
          if (_wifiNames.isEmpty)
            _buildHint(l10n.sync_allowed_wifi_empty_hint)
          else
            Column(children: _wifiNames.map(_buildWifiItem).toList()),
          const SizedBox(height: 10),
          _buildHint(l10n.sync_wifi_ssid_tip),
        ],
      ),
    );
  }

  Widget _buildWifiItem(String wifiName) {
    final dangerIconColor = IOS26Theme.iconColor(IOS26IconTone.danger);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.wifi, size: 18, color: IOS26Theme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              wifiName,
              style: IOS26Theme.bodyMedium.copyWith(
                color: IOS26Theme.textPrimary,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            onPressed: () => setState(
              () => _wifiNames = [
                for (final name in _wifiNames)
                  if (name != wifiName) name,
              ],
            ),
            child: Icon(CupertinoIcons.trash, size: 18, color: dangerIconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCard() {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: l10n.sync_advanced_section_title,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sync_auto_sync_on_startup_label,
                  style: IOS26Theme.bodyMedium.copyWith(
                    color: IOS26Theme.textPrimary,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: _autoSyncOnStartup,
                onChanged: (value) =>
                    setState(() => _autoSyncOnStartup = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncActionCard() {
    return Consumer2<SyncConfigService, SyncService>(
      builder: (context, configService, syncService, _) {
        final l10n = AppLocalizations.of(context)!;
        final lastSyncTime = configService.config?.lastSyncTime;
        final lastError = syncService.lastError;

        return GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: l10n.sync_section_title,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: IOS26Button(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  variant: IOS26ButtonVariant.primary,
                  onPressed: syncService.isSyncing ? null : _performSync,
                  child: syncService.isSyncing
                      ? const IOS26ButtonLoadingIndicator(radius: 9)
                      : IOS26ButtonLabel(
                          l10n.sync_now_button,
                          style: IOS26Theme.labelLarge,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (lastSyncTime != null)
                _buildHint(
                  l10n.sync_last_sync_label(
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(lastSyncTime),
                  ),
                )
              else
                _buildHint(l10n.sync_last_sync_none),
              if (syncService.state == SyncState.success) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.sync_success_label,
                  style: IOS26Theme.bodySmall.copyWith(
                    color: IOS26Theme.toolGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (lastError != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.sync_error_details_label,
                  style: IOS26Theme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: IOS26Theme.toolRed,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: IOS26Theme.toolRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: IOS26Theme.toolRed.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    lastError,
                    style: IOS26Theme.bodySmall.copyWith(
                      color: IOS26Theme.toolRed,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: IOS26Button(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(14),
                        variant: IOS26ButtonVariant.ghost,
                        onPressed: () => _copyToClipboard(lastError),
                        child: IOS26ButtonLabel(
                          l10n.sync_copy_error_details_button,
                          style: IOS26Theme.labelLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshCurrentWifi() async {
    final l10n = AppLocalizations.of(context)!;
    WifiService wifiService;
    try {
      wifiService = context.read<WifiService>();
    } catch (_) {
      wifiService = WifiService();
    }
    final status = await wifiService.getNetworkStatus();
    if (!mounted) return;

    if (status != NetworkStatus.wifi) {
      setState(() {
        _currentWifiName = null;
        _currentWifiHint = l10n.sync_current_network_hint(
          _formatNetworkStatus(l10n, status),
        );
      });
      return;
    }

    if (_networkType == SyncNetworkType.privateWifi) {
      final permissionOk = await _ensureWifiNamePermission();
      if (!permissionOk) {
        if (!mounted) return;
        setState(() {
          _currentWifiName = null;
          _currentWifiHint = l10n.sync_wifi_permission_hint;
        });
        return;
      }
    }

    final raw = await wifiService.getCurrentWifiName();
    final normalized = WifiService.normalizeWifiName(raw);
    if (!mounted) return;

    setState(() {
      _currentWifiName = normalized;
      _currentWifiHint = normalized == null
          ? l10n.sync_wifi_ssid_unavailable_hint
          : null;
    });
  }

  String _formatNetworkStatus(AppLocalizations l10n, NetworkStatus status) {
    return switch (status) {
      NetworkStatus.wifi => l10n.network_status_wifi,
      NetworkStatus.mobile => l10n.network_status_mobile,
      NetworkStatus.offline => l10n.network_status_offline,
      NetworkStatus.unknown => l10n.network_status_unknown,
    };
  }

  Future<bool> _ensureWifiNamePermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;

    final result = await Permission.locationWhenInUse.request();
    if (result.isGranted) return true;

    if (!mounted) return false;

    if (result.isPermanentlyDenied) {
      final go = await _confirmOpenAppSettings();
      if (go) {
        await openAppSettings();
      }
      return false;
    }

    final l10n = AppLocalizations.of(context)!;
    await AppDialogs.showInfo(
      context,
      title: l10n.sync_location_permission_required_title,
      content: l10n.sync_location_permission_required_content,
    );
    return false;
  }

  Future<bool> _confirmOpenAppSettings() async {
    final l10n = AppLocalizations.of(context)!;
    return AppDialogs.showConfirm(
      context,
      title: l10n.sync_permission_permanently_denied_title,
      content: l10n.sync_permission_permanently_denied_content,
      cancelText: l10n.common_cancel,
      confirmText: l10n.common_go_settings,
    );
  }

  Future<void> _saveConfig() async {
    final l10n = AppLocalizations.of(context)!;
    final config = SyncConfig(
      userId: _userIdController.text.trim(),
      networkType: _networkType,
      serverUrl: _serverUrlController.text.trim(),
      serverPort: int.tryParse(_portController.text.trim()) ?? 443,
      customHeaders: const {},
      allowedWifiNames: _wifiNames,
      autoSyncOnStartup: _autoSyncOnStartup,
    );

    if (!config.isValid) {
      await AppDialogs.showInfo(
        context,
        title: l10n.sync_config_invalid_title,
        content: l10n.sync_config_invalid_content,
      );
      return;
    }

    final configService = context.read<SyncConfigService>();
    final localStateService = context.read<SyncLocalStateService>();
    final currentUserId = configService.config?.userId.trim() ?? '';
    if (localStateService.localUserId == null &&
        currentUserId.isNotEmpty &&
        currentUserId != config.userId) {
      // 若用户在“未记录 localUserId”的历史版本基础上切换 userId，
      // 这里先把“切换前的 userId”记为本地数据归属，避免后续误覆盖服务端。
      await localStateService.setLocalUserId(currentUserId);
    }

    await configService.save(config);
    if (!mounted) return;

    await AppDialogs.showInfo(
      context,
      title: l10n.sync_config_saved_title,
      content: l10n.sync_config_saved_content,
    );
  }

  Future<void> _performSync() async {
    final l10n = AppLocalizations.of(context)!;
    final syncService = context.read<SyncService>();
    final mismatch = syncService.getUserMismatch();
    SyncForceDecision? forceDecision;

    if (mismatch != null) {
      forceDecision = await _confirmUserMismatch(mismatch);
      if (!mounted) return;
      if (forceDecision == null) return;
    }

    if (_networkType == SyncNetworkType.privateWifi) {
      final permissionOk = await _ensureWifiNamePermission();
      if (!mounted) return;
      if (!permissionOk) return;

      await _refreshCurrentWifi();
      if (!mounted) return;
    }

    final ok = await syncService.sync(
      trigger: SyncTrigger.manual,
      forceDecision: forceDecision,
    );
    if (!mounted) return;

    await AppDialogs.showInfo(
      context,
      title: ok
          ? l10n.sync_finished_title_success
          : l10n.sync_finished_title_failed,
      content: ok
          ? l10n.sync_finished_content_success
          : l10n.sync_finished_content_failed,
    );
  }

  Future<SyncForceDecision?> _confirmUserMismatch(
    SyncUserMismatch mismatch,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    final result = await showCupertinoDialog<SyncForceDecision>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.sync_user_mismatch_title),
        content: Text(
          l10n.sync_user_mismatch_content(
            mismatch.localUserId,
            mismatch.serverUserId,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.common_cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, SyncForceDecision.useServer),
            child: Text(l10n.sync_user_mismatch_overwrite_local),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, SyncForceDecision.useClient),
            child: Text(l10n.sync_user_mismatch_overwrite_server),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _addWifiName() async {
    await _refreshCurrentWifi();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final name = await AppDialogs.showInput(
      context,
      title: l10n.sync_add_wifi_title,
      placeholder: l10n.sync_add_wifi_placeholder,
      defaultValue: _currentWifiName ?? '',
      confirmText: l10n.common_add,
    );

    if (name == null) return;
    final normalized = WifiService.normalizeWifiName(name);
    if (normalized == null) return;

    setState(() {
      final set = <String>{
        ..._wifiNames.map(WifiService.normalizeWifiName).whereType<String>(),
        normalized,
      };
      _wifiNames = set.toList()..sort();
    });
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
