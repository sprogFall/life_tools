import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/theme/ios26_theme.dart';
import '../pages/home_page.dart';

/// 工具占位页面，iOS 26 风格
class PlaceholderToolPage extends StatelessWidget {
  final String toolName;

  const PlaceholderToolPage({super.key, required this.toolName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: Stack(
        children: [
          // 背景装饰
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    IOS26Theme.toolOrange.withValues(alpha: 0.15),
                    IOS26Theme.toolOrange.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    IOS26Theme.primaryColor.withValues(alpha: 0.1),
                    IOS26Theme.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 主内容
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: _buildContent(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: IOS26Theme.glassColor,
            border: Border(
              bottom: BorderSide(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => _navigateToHome(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.home,
                      color: IOS26Theme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '首页',
                      style: TextStyle(
                        fontSize: 17,
                        color: IOS26Theme.primaryColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  toolName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.41,
                    color: IOS26Theme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标容器
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    IOS26Theme.textTertiary.withValues(alpha: 0.3),
                    IOS26Theme.textTertiary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                CupertinoIcons.hammer,
                size: 48,
                color: IOS26Theme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            // 标题
            Text(
              toolName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.36,
                color: IOS26Theme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // 描述
            Text(
              '功能开发中，敬请期待...',
              style: TextStyle(
                fontSize: 17,
                color: IOS26Theme.textSecondary.withValues(alpha: 0.8),
                letterSpacing: -0.41,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // 返回首页按钮
            GestureDetector(
              onTap: () => _navigateToHome(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: IOS26Theme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: IOS26Theme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_left,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '返回首页',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.41,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }
}
