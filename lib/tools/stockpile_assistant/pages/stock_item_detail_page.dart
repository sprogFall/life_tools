import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/messages/message_service.dart';
import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../models/stock_consumption.dart';
import '../models/stock_item.dart';
import '../services/stockpile_reminder_service.dart';
import '../services/stockpile_service.dart';
import '../stockpile_constants.dart';
import '../utils/stockpile_tag_utils.dart';
import '../utils/stockpile_utils.dart';
import 'stock_consumption_edit_page.dart';
import 'stock_item_edit_page.dart';

class StockItemDetailPage extends StatefulWidget {
  final int itemId;

  const StockItemDetailPage({super.key, required this.itemId});

  @override
  State<StockItemDetailPage> createState() => _StockItemDetailPageState();
}

class _StockItemDetailPageState extends State<StockItemDetailPage> {
  late final StockpileService _service;
  TagService? _tagService;

  StockItem? _item;
  List<Tag> _tags = const [];
  List<StockConsumption> _logs = const [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<StockpileService>();
    try {
      _tagService = context.read<TagService>();
      _tagService?.refreshToolTags(StockpileConstants.toolId);
    } catch (_) {
      _tagService = null;
    }
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final item = await _service.getItem(widget.itemId);
    final logs = await _service.listConsumptionsForItem(widget.itemId);
    final tags = await _service.loadTagsForItem(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      _logs = logs;
      _tags = tags;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: IOS26Theme.backgroundColor,
        appBar: IOS26AppBar(
          title: '物品详情',
          showBackButton: true,
          onBackPressed: () => Navigator.pop(context, _changed),
          actions: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: IOS26Theme.minimumTapSize,
              onPressed: _openEdit,
              child: const Icon(
                CupertinoIcons.pencil,
                color: IOS26Theme.primaryColor,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: IOS26Theme.minimumTapSize,
              onPressed: _openConsume,
              child: const Icon(
                CupertinoIcons.minus_circle,
                color: IOS26Theme.primaryColor,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: IOS26Theme.minimumTapSize,
              onPressed: _confirmDelete,
              child: const Icon(
                CupertinoIcons.delete,
                color: IOS26Theme.toolRed,
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : SafeArea(
                child: _item == null ? _buildNotFound() : _buildContent(_item!),
              ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Text(
        '未找到该物品（可能已删除）',
        style: IOS26Theme.bodyMedium,
      ),
    );
  }

  Widget _buildContent(StockItem item) {
    final categoryByTagId = <int, String>{};
    final tagService = _tagService;
    if (tagService != null) {
      for (final link in tagService.tagsForToolWithCategory(
        StockpileConstants.toolId,
      )) {
        final id = link.tag.id;
        if (id != null) categoryByTagId[id] = link.categoryId;
      }
    }
    final split = StockpileTagUtils.splitItemTags(
      tags: _tags,
      categoryByTagId: categoryByTagId,
    );
    final typeNames = split.itemTypes.map((t) => t.name).toList();
    final location = (split.location?.name.trim().isNotEmpty ?? false)
        ? split.location!.name.trim()
        : item.location.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: IOS26Theme.headlineSmall,
              ),
              const SizedBox(height: 10),
              _kv('物品类型', typeNames.isEmpty ? '无' : typeNames.join('、')),
              if (location.isNotEmpty) _kv('位置', location),
              _kv(
                '库存',
                '${StockpileFormat.num(item.remainingQuantity)}/${StockpileFormat.num(item.totalQuantity)}${item.unit.isEmpty ? '' : item.unit}',
              ),
              _kv('采购日期', StockpileFormat.date(item.purchaseDate)),
              _kv(
                '到期日期',
                item.expiryDate == null
                    ? '无'
                    : StockpileFormat.date(item.expiryDate!),
              ),
              if (item.expiryDate != null)
                _kv(
                  '提醒',
                  item.remindDays < 0 ? '不提醒' : '提前 ${item.remindDays} 天',
                ),
              if (item.restockRemindDate != null)
                _kv('补货日期', StockpileFormat.date(item.restockRemindDate!)),
              if (item.restockRemindQuantity != null)
                _kv(
                  '补货库存',
                  '≤ ${StockpileFormat.num(item.restockRemindQuantity!)}${item.unit.isEmpty ? '' : item.unit}',
                ),
              if (item.note.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  item.note,
                  style: IOS26Theme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '消耗记录',
          style: IOS26Theme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (_logs.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(14),
            child: Text(
              '暂无消耗记录',
              style: IOS26Theme.bodyMedium,
            ),
          )
        else
          for (final log in _logs) _buildLogRow(log),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              k,
              style: IOS26Theme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(StockConsumption log) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.minus_circle_fill,
            size: 18,
            color: IOS26Theme.toolOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.method.trim().isEmpty ? '消耗' : log.method,
                  style: IOS26Theme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  StockpileFormat.dateTime(log.consumedAt),
                  style: IOS26Theme.bodySmall,
                ),
                if (log.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.note,
                    style: IOS26Theme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '-${StockpileFormat.num(log.quantity)}',
            style: IOS26Theme.titleMedium.copyWith(
              color: IOS26Theme.toolOrange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit() async {
    final ok = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _service,
          child: StockItemEditPage(itemId: widget.itemId),
        ),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      _changed = true;
      await _reload();
    }
  }

  Future<void> _openConsume() async {
    final ok = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _service,
          child: StockConsumptionEditPage(itemId: widget.itemId),
        ),
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      _changed = true;
      await _reload();
    }
  }

  Future<void> _confirmDelete() async {
    final item = _item;
    if (item == null) return;
    final messageService = context.read<MessageService>();
    final expiryDedupeKey = StockpileReminderService.dedupeKeyForItem(
      itemId: widget.itemId,
    );
    final restockDedupeKey = StockpileReminderService.restockDedupeKeyForItem(
      itemId: widget.itemId,
    );

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认删除'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('将删除「${item.name}」及其消耗记录，是否继续？'),
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

    if (confirmed != true) return;
    if (!mounted) return;
    await _service.deleteItem(widget.itemId);
    await messageService.deleteMessageByDedupeKey(expiryDedupeKey);
    await messageService.deleteMessageByDedupeKey(restockDedupeKey);
    await StockpileReminderService.cancelScheduledNotificationsForItem(
      messageService: messageService,
      itemId: widget.itemId,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
