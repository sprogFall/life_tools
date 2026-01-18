import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/tool_info.dart';
import '../../../core/registry/tool_registry.dart';
import '../../../core/tags/models/tag_with_tools.dart';
import '../../../core/tags/tag_service.dart';
import '../../../core/theme/ios26_theme.dart';

class TagEditPage extends StatefulWidget {
  final TagWithTools? editing;
  final String? initialToolId;

  const TagEditPage({super.key, this.editing, this.initialToolId});

  @override
  State<TagEditPage> createState() => _TagEditPageState();
}

class _TagEditPageState extends State<TagEditPage> {
  final _nameController = TextEditingController();
  late List<String> _selectedToolIds;

  bool get _isEdit => widget.editing != null;

  List<ToolInfo> get _tools => ToolRegistry.instance.tools
      .where((t) => t.id != 'tag_manager')
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _nameController.text = editing.tag.name;
      _selectedToolIds = [...editing.toolIds];
    } else {
      _selectedToolIds = widget.initialToolId == null
          ? <String>[]
          : [widget.initialToolId!];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildNameCard(),
                    const SizedBox(height: 16),
                    _buildToolsCard(),
                  ],
                ),
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
                onPressed: () => Navigator.pop(context, false),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: IOS26Theme.primaryColor,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  _isEdit ? '编辑标签' : '新增标签',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                    color: IOS26Theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onPressed: () => _save(context),
                child: const Text(
                  '保存',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: IOS26Theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '标签名',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '例如：紧急 / 例行 / 复盘',
              hintStyle: const TextStyle(
                fontSize: 15,
                color: IOS26Theme.textSecondary,
              ),
              filled: true,
              fillColor: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '关联工具',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ..._tools.map(_toolRow),
        ],
      ),
    );
  }

  Widget _toolRow(ToolInfo tool) {
    final selected = _selectedToolIds.contains(tool.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tool.name,
              style: const TextStyle(
                fontSize: 15,
                color: IOS26Theme.textPrimary,
              ),
            ),
          ),
          CupertinoSwitch(
            value: selected,
            onChanged: (v) {
              setState(() {
                if (v) {
                  _selectedToolIds = {..._selectedToolIds, tool.id}.toList();
                } else {
                  _selectedToolIds = _selectedToolIds
                      .where((e) => e != tool.id)
                      .toList();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await _showMessage('提示', '请填写标签名');
      return;
    }
    if (_selectedToolIds.isEmpty) {
      await _showMessage('提示', '请至少选择 1 个关联工具');
      return;
    }

    final service = context.read<TagService>();
    final navigator = Navigator.of(context);

    try {
      if (_isEdit) {
        await service.updateTag(
          tagId: widget.editing!.tag.id!,
          name: name,
          toolIds: _selectedToolIds,
        );
      } else {
        await service.createTag(name: name, toolIds: _selectedToolIds);
      }
    } catch (e) {
      await _showMessage('保存失败', e.toString());
      return;
    }

    if (!mounted) return;
    navigator.pop(true);
  }

  Future<void> _showMessage(String title, String content) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
