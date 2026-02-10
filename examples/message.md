# 消息通知调用示例

本项目已在 `lib/main.dart` 通过 Provider 全局注入 `MessageService`，业务侧（页面/工具/服务）只需要通过 `context.read<MessageService>()` 获取即可。

## 1) 发送/更新一条消息（推荐：带 `dedupeKey`）

`dedupeKey` 用于"同一条消息的更新"，例如：同一个物品的临期提醒每天只更新内容，不新增多条记录。

> **默认过期行为**：如果不传 `expiresAt`，消息会在 **当天 00:00 + 1 天（即次日 00:00）** 自动过期清理。
> 如需更长/更短的过期时间，可显式传入 `expiresAt`。

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/messages/message_service.dart';

final messageService = context.read<MessageService>();

// expiresAt 不传 → 默认次日 00:00 过期
await messageService.upsertMessage(
  toolId: 'stockpile_assistant',
  title: '囤货助手',
  body: '【囤货助手】牛奶将在 2 天后到期（2026-01-03），剩余 1 瓶。',
  dedupeKey: 'stockpile:expiry:123', // 稳定 key：同一条提醒固定一个 key
  route: 'tool://stockpile_assistant', // 点击消息跳转到工具
  notify: true, // 是否触发系统通知（Android/iOS）
);

// 显式传入 expiresAt → 使用传入值
await messageService.upsertMessage(
  toolId: 'stockpile_assistant',
  title: '囤货助手',
  body: '【囤货助手】牛奶将在 2 天后到期（2026-01-03），剩余 1 瓶。',
  dedupeKey: 'stockpile:expiry:123',
  route: 'tool://stockpile_assistant',
  expiresAt: DateTime.now().add(const Duration(days: 7)), // 7 天后过期
  notify: true,
);
```

说明：`notify: true` 仅在 Android/iOS（`LocalNotificationService` 已注入且已申请通知权限）时生效；桌面/Web 平台会自动忽略，不会报错。

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
