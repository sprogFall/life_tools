import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/messages/message_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../ai/stockpile_ai_intent.dart';
import '../models/stock_consumption.dart';
import '../models/stock_item.dart';
import '../providers/stockpile_batch_entry_provider.dart';
import '../services/stockpile_reminder_service.dart';
import '../services/stockpile_service.dart';
import '../utils/stockpile_utils.dart';
import '../widgets/stockpile_batch_entry_ui.dart';
import '../widgets/stockpile_batch_item_row.dart';

class StockpileAiBatchEntryView extends StatelessWidget {
  const StockpileAiBatchEntryView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockpileBatchEntryProvider>();
    final itemsCount = provider.items.length;
    final consumptionsCount = provider.consumptions.length;

    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: const IOS26AppBar(title: 'AI 批量录入', showBackButton: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IOS26Theme.spacingLg,
                IOS26Theme.spacingMd,
                IOS26Theme.spacingLg,
                IOS26Theme.spacingSm,
              ),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: provider.tab,
                onValueChanged: (v) =>
                    context.read<StockpileBatchEntryProvider>().setTab(v ?? 0),
                children: {
                  0: Text('物品 $itemsCount'),
                  1: Text('消耗 $consumptionsCount'),
                },
              ),
            ),
            const SizedBox(height: IOS26Theme.spacingSm),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  IOS26Theme.spacingLg,
                  0,
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingLg,
                ),
                child: Column(
                  children: provider.tab == 0
                      ? _buildItemList(context, provider)
                      : _buildConsumptionList(context, provider),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            IOS26Theme.spacingLg,
            IOS26Theme.spacingMd,
            IOS26Theme.spacingLg,
            IOS26Theme.spacingLg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: IOS26Button(
              key: const ValueKey('stockpile_ai_batch_save'),
              padding: const EdgeInsets.symmetric(
                vertical: IOS26Theme.spacingLg,
              ),
              variant: IOS26ButtonVariant.primary,
              borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
              onPressed: provider.saving ? null : () => _save(context),
              child: provider.saving
                  ? const IOS26ButtonLoadingIndicator()
                  : IOS26ButtonLabel('保存', style: IOS26Theme.labelLarge),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItemList(
    BuildContext context,
    StockpileBatchEntryProvider provider,
  ) {
    final widgets = <Widget>[];

    if (provider.items.isEmpty) {
      widgets.add(
        GlassContainer(
          padding: const EdgeInsets.all(IOS26Theme.spacingMd),
          child: Text('暂无物品条目，可在下方增加物品', style: IOS26Theme.bodyMedium),
        ),
      );
      widgets.add(const SizedBox(height: IOS26Theme.spacingMd));
    }

    for (final entry in provider.items) {
      widgets.add(StockpileBatchItemRow(entry: entry));
      widgets.add(const SizedBox(height: IOS26Theme.spacingMd));
    }

    widgets.add(
      StockpileBatchEntryAddRow(
        buttonKey: const ValueKey('stockpile_ai_batch_add_item'),
        text: '增加物品',
        icon: CupertinoIcons.add_circled_solid,
        color: IOS26Theme.toolGreen,
        onPressed: provider.saving
            ? null
            : () => context.read<StockpileBatchEntryProvider>().addEmptyItem(),
      ),
    );

    return widgets;
  }

  List<Widget> _buildConsumptionList(
    BuildContext context,
    StockpileBatchEntryProvider provider,
  ) {
    final widgets = <Widget>[];

    if (provider.consumptions.isEmpty) {
      widgets.add(
        GlassContainer(
          padding: const EdgeInsets.all(IOS26Theme.spacingMd),
          child: Text('暂无消耗条目，可在下方增加消耗', style: IOS26Theme.bodyMedium),
        ),
      );
      widgets.add(const SizedBox(height: IOS26Theme.spacingMd));
    }

    for (final entry in provider.consumptions) {
      widgets.add(_buildConsumptionEntry(context, entry, provider: provider));
      widgets.add(const SizedBox(height: IOS26Theme.spacingMd));
    }

    widgets.add(
      StockpileBatchEntryAddRow(
        buttonKey: const ValueKey('stockpile_ai_batch_add_consumption'),
        text: '增加消耗',
        icon: CupertinoIcons.add_circled_solid,
        color: IOS26Theme.toolOrange,
        onPressed: provider.saving
            ? null
            : () => context
                  .read<StockpileBatchEntryProvider>()
                  .addEmptyConsumption(),
      ),
    );

    return widgets;
  }

  Widget _buildConsumptionEntry(
    BuildContext context,
    StockpileBatchConsumptionEntry entry, {
    required StockpileBatchEntryProvider provider,
  }) {
    return GlassContainer(
      key: ValueKey('stockpile_ai_batch_consumption_${entry.keyId}'),
      padding: const EdgeInsets.all(IOS26Theme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('消耗', style: IOS26Theme.bodySmall),
              const Spacer(),
              CupertinoButton(
                key: ValueKey(
                  'stockpile_ai_batch_consumption_${entry.keyId}_delete',
                ),
                padding: EdgeInsets.zero,
                minimumSize: IOS26Theme.minimumTapSize,
                onPressed: provider.saving
                    ? null
                    : () async {
                        final ok = await showStockpileConfirmDeleteDialog(
                          context,
                          title: '确认删除',
                          content: '确认删除该消耗条目？',
                        );
                        if (!ok || !context.mounted) return;
                        context
                            .read<StockpileBatchEntryProvider>()
                            .removeConsumption(entry);
                      },
                child: Icon(
                  CupertinoIcons.trash,
                  size: 18,
                  color: IOS26Theme.toolRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildConsumptionItemRow(context, entry, provider: provider),
          const SizedBox(height: IOS26Theme.spacingMd),
          StockpileBatchEntryInlineField(
            title: '消耗数量',
            child: StockpileBatchEntryTextField(
              fieldKey: ValueKey(
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
          const SizedBox(height: IOS26Theme.spacingMd),
          StockpileBatchEntryPickerRow(
            title: '消耗时间',
            value: StockpileFormat.dateTime(entry.consumedAt),
            onTap: provider.saving
                ? null
                : () => showStockpileDateTimePicker(
                    context: context,
                    initial: entry.consumedAt,
                    onSelected: (v) {
                      entry.consumedAt = v;
                      provider.touch();
                    },
                  ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          StockpileBatchEntryInlineField(
            title: '备注',
            child: StockpileBatchEntryTextField(
              fieldKey: ValueKey(
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

  Widget _buildConsumptionItemRow(
    BuildContext context,
    StockpileBatchConsumptionEntry entry, {
    required StockpileBatchEntryProvider provider,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: provider.saving
                  ? null
                  : () => _pickItemForConsumption(context, entry, provider),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.cube_box_fill,
                    size: 18,
                    color: IOS26Theme.toolGreen,
                  ),
                  const SizedBox(width: IOS26Theme.spacingMd),
                  Expanded(
                    child: Text(
                      entry.displayItemText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IOS26Theme.titleSmall,
                    ),
                  ),
                  if (entry.remainingQuantity != null) ...[
                    const SizedBox(width: IOS26Theme.spacingMd),
                    Text(
                      '库存：${StockpileFormat.num(entry.remainingQuantity!)}${entry.unitText}',
                      style: IOS26Theme.bodySmall,
                    ),
                  ],
                  const SizedBox(width: IOS26Theme.spacingSm),
                  Icon(
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

  Future<void> _pickItemForConsumption(
    BuildContext context,
    StockpileBatchConsumptionEntry entry,
    StockpileBatchEntryProvider provider,
  ) async {
    final service = context.read<StockpileService>();
    final items = await service.listAllItemsForAiContext();
    final candidates = items.where((e) => e.id != null).toList();
    if (!context.mounted) return;
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
    if (selected == null || !context.mounted) return;
    final item = candidates.firstWhere((e) => e.id == selected);
    entry.resolvedItemId = selected;
    entry.itemRef = StockpileAiItemRef(id: selected, name: item.name);
    entry.remainingQuantity = item.remainingQuantity;
    entry.unit = item.unit;
    provider.touch();
  }

  Future<void> _save(BuildContext context) async {
    final provider = context.read<StockpileBatchEntryProvider>();
    if (provider.saving) return;
    provider.setSaving(true);

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

      for (final entry in provider.items) {
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

      if (provider.consumptions.isNotEmpty) {
        final existingItems = await service.listAllItemsForAiContext();
        if (!context.mounted) return;
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

        for (final entry in provider.consumptions) {
          final qty = double.tryParse(entry.qtyController.text.trim());
          if (qty == null || qty <= 0) {
            throw const _UserReadableError('请填写正确的消耗数量（必须 > 0）。');
          }

          if (!context.mounted) return;
          final itemId = await _resolveConsumptionItemId(
            context,
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
      if (!context.mounted) return;
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: e.message,
      );
      provider.setSaving(false);
      return;
    } catch (e) {
      if (!context.mounted) return;
      await StockpileDialogs.showMessage(
        context,
        title: '保存失败',
        content: e.toString(),
      );
      provider.setSaving(false);
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context, true);
  }

  Future<int?> _resolveConsumptionItemId(
    BuildContext context, {
    required StockpileBatchConsumptionEntry entry,
    required Map<String, List<int>> createdNameToIds,
    required Map<String, List<int>> existingNameToIds,
  }) async {
    final provider = context.read<StockpileBatchEntryProvider>();

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
    if (picked == null || !context.mounted) return null;
    entry.resolvedItemId = picked;
    provider.touch();
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
