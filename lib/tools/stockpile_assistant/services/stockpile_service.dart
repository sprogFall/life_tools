import 'package:flutter/foundation.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_repository.dart';
import '../models/stock_consumption.dart';
import '../models/stock_item.dart';
import '../repository/stockpile_repository.dart';

class StockpileService extends ChangeNotifier {
  final StockpileRepository _repository;
  final TagRepository _tagRepository;

  StockItemStockStatus _stockStatus = StockItemStockStatus.inStock;
  List<StockItem> _items = [];
  List<Tag> _availableTags = const [];
  Map<int, List<Tag>> _itemTags = const {};

  StockpileService({StockpileRepository? repository})
    : _repository = repository ?? StockpileRepository(),
      _tagRepository = TagRepository();

  StockpileService.withRepositories({
    required StockpileRepository repository,
    required TagRepository tagRepository,
  }) : _repository = repository,
       _tagRepository = tagRepository;

  StockItemStockStatus get stockStatus => _stockStatus;
  List<StockItem> get items => List.unmodifiable(_items);
  List<Tag> get availableTags => List.unmodifiable(_availableTags);

  List<StockItem> expiringSoonItems(DateTime now) {
    return _items.where((e) => !e.isDepleted && e.isExpiringSoon(now)).toList();
  }

  List<Tag> tagsForItem(int itemId) {
    return List.unmodifiable(_itemTags[itemId] ?? const []);
  }

  Future<void> loadItems() async {
    _items = await _repository.listItems(stockStatus: _stockStatus);
    _availableTags = await _tagRepository.listTagsForTool(
      'stockpile_assistant',
    );
    final ids = _items.map((e) => e.id).whereType<int>().toList();
    _itemTags = ids.isEmpty
        ? <int, List<Tag>>{}
        : await _tagRepository.listTagsForStockItems(ids);
    notifyListeners();
  }

  Future<void> setStockStatus(StockItemStockStatus status) async {
    if (_stockStatus == status) return;
    _stockStatus = status;
    await loadItems();
  }

  Future<int> createItem(StockItem item) async {
    final id = await _repository.createItem(item);
    await loadItems();
    return id;
  }

  Future<void> updateItem(StockItem item) async {
    await _repository.updateItem(item);
    await loadItems();
  }

  Future<void> deleteItem(int id) async {
    await _repository.deleteItem(id);
    await loadItems();
  }

  Future<int> createConsumption(StockConsumption consumption) async {
    final id = await _repository.createConsumption(consumption);
    await loadItems();
    return id;
  }

  Future<StockItem?> getItem(int id) => _repository.getItem(id);

  Future<List<StockConsumption>> listConsumptionsForItem(int itemId) {
    return _repository.listConsumptionsForItem(itemId);
  }

  Future<List<int>> listTagIdsForItem(int itemId) {
    return _tagRepository.listTagIdsForStockItem(itemId);
  }

  Future<void> setTagsForItem(int itemId, List<int> tagIds) async {
    await _tagRepository.setTagsForStockItem(itemId, tagIds);
    final updated = await _tagRepository.listTagsForStockItems([itemId]);
    _itemTags = {..._itemTags, ...updated};
    notifyListeners();
  }

  Future<List<Tag>> loadTagsForItem(int itemId) async {
    final updated = await _tagRepository.listTagsForStockItems([itemId]);
    _itemTags = {..._itemTags, ...updated};
    notifyListeners();
    return _itemTags[itemId] ?? const [];
  }

  Future<List<StockItem>> listAllItemsForAiContext() async {
    final inStock = await _repository.listItems(
      stockStatus: StockItemStockStatus.inStock,
    );
    final depleted = await _repository.listItems(
      stockStatus: StockItemStockStatus.depleted,
    );
    return [...inStock, ...depleted];
  }
}
