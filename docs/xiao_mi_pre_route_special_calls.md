# 小蜜聊天预选路由能力清单

## 1. 路由机制

小蜜聊天发送消息后，固定执行两次 AI 调用：

1. 第一次（非流式）：只做路由判断，返回 JSON。
2. 第二次（流式）：产出最终回答（无论是否触发 special_call，都走流式）。

第一次路由结果示例：

```json
{"type":"special_call","call":"work_log_month_summary","arguments":{"style":"review"}}
```

未触发示例：

```json
{"type":"no_special_call"}
```

客户端只在第一次的 `type = special_call` 时注入特殊上下文；其余场景按普通聊天上下文进入第二次流式回答。

## 2. 当前支持的 special_call 能力

| 能力 | call | 默认时间范围 | 默认风格 |
| --- | --- | --- | --- |
| 本周工作总结 | `work_log_week_summary` | 本周（周一到周日） | `concise` |
| 本月工作总结 | `work_log_month_summary` | 本月（1号到月底） | `review` |
| 本季度工作总结 | `work_log_quarter_summary` | 当前季度（Q1/Q2/Q3/Q4） | `management` |
| 年度工作总结 | `work_log_year_summary` | 今年（1月1日到12月31日） | `management` |

## 3. arguments 约定

- `style`（可选）：`concise | review | risk | highlight | management`
- `date`（可选）：`YYYY-MM-DD`，用于指定某一周（按该日期所在周统计）
- `year`（可选）：年份整数
- `month`（可选）：`1-12`，与 `year` 组合指定某个月
- `quarter`（可选）：`1-4`，与 `year` 组合指定某个季度

示例：

```json
{"type":"special_call","call":"work_log_week_summary","arguments":{"style":"risk"}}
```

```json
{"type":"special_call","call":"work_log_month_summary","arguments":{"year":2026,"month":1,"style":"review"}}
```

## 4. UI 提示行为

当消息触发 `special_call` 后，用户消息 metadata 会写入：

- `presetId`
- `triggerSource = "pre_route"`

聊天页会在该条用户消息下方显示灰字触发提示（复用现有提示样式）。

## 5. 快捷入口（Quick Prompts）

当前预置快捷语：

- 本周工作总结
- 本月工作总结
- 本季度工作总结
- 今年工作总结
