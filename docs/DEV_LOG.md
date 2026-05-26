# DEV_LOG.md

> 按日期记录开发过程。  
> 每次完成任务后追加，不要覆盖历史。

## 2026-05-26

### T0407 精简地点事件与建筑状态见闻
完成：
- `location_entered` / `location_exited` 现在只记录进入/离开的行动事实，不再在事件 payload 或 summary 中携带完整地点状态。
- NPC 进入新信息地点时，进入者会在见闻库获得一次 `location_entry_snapshot` 当前状态快照；已经在该地点的 NPC 只收到本地公开的进入/离开事件。
- NPC 离开地点时生成 `location_exited`，事件 `location_id` 使用被离开的地点，并广播给仍在该地点的 NPC。
- 建筑状态变化见闻改为字段级差量：外部状态使用 `changed_fields`，工位占用变化使用 `changed_workstations`，不再复制完整广场或建筑快照。
- 更新 `tools/verify_location_info_nodes.gd` 与 `tools/verify_plaza_public_broadcast.gd` 覆盖 T0407 规则。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

## 2026-05-25

### 建筑修复覆盖、进入快照与协助事件位置修正
完成：
- `data/building_defs.json` 为城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所和工械坊补齐 `repair` 配置，验证所有建筑都可修复。
- NPC 进入可进入建筑时，`location_entered` 摘要和进入者收到的当前状态见闻会立即包含建筑外部状态、建筑内 NPC 和工位占用状态。
- 协助修复/协助升级改为广场行为：NPC 在室内时先移动到广场；协助开始事件写入 `plaza_public`，`location_id == "plaza"`，目标建筑保留在 `payload.building_id`。
- `BuildingSystem` 的协助者有效性改为要求 NPC 仍在广场且当前行动仍是协助对应建筑。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。

### T0205/T0305/T0403/T0404/T0405 建筑升级倒计时与见闻降噪
完成：
- `BuildingSystem.upgrade_building(...)` 改为点击时一次性扣除资源并创建升级作业，随 `logical_time_tick` 推进；倒计时完成后才提升等级、Max HP 和可配置工作位奖励。
- 建筑受损、正在修复或正在升级时不可开始升级；升级期间不可开始修复。所有建筑定义都补齐了 `upgrade` 最小配置。
- `ActionSystem` 新增 `debug_assign_upgrade_assist(npc_id, building_id)`；NPC 可协助正在升级的建筑并按工程熟练度提供加速，升级完成后自动回到 idle。
- `MemorySystem` 的建筑可传播外部状态收窄为等级和完好/受损/正在修复/正在升级；HP、Max HP、剩余修复/升级时长不再触发见闻传播。可传播内部状态收窄为在场 NPC 和每个工位的占用/空闲状态，工位数量不再触发传播。
- 建筑状态见闻 summary 改为直接表达实际信息，不再使用“建筑状态更新”这类空泛前缀。
- `BuildingPanel` 显示升级倒计时进度、剩余时间、速度倍率和协助人数；`GMPanel` 新增协助升级按钮与 `assist_upgrade <npc_id> <building_id>` 命令。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。

### T0403/T0404/T0405 建筑状态与见闻广播修正
完成：
- `MemorySystem` 监听 `building_state_changed`，任一建筑外部状态变化都会同步到广场 `building_external_states` / `key_entities`，并生成带具体建筑名的 `plaza_status_changed` 见闻。
- 可进入建筑状态变化会生成 `location_status_changed` 本地见闻；NPC 进入广场获得所有建筑外部状态，进入可进入建筑获得该建筑外部 + 内部状态。
- 建筑状态快照拆分外部状态（HP、等级、完好/受损/正在修复、剩余修复时长）和内部状态（在场 NPC、工位数量、占用/空闲状态）；不可进入建筑不暴露内部 NPC 或工位。
- `data/building_defs.json` 移除主厅、仓库、围墙、城门的旧内部工位占位；围墙升级不再增加内部工位。
- 更新 `tools/verify_location_info_nodes.gd`、`tools/verify_plaza_public_broadcast.gd`、`tools/verify_building_repair_upgrade.gd` 覆盖全建筑外部状态、内部字段隔离、状态见闻命名和不可进入建筑无工位规则。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0006 修复建筑修复进度抢占右上角面板
完成：
- `EventBus` 新增 `building_state_changed(building_id)`，区分建筑状态刷新与玩家/调试选择建筑。
- `BuildingSystem` 在建筑受损、开始修复、修复进度推进、协助者变化、修复完成和升级时发出 `building_state_changed`，不再复用 `building_clicked`。
- `BuildingPanel` 仍通过 `building_clicked` 打开建筑，但只在自身可见且当前显示同一建筑时响应 `building_state_changed` 刷新。
- `tools/verify_npc_panel_state.gd` 增加回归用例：开始修复受损建筑后点击 NPC，再推进修复时间，确认右上角保持 NPC 面板。

验证：
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0305 行动系统持续时间修订
完成：
- `ActionSystem` 的工作、吃饭、睡觉改为到达地点后进入 active 行动，随 `TimeSystem.logical_time_tick` 推进，不再瞬时完成。
- `data/action_defs.json` 改用 `duration_seconds`：工作 3600 秒、吃饭 1200 秒、睡觉 23400 秒。
- 吃饭按 20 分钟恢复约 50 点饱食度结算；睡觉按 6.5 小时降低 100 点疲劳结算；工作保留 1 小时最小批次，完成后结算当前占位投入/产出。
- 更新行动验证脚本，使测试显式推进逻辑时间后再检查完成事件和数值变化。

验证：
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。

### T0005 加固 Godot MCP proxy 自恢复
完成：
- 排查到这次 MCP “又连不上”的直接原因不是 Godot 插件掉了，而是同一个 `codex` 父进程下残留了两个 `godot-mcp-proxy.mjs`；其中旧的那个没有 broker 子进程，属于孤立 proxy。
- 更新 `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`，加入 `%USERPROFILE%\.codex\godot-mcp-proxy.lock`。新 proxy 启动时会检查同父进程的旧 proxy，命中后先清理再接管，退出时再移除自己的 lock。
- 更新 `tools/check_godot_mcp.ps1`，除了原来的连接判断外，额外提示“多 proxy”与“proxy 在但 broker 不在”两类故障。
- 将这次经验精简回写到 `CURRENT_STATE.md` 和 `TASKS.md` 的 Godot MCP 相关位置，后续排查优先先看自检脚本和 proxy/broker 进程关系。
- 追加修正：再次复发时确认旧逻辑只会清理 lock 指向的单个 proxy，连续多次拉起后更早的残留 proxy 仍会留下。已改为按同一个 `codex` 父进程枚举所有 `godot-mcp-proxy.mjs`，在启动时一次性清理其余旧实例。

验证：
- `powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1` 返回 `Godot MCP connected`。
- Godot MCP `project.addon_status` 返回 `connected: true`、`versions_match: true`。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。
- 清理孤立 proxy 后，只剩 1 条有效的 `proxy -> broker` 链路。

## 2026-05-24

### T0205/T0305 建筑修复 UI 与协助行为清理
完成：
- `BuildingPanel` 不再把修复/升级消耗常驻显示在面板正文；悬停修复/升级按钮时，在按钮旁显示资源消耗和条件提示框。
- `BuildingSystem` 会在 NPC 状态变化和修复推进前清理无效协助者；NPC 离开对应建筑或被改派后，协助人数和速度加成立即移除。
- `ActionSystem` 的协助修复保留为 `debug_assign_repair_assist(npc_id, building_id)` 这一套带建筑参数的统一行为；移除 `data/action_defs.json` 中固定“修补围墙”行动，避免 GM 行动下拉与协助修复按钮表达重复。
- `GMPanel` 行动分组新增“修复目标”建筑下拉，让“协助修复”按钮可直接选择目标建筑。
- 建筑操作提示框增加屏幕边界夹取；靠近右侧等边缘时会翻到按钮内侧或保持在可视区域内。
- `tools/verify_action_system_basic.gd` 增加“协助者离开后移除加成”的回归检查。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现真实每日计划自动挑选修复目标；仍保留在 T1001 TODO。

### T0205/T0305 建筑修复倒计时与 NPC 协助修复
完成：
- `BuildingSystem.repair_building(...)` 改为点击时一次性扣除资源并创建修复作业；HP 随 `logical_time_tick` 按进度逐步恢复，不再瞬间修复。
- 修复时长由缺失 HP、建筑等级和 `data/building_defs.json` 中的 `repair.seconds_per_missing_hp` / `repair.level_time_factor` 计算。
- 新增修复状态查询与 NPC 协助接口：`get_repair_status(...)`、`is_repair_in_progress(...)`、`add_repair_helper(...)`、`remove_repair_helper(...)`。
- `ActionSystem` 新增 `debug_assign_repair_assist(npc_id, building_id)`；NPC 到达正在修复的建筑后按工程熟练度加速倒计时，多个 NPC 可叠加，修复完成后回到 idle。
- `GMPanel` 新增 `assist_repair <npc_id> <building_id>` 命令，并在建筑快照中可观察修复状态。
- `MemorySystem` 预留并格式化 `repair_assist_started` 事件。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现真实每日计划自动选择协助修复；已把“规则计划可把协助修复作为候选行为并选择目标”加入 T1001 TODO。

### T0403 修复行动事件 local_public 广播
完成：
- 修复 `ActionSystem` 行动事件可见性：工作、吃饭、睡觉开始/完成/失败事件不再以 `private` 写入，而是以 `local_public` 写入 `MemorySystem`。
- 同地点当前在场 NPC 会收到这些活动/工作事件并写入见闻库；行动者本人仍只保留亲历事件，不重复写入自己的见闻库。
- 新增 `tools/verify_action_local_public_broadcast.gd`，覆盖工作、吃饭、睡觉三类行动事件的本地公开广播。

验证：
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未新增 GM 面板入口；现有行动指派和记忆查询入口已经可以手动验证该修复。

### T0406 统一玩家交互事件世界内称呼
完成：
- `MemorySystem.record_player_interaction(...)` 将玩家相关 actor id 写为 `guard_officer`，并在 payload 中补充 `actor_display_name = "守备官"`。
- 玩家非对话交互 summary 模板改为“守备官给了/守备官攻击了/守备官指派了”等世界内称呼，不再把“玩家”写入 NPC 记忆文本。
- `tools/verify_npc_short_term_memory_container.gd` 增加给钱与攻击事件 summary 检查，确保包含“守备官”、不包含“玩家”，且 actor id 为 `guard_officer`。
- 更新设计源、NPC、记忆、Prompt、数据结构、GM、模块索引、当前状态和任务文档中的称呼规则。

验证：
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

未做：
- 未重命名现有 `record_player_interaction(...)` / `npc_attacked_by_player` 等开发接口和事件类型，避免破坏当前任务、验证脚本和后续模块引用；世界内文本已统一为“守备官”。

### T0206 将公告牌移出建筑数据结构
完成：
- 从 `data/building_defs.json` 删除 `notice_board` 建筑定义，建筑定义数量由 16 调整为 15。
- 保留 `Main.tscn` 中主厅前 `NoticeBoard` 视觉占位；它不再绑定 `BuildingSystem`，不拥有 HP、等级、工作位、修复或升级。
- 明确公告文本的权威状态仍由广场信息节点保存，公告变更继续生成 `plaza_notice_changed` 并广播给当前在广场的 NPC。
- 更新建筑、数据结构、记忆信息、Godot 架构、模块索引、当前状态、任务列表和设计源中的相关说明。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/building_defs.json` 合法，且不包含 `notice_board`。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_public_broadcast.gd` 通过。

未做：
- 未新增公告编辑 UI；现有 GM 广场公告入口继续作为验证入口。

### T0004 建立 GM 调试面板与验证工作流
完成：
- 新增 `scripts/ui/GMPanel.gd`，在 `Main/UI/GMPanel` 下提供可拖动半透明 `GM` 按钮、GM 面板窗口、命令输入框、执行结果区和分组调试按钮。
- GM 面板顶部 `GM_ENABLED` 常量可用 `true` / `false` 切换开发/上线显示。
- GM 面板当前覆盖资源、时间、建筑、NPC、行动、记忆/见闻/广场公告等 M1-M4 已完成但前端不易直接验证的关键能力。
- 新增 `docs/GM_PANEL.md`，记录开关、分组、命令、维护规则和验证方式。
- 更新 `AGENTS.md`：每次任务完成时若新增功能无法直接在前端验证，必须给 GM 面板新增或替换调试入口，并同步更新 GM 文档。
- 新增 `tools/verify_gm_panel.gd`，覆盖 GM 面板加载、打开、资源命令、建筑受损、时间设置、NPC 地点进入、给钱事件、广场公告和结果输出。

验证：
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，清空旧日志后游戏日志无报错，截图可见 GM 按钮与面板。

未做：
- 未新增新的权威结算系统；GM 面板只调用已有系统接口或 `debug_*` 接口。
- 未实现真实对话、征召、战斗、昏迷/治疗/复苏或后端 LLM 调用。

### T0405 实现 NPC 短期记忆容器
完成：
- `MemorySystem` 新增 `get_npc_short_term_memory(...)` / `get_npc_short_term_memory_ids(...)`，将当天 `event_log` 与 `witness_log` 作为独立容器暴露给后续 LLM 输入。
- 新增 `record_player_interaction(...)`，玩家非对话交互会先进入目标 NPC 事件库，再按 `private` / `local_public` / `plaza_public` 可见性广播给地点或广场当时在场 NPC。
- 新增 `debug_record_player_money_given(...)` 和 `debug_record_player_attack_npc(...)`，用于验证给钱和攻击事件写入；本次不实现真实按钮、HP 扣除或昏迷。
- `NPCPanel` 新增事件库和见闻库最近摘要，监听 `npc_memory_changed` 自动刷新。
- 新增 `tools/verify_npc_short_term_memory_container.gd`，覆盖短期记忆容器、给钱/攻击交互、见闻广播和面板区分显示。

验证：
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。

未做：
- 未做睡前总结、知识图谱更新、LLM 接入、真实交互 UI、真实攻击扣血或昏迷。

### T0404 实现广场公开信息即时广播
完成：
- `MemorySystem` 将 `plaza_public` 事件统一广播到广场信息节点，当前在广场的 NPC 会把事件写入见闻库；事件若原本发生在其他可进入地点，也会同步广播给该地点在场 NPC。
- 室外或不可进入实体来源的公开事件会规范化为 `location_id == "plaza"`，并在 payload 中保留 `source_location_id`。
- 广场快照明确没有自身建筑 HP，并提供主厅、围墙、城门、仓库 `key_entities`、当前在场 NPC 数和敌人数。
- 广场公告文本变更会生成 `plaza_notice_changed` 广场公开事件；关键目标受损、修复或升级会生成 `plaza_status_changed` 广场公开状态事件。
- `BuildingSystem` 在关键目标受损、修复或升级时通知 `MemorySystem` 进行广场状态广播。
- 新增 `tools/verify_plaza_public_broadcast.gd`，覆盖广场公开事件、公告、关键实体状态、广场快照字段和见闻库写入。
验证：
- `godot --headless --path . --script res://tools/verify_plaza_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
未做：
- 未实现战斗本体、昏迷/复苏系统、逃离行为、公告输入 UI 或 LLM 解读。

### T0403 实现地点信息节点与进入快照

完成：
- 在 `scripts/systems/MemorySystem.gd` 中建立可进入地点信息节点，覆盖广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊。
- 地点节点维护 `people_present`、当前公告/命令和进入快照；主厅、围墙、城门、仓库状态归入广场 `key_entities`。
- `NPCSystem` 到达地点时会更新旧地点/新地点在场人员，并把 `location_entered.payload.location_snapshot` 写入事件库。
- `local_public` 事件会即时广播给事件地点当前在场 NPC，并写入接收者见闻库；地点节点不保存事件历史。
- `BuildingSystem.get_building_location_context(...)` 优先读取 `MemorySystem.get_location_snapshot(...)`，让 UI / NPC 状态使用同一套当前状态快照。
- 新增 `tools/verify_location_info_nodes.gd`，覆盖地点人数进出、进入快照、广场关键实体状态和本地公开事件见闻转发。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现完整广场公开信息规则、战斗公开事件、公告输入 UI、睡前总结或 LLM 记忆摘要。

## 2026-05-23

### T0402 架构适配检查

完成：
- 检查 T0403 前已完成代码是否仍隐含旧的“地点/建筑保存事件历史并供后来 NPC 继承”模型。
- `BuildingSystem.get_building_location_context(...)` 删除 `recent_events` 占位，改为 `current_public_note_ids` / `public_notes` 当前状态占位。
- 删除 `MemorySystem` 的按地点查询事件 API 与内部索引，避免继续暗示地点/建筑保存事件历史。
- `BuildingPanel` 和验证脚本中的旧措辞同步为“地点状态 / 结构化事件日志”。

验证：
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0402 实现结构化事件底座

完成：
- `MemorySystem` 从最小 EventLog 占位升级为结构化事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场公开事件查询；地点/广场节点不作为事件历史存储。
- 结构化事件统一包含 `event_id`、`day`、`time`、`type`、`subject_npc_id`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary`、`payload`。
- 已预留 T0402 要求的事件类型，并为 `location_entered`、`work_started`、`work_completed`、`work_failed`、`eat_completed` 等实现确定性 summary 模板和必需 payload 字段声明。
- `ActionSystem` 工作/吃饭/睡觉/失败路径已迁移到结构化事件；`NPCSystem` 到达地点时写入 `location_entered`。
- `EventBus` 增加 `event_recorded`、`npc_memory_changed`、`location_info_changed` 信号。
- 新增 `tools/verify_structured_memory_events.gd`，覆盖结构化字段、NPC 事件库、全局索引、广场公开查询和 payload schema。

验证：
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现地点/广场即时广播、知识图谱、日记、LLM 记忆摘要、对话或战斗。

## 2026-05-22

### T0401 暂停输入与暂停结算语义修正

完成：
- 确认 `SpeedButton` 只调用 `TimeSystem.cycle_speed()`，空格和 `PauseButton` 只调用 `TimeSystem.toggle_paused()`，空格不会改变 `x1` / `x2` / `x4` 速度倍率。
- `ActionSystem` 监听 `gameplay_pause_changed`；暂停期间已到位行动只保留 pending，不执行资源消耗/产出、饱食/疲劳变化或 EventLog 结算，恢复后再结算。
- `game_design.md` 补充暂停设计：暂停停止逻辑时间、NPC 移动、战斗和资源/状态结算，但不冻结 UI、后端请求或 LLM 对话/判定等待。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过，覆盖空格不改速度、NPC 暂停移动、暂停期间行动不结算且恢复后结算。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志无报错。

未做：
- 当前仍未实现真实 LLM 对话、NPC-NPC 对话、战斗系统或真实时间驱动生产；本次只补齐暂停底层语义和已接入行动结算的暂停保护。

## 2026-05-21

### T0401 逻辑时间倍率与 LLM 等待减速架构

完成：
- `TimeSystem` 增加 LLM 等待减速请求接口：`request_time_slowdown(...)`、`release_time_slowdown(...)`、`clear_time_slowdowns()`。
- 新增有效逻辑倍率读取接口：`get_effective_time_scale()`、`get_numeric_delta_multiplier()`、`get_game_delta_seconds(...)`。
- `EventBus` 新增 `time_scale_changed(...)` 与 `logical_time_tick(...)`，用于后续资源、计划、战斗数值按逻辑时间倍率结算。
- 默认 LLM 等待倍率为 `1/60`，即默认速度下现实 1 秒 = 游戏 1 秒；该机制不修改 `Engine.time_scale`，不改变 NPC 移动或动画速度。
- 更新 `game_design.md`、架构、AI、经济、战斗、Prompt、API 预算和任务路线图中的相关说明。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过，覆盖 LLM 等待减速、释放后恢复玩家倍率和数值倍率接口。
- `godot --headless --path . --quit-after 1` 通过。
- `verify_action_system_basic.gd`、`verify_npc_panel_state.gd` 回归通过。

未做：
- 未将真实 LLMBridge、资源产出、计划调度或战斗数值实际接入逻辑倍率；已在后续任务中补充要求。

### T0401 秒级时间显示与控制修正

完成：
- `GameState` 增加 `current_minute` / `current_second`，`TimeSystem` 改为按游戏秒推进并写回 `HH:MM:SS`。
- `EventBus` 增加 `time_changed(day, hour, minute, second)`，HUD 使用该信号连续刷新时间显示。
- `HUD` 的 `SpeedButton` 改为只循环 `x1` / `x2` / `x4` 流速。
- `Main/UI/HUD` 新增 `PauseButton`，用于暂停/继续；空格键绑定到同一暂停/继续逻辑。
- `tools/verify_time_system.gd` 补充秒级流逝、速度按钮、暂停按钮和空格暂停验证。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现每日计划、战斗倒计时或 LLM 时间减速。

### T0401 实现 TimeSystem

完成：
- 在 `scripts/systems/TimeSystem.gd` 中实现基础时间推进：一天 24 小时，默认现实 1 秒 = 游戏内 1 分钟，每 60 游戏分钟推进 1 小时。
- 增加暂停与 `x1` / `x2` / `x4` 加速切换接口，并将 `HUD` 的时间按钮接到 `TimeSystem.cycle_speed()`。
- 在 `EventBus.gd` 中补充 `day_started(day)`；`GameState.set_time(...)` 会在跨天时发出 `day_started`，并继续发出 `hour_started(day, hour)`。
- `HUD.gd` 监听 `hour_started` / `day_started` 刷新天数、小时和阶段文本。
- 新增 `tools/verify_time_system.gd`，覆盖时间推进、暂停、加速、跨天信号和 HUD 刷新。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd`、`verify_npc_panel_state.gd`、`verify_action_system_basic.gd` 回归通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 LLM 时间减速、每日计划或战斗倒计时。

### NPC 面板属性显示修正

完成：
- `NPCPanel` 新增属性行，显示 `stats.strength` / 力量和 `stats.intelligence` / 智力。
- 面板显示顺序调整为：姓名、HP、属性、专长、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、职业熟练度、武器熟练度。
- `tools/verify_npc_panel_state.gd` 增加属性文本与 HP/属性/专长顺序验证。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- Godot MCP 本次连接失败：`ECONNREFUSED 127.0.0.1:8765`，未作为本次验证项。

### T0305 资源消耗与生产对齐修正

完成：
- 修正 `ActionSystem._execute_work(...)`：无 `output_resources` 的工作现在也会正确结算饱食/疲劳、写入 EventLog 并返回成功。
- `BuildingSystem` 新增 `restore_building_hp(...)`，支持工作行动恢复建筑 HP。
- `data/action_defs.json` 按 `game_design.md` 补齐酒窖酿酒、铁匠铺制造武器/盔甲、工械坊制造工程器械、马厩产出马匹整备占位，以及围墙修补恢复 HP。
- `data/resource_defs.json` 新增酒、武器、盔甲、工程器械、马匹整备派生资源。
- 扩展 `tools/verify_action_system_basic.gd`，覆盖派生资源生产、无普通产出工作和围墙修补 HP 变化。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/resource_defs.json` 和 `data/action_defs.json` 合法。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 派生资源仍是库存占位，不实现装备分配、器械部署、马匹实体、出售酒或复杂熟练度效率。

### T0305 实现简单行动系统

完成：
- `ActionSystem` 接入 `data/action_defs.json`，提供调试指派工作、吃饭、睡觉和指定行动的接口。
- 行动指派会先复用 `NPCSystem.move_npc_to_building(...)` 前往目标建筑；2026-05-25 起，到达后进入持续行动并随逻辑时间结算。
- 菜园工作产出粮食，食堂工作消耗粮食产出餐食；吃饭优先消耗餐食并恢复更多饱食度，没有餐食时消耗粮食；睡觉降低疲劳。2026-05-25 起，吃饭和睡觉恢复/消耗按持续时间逐步发生。
- `MemorySystem` 新增最小 EventLog 占位，行动成功或失败会记录事件。
- `data/resource_defs.json` 新增餐食资源，`data/action_defs.json` 扩展工作 / 吃饭 / 睡觉行动配置。
- 新增 `tools/verify_action_system_basic.gd` 验证最小行动闭环。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 LLM 日程、训练、战斗、工作位占用或复杂职业产出。

### 熟练度架构修正

完成：
- 按 `game_design.md` 8.4 固定 NPC 熟练度全集：职业熟练度 `养马`、`厨艺`、`耕种`、`打铁`、`教练`、`酿酒`、`医术`、`工程`；武器熟练度 `剑盾`、`长杆`、`弓`、`弩`、`骑术`。
- `data/npc_profiles.json` 中每名 NPC 均补齐 13 个熟练度维度，并移除 `搬运`、`草药`、`护甲制作`、`指挥`、`祈祷`、`劝解`、`木工` 等非设计源技能。
- `NPCSystem` 新增固定熟练度枚举、`normalize_skills(...)` 和 `get_npc_specialties(...)`，职业倾向由高熟练度推导，不再依赖硬职业字段。
- `NPCPanel` 改为显示“专长”，并分组显示职业熟练度与武器熟练度。
- 新增 `tools/verify_npc_skill_schema.gd` 验证每名 NPC 的技能全集。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/npc_profiles.json` 合法，且每名 NPC 刚好 13 个固定熟练度。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_skill_schema.gd` 通过。

### NPC 主界面标签与短名修正

完成：
- 将 `data/npc_profiles.json` 中 8 名 NPC 的显示名改为短名：托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文。
- 简化 `NPC.gd` 头顶标签，主场景只显示姓名、HP 和当前行动。
- 职业、是否入伍等详细信息仍保留在 `NPCPanel` 中显示。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- `verify_npc_generation_click.gd`、`verify_npc_panel_state.gd`、`verify_npc_movement_location.gd` 均通过。

### T0304 实现基础移动与地点进入

完成：
- `BuildingSystem` 新增 `get_building_entry_position(...)`，为 NPC 移动提供建筑入口目标点。
- `BuildingSystem` 新增 `get_building_location_context(...)`，返回地点信息读取占位。
- `NPC.gd` 新增 `move_to_location(...)` 和 `movement_arrived`，支持简单直线移动。
- `NPCSystem` 新增 `move_npc_to_building(...)`、`debug_move_npc_to_building(...)` 和 `debug_move_selected_npc_to_building(...)`。
- NPC 到达建筑后写回 `current_location`、`current_location_name`、`location_context`，并发出 `npc_state_changed`。
- 新增 `tools/verify_npc_movement_location.gd`，覆盖调试移动到食堂、宿舍、仓库和地点状态更新。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- 通过 Godot MCP 打开并运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现复杂避障、真实日程计划、工作/吃饭/睡觉行动结算、对话、征召、战斗或 LLM。

## 2026-05-20

### T0303 实现 NPC 基础状态与 NPC 面板

完成：
- 新增 `scripts/ui/NPCPanel.gd` 并接入 `Main/UI/NPCPanel`。
- NPC 面板当时显示姓名、职业、HP、饱食度、疲劳度、金钱、昏迷、入伍、当前行动和技能熟练度；2026-05-21 已改为显示由固定熟练度推导的专长。
- `EventBus` 新增 `npc_state_changed(npc_id)`。
- `NPCSystem` 新增 `get_npc_state(...)`、`update_npc_state(...)`、`set_npc_state_value(...)`，状态变化后会刷新 NPC 标签并通知 UI。
- `NPC.gd` 头顶调试标签在当时补充了入伍状态、昏迷和 HP 摘要；2026-05-21 已按主界面降噪要求改为短姓名、HP 和当前行动。
- `BuildingPanel` 与 `NPCPanel` 支持点击对象互斥切换。
- 新增 `tools/verify_npc_panel_state.gd` 覆盖面板打开、状态刷新、面板切换和关闭。

验证：
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，并确认 `Main/UI` 下存在 `NPCPanel`、`BuildingPanel`、`DialogPanel`。

未做：
- 未实现 NPC 状态自然变化、治疗、对话、移动、征召或战斗。

## 2026-05-18

### 初始化文档结构

完成：

- 创建项目管理文档种子。
- 创建 `AGENTS.md` 协作规则。
- 创建核心模块文档。
- 明确文档回写流程。

影响文件：

- `AGENTS.md`
- `docs/PROJECT_BRIEF.md`
- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- 其他模块文档

待办：

- 初始化 Godot 项目。
- 初始化后端目录。
- 将现有完整策划案放入 `game_design.md`。

## 2026-05-19

### T0002 初始化后端目录

完成：
- 创建 Flask 后端入口 `backend/app.py`。
- 实现 `GET /health`，返回 `{"ok": true, "service": "war-not-mine-backend"}`。
- 确认 `backend/requirements.txt` 包含 `flask`、`python-dotenv`、`pydantic`、`requests`。
- 新增 `backend/.env.example` 作为本地配置模板；真实 API Key 不写入仓库。
- 创建 `backend/schemas/`、`backend/services/`、`backend/data/`，并使用 `.gitkeep` 保留空目录。
- 新增最小 `backend/services/model_adapter.py`，作为后续 LLM 供应商隔离边界。
- 更新 `.gitignore`，忽略 `backend/.env`。

验证：
- `python -m compileall backend` 通过。
- 安装 `backend/requirements.txt` 后，通过 Flask test client 验证 `GET /health` 返回 HTTP 200 和 `{"ok": true, "service": "war-not-mine-backend"}`。
- 启动 `python backend/app.py` 后，通过 `http://127.0.0.1:5000/health` 验证返回 `{"ok":true,"service":"war-not-mine-backend"}`。

未做：
- 未修改 Godot 场景。
- 未实现 NPC、战斗、资源或 AI 对话。

### T0001 初始化 Godot 项目结构

完成：
- 创建 `res://scenes/main/Main.tscn` 作为最小可运行主场景。
- 主场景包含 `WorldRoot/Station/Ground`、`Systems`、`UI/HUD`、`CameraRig/Camera3D` 和 `SunLight`。
- 补齐 Godot 目录骨架：`scenes/main/`, `scenes/world/`, `scenes/npc/`, `scenes/enemy/`, `scenes/buildings/`, `scenes/ui/`, `scripts/core/`, `scripts/systems/`，并用 `.gitkeep` 保留空目录。
- 设置 `project.godot` 的 `run/main_scene` 为 `res://scenes/main/Main.tscn`。
- 通过 Godot MCP 运行主场景，游戏日志无报错，截图可见标题与基础地面。

影响文件：
- `project.godot`
- `scenes/main/Main.tscn`
- `scenes/**/.gitkeep`
- `scripts/**/.gitkeep`
- `ui/.gitkeep`
- `assets/.gitkeep`
- `data/.gitkeep`
- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- `docs/DEV_LOG.md`
- `docs/CHANGELOG.md`

未做：
- 未实现 NPC、战斗、建筑交互、资源系统、时间系统或后端。

### 稳定 Godot MCP 启动与自检
完成：
- 定位 Godot MCP 频繁断开的根因：同一个 `codex.exe` 下重复拉起 `godot-mcp` 实例，Godot 插件会用 “Replaced by new client” 替换旧连接。
- 修复 `tools/check_godot_mcp.ps1` 解析错误和乱码提示，改为可用的连接自检脚本。
- 将 Codex 全局 `godot-mcp` 启动命令改为 `node C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`。
- 新增 `godot-mcp-broker.mjs`，由单例 broker 负责唯一的 Godot WebSocket 连接；多个 Codex 会话只连接本机 proxy。
- 本机验证 broker 可正常健康检查，并能成功调用 `editor.get_state` 读取 Godot 编辑器状态。

换机补充：
- 新环境若仍配置为 `npx.cmd -y @satelliteoflove/godot-mcp`，切换 Codex 会话仍会重复直连 Godot `6550`，需要改为 `node %USERPROFILE%\.codex\scripts\godot-mcp-proxy.mjs`。
- Windows 下 broker 直接 `spawn("npx.cmd")` 可能报 `spawn EINVAL`；更稳妥的方式是直接启动 npm cache 中的 `@satelliteoflove/godot-mcp/dist/cli.js`。
- `tools/check_godot_mcp.ps1` 自检不要用 TCP 主动探测 Godot `6550`，裸 TCP 连接会被 Godot MCP 插件当作新客户端并顶掉 broker；只检查监听状态，真实验证走 proxy 调用 `editor.get_state`。
- 修复后应只看到 broker 与其唯一 `godot-mcp` 子进程，Godot `6550` 只有 1 条有效客户端连接；本机 broker 默认监听 `127.0.0.1:6551`。

影响文件：
- `tools/check_godot_mcp.ps1`
- `C:\Users\JT\.codex\config.toml`
- `C:\Users\JT\.codex\scripts\godot-mcp-broker.mjs`
- `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`

### T0101 建立核心 Autoload 与系统骨架

完成：
- 新增 `scripts/core/EventBus.gd`，声明资源、时间、建筑点击、NPC 点击和公开事件基础信号。
- 新增 `scripts/core/GameState.gd`，保存当前天数、小时和战斗状态。
- 新增 `scripts/core/ConfigLoader.gd`，提供 JSON 配置读取入口，并在文件缺失或解析失败时给出明确错误。
- 在 `project.godot` 中注册 `EventBus`、`GameState`、`ConfigLoader` Autoload，保留既有 `MCPGameBridge`。
- 新增 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`MemorySystem.gd` 空系统脚本占位。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 清空旧日志后再次运行，游戏日志无报错。

未做：
- 未实现 NPC、建筑点击、资源变化、时间推进、后端连接或战斗逻辑。

### T0102 扩展 Main 场景节点结构

完成：
- 将 `res://scenes/main/Main.tscn` 整理为 `WorldRoot/Station`、`Systems`、`UI`、`CameraRig` 的标准结构。
- 在 `WorldRoot/Station` 下保留 `Ground`，并补齐 `Buildings`、`NPCs`、`Enemies`、`Props` 容器。
- 在 `Systems` 下补齐 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem`、`MemorySystem`、`CombatSystem`、`DialogSystem`。
- 新增 `ActionSystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 空系统脚本占位，并绑定到 Main 场景。
- 在 `UI` 下保留 `HUD/TitleLabel`，并新增隐藏占位 `NPCPanel`、`BuildingPanel`、`DialogPanel`。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认当前 HUD 标题与基础地面仍可见。

未做：
- 未实现点击逻辑、NPC、资源数值、战斗或对话 UI。

### T0103 创建低模驿站 Blockout

完成：
- 在 `res://scenes/main/Main.tscn` 中扩展低模驿站空间占位。
- 在 `WorldRoot/Station/Buildings` 下新增主厅、宿舍、食堂、仓库、围墙、城门、后门等几何体占位。
- 在 `WorldRoot/Station/Props` 下新增广场、正门道路、后门道路和商人入口占位。
- 补齐酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、主厅前公告牌视觉占位等 T0103 要求的剩余占位区域。
- 为 P0 占位区域添加 `Label3D` 调试标签，便于后续建筑系统和导航接入。
- 扩大地面尺寸并调整俯视相机，让启动后可看到完整驿站布局。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认 HUD 标题、完整低模驿站和调试标签可见。

追加调整：
- 根据反馈扩大地面和围墙范围，并重新拉开建筑间距。
- 将建筑更明显地分散到中央广场、生活区、生产区、防务区和后门入口周边。
- 再次通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认拥挤感降低。

反馈修正：
- 补齐围墙四角闭合，让驿站院墙更像完整防御边界。
- 将公告牌缩小并移动到主厅正面，符合公共信息挂在主厅前的设想。
- 再次通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现建筑数据、建筑点击、生产、NPC、导航或战斗逻辑。

### T0104 建立 HUD 基础界面

完成：
- 在 `res://scenes/main/Main.tscn` 的 `Main/UI/HUD` 下补齐标题、天数、小时/阶段、资源占位、加速按钮、警铃按钮和后端状态占位。
- 新增 `res://scripts/ui/HUD.gd`，从 `GameState` 读取当前天数和小时，并根据小时显示清晨/白昼/黄昏/夜间阶段。
- 资源显示保持占位值 `--`，后端状态固定为未连接占位；加速和警铃按钮不触发真实逻辑。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认 HUD 可见，并且没有遮挡主要驿站视角。

未做：
- 未实现真实资源变化、时间推进、警铃逻辑、后端连接或对话 UI。

### T0201 创建基础数据文件

完成：
- 新增 `data/resource_defs.json`，包含第纳尔、粮食、木材、石料、铁五类基础资源的最小配置。
- 新增 `data/building_defs.json`，包含主厅建筑的最小配置。
- 新增 `data/action_defs.json`，包含修补围墙行动的最小配置。
- 新增 `data/weapon_defs.json`，包含短剑武器的最小配置。
- 新增 `data/enemy_waves.json`，包含第一波敌人占位配置。
- 新增 `data/npc_profiles.json`，包含老兵副官占位档案。
- 更新 `DATA_SCHEMA.md`，补齐资源、武器、敌人波次 schema，并让已有示例与实际 JSON 字段一致。
- 更新 `MODULE_INDEX.md`，记录新增数据文件的用途、依赖和当前状态。

验证：
- 使用 PowerShell `ConvertFrom-Json` 验证 6 个 JSON 文件格式合法，且均为非空数组。
- 通过临时 Godot 脚本调用 `ConfigLoader.load_data_file(...)` 读取 6 个文件，确认每个文件均返回数组数据。
- 通过 Godot MCP 自检确认连接正常。

未做：
- 未实现资源系统、建筑系统、NPC 生成、战斗波次生成或 LLM 接入。

### T0105 实现基础摄像机控制

完成：
- 新增 `res://scripts/camera/CameraRig.gd`，绑定到 `Main/CameraRig`。
- 支持 WASD 键盘平移、鼠标中键拖拽平移、鼠标滚轮缩放。
- 通过 X/Z 边界和缩放距离限制，避免摄像机离开驿站太远。
- 保留当前高机位俯视角，只移动 `CameraRig` 和调整 `Camera3D` 本地距离。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- Godot MCP 确认 `/root/Main/CameraRig` 已挂载 `res://scripts/camera/CameraRig.gd`，并暴露平移、缩放和边界参数。
- 使用 `godot --headless --path . --quit-after 1` 验证项目加载无错误。

未做：
- 未实现角色控制、镜头旋转或自由第一人称视角。

### T0202 实现 ResourceSystem

完成：
- 在 `scripts/systems/ResourceSystem.gd` 中实现基础资源初始化和读写接口。
- 启动时通过 `ConfigLoader.load_data_file("resource_defs.json")` 读取第纳尔、粮食、木材、石料、铁的初始值和下限。
- 提供 `get_resource(id)`、`add_resource(id, amount)`、`can_afford(cost_dict)`、`spend_resources(cost_dict)`。
- 提供 `debug_add_resource(...)` 和 `debug_spend_resources(...)` 作为临时测试入口。
- 资源变化通过 `EventBus.resource_changed` 发出，`scripts/ui/HUD.gd` 监听信号并显示真实资源数值。

验证：
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过临时测试场景验证：初始金钱 30；调试增加 5 后扣除 10 成功；粮食扣除 2 成功；超额扣除 9999 金钱失败且没有产生负数。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示 `金钱 30`、`粮食 18`、`木材 12`、`石料 8`、`铁 5`。

未做：
- 未实现商人交易、建筑生产或工作产出。

### T0203 实现 BuildingSystem 与建筑实体

完成：
- 扩展 `data/building_defs.json`，当时覆盖 16 个建筑/门墙实体；2026-05-24 T0206 已将公告牌移出建筑定义，当前为 15 个建筑/门墙实体。
- 在 `scripts/systems/BuildingSystem.gd` 中实现建筑配置读取、基础状态保存、`get_building(...)` / `get_building_ids()` / `get_building_snapshot()` 查询接口。
- 通过 `scene_nodes` 将配置绑定到 `Main/WorldRoot/Station/Buildings` 下的低模节点。
- 为绑定建筑运行时创建 `Area3D/CollisionShape3D` 点击区，左键点击后发出 `EventBus.building_clicked(building_id)`。
- 将建筑调试标签更新为名称、等级和 HP，便于确认基础状态。

验证：
- `data/building_defs.json` 可被 PowerShell `ConvertFrom-Json` 解析；当时包含 16 条建筑定义，2026-05-24 T0206 后当前为 15 条。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 使用临时 Godot 验证脚本确认当时 `BuildingSystem` 加载 16 个建筑定义、主厅数据可查询、仓库可选中、主厅 ClickArea 已创建；2026-05-24 T0206 后公告牌不再加载为建筑。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认建筑标签显示名称、等级和 HP。
- Godot MCP 查找确认运行时创建了 19 个 `ClickArea` 节点，覆盖多段围墙、城门和主要建筑。

未做：
- 未实现建筑面板、升级、修复、生产、敌人攻击或建筑 HP 扣除。

### T0204 实现建筑面板

完成：
- 新增 `scripts/ui/BuildingPanel.gd`，监听 `EventBus.building_clicked` 并从 `BuildingSystem` 读取建筑基础状态。
- 扩展 `Main/UI/BuildingPanel`，显示建筑名称、等级、HP / Max HP、当前工作位和地点信息占位。
- 修复、升级按钮保持禁用，仅作为后续 T0205 的 UI 占位。
- 面板右上角关闭按钮可隐藏面板；未知建筑或无建筑时面板保持隐藏。

验证：
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 使用临时 Godot 验证脚本确认选择主厅会打开面板、切换仓库会刷新数据、关闭按钮会隐藏面板。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 与低模驿站仍正常显示。

未做：
- 未实现建筑修复、升级、生产、储存/消耗展示或敌人攻击。

### T0204 建筑面板真实点击修正

完成：
- 修正点击建筑时不能显示面板的问题。
- 在 `scripts/ui/HUD.gd` 中让 HUD 根节点忽略鼠标，避免全屏 Control 背板拦截 3D 建筑点击。
- 在 `scripts/systems/BuildingSystem.gd` 中增加 `_unhandled_input` 射线拾取，从当前相机向鼠标位置投射并识别带有 `building_id` 的点击区。

验证：
- 使用临时 Godot 验证脚本模拟真实鼠标点击主厅，确认 `BuildingPanel` 打开且显示“主厅”。
- 使用 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 验证项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

### T0205 建立建筑修复与升级占位逻辑

完成：
- 在 `scripts/systems/BuildingSystem.gd` 中实现建筑修复、升级、可用性检查和临时受损调试入口。
- 修复/升级统一通过 `ResourceSystem.spend_resources` 扣除石料；资源不足时不扣资源、不改变建筑状态。
- 在 `scripts/ui/BuildingPanel.gd` 中接通修复/升级按钮，并根据建筑 HP、等级、配置和资源状态自动启用或禁用。
- 在 `data/building_defs.json` 为主厅、宿舍、食堂、仓库、围墙加入 `repair` / `upgrade` 配置；围墙升级会提升等级、Max HP，并增加 1 个修复工作位。
- 新增 `tools/verify_building_repair_upgrade.gd`，覆盖 T0205 的最小验收路径。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过，项目加载无错误。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现复杂升级树、美术变化、生产结算、敌人攻击或战斗系统联动。

## 2026-05-20

### T0301 完成 8 个初始 NPC 数据草案

完成：
- 将 `data/npc_profiles.json` 从老兵副官占位档案扩展为 8 名初始 NPC：马夫、厨子、园丁、铁匠、老兵副官、神父、医生、工程师。
- 每名 NPC 均补齐 `id`、`name`、`gender`、`appearance`、`background_story`、`personality`、`desires`、`fears`、`abilities`、`states`、`skills`、`recruited`、`equipment`、`plan`、`short_term_memory`、`knowledge_graph`、`diary` 等字段。
- 老兵副官 `veteran_deputy_01` 设为女性且 `recruited=true`；医生 `doctor_01` 设为女性；其他 NPC 初始 `recruited=false`。
- 更新 `AI_NPC_SYSTEM.md`、`DATA_SCHEMA.md`、`MODULE_INDEX.md`、`CURRENT_STATE.md`、`TASKS.md` 和 `CHANGELOG.md`，让文档中的 NPC 列表与数据一致。

验证：
- 使用 PowerShell `ConvertFrom-Json` 验证 `data/npc_profiles.json` 格式合法。
- 确认 NPC 数量为 8，且只有老兵副官 `recruited=true`。
- 使用 `godot --headless --path . --quit-after 1` 验证项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 NPC 场景、NPCSystem 生成、点击、移动、对话、征召或 LLM 接入。

### T0302 创建 NPC 场景与 NPCSystem

完成：
- 新增 `scenes/npc/NPC.tscn`，作为通用 NPC 低模占位场景。
- 新增 `scripts/npc/NPC.gd`，保存唯一 `npc_id`，显示 NPC 调试标签，并在点击时发出 `EventBus.npc_clicked`。
- 扩展 `scripts/systems/NPCSystem.gd`，启动时读取 `data/npc_profiles.json` 并在 `Main/WorldRoot/Station/NPCs` 下生成 8 个 NPC。
- 提供 `get_npc(...)`、`get_npc_ids()`、`get_npc_count()` 和 `debug_select_npc(...)`，便于后续面板和验证脚本接入。
- 新增 `tools/verify_npc_generation_click.gd`，验证 NPC 生成数量和点击事件。

验证：
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。
- Godot MCP 查找确认 `Main/WorldRoot/Station/NPCs` 下生成 8 个 NPC `Area3D` 节点。

未做：
- 未实现 NPC 移动、状态面板、行动计划、对话、征召、战斗或 LLM 接入。

备注：
- 本次排查到一次 MCP 断连原因：Godot 插件仍在 `127.0.0.1:6550` 监听，但 `godot-mcp-broker.mjs` 未在 `127.0.0.1:8765` 监听，只剩 proxy 进程。手动启动 broker 后恢复，`tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
