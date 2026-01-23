import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/obj_store/obj_store_errors.dart';
import '../../../core/obj_store/obj_store_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../services/overcooked_image_cache_service.dart';

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
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              text ?? '无图片',
              style: const TextStyle(
                fontSize: 12,
                color: IOS26Theme.textSecondary,
              ),
            ),
    );
  }
}

class OvercookedCachedImageByKey extends StatefulWidget {
  final ObjStoreService objStoreService;
  final OvercookedImageCacheService cacheService;
  final String? objectKey;
  final BoxFit fit;
  final double borderRadius;

  const OvercookedCachedImageByKey({
    super.key,
    required this.objStoreService,
    required this.cacheService,
    required this.objectKey,
    this.fit = BoxFit.cover,
    this.borderRadius = 14,
  });

  @override
  State<OvercookedCachedImageByKey> createState() =>
      _OvercookedCachedImageByKeyState();
}

class _OvercookedCachedImageByKeyState extends State<OvercookedCachedImageByKey> {
  File? _file;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OvercookedCachedImageByKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = oldWidget.objectKey?.trim();
    final newKey = widget.objectKey?.trim();
    if (oldKey != newKey) {
      _file = null;
      _error = null;
      _loading = false;
      _load();
    }
  }

  Future<void> _load() async {
    final key = widget.objectKey?.trim();
    if (key == null || key.isEmpty) return;
    if (_loading) return;

    setState(() => _loading = true);
    try {
      final cached = await widget.cacheService.getCachedFile(key: key);
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _file = cached;
          _error = null;
          _loading = false;
        });
        return;
      }

      final f = await widget.cacheService.ensureCached(
        key: key,
        resolveUri: () => widget.objStoreService.resolveUri(key: key),
      );
      if (!mounted) return;
      setState(() {
        _file = f;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.objectKey?.trim();
    if (key == null || key.isEmpty) {
      return _placeholder();
    }

    final file = _file;
    if (file != null && file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.file(file, fit: widget.fit),
      );
    }

    final err = _error;
    if (_loading) return _placeholder(isLoading: true);
    if (err is ObjStoreNotConfiguredException) {
      return _placeholder(text: '未配置资源存储');
    }
    if (err != null) return _placeholder(text: '图片加载失败');
    return _placeholder();
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
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              text ?? '无图片',
              style: const TextStyle(
                fontSize: 12,
                color: IOS26Theme.textSecondary,
              ),
            ),
    );
  }
}
