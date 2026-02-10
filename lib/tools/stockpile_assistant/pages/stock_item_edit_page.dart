import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/messages/message_service.dart';
import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_service.dart';
import '../../../core/tags/widgets/tag_picker_sheet.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/utils/text_editing_safety.dart';
import '../../../core/widgets/ios26_select_field.dart';
import '../models/stock_item.dart';
import '../models/stockpile_drafts.dart';
import '../services/stockpile_reminder_service.dart';
import '../services/stockpile_service.dart';
import '../stockpile_constants.dart';
import '../utils/stockpile_tag_utils.dart';
import '../utils/stockpile_utils.dart';

class StockItemEditPage extends StatefulWidget {
  final int? itemId;
  final StockItemDraft? draft;

  const StockItemEditPage({super.key, this.itemId, this.draft});

  @override
  State<StockItemEditPage> createState() => _StockItemEditPageState();
}

class _StockItemEditPageState extends State<StockItemEditPage> {
  late final StockpileService _service;

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _unitController = TextEditingController();
  final _totalController = TextEditingController(text: '1');
  final _remainingController = TextEditingController(text: '1');
  final _remindDaysController = TextEditingController();
  final _restockQuantityController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  DateTime? _expiryDate;
  DateTime? _restockRemindDate;

  StockItem? _editing;
  Set<int> _selectedTagIds = {};
  Set<int> _selectedItemTypeTagIds = {};
  int? _selectedLocationTagId;

  bool _loadingTags = false;
  List<Tag> _itemTypeTags = const [];
  List<Tag> _locationTags = const [];
  Map<int, Tag> _tagsById = const {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<StockpileService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadTagOptions();
    });
    final id = widget.itemId;
    if (id != null) {
      _loading = true;
      Future<void>.microtask(() async {
        final item = await _service.getItem(id);
        final tagIds = await _service.listTagIdsForItem(id);
        if (!mounted) return;
        setState(() {
          _editing = item;
          _selectedTagIds = tagIds.toSet();
          _loading = false;
        });
        if (item != null) _fill(item);
        _syncTagSelectionsFromAll();
      });
    } else {
      final draft = widget.draft;
      if (draft != null) {
        _fillDraft(draft);
        _syncTagSelectionsFromAll();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _unitController.dispose();
    _totalController.dispose();
    _remainingController.dispose();
    _remindDaysController.dispose();
    _restockQuantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _fill(StockItem item) {
    _nameController.text = item.name;
    _locationController.text = item.location;
    _unitController.text = item.unit;
    _totalController.text = StockpileFormat.num(item.totalQuantity);
    _remainingController.text = StockpileFormat.num(item.remainingQuantity);
    _remindDaysController.text = item.expiryDate == null || item.remindDays < 0
        ? ''
        : item.remindDays.toString();
    _restockQuantityController.text = item.restockRemindQuantity == null
        ? ''
        : StockpileFormat.num(item.restockRemindQuantity!);
    _noteController.text = item.note;

    _purchaseDate = item.purchaseDate;
    _expiryDate = item.expiryDate;
    _restockRemindDate = item.restockRemindDate;
  }

  void _fillDraft(StockItemDraft draft) {
    _nameController.text = draft.name;
    _locationController.text = draft.location;
    _unitController.text = draft.unit;
    _totalController.text = StockpileFormat.num(draft.totalQuantity);
    _remainingController.text = StockpileFormat.num(draft.remainingQuantity);
    _remindDaysController.text =
        draft.expiryDate == null || draft.remindDays < 0
        ? ''
        : draft.remindDays.toString();
    _restockQuantityController.text = draft.restockRemindQuantity == null
        ? ''
        : StockpileFormat.num(draft.restockRemindQuantity!);
    _noteController.text = draft.note;

    _purchaseDate = draft.purchaseDate;
    _expiryDate = draft.expiryDate;
    _restockRemindDate = draft.restockRemindDate;
    _selectedTagIds = draft.tagIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.itemId != null;
    final ghostButton = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);
    final primaryButton = IOS26Theme.buttonColors(IOS26ButtonVariant.primary);
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: isEdit ? '编辑物品' : '新增物品',
        showBackButton: true,
      ),
      body: BackdropGroup(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _buildFormCard(
                      title: '名称',
                      child: _buildTextField(
                        key: const ValueKey('stock_item_name'),
                        controller: _nameController,
                        placeholder: '如：牛奶、抽纸',
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildItemTypePicker(),
                    const SizedBox(height: 12),
                    _buildLocationPicker(),
                    const SizedBox(height: 12),
                    _buildFormCard(
                      title: '数量',
                      compact: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildInlineLabeledField(
                              label: '总数量',
                              child: _buildTextField(
                                key: const ValueKey('stock_item_total'),
                                controller: _totalController,
                                placeholder: '',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _buildInlineLabeledField(
                              label: '剩余数量',
                              child: _buildTextField(
                                key: const ValueKey('stock_item_remaining'),
                                controller: _remainingController,
                                placeholder: '',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildInlineLabeledField(
                              label: '单位',
                              child: _buildTextField(
                                key: const ValueKey('stock_item_unit'),
                                controller: _unitController,
                                placeholder: '如：盒',
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDateRow(
                      title: '采购日期',
                      value: StockpileFormat.date(_purchaseDate),
                      onTap: () => _pickDate(
                        initial: _purchaseDate,
                        onSelected: (v) => setState(() => _purchaseDate = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildExpirySection(),
                    const SizedBox(height: 12),
                    _buildRestockSection(),
                    const SizedBox(height: 12),
                    _buildFormCard(
                      title: '备注',
                      compact: true,
                      child: _buildTextField(
                        key: const ValueKey('stock_item_note'),
                        controller: _noteController,
                        placeholder: '可选',
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: IOS26Button(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  variant: IOS26ButtonVariant.ghost,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    '取消',
                    style: IOS26Theme.labelLarge.copyWith(
                      color: ghostButton.foreground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IOS26Button(
                  key: const ValueKey('stock_item_save'),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  variant: IOS26ButtonVariant.primary,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _save,
                  child: Text(
                    '保存',
                    style: IOS26Theme.labelLarge.copyWith(
                      color: primaryButton.foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemTypePicker() {
    final names =
        _selectedItemTypeTagIds
            .map((id) => _tagsById[id]?.name)
            .whereType<String>()
            .toList()
          ..sort();
    final text = names.isEmpty ? '未选择' : names.join('、');

    return _buildFormCard(
      title: '物品类型',
      child: IOS26SelectField(
        buttonKey: const ValueKey('stock_item_pick_item_types'),
        text: text,
        isPlaceholder: names.isEmpty,
        onPressed: _pickItemTypes,
      ),
    );
  }

  Widget _buildLocationPicker() {
    final selectedName = _selectedLocationTagId == null
        ? null
        : _tagsById[_selectedLocationTagId!]?.name;
    final legacy = _locationController.text.trim();
    final text = selectedName ?? (legacy.isEmpty ? '未选择' : legacy);
    final isPlaceholder = selectedName == null && legacy.isEmpty;

    return _buildFormCard(
      title: '位置',
      child: IOS26SelectField(
        buttonKey: const ValueKey('stock_item_pick_location'),
        text: text,
        isPlaceholder: isPlaceholder,
        onPressed: _pickLocation,
      ),
    );
  }

  Future<void> _pickItemTypes() async {
    final selected = await TagPickerSheetView.show<TagPickerResult>(
      context,
      title: '选择物品类型',
      tags: _itemTypeTags,
      selectedIds: _selectedItemTypeTagIds,
      multi: true,
      keyPrefix: 'stockpile-tag',
      createHint: StockpileTagUtils.createHint(
        context,
        StockpileTagCategories.itemType,
      ),
      onCreateTag: (name) => StockpileTagUtils.createTag(
        context,
        categoryId: StockpileTagCategories.itemType,
        name: name,
      ),
      buildResult: (ids, changed) =>
          TagPickerResult(selectedIds: ids, tagsChanged: changed),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedItemTypeTagIds = selected.selectedIds);
    _rebuildAllSelectedTagIds();

    if (selected.tagsChanged) {
      await _loadTagOptions();
    }
  }

  Future<void> _pickLocation() async {
    final initial = _selectedLocationTagId == null
        ? <int>{}
        : {_selectedLocationTagId!};
    final selected = await TagPickerSheetView.show<TagPickerResult>(
      context,
      title: '选择位置',
      tags: _locationTags,
      selectedIds: initial,
      multi: false,
      keyPrefix: 'stockpile-location',
      createHint: StockpileTagUtils.createHint(
        context,
        StockpileTagCategories.location,
      ),
      onCreateTag: (name) => StockpileTagUtils.createTag(
        context,
        categoryId: StockpileTagCategories.location,
        name: name,
      ),
      buildResult: (ids, changed) =>
          TagPickerResult(selectedIds: ids, tagsChanged: changed),
    );
    if (selected == null || !mounted) return;

    final id = selected.selectedIds.isEmpty ? null : selected.selectedIds.first;
    setState(() => _selectedLocationTagId = id);
    if (id != null) {
      final name = _tagsById[id]?.name;
      if (name != null) {
        setControllerTextWhenComposingIdle(
          _locationController,
          name,
          shouldContinue: () => mounted,
        );
      }
    }
    _rebuildAllSelectedTagIds();

    if (selected.tagsChanged) {
      await _loadTagOptions();
    }
  }

  void _rebuildAllSelectedTagIds() {
    final next = <int>{..._selectedItemTypeTagIds};
    final locationId = _selectedLocationTagId;
    if (locationId != null) next.add(locationId);
    if (!setEquals(next, _selectedTagIds)) {
      setState(() => _selectedTagIds = next);
    }
  }

  void _syncTagSelectionsFromAll() {
    if (_locationTags.isEmpty && _itemTypeTags.isEmpty) return;

    final locationIds = _locationTags.map((e) => e.id).whereType<int>().toSet();
    final selectedLocationIds = _selectedTagIds.where(locationIds.contains);
    _selectedLocationTagId = selectedLocationIds.isEmpty
        ? null
        : selectedLocationIds.first;
    _selectedItemTypeTagIds = {
      for (final id in _selectedTagIds)
        if (!locationIds.contains(id)) id,
    };

    // 兼容历史数据：若已有 location 文本，尝试自动匹配同名位置标签。
    if (_selectedLocationTagId == null) {
      final legacy = _locationController.text.trim();
      if (legacy.isNotEmpty) {
        for (final t in _locationTags) {
          final id = t.id;
          if (id != null && t.name.trim() == legacy) {
            _selectedLocationTagId = id;
            _selectedItemTypeTagIds.remove(id);
            _selectedTagIds.add(id);
            break;
          }
        }
      }
    }

    final locationId = _selectedLocationTagId;
    if (locationId != null) {
      final name = _tagsById[locationId]?.name.trim();
      if (name != null && name.isNotEmpty) {
        setControllerTextWhenComposingIdle(
          _locationController,
          name,
          shouldContinue: () => mounted,
        );
      }
    }
  }

  Future<void> _loadTagOptions() async {
    if (_loadingTags) return;
    setState(() => _loadingTags = true);
    try {
      final tagService = context.read<TagService>();
      final itemTypeTags = await tagService.listTagsForToolCategory(
        toolId: StockpileConstants.toolId,
        categoryId: StockpileTagCategories.itemType,
      );
      final locationTags = await tagService.listTagsForToolCategory(
        toolId: StockpileConstants.toolId,
        categoryId: StockpileTagCategories.location,
      );
      final all = await tagService.listTagsForTool(StockpileConstants.toolId);

      setState(() {
        _itemTypeTags = itemTypeTags;
        _locationTags = locationTags;
        _tagsById = {
          for (final t in all)
            if (t.id != null) t.id!: t,
        };
      });
      _syncTagSelectionsFromAll();
      _rebuildAllSelectedTagIds();
    } catch (_) {
      // 测试/极端情况下（例如页面已销毁或数据库关闭）直接忽略，避免抛出异步异常。
    } finally {
      if (mounted) setState(() => _loadingTags = false);
    }
  }

  Widget _buildExpirySection() {
    final dateText = _expiryDate == null
        ? '未设置'
        : StockpileFormat.date(_expiryDate!);
    final remindEnabled = _expiryDate != null;

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('到期提醒', style: IOS26Theme.bodySmall),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInlineLabeledField(
                  label: '到期日',
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: CupertinoButton(
                      key: const ValueKey('stock_item_expiry_date'),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final initial =
                            _expiryDate ??
                            DateTime.now().add(const Duration(days: 7));
                        _pickDate(
                          initial: initial,
                          onSelected: (v) => setState(() => _expiryDate = v),
                        );
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: IOS26Theme.bodySmall.copyWith(
                                color: _expiryDate == null
                                    ? IOS26Theme.textTertiary
                                    : IOS26Theme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_expiryDate != null)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => setState(() {
                                _expiryDate = null;
                                _remindDaysController.text = '';
                              }),
                              child: Icon(
                                CupertinoIcons.clear_circled_solid,
                                size: 18,
                                color: IOS26Theme.textTertiary,
                              ),
                            )
                          else
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: IOS26Theme.textTertiary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInlineLabeledField(
                  label: '临期提前提醒(天)',
                  child: AbsorbPointer(
                    absorbing: !remindEnabled,
                    child: Opacity(
                      opacity: remindEnabled ? 1 : 0.45,
                      child: _buildTextField(
                        key: const ValueKey('stock_item_remind_days'),
                        controller: _remindDaysController,
                        placeholder: '不提醒',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestockSection() {
    final dateText = _restockRemindDate == null
        ? '未设置'
        : StockpileFormat.date(_restockRemindDate!);

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('补货提醒', style: IOS26Theme.bodySmall),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInlineLabeledField(
                  label: '补货提醒日期',
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: CupertinoButton(
                      key: const ValueKey('stock_item_restock_date'),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final initial =
                            _restockRemindDate ??
                            DateTime.now().add(const Duration(days: 7));
                        _pickDate(
                          initial: initial,
                          onSelected: (v) =>
                              setState(() => _restockRemindDate = v),
                        );
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: IOS26Theme.bodySmall.copyWith(
                                color: _restockRemindDate == null
                                    ? IOS26Theme.textTertiary
                                    : IOS26Theme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_restockRemindDate != null)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => setState(() {
                                _restockRemindDate = null;
                              }),
                              child: Icon(
                                CupertinoIcons.clear_circled_solid,
                                size: 18,
                                color: IOS26Theme.textTertiary,
                              ),
                            )
                          else
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: IOS26Theme.textTertiary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInlineLabeledField(
                  label: '提醒库存',
                  child: _buildTextField(
                    key: const ValueKey('stock_item_restock_quantity'),
                    controller: _restockQuantityController,
                    placeholder: '不提醒',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required String title,
    required Widget child,
    bool compact = false,
  }) {
    return GlassContainer(
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: IOS26Theme.bodySmall),
          SizedBox(height: compact ? 8 : 10),
          child,
        ],
      ),
    );
  }

  Widget _buildInlineLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: IOS26Theme.bodySmall),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDateRow({
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: IOS26Theme.bodyMedium.copyWith(
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            Text(value, style: IOS26Theme.bodyMedium),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: IOS26Theme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    String placeholder = '',
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: CupertinoTextField(
        key: key,
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: null,
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        var temp = DateTime(initial.year, initial.month, initial.day);
        return Container(
          height: 300,
          color: IOS26Theme.surfaceColor,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    CupertinoButton(
                      key: const ValueKey('stock_item_pick_date_done'),
                      onPressed: () {
                        onSelected(temp);
                        Navigator.pop(context);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: temp,
                  onDateTimeChanged: (value) => temp = value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '请输入名称',
      );
      return;
    }

    final total = double.tryParse(_totalController.text.trim());
    final remaining = double.tryParse(_remainingController.text.trim());
    if (total == null || remaining == null) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '请输入正确的数量',
      );
      return;
    }
    if (total < 0 || remaining < 0) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '数量不能小于 0',
      );
      return;
    }
    if (remaining > total) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '剩余数量不能大于总数量',
      );
      return;
    }

    final hasExpiry = _expiryDate != null;
    var remindDays = -1;
    if (hasExpiry) {
      final text = _remindDaysController.text.trim();
      if (text.isEmpty) {
        remindDays = -1;
      } else {
        final parsed = int.tryParse(text);
        if (parsed == null) {
          await StockpileDialogs.showMessage(
            context,
            title: '提示',
            content: '请输入正确的提前提醒天数（留空表示不提醒）',
          );
          return;
        }
        if (parsed < 0) {
          await StockpileDialogs.showMessage(
            context,
            title: '提示',
            content: '提前提醒天数不能小于 0（留空表示不提醒）',
          );
          return;
        }
        remindDays = parsed;
      }
    }

    final restockQtyText = _restockQuantityController.text.trim();
    double? restockRemindQuantity;
    if (restockQtyText.isNotEmpty) {
      final parsed = double.tryParse(restockQtyText);
      if (parsed == null) {
        await StockpileDialogs.showMessage(
          context,
          title: '提示',
          content: '请输入正确的提醒库存（留空表示不提醒）',
        );
        return;
      }
      if (parsed < 0) {
        await StockpileDialogs.showMessage(
          context,
          title: '提示',
          content: '提醒库存不能小于 0（留空表示不提醒）',
        );
        return;
      }
      if (parsed > total) {
        await StockpileDialogs.showMessage(
          context,
          title: '提示',
          content: '提醒库存不能大于总数量',
        );
        return;
      }
      restockRemindQuantity = parsed;
    }

    final now = DateTime.now();
    final editing = _editing;
    int? itemId;
    final messageService = context.read<MessageService>();

    try {
      if (editing == null) {
        itemId = await _service.createItem(
          StockItem.create(
            name: name,
            location: _locationController.text,
            unit: _unitController.text,
            totalQuantity: total,
            remainingQuantity: remaining,
            purchaseDate: _purchaseDate,
            expiryDate: hasExpiry ? _expiryDate : null,
            remindDays: remindDays,
            restockRemindDate: _restockRemindDate,
            restockRemindQuantity: restockRemindQuantity,
            note: _noteController.text,
            now: now,
          ),
        );
      } else {
        itemId = editing.id;
        await _service.updateItem(
          editing.copyWith(
            name: name,
            location: _locationController.text.trim(),
            unit: _unitController.text.trim(),
            totalQuantity: total,
            remainingQuantity: remaining,
            purchaseDate: _purchaseDate,
            expiryDate: hasExpiry ? _expiryDate : null,
            remindDays: remindDays,
            restockRemindDate: _restockRemindDate,
            restockRemindQuantity: restockRemindQuantity,
            note: _noteController.text.trim(),
            updatedAt: now,
          ),
        );
      }

      if (itemId != null) {
        await _service.setTagsForItem(itemId, _selectedTagIds.toList());
        final item = await _service.getItem(itemId);
        if (item != null) {
          await StockpileReminderService().syncReminderForItem(
            messageService: messageService,
            item: item,
            now: now,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      await StockpileDialogs.showMessage(
        context,
        title: '保存失败',
        content: e.toString(),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
