# DEV_LOG.md

> 按日期记录开发过程。  
> 每次完成任务后追加，不要覆盖历史。

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
