import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../theme/ios26_theme.dart';
import 'package:life_tools/core/ui/app_dialogs.dart';
import 'package:life_tools/core/ui/app_scaffold.dart';
import 'package:life_tools/core/ui/section_header.dart';
import '../models/sync_config.dart';
import '../services/sync_config_service.dart';
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

    setState(() {
      _userIdController.text = config.userId;
      _serverUrlController.text = config.serverUrl;
      _portController.text = config.serverPort.toString();
      _networkType = config.networkType;
      _wifiNames = List<String>.from(config.allowedWifiNames);
      _autoSyncOnStartup = config.autoSyncOnStartup;
    });
  }

  static BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
        width: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(
            title: '数据同步',
            showBackButton: true,
            actions: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onPressed: _saveConfig,
                child: Text('保存', style: IOS26Theme.labelLarge),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
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
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '网络类型', padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          CupertinoSlidingSegmentedControl<SyncNetworkType>(
            groupValue: _networkType,
            children: const {
              SyncNetworkType.public: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('公网模式'),
              ),
              SyncNetworkType.privateWifi: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('私网模式'),
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
                ? '公网模式：只要有网络即可同步'
                : '私网模式：仅允许在指定 WiFi 下同步（用于家庭/公司内网）',
          ),
        ],
      ),
    );
  }

  Widget _buildBasicConfigCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '基本配置', padding: EdgeInsets.zero),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '用户 ID',
            child: CupertinoTextField(
              controller: _userIdController,
              placeholder: '用于服务端区分用户',
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '服务器地址',
            child: CupertinoTextField(
              controller: _serverUrlController,
              placeholder: '例如 https://sync.example.com 或 http://127.0.0.1',
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLabeledField(
            label: '端口',
            child: CupertinoTextField(
              controller: _portController,
              placeholder: '默认 443',
              keyboardType: TextInputType.number,
              autocorrect: false,
              decoration: _fieldDecoration(),
            ),
          ),
          const SizedBox(height: 10),
          _buildHint('提示：本地部署（docker/uvicorn）通常是 http + 8080，请显式填写 http:// 避免 TLS 握手错误。'),
        ],
      ),
    );
  }

  Widget _buildWifiCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: '允许的 WiFi（SSID）',
                  padding: EdgeInsets.zero,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                onPressed: _refreshCurrentWifi,
                child: const Icon(
                  CupertinoIcons.refresh,
                  size: 18,
                  color: IOS26Theme.primaryColor,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                onPressed: _addWifiName,
                child: const Icon(
                  CupertinoIcons.add_circled,
                  size: 20,
                  color: IOS26Theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_currentWifiName != null)
            _buildHint('当前 WiFi：$_currentWifiName')
          else if (_currentWifiHint != null)
            _buildHint(_currentWifiHint!)
          else
            _buildHint('当前 WiFi：未知（可点右侧刷新）'),
          const SizedBox(height: 12),
          if (_wifiNames.isEmpty)
            _buildHint('未配置允许的 WiFi 名称')
          else
            Column(children: _wifiNames.map(_buildWifiItem).toList()),
          const SizedBox(height: 10),
          _buildHint('提示：SSID 区分大小写，建议不要包含引号和首尾空格'),
        ],
      ),
    );
  }

  Widget _buildWifiItem(String wifiName) {
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
          const Icon(
            CupertinoIcons.wifi,
            size: 18,
            color: IOS26Theme.textSecondary,
          ),
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
            child: const Icon(
              CupertinoIcons.trash,
              size: 18,
              color: IOS26Theme.toolRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '高级选项', padding: EdgeInsets.zero),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '启动时自动同步',
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
        final lastSyncTime = configService.config?.lastSyncTime;
        final lastError = syncService.lastError;

        return GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '同步', padding: EdgeInsets.zero),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  color: IOS26Theme.primaryColor,
                  onPressed: syncService.isSyncing ? null : _performSync,
                  child: syncService.isSyncing
                      ? const CupertinoActivityIndicator(
                          radius: 9,
                          color: Colors.white,
                        )
                      : Text(
                          '立即同步',
                          style: IOS26Theme.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (lastSyncTime != null)
                _buildHint(
                  '上次同步：${DateFormat('yyyy-MM-dd HH:mm:ss').format(lastSyncTime)}',
                )
              else
                _buildHint('上次同步：暂无'),
              if (syncService.state == SyncState.success) ...[
                const SizedBox(height: 6),
                Text(
                  '同步成功',
                  style: IOS26Theme.bodySmall.copyWith(
                    color: IOS26Theme.toolGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (lastError != null) ...[
                const SizedBox(height: 10),
                Text(
                  '错误信息（便于调试）：',
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
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(14),
                        color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
                        onPressed: () => _copyToClipboard(lastError),
                        child: Text(
                          '复制错误详情',
                          style: IOS26Theme.labelLarge.copyWith(
                            color: IOS26Theme.textSecondary,
                          ),
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
        _currentWifiHint = '当前网络：${status.name}（私网模式需 WiFi）';
      });
      return;
    }

    if (_networkType == SyncNetworkType.privateWifi) {
      final permissionOk = await _ensureWifiNamePermission();
      if (!permissionOk) {
        if (!mounted) return;
        setState(() {
          _currentWifiName = null;
          _currentWifiHint = '无法获取 SSID：未获得定位权限（Android 读取 WiFi 名称需要定位权限）';
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
          ? '已连接 WiFi，但无法获取 SSID（可能缺少定位权限/未开启定位/系统限制）'
          : null;
    });
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

    await AppDialogs.showInfo(
      context,
      title: '需要定位权限',
      content: 'Android 读取当前 WiFi 名称（SSID）需要定位权限，请在系统弹窗中选择允许后再重试。',
    );
    return false;
  }

  Future<bool> _confirmOpenAppSettings() async {
    return AppDialogs.showConfirm(
      context,
      title: '权限被永久拒绝',
      content: '请前往系统设置开启定位权限后再获取 WiFi 名称。',
      cancelText: '取消',
      confirmText: '去设置',
    );
  }

  Future<void> _saveConfig() async {
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
        title: '提示',
        content: '配置不完整，请检查必填项（私网模式需至少配置 1 个 WiFi）',
      );
      return;
    }

    await context.read<SyncConfigService>().save(config);
    if (!mounted) return;

    await AppDialogs.showInfo(context, title: '已保存', content: '同步配置已更新');
  }

  Future<void> _performSync() async {
    if (_networkType == SyncNetworkType.privateWifi) {
      final permissionOk = await _ensureWifiNamePermission();
      if (!mounted) return;
      if (!permissionOk) return;

      await _refreshCurrentWifi();
      if (!mounted) return;
    }

    final ok = await context.read<SyncService>().sync();
    if (!mounted) return;

    await AppDialogs.showInfo(
      context,
      title: ok ? '同步完成' : '同步失败',
      content: ok ? '已完成同步' : '请查看页面内的错误信息（便于调试）',
    );
  }

  Future<void> _addWifiName() async {
    await _refreshCurrentWifi();
    if (!mounted) return;

    final name = await AppDialogs.showInput(
      context,
      title: '添加 WiFi 名称（SSID）',
      placeholder: '例如 MyHomeWifi',
      defaultValue: _currentWifiName ?? '',
      confirmText: '添加',
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
