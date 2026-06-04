# MODULE_INDEX.md

> 本文件用于帮助 Agent 快速找到模块位置。
> 每新增、移动、删除重要代码文件，都必须更新这里。

## 文档入口

| 内容 | 文件 |
|---|---|
| 完整玩法设计源 | `game_design.md` |
| Agent 规则 | `AGENTS.md` |
| 项目简报 | `docs/PROJECT_BRIEF.md` |
| 当前状态 | `docs/CURRENT_STATE.md` |
| 任务列表 | `docs/TASKS.md` |
| 技术架构 | `docs/TECH_ARCHITECTURE.md` |
| Godot 架构 | `docs/GODOT_ARCHITECTURE.md` |
| 代码规范 | `docs/CODING_RULES.md` |
| 数据结构 | `docs/DATA_SCHEMA.md` |
| AI NPC 系统 | `docs/AI_NPC_SYSTEM.md` |
| 记忆与信息节点 | `docs/MEMORY_AND_INFO_SPACE.md` |
| 经济与建筑 | `docs/ECONOMY_AND_BUILDINGS.md` |
| 战斗系统 | `docs/COMBAT_SYSTEM.md` |
| UI | `docs/UI_UX.md` |
| GM 调试面板 | `docs/GM_PANEL.md` |
| Prompt | `docs/PROMPTS.md` |
| API 成本 | `docs/API_BUDGET.md` |
| 长期记忆 | `docs/LONG_TERM_MEMORY.md` |
| 开发日志 | `docs/DEV_LOG.md` |
| 变更记录 | `docs/CHANGELOG.md` |

## Godot 模块规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 主场景 | `res://scenes/main/Main.tscn` | 游戏入口 |
| 驿站地图 | `res://scenes/world/Station.tscn` | 低模驿站 |
| NPC 场景 | `res://scenes/npc/NPC.tscn` | 通用 NPC 实体 |
| 敌人场景 | `res://scenes/enemy/Enemy.tscn` | 通用敌人实体 |
| 建筑场景 | `res://scenes/buildings/Building.tscn` | 通用建筑实体 |
| UI 主界面 | `res://scenes/ui/HUD.tscn` | 资源、时间、按钮 |
| 对话 UI | `res://scenes/ui/DialogPanel.tscn` | NPC 对话 |
| NPC 面板 | `res://scenes/ui/NPCPanel.tscn` | 状态、装备、按钮 |
| 建筑面板 | `res://scenes/ui/BuildingPanel.tscn` | 建筑信息 |
| GM 调试面板 | `res://scripts/ui/GMPanel.gd` | 开发验证入口 |

## Godot 当前已创建

路径：`project.godot`
用途：Godot 项目配置，当前启动场景为 `res://scenes/main/Main.tscn`，并注册 `MCPGameBridge`、`EventBus`、`GameState`、`ConfigLoader` Autoload。
依赖：Godot 4.6，`addons/godot_mcp` 自动加载配置。
当前状态：T0101 已验证可打开并运行，核心 Autoload 加载无报错。

路径：`res://scenes/main/Main.tscn`
用途：最小可运行主场景，包含 `WorldRoot/Station/Ground`、`WorldRoot/Station/Buildings`、`WorldRoot/Station/NPCs`、`WorldRoot/Station/Enemies`、`WorldRoot/Station/Props`、`Systems/*`、`UI/HUD`、`UI/NPCPanel`、`UI/BuildingPanel`、`UI/DialogPanel`、`UI/GMPanel`、`CameraRig/Camera3D`、`SunLight`。`Systems` 下已包含 `LLMBridge`。`Buildings` 下已有主厅、宿舍、食堂、仓库、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、围墙、城门、后门等低模建筑/门墙占位，并保留主厅前 `NoticeBoard` 视觉占位；`NoticeBoard` 不绑定建筑定义，不具备 HP / 等级 / 工作位。`Props` 下已有广场、正门道路、后门道路和商人入口占位；`UI/HUD` 下已有标题、天数、`HH:MM:SS` 时间/阶段、资源占位、速度按钮、暂停按钮、警铃按钮占位和后端状态；`UI/NPCPanel` 和 `UI/BuildingPanel` 已接入右上角信息面板；`UI/GMPanel` 已接入可拖动半透明 GM 调试按钮和面板；`CameraRig` 已挂载基础俯视摄像机控制。
依赖：绑定 `res://scripts/systems/TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 作为系统脚本，绑定 `res://scripts/ui/HUD.gd` 和 `res://scripts/ui/GMPanel.gd` 作为 UI 脚本，并绑定 `res://scripts/camera/CameraRig.gd` 作为相机控制脚本。
当前状态：T0403/T0409 已完成地点信息节点与进入快照；T0401 已完成基础 TimeSystem，HUD 时间以 `HH:MM:SS` 推进，速度按钮可切换 `x1` / `x2` / `x4`，暂停按钮和空格可暂停/继续，空格不触发加速；T0305 已完成 NPC 工作 / 吃饭 / 睡觉最小行动闭环，并按 `game_design.md` 补齐酒窖、铁匠铺、工械坊、马厩、协助修复和协助升级的最小效果；低模驿站、HUD 信息、建筑调试标签和 NPC 调试标签可见，可用 WASD/鼠标中键/滚轮查看驿站；建筑节点运行时具备点击区并可发出 `building_clicked`，右上角建筑面板可显示被点击建筑的基础信息并触发倒计时修复/升级；NPC 点击可发出 `npc_clicked` 并打开 NPC 面板；可通过调试接口让 NPC 直线移动到指定建筑，或安排工作、协助修复、协助升级、吃饭、睡觉，到达后更新地点 `people_present`、写入只含行动事实的 `location_entered` / `location_exited`，并给进入者写入一次地点快照见闻；室内到室内切换会在事件与地点信息层经由广场，再进入持续行动。吃饭、睡觉和工作通过 `logical_time_tick` 推进，完成后结算资源/状态并写入结构化事件。暂停期间 NPC 移动与行动结算停止，未开始行动保持 pending，已开始行动保持 active，恢复后继续；建筑修复和升级进度也随逻辑时间暂停/加速。未实现真实日程、复杂生产效率或战斗。

路径：`res://scenes/world/`, `res://scenes/npc/`, `res://scenes/enemy/`, `res://scenes/buildings/`, `res://scenes/ui/`
用途：后续世界、NPC、敌人、建筑和 UI 场景目录。
依赖：暂无。
当前状态：目录已创建，具体场景待后续任务实现。

路径：`res://scripts/core/`, `res://scripts/systems/`
用途：后续核心单例与系统脚本目录。
依赖：暂无。
当前状态：T0101 已创建核心 Autoload 脚本与部分系统占位脚本。

路径：`res://scripts/core/EventBus.gd`
用途：全局事件总线，声明基础跨系统信号。
依赖：作为 Autoload 注册于 `project.godot`。
当前状态：T0502 后已包含 `resource_changed`、`time_changed`、`time_scale_changed`、`logical_time_tick`、`gameplay_pause_changed`、`day_started`、`hour_started`、`building_clicked`、`building_state_changed`、`npc_clicked`、`npc_state_changed`、`npc_hp_changed`、`npc_unconscious`、`npc_revived`、`event_recorded`、`npc_memory_changed`、`location_info_changed`、`public_event_added`。

路径：`res://scripts/core/GameState.gd`
用途：全局运行状态，保存当前天数、小时、分钟、秒和是否处于战斗中。
依赖：作为 Autoload 注册于 `project.godot`；需要广播时通过 `/root/EventBus` 查找事件总线。
当前状态：T0101 已创建；仅提供最小状态字段和设置接口。

路径：`res://scripts/core/ConfigLoader.gd`
用途：统一 JSON 配置读取入口。
依赖：作为 Autoload 注册于 `project.godot`；使用 Godot `FileAccess` 和 `JSON`。
当前状态：T0101 已创建；文件缺失、打开失败、解析失败时会 `push_error` 并返回默认值。

路径：`res://scripts/systems/TimeSystem.gd`
用途：基础逻辑时间系统，负责 24 小时阶段、秒级显示、暂停、加速、跨天、LLM 等待减速和数值倍率出口。
依赖：读取 `/root/GameState`，通过 `/root/EventBus.time_changed`、`time_scale_changed`、`logical_time_tick`、`hour_started` 与 `day_started` 广播时间变化；由 `HUD.gd` 的 `SpeedButton` 调用 `cycle_speed()`，由 `PauseButton` 和空格调用 `toggle_paused()`；后续 LLMBridge / DialogSystem 调用 `request_time_slowdown(...)` 与 `release_time_slowdown(...)`。
当前状态：T0401 已实现；默认现实 1 秒 = 游戏内 1 分钟，HUD 显示 `HH:MM:SS` 并随游戏秒刷新，支持 `x1` / `x2` / `x4` 速度切换和独立暂停/继续；空格只切换暂停，不改变速度倍率；已提供 LLM 等待时 `1/60` 有效逻辑倍率与 `get_numeric_delta_multiplier()` / `get_game_delta_seconds(...)` 接口；尚未把战斗、每日计划或真实 LLM 请求接入该倍率。

路径：`res://scripts/systems/ResourceSystem.gd`
用途：资源系统占位脚本。
依赖：通过 `/root/ConfigLoader` 读取 `data/resource_defs.json`，通过 `/root/EventBus.resource_changed` 广播资源变化，供 HUD 刷新。
当前状态：T0202 已实现基础资源读写；支持 `get_resource(id)`、`add_resource(id, amount)`、`can_afford(cost_dict)`、`spend_resources(cost_dict)`，并提供调试入口验证增减资源和超额扣除失败。

路径：`res://scripts/systems/BuildingSystem.gd`
用途：基础建筑系统，负责建筑配置读取、场景节点绑定、点击识别和基础状态查询。
依赖：通过 `/root/ConfigLoader` 读取 `data/building_defs.json`，绑定 `Main/WorldRoot/Station/Buildings` 下的低模建筑节点，并通过 `/root/EventBus.building_clicked` 广播点击选择、通过 `/root/EventBus.building_state_changed` 广播状态刷新。
当前状态：T0304 已实现基础建筑数据读取、场景节点绑定、运行时点击区、调试标签状态显示、`get_building(...)` 等查询接口、建筑入口坐标查询 `get_building_entry_position(...)`、地点当前状态占位 `get_building_location_context(...)` 和最小修复/升级逻辑；2026-05-20 已补充 `_unhandled_input` 相机射线拾取，真实鼠标点击建筑可稳定触发 `building_clicked`。T0006 后建筑受损、修复进度、协助者变化、修复完成和升级只触发 `building_state_changed`，不再伪装为建筑点击。修复/升级消耗由 `ResourceSystem` 结算，资源不足时不会改变建筑状态；修复和升级都会创建随 `logical_time_tick` 推进的倒计时作业，并可被多个 NPC 按工程熟练度协助加速；建筑受损、正在修复或正在升级时不能开始升级，只有完好建筑可升级；协助者离开对应建筑或被改派时会从作业中移除；建筑/地点节点后续只保存当前状态并负责广播，不保存事件历史；仍不实现生产或敌人攻击。

路径：`res://scripts/systems/NPCSystem.gd`
用途：基础 NPC 系统，负责读取 NPC 档案、生成 NPC 占位实体和转发 NPC 点击事件。
依赖：通过 `/root/ConfigLoader` 读取 `data/npc_profiles.json`，实例化 `res://scenes/npc/NPC.tscn` 到 `Main/WorldRoot/Station/NPCs`，并通过 `/root/EventBus.npc_clicked` 广播点击事件。
当前状态：T0403/T0409 后，移动到达会通过 `MemorySystem.move_npc_between_locations(...)` 更新地点 `people_present` 并写入进入快照；室内信息地点切换到另一个室内信息地点时，会在事件与地点信息层插入“离开原地点 -> 进入广场 -> 离开广场 -> 进入目标地点”的中转链，物理表现仍是直线移动占位。T0304 已实现 8 名初始 NPC 生成、唯一 ID 保存、`get_npc(...)` / `get_npc_state(...)` / `get_npc_ids()` / `get_npc_count()` 查询接口、`update_npc_state(...)` / `set_npc_state_value(...)` 状态修改接口、固定熟练度枚举、`normalize_skills(...)`、`get_npc_specialties(...)`、`debug_select_npc(...)` 调试选择，以及 `move_npc_to_building(...)` / `debug_move_npc_to_building(...)` / `debug_move_selected_npc_to_building(...)` 基础移动接口；新增 `debug_enter_location_immediately(...)` 用于验证地点信息节点；状态修改和移动到达都会发出 `npc_state_changed`。T0501/T0502/T0503 已实现 `apply_damage_to_npc(...)`、`debug_damage_npc(...)`、`debug_advance_unconscious_recovery(...)` 和 `assist_unconscious_recovery(...)`；昏迷 NPC 随 `logical_time_tick` 自然恢复，达到 Max HP 30% 后复苏并发出 `npc_revived`，协助治疗可按医术熟练度加速恢复。仍不实现复杂避障、对话、征召、敌人战斗、完整诊所治疗或 LLM。

路径：`res://scripts/npc/NPC.gd`
用途：通用 NPC 占位实体脚本，保存 `npc_id` 和档案快照，刷新短姓名/HP/当前行动标签，并处理点击。
依赖：绑定到 `res://scenes/npc/NPC.tscn`，通过 `/root/EventBus.npc_clicked` 发出点击事件。
当前状态：T0304 已创建；点击 NPC 会打印 ID 并发出 `npc_clicked(npc_id)`；头顶标签只显示短姓名、HP 和当前行动摘要；支持 `move_to_location(...)` 直线移动，到达后发出 `movement_arrived` 给 `NPCSystem` 写回地点状态。

路径：`res://scenes/npc/NPC.tscn`
用途：通用 NPC 低模占位场景。
依赖：绑定 `res://scripts/npc/NPC.gd`，由 `NPCSystem` 实例化。
当前状态：T0303 已创建；当前包含 `Area3D` 点击区、低模胶囊身体、头部和 `Label3D` 短姓名/HP/当前行动调试标签。

路径：`res://scripts/systems/MemorySystem.gd`
用途：事件、见闻与地点/广场信息节点系统。
依赖：由 ActionSystem、NPCSystem、DialogSystem、CombatSystem、BuildingSystem 等系统写入事件；读取 GameState / TimeSystem 的游戏时间；通过 EventBus 广播 `event_recorded`、`npc_memory_changed`、`location_info_changed` 和 `public_event_added`。
当前状态：T0405 已实现 NPC 短期记忆容器查询；支持 `get_npc_short_term_memory(...)`、`get_npc_short_term_memory_ids(...)`、`record_player_interaction(...)`、`debug_record_player_money_given(...)`、`debug_record_player_attack_npc(...)`、`debug_get_npc_witness_events(...)` 和 `debug_get_npc_short_term_memory(...)`。T0404/T0408/T0409 已实现广场信息即时广播并统一为 `location_id == "plaza"` 的 `local_public`；支持 `move_npc_between_locations(...)`、`get_location_snapshot(...)`、`get_location_people_present(...)`、`is_enterable_location(...)`、`set_plaza_notice(...)`、`broadcast_plaza_event(...)`、`broadcast_plaza_state_change(...)`、`notify_key_entity_state_changed(...)` 及对应调试接口。2026-05-25 起，MemorySystem 监听 `building_state_changed`：任一建筑可传播外部状态会同步进广场 `building_external_states` / `key_entities` 并生成带具体建筑名和具体事实的 `plaza_status_changed`；可进入建筑的外部或内部可传播状态当前会生成 `location_status_changed` 本地见闻。可传播外部状态只计算等级与完好/受损/正在修复/正在升级；HP、剩余修复/升级时长不触发广播。广场和可进入建筑进入快照都会生成 `people_statuses`，把当前在场 NPC 的生命状态写为健康/受伤/昏迷，昏迷时可列出治疗者，并把 `current_action` 翻译成精简中文；可进入建筑还会提供每个工位占用/空闲，工位数量不触发广播。NPC 进入广场会获得当前广场在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态，进入可进入建筑会获得该建筑外部 + 内部状态。T0407 已实现：`location_entered` / `location_exited` 事件库只保留进出行动事实，进入者获得一次状态见闻，已在场 NPC 只收进出事件，建筑/地点状态变化改为字段级差量见闻。T0402 已升级为结构化事件事实源；支持 `add_event(...)`、`get_event_log()` / `get_all_events()`、`get_npc_daily_events(...)`、`get_npc_witness_events(...)`、`get_plaza_events(...)`、`add_witness_event(...)` 和调试查询接口。T0502A 后，`add_witness_event(...)` 会拒绝给昏迷 NPC 写入见闻，复苏后自动恢复。事件会规范化为包含 `event_id`、`day`、`time`、`type`、`subject_npc_id`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary`、`payload` 的结构，并首先写入对应 NPC 当天事件库；`local_public` 会转发给事件地点当前在场且未昏迷 NPC 的见闻库，广场事件通过同一机制转发给广场当前在场且未昏迷 NPC 并可被广场查询返回。玩家非对话交互写入时 actor id 使用 `guard_officer`，summary 使用“守备官”。公告变更写入 `plaza_notice_changed`，建筑状态变更写入 `plaza_status_changed` 或 `location_status_changed`。MemorySystem 不提供按地点查询事件的长期接口，地点/广场节点也不保存事件历史。已为 `location_entered`、`work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_completed`、`money_given`、`npc_attacked_by_player`、`damage_taken`、`unconscious_started`、`healing_started`、`healing_completed`、`revived` 等实现确定性 summary 模板和必需 payload 字段声明。尚未实现睡前总结或知识图谱更新。

路径：`res://scripts/systems/ActionSystem.gd`
用途：行动系统占位脚本，后续用于工作、吃饭、睡觉、训练等行动调度。
依赖：通过 `/root/ConfigLoader` 读取 `data/action_defs.json`，调用 `NPCSystem` 移动与状态接口、`ResourceSystem` 资源结算接口，并写入 `MemorySystem` 结构化事件。
当前状态：T0402 已在 T0305 工作 / 吃饭 / 睡觉最小行动闭环上接入结构化事件；提供 `debug_assign_work(...)`、`debug_assign_repair_assist(...)`、`debug_assign_upgrade_assist(...)`、`debug_assign_heal_assist(...)`、`debug_assign_eat(...)`、`debug_assign_sleep(...)`、`debug_assign_action(...)` 和只读 `get_healing_helpers_for_target(...)`。当前工作支持菜园产粮、食堂加工餐食、酒窖酿酒、铁匠铺制造武器/盔甲、工械坊制造工程器械、马厩产出马匹整备占位；建筑修复和升级由 `BuildingSystem` 创建倒计时作业，NPC 行动只负责在广场协助正在进行的修复/升级并加速倒计时。协助治疗是带昏迷 NPC 目标的运行时行为，治疗者会前往目标所在信息地点，最多 2 人协助同一目标，按医术熟练度调用 `NPCSystem` 加速昏迷恢复，并按逻辑时间消耗第纳尔。工作、吃饭、睡觉会以 `local_public` 写入事件，让同地点当前在场 NPC 收到见闻；协助修复/协助升级同样以 `local_public` 写入 `repair_assist_started` / `upgrade_assist_started`，事件地点为 `plaza`；协助治疗写入 `healing_started` / `healing_completed`，进入治疗者和目标事件库，并写入同地点其他在场 NPC 的见闻库，事件信息不暴露医术熟练度。T0401 暂停语义修正后，暂停期间不会执行行动结算；2026-05-25 起，吃饭、睡觉和工作到达地点后进入 active 行动并随 `logical_time_tick` 推进，吃饭 1200 秒、睡觉 23400 秒、工作 3600 秒为当前基准。未实现 LLM 日程、训练、战斗、工作位占用或复杂职业效率。

路径：`res://scripts/systems/CombatSystem.gd`
用途：战斗系统占位脚本，后续用于攻击、策略和敌人波次。
依赖：暂无。
当前状态：T0102 已创建并绑定到 `Main/Systems/CombatSystem`；尚未实现战斗逻辑。

路径：`res://scripts/systems/LLMBridge.gd`
用途：Godot 侧后端桥接脚本，负责请求 `/health` 与 `/npc/dialogue`，构造 T0603 对话 payload，并管理 LLM 等待期间的 TimeSystem 慢速请求。
依赖：挂载到 `Main/Systems/LLMBridge`；读取 `NPCSystem`、`MemorySystem`、`GameState` 和 `TimeSystem`；使用 Godot 原生 `HTTPClient` 请求游戏后端。
当前状态：T0604 已创建，T0604A 已替换传输层；支持后端地址配置、health check、玩家-NPC / NPC-NPC 对话 payload 构造、`speaker_name == "守备官"`、短期记忆事件/见闻分离、地点快照注入、请求失败结果返回和成功/失败/超时后的慢速释放。不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件。尚未写入对话事件、修改征召状态或调用真实 LLM；正式架构下 Godot 客户端只请求游戏后端，不保存供应商 API Key。

路径：`res://scripts/systems/DialogSystem.gd`
用途：对话系统占位脚本，后续用于 NPC 对话和后端请求。
依赖：暂无。
当前状态：T0102 已创建并绑定到 `Main/Systems/DialogSystem`；T0604 的后端请求由 `LLMBridge` 承担，DialogSystem 仍尚未实现对话 UI、事件入库或征召逻辑。

路径：`res://scripts/ui/HUD.gd`
用途：HUD 展示脚本，刷新标题区下方的天数、`HH:MM:SS` 时间/阶段、资源占位、速度/暂停按钮和后端状态占位。
依赖：读取 `/root/GameState`，监听 `/root/EventBus.time_changed`、`hour_started`、`day_started` 和 `resource_changed`，从 `Main/Systems/ResourceSystem` 读取当前资源。
当前状态：T0604 后，HUD 后端状态会读取 `LLMBridge.get_last_backend_status()` 并监听 `backend_status_changed`；T0401 已接入真实时间推进、秒级时间显示、速度按钮、暂停按钮和空格暂停；速度按钮显示玩家设定倍率，空格只触发暂停/继续，不触发速度切换；LLM 等待造成的有效逻辑倍率由 TimeSystem 提供给后续调试 UI；T0202 已接入真实基础资源显示；2026-05-20 已让 HUD 根节点忽略鼠标，避免全屏背板拦截建筑点击；警铃仍为占位。

路径：`res://scripts/ui/BuildingPanel.gd`
用途：建筑信息面板脚本，监听建筑点击并展示建筑名称、等级、HP、工作位和地点信息占位。
依赖：监听 `/root/EventBus.building_clicked` 和 `/root/EventBus.building_state_changed`，从 `Main/Systems/BuildingSystem` 读取建筑状态。
当前状态：T0303 已接入 `Main/UI/BuildingPanel`；修复和升级按钮会调用 `BuildingSystem`，并根据 HP、等级、配置、是否已有修复/升级作业和资源是否足够自动启用或禁用；建筑受损、正在修复或正在升级时不可升级；修复/升级的资源消耗和执行条件只在按钮悬停提示框中显示，不常驻写入面板正文；提示框靠近屏幕边缘时会保持在可视区域内；修复和升级进行中都会展示剩余时间、进度、速度倍率和协助人数；点击 NPC 时会隐藏建筑面板；T0006 后只有当前建筑面板仍可见时才响应建筑状态刷新，因此进度刷新不会抢占 NPC 面板。

路径：`res://scripts/ui/NPCPanel.gd`
用途：NPC 信息面板脚本，监听 NPC 点击和状态变化并展示 NPC 基础状态。
依赖：监听 `/root/EventBus.npc_clicked`、`/root/EventBus.npc_state_changed` 和 `/root/EventBus.building_clicked`，从 `Main/Systems/NPCSystem` 读取 NPC 档案与状态。
当前状态：T0405 后，`Main/UI/NPCPanel` 会显示 NPC 当天事件库和见闻库最近摘要，并监听 `npc_memory_changed` 刷新；基础状态仍按姓名、HP、属性、专长、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、职业熟练度和武器熟练度显示；属性来自 `stats.strength` / 力量和 `stats.intelligence` / 智力，专长由熟练度推导；点击建筑时会隐藏 NPC 面板。

路径：`tools/verify_npc_damage_unconscious.gd`
用途：验证 T0501 NPC HP 扣除、昏迷状态、行动阻断和同地点见闻传播。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`ActionSystem`、`MemorySystem` 和 `NPCPanel`。
当前状态：T0501 已创建；验证致命伤害会把 HP 降到 0、设置昏迷、阻止行动和移动，并让同地点 NPC 收到 `unconscious_started` 见闻。

路径：`tools/verify_npc_unconscious_natural_recovery.gd`
用途：验证 T0502 NPC 昏迷自然恢复、自动复苏、复苏事件和复苏后行动恢复。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`NPCSystem.debug_advance_unconscious_recovery(...)`、`ActionSystem` 和 `MemorySystem`。
当前状态：T0502/T0502A 已创建；验证昏迷 NPC 每游戏小时恢复 2 HP，达到 Max HP 30% 后写入 `revived`、同地点 NPC 收到见闻，并重新允许行动指派；同时验证昏迷期间拒收见闻、复苏后重新接收见闻。

路径：`tools/verify_npc_unconscious_healing.gd`
用途：验证 T0503 NPC 昏迷协助治疗、治疗者上限、治疗消耗、医术加速、治疗事件和资源不足失败。
依赖：加载 `res://scenes/main/Main.tscn`，调用 `NPCSystem.debug_damage_npc(...)`、`ActionSystem.debug_assign_heal_assist(...)`、`ResourceSystem` 和 `MemorySystem`。
当前状态：T0503 已创建；验证其他 NPC 可协助治疗昏迷目标，每个目标最多 2 名治疗者，治疗会持续消耗第纳尔，高医术治疗明显快于自然恢复；治疗事件进入治疗者和目标事件库、同地点其他在场 NPC 见闻库，且不暴露医术熟练度。

路径：`res://scripts/ui/GMPanel.gd`
用途：GM 调试面板脚本，为 M1-M4 已完成但前端不易直接验证的系统能力提供可拖动按钮、命令输入框、调试按钮和结果输出。
依赖：挂载到 `Main/UI/GMPanel`；调用 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem` 和 `MemorySystem` 的已有公开接口或 `debug_*` 接口；使用顶部 `GM_ENABLED` 常量控制开发/上线显示。
当前状态：T0004 已实现；支持资源、时间、建筑、NPC、行动、记忆/见闻/广场公告等调试入口，行动分组内提供“修复目标”“升级目标”和“治疗目标”下拉用于测试参数化协助修复/协助升级/协助治疗；支持 `help`、`add_resource`、`damage_building`、`repair_building`、`upgrade_building`、`assist_repair`、`assist_upgrade`、`assist_heal`、`enter_location`、`give_money`、`attack_npc` / `damage_npc`、`recover_npc`、`memory`、`events` 等命令。GMPanel 不写入新的权威结算逻辑，只转发到已有系统。

路径：`res://scripts/camera/CameraRig.gd`
用途：基础俯视摄像机控制脚本，驱动 `Main/CameraRig` 的平移和 `CameraRig/Camera3D` 的本地距离缩放。
依赖：绑定到 `res://scenes/main/Main.tscn` 的 `CameraRig`，读取键盘 WASD、鼠标中键拖拽和滚轮输入。
当前状态：T0105 已创建并绑定；支持 X/Z 边界限制、缩放距离限制，并保持高机位俯视角，不实现角色控制或第一人称自由视角。

## Godot 脚本规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 事件总线 | `res://scripts/core/EventBus.gd` | 全局信号 |
| 游戏状态 | `res://scripts/core/GameState.gd` | 全局状态 |
| 配置加载 | `res://scripts/core/ConfigLoader.gd` | JSON 配置加载 |
| 时间系统 | `res://scripts/systems/TimeSystem.gd` | 天数、阶段、加速 |
| 资源系统 | `res://scripts/systems/ResourceSystem.gd` | 金钱、粮食等 |
| 建筑系统 | `res://scripts/systems/BuildingSystem.gd` | 建筑 HP、等级、工作位 |
| NPC 系统 | `res://scripts/systems/NPCSystem.gd` | NPC 生成与管理 |
| NPC 展示脚本 | `res://scripts/npc/NPC.gd` | NPC 占位实体、标签和点击事件 |
| 行动系统 | `res://scripts/systems/ActionSystem.gd` | 工作、吃饭、睡觉、训练 |
| 对话系统 | `res://scripts/systems/DialogSystem.gd` | 与后端对话 |
| 征召系统 | `res://scripts/systems/RecruitmentSystem.gd` | 入伍状态 |
| 记忆系统 | `res://scripts/systems/MemorySystem.gd` | 事件、见闻、短期记忆 |
| 战斗系统 | `res://scripts/systems/CombatSystem.gd` | 攻击、策略、波次 |
| 昏迷系统 | `res://scripts/systems/UnconsciousSystem.gd` | 昏迷、治疗、复苏 |
| LLM 桥接 | `res://scripts/systems/LLMBridge.gd` | HTTP 请求后端 |
| HUD 展示 | `res://scripts/ui/HUD.gd` | 时间、资源、按钮和后端状态占位 |
| 建筑面板 | `res://scripts/ui/BuildingPanel.gd` | 建筑信息展示、修复/升级按钮 |
| NPC 面板 | `res://scripts/ui/NPCPanel.gd` | NPC 基础状态展示与刷新 |
| 摄像机控制 | `res://scripts/camera/CameraRig.gd` | 俯视平移、缩放和边界限制 |

## 数据文件规划

| 内容 | 推荐路径 | 说明 |
|---|---|---|
| 资源定义 | `data/resource_defs.json` | 初始资源、显示顺序和基础分类 |
| NPC 档案 | `data/npc_profiles.json` | 8 个初始 NPC |
| 建筑定义 | `data/building_defs.json` | 建筑 HP、等级、工作位；公告牌不在此表中 |
| 行动定义 | `data/action_defs.json` | 工作、吃饭、睡觉等 |
| 武器定义 | `data/weapon_defs.json` | 剑盾、长杆、弓、弩 |
| 敌人波次 | `data/enemy_waves.json` | 5 波 Demo |
| Prompt 模板 | `data/prompts/*.txt` | 计划、对话、判定、总结 |

## 数据文件当前已创建

路径：`data/resource_defs.json`
用途：资源配置，记录资源 id、显示名、分类、初始数量、最小值和 HUD 顺序。
依赖：由 `ResourceSystem` 通过 `ConfigLoader.load_data_file("resource_defs.json")` 读取。
当前状态：T0305 已接入运行时资源初始化，包含第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁；HUD 仍只显示五类基础资源，派生资源当前用于行动系统内部结算。

路径：`data/building_defs.json`
用途：建筑配置，记录建筑 id、等级、HP、标签、工作位、输入输出、修复和升级规则。
依赖：由 `BuildingSystem` 通过 `ConfigLoader.load_data_file("building_defs.json")` 读取，并通过 `scene_nodes` 绑定到低模建筑实体。
当前状态：T0206 后为 15 条建筑/门墙定义，覆盖主厅、宿舍、食堂、仓库、围墙、城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所和工械坊；所有建筑都有 `upgrade` 最小规则，既有关键建筑保留 `repair` 规则，`repair` 可配置每点缺失 HP 耗时和等级耗时系数。2026-05-25 起，不可进入建筑不保留内部工位占位；公告牌已从建筑定义中移除，作为主厅前视觉占位和广场公告输入/显示接口处理。

路径：`data/action_defs.json`
用途：行动配置，记录行动 id、类型、地点需求、技能、耗时、资源输入输出和状态变化。
依赖：由 `ActionSystem` 读取并作为 NPC 日程与工作白名单。
当前状态：T0305 已由 `ActionSystem` 读取；包含菜园工作、食堂加工餐食、酒窖酿酒、铁匠铺制造、工械坊制造、马厩照料、吃饭、睡觉和协助治疗昏迷者等最小行动定义。2026-05-25 起优先使用 `duration_seconds` 表达持续时间：工作 3600 秒、吃饭 1200 秒、睡觉 23400 秒。协助治疗是需要目标 NPC 的 `targeted_heal` 行动，普通 `assign_action` 不直接执行，必须走 `debug_assign_heal_assist(healer_npc_id, target_npc_id)`。协助修复和协助升级不在该文件中按建筑写死，而由 `ActionSystem` 作为带建筑参数的运行时行为处理。

路径：`data/weapon_defs.json`
用途：武器配置，记录武器类型、射程、伤害、攻击间隔和技能需求。
依赖：后续由装备、征召和战斗系统读取。
当前状态：T0201 已创建最小样例，包含短剑。

路径：`data/enemy_waves.json`
用途：敌人波次配置，记录波次编号、触发时间、生成点和敌人数量。
依赖：后续由 `CombatSystem` 或波次系统读取。
当前状态：T0201 已创建最小样例，包含第一波敌人占位。

路径：`data/npc_profiles.json`
用途：NPC 档案配置，记录身份、性格、欲望、恐惧、底线、基础数值、状态、技能、入伍状态、装备、知识图谱和日记。
依赖：由 `NPCSystem` 通过 `ConfigLoader.load_data_file("npc_profiles.json")` 读取并生成 NPC 实体。
当前状态：T0302 已接入运行时 NPC 生成；包含 8 名初始 NPC 档案：马夫 `stableman_01`、厨子 `cook_01`、园丁 `gardener_01`、铁匠 `blacksmith_01`、老兵副官 `veteran_deputy_01`、神父 `priest_01`、医生 `doctor_01`、工程师 `engineer_01`。每名 NPC 包含基础外观、背景、性格、欲望、恐惧、能力、状态、技能、装备、计划、短期记忆、知识图谱和日记字段。

## 后端模块规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 后端入口 | `backend/app.py` | Flask/FastAPI 入口 |
| 模型适配器 | `backend/services/model_adapter.py` | DeepSeek/MiniMax 等统一接口 |
| 对话服务 | `backend/services/dialog_service.py` | NPC 对话 |
| 计划服务 | `backend/services/planning_service.py` | 每日计划 |
| 判定服务 | `backend/services/judgement_service.py` | 战斗/逃离判定 |
| 记忆服务 | `backend/services/memory_service.py` | 总结、知识图谱 |
| 成本统计 | `backend/services/budget_service.py` | token 与费用 |
| 数据模型 | `backend/schemas/*.py` | Pydantic 或 dataclass |

## 后端当前已创建

路径：`backend/app.py`
用途：Flask 后端入口，当前提供 `GET /health` 健康检查、`POST /mock/model` Mock Model 调试接口和 `POST /npc/dialogue` NPC 对话 Mock 业务接口。
依赖：`flask`, `python-dotenv`。
当前状态：T0603 后，`/npc/dialogue` 会校验 T0603 版 `NPCDialogueRequest`，调用默认 mock provider 的 `dialogue` 分支，并将输出校验为 `NPCDialogueResponse`；玩家-NPC 对话可返回 `recruitment_result=accept/reject`，NPC-NPC 对话在轮次接近上限时可返回 `should_end_dialogue=true`。T0602 的 `/mock/model` 仍可按 `call_type` 返回稳定 JSON 并附带伪 token / 用途记录；尚未实现正式计划、判定业务接口或真实 LLM 调用。

路径：`backend/requirements.txt`
用途：记录 Python 后端依赖。
依赖：至少包含 `flask`, `python-dotenv`, `pydantic`, `requests`。
当前状态：T0002 已确认可用于安装后端最小依赖。

路径：`backend/.env.example`
用途：本地 `.env` 配置模板。
依赖：无。
当前状态：仅包含变量名和占位值；真实 API Key 必须放入本地 `backend/.env`，不得提交仓库。

路径：`backend/services/model_adapter.py`
用途：模型供应商适配器边界，后续由对话、计划、判定服务复用。
依赖：环境变量 `LLM_PROVIDER`, `LLM_API_KEY`。
当前状态：T0602 已实现默认 `mock` provider；`.env` 不存在或未设置 `LLM_PROVIDER` 时默认 mock，支持 `generate(call_type, payload)` 按调用类型返回稳定 JSON，并记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用和成功/失败状态；非 mock provider 未配置 `LLM_API_KEY` 时返回明确失败，不发起真实 LLM 请求。

路径：`backend/schemas/common.py`
用途：后端 AI 接口共享 Schema，定义游戏时间、请求元信息、事件摘要、短期记忆、NPC 身份/状态/上下文、行动候选和通用错误响应。
依赖：`pydantic`。
当前状态：T0601 已创建；只提供数据模型，不调用 LLM，不改变游戏权威状态。

路径：`backend/schemas/npc_ai.py`
用途：NPC AI 请求/响应 Schema，覆盖玩家-NPC / NPC-NPC / 逃离挽留对话、每日计划、计划异常重评估、战斗判定、睡前总结、知识图谱更新、主动交涉和玩家话术分类。
依赖：`pydantic`，复用 `backend/schemas/common.py`。
当前状态：T0603 后，对话 Schema 已按当前任务重整为显式 `npc_id`、`npc_name`、`npc_setting`、`speaker_name`、`speaker_text`、`speaker_context`、`is_recruitment_request`、轮次、`npc_state`、`dialogue_state`、`short_memory`、`long_memory` 和 `location_context` 输入；响应使用 `replyer_id`、`reply_text`、`response_kind`、`recruitment_result` 和 `should_end_dialogue`。每日计划、修订、战斗判定、睡前总结等 Schema 沿用 T0601 结构。

路径：`backend/schemas/__init__.py`
用途：统一导出后端 Schema 类型。
依赖：`backend/schemas/common.py`、`backend/schemas/npc_ai.py`。
当前状态：T0601 已创建。

路径：`backend/schemas/README.md`
用途：记录后端 Schema 分组和权威边界。
依赖：无。
当前状态：T0601 已创建。

路径：`backend/services/`, `backend/data/`
用途：后端服务层和后端本地数据目录。
依赖：暂时无。
当前状态：T0002 创建目录骨架，用 `.gitkeep` 保留空目录。

## 更新规则

新增任何实际文件后，在本文件加入：

```text
路径：
用途：
依赖：
当前状态：
```
## Tools

| 内容 | 文件 |
|---|---|
| Godot MCP 连接自检与重复 proxy 检查 | `tools/check_godot_mcp.ps1` |
| 建筑修复/升级验证 | `tools/verify_building_repair_upgrade.gd` |
| NPC 面板与状态验证 | `tools/verify_npc_panel_state.gd` |
| NPC 移动与地点验证 | `tools/verify_npc_movement_location.gd` |
| NPC 熟练度 schema 验证 | `tools/verify_npc_skill_schema.gd` |
| 简单行动系统验证 | `tools/verify_action_system_basic.gd` |
| 时间系统验证 | `tools/verify_time_system.gd` |
| 结构化事件底座验证 | `tools/verify_structured_memory_events.gd` |
| 地点信息节点验证 | `tools/verify_location_info_nodes.gd` |
| 广场本地公开广播验证 | `tools/verify_plaza_local_public_broadcast.gd` |
| NPC 短期记忆容器验证 | `tools/verify_npc_short_term_memory_container.gd` |
| 行动事件本地公开广播验证 | `tools/verify_action_local_public_broadcast.gd` |
| NPC 扣血与昏迷验证 | `tools/verify_npc_damage_unconscious.gd` |
| NPC 昏迷自然恢复验证 | `tools/verify_npc_unconscious_natural_recovery.gd` |
| NPC 昏迷协助治疗验证 | `tools/verify_npc_unconscious_healing.gd` |
| GM 调试面板验证 | `tools/verify_gm_panel.gd` |
| 后端 Schema 验证 | `tools/verify_backend_schemas.py` |
| Mock Model Adapter 验证 | `tools/verify_mock_model_adapter.py` |
| `/npc/dialogue` Mock 接口验证 | `tools/verify_dialogue_mock_endpoint.py` |
| Godot LLMBridge 验证 | `tools/verify_llm_bridge.gd`，T0604A 起包含不依赖 `curl.exe` / `OS.execute` 的静态检查 |
