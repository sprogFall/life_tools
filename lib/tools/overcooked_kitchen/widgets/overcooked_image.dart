import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../core/obj_store/obj_store_errors.dart';
import '../../../core/obj_store/obj_store_service.dart';
import '../../../core/theme/ios26_theme.dart';

class OvercookedImageByKey extends StatelessWidget {
  final ObjStoreService objStoreService;
  final String? objectKey;
  final BoxFit fit;
  final double borderRadius;

  const OvercookedImageByKey({
    super.key,
    required this.objStoreService,
    required this.objectKey,
    this.fit = BoxFit.cover,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final key = objectKey?.trim();
    if (key == null || key.isEmpty) {
      return _placeholder();
    }

    if (!kIsWeb) {
      return FutureBuilder<File?>(
        future: objStoreService.ensureCachedFile(key: key),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _placeholder(isLoading: true);
          }
          if (snapshot.hasError) {
            if (snapshot.error is ObjStoreNotConfiguredException) {
              return _placeholder(text: '未配置资源存储');
            }
            return _placeholder(text: '图片加载失败');
          }

          final file = snapshot.data;
          if (file != null && file.existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.file(file, fit: fit),
            );
          }

          return _buildNetworkFallback(key: key);
        },
      );
    }

    return _buildNetworkFallback(key: key);
  }

  Widget _buildNetworkFallback({required String key}) {
    return FutureBuilder<String>(
      future: objStoreService.resolveUri(key: key),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholder(isLoading: true);
        }
        if (snapshot.hasError) {
          if (snapshot.error is ObjStoreNotConfiguredException) {
            return _placeholder(text: '未配置资源存储');
          }
          return _placeholder(text: '图片加载失败');
        }
        final uriText = snapshot.data;
        if (uriText == null || uriText.trim().isEmpty) {
          return _placeholder(text: '图片不存在');
        }
        final uri = Uri.tryParse(uriText);
        if (!kIsWeb && uri != null && uri.scheme == 'file') {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(File.fromUri(uri), fit: fit),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.network(uriText, fit: fit),
        );
      },
    );
  }

  Widget _placeholder({bool isLoading = false, String? text}) {
    return Container(
      decoration: BoxDecoration(
        color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CupertinoActivityIndicator(radius: 9),
            )
          : Text(
              text ?? '无图片',
              style: IOS26Theme.bodySmall.copyWith(fontSize: 12),
            ),
    );
  }
}
