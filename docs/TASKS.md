# TASKS.md

> 本文件是 Agent 开发入口，也是项目从零推进到 Demo 完成的任务路线图。
> 每次开始实现前，必须确认任务在本文件中有明确条目。
> 每次完成后，必须更新状态、验收结果和后续任务。
> 原“建立文档回写流程”的 T0003 已取消；文档回写规则以 `AGENTS.md` 为准。当前 T0003 用于记录 Godot MCP 启动稳定化任务。

---

# 0. 使用方式

## 0.1 给 Agent 的固定启动指令

每次让 Agent 继续开发时，可以直接使用以下指令：

```
执行 TASKS.md 中的Txxxx
```

## 0.2 任务状态

- `Todo`：未开始
- `Doing`：正在做
- `Partial`：部分完成，可运行但未完全达标
- `Blocked`：受阻，需要用户或外部条件
- `Done`：已完成并验证

## 0.3 优先级

- `P0`：Demo 主线必需；不做就无法形成核心闭环
- `P1`：重要增强；能显著改善玩法体验，但可在 P0 闭环后实现
- `P2`：锦上添花；参赛展示可后置

## 0.4 每个任务的默认回写要求

每个任务完成后，至少检查并按需更新：

- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- `docs/DEV_LOG.md`
- 对应模块文档，例如：
  - Godot 架构：`docs/GODOT_ARCHITECTURE.md`
  - 后端架构：`docs/TECH_ARCHITECTURE.md`
  - NPC：`docs/AI_NPC_SYSTEM.md`
  - 记忆：`docs/MEMORY_AND_INFO_SPACE.md`
  - 建筑资源：`docs/ECONOMY_AND_BUILDINGS.md`
  - 战斗：`docs/COMBAT_SYSTEM.md`
  - UI：`docs/UI_UX.md`
  - Prompt：`docs/PROMPTS.md`
  - API 成本：`docs/API_BUDGET.md`

## 0.5 每个任务的禁止事项

除任务明确要求外，默认禁止：

- 不要修改无关模块。
- 不要实现下一个任务的内容。
- 不要把 NPC 档案、建筑数值、Prompt 写死在 GDScript 中。
- 不要让 LLM 决定 HP、资源、伤害、建筑摧毁等权威数值。
- 不要一次性大规模重构。
- 不要恢复已经从策划案中删掉的机制。

---

# M0：项目骨架与工具稳定

目标：让 Godot 项目、Python 后端、MCP 工具和项目文档结构可运行、可检查、可继续开发。

---

## T0001 初始化 Godot 项目结构

状态：Done
优先级：P0
涉及文档：`GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`

验收标准：

- Godot 项目可以打开。
- 存在主场景 `Main.tscn`。
- 存在基础目录：`scenes/`, `scripts/`, `ui/`, `assets/`, `data/`。
- `CURRENT_STATE.md` 记录运行方式。
- `MODULE_INDEX.md` 记录新增路径。

验收结果（2026-05-19）：

- 已创建并设置启动场景 `res://scenes/main/Main.tscn`。
- 已确认基础目录 `scenes/`, `scripts/`, `ui/`, `assets/`, `data/` 存在，并补齐 `scenes/main/`, `scenes/world/`, `scenes/npc/`, `scenes/enemy/`, `scenes/buildings/`, `scenes/ui/`, `scripts/core/`, `scripts/systems/`；空目录用 `.gitkeep` 保留。
- 已通过 Godot MCP 运行 `Main.tscn`，无游戏日志报错，截图可见最小 HUD 标题和基础 3D 地面。
- 本任务只完成项目入口和 Main 场景占位，不实现 NPC、建筑交互、资源、时间或战斗。

---

## T0002 初始化后端目录

状态：Done
优先级：P0
涉及文档：`TECH_ARCHITECTURE.md`, `API_BUDGET.md`, `MODULE_INDEX.md`

验收标准：

- 存在 `backend/app.py`。
- 存在后端 README。
- 存在基础服务目录：`schemas/`, `services/`, `data/`。
- 能启动一个本地健康检查接口。
- 使用环境变量读取 LLM API Key，仓库中不提交真实 API Key。

验收结果（2026-05-19）：

- 已创建 `backend/app.py`，使用 Flask 提供 `GET /health`。
- `/health` 返回 `{"ok": true, "service": "war-not-mine-backend"}`。
- `backend/requirements.txt` 已包含 `flask`、`python-dotenv`、`pydantic`、`requests`。
- 已创建 `backend/.env.example`，仅提供本地配置模板，不提交真实 API Key。
- 已创建 `backend/schemas/`、`backend/services/`、`backend/data/`，并用 `.gitkeep` 保留空目录。
- 已创建最小 `backend/services/model_adapter.py`，仅负责读取 provider 和 API Key 配置，不实现实际 LLM 调用。
- 本任务未修改 Godot 场景，未实现 NPC、战斗、资源或 AI 对话。

---

## T0003 Stabilize Godot MCP startup

状态：Done
优先级：P0
涉及文档：`CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

验收标准：

- Codex 的 `godot-mcp` 启动入口改为单实例包装脚本，新的启动会清理旧实例。
- 只保留 1 条有效的 Godot MCP 客户端连接到 Godot 编辑器。
- `tools/check_godot_mcp.ps1` 可以正常报告连接状态，不再出现脚本解析错误。

---

# M1：Godot 核心骨架与最小驿站

目标：进入 Godot 后能看到一个结构清楚的低模驿站场景，具备基础系统节点、资源栏、时间显示和可扩展 UI 骨架。
本阶段不实现 NPC AI、不实现真实战斗、不接 LLM。

---

## T0101 建立核心 Autoload 与系统骨架

状态：Done
优先级：P0
前置任务：T0001
涉及文档：`GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CODING_RULES.md`

任务目标：

建立 Godot 项目的基础脚本骨架，让后续系统通过统一入口通信。

实现范围：

- 新增 `res://scripts/core/EventBus.gd`
- 新增 `res://scripts/core/GameState.gd`
- 新增 `res://scripts/core/ConfigLoader.gd`
- 在 `project.godot` 中配置必要 Autoload
- 新增空的系统节点脚本占位：
  - `TimeSystem.gd`
  - `ResourceSystem.gd`
  - `BuildingSystem.gd`
  - `NPCSystem.gd`
  - `MemorySystem.gd`

禁止事项：

- 不实现 NPC。
- 不实现建筑点击。
- 不实现资源变化。
- 不接后端。
- 不修改后端代码。

验收标准：

- Godot 项目启动无报错。
- Autoload 能正常加载。
- `EventBus` 至少声明基础信号：
  - `resource_changed`
  - `hour_started`
  - `building_clicked`
  - `npc_clicked`
  - `public_event_added`
- `GameState` 至少保存当前天数、小时、是否战斗中。
- `ConfigLoader` 能读取 JSON 文件，并在文件不存在时给出明确错误。
- `MODULE_INDEX.md` 记录新增核心脚本。

验收结果（2026-05-19）：

- 已新增 `res://scripts/core/EventBus.gd`，声明 `resource_changed`、`hour_started`、`building_clicked`、`npc_clicked`、`public_event_added` 基础信号。
- 已新增 `res://scripts/core/GameState.gd`，保存 `current_day`、`current_hour`、`in_combat`，并提供最小时间/战斗状态设置接口。
- 已新增 `res://scripts/core/ConfigLoader.gd`，支持读取 JSON；文件不存在、打开失败或解析失败时通过 `push_error` 给出明确错误并返回默认值。
- 已在 `project.godot` 注册 `EventBus`、`GameState`、`ConfigLoader` Autoload，保留既有 `MCPGameBridge`。
- 已新增 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`MemorySystem.gd` 空系统脚本占位。
- 已通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

---

## T0102 扩展 Main 场景节点结构

状态：Done
优先级：P0
前置任务：T0101
涉及文档：`GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`

任务目标：

把当前 Main 占位场景整理成后续可扩展的标准节点结构。

推荐节点结构：

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
│  └─ DialogSystem
├─ UI
│  ├─ HUD
│  ├─ NPCPanel
│  ├─ BuildingPanel
│  └─ DialogPanel
└─ CameraRig
```

禁止事项：

- 不实现点击逻辑。
- 不实现 NPC。
- 不实现资源数值。
- 不实现战斗。

验收标准：

- 启动仍进入 `Main.tscn`。
- 场景树结构清晰，命名与文档一致。
- 当前 HUD 标题仍可见。
- `GODOT_ARCHITECTURE.md` 与 `MODULE_INDEX.md` 已同步更新。

验收结果（2026-05-19）：

- 已将 `res://scenes/main/Main.tscn` 整理为 `WorldRoot/Station`、`Systems`、`UI`、`CameraRig` 的标准结构。
- `WorldRoot/Station` 下保留 `Ground`，并补齐 `Buildings`、`NPCs`、`Enemies`、`Props` 容器。
- `Systems` 下补齐 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem`、`MemorySystem`、`CombatSystem`、`DialogSystem`，均为占位节点；未实现任何点击、NPC、资源或战斗逻辑。
- `UI` 下保留 `HUD/TitleLabel`，并补齐隐藏占位 `NPCPanel`、`BuildingPanel`、`DialogPanel`。
- 新增 `ActionSystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 空系统脚本占位。
- 已通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 标题与基础地面仍可见。

---

## T0103 创建低模驿站 Blockout

状态：Done
优先级：P0
前置任务：T0102
涉及文档：`GODOT_ARCHITECTURE.md`, `ECONOMY_AND_BUILDINGS.md`, `MODULE_INDEX.md`

任务目标：

用简单几何体搭出边境驿站的空间占位，用于后续建筑和导航。

需要出现的占位区域：

- 主厅
- 宿舍
- 食堂
- 仓库
- 围墙 / 城门
- 广场
- 后门 / 商人入口占位
- 酒窖
- 菜园
- 铁匠铺
- 训练场
- 马厩
- 小教堂
- 小诊所
- 工械坊
- 公告牌

禁止事项：

- 不实现建筑数据。
- 不实现建筑点击。
- 不实现生产。
- 不做精细美术。

验收标准：

- 玩家启动项目后能看到一个可辨认的低模驿站。
- 摄像机角度适合俯视管理。
- 每个占位建筑有清晰名称或调试标签。
- 场景运行无报错。

验收结果（2026-05-19）：

- 已在 `res://scenes/main/Main.tscn` 中补齐 T0103 所列低模空间占位：主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌。
- 每个占位区域均使用简单几何体和 `Label3D` 调试标签表示，保持 Blockout 阶段边界。
- 已通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD、低模驿站和调试标签可见。
- 未实现建筑数据、建筑点击、生产、NPC、导航或战斗逻辑。

追加调整（2026-05-19）：

- 根据反馈扩大地面、围墙和相机视野，并拉开建筑间距。
- 建筑现在按中央广场、生活区、生产区、防务区和后门入口周边分布，降低占位过小过密的问题。
- 已再次通过 Godot MCP 运行主场景，游戏日志无报错。

反馈修正（2026-05-19）：

- 补齐围墙四角闭合，避免驿站院墙看起来断开。
- 将公告牌缩小并移动到主厅正面，不再作为广场中央的大型独立物件。
- 已再次通过 Godot MCP 运行主场景，游戏日志无报错。

---

## T0104 建立 HUD 基础界面

状态：Done
优先级：P0
前置任务：T0102
涉及文档：`UI_UX.md`, `MODULE_INDEX.md`

任务目标：

创建最小 HUD，用于显示时间、资源和基础操作按钮。

显示内容：

- 游戏标题
- 当前天数
- 当前小时 / 阶段
- 金钱、粮食、木材、石料、铁
- 加速按钮占位
- 警铃按钮占位
- 后端连接状态占位

禁止事项：

- 不实现真实资源变化。
- 不实现警铃逻辑。
- 不实现后端连接。
- 不实现对话 UI。

验收标准：

- HUD 随 Main 场景启动显示。
- UI 不遮挡主要驿站视角。
- HUD 节点路径记录在 `MODULE_INDEX.md`。
- `UI_UX.md` 同步当前 HUD 结构。

验收结果（2026-05-19）：

- 已在 `res://scenes/main/Main.tscn` 的 `Main/UI/HUD` 下补齐标题、天数、小时/阶段、金钱、粮食、木材、石料、铁、加速按钮、警铃按钮和后端状态占位。
- 新增 `res://scripts/ui/HUD.gd`，仅负责读取 `GameState` 当前天数/小时并刷新 HUD 占位文本；资源、警铃和后端连接仍为占位，不执行真实逻辑。
- HUD 以左上角小面积信息块显示，Godot MCP 截图确认没有遮挡主要驿站视角。
- 已通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

---

## T0105 实现基础摄像机控制

状态：Done
优先级：P1
前置任务：T0103
涉及文档：`GODOT_ARCHITECTURE.md`, `UI_UX.md`

任务目标：

让玩家可以在俯视视角下查看驿站。

实现范围：

- 鼠标中键或键盘 WASD 平移
- 鼠标滚轮缩放
- 限制摄像机边界
- 保持高机位俯视角

禁止事项：

- 不实现角色控制。
- 不实现自由第一人称视角。

验收标准：

- 可以平移查看驿站。
- 可以缩放。
- 不会移出场景太远。
- 操作手感基本可用。

验收结果（2026-05-19）：

- 已新增 `res://scripts/camera/CameraRig.gd` 并绑定到 `Main/CameraRig`。
- 支持 WASD 键盘平移、鼠标中键拖拽平移、鼠标滚轮缩放。
- 摄像机保持现有高机位俯视角，只调整 `CameraRig` 的 X/Z 位置和 `Camera3D` 的本地距离。
- 已设置 X/Z 边界和缩放距离限制，避免视角移出场景太远。
- 已通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错；MCP 可确认 `CameraRig` 挂载脚本和导出参数。
- 已使用 `godot --headless --path . --quit-after 1` 验证项目加载无错误。

---

# M2：配置化数据与建筑/资源基础

目标：建立数据驱动基础，让建筑、资源、行动、NPC 档案都从配置读取，而不是写死在脚本中。

---

## T0201 创建基础数据文件

状态：Done
优先级：P0
前置任务：T0101
涉及文档：`DATA_SCHEMA.md`, `MODULE_INDEX.md`

任务目标：

建立项目初始 JSON 数据文件。

需要新增：

- `data/resource_defs.json`
- `data/building_defs.json`
- `data/action_defs.json`
- `data/weapon_defs.json`
- `data/enemy_waves.json`
- `data/npc_profiles.json`

禁止事项：

- 不实现完整数值平衡。
- 不写过复杂字段。
- 不接 LLM。

验收标准：

- 每个 JSON 文件格式合法。
- `ConfigLoader` 能读取这些文件。
- 每个文件至少有 1 条示例数据。
- `DATA_SCHEMA.md` 与实际字段一致。
- `MODULE_INDEX.md` 记录数据文件。

验收结果（2026-05-19）：

- 已新增 `data/resource_defs.json`、`data/building_defs.json`、`data/action_defs.json`、`data/weapon_defs.json`、`data/enemy_waves.json`、`data/npc_profiles.json`。
- 每个文件均为合法 JSON 数组，且至少包含 1 条最小样例数据；`resource_defs.json` 包含 HUD 规划中的五类基础资源。
- 已用 `ConfigLoader.load_data_file(...)` 读取 6 个文件并确认返回数组数据。
- 已同步更新 `DATA_SCHEMA.md` 和 `MODULE_INDEX.md`。
- 本任务仅建立配置数据，不实现资源系统、建筑系统、NPC 生成、战斗或 LLM 接入。

---

## T0202 实现 ResourceSystem

状态：Done
优先级：P0
前置任务：T0201, T0104
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`

任务目标：

实现资源读写接口，并将资源显示到 HUD。

资源包括：

- 金钱 / 第纳尔
- 粮食
- 木材
- 石料
- 铁

实现范围：

- 初始化资源数值
- `get_resource(id)`
- `add_resource(id, amount)`
- `can_afford(cost_dict)`
- `spend_resources(cost_dict)`
- 资源变化发出 `resource_changed` 信号
- HUD 自动刷新显示

禁止事项：

- 不实现商人交易。
- 不实现建筑生产。
- 不实现工作产出。

验收标准：

- 启动后 HUD 显示资源。
- 可通过调试按钮或临时测试方法增减资源。
- 资源不足时扣除失败且不产生负数。
- 文档回写完成。

验收结果（2026-05-19）：

- 已实现 `scripts/systems/ResourceSystem.gd`，启动时从 `data/resource_defs.json` 初始化第纳尔、粮食、木材、石料、铁。
- 已提供 `get_resource(id)`、`add_resource(id, amount)`、`can_afford(cost_dict)`、`spend_resources(cost_dict)`，并保留 `debug_add_resource(...)` 与 `debug_spend_resources(...)` 作为临时测试入口。
- 资源变化会通过 `EventBus.resource_changed` 发出信号，`scripts/ui/HUD.gd` 监听后自动刷新。
- 通过临时测试场景验证：初始金钱为 30；增加 5 后扣除 10 成功；粮食扣除 2 成功；超额扣除 9999 金钱失败且资源不变为负数。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示 `金钱 30`、`粮食 18`、`木材 12`、`石料 8`、`铁 5`。

---

## T0203 实现 BuildingSystem 与建筑实体

状态：Done
优先级：P0
前置任务：T0103, T0201
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`

任务目标：

让驿站中的建筑由配置驱动生成或绑定，并具备基础属性。

需要支持的建筑：

- 主厅
- 宿舍
- 食堂
- 仓库
- 围墙
- 酒窖
- 菜园
- 铁匠铺
- 训练场
- 马厩
- 小教堂
- 小诊所
- 工械坊
- 公告牌

实现范围：

- 建筑 ID
- 名称
- HP / Max HP
- 等级
- 工作位列表
- 建筑点击事件
- 发出 `building_clicked`

禁止事项：

- 不实现升级。
- 不实现修复。
- 不实现生产。
- 不实现敌人攻击。

验收标准：

- 点击建筑可识别建筑 ID。
- 建筑信息来自 `building_defs.json`。
- 至少 5 个 P0 建筑能显示基础状态。
- 不把建筑数值写死在场景脚本中。

验收结果（2026-05-19）：

- 已扩展 `data/building_defs.json`，覆盖主厅、宿舍、食堂、仓库、围墙、城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌 16 个建筑/门墙实体。
- 已实现 `scripts/systems/BuildingSystem.gd`：读取建筑配置，按 `scene_nodes` 绑定低模建筑节点，保存 `id`、名称、等级、HP / Max HP、工作位等基础状态。
- 已为绑定到 MeshInstance3D 的建筑运行时创建 `Area3D/CollisionShape3D` 点击区；点击后通过 `EventBus.building_clicked(building_id)` 发出建筑 ID。
- 已将建筑调试标签更新为名称、等级和 HP；主场景中超过 5 个 P0 建筑可见基础状态。
- 已通过 `godot --headless --path . --quit-after 1`、临时 Godot 验证脚本和 Godot MCP 主场景运行验证；游戏日志无报错。

---

## T0204 实现建筑面板

状态：Done
优先级：P0
前置任务：T0203
涉及文档：`UI_UX.md`, `ECONOMY_AND_BUILDINGS.md`, `MODULE_INDEX.md`

任务目标：

点击建筑后显示建筑信息面板。

显示内容：

- 建筑名称
- 建筑等级
- HP / Max HP
- 当前工作位
- 当前地点信息占位
- 修复按钮占位
- 升级按钮占位

禁止事项：

- 修复按钮可先不可用。
- 升级按钮可先不可用。
- 不实现生产细节。

验收标准：

- 点击不同建筑显示不同信息。
- 面板可关闭。
- 没有建筑时不显示错误信息。
- UI 文档更新。

验收结果（2026-05-19）：

- 已新增 `scripts/ui/BuildingPanel.gd` 并绑定到 `Main/UI/BuildingPanel`。
- 点击建筑后，面板通过 `EventBus.building_clicked(building_id)` 从 `BuildingSystem` 读取建筑名称、等级、HP / Max HP、工作位和地点信息占位。
- 修复与升级按钮已显示但保持禁用，占位后续 T0205，不执行真实修复、升级或生产逻辑。
- 面板右上角关闭按钮可隐藏面板；无建筑或未知建筑 ID 时面板保持隐藏且不报错。
- 已通过 `godot --headless --path . --quit-after 1`、临时 Godot 验证脚本和 Godot MCP 主场景运行验证；游戏日志无报错。

修正记录（2026-05-20）：

- 修正真实鼠标点击建筑无法打开面板的问题。
- `HUD.gd` 让全屏 HUD 根节点忽略鼠标，避免背板拦截 3D 地图点击。
- `BuildingSystem.gd` 增加 `_unhandled_input` 相机射线拾取点击区，真实左键点击建筑会稳定触发 `building_clicked`。
- 已用临时 Godot 验证脚本覆盖真实鼠标点击路径：点击主厅后面板打开并显示“主厅”。

---

## T0205 建立建筑修复与升级占位逻辑

状态：Done
优先级：P1
前置任务：T0202, T0204
涉及文档：`ECONOMY_AND_BUILDINGS.md`

任务目标：

为后续防守战做建筑修复和升级基础。

实现范围：

- 消耗石料修复建筑 HP
- 消耗石料升级建筑等级
- 升级后提高 Max HP 或工作位数量
- UI 按钮可触发

禁止事项：

- 不做复杂升级树。
- 不做美术变化。
- 不影响战斗系统。

验收标准：

- 建筑 HP 受损后可修复。
- 资源不足时无法修复/升级。
- 升级至少能影响一个数值。

验收结果（2026-05-20）：

- 已在 `BuildingSystem.gd` 中实现 `can_repair_building`、`repair_building`、`can_upgrade_building`、`upgrade_building` 和临时验证用 `debug_damage_building`。
- 修复/升级消耗由 `ResourceSystem.spend_resources` 权威结算；资源不足时返回失败，不扣除资源，不改变建筑状态。
- 已在 `data/building_defs.json` 为主厅、宿舍、食堂、仓库、围墙加入 `repair` / `upgrade` 配置；围墙升级会提升等级、Max HP 并增加 1 个修复工作位。
- `BuildingPanel.gd` 的修复/升级按钮现在会触发系统接口，并根据当前 HP、等级和资源是否足够自动启用/禁用。
- 已新增 `tools/verify_building_repair_upgrade.gd` 验证：围墙受损后可用石料修复，升级消耗石料并改变等级、Max HP、工作位，石料不足时升级失败且资源不变。
- 已通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`--quit-after 1` 和 Godot MCP 主场景运行验证；游戏日志无报错。

---

# M3：NPC 数据、状态与基础行动

目标：让 8 个初始 NPC 以数据驱动方式出现，并能移动、显示状态、执行最简单的工作/吃饭/睡觉行为。

---

## T0301 完成 8 个初始 NPC 数据草案

状态：Done
优先级：P0
前置任务：T0201
涉及文档：`AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`, `MODULE_INDEX.md`

任务目标：

补全 `data/npc_profiles.json` 中 8 个 NPC 的基础档案。

必须包含：

1. 马夫
2. 厨子
3. 园丁
4. 铁匠
5. 老兵副官，女性，开局可控
6. 神父
7. 医生，女性
8. 工程师

字段至少包括：

- id
- name
- gender
- appearance
- background_story
- personality
- desires
- fears
- abilities
- states
- skills
- recruited
- equipment
- plan
- short_term_memory
- knowledge_graph
- diary

禁止事项：

- 不写成长篇小说。
- 不接 LLM。
- 不实现 NPC 行为。

验收标准：

- 8 个 NPC 数据格式合法。
- 副官 `recruited=true` 
- 其他 NPC 初始不可指派。
- 文档中的 NPC 列表与数据一致。

验收结果（2026-05-20）：

- `data/npc_profiles.json` 已补齐 8 名初始 NPC：马夫、厨子、园丁、铁匠、老兵副官、神父、医生、工程师。
- 每名 NPC 均包含 T0301 要求的基础字段：`id`、`name`、`gender`、`appearance`、`background_story`、`personality`、`desires`、`fears`、`abilities`、`states`、`skills`、`recruited`、`equipment`、`plan`、`short_term_memory`、`knowledge_graph`、`diary`。
- 老兵副官 `veteran_deputy_01` 为女性且 `recruited=true`；其他 7 名 NPC `recruited=false`。
- 已通过 PowerShell `ConvertFrom-Json` 验证 JSON 格式合法并确认数量为 8。

---

## T0302 创建 NPC 场景与 NPCSystem

状态：Done
优先级：P0
前置任务：T0301, T0102
涉及文档：`AI_NPC_SYSTEM.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`

任务目标：

从 `npc_profiles.json` 读取并生成 8 个 NPC。

实现范围：

- 通用 `NPC.tscn`
- `NPC.gd`
- `NPCSystem.gd`
- NPC 显示名字或调试标签
- NPC 具有唯一 ID
- 点击 NPC 发出 `npc_clicked`

禁止事项：

- 不实现 LLM。
- 不实现复杂移动。
- 不实现战斗。
- 不实现对话。

验收标准：

- 启动场景后能看到 8 个 NPC 占位模型。
- 点击 NPC 能打印或显示对应 ID。
- NPC 数据来自 JSON。
- `MODULE_INDEX.md` 更新路径。

验收结果（2026-05-20）：

- 已新增通用 `res://scenes/npc/NPC.tscn` 和 `res://scripts/npc/NPC.gd`，NPC 为可点击 `Area3D`，带低模胶囊占位和 `Label3D` 短姓名/HP/当前行动标签。
- `res://scripts/systems/NPCSystem.gd` 启动时读取 `data/npc_profiles.json`，在 `Main/WorldRoot/Station/NPCs` 下生成 8 个 NPC，并保存唯一 `npc_id`。
- 点击 NPC 或调用 `debug_select_npc(npc_id)` 会打印对应 ID，并通过 `EventBus.npc_clicked` 发出事件。
- 已通过 `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 验证 8 个 NPC 生成和 `npc_clicked` 信号。
- 已通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，MCP 查找确认 8 个 NPC `Area3D` 节点存在。

---

## T0303 实现 NPC 基础状态与 NPC 面板

状态：Done
优先级：P0
前置任务：T0302
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`, `DATA_SCHEMA.md`

任务目标：

让 NPC 状态可视化，并支持后续系统读取。

显示状态：

- HP
- 饱食度
- 疲劳度
- 金钱
- 是否昏迷
- 是否已入伍
- 当前行动占位
- 技能熟练度

禁止事项：

- 不实现状态自然变化。
- 不实现治疗。
- 不实现对话。

验收标准：

- 点击 NPC 打开 NPC 面板。如果建筑面板打开着，关闭建筑面板然后切换到NPC面板，点击建筑则又能切换到建筑面板。
- 面板显示正确数据。
- 面板可关闭。
- NPC 状态修改后面板可刷新。

验收结果（2026-05-20）：

- 已新增 `res://scripts/ui/NPCPanel.gd` 并接入 `Main/UI/NPCPanel`，点击 NPC 后按“姓名 → HP → 属性 → 专长 → 饱食度 → 疲劳度 → 金钱 → 昏迷 → 入伍 → 当前行动 → 职业熟练度 / 武器熟练度”的顺序显示数据；属性当前展示 `stats.strength` / 力量和 `stats.intelligence` / 智力，专长由熟练度推导。
- `NPCSystem` 现在提供 `get_npc_state(...)`、`update_npc_state(...)`、`set_npc_state_value(...)`，状态更新后发出 `npc_state_changed`，NPC 面板会自动刷新。
- `NPC.gd` 的头顶调试标签显示短姓名、HP 和当前行动摘要；职业与入伍状态保留在 NPC 面板。
- `NPCPanel` 和 `BuildingPanel` 已通过 `npc_clicked` / `building_clicked` 互斥切换；NPC 面板可用关闭按钮隐藏。
- 已通过 `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 验证 NPC 面板打开、HP/属性/专长顺序、状态刷新、建筑/NPC 面板切换和关闭按钮。
- 已通过 `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 回归验证 T0302；通过 Godot MCP 运行主场景，游戏日志无报错。

---

## T0304 实现基础移动与地点进入

状态：Done
优先级：P0
前置任务：T0203, T0302
涉及文档：`GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`

任务目标：

让 NPC 能移动到指定建筑或地点。

实现范围：

- 简单导航或直线移动
- 指定目标建筑
- 到达后记录当前地点
- 进入地点后触发地点信息读取占位

禁止事项：

- 不实现复杂避障。
- 不实现真实日程计划。
- 不接 LLM。

验收标准：

- 可以通过调试命令让 NPC 前往食堂/宿舍/仓库。
- 到达后 NPC 当前地点更新。
- 移动过程中无报错。

验收结果（2026-05-21）：

- `NPCSystem.debug_move_npc_to_building(npc_id, building_id)` 可让 NPC 前往 `dining_hall`、`dormitory`、`warehouse`。
- `NPC.gd` 使用直线移动，到达后通过 `movement_arrived` 回调 `NPCSystem`。
- `BuildingSystem.get_building_entry_position(...)` 提供建筑入口坐标，`get_building_location_context(...)` 提供地点信息读取占位。
- 到达后 NPC 状态更新 `current_location`、`current_location_name`、`location_context`，并发出 `npc_state_changed`。
- 已通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 验证；并回归通过 `verify_npc_generation_click.gd`、`verify_npc_panel_state.gd`。

---

## T0305 实现简单行动系统：工作 / 吃饭 / 睡觉

状态：Done
优先级：P0
前置任务：T0202, T0203, T0304
涉及文档：`AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`

任务目标：

让 NPC 能执行最小行动闭环。

行动包括：

- 工作：产生、消耗资源的占位逻辑（哪个建筑工位产生什么消耗什么，在game_design对应处有写）
- 吃饭：消耗粮食或餐食，恢复饱食度，粮食做成餐食后恢复的更多
- 睡觉：恢复疲劳度

禁止事项：

- 不实现 LLM 日程。
- 不实现复杂职业产出。
- 不实现训练。
- 不实现战斗。

验收标准：

- NPC 可被调试指令安排去工作。
- 吃饭能恢复饱食度并消耗资源。
- 睡觉能降低疲劳度。
- 行动结束后写入 EventLog 占位。

验收结果（2026-05-21）：

- `ActionSystem` 已读取 `data/action_defs.json`，提供 `debug_assign_work(npc_id, building_id)`、`debug_assign_eat(npc_id)`、`debug_assign_sleep(npc_id)` 和 `debug_assign_action(npc_id, action_id)`。
- 调试指派会复用 `NPCSystem.move_npc_to_building(...)`，NPC 到达目标建筑后自动结算行动。
- 菜园工作可产出粮食；食堂工作可消耗粮食产出餐食；酒窖可消耗粮食产出酒；铁匠铺可消耗铁和木材产出武器/盔甲；工械坊可消耗木材产出工程器械；马厩可消耗粮食产出马匹整备占位；围墙修补可消耗石料恢复围墙 HP；吃饭优先消耗餐食并恢复更多饱食度，没有餐食时消耗粮食；睡觉降低疲劳。
- 已修正无产出工作不会结算饱食/疲劳和 EventLog 的问题。
- `MemorySystem` 已提供最小 EventLog 占位，行动成功/失败会写入事件。
- 已通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 验证吃饭、睡觉、基础生产、派生资源生产和围墙修补；并回归通过 `verify_npc_movement_location.gd`、`verify_npc_panel_state.gd`、`verify_npc_generation_click.gd`；通过 Godot MCP 运行主场景，游戏日志无报错。

---

# M4：时间系统、事件系统与信息空间

目标：让一天 24 阶段运转起来，并建立事件、地点见闻和广场公开信息，为 AI 记忆做准备。

---

## T0401 实现 TimeSystem

状态：Done
优先级：P0
前置任务：T0101, T0104
涉及文档：`GODOT_ARCHITECTURE.md`, `UI_UX.md`

任务目标：

实现游戏时间流逝。

规则：

- 一天 24 个阶段
- 每阶段对应 1 小时
- 正常状态下游戏内 1 分钟 = 现实 1 秒
- 支持暂停
- 支持加速
- 发出 `hour_started(day, hour)`
- 发出 `day_started(day)`

禁止事项：

- 不接入真实 LLM 请求。
- 不实现每日计划。
- 不实现战斗倒计时。

验收标准：

- HUD 显示当前天数和小时。
- 时间正常前进。
- 可暂停和加速。
- 小时变化时系统发出信号。

验收结果（2026-05-21）：

- 已在 `scripts/systems/TimeSystem.gd` 实现 24 小时阶段推进：默认现实 1 秒 = 游戏内 1 分钟，每 60 分钟推进 1 小时。
- 已支持暂停和 `x1` / `x2` / `x4` 加速；`HUD` 的速度按钮只循环切换速度，独立暂停按钮控制暂停/继续。
- 已补充 `EventBus.day_started(day)` 信号；小时变化时继续发出 `hour_started(day, hour)`。
- `HUD` 会随 `hour_started` / `day_started` 刷新天数、小时与阶段文本。
- 已新增 `tools/verify_time_system.gd` 覆盖时间推进、暂停、加速、跨天信号和 HUD 刷新。
- 已通过 `godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --quit-after 1`、现有 NPC/行动回归验证，以及 Godot MCP 主场景运行日志检查。

修正记录（2026-05-21）：

- HUD 时间显示已从整点 `HH:00` 修正为 `HH:MM:SS`，并随 `TimeSystem` 的游戏秒连续刷新。
- `GameState` 增加 `current_minute` / `current_second`；`EventBus` 增加 `time_changed(day, hour, minute, second)`。
- `SpeedButton` 只负责切换 `x1` / `x2` / `x4` 流速；新增 `PauseButton` 控制暂停/继续。
- 空格键绑定到同一套暂停/继续逻辑。
- `tools/verify_time_system.gd` 已补充秒级流逝、独立速度按钮、暂停按钮和空格暂停验证。

架构修正（2026-05-22）：

- TimeSystem 明确改为“逻辑时间倍率”系统，不修改 `Engine.time_scale`，不直接改变 NPC 移动、动画或物理速度。
- 玩家速度 `x1` / `x2` / `x4` 只影响逻辑时间与未来数值结算倍率。
- 新增 LLM 等待减速底层接口：`request_time_slowdown(request_id, scale, reason)`、`release_time_slowdown(request_id)`、`clear_time_slowdowns()`。
- 默认 LLM 等待倍率为 `1/60`，即默认 `x1` 下从现实 1 秒 = 游戏 1 分钟减缓为现实 1 秒 = 游戏 1 秒。
- 新增 `time_scale_changed(player_scale, effective_scale, numeric_multiplier, reason)` 和 `logical_time_tick(game_delta_seconds, numeric_multiplier)`，供后续资源、计划、事件和战斗系统按有效逻辑倍率结算。
- 已补充验证：LLM 等待减速时 `get_game_delta_seconds(1.0)` 返回 1 游戏秒，释放后恢复玩家设定倍率。

暂停语义修正（2026-05-22）：

- 空格键只绑定暂停/继续，不绑定加速；`SpeedButton` 只负责 `x1` / `x2` / `x4`。
- 暂停时逻辑时间停止、NPC 移动停止，当前已接入的行动资源/状态结算不会执行；行动保持 pending，恢复后再结算。
- 暂停不冻结 UI、后端请求或未来 LLM 对话/判定请求；LLM 返回后的权威状态改变仍由程序在可推进时结算。
- `tools/verify_time_system.gd` 已覆盖空格不改变速度、NPC 暂停移动、暂停期间行动不消耗/产出资源且恢复后结算。

---

## T0402 实现结构化事件底座

状态：Todo
优先级：P0
前置任务：T0101
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `DATA_SCHEMA.md`, `MODULE_INDEX.md`

任务目标：

把 `MemorySystem` 从最小 EventLog 占位升级为结构化事件事实源。事件系统是游戏信息产生、记录和传递的底层系统，类似面向 AI 记忆与叙事的埋点系统。

事件字段必须支持：

- `event_id`
- `day` / `time`
- `type`
- `subject_npc_id`
- `actor_ids`
- `target_ids`
- `location_id`
- `visibility`
- `importance`
- `summary`
- `payload`

事件类型至少预留：

- `wake_up`、`plan_created`、`reflection_started`、`sleep_started`、`sleep_ended`
- `location_entered`、`location_exited`
- `work_started`、`work_completed`、`work_failed`、`eat_started`、`eat_completed`
- `dialogue_started`、`dialogue_turn`、`dialogue_ended`
- `money_given`、`equipment_given`、`equipment_changed`、`order_assigned`、`npc_attacked_by_player`
- `skill_improved`、`npc_recruited`、`npc_left_recruited_state`
- `combat_started`、`combat_ended`、`attack_made`、`damage_taken`、`low_hp_triggered`、`unconscious_started`、`healing_started`、`healing_completed`、`revived`、`escape_started`、`escaped`
- `building_damaged`、`building_repaired`、`building_upgraded`、`resource_changed`

需要支持：

- 添加结构化事件。
- 每个事件首先写入 `subject_npc_id` 对应 NPC 的当天事件库。
- 查询当天全部事件。
- 查询某 NPC 的当天事件库。
- 查询某地点相关事件。
- 查询 `visibility == plaza_public` 或写入广场信息空间的事件。
- 对现有 ActionSystem 行动完成/失败事件做兼容迁移。
- `target_ids` 支持 NPC、地点、建筑、行动、资源、敌人等不同 ID，不把它当成单一自然语言宾语。
- 每种事件类型定义确定性 summary 模板和 payload schema；summary 不使用 LLM 生成，也不依赖通用主宾语自动拼句。

禁止事项：

- 不实现知识图谱。
- 不实现日记。
- 不接 LLM。
- 不实现完整地点继承逻辑，那是 T0403/T0404。
- 不实现“万能事件句子生成器”；必须按事件类型模板格式化 summary。

验收标准：

- 行动、点击测试或调试按钮能写入结构化事件。
- 至少工作完成、吃饭完成、睡觉完成、行动失败能写入带 `subject_npc_id`、`location_id`、`visibility` 和 `payload` 的事件。
- 能通过调试接口查询某 NPC 当天事件库。
- 能通过调试接口查询全局事件索引。
- 至少为 `location_entered`、`work_started`、`work_completed`、`work_failed`、`eat_completed` 定义 summary 模板和必需 payload 字段。
- `DATA_SCHEMA.md` 与事件结构一致。

---

## T0403 实现地点信息空间与进入快照

状态：Todo
优先级：P0
前置任务：T0203, T0402
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`

任务目标：

为可进入地点建立公共信息空间，并在 NPC 进入地点时生成地点状态快照。

实现范围：

- 可进入地点拥有信息空间：广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、仓库。
- 不可进入实体不建常规进入空间：主厅、围墙、城门。
- 地点信息空间记录 `people_present`、建筑 HP、等级、可用状态、工作位/床位占用、近期公开事件 ID 和公告。
- NPC 进入地点时写入 `location_entered` 事件。
- `location_entered.payload.location_snapshot` 包含进入时地点状态。
- 主厅、围墙、城门的 HP 和状态归入广场状态快照。

禁止事项：

- 不做 LLM 总结。
- 不做复杂传播算法。
- 不做建筑内部模型细化；这里只做数据空间。

验收标准：

- NPC 进入可进入地点后，地点 `people_present` 更新。
- NPC 离开地点后，地点 `people_present` 更新。
- `location_entered` 事件 payload 包含人数、工作位/床位占用、建筑 HP/等级和近期公开事件摘要。
- NPC 进入广场时，payload 包含主厅、围墙、城门状态。
- 建筑发生 `local_public` 事件后写入对应地点信息空间。

---

## T0404 实现广场公开信息与见闻继承

状态：Todo
优先级：P0
前置任务：T0402, T0403
涉及文档：`MEMORY_AND_INFO_SPACE.md`

任务目标：

实现广场作为室外事件归属地和公共信息中枢的机制，并让 NPC 进入广场时继承广场信息到见闻库。

公开事件包括：

- 室外发生的公开事件
- NPC 昏迷
- NPC 复苏
- NPC 逃离或试图逃离
- 玩家攻击 NPC
- 主厅、围墙、城门、仓库等关键目标受损
- 战斗开始/结束
- 敌我大致人数
- 公告牌内容

禁止事项：

- 不实现战斗本体。
- 不实现 LLM 解读。

验收标准：

- 调试触发公开事件后，广场信息空间能记录。
- NPC 进入广场后能继承这些见闻。
- 室外事件默认 `location_id == plaza`。
- 广场没有建筑 HP，但能提供主厅、围墙、城门状态快照。
- `MEMORY_AND_INFO_SPACE.md` 更新当前实现范围。

---

## T0405 实现 NPC 短期记忆容器

状态：Todo
优先级：P0
前置任务：T0402, T0403, T0404
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `AI_NPC_SYSTEM.md`

任务目标：

给每个 NPC 建立当天短期记忆容器，用于后续 LLM 输入。短期记忆由事件库和见闻库组成，不再混成一个文本列表。

实现范围：

- NPC 自身事件写入 `event_log`。
- NPC 进入地点、进入广场、读取公告或继承公开事件时写入 `witness_log`。
- 玩家对 NPC 的非对话交互写入目标 NPC 的 `event_log`，并按可见性写入地点/广场信息空间。
- 可查看 NPC 当前事件库、见闻库和摘要。

禁止事项：

- 不做睡前总结。
- 不接 LLM。
- 不做知识图谱更新。

验收标准：

- NPC 工作、吃饭、睡觉、被给予金钱、被攻击等事件进入事件库。
- NPC 进入地点后继承地点信息到见闻库。
- NPC 面板或调试工具能区分查看事件库与见闻库。
- 每天结束时暂不清空，后续任务处理。

---

# M5：昏迷、治疗与基础医疗闭环

目标：实现 NPC 不死亡机制。HP 清零后昏迷，医生可治疗，HP 到 30% 后复苏。

---

## T0501 实现 HP 扣除与昏迷状态

状态：Todo
优先级：P0
前置任务：T0303, T0402
涉及文档：`AI_NPC_SYSTEM.md`, `COMBAT_SYSTEM.md`, `DATA_SCHEMA.md`

任务目标：

实现 NPC HP 清零后昏迷，而不是死亡。

规则：

- HP 可被调试按钮或攻击按钮扣除。
- HP 降到 0 时进入昏迷。
- 昏迷 NPC 不能移动、工作、对话、战斗。
- 昏迷事件写入 NPC 事件库。
- 昏迷事件按 `plaza_public` 公开到广场。

禁止事项：

- 不实现敌人战斗。
- 不实现医生治疗。
- 不实现自然恢复。

验收标准：

- 使用调试扣血可让 NPC 昏迷。
- 昏迷状态在 NPC 面板显示。
- 昏迷 NPC 无法执行行动。
- 广场公开事件可见。

---

## T0502 实现昏迷自然恢复

状态：Todo
优先级：P0
前置任务：T0501, T0401
涉及文档：`COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`

任务目标：

让昏迷 NPC 随时间缓慢恢复 HP。

规则：

- 昏迷状态下每小时恢复少量 HP。
- HP 达到 Max HP 的 30% 后复苏。
- 复苏后重新允许行动。
- 复苏事件进入 NPC 事件库，并按规则公开到广场。

禁止事项：

- 不实现医生加速治疗。
- 不实现战斗中复苏判定。

验收标准：

- 昏迷 NPC 随时间恢复。
- 到 30% 后自动复苏。
- 复苏后状态正确刷新。
- 事件写入 NPC 事件库与广场公开信息。

---

## T0503 实现医生治疗昏迷 NPC

状态：Todo
优先级：P0
前置任务：T0502, T0305
涉及文档：`AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`

任务目标：

让医生能够更快治疗昏迷 NPC。

规则：

- 医生职业 NPC 在小诊所或目标身边可执行治疗行动。
- 治疗消耗金钱。
- 医术熟练度影响恢复速度。
- 治疗事件写入目标 NPC 和医生的结构化事件。
- 被治疗和复苏事件公开到广场。

禁止事项：

- 不实现复杂药品。
- 不实现医疗床位复杂管理。
- 不接 LLM。

验收标准：

- 医生能对昏迷 NPC 执行治疗。
- 治疗比自然恢复更快。
- 资源不足时治疗失败。
- 事件记录完整。

---

# M6：后端 LLM 接口骨架与 Mock AI

目标：先建立 Godot 与后端的 AI 通信闭环，但默认使用 Mock，不依赖真实模型，不消耗额度。

---

## T0601 创建后端 Schema

状态：Todo
优先级：P0
前置任务：T0002
涉及文档：`TECH_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `PROMPTS.md`

任务目标：

在后端创建请求/响应数据结构。

需要覆盖：

- NPC 对话请求/响应
- 每日计划请求/响应
- 战斗判定请求/响应
- 睡前总结请求/响应
- 错误响应

禁止事项：

- 不调用真实模型。
- 不实现复杂业务逻辑。

验收标准：

- `backend/schemas/` 中有清晰的数据模型。
- 后端启动无报错。
- 文档与字段一致。

---

## T0602 实现 Mock Model Adapter

状态：Todo
优先级：P0
前置任务：T0601
涉及文档：`TECH_ARCHITECTURE.md`, `API_BUDGET.md`

任务目标：

让后端即使没有真实 LLM，也能返回稳定 JSON。

实现范围：

- `model_adapter.py` 支持 `mock` provider
- Mock 返回合法 JSON
- 支持按调用类型返回不同内容
- 记录调用用途和伪 token 信息

禁止事项：

- 不接真实 DeepSeek / MiniMax。
- 不写真实 API Key。

验收标准：

- `.env` 不存在时默认 mock。
- 调用后端接口返回合法 JSON。
- 失败时返回明确错误，不让 Godot 卡死。

---

## T0603 实现 `/npc/dialogue` Mock 接口

状态：Todo
优先级：P0
前置任务：T0601, T0602
涉及文档：`TECH_ARCHITECTURE.md`, `PROMPTS.md`, `AI_NPC_SYSTEM.md`

任务目标：

实现最小 NPC 对话接口。

输入：

- npc_id
- player_text
- is_recruitment_request
- npc_state
- short_memory
- knowledge_context
- location_context

输出：

- dialogue
- recruitment_result：none / accept / reject
- npc_intent
- memory_to_store

禁止事项：

- 不接真实模型。
- 不实现完整 Prompt。
- 不改 Godot UI。

验收标准：

- 可用 curl 或 HTTP 工具调用。
- 请求“提出应征”时 Mock 可返回 accept 或 reject。
- JSON 结构稳定。

---

## T0604 实现 Godot LLMBridge

状态：Todo
优先级：P0
前置任务：T0603, T0101
涉及文档：`TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`

任务目标：

让 Godot 能请求后端 `/health` 和 `/npc/dialogue`。

实现范围：

- 新增 `LLMBridge.gd`
- 支持后端地址配置
- 支持 health check
- 支持发送 NPC 对话请求
- 请求失败时返回降级结果
- 发起会影响当前事态的 LLM 请求前，调用 `TimeSystem.request_time_slowdown(...)`
- 请求成功、失败、超时或降级后，必须调用 `TimeSystem.release_time_slowdown(...)`

禁止事项：

- 不实现对话 UI。
- 不实现真实 LLM。
- 不实现征召。

验收标准：

- Godot 能显示后端连接状态。
- 后端关闭时不会崩溃。
- 请求 `/npc/dialogue` 可收到 Mock JSON。
- LLM 请求等待期间有效逻辑时间倍率降为 `1/60`，请求结束后恢复玩家设定倍率。
- 后端失败或超时时不会遗留慢速请求。

---

# M7：玩家对话、征召与非对话交互

目标：玩家能够点击 NPC 对话，通过“提出应征”让 NPC 接受或拒绝；玩家可给钱、给装备、攻击，且这些行为进入结构化事件与 NPC 事件库。

---

## T0701 实现对话 UI

状态：Todo
优先级：P0
前置任务：T0303, T0604
涉及文档：`UI_UX.md`, `AI_NPC_SYSTEM.md`

任务目标：

点击 NPC 后可以打开对话窗口并输入文本。

功能：

- 显示 NPC 名字
- 显示历史对话
- 玩家输入文本
- 发送到后端
- 显示 NPC 回复
- 结束对话按钮

禁止事项：

- 不实现语音。
- 不实现主动找玩家。
- 不实现征召状态切换。

验收标准：

- 点击 NPC 可打开对话 UI。
- 输入文本后能看到 Mock 回复。
- 后端关闭时显示降级回复。
- 对话事件写入 NPC 事件库；对话全文存入事件 `payload`。

---

## T0702 实现“提出应征”按钮与征召结果

状态：Todo
优先级：P0
前置任务：T0701
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`

任务目标：

玩家在对话中点击“提出应征”，NPC 通过后端返回接受或拒绝。

规则：

- 点击“提出应征”后，下次对话请求 `is_recruitment_request=true`
- 后端返回 `accept` 后 NPC `recruited=true`
- 返回 `reject` 后 NPC 保持自由行动
- 征召结果写入结构化事件和 NPC 事件库

禁止事项：

- 不实现复杂条件接受。
- 不实现真实 LLM 判断。
- 不实现战斗指派。

验收标准：

- NPC 接受后面板显示已入伍。
- 已入伍 NPC 可出现指派按钮占位。
- 拒绝后不改变入伍状态。
- 征召事件被记录。

---

## T0703 实现入伍 NPC 指派入口

状态：Todo
优先级：P0
前置任务：T0702, T0305
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`

任务目标：

让已入伍 NPC 能被玩家指派基础行动。

可指派：

- 工作
- 吃饭
- 睡觉
- 前往建筑
- 训练占位
- 治疗/休息占位

禁止事项：

- 未入伍 NPC 不能被直接指派。
- 不实现完整训练系统。
- 不实现战斗策略。

验收标准：

- 副官开局可被指派。
- 被征召 NPC 可被指派。
- 未征召 NPC 指派按钮不可用或提示不能指派。
- 指派事件写入目标 NPC 事件库。

---

## T0704 实现玩家非对话交互记忆

状态：Todo
优先级：P0
前置任务：T0405, T0702
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `AI_NPC_SYSTEM.md`, `UI_UX.md`

任务目标：

玩家除了对话以外的行为也要进入结构化事件系统，并写入目标 NPC 事件库。

交互包括：

- 赠予金钱
- 给予 / 更换装备
- 指派任务
- 攻击 NPC 造成伤害
- 要求休息或治疗

禁止事项：

- 不实现完整装备系统也可先用占位装备。
- 不实现复杂威胁 UI。

验收标准：

- 给钱事件写入目标 NPC 事件库，并按地点可见性进入地点信息空间。
- 攻击事件写入目标 NPC 事件库与广场公开信息。
- 指派事件写入目标 NPC 事件库。
- 后续对话请求会带上这些记忆摘要。

---

## T0705 实现 NPC 主动找玩家交涉

状态：Todo
优先级：P1
前置任务：T0701, T0405
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`

任务目标：

NPC 可主动请求与玩家对话。

实现范围：

- NPC 进入“主动找玩家交涉”状态
- 头顶显示问号气泡
- 玩家点击后打开对话
- 对话结束后 NPC 重新评估或恢复原计划

禁止事项：

- 不接真实 LLM 主动意图也可以先用规则触发。
- 不实现复杂情绪系统。

验收标准：

- 可通过调试按钮让 NPC 主动找玩家。
- 问号气泡显示正确。
- 点击后进入对话。
- 对话结束后气泡消失。

---

# M8：职业工作、生产与经营闭环

目标：让建筑和 NPC 职业熟练度产生实际经营价值，形成粮食、餐食、酒、装备、马匹、治疗、工程器械等基础产出。

---

## T0801 实现职业工作产出框架

状态：Todo
优先级：P0
前置任务：T0305, T0202, T0203
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`

任务目标：

建立统一工作产出公式。

需要考虑：

- 工作类型
- NPC 对应熟练度
- 力量或智力
- 建筑等级
- 工作时长
- TimeSystem 有效逻辑时间倍率
- 输入资源
- 输出资源
- 疲劳与饱食消耗

禁止事项：

- 不做复杂平衡。
- 不做所有职业特殊逻辑。

验收标准：

- 同一工作由高熟练 NPC 执行，产出更高或耗时更短。
- 资源不足时工作失败。
- 工作完成写入结构化事件和 NPC 事件库。
- 资源产出/消耗、饱食和疲劳变化使用 `TimeSystem` 的逻辑时间倍率或 `logical_time_tick`，不依赖真实帧率或 NPC 移动速度。

---

## T0802 实现食堂：粮食加工餐食

状态：Todo
优先级：P0
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`

验收标准：

- 食堂工作消耗粮食，产出餐食。
- 厨艺影响效率。
- NPC 吃餐食恢复更多饱食度。
- 工作和吃饭事件进入结构化事件与 NPC 事件库。

---

## T0803 实现菜园：产出粮食

状态：Todo
优先级：P0
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`

验收标准：

- 菜园工作产出粮食。
- 耕种影响产出。
- 建筑等级影响产出。
- 园丁有明显优势。

---

## T0804 实现铁匠铺：制造金属武器和盔甲

状态：Todo
优先级：P0
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`

验收标准：

- 消耗铁制造基础武器或盔甲。
- 打铁影响制作效率。
- 产物进入库存。
- 不需要完整装备外观，但数据可用。

---

## T0805 实现工械坊：制造弓弩与防御器械

状态：Todo
优先级：P1
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`

验收标准：

- 消耗木材制造弓、弩或器械。
- 工程影响制作效率。
- 工程器械可先作为库存项，不必立即部署。

---

## T0806 实现马厩：马匹喂养和恢复

状态：Todo
优先级：P1
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`

验收标准：

- 马厩消耗粮食维护马匹。
- 养马影响马匹恢复。
- 马匹可作为装备坐骑使用。
- 再生产可先用低概率或暂不开放。

---

## T0807 实现酒窖：酿酒与出售

状态：Todo
优先级：P1
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`

验收标准：

- 酒窖消耗粮食产出酒。
- 酿酒影响效率。
- 酒可出售换金钱。
- 暂不实现饮酒副作用。

---

## T0808 实现小诊所：治疗行动完善

状态：Todo
优先级：P0
前置任务：T0503, T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `AI_NPC_SYSTEM.md`

验收标准：

- 医术影响治疗速度。
- 诊所等级或床位影响治疗效率。
- 治疗消耗金钱。
- 医生在治疗中获得医术经验。

---

# M9：装备、熟练度、训练与升级

目标：让 NPC 能装备武器/盔甲/坐骑，通过工作、训练和战斗提升熟练度，并由 AI 或规则决定力量/智力成长。

---

## T0901 实现库存与装备系统

状态：Todo
优先级：P0
前置任务：T0804
涉及文档：`COMBAT_SYSTEM.md`, `DATA_SCHEMA.md`, `UI_UX.md`

任务目标：

支持 NPC 装备武器、盔甲和坐骑。

装备部位：

- 主武器
- 头盔
- 胸甲
- 腕甲
- 腿甲
- 坐骑

禁止事项：

- 不做复杂外观换装也可先用数据表现。
- 不做装备耐久。

验收标准：

- 玩家可给已入伍 NPC 装备武器。
- 装备后 NPC 面板显示更新。
- 装备事件写入目标 NPC 事件库，并按地点可见性进入地点信息空间。
- 兵种可根据装备组合判定。

---

## T0902 实现兵种判定

状态：Todo
优先级：P0
前置任务：T0901
涉及文档：`COMBAT_SYSTEM.md`

验收标准：

- 剑盾 → 近战步兵
- 长杆武器 → 长杆步兵
- 弓 → 弓箭兵
- 弩 → 弩兵
- 近战武器 + 马 → 近战骑兵
- 远程武器 + 马 → 骑射单位
- 无武器 → 非战斗人员 / 避战单位

---

## T0903 实现训练场与武器熟练度提升

状态：Todo
优先级：P0
前置任务：T0703, T0901
涉及文档：`AI_NPC_SYSTEM.md`, `COMBAT_SYSTEM.md`

验收标准：

- 入伍 NPC 可被指派去训练场训练。
- 可选择剑盾、长杆、弓、弩、骑术。
- 训练消耗疲劳和饱食。
- 训练提升对应熟练度。
- 教练熟练度可影响训练速度。

---

## T0904 实现职业熟练度与经验升级

状态：Todo
优先级：P1
前置任务：T0801, T0903
涉及文档：`AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`

验收标准：

- 工作提升职业熟练度。
- 战斗或训练提升武器熟练度。
- 熟练度提升同步增加经验。
- 经验达标获得技能点。
- 技能点可由规则或 Mock AI 分配到力量/智力。

---

# M10：每日计划、行动中断与睡前总结

目标：让 NPC 具备“看起来像在生活”的自动计划系统，并让记忆在每天结束时压缩为长期信息。

---

## T1001 实现规则版每日计划

状态：Todo
优先级：P0
前置任务：T0401, T0305, T0801
涉及文档：`AI_NPC_SYSTEM.md`

任务目标：

先不用 LLM，使用规则为 NPC 生成简单每日计划。

规则：

- 一天 24 阶段
- 至少 6 阶段工作
- 饱食低则吃饭
- 疲劳高则睡觉
- 职业倾向影响工作选择
- 副官可优先训练或巡逻

禁止事项：

- 不调用 LLM。
- 不实现复杂社交计划。

验收标准：

- 每个 NPC 每天有计划。
- NPC 按计划执行行动。
- 计划执行结果写入记忆。
- 玩家指派可覆盖入伍 NPC 的计划。
- 阶段开始、计划执行和计划重估以 `TimeSystem` 的逻辑时间打点为准。

---

## T1002 实现行动异常与计划重评估

状态：Todo
优先级：P0
前置任务：T1001
涉及文档：`AI_NPC_SYSTEM.md`

触发异常：

- 目标建筑不可用
- 工作位占用
- 资源不足
- 被玩家对话打断
- 被其他 NPC 对话打断
- HP 过低
- 饱食或疲劳过低
- 战斗警报

验收标准：

- 轻微异常可用规则处理。
- 重大异常进入重评估。
- 重评估后 NPC 不会卡死。
- 异常事件写入记忆。
- 需要 LLM / Mock 重评估时，通过 LLMBridge 申请 TimeSystem 慢速请求，返回或降级后释放。

---

## T1003 实现 LLM / Mock 版每日计划接口

状态：Todo
优先级：P1
前置任务：T0602, T1001
涉及文档：`PROMPTS.md`, `AI_NPC_SYSTEM.md`, `API_BUDGET.md`

验收标准：

- 后端提供 `/npc/plan_day`。
- Mock 能返回 24 阶段计划。
- Godot 可选择使用规则计划或 Mock 计划。
- 输出 JSON 被校验，不合法则回退规则计划。
- 影响当前场景即时行动的计划请求必须申请 TimeSystem 慢速；后台批处理每日计划可不申请慢速，但必须记录调试状态。

---

## T1004 实现睡前总结与短期记忆清空

状态：Todo
优先级：P1
前置任务：T0405, T0602
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`

验收标准：

- 每天结束时为 NPC 生成第一人称日记。
- 更新知识图谱占位。
- 清空当天事件库和见闻库缓存。
- 日记可在 NPC 面板查看。
- Mock 后端不可用时使用模板总结。

---

# M11：敌人、警铃与基础战斗

目标：敌人能按波次进攻，玩家可摇铃集结入伍 NPC，战斗按照装备与策略自动执行。

---

## T1101 实现敌人配置与敌人生成

状态：Todo
优先级：P0
前置任务：T0201
涉及文档：`COMBAT_SYSTEM.md`, `DATA_SCHEMA.md`

任务目标：

实现 `enemy_waves.json` 并按波次生成敌人。

验收标准：

- 至少配置 5 波敌人。
- 敌人有 HP、武器类型、攻击力、目标偏好。
- 可通过调试按钮生成第一波敌人。
- 敌人生成位置在正门外。

---

## T1102 实现敌人目标优先级

状态：Todo
优先级：P0
前置任务：T1101, T0203
涉及文档：`COMBAT_SYSTEM.md`

规则：

1. 攻击城门 / 围墙
2. 攻击仓库
3. 攻击主厅
4. 如果一定范围内有我方单位，优先攻击我方单位

验收标准：

- 敌人会向目标移动。
- 敌人能攻击建筑。
- 建筑 HP 会下降。
- 主厅被攻击可触发失败条件占位。

---

## T1103 实现警铃与集结

状态：Todo
优先级：P0
前置任务：T0703, T0902
涉及文档：`COMBAT_SYSTEM.md`, `UI_UX.md`

任务目标：

玩家点击警铃后，入伍且有武器的 NPC 尝试集结防线。

规则：

- 近战在前
- 远程在后
- 面向敌人方向
- 未入伍或无武器 NPC 不集结

验收标准：

- HUD 警铃按钮可触发集结。
- 已入伍有武器 NPC 移动到防守位置。
- 未入伍 NPC 不响应。
- 集结事件写入结构化事件。

---

## T1104 实现基础攻击与伤害

状态：Todo
优先级：P0
前置任务：T0902, T1102, T1103
涉及文档：`COMBAT_SYSTEM.md`

任务目标：

实现最小自动战斗。

需要支持：

- 我方攻击敌人
- 敌人攻击我方或建筑
- 攻击间隔
- 攻击力
- HP 扣除
- TimeSystem 有效逻辑时间倍率
- HP 清零后的敌人消失或倒下
- NPC HP 清零进入昏迷

禁止事项：

- 不做复杂动画。
- 不做命中率复杂计算。
- 不做士气系统。

验收标准：

- 我方和敌人能互相造成伤害。
- NPC HP 清零后昏迷。
- 建筑 HP 会被敌人打掉。
- 敌人被击败后从战斗中移除。
- 攻击间隔、持续伤害、恢复等时间相关数值使用 `TimeSystem.get_numeric_delta_multiplier()` 或 `logical_time_tick` 结算。

---

## T1105 实现战斗策略

状态：Todo
优先级：P0
前置任务：T1104
涉及文档：`COMBAT_SYSTEM.md`, `UI_UX.md`

策略：

剑盾/长杆：

- 主动进攻
- 避战

弓/弩：

- 最大化输出
- 保持距离射击
- 避战

近战骑兵：

- 主动进攻
- 拉开距离冲击
- 避战

骑马远程：

- 最大化输出
- 保持距离射击
- 避战

验收标准：

- 玩家可为入伍 NPC 设置策略。
- 不同策略行为可明显区分。
- 策略变化写入记忆。

---

## T1106 实现战斗开始/结束流程

状态：Todo
优先级：P0
前置任务：T1101, T1104
涉及文档：`COMBAT_SYSTEM.md`, `CURRENT_STATE.md`

验收标准：

- 敌人波次开始时进入战斗状态。
- 敌人全灭或撤退后退出战斗状态。
- 战斗开始/结束进入广场公开信息。
- 战斗后 NPC 回到工作状态并重新评估计划。

---

# M12：战斗心理判定、逃离与公开见闻

目标：让战斗不只是数值碰撞，而是能触发 AI 判定、逃离、斗志激昂、昏迷和广场舆论。

---

## T1201 实现战斗前 Mock 心理判定

状态：Todo
优先级：P0
前置任务：T0602, T1106
涉及文档：`COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`

任务目标：

战斗触发时，全员进行一次心理判定。

入伍 NPC 结果：

- 参战
- 逃离驿站
- 斗志激昂

非入伍 NPC 结果：

- 避战
- 逃离驿站

禁止事项：

- 可先用 Mock，不接真实模型。
- 不实现复杂情绪数值。

验收标准：

- 战斗开始时调用后端 Mock 判定。
- 结果影响 NPC 行为。
- 判定结果写入 NPC 事件库。
- 后端失败时使用规则判定。
- 判定等待期间申请 TimeSystem 慢速，请求完成、失败或规则降级后释放。

---

## T1202 实现 HP 低于 30% 心理判定

状态：Todo
优先级：P0
前置任务：T1104, T1201
涉及文档：`COMBAT_SYSTEM.md`

验收标准：

- NPC HP 首次低于 30% 时触发判定。
- 可能继续参战、逃离、斗志激昂。
- 每个 NPC 每波最多触发一次。
- 判定事件进入 NPC 事件库与广场公开信息。
- 判定等待期间申请 TimeSystem 慢速，请求完成、失败或规则降级后释放。

---

## T1203 实现逃离驿站行为

状态：Todo
优先级：P0
前置任务：T0304, T1201
涉及文档：`AI_NPC_SYSTEM.md`, `COMBAT_SYSTEM.md`

规则：

- NPC 前往后门或小门。
- 完全离开地图后状态变为 escaped。
- 逃离事件公开到广场。
- 逃离 NPC 不再参与工作和战斗。

验收标准：

- 可通过判定或调试触发逃离。
- NPC 会走向出口。
- 离开后从可用 NPC 列表中移除或标记。
- 事件记录完整。

---

## T1204 实现逃离挽留五轮对话

状态：Todo
优先级：P1
前置任务：T0701, T1203
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`, `PROMPTS.md`

规则：

- NPC 完全离开前，玩家可进行最多 5 轮对话。
- 玩家可承诺补偿、威胁、给钱、攻击。
- 对话后 NPC 可留下、退出入伍状态、继续逃离、被攻击昏迷。

验收标准：

- 逃离 NPC 可被点击进入挽留对话。
- 轮数限制生效。
- 结果改变 NPC 状态。
- 事件进入 NPC 事件库和广场公开信息。

---

## T1205 完善战场公开信息

状态：Todo
优先级：P0
前置任务：T0404, T1106, T1202
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `COMBAT_SYSTEM.md`

公开内容：

- 敌我大致人数
- NPC 被打到 30% HP 以下
- NPC 击倒或击杀敌人
- NPC 昏迷
- NPC 被治疗
- NPC 复苏
- NPC 逃离
- 建筑受损

验收标准：

- 战斗事件自动进入广场信息空间。
- NPC 后续对话请求包含相关公开见闻摘要。
- NPC 面板可查看最近公开见闻。

---

# M13：波次推进、胜负结算与 Demo 闭环

目标：形成完整可玩的 5 波防守 Demo，有胜利、失败和 NPC 结局总结。

---

## T1301 实现波次倒计时与自动来袭

状态：Todo
优先级：P0
前置任务：T0401, T1101
涉及文档：`COMBAT_SYSTEM.md`, `UI_UX.md`

验收标准：

- HUD 显示下一波倒计时。
- 第 3 天或配置时间触发小股敌人。
- 之后按配置触发更强敌人。
- 可手动调试跳到下一波。
- 波次倒计时与触发时间使用 TimeSystem 逻辑时间，不使用真实时间。

---

## T1302 实现主厅失败条件

状态：Todo
优先级：P0
前置任务：T1102, T1104
涉及文档：`COMBAT_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`

验收标准：

- 主厅 HP 清零后进入失败结算。
- 失败原因记录为主厅被摧毁。
- 游戏停止正常推进。
- 显示失败界面占位。

---

## T1303 实现无可战斗人员失败条件

状态：Todo
优先级：P1
前置任务：T0501, T1203
涉及文档：`COMBAT_SYSTEM.md`

验收标准：

- 所有可战斗人员离开或昏迷，且下一波无法抵抗时触发失败。
- 失败原因记录清楚。
- 不误判短暂未集结状态。

---

## T1304 实现 5 波胜利条件

状态：Todo
优先级：P0
前置任务：T1301, T1106
涉及文档：`COMBAT_SYSTEM.md`, `CURRENT_STATE.md`

验收标准：

- 成功守住第 5 波后进入胜利结算。
- 游戏停止继续刷波。
- 显示胜利界面占位。
- 记录剩余资源、建筑状态、NPC 状态。

---

## T1305 实现 NPC 结局总结页面

状态：Todo
优先级：P0
前置任务：T1302, T1304, T1004
涉及文档：`UI_UX.md`, `MEMORY_AND_INFO_SPACE.md`, `AI_NPC_SYSTEM.md`

显示内容：

- 每名 NPC 最终状态：可行动 / 昏迷 / 逃离
- 是否入伍
- 最后位置
- 对玩家最终看法，占位或 Mock
- 后续命运，占位或 Mock

验收标准：

- 胜利和失败都显示 NPC 总结。
- 不出现“阵亡”表述，统一使用昏迷/逃离/最终状态。
- 可基于日记和记忆生成简短总结。

---

# M14：真实 LLM 接入与 Prompt 打磨

目标：在 Mock 闭环稳定后，接入真实模型，逐步替换 Mock 输出，并控制成本。

---

## T1401 接入真实 Model Adapter

状态：Todo
优先级：P1
前置任务：T0602, T0701
涉及文档：`TECH_ARCHITECTURE.md`, `API_BUDGET.md`, `PROMPTS.md`

任务目标：

支持至少一个真实模型供应商。

候选：

- DeepSeek
- MiniMax
- 通义千问
- 智谱

规则：

- API Key 只从环境变量读取。
- 默认仍可切回 mock。
- 请求失败自动降级。
- 所有调用记录 token 和用途。
- Godot 侧所有会影响当前事态的真实模型请求必须与 TimeSystem 慢速请求成对注册/释放。

验收标准：

- 本地 `.env` 配置后可调用真实模型。
- 不提交真实 Key。
- 无 Key 时仍可用 Mock。
- 成本统计可见。
- 请求失败、超时或降级时不会让游戏长期保持慢速逻辑时间。

---

## T1402 打磨 NPC 对话 Prompt

状态：Todo
优先级：P1
前置任务：T1401, T0702
涉及文档：`PROMPTS.md`, `AI_NPC_SYSTEM.md`

验收标准：

- NPC 回复符合职业、人设、记忆。
- “提出应征”时能接受或拒绝。
- 输出稳定 JSON。
- 不越权决定程序数值。
- 失败时可降级。

---

## T1403 打磨每日计划 Prompt

状态：Todo
优先级：P1
前置任务：T1003, T1401
涉及文档：`PROMPTS.md`, `AI_NPC_SYSTEM.md`

验收标准：

- 能输出 24 阶段计划。
- 至少 6 阶段工作。
- 计划使用行动白名单。
- 输出不合法时回退规则计划。

---

## T1404 打磨战斗判定 Prompt

状态：Todo
优先级：P1
前置任务：T1201, T1401
涉及文档：`PROMPTS.md`, `COMBAT_SYSTEM.md`

验收标准：

- 战斗前和低血量判定可用真实模型。
- 输出只在允许结果中选择。
- 能引用 NPC 记忆和公开见闻。
- 成本可控。

---

## T1405 打磨睡前总结 Prompt

状态：Todo
优先级：P1
前置任务：T1004, T1401
涉及文档：`PROMPTS.md`, `MEMORY_AND_INFO_SPACE.md`

验收标准：

- 每天生成知识图谱更新和第一人称日记。
- 日记符合 NPC 语气。
- 能压缩当天关键事件。
- 不产生过长上下文。

---

## T1406 实现 API 额度面板 / 调试信息

状态：Todo
优先级：P1
前置任务：T1401
涉及文档：`API_BUDGET.md`, `UI_UX.md`

验收标准：

- 后端记录调用次数、类型、token、费用估算。
- Godot 或后端调试页面可查看累计消耗。
- 超预算时可切换 Mock 或模板降级。
- Godot 调试信息可查看当前等待中的 LLM 请求数量、有效逻辑倍率和最近一次 TimeSystem 慢速原因。

---

# M15：内容补全与体验打磨

目标：把可运行系统打磨成可展示、可直播、可参赛的 Demo。

---

## T1501 补全 8 名 NPC 的具体姓名与个性台词

状态：Todo
优先级：P1
前置任务：T1402
涉及文档：`AI_NPC_SYSTEM.md`, `game_design.md`

验收标准：

- 8 名 NPC 有明确姓名。
- 每人有职业语气、欲望、恐惧、底线。
- 对话中能体现职业身份。
- 不写过长背景，保持 Demo 可控。

---

## T1502 补全建筑低模表现

状态：Todo
优先级：P1
前置任务：T0103, T0203
涉及文档：`ECONOMY_AND_BUILDINGS.md`

验收标准：

- 建筑在视觉上可区分。
- 围墙、主厅、仓库、食堂、宿舍识别度足够。
- 不追求精细美术。
- 保持低模风格一致。

---

## T1503 补全战斗反馈

状态：Todo
优先级：P1
前置任务：T1104, T1205
涉及文档：`COMBAT_SYSTEM.md`, `UI_UX.md`

验收标准：

- 攻击有基础动画或反馈。
- 受伤、昏迷、复苏有明显表现。
- 建筑受损有提示。
- 战斗公开信息能被玩家看懂。

---

## T1504 平衡 5 波敌人和资源压力

状态：Todo
优先级：P1
前置任务：T1304
涉及文档：`COMBAT_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`

验收标准：

- 普通玩家有机会守住 5 波。
- 资源不至于完全无意义。
- 征召和训练能明显改善结果。
- 不出现必败或必胜。

---

## T1505 制作新手引导

状态：Todo
优先级：P1
前置任务：T1304
涉及文档：`UI_UX.md`, `AI_NPC_SYSTEM.md`

验收标准：

- 副官引导玩家查看资源、对话、征召、装备、摇铃。
- 不超过 3 分钟。
- 可跳过。
- 不依赖真实 LLM 也能运行。

---

## T1506 增加黑色幽默事件与公告牌

状态：Todo
优先级：P2
前置任务：T0404, T0701
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`

验收标准：

- 玩家可在公告牌写公告。
- 公告进入广场信息空间。
- NPC 后续对话可引用公告内容。
- 至少有 3 个可触发的黑色幽默反馈。

---

## T1507 商人交易系统

状态：Todo
优先级：P2
前置任务：T0202, T0401
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`

验收标准：

- 每天特定时段商人到后门。
- 玩家可买粮食、木材、石料、铁。
- 玩家可卖酒。
- 交易事件写入结构化事件。

---

## T1508 工程器械部署

状态：Todo
优先级：P2
前置任务：T0805, T1104
涉及文档：`COMBAT_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`

验收标准：

- 弩床或拒马可部署在围墙。
- 自动攻击或阻挡敌人。
- 工程技能影响制造效率。
- 部署事件进入结构化事件与相关 NPC 事件库。

---

## T1509 可进入建筑内部空间细化

状态：Todo
优先级：P2
前置任务：T0403, T1502
涉及文档：`GODOT_ARCHITECTURE.md`, `ECONOMY_AND_BUILDINGS.md`, `MEMORY_AND_INFO_SPACE.md`

任务目标：

在数据上的地点信息空间已经稳定后，为可进入建筑逐步增加室内空间和模型表现。

实现范围：

- 宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、仓库可以拥有室内空间或更细的工位/床位模型。
- 室内模型表现必须服从已经实现的地点信息空间数据；不要反过来把信息系统写死在模型节点里。
- 主厅、围墙、城门仍不可进入，状态继续归入广场信息空间。

验收标准：

- 至少 1 个可进入建筑有可辨认室内空间占位。
- NPC 进入该建筑时仍使用 T0403 的地点信息空间和进入事件。
- 室内工位/床位表现与数据占用状态一致。
- 不破坏现有低模驿站和摄像机操作。

---

# M16：语音输入、情绪识别与可选 AI 增强

目标：作为参赛加分项加入语音和情绪输入，但不影响核心 Demo 可运行性。

---

## T1601 玩家语音输入

状态：Todo
优先级：P2
前置任务：T0701
涉及文档：`UI_UX.md`, `PROMPTS.md`

验收标准：

- 玩家可用语音输入文本。
- 语音识别失败时可手动输入。
- 不影响文本对话主流程。

---

## T1602 玩家语音情绪识别

状态：Todo
优先级：P2
前置任务：T1601, T1402
涉及文档：`PROMPTS.md`, `AI_NPC_SYSTEM.md`

验收标准：

- 可识别平静、愤怒、低沉、急促、嘲讽等基础语气。
- 情绪结果进入对话请求。
- NPC 回复可参考语气。
- 情绪识别失败时忽略，不阻塞对话。

---

# M17：参赛打包与展示

目标：完成可提交、可录屏、可演示的 Demo 包。

---

## T1701 Demo 稳定性测试

状态：Todo
优先级：P0
前置任务：T1305
涉及文档：`CURRENT_STATE.md`, `DEV_LOG.md`

验收标准：

- 从新游戏开始到守住或失败能完整跑通。
- 连续运行 30 分钟无严重报错。
- 后端断开时仍可降级运行基础流程。
- 关键 UI 不阻塞操作。

---

## T1702 整理参赛演示流程

状态：Todo
优先级：P1
前置任务：T1701
涉及文档：`PROJECT_BRIEF.md`, `game_design.md`

验收标准：

- 有 5 分钟演示脚本。
- 有 30 分钟可体验路线。
- 能展示 AI 对话、征召、战斗、昏迷、见闻、结算。
- 明确哪些功能是真实实现，哪些是 Mock 或占位。

---

## T1703 打包导出

状态：Todo
优先级：P1
前置任务：T1701
涉及文档：`CURRENT_STATE.md`

验收标准：

- Godot 可导出目标平台版本。
- 后端运行说明清楚。
- API Key 配置说明清楚。
- 不包含真实 Key。
- 压缩包或提交包结构清晰。

---

## T1704 项目说明与提交材料

状态：Todo
优先级：P1
前置任务：T1702
涉及文档：`PROJECT_BRIEF.md`

验收标准：

- 有项目 README。
- 有玩法介绍。
- 有 AI 技术说明。
- 有操作说明。
- 有已知问题说明。
- 有演示视频或截图说明。

---
