import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../pages/home_page.dart';
import '../models/stock_item.dart';
import '../services/stockpile_service.dart';
import '../utils/stockpile_utils.dart';
import 'stock_consumption_edit_page.dart';
import 'stock_item_detail_page.dart';
import 'stock_item_edit_page.dart';

class StockpileToolPage extends StatefulWidget {
  const StockpileToolPage({super.key});

  @override
  State<StockpileToolPage> createState() => _StockpileToolPageState();
}

class _StockpileToolPageState extends State<StockpileToolPage> {
  late final StockpileService _service;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _service = StockpileService();
    _service.loadItems();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _service,
      child: Scaffold(
        backgroundColor: IOS26Theme.backgroundColor,
        body: Stack(
          children: [
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      IOS26Theme.toolGreen.withValues(alpha: 0.16),
                      IOS26Theme.toolGreen.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      IOS26Theme.toolOrange.withValues(alpha: 0.12),
                      IOS26Theme.toolOrange.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _StockpileAppBar(
                    onHome: () => _navigateToHome(context),
                    onAdd: _openCreateItem,
                  ),
                  const SizedBox(height: 10),
                  _buildSegmented(),
                  const SizedBox(height: 10),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmented() {
    return Consumer<StockpileService>(
      builder: (context, service, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _tab,
            backgroundColor: IOS26Theme.textTertiary.withValues(alpha: 0.25),
            thumbColor: IOS26Theme.surfaceColor.withValues(alpha: 0.9),
            children: const {
              0: Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Text('在库'),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Text('已耗尽'),
              ),
            },
            onValueChanged: (value) async {
              if (value == null) return;
              setState(() => _tab = value);
              await service.setStockStatus(
                value == 0
                    ? StockItemStockStatus.inStock
                    : StockItemStockStatus.depleted,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return Consumer<StockpileService>(
      builder: (context, service, _) {
        final items = service.items;
        final now = DateTime.now();
        final expiring = service.expiringSoonItems(now);

        if (items.isEmpty) {
          return const Center(
            child: Text(
              '暂无记录，点击右上角 + 录入',
              style: TextStyle(fontSize: 16, color: IOS26Theme.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            if (_tab == 0 && expiring.isNotEmpty)
              GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                color: IOS26Theme.toolOrange.withValues(alpha: 0.10),
                border: Border.all(
                  color: IOS26Theme.toolOrange.withValues(alpha: 0.25),
                  width: 1,
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.bell_fill,
                      size: 18,
                      color: IOS26Theme.toolOrange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '临期/已过期：${expiring.length} 个（列表已按临期优先排序）',
                        style: const TextStyle(
                          fontSize: 14,
                          color: IOS26Theme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final item in items)
              _buildItemCard(
                item,
                now,
                item.id == null ? const [] : service.tagsForItem(item.id!),
              ),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(StockItem item, DateTime now, List<Tag> tags) {
    final expiryDate = item.expiryDate;
    final badge = _buildExpiryBadge(item, now);
    final qtyText =
        '${StockpileFormat.num(item.remainingQuantity)}/${StockpileFormat.num(item.totalQuantity)}${item.unit.isEmpty ? '' : item.unit}';
    final tagText =
        tags.isEmpty ? '无标签' : tags.map((t) => t.name).join('、');

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: IOS26Theme.toolGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.cube_box,
              color: IOS26Theme.toolGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openDetail(item.id!),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: IOS26Theme.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) badge,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tagText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: IOS26Theme.textSecondary,
                          ),
                        ),
                      ),
                      if (item.location.trim().isNotEmpty) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 13,
                            color: IOS26Theme.textTertiary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: IOS26Theme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expiryDate == null
                        ? '库存：$qtyText · 无保质期'
                        : '库存：$qtyText · 到期：${StockpileFormat.date(expiryDate)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: IOS26Theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildConsumeButton(item),
        ],
      ),
    );
  }

  Widget? _buildExpiryBadge(StockItem item, DateTime now) {
    final expiry = item.expiryDate;
    if (expiry == null) return null;
    if (item.isExpired(now)) return _badge('已过期', IOS26Theme.toolRed);
    if (item.isExpiringSoon(now)) return _badge('临期', IOS26Theme.toolOrange);
    return _badge(StockpileFormat.date(expiry), IOS26Theme.textTertiary);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );
  }

  Widget _buildConsumeButton(StockItem item) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      onPressed:
          item.remainingQuantity <= 0 ? null : () => _openCreateConsumption(item),
      child: const Icon(
        CupertinoIcons.minus_circle,
        size: 20,
        color: IOS26Theme.textSecondary,
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _openCreateItem() async {
    final created = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const StockItemEditPage()),
    );
    if (!mounted) return;
    if (created == true) await _service.loadItems();
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => StockItemDetailPage(itemId: id)),
    );
    if (!mounted) return;
    if (changed == true) await _service.loadItems();
  }

  Future<void> _openCreateConsumption(StockItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => StockConsumptionEditPage(itemId: item.id!),
      ),
    );
    if (!mounted) return;
    if (changed == true) await _service.loadItems();
  }
}

class _StockpileAppBar extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onAdd;

  const _StockpileAppBar({required this.onHome, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: IOS26Theme.glassColor,
            border: Border(
              bottom: BorderSide(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: onHome,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.home,
                      color: IOS26Theme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '首页',
                      style: TextStyle(
                        fontSize: 17,
                        color: IOS26Theme.primaryColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Text(
                  '囤货助手',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                    color: IOS26Theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: onAdd,
                child: const Icon(
                  CupertinoIcons.add,
                  color: IOS26Theme.primaryColor,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

