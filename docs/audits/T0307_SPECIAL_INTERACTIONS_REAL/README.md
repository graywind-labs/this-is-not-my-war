# T0307 四类特殊互动真实 API 验收

验收日期：2026-09-01  
Provider：DeepSeek  
Model：`deepseek-v4-flash`  
自动 Mock fallback：关闭

## 结论

- 隔离矩阵 11/11、拟真矩阵 11/11，四类 toggle 的全部合法结果都至少由真实模型返回一次：应征 `none / reject / accept`，士气 `none / escape / morale_boost`，工作 `none / escape / work_boost`，策略 `keep / change`。
- 22 个会话中 18 个首条输入命中；应征无关话题、工作无关话题和策略改变存在分类摆动，最终分别用了最多 3 / 2 / 3 条彼此独立的自然输入证明可达。没有改写模型响应、没有把 Schema 限制为单一目标值。
- `real_results.json` 保存最终 22 个 case、所有保留的尝试、原始真实响应和 usage。最终可复放矩阵保留 29 次真实调用，0 次失败、0 次 fallback，账本估算费用 ¥0.014049。
- 为探索稳定输入，本轮从 04:07:46Z 到 04:25:08Z 共进行了 169 次真实 provider attempt；append-only 成本账本合计 1,236,614 input tokens、18,532 output tokens、估算 ¥0.233279。最终矩阵只保留用于复放的 29 条，不把其费用冒充为整轮探索总费用。

## 拟真上下文

- 人设直接读取 `data/npc_profiles.json`，驿站成员、建筑、行为和资源上下文使用正式 fixture；目标状态、地点、工作行为、武器、战况、短期记忆和合法策略候选保持相互一致。
- 逃离不是辱骂关键词回声。真实模型通常只会口头拒绝不合理命令；最终可达上下文包含累计事实：战时逃离为 HP 9、疲劳 97、饱食 12、12 名敌人、同伴昏迷且轮换 / 接应 / 救治失效；工作逃离为疲劳 99、饱食 5、材料缺失和多次威胁 / 承诺未兑现。
- 发现的稳定性风险：简单资源询问偶尔被误判为 `work_boost`；明确策略切换偶尔被艾达角色判断覆盖为 `keep`；个别 `escape` 的台词只表达拒绝或条件诉求，没有同结构化字段一样明确说“离开”。这些不影响程序解析，但会影响玩家对结果的可理解性。

## Godot 权威效果与事件

`verify_t0307_real_responses_game_effects.gd` 原样读取拟真矩阵选中的 11 个真实响应，并交给正式 `DialogSystem._apply_player_message_response`：

- `accept` 立即入伍；`none / reject` 不入伍。
- 策略 `keep` 保持主动进攻，`change` 通过 CombatSystem 改为避战。
- `morale_boost` 在完成对话时写入当天 24:00 失效的攻击 / 移速各 +15% buff；`morale escape` 正式切入 `escaping_station`。
- `work_boost` 在完成对话时写入当天 24:00 失效的 1.2 工作倍率；`work escape` 正式切入 `escaping_station`。
- 每个结果在回复落地时只写一条 `dialogue_special_interaction_result`；公开对话只给同地点见闻一次。完成对话后数量不增加，`dialogue_turn` 只保留双方纯台词。

## 事件压缩审计

- T0306 五类专项继续通过：`attack_made / damage_taken / building_damaged / defense_device_triggered / horse_damaged` 只在 LLM 投影按严格键聚合，次数、累计伤害、HP 首尾 / 最低、首尾时间和终结信息保留。
- 实际特殊交互事件和公开见闻经过 `build_memory_event_projection` 后数量逐条不变，且不存在 `details.aggregation`；投影前后权威数组逐字节不变。
- `dialogue_special_interaction_result`、入伍、buff、策略变化、逃离等均非压缩白名单，并作为连续战斗聚合的叙事边界，不会被错误合并。

## 复验命令

```powershell
python tools/verify_t0307_special_interactions_real.py
python tools/verify_t0307_special_interactions_real.py --resume-passed
godot --headless --path . --script res://tools/verify_t0307_real_responses_game_effects.gd
godot --headless --path . --script res://tools/verify_t0306_memory_event_aggregation.gd
```

第一条会重新消耗真实 API；第二条只复用已通过记录并调用未通过 case。
