import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/registry/tool_registry.dart';
import '../../../core/tags/models/tag_in_tool_category.dart';
import '../../../core/tags/models/tag_with_tools.dart';
import '../../../core/tags/models/tag_category.dart';
import '../../../core/tags/tag_repository.dart';
import '../../../core/tags/tag_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../pages/home_page.dart';
import 'tag_rename_page.dart';

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
    final initial = widget.initialToolId?.trim();
    final tools = ToolRegistry.instance.tools
        .where((t) => t.id != 'tag_manager')
        .toList(growable: false);
    final firstToolId = tools.isEmpty ? null : tools.first.id;
    if (initial == null || initial.isEmpty || initial == 'tag_manager') {
      _filterToolId = firstToolId;
    } else if (tools.any((t) => t.id == initial)) {
      _filterToolId = initial;
    } else {
      _filterToolId = firstToolId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = context.read<TagService>();
      if (!service.loading && service.allTags.isEmpty) {
        service.refreshAll();
      }
      final toolId = _filterToolId;
      if (toolId != null) {
        if (!service.toolLoading(toolId) &&
            service.tagsForToolWithCategory(toolId).isEmpty) {
          service.refreshToolTags(toolId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            IOS26AppBar(
              title: '标签管理',
              leading: CupertinoButton(
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
              actions: [
                // 新增标签统一走「按工具 -> 分类」的入口，避免“全部”页继续走旧新增流程
              ],
            ),
            Expanded(
              child: Consumer<TagService>(
                builder: (context, service, child) {
                  final allItems = service.allTags;
                  final toolId = _filterToolId;

                  return Column(
                    children: [
                      _FilterBar(
                        selectedToolId: _filterToolId,
                        onChanged: (toolId) {
                          setState(() => _filterToolId = toolId);
                          if (toolId != null && toolId.trim().isNotEmpty) {
                            if (!service.toolLoading(toolId) &&
                                service
                                    .tagsForToolWithCategory(toolId)
                                    .isEmpty) {
                              service.refreshToolTags(toolId);
                            }
                          }
                        },
                      ),
                      Expanded(
                        child: toolId == null
                            ? Center(
                                child: Text(
                                  '暂无可用工具',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: IOS26Theme.textSecondary.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                ),
                              )
                            : _ToolCategoryList(toolId: toolId, allItems: allItems),
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
              for (int i = 0; i < tools.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _FilterChip(
                  key: ValueKey('tag-filter-${tools[i].id}'),
                  selected: selectedToolId == tools[i].id,
                  text: tools[i].name,
                  onTap: () => onChanged(tools[i].id),
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

class _ToolCategoryList extends StatefulWidget {
  final String toolId;
  final List<TagWithTools> allItems;

  const _ToolCategoryList({required this.toolId, required this.allItems});

  @override
  State<_ToolCategoryList> createState() => _ToolCategoryListState();
}

class _ToolCategoryListState extends State<_ToolCategoryList> {
  final Map<String, bool> _expandedByCategoryId = {};
  final Set<String> _managingCategoryIds = {};

  @override
  void didUpdateWidget(covariant _ToolCategoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.toolId != widget.toolId) {
      _expandedByCategoryId.clear();
      _managingCategoryIds.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<TagService>();
    final loading = service.toolLoading(widget.toolId);
    final items = service.tagsForToolWithCategory(widget.toolId);

    final byTagId = <int, TagWithTools>{
      for (final item in widget.allItems)
        if (item.tag.id != null) item.tag.id!: item,
    };

    final registered = service.categoriesForTool(widget.toolId);
    final classificationEnabled = registered.length > 1;
    final categories = _buildCategories(registered, items);
    final tagsByCategory = <String, List<TagInToolCategory>>{};
    for (final item in items) {
      final key = classificationEnabled
          ? item.categoryId
          : TagRepository.defaultCategoryId;
      tagsByCategory.putIfAbsent(key, () => []).add(item);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          if (loading) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: CupertinoActivityIndicator(radius: 12),
            ),
          ],
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryId = category.id;
                final categoryItems =
                    tagsByCategory[categoryId] ?? const <TagInToolCategory>[];
                final expanded = _expandedByCategoryId[categoryId] ?? true;
                final managing = _managingCategoryIds.contains(categoryId);

                return GlassContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _CategoryHeader(
                        title: category.name,
                        count: categoryItems.length,
                        expanded: expanded,
                        onToggleExpanded: () => setState(() {
                          _expandedByCategoryId[categoryId] = !expanded;
                          if (expanded) _managingCategoryIds.remove(categoryId);
                        }),
                        onAdd: () => _openCreateTag(
                          context,
                          toolId: widget.toolId,
                          categoryId: categoryId,
                          categoryName: category.name,
                          categoryCreateHint: category.createHint,
                        ),
                        onManage: () => setState(() {
                          if (managing) {
                            _managingCategoryIds.remove(categoryId);
                          } else {
                            _managingCategoryIds.add(categoryId);
                            _expandedByCategoryId[categoryId] = true;
                          }
                        }),
                        addKey: ValueKey(
                          'tag-category-add-${widget.toolId}-$categoryId',
                        ),
                        manageKey: ValueKey(
                          'tag-category-manage-${widget.toolId}-$categoryId',
                        ),
                        managing: managing,
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 12),
                        if (categoryItems.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '暂无标签',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: IOS26Theme.textSecondary.withValues(
                                  alpha: 0.95,
                                ),
                              ),
                            ),
                          )
                        else if (managing)
                          _TagReorderList(
                            toolId: widget.toolId,
                            categoryId: categoryId,
                            items: categoryItems,
                            onTap: (tagId, tagName) => _openRename(
                              context,
                              toolId: widget.toolId,
                              tagId: tagId,
                              initialName: tagName,
                            ),
                            onRemove: (tagId, tagName) => _confirmDelete(
                              context,
                              toolId: widget.toolId,
                              tagId: tagId,
                              tagName: tagName,
                              tools: byTagId[tagId],
                            ),
                          )
                        else
                          _TagChipsWrap(
                            items: categoryItems,
                            managing: false,
                            onTap: (tagId, tagName) => _openRename(
                              context,
                              toolId: widget.toolId,
                              tagId: tagId,
                              initialName: tagName,
                            ),
                            onRemove: null,
                            removeKeyOf: null,
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_CategoryView> _buildCategories(
    List<TagCategory> registered,
    List<TagInToolCategory> items,
  ) {
    if (registered.length == 1 &&
        registered.first.id == TagRepository.defaultCategoryId) {
      return const [
        _CategoryView(id: TagRepository.defaultCategoryId, name: '默认'),
      ];
    }

    final seen = <String>{for (final c in registered) c.id};

    final extra = <_CategoryView>[];
    for (final item in items) {
      final id = item.categoryId.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      extra.add(_CategoryView(id: id, name: id));
    }

    return [
      for (final c in registered)
        _CategoryView(id: c.id, name: c.name, createHint: c.createHint),
      ...extra,
    ];
  }

  Future<void> _openCreateTag(
    BuildContext context, {
    required String toolId,
    required String categoryId,
    required String categoryName,
    required String? categoryCreateHint,
  }) async {
    final controller = TextEditingController();
    String? error;
    final hint = (categoryCreateHint == null || categoryCreateHint.trim().isEmpty)
        ? '${categoryName.trim()}标签'
        : categoryCreateHint.trim();

    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => CupertinoAlertDialog(
          title: Text('添加到「$categoryName」'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('标签名')),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: controller,
                placeholder: '如：$hint',
                autofocus: true,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: IOS26Theme.toolRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setState(() => error = '请填写标签名');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;

    await context.read<TagService>().createTagForToolCategory(
      toolId: toolId,
      categoryId: categoryId,
      name: controller.text.trim(),
    );
  }

  Future<void> _openRename(
    BuildContext context, {
    required String toolId,
    required int tagId,
    required String initialName,
  }) async {
    final service = context.read<TagService>();
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => TagRenamePage(tagId: tagId, initialName: initialName),
      ),
    );
    if (saved == true && mounted) {
      await service.refreshAll();
      if (!mounted) return;
      await service.refreshToolTags(toolId);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required String toolId,
    required int tagId,
    required String tagName,
    required TagWithTools? tools,
  }) async {
    final service = context.read<TagService>();
    final toolNames = tools?.toolIds
        .map((id) => ToolRegistry.instance.getById(id)?.name ?? id)
        .toList(growable: false);
    final related = (toolNames == null || toolNames.isEmpty)
        ? ''
        : '\n同时关联到：${toolNames.join('、')}';

    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('确认删除'),
        content: Text('确认删除标签「$tagName」？$related\n已在任务中使用的该标签会自动移除。'),
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

    if (ok == true && mounted) {
      await service.deleteTag(tagId);
      if (!mounted) return;
      await service.refreshToolTags(toolId);
    }
  }
}

class _CategoryView {
  final String id;
  final String name;
  final String? createHint;

  const _CategoryView({required this.id, required this.name, this.createHint});
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onAdd;
  final VoidCallback onManage;
  final bool managing;
  final Key addKey;
  final Key manageKey;

  const _CategoryHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onAdd,
    required this.onManage,
    required this.managing,
    required this.addKey,
    required this.manageKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            pressedOpacity: 0.7,
            onPressed: onToggleExpanded,
            child: Row(
              children: [
                Icon(
                  expanded
                      ? CupertinoIcons.chevron_down
                      : CupertinoIcons.chevron_right,
                  size: 18,
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: IOS26Theme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IOS26Theme.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _iconButton(
          key: addKey,
          icon: CupertinoIcons.add,
          color: IOS26Theme.primaryColor,
          onPressed: onAdd,
        ),
        const SizedBox(width: 8),
        _iconButton(
          key: manageKey,
          icon: managing
              ? CupertinoIcons.checkmark
              : CupertinoIcons.slider_horizontal_3,
          color: managing ? IOS26Theme.toolGreen : IOS26Theme.textSecondary,
          onPressed: onManage,
        ),
      ],
    );
  }

  static Widget _iconButton({
    Key? key,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return CupertinoButton(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: onPressed,
      color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _TagReorderList extends StatelessWidget {
  final String toolId;
  final String categoryId;
  final List<TagInToolCategory> items;
  final void Function(int tagId, String tagName) onTap;
  final void Function(int tagId, String tagName) onRemove;

  const _TagReorderList({
    required this.toolId,
    required this.categoryId,
    required this.items,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<TagService>();
    final reorderable = items.where((e) => e.tag.id != null).toList();

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: reorderable.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final ids = reorderable.map((e) => e.tag.id!).toList();
        final id = ids.removeAt(oldIndex);
        ids.insert(newIndex, id);
        service.reorderToolCategoryTags(
          toolId: toolId,
          categoryId: categoryId,
          tagIds: ids,
        );
      },
      itemBuilder: (context, index) {
        final item = reorderable[index];
        final id = item.tag.id!;
        return Padding(
          key: ValueKey('tag-sort-$toolId-$categoryId-$id'),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              ReorderableDelayedDragStartListener(
                index: index,
                child: Icon(
                  CupertinoIcons.line_horizontal_3,
                  size: 18,
                  color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  pressedOpacity: 0.7,
                  onPressed: () => onTap(id, item.tag.name),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.tag.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IOS26Theme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                key: ValueKey('tag-remove-$toolId-$categoryId-$id'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onPressed: () => onRemove(id, item.tag.name),
                color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                child: const Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: IOS26Theme.toolRed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TagChipsWrap extends StatelessWidget {
  final List<TagInToolCategory> items;
  final bool managing;
  final void Function(int tagId, String tagName) onTap;
  final void Function(int tagId, String tagName)? onRemove;
  final Key? Function(int tagId)? removeKeyOf;

  const _TagChipsWrap({
    required this.items,
    required this.managing,
    required this.onTap,
    required this.onRemove,
    required this.removeKeyOf,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            if (item.tag.id != null)
              _TagChip(
                key: ValueKey('tag-item-${item.tag.id!}'),
                name: item.tag.name,
                onTap: () => onTap(item.tag.id!, item.tag.name),
                showRemove: managing,
                onRemove: managing && onRemove != null
                    ? () => onRemove!(item.tag.id!, item.tag.name)
                    : null,
                removeKey: managing ? removeKeyOf?.call(item.tag.id!) : null,
              ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  final bool showRemove;
  final VoidCallback? onRemove;
  final Key? removeKey;

  const _TagChip({
    super.key,
    required this.name,
    required this.onTap,
    required this.showRemove,
    required this.onRemove,
    required this.removeKey,
  });

  @override
  Widget build(BuildContext context) {
    final bg = IOS26Theme.surfaceColor.withValues(alpha: 0.65);
    final border = IOS26Theme.textTertiary.withValues(alpha: 0.35);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(44, 44),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            if (showRemove) ...[
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border, width: 1),
                ),
                child: CupertinoButton(
                  key: removeKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  onPressed: onRemove,
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 14,
                    color: IOS26Theme.toolRed,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
