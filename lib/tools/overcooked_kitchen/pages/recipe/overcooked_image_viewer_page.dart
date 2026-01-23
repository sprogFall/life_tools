import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/obj_store/obj_store_errors.dart';
import '../../../../core/obj_store/obj_store_service.dart';
import '../../../../core/theme/ios26_theme.dart';

class OvercookedImageViewerPage extends StatelessWidget {
  final String objectKey;
  final String title;

  const OvercookedImageViewerPage({
    super.key,
    required this.objectKey,
    this.title = '查看图片',
  });

  @override
  Widget build(BuildContext context) {
    final key = objectKey.trim();
    final objStore = context.read<ObjStoreService>();

    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(title: title, showBackButton: true),
      body: FutureBuilder<String>(
        future: objStore.resolveUri(key: key),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            if (snapshot.error is ObjStoreNotConfiguredException) {
              return const Center(
                child: Text(
                  '未配置资源存储',
                  style: TextStyle(color: IOS26Theme.textSecondary),
                ),
              );
            }
            return const Center(
              child: Text(
                '图片加载失败',
                style: TextStyle(color: IOS26Theme.textSecondary),
              ),
            );
          }
          final uriText = snapshot.data?.trim();
          if (uriText == null || uriText.isEmpty) {
            return const Center(
              child: Text(
                '图片不存在',
                style: TextStyle(color: IOS26Theme.textSecondary),
              ),
            );
          }

          final uri = Uri.tryParse(uriText);
          final image = !kIsWeb && uri != null && uri.scheme == 'file'
              ? Image.file(File.fromUri(uri), fit: BoxFit.contain)
              : Image.network(
                  uriText,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    final value = progress.expectedTotalBytes == null
                        ? null
                        : progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!;
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(value: value),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        '图片加载失败',
                        style: TextStyle(color: IOS26Theme.textSecondary),
                      ),
                    );
                  },
                );

          return InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(child: image),
          );
        },
      ),
    );
  }
}
