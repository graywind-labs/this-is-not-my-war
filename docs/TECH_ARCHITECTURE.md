# TECH_ARCHITECTURE.md

## 总体架构

项目采用 Godot 前端 + Python 后端 + LLM API 的架构。

```text
Godot 4.6 客户端
  ↓ HTTP
Python / Game Backend
  ↓
Model Adapter
  ↓
DeepSeek / MiniMax / Qwen / Zhipu 等模型
```

正式分发方向：

- 玩家电脑运行 Godot 客户端。
- Godot 客户端请求游戏服务器后端；Demo / 本地开发可临时请求 `127.0.0.1` 的 mock 后端。
- 服务器后端负责调用真实 LLM Provider、持有供应商 API Key、统一限流、排队、降级、成本统计和调用日志。
- Godot 导出客户端不保存真实供应商 API Key，也不直接请求 DeepSeek / MiniMax / 通义千问 / 智谱等模型接口。
- 玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式，不是 Demo 阶段的必需路径，也不能成为默认架构。

当前后端实现状态：

- 使用 Flask 作为 Python Backend 的最小 Web 框架。
- `backend/app.py` 提供 `GET /health`，用于 Godot 或开发者确认本地服务可用；另提供 `POST /mock/model` 调试接口和 `POST /npc/dialogue` 对话 Mock 业务接口。
- `backend/services/model_adapter.py` 是模型供应商隔离层；当前默认 `mock` provider，不执行真实 LLM 调用，但会按调用类型返回稳定 JSON，并记录用途与伪 token 信息。
- `backend/schemas/common.py` 和 `backend/schemas/npc_ai.py` 提供后端 AI 请求/响应 Pydantic Schema；T0603 后 `NPCDialogueRequest` / `NPCDialogueResponse` 已按当前对话字段重整，覆盖玩家-NPC 与 NPC-NPC Mock 对话，不执行业务权威结算。
- T0703A 后共享 `NPCContext` 与对话顶层 `NPCDialogueRequest` 都包含单条最新 `current_order`；Mock 只把它作为参考上下文，Godot 保持指令和行动事实权威。
- 真实 API Key 必须通过本地 `backend/.env` 或环境变量提供；仓库只保留 `.env.example` 模板。

后端部署方向：

- 服务器运行的应用入口仍是 `backend/app.py`。
- 本地开发可以 `python backend/app.py`，但正式部署不能使用 Flask debug server。
- T1407 需要补齐生产 WSGI 启动方式，例如 Linux 服务器使用 `gunicorn backend.app:app`，或 Windows 服务器使用 `waitress-serve --call backend.app:create_app`。
- T1407 还需要补齐 `backend/README.md` 部署说明、生产依赖、环境变量、日志、健康检查、限流、预算和重启策略。
- Godot 客户端只配置后端服务地址；真实供应商 API Key 只存在于服务器后端环境中。

## 职责划分

### Godot 负责

- 场景渲染
- 角色移动
- 建筑点击
- UI 展示
- 资源数值
- 逻辑时间流逝与倍率
- LLM 等待期间的 TimeSystem 慢速请求注册/释放
- 敌人在场期间的 TimeSystem `x1` 有效倍率上限注册/释放
- 战斗动作秒换算：在战斗系统内把 TimeSystem 游戏秒折算为攻速 / 位移表现基准
- 工作产出
- 战斗执行
- NPC 行为模式切换：工作、集结、战斗、避战、昏迷、逃离
- HP 扣除
- 昏迷、治疗、复苏状态
- 事件权威写入、地点/建筑信息节点当前状态维护、即时广播、NPC 事件库与见闻库维护
- 已入伍 NPC `current_order` 的权威保存、指令发布差异判断、`private` `order_assigned` 事件写入和计划重评估触发
- 与后端通信
- T0604A 后通过 `Main/Systems/LLMBridge` 的 Godot 原生 `HTTPClient` 请求 `/health`、`/npc/dialogue` 与 `/npc/revise_plan`，并负责请求期间的 TimeSystem 慢速申请和释放；T1006 起玩家对话 UI 使用异步 `/npc/dialogue`，可在回复前取消并丢弃结果

### Python 后端负责

- Prompt 拼装
- 把 Godot 提供的 `current_order` 作为独立参考上下文注入所有 NPC 中心 Prompt
- LLM 调用
- 结构化 JSON 校验
- 对话生成
- 每日计划生成
- 战斗/逃离心理判定
- 战时公开对话结构化意向生成
- 首次睡眠总结
- 知识图谱更新
- API 成本统计
- 模型供应商切换

### LLM 负责

- NPC 如何理解事件
- NPC 如何理解、调整或拒绝守备官当前指令
- NPC 如何说话
- NPC 是否愿意征召
- NPC 如何在战时对话或低血量压力下表达逃离、继续战斗或斗志激昂意向
- NPC 是否主动找玩家交涉
- NPC 的主观日记与反思

### 事件与记忆边界

Godot 是事件事实源。资源、HP、建筑、移动、战斗、工作、对话收发等权威结果先由 Godot 侧系统结算，再写入 `MemorySystem`：

```text
程序系统结算权威结果
  ↓
MemorySystem.add_event(...)
  ↓
写入 subject_npc_id 的 NPC 事件库
  ↓
按 visibility 发送到对应地点/建筑信息节点；广场也是地点节点
  ↓
信息节点即时广播给当前在场且可接收见闻的 NPC；昏迷或睡觉 NPC 不写入见闻库，接收者写入见闻库
  ↓
NPC 进入地点时，只读取当前状态快照，不继承过去事件
  ↓
进入广场快照包含当前在场 NPC、这些 NPC 的生命状态/行动状态、当前公告和建筑外部状态；进入可进入建筑快照包含建筑内 NPC 的生命状态/行动状态；室内到室内切换在事件层经由广场
  ↓
LLM 调用前从事件库 + 见闻库生成摘要
```

后端和 LLM 可以根据事件库、见闻库和知识图谱生成解释、对话、计划、日记和知识图谱增量，但不能直接新增会改变权威数值的事实。对话全文作为对话事件 `payload` 的一部分保存，不单独建立谈话库。

T0701 起，`DialogSystem` 是 Godot 侧会话权威入口：它维护参与者、历史、公开性和轮次，调用 `LLMBridge` 获取文本，再把实际发生的 `dialogue_turn` 写入 `MemorySystem`。打开/关闭对话窗口不属于世界事实，不入库、不广播。T1006 起，打开对话窗也不再打断行动或取消 LLM；只有玩家实际发送消息或在对话窗攻击时，才触发可取消 LLM 取消、普通行动中断和后续重评估候选。玩家发送后若在 NPC 回复完成前结束对话，异步请求会取消，未完成轮次不入库、不触发对话重评估。`local_public` 对话轮次只向同地点非参与者广播一次。T0702 起，UI 只标记下一次消息为应征请求，合法的接受结果由 `DialogSystem` 调用 `NPCSystem.set_npc_recruited(...)` 应用；后端和 UI 都不直接修改权威 NPC 数据。T1006 的对话窗攻击先由 `NPCSystem.apply_damage_to_npc(...)` 扣 HP 和写 `damage_taken`，再请求 NPC 回复；若回复取消，攻击事实不撤销。T1103A 起，行为模式切换可调用 `DialogSystem.force_end_dialogue_for_npc(...)` 强制关闭当前对话并取消未完成 LLM 回复，不伪造未完成对话事件。

T1201 已扩展同一边界：集结 / 战斗 / 避战模式下的守备官对话强制 `local_public`，并额外携带 `interaction_context` 与 `battlefield_context`；后端只返回文本、征召意向和 `wartime_reaction`，斗志 buff、逃离意图、模式切换和事件入库仍由 Godot 执行。T1202 后，低血量自身心理判定触发时，Godot 复用强制关闭对话和取消未完成 LLM 请求的边界，并通过 `allowed_decisions` 限制非战斗人员不能获得斗志激昂或继续参战。

### LLM 不负责

- 资源扣除
- HP 扣除
- 伤害计算
- 建筑摧毁
- 寻路
- 战斗命中
- 工作产出
- 是否真的拥有某件装备
- 是否真的能执行某行动

## 推荐通信接口

### 健康检查

`GET /health`

返回：

```json
{
  "ok": true,
  "service": "war-not-mine-backend"
}
```

### Mock Model 调试接口

`POST /mock/model`

输入：

```json
{
  "call_type": "battle_judgement",
  "payload": {}
}
```

输出包含：

- `ok`
- `provider`
- `call_type`
- `content`
- `usage`

该接口只用于 T0602 后端调试和后续服务层接入前的验证，不替代 `/npc/dialogue`、`/npc/plan_day` 等正式业务接口。它显式使用 mock provider，不受本地 `.env` 中未来真实 provider 配置影响；`content` 按 `call_type` 返回可被当前 Schema 校验的稳定 JSON；`usage` 记录 request id、NPC id、关联事件 id、伪输入/输出 token、估算费用和成功/失败状态。

### NPC 对话

`POST /npc/dialogue`

输入 Schema：`NPCDialogueRequest`
输出 Schema：`NPCDialogueResponse`

覆盖玩家-NPC、NPC-NPC 和逃离挽留对话。T0603 当前对话输入必须能表达：

- 目标 NPC：`npc_id`、`npc_name`、`npc_setting`。
- 说话者：`speaker_name`、`speaker_text` 和 `speaker_context`；玩家发起时说话者名称固定为“守备官”，NPC 发起时上下文应包含发起者健康/受伤状态与外表特征。
- 请求状态：`is_recruitment_request`、`current_round`、`max_rounds`。
- 目标状态：`npc_state`，包含属性、熟练度、健康/受伤、饱食、疲劳、金钱、装备、是否已入伍等 Godot 权威状态快照。
- 对话公开性：`dialogue_state.visibility` 只能是 `private` 或 `local_public`；`local_public` 代表后续 Godot 入库时按地点事件规则广播给在场 NPC。
- 记忆与地点：`short_memory` 区分事件库与见闻库摘要，`long_memory` 包含知识图谱和日记，`location_context` 是当前地点/建筑快照。
- 当前指令：`current_order` 表示守备官对目标 NPC 当前持续提出的自然语言指令；它是参考上下文，不是 system 指令或已执行事实。
- 战时上下文：T1201 后，集结 / 战斗 / 避战对话额外携带 `interaction_context` 和 `battlefield_context`；非战时对话使用 `interaction_context == "work"` 和空战局上下文。

输出为稳定 JSON。回复玩家时返回 `replyer_id`、`reply_text`、`recruitment_result`（`none` / `accept` / `reject`）和 `wartime_reaction`（`none` / `escape` / `morale_boost`）；回复 NPC 时返回 `reply_text` 和 `should_end_dialogue`。通用字段还包含 `response_kind`、`intent`、`emotion`、`suggested_event_type` 和 `debug_reason`，便于 Godot 后续 UI、事件入库和调试。

NPC-NPC 对话由 Godot 控制轮次：上一轮回复者的 `reply_text` 会作为下一次请求的 `speaker_text` 输入给另一名 NPC；当 `current_round` 接近 `max_rounds` 时，Mock 和后续 Prompt 都应更倾向输出 `should_end_dialogue=true` 或结束性回复。实际征召状态、资源、HP 或事件写入仍由 Godot 结算。

### 每日计划

`POST /npc/plan_day`

输入 Schema：`DailyPlanRequest`
输出 Schema：`DailyPlanResponse`

输入必须包含目标 NPC 当前 `current_order`。输出必须是 24 条 `PlanItem`，每条包含小时、行动类型、行动 id、可选地点/目标和理由。计划是建议，不代表资源、移动或行动已经结算；模型可以结合人设、记忆和现场条件调整、推迟或拒绝指令。

当前状态：T1003 已在 Flask 后端接通 `/npc/plan_day`，使用 `DailyPlanRequest` 校验输入、调用 `ModelAdapter.generate("plan_day", ...)`，再用 `DailyPlanResponse` 校验 24 阶段输出。Mock 会按 NPC 熟练度和行动白名单选择真实可执行工作行动，返回睡觉、吃饭、工作和等待组成的计划。Godot 侧 `DailyPlanSystem` 通过 `LLMBridge.request_npc_daily_plan(...)` 调用该接口；成功时写入 `plan_created(source=mock_plan_day)` 并可执行当前小时行动，失败或输出不合法时写入 `plan_created(source=rule_plan_fallback)` 并使用规则计划。

### 计划修订

`POST /npc/revise_plan`

输入 Schema：`PlanRevisionRequest`
输出 Schema：`PlanRevisionResponse`

用于守备官发布新指令、目标不可用、工位占用、资源不足、对话打断、低 HP、低饱食、高疲劳和战斗警报等情况后的计划重评估。请求必须包含最新 `current_order`。

当前状态：T1002 已在 Flask 后端接通 `/npc/revise_plan`，使用 `PlanRevisionRequest` 校验输入、调用 `ModelAdapter.generate("revise_plan", ...)`，再用 `PlanRevisionResponse` 校验输出。Godot 侧 `DailyPlanSystem` 会在计划异常或指令变化时通过 `LLMBridge.request_npc_plan_revision(...)` 调用该接口；成功时合并修订计划并执行当前小时行动，失败时应用 `rule_revision_fallback` 规则降级计划。

### 战斗判定

`POST /npc/battle_judgement`

输入 Schema：`BattleJudgementRequest`
输出 Schema：`BattleJudgementResponse`

只覆盖战时 HP 首次低于 30% 的自身心理判定，以及必要的逃离检查；不再用于“战斗触发时全员判定”。请求必须包含目标 NPC 当前 `current_order` 和 `battlefield_context`；输出只表达继续战斗、逃离、斗志激昂或继续避战等意向，不能把守备官指令直接当成强制结果。伤害、buff、逃离移动和状态变更由 Godot 执行。

Godot 负责按目标 NPC 状态提供 `allowed_decisions`：已入伍且有主武器、实际处于 `combat` 模式的 NPC 可继续战斗、逃离或斗志激昂；避战 / 非战斗人员只能逃离或继续避战。后端和模型返回越界结果时，Godot 必须规则降级，不让非战斗人员获得斗志激昂或直接参战。

### 首次睡眠总结

`POST /npc/daily_reflection`

输入 Schema：`DailyReflectionRequest`
输出 Schema：`DailyReflectionResponse`

输出第一人称日记、当天记忆摘要和 `KnowledgeGraphPatch` 列表。

当前状态：T1004/T1005 已在 Flask 后端接通 `/npc/daily_reflection`，使用 `DailyReflectionRequest` 校验输入、调用 `ModelAdapter.generate("daily_reflection", ...)`，再用 `DailyReflectionResponse` 校验输出。接口历史名仍是 daily_reflection，当前玩法语义是首次睡眠总结。Godot 侧 `DailyReflectionSystem` 监听 `sleep_started`、`sleep_ended` 和 `logical_time_tick`，NPC 每天首次睡眠满 1 游戏小时后通过 `LLMBridge.request_npc_daily_reflection(...)` 调用该接口；成功时写入 NPC 长期日记和知识图谱占位，失败时使用 Godot 模板降级，完成后清空该 NPC 当天短期事件 / 见闻索引。该调用会申请 TimeSystem 慢速，且请求发起到应用完成期间 NPC 处于不可打断的深度睡眠锁。

### 其他 AI 辅助

后续接口可复用：

- `KnowledgeGraphUpdateRequest` / `KnowledgeGraphUpdateResponse`
- `ProactiveIntentionRequest` / `ProactiveIntentionResponse`
- `PlayerStrategyClassificationRequest` / `PlayerStrategyClassificationResponse`

## 数据流

```text
玩家点击 NPC
  ↓
Godot 收集 NPC 当前状态、地点信息、短期记忆摘要
  ↓
Godot 通过 TimeSystem 注册 LLM 等待慢速请求
  ↓
发送到后端
  ↓
后端拼装 Prompt 并调用模型
  ↓
模型返回 JSON
  ↓
后端校验 JSON
  ↓
Godot 释放 TimeSystem 慢速请求
  ↓
Godot 执行合法结果
  ↓
权威结果写入 MemorySystem 事件系统，并按可见性通过对应地点信息节点即时广播给当前在场 NPC；广场公开信息使用 `location_id == "plaza"` 的本地公开事件
```

## 失败降级

如果 LLM 请求失败，Godot 必须释放 TimeSystem 慢速请求，并使用 Mock / 规则 / 模板结果降级，不能让游戏长期停留在慢速逻辑时间。

## 时间倍率边界

Godot 不使用后端结果直接决定时间倍率。后端只返回业务 JSON；是否申请慢速、慢速 request id、超时释放和恢复玩家速度，由 Godot 的 LLMBridge / DialogSystem / 计划系统负责。

T1104A 起，TimeSystem 还支持“有效倍率上限”请求。CombatSystem 只在活动敌人存在时注册 `combat_enemy_presence` 上限，把有效倍率最高压到 `x1`；所有敌人消失后释放。该上限与 LLM 慢速取更慢者：玩家选择 `x4` 且有敌人时实际为 `x1`，战斗中若有 LLM 调用则实际可降到 `1/60`，调用结束后回到敌人在场的 `x1`。后端和 LLM 仍不直接决定时间倍率。

T1104B 起，CombatSystem 不把 `logical_time_tick` 传入的原始游戏秒直接当作攻击冷却秒。战斗攻击冷却和敌人位移表现使用 `game_delta_seconds / 60` 得到的战斗动作秒，因此默认 `x1` 下现实 1 秒推进游戏内 1 分钟，也只推进约 1 秒战斗动作。工作、日常状态、治疗、建筑修复 / 升级等经营结算仍直接使用 TimeSystem 游戏秒。

## Godot LLMBridge 当前实现

T0604 已在 Godot 侧新增 `res://scripts/systems/LLMBridge.gd`，挂载于 `Main/Systems/LLMBridge`；T0604A 已将传输层替换为 Godot 原生 `HTTPClient` 状态机。

当前能力：

- `check_health()` 通过原生 HTTP 请求 `GET /health`，并通过 `backend_status_changed(status_text, ok)` 供 HUD 显示后端状态。
- `build_npc_dialogue_payload(...)` 按 T0603/T1201 Schema 收集目标 NPC 设定、守备官/NPC 说话者上下文、应征标记、轮次、NPC 状态、短期记忆、长期记忆、地点快照、`interaction_context` 和必要时的 `battlefield_context`。
- `request_npc_dialogue(...)` 通过原生 HTTP 请求 `POST /npc/dialogue`，返回后端 Mock JSON 或错误字典。
- `build_npc_daily_plan_payload(...)` 按 T1003 Schema 收集目标 NPC 共享上下文、当前 `current_order`、短期记忆、长期记忆、地点、广场、资源、建筑状态、行动白名单和计划规则。
- `request_npc_daily_plan(...)` 通过原生 HTTP 请求 `POST /npc/plan_day`，返回后端 Mock 24 小时计划或错误字典。
- `build_npc_plan_revision_payload(...)` / `request_npc_plan_revision(...)` 通过 `POST /npc/revise_plan` 处理 T1002 行动异常和指令变化后的计划修订。
- 对话请求前注册 `TimeSystem.request_time_slowdown(...)`，成功、失败或超时后调用 `release_time_slowdown(...)`。
- `build_npc_dialogue_payload(...)` 与共享 NPC 上下文构造会注入目标 NPC 最新 `current_order`；`get_last_npc_context_injection()` 暴露最近注入快照用于 GM / 自动化验证。

当前传输层不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件。`LLMBridge` 会解析后端 base url，使用 `HTTPClient.connect_to_host(...)`、`request(...)`、`poll()` 和响应体读取循环完成显式请求状态机，并用 `request_timeout_seconds` 覆盖连接、请求和响应体读取超时。后端关闭、超时、非法 JSON 或后端 `ok=false` 都返回可处理错误字典；会影响当前事态的对话、每日计划和计划修订请求在成功、失败或超时后都会释放 TimeSystem 慢速请求。T1006 新增异步对话请求路径，UI 等待 NPC 回复时不阻塞结束按钮；取消会释放慢速并清除 NPC LLM 活动，后台 HTTP 返回后只发出已取消结果，不再应用到会话。

T0703A/T1002/T1003 已将 `current_order` 接入共享 NPC 请求上下文、对话顶层 payload、每日计划请求和计划修订请求，由 `LLMBridge` 统一收集，避免只在某一种 Prompt 中手工拼接。Godot 保持当前指令、事件事实、行动白名单与结算的权威；后端只负责把该上下文传给模型并校验模型输出。新指令重评估现在会通过 T1002 链路应用 Mock 修订计划或规则降级计划；每日计划生成会通过 T1003 链路应用 Mock 24 小时计划或规则降级计划。

验证脚本 `tools/verify_llm_bridge.gd` 会静态检查 `LLMBridge.gd` 不含 `curl.exe` / `OS.execute` / 临时请求体文件旧路径，并覆盖后端关闭、health、`/npc/dialogue` Mock 成功和失败后慢速释放。

T0604 遇到的坑：

- Godot 原生 HTTP 的首次尝试在 headless 脚本验证中被信号等待和节点生命周期卡住；后续需要显式请求状态机、完成回调和超时。
- 同步等待异步 HTTP 结果会导致验证脚本挂起；所有成功、失败和超时路径都必须释放 TimeSystem 慢速请求。
- Windows 命令行直接传中文 JSON、引号和换行容易破坏请求体；T0604 才临时使用 `curl.exe` + 临时 JSON 文件。
- 本机环境变量残留非 mock provider 且缺少 Key 时，后端会按设计返回 provider unavailable；验证脚本应显式使用 mock 或隔离环境。
- 这些问题属于 Godot 传输层和开发验证环境问题，不是 NPC、记忆、Prompt 或前后端职责边界的问题。

## API Key

禁止把 API Key 写入仓库。  
真实供应商 API Key 默认只存在于服务器后端环境变量或后端 `.env`，并确保 `.gitignore` 忽略 `.env`。Godot 客户端不得保存、提交、导出或要求玩家在 Demo 阶段必须提供供应商 API Key。
