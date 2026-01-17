# 消息通知调用示例

本项目已在 `lib/main.dart` 通过 Provider 全局注入 `MessageService`，业务侧（页面/工具/服务）只需要通过 `context.read<MessageService>()` 获取即可。

## 1) 发送/更新一条消息（推荐：带 `dedupeKey`）

`dedupeKey` 用于“同一条消息的更新”，例如：同一个物品的临期提醒每天只更新内容，不新增多条记录。

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/messages/message_service.dart';

final messageService = context.read<MessageService>();

await messageService.upsertMessage(
  toolId: 'stockpile_assistant',
  title: '囤货助手',
  body: '【囤货助手】牛奶将在 2 天后到期（2026-01-03），剩余 1 瓶。',
  dedupeKey: 'stockpile:expiry:123', // 稳定 key：同一条提醒固定一个 key
  route: 'tool://stockpile_assistant', // 点击消息跳转到工具
  // expiresAt: DateTime.now().add(const Duration(days: 7)), // 可选：到期自动清理
  notify: true, // 是否触发系统通知（Android/iOS）
);
```

## 2) 工具主动消除消息（例如：物品已消耗完）

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/messages/message_service.dart';

final messageService = context.read<MessageService>();

await messageService.deleteMessageByDedupeKey('stockpile:expiry:123');
```

## 3) 标记已读

首页点击跳转会自动算作“已读”。在“全部消息”页面也支持右滑标记已读。

如果业务侧需要手动标记：

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/messages/message_service.dart';

final messageService = context.read<MessageService>();

await messageService.markMessageRead(1); // 通过消息 id 标记已读
```

## 4) 路由字段约定

当前内置支持最基础的工具跳转：

- `route: 'tool://<toolId>'`：跳转到该工具首页（推荐）
- `route: '<toolId>'`：等同于上面
- `route: null`：默认使用 `toolId` 跳转

后续如需支持“跳到工具内更深的页面”，可以在此基础上扩展路由格式。

