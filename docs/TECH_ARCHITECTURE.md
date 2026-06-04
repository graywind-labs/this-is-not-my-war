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
- 工作产出
- 战斗执行
- HP 扣除
- 昏迷、治疗、复苏状态
- 事件权威写入、地点/建筑信息节点当前状态维护、即时广播、NPC 事件库与见闻库维护
- 与后端通信
- T0604A 后通过 `Main/Systems/LLMBridge` 的 Godot 原生 `HTTPClient` 请求 `/health` 与 `/npc/dialogue`，并负责请求期间的 TimeSystem 慢速申请和释放

### Python 后端负责

- Prompt 拼装
- LLM 调用
- 结构化 JSON 校验
- 对话生成
- 每日计划生成
- 战斗/逃离心理判定
- 睡前总结
- 知识图谱更新
- API 成本统计
- 模型供应商切换

### LLM 负责

- NPC 如何理解事件
- NPC 如何说话
- NPC 是否愿意征召
- NPC 是否想参战、逃离、斗志激昂
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

输出为稳定 JSON。回复玩家时返回 `replyer_id`、`reply_text` 和 `recruitment_result`（`none` / `accept` / `reject`）；回复 NPC 时返回 `reply_text` 和 `should_end_dialogue`。通用字段还包含 `response_kind`、`intent`、`emotion`、`suggested_event_type` 和 `debug_reason`，便于 Godot 后续 UI、事件入库和调试。

NPC-NPC 对话由 Godot 控制轮次：上一轮回复者的 `reply_text` 会作为下一次请求的 `speaker_text` 输入给另一名 NPC；当 `current_round` 接近 `max_rounds` 时，Mock 和后续 Prompt 都应更倾向输出 `should_end_dialogue=true` 或结束性回复。实际征召状态、资源、HP 或事件写入仍由 Godot 结算。

### 每日计划

`POST /npc/plan_day`

输入 Schema：`DailyPlanRequest`
输出 Schema：`DailyPlanResponse`

输出必须是 24 条 `PlanItem`，每条包含小时、行动类型、行动 id、可选地点/目标和理由。计划是建议，不代表资源、移动或行动已经结算。

### 计划修订

`POST /npc/revise_plan`

输入 Schema：`PlanRevisionRequest`
输出 Schema：`PlanRevisionResponse`

用于目标不可用、工位占用、资源不足、对话打断、低 HP、低饱食、高疲劳和战斗警报等异常后的计划重评估。

### 战斗判定

`POST /npc/battle_judgement`

输入 Schema：`BattleJudgementRequest`
输出 Schema：`BattleJudgementResponse`

覆盖战斗开始、低 HP 和逃离检查。输出只表达参战、避战、继续战斗、逃离或斗志激昂等意向；伤害、逃离移动和状态变更由 Godot 执行。

### 睡前总结

`POST /npc/daily_reflection`

输入 Schema：`DailyReflectionRequest`
输出 Schema：`DailyReflectionResponse`

输出第一人称日记、当天记忆摘要和 `KnowledgeGraphPatch` 列表。

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

## Godot LLMBridge 当前实现

T0604 已在 Godot 侧新增 `res://scripts/systems/LLMBridge.gd`，挂载于 `Main/Systems/LLMBridge`；T0604A 已将传输层替换为 Godot 原生 `HTTPClient` 状态机。

当前能力：

- `check_health()` 通过原生 HTTP 请求 `GET /health`，并通过 `backend_status_changed(status_text, ok)` 供 HUD 显示后端状态。
- `build_npc_dialogue_payload(...)` 按 T0603 Schema 收集目标 NPC 设定、守备官/NPC 说话者上下文、应征标记、轮次、NPC 状态、短期记忆、长期记忆和地点快照。
- `request_npc_dialogue(...)` 通过原生 HTTP 请求 `POST /npc/dialogue`，返回后端 Mock JSON 或错误字典。
- 对话请求前注册 `TimeSystem.request_time_slowdown(...)`，成功、失败或超时后调用 `release_time_slowdown(...)`。

当前传输层不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件。`LLMBridge` 会解析后端 base url，使用 `HTTPClient.connect_to_host(...)`、`request(...)`、`poll()` 和响应体读取循环完成显式请求状态机，并用 `request_timeout_seconds` 覆盖连接、请求和响应体读取超时。后端关闭、超时、非法 JSON 或后端 `ok=false` 都返回可处理错误字典；会影响当前事态的请求在成功、失败或超时后都会释放 TimeSystem 慢速请求。

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
