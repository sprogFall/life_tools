import '../models/tag_model.dart';

abstract class TagRepositoryBase {
  // 标签管理
  Future<int> createTag(Tag tag);
  
  Future<Tag?> getTag(int id);
  
  Future<List<Tag>> listAllTags();
  
  Future<List<Tag>> listTagsByToolId(String toolId);
  
  Future<void> updateTag(Tag tag);
  
  Future<void> deleteTag(int id);
  
  Future<int?> getTagIdByName(String name);
  
  // 标签与工具关联
  Future<void> associateTagWithTool(int tagId, String toolId);
  
  Future<void> disassociateTagFromTool(int tagId, String toolId);
  
  Future<List<String>> getToolIdsForTag(int tagId);
  
  // 标签与实体关联（以工作记录为例）
  Future<void> associateTagWithTask(int tagId, int taskId);
  
  Future<void> disassociateTagFromTask(int tagId, int taskId);
  
  Future<List<Tag>> getTagsForTask(int taskId);
  
  Future<List<int>> getTaskIdsForTag(int tagId);
  
  // 同步支持
  Future<void> importTagsFromServer(List<Map<String, dynamic>> tagsData);
  
  Future<void> importTagToolAssociationsFromServer(
    List<Map<String, dynamic>> associationsData,
  );
  
  Future<void> importWorkTaskTagsFromServer(
    List<Map<String, dynamic>> taskTagsData,
  );
}