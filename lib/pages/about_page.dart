import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../core/app_build_info.dart';
import '../core/theme/ios26_theme.dart';
import '../core/ui/app_scaffold.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const Duration _messageDismissDelay = Duration(seconds: 3);

  Timer? _dismissTimer;
  bool _showCommitMessage = false;

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
      title: '过家家厨房',
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
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
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
}

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
