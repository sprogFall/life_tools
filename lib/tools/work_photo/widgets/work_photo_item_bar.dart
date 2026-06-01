import 'package:flutter/cupertino.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_asset.dart';
import '../models/work_photo_project_item.dart';

class WorkPhotoItemBar extends StatelessWidget {
  final List<WorkPhotoProjectItem> items;
  final Map<int, List<WorkPhotoAsset>> assetsByItemId;
  final int? selectedItemId;
  final ValueChanged<WorkPhotoProjectItem> onSelected;

  const WorkPhotoItemBar({
    super.key,
    required this.items,
    required this.assetsByItemId,
    required this.selectedItemId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingLg,
          vertical: IOS26Theme.spacingMd,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: IOS26Theme.spacingMd),
        itemBuilder: (context, index) {
          final item = items[index];
          final itemId = item.id;
          final count = itemId == null
              ? 0
              : (assetsByItemId[itemId]?.length ?? 0);
          final selected = itemId != null && itemId == selectedItemId;
          return _WorkPhotoItemChip(
            item: item,
            count: count,
            selected: selected,
            onPressed: () => onSelected(item),
          );
        },
      ),
    );
  }
}

class _WorkPhotoItemChip extends StatelessWidget {
  final WorkPhotoProjectItem item;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  const _WorkPhotoItemChip({
    required this.item,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final done = count >= item.minCount;
    final colors = selected
        ? IOS26Theme.iconChipColors(IOS26IconTone.onAccent)
        : IOS26Theme.iconChipColors(
            done ? IOS26IconTone.success : IOS26IconTone.secondary,
          );
    return SizedBox(
      width: 118,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: IOS26Button.plain(
          padding: const EdgeInsets.symmetric(
            horizontal: IOS26Theme.spacingMd,
            vertical: IOS26Theme.spacingSm,
          ),
          foregroundColor: colors.foreground,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
          onPressed: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nameSnapshot,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IOS26Theme.titleSmall.copyWith(color: colors.foreground),
              ),
              const SizedBox(height: IOS26Theme.spacingXs),
              Text(
                '${l10n.work_photo_photo_count(count)} / ${item.minCount}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IOS26Theme.bodySmall.copyWith(color: colors.foreground),
              ),
              const SizedBox(height: IOS26Theme.spacingXs),
              Text(
                done ? l10n.work_photo_done_item : l10n.work_photo_missing_item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IOS26Theme.bodySmall.copyWith(color: colors.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
