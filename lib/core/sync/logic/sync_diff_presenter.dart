import 'package:flutter/cupertino.dart';
import '../../theme/ios26_theme.dart';

class SyncDiffDisplay {
  final String label;
  final String path;
  final String details;
  final Color color;

  SyncDiffDisplay({
    required this.label,
    required this.path,
    required this.details,
    required this.color,
  });
}

class SyncDiffPresenter {
  static const Map<String, String> _toolNames = {
    'work_log': '工作记录',
    'stockpile_assistant': '囤货助手',
    'overcooked_kitchen': '胡闹厨房',
    'tag_manager': '标签管理',
    'app_config': '应用配置',
  };

  static const Map<String, String> _categoryNames = {
    'location': '位置',
    'item_type': '物品类型',
    'dish_type': '菜品类型',
    'ingredient': '食材',
    'sauce': '酱料',
    'affiliation': '归属',
  };

  static String getToolName(String toolId) {
    return _toolNames[toolId] ?? toolId;
  }

  static String _getCategoryName(String categoryId) {
    return _categoryNames[categoryId] ?? categoryId;
  }

  static SyncDiffDisplay formatDiffItem(String toolId, Map<dynamic, dynamic> raw) {
    final path = (raw['path'] as String?) ?? '';
    final change = (raw['change'] as String?) ?? '';

    // Convert path to readable format
    var readablePath = path;
    readablePath = readablePath.replaceAllMapped(RegExp(r'\[(\d+)\]'), (match) {
      final index = int.tryParse(match.group(1) ?? '0') ?? 0;
      return ' > 第${index + 1}项';
    });
    readablePath = readablePath.replaceAll('.', ' > ');

    String label;
    String details = '';
    Color color = IOS26Theme.textSecondary;

    switch (change) {
      case 'added':
        label = '新增';
        color = CupertinoColors.activeGreen;
        details = _formatAddedOrRemoved(toolId, raw['client'] ?? raw['server'], isAdded: true);
        break;
      case 'removed':
        label = '删除';
        color = CupertinoColors.destructiveRed;
        details = _formatAddedOrRemoved(toolId, raw['server'] ?? raw['client'], isAdded: false);
        break;
      case 'value_changed':
        label = '修改';
        color = CupertinoColors.activeBlue;
        final s = raw['server'];
        final c = raw['client'];
        if (s.toString().length < 20 && c.toString().length < 20) {
           details = '$s → $c';
        } else {
           details = '内容已变更';
        }
        break;
      case 'type_changed':
        label = '类型变更';
        details = '${raw['server_type']} → ${raw['client_type']}';
        break;
      default:
        label = change;
        break;
    }

    return SyncDiffDisplay(
      label: label,
      path: readablePath,
      details: details,
      color: color,
    );
  }

  static String _formatAddedOrRemoved(String toolId, dynamic data, {required bool isAdded}) {
    if (data is! Map) {
      return isAdded ? '新增了数据' : '删除了数据';
    }

    // Handle Tag specific logic
    // Assuming tags have 'name' and 'category_id' or similar fields
    // and usually the path contains 'tags'
    if (data.containsKey('name') && (data.containsKey('category_id') || data.containsKey('categoryId'))) {
      final name = data['name'];
      final categoryId = data['category_id'] ?? data['categoryId'];
      final categoryName = _getCategoryName(categoryId.toString());
      final toolName = getToolName(toolId);
      
      return '${isAdded ? "新增" : "删除"}了$toolName下$categoryName类型的标签：【$name】';
    }
    
    // Generic fallback with name/title if available
    if (data.containsKey('name')) {
       return '${isAdded ? "新增" : "删除"}了：【${data['name']}】';
    }
    if (data.containsKey('title')) {
       return '${isAdded ? "新增" : "删除"}了：【${data['title']}】';
    }

    return isAdded ? '新增了数据' : '删除了数据';
  }
}
