import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/text_editing_safety.dart';

enum IOS26ButtonVariant {
  primary,
  secondary,
  ghost,
  destructive,
  destructivePrimary,
}

enum IOS26IconTone {
  primary,
  secondary,
  accent,
  success,
  warning,
  danger,
  onAccent,
}

@immutable
class IOS26ButtonColors {
  final Color background;
  final Color foreground;
  final Color border;

  const IOS26ButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}

@immutable
class IOS26IconChipColors {
  final Color background;
  final Color foreground;
  final Color border;

  const IOS26IconChipColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}

/// iOS 26 风格主题配置
class IOS26Theme {
  IOS26Theme._();

  static Brightness _brightness = Brightness.light;

  static Brightness get brightness => _brightness;
  static bool get isDarkMode => _brightness == Brightness.dark;

  static void setBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  // 主色调 - iOS 26 风格的柔和蓝色
  static const Color _lightPrimaryColor = Color(0xFF007AFF);
  static const Color _darkPrimaryColor = Color(0xFF3B82F6);
  static const Color _lightSecondaryColor = Color(0xFF5856D6);
  static const Color _darkSecondaryColor = Color(0xFF9A8CFF);

  // 背景色
  static const Color _lightBackgroundColor = Color(0xFFF2F2F7);
  static const Color _darkBackgroundColor = Color(0xFF000000);
  static const Color _lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color _darkSurfaceColor = Color(0xFF111214);
  static const Color _lightSurfaceVariant = Color(0xFFE5E5EA);
  static const Color _darkSurfaceVariant = Color(0xFF1C1F24);
  static const Color _lightCardColor = Color(0xFFFFFFFF);
  static const Color _darkCardColor = Color(0xFF15181E);

  // 文字颜色
  static const Color _lightTextPrimary = Color(0xFF1C1C1E);
  static const Color _darkTextPrimary = Color(0xFFF5F5F7);
  static const Color _lightTextSecondary = Color(0xFF8E8E93);
  static const Color _darkTextSecondary = Color(0xFFC0C3CC);
  static const Color _lightTextTertiary = Color(0xFFC7C7CC);
  static const Color _darkTextTertiary = Color(0xFF7A8090);

  // 毛玻璃效果颜色
  static const Color _lightGlassColor = Color(0xCCFFFFFF);
  static const Color _darkGlassColor = Color(0xB315181E);
  static const Color _lightGlassBorderColor = Color(0x1A000000);
  static const Color _darkGlassBorderColor = Color(0x40FFFFFF);

  // 语义化覆盖/阴影颜色
  static const Color _lightOverlayColor = Color(0x26000000);
  static const Color _darkOverlayColor = Color(0x59000000);
  static const Color _lightShadowColor = Color(0x1F000000);
  static const Color _darkShadowColor = Color(0x66000000);
  static const Color _lightShadowColorFaint = Color(0x0A000000);
  static const Color _darkShadowColorFaint = Color(0x33000000);

  // 工具颜色
  static const Color _lightToolBlue = Color(0xFF007AFF);
  static const Color _darkToolBlue = Color(0xFF3B82F6);
  static const Color _lightToolOrange = Color(0xFFFF9500);
  static const Color _darkToolOrange = Color(0xFFFFB14A);
  static const Color _lightToolRed = Color(0xFFFF3B30);
  static const Color _darkToolRed = Color(0xFFFF453A);
  static const Color _lightToolGreen = Color(0xFF34C759);
  static const Color _darkToolGreen = Color(0xFF32D583);
  static const Color _lightToolPurple = Color(0xFF5856D6);
  static const Color _darkToolPurple = Color(0xFFC084FC);
  static const Color _lightToolPink = Color(0xFFFF2D55);
  static const Color _darkToolPink = Color(0xFFFF6E91);

  static const Color onPrimaryColor = Color(0xFFFFFFFF);

  static IOS26ButtonColors buttonColors(IOS26ButtonVariant variant) {
    final isDark = isDarkMode;
    return switch (variant) {
      IOS26ButtonVariant.primary => IOS26ButtonColors(
        background: primaryColor,
        foreground: onPrimaryColor,
        border: primaryColor.withValues(alpha: isDark ? 0.78 : 1),
      ),
      IOS26ButtonVariant.secondary => IOS26ButtonColors(
        background: isDark ? const Color(0xFF161A22) : const Color(0xFFEAF2FF),
        foreground: isDark ? const Color(0xFFEAF3FF) : const Color(0xFF1457C8),
        border: primaryColor.withValues(alpha: isDark ? 0.42 : 0.22),
      ),
      IOS26ButtonVariant.ghost => IOS26ButtonColors(
        background: textTertiary.withValues(alpha: isDark ? 0.2 : 0.22),
        foreground: textPrimary,
        border: textTertiary.withValues(alpha: isDark ? 0.28 : 0.24),
      ),
      IOS26ButtonVariant.destructive => IOS26ButtonColors(
        background: toolRed.withValues(alpha: isDark ? 0.28 : 0.14),
        foreground: toolRed,
        border: toolRed.withValues(alpha: isDark ? 0.6 : 0.34),
      ),
      IOS26ButtonVariant.destructivePrimary => IOS26ButtonColors(
        background: toolRed,
        foreground: onPrimaryColor,
        border: toolRed.withValues(alpha: isDark ? 0.86 : 1),
      ),
    };
  }

  static Color iconColor(IOS26IconTone tone) {
    return switch (tone) {
      IOS26IconTone.primary => textPrimary,
      IOS26IconTone.secondary => textSecondary,
      IOS26IconTone.accent => primaryColor,
      IOS26IconTone.success => toolGreen,
      IOS26IconTone.warning => toolOrange,
      IOS26IconTone.danger => toolRed,
      IOS26IconTone.onAccent => onPrimaryColor,
    };
  }

  static IOS26IconChipColors iconChipColors(IOS26IconTone tone) {
    final isDark = isDarkMode;
    return switch (tone) {
      IOS26IconTone.onAccent => IOS26IconChipColors(
        background: primaryColor,
        foreground: onPrimaryColor,
        border: primaryColor.withValues(alpha: isDark ? 0.78 : 1),
      ),
      IOS26IconTone.accent => IOS26IconChipColors(
        background: primaryColor.withValues(alpha: isDark ? 0.22 : 0.12),
        foreground: primaryColor,
        border: primaryColor.withValues(alpha: isDark ? 0.46 : 0.24),
      ),
      IOS26IconTone.success => IOS26IconChipColors(
        background: toolGreen.withValues(alpha: isDark ? 0.25 : 0.12),
        foreground: toolGreen,
        border: toolGreen.withValues(alpha: isDark ? 0.52 : 0.3),
      ),
      IOS26IconTone.warning => IOS26IconChipColors(
        background: toolOrange.withValues(alpha: isDark ? 0.27 : 0.13),
        foreground: toolOrange,
        border: toolOrange.withValues(alpha: isDark ? 0.54 : 0.3),
      ),
      IOS26IconTone.danger => IOS26IconChipColors(
        background: toolRed.withValues(alpha: isDark ? 0.27 : 0.13),
        foreground: toolRed,
        border: toolRed.withValues(alpha: isDark ? 0.52 : 0.3),
      ),
      IOS26IconTone.primary => IOS26IconChipColors(
        background: textPrimary.withValues(alpha: isDark ? 0.14 : 0.08),
        foreground: textPrimary,
        border: textPrimary.withValues(alpha: isDark ? 0.24 : 0.16),
      ),
      IOS26IconTone.secondary => IOS26IconChipColors(
        background: textSecondary.withValues(alpha: isDark ? 0.18 : 0.1),
        foreground: textSecondary,
        border: textSecondary.withValues(alpha: isDark ? 0.3 : 0.18),
      ),
    };
  }

  static Color _adaptive({required Color light, required Color dark}) {
    return isDarkMode ? dark : light;
  }

  static Color get primaryColor =>
      _adaptive(light: _lightPrimaryColor, dark: _darkPrimaryColor);
  static Color get secondaryColor =>
      _adaptive(light: _lightSecondaryColor, dark: _darkSecondaryColor);

  static Color get backgroundColor =>
      _adaptive(light: _lightBackgroundColor, dark: _darkBackgroundColor);
  static Color get surfaceColor =>
      _adaptive(light: _lightSurfaceColor, dark: _darkSurfaceColor);
  static Color get surfaceVariant =>
      _adaptive(light: _lightSurfaceVariant, dark: _darkSurfaceVariant);
  static Color get cardColor =>
      _adaptive(light: _lightCardColor, dark: _darkCardColor);

  static Color get textPrimary =>
      _adaptive(light: _lightTextPrimary, dark: _darkTextPrimary);
  static Color get textSecondary =>
      _adaptive(light: _lightTextSecondary, dark: _darkTextSecondary);
  static Color get textTertiary =>
      _adaptive(light: _lightTextTertiary, dark: _darkTextTertiary);

  static Color get glassColor =>
      _adaptive(light: _lightGlassColor, dark: _darkGlassColor);
  static Color get glassBorderColor =>
      _adaptive(light: _lightGlassBorderColor, dark: _darkGlassBorderColor);

  static Color get overlayColor =>
      _adaptive(light: _lightOverlayColor, dark: _darkOverlayColor);
  static Color get shadowColor =>
      _adaptive(light: _lightShadowColor, dark: _darkShadowColor);
  static Color get shadowColorFaint =>
      _adaptive(light: _lightShadowColorFaint, dark: _darkShadowColorFaint);

  static Color get toolBlue =>
      _adaptive(light: _lightToolBlue, dark: _darkToolBlue);
  static Color get toolOrange =>
      _adaptive(light: _lightToolOrange, dark: _darkToolOrange);
  static Color get toolRed =>
      _adaptive(light: _lightToolRed, dark: _darkToolRed);
  static Color get toolGreen =>
      _adaptive(light: _lightToolGreen, dark: _darkToolGreen);
  static Color get toolPurple =>
      _adaptive(light: _lightToolPurple, dark: _darkToolPurple);
  static Color get toolPink =>
      _adaptive(light: _lightToolPink, dark: _darkToolPink);

  // ==================== 间距规范 ====================
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 20;
  static const double spacingXxl = 28;
  static const double spacingXxxl = 36;

  // ==================== 圆角规范 ====================
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 24;
  static const double radiusFull = 999;
  static const double radiusFormField = 14;

  // ==================== 交互尺寸规范 ====================
  static const Size minimumTapSize = Size(44, 44);

  /// 统一的表单文本输入框装饰（用于 CupertinoTextField.decoration）。
  static BoxDecoration textFieldDecoration({double? radius}) {
    return BoxDecoration(
      color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(radius ?? IOS26Theme.radiusFormField),
      border: Border.all(
        color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
        width: 0.5,
      ),
    );
  }

  static TextTheme _textThemeFor(Brightness brightness) {
    final primary = _textPrimaryFor(brightness);
    final secondary = _textSecondaryFor(brightness);
    final accent = _primaryFor(brightness);
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.37,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.36,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.36,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.38,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.32,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.24,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.24,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.08,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.24,
        color: accent,
      ),
    );
  }

  static Color _primaryFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? _darkPrimaryColor
        : _lightPrimaryColor;
  }

  static Color _secondaryFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? _darkSecondaryColor
        : _lightSecondaryColor;
  }

  static Color _backgroundFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? _darkBackgroundColor
        : _lightBackgroundColor;
  }

  static Color _surfaceFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? _darkSurfaceColor
        : _lightSurfaceColor;
  }

  static Color _cardFor(Brightness brightness) {
    return brightness == Brightness.dark ? _darkCardColor : _lightCardColor;
  }

  static Color _textPrimaryFor(Brightness brightness) {
    return brightness == Brightness.dark ? _darkTextPrimary : _lightTextPrimary;
  }

  static Color _textSecondaryFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? _darkTextSecondary
        : _lightTextSecondary;
  }

  static Color _textThemeTertiaryFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? _darkTextTertiary
        : _lightTextTertiary;
  }

  static Color _glassFor(Brightness brightness) {
    return brightness == Brightness.dark ? _darkGlassColor : _lightGlassColor;
  }

  // ==================== 文本样式静态访问器 ====================
  static TextTheme get _textTheme => _textThemeFor(_brightness);

  /// 大标题 (34pt, w700) - 用于页面主标题、品牌名称
  static TextStyle get displayLarge => _textTheme.displayLarge!;

  /// 次级大标题 (28pt, w700)
  static TextStyle get displayMedium => _textTheme.displayMedium!;

  /// 页面标题 (28pt, w600) - 用于导航栏大标题
  static TextStyle get headlineLarge => _textTheme.headlineLarge!;

  /// 卡片标题 (22pt, w600) - 用于卡片组标题
  static TextStyle get headlineMedium => _textTheme.headlineMedium!;

  /// 小标题 (20pt, w600)
  static TextStyle get headlineSmall => _textTheme.headlineSmall!;

  /// 列表项标题 (17pt, w600) - 用于列表项、卡片标题
  static TextStyle get titleLarge => _textTheme.titleLarge!;

  /// 次级标题 (16pt, w600)
  static TextStyle get titleMedium => _textTheme.titleMedium!;

  /// 小标题 (15pt, w600) - 用于小节标题
  static TextStyle get titleSmall => _textTheme.titleSmall!;

  /// 正文 (17pt, w400) - 主要阅读文本
  static TextStyle get bodyLarge => _textTheme.bodyLarge!;

  /// 次级正文 (15pt, w400) - 次要说明文本
  static TextStyle get bodyMedium => _textTheme.bodyMedium!;

  /// 辅助文本 (13pt, w400) - 提示、标注
  static TextStyle get bodySmall => _textTheme.bodySmall!;

  /// 按钮文本 (15pt, w500) - 用于按钮、链接
  static TextStyle get labelLarge => _textTheme.labelLarge!;

  /// 标签文本 (13pt, w700) - 用于标签、小按钮
  static TextStyle get labelSmall => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.08,
    color: textPrimary,
  );

  /// 获取主题数据
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final primary = _primaryFor(brightness);
    final secondary = _secondaryFor(brightness);
    final background = _backgroundFor(brightness);
    final surface = _surfaceFor(brightness);
    final card = _cardFor(brightness);
    final textPrimary = _textPrimaryFor(brightness);
    final textSecondary = _textSecondaryFor(brightness);
    final textTertiary = _textThemeTertiaryFor(brightness);
    final glass = _glassFor(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimaryColor,
        secondary: secondary,
        onSecondary: onPrimaryColor,
        error: brightness == Brightness.dark ? _darkToolRed : _lightToolRed,
        onError: onPrimaryColor,
        surface: surface,
        onSurface: textPrimary,
      ),
      fontFamily: 'Source Han Sans CN',
      fontFamilyFallback: const ['Noto Sans SC', 'Microsoft YaHei', 'Arial'],
      textTheme: _textThemeFor(brightness),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: primary,
        scaffoldBackgroundColor: background,
        barBackgroundColor: glass,
      ),
      appBarTheme: AppBarTheme(
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
        color: card,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerColor: textTertiary.withValues(alpha: 0.2),
      disabledColor: textSecondary.withValues(alpha: 0.5),
      shadowColor: brightness == Brightness.dark
          ? _darkShadowColor
          : _lightShadowColor,
      splashColor: primary.withValues(alpha: 0.15),
      highlightColor: primary.withValues(alpha: 0.08),
      canvasColor: background,
    );
  }
}

/// 在构建期将当前 [Theme] 亮度同步到 [IOS26Theme]，并在亮度变化时强制刷新子树。
///
/// 说明：项目中存在大量直接读取 `IOS26Theme.xxx` 静态 getter 的业务组件，
/// 这类组件不会自动订阅 `Theme.of(context)`，若不强制刷新可能出现系统亮暗切换后
/// 页面“部分颜色未更新”的情况。
class IOS26ThemeBrightnessSync extends StatelessWidget {
  final Widget child;

  const IOS26ThemeBrightnessSync({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    IOS26Theme.setBrightness(brightness);
    return KeyedSubtree(
      key: ValueKey<String>('ios26_theme_sync_${brightness.name}'),
      child: child,
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

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (disableBlurDuringRouteTransition && routeAnimation != null) {
      return AnimatedBuilder(
        animation: routeAnimation,
        builder: (context, _) {
          final status = routeAnimation.status;
          final isAnimating =
              status == AnimationStatus.forward ||
              status == AnimationStatus.reverse;
          return _buildWithBlur(context, isAnimating ? 0 : blur);
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

/// iOS 26 风格的导航栏
enum _IOS26AppBarVariant { standard, home }

class IOS26AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onTitlePressed;
  final bool useSafeArea;
  final _IOS26AppBarVariant _variant;

  const IOS26AppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.onBackPressed,
    this.onTitlePressed,
    this.useSafeArea = true,
  }) : onSettingsPressed = null,
       _variant = _IOS26AppBarVariant.standard;

  const IOS26AppBar.home({
    super.key,
    required this.title,
    this.onSettingsPressed,
    this.onTitlePressed,
  }) : actions = null,
       leading = null,
       showBackButton = false,
       onBackPressed = null,
       useSafeArea = false,
       _variant = _IOS26AppBarVariant.home;

  @override
  Size get preferredSize =>
      Size.fromHeight(_variant == _IOS26AppBarVariant.home ? 64 : 56);

  @override
  Widget build(BuildContext context) {
    final content = _variant == _IOS26AppBarVariant.home
        ? _buildHomeContent(context)
        : _buildStandardContent(context);
    final wrapped = useSafeArea
        ? SafeArea(bottom: false, child: content)
        : content;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: _variant == _IOS26AppBarVariant.home
              ? null
              : BoxDecoration(
                  color: IOS26Theme.glassColor,
                  border: Border(
                    bottom: BorderSide(
                      color: IOS26Theme.glassBorderColor,
                      width: 0.5,
                    ),
                  ),
                ),
          child: wrapped,
        ),
      ),
    );
  }

  Widget _buildStandardContent(BuildContext context) {
    final hasActions = actions != null && actions!.isNotEmpty;
    return SizedBox(
      height: 56,
      child: NavigationToolbar(
        centerMiddle: true,
        leading: showBackButton
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: IOS26Theme.minimumTapSize,
                onPressed: onBackPressed ?? () => Navigator.pop(context),
                child: Icon(
                  CupertinoIcons.back,
                  color: IOS26Theme.iconColor(IOS26IconTone.accent),
                  size: 20,
                ),
              )
            : (leading ?? SizedBox(width: IOS26Theme.minimumTapSize.width)),
        middle: Text(
          title,
          style: IOS26Theme.titleLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        trailing: hasActions
            ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
            : SizedBox(width: IOS26Theme.minimumTapSize.width),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    final titleWidget = Text(title, style: IOS26Theme.displayLarge);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingXl,
        vertical: IOS26Theme.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          onTitlePressed == null
              ? titleWidget
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: IOS26Theme.minimumTapSize,
                  pressedOpacity: 1,
                  onPressed: onTitlePressed,
                  child: titleWidget,
                ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: IOS26Theme.minimumTapSize,
            onPressed: onSettingsPressed,
            child: Container(
              padding: const EdgeInsets.all(IOS26Theme.spacingMd),
              decoration: BoxDecoration(
                color: IOS26Theme.glassColor,
                borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
                border: Border.all(
                  color: IOS26Theme.glassBorderColor,
                  width: 0.5,
                ),
              ),
              child: Icon(
                CupertinoIcons.gear,
                color: IOS26Theme.iconColor(IOS26IconTone.secondary),
                size: 22,
              ),
            ),
          ),
        ],
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
    setControllerTextWhenComposingIdle(
      widget.controller,
      '',
      shouldContinue: () => mounted,
    );
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
    final chipColors = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.maxFieldWidth + 44);
        final maxField = (availableWidth - 44)
            .clamp(0.0, widget.maxFieldWidth)
            .toDouble();
        final minField = widget.minFieldWidth.clamp(0.0, maxField).toDouble();

        final raw = widget.controller.text;
        final textWidth = _measureTextWidth(
          context: context,
          text: raw,
          style: IOS26Theme.labelSmall,
        );
        final desiredField = raw.trim().isEmpty
            ? minField
            : (textWidth + 24).clamp(minField, maxField).toDouble();

        return DecoratedBox(
          decoration: BoxDecoration(
            color: chipColors.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: chipColors.border, width: 1),
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
                        decoration: BoxDecoration(color: Colors.transparent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        style: IOS26Theme.labelSmall,
                        placeholderStyle: IOS26Theme.labelSmall.copyWith(
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
                      minimumSize: IOS26Theme.minimumTapSize,
                      pressedOpacity: 0.7,
                      onPressed: widget.loading ? null : _commit,
                      child: widget.loading
                          ? const CupertinoActivityIndicator(radius: 10)
                          : Icon(
                              CupertinoIcons.check_mark,
                              size: 14,
                              color: IOS26Theme.iconColor(
                                IOS26IconTone.success,
                              ),
                            ),
                    ),
                  ],
                )
              : CupertinoButton(
                  key: widget.buttonKey,
                  padding: EdgeInsets.zero,
                  minimumSize: IOS26Theme.minimumTapSize,
                  pressedOpacity: 0.7,
                  onPressed: widget.loading ? null : _expand,
                  child: widget.loading
                      ? const CupertinoActivityIndicator(radius: 10)
                      : Icon(
                          CupertinoIcons.add,
                          size: 14,
                          color: IOS26Theme.iconColor(IOS26IconTone.accent),
                        ),
                ),
        );
      },
    );
  }
}
