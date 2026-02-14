import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../core/obj_store/obj_store_errors.dart';
import '../../../core/obj_store/obj_store_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/ios26_image.dart';

class OvercookedImageByKey extends StatefulWidget {
  final ObjStoreService objStoreService;
  final String? objectKey;
  final BoxFit fit;
  final double borderRadius;
  final bool cacheOnly;

  const OvercookedImageByKey({
    super.key,
    required this.objStoreService,
    required this.objectKey,
    this.fit = BoxFit.cover,
    this.borderRadius = 14,
    this.cacheOnly = false,
  });

  @override
  State<OvercookedImageByKey> createState() => _OvercookedImageByKeyState();
}

class _OvercookedImageByKeyState extends State<OvercookedImageByKey> {
  Future<File?>? _fileFuture;
  String? _resolvedKey;

  @override
  void initState() {
    super.initState();
    _initFuture();
  }

  @override
  void didUpdateWidget(covariant OvercookedImageByKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.objectKey != widget.objectKey ||
        oldWidget.cacheOnly != widget.cacheOnly ||
        oldWidget.objStoreService != widget.objStoreService) {
      _initFuture();
    }
  }

  void _initFuture() {
    final key = widget.objectKey?.trim();
    _resolvedKey = key;
    if (key == null || key.isEmpty || kIsWeb) {
      _fileFuture = null;
      return;
    }
    _fileFuture = widget.cacheOnly
        ? widget.objStoreService.getCachedFile(key: key)
        : widget.objStoreService.ensureCachedFile(key: key);
  }

  @override
  Widget build(BuildContext context) {
    final key = _resolvedKey;
    if (key == null || key.isEmpty) {
      return _placeholder();
    }

    if (!kIsWeb) {
      return FutureBuilder<File?>(
        future: _fileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return widget.cacheOnly
                ? _placeholder()
                : _placeholder(isLoading: true);
          }
          if (snapshot.hasError) {
            if (widget.cacheOnly) return _placeholder();
            if (snapshot.error is ObjStoreNotConfiguredException) {
              return _placeholder(text: '未配置资源存储');
            }
            return _placeholder(text: '图片加载失败');
          }

          final file = snapshot.data;
          if (file != null && file.existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: IOS26Image.file(file, fit: widget.fit),
            );
          }

          if (widget.cacheOnly) return _placeholder();
          return _buildNetworkFallback(key: key);
        },
      );
    }

    if (widget.cacheOnly) return _placeholder();
    return _buildNetworkFallback(key: key);
  }

  Widget _buildNetworkFallback({required String key}) {
    return FutureBuilder<String>(
      future: widget.objStoreService.resolveUri(key: key),
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
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: IOS26Image.file(File.fromUri(uri), fit: widget.fit),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: IOS26Image.network(uriText, fit: widget.fit),
        );
      },
    );
  }

  Widget _placeholder({bool isLoading = false, String? text}) {
    return Container(
      decoration: BoxDecoration(
        color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(widget.borderRadius),
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
