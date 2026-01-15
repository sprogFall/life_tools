# Repository Guidelines

## Agent注意事项
1. 永远用中文回答我

## 开发原则

1. **TDD（测试驱动开发）**：编写功能代码之前，先编写测试类，覆盖尽可能多的场景。每次修改后必须执行测试用例，并及时补充新功能所需的测试案例
2. **简约原则**：不要过度设计，保持代码简洁，避免不必要的复杂化
3. **零容忍重复**：必须复用代码，杜绝重复逻辑
4. **中文响应**：始终使用中文进行交流和回复

## 项目概述

这是一个名为 "life_tools" 的 Flutter 应用，支持 Android、iOS、Web、Linux、macOS 和 Windows 多平台。使用 Dart SDK ^3.10.7。
数据全部记录在应用本地（SQLite）
## 常用命令

所有命令均兼容 Windows 系统（PowerShell/CMD）。

```bash
# 安装依赖
flutter pub get

# 运行应用（调试模式）
flutter run

# 在指定设备上运行
flutter run -d chrome    # Web
flutter run -d windows   # Windows
flutter run -d android   # Android 模拟器/真机

# 构建发布版本
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web

# 运行所有测试（开发过程中频繁使用）
flutter test

# 运行单个测试文件
flutter test test/widget_test.dart

# 运行测试并生成覆盖率报告
flutter test --coverage

# 静态代码分析
flutter analyze

# 格式化代码
dart format .
```

## 架构

- **lib/main.dart** - 应用入口，包含 `MyApp` 根组件和 `MyHomePage` 主页面
- **test/** - 使用 `flutter_test` 包的 Widget 测试
- 使用 Material Design（`uses-material-design: true`）
- 通过 `flutter_lints` 包进行代码检查（配置在 `analysis_options.yaml`）

## AI 调用（公共入口）

项目在 `lib/main.dart` 已注入 `AiService`，业务侧通过 Provider 获取后调用 `chatText(...)` 或 `chat(...)` 即可。

示例代码请查看：`examples/ai.md`

## 标签调用（公共入口）

项目在 `lib/main.dart` 已注入 `TagService`，业务侧通过 Provider 获取后即可查询「当前工具可用的标签」，并用标签实现各工具内部功能（如：工作记录的任务打标签/按标签筛选）。

示例代码请查看：`examples/tags.md`

## UI 设计规范

### 主题颜色

项目使用 iOS 26 风格的设计主题，所有颜色定义在 `lib/core/theme/ios26_theme.dart` 中：

**主色调：**
- `IOS26Theme.primaryColor` - 主要操作色（蓝色 #007AFF）
- `IOS26Theme.secondaryColor` - 次要操作色（紫色 #5856D6）

**文字颜色：**
- `IOS26Theme.textPrimary` - 主要文字（深色 #1C1C1E）
- `IOS26Theme.textSecondary` - 次要文字（灰色 #8E8E93）
- `IOS26Theme.textTertiary` - 辅助文字（浅灰 #C7C7CC）

**工具颜色：**
- `IOS26Theme.toolBlue` - 工具蓝（#007AFF）
- `IOS26Theme.toolGreen` - 工具绿（#34C759）
- `IOS26Theme.toolOrange` - 工具橙（#FF9500）
- `IOS26Theme.toolRed` - 工具红（#FF3B30）
- `IOS26Theme.toolPurple` - 工具紫（#5856D6）
- `IOS26Theme.toolPink` - 工具粉（#FF2D55）

### 按钮颜色使用规范

**主要操作按钮（Primary）：**
- 背景色：`IOS26Theme.primaryColor`
- 文字色：`Colors.white`
- 适用场景：提交、确认、保存等主要操作
- 示例：AI录入页面的"提交给AI"按钮

**次要操作按钮（Secondary）：**
- 背景色：`IOS26Theme.textTertiary.withValues(alpha: 0.3)` （半透明浅灰）
- 图标色：`IOS26Theme.textSecondary`
- 适用场景：取消、清空、删除等辅助操作
- 示例：AI录入页面的清空（垃圾桶）、取消（×）按钮

**按钮圆角：**
- 统一使用 `BorderRadius.circular(14)` 保持 iOS 26 风格

**按钮内边距：**
- 主要按钮：`EdgeInsets.symmetric(vertical: 14)`
- 图标按钮：`EdgeInsets.symmetric(horizontal: 16, vertical: 14)`
