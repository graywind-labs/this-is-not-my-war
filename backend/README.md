# Backend README

本目录用于 Python 后端，负责：

- LLM API 调用
- Prompt 拼装
- JSON 校验
- NPC 对话
- 每日计划
- 战斗心理判定
- 睡前总结
- 知识图谱更新
- API 额度统计

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
LLM_TIMEOUT_SECONDS=30
LLM_FALLBACK_TO_MOCK=false
LLM_INPUT_COST_PER_M_TOKENS=0
LLM_OUTPUT_COST_PER_M_TOKENS=0
LLM_BUDGET_MAX_CALLS=0
LLM_BUDGET_MAX_INPUT_TOKENS=0
LLM_BUDGET_MAX_OUTPUT_TOKENS=0
LLM_BUDGET_MAX_TOTAL_TOKENS=0
LLM_BUDGET_MAX_COST=0
```

真实 Key 只放在 `backend/.env` 或服务器环境变量中，不写入 Godot 客户端、导出包或仓库。请求失败、超时、无 Key 或模型返回非 JSON 时，生产 / 演示路径必须返回可处理错误并记录真实失败原因；不要用 mock 内容伪装模型成功。`LLM_FALLBACK_TO_MOCK=true` 只能作为本地开发过渡或对比测试使用。

预算变量默认 `0` 表示关闭。设置任一 `LLM_BUDGET_MAX_*` 后，后端会在正式业务接口调用模型前检查累计调用、token 或费用估算；超限时返回 HTTP 429 / `budget_exceeded`，并在 `/debug/llm_usage` 中记录 `exception_type=BudgetExceeded`、request id、call_type、provider、model 和失败原因，不会自动切到 mock。

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
- `POST /npc/plan_day`
- `POST /npc/revise_plan`
- `POST /npc/battle_judgement`
- `POST /npc/daily_reflection`

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

返回当前 provider / model 配置快照、预算上限与剩余额度、累计调用次数、token、费用估算、fallback 次数、失败原因和逐次调用记录。

NPC 对话开发 mock 示例：

```bash
curl -X POST http://127.0.0.1:5000/npc/dialogue ^
  -H "Content-Type: application/json" ^
  -d "{\"meta\":{\"request_id\":\"demo_dialogue\",\"call_type\":\"dialogue\",\"source\":\"godot\",\"requires_time_slowdown\":true},\"game_time\":{\"day\":1,\"time\":\"08:00:00\",\"hour\":8},\"dialogue_kind\":\"player_npc\",\"npc_id\":\"cook_01\",\"npc_name\":\"布鲁诺\",\"npc_setting\":{\"background_job\":\"厨子\"},\"speaker_name\":\"守备官\",\"speaker_text\":\"守备官请求你应征，帮忙守住驿站。\",\"speaker_context\":{\"speaker_id\":\"guard_officer\",\"speaker_name\":\"守备官\",\"speaker_kind\":\"guard_officer\",\"appearance\":\"披着旧军斗篷。\"},\"is_recruitment_request\":true,\"current_round\":1,\"max_rounds\":5,\"npc_state\":{\"hp\":100,\"max_hp\":100,\"recruited\":false},\"dialogue_state\":{\"visibility\":\"local_public\",\"location_id\":\"dining_hall\",\"location_name\":\"食堂\",\"current_round\":1,\"max_rounds\":5},\"short_memory\":{\"experienced_events\":[],\"witnessed_events\":[]},\"long_memory\":{\"knowledge_graph\":{},\"diary\":[]},\"location_context\":{\"location_id\":\"dining_hall\"}}"
```

在 `LLM_PROVIDER=mock` 时，该接口返回开发期 Mock JSON，不写入 Godot 事件库；Godot 侧对话事件入库、`local_public` 广播、T1201 战时对话 `wartime_reaction` 结算由 LLMBridge / DialogSystem / CombatSystem 执行。真实 Prompt 验收需要切换到真实 provider，并确认失败不会自动 mock fallback。

当前 Schema：

- `backend/schemas/common.py`：共享游戏时间、请求元信息、NPC 上下文、短期记忆和行动候选。
- `backend/schemas/npc_ai.py`：对话、每日计划、计划修订、战斗判定、睡前总结、知识图谱更新、主动交涉和玩家话术分类请求/响应。

验证：

```bash
python tools/verify_backend_schemas.py
python tools/verify_mock_model_adapter.py
python tools/verify_api_budget_debug.py
python tools/verify_dialogue_mock_endpoint.py
python tools/verify_dialogue_prompt.py
python tools/verify_dialogue_prompt_real.py
python tools/verify_plan_day_prompt.py
python tools/verify_plan_day_prompt_real.py
python tools/verify_plan_day_endpoint.py
python tools/verify_plan_revision_endpoint.py
python tools/verify_daily_reflection_endpoint.py
```

`tools/verify_dialogue_prompt.py` 使用 fake real-provider 检查 `/npc/dialogue` 系统 Prompt 是否包含职业、人设、记忆、`current_order`、征召、战时、避战和逃离挽留约束。`tools/verify_dialogue_prompt_real.py` 只在已有非 mock `LLM_PROVIDER` 和真实 `LLM_API_KEY` 时调用真实 `/npc/dialogue`，覆盖日常对话、提出应征、战时结构化意向和逃离挽留；无 Key 时会明确 skip，不把 mock 当成真实验收。
`tools/verify_plan_day_prompt.py` 使用 fake real-provider 检查 `/npc/plan_day` 系统 Prompt 是否包含 24 阶段、至少 6 阶段工作、行动白名单和 `current_order` 边界。`tools/verify_plan_day_prompt_real.py` 只在已有非 mock `LLM_PROVIDER` 和真实 `LLM_API_KEY` 时调用真实 `/npc/plan_day`，并校验返回计划覆盖 0-23 点、只使用 allowed_actions / idle 且至少 6 个工作阶段。

真实 provider smoke test 可复用同一业务接口：启动后端时设置真实 `LLM_PROVIDER` / `LLM_API_KEY` / `LLM_FALLBACK_TO_MOCK=false`，调用 `/npc/dialogue` 或当前任务涉及的接口，然后查看 `/debug/llm_usage`。不要把包含 Key 的 `.env`、命令历史截图或日志提交到仓库。
