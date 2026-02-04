import 'package:flutter/material.dart';
import '../theme/ios26_theme.dart';

/// 统一的 iOS 26 风格脚手架
/// 包含背景渐变装饰、SafeArea 处理和统一背景色
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool useSafeArea;
  final bool withBackgroundDecor;
  final bool withBackdropGroup;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.useSafeArea = true,
    this.withBackgroundDecor = true,
    this.withBackdropGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        if (withBackgroundDecor) ..._buildDecorations(),
        _buildBody(),
      ],
    );
    return Scaffold(
      backgroundColor: backgroundColor ?? IOS26Theme.backgroundColor,
      extendBodyBehindAppBar: true, // 让背景延伸到 AppBar 下方
      appBar: appBar,
      body: withBackdropGroup ? BackdropGroup(child: content) : content,
    );
  }

  Widget _buildBody() {
    if (useSafeArea) {
      // 如果有 AppBar，通常需要 top: false 避免双重 SafeArea（如果 AppBar 已经在 SafeArea 内）
      // 但标准 Scaffold 处理 body 的 SafeArea 通常需要我们自己包
      // 这里为了兼容性，如果 appBar 存在，Scaffold 会处理顶部 padding
      return SafeArea(
        // 如果使用了 extendBodyBehindAppBar，Scaffold 不会预留顶部空间，
        // 但我们有了 IOS26AppBar (它是毛玻璃)，我们通常希望内容滚到它下面。
        // 所以这里我们不需要 SafeArea(top: true)，除非我们不想内容被遮挡。
        // iOS 风格通常是 List 可以滚到 Bar 下面。
        // 这里的策略是：让 body 占据全屏，内容自己加 Padding 或 ListView。
        top: appBar == null, 
        bottom: true,
        child: body,
      );
    }
    return body;
  }

  List<Widget> _buildDecorations() {
    return [
      Positioned(
        top: -100,
        right: -100,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                IOS26Theme.primaryColor.withValues(alpha: 0.12),
                IOS26Theme.primaryColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -50,
        left: -50,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                IOS26Theme.toolPurple.withValues(alpha: 0.08),
                IOS26Theme.toolPurple.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}
