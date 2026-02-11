import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../core/ai/ai_call_history_record.dart';
import '../core/ai/ai_call_history_service.dart';
import '../core/theme/ios26_theme.dart';
import '../core/ui/app_navigator.dart';
import '../core/ui/app_scaffold.dart';
import 'ai_call_text_detail_page.dart';

class AiCallHistoryPage extends StatefulWidget {
  const AiCallHistoryPage({super.key});

  @override
  State<AiCallHistoryPage> createState() => _AiCallHistoryPageState();
}

class _AiCallHistoryPageState extends State<AiCallHistoryPage> {
  Future<void> _openRetentionLimitSheet() async {
    final service = context.read<AiCallHistoryService>();
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text('设置保留条数', style: IOS26Theme.titleSmall),
        message: Text('调整后将仅保留最近指定条数的 AI 调用记录', style: IOS26Theme.bodySmall),
        actions: [
          for (final option in AiCallHistoryService.retentionLimitOptions)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(option),
              child: Text('$option 条'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(
            '取消',
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    await service.updateRetentionLimit(selected);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AiCallHistoryService>();
    final records = service.records;

    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(
            title: 'AI 调用历史',
            showBackButton: true,
            actions: [
              CupertinoButton(
                key: const ValueKey('ai_history_limit_button'),
                padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                minimumSize: IOS26Theme.minimumTapSize,
                onPressed: _openRetentionLimitSheet,
                child: IOS26Icon(
                  CupertinoIcons.slider_horizontal_3,
                  color: IOS26Theme.primaryColor,
                  size: 22,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingLg,
              IOS26Theme.spacingSm,
              IOS26Theme.spacingLg,
              IOS26Theme.spacingXs,
            ),
            child: Text(
              '仅保留最近${service.retentionLimit}条记录',
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(IOS26Theme.spacingLg),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _buildRecordItem(records[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        '暂无 AI 调用记录',
        style: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
      ),
    );
  }

  Widget _buildRecordItem(AiCallHistoryRecord record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: IOS26Theme.spacingMd),
      child: GlassContainer(
        padding: const EdgeInsets.all(IOS26Theme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${record.source.toolName} · ${record.source.featureName}',
                        style: IOS26Theme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '模型：${record.model.isEmpty ? '未知模型' : record.model}',
                        style: IOS26Theme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDateTime(record.createdAt),
                  style: IOS26Theme.bodySmall.copyWith(
                    color: IOS26Theme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: IOS26Theme.spacingMd),
            _buildTextSection(
              label: '提示词',
              content: record.prompt,
              buttonKey: ValueKey('ai_history_prompt_detail_${record.id}'),
              onOpenDetail: () {
                AppNavigator.push(
                  context,
                  AiCallTextDetailPage(title: '提示词详情', content: record.prompt),
                );
              },
            ),
            const SizedBox(height: IOS26Theme.spacingSm),
            _buildTextSection(
              label: '返回内容',
              content: record.response,
              buttonKey: ValueKey('ai_history_response_detail_${record.id}'),
              onOpenDetail: () {
                AppNavigator.push(
                  context,
                  AiCallTextDetailPage(
                    title: '返回内容详情',
                    content: record.response,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSection({
    required String label,
    required String content,
    required Key buttonKey,
    required VoidCallback onOpenDetail,
  }) {
    final normalized = content.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(IOS26Theme.spacingMd),
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
        border: Border.all(color: IOS26Theme.glassBorderColor, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: IOS26Theme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              CupertinoButton(
                key: buttonKey,
                padding: EdgeInsets.zero,
                minimumSize: IOS26Theme.minimumTapSize,
                onPressed: onOpenDetail,
                child: Text(
                  '查看详情',
                  style: IOS26Theme.bodySmall.copyWith(
                    color: IOS26Theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            normalized.isEmpty ? '（空）' : _preview(normalized),
            style: IOS26Theme.bodySmall.copyWith(height: 1.45),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static String _preview(String text, {int maxLength = 180}) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  static String _formatDateTime(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}';
  }
}
