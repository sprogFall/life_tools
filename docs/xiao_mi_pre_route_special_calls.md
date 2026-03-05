# 小蜜聊天预选路由能力清单

## 1. 路由机制

小蜜聊天发送消息后，固定执行两次 AI 调用：

1. 第一次（非流式）：只做路由判断，返回 JSON。
2. 第二次（流式）：产出最终回答（无论是否触发 special_call，都走流式）。

第一次路由结果示例：

```json
{"type":"special_call","call":"work_log_range_summary","arguments":{"start_date":"20260101","end_date":"20261231","style":"management"}}
```

未触发示例：

```json
{"type":"no_special_call"}
```

客户端只在第一次的 `type = special_call` 时注入特殊上下文；其余场景按普通聊天上下文进入第二次流式回答。

## 2. 当前支持的 special_call 能力

预选路由系统提示词中仅定义了一个统一入口 `work_log_range_summary`，客户端会根据 `start_date` / `end_date` 自动识别时间粒度（周/月/季度/年），并选择对应的默认风格。

| 时间粒度 | call | 默认风格 | 识别条件 |
| --- | --- | --- | --- |
| 周 | `work_log_week_summary` | `concise` | 周一到周日，跨 6 天 |
| 月 | `work_log_month_summary` | `review` | 1号到月末 |
| 季度 | `work_log_quarter_summary` | `management` | 季度首月1号到季度末 |
| 年 | `work_log_year_summary` | `management` | 1月1日到12月31日 |
| 自定义范围 | `work_log_range_summary` | 按天数自动选择 | 其他 |

此外，客户端 `XiaoMiPromptResolver` 也兼容以下旧版 `call` 值（向后兼容）：

- `work_log_week_summary`
- `work_log_month_summary`
- `work_log_quarter_summary`
- `work_log_year_summary`

## 3. arguments 约定

- `style`（可选）：`concise | review | risk | highlight | management`
- `start_date`（可选）：`YYYYMMDD`，汇总起始日（含当日）
- `end_date`（可选）：`YYYYMMDD`，汇总结束日（含当日）

> 旧版 call 值还可接受以下参数（新代码推荐使用 `start_date` / `end_date`）：
> - `date` / `anchor_date`：`YYYY-MM-DD`，用于指定某一周
> - `year`：年份整数
> - `month`：`1-12`，与 `year` 组合指定某个月
> - `quarter`：`1-4`，与 `year` 组合指定某个季度

示例：

```json
{"type":"special_call","call":"work_log_range_summary","arguments":{"start_date":"20260301","end_date":"20260307","style":"concise"}}
```

```json
{"type":"special_call","call":"work_log_range_summary","arguments":{"start_date":"20260101","end_date":"20260131","style":"review"}}
```

## 4. UI 提示行为

当消息触发 `special_call` 后，用户消息 metadata 会写入：

- `triggerSource = "pre_route"`
- `queryStartDate` / `queryEndDate`（命中日期范围时写入，格式 `YYYY-MM-DD`）

聊天页会在该条用户消息下方显示灰字触发提示：

- 存在 `queryStartDate`/`queryEndDate` 时显示区间提示（例如：`查询 2026-01-01 至 2026-12-31 工作记录`）
- 否则回退显示通用触发提示。

## 5. 快捷入口（Quick Prompts）

当前预置快捷语：

- 本周工作总结
- 本月工作总结
- 本季度工作总结
- 今年工作总结
