import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../core/ai/ai_config_service.dart';
import '../core/models/tool_info.dart';
import '../core/services/settings_service.dart';
import '../core/sync/services/sync_config_service.dart';
import '../core/sync/pages/sync_settings_page.dart';
import '../core/theme/ios26_theme.dart';
import 'ai_settings_page.dart';

/// 首页欢迎页面，iOS 26 风格
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: Stack(
        children: [
          // 背景渐变装饰
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    IOS26Theme.primaryColor.withValues(alpha: 0.15),
                    IOS26Theme.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    IOS26Theme.toolPurple.withValues(alpha: 0.1),
                    IOS26Theme.toolPurple.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 主内容
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Consumer<SettingsService>(
                    builder: (context, settings, child) {
                      final tools = settings.getSortedTools();
                      return _buildContent(context, tools, settings);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '生活助手',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.37,
                  color: IOS26Theme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _showSettingsSheet(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: IOS26Theme.glassColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: IOS26Theme.glassBorderColor,
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.gear,
                    color: IOS26Theme.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<ToolInfo> tools,
    SettingsService settings,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 欢迎卡片
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        IOS26Theme.primaryColor,
                        IOS26Theme.primaryColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    CupertinoIcons.sparkles,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '欢迎回来',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '选择下方工具开始使用',
                        style: TextStyle(
                          fontSize: 15,
                          color: IOS26Theme.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // 工具标题
          const Text(
            '我的工具',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.35,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // 工具网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index];
              return _IOS26ToolCard(
                tool: tool,
                isDefault: tool.id == settings.defaultToolId,
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => tool.pageBuilder()),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const _SettingsSheet(),
    );
  }
}

/// iOS 26 风格工具卡片
class _IOS26ToolCard extends StatefulWidget {
  final ToolInfo tool;
  final bool isDefault;
  final VoidCallback onTap;

  const _IOS26ToolCard({
    required this.tool,
    required this.isDefault,
    required this.onTap,
  });

  @override
  State<_IOS26ToolCard> createState() => _IOS26ToolCardState();
}

class _IOS26ToolCardState extends State<_IOS26ToolCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.tool.color.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 背景渐变装饰
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.tool.color.withValues(alpha: 0.2),
                        widget.tool.color.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // 内容
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 图标
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.tool.color,
                            widget.tool.color.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.tool.color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.tool.icon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    // 名称
                    Text(
                      widget.tool.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.41,
                        color: IOS26Theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 描述
                    Text(
                      widget.tool.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: IOS26Theme.textSecondary.withValues(alpha: 0.8),
                        letterSpacing: -0.08,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 默认标记
              if (widget.isDefault)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: IOS26Theme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.star_fill,
                          color: Colors.white,
                          size: 10,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '默认',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

/// 设置底部弹出层
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: IOS26Theme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: IOS26Theme.textTertiary,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 20),
            // 标题
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: IOS26Theme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 默认工具设置
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: IOS26Theme.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Consumer2<SettingsService, AiConfigService>(
                  builder: (context, settings, aiConfig, _) {
                    final tools = settings.getSortedTools();
                    final aiValue =
                        aiConfig.isConfigured ? aiConfig.config!.model : '未配置';

                    return Column(
                      children: [
                        _SettingsItem(
                          icon: CupertinoIcons.app,
                          title: '默认打开工具',
                          value: settings.defaultToolId == null
                              ? '首页'
                              : tools
                                      .where(
                                          (t) => t.id == settings.defaultToolId)
                                      .firstOrNull
                                      ?.name ??
                                  '首页',
                          onTap: () =>
                              _showToolPicker(context, settings, tools),
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color:
                              IOS26Theme.textTertiary.withValues(alpha: 0.25),
                        ),
                        _SettingsItem(
                          icon: CupertinoIcons.sparkles,
                          title: 'AI配置',
                          value: aiValue,
                          onTap: () => _openAiSettings(context),
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color:
                              IOS26Theme.textTertiary.withValues(alpha: 0.25),
                        ),
                        Consumer<SyncConfigService>(
                          builder: (context, syncConfig, _) {
                            return _SettingsItem(
                              icon: CupertinoIcons.cloud_upload,
                              title: '数据同步',
                              value: syncConfig.isConfigured ? '已配置' : '未配置',
                              onTap: () => _openSyncSettings(context),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 提示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '设置默认工具后，下次打开应用将直接进入该工具',
                style: TextStyle(
                  fontSize: 13,
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showToolPicker(
    BuildContext context,
    SettingsService settings,
    List<ToolInfo> tools,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择默认工具'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              settings.setDefaultTool(null);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (settings.defaultToolId == null)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: IOS26Theme.primaryColor,
                      size: 20,
                    ),
                  ),
                const Text('首页'),
              ],
            ),
          ),
          ...tools.map(
            (tool) => CupertinoActionSheetAction(
              onPressed: () {
                settings.setDefaultTool(tool.id);
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (settings.defaultToolId == tool.id)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: IOS26Theme.primaryColor,
                        size: 20,
                      ),
                    ),
                  Text(tool.name),
                ],
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _openAiSettings(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future<void>.microtask(() {
      navigator.push(
        CupertinoPageRoute<void>(builder: (_) => const AiSettingsPage()),
      );
    });
  }

  void _openSyncSettings(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future<void>.microtask(() {
      navigator.push(
        CupertinoPageRoute<void>(builder: (_) => const SyncSettingsPage()),
      );
    });
  }
}

/// 设置项组件
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IOS26Theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: IOS26Theme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: IOS26Theme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              CupertinoIcons.chevron_right,
              color: IOS26Theme.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
