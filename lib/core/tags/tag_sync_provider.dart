import '../sync/interfaces/tool_sync_provider.dart';
import 'tag_repository.dart';

/// 标签管理工具的导入/导出（备份/还原）适配
class TagSyncProvider implements ToolSyncProvider {
  final TagRepository _repository;

  TagSyncProvider({required TagRepository repository})
    : _repository = repository;

  @override
  String get toolId => 'tag_manager';

  @override
  Future<Map<String, dynamic>> exportData() async {
    return {
      'version': 1,
      'data': {
        'tags': await _repository.exportTags(),
        'tool_tags': await _repository.exportToolTags(),
      },
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    final version = data['version'] as int?;
    if (version != 1) {
      throw Exception('不支持的标签数据版本: $version');
    }

    final map = data['data'];
    if (map is! Map<String, dynamic>) {
      throw Exception('标签数据格式错误：缺少 data');
    }

    final tagsRaw = (map['tags'] as List?) ?? const [];
    final toolTagsRaw = (map['tool_tags'] as List?) ?? const [];

    await _repository.importTagsFromServer(
      tags: tagsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      toolTags: toolTagsRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}
