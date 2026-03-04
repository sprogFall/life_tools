import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/ios26_theme.dart';

/// 毛玻璃容器组件
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? color;
  final Border? border;
  final bool disableBlurDuringRouteTransition;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.blur = 20,
    this.color,
    this.border,
    this.disableBlurDuringRouteTransition = true,
  });

  static bool shouldDisableBlurForRouteStatus(AnimationStatus status) {
    return status == AnimationStatus.reverse;
  }

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (disableBlurDuringRouteTransition && routeAnimation != null) {
      return AnimatedBuilder(
        animation: routeAnimation,
        builder: (context, _) {
          final shouldDisable = shouldDisableBlurForRouteStatus(
            routeAnimation.status,
          );
          return _buildWithBlur(context, shouldDisable ? 0 : blur);
        },
      );
    }

    return _buildWithBlur(context, blur);
  }

  Widget _buildWithBlur(BuildContext context, double effectiveBlur) {
    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? IOS26Theme.glassColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            border ??
            Border.all(color: IOS26Theme.glassBorderColor, width: 0.5),
      ),
      child: child,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: IOS26Theme.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: effectiveBlur <= 0
            ? inner
            : BackdropFilter.grouped(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlur,
                  sigmaY: effectiveBlur,
                ),
                child: inner,
              ),
      ),
    );
  }
}
