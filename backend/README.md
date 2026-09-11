# Backend README

## T0306 五类战斗记忆聚合透传

Godot 只对 `attack_made / damage_taken / building_damaged / defense_device_triggered / horse_damaged` 生成严格同键聚合投影；后端不重新分组，也不接收或修改 MemorySystem 原始事件。Model Adapter 继续对白名单顶层字段做二次投影，并深拷贝 `details.aggregation` 的次数、累计伤害、HP 与时间范围到 provider。七类正式调用的 endpoint、Schema 顶层和调用频率均不变。

## T0289 对话情绪合同

`/npc/dialogue` 的三类响应现在统一要求 `emotion` 为：`none / happy / relieved / angry / sad / afraid / surprised / confused / determined`。基础 Prompt 和动态 schema hint 都会给出该白名单。HTTP 层会把旧 `neutral / wary / fearful / tense / shaken / resolved`、已知中文近义词、`null` 或未知值归一化为合法 id，并把变化写入 `model_normalizations`；情绪不是权威数值，不影响特殊交互结算。

T1601A 另行增加玩家语音预处理端点 `POST /voice/analyze`。它接收 multipart 的 `audio`、`request_id`、`npc_id`、`dialogue_id` 和可选 `locale`，并按 `data/dialogue_input_config.json` 复核 30 秒、6 MiB 与 PCM WAV。T1602 已实现显式 `VOICE_PROVIDER=qwen3_asr_flash`：后端以 Base64 Data URI 调用北京业务空间专属 OpenAI 兼容接口，从 `message.content` 与 `message.annotations[].emotion` 读取结果；Key 不进入 Godot 或日志，真实失败绝不回退 Mock。语音情绪只允许 `neutral / happy / sad / disgusted / angry / fearful / surprised`，未知值归一化为 `none` 并保留转写。

T1604 可用 `tools/generate_t1604_voice_samples.ps1`、`tools/add_t1604_light_noise_sample.py` 和 `tools/verify_t1604_voice_real_matrix.py` 生成临时中文样本并批量跑真实 `/voice/analyze`。矩阵输出不包含音频、Base64 或 Key；合成音只用于传输 / 转写回归，不能代替真人情绪和实体麦克风验收。

直接从项目根目录运行 `python backend/app.py` 或导入 `backend.app` 时，服务会按 `backend/app.py` 的绝对位置加载同目录 `.env`，不依赖当前工作目录；调用进程中已显式设置的环境变量仍优先。

真实语音与文本 Provider 共享 `LLM_COST_LEDGER_PATH` 和 `LLM_DAILY_BUDGET_MAX_CNY`。语音调用前按 `VOICE_DAILY_BUDGET_REQUEST_RESERVE_CNY`（默认 `0.0066` 元）预留，成功后按 `VOICE_COST_PER_SECOND_CNY`（默认 `0.00022` 元/秒）和服务端复核的 WAV 时长结算；超预算返回 `voice_budget_exceeded`，不会上传到百炼。

T0285 起，玩家对话的应征、鼓舞士气、调整战斗策略、鼓励工作为最多开启一个的动态特殊模块。只有请求 flag 为 true 时，Model Adapter 才拼入对应判断 Prompt 和输出字段；工作返回 `work_encouragement_reaction=none|escape|work_boost`，应征允许无关发言返回 `recruitment_result=none`。HTTP 只校验意向，20% 工作倍率、当天 24:00 失效、资源 / 治疗 / 建筑结算和逃离均由 Godot 权威系统处理。

T0116 新增 `/npc/dialogue_intent_revalidation`。它在计划对话执行前接收旧意图制定时间、当前完整计划和计划同级 NPC / 驿站 / 建筑 / 资源上下文，只返回 continue / modify / cancel_and_replan。HTTP 层严格约束首句字段并可对业务矛盾使用同一真实 provider 纠错一次；失败不转 Mock。

T0106 起，正式 NPC 请求的短期记忆在供应商边界统一为全量紧凑投影；T0116 加入执行前复核后当前共七类。每条只允许 `type / summary / importance / day / time / details`，不转发 `event_id / payload / extra`。普通调用保留当前索引全部 `experienced_events / witnessed_events`；`daily_reflection` 保留带 `memory_kind` 的全部 `day_events`，并删除同批 `npc.short_term_memory`。这层清洗是 Godot 压缩后的防御边界，不改变 MemorySystem 权威事件或 HTTP 业务事实。

T0092 起，正式 provider 使用比 HTTP / Godot 更小的内部合同。Model Adapter 在发送前删除纯传输 `meta`、`null`、同值资源 / 记忆 / 轮次副本和分支外字段；模型返回后确定性补齐完整响应的固定 envelope 和派生字段。T0097 起计划项以 `hour + action_id` 为核心，拜访、NPC 目标和建筑目标分别读取 `location_id / target_npc_id / building_id`；其他模型字段全部丢弃，再由动态候选编译 `action_kind / priority / internal target / 固定 location_id` 和修订 `immediate_action`。HTTP Schema、动态白名单和业务校验仍验证补齐后的完整结构，非法行动、必要目标和小时不会被降级掩盖。

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

T0025/T0049/T0050 后，`/npc/plan_day` 与 `/npc/revise_plan` 按请求中的 `allowed_actions` 校验计划候选。T0097 起 provider 不再回显内部 `action_kind / target_id / priority`：固定行为只选 action，拜访选地点，找人 / 治疗选 NPC，修复 / 升级选建筑；无关字段直接丢弃。编译后的内部 action/kind/target/location 组合仍精确校验，白名单外目标、自聊与空 `dialogue_goal` 仍失败。通用 `/npc/plan_revision_judgement` 通过 `trigger_kind=dialogue|action_failure` 接收会话事实或程序权威失败项 / 类型 / 摘要 / 上下文、原计划和工作阶段下限；T0053 起同样必填动态 `station_context`、完整 `NPCContext`（含长短期记忆与当前指令）、行动候选及实时建筑 / 资源状态。T0054 将唯一顶层 `station_context` 收紧为精简简介、当前在站人员、完整建筑、工作模式行为和驿站规则五部分；目录是世界常识，不能替代 `allowed_actions / allowed_decisions` 或实时状态。输出仍是可为空的精确 `revision_hours`，空数组表示无需修订。`/npc/revise_plan` 只接受 `revision_scope=selected_hours` 与非空、升序、去重的 `revision_hours`，返回项小时集合必须与请求完全一致；对话和日常行动失败路径都使用第一层判别结果，第二层原样保留失败与人物上下文。首个真实 JSON / Schema 合法响应若仅业务校验失败，仍可交回同一真实 provider 纠正一次，不进入 Mock / 规则降级。T0029/T0030 后，`/npc/dialogue` 的 NPC-NPC 邀请 / 正式会话合同保持不变：目标 NPC 以 `reply_to_npc` 回复，邀请返回接受 / 拒绝，正式会话无硬轮次上限；模型只返回文本与意向，不直接改写行动、资源、工位或计划。

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
- `POST /voice/analyze`（显式 Mock 或 T1602 真实百炼 `qwen3-asr-flash`）
- `POST /mock/model`
- `POST /npc/dialogue`
- `POST /npc/plan_revision_judgement`（旧 `/npc/dialogue_plan_revision_judgement` 兼容）
- `POST /npc/plan_day`
- `POST /npc/revise_plan`
- `POST /npc/battle_judgement`
- `POST /npc/daily_reflection`
- `POST /game/epilogue`

六个正式 LLM 业务端点成功响应都会统一附加 `model_provider`、`model_name`、`model_fallback_used` 和 `model_normalizations`。T0097 的计划项无关字段在 Model Adapter 编译边界直接丢弃，原始值只保留在本地审计日志，不为每个丢弃字段生成 normalization；`model_normalizations` 继续记录其他程序权威合并或默认化。这些字段不属于模型输出 Schema；Godot 据此区分真实 provider、显式开发 Mock 和 fallback，不能按调用路径硬编码来源。正式日计划、对话计划判别和修订仍只接受非 Mock 且无 fallback 的响应。

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
- `backend/schemas/voice_input.py`：语音元数据、成功 / 失败响应、统一输入配置与百炼原生七类情绪。
- `backend/services/voice_model_adapter.py`：独立语音 Provider 边界、显式 Mock、真实百炼 HTTP、七类情绪归一化和 usage。

验证：

```bash
python tools/verify_backend_schemas.py
python tools/verify_voice_input_mock_endpoint.py
python tools/verify_t1602_qwen_voice_provider.py
# 准备真实 WAV 和 backend/.env 后：
python tools/verify_t1602_qwen_voice_provider_real.py path/to/recording.wav
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
