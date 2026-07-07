# COMBAT_SYSTEM.md

## 战斗目标

战斗系统用于制造外部压力。  
它不是项目的唯一核心，真正的核心是战前动员、战中崩溃、战后记忆反噬。

战斗数值不再绑定玩家时间倍率。伤害、攻击间隔、攻击速度和战斗移动速度按配置、属性、熟练度、装备、防御和战斗状态计算；玩家选择 `x2` / `x4` 不会让战斗数值同步加快。战斗仍由 TimeSystem 的逻辑 tick 推进，暂停会停止推进，LLM 等待可通过全局慢速让战斗暂时变慢，但 CombatSystem 不读取玩家倍率作为额外伤害、攻速或移速输入。

当场景中存在任意活动敌人时，CombatSystem 会向 TimeSystem 注册 `combat_enemy_presence` 时间流速上限，把有效倍率上限设为 `x1`。如果敌人出现前玩家速度高于 `x1`，实际有效倍率压到 `x1`，玩家选择值保留；如果已有 LLM 慢速，实际倍率继续使用更慢者。所有敌人消失后释放该上限，恢复正常时间逻辑。

## 行为模式

T1103A 起，战斗相关运行时以 NPC 行为模式为主线，而不是“战斗触发时全员心理判定”。当前已保存并展示 `states.behavior_mode`，同时保留 T1103 的 `combat_mode` 兼容字段用于旧集结视觉。运行时至少区分：

| 模式 | 适用范围 | 行为 | 进入条件 | 退出 / 切换 |
|---|---|---|---|---|
| 工作模式 / 日常模式 | 所有未昏迷、未逃离 NPC | 按计划行动、处理异常、被对话打断、计划重评估 | 默认模式；其他模式结束后返回 | 警铃、接敌、非战斗人员遇敌、昏迷、逃离等高优先级事件打断 |
| 集结模式 | 已入伍、有主武器、当前可行动 NPC | 前往城门外防线并等待接敌 | 守备官摇响警铃 | 集结途中或集合点敌人进入一定范围后进入战斗模式；到达集合点等待 1 游戏小时仍未接敌，返回工作模式且不重评估计划 |
| 战斗模式 | 已入伍且有主武器的可战斗 NPC | 按兵种和战斗策略自动战斗 | 从集结模式接敌；或工作模式中敌人进入一定范围；正在睡觉的持武器入伍 NPC 只有被敌人攻击才进入 | 场上敌人全部消失后返回工作模式并重评估计划；HP 清零进入昏迷 |
| 避战模式 | 非战斗人员：未入伍 NPC，或已入伍但无主武器 NPC | 按敌人接近方位逐步远离，尝试离开接敌范围，不攻击敌人 | 非战斗人员附近出现敌人；正在睡觉的非战斗人员只有被敌人攻击才进入 | 场上敌人全部消失后返回工作模式；避战中应征但仍无主武器时继续避战，装备主武器且仍有敌人时进入战斗模式 |
| 逃离驿站 | 逃离意向已被程序应用、尚未离图的 NPC | 朝后门外出口移动；可被玩家进行最多 5 轮挽留 | 战时对话、低血量判定、逃离挽留失败或 GM 调试触发 | 到达出口后标记 `escaped=true`；挽留结果为留下时返回工作模式并重评估计划；昏迷后暂停，复苏继续逃离 |

避战模式是非战斗人员的同级行为模式，不等于已入伍且有主武器 NPC 在战斗模式中可选的“避战策略”。后者仍属于战斗模式。

任一高优先级模式触发时，如果该 NPC 正在对话，系统必须强制结束对话、关闭对话框并取消可取消 LLM 请求；未完成回复不写入对话事件。如果 NPC 正在做普通计划行动、移动、工作、吃饭、训练、治疗或计划 LLM 活动，系统应中断并进入新模式。睡觉 NPC 通常不因附近敌人直接切换模式，只有被敌人攻击时才按入伍状态和主武器进入战斗或避战。

T1103A 已实现模式切换的权威边界：进入集结 / 战斗 / 避战时会中断普通行动、移动、可取消 LLM 与当前对话；需要留痕的模式变化会写入 `npc_mode_changed`。T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 的互转不再写入 `npc_mode_changed`，也不通过该事件广播；避战开始 / 结束、攻击、受伤、警铃、集结、昏迷和复苏仍由具体事件记录。昏迷 NPC 复苏后按场上敌军、入伍状态和主武器分流：仍有敌军时，已入伍且有主武器者进入战斗模式，未入伍或无主武器者进入避战模式；没有敌军时返回工作模式并重新评估计划。T1103B/T1103C 已实现非战斗人员的避战移动、清敌退出、避战中应征 / 装备分流，以及 `avoidance_started` / `avoidance_ended` 事件。

## 战斗触发

触发入口：

1. 守备官手动摇响警铃，符合条件的已入伍持武器 NPC 进入集结模式。
2. 已入伍且有主武器 NPC 在工作模式或集结模式中接敌，进入战斗模式。
3. 未入伍 NPC、已入伍但无主武器 NPC 在工作模式中遇敌，进入避战模式。
4. 睡觉中的 NPC 只有被敌人攻击时才从睡觉进入战斗 / 避战。

T1103/T1103A/T1103B/T1103C 已完成玩家手动摇响警铃后的集结、模式切换和非战斗人员避战闭环：HUD `AlarmButton` 和 GM `alarm` / `rally` 都调用 `CombatSystem.trigger_combat_alarm(...)`。警铃会给所有 NPC 写入 `combat_alarm_rang` 结构化事件；随后只有已入伍、已装备主武器、当前可行动且非睡觉的 NPC 响应集结并进入 `behavior_mode == "rally"`。响应者的普通日常行动会通过 `NPCSystem.set_npc_behavior_mode(...)` 的中断边界打断并释放工位，再移动到城门外防线。阵型按近战步兵 / 长杆步兵 / 近战骑兵前排，弓箭兵 / 弩兵 / 骑射单位后排排列，方向标记面向正门外敌人来袭方向。已装备坐骑的 NPC 只在 `behavior_mode == "rally"` 或 `"combat"` 时显示低模坐骑；日常工作模式不显示骑乘。若集结途中或集合点附近遭遇敌人，只有已入伍且有主武器 NPC 会停止集结并进入 `behavior_mode == "combat"` 与 `combat_ready` 占位状态，写入 `combat_rally_encountered_enemy` 和必要的 `npc_mode_changed`。未入伍或已入伍但无主武器 NPC 在工作模式中接敌会进入 `behavior_mode == "avoid_combat"`，按最近敌人方位生成短距离散射移动目标，不设置战斗 `combat_mode`，也不攻击敌人；睡觉中的非战斗人员只有被敌人攻击才进入避战。集结到点后等待 1 游戏小时仍未接敌会返回 `work` 且不触发计划重评估；场上敌人清空时，`combat` NPC 返回 `work` 并触发计划重评估，`avoid_combat` NPC 返回 `work` 且不触发计划重评估。T1103D 起，工作 / 战斗和工作 / 避战互转不再写 `npc_mode_changed`，具体战斗和避战事实由 `attack_made`、`damage_taken`、`avoidance_started`、`avoidance_ended` 等事件表达。T1104 后，`combat` 模式中的入伍持主武器 NPC 已能执行基础自动攻击、扣除敌人 HP 并在敌人 HP 清零后移除敌人。T1105 后，战斗模式会按 NPC 当前手动选择的兵种策略决定基础攻击前的战术移动与攻击节奏。T1106 后，波次生成和敌军清空会分别写入广场 `combat_started` / `combat_ended`，并维护本场受伤、昏迷和击退统计；T1201 后，战时公开对话可应用斗志 buff 或触发逃离；T1202 后，战时低血量自身心理判定已接入；T1203 后，逃离会移动到后门外出口并在离图后标记 `escaped`；T1204A 后，逃离过程中可通过 NPC 面板进行最多 5 轮挽留，打开对话暂停逃离移动，未满 5 轮关闭恢复，给钱减速，逃离攻击加速且不请求 NPC 回复，并在昏迷复苏后继续逃离；T1302 后，主厅被摧毁会进入失败占位结算并停止正常推进；T1303 后，活动敌人在场且所有已入伍持主武器战斗人员均昏迷、已逃离或正在逃离时，会进入无可战斗人员失败；T1304 后，包含第 5 波的战斗清敌会进入 Demo 胜利占位结算并停止继续刷波。NPC 结局总结和命中 / 格挡仍留给后续任务。

## 兵种判定

兵种由装备和坐骑决定：

| 装备组合 | 实际兵种 |
|---|---|
| 剑盾 | 近战步兵 |
| 长杆武器 | 长杆步兵 |
| 弓 | 弓箭兵 |
| 弩 | 弩兵 |
| 近战武器 + 马 | 近战骑兵 |
| 远程武器 + 马 | 骑射单位 |
| 无武器 | 非战斗人员 / 避战单位 |

T0804 后，铁匠铺已经能把铁加工为 `weapons` / `armor` 两类派生库存。T0805 后，工械坊会把木材加工为 `weapons` / `defense_devices`；T0806 后，马厩会把粮食维护转化为 `horse_readiness` 马匹整备库存。T0901 后，`EquipmentSystem` 已能把 `weapons` 转换为剑盾、长杆、弓或弩主武器，把 `armor` 转换为头盔、胸甲、腕甲或腿甲，把 `horse_readiness` 转换为坐骑槽。T0902 后，兵种判定已独立验收，并提供 `get_unit_type_snapshot(...)` 供 GM 与后续战斗系统读取；坐骑来源只看 NPC 的 `equipment.mount` 槽，不能直接读取 `horse_readiness` 库存当作已骑乘。T1103 已接入集结 / 接敌时的低模坐骑表现，日常工作仍不骑马；T1104 后，CombatSystem 会读取主武器 `damage` / `range` / `attack_interval`、盔甲 `armor_value` 和坐骑槽来计算基础攻击、防御和部分攻击速度修正。EquipmentSystem 本身仍不结算攻击、防御、耐久或策略行为；工程器械部署仍由 T1508 接入。

T0903 后，训练场可以提升后续战斗会读取的武器熟练度和骑术。训练项目由 NPC 当前装备决定：主武器对应剑盾、长杆、弓或弩，坐骑对应骑术；教官带受训者时，受训者按自己的装备成长，教官提升“教练”。训练只改变 NPC 熟练度和基础状态消耗，不直接结算攻击、命中、伤害、防御、骑乘表现或当前战斗策略选择。

## 战时对话与心理结果

取消旧规则：战斗触发时不再全员进行一次心理判定。

T1201 已实现：已入伍且有主武器 NPC 在集结模式和战斗模式下可被守备官主动对话。该对话会：

- 强制 `local_public`，UI 中“同地点公开”默认开启且不可关闭。
- 在 Prompt 中明确当前模式是集结或战斗，并注入相关集结 / 战斗事件。
- 继承 T0603 对话上下文：NPC 设定、状态、短期事件库 / 见闻库、长期记忆、地点上下文、对话轮次和当前 `current_order`。
- 额外加入战局上下文：敌方 / 友方数量、兵种、HP 概况，正在参战的 NPC 列表，仍在驿站但非战斗人员的 NPC 列表。
- 在回复结构中额外输出战时心理意向，例如 `wartime_reaction = none | escape | morale_boost`。

`morale_boost` 由 CombatSystem 应用为斗志激昂 buff，持续 2 游戏小时，当前提高攻击力和 NPC 实体移动速度。开始和结束分别写入 `morale_boost_started` / `morale_boost_ended`；每次战时心理结果写入 `battle_psychology_result` 并进入广场公开事件。`escape` 由 T1203 的 `start_npc_escape(...)` 执行：写入 `escape_started`，让 NPC 前往后门外出口，并在离开地图后写入 `escaped`。T1204A 后，逃离挽留回复只解析 `stay_after_intervention` / `leave_after_intervention`；停止逃离、继续逃离、对话暂停 / 恢复、移动倍率、昏迷暂停和复苏续逃都由程序结算。LLM 不直接改 HP、速度、攻击力或逃离位置。

非战斗人员在避战模式下也可被守备官主动对话。该对话同样强制 `local_public`，Prompt 明确其正在躲避敌人袭击，并注入战局上下文。守备官仍可勾选“提出应征”，征召结果沿用日常对话逻辑；若避战中的 NPC 同意应征但仍无主武器，继续避战；只有已入伍且装备主武器并且场上仍有敌人时，程序才将其切入战斗模式。后端不可用时，战时对话会使用规则 fallback 生成回复、应征结果和 `wartime_reaction`。

## 低血量判定

T1202 已实现：当前战斗 / 敌人在场期间，当任一未昏迷、未逃离 NPC 的 HP 首次从不低于 30% 跌破 30%，且仍大于 0 时，触发自身心理判定。该判定不只覆盖 `combat` 模式中的已入伍持武器 NPC；`avoid_combat` 中的非战斗人员被敌人追上并打到残血时也会触发。

参战 NPC 的可能结果：

- 继续参战
- 逃离驿站
- 斗志激昂

不参战 / 避战 NPC 的可能结果：

- 逃离驿站
- 留在驿站继续避战（无事发生）

该请求由 `LLMBridge.request_npc_battle_judgement(...)` 调用 `/npc/battle_judgement`，没有守备官本轮发言，只根据 NPC 自身上下文、当前 `current_order`、亲历 / 见闻、低血量事实和战局上下文判断。每名 NPC 每波或每场战斗最多触发一次；后端失败或输出越界时，Godot 按允许结果规则降级。

已入伍且有主武器、实际处于 `combat` 模式的 NPC 可以因判定获得斗志激昂或继续参战。未入伍 NPC、已入伍但无主武器 NPC、以及处于 `avoid_combat` 的非战斗人员，不会获得斗志激昂，也不会因此切入或继续战斗；他们只能触发逃离驿站意向，或继续留在驿站内避战。

低血量与逃离相关判定也必须继续携带最新 `current_order`，让 NPC 在受伤或恐惧时重新解释守备官要求，而不是把发布指令时的旧判断当成永久结果。已昏迷、已逃离、HP 已经低于 30% 后再次受击，或 HP 直接清零进入昏迷的 NPC 不触发该判定。

判定等待期间，守备官不能与该 NPC 对话。如果触发时守备官正与该 NPC 对话，当前对话被强制结束并取消未完成 LLM 请求，随后进入自身心理判定。该判定需要申请 TimeSystem 慢速，请求完成、失败或规则降级后释放。触发事实写入 `low_hp_triggered`，判定结果写入 `battle_psychology_result`，并通过 `debug_get_combat_snapshot().last_low_hp_judgement_result` 与 `active_battle.low_hp_judgements` 暴露给 GM / 自动化验证。

## 昏迷机制

NPC 不死亡。  
HP 清零后在原地倒下并进入昏迷。

规则：

- 昏迷 NPC 不能移动、工作、战斗、对话或执行计划。
- 昏迷 NPC 不接收地点/广场公开广播或状态见闻，见闻库暂停更新。
- 昏迷 NPC 会极慢自然恢复 HP。
- 其他NPC可治疗昏迷 NPC，使其更快恢复。
- HP 恢复到 30% 后复苏。
- 复苏后按场上敌军、入伍状态和主武器进入战斗、避战或工作模式。
- 若场上无敌军，复苏后重新评估计划；若仍有敌军，按模式切换进入战斗或避战，不再使用旧式战斗前全员判定。

当前 T0501/T0502/T0502A/T0503 已实现 HP 扣除、昏迷状态、自然恢复、协助治疗、自动复苏和昏迷见闻暂停的最小闭环：`NPCSystem.apply_damage_to_npc(...)` 是权威扣血入口，GM `attack_npc` / `damage_npc` 可触发调试扣血；HP 到 0 后 NPC 设置为昏迷、停止移动并阻断行动。系统会写入 `damage_taken` 和 `unconscious_started` 结构化事件，昏迷事件按当前信息地点 `local_public` 广播给同地点 NPC。昏迷 NPC 会随 `TimeSystem.logical_time_tick` 以每游戏小时 2 HP 的速度自然恢复；其他可行动 NPC 可协助治疗，治疗按医术熟练度增加恢复速度并按逻辑时间消耗第纳尔，每个昏迷目标最多 2 名治疗者。HP 达到 Max HP 的 30% 后自动复苏、回到 `idle`、重新允许行动，并写入 `revived` 本地公开事件。昏迷期间 NPC 不接收见闻广播，复苏后恢复接收。T1104 后，敌人攻击 NPC 会先按 NPC 盔甲防御计算实际伤害，再复用同一扣血 / 昏迷入口；`damage_taken` payload 会保留原始攻击力、防御值和防御后伤害。

## 战斗策略

T1105 后，某名 NPC 可用哪些策略只由当前主武器和坐骑判定出的兵种决定。玩家在已入伍且有主武器 NPC 的面板中，通过“装备武器”旁的策略下拉框手动选择当前策略；默认是该兵种列表中的第一种进攻 / 输出策略。更换主武器或坐骑后，CombatSystem 会把策略重置为新兵种默认策略；更换盔甲不会重置策略。`current_order` 可作为 NPC 理解守备官意图的 LLM 上下文，但不再自动决定、覆盖或推断当前战斗策略。

### 剑盾/长杆步兵

- 主动进攻
- 避战

### 弓/弩步兵

- 最大化输出
- 保持距离射击
- 避战

### 近战骑兵

- 主动进攻
- 拉开距离冲击
- 避战

### 骑马远程

- 最大化输出
- 保持距离射击
- 避战

这里的“避战”是已入伍且有主武器 NPC 在战斗模式中的战术策略，不是非战斗人员的同级避战模式。

当前策略语义：

- 主动进攻：近战步兵 / 长杆步兵 / 近战骑兵主动接近敌人，进入武器射程后攻击。
- 最大化输出：远程兵种站桩射击，不为了保持距离主动移动。
- 保持距离射击：远程兵种在敌人太近时短距离后撤，目标点仍尽量保持在自身攻击射程内；敌人过远时会接近到可射击范围，拉开一小段距离后继续射击。
- 拉开距离冲击：近战骑兵在过近或冲击冷却时拉开距离，随后重新接近并攻击，用于形成冲击循环占位。
- 避战：入伍持武器 NPC 的战斗策略，复用非战斗人员短步长避战目标算法，但保持 `behavior_mode == "combat"`；该策略只在最近敌人低于避战安全阈值时按敌人来袭方向短距离远离，敌人已经远离到阈值外时保持 `combat_ready` 等待，不继续退向驿站边界或角落；该策略不主动攻击，清敌后按战斗模式退出规则回到工作模式。

## 非战斗人员避战模式

未入伍 NPC、以及已入伍但没有主武器的 NPC 都属于非战斗人员，不进入集结和战斗模式。敌人进入一定范围后进入避战模式，按最近敌人的接近方位生成短距离远离目标，并用 NPC / 敌人组合生成稳定散射角，让不同 NPC 向不同方向四散移动。避战会尝试逐步退到接敌范围之外，但不会一步挪到驿站角落，也不会离开驿站太远。只有当场上没有敌军后，避战 NPC 才退出避战回到工作模式。

T1103B/T1103C 当前实现：`CombatSystem` 在敌人接触扫描中检测工作模式非战斗人员，调用 `NPCSystem.set_npc_behavior_mode(..., "avoid_combat")` 并通过 `move_npc_to_world_position(...)` 移动到按敌方方位计算出的短步长目标。避战快照保存在 `active_avoidances`，包含敌人、距离、目标点、移动步长、目标点敌距、原因和最近结果。敌军清空时避战 NPC 回到 `work` 且不触发计划重评估。若避战中的 NPC 被征召成功但仍没有主武器，继续避战；若随后装备主武器且仍有敌军，切入 `combat`；若无敌军则回到 `work`。T1103D 起，`work -> avoid_combat` 和 `avoid_combat -> work` 的模式切换本身不写事件，避战信息只由 `avoidance_started` / `avoidance_ended` 记录。

避战模式不得被实现为逃离驿站。逃离驿站是独立行为，需要明确的 LLM / 对话 / 调试结果触发，并会让 NPC 前往后门或小门离开地图。

## 逃离驿站行为

T1203/T1204A 已实现逃离闭环。`CombatSystem.start_npc_escape(...)` 是权威入口，战时公开对话 `wartime_reaction == "escape"`、低血量判定 `decision == "escape_station"` 或 GM `escape_npc <npc_id>` 都走同一接口。逃离开始时写入广场公开 `escape_started`，NPC 切到 `behavior_mode == "escaped"` 但 `states.escaped` 仍为 `false`，并以 `escape_intent.status == "escaping"` 前往后门外出口；这段期间普通行动和战斗 AI 不再把该 NPC 当作可用单位。逃离中的 NPC 被点击会打开 NPC 面板；若挽留轮次未用完，NPC 面板【对话】按钮调用 `DialogSystem.start_escape_intervention_dialogue(...)`，该对话强制 `local_public`、最多 5 轮、隐藏应征入口，并通过 `/npc/dialogue` 的 `dialogue_kind == "escape_intervention"` 请求结构化 stay/leave 意图。进入挽留时 `CombatSystem.pause_escape_for_dialogue(...)` 暂停移动，关闭、攻击或满 5 轮后由 `resume_escape_after_dialogue(...)` 恢复前往后门。

NPC 抵达后门外出口后，`NPCSystem` 将其标记为 `escaped=true`、`current_action="escaped"`、`current_location="outside_station"`，隐藏并取消拾取 NPC 实体，写入广场公开 `escaped` 事件，并从 `CombatSystem.active_escapes` 中移除。若挽留结果为 `stay_after_intervention`，CombatSystem 会停止移动，把 `escape_intent.status` 设为 `stayed`，切回 `work` 并触发计划重评估；若结果为 `leave_after_intervention`，NPC 继续逃离，直至 5 轮上限，随后 NPC 面板【对话】置灰。未满 5 轮时玩家可关闭面板，NPC 立即继续逃离，之后仍可再次打开并再次暂停。逃离中给钱会降低 `escape_intent.speed_multiplier`；逃离挽留中的守备官攻击会提高该倍率、计为 1 轮并立即关闭面板，但不请求 NPC LLM 回复、不写攻击回复对话事件，也不写 `escape_intervention_result`。速度变化写入 `escape_speed_changed`，只有真正的挽留消息回复结果才写入 `escape_intervention_result`。如果逃离中 NPC 昏迷，`escape_intent.status` 暂停为 `paused_unconscious`，复苏后会再次移动到后门外出口。`debug_get_combat_snapshot()` 暴露 `active_escapes`、剩余挽留轮次、速度倍率与 `last_escape_result`。

## 基础攻击与伤害（T1104 / T1104A / T1104B / T1105）

T1104 已实现最小自动战斗，T1105 已接入不同兵种的玩家手动策略选择和对应战术移动，但仍不包含命中率、格挡、士气修正、完整动画或正式战斗结算。`CombatSystem` 在 `TimeSystem.logical_time_tick(game_delta_seconds, numeric_multiplier)` 推进中先处理我方策略与基础攻击，再处理敌方 AI；GM `step_enemies [game_seconds]` 使用同一套逻辑。T1104A 后，玩家时间倍率不再直接影响伤害、攻击间隔、攻击速度或战斗移动速度；敌人在场时 TimeSystem 会把有效倍率上限压到 `x1`，LLM 慢速仍可进一步降低有效推进速度。CombatSystem 不读取真实帧率或 Godot 全局时间缩放。

T1104B 后，战斗攻击冷却使用“战斗动作秒”作为基准：`60` 游戏秒折算为 `1` 战斗动作秒。默认 `x1` 下现实 1 秒仍推进游戏内 1 分钟，但不会让 `attack_interval = 1.5` 的单位在现实 1 秒内攻击几十次；GM `step_enemies 60` 约等于推进 1 秒战斗动作，`step_enemies 600` 约等于推进 10 秒战斗动作。该换算只用于战斗攻击 / 移动表现层，经营生产、治疗、建筑倒计时仍按 TimeSystem 的游戏秒结算。

我方攻击条件：

- NPC 必须已入伍、有主武器、可行动，并处于 `behavior_mode == "combat"`。
- `behavior_mode == "avoid_combat"` 的 NPC 不攻击敌人，即使已经入伍或持有武器。
- 攻击目标当前选择最近的活动敌人，优先沿用 `states.combat_target_enemy_id`；不同策略会决定是否先接近、后撤、拉开冲击距离或直接站桩攻击。

数值口径：

- NPC 基础攻击力 = 主武器 `damage` × 力量修正。力量 5 作为基线，每高 / 低 1 点约修正 8%，当前倍率限制在 0.65 到 1.45。
- NPC 攻击间隔 = 主武器 `attack_interval` / 攻击速度倍率。`attack_interval` 的单位是战斗动作秒，不是 TimeSystem 游戏秒。攻击速度倍率读取对应武器熟练度，疲劳超过 60 产生惩罚，饱食低于 35 产生惩罚；已装备坐骑时，骑术会提供小额攻击速度加成。当前最短攻击间隔为 0.25 战斗动作秒。玩家 `x2` / `x4` 不参与该倍率。
- NPC 防御 = 头盔、胸甲、腕甲、腿甲四个装备槽 `armor_value` 之和。
- 敌人防御 = `data/enemy_waves.json` 中该敌人的 `defense`。
- 实际 HP 伤害 = 原始攻击力 × (1 - 防御减伤)，四舍五入且至少 1 点。防御每点当前减少 4% 伤害，最大减伤 70%。

敌人 HP 清零后从 `_active_enemies` 和 `Station/Enemies` 场景节点中移除；若场上敌人全部消失，沿用 T1103A/T1103B/T1106 的清敌退出规则：`combat` NPC 回到 `work` 并请求计划重评估，`avoid_combat` NPC 回到 `work` 且不因单纯避战结束重评估，未接敌的 `rally` NPC 回到 `work` 且不重评估计划。

我方攻击会写入 `attack_made` 结构化事件，payload 包含攻击者、目标敌人、武器、力量 / 熟练度输入、原始攻击力、防御、实际伤害、敌人 HP 前后值和是否击退敌人。敌人攻击 NPC 时会先计算 NPC 盔甲防御，再调用 `NPCSystem.apply_damage_to_npc(...)`；敌人攻击建筑仍直接以配置 `attack_power` 调用 `BuildingSystem.apply_damage_to_building(...)`，不在 CombatSystem 中自行改写建筑 HP。

## 战斗开始 / 结束流程（T1106）

T1106 已实现战斗开始和结束的最小闭环。`spawn_wave(...)` 成功生成敌人后会创建当前战斗运行态，并在广场写入 `combat_started` 公开事件；payload 包含波次、敌军数量、敌军 roster、我方已入伍且持主武器 NPC 的姓名 / 兵种，以及非战斗人员数量。该事件只描述程序已知的敌我态势，不触发额外数值结算。

战斗运行态记录本场受伤 NPC、昏迷 NPC、每名 NPC 击退敌人的数量和击退敌人列表。敌人被我方攻击清零时会计入对应 NPC；敌人攻击 NPC 造成 HP 下降时会计入受伤；NPC 昏迷会计入昏迷统计。敌军全灭或 GM 清敌后，`CombatSystem` 写入广场 `combat_ended` 公开事件，summary 会说明敌人被清空、本场受伤 / 昏迷人员和击退统计。

战斗结束回收仍由行为模式系统执行：`combat` NPC 回到 `work` 并请求计划重评估；`avoid_combat` NPC 回到 `work`，只记录避战结束事实，不强制计划重评估；未接敌的 `rally` NPC 在清敌或等待超时后回到 `work`，也不重评估计划。`debug_get_combat_snapshot()` 暴露 `active_battle`、`last_battle_start_result` 和 `last_battle_end_result`，GM 面板“敌人快照”可直接观察当前战斗与最近结算。

## 敌人 AI

Demo 阶段敌人使用规则 AI，不调用 LLM。

T1101 已完成敌人波次配置与调试生成：`data/enemy_waves.json` 包含 5 波 Demo 敌人，后续波次在人数、HP、攻击、防御和兵种组合上逐步增强；每个敌人组记录 HP、武器类型、单位类型、攻击、防御、移动速度、攻击范围、攻击间隔和目标偏好。T1104B 后第一波被校准为低强度探路敌人，艾达持剑时应能观察到十几秒左右的互相攻击过程，而不是瞬间结束。`CombatSystem` 会读取该配置，并可通过 `spawn_wave(...)` / `debug_spawn_wave(...)` 在 `Main/WorldRoot/Station/Enemies` 下生成正门外低模敌人实体。

T1301 已完成波次倒计时与自动来袭：每个波次配置可包含 `trigger_day`、`trigger_hour`、`trigger_minute` 和 `trigger_second`，当前 5 波默认分别在第 3-7 天 18:00 触发。`CombatSystem` 在 TimeSystem 的 `logical_time_tick` 中按逻辑时间比较配置触发点，只触发下一未触发波次，并记录 `triggered_wave_numbers`，避免同一波重复自动生成。`get_wave_schedule_snapshot()` 暴露下一波、已触发波次、待触发波次、活动敌人数量、最近自动触发结果和最近手动跳波结果；HUD 使用该快照显示下一波倒计时，GM “跳到下一波”按钮和 `next_wave` / `jump_wave` 命令调用 `debug_trigger_next_wave()` 触发下一未触发波次。T1304 后，包含最终配置波次（当前第 5 波）的战斗在敌人清空后触发 `victory/five_waves_survived`；`GameState.set_game_over(...)` 保存通用结算原因和 `settlement_snapshot`，快照记录剩余资源、建筑 HP / 损毁 / 摧毁、驿站是否仍可运转，以及 NPC 可行动 / 昏迷 / 逃离状态。胜利后 TimeSystem 停止推进，HUD 显示胜利占位界面，`spawn_wave(...)` 会因游戏已结算而拒绝继续生成敌人。

T1303 已完成无可战斗人员失败条件：`CombatSystem` 的 `combatant_availability` 快照只把已入伍且持主武器、未昏迷、未逃离且未正在逃离的 NPC 视为当前可抵抗人员。该判定不要求 NPC 已经处于 `rally` 或 `combat`，因此工作中、尚未摇铃、尚未集结或尚未接敌的武装入伍 NPC 仍会计为可用，避免短暂未集结状态误判。活动敌人在场时，波次生成、逻辑推进、NPC 昏迷、逃离开始和逃离完成都会检查该快照；若存在可战斗人员但全部不可用，会写入 `failure/no_available_combatants`、保留不可用原因（`unconscious` / `escaped` / `escaping`）并复用 `GameState`、`TimeSystem` 和 HUD 的失败占位链路。

T1102 已完成敌人目标优先级、移动和敌方攻击，T1104 已把该推进扩展为双方基础攻击：`CombatSystem` 监听 `TimeSystem.logical_time_tick` 推进战斗 AI；敌人若在侦测范围内发现可行动 NPC，会优先攻击该 NPC，否则按目标偏好选择仍有 HP 的城门、仓库或主厅。T1104C 起，围墙不再作为敌人攻击目标：城门被攻破后敌人直接转向仓库，仓库被摧毁后再转向主厅；旧配置中的 `wall` / `front_wall` 会在目标偏好规范化时过滤。敌人移动按配置 `move_speed` 和 `game_delta_seconds / 60` 折算为战斗动作秒级位移；玩家 `x2` / `x4` 不额外提高敌人移动速度。进入 `attack_range` 后按战斗动作秒中的 `attack_interval` 和 `attack_power` 进行接触式攻击。攻击 NPC 时会先按 NPC 盔甲防御计算实际伤害，再调用 `NPCSystem.apply_damage_to_npc(...)`；攻击建筑时调用 `BuildingSystem.apply_damage_to_building(...)` 并写入 `building_damaged` 事件。T1302 后，主厅 HP 清零时 `GameState` 写入 `game_over=true`、`game_result="failure"`、`failure_reason="main_hall_destroyed"` 和失败时间，广播 `game_over_changed`，`TimeSystem` 自动暂停并停止逻辑推进，HUD 显示失败占位界面。T1303 后，活动敌人在场且所有已入伍持主武器战斗人员均不可用时，`GameState.failure_reason` 会写入 `no_available_combatants`。T1304 后，最终波次清敌时 `GameState.game_result` 会写入 `victory`，`game_over_reason` 写入 `five_waves_survived`，`failure_reason` 保持为空，并保存胜利 `settlement_snapshot`。T1104 后，`CombatSystem` 同时维护最近我方攻击快照 `last_friendly_attack_result`，并在最近 AI 推进结果中返回 `friendly_attacks`。T1104A 后，活动敌人存在期间 `debug_get_combat_snapshot()` 会包含 TimeSystem 时间倍率快照，GM 可观察 `combat_enemy_presence` 上限请求；T1104B 后快照会同时包含 `game_seconds` 与 `combat_seconds`，便于检查战斗动作秒换算；T1105 后快照包含 `combat_strategies`，用于查看每名入伍持武器 NPC 当前策略、可选策略和策略移动目标；T1204A 后快照包含 `active_escapes`、`last_escape_result`、已用 / 剩余挽留轮次、逃离速度倍率和暂停 / 恢复状态；T1303 后快照包含 `combatant_availability` 与 `last_failure_result` 供 GM / 自动化验证；T1304 后快照包含 `last_victory_result` 供 GM / 自动化验证。GM 面板提供“警铃集结”“推进敌人AI”“行为模式快照”“模拟避战”“触发逃离”“推进集结等待”按钮和 `alarm` / `rally` / `step_enemies [game_seconds]` / `behavior_modes` / `avoid_npc <npc_id>` / `escape_npc <npc_id>` / `advance_rally_wait [game_seconds]` 命令；敌人快照会显示目标、当前行动、最近 AI 推进结果、我方攻击结果、集结状态、避战目标、逃离目标、可战斗人员可用性、战斗策略、行为模式、失败 / 胜利结果和时间上限状态。

目标优先级：

1. 如果一定范围内有我方单位，优先攻击我方单位
2. 攻击城门
3. 城门被攻破后攻击仓库
4. 仓库被摧毁后攻击主厅

当前规则敌人不攻击围墙。后续“敌人必须从城门进入、NPC / 敌人不能直接穿越围墙”的空间约束，留给碰撞体积、导航路径或不可进入对象阻挡任务实现。

## 战场公开信息

战斗中关键事件必须先作为结构化事件写入 `MemorySystem`。每个事件关联 `subject_npc_id` 和 `location_id`；事件写入 NPC 自身事件库后，再按 `visibility` 发送到所在建筑的信息节点，由节点即时广播给当前在场 NPC；节点不保存事件历史。

通过信息节点公开广播的战斗事件包括：

- 敌袭开始、波次、敌军构成和我方已入伍持武器战斗人员
- 某 NPC HP 低于 30%
- 某非战斗人员开始 / 结束避战
- 某 NPC 击倒或击退敌人
- 某 NPC 昏迷
- 某 NPC 被治疗
- 某 NPC 复苏
- 某 NPC 逃离
- 建筑受损

若战斗发生在可进入建筑内部，事件可以同时广播到该建筑信息节点；室外战斗、城门/仓库/主厅受损、敌袭开始和战斗结束归入广场公开广播。

T1205 收尾检查已通过 `tools/verify_battlefield_public_info.gd` 综合验收：敌我人数、集结 / 必要模式切换、避战开始 / 结束、低血量、战时心理结果、击退敌人、昏迷、治疗、复苏、逃离、建筑受损和战斗结束均能进入广场或同地点见闻；后续 NPC 对话 payload 与 NPC 面板见闻库都能看到这些公开摘要。`work <-> combat` 与 `work <-> avoid_combat` 仍按 T1103D 规则降噪，不通过 `npc_mode_changed` 广播。

战斗结束后，NPC 回到工作状态，并根据自身经历重新评估计划。
