import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS 26 风格主题配置
class IOS26Theme {
  IOS26Theme._();

  // 主色调 - iOS 26 风格的柔和蓝色
  static const Color primaryColor = Color(0xFF007AFF);
  static const Color secondaryColor = Color(0xFF5856D6);

  // 背景色
  static const Color backgroundColor = Color(0xFFF2F2F7);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  // 文字颜色
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFFC7C7CC);

  // 毛玻璃效果颜色
  static const Color glassColor = Color(0xAAFFFFFF);
  static const Color glassBorderColor = Color(0x33FFFFFF);

  // 工具颜色
  static const Color toolBlue = Color(0xFF007AFF);
  static const Color toolOrange = Color(0xFFFF9500);
  static const Color toolRed = Color(0xFFFF3B30);
  static const Color toolGreen = Color(0xFF34C759);
  static const Color toolPurple = Color(0xFF5856D6);
  static const Color toolPink = Color(0xFFFF2D55);

  /// 获取主题数据
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: 'Source Han Sans CN',
      fontFamilyFallback: const ['Noto Sans SC', 'Microsoft YaHei', 'Arial'],
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.37,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.36,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.36,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.35,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.38,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.32,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.24,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.41,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.24,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.08,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.24,
          color: primaryColor,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: cardColor,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }
}

/// 毛玻璃容器组件
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? color;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.blur = 20,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? IOS26Theme.glassColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border:
                  border ??
                  Border.all(color: IOS26Theme.glassBorderColor, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// iOS 26 风格的导航栏
class IOS26AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const IOS26AppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: IOS26Theme.glassColor,
            border: Border(
              bottom: BorderSide(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  if (showBackButton)
                    IconButton(
                      onPressed: onBackPressed ?? () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: IOS26Theme.primaryColor,
                        size: 20,
                      ),
                    )
                  else if (leading != null)
                    leading!
                  else
                    const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.41,
                        color: IOS26Theme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (actions != null)
                    ...actions!
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS 26 风格的「内联新增」输入 chip（输入框 + 右侧加号/加载态）
class IOS26QuickAddChipController extends ChangeNotifier {
  bool _expanded = false;

  bool get expanded => _expanded;

  void expand() {
    if (_expanded) return;
    _expanded = true;
    notifyListeners();
  }

  void collapse() {
    if (!_expanded) return;
    _expanded = false;
    notifyListeners();
  }
}

/// iOS 26 风格的「内联新增」chip：
/// - 默认仅显示一个「+」圆角按钮
/// - 点击后展开为「短输入框 + ✓」并随输入内容自适应宽度
/// - 提交成功后自动收起回到「+」
class IOS26QuickAddChip extends StatefulWidget {
  final Key fieldKey;
  final Key buttonKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final bool loading;
  final FutureOr<bool> Function(String name) onAdd;
  final double minFieldWidth;
  final double maxFieldWidth;
  final IOS26QuickAddChipController? uiController;
  final bool initiallyCollapsed;

  const IOS26QuickAddChip({
    super.key,
    required this.fieldKey,
    required this.buttonKey,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.loading,
    required this.onAdd,
    this.minFieldWidth = 72,
    this.maxFieldWidth = 320,
    this.uiController,
    this.initiallyCollapsed = true,
  });

  @override
  State<IOS26QuickAddChip> createState() => _IOS26QuickAddChipState();
}

class _IOS26QuickAddChipState extends State<IOS26QuickAddChip> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.uiController?.expanded ?? !widget.initiallyCollapsed;
    widget.controller.addListener(_onTextChanged);
    widget.uiController?.addListener(_onUiChanged);
  }

  @override
  void didUpdateWidget(covariant IOS26QuickAddChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
    if (oldWidget.uiController != widget.uiController) {
      oldWidget.uiController?.removeListener(_onUiChanged);
      widget.uiController?.addListener(_onUiChanged);
      _expanded = widget.uiController?.expanded ?? _expanded;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.uiController?.removeListener(_onUiChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;
    if (_expanded) setState(() {});
  }

  void _onUiChanged() {
    if (!mounted) return;
    final next = widget.uiController?.expanded ?? _expanded;
    if (next == _expanded) return;
    setState(() => _expanded = next);
    if (next) _requestFocusSoon();
  }

  void _expand() {
    if (widget.loading) return;
    if (_expanded) {
      _requestFocusSoon();
      return;
    }
    if (widget.uiController != null) {
      widget.uiController!.expand();
    } else {
      setState(() => _expanded = true);
      _requestFocusSoon();
    }
  }

  void _collapse() {
    if (!_expanded) return;
    if (widget.uiController != null) {
      widget.uiController!.collapse();
    } else {
      setState(() => _expanded = false);
    }
  }

  void _requestFocusSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.focusNode.requestFocus();
    });
  }

  Future<void> _commit() async {
    if (widget.loading) return;
    final name = widget.controller.text.trim();
    if (name.isEmpty) {
      _requestFocusSoon();
      return;
    }

    final ok = await Future<bool>.value(widget.onAdd(name));
    if (!mounted) return;
    if (!ok) {
      _requestFocusSoon();
      return;
    }
    widget.controller.clear();
    _collapse();
  }

  double _measureTextWidth({
    required BuildContext context,
    required String text,
    required TextStyle style,
  }) {
    if (text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final bg = IOS26Theme.surfaceColor.withValues(alpha: 0.65);
    final border = IOS26Theme.textTertiary.withValues(alpha: 0.35);

    final textStyle = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: IOS26Theme.textPrimary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.maxFieldWidth + 44);
        final maxField = (availableWidth - 44)
            .clamp(0.0, widget.maxFieldWidth)
            .toDouble();
        final minField =
            widget.minFieldWidth.clamp(0.0, maxField).toDouble();

        final raw = widget.controller.text;
        final textWidth = _measureTextWidth(
          context: context,
          text: raw,
          style: textStyle,
        );
        final desiredField = raw.trim().isEmpty
            ? minField
            : (textWidth + 24).clamp(minField, maxField).toDouble();

        return DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1),
          ),
          child: _expanded
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: desiredField,
                      child: CupertinoTextField(
                        key: widget.fieldKey,
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        placeholder: widget.placeholder,
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        style: textStyle,
                        placeholderStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: IOS26Theme.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                        ),
                        onSubmitted: (_) => _commit(),
                      ),
                    ),
                    CupertinoButton(
                      key: widget.buttonKey,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      pressedOpacity: 0.7,
                      onPressed: widget.loading ? null : _commit,
                      child: widget.loading
                          ? const CupertinoActivityIndicator(radius: 10)
                          : const Icon(
                              CupertinoIcons.check_mark,
                              size: 14,
                              color: IOS26Theme.toolGreen,
                            ),
                    ),
                  ],
                )
              : CupertinoButton(
                  key: widget.buttonKey,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  pressedOpacity: 0.7,
                  onPressed: widget.loading ? null : _expand,
                  child: widget.loading
                      ? const CupertinoActivityIndicator(radius: 10)
                      : const Icon(
                          CupertinoIcons.add,
                          size: 14,
                          color: IOS26Theme.primaryColor,
                        ),
                ),
        );
      },
    );
  }
}
