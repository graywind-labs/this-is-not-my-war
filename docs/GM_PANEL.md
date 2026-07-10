# GM_PANEL.md

> 本文件记录 GM 调试面板的用途、入口、命令和维护规则。每次更新 GM 面板都必须同步更新本文档。

## 目标

GM 面板用于把“已经实现但用户难以在主界面直接验证”的关键系统能力暴露到 `Main.tscn` 前端。它只调用已有系统接口或 `debug_*` 接口，不作为新的权威结算系统。

当前重点覆盖 M1-M4 已完成内容中原本主要靠脚本验证的能力：

- 资源增减、扣除失败和负数保护。
- 建筑选中、受损、倒计时修复、倒计时升级和全建筑外部状态广播。
- NPC 选中、状态修改、移动到建筑、立即进入地点。
- NPC 扣血、HP 清零昏迷、昏迷后行动阻断、昏迷自然恢复和复苏。
- 昏迷或睡觉期间见闻暂停；睡觉 NPC 不会接收同地点/同建筑 public 见闻，睡醒后恢复。
- 通过“指定行动”下拉统一指派工作、训练场教官/受训者、吃饭、睡觉等普通行动，并保留协助修复、协助升级、协助治疗昏迷者等带目标参数的行动调试入口。
- TimeSystem 设定时间、跳小时、LLM 等待减速请求、有效倍率 / 慢速请求 / 时间上限请求快照。
- LLMBridge 后端 health check、开发期 NPC 对话 Mock、提出应征 Mock 和后端 LLM usage / 成本统计 / 预算状态 / 失败原因 / Godot LLM 等待运行态查询。
- 地点快照、广场公告、广场公开事件、守备官给钱/攻击等记忆事件。
- NPC 短期记忆容器，区分事件库和见闻库。
- 已入伍 NPC 当前自然语言指令、修订号、最近计划重评估请求 / 应用结果和最近一次 NPC LLM 指令注入。
- 每日计划与 T1002/T1003 重评估：通过 LLM / Mock 生成 24 小时计划并自动规则降级，也可生成纯规则计划、执行当前小时计划、查看当前计划、手动触发当前 NPC 计划重评估。
- 首次睡眠总结与长期记忆：触发当前 NPC 首次睡眠总结、查看长期日记 / 知识图谱当前键值、最近一次总结结果和当前 LLM 活动状态。
- NPC 主动找守备官交涉的调试触发、问号气泡状态和超时 / 对话结束后的计划重评估请求。
- 正式装备系统：为已入伍 NPC 装备主武器、盔甲和坐骑，并查看当前兵种判定快照。
- T0904 成长系统：查看 NPC 总经验、未分配技能点，并由玩家把技能点分配到力量或智力。
- T0015 调试征召：可将当前选中 NPC 设为入伍，便于验证指令、装备和训练入口。
- T1101-T1304 敌人波次、目标优先级、双方基础攻击、战斗动作秒、警铃集结、非战斗人员避战、不同兵种战斗策略、敌人在场时间上限、战斗开始 / 结束流程、逃离驿站、逃离挽留、波次日程、失败条件和第 5 波胜利调试：生成第一波或指定波次敌人，按已触发记录跳到下一波，触发警铃集结，查看敌人目标 / NPC 集结 / 避战 / 逃离 / 挽留轮次 / 逃离速度 / 可战斗人员可用性 / 战斗策略 / 我方攻击 / 当前战斗 / 波次日程 / 最近战斗开始和结束结果 / 最近失败或胜利结果 / TimeSystem 倍率快照，模拟未入伍或无主武器 NPC 避战，手动触发 NPC 逃离，手动推进战斗 AI，清空当前敌人；T1104C 后敌人不再攻击围墙，城门破坏后转向仓库 / 主厅。T1105 的正式策略选择入口在 NPC 面板“装备武器”旁的下拉框，GM 只通过敌人快照观察当前策略，不另设权威策略按钮。

GM 命令仍可使用 `give_money` / `attack_npc` 这类开发语义；写入 NPC 事件库、见闻库和事件 summary 时，玩家身份必须显示为“守备官”。

## 开关

GM 面板脚本位于：

```text
res://scripts/ui/GMPanel.gd
```

顶部常量控制是否启用：

```gdscript
const GM_ENABLED := true
```

- 开发验证时设为 `true`。
- 上线、正式录屏或不希望显示 GM 时设为 `false`。
- 不要删除 GM 节点和文档；后续开发仍需要它作为不可见功能的验证入口。

## 界面

运行 `res://scenes/main/Main.tscn` 后，屏幕左侧会出现半透明 `GM` 按钮。

- 拖动 `GM` 按钮可改变位置。
- 点击 `GM` 按钮会在按钮附近打开或关闭 GM 面板；面板会随按钮位置重定位，并夹在可用屏幕范围内，避免固定覆盖左上角 HUD。
- 面板顶部有命令输入框和执行按钮。
- 面板中部分组提供常用按钮和输入框。
- 面板底部显示最近执行结果。

## 分组

资源：

- 选择资源 ID 和数量。
- 增加资源。
- 扣除资源。
- 查看资源快照。

时间：

- 设置天、时、分、秒。
- 跳过 1 小时。
- 注册一次 GM 手动 LLM 减速。
- 清空所有减速请求。
- 查看时间倍率快照，包括玩家选择倍率、实际有效倍率、LLM 慢速请求和 TimeSystem 上限请求；T1104A 后生成敌人时可观察 `combat_enemy_presence` 上限，清敌后应消失。

建筑：

- 选择建筑。
- 打开建筑面板。
- 造成建筑受损。
- 调用修复；修复会先扣资源并创建倒计时作业，建筑快照可观察剩余时间、进度、协助人数和加速倍率。
- 调用升级；升级会先扣资源并创建倒计时作业，建筑快照可观察升级状态、进度、剩余时间、协助人数和加速倍率。
- 查看建筑快照。

NPC：

- 选择 NPC。
- 打开 NPC 面板。
- 移动到指定建筑入口。
- 立即进入地点信息节点。
- 设置 NPC 状态字段。
- 扣除 NPC HP；HP 清零后由 `NPCSystem` 触发昏迷；战斗中 HP 首次跌破 30% 且仍大于 0 时由正式低血量判定链路处理。
- 用自然恢复规则推进指定 NPC 的昏迷恢复，便于快速验证复苏。
- 查看 NPC 快照。
- 为已入伍 NPC 发布自然语言指令、查看当前指令，并查看最近一次计划重评估请求及其应用结果；未入伍 NPC 发布会被 `NPCSystem` 拒绝。
- 为当前选中 NPC 生成 LLM / Mock 版 24 小时计划、生成纯规则计划、执行当前小时计划、查看计划或立即触发计划重评估；计划入口调用 `DailyPlanSystem`，不在 GMPanel 中自行决定行动结算。`plan_generate` 会请求 `/npc/plan_day` 并在失败时规则降级，`plan_generate_rule` 只生成规则计划。
- 为当前选中 NPC 触发首次睡眠总结、查看长期记忆、最近一次总结结果和 LLM 状态；首次睡眠总结入口调用 `DailyReflectionSystem`，不在 GMPanel 中自行写日记、清短期记忆或更新知识图谱。`llm_state` 只读取 NPC 当前 `llm_activity`、首次睡眠总结锁和延后计划重评估状态。
- 将当前选中 NPC 设为入伍；该入口只调用 `NPCSystem.set_npc_recruited(...)`，用于调试验证，正式征召仍由对话同意结果驱动。
- 触发当前选中 NPC 主动找守备官交涉，并查看该 NPC 的主动交涉状态；触发后 NPC 头顶出现 `?`，点击后进入既有对话面板。
- 选择武器类型和盔甲部位，为当前选中且已入伍 NPC 装备武器、盔甲或坐骑；装备入口调用 `EquipmentSystem`，消耗 `weapons` / `armor` / `horse_readiness` 派生库存并写入装备事件。
- 查看当前选中 NPC 的兵种判定快照，包括主武器类型、武器 class、是否有坐骑和装备槽内容。
- 为当前选中 NPC 分配技能点到力量或智力；该入口只调用 `NPCSystem.assign_npc_attribute_point(...)`，无未分配技能点或属性已达上限时会失败。技能点由玩家分配，AI 只可作为后续建议来源。

行动：

- 指派指定行动；该下拉列出 `data/action_defs.json` 中的普通行动，包括工作、诊所、训练、吃饭和睡觉等入口，不包含协助修复、协助升级、协助治疗这类需要额外目标参数的运行时行动。
- 工作类行动会占用目标可进入建筑的真实工位，并按 NPC 对应熟练度、力量/智力属性和建筑等级缩短单位周期。T0803 起，菜园工作还会按耕种熟练度、力量和菜园等级提高粮食产出。T0804 起，铁匠铺工作会消耗铁并产出武器/盔甲派生库存，打铁、力量和铁匠铺等级影响制作周期。T0805 起，工械坊工作会消耗木材并产出武器/工程器械派生库存，工程、智力和工械坊等级影响制作周期。T0806 起，马厩工作会消耗粮食并产出马匹整备派生库存，养马、力量和马厩等级影响制作周期与实际产出。T0807 起，酒窖工作会消耗粮食并产出酒库存，酿酒、智力和酒窖等级影响制作周期与实际产出；出售酒换钱仍归后续商人交易系统。工位占满或资源不足时会失败并写入对应结构化事件。
- “指派行动”下拉可直接选择 `work_clinic_doctor` 和 `receive_clinic_treatment` 验证 T0808 小诊所：先让医生进入诊所医生工位，再让受伤且未昏迷 NPC 进入病床，治疗会随逻辑时间扣第纳尔并恢复 HP；若医生在岗但没有病人，会研读医学著作并缓慢提升医术。
- 通过行动分组内的“修复目标”建筑下拉选择目标，再指派 NPC 协助该建筑的修复；协助修复是一个统一行为，建筑由该下拉或命令参数决定。
- 通过行动分组内的“升级目标”建筑下拉选择目标，再指派 NPC 协助该建筑的升级；协助升级同样是带建筑参数的统一行为。
- 通过行动分组内的“治疗目标”NPC 下拉选择昏迷目标，再指派当前选中 NPC 协助治疗；协助治疗是带目标 NPC 参数的统一行为，目标必须昏迷，每个昏迷目标最多 2 名治疗者。
- 训练、吃饭和睡觉在 UI 中都通过行动下拉指派；`train_instructor <npc_id>`、`train_student <npc_id>`、`eat <npc_id>`、`sleep <npc_id>` 等命令仍保留，便于自动化验证和快速调试。训练入口只调用 `ActionSystem`，无装备、无教官或工位占用等失败条件仍由行动系统结算并写入事件。

战斗 / 敌人：

- 选择敌人波次。
- “生成第一波敌人”固定调用 `CombatSystem.debug_spawn_wave(1)`，用于快速验证 T1101 第一波正门外生成。
- “生成所选波次”按波次下拉调用 `CombatSystem.debug_spawn_wave(...)`。
- “跳到下一波”调用 `CombatSystem.debug_trigger_next_wave()`，按 `CombatSystem` 已记录的 `triggered_wave_numbers` 触发下一未触发波次，用于快速验证 T1301 自动波次日程；该入口不修改时间、不自行写战斗事件。
- “警铃集结”调用 `CombatSystem.debug_trigger_combat_alarm()`，触发与 HUD 警铃相同的集结流程：所有 NPC 写入警铃事件，入伍且有主武器的可行动 NPC 前往城门外防线。
- “敌人快照”读取 `CombatSystem.debug_get_combat_snapshot()`，显示当前活动敌人数量、波次、波次日程、敌人目标、当前行动、NPC 集结状态、非战斗人员避战目标、逃离目标、逃离挽留轮次、逃离速度倍率、可战斗人员可用性 `combatant_availability`、入伍持武器 NPC 战斗策略、当前战斗 `active_battle`、最近战斗开始 / 结束结果、最近战时对话结果、最近低血量自身心理判定结果、最近逃离结果、行为模式快照、最近警铃结果、最近生成结果、最近 AI 推进结果、最近我方攻击结果、最近失败结果、最近胜利结果、最近模式切换结果、最近避战结果和 TimeSystem 倍率快照；T1104C 后可用该快照确认敌人目标不会是围墙，T1105 后可用该快照确认策略下拉框选择已进入 CombatSystem 状态，T1106 后可用该快照确认 `combat_started` / `combat_ended` 的运行态和结算统计，T1201 后可用该快照确认 `morale_boost` 或逃离流程的最近应用结果，T1202 后可用该快照确认 `last_low_hp_judgement_result` 与 `active_battle.low_hp_judgements`，T1204A 后可用 `active_escapes` / `last_escape_result` 确认逃离开始、挽留打开暂停、关闭或满 5 轮恢复、挽留后留下 / 继续、给钱减速、攻击加速且无 NPC 回复、昏迷暂停、复苏继续和离站完成；T1301 后可用 `wave_schedule` 确认下一波、已触发波次和最近手动跳波结果；T1303 后可用 `combatant_availability` 和 `last_failure_result.reason == "no_available_combatants"` 确认无可战斗人员失败；T1304 后可用 `last_victory_result.reason == "five_waves_survived"` 和 `settlement_snapshot` 确认第 5 波胜利快照。
- “推进敌人AI”调用 `CombatSystem.debug_step_enemy_ai(60.0)`，用于手动推进 60 游戏秒的目标选择、移动、我方基础自动攻击和敌方攻击；T1104B 后这约等于 1 秒战斗动作。命名保留为兼容旧入口。
- “清空敌人”调用 `CombatSystem.debug_clear_enemies()`，删除当前 `Station/Enemies` 下由 CombatSystem 生成的敌人。
- “行为模式快照”调用 `NPCSystem.debug_get_behavior_mode_snapshot()`，查看每名 NPC 的 `behavior_mode`、进入原因、进入时间、当前行动和兼容 `combat_mode`。
- “模拟避战”调用 `CombatSystem.debug_trigger_npc_avoidance(selected_npc_id)`，用于让当前选中的非战斗人员（未入伍，或已入伍但无主武器）在已有活动敌人时进入避战，并按敌方方位生成短步长四散移动目标；已入伍且有主武器的 NPC 会被拒绝，按战斗逻辑处理。
- “触发逃离”调用 `CombatSystem.debug_start_npc_escape(selected_npc_id)`，用于让当前选中且未昏迷、未逃离的 NPC 前往后门外出口；该入口只触发正式逃离系统，`escape_started` / `escaped` 事件和 `escaped=true` 标记仍由系统结算。T1204A 后可用该入口制造逃离状态，再在主界面点击逃离 NPC 打开 NPC 面板，通过【对话】进入五轮挽留；也可用 `give_money` 或逃离挽留面板里的攻击按钮验证逃离速度变化。
- “推进集结等待”调用 `CombatSystem.debug_advance_rally_wait(3600.0)`，用于快速验证 NPC 到达集合点后等待 1 游戏小时仍未接敌会返回工作模式且不触发计划重评估。
- 该分组不自行结算伤害、集结结果、逃离结果或时间倍率，只调用 CombatSystem / NPCSystem / TimeSystem 的公开 / `debug_*` 接口；警铃集结会经 CombatSystem 调用 ActionSystem / NPCSystem / MemorySystem。T1104 后，我方攻击和敌人受击由 CombatSystem 结算并写入 `attack_made`，敌方攻击 NPC 先按 NPC 盔甲防御减伤再复用 `NPCSystem.apply_damage_to_npc(...)`，敌方攻击建筑复用 `BuildingSystem.apply_damage_to_building(...)`。T1104A 后，活动敌人存在时 CombatSystem 注册 `combat_enemy_presence` 时间上限，把 TimeSystem 有效倍率上限压到 `x1`，清敌后释放；T1104B 后，GM 推进 60 游戏秒约等于 1 秒战斗动作，便于观察攻速基准。T1106 后，战斗开始 / 结束事件和受伤 / 昏迷 / 击退统计由 CombatSystem 写入并通过敌人快照展示。T1201 后，敌人快照可观察最近一次战时对话心理结果和斗志 buff；T1202 后，通过生成敌人并用 `damage_npc` / NPC 扣血入口让 HP 跨过 30%，可在敌人快照观察低血量自身心理判定结果；T1204A 后，逃离调试、挽留暂停 / 恢复、轮次置灰、速度变化、逃离攻击无回复、昏迷暂停和正式逃离结果可在敌人快照观察。GM 仍只显示这些状态，不自行决定倍率、冷却、HP、击退统计、心理结果、逃离完成或胜负。

行为模式后续调试入口：

- T1103B/T1103C 已可查看每名 NPC 的 `behavior_mode`、模式进入原因和模式进入时间，并可推进集结等待时间；敌人快照可查看 `active_avoidances`，`avoid_npc <npc_id>` 可手动触发非战斗人员避战。
- 后续仍需补充可视化：当前敌人接触范围判定、斗志 buff 剩余时间的专用 UI。
- 手动触发 / 验证：战时心理结果、斗志 buff、低血量自身心理判定、逃离驿站和逃离挽留都可通过正式入口与敌人快照验证；低血量判定可用敌人在场时的 NPC 扣血入口触发，逃离可用 `escape_npc <npc_id>` 触发，挽留可在主界面点击逃离 NPC 打开 NPC 面板后点击【对话】触发。
- 查看最近一次战时对话的 `wartime_reaction`、`battle_psychology_result`、`morale_boost` / `escape_intent` 状态，最近一次低血量自身心理判定的 `last_low_hp_judgement_result`、`active_battle.low_hp_judgements`，以及逃离流程的 `active_escapes` / `last_escape_result`，其中 T1204A 会显示挽留轮次、速度倍率和暂停 / 继续状态。
- 这些入口只能调用 CombatSystem / NPCSystem / DialogSystem / LLMBridge 的公开或 `debug_*` 接口，不在 GMPanel 内自行决定模式、buff、逃离或战斗伤害。

后端 / LLMBridge：

- 后端健康检查，调用 `LLMBridge.check_health()` 并刷新 HUD 后端状态。
- 查看后端 LLM usage / 成本统计 / 预算状态，调用 `LLMBridge.debug_request_llm_usage()` 读取 `GET /debug/llm_usage`，显示 provider、model、调用次数、token、费用估算、fallback 次数、预算上限、已用量、剩余额度、最近预算错误、最近失败、HTTP 状态或异常类型、Schema 失败和降级来源；同时读取 `LLMBridge.debug_get_llm_runtime_snapshot()`，显示当前等待中的 LLM 请求数、pending slowdown request id、NPC 活动请求、异步请求数量、有效逻辑倍率和最近一次 TimeSystem 倍率变化原因。该入口只读，不申请 TimeSystem 慢速。
- 对当前选中 NPC 发送 `/npc/dialogue` 开发期 Mock 请求。
- 对当前选中 NPC 发送带 `is_recruitment_request=true` 的开发期应征 Mock 请求。
- 查看最近一次共享 NPC LLM 上下文注入的目标、调用类型和 `current_order`。
- 该分组只显示后端返回，不写入对话事件、不修改入伍状态。`dialogue_mock` / `dialogue_recruit` 只用于开发和 Schema 验证，不作为真实 API 验收；真实 provider 失败应通过 usage / 日志查看原因，不用 mock 回复伪装成功。

记忆 / 见闻 / 广场：

- 写入广场公告。
- 查看地点快照；广场快照包含当前在场 NPC 的 `people_statuses`、当前公告和所有建筑外部状态，可进入建筑快照包含该建筑外部 + 内部状态，`people_statuses` 可观察在场 NPC 的生命状态、行动状态和昏迷治疗者。
- 查看 NPC 短期记忆。
- 写入守备官给钱事件。
- 写入守备官攻击 NPC 事件。
- 广场公开广播事件。
- 查看全局事件列表。

上述玩家交互事件写入后，summary 应显示为“守备官给了……”或“守备官攻击了……”，不显示以“玩家”为主语的旧式文本。

## 命令

命令输入框支持以下命令：

```text
help
refresh
snapshot
events
plaza_events
add_resource <resource_id> <amount>
spend_resource <resource_id> <amount>
set_time <day> <hour> <minute> <second>
advance_hour
time_snapshot
slowdown [request_id] [scale] [reason]
release_slowdown <request_id>
clear_slowdowns
select_npc <npc_id>
select_building <building_id>
move_npc <npc_id> <building_id>
enter_location <npc_id> <location_id>
set_npc_state <npc_id> <key> <value>
recruit_npc <npc_id>
assign_attribute <npc_id> <strength|intelligence>
publish_order <npc_id> <text>
order <npc_id>
plan_request
plan_generate [npc_id|all]
plan_generate_rule [npc_id|all]
plan_execute [npc_id|all]
plan <npc_id>
plan_revise <npc_id> [reason]
reflect_npc <npc_id> [force]
long_memory <npc_id>
reflection_result
llm_state <npc_id>
start_proactive <npc_id> <text>
proactive <npc_id>
equip_weapon <npc_id> <weapon_id> [visibility]
equip_armor <npc_id> <slot> [visibility]
equip_mount <npc_id> [visibility]
unit_type <npc_id>
spawn_wave [wave_number]
enemy_wave [wave_number]
next_wave
jump_wave
enemies
alarm
rally
step_enemies [game_seconds]
clear_enemies
behavior_modes
avoid_npc <npc_id>
advance_rally_wait [game_seconds]
escape_npc <npc_id>
assign_action <npc_id> <action_id>
work <npc_id> <building_id>
train_instructor <npc_id>
train_student <npc_id>
assist_repair <npc_id> <building_id>
assist_upgrade <npc_id> <building_id>
assist_heal <healer_npc_id> <target_npc_id>
eat <npc_id>
sleep <npc_id>
damage_building <building_id> <amount>
repair_building <building_id>
upgrade_building <building_id>
plaza_notice <text>
give_money <npc_id> <amount> [visibility]
attack_npc <npc_id> <damage> [visibility]
damage_npc <npc_id> <damage> [visibility]
recover_npc <npc_id> <game_seconds>
backend_health
llm_usage
dialogue_mock <npc_id> <text>
dialogue_recruit <npc_id> <text>
last_order_injection
memory <npc_id>
location <location_id>
```

常用示例：

```text
add_resource money 20
damage_building wall 15
repair_building wall
assist_repair engineer_01 wall
upgrade_building garden
assist_upgrade engineer_01 garden
damage_npc cook_01 150 local_public
assist_heal doctor_01 cook_01
set_time 2 9 30 0
time_snapshot
enter_location cook_01 dining_hall
work gardener_01 garden
work blacksmith_01 blacksmith
work engineer_01 workshop
work stableman_01 stable
work cook_01 tavern
assign_action doctor_01 work_clinic_doctor
assign_action cook_01 receive_clinic_treatment
train_instructor veteran_deputy_01
train_student stableman_01
eat cook_01
sleep priest_01
plaza_notice 今晚所有人都必须留在广场附近。
give_money cook_01 5 local_public
recover_npc cook_01 54000
backend_health
llm_usage
dialogue_recruit cook_01 守备官需要你一起保护大家。
publish_order veteran_deputy_01 守住城门，但先保证自己安全。
recruit_npc priest_01
order veteran_deputy_01
plan_request
plan_generate gardener_01
plan_generate_rule gardener_01
plan_execute gardener_01
plan gardener_01
plan_revise gardener_01 gm_manual
reflect_npc cook_01 force
long_memory cook_01
reflection_result
llm_state cook_01
start_proactive cook_01 守备官，我想知道我们还能不能守住这里。
proactive cook_01
add_resource weapons 2
add_resource armor 1
add_resource horse_readiness 1
equip_weapon veteran_deputy_01 bow local_public
equip_armor veteran_deputy_01 chest local_public
equip_mount veteran_deputy_01 local_public
unit_type veteran_deputy_01
assign_attribute cook_01 strength
spawn_wave 1
next_wave
alarm
enemies
escape_npc priest_01
step_enemies 60
clear_enemies
memory cook_01
location plaza
events
```

`unit_type` 只读取 `EquipmentSystem.get_unit_type_snapshot(...)`。即使资源库存里存在 `horse_readiness`，NPC 未装备 `equipment.mount` 时也不会被判定为骑兵。

## 维护规则

每次完成任务验证时，Agent 必须判断本次功能是否能被用户直接在主界面看见和手动验证。

- 如果不能直接看见，但它是关键状态、数据、事件、AI、资源、建筑、NPC、时间、战斗、后端或 Prompt 调试能力，就必须给 GM 面板新增或替换入口。
- 如果新实现已经覆盖旧调试能力，应替换旧按钮或命令，不保留误导性的旧入口。
- GM 面板入口应该调用系统已有公开方法或 `debug_*` 方法；不要把数值结算、HP 扣除、记忆写入等权威逻辑写在 GMPanel 里。
- 每次更新 GM 面板时，同步更新本文件的“分组”“命令”和“常用示例”。
- 如果新增 GM 验证脚本或重要文件，同步更新 `docs/MODULE_INDEX.md`。

## 验证

GM 面板当前有专用验证脚本：

```powershell
godot --headless --path . --script res://tools/verify_gm_panel.gd
```

该脚本会加载 `Main.tscn`，检查 GM 按钮和窗口，执行命令验证资源、建筑、时间、时间倍率快照、NPC 地点、GM 入伍按钮、自然语言指令、每日计划生成 / 查看 / 执行、手动计划重评估、首次睡眠总结入口、长期记忆查看、计划重评估请求/结果、最近 LLM 指令注入、训练场教官/受训者入口、敌人波次生成 / 跳到下一波按钮 / 警铃集结 / 快照 / AI 推进 / 清空、逃离命令、敌人在场 TimeSystem `x1` 上限注册 / 释放、记忆事件和广场公告。T0904 的成长与技能点分配由 `tools/verify_skill_progression.gd` 覆盖；T1001 的计划执行细节由 `tools/verify_daily_plan_system.gd` 覆盖；T1002 的异常重评估细节由 `tools/verify_daily_plan_reevaluation.gd` 覆盖；T1003 的 `/npc/plan_day` Mock 计划和规则降级由 `tools/verify_daily_plan_llm.gd` 覆盖；T1004/T1005 的首次睡眠总结、NPC 面板日记、短期记忆清空和对话 / LLM 打断边界由 `tools/verify_daily_reflection_system.gd` 与 `tools/verify_dialogue_sleep_summary_boundaries.gd` 覆盖；T1101 的敌人波次数据、正门外生成位置、GM 入口和清理流程由 `tools/verify_enemy_wave_generation.gd` 覆盖；T1301 的 HUD 倒计时、配置时间自动来袭、重复触发保护和 GM 跳波入口由 `tools/verify_enemy_wave_schedule.gd` 覆盖；T1102/T1104C 的目标优先级、跳过围墙、移动、敌方建筑攻击和主厅失败状态由 `tools/verify_enemy_target_priority.gd` 覆盖；T1103 的 HUD 警铃、GM 命令、阵型、骑乘表现和遭遇敌人切换由 `tools/verify_combat_alarm_rally.gd` 覆盖；T1104 的双方基础伤害、盔甲减伤、攻击间隔、敌人移除、清敌退出和避战不攻击由 `tools/verify_combat_damage.gd` 覆盖；T1104A 的战斗时间上限、LLM 慢速叠加和清敌恢复由 `tools/verify_combat_time_cap.gd` 覆盖；T1104B 的艾达持剑第一波节奏和战斗动作秒换算由 `tools/verify_combat_pacing.gd` 覆盖；T1105 的兵种策略选项、NPC 面板策略下拉框、策略事件、默认策略重置、战斗内避战和保持距离射击由 `tools/verify_combat_strategies.gd` 覆盖；T1106 的战斗开始 / 结束广播、受伤 / 昏迷 / 击退统计和清敌回工作状态由 `tools/verify_combat_flow.gd` 覆盖；T1203 的完整逃离移动、离站标记和事件由 `tools/verify_escape_station_behavior.gd` 覆盖；T1204A 的逃离警告、NPC 面板入口、对话打开暂停、关闭恢复、五轮置灰、给钱减速、逃离攻击无回复计轮、昏迷暂停和复苏继续由 `tools/verify_escape_intervention_dialogue.gd` 覆盖；T1303 的无可战斗人员失败、未集结误判边界和 HUD / 快照原因由 `tools/verify_no_available_combatants_failure.gd` 覆盖；T1304 的第 5 波胜利、结算快照、HUD 胜利占位和结算后拒绝刷波由 `tools/verify_five_wave_victory.gd` 覆盖。
