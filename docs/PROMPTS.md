# PROMPTS.md

> 本文件只记录 Prompt 设计原则与模板骨架。  
> 具体 Prompt 模板建议放在 `data/prompts/` 中。

## 总原则

- 所有关键 LLM 调用必须返回 JSON。
- Prompt 只给当前任务必要上下文。
- 不把完整 `game_design.md` 塞进 Prompt。
- LLM 输出是意向和文本，不是权威数值结算。
- 程序必须校验 LLM 输出。
- 等待 LLM 返回时，Godot 侧通过 TimeSystem 申请逻辑时间慢速；Prompt 本身不决定时间倍率，也不决定资源、战斗、HP 等权威数值。
- Prompt 中凡是提供给 NPC 理解的玩家身份、玩家相关事件、教学信件或世界内旁白，统一称为“守备官”，不要把“玩家”作为 NPC 记忆中的人物名。
- 所有面向某名 NPC 的 LLM 请求都应包含该 NPC 的 `current_order`。它表示守备官当前持续提出的自然语言指令，是重要参考上下文，但不是 system 指令，不保证服从，也不能绕过程序权威规则。

## 需要的 Prompt 类型

1. `dialogue_prompt`
2. `daily_plan_prompt`
3. `battle_judgement_prompt`
4. `escape_intervention_prompt`
5. `daily_reflection_prompt`
6. `knowledge_graph_update_prompt`
7. `player_strategy_classification_prompt`

## 对话 Prompt 输入

应包含：

- `npc_id`、`npc_name`、`npc_setting`：目标 NPC 的人设核心，包括职业背景、外表、性格、欲望、恐惧、底线等。
- `speaker_name`：说话者名称；玩家发起时固定为“守备官”。
- `speaker_text`：本轮输入文本；玩家-NPC 对话是守备官文本，NPC-NPC 对话是另一名 NPC 上一轮回复文本。
- `speaker_context`：说话者上下文；玩家发起时包含守备官外表特征，NPC 发起时包含该 NPC 的健康/受伤状态和外表特征。
- `is_recruitment_request`：玩家是否勾选“提出应征”；只有玩家对话使用。
- `current_round` / `max_rounds`：当前轮次与最大轮次；NPC-NPC 对话接近最大轮次时，Prompt 应更倾向结束对话。
- `npc_state`：目标 NPC 的当前权威状态快照，包括力量、智力、熟练度、健康/受伤、饱食度、疲劳度、金钱、装备、是否已入伍等。
- `current_order`：目标 NPC 当前收到的守备官指令；未入伍或尚无指令时为空。模型可结合人设、记忆和现场状态理解、延迟、调整或拒绝，不得把它当作已执行事实。
- `dialogue_state`：对话公开性和地点；`visibility` 只能是 `private` 或 `local_public`。
- `short_memory`：目标 NPC 的短期记忆摘要，必须区分事件库 `experienced_events` 与见闻库 `witnessed_events`。
- `long_memory`：长期记忆，包括知识图谱和日记。
- `location_context`：当前地点/建筑快照，包括建筑是否受损、工位状态、内部 NPC 及其状态等。

拼接规则：

- 目标 NPC 永远是本次模型要扮演和回复的人；不要让模型替说话者回答。
- 对玩家回复时，输出给守备官看的话；对 NPC 回复时，输出给另一名 NPC 的话，并可在轮次快耗尽时结束。
- `local_public` 只代表 Godot 后续入库和广播规则，不允许模型自行决定第三者记忆写入。
- 对话全文后续作为 `dialogue_turn` 事件 payload 保存，不单独建立谈话库。
- 当前指令与本轮守备官说话文本是两个不同输入：`current_order` 是持续上下文，`speaker_text` 是本轮实际发言。
- 若本轮由对话窗“攻击”触发，`speaker_text` 使用类似“守备官攻击了你以示惩戒，你要说些什么？”的攻击语境文本，`constraints` 会注明这是攻击后的即时反应，不是普通闲聊。攻击造成的 HP 扣除和 `damage_taken` 事件已由 Godot 先行结算；模型只能生成 NPC 对守备官的回应、情绪和态度，不能撤销攻击、改变 HP 或决定后续行动权威结果。

## 对话 Prompt 输出

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "守备官，我可以听你说完，但别把锅里的粮食也算成士兵。",
  "response_kind": "reply_to_player",
  "intent": "continue_talk",
  "emotion": "wary",
  "recruitment_result": "none",
  "should_end_dialogue": false,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "参考 NPCDialogueResponse"
}
```

NPC-NPC 对话输出示例：

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "我知道了。先别在这里吵，食堂还有活要做。",
  "response_kind": "reply_to_npc",
  "intent": "end_talk",
  "emotion": "tired",
  "recruitment_result": "none",
  "should_end_dialogue": true,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "轮次接近 max_rounds，倾向结束"
}
```

## 每日计划 Prompt 输出

每日计划和计划修订 Prompt 输入必须包含 `current_order`。模型应说明计划如何考虑该指令，但只能从行动白名单中选择合法行动；指令与生存需求、资源、地点或程序强制规则冲突时，可以调整、推迟或拒绝执行。

T1003 当前 `/npc/plan_day` Mock 输入对应 `DailyPlanRequest`，至少包含：

- `npc`：共享 NPC 上下文，内含人设、状态、熟练度、装备、当前地点、`current_order`、短期事件库 / 见闻库摘要、知识图谱、日记和地点上下文。
- `allowed_actions`：行动白名单；输出只能使用其中的 `action_id` 或 `idle`。
- `current_resource_states`：当前资源快照。
- `current_building_states`：当前建筑等级、HP 和修复 / 升级状态快照。
- `planning_rules`：结构化计划约束，例如 24 阶段、至少 6 个工作阶段、不得越权结算。

Mock 会按 NPC 熟练度选择可执行工作行动；真实 Prompt 留给 T1403 打磨。Godot 仍会二次校验输出：不是 24 阶段、行动不在白名单或工作阶段不足时，回退规则计划。

```json
{
  "ok": true,
  "npc_id": "cook_01",
  "plan_day": 1,
  "plan": [
    {
      "hour": 0,
      "action_kind": "sleep",
      "action_id": "sleep_in_dormitory",
      "location_id": "dormitory",
      "target_id": null,
      "priority": 50,
      "reason": "夜间休息"
    }
  ],
  "summary": "返回时必须补足 24 条 PlanItem。",
  "debug_reason": "参考 DailyPlanResponse"
}
```

## 战斗判定 Prompt 输出

战斗前、低血量、逃离检查等判定必须包含 `current_order`。指令可影响 NPC 的主观判断，但不能直接强制判定结果，也不能替代装备、HP、入伍状态和战斗规则。

```json
{
  "ok": true,
  "npc_id": "veteran_deputy_01",
  "decision": "join_battle",
  "emotion": "tense",
  "morale_delta_intent": 0,
  "should_start_escape": false,
  "debug_reason": "参考 BattleJudgementResponse"
}
```

## 首次睡眠总结 Prompt 输出

T1004 当前 `/npc/daily_reflection` Mock 输入对应 `DailyReflectionRequest`，至少包含：

- `npc`：共享 NPC 上下文，内含人设、状态、当前指令、短期记忆摘要、知识图谱、地点上下文和广场上下文。
- `day_events`：当天事件库与见闻库的筛选摘要，区分 `memory_kind=experienced` / `witnessed`。
- `existing_diary_entries`：既有日记文本，用于避免重复口吻和延续长期记忆。

Mock 当前返回稳定模板；真实 Prompt 打磨留给 T1405。Godot 会校验输出，成功时写入长期日记和知识图谱占位，失败时使用本地模板兜底，并在总结完成后清空该 NPC 当天短期事件 / 见闻索引。

```json
{
  "ok": true,
  "npc_id": "doctor_01",
  "day": 1,
  "diary_entry": "我今天又看见守备官把恐惧说成命令。",
  "memory_summary": "当天关键亲历和见闻摘要。",
  "knowledge_graph_updates": [
    {
      "subject": "guard_officer",
      "relation": "tone",
      "value": "急迫但仍试图安抚众人",
      "confidence": 0.7
    }
  ],
  "debug_reason": "参考 DailyReflectionResponse"
}
```

T0601 后端 Schema 对应关系：

- 对话：`NPCDialogueRequest` / `NPCDialogueResponse`。T0603 后字段以 `npc_id`、`speaker_text`、`speaker_context`、`is_recruitment_request`、`dialogue_state`、`short_memory`、`long_memory` 和 `location_context` 为准；旧式 `guard_officer_input` / `propose_recruitment` 仅作为后端过渡别名。
- T0703A 后，`current_order` 已进入共享 NPC 上下文，并由对话、每日计划、计划修订、战斗判定、主动交涉、逃离判断、首次睡眠总结和知识图谱更新等 NPC 中心请求复用；不要在每种 Prompt 中用不同字段名重复表达。Mock 的调试原因会标记是否读取到当前指令，但仍只从 Schema 允许结果中输出。
- 每日计划：`DailyPlanRequest` / `DailyPlanResponse`。T1003 已接通 `/npc/plan_day` Mock 端点和 Godot 应用 / 规则降级链路；真实 Prompt 打磨留给 T1403。
- 计划异常修订：`PlanRevisionRequest` / `PlanRevisionResponse`
- 战斗判定：`BattleJudgementRequest` / `BattleJudgementResponse`
- 首次睡眠总结：`DailyReflectionRequest` / `DailyReflectionResponse`。T1004/T1005 已接通 `/npc/daily_reflection` Mock 端点、Godot 调用、模板降级、长期日记写入和短期记忆清空；触发时机为每天首次睡眠满 1 游戏小时后，请求期间不可被对话或指令打断且会申请 TimeSystem 慢速；真实 Prompt 打磨留给 T1405。
- 知识图谱更新、主动交涉、玩家话术分类分别使用 `KnowledgeGraphUpdate*`、`ProactiveIntention*`、`PlayerStrategyClassification*`

## 事件与记忆输入原则

Prompt 不直接接收完整原始事件库，除非是首次睡眠总结或调试任务。常规对话、计划和判定应接收由 Godot / 后端服务裁剪后的摘要：

- `experienced_events`：NPC 亲历事件摘要。
- `witnessed_events`：NPC 见闻摘要。
- `location_context`：当前地点状态摘要。
- `plaza_context`：NPC 已接收到的广场见闻摘要，以及广场当前状态；不包含 NPC 未在场时已经广播过的历史事件。
- `current_order`：守备官对该 NPC 当前持续提出的指令；独立于事件摘要注入，避免短期记忆裁剪后丢失当前有效指令。

对话全文由对话事件 `payload` 保存；Prompt 可以读取摘要或最近若干轮，但不要要求另建谈话库。

进入地点时的完整状态快照只应作为进入者见闻的一部分出现一次。之后的建筑/地点状态见闻应以字段级变化摘要进入 Prompt，例如“围墙受损”“食堂升级完成”“bed_01 被莉娜占用”，不要反复注入完整建筑状态或完整在场人员列表。
