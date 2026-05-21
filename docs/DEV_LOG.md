# DEV_LOG.md

> 按日期记录开发过程。  
> 每次完成任务后追加，不要覆盖历史。

## 2026-05-21

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
- 行动指派会先复用 `NPCSystem.move_npc_to_building(...)` 前往目标建筑，到达后自动结算。
- 菜园工作产出粮食，食堂工作消耗粮食产出餐食；吃饭优先消耗餐食并恢复更多饱食度，没有餐食时消耗粮食；睡觉降低疲劳。
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
- 补齐酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌等 T0103 要求的剩余占位区域。
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
- 扩展 `data/building_defs.json`，覆盖 16 个建筑/门墙实体：主厅、宿舍、食堂、仓库、围墙、城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊和公告牌。
- 在 `scripts/systems/BuildingSystem.gd` 中实现建筑配置读取、基础状态保存、`get_building(...)` / `get_building_ids()` / `get_building_snapshot()` 查询接口。
- 通过 `scene_nodes` 将配置绑定到 `Main/WorldRoot/Station/Buildings` 下的低模节点。
- 为绑定建筑运行时创建 `Area3D/CollisionShape3D` 点击区，左键点击后发出 `EventBus.building_clicked(building_id)`。
- 将建筑调试标签更新为名称、等级和 HP，便于确认基础状态。

验证：
- `data/building_defs.json` 可被 PowerShell `ConvertFrom-Json` 解析，包含 16 条建筑定义。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 使用临时 Godot 验证脚本确认 `BuildingSystem` 加载 16 个建筑定义、主厅数据可查询、仓库可选中、主厅 ClickArea 已创建。
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
