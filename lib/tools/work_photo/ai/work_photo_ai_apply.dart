import '../models/work_photo_capture_item.dart';
import '../models/work_photo_hierarchy_level.dart';
import '../repository/work_photo_repository.dart';
import 'work_photo_ai_intent.dart';

/// 将 AI 生成的模板树整体覆盖到指定模板：
/// 1) 归档模板下既有层级与拍摄项
/// 2) 按 nodes 顺序重建新树
Future<void> applyWorkPhotoTemplateTree({
  required WorkPhotoConfigRepository repository,
  required int templateId,
  required List<WorkPhotoAiTemplateNode> nodes,
  required List<WorkPhotoHierarchyLevel> existingLevels,
  required List<WorkPhotoCaptureItem> existingItems,
  DateTime? now,
}) async {
  final time = now ?? DateTime.now();

  for (final level in existingLevels.where(
    (e) => e.templateId == templateId && !e.isArchived,
  )) {
    await repository.updateHierarchyLevel(
      level.copyWith(isArchived: true, updatedAt: time),
    );
  }
  for (final item in existingItems.where(
    (e) => e.templateId == templateId && !e.isArchived,
  )) {
    await repository.updateCaptureItem(
      item.copyWith(isArchived: true, updatedAt: time),
    );
  }

  await _createNodes(
    repository: repository,
    templateId: templateId,
    parentLevelId: null,
    nodes: nodes,
    now: time,
  );
}

Future<void> _createNodes({
  required WorkPhotoConfigRepository repository,
  required int templateId,
  required int? parentLevelId,
  required List<WorkPhotoAiTemplateNode> nodes,
  required DateTime now,
}) async {
  for (var index = 0; index < nodes.length; index++) {
    final node = nodes[index];
    if (node.isLevel) {
      final levelId = await repository.createHierarchyLevel(
        WorkPhotoHierarchyLevel.create(
          templateId: templateId,
          parentLevelId: parentLevelId,
          name: node.name,
          sortIndex: index,
          isRequired: node.isRequired,
          now: now,
        ),
      );
      if (node.children.isNotEmpty) {
        await _createNodes(
          repository: repository,
          templateId: templateId,
          parentLevelId: levelId,
          nodes: node.children,
          now: now,
        );
      }
      continue;
    }

    await repository.createCaptureItem(
      WorkPhotoCaptureItem.create(
        templateId: templateId,
        parentLevelId: parentLevelId,
        name: node.name,
        sortIndex: index,
        minCount: node.minCount,
        maxCount: node.maxCount,
        now: now,
      ),
    );
  }
}
