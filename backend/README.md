# Backend README

T0092 起，正式 provider 使用比 HTTP / Godot 更小的内部合同。Model Adapter 在发送前删除纯传输 `meta`、`null`、同值资源 / 记忆 / 轮次副本和分支外字段；模型返回后确定性补齐完整响应的固定 envelope、派生布尔值、`immediate_action` 及计划候选的 `action_kind / priority / 唯一 location_id`。HTTP Schema、动态白名单和业务校验仍验证补齐后的完整结构，非法行动、目标、枚举和小时不会被降级掩盖。

T0078 起，`/npc/plan_revision_judgement` 把请求中的 `required_revision_hours` 视为程序权威范围下限。若真实模型遗漏，HTTP 层保留模型选择的其他合法小时、并入 required 集合、同步令 `needs_revision=true`，并在 `model_normalizations` 写入 `required_revision_hours_authoritative_union`；它不生成第二层行动。该规则用于自主 NPC-NPC 发起者和当前计划仍为 `seek_guard_officer` 的 NPC 主动守备官会话。

本目录用于 Python 后端，负责：

- LLM API 调用
- Prompt 拼装
- JSON 校验
- NPC 对话
- 每日计划
- 战斗心理判定
- 熟睡总结
- 知识图谱更新
- API 额度统计

T0025/T0049/T0050 后，`/npc/plan_day` 与 `/npc/revise_plan` 按请求中的 `allowed_actions` 校验计划候选。固定地点行动精确校验 `action_id + action_kind + target_id + location_id`；T0091 起 `talk_to_npc` 只由 `action_id + target_id` 选择 NPC，模型请求不再包含候选地点，输出可省略 / 置空地点。若供应商冗余返回瞬时地点，后端确定性规范化为 `null` 并写入 `model_normalizations`；白名单外目标、自聊、错误 kind 与空 `dialogue_goal` 仍失败。通用 `/npc/plan_revision_judgement` 通过 `trigger_kind=dialogue|action_failure` 接收会话事实或程序权威失败项 / 类型 / 摘要 / 上下文、原计划和工作阶段下限；T0053 起同样必填动态 `station_context`、完整 `NPCContext`（含长短期记忆与当前指令）、行动候选及实时建筑 / 资源状态。T0054 将唯一顶层 `station_context` 收紧为精简简介、当前在站人员、完整建筑、工作模式行为和驿站规则五部分；目录是世界常识，不能替代 `allowed_actions / allowed_decisions` 或实时状态。输出仍是可为空的精确 `revision_hours`，空数组表示无需修订。`/npc/revise_plan` 只接受 `revision_scope=selected_hours` 与非空、升序、去重的 `revision_hours`，返回项小时集合必须与请求完全一致；对话和日常行动失败路径都使用第一层判别结果，第二层原样保留失败与人物上下文。首个真实 JSON / Schema 合法响应若仅业务校验失败，仍可交回同一真实 provider 纠正一次，不进入 Mock / 规则降级。T0029/T0030 后，`/npc/dialogue` 的 NPC-NPC 邀请 / 正式会话合同保持不变：目标 NPC 以 `reply_to_npc` 回复，邀请返回接受 / 拒绝，正式会话无硬轮次上限；模型只返回文本与意向，不直接改写行动、资源、工位或计划。

T0095 后，`/npc/daily_reflection` 必填 `summary_window / reflection_period`：前者固定 21:00 到次日 21:00 的锚点窗口和“接到守备命令的第N天”标签，后者限定从上次成功总结水位到本次请求快照的未总结内容。“接到守备命令”专指公告牌向驿站众人公开传达“我们奉命守住此地”，不是目标 NPC 入伍或收到个人命令；后端只约束模型叙事，不决定触发、记忆清理或日记写入。

禁止在仓库中提交真实 API Key。

开发期 mock 环境变量：

```bash
LLM_PROVIDER=mock
```

`.env` 不存在或未设置 `LLM_PROVIDER` 时，当前后端仍默认使用 `mock` provider；mock 不需要 API Key，也不会产生真实费用。该路径只用于本地开发、Schema 验证和自动化测试，不代表成品 / Demo 的模型失败兜底。

DeepSeek / OpenAI-compatible 本地或服务器配置示例：

```bash
LLM_PROVIDER=deepseek
LLM_API_KEY=your_real_backend_only_key
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-v4-flash
LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS=10
LLM_PROVIDER_IDLE_TIMEOUT_SECONDS=120
LLM_FALLBACK_TO_MOCK=false
LLM_FORCE_JSON_RESPONSE=true
LLM_TEMPERATURE=0.2
LLM_THINKING_MODE=disabled
LLM_INPUT_CACHE_HIT_COST_PER_M_TOKENS=0.02
LLM_INPUT_COST_PER_M_TOKENS=1
LLM_OUTPUT_COST_PER_M_TOKENS=2
LLM_COST_LEDGER_ENABLED=true
LLM_COST_LEDGER_PATH=backend/logs/llm_cost_ledger.jsonl
LLM_DAILY_BUDGET_MAX_CNY=20
LLM_DAILY_BUDGET_TIMEZONE=Asia/Shanghai
LLM_DAILY_BUDGET_REQUEST_RESERVE_CNY=0.05
LLM_BUDGET_MAX_CALLS=0
LLM_BUDGET_MAX_INPUT_TOKENS=0
LLM_BUDGET_MAX_OUTPUT_TOKENS=0
LLM_BUDGET_MAX_TOTAL_TOKENS=0
LLM_BUDGET_MAX_COST=0
LLM_AUDIT_LOG_ENABLED=true
LLM_AUDIT_LOG_PATH=backend/logs/llm_calls.jsonl
LLM_AUDIT_LOG_INCLUDE_PAYLOADS=true
```

真实 Key 只放在 `backend/.env` 或服务器环境变量中，不写入 Godot 客户端、导出包或仓库。请求失败、超时、无 Key 或模型返回非 JSON 时，生产 / 演示路径必须返回可处理错误并记录真实失败原因；不要用 mock 内容伪装模型成功。`LLM_FALLBACK_TO_MOCK=true` 只能作为本地开发过渡或对比测试使用。

## 持久化 LLM 调用日志

T0069 后，使用环境配置创建的后端 ModelAdapter 默认把完整调用生命周期追加写入 `backend/logs/llm_calls.jsonl`。该目录已被 Git 忽略；日志包含玩家 / NPC 对话、人物上下文和模型输出，只能作为本地或受控服务器诊断数据保存，不应上传、提交或直接暴露给客户端。

- `LLM_AUDIT_LOG_ENABLED=true|false`：启用或关闭写盘，默认启用。
- `LLM_AUDIT_LOG_PATH=...`：JSONL 文件路径；相对路径以项目根目录解析，默认 `backend/logs/llm_calls.jsonl`。
- `LLM_AUDIT_LOG_INCLUDE_PAYLOADS=true|false`：是否保存完整输入、正式 system/user messages、聚合响应和校验详情，默认启用。关闭后仍保存 request id、call type、provider、model、状态和 usage。

每行是一个带 `schema_version=1`、UTC 时间和唯一 `audit_id` 的 JSON 事件。同一次调用按生命周期关联：

- `call_started`：ModelAdapter 输入 payload 与目标 NPC / 事件。
- `provider_request_sent`：每次正式供应商尝试的完整 JSON body、重试序号和 endpoint；明确不保存请求头。
- `provider_response_received`：HTTP 状态与流式聚合后的供应商响应。
- `provider_output_parsed` / `provider_output_rejected`：原始模型正文、解析结果，或截断 / 非 JSON 原因。
- `provider_attempt_failed`：HTTP、连接、空闲超时或响应格式错误。
- `call_completed`：最终内容、usage、fallback 与错误状态。
- `business_validation_failed`：后端 Pydantic Schema 或业务合同拒绝结果；与原调用共用 audit id。

常见 `api_key / authorization / password / secret / token` 凭据字段、Bearer 值、`sk-...` 值和当前配置的真实 API Key 会在写盘前递归替换为 `[REDACTED]`。日志写入采用进程内按路径加锁；写盘失败只记录在运行配置的 `audit_log.last_error`，不会让游戏调用失败。`GET /health`、`GET /debug/llm_usage` 和 GM“成本统计”只返回日志状态 / 路径 / 最近写盘错误，不返回日志正文。

PowerShell 实时查看：

```powershell
Get-Content -Encoding UTF8 -Wait backend/logs/llm_calls.jsonl
```

正式业务请求不再向供应商发送 `max_tokens`，避免对话、通用计划修改判别、每日计划、计划修订、战时心理判定或首次睡眠总结被客户端固定输出上限截断。DeepSeek V4 默认可能启用 thinking，结构化 JSON 业务默认设置 `LLM_THINKING_MODE=disabled`，避免思考内容挤占最终结构化内容。后端 `/health` 会暴露 `client_output_token_limit_applied=false`；任一正式结构化调用首次返回空内容、`finish_reason=length` 或非法 JSON 时，会自动用对应业务的紧凑提示重试一次，并在 usage 中记录真实 `finish_reason`、内容长度和尝试次数。供应商自身的模型上下文上限仍然存在，但不再由本项目额外设置单次输出硬上限。

正式供应商请求使用流式 SSE 聚合完整 JSON，不设置模型生成的固定总时长。`LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS` 只限制建立供应商连接的时间；`LLM_PROVIDER_IDLE_TIMEOUT_SECONDS` 只在连接建立后长时间完全收不到 token、keep-alive 或其他数据时触发。持续排队 keep-alive 或持续生成 token 会继续等待，不会因为经过固定 30 / 75 / 90 秒而失败。

`LLM_BUDGET_MAX_*` 是兼容的进程内调用 / token / 费用守门，默认 `0` 表示关闭。T0077 后，环境构造的正式 DeepSeek adapter 还默认启用 `LLM_DAILY_BUDGET_MAX_CNY=20`。T0090 将当前 Flash 开发配置的每次 provider HTTP 尝试预留校准为 ¥0.05，再把供应商返回的缓存命中输入、未命中输入和输出 usage 按官方人民币价追加到 `backend/logs/llm_cost_ledger.jsonl`。该值来自 347 次实测尝试的均值 ¥0.01899017、P99 ¥0.03258096 和最大值 ¥0.04262264，并留有约 17% 高于实测最大值的余量；它不再覆盖供应商声明的极端最大上下文理论成本。账本按 `Asia/Shanghai` 自然日重放，后端重启不清零；自动重试逐次计费。已用 + 在途预留会越过上限、价格缺失或账本故障时，请求在发给供应商前返回 HTTP 429 / `budget_exceeded`，不会自动切到 mock。Prompt、模型、上下文上限或实际费用分布明显变化时必须重新统计并提高预留。

LLM 相关任务的推荐验证顺序：

1. 先用 `LLM_PROVIDER=mock` 跑基础 Schema / 通信自动化测试。
2. 再用真实 `LLM_API_KEY`、真实 provider 和 `LLM_FALLBACK_TO_MOCK=false` 调用对应业务接口。
3. 通过 `GET /debug/llm_usage` 确认 provider、model、request id、token / 费用估算、`fallback_used=false` 和失败原因记录。
4. 如果没有真实 Key，不能把真实 Prompt / LLM 行为标记为完全验收。

初始接口建议：

- `GET /health`
- `GET /debug/llm_usage`
- `POST /mock/model`
- `POST /npc/dialogue`
- `POST /npc/plan_revision_judgement`（旧 `/npc/dialogue_plan_revision_judgement` 兼容）
- `POST /npc/plan_day`
- `POST /npc/revise_plan`
- `POST /npc/battle_judgement`
- `POST /npc/daily_reflection`

六个正式 LLM 业务端点成功响应都会统一附加 `model_provider`、`model_name`、`model_fallback_used` 和 `model_normalizations`；该数组当前仅在计划 / 修订发生确定性 kind 规范化时非空。这些字段来自 Model Adapter 运行结果和后端业务校验，不属于模型输出 Schema；Godot 据此区分真实 provider、显式开发 Mock 和 fallback，不能按调用路径硬编码来源。正式日计划、对话计划判别和修订仍只接受非 Mock 且无 fallback 的响应。

Mock 调试接口：

```bash
curl -X POST http://127.0.0.1:5000/mock/model ^
  -H "Content-Type: application/json" ^
  -d "{\"call_type\":\"battle_judgement\",\"payload\":{\"trigger\":\"low_hp\",\"allowed_decisions\":[\"avoid_battle\",\"escape_station\"]}}"
```

该接口显式使用 mock provider，不受本地 `.env` 中未来真实 provider 配置影响。返回的 `usage` 中 token 是伪估算，费用固定为 0；正式业务接口负责校验各自 Schema 并经由 `ModelAdapter` 返回业务 JSON，Godot 侧仍负责事件入库和权威状态结算。生产 / 演示路径真实 provider 失败时不得退回该接口内容。

Usage 调试接口：

```bash
curl http://127.0.0.1:5000/debug/llm_usage
```

返回当前 provider / model 配置快照、预算上限与剩余额度、业务调用记录，以及 `summary.provider_usage.session / daily` 的逐 provider 尝试 token、缓存命中 / 未命中、人民币估算和今日持久化金额。供应商生成后若响应未通过 Schema 或业务校验，后端会把同一 request id 对应的业务 usage 原地标为 `SchemaValidationError`；provider 尝试账本保持不可变，避免漏掉已经实际发生的供应商费用。

NPC 对话开发 mock 示例：

```bash
curl -X POST http://127.0.0.1:5000/npc/dialogue ^
  -H "Content-Type: application/json" ^
  -d "{\"meta\":{\"request_id\":\"demo_dialogue\",\"call_type\":\"dialogue\",\"source\":\"godot\",\"requires_time_slowdown\":true},\"game_time\":{\"day\":1,\"time\":\"08:00:00\",\"hour\":8},\"dialogue_kind\":\"player_npc\",\"dialogue_phase\":\"conversation\",\"npc_id\":\"cook_01\",\"npc_name\":\"布鲁诺\",\"npc_setting\":{\"background_job\":\"厨子\"},\"speaker_name\":\"守备官\",\"speaker_text\":\"守备官请求你应征，帮忙守住驿站。\",\"speaker_context\":{\"speaker_id\":\"guard_officer\",\"speaker_name\":\"守备官\",\"speaker_kind\":\"guard_officer\",\"appearance\":\"披着旧军斗篷。\"},\"is_recruitment_request\":true,\"current_round\":1,\"max_rounds\":999999,\"npc_state\":{\"hp\":100,\"max_hp\":100,\"recruited\":false},\"dialogue_state\":{\"visibility\":\"local_public\",\"location_id\":\"dining_hall\",\"location_name\":\"食堂\",\"current_round\":1,\"max_rounds\":999999},\"short_memory\":{\"experienced_events\":[],\"witnessed_events\":[]},\"long_memory\":{\"knowledge_graph\":{},\"diary\":[]},\"location_context\":{\"location_id\":\"dining_hall\"},\"allowed_actions\":[{\"action_id\":\"work_dining_hall\",\"name\":\"加工餐食\",\"action_kind\":\"work\",\"location_id\":\"dining_hall\",\"tags\":[\"work\"],\"context\":{\"authority\":\"ActionSystem\"}}]}"
```

在 `LLM_PROVIDER=mock` 时，该接口返回开发期 Mock JSON，不写入 Godot 事件库；Godot 侧对话事件入库、`local_public` 广播、T1201 战时对话 `wartime_reaction` 结算由 LLMBridge / DialogSystem / CombatSystem 执行。真实 Prompt 验收需要切换到真实 provider，并确认失败不会自动 mock fallback。

当前 Schema：

- `backend/schemas/common.py`：共享游戏时间、请求元信息、NPC 上下文、短期记忆和行动候选。
- `backend/schemas/npc_ai.py`：对话、对话 / 行动失败通用计划修改判别、每日计划、精确小时计划修订、战斗判定、熟睡总结（含窗口与内容水位）、知识图谱更新、主动交涉和玩家话术分类请求/响应。

验证：

```bash
python tools/verify_backend_schemas.py
python tools/verify_mock_model_adapter.py
python tools/verify_api_budget_debug.py
python tools/verify_dialogue_mock_endpoint.py
python tools/verify_dialogue_prompt.py
python tools/verify_dialogue_prompt_real.py
python tools/verify_dialogue_plan_revision_judgement.py
python tools/verify_dialogue_plan_revision_judgement_real.py
python tools/verify_plan_day_prompt.py
python tools/verify_plan_day_prompt_real.py
python tools/verify_plan_day_endpoint.py
python tools/verify_plan_revision_endpoint.py
python tools/verify_plan_revision_prompt.py
python tools/verify_plan_revision_prompt_real.py
python tools/verify_daily_reflection_endpoint.py
```

`tools/verify_dialogue_prompt.py` 使用 fake real-provider 检查 `/npc/dialogue` 系统 Prompt 是否包含职业、人设、记忆、`current_order`、行动能力边界、征召、战时、避战和逃离挽留约束。`tools/verify_dialogue_action_reference.gd` 检查 7 个对话上下文的候选与日计划候选一致。`tools/verify_dialogue_prompt_real.py` 只在已有非 mock `LLM_PROVIDER` 和真实 `LLM_API_KEY` 时调用真实 `/npc/dialogue`，覆盖玩家-NPC / NPC-NPC 能做与做不到问答、日常、应征、战时和逃离挽留；无 Key 时会明确 skip，不把 mock 当成真实验收。
`tools/verify_plan_day_prompt.py` 使用 fake real-provider 检查 `/npc/plan_day` 系统 Prompt 是否包含 24 阶段、通常至少 6 阶段的强建议、非程序硬门槛、行动白名单和 `current_order` 边界。`tools/verify_plan_day_prompt_real.py` 只在已有非 mock `LLM_PROVIDER` 和真实 `LLM_API_KEY` 时调用真实 `/npc/plan_day`，并校验返回计划覆盖 0-23 点且只使用 allowed_actions / idle；工作阶段数量作为模型质量观察项，不作为 endpoint 成功条件。
`tools/verify_dialogue_plan_revision_judgement.py` 覆盖通用判别 Prompt、对话 / 行动失败分支、空 / 非空 `revision_hours`、小时边界和 endpoint 元数据；`tools/verify_dialogue_plan_revision_judgement_real.py` 在有真实 Key 时验收行动失败判别和第二层精确范围，并要求 `fallback_used=false`。
`tools/verify_plan_revision_prompt.py` 与 `tools/verify_plan_revision_endpoint.py` 覆盖 `selected_hours` 唯一范围、请求 / 响应小时集合严格一致、即时行动、工作阶段和白名单；`tools/verify_plan_revision_prompt_real.py` 用真实 provider 验收精确选中小时修订，并要求 `fallback_used=false`。

真实 provider smoke test 可复用同一业务接口：启动后端时设置真实 `LLM_PROVIDER` / `LLM_API_KEY` / `LLM_FALLBACK_TO_MOCK=false`，调用 `/npc/dialogue` 或当前任务涉及的接口，然后查看 `/debug/llm_usage`。不要把包含 Key 的 `.env`、命令历史截图或日志提交到仓库。
