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
  @override
  void initState() {
    super.initState();
    context.read<TagService>().refreshAll();
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
                  if (service.loading && service.allTags.isEmpty) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  final items = service.allTags;
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无标签，点击右上角「+」新增',
                        style: TextStyle(
                          fontSize: 15,
                          color: IOS26Theme.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _TagCard(tag: items[index]),
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
        builder: (_) => TagEditPage(initialToolId: widget.initialToolId),
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

class _TagCard extends StatelessWidget {
  final TagWithTools tag;

  const _TagCard({required this.tag});

  @override
  Widget build(BuildContext context) {
    final toolNames = tag.toolIds
        .map((id) => ToolRegistry.instance.getById(id)?.name ?? id)
        .toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.tag.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: IOS26Theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: toolNames.map(_chip).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              _iconButton(
                icon: CupertinoIcons.pencil,
                onPressed: () => _openEdit(context),
              ),
              const SizedBox(height: 10),
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

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: IOS26Theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: IOS26Theme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Widget _iconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = IOS26Theme.primaryColor,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
