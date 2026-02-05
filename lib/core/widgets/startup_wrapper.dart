import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sync/models/sync_config.dart';
import '../sync/services/sync_service.dart';
import '../sync/services/sync_config_service.dart';
import '../sync/services/sync_network_precheck.dart';
import 'ios26_toast.dart';

/// 启动任务包装器
///
/// 负责在应用启动时执行一次性任务，例如自动同步。
class StartupWrapper extends StatefulWidget {
  final Widget child;

  const StartupWrapper({super.key, required this.child});

  @override
  State<StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends State<StartupWrapper> {
  @override
  void initState() {
    super.initState();
    // 延迟执行，确保 UI 构建完成
    Future.microtask(_performStartupTasks);
  }

  Future<void> _performStartupTasks() async {
    if (!mounted) return;

    // 1. 启动时自动同步
    final syncConfigService = context.read<SyncConfigService>();
    final config = syncConfigService.config;

    if (config != null && config.autoSyncOnStartup) {
      // 稍微延迟一下，避免与应用启动时的其他繁重操作争抢资源
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      final syncService = context.read<SyncService>();
      final toastService = context.read<ToastService>();

      // 显示开始提示（可选，这里只提示结果）
      // toastService.show('正在自动同步...');
      
      final success = await syncService.sync(trigger: SyncTrigger.auto);
      
      if (!mounted) return;
      
      if (success) {
        toastService.showSuccess('自动同步成功');
      } else {
        final error = syncService.lastError;
        // 启动自动同步：若仅是不满足“私网必须连 WiFi”的前置条件，则静默跳过即可。
        if (config.networkType == SyncNetworkType.privateWifi &&
            SyncNetworkPrecheck.isPrivateWifiNotConnectedError(error)) {
          return;
        }

        // 如果是因为“正在同步中”返回 false，可能不需要报错？
        // 但 sync() 内部如果正在同步会返回 false 且设置 lastError。
        toastService.showError('自动同步失败: ${error ?? "未知错误"}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
