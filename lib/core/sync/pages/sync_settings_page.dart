import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/ios26_theme.dart';
import '../models/sync_config.dart';
import '../services/sync_config_service.dart';
import '../services/sync_service.dart';
import 'package:intl/intl.dart';

/// 同步设置页面（简化版）
class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  late TextEditingController _userIdController;
  late TextEditingController _serverUrlController;
  late TextEditingController _portController;

  SyncNetworkType _networkType = SyncNetworkType.public;
  List<String> _wifiNames = [];
  bool _autoSyncOnStartup = true;

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController();
    _serverUrlController = TextEditingController();
    _portController = TextEditingController(text: '443');

    // 加载现有配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = context.read<SyncConfigService>().config;
      if (config != null) {
        setState(() {
          _userIdController.text = config.userId;
          _serverUrlController.text = config.serverUrl;
          _portController.text = config.serverPort.toString();
          _networkType = config.networkType;
          _wifiNames = List.from(config.allowedWifiNames);
          _autoSyncOnStartup = config.autoSyncOnStartup;
        });
      }
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _serverUrlController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: AppBar(
        title: const Text('数据同步设置'),
        backgroundColor: IOS26Theme.surfaceColor,
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: const Text('保存',
                style: TextStyle(color: IOS26Theme.primaryColor)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNetworkTypeSection(),
            const SizedBox(height: 24),
            _buildBasicConfigSection(),
            const SizedBox(height: 24),
            if (_networkType == SyncNetworkType.privateWifi) ...[
              _buildWifiSection(),
              const SizedBox(height: 24),
            ],
            _buildAdvancedSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 16),
            _buildSyncStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('网络类型',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        CupertinoSegmentedControl<SyncNetworkType>(
          children: const {
            SyncNetworkType.public: Text('公网模式'),
            SyncNetworkType.privateWifi: Text('私网模式'),
          },
          groupValue: _networkType,
          onValueChanged: (value) {
            setState(() => _networkType = value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _networkType == SyncNetworkType.public
              ? '公网模式：任何网络环境下都可以同步'
              : '私网模式：只有在指定WiFi下才能同步',
          style: const TextStyle(fontSize: 13, color: IOS26Theme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBasicConfigSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('基本配置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildTextField('用户ID', _userIdController, '用于服务端识别用户'),
        const SizedBox(height: 12),
        _buildTextField('服务器地址', _serverUrlController, '例: sync.example.com'),
        const SizedBox(height: 12),
        _buildTextField('端口', _portController, '默认 443',
            keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildWifiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('允许的WiFi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(CupertinoIcons.add_circled,
                  color: IOS26Theme.primaryColor),
              onPressed: _addWifiName,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_wifiNames.isEmpty)
          const Text('未配置WiFi名称',
              style: TextStyle(color: IOS26Theme.textSecondary))
        else
          ..._wifiNames.map((wifi) => _buildWifiItem(wifi)),
      ],
    );
  }

  Widget _buildWifiItem(String wifiName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.wifi,
              size: 20, color: IOS26Theme.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(wifiName)),
          IconButton(
            icon: const Icon(CupertinoIcons.trash,
                size: 20, color: IOS26Theme.toolRed),
            onPressed: () {
              setState(() => _wifiNames.remove(wifiName));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('高级选项',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('启动时自动同步'),
            CupertinoSwitch(
              value: _autoSyncOnStartup,
              onChanged: (value) => setState(() => _autoSyncOnStartup = value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: Consumer<SyncService>(
        builder: (context, syncService, _) {
          return ElevatedButton(
            onPressed: syncService.isSyncing ? null : _performSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: IOS26Theme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: syncService.isSyncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('立即同步',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
          );
        },
      ),
    );
  }

  Widget _buildSyncStatus() {
    return Consumer2<SyncConfigService, SyncService>(
      builder: (context, configService, syncService, _) {
        final lastSyncTime = configService.config?.lastSyncTime;
        final lastError = syncService.lastError;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: IOS26Theme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('同步状态',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (lastSyncTime != null)
                Text(
                  '上次同步: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(lastSyncTime)}',
                  style: const TextStyle(
                      fontSize: 13, color: IOS26Theme.textSecondary),
                ),
              if (lastError != null) ...[
                const SizedBox(height: 4),
                Text(
                  '错误: $lastError',
                  style: const TextStyle(
                      fontSize: 13, color: IOS26Theme.toolRed),
                ),
              ],
              if (syncService.state == SyncState.success) ...[
                const SizedBox(height: 4),
                const Text(
                  '✓ 同步成功',
                  style:
                      TextStyle(fontSize: 13, color: IOS26Theme.toolGreen),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  void _addWifiName() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('添加WiFi名称'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '输入WiFi名称（SSID）'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() => _wifiNames.add(controller.text.trim()));
                  Navigator.pop(context);
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveConfig() async {
    final config = SyncConfig(
      userId: _userIdController.text.trim(),
      networkType: _networkType,
      serverUrl: _serverUrlController.text.trim(),
      serverPort: int.tryParse(_portController.text) ?? 443,
      customHeaders: {},
      allowedWifiNames: _wifiNames,
      autoSyncOnStartup: _autoSyncOnStartup,
    );

    if (!config.isValid) {
      _showError('配置不完整，请检查必填项');
      return;
    }

    await context.read<SyncConfigService>().save(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
    }
  }

  Future<void> _performSync() async {
    final success = await context.read<SyncService>().sync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '同步成功' : '同步失败')),
      );
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
