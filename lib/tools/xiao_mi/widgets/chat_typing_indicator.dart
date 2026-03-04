import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// ChatGPT风格打字指示器动画
class ChatTypingIndicator extends StatefulWidget {
  const ChatTypingIndicator({super.key});

  @override
  State<ChatTypingIndicator> createState() => _ChatTypingIndicatorState();
}

class _ChatTypingIndicatorState extends State<ChatTypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  static const int _dotCount = 3;
  static const Duration _animationDuration = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _dotCount,
      (index) => AnimationController(
        vsync: this,
        duration: _animationDuration,
      ),
    );

    _animations = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInCubic)),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: ConstantTween(0.0),
          weight: 50,
        ),
      ]).animate(controller);
    }).toList();

    // 错开启动动画
    for (var i = 0; i < _dotCount; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IOS26Theme.spacingSm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlassContainer(
          borderRadius: IOS26Theme.radiusXl,
          padding: const EdgeInsets.symmetric(
            horizontal: IOS26Theme.spacingMd,
            vertical: IOS26Theme.spacingSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(_dotCount, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < _dotCount - 1 ? IOS26Theme.spacingXs : 0,
                  ),
                  child: AnimatedBuilder(
                    animation: _animations[index],
                    builder: (context, child) {
                      return Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              IOS26Theme.primaryColor.withValues(
                                alpha: 0.3 + (_animations[index].value * 0.7),
                              ),
                              IOS26Theme.secondaryColor.withValues(
                                alpha: 0.3 + (_animations[index].value * 0.7),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
