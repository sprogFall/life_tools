import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// iOS26 统一图片组件：页面层不直接使用 Image.xxx，便于后续统一扩展明暗主题策略。
class IOS26Image extends StatelessWidget {
  final Widget child;

  const IOS26Image._({super.key, required this.child});

  factory IOS26Image.file(
    File file, {
    Key? key,
    BoxFit? fit,
    double? width,
    double? height,
    AlignmentGeometry alignment = Alignment.center,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    return IOS26Image._(
      key: key,
      child: Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: errorBuilder,
      ),
    );
  }

  factory IOS26Image.network(
    String src, {
    Key? key,
    BoxFit? fit,
    double? width,
    double? height,
    AlignmentGeometry alignment = Alignment.center,
    Map<String, String>? headers,
    ImageFrameBuilder? frameBuilder,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    return IOS26Image._(
      key: key,
      child: Image.network(
        src,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        headers: headers,
        frameBuilder: frameBuilder,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
      ),
    );
  }

  factory IOS26Image.memory(
    Uint8List bytes, {
    Key? key,
    BoxFit? fit,
    double? width,
    double? height,
    AlignmentGeometry alignment = Alignment.center,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    return IOS26Image._(
      key: key,
      child: Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: errorBuilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}
