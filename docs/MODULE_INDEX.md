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
| 对话 UI | `res://scripts/ui/DialogPanel.gd`（节点内嵌于 `Main.tscn`） | NPC 对话 |
| 指令 UI | `res://scripts/ui/OrderPanel.gd`（节点内嵌于 `Main.tscn`） | 已入伍 NPC 自然语言指令 |
| NPC 面板 | `res://scenes/ui/NPCPanel.tscn` | 状态、装备、按钮 |
| 建筑面板 | `res://scenes/ui/BuildingPanel.tscn` | 建筑信息 |
| GM 调试面板 | `res://scripts/ui/GMPanel.gd` | 开发验证入口 |
| 每日计划系统 | `res://scripts/systems/DailyPlanSystem.gd` | 规则版 / LLM Mock 24 小时计划生成、执行与异常重评估 |
| 首次睡眠总结系统 | `res://scripts/systems/DailyReflectionSystem.gd` | 每日首次睡眠满 1 游戏小时后的日记、知识图谱占位更新、短期记忆清空与深度睡眠锁 |

## Godot 当前已创建

路径：`project.godot`
用途：Godot 项目配置，当前启动场景为 `res://scenes/main/Main.tscn`，并注册 `MCPGameBridge`、`EventBus`、`GameState`、`ConfigLoader` Autoload。
依赖：Godot 4.6，`addons/godot_mcp` 自动加载配置。
当前状态：T0101 已验证可打开并运行，核心 Autoload 加载无报错。

路径：`addons/godot_mcp/`
用途：Godot MCP 编辑器插件与运行桥接，供 Codex / MCP server 查看场景、节点、资源、截图、运行状态和编辑器状态。
依赖：Node 侧 `@satelliteoflove/godot-mcp`；插件监听 `127.0.0.1:6550`。
当前状态：2026-06-17 已升级到 `4.0.1`，与本机 npm server `4.0.1` 对齐；新增/保留运行态采样、输入名解析、执行保护和网格校验相关脚本。`MCPGameBridge` 显式预加载 `mcp_runtime_state_sampler.gd`、`key_names.gd`、`joy_names.gd` 和 `mcp_exec_guard.gd`，避免换机或 `.godot` 缓存未刷新时 Autoload 解析失败。Codex MCP 已通过 `godot_project.addon_status` / `godot_editor.get_state` 复验连接正常。换环境恢复时先按 `docs/CURRENT_STATE.md` 的“换环境恢复 Godot MCP 清单”和 `docs/TASKS.md` 的 T0007 / T0009 / T0017 记录检查 server/addon/config 版本一致性和运行桥接脚本状态。

路径：`res://scenes/main/Main.tscn`
用途：最小可运行主场景，包含 `WorldRoot/Station/Ground`、`WorldRoot/Station/Buildings`、`WorldRoot/Station/NPCs`、`WorldRoot/Station/Enemies`、`WorldRoot/Station/Props`、`Systems/*`、`UI/HUD`、`UI/NPCPanel`、`UI/BuildingPanel`、`UI/DialogPanel`、`UI/OrderPanel`、`UI/GMPanel`、`CameraRig/Camera3D`、`SunLight`。`Systems` 下已包含 `LLMBridge`。`Buildings` 下已有主厅、宿舍、食堂、仓库、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、围墙、城门、后门等低模建筑/门墙占位，并保留主厅前 `NoticeBoard` 视觉占位；`NoticeBoard` 不绑定建筑定义，不具备 HP / 等级 / 工作位。`Props` 下已有广场、正门道路、后门道路和商人入口占位；`UI/HUD` 下已有标题、天数、`HH:MM:SS` 时间/阶段、资源占位、速度按钮、暂停按钮、可触发警铃集结的警铃按钮和后端状态；`UI/NPCPanel` 和 `UI/BuildingPanel` 已接入右上角信息面板；`UI/OrderPanel` 已接入自然语言指令编辑；`UI/GMPanel` 已接入可拖动半透明 GM 调试按钮和面板；`CameraRig` 已挂载基础俯视摄像机控制。
依赖：绑定 `res://scripts/systems/TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`EquipmentSystem.gd`、`LLMBridge.gd`、`DialogSystem.gd`、`DailyPlanSystem.gd`、`DailyReflectionSystem.gd` 作为系统脚本，绑定 `res://scripts/ui/HUD.gd` 和 `res://scripts/ui/GMPanel.gd` 作为 UI 脚本，并绑定 `res://scripts/camera/CameraRig.gd` 作为相机控制脚本。
当前状态：T0403/T0409 已完成地点信息节点与进入快照；T0401 已完成基础 TimeSystem，HUD 时间以 `HH:MM:SS` 推进，速度按钮可切换 `x1` / `x2` / `x4`，暂停按钮和空格可暂停/继续，空格不触发加速；T0012 后 HUD 主栏按资源定义顺序显示非聚合资源库存，并提供装备/器械详情按钮，详情面板贴近各自按钮左下且夹在屏幕内；T0305 已完成 NPC 工作 / 吃饭 / 睡觉最小行动闭环，并按 `game_design.md` 补齐酒窖、铁匠铺、工械坊、马厩、协助修复和协助升级的最小效果；低模驿站、HUD 信息、建筑调试标签和 NPC 调试标签可见，可用 WASD/鼠标中键/滚轮查看驿站；T1101 后正门外地面和正门道路已扩大，`WorldRoot/Station/Enemies` 可由 CombatSystem 生成正门外低模敌人占位；T1103 后 HUD 警铃可触发入伍持武器 NPC 前往城门外防线集结，近战 / 骑兵在前、弓弩 / 骑射在后，集结 / 接敌时显示方向标记和坐骑表现；T1105 后已入伍持武器 NPC 可在 NPC 面板选择当前兵种可用战斗策略，T1105A 后战斗内避战够远时保持等待；T1106 后敌人波次开始 / 结束会写入广场公开事件并维护本场受伤、昏迷和击退统计；建筑节点运行时具备点击区并可发出 `building_clicked`，右上角建筑面板可显示被点击建筑的基础信息、按类型分组的工位空闲数 / 总数与占用者，并触发倒计时修复/升级；NPC 点击可发出 `npc_clicked` 并打开 NPC 面板；可通过调试接口让 NPC 直线移动到指定建筑、战斗集结世界坐标或策略移动目标，或安排工作、协助修复、协助升级、训练、吃饭、睡觉，到达后更新地点 `people_present`、写入只含行动事实的 `location_entered` / `location_exited`，并给进入者写入一次地点快照见闻；室内到室内切换会在事件与地点信息层经由广场，再进入持续行动。吃饭、睡觉、工作和训练通过 `logical_time_tick` 推进，完成后结算资源/状态并写入结构化事件。T0804 后，铁匠铺可消耗铁产出武器/盔甲派生库存；T0805 后，工械坊可消耗木材产出武器/工程器械派生库存；T0806 后，马厩可消耗粮食并按养马、力量和马厩等级产出马匹整备派生库存；T0807 后，酒窖可消耗粮食并按酿酒、智力和酒窖等级产出酒派生库存；T0901/T0902 后，装备系统可把武器/盔甲/马匹整备库存转换到已入伍 NPC 的装备槽，并按主武器与 `equipment.mount` 槽提供兵种判定快照；T0903 后，训练场可通过教官工位和受训位提升当前装备对应的武器熟练度 / 骑术，并让教官提升“教练”；T0904 后，工作 / 诊所 / 训练的熟练度提升同步增加经验、产生未分配技能点；T0015 后 NPC 面板把经验显示在 HP 右侧，并只在有未分配技能点时显示属性旁 `+1`，GM 可把选中 NPC 设为入伍并由玩家分配力量或智力。暂停期间 NPC 移动与行动结算停止，未开始行动保持 pending，已开始行动保持 active，恢复后继续；建筑修复和升级进度也随逻辑时间暂停/加速。未实现真实日程、复杂生产效率、酒的商队出售交易、工程器械部署、正式胜负结算或真实 LLM。
T1204A 补充：逃离 NPC 会显示头顶 `!` 和 HUD 警告，点击后先打开 NPC 面板；玩家通过【对话】按钮进入强制公开的逃离挽留对话，最多 5 轮。挽留面板打开时 CombatSystem 暂停逃离移动，未满 5 轮关闭后恢复移动且可再次打开，5 轮用完后 NPC 面板【对话】置灰。LLM / Mock 只返回留下或继续逃离意向，CombatSystem 负责停止或继续逃离；守备官给钱会减速，逃离挽留中的攻击会加速、计 1 轮、关闭面板且不请求 NPC LLM 回复，攻击昏迷只暂停逃离并在复苏后继续。
T1001-T1003 补充：`Main.tscn` 已挂载 `DailyPlanSystem`，规则版每日计划接口、按小时执行、行动异常 / 指令变化后的 Mock 或规则降级计划重评估应用、以及 `/npc/plan_day` LLM / Mock 每日计划制定与规则降级应用已实现；上段旧口径中的“未实现真实日程”现在仅指真实 LLM Prompt 打磨和更完整的自主计划链路尚未实现。
T1004/T1005 补充：`Main.tscn` 已挂载 `DailyReflectionSystem`，NPC 每天首次睡觉并持续睡眠满 1 游戏小时后会生成首次睡眠总结，写入长期日记和知识图谱占位，并清空该 NPC 当天短期事件/见闻索引；总结请求和应用期间 NPC 进入不可打断的深度睡眠锁。

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
当前状态：T0703 后已包含资源、时间、建筑、NPC、记忆与地点信号，以及 `recruitment_changed`、`npc_order_changed`、`npc_plan_reevaluation_requested`；指令变化与计划重评估请求可由后续计划系统独立监听。

路径：`res://scripts/core/GameState.gd`
用途：全局运行状态，保存当前天数、小时、分钟、秒和是否处于战斗中。
依赖：作为 Autoload 注册于 `project.godot`；需要广播时通过 `/root/EventBus` 查找事件总线。
当前状态：T0101 已创建；保存当前天、时、分、秒和战斗状态。T1102 新增 `game_over`、`game_result`、`failure_reason` 和 `set_game_over(...)`，用于主厅被摧毁后的失败状态占位；正式失败界面仍由后续结算任务实现。

路径：`res://scripts/core/ConfigLoader.gd`
用途：统一 JSON 配置读取入口。
依赖：作为 Autoload 注册于 `project.godot`；使用 Godot `FileAccess` 和 `JSON`。
当前状态：T0101 已创建；文件缺失、打开失败、解析失败时会 `push_error` 并返回默认值。

路径：`res://scripts/systems/TimeSystem.gd`
用途：基础逻辑时间系统，负责 24 小时阶段、秒级显示、暂停、加速、跨天、LLM 等待减速和数值倍率出口。
依赖：读取 `/root/GameState`，通过 `/root/EventBus.time_changed`、`time_scale_changed`、`logical_time_tick`、`hour_started` 与 `day_started` 广播时间变化；由 `HUD.gd` 的 `SpeedButton` 调用 `cycle_speed()`，由 `PauseButton` 和空格调用 `toggle_paused()`；后续 LLMBridge / DialogSystem 调用 `request_time_slowdown(...)` 与 `release_time_slowdown(...)`。
当前状态：T0401 已实现；默认现实 1 秒 = 游戏内 1 分钟，HUD 显示 `HH:MM:SS` 并随游戏秒刷新，支持 `x1` / `x2` / `x4` 速度切换和独立暂停/继续；空格只切换暂停，不改变速度倍率；已提供 LLM 等待时 `1/60` 有效逻辑倍率与 `get_numeric_delta_multiplier()` / `get_game_delta_seconds(...)` 接口；T0604/T1002/T1003 已把对话、计划修订和每日计划请求接入慢速申请 / 释放；T1104A 新增 `request_time_scale_cap(...)` / `release_time_scale_cap(...)` / `get_time_scale_snapshot()`，CombatSystem 可在敌人在场时注册 `combat_enemy_presence` 上限，把有效倍率最高压到 `x1`；T1104B 后战斗攻速由 CombatSystem 内部把游戏秒折算为战斗动作秒，TimeSystem 不承担攻速倍率结算。尚未把真实 LLM 请求接入完整成本与并发面板。

路径：`res://scripts/systems/ResourceSystem.gd`
用途：资源系统占位脚本。
依赖：通过 `/root/ConfigLoader` 读取 `data/resource_defs.json`，通过 `/root/EventBus.resource_changed` 广播资源变化，供 HUD 刷新。
当前状态：T0202 已实现基础资源读写；支持 `get_resource(id)`、`add_resource(id, amount)`、`can_afford(cost_dict)`、`spend_resources(cost_dict)`，并提供调试入口验证增减资源和超额扣除失败。

路径：`res://scripts/systems/BuildingSystem.gd`
用途：基础建筑系统，负责建筑配置读取、场景节点绑定、点击识别和基础状态查询。
依赖：通过 `/root/ConfigLoader` 读取 `data/building_defs.json`，绑定 `Main/WorldRoot/Station/Buildings` 下的低模建筑节点，并通过 `/root/EventBus.building_clicked` 广播点击选择、通过 `/root/EventBus.building_state_changed` 广播状态刷新。
当前状态：T0304 已实现基础建筑数据读取、场景节点绑定、运行时点击区、调试标签状态显示、`get_building(...)` 等查询接口、建筑入口坐标查询 `get_building_entry_position(...)`、地点当前状态占位 `get_building_location_context(...)` 和最小修复/升级逻辑；2026-05-20 已补充 `_unhandled_input` 相机射线拾取，真实鼠标点击建筑可稳定触发 `building_clicked`。T0006 后建筑受损、修复进度、协助者变化、修复完成和升级只触发 `building_state_changed`，不再伪装为建筑点击。T0801 新增 `claim_workstation(...)` / `release_workstation(...)`，作为工作位占用和释放的权威接口；工位变化仍通过 `building_state_changed` 交给 MemorySystem 广播地点内部状态差量。修复/升级消耗由 `ResourceSystem` 结算，资源不足时不会改变建筑状态；修复和升级都会创建随 `logical_time_tick` 推进的倒计时作业，并可被多个 NPC 按工程熟练度协助加速；建筑受损、正在修复或正在升级时不能开始升级，只有完好建筑可升级；协助者离开对应建筑或被改派时会从作业中移除；T1102 新增 `apply_damage_to_building(...)` 供 CombatSystem 结算敌方建筑伤害，并写入 `building_damaged` 结构化事件；建筑/地点节点后续只保存当前状态并负责广播，不保存事件历史。

路径：`res://scripts/systems/NPCSystem.gd`
用途：基础 NPC 系统，负责读取 NPC 档案、生成 NPC 占位实体和转发 NPC 点击事件。
依赖：通过 `/root/ConfigLoader` 读取 `data/npc_profiles.json`，实例化 `res://scenes/npc/NPC.tscn` 到 `Main/WorldRoot/Station/NPCs`，并通过 `/root/EventBus.npc_clicked` 广播点击事件。
当前状态：T0403/T0409 后，移动到达会通过 `MemorySystem.move_npc_between_locations(...)` 更新地点 `people_present` 并写入进入快照；室内信息地点切换到另一个室内信息地点时，会在事件与地点信息层插入“离开原地点 -> 进入广场 -> 离开广场 -> 进入目标地点”的中转链，物理表现仍是直线移动占位。T0501/T0502/T0503 已实现 HP 扣除、昏迷恢复和协助治疗；T0808 已实现诊所病床治疗和研读医术。T0702 新增征召权威更新入口；T0703 新增 `get_current_order(...)`、`publish_npc_order(...)` 和最近计划重评估请求快照，只有已入伍 NPC 的指令文本变化时才写入私有事件并发出请求。T1001 新增 `get_npc_plan(...)` / `set_npc_plan(...)` 和 `stop_npc_movement_for_system(...)`，供每日计划系统保存计划并在小时计划切换时安全中断移动。T1004 新增 `get_npc_long_memory(...)` 与 `apply_daily_reflection(...)`，用于写入长期日记并合并知识图谱占位更新。T0704 新增 `give_money_to_npc(...)`；T0013 后旧占位武器兼容入口已移除，正式装备统一通过 T0901 `EquipmentSystem`。T0901 新增 `get_npc_equipment(...)` / `set_npc_equipment_slot(...)`，NPCSystem 只负责保存装备槽和刷新 NPC 状态，不负责库存扣除或兵种判定；T1103C 起，如果避战中的已入伍 NPC 获得主武器，会交给 CombatSystem 按当前敌军分流到战斗。T0904 新增 `increase_npc_skill(...)`、`get_npc_progression(...)`、`assign_npc_attribute_point(...)` / `debug_assign_attribute_point(...)`，统一熟练度经验、未分配技能点和玩家分配力量 / 智力。T0705 新增 `debug_start_proactive_talk(...)`、`get_proactive_talk(...)` 和 `handle_npc_clicked(...)`，可让 NPC 进入主动找守备官交涉状态、显示问号气泡、点击后打开既有对话面板，并在超时或对话结束后请求计划重评估。T1204A 后，`handle_npc_clicked(...)` 对正在逃离的 NPC 返回未接管，让点击路径打开 NPC 面板而不是直接进入挽留对话；NPCPanel 再通过【对话】按钮进入逃离挽留。T1102 新增只读 `get_npc_world_position(...)` 供 CombatSystem 做附近单位目标选择；敌人对 NPC 的伤害复用既有 `apply_damage_to_npc(...)` 昏迷链路。T1202 后，`apply_damage_to_npc(...)` 的权威扣血结果会延迟通知 CombatSystem 进行战时低血量判定。T1103 新增 `move_npc_to_world_position(...)` 和 `stop_npc_movement_with_state(...)`，供 CombatSystem 将入伍持武器 NPC 移动到城门外集结点或暂停逃离挽留移动。T1103A 新增 `set_npc_behavior_mode(...)`、`get_npc_behavior_mode_snapshot(...)`、`debug_get_behavior_mode_snapshot(...)` 和睡觉判定接口，统一保存 `behavior_mode`、进入原因和进入时间，并继续兼容 `combat_mode`。T1103B/T1103C 后，避战快照包含 `avoidance_target_id` / `avoidance_target_name` / `avoidance_target_position`，`set_npc_recruited(...)` 会在 NPC 避战中应征成功时交给 CombatSystem 分流：无主武器继续避战，有主武器且仍有敌军进入 `combat`，无敌军回到 `work`。T1105 后，NPCSystem 运行时状态会保存 `states.combat_strategy` 和 `combat_strategy_move_target_*` 策略移动目标，并在行为模式快照中暴露这些字段。T1204A 后，守备官给钱或攻击逃离 NPC 会通知 CombatSystem 调整逃离速度，逃离挽留攻击不触发 NPC LLM 回复，攻击导致昏迷时逃离暂停并在复苏后继续。模式切换可强制中断普通行动、移动、可取消 LLM 和当前对话；T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 不写入 `npc_mode_changed`，其他需要留痕的模式变化仍可记录。仍不实现复杂避障、真实计划重评估或真实 LLM。

路径：`res://scripts/systems/EquipmentSystem.gd`
用途：正式装备系统，负责把派生库存转换为 NPC 装备槽，并提供兵种判定。
依赖：通过 `/root/ConfigLoader` 读取 `data/weapon_defs.json`、`data/armor_defs.json` 和 `data/mount_defs.json`；调用 `ResourceSystem.spend_resources(...)` / `add_resource(...)` 结算装备库存；调用 `NPCSystem.set_npc_equipment_slot(...)` 写入槽位；通过 `MemorySystem.record_player_interaction(...)` 写入 `equipment_given` / `equipment_changed`。
当前状态：T0901 已实现主武器、头盔、胸甲、腕甲、腿甲和坐骑槽。只有已入伍 NPC 可由守备官直接分配装备；装备主武器消耗 `weapons`，装备盔甲消耗 `armor`，装备坐骑消耗 `horse_readiness`，换装会返还旧装备对应库存。T0902 已独立验收兵种判定：`determine_unit_type(...)` / `get_npc_unit_type(...)` 可按主武器与 `equipment.mount` 槽返回非战斗人员、近战步兵、长杆步兵、弓箭兵、弩兵、近战骑兵或骑射单位；`get_unit_type_snapshot(...)` 返回兵种、武器类型、武器 class、坐骑槽和装备快照，供 GM 与后续战斗系统只读使用。`horse_readiness` 库存本身不会让 NPC 被判定为骑兵。T1103 后，CombatSystem 只读该快照决定警铃集结阵型和集结 / 接敌坐骑显示；T1104 后，CombatSystem 会读取主武器数值、盔甲防御和坐骑槽参与基础攻击与攻速修正；T1105 后，更换主武器或坐骑会调用 CombatSystem 归一化当前战斗策略并重置为新兵种默认策略，换盔甲不重置策略。EquipmentSystem 本身不结算装备耐久、完整外观换装或战斗伤害。

路径：`res://scripts/npc/NPC.gd`
用途：通用 NPC 占位实体脚本，保存 `npc_id` 和档案快照，刷新短姓名/HP/当前行动标签，并处理点击。
依赖：绑定到 `res://scenes/npc/NPC.tscn`，通过 `/root/EventBus.npc_clicked` 发出点击事件。
当前状态：T0304 已创建；普通点击 NPC 会打印 ID 并发出 `npc_clicked(npc_id)`；头顶标签只显示短姓名、HP 和当前行动摘要；T0705 后若 NPC 有主动交涉状态，点击会优先交给 `NPCSystem.handle_npc_clicked(...)` 打开对话，不再先弹出 NPC 面板，并在运行时显示 `ProactiveTalkBubble` 问号气泡；T1103 后运行时创建 `CombatMountVisual` 和 `CombatFacingMarker`，T1103A 起优先按 `behavior_mode` 为 `rally` / `combat` 时显示集结/接敌方向标记，兼容旧 `combat_mode`，且只有 `combat_mounted == true` 的 NPC 显示低模坐骑；T1105 后策略移动中的 NPC 头顶行动摘要显示“战术移动”；T1204A 后逃离中的 NPC 头顶显示 `!` 警告标记，行动摘要显示“逃离”，逃离移动会读取 `escape_intent.speed_multiplier`；支持 `move_to_location(...)` 直线移动，到达后发出 `movement_arrived` 给 `NPCSystem` 写回地点状态。

路径：`res://scenes/npc/NPC.tscn`
用途：通用 NPC 低模占位场景。
依赖：绑定 `res://scripts/npc/NPC.gd`，由 `NPCSystem` 实例化。
当前状态：T0303 已创建；当前包含 `Area3D` 点击区、低模胶囊身体、头部和 `Label3D` 短姓名/HP/当前行动调试标签。T0705 后问号气泡由 `NPC.gd` 运行时创建，T1204A 后逃离警告 `!` 标记也由 `NPC.gd` 运行时创建，不需要手改场景资源。

路径：`res://scripts/systems/MemorySystem.gd`
用途：事件、见闻与地点/广场信息节点系统。
依赖：由 ActionSystem、NPCSystem、DialogSystem、CombatSystem、BuildingSystem 等系统写入事件；读取 GameState / TimeSystem 的游戏时间；通过 EventBus 广播 `event_recorded`、`npc_memory_changed`、`location_info_changed` 和 `public_event_added`。
当前状态：T0405 已实现 NPC 短期记忆容器查询；支持 `get_npc_short_term_memory(...)`、`get_npc_short_term_memory_ids(...)`、`clear_npc_short_term_memory(...)`、`record_player_interaction(...)`、`debug_record_player_money_given(...)`、`debug_record_player_attack_npc(...)`、`debug_get_npc_witness_events(...)`、`debug_get_npc_short_term_memory(...)` 和 `debug_clear_npc_short_term_memory(...)`。T0404/T0408/T0409 已实现广场信息即时广播并统一为 `location_id == "plaza"` 的 `local_public`；支持 `move_npc_between_locations(...)`、`get_location_snapshot(...)`、`get_location_people_present(...)`、`is_enterable_location(...)`、`set_plaza_notice(...)`、`broadcast_plaza_event(...)`、`broadcast_plaza_state_change(...)`、`notify_key_entity_state_changed(...)` 及对应调试接口。2026-05-25 起，MemorySystem 监听 `building_state_changed`：任一建筑可传播外部状态会同步进广场 `building_external_states` / `key_entities` 并生成带具体建筑名和具体事实的 `plaza_status_changed`；可进入建筑的外部或内部可传播状态当前会生成 `location_status_changed` 本地见闻。可传播外部状态只计算等级与完好/受损/正在修复/正在升级；HP、剩余修复/升级时长不触发广播。广场和可进入建筑进入快照都会生成 `people_statuses`，把当前在场 NPC 的生命状态写为健康/受伤/昏迷，昏迷时可列出治疗者，并把 `current_action` 翻译成精简中文；T1103 后行动状态摘要会把集结 / 接敌状态显示为“前往城门外防线 / 在城门外集结 / 准备接敌”，T1105 后会把策略移动显示为“进行战术移动”，T1203/T1204A 后会把逃离显示为“正朝后门逃离 / 已离开驿站”；可进入建筑还会提供每个工位占用/空闲，工位数量不触发广播。NPC 进入广场会获得当前广场在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态，进入可进入建筑会获得该建筑外部 + 内部状态。T0407 已实现：`location_entered` / `location_exited` 事件库只保留进出行动事实，进入者获得一次状态见闻，已在场 NPC 只收进出事件，建筑/地点状态变化改为字段级差量见闻。T0402 已升级为结构化事件事实源；支持 `add_event(...)`、`get_event_log()` / `get_all_events()`、`get_npc_daily_events(...)`、`get_npc_witness_events(...)`、`get_plaza_events(...)`、`add_witness_event(...)` 和调试查询接口。T0502A 后，`add_witness_event(...)` 会拒绝给昏迷 NPC 写入见闻，复苏后自动恢复。事件会规范化为包含 `event_id`、`day`、`time`、`type`、`subject_npc_id`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary`、`payload` 的结构，并首先写入对应 NPC 当天事件库；`local_public` 会转发给事件地点当前在场且未昏迷 NPC 的见闻库，广场事件通过同一机制转发给广场当前在场且未昏迷 NPC 并可被广场查询返回。玩家非对话交互写入时 actor id 使用 `guard_officer`，summary 使用“守备官”。T0705 新增 `proactive_talk_started` / `proactive_talk_message` 事件模板：主动交涉发起和 NPC 开场问题先进入发起者事件库；玩家后续回复仍走既有 `dialogue_turn`。T1103 新增 `combat_alarm_rang`、`combat_rally_started` 和 `combat_rally_encountered_enemy` 事件模板，记录听到警铃、前往城门外集结和集结途中接敌；T1105 新增 `combat_strategy_selected`，记录守备官为入伍持武器 NPC 设置当前战斗策略；T1202 新增 / 完善 `low_hp_triggered`、`battle_psychology_result` 和低血来源的 `morale_boost_started` 摘要，支持“继续参战 / 继续避战 / 逃离 / 斗志激昂”的公开事件表达；T1203 新增 `escape_started` / `escaped` 摘要；T1204A 新增 `escape_intervention_result` 与 `escape_speed_changed` 摘要，记录挽留后留下 / 继续逃离和给钱 / 攻击造成的逃离速度变化。公告变更写入 `plaza_notice_changed`，建筑状态变更写入 `plaza_status_changed` 或 `location_status_changed`。MemorySystem 不提供按地点查询事件的长期接口，地点/广场节点也不保存事件历史；T1004/T1005 首次睡眠总结只清空指定 NPC 的当天事件/见闻索引，不删除全局事件档案。

路径：`res://scripts/systems/ActionSystem.gd`
用途：行动系统占位脚本，后续用于工作、吃饭、睡觉、训练等行动调度。
依赖：通过 `/root/ConfigLoader` 读取 `data/action_defs.json`，调用 `NPCSystem` 移动与状态接口、`ResourceSystem` 资源结算接口，并写入 `MemorySystem` 结构化事件。
当前状态：T0402 已在 T0305 工作 / 吃饭 / 睡觉最小行动闭环上接入结构化事件；提供 `debug_assign_work(...)`、`debug_assign_repair_assist(...)`、`debug_assign_upgrade_assist(...)`、`debug_assign_heal_assist(...)`、`debug_assign_eat(...)`、`debug_assign_sleep(...)`、`debug_assign_action(...)` 和只读 `get_healing_helpers_for_target(...)`。T1001 新增 `get_pending_action_id(...)`、`get_active_action_id(...)`、`get_runtime_action_id(...)` 和 `interrupt_npc_action(...)`，供计划系统判断与中断行动。T0801 后，工作支持真实工位占用/释放和统一效率公式：NPC 对应熟练度、力量/智力属性和建筑等级会缩短单位工作周期；T0803 后，配置了 `output_scaling` 的工作可按熟练度、属性和建筑等级提高实际产出，当前菜园产粮使用该规则。T0804 后，铁匠铺工作使用打铁和力量，消耗铁并产出 `weapons` / `armor` 派生库存。T0805 后，工械坊工作使用工程和智力，消耗木材并产出 `weapons` / `defense_devices` 派生库存。T0806 后，马厩工作使用养马和力量，消耗粮食并产出 `horse_readiness` 派生库存。T0901 后，`weapons` / `armor` / `horse_readiness` 可由 `EquipmentSystem` 转换为 NPC 装备槽。T0903 后，训练场支持 `training_instructor` 教官工位和 `training_student` 受训位：无武器且无坐骑不能当教官或受训者；受训者需要已有教官；教官独处时极慢提升自己当前装备对应武器 / 骑术，有受训者时受训者按自己的装备提升对应熟练度，教官提升“教练”。当前工作支持菜园产粮、食堂加工餐食、酒窖酿酒、铁匠铺制造武器/盔甲库存、工械坊制造弓弩/工程器械库存、马厩产出马匹整备。建筑修复和升级由 `BuildingSystem` 创建倒计时作业，NPC 行动只负责在广场协助正在进行的修复/升级并加速倒计时。协助治疗是带昏迷 NPC 目标的运行时行为，治疗者会前往目标所在信息地点，最多 2 人协助同一目标，按医术熟练度调用 `NPCSystem` 加速昏迷恢复，并按逻辑时间消耗第纳尔。工作、训练、吃饭、睡觉会以 `local_public` 写入事件，让同地点当前在场 NPC 收到见闻；协助修复/协助升级同样以 `local_public` 写入 `repair_assist_started` / `upgrade_assist_started`，事件地点为 `plaza`；协助治疗写入 `healing_started` / `healing_completed`，进入治疗者和目标事件库，并写入同地点其他在场 NPC 的见闻库，事件信息不暴露医术熟练度。T0401 暂停语义修正后，暂停期间不会执行行动结算；2026-05-25 起，吃饭、睡觉、工作和训练到达地点后进入 active 行动并随 `logical_time_tick` 推进。未实现 LLM 日程、战斗、工程器械部署或其他职业特殊生产平衡。

路径：`res://scripts/systems/DailyPlanSystem.gd`
用途：每日计划系统，负责生成规则版或 LLM / Mock 版 24 小时 NPC 计划、写入计划事件，并按小时打点调用行动系统；行动异常或指令变化时负责应用计划修订或规则降级。
依赖：读取 `NPCSystem` 的 NPC、熟练度和计划字段；调用 `LLMBridge.request_npc_daily_plan(...)` / `request_npc_plan_revision(...)` 获取后端 Mock 计划；调用 `ActionSystem.debug_assign_action(...)` / 协助类接口执行计划项，并通过 `ActionSystem.interrupt_npc_action(...)` 在计划切换时中断旧行动；调用 `MemorySystem.add_event(...)` 写入 `plan_created` / `plan_revised`。
当前状态：T1001 已实现规则计划：默认按熟练度选择工作行动，24 小时计划至少包含 6 个工作阶段；执行只接管已经显式生成计划的 NPC，按 `hour_started` 执行当前小时项，同一小时内计划启动的行动提前完成会重复执行当前项。T1002 已接入行动异常和统一计划重评估：资源不足、工位占用、目标不可用、对话打断、守备官攻击、主动交涉结束 / 超时、战斗警报占位和新指令会触发 `/npc/revise_plan` Mock 修订，成功时合并修订计划并执行当前小时行动，失败时应用 `rule_revision_fallback` 规则降级计划。T1003 新增 `generate_daily_plan_for_npc(...)`，优先通过 `LLMBridge.request_npc_daily_plan(...)` 请求 `/npc/plan_day` 并应用 `mock_plan_day` 计划，后端不可用、输出不合法、不是 24 阶段或工作阶段不足时回退 `rule_plan_fallback`。

路径：`res://scripts/systems/DailyReflectionSystem.gd`
用途：首次睡眠总结系统，负责监听睡觉开始 / 结束和逻辑时间、在每日首次睡眠满 1 游戏小时后生成反思、写入长期日记、更新知识图谱占位并清空当天短期记忆。
依赖：监听 `EventBus.event_recorded` 的 `sleep_started`；读取 `MemorySystem.get_npc_short_term_memory(...)`；调用 `LLMBridge.request_npc_daily_reflection(...)` 请求 `/npc/daily_reflection`；调用 `NPCSystem.apply_daily_reflection(...)` 写入长期记忆；调用 `MemorySystem.clear_npc_short_term_memory(...)` 清空该 NPC 当天短期索引。
当前状态：T1004/T1005 已实现；每名 NPC 每天首次睡眠满 1 游戏小时后自动生成一次，发起到完成期间不可被对话、指令或行动改派打断，后端不可用时使用模板降级，GM 可通过 `debug_generate_reflection(...)` 强制触发。

路径：`res://scripts/systems/CombatSystem.gd`
用途：敌人波次读取、调试生成、目标选择、基础移动、双方基础攻击、战斗动作秒换算、不同兵种战斗策略和战斗调试快照系统，后续继续承接正式战斗流程。
依赖：通过 `/root/ConfigLoader` 读取 `data/enemy_waves.json`；在 `Main/WorldRoot/Station/Enemies` 下生成运行时敌人节点。
当前状态：T1101 已实现 5 波敌人配置读取、波次查询、`spawn_wave(...)`、`debug_spawn_wave(...)`、`debug_clear_enemies(...)` 和 `debug_get_combat_snapshot(...)`。生成的敌人是低模 `Area3D` 占位，保存 `enemy_id`、`wave_number`、HP、武器类型、单位类型、攻击、防御、移动速度、目标偏好和位置元数据，头顶显示名称 / HP / 单位类型标签。T1102 后，`CombatSystem` 监听 `logical_time_tick` 推进敌人目标选择、移动和敌方攻击；附近可行动 NPC 优先，否则按城门、仓库、主厅选择仍有 HP 的建筑。T1104C 后，围墙不再作为敌人攻击目标，旧配置中的 `wall` / `front_wall` 会在目标偏好规范化时过滤；城门被攻破后直接转向仓库，后续真实路径阻挡留给碰撞 / 导航任务。T1104 后，CombatSystem 会先推进 `combat` 模式入伍持武器 NPC 的基础自动攻击，再推进敌方攻击；我方攻击读取武器伤害 / 射程 / 攻击间隔、力量、熟练度、疲劳、饱食、坐骑和敌人防御，敌人 HP 清零后移除；敌人攻击 NPC 时读取 NPC 盔甲防御后复用 `NPCSystem.apply_damage_to_npc(...)`，攻击建筑时调用 `BuildingSystem.apply_damage_to_building(...)`，主厅清零后写入 `GameState` 失败占位。

T1104A 后，CombatSystem 不再把玩家 `x2` / `x4` 作为战斗伤害、攻速或战斗移动倍率；活动敌人存在时会通过 TimeSystem 注册 `combat_enemy_presence` `x1` 上限，清敌或最后一个敌人被移除时释放。T1104B 后，CombatSystem 把 `game_delta_seconds / 60` 折算为战斗动作秒推进攻击冷却，并在最近 AI / 我方攻击快照中暴露 `combat_seconds`；第一波敌人已按艾达持剑基准校准为低强度探路战。T1105 新增 `get_combat_strategy_options_for_unit_type(...)`、`get_npc_combat_strategy_options(...)`、`get_npc_combat_strategy(...)`、`set_npc_combat_strategy(...)` 和 `normalize_npc_combat_strategy(...)`，可按兵种提供策略选项、保存玩家手动选择、在换主武器 / 坐骑时重置默认策略，并执行主动进攻、最大化输出、保持距离射击、拉开距离冲击和战斗内避战；T1105A 后，战斗内避战只在最近敌人低于安全阈值时短步长远离，敌人已远离到阈值外时停止移动并保持 `combat_ready`。

T1103 新增 `trigger_combat_alarm(...)` / `debug_trigger_combat_alarm(...)`、`get_active_rallies(...)` 和 `get_last_alarm_result(...)`，警铃会写入全员警铃事件，并让入伍持武器 NPC 按前后排集结。T1103A 后，CombatSystem 通过 NPCSystem 的 `behavior_mode` 接口统一维护集结等待 1 小时超时、工作 / 集结 / 战斗 / 避战切换、敌军清空后的退出和昏迷复苏分流；T1103B/T1103C 后新增 `active_avoidances`、`debug_trigger_npc_avoidance(...)`、`get_active_avoidances(...)` 和避战中应征 / 装备分流，未入伍或已入伍但无主武器 NPC 会按敌方方位短步长四散移动，清敌后回到 `work` 且不请求计划重评估。T1106 后，CombatSystem 会在波次生成时写入广场 `combat_started`，在敌军全灭或 GM 清敌时写入广场 `combat_ended`，并维护本场受伤 / 昏迷 NPC、低血量判定与各 NPC 击退敌人统计；清敌时 `combat` 回 `work` 并请求计划重评估，`avoid_combat` 与未接敌 `rally` 回 `work` 且不强制重评估。

T1201 新增 `build_battlefield_context(...)` 与 `apply_wartime_dialogue_reaction(...)`，战时对话可写入 `battle_psychology_result` 和 2 游戏小时 `morale_boost` 攻击 / 移动加成。T1202 新增 `handle_npc_damage_applied(...)`、低血量判定记录、`low_hp_triggered` 事件写入、`/npc/battle_judgement` 请求应用和规则降级：参战且已入伍持主武器的 `combat` NPC 可继续参战、逃离或斗志激昂，避战 / 非战斗人员只能逃离或继续避战。T1203 新增 `start_npc_escape(...)` / `debug_start_npc_escape(...)` / `handle_npc_escape_completed(...)`，战时逃离意向和 GM 调试会写入 `escape_started`、移动到后门外出口，并在 NPC 离图后记录 `escaped`。T1204A/T1204B 已包含 `apply_escape_intervention_result(...)`、`get_escape_intervention_state(...)`、`pause_escape_for_dialogue(...)`、`resume_escape_after_dialogue(...)`、`handle_escape_money_given(...)`、`handle_escape_guard_attack(...)` 和 `record_escape_attack_intervention_round(...)`：逃离 NPC 最多接受 5 轮挽留，打开对话时暂停移动、关闭时恢复移动，结果只会是留下或继续逃离；给钱会降低逃离速度，逃离挽留攻击会提高逃离速度、计 1 轮并关闭面板但不请求 NPC 回复，也不写 `escape_intervention_result`，昏迷只暂停逃离并在复苏后继续前往后门。`debug_get_combat_snapshot()` 包含行为模式快照、避战快照、逃离快照、逃离挽留轮次和速度倍率、战斗策略快照、当前战斗 `active_battle`、最近战斗开始 / 结束结果、最近战时对话结果、最近低血量判定结果、最近逃离结果、最近模式切换结果、最近避战结果、最近我方攻击结果和 TimeSystem 倍率快照，`debug_advance_rally_wait(...)` 可供 GM / 自动化推进集结等待。当前仍不实现正式胜负结算或命中率。

路径：`res://scripts/systems/LLMBridge.gd`
用途：Godot 侧后端桥接脚本，负责请求 `/health`、`/npc/dialogue`、`/npc/plan_day` 与 `/npc/revise_plan`，构造 T0603 对话 payload、T1003 每日计划 payload 和 T1002 计划修订 payload，并管理 LLM 等待期间的 TimeSystem 慢速请求。
依赖：挂载到 `Main/Systems/LLMBridge`；读取 `NPCSystem`、`ActionSystem`、`MemorySystem`、`GameState` 和 `TimeSystem`；使用 Godot 原生 `HTTPClient` 请求游戏后端。
当前状态：T0604/T0604A 已实现原生 HTTP 后端桥接；T0701 由 DialogSystem 调用该桥并将成功回复显示到对话 UI、写入对话事件。T0703A/T1002/T1003/T1004/T1005 后，LLMBridge 统一把最新 `current_order` 注入对话顶层 payload、每日计划 payload、计划修订 payload、首次睡眠总结 payload 与共享 NPC 上下文，并保存最近注入快照供 GM / 自动化观察。每日计划请求包含行动白名单、资源快照、建筑状态、地点上下文、短期记忆和长期记忆；首次睡眠总结请求包含当天事件摘要和已有日记。对话、每日计划、计划修订、低血量自身心理判定和首次睡眠总结都会申请 TimeSystem 慢速；对话可取消普通可取消 LLM 活动，但不能取消低血量判定和首次睡眠总结。T1006 新增异步对话请求 `request_npc_dialogue_async(...)`，供 DialogPanel 在等待回复时保持 UI 可结束 / 取消；取消会释放慢速、清除 NPC LLM 活动并丢弃后续结果。T1201 后，战时公开对话 payload 会加入 `interaction_context` 和 `battlefield_context`，并接收 `wartime_reaction`；T1202 后，低血量自身心理判定使用 `request_npc_battle_judgement(...)` / `build_npc_battle_judgement_payload(...)` 请求 `/npc/battle_judgement`，携带 `battlefield_context`、低血量事实、最新 `current_order` 和 Godot 侧限制后的 `allowed_decisions`。T1204A 后，逃离挽留中玩家发送消息并等待 NPC 回复的轮次复用 `/npc/dialogue`，payload 带 `dialogue_kind="escape_intervention"`、`interaction_context="escape_intervention"` 和 `escape_intervention_round`；逃离挽留攻击由 Godot 直接计轮并关闭面板，不调用 LLMBridge。LLMBridge 本身仍不修改征召状态、资源、HP、模式或行动权威结算。

路径：`res://scripts/systems/DialogSystem.gd`
用途：Godot 侧对话会话权威入口，维护参与者、历史、公开性和轮次，调用 LLMBridge 并写入 MemorySystem。
依赖：`NPCSystem`、`LLMBridge`、`MemorySystem`、`Main/UI/DialogPanel`。
当前状态：T0701/T0702 已实现玩家-NPC 不限轮次对话与 NPC-NPC 默认 5 轮语义；支持开始、发送、结束、一次性应征请求标记、接受/拒绝结果应用和结构化对话事件。T0705 新增 `start_proactive_player_dialogue(...)`，复用玩家-NPC 对话面板，让 NPC 预先确定的开场问题作为第一条历史显示并先入库；对话结束后请求计划重评估。T1006 起，`start_player_dialogue(...)` 只打开会话，不打断行动、不取消 LLM、不挂结束重评估；玩家实际发送消息后才触发打断和可取消 LLM 取消。结束时只有已完成玩家消息 + NPC 回复，或已提交普通攻击事实，才请求计划重评估。新增 `attack_target_npc(...)`：普通对话中先通过 NPCSystem 扣血并写惩戒攻击事件，再请求 NPC 攻击回复；回复取消时攻击事实保留。T1103A 新增 `force_end_dialogue_for_npc(...)`，供行为模式切换强制关闭当前对话并取消未完成回复。T1201 后，集结 / 战斗 / 避战玩家对话强制 `local_public`，请求携带 `interaction_context` / `battlefield_context`，并把 `wartime_reaction` 交给 CombatSystem 结算；战时后端失败会走规则 fallback。T1204A 后，`start_escape_intervention_dialogue(...)` 由 NPC 面板【对话】按钮进入，强制公开、最多 5 轮、隐藏应征入口；打开时调用 CombatSystem 暂停逃离，关闭或满 5 轮时恢复逃离。逃离挽留攻击在 `attack_target_npc(...)` 内走无回复分支：计 1 轮、关闭面板、继续逃离，不请求 NPC LLM 回复。

路径：`res://scripts/ui/DialogPanel.gd`
用途：显示 NPC 名字、对话历史、公开性、轮次、输入框、发送和结束按钮。
依赖：调用 `Main/Systems/DialogSystem`。
当前状态：T0701/T0702 已创建并绑定到 `Main/UI/DialogPanel`；T1006 后右上角显示“同地点公开”和“提出应征”两个 toggle，“攻击”按钮位于发送按钮旁。普通发送和普通攻击走异步对话请求，等待期间输入框仍可编辑但发送 / 攻击按钮禁用；结束等待中的普通消息会取消本轮 LLM 且不入库，结束等待中的普通攻击会保留攻击事件并触发重评估。T1201 后战时对话会把“同地点公开”锁定为开启并显示战时公开状态；T1204A 后逃离挽留模式显示当前 / 最大 5 轮，隐藏应征 toggle，保留攻击按钮；打开时暂停 NPC 逃离移动，未满 5 轮关闭后恢复移动，达到轮次上限后自动关闭并让 NPC 面板【对话】置灰。逃离挽留攻击会计 1 轮、关闭面板并恢复逃离，不请求 NPC 回复。

路径：`res://scripts/ui/HUD.gd`
用途：HUD 展示脚本，刷新标题区下方的天数、`HH:MM:SS` 时间/阶段、全量资源栏、装备/器械库存详情、速度/暂停按钮和后端状态占位。
依赖：读取 `/root/GameState`，监听 `/root/EventBus.time_changed`、`hour_started`、`day_started` 和 `resource_changed`，从 `Main/Systems/ResourceSystem` 读取当前资源和资源定义，并从 `EquipmentSystem` / `NPCSystem` 读取装备详情展示所需的只读状态。
当前状态：T0012 后会按 `data/resource_defs.json.ui_order` 动态生成非聚合资源标签，显示第纳尔、粮食、餐食、酒、木材、石料和铁；资源栏右侧“装备”“器械”按钮会打开运行时创建的 `ResourceDetailPanel`，展示聚合库存、装备定义、已分配数量或工程器械库存说明，面板贴近各自按钮左下并保持在屏幕内。HUD 只读取系统状态，不直接修改资源、装备或器械事实。
当前状态：T0604 后，HUD 后端状态会读取 `LLMBridge.get_last_backend_status()` 并监听 `backend_status_changed`；T0401 已接入真实时间推进、秒级时间显示、速度按钮、暂停按钮和空格暂停；速度按钮显示玩家设定倍率，空格只触发暂停/继续，不触发速度切换；LLM 等待造成的有效逻辑倍率由 TimeSystem 提供给后续调试 UI；T0012 已接入真实资源主栏去重与装备/器械详情定位；2026-05-20 已让 HUD 根节点忽略鼠标，避免全屏背板拦截建筑点击；T1103 后警铃按钮调用 `CombatSystem.trigger_combat_alarm("hud")` 触发集结；T1204A 后 HUD 会在任一 NPC 正在逃离或昏迷暂停逃离时显示“警告：某人正在逃离驿站”。

路径：`res://scripts/ui/UIInputFocusManager.gd`
用途：Main UI 层输入焦点管理脚本，统一处理 LineEdit / TextEdit 点击外部失焦。
依赖：挂载到 `Main/UI`，读取当前 GUI 焦点和鼠标悬停 Control，不参与资源、HP、事件或行动结算。
当前状态：T0704 反馈修正已创建；任意文本输入控件获得焦点后，点击输入框外任意位置会释放焦点，NPC 给钱数量框、对话输入框和指令 TextEdit 已纳入验证。

路径：`res://scripts/ui/BuildingPanel.gd`
用途：建筑信息面板脚本，监听建筑点击并展示建筑名称、等级、HP、工位空闲数 / 占用者和地点信息占位。
依赖：监听 `/root/EventBus.building_clicked` 和 `/root/EventBus.building_state_changed`，从 `Main/Systems/BuildingSystem` 读取建筑状态。
当前状态：T0303 已接入 `Main/UI/BuildingPanel`；T0016 后不再显示单独的“当前工作位 x/x”汇总行，而是按工位类型显示 `空闲数/总数：占用者`，占用者从 `NPCSystem` 读取 NPC 名字；修复和升级按钮会调用 `BuildingSystem`，并根据 HP、等级、配置、是否已有修复/升级作业和资源是否足够自动启用或禁用；建筑受损、正在修复或正在升级时不可升级；修复/升级的资源消耗和执行条件只在按钮悬停提示框中显示，不常驻写入面板正文；提示框靠近屏幕边缘时会保持在可视区域内；修复和升级进行中都会展示剩余时间、进度、速度倍率和协助人数；点击 NPC 时会隐藏建筑面板；T0006 后只有当前建筑面板仍可见时才响应建筑状态刷新，因此进度刷新不会抢占 NPC 面板。

路径：`res://scripts/ui/NPCPanel.gd`
用途：NPC 信息面板脚本，监听 NPC 点击和状态变化并展示 NPC 基础状态。
依赖：监听 `/root/EventBus.npc_clicked`、`/root/EventBus.npc_state_changed` 和 `/root/EventBus.building_clicked`，从 `Main/Systems/NPCSystem` 读取 NPC 档案与状态。
当前状态：T0405 后，`Main/UI/NPCPanel` 会显示 NPC 当天事件库和见闻库，并监听 `npc_memory_changed` 刷新；T0014 后事件库和见闻库使用固定高度滚动区，刷新后自动滚到底部但允许手动上滑查看旧事件；T0018 后点击事件库或见闻库标题 / 正文区域会打开 `NPCMemoryDetailPopup` 大号详情弹窗，显示当前 NPC 对应记录的时间、summary、类型、地点、可见性、重要度、事件 ID、参与者、目标和 payload，右上角 `×` 可关闭；T1004/T1005 后新增长期日记滚动区，显示首次睡眠总结写入的日记和记忆摘要，并在名字旁显示“正在思考 / 正在计划下一步行动 / 正在熟睡”；T0703 后已入伍 NPC 显示可用“指令”按钮并打开 `OrderPanel`，点击“对话”或“指令”不会关闭 NPC 面板，`DialogPanel` 与 `OrderPanel` 互斥不重叠；T0704 后面板新增非对话交互区，可选择 `private` / `local_public` 可见性并给钱，给钱数量输入框紧邻“给钱”按钮；T1006 起攻击入口已移到 DialogPanel，NPCPanel 不再直接扣血；T1204A 后逃离 NPC 点击也打开 NPCPanel，【对话】按钮在剩余挽留轮次大于 0 时可进入逃离挽留，满 5 轮后置灰并提示轮次已用完；T0901 后面板可选择主武器并为已入伍 NPC 调用 `EquipmentSystem` 装备，当前装备显示会列出主武器、盔甲、坐骑和战斗定位；T1105 后“装备武器”旁运行时创建 `NPCCombatStrategySelect` 下拉框，只在已入伍且有主武器、存在当前兵种可选策略时启用，并调用 CombatSystem 设置当前战斗策略；T0015 后面板在 HP 右侧显示 `经验：当前 / 阈值`，力量 / 智力属性旁仅在有未分配技能点时显示 `+1` 按钮调用 NPCSystem 分配；T1103A 后“当前行动”行同时显示行为模式；点击建筑时会隐藏 NPC 面板。

路径：`res://scripts/ui/OrderPanel.gd`
用途：已入伍 NPC 自然语言指令撰写与发布面板。
依赖：调用 `NPCSystem.get_current_order(...)` / `publish_npc_order(...)`；内嵌于 `Main/UI/OrderPanel`。
当前状态：T0703 已实现；打开时预填当前指令，发布变化文本时显示修订结果，关闭或相同文本无副作用。

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
依赖：挂载到 `Main/UI/GMPanel`；调用 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem`、`MemorySystem` 和 `CombatSystem` 的已有公开接口或 `debug_*` 接口；使用顶部 `GM_ENABLED` 常量控制开发/上线显示。
当前状态：T0004 已实现；支持资源、时间、建筑、NPC、行动、记忆/见闻/广场公告等调试入口。T1104A 后时间分组新增 TimeSystem 倍率快照，`snapshot` / `time_snapshot` 可查看玩家选择倍率、有效倍率、LLM 慢速请求和 TimeSystem 上限请求。T0014 后行动区普通行动统一通过行动下拉和“指定行动”按钮触发，不再为工作、吃饭、睡觉、训练场教官/受训者保留并列快捷按钮；协助修复、协助升级、协助治疗等需要目标参数的入口继续保留。T0703 新增发布/查看指令和查看最近计划重评估请求入口；支持 `publish_order`、`order`、`plan_request`。T0705 新增主动交涉按钮和 `start_proactive` / `proactive` 命令，调用 `NPCSystem` 调试接口触发和查看问号气泡状态。T0904 新增技能点分配按钮和 `assign_attribute <npc_id> <strength|intelligence>` 命令，调用 NPCSystem 分配力量 / 智力。T0015 新增“设为入伍”按钮和 `recruit_npc <npc_id>` 命令，调用 NPCSystem 入伍权威接口。T1101 新增“战斗 / 敌人”分组、波次下拉、生成第一波 / 所选波次、敌人快照和清空按钮，并支持 `spawn_wave [wave_number]`、`enemy_wave [wave_number]`、`enemies`、`clear_enemies`；T1102 新增“推进敌人AI”按钮和 `step_enemies [game_seconds]` 命令，调用 CombatSystem 推进目标选择、移动和敌方攻击；T1103 新增“警铃集结”按钮和 `alarm` / `rally` 命令，调用 CombatSystem 触发同 HUD 的集结流程；T1103B/T1103C 新增“行为模式快照”“模拟避战”“推进集结等待”按钮和 `behavior_modes` / `avoid_npc <npc_id>` / `advance_rally_wait [game_seconds]` 命令，其中 `avoid_npc` 适用于非战斗人员并会拒绝已入伍且有主武器 NPC；T1203 新增“触发逃离”按钮和 `escape_npc <npc_id>` 命令，调用 CombatSystem 正式逃离入口；T1104 后，`step_enemies` 同时推进我方基础自动攻击并在敌人快照中暴露最近我方攻击结果；T1104A 后，敌人快照会暴露 TimeSystem 上限状态；T1204A 后，敌人快照的 `active_escapes` / `last_escape_result` 可观察逃离挽留轮次、速度倍率、暂停 / 恢复、留下 / 继续结果、逃离攻击无回复和昏迷暂停 / 复苏继续状态。T0012 后 GM 面板会跟随 GM 按钮位置打开和重定位，并夹在可用屏幕范围内。GMPanel 不写入新的权威结算逻辑，只转发到已有系统。

路径：`res://scripts/camera/CameraRig.gd`
用途：基础俯视摄像机控制脚本，驱动 `Main/CameraRig` 的平移和 `CameraRig/Camera3D` 的本地距离缩放。
依赖：绑定到 `res://scenes/main/Main.tscn` 的 `CameraRig`，读取键盘 WASD、鼠标中键拖拽和滚轮输入。
当前状态：T0105 已创建并绑定；支持 X/Z 边界限制、缩放距离限制，并保持高机位俯视角；T1101 后 Z 轴正向边界扩展到可查看正门外敌人生成区。不实现角色控制或第一人称自由视角。

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
| 建筑定义 | `data/building_defs.json` | 建筑 HP、等级、工作位；训练场教官/受训位、小诊所医生/病床；公告牌不在此表中 |
| 行动定义 | `data/action_defs.json` | 工作、训练、吃饭、睡觉等 |
| 武器定义 | `data/weapon_defs.json` | 剑盾、长杆、弓、弩 |
| 盔甲定义 | `data/armor_defs.json` | 头盔、胸甲、腕甲、腿甲 |
| 坐骑定义 | `data/mount_defs.json` | 坐骑槽 |
| 敌人波次 | `data/enemy_waves.json` | 5 波 Demo |
| Prompt 模板 | `data/prompts/*.txt` | 计划、对话、判定、总结 |

## 数据文件当前已创建

路径：`data/resource_defs.json`
用途：资源配置，记录资源 id、显示名、分类、初始数量、最小值和 HUD 顺序。
依赖：由 `ResourceSystem` 通过 `ConfigLoader.load_data_file("resource_defs.json")` 读取。
当前状态：T0305 已接入运行时资源初始化，包含第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁；T0012 后 HUD 主栏按 `ui_order` 显示非聚合资源，武器、盔甲、马匹整备和工程器械在装备/器械详情中查看。T0901 后，派生资源 `weapons` / `armor` / `horse_readiness` 可由 `EquipmentSystem` 消耗并转换为 NPC 装备槽；`defense_devices` 当前只作为工程器械库存显示，部署留给 T1508。

路径：`data/building_defs.json`
用途：建筑配置，记录建筑 id、等级、HP、标签、工作位、输入输出、修复和升级规则。
依赖：由 `BuildingSystem` 通过 `ConfigLoader.load_data_file("building_defs.json")` 读取，并通过 `scene_nodes` 绑定到低模建筑实体。
当前状态：T0206 后为 15 条建筑/门墙定义，覆盖主厅、宿舍、食堂、仓库、围墙、城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所和工械坊；所有建筑都有 `upgrade` 最小规则，既有关键建筑保留 `repair` 规则，`repair` 可配置每点缺失 HP 耗时和等级耗时系数。2026-05-25 起，不可进入建筑不保留内部工位占位；T0808 起小诊所包含医生工位 `clinic_doctor` 和病床 `patient_bed`，升级当前增加病床；T0903 起训练场包含教官工位 `training_instructor` 和受训位 `training_student`，升级当前增加受训位；公告牌已从建筑定义中移除，作为主厅前视觉占位和广场公告输入/显示接口处理。

路径：`data/action_defs.json`
用途：行动配置，记录行动 id、类型、地点需求、技能、耗时、资源输入输出和状态变化。
依赖：由 `ActionSystem` 读取并作为 NPC 日程与工作白名单。
当前状态：T0305 已由 `ActionSystem` 读取；包含菜园工作、食堂加工餐食、酒窖酿酒、铁匠铺制造、工械坊制造、马厩照料、小诊所医生坐诊/研读医术、小诊所病床治疗、训练场教官、训练场受训者、吃饭、睡觉和协助治疗昏迷者等最小行动定义。2026-05-25 起优先使用 `duration_seconds` 表达持续时间：工作 3600 秒、吃饭 1200 秒、睡觉 23400 秒。T0803 后 `work_garden` 配置 `output_scaling`，基础产出 2 份粮食，并由耕种熟练度、力量和菜园等级提高实际产出。T0804 后 `work_blacksmith` 明确使用打铁与力量，消耗 2 份铁并产出武器/盔甲派生库存。T0805 后 `work_workshop` 明确使用工程与智力，消耗 2 份木材并产出武器/工程器械派生库存。T0806 后 `work_stable` 明确使用养马与力量，消耗 1 份粮食并产出马匹整备派生库存，且通过 `output_scaling` 让养马、力量和马厩等级提高实际产出。T0807 后 `work_tavern` 明确使用酿酒与智力，消耗 1 份粮食并产出酒派生库存，且通过 `output_scaling` 让酿酒、智力和酒窖等级提高实际产出；酒出售换钱留给 T1507。T0808 后 `work_clinic_doctor` 占用诊所医生工位，`receive_clinic_treatment` 占用诊所病床，二者同时满足时推进治疗并消耗第纳尔；医生无病人时缓慢研读医术。T0903 后 `work_training_instructor` 占用训练场教官工位，`receive_weapon_training` 占用训练场受训位，训练项目由 NPC 当前主武器 / 坐骑决定。T1204A 后补充 `escaping_station` 与 `escape_intervention_dialogue` 系统显示行动，用于地点快照和 UI 文案格式化，不作为普通行动下拉的可执行工作。协助治疗是需要目标 NPC 的 `targeted_heal` 行动，普通 `assign_action` 不直接执行，必须走 `debug_assign_heal_assist(healer_npc_id, target_npc_id)`。协助修复和协助升级不在该文件中按建筑写死，而由 `ActionSystem` 作为带建筑参数的运行时行为处理。

路径：`data/weapon_defs.json`
用途：主武器配置，记录武器类型、装备槽、库存来源、射程、伤害、攻击间隔、技能需求和兵种分类辅助字段。
依赖：由 `EquipmentSystem` 读取；后续战斗系统可继续读取其中的数值字段。
当前状态：T0013 后只包含剑盾、长杆武器、弓和弩四类正式主武器。所有主武器当前都消耗 `weapons` 派生库存，不实现耐久或品质。T1104B 起 `attack_interval` 以战斗动作秒解释，CombatSystem 以 `60` 游戏秒 = `1` 战斗动作秒推进冷却。

路径：`data/armor_defs.json`
用途：盔甲配置，记录头盔、胸甲、腕甲、腿甲等装备槽、库存来源、护甲值和重量占位。
依赖：由 `EquipmentSystem` 读取。
当前状态：T0901 已创建；当前包含铁盔、锁子甲、铁护腕和铁护腿，装备时消耗 `armor` 派生库存。

路径：`data/mount_defs.json`
用途：坐骑配置，记录坐骑槽、库存来源、速度加成占位和骑术需求。
依赖：由 `EquipmentSystem` 读取。
当前状态：T0901 已创建；当前包含 `riding_horse` / 整备马匹，装备时消耗 `horse_readiness` 派生库存。日常工作模式不显示骑乘；T1105 后坐骑会参与兵种判定并影响可选战斗策略。

路径：`data/enemy_waves.json`
用途：敌人波次配置，记录波次编号、触发时间、正门外生成点、生成位置、生成散布和敌人组数值。
依赖：由 `CombatSystem` 通过 `ConfigLoader.load_data_file("enemy_waves.json")` 读取。
当前状态：T1101 已配置 5 波 Demo 敌人，后续波次在人数、HP、攻击、防御和兵种组合上逐步增强。敌人组包含 `enemy_type_id`、`name`、`count`、`unit_type`、`weapon_type`、可选 `mount_type`、`hp`、`max_hp`、`attack_power`、`defense`、`move_speed`、`attack_range`、`attack_interval` 和 `target_preference`。T1102 起驱动敌人目标选择、移动和攻击；T1104 起 `defense` 参与敌人受击减伤，`hp` / `max_hp` 会被我方攻击扣除并在清零后移除。T1104B 起第一波劫掠剑盾手为低强度探路敌人，`attack_interval` 使用战斗动作秒。T1104C 起 `target_preference` 不包含 `wall`，敌人默认按城门、仓库、主厅推进。

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
用途：Flask 后端入口，当前提供 `GET /health` 健康检查、`POST /mock/model` Mock Model 调试接口、`POST /npc/dialogue` NPC 对话 Mock 业务接口、`POST /npc/plan_day` 每日计划 Mock 业务接口、`POST /npc/revise_plan` 计划修订 Mock 业务接口、`POST /npc/battle_judgement` 战斗心理判定 Mock 业务接口和 `POST /npc/daily_reflection` 首次睡眠总结 Mock 业务接口。
依赖：`flask`, `python-dotenv`。
当前状态：T0603 后，`/npc/dialogue` 会校验 T0603 版 `NPCDialogueRequest`，调用默认 mock provider 的 `dialogue` 分支，并将输出校验为 `NPCDialogueResponse`；玩家-NPC 对话可返回 `recruitment_result=accept/reject`，NPC-NPC 对话在轮次接近上限时可返回 `should_end_dialogue=true`。T1204A 后，逃离挽留中的玩家消息轮次支持 `dialogue_kind="escape_intervention"` / `interaction_context="escape_intervention"` / `escape_intervention_round`，Mock 可返回 `intent=stay_after_intervention` 或 `leave_after_intervention`；逃离挽留攻击不调用该接口。T1003 后，`/npc/plan_day` 会校验 `DailyPlanRequest`，调用 mock provider 的 `plan_day` 分支，并用 `DailyPlanResponse` 校验 24 阶段输出。T1002 后，`/npc/revise_plan` 会校验 `PlanRevisionRequest`，调用 mock provider 的 `revise_plan` 分支，并用 `PlanRevisionResponse` 校验输出。T1202 后，`/npc/battle_judgement` 会校验 `BattleJudgementRequest`，调用 mock provider 的 `battle_judgement` 分支，并用 `BattleJudgementResponse` 校验输出。T1004 后，`/npc/daily_reflection` 会校验 `DailyReflectionRequest`，调用 mock provider 的 `daily_reflection` 分支，并用 `DailyReflectionResponse` 校验日记、记忆摘要和知识图谱增量。T0602 的 `/mock/model` 仍可按 `call_type` 返回稳定 JSON 并附带伪 token / 用途记录；尚未实现真实 LLM 调用。

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
当前状态：T0602 已实现默认 `mock` provider；`.env` 不存在或未设置 `LLM_PROVIDER` 时默认 mock，支持 `generate(call_type, payload)` 按调用类型返回稳定 JSON，当前覆盖 `dialogue`、`plan_day`、`revise_plan`、`battle_judgement`、`daily_reflection`、`knowledge_graph_update`、`proactive_intention` 和 `player_strategy_classification`，其中 `dialogue_kind="escape_intervention"` 时会按关键词稳定返回留下或继续逃离意向，并记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用和成功/失败状态；非 mock provider 未配置 `LLM_API_KEY` 时返回明确失败，不发起真实 LLM 请求。

路径：`backend/schemas/common.py`
用途：后端 AI 接口共享 Schema，定义游戏时间、请求元信息、事件摘要、短期记忆、NPC 身份/状态/上下文、行动候选和通用错误响应。
依赖：`pydantic`。
当前状态：T0601 已创建；T0703A 新增 `CurrentOrderContext` 并接入共享 `NPCContext`，让所有复用该上下文的 NPC 中心请求携带最新指令。只提供数据模型，不调用 LLM，不改变游戏权威状态。

路径：`backend/schemas/npc_ai.py`
用途：NPC AI 请求/响应 Schema，覆盖玩家-NPC / NPC-NPC / 逃离挽留对话、每日计划、计划异常重评估、战斗判定、首次睡眠总结、知识图谱更新、主动交涉和玩家话术分类。
依赖：`pydantic`，复用 `backend/schemas/common.py`。
当前状态：T0603 后，对话 Schema 已按当前任务重整为显式输入；T0703A 新增对话顶层 `current_order`，并让每日计划、修订、战斗判定、首次睡眠总结等通过共享 `NPCContext.current_order` 复用最新指令。T1202 后，`BattleJudgementRequest` 包含 `combat_context`、`battlefield_context` 和 Godot 提供的 `allowed_decisions`，用于低血量自身心理判定。T1204A 后，`InteractionContext` 包含 `escape_intervention`，逃离挽留中的玩家消息可携带 `dialogue_kind="escape_intervention"` 与 `escape_intervention_round`，`NPCDialogueResponse.intent` 可表达 `stay_after_intervention` / `leave_after_intervention`；逃离挽留攻击不走对话 Schema。响应使用 `replyer_id`、`reply_text`、`response_kind`、`recruitment_result` 和 `should_end_dialogue`；战斗判定响应使用 `BattleJudgementResponse.decision` 表达允许集合内的意向。

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
| Godot MCP 连接与拓扑自检 | `tools/check_godot_mcp.ps1` |
| Godot MCP 多会话 proxy / 单 broker 拓扑验证 | `tools/verify_godot_mcp_topology.mjs` |
| 建筑修复/升级验证 | `tools/verify_building_repair_upgrade.gd` |
| 建筑面板工位显示验证 | `tools/verify_building_panel_workstations.gd` |
| NPC 面板与状态验证 | `tools/verify_npc_panel_state.gd` |
| NPC 移动与地点验证 | `tools/verify_npc_movement_location.gd` |
| NPC 熟练度 schema 验证 | `tools/verify_npc_skill_schema.gd` |
| 简单行动系统验证 | `tools/verify_action_system_basic.gd` |
| 职业工作产出框架验证 | `tools/verify_work_output_framework.gd` |
| 食堂粮食加工餐食验证 | `tools/verify_dining_hall_meals.gd` |
| 菜园粮食产出验证 | `tools/verify_garden_grain_output.gd` |
| 铁匠铺金属装备验证 | `tools/verify_blacksmith_metal_gear.gd` |
| 工械坊弓弩与工程器械验证 | `tools/verify_workshop_ranged_devices.gd` |
| 马厩马匹整备验证 | `tools/verify_stable_horse_care.gd` |
| 酒窖酿酒与出售边界验证 | `tools/verify_tavern_wine_trade.gd` |
| 小诊所治疗验证 | `tools/verify_clinic_treatment.gd` |
| 训练场熟练度验证 | `tools/verify_training_system.gd` |
| 熟练度经验与技能点验证 | `tools/verify_skill_progression.gd` |
| 规则版每日计划验证 | `tools/verify_daily_plan_system.gd` |
| LLM / Mock 每日计划验证 | `tools/verify_daily_plan_llm.gd` |
| 行动异常与计划重评估验证 | `tools/verify_daily_plan_reevaluation.gd` |
| 首次睡眠总结系统验证 | `tools/verify_daily_reflection_system.gd` |
| 对话懒打断、异步取消、对话窗攻击与首次睡眠总结边界验证 | `tools/verify_dialogue_sleep_summary_boundaries.gd` |
| 后端每日计划端点验证 | `tools/verify_plan_day_endpoint.py` |
| 后端计划修订端点验证 | `tools/verify_plan_revision_endpoint.py` |
| 后端首次睡眠总结端点验证 | `tools/verify_daily_reflection_endpoint.py` |
| 装备系统验证 | `tools/verify_equipment_system.gd` |
| 兵种判定验证 | `tools/verify_unit_type_classification.gd` |
| 敌人波次与生成验证 | `tools/verify_enemy_wave_generation.gd` |
| 敌人目标优先级验证 | `tools/verify_enemy_target_priority.gd` |
| 基础攻击与伤害验证 | `tools/verify_combat_damage.gd` |
| 战斗时间上限验证 | `tools/verify_combat_time_cap.gd` |
| 战斗节奏验证 | `tools/verify_combat_pacing.gd` |
| 兵种战斗策略与避战距离验证 | `tools/verify_combat_strategies.gd` |
| 战斗开始 / 结束流程验证 | `tools/verify_combat_flow.gd` |
| 战时公开对话心理结果验证 | `tools/verify_wartime_dialogue.gd` |
| 低血量自身心理判定验证 | `tools/verify_low_hp_battle_judgement.gd` |
| 战场公开信息综合验证 | `tools/verify_battlefield_public_info.gd` |
| 逃离驿站行为验证 | `tools/verify_escape_station_behavior.gd` |
| 逃离挽留入口、暂停与攻击规则验证 | `tools/verify_escape_intervention_dialogue.gd` |
| 警铃与集结验证 | `tools/verify_combat_alarm_rally.gd` |
| NPC 行为模式状态机验证 | `tools/verify_behavior_mode_state_machine.gd` |
| 非战斗人员避战模式验证 | `tools/verify_avoid_combat_mode.gd` |
| HUD 资源库存验证 | `tools/verify_hud_resources.gd` |
| 时间系统验证 | `tools/verify_time_system.gd` |
| 结构化事件底座验证 | `tools/verify_structured_memory_events.gd` |
| 地点信息节点验证 | `tools/verify_location_info_nodes.gd` |
| 广场本地公开广播验证 | `tools/verify_plaza_local_public_broadcast.gd` |
| NPC 短期记忆容器验证 | `tools/verify_npc_short_term_memory_container.gd` |
| 行动事件本地公开广播验证 | `tools/verify_action_local_public_broadcast.gd` |
| NPC 扣血与昏迷验证 | `tools/verify_npc_damage_unconscious.gd` |
| NPC 昏迷自然恢复验证 | `tools/verify_npc_unconscious_natural_recovery.gd` |
| NPC 昏迷协助治疗验证 | `tools/verify_npc_unconscious_healing.gd` |
| NPC 面板非对话交互验证 | `tools/verify_npc_panel_interactions.gd`，T1006 起确认攻击入口已移出 NPC 面板 |
| NPC 主动交涉验证 | `tools/verify_npc_proactive_talk.gd` |
| GM 调试面板验证 | `tools/verify_gm_panel.gd` |
| 后端 Schema 验证 | `tools/verify_backend_schemas.py` |
| Mock Model Adapter 验证 | `tools/verify_mock_model_adapter.py` |
| `/npc/dialogue` Mock 接口验证 | `tools/verify_dialogue_mock_endpoint.py` |
| Godot LLMBridge 验证 | `tools/verify_llm_bridge.gd`，T0604A 起包含不依赖 `curl.exe` / `OS.execute` 的静态检查 |
| 对话 UI、轮次与对话事件验证 | `tools/verify_dialogue_ui.gd` |
| 入伍 NPC 自然语言指令验证 | `tools/verify_npc_order.gd` |
