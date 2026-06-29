# GODOT_ARCHITECTURE.md

## Godot 版本

目标版本：Godot 4.6

## 场景原则

- 场景负责表现和节点关系。
- 系统脚本负责逻辑。
- 数据来自 JSON 配置，不写死在场景中。
- 所有跨系统通信优先通过 EventBus 信号，不要互相硬引用。

## 推荐场景树

```text
Main
├─ WorldRoot
│  ├─ Station
│  │  ├─ Ground
│  │  ├─ Buildings
│  │  ├─ NPCs
│  │  ├─ Enemies
│  │  └─ Props
├─ Systems
│  ├─ TimeSystem
│  ├─ ResourceSystem
│  ├─ BuildingSystem
│  ├─ NPCSystem
│  ├─ ActionSystem
│  ├─ MemorySystem
│  ├─ CombatSystem
│  ├─ EquipmentSystem
│  ├─ LLMBridge
│  ├─ DailyPlanSystem
│  ├─ DailyReflectionSystem
│  ├─ UnconsciousSystem
│  └─ DialogSystem
├─ UI
│  ├─ HUD
│  ├─ NPCPanel
│  ├─ BuildingPanel
│  ├─ GMPanel
│  └─ DialogPanel
└─ CameraRig
```

## Autoload 建议

| 名称 | 路径 | 作用 |
|---|---|---|
| EventBus | `res://scripts/core/EventBus.gd` | 全局信号 |
| GameState | `res://scripts/core/GameState.gd` | 全局运行状态 |
| ConfigLoader | `res://scripts/core/ConfigLoader.gd` | 加载配置 |

## 当前 Autoload 实现

T0101 已在 `project.godot` 注册以下 Autoload：

| 名称 | 路径 | 当前状态 |
|---|---|---|
| MCPGameBridge | `res://addons/godot_mcp/game_bridge/mcp_game_bridge.gd` | Godot MCP 运行桥接；2026-06-17 升级到 Godot MCP `4.0.1` 后继续直接预加载 `mcp_runtime_state_sampler.gd`，并显式预加载 `key_names.gd`、`joy_names.gd`、`mcp_exec_guard.gd`，避免 `.godot` 全局类缓存缺少 helper class 时启动失败 |
| EventBus | `res://scripts/core/EventBus.gd` | 已声明基础事件信号 |
| GameState | `res://scripts/core/GameState.gd` | 已保存天数、小时、战斗状态 |
| ConfigLoader | `res://scripts/core/ConfigLoader.gd` | 已支持 JSON 读取和错误提示 |

T0102 已将 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 绑定到 Main 场景的 `Systems` 节点下；T0604 新增 `LLMBridge.gd` 并绑定到 `Main/Systems/LLMBridge`，T0604A 已将其传输层替换为 Godot 原生 `HTTPClient`；T0901 新增 `EquipmentSystem.gd` 并绑定到 `Main/Systems/EquipmentSystem`；T1004 新增 `DailyReflectionSystem.gd` 并绑定到 `Main/Systems/DailyReflectionSystem`。T0401 已实现 `TimeSystem.gd` 的基础时间推进、秒级显示、暂停、加速、跨天、逻辑时间倍率、LLM 等待减速请求，以及 `time_changed` / `time_scale_changed` / `logical_time_tick` / `hour_started` / `day_started` 信号；T1104A 新增 TimeSystem 时间倍率上限请求，CombatSystem 可在敌人在场时注册 `combat_enemy_presence` 上限。T0604/T0604A/T1005 已让 `LLMBridge` 在对话、每日计划、计划修订和首次睡眠总结请求前注册慢速请求，并在成功、失败、取消或超时后释放。T0202 已实现 `ResourceSystem.gd` 的基础资源读写和 HUD 同步；T0205 已实现 `BuildingSystem.gd` 的配置读取、低模建筑绑定、运行时点击区、`building_clicked` 选择事件、`building_state_changed` 状态刷新事件，以及倒计时修复/升级逻辑；T0304/T0409 已实现 `NPCSystem.gd` 从 `data/npc_profiles.json` 生成 8 个 NPC 占位实体、发出 `npc_clicked`、读取/更新 NPC 基础状态、调试移动到建筑入口，并在到达后发出 `npc_state_changed`；室内信息地点切换到另一个室内信息地点时，事件和地点信息层会插入广场中转链。T0501/T0502/T0503 已实现 NPC HP 扣除、`npc_hp_changed`、`npc_unconscious`、昏迷阻断移动/行动、昏迷自然恢复、协助治疗、`npc_revived`、自动复苏和昏迷/治疗/复苏事件写入。T0808 已实现小诊所医生工位、病床治疗、研读医术和诊所等级治疗效率。T0901 已实现 `EquipmentSystem` 从装备定义读取主武器、盔甲和坐骑，消耗派生库存写入 NPC 装备槽；T0902 已独立验收只读兵种判定与 `get_unit_type_snapshot(...)`，坐骑判定只读取 `equipment.mount` 槽；T0903 已实现训练场教官工位、受训位、当前装备决定训练项、教官/受训者熟练度成长和训练状态消耗；T0904 已实现 `NPCSystem` 统一成长结构、经验达标获得未分配技能点，以及玩家分配技能点到力量 / 智力。T0402 已将 `MemorySystem.gd` 升级为事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场事件查询；T0403 已在 `MemorySystem.gd` 中实现可进入地点信息节点、`people_present` 维护、进入快照和 `local_public` 即时广播；T0404/T0408/T0409 已统一广场即时广播、公告变更广播、建筑可传播外部状态广播和广场建筑外部状态快照为 `location_id == "plaza"` 的 `local_public`，且 NPC 进入广场时会在进入快照中获得当前在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态；T0405 已提供 NPC 短期记忆容器查询和玩家非对话交互事件调试写入口，仍不提供按地点查询事件的长期接口，地点/建筑节点不作为事件历史存储。T1004/T1005 起，首次睡眠总结完成后只清空指定 NPC 的当天短期事件/见闻索引，保留全局事件档案。T0407 已实现记忆降噪规则：进入/离开事件只保留行动事实，进入者获得一次状态见闻，已在场 NPC 只收进出事件，建筑/地点状态变化只广播变化字段。`ActionSystem.gd` 的工作 / 训练 / 协助修复 / 协助升级 / 协助治疗 / 诊所治疗 / 吃饭 / 睡觉调试行动闭环已写入结构化事件；工作、训练和诊所成长会写入 `skill_improved`，属性分配会写入 `attribute_improved`。T1101 已让 `CombatSystem.gd` 读取 `data/enemy_waves.json`，并在 `Station/Enemies` 下生成正门外低模敌人占位；T1102 已让敌人按逻辑时间选择目标、移动并攻击 NPC / 建筑，主厅清零会写入 `GameState` 失败占位；T1103 已让 HUD / GM 警铃触发入伍持武器 NPC 前往城门外集结，按近战前排 / 远程后排排列，写入警铃与集结事件，并在接敌时切换 `combat_ready` 占位；T1103A 已统一 `behavior_mode`，接入集结超时、接敌入战、清敌退出和昏迷复苏分流；T1103B/T1103C 已实现非战斗人员（未入伍或已入伍但无主武器）避战触发、按敌方方位短步长四散移动、清敌退出、避战中应征 / 装备分流和 `avoidance_started` / `avoidance_ended` 事件；T1104 已实现 combat 模式入伍持武器 NPC 的基础自动攻击、属性 / 防御伤害、攻击间隔、敌人 HP 扣除和清零移除；T1104A 已取消战斗数值与玩家时间倍率绑定，并在活动敌人存在时把 TimeSystem 有效倍率上限设为 `x1`；T1104B 已把攻击冷却从游戏秒换算到战斗动作秒，并校准第一波基础节奏；T1104C 已从敌人目标偏好中移除围墙，敌人破城门后直接转向仓库 / 主厅；T1105 已接入不同兵种战斗策略、玩家手动策略选择、策略状态快照和策略移动目标；T1106 已接入战斗开始 / 结束广场公开事件、当前战斗运行态和受伤 / 昏迷 / 击退统计；T1201/T1202 已接入战时公开对话心理结果和低血量自身心理判定；T1203 已接入逃离驿站行为，逃离 NPC 会前往后门外出口，离图后标记 `escaped` 并写入广场公开事件；T1204A 已接入逃离挽留 NPC 面板入口、对话暂停逃离移动、未满 5 轮关闭恢复、满 5 轮按钮置灰、给钱减速、逃离攻击加速且无 NPC 回复、昏迷暂停和复苏继续逃离。仍不实现正式胜负结算或命中率。

## 逻辑时间倍率原则

TimeSystem 不修改 `Engine.time_scale`，也不直接改变 NPC 移动、动画或物理速度。玩家设置的 `x1` / `x2` / `x4` 是逻辑时间倍率；当 LLMBridge、DialogSystem、计划系统或战斗判定等待模型返回时，可以调用 `TimeSystem.request_time_slowdown(request_id, scale, reason)` 注册慢速请求，完成、失败或超时后调用 `release_time_slowdown(request_id)`。

当前默认 LLM 等待倍率为 `1/60`，即在默认 `x1` 速度下从“现实 1 秒 = 游戏 1 分钟”减缓为“现实 1 秒 = 游戏 1 秒”。多个慢速请求同时存在时，TimeSystem 使用最慢的有效倍率。T1104A 起，TimeSystem 还支持时间倍率上限请求：CombatSystem 在活动敌人存在时注册 `combat_enemy_presence`，把有效倍率上限压到 `x1`；若 LLM 慢速更低，则继续使用更慢者。工作 / 日常状态、资源、计划打点、治疗和建筑倒计时系统应读取 `get_numeric_delta_multiplier()`、`get_game_delta_seconds(real_delta)` 或监听 `logical_time_tick(game_delta_seconds, numeric_multiplier)`，而不是读取真实帧率或 Godot 全局时间缩放。战斗伤害、攻击间隔、攻击速度和战斗移动速度不再读取玩家 `x2` / `x4` 作为额外倍率，只接受暂停、敌人在场上限和 LLM 慢速对全局推进节奏的影响。T1104B 起，CombatSystem 内部再把 `game_delta_seconds / 60` 转为战斗动作秒推进攻击冷却和战斗位移，防止默认 `x1` 的 60 游戏秒 / 现实秒被误用为 60 次战斗动作秒。

暂停与加速彼此独立。`SpeedButton` 只调用 `TimeSystem.cycle_speed()`，空格和 `PauseButton` 只调用 `TimeSystem.toggle_paused()`。暂停时 `get_numeric_delta_multiplier()` 返回 `0`，TimeSystem 不发出逻辑推进；NPC 移动通过 `is_gameplay_paused()` 停止，ActionSystem 的行动资源/状态结算会保持 pending，直到 `gameplay_pause_changed(false)` 后再继续。暂停不应冻结 UI、HTTP/后端请求或未来 LLM 对话/判定请求；这些请求返回后仍必须通过程序规则应用权威状态变化。

`UnconsciousSystem` 仍保留为后续治疗扩展模块规划，T0102 未创建该节点或脚本；当前 T0501/T0502/T0503 的扣血、昏迷、自然恢复、协助治疗和自动复苏最小闭环由 `NPCSystem.gd` 与 `ActionSystem.gd` 负责。

## 当前 Main 场景结构

```text
Main
├─ WorldRoot
│  └─ Station
│     ├─ Ground
│     ├─ Buildings
│     │  ├─ MainHall
│     │  ├─ Dormitory
│     │  ├─ DiningHall
│     │  ├─ Warehouse
│     │  ├─ Tavern
│     │  ├─ Garden
│     │  ├─ Blacksmith
│     │  ├─ TrainingGround
│     │  ├─ Stable
│     │  ├─ Chapel
│     │  ├─ Clinic
│     │  ├─ Workshop
│     │  ├─ NoticeBoard （主厅前公告牌视觉占位，非建筑数据）
│     │  ├─ FrontWall / BackWall / LeftWall / RightWall
│     │  ├─ FrontGate
│     │  └─ BackGate
│     ├─ NPCs
│     │  ├─ Stableman01
│     │  ├─ Cook01
│     │  ├─ Gardener01
│     │  ├─ Blacksmith01
│     │  ├─ VeteranDeputy01
│     │  ├─ Priest01
│     │  ├─ Doctor01
│     │  └─ Engineer01
│     ├─ Enemies
│     └─ Props
│        ├─ Plaza
│        ├─ FrontRoad
│        ├─ BackRoad
│        └─ MerchantEntranceMarker
├─ Systems
│  ├─ TimeSystem
│  ├─ ResourceSystem
│  ├─ BuildingSystem
│  ├─ NPCSystem
│  ├─ ActionSystem
│  ├─ MemorySystem
│  ├─ CombatSystem
│  ├─ EquipmentSystem
│  ├─ LLMBridge
│  ├─ DailyPlanSystem
│  ├─ DailyReflectionSystem
│  └─ DialogSystem
├─ UI
│  ├─ HUD
│  ├─ NPCPanel
│  ├─ BuildingPanel
│  ├─ GMPanel
│  └─ DialogPanel
├─ CameraRig
│  └─ Camera3D
└─ SunLight
```

T0103 已在 `Main.tscn` 直接放置低模驿站 Blockout：主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊，以及主厅前公告牌视觉占位均使用简单几何体和 `Label3D` 调试标签表示。2026-05-19 已扩大地面、围墙和相机视野，并拉开建筑间距，避免建筑过小过密；围墙四角已闭合，公告牌已缩小并移动到主厅正面。2026-06-12 为 T1101 扩大正门外地面与 `Props/FrontRoad`，使敌人可生成在正门外森林方向。该视觉占位不绑定 `data/building_defs.json`，不拥有 HP、等级、工作位、修复或升级；公告文本归广场状态保存。该阶段只提供空间占位和可辨认视觉结构，不实现生产、导航或战斗。

T0104 已在 `Main/UI/HUD` 下补齐基础 HUD：标题、天数、`HH:MM:SS` 时间/阶段、资源栏、速度按钮、暂停按钮、警铃按钮和后端状态。`Main/UI` 绑定 `res://scripts/ui/UIInputFocusManager.gd`，统一处理文本输入框点击外部失焦；`Main/UI/HUD` 绑定 `res://scripts/ui/HUD.gd`，负责显示和从 `GameState` 读取当前时间；T0401 后会监听 `EventBus.time_changed` / `hour_started` / `day_started`，并通过 `SpeedButton` 调用 `TimeSystem.cycle_speed()` 在 `x1`、`x2`、`x4` 间循环，通过 `PauseButton` 或空格调用 `TimeSystem.toggle_paused()`。T0012 后，HUD 会监听 `EventBus.resource_changed`，按 `ResourceSystem.get_resource_ids()` / `data/resource_defs.json.ui_order` 动态显示非聚合资源，并提供装备/器械详情按钮；详情面板贴近各自按钮左下并保持在屏幕内，只读取 `ResourceSystem`、`EquipmentSystem` 和 `NPCSystem`。T0604 后，HUD 读取 `Main/Systems/LLMBridge` 的后端状态，并监听 `backend_status_changed` 刷新 health check 结果。T1103 后，警铃按钮调用 `CombatSystem.trigger_combat_alarm("hud")`，不在 HUD 内自行决定 NPC 集结或战斗事实。T0205 已将 `Main/UI/BuildingPanel` 绑定 `res://scripts/ui/BuildingPanel.gd`：监听 `EventBus.building_clicked` 打开被点击建筑，监听 `EventBus.building_state_changed` 刷新当前可见建筑，从 `BuildingSystem` 读取名称、等级、HP、按类型分组的工位空闲数 / 总数与占用者、地点信息占位，并通过按钮触发 `BuildingSystem` 的修复/升级接口；T0016 后不再显示单独的“当前工作位 x/x”汇总行；修复/升级消耗和条件只在按钮悬停提示框中显示，进行中会显示倒计时进度、剩余时间、速度倍率和协助人数。

T0604 已新增 `res://scripts/systems/LLMBridge.gd`，T0604A 已把请求传输层替换为 Godot 原生 `HTTPClient` 状态机：支持后端地址配置、`check_health()`、`request_npc_dialogue(...)`、`request_npc_daily_plan(...)`、`request_npc_plan_revision(...)` 和 `request_npc_daily_reflection(...)`，不再依赖 Windows `curl.exe`、命令行 JSON 转义或临时请求体文件。T1006 新增 `request_npc_dialogue_async(...)` 供玩家对话 UI 使用：它会登记 NPC LLM 活动和 TimeSystem 慢速，在后台完成 HTTP 请求，并允许结束对话时通过 request id 取消、释放慢速和丢弃结果；既有同步 `request_npc_dialogue(...)` 仍保留给脚本验证和非 UI 调用。`LLMBridge.build_npc_dialogue_payload(...)` 会按 T0603/T1201 Schema 收集目标 NPC 设定、权威状态、短期记忆、长期记忆、地点快照、说话者上下文、对话公开性、轮次、战时 `interaction_context` 和必要时的 `battlefield_context`；守备官发起时 `speaker_name` 固定为“守备官”。T1003 的 `build_npc_daily_plan_payload(...)` 会收集共享 NPC 上下文、当前 `current_order`、行动白名单、资源快照、建筑状态和计划规则；T1002 的计划修订 payload 复用同一 NPC 上下文边界；T1004 的 `build_npc_daily_reflection_payload(...)` 会收集共享 NPC 上下文、当天事件 / 见闻摘要和既有日记。该桥只返回后端 JSON 或错误字典，不写入 `MemorySystem` 对话事件，不修改入伍状态，也不调用真实 LLM。正式架构下 Godot 导出客户端只请求游戏服务器后端，不保存供应商 API Key，也不直连模型供应商。

T0701/T0702 已将 `res://scripts/systems/DialogSystem.gd` 升级为 Godot 侧对话与征召结果权威入口，并新增 `res://scripts/ui/DialogPanel.gd`。DialogSystem 维护参与者、历史、公开性、轮次和一次性应征请求标记，调用 LLMBridge 后把对话事件写入 MemorySystem；合法 `accept` 结果通过 `NPCSystem.set_npc_recruited(...)` 更新入伍状态，`reject` 不改变状态。玩家-NPC 对话不限轮次，NPC-NPC 对话默认最多 5 轮。T1006 起，NPC 面板“对话”只打开 DialogPanel，不打断行动、不取消 LLM、不请求重评估；玩家实际发送消息或在对话窗攻击后，才进入打断、取消和 LLM 等待逻辑。DialogPanel 等待回复时保持输入框可编辑、禁用发送 / 攻击按钮；结束等待中的普通消息会取消异步 LLM 且不入库，结束等待中的攻击会保留已写入的伤害事件并触发一次计划重评估。T1103A 起，行为模式切换可通过 `force_end_dialogue_for_npc(...)` 强制关闭当前对话并取消未完成 LLM 回复；T1201 起，集结 / 战斗 / 避战模式下玩家对话强制公开，注入 `battlefield_context`，并把 `wartime_reaction` 交给 CombatSystem 应用。T1204A 起，逃离挽留由 NPC 面板【对话】调用 `start_escape_intervention_dialogue(...)` 进入；打开时暂停逃离移动，关闭、攻击或满 5 轮时恢复，逃离攻击走无 LLM 回复分支。

T0703 已把 NPCPanel 的已入伍占位按钮替换为独立 `OrderPanel` 自然语言指令面板；NPCSystem 权威保存 `current_order`，MemorySystem 写入 `private` `order_assigned`，并通过 `EventBus.npc_plan_reevaluation_requested` 发出统一重评估请求。UI 不直接调用 ActionSystem 启动具体行动，也不决定 NPC 是否服从。T0014 后 `DialogPanel` 与 `OrderPanel` 在中央弹窗层互斥：打开对话会关闭指令，打开指令会结束 / 关闭当前对话；二者都不会自动关闭右上角 `NPCPanel`。T0703A/T1002/T1003 让 LLMBridge 和后续计划/判定请求统一收集当前指令，并由 `DailyPlanSystem` 消费计划生成或重评估请求、应用 Mock 计划 / 当前小时修订计划或规则降级计划。T0705 新增 NPC 主动找守备官交涉闭环：`NPCSystem` 保存 `proactive_talk` 状态并随 `logical_time_tick` 超时，`NPC.gd` 运行时显示问号气泡，点击时优先调用 `DialogSystem.start_proactive_player_dialogue(...)` 打开既有对话面板，`MemorySystem` 写入 `proactive_talk_started` / `proactive_talk_message`，对话结束或超时后继续走统一计划重评估请求。

T1001 已新增 `res://scripts/systems/DailyPlanSystem.gd` 并挂载到 `Main/Systems/DailyPlanSystem`。它生成规则版 24 小时计划，保存到 NPC `plan` 字段并写入 `plan_created`；计划执行监听 `hour_started`，只接管已经显式生成计划的 NPC。执行计划项时复用 `ActionSystem`，小时切换且行动不同时通过 `ActionSystem.interrupt_npc_action(...)` 安全释放旧行动占用；同一小时内由计划启动的行动提前完成后会再执行当前小时项。T1003 后，`generate_daily_plan_for_npc(...)` 优先调用 `LLMBridge.request_npc_daily_plan(...)` 请求 `/npc/plan_day`，成功时写入 `plan_created(source=mock_plan_day)`，后端不可用、输出不合法、不是 24 阶段或工作阶段不足时写入 `plan_created(source=rule_plan_fallback)` 并使用规则计划。T1002 后，该系统监听 `npc_plan_reevaluation_requested` 和行动失败状态，调用 `LLMBridge.request_npc_plan_revision(...)` 请求 `/npc/revise_plan`，成功时写入 `plan_revised` 并执行当前小时修订项，失败时写入 `rule_revision_fallback` 计划。每日计划和计划修订请求期间由 LLMBridge 申请 / 释放 TimeSystem 慢速。

T1004/T1005 已新增 `res://scripts/systems/DailyReflectionSystem.gd` 并挂载到 `Main/Systems/DailyReflectionSystem`。它监听 `EventBus.event_recorded` 中的 `sleep_started` / `sleep_ended` 和 `logical_time_tick`，每名 NPC 每天首次睡觉并持续睡眠满 1 游戏小时后调用 `LLMBridge.request_npc_daily_reflection(...)` 请求 `/npc/daily_reflection`；后端失败或输出无效时使用本地模板。成功结果通过 `NPCSystem.apply_daily_reflection(...)` 写入长期日记和知识图谱占位，再通过 `MemorySystem.clear_npc_short_term_memory(...)` 清空该 NPC 当天短期事件/见闻索引。该请求会申请 TimeSystem 慢速，且从发起到应用完成期间通过 NPCSystem 的首次睡眠总结锁阻止对话、发消息、行动中断和行动改派。

T0105 已将 `res://scripts/camera/CameraRig.gd` 绑定到 `Main/CameraRig`：玩家可用 WASD 平移、鼠标中键拖拽平移、滚轮缩放；脚本只移动 `CameraRig` 的 X/Z 位置和 `Camera3D` 的本地距离，保留高机位俯视角，并通过导出参数限制移动边界和缩放距离。T1101 后 Z 轴正向边界扩到可观察正门外敌人生成区。该阶段不实现角色控制或自由第一人称视角。

T0202 已在 `res://scripts/systems/ResourceSystem.gd` 中实现基础资源系统：启动时读取 `data/resource_defs.json` 初始化第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁，提供 `get_resource`、`get_resource_definition`、`get_resource_ids`、`add_resource`、`can_afford`、`spend_resources` 与临时调试接口。所有资源变化通过 `EventBus.resource_changed` 通知 UI；资源不足时 `spend_resources` 返回 `false`，不扣除也不产生负数。T0012 后 HUD 主栏直接显示非聚合资源，武器、盔甲、马匹整备和工程器械在装备/器械详情面板中查看；派生资源仍由行动、装备或后续交易/器械部署系统权威结算。

T0205 已在 `res://scripts/systems/BuildingSystem.gd` 中实现基础建筑系统：启动时读取 `data/building_defs.json`，按 `scene_nodes` 绑定 `Main/WorldRoot/Station/Buildings` 下的低模建筑节点，为绑定节点创建运行时 `Area3D/CollisionShape3D` 点击区，并在左键点击时发出 `EventBus.building_clicked(building_id)`；建筑受损、修复/升级进度、协助者变化、修复完成和升级完成会发出 `EventBus.building_state_changed(building_id)`。建筑调试标签会显示名称、等级和 HP，并在修复/升级后刷新。2026-05-24 起，`NoticeBoard` 从建筑定义中移除，只作为主厅前公告牌视觉占位和公告输入/显示接口，公告文本由广场状态保存。2026-05-20 修正后，建筑点击同时通过 `_unhandled_input` 的相机射线拾取点击区，避免全屏 UI 背板或项目拾取设置导致真实鼠标点击失效。T0304 起，建筑系统提供 `get_building_entry_position(...)` 和 `get_building_location_context(...)`，分别用于 NPC 移动目标点与地点当前状态读取占位；该占位不应包含建筑过去事件，也不把 HP、剩余修复/升级时长或工位数量作为 NPC 可传播状态。T0801 起，建筑系统提供 `claim_workstation(...)` / `release_workstation(...)` 作为工位占用权威接口，ActionSystem 通过这些接口占用/释放工作位，MemorySystem 只读取工位状态并广播差量。修复/升级由 `BuildingSystem` 调用 `ResourceSystem.spend_resources` 结算；资源不足时不会改变建筑状态。升级只有在建筑完好且未处于修复/升级作业时可开始。T1102 起，战斗系统通过 `apply_damage_to_building(...)` 扣除建筑 HP，并写入 `building_damaged` 结构化事件；该入口仍由 BuildingSystem 作为权威状态修改点。

T0304 已新增 `res://scenes/npc/NPC.tscn` 和 `res://scripts/npc/NPC.gd`，并在 `res://scripts/systems/NPCSystem.gd` 中实现基础 NPC 生成、状态接口和直线移动占位：启动时读取 `data/npc_profiles.json`，实例化 8 个 NPC 到 `Main/WorldRoot/Station/NPCs`，每个 NPC 保存唯一 `npc_id`，主场景 `Label3D` 调试标签只显示短姓名、HP 和当前行动。NPC 点击会打印 ID 并通过 `EventBus.npc_clicked(npc_id)` 广播；`NPCSystem` 同时提供 `get_npc(...)`、`get_npc_state(...)`、`get_npc_ids()`、`get_npc_count()`、`update_npc_state(...)`、`set_npc_state_value(...)`、固定熟练度枚举、`normalize_skills(...)`、`get_npc_specialties(...)`、`increase_npc_skill(...)`、`get_npc_progression(...)`、`assign_npc_attribute_point(...)`、`debug_assign_attribute_point(...)`、`debug_select_npc(...)`、`move_npc_to_building(...)`、`debug_move_npc_to_building(...)`、`debug_move_selected_npc_to_building(...)` 和 `debug_enter_location_immediately(...)`。T1103 后还提供 `move_npc_to_world_position(...)` 和 `stop_npc_movement_with_state(...)`，供 CombatSystem 以世界坐标发起城门外集结、接敌时停止移动并切换状态。T1103A 起，NPC 运行时状态统一保存 `behavior_mode = work|rally|combat|avoid_combat|unconscious|escaped`、进入原因和进入时间，T1103 的 `combat_mode` 仅作为旧集结 / 坐骑视觉兼容字段保留。每名 NPC 的技能会归一化为 8 个职业熟练度加 5 个武器熟练度，专长由高熟练度推导，不使用硬职业枚举；运行时 `progression` 记录各熟练度经验、总经验、未分配技能点和已分配技能点。技能点由玩家分配到力量或智力，AI 不自动消耗。移动开始时 NPC 状态进入 `moving_to_<building_id>` 或系统指定的移动状态；到达后通过 `MemorySystem.move_npc_between_locations(...)` 更新地点 `people_present`，写入 `current_location`、`current_location_name` 和 `location_context`，并发出 `EventBus.npc_state_changed(npc_id)`。T0409 起，室内信息地点到室内信息地点的切换会在事件与地点信息层插入广场中转；物理移动仍是低模直线占位。T1103A 后 `NPC.gd` 运行时优先按 `behavior_mode` 为 `rally` / `combat` 时显示集结 / 接敌朝向标记，并兼容旧 `combat_mode`；只有 `combat_mounted == true` 的 NPC 显示低模坐骑；T1105 后策略移动会显示“战术移动”行动摘要。进入地点只读取当前地点状态快照，不继承该地点过去事件。该阶段不实现复杂避障、自然状态变化、真实日程计划、正式战斗结算或 LLM。

T0402 后，`res://scripts/systems/ActionSystem.gd` 的简单行动系统会在行动开始、完成或失败时写入结构化事件：工作路径写入 `work_started`、`work_completed`、`work_failed`，协助修复写入 `repair_assist_started`，协助升级写入 `upgrade_assist_started`，协助治疗和诊所治疗写入 `healing_started` / `healing_completed`，吃饭路径写入 `eat_started`、`eat_completed`，睡觉路径写入 `sleep_started`、`sleep_ended`，工作 / 研读医术 / 训练成长写入 `skill_improved`。行动仍会先检查 NPC 是否可行动，必要时调用 `NPCSystem.move_npc_to_building(...)` 前往目标地点；到达后进入持续行动状态，并通过 `EventBus.logical_time_tick` 按逻辑秒推进，不再瞬时结算完整结果。吃饭当前 1200 秒恢复约 50 点饱食度；睡觉当前 23400 秒降低 100 点疲劳，且睡觉期间 `MemorySystem.add_witness_event(...)` 不会给该 NPC 写入地点/建筑 public 见闻；T0801 后工作以配置 `duration_seconds` 为单位周期基准，开始时占用目标建筑工位，实际周期时长按 NPC 对应熟练度、力量/智力属性和建筑等级缩短，单位结束时结算资源输入/输出、饱食消耗和疲劳增长，完成、失败或中断时释放工位。T0803 后，工作可选 `output_scaling` 产出缩放；当前菜园粮食产出会按耕种熟练度、力量和菜园等级提高实际产量，完成事件记录缩放后的产出。T0804 后铁匠铺消耗铁产出武器/盔甲派生库存；T0805 后工械坊消耗木材产出武器/工程器械派生库存，工程和智力影响制作效率；T0806 后马厩消耗粮食产出马匹整备派生库存，养马、力量和马厩等级影响制作效率与实际产出；T0807 后酒窖消耗粮食产出酒库存，酿酒、智力和酒窖等级影响制作效率与实际产出，出售换钱留给商人交易系统。T0808 后小诊所包含医生工位和病床：医生在岗且病人占床时治疗才推进，治疗按逻辑时间消耗第纳尔并恢复 HP，速度由医术、智力和诊所等级提高；医生无病人时缓慢研读医术。T0903 后训练场包含教官工位和受训位：无装备不能训练或执教，受训者需要已有教官，教官独处时提升自己当前装备对应武器 / 骑术，有受训者时受训者按自己的装备提升对应熟练度且教官提升“教练”，训练按逻辑时间消耗疲劳和饱食。T0904 后，工作完成、诊所研读 / 治疗、训练场成长都会调用 `NPCSystem.increase_npc_skill(...)`，同步写入经验和未分配技能点。协助修复/协助升级是带 `building_id` 参数的运行时广场行为，事件 `location_id == "plaza"` 且 `visibility == "local_public"`；建筑 HP、资源预付和倒计时由 `BuildingSystem` 结算。协助治疗是带昏迷 NPC 目标的运行时行为，治疗者前往目标所在信息地点，每个目标最多 2 名治疗者，按逻辑时间消耗第纳尔，并调用 `NPCSystem.assist_unconscious_recovery(...)` 按医术熟练度加速 HP 恢复；`ActionSystem.get_healing_helpers_for_target(...)` 仅供信息节点读取当前治疗者，不参与结算。若游戏处于暂停，未到达目标的行动保留在 pending 队列中，已开始的行动保留在 active 队列中，不推进资源消耗/产出或状态变化；恢复后继续。当前已按 `game_design.md` 覆盖菜园、食堂、酒窖、铁匠铺、工械坊、马厩、小诊所、训练场、协助修复、协助升级、协助治疗、吃饭和睡觉的最小效果；不实现 LLM 日程、商人交易、工程器械部署、战斗或其他职业特殊生产平衡。

T0901 已新增 `res://scripts/systems/EquipmentSystem.gd`：系统读取武器、盔甲和坐骑定义，消耗 `weapons` / `armor` / `horse_readiness` 派生库存，把装备写入已入伍 NPC 的 `equipment` 槽位，并通过 `MemorySystem.record_player_interaction(...)` 记录装备给予或更换事件。T0902 起，兵种判定只根据 `equipment.main_weapon` 与 `equipment.mount` 返回分类标签和只读快照；`horse_readiness` 库存本身不会让 NPC 被判定为骑兵。T1103 起，CombatSystem 只读兵种快照决定集结前后排和是否显示战斗坐骑，NPC 日常工作不会因坐骑库存或装备而自动骑乘。UI 和 GM 面板只调用装备系统接口，不自行决定装备事实或兵种结果。T1104 后，CombatSystem 会读取主武器数值、盔甲防御和坐骑槽参与基础攻击与攻速修正；EquipmentSystem 本身仍不执行伤害结算、耐久或完整外观换装。

T0303 已将 `Main/UI/NPCPanel` 绑定 `res://scripts/ui/NPCPanel.gd`：监听 `npc_clicked` 显示姓名、LLM 状态、专长、HP、力量 / 智力、经验、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、职业熟练度和武器熟练度；监听 `npc_state_changed` 刷新当前 NPC 数据；监听 `building_clicked` 时隐藏自身。T0015 后 NPC 面板将经验以 `经验：当前 / 阈值` 显示在 HP 右侧，并只在存在未分配技能点时于力量 / 智力数值旁显示 `+1` 按钮，按钮调用 `NPCSystem.assign_npc_attribute_point(...)`。T0014 后事件库和见闻库使用固定高度滚动区，刷新时自动滚到底部，避免记忆增长撑高面板；T1004/T1005 后日记也使用固定高度滚动区显示长期首次睡眠总结，名字旁显示“正在思考 / 正在计划下一步行动 / 正在熟睡”。T1103A 后“当前行动”行会同时显示当前行为模式，区分工作 / 集结 / 战斗 / 避战 / 昏迷。T1204A 后，逃离 NPC 被点击仍打开 NPC 面板；【对话】按钮按剩余挽留轮次启用或置灰。`BuildingPanel` 也会在 `npc_clicked` 时隐藏，确保 NPC/建筑面板互斥切换。

T0004 已将 `Main/UI/GMPanel` 绑定 `res://scripts/ui/GMPanel.gd`：开发模式下显示半透明可拖动 `GM` 按钮，点击后打开 GM 调试面板。面板只调用已有系统接口或 `debug_*` 接口，覆盖资源、时间、建筑、NPC、行动、地点信息、广场公告和短期记忆等关键调试入口；T0503 后行动区包含治疗目标下拉与协助治疗按钮；T0014 后普通行动入口收敛为行动下拉 + “指定行动”，带目标参数的协助入口继续保留；T0904 后 NPC 分组包含技能点分配入口，并支持 `assign_attribute <npc_id> <strength|intelligence>` 命令；T0015 后 NPC 分组新增“设为入伍”按钮，并支持 `recruit_npc <npc_id>` 命令；T1004/T1005 后 NPC 分组新增首次睡眠总结、长期记忆和最近总结入口，并支持 `reflect_npc`、`long_memory`、`reflection_result`、`llm_state` 命令；T1101 后新增“战斗 / 敌人”分组和 `spawn_wave` / `enemy_wave` / `enemies` / `clear_enemies` 命令；T1102 后新增“推进敌人AI”按钮和 `step_enemies [game_seconds]` 命令；T1103 后新增“警铃集结”按钮和 `alarm` / `rally` 命令，调用 CombatSystem 的警铃入口并显示集结结果摘要；T1103A 后新增“行为模式快照”“推进集结等待”按钮和 `behavior_modes` / `advance_rally_wait [game_seconds]` 命令，用于查看模式状态和验证 1 游戏小时集结等待超时；T1104 后，`step_enemies` 同时推进我方基础自动攻击并在快照中暴露最近我方攻击结果；顶部 `GM_ENABLED` 常量可在开发/上线模式间切换显示。

## 重要信号建议

```gdscript
signal day_started(day: int)
signal time_changed(day: int, hour: int, minute: int, second: int)
signal time_scale_changed(player_scale: float, effective_scale: float, numeric_multiplier: float, reason: String)
signal logical_time_tick(game_delta_seconds: float, numeric_multiplier: float)
signal hour_started(day: int, hour: int)
signal resource_changed(resource_id: String, amount: int)
signal npc_state_changed(npc_id: String)
signal npc_daily_plan_changed(npc_id: String, plan: Array)
signal npc_proactive_talk_changed(npc_id: String, active: bool)
signal npc_hp_changed(npc_id: String, hp: int, max_hp: int)
signal npc_unconscious(npc_id: String)
signal npc_clicked(npc_id: String)
signal building_clicked(building_id: String)
signal building_state_changed(building_id: String)
signal dialogue_requested(npc_id: String)
signal recruitment_changed(npc_id: String, recruited: bool)
signal battle_started(wave_id: int)
signal battle_ended(wave_id: int)
signal npc_revived(npc_id: String)
signal event_recorded(event: Dictionary)
signal npc_memory_changed(npc_id: String)
signal location_info_changed(location_id: String)
signal public_event_added(event: Dictionary)
```

## 命名规范

- 场景：`PascalCase.tscn`
- 脚本：`PascalCase.gd`
- JSON 配置：`snake_case.json`
- 节点名：明确表达用途，如 `NPCContainer`, `BuildingContainer`
- 信号名：动词过去式或事件式，如 `npc_unconscious`, `resource_changed`

## 不要做

- 不要把游戏所有逻辑塞进 `Main.gd`。
- 不要在 NPC 节点里直接调用所有系统。
- 不要在 UI 脚本里修改底层数据，UI 应调用系统接口。
- 不要在场景里手填大量 NPC 数值。
- 不要手改大型 `.tscn` 导致场景损坏。
