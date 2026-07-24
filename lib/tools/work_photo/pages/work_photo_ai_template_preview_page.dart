import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../ai/work_photo_ai_intent.dart';

/// 预览 AI 生成的模板树，用户可取消或确认应用。
class WorkPhotoAiTemplatePreviewPage extends StatelessWidget {
  final String templateName;
  final List<WorkPhotoAiTemplateNode> nodes;

  const WorkPhotoAiTemplatePreviewPage({
    super.key,
    required this.templateName,
    required this.nodes,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: l10n.work_photo_ai_preview_title,
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingLg,
                  IOS26Theme.spacingXxl,
                ),
                children: [
                  GlassContainer(
                    borderRadius: IOS26Theme.radiusLg,
                    padding: const EdgeInsets.all(IOS26Theme.spacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.work_photo_ai_preview_template_label(
                            templateName,
                          ),
                          style: IOS26Theme.titleMedium,
                        ),
                        const SizedBox(height: IOS26Theme.spacingSm),
                        Text(
                          l10n.work_photo_ai_preview_warning,
                          style: IOS26Theme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: IOS26Theme.spacingXl),
                  Text(
                    l10n.work_photo_ai_preview_tree_section,
                    style: IOS26Theme.titleMedium,
                  ),
                  const SizedBox(height: IOS26Theme.spacingSm),
                  GlassContainer(
                    borderRadius: IOS26Theme.radiusLg,
                    padding: const EdgeInsets.all(IOS26Theme.spacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final row in _buildRows(nodes, 0, l10n)) row,
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IOS26Theme.spacingLg,
                IOS26Theme.spacingSm,
                IOS26Theme.spacingLg,
                IOS26Theme.spacingLg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: IOS26Button(
                      key: const ValueKey('work_photo_ai_preview_cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                      variant: IOS26ButtonVariant.ghost,
                      child: IOS26ButtonLabel(l10n.common_cancel),
                    ),
                  ),
                  const SizedBox(width: IOS26Theme.spacingMd),
                  Expanded(
                    child: IOS26Button(
                      key: const ValueKey('work_photo_ai_preview_apply'),
                      onPressed: () => Navigator.of(context).pop(true),
                      variant: IOS26ButtonVariant.primary,
                      child: IOS26ButtonLabel(l10n.work_photo_ai_apply),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRows(
    List<WorkPhotoAiTemplateNode> nodes,
    int depth,
    AppLocalizations l10n,
  ) {
    final rows = <Widget>[];
    for (final node in nodes) {
      if (node.isLevel) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              left: depth * IOS26Theme.spacingLg,
              bottom: IOS26Theme.spacingSm,
            ),
            child: Row(
              children: [
                const IOS26Icon(
                  CupertinoIcons.folder,
                  tone: IOS26IconTone.secondary,
                  size: 20,
                ),
                const SizedBox(width: IOS26Theme.spacingSm),
                Expanded(child: Text(node.name, style: IOS26Theme.titleSmall)),
              ],
            ),
          ),
        );
        rows.addAll(_buildRows(node.children, depth + 1, l10n));
      } else {
        final max = node.maxCount == null ? '' : ' / ${node.maxCount}';
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              left: depth * IOS26Theme.spacingLg,
              bottom: IOS26Theme.spacingSm,
            ),
            child: Row(
              children: [
                const IOS26Icon(
                  CupertinoIcons.camera,
                  tone: IOS26IconTone.accent,
                  size: 20,
                ),
                const SizedBox(width: IOS26Theme.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.name, style: IOS26Theme.titleSmall),
                      Text(
                        '${l10n.work_photo_min_count_title}: ${node.minCount}$max',
                        style: IOS26Theme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return rows;
  }
}
