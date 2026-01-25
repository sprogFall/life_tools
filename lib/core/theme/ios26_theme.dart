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
class IOS26QuickAddChip extends StatelessWidget {
  final Key fieldKey;
  final Key buttonKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final bool loading;
  final VoidCallback onAdd;
  final double minFieldWidth;
  final double maxFieldWidth;

  const IOS26QuickAddChip({
    super.key,
    required this.fieldKey,
    required this.buttonKey,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.loading,
    required this.onAdd,
    this.minFieldWidth = 120,
    this.maxFieldWidth = 240,
  });

  @override
  Widget build(BuildContext context) {
    final bg = IOS26Theme.surfaceColor.withValues(alpha: 0.65);
    final border = IOS26Theme.textTertiary.withValues(alpha: 0.35);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minFieldWidth,
              maxWidth: maxFieldWidth,
            ),
            child: CupertinoTextField(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              placeholder: placeholder,
              decoration: const BoxDecoration(color: Colors.transparent),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: IOS26Theme.textPrimary,
              ),
              placeholderStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          CupertinoButton(
            key: buttonKey,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            minimumSize: const Size(44, 44),
            pressedOpacity: 0.7,
            onPressed: loading ? null : onAdd,
            child: loading
                ? const CupertinoActivityIndicator(radius: 10)
                : const Icon(
                    CupertinoIcons.add,
                    size: 13,
                    color: IOS26Theme.primaryColor,
                  ),
          ),
        ],
      ),
    );
  }
}
