import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/ios26_image.dart';
import '../../../l10n/app_localizations.dart';
import '../models/work_photo_asset.dart';
import '../services/work_photo_media_store.dart';

class WorkPhotoAssetGrid extends StatelessWidget {
  final List<WorkPhotoAsset> assets;
  final WorkPhotoMediaStore mediaStore;
  final ValueChanged<WorkPhotoAsset>? onTap;

  const WorkPhotoAssetGrid({
    super.key,
    required this.assets,
    required this.mediaStore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (assets.isEmpty) {
      return Text(l10n.work_photo_no_assets, style: IOS26Theme.bodyMedium);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: IOS26Theme.spacingSm,
        crossAxisSpacing: IOS26Theme.spacingSm,
        childAspectRatio: 1,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        return _WorkPhotoThumb(
          asset: asset,
          mediaStore: mediaStore,
          onTap: onTap == null ? null : () => onTap!(asset),
        );
      },
    );
  }
}

class _WorkPhotoThumb extends StatelessWidget {
  final WorkPhotoAsset asset;
  final WorkPhotoMediaStore mediaStore;
  final VoidCallback? onTap;

  const _WorkPhotoThumb({
    required this.asset,
    required this.mediaStore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
      child: FutureBuilder<File>(
        future: mediaStore.resolveStoredFile(asset.relativePath),
        builder: (context, snapshot) {
          final file = snapshot.data;
          final child = file == null
              ? Container(color: IOS26Theme.surfaceVariant)
              : IOS26Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: IOS26Theme.surfaceVariant),
                );
          return IOS26Button.plain(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onTap,
            child: AspectRatio(aspectRatio: 1, child: child),
          );
        },
      ),
    );
  }
}
