import '../../../core/sync/interfaces/tool_sync_provider.dart';
import '../../../core/tags/tag_repository.dart';
import '../repository/stockpile_repository.dart';

class StockpileSyncProvider implements ToolSyncProvider {
  final StockpileRepository _repository;
  final TagRepository _tagRepository;

  StockpileSyncProvider({
    required StockpileRepository repository,
    TagRepository? tagRepository,
  }) : _repository = repository,
       _tagRepository = tagRepository ?? TagRepository();

  @override
  String get toolId => 'stockpile_assistant';

  @override
  Future<Map<String, dynamic>> exportData() async {
    final items = await _repository.exportItems();
    final consumptions = await _repository.exportConsumptions();
    final itemTags = await _tagRepository.exportStockItemTags();

    return {
      'version': 2,
      'data': {
        'items': items,
        'consumptions': consumptions,
        'item_tags': itemTags,
      },
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    final version = data['version'] as int?;
    if (version != 1 && version != 2) {
      throw Exception('不支持的数据版本: $version');
    }

    final dataMap = data['data'] as Map<String, dynamic>?;
    if (dataMap == null) {
      throw Exception('数据格式错误：缺少 data 字段');
    }

    final items = (dataMap['items'] as List<dynamic>?) ?? [];
    final consumptions = (dataMap['consumptions'] as List<dynamic>?) ?? [];
    final itemTags = (dataMap['item_tags'] as List<dynamic>?) ?? [];

    await _repository.importFromServer(
      items: items.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      consumptions:
          consumptions.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );

    if (version == 2 && itemTags.isNotEmpty) {
      await _tagRepository.importStockItemTagsFromServer(
        itemTags.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }
  }
}
