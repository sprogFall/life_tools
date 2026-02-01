import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/tags/tag_service.dart';
import '../ai/stockpile_ai_intent.dart';
import '../models/stockpile_drafts.dart';
import '../providers/stockpile_batch_entry_provider.dart';
import '../services/stockpile_service.dart';
import 'stockpile_ai_batch_entry_view.dart';

class StockpileAiBatchEntryPage extends StatelessWidget {
  final List<StockItemDraft> initialItems;
  final List<StockpileAiConsumptionEntry> initialConsumptions;

  const StockpileAiBatchEntryPage({
    super.key,
    required this.initialItems,
    required this.initialConsumptions,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StockpileBatchEntryProvider>(
      create: (context) {
        final provider = StockpileBatchEntryProvider(
          initialItems: initialItems,
          initialConsumptions: initialConsumptions,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          try {
            provider.loadTagOptions(context.read<TagService>());
          } catch (_) {
            // ignore
          }

          try {
            provider.resolveConsumptionItemDetails(
              context.read<StockpileService>(),
            );
          } catch (_) {
            // ignore
          }
        });
        return provider;
      },
      child: const StockpileAiBatchEntryView(),
    );
  }
}
