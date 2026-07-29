# T0067 真实 LLM 94 次调用审计包

## 先看结论

T0067 共计 94 次真实供应商请求：

| 来源 | battle_judgement | dialogue | plan_day | 合计 |
|---|---:|---:|---:|---:|
| 正式 Main 后端 | 7 | 43 | 28 | 78 |
| 独立定向矩阵 | 7 | 9 | 0 | 16 |
| 合计 | 14 | 52 | 28 | 94 |

93 次通过业务校验，1 次普通开局 `plan_day` 未通过业务校验，0 fallback。总输入 1,876,789、输出 61,520 tokens。

## 原始证据与可恢复范围

| 内容 | 可恢复情况 |
|---|---|
| 正式 system Prompt | 3 类均完整恢复，见 `formal_system_prompts/` |
| Agent 编写的场景命令/对话 | 完整保留于 `SCENARIO_TEXTS.md` 和 `source_snapshots/` |
| 独立矩阵 16 次完整 provider 请求体 | 可由当时未再改动的测试构造器、Prompt 与 ModelAdapter 确定性重建，见 `direct_calls/` |
| 独立矩阵 16 次业务结果与 usage | 原始输出完整恢复，见 `direct_matrix_report.json` |
| Main 78 次完整动态 user payload | 当时未启用正文持久化，无法事后无损恢复 |
| Main 78 次 request id/逐次 token | 最终会话只保留尾部 11 个唯一请求；其余 67 次只有按 call type 聚合的原始统计 |
| Main 场景结果 | 战斗、日计划和多轮对话的测试输出摘要已从会话/轮转前输出恢复，见 `recovered_marker_events.json` 与 `raw_outputs/` |
| 原始 provider 文本的空格/SSE 分块 | 后端只保存解析后的业务 JSON与 usage，没有持久化原始 SSE，无法恢复 |

因此，`call_inventory.csv` 有 94 行，但只有 27 行拥有真实 request id：16 个独立矩阵请求和 Main 尾部 11 个唯一请求。其余 67 行明确标为 `aggregate_only_original_request_not_persisted`，不是伪造的 request id。

## 文件导航

- `call_inventory.csv`：94 行总清单与证据级别。
- `SCENARIO_TEXTS.md`：测试时人工编写的守备官命令、对话和压力事实。
- `RESULTS.md`：可直接阅读的定向矩阵与 Main 场景返回结果。
- `formal_system_prompts/`：测试时三类完整 system Prompt。
- `direct_calls/`：16 次定向矩阵的完整无请求头 provider body、真实结果和 usage。
- `direct_matrix_report.json`：恢复的 16 路真实结果总报告。
- `main_usage_aggregate.json`：78 次 Main 调用的权威聚合统计。
- `main_usage_tail_raw_12.json`：修复 usage 双计前保存的尾部 12 条原始记录。
- `main_usage_tail_deduped_11.json`：按已修复语义合并后的 11 个真实上游请求。
- `recovered_marker_events.json`：从会话函数输出恢复并去重的场景结果。
- `raw_outputs/`：测试结束时删除、但仍由本次会话变更证据保存的原始 `.out`。
- `source_snapshots/`：生成审计包时保存的四份 T0067 测试脚本快照。

## 安全边界

本审计包不含 `.env`、API Key、Authorization 请求头或无关 Codex 会话正文。`direct_calls/` 只保存供应商 JSON body。
