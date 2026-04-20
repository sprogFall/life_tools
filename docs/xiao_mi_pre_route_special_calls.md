# 小蜜 AI 预选路由与 Special Call 清单

本文档说明小蜜当前支持的 AI 触发提示词、预选路由协议、special_call 接口、字段裁剪能力与维护约定。

## 1. 调用机制

小蜜聊天发送消息后，固定执行两次 AI 调用：

1. 第一次：预选路由，非流式，只负责判断是否需要触发 special_call，返回 JSON。
2. 第二次：正式回答，流式输出；若命中 special_call，会先注入本地数据，再生成回答。

预选结果示例：

```json
{"type":"special_call","call":"work_time_query","arguments":{"start_date":"20260401","end_date":"20260430","keyword":"接口","statuses":["doing"],"affiliation_names":["项目A"],"fields":["work_date","task_title","minutes"],"limit":20}}
```

未命中示例：

```json
{"type":"no_special_call"}
```

## 2. 当前支持的 AI 触发提示词

这里的“提示词”分为两类：

- 快捷提示词：前端直接展示，命中后跳过预选路由。
- 自然语言触发：用户自由输入，先经过 pre-route，再决定是否触发 special_call。

### 2.1 快捷提示词

| 展示文案 | special_call | 能力 |
| --- | --- | --- |
| 本周工作总结 | `work_log_week_summary` | 读取本周工作记录并生成周总结 |
| 本月工作总结 | `work_log_month_summary` | 读取本月工作记录并生成月总结 |
| 本季度工作总结 | `work_log_quarter_summary` | 读取本季度工作记录并生成季度总结 |
| 今年工作总结 | `work_log_year_summary` | 读取今年工作记录并生成年度总结 |

### 2.2 自然语言触发示例

| 用户说法示例 | 预期 special_call | 能力 |
| --- | --- | --- |
| 请基于今年记录写一个工作总结 | `work_log_range_summary` | 读取指定时间范围的工作记录并生成总结 |
| 查一下标题里有防汛的任务 | `work_task_query` | 直接查询当前任务列表，允许没有工时也能命中 |
| 查下四月项目A里跟接口相关且进行中的工作记录 | `work_time_query` | 按时间、关键词、状态、归属标签组合筛选工时记录 |
| 查最近两周已完成的工作记录，只看日期和任务名 | `work_time_query` | 查询工时记录并只返回指定字段 |
| 宫保鸡丁怎么做 | `overcooked_context_query` | 查询胡闹厨房菜谱正文 |
| 2026-03-05 做了什么菜 | `overcooked_context_query` | 查询指定日期做菜记录 |

说明：

- 总结/复盘/汇报类意图优先走 `work_log_range_summary`。
- 查任务列表/任务标题类意图优先走 `work_task_query`。
- 查工时、工作记录明细、花了多久类意图优先走 `work_time_query`。
- 胡闹厨房目前支持“查菜谱”和“查某天做了什么菜”两类本地数据查询。

## 3. Special Call 接口清单

| call | 主要用途 | 核心参数 | 当前能力 |
| --- | --- | --- | --- |
| `work_log_range_summary` | 通用工作总结 | `start_date` `end_date` `style` | 按任意日期范围生成总结 |
| `work_log_week_summary` | 周总结 | 兼容旧参数 | 自动换算周一到周日 |
| `work_log_month_summary` | 月总结 | 兼容旧参数 | 自动换算月初到月末 |
| `work_log_quarter_summary` | 季度总结 | 兼容旧参数 | 自动换算季度范围 |
| `work_log_year_summary` | 年总结 | 兼容旧参数 | 自动换算全年范围 |
| `work_task_query` | 任务查询 | `keyword` `status/statuses` `affiliation_names` `fields` `limit` | 直接查询当前任务列表，不依赖工时存在 |
| `work_time_query` | 工时查询 | `start_date` `end_date` `keyword` `status/statuses` `affiliation_names` `fields` `limit` | 多条件组合筛选 + 字段裁剪 |
| `work_log_query` | 旧版工时查询别名 | 同 `work_time_query` | 向后兼容，语义等同于 `work_time_query` |
| `overcooked_context_query` | 胡闹厨房本地数据查询 | `query_type` + 对应参数 | 查菜谱 / 查某天做菜记录 |

向后兼容：

- `work_log_week_summary`
- `work_log_month_summary`
- `work_log_quarter_summary`
- `work_log_year_summary`

这些旧 call 仍可继续使用，但新协议优先推荐：

- 总结类统一用 `work_log_range_summary`
- 任务查询类统一用 `work_task_query`
- 工时明细查询类统一用 `work_time_query`
- `work_log_query` 仅作为旧版兼容别名保留

## 4. 工作记录接口能力

### 4.1 `work_log_range_summary`

适用场景：

- 周报、月报、季报、年报
- 复盘、阶段性总结、管理汇报

参数：

- `style`：`concise | review | risk | highlight | management`
- `start_date`：`YYYYMMDD`
- `end_date`：`YYYYMMDD`

说明：

- 旧版总结 call 仍兼容 `date` / `anchor_date` / `year` / `month` / `quarter`。
- 客户端会把相对时间换算成绝对日期。

### 4.2 `work_task_query`

适用场景：

- 查询当前有哪些任务
- 查询标题包含某关键词的任务
- 查询某个状态、某些归属标签下的任务
- 明确要确认“是否存在某个任务”时

参数：

- `keyword`：关键词，会匹配任务标题、任务描述、归属标签
- `status`：单个状态，`todo | doing | done | canceled`
- `statuses`：多个状态，数组形式
- `affiliation_names`：归属标签名数组，例如 `["项目A","团队B"]`
- `fields`：限定返回字段，见下表
- `limit`：返回结果条数上限，默认 20，最大 100

字段白名单：

| 字段名 | 含义 |
| --- | --- |
| `task_title` | 任务标题 |
| `task_status` | 任务状态 |
| `affiliations` | 任务归属标签 |
| `task_description` | 任务描述 |
| `estimated_minutes` | 预估工时 |
| `task_id` | 任务 ID |
| `is_pinned` | 是否置顶 |

筛选行为：

- `work_task_query` 查询的是当前任务列表，不要求任务已经有工时记录。
- `keyword` 会匹配任务标题、任务描述和归属标签。
- `affiliation_names` 基于工作记录工具的“归属”标签匹配。
- 若 pre-route 把与 `keyword` 完全相同的词也放进了 `affiliation_names`，且用户并未明确要求“按归属/标签筛选”，客户端会自动去掉这类重复标签条件，避免把“标题命中但未打同名标签”的任务误过滤掉。
- `fields` 只控制“任务列表”返回哪些字段。

推荐输出示例：

```json
{
  "type": "special_call",
  "call": "work_task_query",
  "arguments": {
    "keyword": "防汛",
    "statuses": ["doing"],
    "fields": ["task_title", "task_status", "estimated_minutes"],
    "limit": 20
  }
}
```

### 4.3 `work_time_query`

适用场景：

- 查询某段时间做过哪些事
- 查询某个关键词相关的工作记录
- 查询某个状态、某些归属标签下的工作记录
- 只返回少量字段给 AI，压缩大数据量上下文

参数：

- `start_date`：`YYYYMMDD`，查询起始日，含当日
- `end_date`：`YYYYMMDD`，查询结束日，含当日
- `keyword`：关键词，会同时匹配任务标题、任务描述、工时内容
- `status`：单个状态，`todo | doing | done | canceled`
- `statuses`：多个状态，数组形式
- `affiliation_names`：归属标签名数组，例如 `["项目A","团队B"]`
- `fields`：限定返回字段，见下表
- `limit`：返回记录条数上限，默认 20，最大 100

字段白名单：

| 字段名 | 含义 |
| --- | --- |
| `work_date` | 记录日期 |
| `task_title` | 任务标题 |
| `task_status` | 任务状态 |
| `affiliations` | 任务归属标签 |
| `minutes` | 本条记录工时 |
| `content` | 工时内容正文 |
| `task_description` | 任务描述 |
| `task_id` | 任务 ID |

筛选行为：

- 时间范围、关键词、状态、归属标签可以同时生效。
- `keyword` 会同时匹配任务标题、任务描述和工时内容。
- `affiliation_names` 基于工作记录工具的“归属”标签匹配。
- 若 pre-route 把与 `keyword` 完全相同的词也放进了 `affiliation_names`，且用户并未明确要求“按归属/标签筛选”，客户端会自动去掉这类重复标签条件，避免把“标题命中但未打同名标签”的任务误过滤掉。
- `fields` 只控制“记录列表”返回哪些字段，用于压缩注入上下文。

推荐输出示例：

```json
{
  "type": "special_call",
  "call": "work_time_query",
  "arguments": {
    "start_date": "20260401",
    "end_date": "20260430",
    "keyword": "接口",
    "statuses": ["doing"],
    "affiliation_names": ["项目A"],
    "fields": ["work_date", "task_title", "minutes"],
    "limit": 20
  }
}
```

兼容说明：

- `work_log_query` 仍然可用，但客户端会将其按 `work_time_query` 处理。

字段裁剪建议：

- 用户明确说“只看日期和任务名”时，`fields` 只保留对应字段。
- 用户没有明确字段要求时，可省略 `fields`，客户端会返回默认核心字段。
- 对大数据量查询，优先同时设置 `fields` 与 `limit`，避免把无关正文注入给 AI。

## 5. 胡闹厨房接口能力

### 5.1 `overcooked_context_query`

`query_type = recipe_lookup`

- `recipe_name`：要查的菜名
- 能力：返回命中的菜谱名称、简介、正文，供 AI 回答“怎么做”

`query_type = cooked_on_date`

- `date`：`YYYYMMDD`
- 能力：返回指定日期的做菜记录，供 AI 回答“那天做了什么菜”

## 6. UI 与 Metadata

当消息触发 special_call 后，用户消息 metadata 会写入：

- `triggerSource = "pre_route"` 或 `preset`
- `triggerTool`：如 `work_log` / `overcooked`
- 工时查询/工作记录总结命中日期范围时写入 `queryStartDate` / `queryEndDate`
- 胡闹厨房按日期查询时写入 `queryDate`

聊天页展示行为：

- 存在 `queryStartDate` / `queryEndDate` 时，显示“查询 YYYY-MM-DD 至 YYYY-MM-DD 工作记录”
- 否则显示通用的 special_call 触发提示

## 7. 维护约定

若改动以下任一项，需要同步评估并更新本文档：

- 小蜜快捷提示词
- pre-route 系统提示词
- special_call 名称、参数协议、字段白名单
- 本地数据注入逻辑或 UI metadata 行为

建议同时检查：

- `examples/xiaomi_ai.md`
- 根目录 `AGENTS.md`
