# 标签公共接口示例
本项目已在 `lib/main.dart` 通过 Provider 全局注入 `TagService`，业务侧（页面/工具/服务）可直接通过 `context.read<TagService>()` 获取并调用。

## 1) 查询某个工具当前可用的标签
```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/tags/tag_service.dart';

final tagService = context.read<TagService>();

final tags = await tagService.listTagsForTool('work_log');
for (final t in tags) {
  print('tag: ${t.id} ${t.name}');
}
```

## 2) 工作记录：任务打标签（创建/编辑时传入 tagIds）
```dart
// WorkTaskEditPage 内部已支持选择标签并传给 WorkLogService.createTask/updateTask
await service.createTask(task, tagIds: [1, 2, 3]);

// 更新任务时，如果传入 tagIds 会覆盖该任务的标签；不传则保留原标签
await service.updateTask(task, tagIds: [2, 3]);
await service.updateTask(task); // 不改标签
```

## 3) 工作记录：按标签筛选任务列表
```dart
// WorkLogRepository.listTasks 支持传入 tagIds（任意匹配）
final tasks = await repository.listTasks(tagIds: [1, 2]);
```

## 4) 导入/导出（备份/还原）说明
- `tag_manager`：导出/导入 `tags` 与 `tool_tags`
- `work_log`：额外导出/导入 `task_tags`（任务-标签关联）

