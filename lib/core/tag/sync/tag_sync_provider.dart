import '../../../core/sync/interfaces/tool_sync_provider.dart';
import '../repository/tag_repository_base.dart';
import '../models/tag_model.dart';

/// 标签管理工具的同步提供者
class TagSyncProvider implements ToolSyncProvider {
  final TagRepositoryBase _repository;

  TagSyncProvider({required TagRepositoryBase repository})
    : _repository = repository;

  @override
  String get toolId => 'tag_management';

  @override
  Future<Map<String, dynamic>> exportData() async {
    // 导出所有标签、标签工具关联（不包含具体的实体标签关联）
    final tags = await _repository.listAllTags();
    
    // 收集标签工具关联
    final toolAssociations = <Map<String, dynamic>>[];
    for (final tag in tags) {
      final toolIds = await _repository.getToolIdsForTag(tag.id!);
      for (final toolId in toolIds) {
        final association = TagToolAssociation.create(
          tagId: tag.id!,
          toolId: toolId,
        );
        toolAssociations.add(association.toMap());
      }
    }

    return {
      'version': 1,
      'data': {
        'tags': tags.map((t) => t.toMap()).toList(),
        'tag_tool_associations': toolAssociations,
      },
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    // 验证数据格式
    final version = data['version'] as int?;
    if (version == null || version != 1) {
      throw Exception('不支持的数据版本: $version');
    }

    final dataMap = data['data'] as Map<String, dynamic>?;
    if (dataMap == null) {
      throw Exception('数据格式错误：缺少data字段');
    }

    final tags = (dataMap['tags'] as List<dynamic>?) ?? [];
    final associations = (dataMap['tag_tool_associations'] as List<dynamic>?) ?? [];

    // 批量导入（使用事务确保原子性）
    await _repository.importTagsFromServer(
      tags.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
    await _repository.importTagToolAssociationsFromServer(
      associations.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}