import 'package:flutter/material.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/tags/widgets/tag_picker_sheet.dart';
import '../../../core/theme/ios26_theme.dart';

class OvercookedTagPickerResult {
  final Set<int> selectedIds;
  final bool tagsChanged;

  const OvercookedTagPickerResult({
    required this.selectedIds,
    required this.tagsChanged,
  });
}

/// 胡闹厨房专用包装：保留对外 API 与测试 key，但内部复用通用 TagPickerSheetView。
class OvercookedTagPickerSheet
    extends TagPickerSheetView<OvercookedTagPickerResult> {
  OvercookedTagPickerSheet({
    super.key,
    required super.title,
    required super.tags,
    required super.selectedIds,
    required super.multi,
    super.createHint,
    super.onCreateTag,
  }) : super(
         keyPrefix: 'overcooked-tag',
         buildResult: (ids, changed) =>
             OvercookedTagPickerResult(selectedIds: ids, tagsChanged: changed),
       );

  static Future<OvercookedTagPickerResult?> show(
    BuildContext context, {
    required String title,
    required List<Tag> tags,
    required Set<int> selectedIds,
    required bool multi,
    String? createHint,
    Future<Tag> Function(String name)? onCreateTag,
  }) {
    return showModalBottomSheet<OvercookedTagPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: IOS26Theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            child: OvercookedTagPickerSheet(
              title: title,
              tags: tags,
              selectedIds: selectedIds,
              multi: multi,
              createHint: createHint,
              onCreateTag: onCreateTag,
            ),
          ),
        );
      },
    );
  }
}
