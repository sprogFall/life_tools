import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/ios26_theme.dart';
import '../models/sync_config.dart';
import '../services/backup_restore_service.dart';
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
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            IOS26AppBar(
              title: '数据同步',
              showBackButton: true,
              actions: [
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  onPressed: _saveConfig,
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.primaryColor,
                    ),
                  ),
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
                    const SizedBox(height: 16),
                    _buildBackupRestoreCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: IOS26Theme.textPrimary,
      ),
    );
  }

  Widget _buildHint(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
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
          _buildCardTitle('网络类型'),
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
          _buildCardTitle('基本配置'),
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
              placeholder: '例如 sync.example.com',
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
              Expanded(child: _buildCardTitle('允许的 WiFi（SSID）')),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                onPressed: _refreshCurrentWifi,
                child: const Icon(
                  CupertinoIcons.refresh,
                  size: 18,
                  color: IOS26Theme.primaryColor,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            Column(
              children: _wifiNames.map(_buildWifiItem).toList(),
            ),
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
              style: const TextStyle(
                fontSize: 15,
                color: IOS26Theme.textPrimary,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            onPressed: () => setState(() => _wifiNames = [
              for (final name in _wifiNames)
                if (name != wifiName) name,
            ]),
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
          _buildCardTitle('高级选项'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '启动时自动同步',
                  style: TextStyle(
                    fontSize: 15,
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
              _buildCardTitle('同步'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  color: IOS26Theme.primaryColor,
                  onPressed: syncService.isSyncing ? null : _performSync,
                  child: syncService.isSyncing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '立即同步',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.24,
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
                const Text(
                  '同步成功',
                  style: TextStyle(
                    fontSize: 13,
                    color: IOS26Theme.toolGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (lastError != null) ...[
                const SizedBox(height: 10),
                const Text(
                  '错误信息（便于调试）：',
                  style: TextStyle(
                    fontSize: 13,
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
                    style: const TextStyle(
                      fontSize: 13,
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
                        child: const Text(
                          '复制错误详情',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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

  Widget _buildBackupRestoreCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle('备份与还原'),
          const SizedBox(height: 10),
          _buildHint('导出：同步配置 + 工具数据导出为 JSON，并复制到剪切板'),
          const SizedBox(height: 4),
          _buildHint('还原：粘贴 JSON 覆盖写入本地（请谨慎操作）'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  color: IOS26Theme.primaryColor,
                  onPressed: _exportBackupToClipboard,
                  child: const Text(
                    '导出到剪切板',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
                  onPressed: _openRestoreSheet,
                  child: const Text(
                    '从 JSON 还原',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.textSecondary,
                      letterSpacing: -0.24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refreshCurrentWifi() async {
    final wifiService = WifiService();
    final status = await wifiService.getNetworkStatus();
    if (!mounted) return;

    if (status != NetworkStatus.wifi) {
      setState(() {
        _currentWifiName = null;
        _currentWifiHint = '当前网络：${status.name}（私网模式需 WiFi）';
      });
      return;
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
      await _showDialog(
        title: '提示',
        content: '配置不完整，请检查必填项（私网模式需至少配置 1 个 WiFi）',
      );
      return;
    }

    await context.read<SyncConfigService>().save(config);
    if (!mounted) return;

    await _showDialog(title: '已保存', content: '同步配置已更新');
  }

  Future<void> _performSync() async {
    final ok = await context.read<SyncService>().sync();
    if (!mounted) return;

    await _showDialog(
      title: ok ? '同步完成' : '同步失败',
      content: ok ? '已完成同步' : '请查看页面内的错误信息（便于调试）',
    );
  }

  Future<void> _addWifiName() async {
    final controller = TextEditingController(text: _currentWifiName ?? '');

    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('添加 WiFi 名称（SSID）'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '例如 MyHomeWifi',
            decoration: _fieldDecoration(),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final normalized =
                  WifiService.normalizeWifiName(controller.text);
              if (normalized == null) return;

              setState(() {
                final set = <String>{
                  ..._wifiNames.map(WifiService.normalizeWifiName).whereType<String>(),
                  normalized,
                };
                _wifiNames = set.toList()..sort();
              });

              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _exportBackupToClipboard() async {
    final service = BackupRestoreService(
      syncConfigService: context.read<SyncConfigService>(),
    );

    final jsonText = await service.exportAsJson(pretty: true);
    await _copyToClipboard(jsonText);
    if (!mounted) return;

    final kb = (jsonText.length / 1024).toStringAsFixed(1);
    await _showDialog(title: '已导出', content: 'JSON 已复制到剪切板（约 $kb KB）');
  }

  Future<void> _openRestoreSheet() async {
    final controller = TextEditingController();

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('从 JSON 还原'),
        message: SizedBox(
          height: 180,
          child: CupertinoTextField(
            controller: controller,
            placeholder: '粘贴备份 JSON（将覆盖写入本地）',
            maxLines: null,
            decoration: _fieldDecoration(),
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              controller.text = data?.text ?? '';
            },
            child: const Text('从剪切板粘贴'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => controller.clear(),
            isDestructiveAction: true,
            child: const Text('清空输入'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              final confirmed = await _confirmRestore();
              if (!confirmed) return;
              if (!mounted) return;

              try {
                final service = BackupRestoreService(
                  syncConfigService: context.read<SyncConfigService>(),
                );
                final result = await service.restoreFromJson(controller.text);
                if (!mounted) return;

                Navigator.pop(context);
                _loadConfigFromService();

                final summary = [
                  '已导入工具：${result.importedTools}',
                  '已跳过工具：${result.skippedTools}',
                  if (result.failedTools.isNotEmpty)
                    '失败工具：${result.failedTools.keys.join("，")}',
                ].join('\n');

                await _showDialog(title: '还原完成', content: summary);
              } catch (e) {
                if (!mounted) return;
                await _showDialog(title: '还原失败', content: e.toString());
              }
            },
            isDestructiveAction: true,
            child: const Text('开始还原（覆盖本地）'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );

    controller.dispose();
  }

  Future<bool> _confirmRestore() async {
    var confirmed = false;
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认还原？'),
        content: const Text('该操作会覆盖本地配置与数据，建议先导出备份。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              confirmed = true;
              Navigator.pop(context);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
    return confirmed;
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _showDialog({
    required String title,
    required String content,
  }) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
