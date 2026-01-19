import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/messages/message_service.dart';
import '../../../core/tags/models/tag.dart';
import '../../../core/theme/ios26_theme.dart';
import '../ai/stockpile_ai_intent.dart';
import '../models/stock_consumption.dart';
import '../models/stock_item.dart';
import '../models/stockpile_drafts.dart';
import '../services/stockpile_reminder_service.dart';
import '../services/stockpile_service.dart';
import '../utils/stockpile_utils.dart';

class StockpileAiBatchEntryPage extends StatefulWidget {
  final List<StockItemDraft> initialItems;
  final List<StockpileAiConsumptionEntry> initialConsumptions;

  const StockpileAiBatchEntryPage({
    super.key,
    required this.initialItems,
    required this.initialConsumptions,
  });

  @override
  State<StockpileAiBatchEntryPage> createState() =>
      _StockpileAiBatchEntryPageState();
}

class _StockpileAiBatchEntryPageState extends State<StockpileAiBatchEntryPage> {
  int _tab = 0; // 0=items, 1=consumptions

  var _nextItemKey = 0;
  var _nextConsumptionKey = 0;

  late final List<_ItemEntry> _items = widget.initialItems
      .map(_createItemEntry)
      .toList(growable: true);
  late final List<_ConsumptionEntry> _consumptions = widget.initialConsumptions
      .map(_createConsumptionEntry)
      .toList(growable: true);

  bool _saving = false;

  _ItemEntry _createItemEntry(StockItemDraft draft) {
    return _ItemEntry.fromDraft(keyId: _nextItemKey++, draft: draft);
  }

  _ConsumptionEntry _createConsumptionEntry(StockpileAiConsumptionEntry entry) {
    return _ConsumptionEntry.fromDraft(
      keyId: _nextConsumptionKey++,
      entry: entry,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialItems.isEmpty && widget.initialConsumptions.isNotEmpty) {
      _tab = 1;
    } else if (widget.initialConsumptions.isEmpty &&
        widget.initialItems.isNotEmpty) {
      _tab = 0;
    }

    final service = context.read<StockpileService>();
    Future<void>.microtask(() async {
      for (final entry in _consumptions) {
        final id = entry.resolvedItemId ?? entry.itemRef.id;
        if (id == null) continue;
        final item = await service.getItem(id);
        if (!mounted) return;
        setState(() {
          entry.remainingQuantity = item?.remainingQuantity;
          entry.unit = item?.unit;
        });
      }
    });
  }

  @override
  void dispose() {
    for (final e in _items) {
      e.dispose();
    }
    for (final e in _consumptions) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsCount = _items.length;
    final consumptionsCount = _consumptions.length;

    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: 'AI 批量录入',
        showBackButton: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tab,
                onValueChanged: (v) => setState(() => _tab = v ?? 0),
                children: {
                  0: Text('物品 $itemsCount'),
                  1: Text('消耗 $consumptionsCount'),
                },
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: _tab == 0
                      ? _buildItemList()
                      : _buildConsumptionList(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              key: const ValueKey('stockpile_ai_batch_save'),
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: IOS26Theme.primaryColor,
              borderRadius: BorderRadius.circular(14),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text(
                      '保存',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItemList() {
    final widgets = <Widget>[];

    if (_items.isEmpty) {
      widgets.add(
        GlassContainer(
          padding: const EdgeInsets.all(12),
          child: const Text(
            '暂无物品条目，可在下方增加物品',
            style: TextStyle(fontSize: 14, color: IOS26Theme.textSecondary),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    for (final entry in _items) {
      widgets.add(_buildItemEntry(entry));
      widgets.add(const SizedBox(height: 12));
    }

    widgets.add(
      _buildAddEntryRow(
        key: const ValueKey('stockpile_ai_batch_add_item'),
        text: '增加物品',
        icon: CupertinoIcons.add_circled_solid,
        color: IOS26Theme.toolGreen,
        onPressed: _saving
            ? null
            : () => setState(() {
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
                }),
      ),
    );

    return widgets;
  }

  Widget _buildItemEntry(_ItemEntry entry) {
    return GlassContainer(
      key: ValueKey('stockpile_ai_batch_item_${entry.keyId}'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              key: ValueKey('stockpile_ai_batch_item_${entry.keyId}_delete'),
              padding: EdgeInsets.zero,
              onPressed: _saving
                  ? null
                  : () async {
                      final ok = await _confirmDelete(
                        title: '确认删除',
                        content: '确认删除该物品条目？',
                      );
                      if (!ok || !mounted) return;
                      setState(() {
                        _items.remove(entry);
                        entry.dispose();
                      });
                    },
              child: const Icon(
                CupertinoIcons.trash,
                size: 18,
                color: IOS26Theme.toolRed,
              ),
            ),
          ),
          _buildCompactField(
            title: '名称',
            child: _buildTextField(
              key: ValueKey('stockpile_ai_batch_item_${entry.keyId}_name'),
              controller: entry.nameController,
              placeholder: '如：牛奶',
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 10),
          _buildTwoColRow(
            left: _buildCompactField(
              title: '位置',
              child: _buildTextField(
                key: ValueKey(
                  'stockpile_ai_batch_item_${entry.keyId}_location',
                ),
                controller: entry.locationController,
                placeholder: '如：冰箱',
                textInputAction: TextInputAction.next,
              ),
            ),
            right: _buildCompactField(
              title: '单位',
              child: _buildTextField(
                key: ValueKey('stockpile_ai_batch_item_${entry.keyId}_unit'),
                controller: entry.unitController,
                placeholder: '如：盒',
                textInputAction: TextInputAction.next,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildTwoColRow(
            left: _buildCompactField(
              title: '总数量',
              child: _buildTextField(
                key: ValueKey('stockpile_ai_batch_item_${entry.keyId}_total'),
                controller: entry.totalController,
                placeholder: '1',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
            right: _buildCompactField(
              title: '剩余数量',
              child: _buildTextField(
                key: ValueKey(
                  'stockpile_ai_batch_item_${entry.keyId}_remaining',
                ),
                controller: entry.remainingController,
                placeholder: '1',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildPickerRow(
            title: '采购日期',
            value: StockpileFormat.date(entry.purchaseDate),
            onTap: _saving
                ? null
                : () => _pickDate(
                    initial: entry.purchaseDate,
                    onSelected: (v) => setState(() => entry.purchaseDate = v),
                  ),
          ),
          const SizedBox(height: 10),
          _buildExpiryInlineRow(entry),
          const SizedBox(height: 10),
          _buildRestockInlineRow(entry),
          const SizedBox(height: 10),
          _buildTagSelector(entry),
          const SizedBox(height: 10),
          _buildCompactField(
            title: '备注',
            child: _buildTextField(
              key: ValueKey('stockpile_ai_batch_item_${entry.keyId}_note'),
              controller: entry.noteController,
              placeholder: '可选',
              maxLines: 2,
              textInputAction: TextInputAction.newline,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildConsumptionList() {
    final widgets = <Widget>[];

    if (_consumptions.isEmpty) {
      widgets.add(
        GlassContainer(
          padding: const EdgeInsets.all(12),
          child: const Text(
            '暂无消耗条目，可在下方增加消耗',
            style: TextStyle(fontSize: 14, color: IOS26Theme.textSecondary),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    for (final entry in _consumptions) {
      widgets.add(_buildConsumptionEntry(entry));
      widgets.add(const SizedBox(height: 12));
    }

    widgets.add(
      _buildAddEntryRow(
        key: const ValueKey('stockpile_ai_batch_add_consumption'),
        text: '增加消耗',
        icon: CupertinoIcons.add_circled_solid,
        color: IOS26Theme.toolOrange,
        onPressed: _saving
            ? null
            : () => setState(() {
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
                }),
      ),
    );

    return widgets;
  }

  Widget _buildConsumptionEntry(_ConsumptionEntry entry) {
    return GlassContainer(
      key: ValueKey('stockpile_ai_batch_consumption_${entry.keyId}'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '消耗',
                style: TextStyle(fontSize: 13, color: IOS26Theme.textSecondary),
              ),
              const Spacer(),
              CupertinoButton(
                key: ValueKey(
                  'stockpile_ai_batch_consumption_${entry.keyId}_delete',
                ),
                padding: EdgeInsets.zero,
                onPressed: _saving
                    ? null
                    : () async {
                        final ok = await _confirmDelete(
                          title: '确认删除',
                          content: '确认删除该消耗条目？',
                        );
                        if (!ok || !mounted) return;
                        setState(() {
                          _consumptions.remove(entry);
                          entry.dispose();
                        });
                      },
                child: const Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: IOS26Theme.toolRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildConsumptionItemRow(entry),
          const SizedBox(height: 10),
          _buildInlineField(
            title: '消耗数量',
            child: _buildTextField(
              key: ValueKey(
                'stockpile_ai_batch_consumption_${entry.keyId}_qty',
              ),
              controller: entry.qtyController,
              placeholder: '1',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 10),
          _buildPickerRow(
            title: '消耗时间',
            value: StockpileFormat.dateTime(entry.consumedAt),
            onTap: _saving
                ? null
                : () => _pickDateTime(
                    initial: entry.consumedAt,
                    onSelected: (v) => setState(() => entry.consumedAt = v),
                  ),
          ),
          const SizedBox(height: 10),
          _buildInlineField(
            title: '备注',
            child: _buildTextField(
              key: ValueKey(
                'stockpile_ai_batch_consumption_${entry.keyId}_note',
              ),
              controller: entry.noteController,
              placeholder: '可选',
              maxLines: 1,
              textInputAction: TextInputAction.done,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsumptionItemRow(_ConsumptionEntry entry) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _saving ? null : () => _pickItemForConsumption(entry),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.cube_box_fill,
                    size: 18,
                    color: IOS26Theme.toolGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.displayItemText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: IOS26Theme.textPrimary,
                      ),
                    ),
                  ),
                  if (entry.remainingQuantity != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      '库存：${StockpileFormat.num(entry.remainingQuantity!)}${entry.unitText}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: IOS26Theme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: IOS26Theme.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColRow({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: w, child: left),
            const SizedBox(width: 10),
            SizedBox(width: w, child: right),
          ],
        );
      },
    );
  }

  Widget _buildPickerRow({
    required String title,
    required String value,
    required VoidCallback? onTap,
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
                style: const TextStyle(
                  fontSize: 13,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: IOS26Theme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: IOS26Theme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddEntryRow({
    required Key key,
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: CupertinoButton(
        key: key,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: IOS26Theme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryInlineRow(_ItemEntry entry) {
    final dateText = entry.expiryDate == null
        ? '未设置'
        : StockpileFormat.date(entry.expiryDate!);
    final remindEnabled = entry.expiryDate != null && !_saving;

    return _buildTwoColRow(
      left: _buildCompactField(
        title: '到期日',
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _saving
                ? null
                : () {
                    final initial =
                        entry.expiryDate ??
                        DateTime.now().add(const Duration(days: 7));
                    _pickDate(
                      initial: initial,
                      onSelected: (v) => setState(() => entry.expiryDate = v),
                    );
                  },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: entry.expiryDate == null
                          ? IOS26Theme.textTertiary
                          : IOS26Theme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (entry.expiryDate != null && !_saving)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() {
                      entry.expiryDate = null;
                      entry.remindDaysController.text = '';
                    }),
                    child: const Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 18,
                      color: IOS26Theme.textTertiary,
                    ),
                  )
                else
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: IOS26Theme.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
      right: _buildCompactField(
        title: '提前提醒(天)',
        child: AbsorbPointer(
          absorbing: !remindEnabled,
          child: Opacity(
            opacity: remindEnabled ? 1 : 0.45,
            child: _buildTextField(
              key: ValueKey(
                'stockpile_ai_batch_item_${entry.keyId}_remind_days',
              ),
              controller: entry.remindDaysController,
              placeholder: '不提醒',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestockInlineRow(_ItemEntry entry) {
    final dateText = entry.restockRemindDate == null
        ? '未设置'
        : StockpileFormat.date(entry.restockRemindDate!);

    return _buildTwoColRow(
      left: _buildCompactField(
        title: '提醒日期',
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _saving
                ? null
                : () {
                    final initial =
                        entry.restockRemindDate ??
                        DateTime.now().add(const Duration(days: 7));
                    _pickDate(
                      initial: initial,
                      onSelected: (v) =>
                          setState(() => entry.restockRemindDate = v),
                    );
                  },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: entry.restockRemindDate == null
                          ? IOS26Theme.textTertiary
                          : IOS26Theme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (entry.restockRemindDate != null && !_saving)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => entry.restockRemindDate = null),
                    child: const Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 18,
                      color: IOS26Theme.textTertiary,
                    ),
                  )
                else
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: IOS26Theme.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
      right: _buildCompactField(
        title: '提醒库存',
        child: _buildTextField(
          key: ValueKey('stockpile_ai_batch_item_${entry.keyId}_restock_qty'),
          controller: entry.restockQuantityController,
          placeholder: '不提醒',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
        ),
      ),
    );
  }

  Widget _buildTagSelector(_ItemEntry entry) {
    return Consumer<StockpileService>(
      builder: (context, service, _) {
        final tags = service.availableTags.where((e) => e.id != null).toList();
        if (tags.isEmpty) {
          return GlassContainer(
            padding: const EdgeInsets.all(12),
            child: const Text(
              '暂无可用标签（可在「标签管理」中创建并关联到「囤货助手」）',
              style: TextStyle(fontSize: 13, color: IOS26Theme.textSecondary),
            ),
          );
        }

        return GlassContainer(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '标签',
                style: TextStyle(fontSize: 13, color: IOS26Theme.textSecondary),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tag in tags) ...[
                      _buildTagPill(tag, entry),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagPill(Tag tag, _ItemEntry entry) {
    final id = tag.id;
    if (id == null) return const SizedBox.shrink();

    final selected = entry.selectedTagIds.contains(id);
    final bgColor = selected
        ? IOS26Theme.primaryColor
        : IOS26Theme.surfaceColor.withValues(alpha: 0.65);
    final borderColor = selected
        ? IOS26Theme.primaryColor
        : IOS26Theme.textTertiary.withValues(alpha: 0.4);
    final textColor = selected ? Colors.white : IOS26Theme.textPrimary;
    final dotColor = tag.color == null
        ? IOS26Theme.textTertiary
        : Color(tag.color!);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _saving
          ? null
          : () {
              setState(() {
                if (selected) {
                  entry.selectedTagIds.remove(id);
                } else {
                  entry.selectedTagIds.add(id);
                }
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                size: 18,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineField({required String title, required Widget child}) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: IOS26Theme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete({
    required String title,
    required String content,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(content),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
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

  Future<void> _pickDateTime({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        var temp = initial;
        return Container(
          height: 320,
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
                  mode: CupertinoDatePickerMode.dateAndTime,
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

  Future<void> _pickItemForConsumption(_ConsumptionEntry entry) async {
    final service = context.read<StockpileService>();
    final items = await service.listAllItemsForAiContext();
    final candidates = items.where((e) => e.id != null).toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '本地暂无物品，请先新增物品后再记录消耗。',
      );
      return;
    }

    final selected = await showCupertinoModalPopup<int?>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('选择物品'),
        actions: [
          for (final item in candidates)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, item.id),
              child: Text(item.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final item = candidates.firstWhere((e) => e.id == selected);
    setState(() {
      entry.resolvedItemId = selected;
      entry.itemRef = StockpileAiItemRef(id: selected, name: item.name);
      entry.remainingQuantity = item.remainingQuantity;
      entry.unit = item.unit;
    });
  }

  Widget _buildCompactField({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: IOS26Theme.textSecondary),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required String placeholder,
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final service = context.read<StockpileService>();
    MessageService? messageService;
    try {
      messageService = context.read<MessageService>();
    } on ProviderNotFoundException {
      messageService = null;
    }

    final now = DateTime.now();
    try {
      final createdNameToIds = <String, List<int>>{};

      for (final entry in _items) {
        final name = entry.nameController.text.trim();
        if (name.isEmpty) {
          throw const _UserReadableError('请填写所有物品的「名称」。');
        }

        final total = double.tryParse(entry.totalController.text.trim());
        final remaining = double.tryParse(
          entry.remainingController.text.trim(),
        );
        if (total == null || remaining == null) {
          throw const _UserReadableError('请填写正确的物品数量（总数量/剩余数量）。');
        }
        if (total < 0 || remaining < 0) {
          throw const _UserReadableError('物品数量不能小于 0。');
        }
        if (remaining > total) {
          throw const _UserReadableError('物品剩余数量不能大于总数量。');
        }

        final expiryDate = entry.expiryDate;
        final remindText = entry.remindDaysController.text.trim();
        int remindDays;
        if (expiryDate == null) {
          remindDays = -1;
        } else if (remindText.isEmpty) {
          remindDays = -1;
        } else {
          final parsed = int.tryParse(remindText);
          if (parsed == null || parsed < 0) {
            throw const _UserReadableError('提醒天数必须是 >=0 的整数（留空表示不提醒）。');
          }
          remindDays = parsed;
        }

        final restockQtyText = entry.restockQuantityController.text.trim();
        double? restockRemindQuantity;
        if (restockQtyText.isNotEmpty) {
          final parsed = double.tryParse(restockQtyText);
          if (parsed == null || parsed < 0) {
            throw const _UserReadableError('提醒库存必须是 >=0 的数字（留空表示不提醒）。');
          }
          if (parsed > total) {
            throw const _UserReadableError('提醒库存不能大于总数量。');
          }
          restockRemindQuantity = parsed;
        }

        final itemId = await service.createItem(
          StockItem.create(
            name: name,
            location: entry.locationController.text,
            unit: entry.unitController.text,
            totalQuantity: total,
            remainingQuantity: remaining,
            purchaseDate: entry.purchaseDate,
            expiryDate: expiryDate,
            remindDays: remindDays,
            restockRemindDate: entry.restockRemindDate,
            restockRemindQuantity: restockRemindQuantity,
            note: entry.noteController.text,
            now: now,
          ),
        );

        await service.setTagsForItem(itemId, entry.selectedTagIds.toList());
        createdNameToIds.update(
          name,
          (v) => [...v, itemId],
          ifAbsent: () => [itemId],
        );

        if (messageService != null) {
          final item = await service.getItem(itemId);
          if (item != null) {
            await StockpileReminderService().syncReminderForItem(
              messageService: messageService,
              item: item,
              now: now,
            );
          }
        }
      }

      if (_consumptions.isNotEmpty) {
        final existingItems = await service.listAllItemsForAiContext();
        final existingNameToIds = <String, List<int>>{};
        for (final item in existingItems) {
          final id = item.id;
          if (id == null) continue;
          final name = item.name.trim();
          if (name.isEmpty) continue;
          existingNameToIds.update(
            name,
            (v) => [...v, id],
            ifAbsent: () => [id],
          );
        }

        for (final entry in _consumptions) {
          final qty = double.tryParse(entry.qtyController.text.trim());
          if (qty == null || qty <= 0) {
            throw const _UserReadableError('请填写正确的消耗数量（必须 > 0）。');
          }

          final itemId = await _resolveConsumptionItemId(
            entry: entry,
            createdNameToIds: createdNameToIds,
            existingNameToIds: existingNameToIds,
          );
          if (itemId == null) {
            throw const _UserReadableError('存在未完成的消耗条目，请先处理。');
          }

          final item = await service.getItem(itemId);
          final remaining = item?.remainingQuantity;
          if (remaining != null && qty > remaining) {
            throw _UserReadableError('消耗数量不能超过「${item?.name ?? ''}」的剩余库存。');
          }

          await service.createConsumption(
            StockConsumption.create(
              itemId: itemId,
              quantity: qty,
              method: '',
              consumedAt: entry.consumedAt,
              note: entry.noteController.text,
              now: now,
            ),
          );

          if (messageService != null) {
            final updated = await service.getItem(itemId);
            if (updated != null) {
              await StockpileReminderService().syncReminderForItem(
                messageService: messageService,
                item: updated,
                now: now,
              );
            }
          }
        }
      }
    } on _UserReadableError catch (e) {
      if (!mounted) return;
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: e.message,
      );
      setState(() => _saving = false);
      return;
    } catch (e) {
      if (!mounted) return;
      await StockpileDialogs.showMessage(
        context,
        title: '保存失败',
        content: e.toString(),
      );
      setState(() => _saving = false);
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<int?> _resolveConsumptionItemId({
    required _ConsumptionEntry entry,
    required Map<String, List<int>> createdNameToIds,
    required Map<String, List<int>> existingNameToIds,
  }) async {
    final resolved = entry.resolvedItemId;
    if (resolved != null) return resolved;

    final id = entry.itemRef.id;
    if (id != null) return id;

    final name = entry.itemRef.name?.trim();
    if (name == null || name.isEmpty) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '存在未指定物品的消耗条目，请先为其选择物品。',
      );
      return null;
    }

    final createdCandidates = createdNameToIds[name] ?? const <int>[];
    if (createdCandidates.length == 1) return createdCandidates.single;
    final existingCandidates = existingNameToIds[name] ?? const <int>[];
    if (existingCandidates.length == 1) return existingCandidates.single;

    final candidates = [
      ...createdCandidates.map((id) => _ItemCandidate(id: id, name: name)),
      ...existingCandidates.map((id) => _ItemCandidate(id: id, name: name)),
    ];
    if (candidates.isEmpty) {
      await StockpileDialogs.showMessage(
        context,
        title: '未找到物品',
        content: '未在本地找到「$name」，请先新增该物品或手动选择物品。',
      );
      return null;
    }

    if (!mounted) return null;
    final picked = await showCupertinoModalPopup<int?>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('选择物品'),
        message: Text('「$name」匹配到多个物品，请选择一个：'),
        actions: [
          for (final c in candidates)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, c.id),
              child: Text('${c.name}（id=${c.id}）'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (picked == null) return null;
    setState(() => entry.resolvedItemId = picked);
    return picked;
  }
}

class _ItemCandidate {
  final int id;
  final String name;
  const _ItemCandidate({required this.id, required this.name});
}

class _UserReadableError implements Exception {
  final String message;
  const _UserReadableError(this.message);
}

class _ItemEntry {
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

  _ItemEntry._(this.keyId);

  factory _ItemEntry.fromDraft({
    required int keyId,
    required StockItemDraft draft,
  }) {
    final e = _ItemEntry._(keyId);
    e.nameController.text = draft.name;
    e.locationController.text = draft.location;
    e.unitController.text = draft.unit;
    e.totalController.text = StockpileFormat.num(draft.totalQuantity);
    e.remainingController.text = StockpileFormat.num(draft.remainingQuantity);
    e.remindDaysController.text =
        draft.expiryDate == null || draft.remindDays < 0
            ? ''
            : draft.remindDays.toString();
    e.restockQuantityController.text =
        draft.restockRemindQuantity == null
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

class _ConsumptionEntry {
  final int keyId;

  StockpileAiItemRef itemRef = const StockpileAiItemRef();
  int? resolvedItemId;
  double? remainingQuantity;
  String? unit;

  final qtyController = TextEditingController(text: '1');
  final noteController = TextEditingController();
  DateTime consumedAt = DateTime.now();

  _ConsumptionEntry._(this.keyId);

  factory _ConsumptionEntry.fromDraft({
    required int keyId,
    required StockpileAiConsumptionEntry entry,
  }) {
    final e = _ConsumptionEntry._(keyId);
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
