import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../core/tag/services/tag_service.dart';
import '../../../core/tag/models/tag_model.dart';
import '../../../core/registry/tool_registry.dart';
import '../../../core/models/tool_info.dart';
import '../../../core/theme/ios26_theme.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  late TagService _tagService;
  List<Tag> _allTags = [];
  List<Tag> _filteredTags = [];
  Map<int, List<String>> _tagToolMap = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tagService = TagService();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      final tags = await _tagService.listAllTags();
      final toolMap = <int, List<String>>{};
      
      for (final tag in tags) {
        if (tag.id != null) {
          final tools = await _tagService.getToolIdsForTag(tag.id!);
          toolMap[tag.id!] = tools;
        }
      }
      
      setState(() {
        _allTags = tags;
        _tagToolMap = toolMap;
        _filteredTags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载标签失败: $e')),
        );
      }
    }
  }

  void _filterTags(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTags = _allTags;
      } else {
        _filteredTags = _allTags.where((tag) {
          return tag.name.toLowerCase().contains(query.toLowerCase()) ||
                 tag.description.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showCreateTagDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => const CreateTagDialog(),
    );
  }

  void _showEditTagDialog(Tag tag) {
    showCupertinoDialog(
      context: context,
      builder: (context) => EditTagDialog(tag: tag, tagService: _tagService),
    );
  }

  Future<void> _deleteTag(Tag tag) async {
    if (tag.id == null) return;
    
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除标签'),
        content: Text('确定要删除标签"${tag.name}"吗？\n\n删除后所有关联数据将被解除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            isDestructiveAction: true,
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _tagService.deleteTag(tag.id!);
        _loadTags();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _addTagToTool(Tag tag) async {
    final availableTools = ToolRegistry.instance.tools;
    final currentToolIds = _tagToolMap[tag.id!] ?? [];
    final unassociatedTools = availableTools
      .where((tool) => !currentToolIds.contains(tool.id))
      .toList();

    if (unassociatedTools.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该标签已关联所有工具')),
        );
      }
      return;
    }

    final selectedToolId = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('关联"${tag.name}"到工具'),
        content: SizedBox(
          height: 200,
          child: CupertinoPicker(
            itemExtent: 32,
            onSelectedItemChanged: (index) {
              // 处理选择
            },
            children: unassociatedTools.map((tool) => Text(tool.name)).toList(),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(unassociatedTools.first.id),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (selectedToolId != null) {
      try {
        await _tagService.addTagToTool(tag.id!, selectedToolId);
        _loadTags();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('关联失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: IOS26Theme.backgroundColor.withValues(alpha: 0.8),
        border: null,
        middle: const Text('标签管理'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showCreateTagDialog,
          child: const Icon(CupertinoIcons.add, color: IOS26Theme.primaryColor),
        ),
      ),
      body: _isLoading
        ? const Center(child: CupertinoActivityIndicator())
        : Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _filteredTags.isEmpty
                  ? _buildEmptyState()
                  : _buildTagList(),
              ),
            ],
          ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IOS26Theme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: IOS26Theme.textTertiary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: CupertinoSearchTextField(
        placeholder: '搜索标签',
        onChanged: _filterTags,
      ),
    );
  }

  Widget _buildTagList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTags.length,
      itemBuilder: (context, index) {
        final tag = _filteredTags[index];
        final toolIds = _tagToolMap[tag.id!] ?? [];
        final toolNames = toolIds
          .map((id) => ToolRegistry.instance.getById(id)?.name ?? id)
          .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: IOS26Theme.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(tag.color),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            title: Text(
              tag.name,
              style: TextStyle(
                color: IOS26Theme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag.description.isNotEmpty)
                  Text(
                    tag.description,
                    style: TextStyle(color: IOS26Theme.textSecondary, fontSize: 14),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: toolNames.map((toolName) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: IOS26Theme.textTertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        toolName,
                        style: TextStyle(
                          color: IOS26Theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _addTagToTool(tag),
                  child: Icon(CupertinoIcons.link, color: IOS26Theme.primaryColor),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showEditTagDialog(tag),
                  child: Icon(CupertinoIcons.pencil, color: IOS26Theme.textSecondary),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _deleteTag(tag),
                  child: Icon(CupertinoIcons.trash, color: IOS26Theme.toolRed),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.tag,
            size: 64,
            color: IOS26Theme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '暂无标签' : '未找到匹配的标签',
            style: TextStyle(
              color: IOS26Theme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
              ? '点击右上角添加第一个标签'
              : '尝试其他搜索关键词',
            style: TextStyle(
              color: IOS26Theme.textTertiary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class CreateTagDialog extends StatefulWidget {
  const CreateTagDialog({super.key});

  @override
  State<CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<CreateTagDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  Color _selectedColor = IOS26Theme.toolBlue;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTag() async {
    if (!_formKey.currentState!.validate()) return;

    final tagService = TagService();
    final toolRegistry = ToolRegistry.instance;
    final availableTools = toolRegistry.tools;

    if (availableTools.isEmpty) {
      return;
    }

    // 显示工具选择对话框
    final selectedToolIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => ToolSelectionDialog(tools: availableTools),
    );

    if (selectedToolIds == null || selectedToolIds.isEmpty) {
      return;
    }

    try {
      // 创建标签
      final tag = await tagService.createTagForTool(
        toolId: selectedToolIds.first,
        name: _nameController.text,
        color: _selectedColor.toARGB32(),
        description: _descriptionController.text,
      );

      // 关联到其他工具
      for (int i = 1; i < selectedToolIds.length; i++) {
        await tagService.addTagToTool(tag.id!, selectedToolIds[i]);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('标签创建成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('创建新标签'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CupertinoTextFormFieldRow(
              controller: _nameController,
              placeholder: '标签名称',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入标签名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            CupertinoTextFormFieldRow(
              controller: _descriptionController,
              placeholder: '描述（可选）',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('颜色: '),
                GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: IOS26Theme.textTertiary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: _createTag,
          child: const Text('创建'),
        ),
      ],
    );
  }
}

class EditTagDialog extends StatefulWidget {
  final Tag tag;
  final TagService tagService;

  const EditTagDialog({super.key, required this.tag, required this.tagService});

  @override
  State<EditTagDialog> createState() => _EditTagDialogState();
}

class _EditTagDialogState extends State<EditTagDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late Color _selectedColor;
  late List<String> _selectedToolIds;
  List<String> _availableToolIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag.name);
    _descriptionController = TextEditingController(text: widget.tag.description);
    _selectedColor = Color(widget.tag.color);
    _loadTools();
  }

  Future<void> _loadTools() async {
    final toolIds = await widget.tagService.getToolIdsForTag(widget.tag.id!);
    final registry = ToolRegistry.instance;
    final allTools = registry.tools.map((t) => t.id).toList();
    
    setState(() {
      _selectedToolIds = toolIds;
      _availableToolIds = allTools;
      _isLoading = false;
    });
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTag() async {
    try {
      final updatedTag = widget.tag.copyWith(
        name: _nameController.text,
        color: _selectedColor.toARGB32(),
        description: _descriptionController.text,
      );
      
      await widget.tagService.updateTag(updatedTag);
      
      // 更新工具关联
      final currentToolIds = await widget.tagService.getToolIdsForTag(widget.tag.id!);
      
      // 移除取消关联的工具
      for (final toolId in currentToolIds) {
        if (!_selectedToolIds.contains(toolId)) {
          await widget.tagService.removeTagFromTool(widget.tag.id!, toolId);
        }
      }
      
      // 添加新关联的工具
      for (final toolId in _selectedToolIds) {
        if (!currentToolIds.contains(toolId)) {
          await widget.tagService.addTagToTool(widget.tag.id!, toolId);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('标签更新成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoAlertDialog(
        title: Text('编辑标签'),
        content: Center(child: CupertinoActivityIndicator()),
      );
    }

    final registry = ToolRegistry.instance;
    
    return CupertinoAlertDialog(
      title: const Text('编辑标签'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CupertinoTextFormFieldRow(
              controller: _nameController,
              placeholder: '标签名称',
            ),
            const SizedBox(height: 8),
            CupertinoTextFormFieldRow(
              controller: _descriptionController,
              placeholder: '描述（可选）',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('颜色: '),
                GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: IOS26Theme.textTertiary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '关联工具',
              style: TextStyle(
                color: IOS26Theme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            ..._availableToolIds.map((toolId) {
              final tool = registry.getById(toolId);
              if (tool == null) return Container();
              
              return Row(
                children: [
                  Checkbox(
                    value: _selectedToolIds.contains(toolId),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedToolIds.add(toolId);
                        } else {
                          _selectedToolIds.remove(toolId);
                        }
                      });
                    },
                  ),
                  Text(tool.name),
                ],
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: _updateTag,
          child: const Text('保存'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class ToolSelectionDialog extends StatefulWidget {
  final List<ToolInfo> tools;

  const ToolSelectionDialog({super.key, required this.tools});

  @override
  State<ToolSelectionDialog> createState() => _ToolSelectionDialogState();
}

class _ToolSelectionDialogState extends State<ToolSelectionDialog> {
  final List<String> _selectedIds = [];

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('选择关联工具'),
      content: SizedBox(
        height: 200,
        child: ListView.builder(
          itemCount: widget.tools.length,
          itemBuilder: (context, index) {
            final tool = widget.tools[index];
            return Row(
              children: [
                Checkbox(
                  value: _selectedIds.contains(tool.id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedIds.add(tool.id);
                      } else {
                        _selectedIds.remove(tool.id);
                      }
                    });
                  },
                ),
                Icon(tool.icon, size: 20, color: tool.color),
                const SizedBox(width: 8),
                Text(tool.name),
              ],
            );
          },
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(_selectedIds),
          child: const Text('确定'),
        ),
      ],
    );
  }
}