import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/registry/tool_registry.dart';
import '../../../core/tags/models/tag_with_tools.dart';
import '../../../core/tags/tag_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../pages/home_page.dart';
import 'tag_edit_page.dart';

class TagManagerToolPage extends StatefulWidget {
  final String? initialToolId;

  const TagManagerToolPage({super.key, this.initialToolId});

  @override
  State<TagManagerToolPage> createState() => _TagManagerToolPageState();
}

class _TagManagerToolPageState extends State<TagManagerToolPage> {
  String? _filterToolId;

  @override
  void initState() {
    super.initState();
    _filterToolId = widget.initialToolId == 'tag_manager'
        ? null
        : widget.initialToolId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TagService>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Consumer<TagService>(
                builder: (context, service, child) {
                  final allItems = service.allTags;
                  final items = _filterToolId == null
                      ? allItems
                      : allItems
                            .where((e) => e.toolIds.contains(_filterToolId))
                            .toList(growable: false);

                  return Column(
                    children: [
                      _FilterBar(
                        selectedToolId: _filterToolId,
                        onChanged: (toolId) => setState(() {
                          _filterToolId = toolId;
                        }),
                      ),
                      Expanded(
                        child: _TagList(
                          loading: service.loading,
                          allItems: allItems,
                          items: items,
                          enableReorder: _filterToolId == null,
                          onReorder: service.reorderTags,
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

  Widget _buildAppBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: IOS26Theme.glassColor,
            border: Border(
              bottom: BorderSide(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _navigateToHome(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.home,
                      color: IOS26Theme.primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '首页',
                      style: TextStyle(
                        fontSize: 17,
                        color: IOS26Theme.primaryColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Text(
                  '标签管理',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                    color: IOS26Theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _openCreate(context),
                child: const Icon(
                  CupertinoIcons.add,
                  color: IOS26Theme.primaryColor,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) =>
            TagEditPage(initialToolId: _filterToolId ?? widget.initialToolId),
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<TagService>().refreshAll();
    }
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? selectedToolId;
  final ValueChanged<String?> onChanged;

  const _FilterBar({required this.selectedToolId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tools = ToolRegistry.instance.tools
        .where((t) => t.id != 'tag_manager')
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _FilterChip(
                key: const ValueKey('tag-filter-all'),
                selected: selectedToolId == null,
                text: '全部',
                onTap: () => onChanged(null),
              ),
              for (final tool in tools) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  key: ValueKey('tag-filter-${tool.id}'),
                  selected: selectedToolId == tool.id,
                  text: tool.name,
                  onTap: () => onChanged(tool.id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? IOS26Theme.primaryColor.withValues(alpha: 0.14)
        : IOS26Theme.surfaceColor.withValues(alpha: 0.6);
    final fg = selected ? IOS26Theme.primaryColor : IOS26Theme.textSecondary;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(14),
      color: bg,
      onPressed: onTap,
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _TagList extends StatelessWidget {
  final bool loading;
  final List<TagWithTools> allItems;
  final List<TagWithTools> items;
  final bool enableReorder;
  final ValueChanged<List<int>> onReorder;

  const _TagList({
    required this.loading,
    required this.allItems,
    required this.items,
    required this.enableReorder,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && allItems.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (allItems.isEmpty) {
      return Center(
        child: Text(
          '暂无标签，点击右上角「+」新增',
          style: TextStyle(
            fontSize: 15,
            color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          '暂无符合筛选条件的标签',
          style: TextStyle(
            fontSize: 15,
            color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
          ),
        ),
      );
    }

    if (!enableReorder) {
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: items.length,
        itemBuilder: (_, index) => Padding(
          key: ValueKey(items[index].tag.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: _TagCard(tag: items[index]),
        ),
      );
    }

    return ReorderableListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final ids = items.map((e) => e.tag.id!).toList();
        final id = ids.removeAt(oldIndex);
        ids.insert(newIndex, id);
        onReorder(ids);
      },
      itemBuilder: (_, index) => Padding(
        key: ValueKey(items[index].tag.id),
        padding: const EdgeInsets.only(bottom: 10),
        child: _TagCard(tag: items[index]),
      ),
    );
  }
}

class _TagCard extends StatelessWidget {
  final TagWithTools tag;

  const _TagCard({required this.tag});

  @override
  Widget build(BuildContext context) {
    final toolNames = tag.toolIds
        .map((id) => ToolRegistry.instance.getById(id)?.name ?? id)
        .toList();
    final toolText = toolNames.join('、');

    return GlassContainer(
      key: ValueKey('tag-row-${tag.tag.id ?? tag.tag.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: Text(
              tag.tag.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: IOS26Theme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              toolText.isEmpty ? '未关联工具' : toolText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              _iconButton(
                icon: CupertinoIcons.pencil,
                onPressed: () => _openEdit(context),
              ),
              const SizedBox(width: 8),
              _iconButton(
                icon: CupertinoIcons.trash,
                color: IOS26Theme.toolRed,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _iconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = IOS26Theme.primaryColor,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onPressed: onPressed,
      color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(CupertinoPageRoute(builder: (_) => TagEditPage(editing: tag)));
    if (saved == true && context.mounted) {
      await context.read<TagService>().refreshAll();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认删除'),
        content: Text('确认删除标签「${tag.tag.name}」？\n已在任务中使用的该标签会自动移除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await context.read<TagService>().deleteTag(tag.tag.id!);
    }
  }
}
