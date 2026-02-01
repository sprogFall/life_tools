import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models/tool_info.dart';
import '../core/services/settings_service.dart';
import '../core/theme/ios26_theme.dart';
import '../core/widgets/ios26_settings_row.dart';

class ToolManagementPage extends StatelessWidget {
  const ToolManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const IOS26AppBar(title: '工具管理', showBackButton: true),
            Expanded(
              child: Consumer<SettingsService>(
                builder: (context, settings, _) {
                  final tools = settings.getSortedTools();
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                        sliver: SliverToBoxAdapter(
                          child: _HintCard(
                            hiddenCount: settings.hiddenToolIds.length,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                        sliver: SliverToBoxAdapter(
                          child: _DefaultToolCard(tools: tools),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                        sliver: SliverToBoxAdapter(
                          child: _HomeVisibilityCard(tools: tools),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final int hiddenCount;

  const _HintCard({required this.hiddenCount});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.arrow_up_arrow_down,
            size: 18,
            color: IOS26Theme.primaryColor.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '首页长按工具卡片并拖拽可调整顺序。\n这里可设置启动默认进入工具，并选择是否在首页显示（已隐藏 $hiddenCount 个）。',
              style: IOS26Theme.bodySmall.copyWith(
                height: 1.35,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.95),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultToolCard extends StatelessWidget {
  final List<ToolInfo> tools;

  const _DefaultToolCard({required this.tools});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          const _CardHeader(title: '启动默认进入', subtitle: '设置后，下次打开应用将直接进入该工具'),
          const _Divider(),
          _DefaultToolRow(
            icon: CupertinoIcons.house,
            title: '首页',
            toolId: null,
          ),
          for (final tool in tools) ...[
            const _Divider(),
            _DefaultToolRow(icon: tool.icon, title: tool.name, toolId: tool.id),
          ],
        ],
      ),
    );
  }
}

class _DefaultToolRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? toolId;

  const _DefaultToolRow({
    required this.icon,
    required this.title,
    required this.toolId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        final selected = settings.defaultToolId == toolId;
        return IOS26SettingsRow(
          icon: icon,
          title: title,
          showChevron: false,
          trailing: SizedBox(
            width: 24,
            height: 24,
            child: selected
                ? const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: IOS26Theme.primaryColor,
                    size: 22,
                  )
                : const SizedBox.shrink(),
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            unawaited(settings.setDefaultTool(toolId));
          },
        );
      },
    );
  }
}

class _HomeVisibilityCard extends StatelessWidget {
  final List<ToolInfo> tools;

  const _HomeVisibilityCard({required this.tools});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          const _CardHeader(title: '首页显示', subtitle: '关闭后首页不显示该工具（不影响备份与默认进入）'),
          for (final tool in tools) ...[
            const _Divider(),
            _HomeVisibilityRow(tool: tool),
          ],
        ],
      ),
    );
  }
}

class _HomeVisibilityRow extends StatelessWidget {
  final ToolInfo tool;

  const _HomeVisibilityRow({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        final visible = !settings.isToolHidden(tool.id);
        return IOS26SettingsRow(
          icon: tool.icon,
          title: tool.name,
          showChevron: false,
          trailing: IgnorePointer(
            ignoring: true,
            child: CupertinoSwitch(
              value: visible,
              onChanged: (_) {},
              activeTrackColor: IOS26Theme.primaryColor,
            ),
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            unawaited(settings.setToolHidden(tool.id, visible));
          },
        );
      },
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _CardHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: IOS26Theme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: IOS26Theme.bodySmall.copyWith(
                    height: 1.25,
                    color: IOS26Theme.textSecondary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
    );
  }
}
