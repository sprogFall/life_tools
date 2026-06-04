import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../core/app_build_info.dart';
import '../core/theme/ios26_theme.dart';
import '../core/ui/app_scaffold.dart';
import '../core/update/app_update.dart';
import '../core/utils/dev_log.dart';
import '../core/widgets/ios26_toast.dart';

class AboutPage extends StatefulWidget {
  final AppUpdateService? updateService;
  final String? currentVersionOverride;
  final bool? currentIsPrereleaseOverride;

  const AboutPage({
    super.key,
    this.updateService,
    this.currentVersionOverride,
    this.currentIsPrereleaseOverride,
  });

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const Duration _messageDismissDelay = Duration(seconds: 3);

  Timer? _dismissTimer;
  bool _showCommitMessage = false;
  bool _checkingUpdate = false;

  AppUpdateService? _ownedUpdateService;
  AppUpdateService? _observedUpdateService;

  String get _currentVersion =>
      widget.currentVersionOverride ?? AppBuildInfo.version;

  bool get _currentIsPrerelease =>
      widget.currentIsPrereleaseOverride ?? AppBuildInfo.isPreRelease;

  AppUpdateService get _updateService {
    if (widget.updateService != null) return widget.updateService!;
    try {
      return context.read<AppUpdateService>();
    } catch (error, stackTrace) {
      devLog(
        'AppUpdateService 未注入，使用页面内服务',
        error: error,
        stackTrace: stackTrace,
      );
      return _ownedUpdateService ??= AppUpdateService();
    }
  }

  static const List<_FeatureItem> _featureItems = [
    _FeatureItem(
      icon: CupertinoIcons.briefcase,
      tone: IOS26IconTone.primary,
      title: '工作记录',
      description: '任务拆分、工时登记、日志回溯，帮助快速整理每日产出。',
    ),
    _FeatureItem(
      icon: CupertinoIcons.cube_box_fill,
      tone: IOS26IconTone.success,
      title: '囤货助手',
      description: '管理库存、批量录入消耗，临期与过期提醒更省心。',
    ),
    _FeatureItem(
      icon: CupertinoIcons.flame_fill,
      tone: IOS26IconTone.warning,
      title: '胡闹厨房',
      description: '食谱与愿望单联动，配合抽卡记录与提醒轻松安排做饭计划。',
    ),
    _FeatureItem(
      icon: CupertinoIcons.tag,
      tone: IOS26IconTone.accent,
      title: '标签管理',
      description: '统一管理标签与分类，跨工具筛选信息更加直观。',
    ),
    _FeatureItem(
      icon: CupertinoIcons.sparkles,
      tone: IOS26IconTone.secondary,
      title: 'AI 辅助',
      description: '支持接入兼容 OpenAI 的模型，覆盖记录与整理场景。',
    ),
    _FeatureItem(
      icon: CupertinoIcons.arrow_2_circlepath_circle,
      tone: IOS26IconTone.secondary,
      title: '数据安全',
      description: '支持数据同步、备份恢复与对象存储，减少数据丢失风险。',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachUpdateService(_updateService);
  }

  @override
  void didUpdateWidget(covariant AboutPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updateService != widget.updateService) {
      _attachUpdateService(_updateService);
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _observedUpdateService?.removeListener(_handleUpdateServiceChanged);
    _ownedUpdateService?.close();
    super.dispose();
  }

  void _attachUpdateService(AppUpdateService service) {
    if (_observedUpdateService == service) return;
    _observedUpdateService?.removeListener(_handleUpdateServiceChanged);
    _observedUpdateService = service;
    service.addListener(_handleUpdateServiceChanged);
  }

  void _handleUpdateServiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: [
          const IOS26AppBar(title: '关于', showBackButton: true),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildIntroCard(),
                      const SizedBox(height: 14),
                      _buildUpdateCard(),
                      const SizedBox(height: 14),
                      _buildFeatureCard(),
                    ],
                  ),
                ),
                _buildCommitFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCard() {
    final downloadState = _updateService.downloadState;
    final downloadProgress = downloadState.progress;
    final busy = _checkingUpdate || downloadState.isBusy;
    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('版本更新', style: IOS26Theme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '当前版本 $_currentVersion',
                      style: IOS26Theme.bodySmall.copyWith(
                        color: IOS26Theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IOS26Button(
                    key: const ValueKey('about_check_beta_button'),
                    onPressed: busy ? null : _checkBetaUpdate,
                    variant: IOS26ButtonVariant.secondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: const IOS26ButtonLabel('体验版'),
                  ),
                  const SizedBox(width: 8),
                  IOS26Button(
                    key: const ValueKey('about_check_update_button'),
                    onPressed: busy ? null : _checkUpdateManually,
                    variant: IOS26ButtonVariant.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: _checkingUpdate
                        ? const IOS26ButtonLoadingIndicator(radius: 8)
                        : const IOS26ButtonLabel('检查更新'),
                  ),
                ],
              ),
            ],
          ),
          if (downloadState.isBusy) ...[
            const SizedBox(height: 12),
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: IOS26Theme.surfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
              ),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (downloadProgress ?? 0).clamp(0.04, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: IOS26Theme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              downloadProgress == null
                  ? '正在下载安装包...'
                  : '正在下载 ${(downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: IOS26Theme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: IOS26Icon(
                  CupertinoIcons.square_stack_3d_up_fill,
                  tone: IOS26IconTone.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '小蜜',
                  style: IOS26Theme.headlineMedium.copyWith(
                    color: IOS26Theme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '小蜜是一款围绕“日常记录 + 生活整理”打造的工具集合，'
            '把常用能力集中在一个入口，减少在多个应用间切换。',
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard() {
    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '基础功能',
            style: IOS26Theme.titleLarge.copyWith(
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ..._featureItems.map(_buildFeatureItem),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(_FeatureItem item) {
    final iconColors = IOS26Theme.iconChipColors(item.tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColors.border, width: 0.8),
            ),
            alignment: Alignment.center,
            child: IOS26Icon(item.icon, color: iconColors.foreground, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: IOS26Theme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: IOS26Theme.bodySmall.copyWith(
                    color: IOS26Theme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitFooter() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showCommitMessage)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassContainer(
                key: const ValueKey('about_commit_floating_message'),
                borderRadius: 14,
                blur: 12,
                color: IOS26Theme.surfaceColor.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  AppBuildInfo.commitMessage,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: IOS26Theme.bodySmall.copyWith(
                    color: IOS26Theme.textSecondary,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          GestureDetector(
            key: const ValueKey('about_commit_hash_tap_target'),
            behavior: HitTestBehavior.opaque,
            onTap: _showMessage,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                'commit ${AppBuildInfo.shortCommitSha}',
                style: IOS26Theme.bodySmall.copyWith(
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.82),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage() {
    _dismissTimer?.cancel();
    if (!_showCommitMessage) {
      setState(() => _showCommitMessage = true);
    }
    _dismissTimer = Timer(_messageDismissDelay, () {
      if (!mounted) return;
      setState(() => _showCommitMessage = false);
    });
  }

  Future<void> _checkUpdateManually() async {
    setState(() => _checkingUpdate = true);
    final result = await _updateService.checkForUpdate(
      includeIgnored: true,
      currentVersion: _currentVersion,
      currentIsPrerelease: _currentIsPrerelease,
    );
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    switch (result.availability) {
      case AppUpdateAvailability.updateAvailable:
      case AppUpdateAvailability.ignored:
        final release = result.release;
        if (release != null) {
          await _showUpdateDialog(
            release,
            forceUpdate: _currentIsPrerelease && !release.isPrerelease,
          );
        }
      case AppUpdateAvailability.upToDate:
        _showToast('当前已是最新版本');
      case AppUpdateAvailability.unavailable:
        _showToast(result.message ?? '检查更新失败，请稍后再试', error: true);
    }
  }

  Future<void> _checkBetaUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final release = await _updateService.fetchLatestPrerelease();
      if (!mounted) return;
      setState(() => _checkingUpdate = false);

      if (release == null) {
        _showToast('暂无可用的体验版本');
        return;
      }

      if (!_shouldOfferBetaUpdate(release)) {
        _showToast('当前已是最新版本');
        return;
      }

      await _showUpdateDialog(release, isBeta: true);
    } catch (error, stackTrace) {
      devLog('获取体验版失败', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _checkingUpdate = false);
      _showToast('获取体验版失败，请稍后再试', error: true);
    }
  }

  bool _shouldOfferBetaUpdate(AppReleaseInfo release) {
    final currentVersion = _currentVersion;
    if (AppVersion.parse(release.version).isNewerThan(currentVersion)) {
      return true;
    }
    return !_currentIsPrerelease &&
        release.isPrerelease &&
        AppVersion.isSameCore(release.version, currentVersion);
  }

  Future<void> _showUpdateDialog(
    AppReleaseInfo release, {
    bool isBeta = false,
    bool forceUpdate = false,
  }) async {
    final content = _buildUpdateDialogContent(
      release,
      isBeta: isBeta,
      forceUpdate: forceUpdate,
    );

    final action = await showCupertinoDialog<_UpdateDialogAction>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          forceUpdate
              ? '建议更新至正式版 ${release.version}'
              : isBeta
              ? '体验版 ${release.version}'
              : '发现新版本 ${release.version}',
        ),
        content: content,
        actions: [
          if (!forceUpdate)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, _UpdateDialogAction.later),
              child: const Text('稍后'),
            ),
          if (!isBeta && !forceUpdate)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, _UpdateDialogAction.ignore),
              child: const Text('忽略此版本'),
            ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, _UpdateDialogAction.install),
            isDefaultAction: true,
            child: const Text('立即更新'),
          ),
          if (forceUpdate)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, _UpdateDialogAction.later),
              child: const Text('稍后'),
            ),
        ],
      ),
    );

    if (!mounted) return;
    switch (action) {
      case _UpdateDialogAction.install:
        await _downloadAndInstall(release);
      case _UpdateDialogAction.ignore:
        if (!isBeta && !forceUpdate) {
          await _updateService.ignoreVersion(release.version);
          _showToast('已忽略此版本');
        }
      case _UpdateDialogAction.later:
      case null:
        break;
    }
  }

  Widget _buildUpdateDialogContent(
    AppReleaseInfo release, {
    required bool isBeta,
    bool forceUpdate = false,
  }) {
    final parts = <String>[];

    if (forceUpdate) {
      parts.add('⚠️ 您当前使用的是体验版，建议更新至稳定的正式版本');
      parts.add('');
    }

    // 提交信息
    if (release.commitMessage != null && release.commitMessage!.isNotEmpty) {
      parts.add('📝 ${release.commitMessage}');
    }

    // 提交 SHA
    if (release.commitSha != null && release.commitSha!.isNotEmpty) {
      parts.add('🔖 commit ${release.commitSha!.substring(0, 7)}');
    }

    // 发布时间
    if (release.publishedAt != null) {
      final now = DateTime.now();
      final diff = now.difference(release.publishedAt!);
      String timeAgo;
      if (diff.inDays > 0) {
        timeAgo = '${diff.inDays} 天前';
      } else if (diff.inHours > 0) {
        timeAgo = '${diff.inHours} 小时前';
      } else if (diff.inMinutes > 0) {
        timeAgo = '${diff.inMinutes} 分钟前';
      } else {
        timeAgo = '刚刚';
      }
      parts.add('🕒 $timeAgo');
    }

    // 安装包大小
    if (release.apkSize != null) {
      final sizeMb = (release.apkSize! / (1024 * 1024)).toStringAsFixed(1);
      parts.add('📦 $sizeMb MB');
    }

    // 体验版提示
    if (isBeta && !forceUpdate) {
      parts.add('\n⚠️ 体验版可能包含未充分测试的功能');
    }

    // Release body（如果有且不重复）
    if (release.body.isNotEmpty && release.body != release.commitMessage) {
      parts.add('\n${release.body}');
    }

    if (parts.isEmpty) {
      return const Text('是否立即下载并安装最新安装包？');
    }

    return Text(parts.join('\n'));
  }

  Future<void> _downloadAndInstall(AppReleaseInfo release) async {
    try {
      final apk = await _updateService.downloadApk(release);
      if (!mounted) return;
      await _updateService.installApk(apk);
    } catch (error, stackTrace) {
      devLog('下载或安装更新失败', error: error, stackTrace: stackTrace);
      if (mounted) _showToast('下载或安装失败，请稍后再试', error: true);
    }
  }

  void _showToast(String message, {bool error = false}) {
    try {
      final toast = context.read<ToastService>();
      if (error) {
        toast.showError(message);
      } else {
        toast.show(message);
      }
    } catch (error, stackTrace) {
      devLog('ToastService 不可用，更新提示已降级', error: error, stackTrace: stackTrace);
      // AboutPage 的旧测试未挂 ToastService，缺失时静默降级。
    }
  }
}

enum _UpdateDialogAction { install, later, ignore }

class _FeatureItem {
  final IconData icon;
  final IOS26IconTone tone;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.tone,
    required this.title,
    required this.description,
  });
}
