# AI_NPC_SYSTEM.md

## 模块目标

AI NPC 系统负责让 NPC 看起来像有职业、有记忆、有意图的人，而不是普通兵种单位。

## NPC 初始名单

T0301 已在 `data/npc_profiles.json` 补齐 8 名初始 NPC 档案：

| 职业 | id | 姓名 | 性别 | 初始是否已入伍 / 可接收指令 |
|---|---|---|---|---|
| 马夫 | `stableman_01` | 托马 | male | 否 |
| 厨子 | `cook_01` | 布鲁诺 | male | 否 |
| 园丁 | `gardener_01` | 伊沃 | male | 否 |
| 铁匠 | `blacksmith_01` | 格伦 | male | 否 |
| 老兵副官 | `veteran_deputy_01` | 艾达 | female | 是 |
| 神父 | `priest_01` | 马塞尔 | male | 否 |
| 医生 | `doctor_01` | 莉娜 | female | 否 |
| 工程师 | `engineer_01` | 欧文 | male | 否 |

开局仍只有老兵副官 `veteran_deputy_01` 已入伍并可接收守备官指令；其他 NPC 必须通过后续征召/对话流程同意后才会获得指令入口。

## 熟练度架构

NPC 没有写死的程序职业。`background_job` 只记录叙事出身，工作效率、训练倾向、装备表现和后续 AI 判断都应优先读取固定熟练度维度。

每名 NPC 都必须拥有且只能拥有以下 13 个熟练度：

| 类型 | 熟练度 |
|---|---|
| 职业熟练度 | 养马、厨艺、耕种、打铁、教练、酿酒、医术、工程 |
| 武器熟练度 | 剑盾、长杆、弓、弩、骑术 |

职业倾向由高熟练度推导。例如养马高的人可被看作马厩专家，医术高的人可被看作医生，但系统不应把“马夫 / 医生 / 工程师”等作为权威职业枚举。

## 当前运行时实现

T0304 已实现最小 NPC 生成、基础状态读取/更新、面板显示和直线移动闭环：

- `NPCSystem` 从 `data/npc_profiles.json` 读取 8 名初始 NPC 档案。
- 通用 `res://scenes/npc/NPC.tscn` 由 `NPCSystem` 实例化到 `Main/WorldRoot/Station/NPCs`。
- 每个 NPC 保存唯一 `npc_id`，主场景头顶调试标签只显示姓名、HP 和当前行动，职业与入伍状态保留在 NPC 面板中。
- 点击 NPC 会打印对应 ID，并通过 `EventBus.npc_clicked(npc_id)` 广播，打开 `Main/UI/NPCPanel`。
- `NPCSystem` 提供 `get_npc(...)`、`get_npc_state(...)`、`update_npc_state(...)` 和 `set_npc_state_value(...)`，后续系统可通过这些接口读取或修改 NPC 基础状态。
- `NPCSystem` 提供固定熟练度枚举与 `normalize_skills(...)`，确保每名 NPC 都拥有完整 13 维熟练度，且不会保留未定义技能。
- NPC 状态修改后会通过 `EventBus.npc_state_changed(npc_id)` 通知 UI 刷新。
- `NPCSystem.move_npc_to_building(...)` / `debug_move_npc_to_building(...)` 可让 NPC 前往指定建筑入口；当前用于调试验证和后续行动系统接入。
- `NPC.gd` 负责简单直线移动，到达目标后发出 `movement_arrived`，由 `NPCSystem` 写回 `current_location`、`current_location_name` 和 `location_context` 地点信息占位。

T0305 后，`ActionSystem` 已能通过调试接口安排 NPC 执行工作、吃饭和睡觉：系统会先复用 `NPCSystem.move_npc_to_building(...)` 前往目标建筑，到达后进入持续行动状态，并随 `TimeSystem.logical_time_tick` 逐步推进，而不是瞬时完成。吃饭当前以 20 分钟为基准，完整进餐恢复约 50 点饱食度；睡觉以 6.5 小时消耗 100 点疲劳为基准，按逻辑秒细分结算；工作当前以 1 小时为最小工作批次，在持续时间结束时结算该批次的资源投入、产出、饱食消耗和疲劳增长。行动开始、完成或失败都会写入 `MemorySystem` 的结构化事件。

2026-05-24 起新增协助修复行为；2026-05-25 起新增协助升级行为。`debug_assign_repair_assist(npc_id, building_id)` 与 `debug_assign_upgrade_assist(npc_id, building_id)` 都是带建筑参数的独立行为，可让 NPC 在广场协助正在修复或正在升级的建筑，并按工程熟练度加速对应倒计时；NPC 如果在室内，会先前往广场再开始协助。如果 NPC 离开广场或被改派其他行动，`BuildingSystem` 会移除其协助人数和速度加成。协助修复/升级事件写为 `location_id == "plaza"` 的 `local_public`。当前行动仍是最小闭环，不代表 NPC 已有真实每日计划或 LLM 自主决策。

T0501 起，`NPCSystem.apply_damage_to_npc(...)` / `debug_damage_npc(...)` 负责权威 HP 扣除。HP 降到 0 时 NPC 进入昏迷而不是死亡，停止移动，`current_action` 变为 `unconscious`，头顶标签与 NPC 面板会显示昏迷状态。昏迷 NPC 不能移动或执行工作、吃饭、睡觉、协助修复/升级等行动。

T0502 起，昏迷 NPC 会随 `TimeSystem.logical_time_tick` 自然恢复 HP，当前速率为每游戏小时 2 HP；HP 达到 Max HP 的 30% 后自动复苏，`unconscious=false`，`current_action=idle`，后续移动和行动指派重新允许。复苏会写入 `revived` 事件并按当前信息地点 `local_public` 广播。

T0503 起，其他可行动 NPC 可通过 `ActionSystem.debug_assign_heal_assist(healer_npc_id, target_npc_id)` 协助治疗昏迷目标。治疗者会前往目标所在信息地点；目标必须处于昏迷状态，每个目标最多 2 名治疗者。治疗开始和持续治疗会消耗全局第纳尔；医术熟练度会转化为额外 HP 恢复速度，低医术几乎没有额外加成，医生的高医术会明显快于自然恢复。治疗开始/完成事件会写入治疗者和目标的事件库，并写入同地点其他在场 NPC 的见闻库；事件信息不暴露医术熟练度。该功能只覆盖“他人治疗昏迷者”，不等同后续 NPC 主动去诊所治疗或医疗床位系统。

T0502A 起，昏迷 NPC 不接收地点/广场公开广播、建筑/地点状态广播、公告或进入快照，见闻库暂停更新；事件库仍记录发生在自己身上的受伤、昏迷、复苏等亲历事件。复苏后见闻接收自动恢复，但不会补收昏迷期间错过的信息。

2026-06-03 起，睡觉 NPC 使用同一条见闻接收规则：当 `current_action == "sleep_in_dormitory"` 时，该 NPC 不会把同建筑内发生的 `local_public` 事件、地点/建筑状态广播、公告或进入快照写入见闻库；自己的入睡和醒来仍进入事件库。睡醒回到可行动状态后，只从后续广播继续接收见闻，不补收睡觉期间错过的信息。

T0701-T0705 已实现 Godot 前端对话、最小征召、指令发布和主动交涉最小闭环。已入伍 NPC 可从 NPC 面板打开 `OrderPanel`，自由查看、修改并发布一条持续生效的 `current_order`；`NPCSystem.publish_npc_order(...)` 只在文本变化时更新指令、写入私有 `order_assigned` 并发出计划重评估请求。`NPCSystem.debug_start_proactive_talk(...)` 可让 NPC 进入主动找守备官交涉状态，显示问号气泡，点击后打开既有对话面板并让 NPC 预先确定的开场问题先入库；1 小时无人点击则状态结束。当前仍不实现复杂避障、真实日程、真实计划重评估处理、战斗心理判定或真实 LLM；Godot 客户端不保存供应商 API Key。

## 当前地点状态

T0304 起，NPC 运行时 `states` 会补齐以下地点字段：

- `current_location`：当前地点 id，默认 `plaza`，到达建筑后更新为建筑 id。
- `current_location_name`：当前地点显示名，到达建筑后由 `BuildingSystem` 填入。
- `movement_target` / `movement_target_name`：移动中的目标地点；到达后清空。
- `location_context`：地点当前状态读取占位，不包含地点历史事件。进入广场时包含当前广场在场 NPC、广场在场 NPC 状态、当前公告文本和所有建筑的可传播外部状态；进入可进入建筑时包含该建筑外部状态（等级、完好/受损/正在修复/正在升级）和内部状态（在场 NPC、建筑内 NPC 状态、每个工位的占用/空闲状态）。在场 NPC 状态分为生命状态和行动状态两个平行类别：生命状态只表达健康、受伤、昏迷；昏迷者如有治疗者会写明正在治疗的人，没有治疗者则不写。行动状态来自 `current_action`，但会翻译成精简中文，例如待命、前往食堂、吃饭、睡觉、协助治疗某人、协助修复某建筑。HP 具体数值、剩余修复/升级时长和工位数量不进入 NPC 需要传播的状态上下文。

这些字段先服务于最小行动闭环与后续见闻系统，不接 LLM，也不代表 NPC 已有真实日程计划。

## 事件、见闻与短期记忆

T0405 后，NPC 的短期记忆不再视为一个扁平文本列表，而由两类运行时记录组成：

- NPC 事件库：发生在该 NPC 身上的事件，例如醒来、制定计划、进入/离开地点、工作、吃饭、睡觉、对话、收到或修改守备官指令、被给予金钱/装备、升级、受击、昏迷、治疗、复苏、逃离等。
- NPC 见闻库：该 NPC 从地点/广场即时广播、状态变化广播、公告或他人公开事件中获得的信息；昏迷或睡觉期间暂停更新。

NPC 进入地点时，系统生成 `location_entered` 事件并写入进入者事件库；该事件只记录“某人进入了某地”，不附带完整建筑状态。进入者随后在见闻库获得一次当前状态快照：进入广场时获得当前广场在场 NPC、广场在场 NPC 的生命状态/行动状态、当前公告文本和所有建筑可传播外部状态，进入某个可进入建筑时获得该建筑外部 + 内部状态，包括当前在场 NPC、建筑内 NPC 的生命状态/行动状态和工位占用。已经在该地点的其他 NPC 只收到 `location_entered` 本地公开事件，不再额外收到完整人员状态。NPC 不会因为进入某建筑而继承该建筑过去发生的事件。

NPC 离开地点时，系统生成 `location_exited` 事件，`location_id` 使用其离开的地点；该事件写入离开者事件库，并以 `local_public` 广播给仍在该地点的 NPC。离开事件本身表达了“谁离开了这里”，不再额外广播完整 `people_present`。

NPC 从一个室内信息地点前往另一个室内信息地点时，当前实现会在事件和地点信息层插入广场中转：离开原地点、进入广场、离开广场、进入目标地点。物理表现仍是低模阶段的直线移动占位，不代表最终导航模型。

后续建筑或地点状态变化只进入字段级见闻，例如建筑受损、升级完成、公告变化或某个工位占用变化；未变化的建筑状态和在场人员不重复传递。对话全文也作为对话事件 `payload` 保存，供后续对话、计划和睡前总结引用。

T0603 对话请求的目标 NPC 输入应包含 `npc_id`、`npc_name`、`npc_setting`、`npc_state`、`short_memory`、`long_memory` 和 `location_context`；说话者输入包含 `speaker_name`、`speaker_text` 和 `speaker_context`。T0703A 实现后，所有面向目标 NPC 的对话请求还必须加入该 NPC 的 `current_order`。如果说话者是守备官，名称固定为“守备官”；如果说话者是 NPC，`speaker_context` 应包含发起者健康/受伤状态与外表特征。NPC-NPC 对话由当前轮次与最大轮次控制，接近最大轮次时后端更倾向结束对话。

对 LLM 来说，亲历事件和见闻必须分开摘要：亲历对情绪和判断权重更高，见闻则代表当场听到/看到的信息、公共压力和场景认知。

面向 NPC 的所有玩家相关事件摘要、见闻摘要、对话上下文和后续日记/反思输入，必须把玩家称为“守备官”。“玩家”只作为开发文档里的外部说明词使用，不进入 NPC 可见文本或 LLM 世界内上下文。

当前运行时可通过 `MemorySystem.get_npc_short_term_memory(npc_id)` 获取 `{ event_log, witness_log }` 两个容器，也可通过 `get_npc_short_term_memory_ids(...)` 获取事件 ID 版本。`NPCPanel` 已显示事件库和见闻库最近摘要；地点状态见闻会写明具体建筑名称和状态，例如“围墙受损”“食堂内现在有布鲁诺、莉娜”“在场人员状态：布鲁诺健康，行动：吃饭”“菜园里的 garden_plot_01 状态变为空闲”。T0704 后，守备官给钱、占位给武器和攻击已可从 NPC 面板触发；给钱、占位装备和攻击会进入目标 NPC 事件库，公开交互会进入同地点 NPC 的见闻库，并随 `LLMBridge` 后续对话上下文的短期记忆摘要传给后端。“要求休息/请求治疗”不作为 NPC 面板按钮，相关意图由已入伍 NPC 的自然语言指令表达。

## NPC 行为层级

NPC 行为分三层：

### 1. 程序强制层

不需要 LLM：

- HP 清零 → 昏迷
- HP 恢复到 30% → 复苏
- 饱食度过低 → 优先吃饭
- 疲劳过高 → 优先睡觉
- 工作位占用 → 等待或换行动
- 敌人进入近距离 → 避战或战斗策略

程序强制层触发吃饭、睡觉或工作时，只能启动持续行动；不能直接把饱食、疲劳、资源或产出改成最终值。权威数值应随逻辑时间推进，由程序按行动定义结算。

### 2. 计划层

低频调用 LLM：

- 每天早晨制定 24 小时计划
- 遇到重大异常后重新评估计划
- 守备官发布不同于原内容的新指令后立即重新评估计划
- 对玩家产生主动交涉意图

计划层的时间触发以 TimeSystem 的逻辑时间为准。每日计划和任何计划重评估都必须读取 `current_order`，但指令只提供倾向，不直接启动行动或覆盖程序强制层。若计划生成或重评估会影响当前场景即时行动，Godot 侧必须申请 TimeSystem 慢速，等待 LLM / Mock 返回、失败或降级后释放。

### 3. 表演与判断层

关键节点调用 LLM：

- 玩家/NPC对话
- 征召同意/拒绝
- 战斗前心理判定
- HP 低于 30% 判定
- 逃离挽留
- 睡前总结

表演与判断层等待 LLM 返回时不冻结游戏，也不改变 NPC 移动或动画速度；只让逻辑时间和按时间结算的资源、状态、战斗数值减速到默认 `1/60`，即现实 1 秒约等于游戏 1 秒。玩家主动暂停时，UI、对话和已经发起的 LLM 请求仍可继续等待或返回，但程序权威结算（移动、战斗、资源/状态变化）应保持暂停，恢复后再应用。

所有面向某名 NPC 的 LLM 调用都必须把该 NPC 的 `current_order` 作为独立上下文字段注入，包括对话、每日计划、计划修订、主动交涉、战斗/低血量/逃离判定和睡前反思。Prompt 必须明确：这是守备官当前提出的指令，不是系统消息，不保证服从，也不能越过行动白名单、资源、HP、地点或战斗权威规则。

## 已入伍 NPC 指令机制

正式玩家指令系统不是 ActionSystem 的行动下拉，也不是 RTS 式强制命令：

- 只有 `recruited=true` 的 NPC 面板显示可用“指令”按钮。
- 点击后打开自由文本指令撰写与发布面板；已有指令会预填，供玩家直接修改。
- 点击“发布”时，新文本只有与原 `current_order.text` 不同才覆盖旧指令、递增修订号并触发后续效果。
- 指令变化会写入目标 NPC 的 `private` `order_assigned` 事件；summary 为“守备官制定了新的指令。”，完整新旧文本写入 payload。
- 指令变化后立即请求统一计划重评估入口；关闭面板或发布相同文本都不修改数据、不写事件、不触发重评估。
- NPC 后续是否执行、何时执行、如何调整或拒绝，由计划、判断、人格、记忆和现场状态共同决定。

`ActionSystem.debug_assign_*` 等直接行动接口仍可用于 GM 和自动化验证，但不代表正式玩家指令语义。

T0703A 后，统一重评估入口仍表现为 `EventBus.npc_plan_reevaluation_requested(npc_id, reason)`；`NPCSystem.get_last_plan_reevaluation_request()` 保存最近请求、最新 `current_order` 和处理结果供 GM / 自动化观察。由于 T1002 完整计划链路尚未实现，当前结果为 `rule_fallback_deferred`：保留最新指令等待统一计划重评估，不直接改变当前行动。`LLMBridge` 同时把最新指令注入对话顶层输入和共享 NPC 上下文，并保存最近注入快照。

## 主动找玩家机制

NPC 可以在计划中选择“主动找玩家交涉”。T0705 当前先提供规则 / GM 调试触发；真实计划层主动意图仍归后续计划系统。

表现方式：

- NPC 头顶出现问号气泡。
- 玩家点击后进入对话；若有主动交涉状态，点击优先打开对话，不先打开 NPC 面板。
- NPC 想说的话在触发时已经确定，写入发起者事件库；点击气泡时不临时调用 LLM 生成开场。
- 对话结束后 NPC 重新评估计划。
- 若 1 游戏小时内未点击，主动交涉状态结束并重新评估计划。

当前运行时实现：

- `NPCSystem.start_proactive_talk(...)` / `debug_start_proactive_talk(...)` 设置 `states.proactive_talk`，并把 `current_action` 置为 `proactive_talk`。
- 触发时写入 `private` 的 `proactive_talk_started` 事件，payload 保存 `prompt_text` 和持续时间。
- `NPC.gd` 运行时创建 `ProactiveTalkBubble`，主动交涉有效时显示 `?`。
- 点击后 `DialogSystem.start_proactive_player_dialogue(...)` 复用玩家-NPC 对话窗口，把 `prompt_text` 作为 NPC 第一条历史显示，并写入 `proactive_talk_message`。
- 玩家后续回复继续走现有 `/npc/dialogue` Mock 与 `dialogue_turn` 事件逻辑。
- T1002 尚未实现时，对话结束或超时后的计划重评估仍为 `rule_fallback_deferred` 降级观察结果，不直接应用新计划。

触发原因：

- 想索要金钱、装备。
- 想询问信息。
- 想表达恐惧或不满。
- 想报告战场或地点见闻。
- 想主动应征、退出入伍或逃离。

## 征召机制

开局只有副官可接收守备官指令。
其他 NPC 必须通过对话同意应征后，才获得指令入口。

征召结果：

- 接受
- 拒绝

## 入伍后

NPC 入伍后仍然保留人格和记忆。  
玩家可以向其自由撰写工作、训练、休息、治疗、防守等指令，并直接管理装备；指令会进入后续 LLM 上下文，但不会硬性覆盖自主计划或权威结算。

## 关键原则

> NPC 的职业经历、熟练度倾向与记忆必须持续影响其行为。  
