import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:life_tools/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/models/tool_info.dart';
import '../core/models/tool_info_l10n.dart';
import '../core/services/settings_service.dart';
import '../core/theme/ios26_theme.dart';
import '../core/ui/app_scaffold.dart';
import '../core/widgets/ios26_settings_row.dart';

class ToolManagementPage extends StatelessWidget {
  const ToolManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(title: l10n.tool_management_title, showBackButton: true),
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
    );
  }
}

class _HintCard extends StatelessWidget {
  final int hiddenCount;

  const _HintCard({required this.hiddenCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.tool_management_hint_content(hiddenCount),
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
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          _CardHeader(
            title: l10n.tool_management_default_tool_title,
            subtitle: l10n.tool_management_default_tool_subtitle,
          ),
          const _Divider(),
          _DefaultToolRow(
            icon: CupertinoIcons.house,
            title: l10n.common_home,
            toolId: null,
          ),
          for (final tool in tools) ...[
            const _Divider(),
            _DefaultToolRow(
              icon: tool.icon,
              title: tool.displayName(l10n),
              toolId: tool.id,
            ),
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
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          _CardHeader(
            title: l10n.tool_management_home_visibility_title,
            subtitle: l10n.tool_management_home_visibility_subtitle,
          ),
          for (final tool in tools) ...[
            const _Divider(),
            _HomeVisibilityRow(title: tool.displayName(l10n), tool: tool),
          ],
        ],
      ),
    );
  }
}

class _HomeVisibilityRow extends StatelessWidget {
  final String title;
  final ToolInfo tool;

  const _HomeVisibilityRow({required this.title, required this.tool});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        final visible = !settings.isToolHidden(tool.id);
        return IOS26SettingsRow(
          icon: tool.icon,
          title: title,
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
