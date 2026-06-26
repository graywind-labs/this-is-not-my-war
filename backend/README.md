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

推荐本地环境变量：

```bash
LLM_PROVIDER=mock
LLM_API_KEY=your_local_key
```

`.env` 不存在或未设置 `LLM_PROVIDER` 时，后端默认使用 `mock` provider；mock 不需要 API Key，也不会产生真实费用。

初始接口建议：

- `GET /health`
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

该接口显式使用 mock provider，不受本地 `.env` 中未来真实 provider 配置影响。返回的 `usage` 中 token 是伪估算，费用固定为 0；正式业务接口负责校验各自 Schema 并经由 `ModelAdapter` 返回 Mock JSON，Godot 侧仍负责事件入库和权威状态结算。

NPC 对话 Mock 接口：

```bash
curl -X POST http://127.0.0.1:5000/npc/dialogue ^
  -H "Content-Type: application/json" ^
  -d "{\"meta\":{\"request_id\":\"demo_dialogue\",\"call_type\":\"dialogue\",\"source\":\"godot\",\"requires_time_slowdown\":true},\"game_time\":{\"day\":1,\"time\":\"08:00:00\",\"hour\":8},\"dialogue_kind\":\"player_npc\",\"npc_id\":\"cook_01\",\"npc_name\":\"布鲁诺\",\"npc_setting\":{\"background_job\":\"厨子\"},\"speaker_name\":\"守备官\",\"speaker_text\":\"守备官请求你应征，帮忙守住驿站。\",\"speaker_context\":{\"speaker_id\":\"guard_officer\",\"speaker_name\":\"守备官\",\"speaker_kind\":\"guard_officer\",\"appearance\":\"披着旧军斗篷。\"},\"is_recruitment_request\":true,\"current_round\":1,\"max_rounds\":5,\"npc_state\":{\"hp\":100,\"max_hp\":100,\"recruited\":false},\"dialogue_state\":{\"visibility\":\"local_public\",\"location_id\":\"dining_hall\",\"location_name\":\"食堂\",\"current_round\":1,\"max_rounds\":5},\"short_memory\":{\"experienced_events\":[],\"witnessed_events\":[]},\"long_memory\":{\"knowledge_graph\":{},\"diary\":[]},\"location_context\":{\"location_id\":\"dining_hall\"}}"
```

该接口当前只返回 Mock JSON，不写入 Godot 事件库；Godot 侧对话事件入库、`local_public` 广播、T1201 战时对话 `wartime_reaction` 结算由 LLMBridge / DialogSystem / CombatSystem 执行。

当前 Schema：

- `backend/schemas/common.py`：共享游戏时间、请求元信息、NPC 上下文、短期记忆和行动候选。
- `backend/schemas/npc_ai.py`：对话、每日计划、计划修订、战斗判定、睡前总结、知识图谱更新、主动交涉和玩家话术分类请求/响应。

验证：

```bash
python tools/verify_backend_schemas.py
python tools/verify_mock_model_adapter.py
python tools/verify_dialogue_mock_endpoint.py
```
