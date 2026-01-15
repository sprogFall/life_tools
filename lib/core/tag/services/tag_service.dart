import '../repository/tag_repository_base.dart';
import '../repository/tag_repository.dart';
import '../models/tag_model.dart';

/// 标签公共服务，提供给其他工具使用的公共接口
class TagService {
  final TagRepositoryBase _repository;

  TagService({TagRepositoryBase? repository})
    : _repository = repository ?? TagRepository();

  /// 获取指定工具可用的所有标签
  Future<List<Tag>> getAvailableTags(String toolId) async {
    return await _repository.listTagsByToolId(toolId);
  }

  /// 检查标签是否可分配给指定工具
  Future<bool> isTagAvailableForTool(int tagId, String toolId) async {
    final toolIds = await _repository.getToolIdsForTag(tagId);
    return toolIds.contains(toolId);
  }

  /// 为指定工具创建并关联新标签
  Future<Tag> createTagForTool({
    required String toolId,
    required String name,
    required int color,
    String description = '',
  }) async {
    // 创建标签
    final tag = Tag.create(
      name: name,
      color: color,
      description: description,
    );
    final tagId = await _repository.createTag(tag);

    // 关联到工具
    await _repository.associateTagWithTool(tagId, toolId);

    // 返回创建的标签
    final createdTag = await _repository.getTag(tagId);
    return createdTag!;
  }

  /// 为实体（如任务）关联标签
  Future<void> addTagToTask(int tagId, int taskId) async {
    await _repository.associateTagWithTask(tagId, taskId);
  }

  /// 从实体（如任务）移除标签
  Future<void> removeTagFromTask(int tagId, int taskId) async {
    await _repository.disassociateTagFromTask(tagId, taskId);
  }

  /// 获取实体（如任务）的所有标签
  Future<List<Tag>> getTagsForTask(int taskId) async {
    return await _repository.getTagsForTask(taskId);
  }

  /// 检查实体（如任务）是否具有指定标签
  Future<bool> taskHasTag(int taskId, int tagId) async {
    final taskTags = await _repository.getTagsForTask(taskId);
    return taskTags.any((tag) => tag.id == tagId);
  }

  /// 获取具有指定标签的所有任务ID
  Future<List<int>> getTaskIdsForTag(int tagId) async {
    return await _repository.getTaskIdsForTag(tagId);
  }

  /// 根据名称获取标签（如果不存在则返回null）
  Future<Tag?> getTagByName(String name) async {
    final tagId = await _repository.getTagIdByName(name);
    if (tagId != null) {
      return await _repository.getTag(tagId);
    }
    return null;
  }

  /// 更新标签信息
  Future<void> updateTag(Tag tag) async {
    await _repository.updateTag(tag);
  }

  /// 删除标签（会自动删除所有关联）
  Future<void> deleteTag(int tagId) async {
    await _repository.deleteTag(tagId);
  }

  /// 批量为任务设置标签（覆盖原有标签）
  Future<void> setTaskTags(int taskId, List<int> tagIds) async {
    final db = await (_repository as dynamic)._database as dynamic;
    
    await db.transaction((txn) async {
      // 删除现有标签关联
      await txn.delete(
        'work_task_tags',
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      
      // 添加新的标签关联
      for (final tagId in tagIds) {
        await txn.insert('work_task_tags', {
          'tag_id': tagId,
          'task_id': taskId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  /// 获取当前系统的所有标签（管理用）
  Future<List<Tag>> listAllTags() async {
    return await _repository.listAllTags();
  }

  /// 为标签关联工具
  Future<void> addTagToTool(int tagId, String toolId) async {
    await _repository.associateTagWithTool(tagId, toolId);
  }

  /// 从标签移除工具关联
  Future<void> removeTagFromTool(int tagId, String toolId) async {
    await _repository.disassociateTagFromTool(tagId, toolId);
  }

  /// 获取标签关联的所有工具ID
  Future<List<String>> getToolIdsForTag(int tagId) async {
    return await _repository.getToolIdsForTag(tagId);
  }
}