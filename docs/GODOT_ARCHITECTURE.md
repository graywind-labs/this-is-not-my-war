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

T0102 已将 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 作为空系统脚本占位绑定到 Main 场景的 `Systems` 节点下。当前仅提供结构占位，不实现点击、NPC、资源数值、战斗或对话逻辑。

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
