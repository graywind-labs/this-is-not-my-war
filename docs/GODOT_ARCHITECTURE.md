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
│  ├─ UnconsciousSystem
│  └─ DialogSystem
├─ UI
│  ├─ HUD
│  ├─ NPCPanel
│  ├─ BuildingPanel
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
| MCPGameBridge | `res://addons/godot_mcp/game_bridge/mcp_game_bridge.gd` | Godot MCP 运行桥接 |
| EventBus | `res://scripts/core/EventBus.gd` | 已声明基础事件信号 |
| GameState | `res://scripts/core/GameState.gd` | 已保存天数、小时、战斗状态 |
| ConfigLoader | `res://scripts/core/ConfigLoader.gd` | 已支持 JSON 读取和错误提示 |

T0102 已将 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 绑定到 Main 场景的 `Systems` 节点下。T0202 已实现 `ResourceSystem.gd` 的基础资源读写和 HUD 同步；T0205 已实现 `BuildingSystem.gd` 的配置读取、低模建筑绑定、运行时点击区、`building_clicked` 事件，以及最小建筑修复/升级逻辑；T0304 已实现 `NPCSystem.gd` 从 `data/npc_profiles.json` 生成 8 个 NPC 占位实体、发出 `npc_clicked`、读取/更新 NPC 基础状态、调试移动到建筑入口，并在到达后发出 `npc_state_changed`。T0305 已实现 `ActionSystem.gd` 的工作 / 吃饭 / 睡觉调试行动闭环，并用 `MemorySystem.gd` 提供最小 EventLog 占位。其余系统当前仍为结构占位，不实现战斗或对话逻辑。

`UnconsciousSystem` 仍保留为后续昏迷/治疗/复苏模块规划，T0102 未创建该节点或脚本。

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
│     │  ├─ NoticeBoard
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
│  └─ DialogSystem
├─ UI
│  ├─ HUD
│  ├─ NPCPanel
│  ├─ BuildingPanel
│  └─ DialogPanel
├─ CameraRig
│  └─ Camera3D
└─ SunLight
```

T0103 已在 `Main.tscn` 直接放置低模驿站 Blockout：主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌均使用简单几何体和 `Label3D` 调试标签表示。2026-05-19 已扩大地面、围墙和相机视野，并拉开建筑间距，避免建筑过小过密；围墙四角已闭合，公告牌已缩小并移动到主厅正面。该阶段只提供空间占位和可辨认视觉结构，不实现建筑数据、点击、生产、导航或战斗。

T0104 已在 `Main/UI/HUD` 下补齐基础 HUD：标题、天数、小时/阶段、五类资源、加速按钮占位、警铃按钮占位和后端状态占位。`Main/UI/HUD` 绑定 `res://scripts/ui/HUD.gd`，负责显示和从 `GameState` 读取当前时间；T0202 后会监听 `EventBus.resource_changed` 并从 `Main/Systems/ResourceSystem` 读取真实基础资源数值。不实现警铃、加速或后端连接。T0205 已将 `Main/UI/BuildingPanel` 绑定 `res://scripts/ui/BuildingPanel.gd`：监听 `EventBus.building_clicked`，从 `BuildingSystem` 读取被点击建筑的名称、等级、HP、工作位和地点信息占位，显示修复/升级消耗摘要，并通过按钮触发 `BuildingSystem` 的修复/升级接口。

T0105 已将 `res://scripts/camera/CameraRig.gd` 绑定到 `Main/CameraRig`：玩家可用 WASD 平移、鼠标中键拖拽平移、滚轮缩放；脚本只移动 `CameraRig` 的 X/Z 位置和 `Camera3D` 的本地距离，保留高机位俯视角，并通过导出参数限制移动边界和缩放距离。该阶段不实现角色控制或自由第一人称视角。

T0202 已在 `res://scripts/systems/ResourceSystem.gd` 中实现基础资源系统：启动时读取 `data/resource_defs.json` 初始化第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁，提供 `get_resource`、`add_resource`、`can_afford`、`spend_resources` 与临时调试接口。所有资源变化通过 `EventBus.resource_changed` 通知 UI；资源不足时 `spend_resources` 返回 `false`，不扣除也不产生负数。HUD 当前只显示基础五类资源，派生资源作为内部库存占位。

T0205 已在 `res://scripts/systems/BuildingSystem.gd` 中实现基础建筑系统：启动时读取 `data/building_defs.json`，按 `scene_nodes` 绑定 `Main/WorldRoot/Station/Buildings` 下的低模建筑节点，为绑定节点创建运行时 `Area3D/CollisionShape3D` 点击区，并在左键点击时发出 `EventBus.building_clicked(building_id)`。建筑调试标签会显示名称、等级和 HP，并在修复/升级后刷新。2026-05-20 修正后，建筑点击同时通过 `_unhandled_input` 的相机射线拾取点击区，避免全屏 UI 背板或项目拾取设置导致真实鼠标点击失效。T0304 起，建筑系统提供 `get_building_entry_position(...)` 和 `get_building_location_context(...)`，分别用于 NPC 移动目标点与地点信息读取占位。修复/升级由 `BuildingSystem` 调用 `ResourceSystem.spend_resources` 结算；资源不足时不会改变建筑状态。建筑系统仍不实现生产、敌人攻击或战斗系统造成的建筑 HP 扣除。

T0304 已新增 `res://scenes/npc/NPC.tscn` 和 `res://scripts/npc/NPC.gd`，并在 `res://scripts/systems/NPCSystem.gd` 中实现基础 NPC 生成、状态接口和直线移动占位：启动时读取 `data/npc_profiles.json`，实例化 8 个 NPC 到 `Main/WorldRoot/Station/NPCs`，每个 NPC 保存唯一 `npc_id`，主场景 `Label3D` 调试标签只显示短姓名、HP 和当前行动。NPC 点击会打印 ID 并通过 `EventBus.npc_clicked(npc_id)` 广播；`NPCSystem` 同时提供 `get_npc(...)`、`get_npc_state(...)`、`get_npc_ids()`、`get_npc_count()`、`update_npc_state(...)`、`set_npc_state_value(...)`、固定熟练度枚举、`normalize_skills(...)`、`get_npc_specialties(...)`、`debug_select_npc(...)`、`move_npc_to_building(...)`、`debug_move_npc_to_building(...)` 和 `debug_move_selected_npc_to_building(...)`。每名 NPC 的技能会归一化为 8 个职业熟练度加 5 个武器熟练度，专长由高熟练度推导，不使用硬职业枚举。移动开始时 NPC 状态进入 `moving_to_<building_id>`；到达后写入 `current_location`、`current_location_name` 和 `location_context`，并发出 `EventBus.npc_state_changed(npc_id)`。该阶段不实现复杂避障、自然状态变化、真实日程计划、对话、征召、战斗或 LLM。

T0305 已在 `res://scripts/systems/ActionSystem.gd` 中实现简单行动系统：启动时读取 `data/action_defs.json`，提供 `debug_assign_work(...)`、`debug_assign_eat(...)`、`debug_assign_sleep(...)` 和 `debug_assign_action(...)`。行动会先检查 NPC 是否可行动，必要时调用 `NPCSystem.move_npc_to_building(...)` 前往目标建筑，到达后由 `ActionSystem` 结算资源输入/输出、可选建筑 HP 恢复、饱食度和疲劳度，并写入 `MemorySystem` 的 EventLog 占位。当前已按 `game_design.md` 覆盖菜园、食堂、酒窖、铁匠铺、工械坊、马厩、围墙修补、吃饭和睡觉的最小效果；不实现 LLM 日程、训练、战斗、工作位占用或复杂职业效率。

T0303 已将 `Main/UI/NPCPanel` 绑定 `res://scripts/ui/NPCPanel.gd`：监听 `npc_clicked` 显示姓名、专长、HP、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、职业熟练度和武器熟练度；监听 `npc_state_changed` 刷新当前 NPC 数据；监听 `building_clicked` 时隐藏自身。`BuildingPanel` 也会在 `npc_clicked` 时隐藏，确保 NPC/建筑面板互斥切换。

## 重要信号建议

```gdscript
signal day_started(day: int)
signal hour_started(day: int, hour: int)
signal resource_changed(resource_id: String, amount: int)
signal npc_state_changed(npc_id: String)
signal npc_clicked(npc_id: String)
signal building_clicked(building_id: String)
signal dialogue_requested(npc_id: String)
signal recruitment_changed(npc_id: String, recruited: bool)
signal battle_started(wave_id: int)
signal battle_ended(wave_id: int)
signal npc_hp_changed(npc_id: String, hp: float)
signal npc_unconscious(npc_id: String)
signal npc_revived(npc_id: String)
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
