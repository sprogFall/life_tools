import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/messages/message_service.dart';
import '../../../core/tags/models/tag_category.dart';
import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../pages/home_page.dart';
import '../../work_log/pages/task/work_log_voice_input_sheet.dart';
import '../ai/stockpile_ai_assistant.dart';
import '../ai/stockpile_ai_context.dart';
import '../ai/stockpile_ai_intent.dart';
import '../models/stock_item.dart';
import '../models/stockpile_drafts.dart';
import '../services/stockpile_reminder_service.dart';
import '../services/stockpile_service.dart';
import '../utils/stockpile_utils.dart';
import '../widgets/stockpile_consume_button.dart';
import 'stockpile_ai_batch_entry_page.dart';
import 'stock_consumption_edit_page.dart';
import 'stock_item_detail_page.dart';
import 'stock_item_edit_page.dart';

class StockpileToolPage extends StatefulWidget {
  final StockpileService? service;

  const StockpileToolPage({super.key, this.service});

  @override
  State<StockpileToolPage> createState() => _StockpileToolPageState();
}

class _StockpileToolPageState extends State<StockpileToolPage> {
  late final StockpileService _service;
  late final bool _ownsService;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StockpileService();
    _ownsService = widget.service == null;
    if (_ownsService) {
      _service.loadItems().then((_) {
        if (!mounted) return;
        _pushDueReminders();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context
            .read<TagService>()
            .registerToolTagCategories('stockpile_assistant', const [
              TagCategory(id: 'place', name: '位置'),
              TagCategory(id: 'purpose', name: '用途'),
              TagCategory(id: 'status', name: '状态'),
            ]);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  void _pushDueReminders() {
    final messageService = Provider.of<MessageService>(context, listen: false);
    StockpileReminderService().pushDueReminders(messageService: messageService);
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
            _buildAiEntryButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAiEntryButton(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 18,
      child: Center(
        child: GlassContainer(
          borderRadius: 999,
          padding: const EdgeInsets.all(6),
          child: CupertinoButton(
            key: const ValueKey('stockpile_ai_input_button'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            onPressed: _openAiInput,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.sparkles,
                  size: 18,
                  color: IOS26Theme.primaryColor,
                ),
                SizedBox(width: 8),
                Text(
                  'AI录入',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: IOS26Theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
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
        final restockDue = service.restockDueItems(now);

        if (items.isEmpty) {
          return const Center(
            child: Text(
              '暂无记录，点击右上角 + 录入',
              style: TextStyle(fontSize: 16, color: IOS26Theme.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          children: [
            if (_tab == 0 && restockDue.isNotEmpty)
              GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                color: IOS26Theme.toolBlue.withValues(alpha: 0.10),
                border: Border.all(
                  color: IOS26Theme.toolBlue.withValues(alpha: 0.25),
                  width: 1,
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.cart_fill,
                      size: 18,
                      color: IOS26Theme.toolBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '需要补货：${restockDue.length} 个',
                        style: const TextStyle(
                          fontSize: 14,
                          color: IOS26Theme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    final compact = item.isDepleted;
    final expiryDate = item.expiryDate;
    final badge = compact ? null : _buildStatusBadges(item, now);
    final qtyText =
        '${StockpileFormat.num(item.remainingQuantity)}/${StockpileFormat.num(item.totalQuantity)}${item.unit.isEmpty ? '' : item.unit}';
    final tagText = tags.isEmpty ? '无标签' : tags.map((t) => t.name).join('、');
    final locationText = item.location.trim().isEmpty
        ? ''
        : ' · ${item.location.trim()}';

    return GlassContainer(
      margin: EdgeInsets.only(bottom: compact ? 8 : 12),
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
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
                          style: TextStyle(
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w600,
                            color: IOS26Theme.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null) badge,
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  Text(
                    '$tagText$locationText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      color: IOS26Theme.textSecondary,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  Text(
                    '库存：$qtyText',
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      color: IOS26Theme.textSecondary,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      expiryDate == null
                          ? '到期：无保质期'
                          : '到期：${StockpileFormat.date(expiryDate)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: IOS26Theme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (canShowConsumeButton(item))
            StockpileConsumeButton(
              onPressed: () => _openCreateConsumption(item),
            ),
        ],
      ),
    );
  }

  Widget? _buildStatusBadges(StockItem item, DateTime now) {
    final chips = <Widget>[];
    if (item.isRestockDue(now)) {
      chips.add(_badge('补货', IOS26Theme.toolBlue));
    }
    if (item.isExpired(now)) {
      chips.add(_badge('已过期', IOS26Theme.toolRed));
    } else if (item.isExpiringSoon(now)) {
      chips.add(_badge('临期', IOS26Theme.toolOrange));
    }

    if (chips.isEmpty) return null;
    if (chips.length == 1) return chips.single;

    return Wrap(spacing: 6, children: chips);
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

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _openCreateItem() async {
    final created = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _service,
          child: const StockItemEditPage(),
        ),
      ),
    );
    if (!mounted) return;
    if (created == true) await _service.loadItems();
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _service,
          child: StockItemDetailPage(itemId: id),
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) await _service.loadItems();
  }

  Future<void> _openCreateConsumption(StockItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _service,
          child: StockConsumptionEditPage(itemId: item.id!),
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) await _service.loadItems();
  }

  Future<void> _openAiInput() async {
    final text = await WorkLogVoiceInputSheet.show(
      context,
      helperText: '输入内容（可不写单位，AI 会根据物品/数量自动补单位；判断不出就留空）',
      placeholder: '例如：买了牛奶2盒放冰箱，保质期到2026-01-05，提醒2天；或：牛奶 消耗1盒 早餐',
    );
    if (!mounted || text == null) return;

    final assistant = _maybeCreateAiAssistant(context);
    if (assistant == null) {
      await StockpileDialogs.showMessage(
        context,
        title: '提示',
        content: '未找到 AI 服务，请确认已在应用入口注入 AiService。',
      );
      return;
    }

    late final String jsonText;
    late final StockpileAiIntent intent;
    try {
      _showLoading('AI 解析中…');
      final aiContext = await _buildAiContext();
      jsonText = await assistant.textToIntentJson(
        text: text,
        context: aiContext,
      );
      intent = StockpileAiIntentParser.parse(jsonText);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // loading
      await StockpileDialogs.showMessage(
        context,
        title: 'AI 调用失败',
        content: e.toString(),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // loading
    await _applyAiIntent(intent, rawJson: jsonText);
  }

  StockpileAiAssistant? _maybeCreateAiAssistant(BuildContext context) {
    try {
      final aiService = context.read<AiService>();
      return DefaultStockpileAiAssistant(aiService: aiService);
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<String> _buildAiContext() async {
    TagService? tagService;
    try {
      tagService = context.read<TagService>();
    } on ProviderNotFoundException {
      tagService = null;
    }

    final now = DateTime.now();
    final items = await _service.listAllItemsForAiContext();
    final tags = tagService == null
        ? _service.availableTags
        : await tagService.listTagsForTool('stockpile_assistant');

    return buildStockpileAiContext(now: now, items: items, tags: tags);
  }

  Future<void> _applyAiIntent(
    StockpileAiIntent intent, {
    required String rawJson,
  }) async {
    if (intent is UnknownIntent) {
      await StockpileDialogs.showMessage(
        context,
        title: '无法识别指令',
        content: '${intent.reason}\n\nAI 返回：\n$rawJson',
      );
      return;
    }

    final items = <StockItemDraft>[];
    final consumptions = <StockpileAiConsumptionEntry>[];
    if (intent is CreateItemIntent) {
      items.add(intent.draft);
    } else if (intent is AddConsumptionIntent) {
      consumptions.add(
        StockpileAiConsumptionEntry(
          itemRef: intent.itemRef,
          draft: intent.draft,
        ),
      );
    } else if (intent is BatchEntryIntent) {
      items.addAll(intent.items);
      consumptions.addAll(intent.consumptions);
    }

    if (items.isEmpty && consumptions.isEmpty) {
      await StockpileDialogs.showMessage(
        context,
        title: '无法识别指令',
        content: 'AI 返回了无法处理的指令。\n\nAI 返回：\n$rawJson',
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _service,
          child: StockpileAiBatchEntryPage(
            initialItems: items,
            initialConsumptions: consumptions,
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) await _service.loadItems();
  }

  void _showLoading(String text) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const CupertinoActivityIndicator(),
            const SizedBox(height: 12),
            Text(text),
          ],
        ),
      ),
    );
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
