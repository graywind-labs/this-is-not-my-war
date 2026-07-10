# API_BUDGET.md

## 目标

控制 LLM 调用成本，避免 8 个 NPC 高频调用导致 Demo 不可运行。

正式成本与并发边界：

- 玩家电脑上的 Godot 客户端只请求游戏服务器后端，不直接调用 LLM Provider。
- 服务器后端统一持有供应商 API Key，并负责限流、排队、批处理、降级、token/费用统计和异常熔断。
- 本地开发可以显式使用 mock provider 或本机后端验证接口；这不代表玩家最终必须自行启动后端或自行配置 API Key。
- 玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式；即使实现，也必须与默认服务器后端模式隔离，不能让 Godot 导出客户端默认保存真实 Key。
- Mock provider 只用于开发期 Schema / 通信 / 自动化验证。真实 API 测试通过后，生产 / 演示路径必须关闭自动 mock fallback；模型失败应返回可处理错误并记录真实原因，或进入明确标记的规则 / 模板降级。

## 调用优先级

| 优先级 | 任务 |
|---|---|
| 高 | 玩家正在对话的 NPC |
| 高 | 集结 / 战斗 / 避战模式下的战时公开对话 |
| 高 | 守备官发布新指令后立即触发的计划重评估 |
| 高 | 战时 HP 低于 30% 的自身心理判定 |
| 中 | 逃离挽留对话 |
| 中 | NPC 主动找玩家交涉 |
| 中 | 行动异常重评估 |
| 低 | NPC 间闲聊 |
| 最高 | 首次睡眠总结 |
| 低 | 每日计划，可批处理 |

## 调用记录字段

每次模型调用记录：

- 时间
- 调用类型
- 关联事件 id 或触发事件 id
- 关联 NPC id
- Godot 侧请求 id
- provider、model、base_url 标识（不含 Key）
- 是否申请 TimeSystem 慢速
- 慢速申请与释放时间
- 输入 token
- 输出 token
- 估算费用
- 是否成功
- 失败原因
- HTTP 状态或异常类型
- 是否使用 mock、规则降级或模板降级

## LLM 等待与时间减速

会影响当前场景即时状态的 LLM 调用，需要由 Godot 侧在发起请求前调用 `TimeSystem.request_time_slowdown(...)`。请求成功、失败、超时或降级后必须释放。

默认慢速倍率为 `1/60`：默认速度下从现实 1 秒 = 游戏 1 分钟减缓为现实 1 秒 = 游戏 1 秒。该倍率只影响逻辑时间、资源/状态/战斗等数值结算，不影响 Godot 全局运行速度、NPC 移动速度或动画速度。

低优先级后台批处理，如每日计划批量生成，可以降低并发或排队，但所有 NPC 相关 LLM 请求仍必须申请慢速。集结 / 战斗 / 避战模式下的守备官对话会影响当前战局意向，应按高优先级立即申请慢速；战时 HP 低于 30% 的自身心理判定同样是高优先级，并且判定等待期间目标 NPC 不可被守备官对话。该低血量判定覆盖参战 NPC 与避战 / 非战斗人员，但 Godot 会限制非战斗人员只允许逃离或继续避战。首次睡眠总结虽然频率低，但它锁定 NPC 当下状态，优先级高于对话和指令，必须申请慢速并确保请求结束后释放。

`current_order` 会进入所有面向该 NPC 的 LLM 请求，因此必须限制为单条当前有效指令，不重复注入全部历史版本。历史修改通过 `private` `order_assigned` 事件进入短期记忆摘要；常规请求只额外携带当前文本和最小元数据，避免指令修订不断放大上下文。

## 当前实现状态

- T0602 已实现默认 `mock` provider 的 `ModelAdapter.generate(...)`，可以按调用类型返回稳定 JSON；该能力只作为开发期脚手架和自动化验证入口。
- Mock 调用会记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用、成功/失败状态和失败原因；mock 费用固定为 0。生产 / 演示真实 provider 失败时不得自动返回 mock 内容伪装成功。
- T1401 已实现 `deepseek` / `openai_compatible` 真实 Model Adapter。DeepSeek 默认 `LLM_BASE_URL=https://api.deepseek.com`、`LLM_MODEL=deepseek-v4-flash`；真实 Key 只从 `LLM_API_KEY` 或服务器 / 本地后端环境读取。T1401A 后 `LLM_FALLBACK_TO_MOCK` 默认关闭，真实 provider 无 Key、请求失败、超时、HTTP 错误、非 JSON 或业务 Schema 校验失败时返回可处理错误并写入 usage；自动 mock fallback 只在显式 `LLM_FALLBACK_TO_MOCK=true` 的开发调试中启用。
- T0603 已实现 `POST /npc/dialogue` 业务接口，内部复用 `ModelAdapter.generate("dialogue", ...)`，因此对话调用也会产生 usage 记录；业务响应仍只返回 Schema 校验后的模型内容，usage 通过 `GET /debug/llm_usage` 暴露给调试入口。
- 真实 provider 调用会优先读取供应商返回的 prompt / completion token；供应商未返回 usage 时用本地粗略估算。费用估算读取 `LLM_INPUT_COST_PER_M_TOKENS` / `LLM_OUTPUT_COST_PER_M_TOKENS`，未配置时为 0。
- T1406 后，预算守门读取 `LLM_BUDGET_MAX_CALLS`、`LLM_BUDGET_MAX_INPUT_TOKENS`、`LLM_BUDGET_MAX_OUTPUT_TOKENS`、`LLM_BUDGET_MAX_TOTAL_TOKENS` 和 `LLM_BUDGET_MAX_COST`，默认 `0` 表示关闭。任一上限启用后，正式业务接口会在调用模型前检查累计 usage 和本次输入 token 估算；超预算时返回 HTTP 429 / `budget_exceeded`，usage 记录 `exception_type=BudgetExceeded`、`degradation_source=budget_blocked`、request id、call_type、provider/model、NPC id 和失败原因，不自动 mock fallback。
- `POST /mock/model` 可用于后端调试；后续实现对话、计划、判定接口时，服务层应复用 Model Adapter 的 usage 信息，并补齐是否申请 TimeSystem 慢速、慢速申请与释放时间等 Godot 侧字段。
- T0604 已在 Godot 侧实现 `LLMBridge`，对 `/npc/dialogue` 请求注册 TimeSystem 慢速请求，成功、失败或超时后释放；T1401 新增 `LLMBridge.debug_request_llm_usage()` 与 GM 面板“成本统计”只读入口，用于查看累计调用、token、费用估算、fallback 次数和失败原因。T1406 后，该入口同时显示预算上限 / 已用 / 剩余、最近预算错误，以及 Godot 侧 `debug_get_llm_runtime_snapshot()` 的等待请求数、pending request id、有效逻辑倍率和最近 TimeSystem 倍率变化原因。更完整的多玩家限流、并发队列和服务器部署治理仍归 T1407。
- T0604A 已将 Godot 侧传输层改为原生 `HTTPClient`，不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件，并继续保证失败、超时和降级路径都会释放慢速请求。
- T1006 起，玩家对话 UI 使用 `LLMBridge.request_npc_dialogue_async(...)` 发起异步 `/npc/dialogue` 请求：发送消息或普通对话攻击才申请慢速和 NPC LLM 活动状态；玩家在回复返回前结束对话会取消 request id、释放慢速、清除活动状态，并丢弃后续返回结果。普通对话窗攻击属于对话 LLM 调用，攻击事实先由 Godot 结算和入库，NPC 回复请求仍计入 `call_type=dialogue`。T1204A 起，逃离挽留中的攻击不属于 LLM 调用，不申请慢速，不计入 API 成本。
- T0703A 已让常规 NPC 请求只注入一条最新 `current_order` 和最小元数据；T1002 起，新指令和行动异常会立即产生计划重评估请求，并通过 `/npc/revise_plan` 走 Model Adapter。开发期 mock provider 会记录伪 token 与用途；真实 provider 不可用、未配置或输出不合法时使用 `rule_revision_fallback`，同时释放 TimeSystem 慢速请求，并保留真实失败日志，避免遗留慢速状态和伪成功。
- T1003 起，每日计划生成可通过 `/npc/plan_day` 走 Model Adapter。Godot 侧 `LLMBridge.request_npc_daily_plan(...)` 会申请 TimeSystem 慢速并在成功、失败或超时后释放；开发期 mock provider 记录 `call_type=plan_day` 的伪 token 与用途。T1403 后真实 provider 路径读取 `data/prompts/daily_plan_system_prompt.txt`，后端额外校验 24 个 hour 覆盖、行动白名单和至少 6 个工作阶段。真实 provider 不可用、未配置、输出不合法、不是 24 阶段或工作阶段不足时，`DailyPlanSystem` 使用 `rule_plan_fallback`，避免低优先级计划请求卡住游戏推进，并保留真实失败日志。
- T1004/T1005/T1405 起，首次睡眠总结可通过 `/npc/daily_reflection` 走 Model Adapter。Godot 侧 `LLMBridge.request_npc_daily_reflection(...)` 默认 `requires_time_slowdown=true`；总结发起到完成期间 NPC 处于不可打断的深度睡眠锁，因此它不是后台无感调用。开发期 mock provider 记录 `call_type=daily_reflection` 的伪 token 与用途。真实 provider 不可用、未配置或输出不合法时，`DailyReflectionSystem` 使用本地模板兜底，仍会追加日记、替换式更新知识图谱当前键值并清空该 NPC 当天短期记忆；模板来源和原始失败原因必须可查。
- T1201 后，战时公开对话复用 `call_type=dialogue`，请求 payload 额外携带 `interaction_context=rally|combat|avoid_combat` 和 `battlefield_context`；`LLMBridge` 最近上下文注入快照会标记是否携带战场上下文。低血量自身心理判定使用独立 `call_type=battle_judgement` 或等价业务类型，不能与旧式“战斗触发全员判定”混淆；后者已被取消。T1404 后，`call_type=battle_judgement` 真实 provider 路径读取 `data/prompts/battle_judgement_system_prompt.txt`，后端会拒绝越界 `decision` 与逃离布尔不一致结果并写入失败 usage；真实 DeepSeek 已对战时 `/npc/dialogue` 与 `/npc/battle_judgement` 各完成一次 smoke 调用，`fallback_used=false`。
- T1204A 后，逃离挽留中“玩家发送消息并等待 NPC 回复”的轮次复用 `call_type=dialogue` 和 `/npc/dialogue`，payload 使用 `dialogue_kind=escape_intervention`、`interaction_context=escape_intervention` 和 `escape_intervention_round=1..5`。它会影响当前逃离状态，因此仍按对话类请求申请 TimeSystem 慢速；后端失败时 Godot 规则降级为 stay/continue 意图，并释放慢速请求、保留真实失败日志。逃离挽留面板内的攻击只由 Godot 权威结算并计 1 轮，不请求 `/npc/dialogue`。

## 真实 API 验收与失败可见性

- 每个涉及 LLM / Prompt 的任务应先跑 mock / schema 自动化测试，再用真实 API Key 对本任务涉及的业务路径做至少一次真实 provider 测试。
- 没有真实 Key 时，不能把真实 LLM 行为标记为完全验收；任务状态应为 Partial / Blocked，或在验收结果中明确真实 API 未测。
- 生产 / 演示配置必须关闭自动 mock fallback。预算超限、无 Key、provider 错误、超时、非 JSON 或 Schema 失败时，返回可处理错误或明确规则 / 模板降级。
- Usage / 日志必须能回答“哪个 request、哪个 call_type、哪个 provider/model、哪个 NPC、为什么失败、是否降级、花了多少 token/费用估算”。这比在失败后生成一段看似正常的 mock 回复更重要。
