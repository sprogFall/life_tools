import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/obj_store/obj_store_errors.dart';
import '../../../../core/obj_store/obj_store_service.dart';
import '../../../../core/theme/ios26_theme.dart';

class OvercookedImageViewerPage extends StatefulWidget {
  final List<String> objectKeys;
  final int initialIndex;
  final String title;

  const OvercookedImageViewerPage({
    super.key,
    required this.objectKeys,
    this.initialIndex = 0,
    this.title = '查看图片',
  });

  @override
  State<OvercookedImageViewerPage> createState() =>
      _OvercookedImageViewerPageState();
}

class _OvercookedImageViewerPageState extends State<OvercookedImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onZoomChanged(bool zoomed) {
    if (_isZoomed != zoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final objStore = context.read<ObjStoreService>();

    final showIndicator = widget.objectKeys.length > 1;

    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: showIndicator
            ? '${widget.title} (${_currentIndex + 1}/${widget.objectKeys.length})'
            : widget.title,
        showBackButton: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: _isZoomed ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.objectKeys.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final key = widget.objectKeys[index].trim();
          return !kIsWeb
              ? _DiskPreferredImageView(
                  objectKey: key,
                  objStore: objStore,
                  onZoomChanged: _onZoomChanged,
                )
              : _NetworkImageView(
                  objectKey: key,
                  objStore: objStore,
                  onZoomChanged: _onZoomChanged,
                );
        },
      ),
    );
  }
}

class _DiskPreferredImageView extends StatelessWidget {
  final String objectKey;
  final ObjStoreService objStore;
  final ValueChanged<bool> onZoomChanged;

  const _DiskPreferredImageView({
    required this.objectKey,
    required this.objStore,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: objStore.ensureCachedFile(key: objectKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          final errMsg = snapshot.error is ObjStoreNotConfiguredException
              ? '未配置资源存储'
              : '图片加载失败';
          return Center(
            child: Text(
              errMsg,
              style: IOS26Theme.bodyMedium,
            ),
          );
        }
        final f = snapshot.data;
        if (f == null || !f.existsSync()) {
          return _NetworkImageView(
            objectKey: objectKey,
            objStore: objStore,
            onZoomChanged: onZoomChanged,
          );
        }
        return _ZoomableImage(
          onZoomChanged: onZoomChanged,
          child: Image.file(f, fit: BoxFit.contain),
        );
      },
    );
  }
}

class _NetworkImageView extends StatelessWidget {
  final String objectKey;
  final ObjStoreService objStore;
  final ValueChanged<bool> onZoomChanged;

  const _NetworkImageView({
    required this.objectKey,
    required this.objStore,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: objStore.resolveUri(key: objectKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          final errMsg = snapshot.error is ObjStoreNotConfiguredException
              ? '未配置资源存储'
              : '图片加载失败';
          return Center(
            child: Text(
              errMsg,
              style: IOS26Theme.bodyMedium,
            ),
          );
        }
        final uriText = snapshot.data?.trim();
        if (uriText == null || uriText.isEmpty) {
          return Center(
            child: Text(
              '图片不存在',
              style: IOS26Theme.bodyMedium,
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
                  return const Center(
                    child: CupertinoActivityIndicator(radius: 12),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      '图片加载失败',
                      style: IOS26Theme.bodyMedium,
                    ),
                  );
                },
              );

        return _ZoomableImage(onZoomChanged: onZoomChanged, child: image);
      },
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImage({required this.child, required this.onZoomChanged});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    widget.onZoomChanged(scale > 1.01);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1,
      maxScale: 6,
      child: Center(child: widget.child),
    );
  }
}
