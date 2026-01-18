import '../../../core/tags/models/tag.dart';
import '../models/stock_item.dart';
import '../utils/stockpile_utils.dart';

String buildStockpileAiContext({
  required DateTime now,
  required Iterable<StockItem> items,
  required Iterable<Tag> tags,
  int maxItems = 80,
}) {
  final tagLines = tags
      .where((e) => e.id != null)
      .map((e) => '- [id=${e.id}] ${e.name}')
      .join('\n');

  final itemLines = items
      .where((e) => e.id != null)
      .take(maxItems)
      .map((e) {
        final id = e.id;
        final unit = e.unit.trim();
        final unitText = unit.isEmpty ? '' : unit;
        return '- [id=$id] ${e.name}（库存：${StockpileFormat.num(e.remainingQuantity)}/${StockpileFormat.num(e.totalQuantity)}$unitText）';
      })
      .join('\n');

  return [
    '当前日期：${StockpileFormat.date(now)}',
    if (tagLines.isNotEmpty) ...[
      '可用标签列表（仅当你确定适合时，为 item.tag_ids 填入这些 id；否则输出空数组 []）：',
      tagLines,
    ],
    '现有物品列表（可用于 item_ref.id / item_ref.name，可能为空）：',
    itemLines.isEmpty ? '- (无)' : itemLines,
  ].join('\n');
}
