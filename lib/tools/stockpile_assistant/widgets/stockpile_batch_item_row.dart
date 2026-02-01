import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_service.dart';
import '../../../core/tags/widgets/tag_picker_sheet.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/ios26_select_field.dart';
import '../providers/stockpile_batch_entry_provider.dart';
import '../stockpile_constants.dart';
import '../utils/stockpile_tag_utils.dart';
import '../utils/stockpile_utils.dart';
import 'stockpile_batch_entry_ui.dart';

class StockpileBatchItemRow extends StatelessWidget {
  final StockpileBatchItemEntry entry;

  const StockpileBatchItemRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockpileBatchEntryProvider>();
    final saving = provider.saving;
    final itemTypeTags = provider.itemTypeTags
        .where((e) => e.id != null)
        .toList(growable: false);

    return GlassContainer(
      key: ValueKey('stockpile_ai_batch_item_${entry.keyId}'),
      padding: const EdgeInsets.all(IOS26Theme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              key: ValueKey('stockpile_ai_batch_item_${entry.keyId}_delete'),
              padding: EdgeInsets.zero,
              minimumSize: IOS26Theme.minimumTapSize,
              onPressed: saving
                  ? null
                  : () async {
                      final ok = await showStockpileConfirmDeleteDialog(
                        context,
                        title: '确认删除',
                        content: '确认删除该物品条目？',
                      );
                      if (!ok || !context.mounted) return;
                      context.read<StockpileBatchEntryProvider>().removeItem(
                        entry,
                      );
                    },
              child: const Icon(
                CupertinoIcons.trash,
                size: 18,
                color: IOS26Theme.toolRed,
              ),
            ),
          ),
          StockpileBatchEntryCompactField(
            title: '名称',
            child: StockpileBatchEntryTextField(
              fieldKey: ValueKey('stockpile_ai_batch_item_${entry.keyId}_name'),
              controller: entry.nameController,
              placeholder: '如：牛奶',
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          StockpileBatchEntryTwoColRow(
            left: StockpileBatchEntryCompactField(
              title: '位置（来自标签）',
              child: IOS26SelectField(
                buttonKey: ValueKey(
                  'stockpile_ai_batch_item_${entry.keyId}_pick_location',
                ),
                text: _locationLabelForEntry(
                  entry: entry,
                  locationTags: provider.locationTags,
                  tagsById: provider.tagsById,
                ),
                isPlaceholder: _locationIsPlaceholderForEntry(
                  entry: entry,
                  locationTags: provider.locationTags,
                ),
                onPressed: saving
                    ? null
                    : () => _pickLocationForItemEntry(
                        context,
                        entry: entry,
                        provider: context.read<StockpileBatchEntryProvider>(),
                      ),
              ),
            ),
            right: StockpileBatchEntryCompactField(
              title: '单位',
              child: StockpileBatchEntryTextField(
                fieldKey: ValueKey(
                  'stockpile_ai_batch_item_${entry.keyId}_unit',
                ),
                controller: entry.unitController,
                placeholder: '如：盒',
                textInputAction: TextInputAction.next,
              ),
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          StockpileBatchEntryTwoColRow(
            left: StockpileBatchEntryCompactField(
              title: '总数量',
              child: StockpileBatchEntryTextField(
                fieldKey: ValueKey(
                  'stockpile_ai_batch_item_${entry.keyId}_total',
                ),
                controller: entry.totalController,
                placeholder: '1',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
            right: StockpileBatchEntryCompactField(
              title: '剩余数量',
              child: StockpileBatchEntryTextField(
                fieldKey: ValueKey(
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
          const SizedBox(height: IOS26Theme.spacingMd),
          StockpileBatchEntryPickerRow(
            title: '采购日期',
            value: StockpileFormat.date(entry.purchaseDate),
            onTap: saving
                ? null
                : () => showStockpileDatePicker(
                    context: context,
                    initial: entry.purchaseDate,
                    onSelected: (v) {
                      entry.purchaseDate = v;
                      context.read<StockpileBatchEntryProvider>().touch();
                    },
                  ),
          ),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildExpiryInlineRow(context, provider: provider),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildRestockInlineRow(context, provider: provider),
          const SizedBox(height: IOS26Theme.spacingMd),
          _buildTagSelector(context, tags: itemTypeTags, provider: provider),
          const SizedBox(height: IOS26Theme.spacingMd),
          StockpileBatchEntryCompactField(
            title: '备注',
            child: StockpileBatchEntryTextField(
              fieldKey: ValueKey('stockpile_ai_batch_item_${entry.keyId}_note'),
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

  Widget _buildExpiryInlineRow(
    BuildContext context, {
    required StockpileBatchEntryProvider provider,
  }) {
    final saving = provider.saving;
    final dateText = entry.expiryDate == null
        ? '未设置'
        : StockpileFormat.date(entry.expiryDate!);
    final remindEnabled = entry.expiryDate != null && !saving;

    return StockpileBatchEntryTwoColRow(
      left: StockpileBatchEntryCompactField(
        title: '到期日',
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: IOS26Theme.spacingMd,
            vertical: IOS26Theme.spacingSm,
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: saving
                ? null
                : () {
                    final initial =
                        entry.expiryDate ??
                        DateTime.now().add(const Duration(days: 7));
                    showStockpileDatePicker(
                      context: context,
                      initial: initial,
                      onSelected: (v) {
                        entry.expiryDate = v;
                        provider.touch();
                      },
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
                      color: entry.expiryDate == null
                          ? IOS26Theme.textTertiary
                          : IOS26Theme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: IOS26Theme.spacingSm),
                if (entry.expiryDate != null && !saving)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: IOS26Theme.minimumTapSize,
                    onPressed: () {
                      entry.expiryDate = null;
                      entry.remindDaysController.text = '';
                      provider.touch();
                    },
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
      right: StockpileBatchEntryCompactField(
        title: '临期提前提醒(天)',
        child: AbsorbPointer(
          absorbing: !remindEnabled,
          child: Opacity(
            opacity: remindEnabled ? 1 : 0.45,
            child: StockpileBatchEntryTextField(
              fieldKey: ValueKey(
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

  Widget _buildRestockInlineRow(
    BuildContext context, {
    required StockpileBatchEntryProvider provider,
  }) {
    final saving = provider.saving;
    final dateText = entry.restockRemindDate == null
        ? '未设置'
        : StockpileFormat.date(entry.restockRemindDate!);

    return StockpileBatchEntryTwoColRow(
      left: StockpileBatchEntryCompactField(
        title: '补货提醒日期',
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: IOS26Theme.spacingMd,
            vertical: IOS26Theme.spacingSm,
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: saving
                ? null
                : () {
                    final initial =
                        entry.restockRemindDate ??
                        DateTime.now().add(const Duration(days: 7));
                    showStockpileDatePicker(
                      context: context,
                      initial: initial,
                      onSelected: (v) {
                        entry.restockRemindDate = v;
                        provider.touch();
                      },
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
                      color: entry.restockRemindDate == null
                          ? IOS26Theme.textTertiary
                          : IOS26Theme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: IOS26Theme.spacingSm),
                if (entry.restockRemindDate != null && !saving)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: IOS26Theme.minimumTapSize,
                    onPressed: () {
                      entry.restockRemindDate = null;
                      provider.touch();
                    },
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
      right: StockpileBatchEntryCompactField(
        title: '提醒库存',
        child: StockpileBatchEntryTextField(
          fieldKey: ValueKey(
            'stockpile_ai_batch_item_${entry.keyId}_restock_qty',
          ),
          controller: entry.restockQuantityController,
          placeholder: '不提醒',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
        ),
      ),
    );
  }

  Widget _buildTagSelector(
    BuildContext context, {
    required List<Tag> tags,
    required StockpileBatchEntryProvider provider,
  }) {
    if (tags.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(IOS26Theme.spacingMd),
        child: Text(
          '暂无可用物品类型（可在「标签管理」中创建并关联到「囤货助手」）',
          style: IOS26Theme.bodySmall,
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(IOS26Theme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('物品类型', style: IOS26Theme.bodySmall),
          const SizedBox(height: IOS26Theme.spacingMd),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tag in tags) ...[
                  _buildTagPill(tag, provider: provider),
                  const SizedBox(width: IOS26Theme.spacingMd),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagPill(
    Tag tag, {
    required StockpileBatchEntryProvider provider,
  }) {
    final id = tag.id;
    if (id == null) return const SizedBox.shrink();

    final saving = provider.saving;
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
      onPressed: saving
          ? null
          : () {
              if (selected) {
                entry.selectedTagIds.remove(id);
              } else {
                entry.selectedTagIds.add(id);
              }
              provider.touch();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingMd,
          vertical: IOS26Theme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
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
                borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
              ),
            ),
            const SizedBox(width: IOS26Theme.spacingSm),
            Text(
              tag.name,
              style: IOS26Theme.titleSmall.copyWith(color: textColor),
            ),
            if (selected) ...[
              const SizedBox(width: IOS26Theme.spacingSm),
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

  static String _locationLabelForEntry({
    required StockpileBatchItemEntry entry,
    required List<Tag> locationTags,
    required Map<int, Tag> tagsById,
  }) {
    final locationIds = locationTags.map((e) => e.id).whereType<int>().toSet();
    final selected = entry.selectedTagIds.where(locationIds.contains);
    if (selected.isNotEmpty) {
      final id = selected.first;
      final tagName = tagsById[id]?.name.trim();
      if (tagName != null && tagName.isNotEmpty) return tagName;
    }
    final legacy = entry.locationController.text.trim();
    return legacy.isEmpty ? '未选择' : legacy;
  }

  static bool _locationIsPlaceholderForEntry({
    required StockpileBatchItemEntry entry,
    required List<Tag> locationTags,
  }) {
    final locationIds = locationTags.map((e) => e.id).whereType<int>().toSet();
    final hasLocationTag = entry.selectedTagIds.any(locationIds.contains);
    if (hasLocationTag) return false;
    return entry.locationController.text.trim().isEmpty;
  }

  static Future<void> _pickLocationForItemEntry(
    BuildContext context, {
    required StockpileBatchItemEntry entry,
    required StockpileBatchEntryProvider provider,
  }) async {
    final locationTags = provider.locationTags;
    final tagsById = provider.tagsById;
    final locationIds = locationTags.map((e) => e.id).whereType<int>().toSet();
    final current = entry.selectedTagIds.where(locationIds.contains);

    final selected = await TagPickerSheetView.show<TagPickerResult>(
      context,
      title: '选择位置',
      tags: locationTags,
      selectedIds: current.isEmpty ? <int>{} : {current.first},
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
    if (selected == null || !context.mounted) return;

    final id = selected.selectedIds.isEmpty ? null : selected.selectedIds.first;
    entry.selectedTagIds.removeWhere(locationIds.contains);
    if (id != null) {
      entry.selectedTagIds.add(id);
      final name = tagsById[id]?.name;
      if (name != null) entry.locationController.text = name;
    }
    provider.touch();

    if (selected.tagsChanged && context.mounted) {
      try {
        await provider.loadTagOptions(context.read<TagService>());
      } catch (_) {
        // ignore
      }
    }
  }
}
