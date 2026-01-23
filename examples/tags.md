# 标签公共接口示例
本项目已在 `lib/main.dart` 通过 Provider 全局注入 `TagService`，业务侧（页面/工具/服务）可直接通过 `context.read<TagService>()` 获取并调用。

## 0)（可选）为工具注册「标签分类」
标签管理已支持「工具 -> 分类 -> 标签」的结构；分类由工具通过公共方法注册产生：

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/tags/models/tag_category.dart';
import 'package:life_tools/core/tags/tag_service.dart';

context.read<TagService>().registerToolTagCategories('work_log', const [
  TagCategory(id: 'priority', name: '优先级', createHint: '紧急/重要'),
  TagCategory(id: 'project', name: '项目', createHint: '小蜜/家庭/工作'),
  TagCategory(id: 'scene', name: '场景', createHint: '会议/开发/复盘'),
]);
```

- 如果工具不调用注册：该工具在标签管理中只会显示 1 个默认分类（`default` / “默认”），并兼容旧数据。
- `createHint` 会用于「标签管理 -> 该工具 -> 该分类 -> 添加标签」时输入框的灰色提示；不传时默认用 `${分类名}标签`（显示为 `如：${分类名}标签`）。

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
  - `tool_tags` 里包含 `category_id` 与 `sort_index`；旧备份若缺失会在导入时自动补默认值（`default` / `0`）。
