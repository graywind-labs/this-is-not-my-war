# PROMPTS.md

> 本文件只记录 Prompt 设计原则与模板骨架。  
> 具体 Prompt 模板建议放在 `data/prompts/` 中。

## 总原则

- 所有关键 LLM 调用必须返回 JSON。
- Prompt 只给当前任务必要上下文。
- 不把完整 `game_design.md` 塞进 Prompt。
- LLM 输出是意向和文本，不是权威数值结算。
- 程序必须校验 LLM 输出。

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
- 当前短期记忆摘要
- 与玩家相关的知识图谱
- 当前玩家输入
- 是否点击了“提出应征”
- 玩家是否给钱/给装备/攻击过该 NPC
- 广场公开见闻摘要

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
