import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../theme/ios26_theme.dart';

enum ToastVariant { success, error, info }

@immutable
class ToastData {
  final int id;
  final String message;
  final ToastVariant variant;
  final bool visible;

  const ToastData({
    required this.id,
    required this.message,
    required this.variant,
    required this.visible,
  });

  ToastData copyWith({String? message, ToastVariant? variant, bool? visible}) {
    return ToastData(
      id: id,
      message: message ?? this.message,
      variant: variant ?? this.variant,
      visible: visible ?? this.visible,
    );
  }
}

class ToastService extends ChangeNotifier {
  static const Duration animationDuration = Duration(milliseconds: 220);
  static const Duration defaultDuration = Duration(seconds: 2);

  ToastData? _toast;
  Timer? _hideTimer;
  Timer? _clearTimer;
  int _seq = 0;

  ToastData? get toast => _toast;

  void showSuccess(String message, {Duration duration = defaultDuration}) {
    show(message, variant: ToastVariant.success, duration: duration);
  }

  void showError(String message, {Duration duration = defaultDuration}) {
    show(message, variant: ToastVariant.error, duration: duration);
  }

  void show(
    String message, {
    ToastVariant variant = ToastVariant.info,
    Duration duration = defaultDuration,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    _hideTimer?.cancel();
    _clearTimer?.cancel();

    final id = ++_seq;
    _toast = ToastData(
      id: id,
      message: trimmed,
      variant: variant,
      visible: true,
    );
    notifyListeners();

    _hideTimer = Timer(duration, () => _hideIfCurrent(id));
  }

  void hide() {
    final current = _toast;
    if (current == null || !current.visible) return;

    final id = current.id;
    _toast = current.copyWith(visible: false);
    notifyListeners();

    _clearTimer?.cancel();
    _clearTimer = Timer(animationDuration, () {
      if (_toast?.id != id) return;
      _toast = null;
      notifyListeners();
    });
  }

  void _hideIfCurrent(int id) {
    if (_toast?.id != id) return;
    hide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _clearTimer?.cancel();
    super.dispose();
  }
}

class IOS26ToastOverlay extends StatelessWidget {
  static const Key overlayKey = Key('ios26_toast_overlay');

  const IOS26ToastOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final toast = context.select((ToastService s) => s.toast);
    if (toast == null) return const SizedBox.shrink();

    final paddingBottom = MediaQuery.paddingOf(context).bottom;
    final isVisible = toast.visible;

    final (icon, color) = switch (toast.variant) {
      ToastVariant.success => (
        CupertinoIcons.check_mark_circled_solid,
        IOS26Theme.toolGreen,
      ),
      ToastVariant.error => (
        CupertinoIcons.exclamationmark_triangle_fill,
        IOS26Theme.toolRed,
      ),
      ToastVariant.info => (
        CupertinoIcons.info_circle_fill,
        IOS26Theme.toolBlue,
      ),
    };

    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            IOS26Theme.spacingXl,
            0,
            IOS26Theme.spacingXl,
            IOS26Theme.spacingXl + paddingBottom,
          ),
          child: AnimatedSlide(
            offset: isVisible ? Offset.zero : const Offset(0, 0.15),
            duration: ToastService.animationDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: isVisible ? 1 : 0,
              duration: ToastService.animationDuration,
              curve: Curves.easeOutCubic,
              child: GlassContainer(
                borderRadius: IOS26Theme.radiusLg,
                padding: const EdgeInsets.symmetric(
                  horizontal: IOS26Theme.spacingLg,
                  vertical: IOS26Theme.spacingMd,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.sizeOf(context).width -
                        IOS26Theme.spacingXl * 2,
                  ),
                  child: Row(
                    key: overlayKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: IOS26Theme.spacingSm),
                      Flexible(
                        child: Text(
                          toast.message,
                          style: IOS26Theme.bodyLarge,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
