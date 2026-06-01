import 'work_photo_asset.dart';
import 'work_photo_project.dart';
import 'work_photo_project_hierarchy_value.dart';
import 'work_photo_project_item.dart';

class WorkPhotoProjectDetail {
  final WorkPhotoProject project;
  final List<WorkPhotoProjectHierarchyValue> hierarchyValues;
  final List<WorkPhotoProjectItem> items;
  final List<WorkPhotoAsset> assets;

  const WorkPhotoProjectDetail({
    required this.project,
    required this.hierarchyValues,
    required this.items,
    required this.assets,
  });

  String get hierarchySummary {
    final values = hierarchyValues
        .map((e) => e.optionNameSnapshot.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return values.join(' / ');
  }

  int get assetCount => assets.length;

  int get requiredItemCount => items.length;

  int get completedItemCount {
    final countByItem = <int, int>{};
    for (final asset in assets) {
      countByItem.update(
        asset.projectItemId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return items.where((item) {
      final id = item.id;
      if (id == null) return false;
      return (countByItem[id] ?? 0) >= item.minCount;
    }).length;
  }

  Map<int, List<WorkPhotoAsset>> get assetsByItemId {
    final result = <int, List<WorkPhotoAsset>>{};
    for (final asset in assets) {
      result.putIfAbsent(asset.projectItemId, () => []).add(asset);
    }
    return result;
  }
}

class WorkPhotoProjectSummary {
  final WorkPhotoProject project;
  final String hierarchySummary;
  final int requiredItemCount;
  final int completedItemCount;
  final int assetCount;

  const WorkPhotoProjectSummary({
    required this.project,
    required this.hierarchySummary,
    required this.requiredItemCount,
    required this.completedItemCount,
    required this.assetCount,
  });
}
