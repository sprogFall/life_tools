import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/work_photo_asset.dart';
import '../models/work_photo_capture_item.dart';
import '../models/work_photo_export_profile.dart';
import '../models/work_photo_hierarchy_level.dart';
import '../models/work_photo_hierarchy_option.dart';
import '../models/work_photo_project.dart';
import '../models/work_photo_project_detail.dart';
import '../models/work_photo_project_hierarchy_value.dart';
import '../models/work_photo_project_item.dart';

class WorkPhotoHierarchySelection {
  final int levelId;
  final int? optionId;

  const WorkPhotoHierarchySelection({
    required this.levelId,
    required this.optionId,
  });
}

class WorkPhotoRepository {
  final Future<Database> _database;

  WorkPhotoRepository({DatabaseHelper? dbHelper})
    : _database = (dbHelper ?? DatabaseHelper.instance).database;

  WorkPhotoRepository.withDatabase(Database database)
    : _database = Future.value(database);

  Future<int> createHierarchyLevel(WorkPhotoHierarchyLevel level) async {
    final db = await _database;
    return db.insert(
      'work_photo_hierarchy_levels',
      level.toMap(includeId: false),
    );
  }

  Future<WorkPhotoHierarchyLevel?> getHierarchyLevel(int id) async {
    final db = await _database;
    final rows = await db.query(
      'work_photo_hierarchy_levels',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkPhotoHierarchyLevel.fromMap(rows.single);
  }

  Future<List<WorkPhotoHierarchyLevel>> listHierarchyLevels({
    bool includeArchived = false,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'work_photo_hierarchy_levels',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'sort_index ASC, id ASC',
    );
    return rows.map(WorkPhotoHierarchyLevel.fromMap).toList();
  }

  Future<void> updateHierarchyLevel(WorkPhotoHierarchyLevel level) async {
    final id = level.id;
    if (id == null) throw ArgumentError('updateHierarchyLevel 需要 id');
    final db = await _database;
    await db.update(
      'work_photo_hierarchy_levels',
      level.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> createHierarchyOption(WorkPhotoHierarchyOption option) async {
    final db = await _database;
    return db.insert(
      'work_photo_hierarchy_options',
      option.toMap(includeId: false),
    );
  }

  Future<WorkPhotoHierarchyOption?> getHierarchyOption(int id) async {
    final db = await _database;
    final rows = await db.query(
      'work_photo_hierarchy_options',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkPhotoHierarchyOption.fromMap(rows.single);
  }

  Future<List<WorkPhotoHierarchyOption>> listHierarchyOptions({
    int? levelId,
    bool includeArchived = false,
  }) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object?>[];
    if (levelId != null) {
      where.add('level_id = ?');
      args.add(levelId);
    }
    if (!includeArchived) {
      where.add('is_archived = 0');
    }
    final rows = await db.query(
      'work_photo_hierarchy_options',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'level_id ASC, parent_option_id ASC, sort_index ASC, id ASC',
    );
    return rows.map(WorkPhotoHierarchyOption.fromMap).toList();
  }

  Future<void> updateHierarchyOption(WorkPhotoHierarchyOption option) async {
    final id = option.id;
    if (id == null) throw ArgumentError('updateHierarchyOption 需要 id');
    final db = await _database;
    await db.update(
      'work_photo_hierarchy_options',
      option.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> createCaptureItem(WorkPhotoCaptureItem item) async {
    final db = await _database;
    return db.insert('work_photo_capture_items', item.toMap(includeId: false));
  }

  Future<WorkPhotoCaptureItem?> getCaptureItem(int id) async {
    final db = await _database;
    final rows = await db.query(
      'work_photo_capture_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkPhotoCaptureItem.fromMap(rows.single);
  }

  Future<List<WorkPhotoCaptureItem>> listCaptureItems({
    bool includeArchived = false,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'work_photo_capture_items',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'sort_index ASC, id ASC',
    );
    return rows.map(WorkPhotoCaptureItem.fromMap).toList();
  }

  Future<void> updateCaptureItem(WorkPhotoCaptureItem item) async {
    final id = item.id;
    if (id == null) throw ArgumentError('updateCaptureItem 需要 id');
    final db = await _database;
    await db.update(
      'work_photo_capture_items',
      item.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> createExportProfile(WorkPhotoExportProfile profile) async {
    final db = await _database;
    return db.insert(
      'work_photo_export_profiles',
      profile.toMap(includeId: false),
    );
  }

  Future<List<WorkPhotoExportProfile>> listExportProfiles() async {
    final db = await _database;
    final rows = await db.query(
      'work_photo_export_profiles',
      orderBy: 'is_default DESC, id ASC',
    );
    return rows.map(WorkPhotoExportProfile.fromMap).toList();
  }

  Future<int> createProject({
    required String name,
    required String note,
    required List<WorkPhotoHierarchySelection> hierarchySelections,
    DateTime? now,
  }) async {
    final db = await _database;
    final time = now ?? DateTime.now();
    return db.transaction((txn) async {
      final project = WorkPhotoProject.create(
        name: name,
        note: note,
        now: time,
      );
      final projectId = await txn.insert(
        'work_photo_projects',
        project.toMap(includeId: false),
      );

      final levels = await txn.query(
        'work_photo_hierarchy_levels',
        orderBy: 'sort_index ASC, id ASC',
      );
      final selectedByLevelId = {
        for (final selection in hierarchySelections)
          selection.levelId: selection.optionId,
      };

      for (final entry in levels.indexed) {
        final index = entry.$1;
        final level = WorkPhotoHierarchyLevel.fromMap(entry.$2);
        final levelId = level.id;
        if (levelId == null || !selectedByLevelId.containsKey(levelId)) {
          continue;
        }

        final optionId = selectedByLevelId[levelId];
        var optionName = '';
        if (optionId != null) {
          final optionRows = await txn.query(
            'work_photo_hierarchy_options',
            where: 'id = ?',
            whereArgs: [optionId],
            limit: 1,
          );
          if (optionRows.isNotEmpty) {
            optionName = WorkPhotoHierarchyOption.fromMap(
              optionRows.single,
            ).name;
          }
        }

        await txn.insert('work_photo_project_hierarchy_values', {
          'project_id': projectId,
          'level_id': levelId,
          'option_id': optionId,
          'level_name_snapshot': level.name,
          'option_name_snapshot': optionName,
          'sort_index': index,
        });
      }

      final itemRows = await txn.query(
        'work_photo_capture_items',
        where: 'is_archived = 0',
        orderBy: 'sort_index ASC, id ASC',
      );
      for (final itemRow in itemRows) {
        final item = WorkPhotoCaptureItem.fromMap(itemRow);
        await txn.insert('work_photo_project_items', {
          'project_id': projectId,
          'source_item_id': item.id,
          'name_snapshot': item.name,
          'sort_index': item.sortIndex,
          'min_count': item.minCount,
          'max_count': item.maxCount,
        });
      }

      return projectId;
    });
  }

  Future<void> updateProject(WorkPhotoProject project) async {
    final id = project.id;
    if (id == null) throw ArgumentError('updateProject 需要 id');
    final db = await _database;
    await db.update(
      'work_photo_projects',
      project.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProject(int id) async {
    final db = await _database;
    await db.delete('work_photo_projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<WorkPhotoProject?> getProject(int id) async {
    final db = await _database;
    final rows = await db.query(
      'work_photo_projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkPhotoProject.fromMap(rows.single);
  }

  Future<WorkPhotoProjectDetail?> getProjectDetail(int projectId) async {
    final db = await _database;
    final projectRows = await db.query(
      'work_photo_projects',
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (projectRows.isEmpty) return null;

    final hierarchyRows = await db.query(
      'work_photo_project_hierarchy_values',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sort_index ASC, id ASC',
    );
    final itemRows = await db.query(
      'work_photo_project_items',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sort_index ASC, id ASC',
    );
    final assetRows = await db.query(
      'work_photo_assets',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'taken_at DESC, id DESC',
    );

    return WorkPhotoProjectDetail(
      project: WorkPhotoProject.fromMap(projectRows.single),
      hierarchyValues: hierarchyRows
          .map(WorkPhotoProjectHierarchyValue.fromMap)
          .toList(),
      items: itemRows.map(WorkPhotoProjectItem.fromMap).toList(),
      assets: assetRows.map(WorkPhotoAsset.fromMap).toList(),
    );
  }

  Future<List<WorkPhotoProjectSummary>> listProjectSummaries() async {
    final db = await _database;
    final projectRows = await db.query(
      'work_photo_projects',
      orderBy: 'updated_at DESC, id DESC',
    );
    if (projectRows.isEmpty) return const [];

    final summaries = <WorkPhotoProjectSummary>[];
    for (final row in projectRows) {
      final project = WorkPhotoProject.fromMap(row);
      final id = project.id;
      if (id == null) continue;
      final detail = await getProjectDetail(id);
      if (detail == null) continue;
      summaries.add(
        WorkPhotoProjectSummary(
          project: project,
          hierarchySummary: detail.hierarchySummary,
          requiredItemCount: detail.requiredItemCount,
          completedItemCount: detail.completedItemCount,
          assetCount: detail.assetCount,
        ),
      );
    }
    return summaries;
  }

  Future<int> createAsset({
    required int projectId,
    required int projectItemId,
    required String relativePath,
    required String originalFilename,
    required String mimeType,
    required int fileSize,
    required int? width,
    required int? height,
    required DateTime takenAt,
    DateTime? now,
  }) async {
    final db = await _database;
    final time = now ?? DateTime.now();
    return db.transaction((txn) async {
      final id = await txn.insert('work_photo_assets', {
        'project_id': projectId,
        'project_item_id': projectItemId,
        'relative_path': relativePath,
        'original_filename': originalFilename,
        'mime_type': mimeType,
        'file_size': fileSize,
        'width': width,
        'height': height,
        'taken_at': takenAt.millisecondsSinceEpoch,
        'created_at': time.millisecondsSinceEpoch,
        'updated_at': time.millisecondsSinceEpoch,
      });
      await txn.update(
        'work_photo_projects',
        {'updated_at': time.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [projectId],
      );
      return id;
    });
  }

  Future<void> deleteAsset(int id) async {
    final db = await _database;
    await db.delete('work_photo_assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkPhotoAsset>> listAssetsForProject(int projectId) async {
    final db = await _database;
    final rows = await db.query(
      'work_photo_assets',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'taken_at DESC, id DESC',
    );
    return rows.map(WorkPhotoAsset.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> exportHierarchyLevels() =>
      _exportTable('work_photo_hierarchy_levels', 'id ASC');

  Future<List<Map<String, Object?>>> exportHierarchyOptions() =>
      _exportTable('work_photo_hierarchy_options', 'id ASC');

  Future<List<Map<String, Object?>>> exportCaptureItems() =>
      _exportTable('work_photo_capture_items', 'id ASC');

  Future<List<Map<String, Object?>>> exportExportProfiles() =>
      _exportTable('work_photo_export_profiles', 'id ASC');

  Future<List<Map<String, Object?>>> exportProjects() =>
      _exportTable('work_photo_projects', 'id ASC');

  Future<List<Map<String, Object?>>> exportProjectHierarchyValues() =>
      _exportTable('work_photo_project_hierarchy_values', 'id ASC');

  Future<List<Map<String, Object?>>> exportProjectItems() =>
      _exportTable('work_photo_project_items', 'id ASC');

  Future<List<Map<String, Object?>>> exportAssets() =>
      _exportTable('work_photo_assets', 'id ASC');

  Future<List<Map<String, Object?>>> _exportTable(
    String table,
    String orderBy,
  ) async {
    final db = await _database;
    final rows = await db.query(table, orderBy: orderBy);
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<void> importFromServer({
    required List<Map<String, dynamic>> hierarchyLevels,
    required List<Map<String, dynamic>> hierarchyOptions,
    required List<Map<String, dynamic>> captureItems,
    required List<Map<String, dynamic>> exportProfiles,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> projectHierarchyValues,
    required List<Map<String, dynamic>> projectItems,
    required List<Map<String, dynamic>> assets,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('work_photo_assets');
      await txn.delete('work_photo_project_items');
      await txn.delete('work_photo_project_hierarchy_values');
      await txn.delete('work_photo_projects');
      await txn.delete('work_photo_export_profiles');
      await txn.delete('work_photo_capture_items');
      await txn.delete('work_photo_hierarchy_options');
      await txn.delete('work_photo_hierarchy_levels');

      await _insertRows(txn, 'work_photo_hierarchy_levels', hierarchyLevels);
      await _insertRows(txn, 'work_photo_hierarchy_options', hierarchyOptions);
      await _insertRows(txn, 'work_photo_capture_items', captureItems);
      await _insertRows(txn, 'work_photo_export_profiles', exportProfiles);
      await _insertRows(txn, 'work_photo_projects', projects);
      await _insertRows(
        txn,
        'work_photo_project_hierarchy_values',
        projectHierarchyValues,
      );
      await _insertRows(txn, 'work_photo_project_items', projectItems);
      await _insertRows(txn, 'work_photo_assets', assets);
    });
  }

  static Future<void> _insertRows(
    DatabaseExecutor txn,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      await txn.insert(table, Map<String, Object?>.from(row));
    }
  }
}
