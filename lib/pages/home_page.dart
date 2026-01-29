import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../core/messages/message_service.dart';
import '../core/messages/pages/all_messages_page.dart';
import '../core/messages/message_navigation.dart';
import '../core/messages/models/app_message.dart';
import '../core/backup/pages/backup_restore_page.dart';
import '../core/ai/ai_config_service.dart';
import '../core/models/tool_info.dart';
import '../core/obj_store/obj_store_config.dart';
import '../core/obj_store/obj_store_config_service.dart';
import '../core/services/settings_service.dart';
import '../core/sync/services/sync_config_service.dart';
import '../core/sync/pages/sync_settings_page.dart';
import '../core/theme/ios26_theme.dart';
import '../core/widgets/ios26_settings_row.dart';
import 'ai_settings_page.dart';
import 'obj_store_settings_page.dart';
import 'tool_management_page.dart';

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
                IOS26AppBar.home(
                  title: '小蜜',
                  onSettingsPressed: () => _showSettingsSheet(context),
                ),
                Expanded(
                  child: Consumer2<SettingsService, MessageService>(
                    builder: (context, settings, messageService, child) {
                      final tools = settings.getHomeTools();
                      return _buildContent(
                        context,
                        tools,
                        settings,
                        messageService,
                      );
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

  Widget _buildContent(
    BuildContext context,
    List<ToolInfo> tools,
    SettingsService settings,
    MessageService messageService,
  ) {
    final allMessages = messageService.messages;
    final unreadMessages = messageService.unreadMessages;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '消息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: IOS26Theme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: allMessages.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => const AllMessagesPage(),
                                ),
                              );
                            },
                      child: Text(
                        '全部消息',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: allMessages.isEmpty
                              ? IOS26Theme.textTertiary
                              : IOS26Theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (unreadMessages.isEmpty)
                  Text(
                    '当前暂时没有新的消息',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: IOS26Theme.textSecondary.withValues(alpha: 0.75),
                    ),
                  )
                else
                  _HomeMessageTickerList(
                    messages: unreadMessages,
                    visibleCount: 3,
                    onTap: (message) async {
                      final id = message.id;
                      if (id != null && !message.isRead) {
                        await messageService.markMessageRead(id);
                      }
                      if (!context.mounted) return;
                      MessageNavigation.open(context, message);
                    },
                  ),
                const SizedBox(height: 12),
                Text(
                  unreadMessages.isEmpty
                      ? '共 ${allMessages.length} 条消息'
                      : '未读 ${unreadMessages.length} / 共 ${allMessages.length} 条',
                  style: TextStyle(
                    fontSize: 12,
                    color: IOS26Theme.textSecondary.withValues(alpha: 0.75),
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
          if (tools.isEmpty)
            Text(
              '暂无可显示的工具，请到「工具管理」中开启',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
              ),
            )
          else
            ReorderableGridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: tools.length,
            dragStartDelay: const Duration(milliseconds: 250),
            dragWidgetBuilderV2: DragWidgetBuilderV2(
              builder: (index, child, screenshot) {
                return Transform.scale(
                  scale: 1.03,
                  child: Material(
                    type: MaterialType.transparency,
                    elevation: 10,
                    shadowColor: Colors.black.withValues(alpha: 0.22),
                    child: Opacity(opacity: 0.98, child: child),
                  ),
                );
              },
            ),
            onReorder: (oldIndex, newIndex) {
              if (oldIndex == newIndex) return;
              HapticFeedback.selectionClick();

              final ids = tools.map((t) => t.id).toList(growable: true);
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              unawaited(settings.updateHomeToolOrder(ids));
            },
            itemBuilder: (context, index) {
              final tool = tools[index];
              return _IOS26ToolCard(
                key: ValueKey('home_tool_${tool.id}'),
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

class _HomeMessageTickerList extends StatefulWidget {
  final List<AppMessage> messages;
  final int visibleCount;
  final ValueChanged<AppMessage> onTap;

  const _HomeMessageTickerList({
    required this.messages,
    required this.visibleCount,
    required this.onTap,
  });

  @override
  State<_HomeMessageTickerList> createState() => _HomeMessageTickerListState();
}

class _HomeMessageTickerListState extends State<_HomeMessageTickerList> {
  static const Duration _interval = Duration(seconds: 3);
  static const Duration _animDuration = Duration(milliseconds: 350);
  static const double _itemHeight = 24;

  final ScrollController _controller = ScrollController();
  Timer? _timer;
  int _scrollIndex = 0;

  @override
  void initState() {
    super.initState();
    _restartTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _HomeMessageTickerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length != widget.messages.length) {
      _scrollIndex = 0;
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
    }
    _restartTimerIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimerIfNeeded() {
    _timer?.cancel();
    final visible = _effectiveVisibleCount();
    if (widget.messages.length <= visible) return;
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  int _effectiveVisibleCount() {
    if (widget.visibleCount <= 0) return 1;
    if (widget.messages.isEmpty) return 1;
    return widget.visibleCount.clamp(1, widget.messages.length);
  }

  Future<void> _tick() async {
    if (!mounted) return;
    if (!_controller.hasClients) return;

    final count = widget.messages.length;
    if (count == 0) return;

    final next = _scrollIndex + 1;
    final shouldWrap = next >= count;
    _scrollIndex = next;

    await _controller.animateTo(
      next * _itemHeight,
      duration: _animDuration,
      curve: Curves.easeOutCubic,
    );

    if (!mounted) return;
    if (shouldWrap && _controller.hasClients) {
      _controller.jumpTo(0);
      _scrollIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    if (messages.isEmpty) return const SizedBox.shrink();

    final visible = _effectiveVisibleCount();
    final itemCount = messages.length + visible;

    return SizedBox(
      height: _itemHeight * visible,
      child: ListView.builder(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemExtent: _itemHeight,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final message = messages[index % messages.length];
          return CupertinoButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            onPressed: () => widget.onTap(message),
            child: Text(
              message.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.15,
                color: IOS26Theme.textPrimary,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// iOS 26 风格工具卡片
class _IOS26ToolCard extends StatefulWidget {
  final ToolInfo tool;
  final bool isDefault;
  final VoidCallback onTap;

  const _IOS26ToolCard({
    super.key,
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
  static const double _cardRadius = 24;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
    final cardBorderRadius = BorderRadius.circular(_cardRadius);
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnimation.value, child: child),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: cardBorderRadius,
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
          child: ClipRRect(
            key: ValueKey('ios26_tool_card_clip_${widget.tool.id}'),
            borderRadius: cardBorderRadius,
            clipBehavior: Clip.antiAlias,
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
                          color: IOS26Theme.textSecondary.withValues(
                            alpha: 0.8,
                          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                    final aiValue = aiConfig.isConfigured
                        ? aiConfig.config!.model
                        : '未配置';

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IOS26SettingsRow(
                          icon: CupertinoIcons.app,
                          title: '工具管理',
                          value: settings.defaultToolId == null
                              ? '默认：首页'
                              : '默认：${tools
                                        .where((t) => t.id == settings.defaultToolId)
                                        .firstOrNull
                                        ?.name ?? '首页'}',
                          onTap: () => _openToolManagement(context),
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: IOS26Theme.textTertiary.withValues(
                            alpha: 0.25,
                          ),
                        ),
                        IOS26SettingsRow(
                          icon: CupertinoIcons.sparkles,
                          title: 'AI配置',
                          value: aiValue,
                          onTap: () => _openAiSettings(context),
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: IOS26Theme.textTertiary.withValues(
                            alpha: 0.25,
                          ),
                        ),
                        Consumer<SyncConfigService>(
                          builder: (context, syncConfig, _) {
                            return IOS26SettingsRow(
                              icon: CupertinoIcons.cloud_upload,
                              title: '数据同步',
                              value: syncConfig.isConfigured ? '已配置' : '未配置',
                              onTap: () => _openSyncSettings(context),
                            );
                          },
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: IOS26Theme.textTertiary.withValues(
                            alpha: 0.25,
                          ),
                        ),
                        Consumer<ObjStoreConfigService>(
                          builder: (context, objStore, _) {
                            final isQiniuPrivate =
                                objStore.config?.qiniuIsPrivate ?? false;
                            final isDataCapsulePrivate =
                                objStore.config?.dataCapsuleIsPrivate ?? true;
                            final value = switch (objStore.selectedType) {
                              ObjStoreType.none => '未选择',
                              ObjStoreType.local =>
                                objStore.isConfigured ? '本地存储' : '未配置',
                              ObjStoreType.qiniu =>
                                objStore.isConfigured
                                    ? (isQiniuPrivate ? '七牛云(私有)' : '七牛云(公有)')
                                    : '未配置',
                              ObjStoreType.dataCapsule =>
                                objStore.isConfigured
                                    ? (isDataCapsulePrivate
                                          ? '数据胶囊(私有)'
                                          : '数据胶囊(公有)')
                                    : '未配置',
                            };
                            return IOS26SettingsRow(
                              icon: CupertinoIcons.photo_on_rectangle,
                              title: '资源存储',
                              value: value,
                              onTap: () => _openObjStoreSettings(context),
                            );
                          },
                        ),
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: IOS26Theme.textTertiary.withValues(
                            alpha: 0.25,
                          ),
                        ),
                        IOS26SettingsRow(
                          icon: CupertinoIcons.archivebox,
                          title: '备份与还原',
                          value: '导入/导出',
                          onTap: () => _openBackupRestore(context),
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
                '在工具管理中设置默认进入工具与首页显示；首页长按工具可拖拽排序',
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

  void _openToolManagement(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future<void>.microtask(() {
      navigator.push(
        CupertinoPageRoute<void>(builder: (_) => const ToolManagementPage()),
      );
    });
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

  void _openBackupRestore(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future<void>.microtask(() {
      navigator.push(
        CupertinoPageRoute<void>(builder: (_) => const BackupRestorePage()),
      );
    });
  }

  void _openObjStoreSettings(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future<void>.microtask(() {
      navigator.push(
        CupertinoPageRoute<void>(builder: (_) => const ObjStoreSettingsPage()),
      );
    });
  }
}
