# 标签系统使用指南

标签管理系统提供了一个统一的标签基础设施，允许用户在应用内创建和管理标签，并将标签关联到不同的工具。本文档说明了如何使用标签系统。

## 核心概念

### 标签（Tag）
- 标签有名称、颜色和描述
- 标签可以关联到多个工具（例如，"重要"标签可以用于工作记录、复盘笔记等多个工具）
- 标签存储在统一的 `tags` 表中

### 标签关联
- **标签-工具关联**：定义哪些工具可以使用某个标签（存储在 `tag_tool_associations` 表中）
- **标签-实体关联**：将标签关联到具体的实体（例如工作记录的任务），存储在工具特定的关联表中

## 公共API使用

### TagService - 标签公共服务

`TagService` 提供了供其他工具使用的公共接口：

```dart
import 'package:your_app/core/tag/services/tag_service.dart';

final tagService = TagService();
```

#### 获取可用标签

获取某个工具可用的所有标签：

```dart
// 获取工作记录工具可用的标签
final tags = await tagService.getAvailableTags('work_log');

// tags 返回 List<Tag>
for (final tag in tags) {
  print('标签: ${tag.name}, 颜色: ${tag.color}');
}
```

#### 检查标签是否可用

```dart
final isAvailable = await tagService.isTagAvailableForTool(tagId, 'work_log');
```

#### 为工具创建标签

```dart
final newTag = await tagService.createTagForTool(
  toolId: 'work_log',
  name: '重要',
  color: Colors.red.value,  // 使用 ARGB 颜色值
  description: '重要任务',
);
```

#### 为实体添加/移除标签

为特定实体（如任务）添加或移除标签：

```dart
// 添加标签到任务
await tagService.addTagToTask(tagId, taskId);

// 从任务移除标签
await tagService.removeTagFromTask(tagId, taskId);

// 批量设置任务的标签（覆盖原有标签）
await tagService.setTaskTags(taskId, [tagId1, tagId2, tagId3]);
```

#### 查询实体的标签

```dart
// 获取任务的所有标签
final tags = await tagService.getTagsForTask(taskId);

// 检查任务是否有某个标签
final hasTag = await tagService.taskHasTag(taskId, tagId);

// 获取具有某个标签的所有任务
final taskIds = await tagService.getTaskIdsForTag(tagId);
```

#### 标签管理

```dart
// 更新标签信息
await tagService.updateTag(tag);

// 删除标签（会自动删除所有关联）
await tagService.deleteTag(tagId);

// 为标签添加工具关联
await tagService.addTagToTool(tagId, toolId);

// 从标签移除工具关联
await tagService.removeTagFromTool(tagId, toolId);
```

## 实际应用示例

### 在工作记录中集成标签

#### 1. 保存任务时设置标签

```dart
class WorkLogService {
  final WorkLogRepository _repository;
  final TagService _tagService = TagService();

  Future<void> saveTask(WorkTask task, List<int> tagIds) async {
    // 保存任务基本信息
    final taskId = await _repository.createTask(task);
    
    // 设置任务的标签
    await _tagService.setTaskTags(taskId, tagIds);
  }
}
```

#### 2. 在UI中显示和选择标签

```dart
class TaskEditPage extends StatefulWidget {
  @override
  _TaskEditPageState createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final TagService _tagService = TagService();
  List<Tag> _availableTags = [];
  List<int> _selectedTagIds = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableTags();
  }

  Future<void> _loadAvailableTags() async {
    final tags = await _tagService.getAvailableTags('work_log');
    setState(() => _availableTags = tags);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('编辑任务')),
      body: Column(
        children: [
          // 任务基本信息表单...
          
          // 标签选择
          Padding(
            padding: EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTagIds.contains(tag.id);
                return FilterChip(
                  selected: isSelected,
                  label: Text(tag.name),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTagIds.add(tag.id!);
                      } else {
                        _selectedTagIds.remove(tag.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 3. 按标签筛选任务

```dart
class TaskListPage extends StatefulWidget {
  @override
  _TaskListPageState createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final WorkLogRepository _repository = WorkLogRepository();
  final TagService _tagService = TagService();
  List<WorkTask> _tasks = [];
  int? _selectedTagId;

  Future<void> _loadTasks() async {
    final tasks = await _repository.listTasks(
      tagId: _selectedTagId,  // 按标签筛选
    );
    setState(() => _tasks = tasks);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标签筛选器
        FutureBuilder<List<Tag>>(
          future: _tagService.getAvailableTags('work_log'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();
            
            final tags = snapshot.data!;
            return Wrap(
              children: [
                FilterChip(
                  label: Text('全部'),
                  selected: _selectedTagId == null,
                  onSelected: (_) {
                    setState(() => _selectedTagId = null);
                    _loadTasks();
                  },
                ),
                ...tags.map((tag) => FilterChip(
                  label: Text(tag.name),
                  selected: _selectedTagId == tag.id,
                  onSelected: (_) {
                    setState(() => _selectedTagId = tag.id);
                    _loadTasks();
                  },
                )).toList(),
              ],
            );
          },
        ),
        
        // 任务列表
        Expanded(
          child: ListView.builder(
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return ListTile(
                title: Text(task.title),
                subtitle: Text(task.description),
                // 显示任务的标签
                trailing: Wrap(
                  children: task.tags.map((tag) => 
                    Container(
                      width: 12,
                      height: 12,
                      color: Color(tag.color),
                      margin: EdgeInsets.only(right: 4),
                    )
                  ).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

### 在Repository中使用标签

```dart
class WorkLogRepository implements WorkLogRepositoryBase {
  
  Future<List<WorkTask>> listTasks({
    WorkTaskStatus? status,
    int? tagId,  // 新增：按标签筛选
  }) async {
    final db = await _database;
    
    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];
    
    if (status != null) {
      whereConditions.add('status = ?');
      whereArgs.add(status.value);
    }
    
    // 按标签筛选
    if (tagId != null) {
      whereConditions.add('''
        id IN (
          SELECT task_id FROM work_task_tags 
          WHERE tag_id = ?
        )
      ''');
      whereArgs.add(tagId);
    }
    
    final results = await db.query(
      'work_tasks',
      where: whereConditions.isEmpty ? null : whereConditions.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );
    
    // 为每个任务加载标签
    final tasks = <WorkTask>[];
    for (final row in results) {
      final taskId = row['id'] as int;
      final tags = await _tagService.getTagsForTask(taskId);
      tasks.add(WorkTask.fromMap(row, tags: tags));
    }
    
    return tasks;
  }
}
```

## 同步和备份

标签数据完美适配应用的同步和备份系统：

### 同步支持
- `TagSyncProvider` 实现了 `ToolSyncProvider` 接口
- 同步时导出标签和标签-工具关联数据
- 不包含具体的实体标签关联（这些由各个工具自己同步）

### 导出数据结构

```json
{
  "version": 1,
  "data": {
    "tags": [
      {
        "id": 1,
        "name": "重要",
        "color": 4294198070,
        "description": "重要任务",
        "created_at": 1234567890000,
        "updated_at": 1234567890000
      }
    ],
    "tag_tool_associations": [
      {
        "id": 1,
        "tag_id": 1,
        "tool_id": "work_log",
        "created_at": 1234567890000
      }
    ]
  }
}
```

## 最佳实践

### 1. 标签命名规范
- 使用简洁明了的中文名称
- 避免过长的标签名称
- 使用统一的命名风格（例如全中文，不使用混合中英文）

### 2. 标签颜色规范
- 使用应用主题中的颜色常量
- 保持颜色的一致性（例如，红色表示重要，绿色表示完成等）
- 避免使用过于相似的颜色

```dart
// 推荐的标签颜色使用方式
import 'core/theme/ios26_theme.dart';

final tagColors = [
  IOS26Theme.toolRed,      // 重要/紧急
  IOS26Theme.toolOrange,   // 警告/注意
  IOS26Theme.toolGreen,    // 完成/正常
  IOS26Theme.toolBlue,     // 信息/进行中
  IOS26Theme.toolPurple,   // 特殊/其他
];
```

### 3. 错误处理

```dart
try {
  final tags = await tagService.getAvailableTags('work_log');
} catch (e) {
  // 处理错误，例如显示错误提示
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('加载标签失败: $e')),
  );
}
```

### 4. 性能优化

- 缓存常用标签，避免重复查询
- 批量操作标签时，使用事务（Repository层面已处理）
- 按需加载标签，避免一次性加载所有标签

```dart
class TagCache {
  final Map<String, List<Tag>> _toolTags = {};
  
  Future<List<Tag>> getTagsForTool(String toolId) async {
    if (_toolTags.containsKey(toolId)) {
      return _toolTags[toolId]!;
    }
    
    final tags = await _tagService.getAvailableTags(toolId);
    _toolTags[toolId] = tags;
    return tags;
  }
  
  void invalidateCache(String toolId) {
    _toolTags.remove(toolId);
  }
}
```

## 常见问题

### Q: 如何为工具添加标签支持？
A: 1. 创建实体-标签关联表（如 `your_entity_tags`）
   2. 使用 `TagService` 进行标签关联操作
   3. 在界面上集成标签选择组件

### Q: 标签删除后会发生什么？
A: 使用 CASCADE 外键约束，删除标签会自动删除所有关联（包括实体关联）

### Q: 如何在同步时处理标签？
A: 标签管理工具负责同步标签定义和标签-工具关联。各个工具负责同步自己的实体-标签关联。

### Q: 如何处理标签重名？
A: 标签名称是唯一的（UNIQUE 约束），创建同名标签会抛出异常。建议在创建前先检查是否存在。

```dart
final existingTag = await tagService.getTagByName('重要');
if (existingTag != null) {
  // 标签已存在，使用现有标签或直接关联
  await tagService.addTagToTool(existingTag.id!, toolId);
} else {
  // 创建新标签
  await tagService.createTagForTool(...);
}
```

## 总结

标签系统提供了：
- ✨ 统一的标签管理和存储
- 🔗 标签与工具的多对多关联
- 🏷️ 标签与实体的灵活关联
- 🔄 完整的同步和备份支持
- 📱 易用的公共API接口
- 🎨 iOS 26 风格的UI组件

通过 `TagService`，任何工具都可以轻松地集成标签功能，为用户提供更好的组织和管理能力。