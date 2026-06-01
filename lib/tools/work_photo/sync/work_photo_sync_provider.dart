import '../../../core/sync/interfaces/tool_sync_provider.dart';
import '../repository/work_photo_repository.dart';
import '../work_photo_constants.dart';

class WorkPhotoSyncProvider implements ToolSyncProvider {
  static const int snapshotVersion = 2;

  final WorkPhotoRepository _repository;

  WorkPhotoSyncProvider({required WorkPhotoRepository repository})
    : _repository = repository;

  @override
  String get toolId => WorkPhotoConstants.toolId;

  @override
  Future<Map<String, dynamic>> exportData() async {
    return {
      'version': snapshotVersion,
      'data': {
        'templates': await _repository.exportTemplates(),
        'hierarchy_levels': await _repository.exportHierarchyLevels(),
        'hierarchy_options': await _repository.exportHierarchyOptions(),
        'capture_items': await _repository.exportCaptureItems(),
        'export_profiles': await _repository.exportExportProfiles(),
        'projects': await _repository.exportProjects(),
        'project_hierarchy_values': await _repository
            .exportProjectHierarchyValues(),
        'project_items': await _repository.exportProjectItems(),
        'assets': await _repository.exportAssets(),
      },
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    final version = data['version'] as int?;
    if (version != 1 && version != snapshotVersion) {
      throw Exception('不支持的数据版本: $version');
    }
    final dataMap = data['data'];
    if (dataMap is! Map) {
      throw Exception('数据格式错误：缺少 data 字段');
    }

    List<Map<String, dynamic>> readList(String key) {
      final raw = dataMap[key];
      if (raw is! List) return const [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    await _repository.importFromServer(
      templates: readList('templates'),
      hierarchyLevels: readList('hierarchy_levels'),
      hierarchyOptions: readList('hierarchy_options'),
      captureItems: readList('capture_items'),
      exportProfiles: readList('export_profiles'),
      projects: readList('projects'),
      projectHierarchyValues: readList('project_hierarchy_values'),
      projectItems: readList('project_items'),
      assets: readList('assets'),
    );
  }
}
