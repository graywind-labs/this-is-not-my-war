# API_BUDGET.md

## 目标

控制 LLM 调用成本，避免 8 个 NPC 高频调用导致 Demo 不可运行。

正式成本与并发边界：

- 玩家电脑上的 Godot 客户端只请求游戏服务器后端，不直接调用 LLM Provider。
- 服务器后端统一持有供应商 API Key，并负责限流、排队、批处理、降级、token/费用统计和异常熔断。
- Demo / 本地开发可以使用 mock provider 或本机后端验证接口；这不代表玩家最终必须自行启动后端或自行配置 API Key。
- 玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式；即使实现，也必须与默认服务器后端模式隔离，不能让 Godot 导出客户端默认保存真实 Key。

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
- 是否申请 TimeSystem 慢速
- 慢速申请与释放时间
- 输入 token
- 输出 token
- 估算费用
- 是否成功
- 失败原因

## LLM 等待与时间减速

会影响当前场景即时状态的 LLM 调用，需要由 Godot 侧在发起请求前调用 `TimeSystem.request_time_slowdown(...)`。请求成功、失败、超时或降级后必须释放。

默认慢速倍率为 `1/60`：默认速度下从现实 1 秒 = 游戏 1 分钟减缓为现实 1 秒 = 游戏 1 秒。该倍率只影响逻辑时间、资源/状态/战斗等数值结算，不影响 Godot 全局运行速度、NPC 移动速度或动画速度。

低优先级后台批处理，如每日计划批量生成，可以降低并发或排队，但所有 NPC 相关 LLM 请求仍必须申请慢速。集结 / 战斗 / 避战模式下的守备官对话会影响当前战局意向，应按高优先级立即申请慢速；战时 HP 低于 30% 的自身心理判定同样是高优先级，并且判定等待期间目标 NPC 不可被守备官对话。该低血量判定覆盖参战 NPC 与避战 / 非战斗人员，但 Godot 会限制非战斗人员只允许逃离或继续避战。首次睡眠总结虽然频率低，但它锁定 NPC 当下状态，优先级高于对话和指令，必须申请慢速并确保请求结束后释放。

`current_order` 会进入所有面向该 NPC 的 LLM 请求，因此必须限制为单条当前有效指令，不重复注入全部历史版本。历史修改通过 `private` `order_assigned` 事件进入短期记忆摘要；常规请求只额外携带当前文本和最小元数据，避免指令修订不断放大上下文。

## 当前实现状态

- T0602 已实现默认 `mock` provider 的 `ModelAdapter.generate(...)`，可以按调用类型返回稳定 JSON。
- Mock 调用会记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用、成功/失败状态和失败原因；mock 费用固定为 0。
- T0603 已实现 `POST /npc/dialogue` Mock 业务接口，内部复用 `ModelAdapter.generate("dialogue", ...)`，因此对话调用也会产生伪 usage 记录；当前接口响应不把 usage 暴露给 Godot，后续 API 额度面板任务再统一展示。
- 当前仍不会产生真实 token 消耗或真实费用。
- `POST /mock/model` 可用于后端调试；后续实现对话、计划、判定接口时，服务层应复用 Model Adapter 的 usage 信息，并补齐是否申请 TimeSystem 慢速、慢速申请与释放时间等 Godot 侧字段。
- T0604 已在 Godot 侧实现 `LLMBridge`，对 `/npc/dialogue` 请求注册 TimeSystem 慢速请求，成功、失败或超时后释放；当前只在 Godot 内保留调试状态，不做正式 API 额度面板。
- T0604A 已将 Godot 侧传输层改为原生 `HTTPClient`，不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件，并继续保证失败、超时和降级路径都会释放慢速请求。
- T1006 起，玩家对话 UI 使用 `LLMBridge.request_npc_dialogue_async(...)` 发起异步 `/npc/dialogue` 请求：发送消息或攻击才申请慢速和 NPC LLM 活动状态；玩家在回复返回前结束对话会取消 request id、释放慢速、清除活动状态，并丢弃后续返回结果。对话窗攻击同样属于对话 LLM 调用，攻击事实先由 Godot 结算和入库，NPC 回复请求仍计入 `call_type=dialogue`。
- T0703A 已让常规 NPC 请求只注入一条最新 `current_order` 和最小元数据；T1002 起，新指令和行动异常会立即产生计划重评估请求，并通过 `/npc/revise_plan` 走 Mock / 后端调用。Mock provider 会记录伪 token 与用途；后端不可用、非 mock provider 未配置或输出不合法时使用 `rule_revision_fallback`，同时释放 TimeSystem 慢速请求，避免遗留慢速状态。
- T1003 起，每日计划生成可通过 `/npc/plan_day` 走 Mock / 后端调用。Godot 侧 `LLMBridge.request_npc_daily_plan(...)` 会申请 TimeSystem 慢速并在成功、失败或超时后释放；Mock provider 记录 `call_type=plan_day` 的伪 token 与用途。后端不可用、非 mock provider 未配置、输出不合法、不是 24 阶段或工作阶段不足时，`DailyPlanSystem` 使用 `rule_plan_fallback`，避免低优先级计划请求卡住游戏推进。
- T1004/T1005 起，首次睡眠总结可通过 `/npc/daily_reflection` 走 Mock / 后端调用。Godot 侧 `LLMBridge.request_npc_daily_reflection(...)` 默认 `requires_time_slowdown=true`；总结发起到完成期间 NPC 处于不可打断的深度睡眠锁，因此它不是后台无感调用。Mock provider 记录 `call_type=daily_reflection` 的伪 token 与用途。后端不可用、非 mock provider 未配置或输出不合法时，`DailyReflectionSystem` 使用本地模板兜底，仍会写入日记、更新知识图谱占位并清空该 NPC 当天短期记忆。
- T1201 后，战时公开对话复用 `call_type=dialogue`，请求 payload 额外携带 `interaction_context=rally|combat|avoid_combat` 和 `battlefield_context`；`LLMBridge` 最近上下文注入快照会标记是否携带战场上下文。低血量自身心理判定使用独立 `call_type=battle_judgement` 或等价业务类型，不能与旧式“战斗触发全员判定”混淆；后者已被取消。
