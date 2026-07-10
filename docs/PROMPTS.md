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
- 战斗策略不由 Prompt 或 `current_order` 自动选择。当前策略由玩家在 NPC 面板手动设置，Godot 只可把它作为状态上下文提供给战时对话或后续判定；模型不得覆盖策略或直接执行策略切换。
- T1401 的真实 Model Adapter 提供通用 JSON schema guard：要求模型只返回 JSON、保持“守备官”称呼、不得越权决定资源/HP/建筑/移动/伤害，并按 call_type 返回后端 Schema 可校验字段。
- T1401A 后，通用 schema guard 会明确列出关键枚举允许值，并要求不确定时使用默认安全值，避免真实 provider 自造 `response_kind`、`intent`、`wartime_reaction` 等字段。该 guard 只保证基础 Schema 可验收，不替代具体业务 Prompt。
- T1402 后，NPC 对话 Prompt 已落到 `data/prompts/dialogue_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=dialogue` 时读取；该模板覆盖日常对话、提出应征、集结 / 战斗公开对话、避战公开对话和逃离挽留，并已完成真实 DeepSeek `/npc/dialogue` 验收。
- T1403 后，每日计划 Prompt 已落到 `data/prompts/daily_plan_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=plan_day` 时读取；该模板要求输出 0-23 点共 24 阶段、至少 6 个工作阶段、只使用 `allowed_actions` 或 `idle`，并明确 `current_order` 只是守备官当前指令参考，不能绕过行动白名单、资源、HP、地点、建筑、工位或程序强制层。后端 `/npc/plan_day` 会在 Schema 校验后额外校验 hour 唯一覆盖、行动白名单和工作阶段数量，不合法时记录 usage 失败并让 Godot 规则计划降级。
- T1404 后，低血量自身心理判定 Prompt 已落到 `data/prompts/battle_judgement_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=battle_judgement` 时读取；战时公开对话继续复用 `data/prompts/dialogue_system_prompt.txt`。`/npc/battle_judgement` 会在 Schema 校验后额外校验 `decision` 属于请求 `allowed_decisions`，并校验 `should_start_escape` 只在 `decision == "escape_station"` 时为 true；不合法时记录 usage 失败并让 Godot 规则降级。
- T1405 后，首次睡眠总结 Prompt 已落到 `data/prompts/daily_reflection_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=daily_reflection` 时读取；`/npc/daily_reflection` 会在 Schema 校验后额外校验 NPC id、日期、日记 / 摘要非空、知识图谱更新字段非空，以及世界内文本必须使用“守备官”而非“玩家”。
- Prompt 任务的验收必须分两步：先用 mock / schema 自动化测试确认字段与流程稳定，再用真实 API Key 对对应 call_type 发起真实 provider 测试。无真实 Key 时，不得把 Prompt 效果标记为完全完成。
- Mock 输出只能用于开发调试，不是 Prompt 质量验收结果。真实 provider 失败、超时、非 JSON 或 Schema 校验失败时，必须记录真实原因并返回错误或规则 / 模板降级，不能用 mock 文本伪装成功。

## 需要的 Prompt 类型

1. `dialogue_prompt`
2. `daily_plan_prompt`
3. `wartime_dialogue_prompt`
4. `low_hp_battle_judgement_prompt`
5. `escape_intervention_prompt`
6. `daily_reflection_prompt`
7. `knowledge_graph_update_prompt`
8. `player_strategy_classification_prompt`

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
- `interaction_context`：当前对话语境；日常模式为 `work`，集结 / 战斗 / 避战模式下分别为 `rally`、`combat`、`avoid_combat`；逃离挽留为 `escape_intervention`。
- `short_memory`：目标 NPC 的短期记忆摘要，必须区分事件库 `experienced_events` 与见闻库 `witnessed_events`。
- `long_memory`：长期记忆，包括知识图谱和日记。
- `location_context`：当前地点/建筑快照，包括建筑是否受损、工位状态、内部 NPC 及其状态等。
- `battlefield_context`：仅在集结 / 战斗 / 避战相关对话或低血量判定中提供；包含场上敌方 / 友方数量、兵种、HP 概况，正在参战的 NPC，仍在驿站但非战斗人员的 NPC，以及目标 NPC 当前行为模式。

拼接规则：

- 目标 NPC 永远是本次模型要扮演和回复的人；不要让模型替说话者回答。
- 对玩家回复时，输出给守备官看的话；对 NPC 回复时，输出给另一名 NPC 的话，并可在轮次快耗尽时结束。
- `local_public` 只代表 Godot 后续入库和广播规则，不允许模型自行决定第三者记忆写入。
- 对话全文后续作为 `dialogue_turn` 事件 payload 保存，不单独建立谈话库。
- 当前指令与本轮守备官说话文本是两个不同输入：`current_order` 是持续上下文，`speaker_text` 是本轮实际发言。
- 若普通对话本轮由对话窗“攻击”触发，`speaker_text` 使用类似“守备官攻击了你以示惩戒，你要说些什么？”的攻击语境文本，`constraints` 会注明这是攻击后的即时反应，不是普通闲聊。攻击造成的 HP 扣除和 `damage_taken` 事件已由 Godot 先行结算；模型只能生成 NPC 对守备官的回应、情绪和态度，不能撤销攻击、改变 HP 或决定后续行动权威结果。逃离挽留中的攻击是例外，不构造该 Prompt，也不请求 NPC 回复。
- 若目标 NPC 处于集结 / 战斗 / 避战模式，`dialogue_state.visibility` 必须固定为 `local_public`，Prompt 应明确这段话会被同地点可接收见闻的 NPC 听见；模型不得建议改成私下谈话。
- 集结 / 战斗模式的已入伍且有主武器 NPC 回复必须额外输出 `wartime_reaction`，表示守备官本轮话术造成的战时心理意向：`none`、`escape` 或 `morale_boost`。避战模式下的非战斗人员不使用该字段触发战斗心理，而是继续通过 `recruitment_result` 表达是否同意应征；若同意但仍无主武器，程序会保持避战。
- 若 `dialogue_kind == "escape_intervention"`，Prompt 必须明确目标 NPC 正在逃离驿站，本轮是守备官在其离图前的挽留 / 威胁 / 承诺。请求会携带 `escape_intervention_round`（1 到 5）、`escape_intent`、当前轮次、短期记忆、长期记忆、地点上下文和 `current_order`。模型只能在 `intent` 中输出 `stay_after_intervention` 或 `leave_after_intervention`，不能输出“留下但退出入伍”等旧分支，也不能直接改变移动、HP、资源或建筑结果。逃离挽留对话中的攻击按钮不发送到模型。

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
  "wartime_reaction": "none",
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

T1003 当前 `/npc/plan_day` 开发期 Mock 输入对应 `DailyPlanRequest`，至少包含：

- `npc`：共享 NPC 上下文，内含人设、状态、熟练度、装备、当前地点、`current_order`、短期事件库 / 见闻库摘要、知识图谱、日记和地点上下文。
- `allowed_actions`：行动白名单；输出只能使用其中的 `action_id` 或 `idle`。
- `current_resource_states`：当前资源快照。
- `current_building_states`：当前建筑等级、HP 和修复 / 升级状态快照。
- `planning_rules`：结构化计划约束，例如 24 阶段、至少 6 个工作阶段、不得越权结算。

开发期 Mock 会按 NPC 熟练度选择可执行工作行动；T1403 后真实 provider 路径读取 `data/prompts/daily_plan_system_prompt.txt`，要求计划覆盖 24 小时、至少 6 个工作阶段、只使用行动白名单，并说明如何参考 `current_order`。后端会校验 24 个 hour 是否覆盖 0-23、`action_id` 是否来自 `allowed_actions` / `idle`、工作阶段是否不少于 6；Godot 仍会二次校验输出，不合法时记录模型失败并回退规则计划。生产 / 演示路径不得把 mock 计划当成真实模型成功。

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

## 战时对话 Prompt 输出

集结 / 战斗模式下，守备官对已入伍且有主武器 NPC 的主动对话输出沿用 `NPCDialogueResponse`，但必须额外带上战时心理意向。`morale_boost` 和 `escape` 只是意向；斗志 buff、逃离移动、事件入库和数值变化由 Godot 程序校验后执行。

```json
{
  "ok": true,
  "replyer_id": "veteran_deputy_01",
  "reply_text": "守备官，说得够明白了。我会把他们拦在门外。",
  "response_kind": "reply_to_player",
  "intent": "continue_talk",
  "emotion": "resolved",
  "recruitment_result": "none",
  "wartime_reaction": "morale_boost",
  "should_end_dialogue": false,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "集结模式公开对话，参考 battlefield_context 与 current_order"
}
```

避战模式下，非战斗人员仍使用 `recruitment_result` 表达是否接受应征。若返回 `accept` 但仍无主武器，Godot 保持其 `avoid_combat`；若无敌军，则回到工作模式并成为已入伍 NPC；只有已入伍且获得主武器、场上仍有敌军时，Godot 才将其切入战斗模式。

## 逃离挽留 Prompt 输出

逃离挽留复用 `NPCDialogueResponse`，但 `dialogue_kind` 必须为 `escape_intervention`，`interaction_context` 必须为 `escape_intervention`，`escape_intervention_round` 必须在 1 到 5 之间。模型必须输出：

- `intent = "stay_after_intervention"`：NPC 被守备官本轮话术挽留下来。Godot 会停止逃离、切回工作模式、触发计划重评估并写入 `escape_intervention_result`。
- `intent = "leave_after_intervention"`：NPC 继续逃离。Godot 会记录已用轮次，未满 5 轮时允许玩家再次挽留，满 5 轮后拒绝第 6 轮。

给钱和攻击不是模型结算：给钱已经由 Godot 扣资源并降低逃离移动倍率；逃离挽留中的攻击已经由 Godot 扣 HP、提高逃离移动倍率、计入 1 轮并关闭对话面板，不会请求模型回复。若攻击导致昏迷，复苏后程序会继续逃离。

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "守备官，我留下。但你得记住你答应过什么。",
  "response_kind": "reply_to_player",
  "intent": "stay_after_intervention",
  "emotion": "shaken",
  "recruitment_result": "none",
  "wartime_reaction": "none",
  "should_end_dialogue": true,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "逃离挽留第 2 轮，守备官承诺补偿并承担后果"
}
```

## 低血量自身心理判定 Prompt 输出

取消旧式“战斗触发时全员判定”。独立低血量判定覆盖战时所有未昏迷、未逃离 NPC：当 HP 首次从不低于 30% 跌破 30% 且仍大于 0 时触发。请求没有守备官本轮发言，必须包含 `current_order`、短期事件 / 见闻、长期记忆、地点上下文和 `battlefield_context`。指令可影响 NPC 的主观判断，但不能直接强制判定结果，也不能替代装备、HP、入伍状态和战斗规则。

允许输出由 Godot 按目标状态提供：已入伍且有主武器、实际处于 `combat` 模式的 NPC 可选择继续参战、逃离或斗志激昂；避战 / 非战斗人员只能选择逃离，或继续避战（无事发生）。T1404 后后端会先拒绝越界 `decision` 和逃离布尔不一致结果并记录 `model_output_invalid`；若仍有非法结果进入 Godot，Godot 必须降级为该 NPC 允许的结果。

```json
{
  "ok": true,
  "npc_id": "veteran_deputy_01",
  "decision": "continue_fighting",
  "emotion": "tense",
  "morale_delta_intent": 0,
  "should_start_escape": false,
  "debug_reason": "参考 BattleJudgementResponse"
}
```

T1404 当前状态：真实 provider 路径读取 `data/prompts/battle_judgement_system_prompt.txt`。Prompt 要求模型引用 NPC 亲历事件、公开见闻、`battlefield_context` 和 `current_order`，但只能从请求 `allowed_decisions` 中选择；`current_order` 只是守备官当前指令参考，不能强制参战或强制逃离。真实 DeepSeek 已完成战时 `/npc/dialogue` 与 `/npc/battle_judgement` smoke 验证，`fallback_used=false`。

## 首次睡眠总结 Prompt 输出

T1004 当前 `/npc/daily_reflection` 开发期 Mock 输入对应 `DailyReflectionRequest`，至少包含：

- `npc`：共享 NPC 上下文，内含人设、状态、当前指令、短期记忆摘要、知识图谱、地点上下文和广场上下文。
- `day_events`：当天事件库与见闻库的筛选摘要，区分 `memory_kind=experienced` / `witnessed`。
- `existing_diary_entries`：既有日记文本，用于避免重复口吻和延续长期记忆。

开发期 Mock 当前返回稳定模板；T1405 后真实 provider 路径读取 `data/prompts/daily_reflection_system_prompt.txt`，并已完成 fake real-provider 验证和真实 DeepSeek smoke 验证。Godot 会校验输出，成功时把 `diary_entry` 追加进长期日记，并把 `knowledge_graph_updates` 按替换式键值更新写入 `knowledge_graph.by_subject[subject][relation]`；失败时使用本地模板兜底，并在总结完成后清空该 NPC 当天短期事件 / 见闻索引。模板兜底必须标明来源并保留模型失败日志，不能把 mock 日记当成真实模型成功。

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
- T0703A 后，`current_order` 已进入共享 NPC 上下文，并由对话、每日计划、计划修订、战时公开对话、低血量自身心理判定、主动交涉、逃离判断、首次睡眠总结和知识图谱更新等 NPC 中心请求复用；不要在每种 Prompt 中用不同字段名重复表达。Mock 的调试原因会标记是否读取到当前指令，但仍只从 Schema 允许结果中输出。
- 每日计划：`DailyPlanRequest` / `DailyPlanResponse`。T1003 已接通 `/npc/plan_day` 开发期 Mock 端点和 Godot 应用 / 规则降级链路；T1403 已完成真实 Prompt 和真实 API 验收。
- 计划异常修订：`PlanRevisionRequest` / `PlanRevisionResponse`
- 战时公开对话：T1201 已接入，仍使用 `NPCDialogueRequest` / `NPCDialogueResponse`，并携带 `interaction_context`、`battlefield_context` 和 `wartime_reaction`；T1404 已完成真实战时公开对话 smoke 验收。
- 低血量自身心理判定：`BattleJudgementRequest` / `BattleJudgementResponse`，用于战时所有 NPC HP 首次低于 30% 的自身判断；参战 NPC 可继续战斗、逃离或斗志激昂，避战 / 非战斗人员只能逃离或继续避战；T1404 已完成真实 Prompt、后端业务校验和真实 API 验收。
- 首次睡眠总结：`DailyReflectionRequest` / `DailyReflectionResponse`。T1004/T1005 已接通 `/npc/daily_reflection` 开发期 Mock 端点、Godot 调用、模板降级、长期日记写入和短期记忆清空；触发时机为每天首次睡眠满 1 游戏小时后，请求期间不可被对话或指令打断且会申请 TimeSystem 慢速。T1405 已接入真实 Prompt 和真实 API 验收；`knowledge_graph_updates` 是替换式当前知识键值，`diary_entry` 是增量第一人称日记。
- 知识图谱更新、主动交涉、玩家话术分类分别使用 `KnowledgeGraphUpdate*`、`ProactiveIntention*`、`PlayerStrategyClassification*`

## 事件与记忆输入原则

Prompt 不直接接收完整原始事件库，除非是首次睡眠总结或调试任务。常规对话、计划和判定应接收由 Godot / 后端服务裁剪后的摘要：

- `experienced_events`：NPC 亲历事件摘要。
- `witnessed_events`：NPC 见闻摘要。
- `location_context`：当前地点状态摘要。
- `battlefield_context`：战时局势摘要，只在集结 / 战斗 / 避战对话和低血量自身心理判定中注入。
- `plaza_context`：NPC 已接收到的广场见闻摘要，以及广场当前状态；不包含 NPC 未在场时已经广播过的历史事件。
- `current_order`：守备官对该 NPC 当前持续提出的指令；独立于事件摘要注入，避免短期记忆裁剪后丢失当前有效指令。

对话全文由对话事件 `payload` 保存；Prompt 可以读取摘要或最近若干轮，但不要要求另建谈话库。

进入地点时的完整状态快照只应作为进入者见闻的一部分出现一次。之后的建筑/地点状态见闻应以字段级变化摘要进入 Prompt，例如“围墙受损”“食堂升级完成”“bed_01 被莉娜占用”，不要反复注入完整建筑状态或完整在场人员列表。
