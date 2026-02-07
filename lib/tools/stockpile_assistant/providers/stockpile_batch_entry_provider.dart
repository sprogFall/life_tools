import 'package:flutter/widgets.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_service.dart';
import '../../../core/utils/text_editing_safety.dart';
import '../ai/stockpile_ai_intent.dart';
import '../models/stockpile_drafts.dart';
import '../services/stockpile_service.dart';
import '../stockpile_constants.dart';
import '../utils/stockpile_utils.dart';

class StockpileBatchEntryProvider extends ChangeNotifier {
  int _tab = 0; // 0=items, 1=consumptions

  int _nextItemKey = 0;
  int _nextConsumptionKey = 0;

  final List<StockpileBatchItemEntry> _items = [];
  final List<StockpileBatchConsumptionEntry> _consumptions = [];

  bool _saving = false;
  bool _loadingTags = false;
  List<Tag> _itemTypeTags = const [];
  List<Tag> _locationTags = const [];
  Map<int, Tag> _tagsById = const {};

  bool _disposed = false;

  StockpileBatchEntryProvider({
    required List<StockItemDraft> initialItems,
    required List<StockpileAiConsumptionEntry> initialConsumptions,
  }) {
    if (initialItems.isEmpty && initialConsumptions.isNotEmpty) {
      _tab = 1;
    }

    for (final draft in initialItems) {
      _items.add(_createItemEntry(draft));
    }
    for (final draft in initialConsumptions) {
      _consumptions.add(_createConsumptionEntry(draft));
    }
  }

  int get tab => _tab;

  void setTab(int value) {
    if (_tab == value) return;
    _tab = value;
    notifyListeners();
  }

  List<StockpileBatchItemEntry> get items => List.unmodifiable(_items);

  List<StockpileBatchConsumptionEntry> get consumptions =>
      List.unmodifiable(_consumptions);

  bool get saving => _saving;

  void setSaving(bool value) {
    if (_saving == value) return;
    _saving = value;
    notifyListeners();
  }

  bool get loadingTags => _loadingTags;

  List<Tag> get itemTypeTags => List.unmodifiable(_itemTypeTags);

  List<Tag> get locationTags => List.unmodifiable(_locationTags);

  Map<int, Tag> get tagsById => Map.unmodifiable(_tagsById);

  StockpileBatchItemEntry _createItemEntry(StockItemDraft draft) {
    return StockpileBatchItemEntry.fromDraft(
      keyId: _nextItemKey++,
      draft: draft,
    );
  }

  StockpileBatchConsumptionEntry _createConsumptionEntry(
    StockpileAiConsumptionEntry draft,
  ) {
    return StockpileBatchConsumptionEntry.fromDraft(
      keyId: _nextConsumptionKey++,
      entry: draft,
    );
  }

  void addEmptyItem() {
    _items.add(
      _createItemEntry(
        StockItemDraft(
          name: '',
          location: '',
          totalQuantity: 1,
          remainingQuantity: 1,
          unit: '',
          purchaseDate: DateTime.now(),
          expiryDate: null,
          remindDays: -1,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
          tagIds: const [],
        ),
      ),
    );
    notifyListeners();
  }

  void removeItem(StockpileBatchItemEntry entry) {
    final removed = _items.remove(entry);
    if (!removed) return;
    entry.dispose();
    notifyListeners();
  }

  void addEmptyConsumption() {
    _consumptions.add(
      _createConsumptionEntry(
        StockpileAiConsumptionEntry(
          itemRef: const StockpileAiItemRef(),
          draft: StockConsumptionDraft(
            quantity: 1,
            method: '',
            consumedAt: DateTime.now(),
            note: '',
          ),
        ),
      ),
    );
    notifyListeners();
  }

  void removeConsumption(StockpileBatchConsumptionEntry entry) {
    final removed = _consumptions.remove(entry);
    if (!removed) return;
    entry.dispose();
    notifyListeners();
  }

  void touch() {
    notifyListeners();
  }

  Future<void> loadTagOptions(TagService tagService) async {
    if (_loadingTags || _disposed) return;
    _loadingTags = true;
    notifyListeners();

    try {
      final itemTypeTags = await tagService.listTagsForToolCategory(
        toolId: StockpileConstants.toolId,
        categoryId: StockpileTagCategories.itemType,
      );
      final locationTags = await tagService.listTagsForToolCategory(
        toolId: StockpileConstants.toolId,
        categoryId: StockpileTagCategories.location,
      );
      final all = await tagService.listTagsForTool(StockpileConstants.toolId);

      if (_disposed) return;
      _itemTypeTags = itemTypeTags;
      _locationTags = locationTags;
      _tagsById = {
        for (final t in all)
          if (t.id != null) t.id!: t,
      };

      _syncLegacyLocationTextIntoLocationTagIds();
    } catch (_) {
      // 测试/极端情况下（例如页面已销毁或数据库关闭）直接忽略，避免抛出异步异常。
    } finally {
      _loadingTags = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> resolveConsumptionItemDetails(StockpileService service) async {
    if (_consumptions.isEmpty || _disposed) return;

    var changed = false;
    for (final entry in _consumptions) {
      final id = entry.resolvedItemId ?? entry.itemRef.id;
      if (id == null) continue;

      final item = await service.getItem(id);
      if (_disposed) return;

      final nextRemaining = item?.remainingQuantity;
      final nextUnit = item?.unit;
      if (entry.remainingQuantity != nextRemaining || entry.unit != nextUnit) {
        entry.remainingQuantity = nextRemaining;
        entry.unit = nextUnit;
        changed = true;
      }
    }

    if (changed && !_disposed) notifyListeners();
  }

  void _syncLegacyLocationTextIntoLocationTagIds() {
    final locationIds = _locationTags.map((e) => e.id).whereType<int>().toSet();

    for (final entry in _items) {
      if (entry.selectedTagIds.any(locationIds.contains)) {
        final id = entry.selectedTagIds.firstWhere(locationIds.contains);
        final name = _tagsById[id]?.name;
        if (name != null) {
          setControllerTextWhenComposingIdle(
            entry.locationController,
            name,
            shouldContinue: () => !_disposed,
          );
        }
        continue;
      }

      final legacy = entry.locationController.text.trim();
      if (legacy.isEmpty) continue;
      for (final t in _locationTags) {
        final id = t.id;
        if (id != null && t.name.trim() == legacy) {
          entry.selectedTagIds.add(id);
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final e in _items) {
      e.dispose();
    }
    for (final e in _consumptions) {
      e.dispose();
    }
    super.dispose();
  }
}

class StockpileBatchItemEntry {
  final int keyId;

  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final unitController = TextEditingController();
  final totalController = TextEditingController(text: '1');
  final remainingController = TextEditingController(text: '1');
  final remindDaysController = TextEditingController();
  final restockQuantityController = TextEditingController();
  final noteController = TextEditingController();

  DateTime purchaseDate = DateTime.now();
  DateTime? expiryDate;
  DateTime? restockRemindDate;
  final Set<int> selectedTagIds = {};

  StockpileBatchItemEntry._(this.keyId);

  factory StockpileBatchItemEntry.fromDraft({
    required int keyId,
    required StockItemDraft draft,
  }) {
    final e = StockpileBatchItemEntry._(keyId);
    e.nameController.text = draft.name;
    e.locationController.text = draft.location;
    e.unitController.text = draft.unit;
    e.totalController.text = StockpileFormat.num(draft.totalQuantity);
    e.remainingController.text = StockpileFormat.num(draft.remainingQuantity);
    e.remindDaysController.text =
        draft.expiryDate == null || draft.remindDays < 0
        ? ''
        : draft.remindDays.toString();
    e.restockQuantityController.text = draft.restockRemindQuantity == null
        ? ''
        : StockpileFormat.num(draft.restockRemindQuantity!);
    e.noteController.text = draft.note;
    e.purchaseDate = draft.purchaseDate;
    e.expiryDate = draft.expiryDate;
    e.restockRemindDate = draft.restockRemindDate;
    e.selectedTagIds.addAll(draft.tagIds);
    return e;
  }

  void dispose() {
    nameController.dispose();
    locationController.dispose();
    unitController.dispose();
    totalController.dispose();
    remainingController.dispose();
    remindDaysController.dispose();
    restockQuantityController.dispose();
    noteController.dispose();
  }
}

class StockpileBatchConsumptionEntry {
  final int keyId;

  StockpileAiItemRef itemRef = const StockpileAiItemRef();
  int? resolvedItemId;
  double? remainingQuantity;
  String? unit;

  final qtyController = TextEditingController(text: '1');
  final noteController = TextEditingController();
  DateTime consumedAt = DateTime.now();

  StockpileBatchConsumptionEntry._(this.keyId);

  factory StockpileBatchConsumptionEntry.fromDraft({
    required int keyId,
    required StockpileAiConsumptionEntry entry,
  }) {
    final e = StockpileBatchConsumptionEntry._(keyId);
    e.itemRef = entry.itemRef;
    e.resolvedItemId = entry.itemRef.id;
    e.qtyController.text = StockpileFormat.num(entry.draft.quantity);
    e.noteController.text = entry.draft.note;
    e.consumedAt = entry.draft.consumedAt;
    return e;
  }

  String get unitText {
    final u = unit?.trim() ?? '';
    return u;
  }

  String get displayItemText {
    final id = resolvedItemId ?? itemRef.id;
    final name = itemRef.name?.trim();
    if ((name ?? '').isEmpty && id == null) return '未匹配物品';
    if (id != null && (name ?? '').isNotEmpty) return '$name（id=$id）';
    if (id != null) return 'id=$id';
    return name!;
  }

  void dispose() {
    qtyController.dispose();
    noteController.dispose();
  }
}
