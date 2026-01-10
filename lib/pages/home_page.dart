import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models/tool_info.dart';
import '../core/services/settings_service.dart';

/// 首页欢迎页面，展示所有可用工具
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生活助手'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
            tooltip: '设置',
          ),
        ],
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          final tools = settings.getSortedTools();
          return _buildToolGrid(context, tools, settings);
        },
      ),
    );
  }

  Widget _buildToolGrid(
    BuildContext context,
    List<ToolInfo> tools,
    SettingsService settings,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '欢迎使用生活助手',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '请选择需要使用的工具',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ReorderableGridView(
              tools: tools,
              onReorder: (oldIndex, newIndex) {
                final newOrder = tools.map((t) => t.id).toList();
                final item = newOrder.removeAt(oldIndex);
                newOrder.insert(
                  newIndex > oldIndex ? newIndex - 1 : newIndex,
                  item,
                );
                settings.updateToolOrder(newOrder);
              },
              onToolTap: (tool) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => tool.pageBuilder()),
                );
              },
              defaultToolId: settings.defaultToolId,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('默认打开工具:'),
            const SizedBox(height: 8),
            Consumer<SettingsService>(
              builder: (context, settings, _) {
                final tools = settings.getSortedTools();
                return DropdownButton<String?>(
                  value: settings.defaultToolId,
                  isExpanded: true,
                  hint: const Text('无（显示首页）'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('无（显示首页）'),
                    ),
                    ...tools.map((tool) => DropdownMenuItem<String?>(
                          value: tool.id,
                          child: Text(tool.name),
                        )),
                  ],
                  onChanged: (value) {
                    settings.setDefaultTool(value);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              '提示：长按工具图标可拖拽调整顺序',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 可重排序的网格视图
class ReorderableGridView extends StatelessWidget {
  final List<ToolInfo> tools;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(ToolInfo tool) onToolTap;
  final String? defaultToolId;

  const ReorderableGridView({
    super.key,
    required this.tools,
    required this.onReorder,
    required this.onToolTap,
    this.defaultToolId,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _ToolCard(
          tool: tool,
          isDefault: tool.id == defaultToolId,
          onTap: () => onToolTap(tool),
        );
      },
    );
  }
}

/// 工具卡片组件
class _ToolCard extends StatelessWidget {
  final ToolInfo tool;
  final bool isDefault;
  final VoidCallback onTap;

  const _ToolCard({
    required this.tool,
    required this.isDefault,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      tool.icon,
                      size: 32,
                      color: tool.color,
                    ),
                  ),
                  if (isDefault)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.star,
                          size: 12,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tool.name,
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                tool.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
