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
| 高 | 战斗前关键判定 |
| 高 | 血量低于 30% 的战斗判定 |
| 中 | 逃离挽留对话 |
| 中 | NPC 主动找玩家交涉 |
| 中 | 行动异常重评估 |
| 低 | NPC 间闲聊 |
| 低 | 睡前总结 |
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

低优先级后台批处理，如每日计划批量生成、睡前总结批量生成，可以不申请慢速，但必须记录调试状态，避免玩家误以为当前场景即时决策已经完成。

## 当前实现状态

- T0602 已实现默认 `mock` provider 的 `ModelAdapter.generate(...)`，可以按调用类型返回稳定 JSON。
- Mock 调用会记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用、成功/失败状态和失败原因；mock 费用固定为 0。
- T0603 已实现 `POST /npc/dialogue` Mock 业务接口，内部复用 `ModelAdapter.generate("dialogue", ...)`，因此对话调用也会产生伪 usage 记录；当前接口响应不把 usage 暴露给 Godot，后续 API 额度面板任务再统一展示。
- 当前仍不会产生真实 token 消耗或真实费用。
- `POST /mock/model` 可用于后端调试；后续实现对话、计划、判定接口时，服务层应复用 Model Adapter 的 usage 信息，并补齐是否申请 TimeSystem 慢速、慢速申请与释放时间等 Godot 侧字段。
- T0604 已在 Godot 侧实现 `LLMBridge`，对 `/npc/dialogue` 请求注册 TimeSystem 慢速请求，成功、失败或超时后释放；当前只在 Godot 内保留调试状态，不做正式 API 额度面板。
- T0604A 已将 Godot 侧传输层改为原生 `HTTPClient`，不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件，并继续保证失败、超时和降级路径都会释放慢速请求。
