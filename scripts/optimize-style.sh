#!/bin/bash

# 确保脚本抛出遇到的错误
set -e

echo "🚀 开始执行代码美学与质量优化脚本..."

# 1. 格式化代码 (Dart 官方格式化工具)
echo "📝 正在格式化所有 Dart 代码..."
dart format .

# 2. 依赖检查 (仅列出过时依赖，不自动升级以防破坏变更)
echo "📦 检查过时依赖..."
flutter pub outdated || true

# 3. 静态代码分析
echo "🔍 执行静态代码分析..."
flutter analyze

# 4. 清理构建产物 (可选，释放空间)
# echo "🧹 清理构建产物..."
# flutter clean

echo "✅ 优化完成！请查看上方输出的分析报告和过时依赖列表。"
echo "💡 提示：若需升级依赖，请手动运行 'flutter pub upgrade --major-versions' 并测试兼容性。"
