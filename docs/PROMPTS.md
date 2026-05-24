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

- NPC 人设核心
- 当前状态
- 当前地点
- 当前短期记忆摘要，区分 NPC 亲历事件库与见闻库
- 与玩家相关的知识图谱
- 当前玩家输入
- 是否点击了“提出应征”
- 玩家是否给钱/给装备/攻击过该 NPC
- NPC 已接收到的广场公开见闻摘要
- 当前地点状态摘要，包括人员、工位/床位占用、建筑状态和当前公告/命令；不要把地点过去事件当作自动继承输入

## 对话 Prompt 输出

```json

```

## 每日计划 Prompt 输出

```json

```

## 战斗判定 Prompt 输出

```json

```

## 睡前总结 Prompt 输出

```json

```

## 事件与记忆输入原则

Prompt 不直接接收完整原始事件库，除非是睡前总结或调试任务。常规对话、计划和判定应接收由 Godot / 后端服务裁剪后的摘要：

- `experienced_events`：NPC 亲历事件摘要。
- `witnessed_events`：NPC 见闻摘要。
- `location_context`：当前地点状态摘要。
- `plaza_public_context`：NPC 已接收到的广场公开见闻摘要，以及广场当前状态；不包含 NPC 未在场时已经广播过的历史事件。

对话全文由对话事件 `payload` 保存；Prompt 可以读取摘要或最近若干轮，但不要要求另建谈话库。
