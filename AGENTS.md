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

## AI 功能（OpenAI 兼容）

### 1) 配置入口（UI）

- 首页右上角点击设置（齿轮）→ 进入设置弹窗 → 点击 `AI配置`
- 需要填写/建议填写：
  - `Base URL`：支持 `https://api.openai.com/v1` 或 `https://你的域名`（代码会自动补全到 `/v1/chat/completions`）
  - `API Key`：`Bearer` 方式的 key（示例：`sk-...`）
  - `Model`：如 `gpt-4o-mini`（按你的服务端支持填写）
  - `Temperature`：0~2
  - `Max Tokens`：输出上限（>0）

### 2) 代码公共入口（推荐用法）

项目在 `lib/main.dart` 已全局注入 `AiService`，在任意页面/工具中可通过 Provider 获取：

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/ai/ai_models.dart';

final ai = context.read<AiService>();

// 最常用：传入 prompt，拿到返回文本
final text = await ai.chatText(
  prompt: '请总结以下内容：...',
  systemPrompt: '你是一个严谨的助手',
);

// 需要强制 AI 输出 JSON（方便业务侧 jsonDecode 后解析）
final jsonText = await ai.chatText(
  prompt: '请只输出一个 JSON：{"result": "..."}',
  responseFormat: AiResponseFormat.jsonObject,
);
```

如果你需要更灵活的消息结构（多轮对话/历史消息），可使用 `chat(...)`：

```dart
final result = await ai.chat(
  messages: const [
    AiMessage.system('你是一个助手'),
    AiMessage.user('你好'),
  ],
);
print(result.text);
```

### 3) 可能抛出的异常

- `AiNotConfiguredException`：未在 UI 中完成 AI 配置（或配置不合法）
- `AiApiException`：服务端返回非 2xx（包含 `statusCode` 与 `message`）

### 4) 相关代码位置

- 配置模型/持久化：`lib/core/ai/ai_config.dart`、`lib/core/ai/ai_config_service.dart`
- 调用入口（公共）：`lib/core/ai/ai_service.dart`
- OpenAI 兼容 HTTP 客户端：`lib/core/ai/openai_client.dart`
- 数据结构/枚举：`lib/core/ai/ai_models.dart`
