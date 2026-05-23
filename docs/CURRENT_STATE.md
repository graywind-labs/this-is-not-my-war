# CURRENT_STATE.md

> 本文件描述“当前项目真实状态”。每次完成任务后必须更新。
> 不要在这里写未来愿景；未来内容写入 `TASKS.md` 或模块设计文档。

## 当前版本

版本：`0.0.23-structured-events`
状态：已完成 Godot 项目入口、可扩展 Main 场景节点结构、低模驿站 Blockout、基础 HUD、基础摄像机控制、核心 Autoload 骨架、基础 JSON 数据文件、8 名初始 NPC 数据草案、基础 NPC 生成与点击、NPC 基础状态读取/更新、NPC 面板、基础 NPC 直线移动与地点进入占位、按 `game_design.md` 对齐的工作/吃饭/睡觉最小行动闭环、基础 ResourceSystem、基础 BuildingSystem、基础建筑面板、建筑修复/升级最小闭环、结构化事件底座、精确到秒且支持独立暂停/加速与 LLM 等待减速请求的基础 TimeSystem，以及 Flask 后端骨架和 `/health` 健康检查；尚未实现真实每日计划、复杂生产效率、地点/广场即时广播见闻、战斗和 AI 对话。

## 当前已实现内容

- [x] Godot 项目初始化
- [x] 核心 Autoload 骨架
- [x] Main 标准节点结构
- [x] 基础地图
- [x] HUD 基础界面
- [x] 基础摄像机控制
- [x] NPC 基础实体
- [x] NPC 基础状态与面板
- [x] NPC 基础移动与地点进入占位
- [x] NPC 工作 / 吃饭 / 睡觉最小行动闭环
- [x] 8 名初始 NPC 数据草案
- [x] 建筑基础实体
- [x] 建筑基础面板
- [x] 建筑修复与升级最小逻辑
- [x] 时间系统
- [x] 资源系统
- [ ] 对话系统
- [x] LLM 后端骨架
- [ ] 征召系统
- [ ] 战斗系统
- [ ] 昏迷/治疗/复苏
- [ ] 见闻系统
- [x] 结构化事件底座
- [ ] 结算系统
- [x] 基础 JSON 数据文件

## 当前稳定运行流程

```text
启动 Godot
  ↓
加载 EventBus / GameState / ConfigLoader Autoload
  ↓
进入 Main 场景
  ↓
加载 WorldRoot / Station / Systems / UI / CameraRig 标准节点结构
  ↓
显示低模驿站 Blockout、俯视相机、方向光
  ↓
ResourceSystem 从 data/resource_defs.json 初始化第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁
  ↓
BuildingSystem 从 data/building_defs.json 初始化建筑基础状态并绑定低模建筑节点
  ↓
NPCSystem 从 data/npc_profiles.json 读取 8 名初始 NPC，并在 Station/NPCs 下生成占位实体
  ↓
可通过调试接口让 NPC 前往指定建筑；NPC 实体直线移动，到达后写回 current_location 与 location_context 占位
  ↓
ActionSystem 可通过调试接口安排 NPC 去工作、吃饭或睡觉；若目标建筑不同，会先移动再结算行动
  ↓
行动结算由程序执行：工作可消耗/产出资源或修复围墙，吃饭消耗粮食或餐食恢复饱食度，睡觉降低疲劳，并写入 MemorySystem 的结构化事件库
  ↓
显示 HUD 标题、天数、`HH:MM:SS` 时间/阶段、真实资源数值、独立速度按钮、独立暂停/继续按钮、警铃按钮占位和后端状态占位
  ↓
建筑调试标签显示名称、等级和 HP，真实鼠标点击建筑可发出 building_clicked(building_id)
  ↓
NPC 短姓名/HP/当前行动调试标签可见，点击 NPC 可打印并发出 npc_clicked(npc_id)
  ↓
右上角 NPC 面板可显示被点击 NPC 的姓名、HP、力量/智力属性、由熟练度推导的专长、饱食、疲劳、金钱、昏迷、入伍、当前行动、职业熟练度和武器熟练度；NPC 状态被 NPCSystem 修改后面板会刷新
  ↓
右上角建筑面板显示被点击建筑的名称、等级、HP、工作位、地点信息占位和修复/升级消耗，可关闭；修复/升级按钮按条件启用并调用 BuildingSystem；NPC 面板和建筑面板会随点击对象互斥切换
  ↓
玩家可用 WASD、鼠标中键拖拽和滚轮在受限边界内查看驿站
```

低模驿站当前包含主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌占位和调试标签。2026-05-19 已扩大地面与围墙范围，并重新拉开建筑间距，让中央广场、生活区、生产区、防务区和后门入口更易辨认；随后补齐围墙四角闭合，并把公告牌缩小移动到主厅正面。HUD 当前显示 `ResourceSystem` 初始化后的五类基础资源数值：第纳尔、粮食、木材、石料、铁；餐食、酒、武器、盔甲、工程器械和马匹整备作为派生资源用于行动结算，暂不显示在 HUD 中；时间显示为 `HH:MM:SS`，会随 `TimeSystem` 每个游戏秒刷新；速度按钮只在 `x1`、`x2`、`x4` 之间循环，暂停/继续由独立按钮控制，也可按空格切换，空格不再触发加速；TimeSystem 当前不改变 Godot 全局速度或 NPC 移动速度，只提供逻辑时间倍率、`logical_time_tick`、`gameplay_pause_changed` 和 LLM 等待慢速请求接口。暂停时逻辑时间停止、NPC 移动停止，当前已接入的调试行动结算会保持 pending，不会在暂停中消耗/产出资源或改变饱食/疲劳，恢复后再结算；后续资源/战斗/计划系统应按同一暂停语义和有效倍率结算。警铃按钮和后端状态仍不触发真实逻辑。建筑当前由 `BuildingSystem` 读取 `data/building_defs.json` 绑定到低模节点，标签显示名称、等级和 HP，运行时点击区可识别建筑 ID 并发出 `building_clicked`；2026-05-20 已修正 HUD 背板拦截问题，真实鼠标点击建筑会通过相机射线拾取打开 `BuildingPanel`。`BuildingPanel` 监听该事件并显示建筑名称、等级、HP、工作位、地点信息占位和修复/升级消耗摘要；修复/升级按钮会调用 `BuildingSystem`，并由 `ResourceSystem` 扣除石料。NPC 当前由 `NPCSystem` 读取 `data/npc_profiles.json`，在 `Main/WorldRoot/Station/NPCs` 下生成 8 个低模占位实体，主场景头顶标签只显示短姓名、HP 和当前行动；`NPCPanel` 按姓名、HP、属性、专长、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、熟练度的顺序展示，其中属性来自 `stats.strength` / 力量和 `stats.intelligence` / 智力，专长由固定熟练度推导，熟练度按职业熟练度、武器熟练度两组展示完整 13 维。点击 NPC 会打印 ID、发出 `npc_clicked(npc_id)` 并打开 `NPCPanel`。`NPCSystem` 提供 NPC 状态读取、更新和调试移动接口，`debug_move_npc_to_building(npc_id, building_id)` 可让 NPC 直线移动到建筑入口；到达后状态会写入 `current_location`、`current_location_name` 和 `location_context` 地点信息占位，并发出 `npc_state_changed` 刷新面板。后续进入地点只应读取当前地点状态，不继承地点过去事件。`ActionSystem` 当前读取 `data/action_defs.json`，提供调试指派工作、吃饭和睡觉接口：菜园产粮、食堂加工餐食、酒窖酿酒、铁匠铺产出武器/盔甲、工械坊产出工程器械、马厩产出马匹整备占位、围墙修补恢复围墙 HP；吃饭优先消耗餐食并恢复更多饱食度，没有餐食时消耗粮食，睡觉降低疲劳；行动开始、完成或失败会写入 `MemorySystem` 的结构化事件库，包含 `subject_npc_id`、`location_id`、`visibility`、`target_ids` 和类型化 `payload`。尚未实现真实日程计划、复杂职业效率、地点/广场即时广播见闻、AI 对话或战斗。

摄像机当前绑定 `res://scripts/camera/CameraRig.gd`，支持 WASD 平移、鼠标中键拖拽平移和滚轮缩放；移动限制在驿站地面附近，缩放保持现有高机位俯视角，不提供角色控制或第一人称自由视角。

后端当前稳定流程：

```text
进入 backend
  ↓
安装 requirements.txt
  ↓
启动 Flask app.py
  ↓
访问 GET /health
  ↓
返回 {"ok": true, "service": "war-not-mine-backend"}
```

后续预期稳定流程：

```text
启动 Godot
  ↓
进入 Main 场景
  ↓
显示驿站地图、时间、资源栏
  ↓
显示至少 1 个 NPC
  ↓
NPC 可移动到建筑并执行简单工作
```

## 当前运行方式

```bash
godot --path .
```

或在 Godot 编辑器中打开 `project.godot` 后运行项目。当前启动场景为：

```text
res://scenes/main/Main.tscn
```

后端已初始化，可用以下方式启动：

```bash
cd backend
python app.py
```

健康检查：

```bash
curl http://127.0.0.1:5000/health
```

## 当前主要文件

- `AGENTS.md`：AI Agent 项目协作规则
- `game_design.md`：完整游戏设计源
- `docs/PROJECT_BRIEF.md`：项目简报
- `docs/TASKS.md`：任务列表
- `docs/MODULE_INDEX.md`：模块索引
- `backend/app.py`：Flask 后端入口，提供 `GET /health`
- `backend/services/model_adapter.py`：模型适配器最小边界，占位后续 LLM 调用
- `backend/requirements.txt`：Python 后端依赖
- `project.godot`：Godot 项目配置，当前入口为 `res://scenes/main/Main.tscn`
- `scenes/main/Main.tscn`：最小可运行主场景，包含标准 WorldRoot、Systems、UI、CameraRig 节点结构、低模驿站 Blockout 和基础 HUD
- `scripts/ui/HUD.gd`：HUD 展示脚本，读取 `GameState` 的天/时/分/秒，监听 `time_changed` / `resource_changed` 并刷新时间、资源显示、速度/暂停按钮和后端状态占位
- `scripts/ui/BuildingPanel.gd`：建筑面板脚本，监听 `building_clicked` 并展示建筑基础信息，可触发建筑修复/升级
- `scripts/ui/NPCPanel.gd`：NPC 面板脚本，监听 `npc_clicked` 和 `npc_state_changed`，按姓名/HP/属性/专长/基础状态顺序展示 NPC 数据，并与建筑面板互斥切换
- `scenes/npc/NPC.tscn`：通用 NPC 占位场景，当前为可点击低模实体和短姓名/HP/当前行动标签
- `scripts/npc/NPC.gd`：NPC 展示脚本，保存唯一 ID，刷新调试标签，在点击时发出 `npc_clicked`，并支持直线移动到指定地点
- `scripts/camera/CameraRig.gd`：基础俯视摄像机控制，支持 WASD/鼠标中键平移、滚轮缩放和边界限制
- `scripts/core/EventBus.gd`：全局事件总线，声明基础跨系统信号
- `scripts/core/GameState.gd`：全局运行状态，保存天数、小时、分钟、秒和战斗状态
- `scripts/core/ConfigLoader.gd`：JSON 配置读取入口，提供缺失/解析错误提示
- `scripts/systems/ResourceSystem.gd`：基础资源系统，从 `data/resource_defs.json` 初始化资源，提供读取、增加、扣除和负数保护接口，并通过 `resource_changed` 通知 HUD
- `scripts/systems/BuildingSystem.gd`：基础建筑系统，从 `data/building_defs.json` 初始化建筑状态，绑定低模建筑节点，创建运行时点击区，发出 `building_clicked`，并提供修复/升级、建筑入口坐标和地点信息占位接口
- `scripts/systems/NPCSystem.gd`：基础 NPC 系统，从 `data/npc_profiles.json` 生成 8 个 NPC 占位实体，并提供查询、状态更新、调试选择和调试移动接口
- `scripts/systems/ActionSystem.gd`：简单行动系统，读取 `data/action_defs.json`，支持调试指派工作、吃饭、睡觉；暂停时行动保持 pending，恢复后再结算资源/状态/围墙 HP，并写入结构化行动事件
- `scripts/systems/MemorySystem.gd`：结构化事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位，并支持按地点和广场公开规则查询；地点/广场节点不保存事件历史
- `scripts/systems/TimeSystem.gd`：基础逻辑时间系统，支持 24 小时阶段、秒级显示、暂停、加速、跨天、LLM 等待减速请求、`logical_time_tick` 和 `time_changed` / `time_scale_changed` / `hour_started` / `day_started` 信号
- `scripts/systems/CombatSystem.gd`、`DialogSystem.gd`：后续系统的空脚本占位
- `data/resource_defs.json`：资源定义，包含第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料、铁
- `data/building_defs.json`：建筑定义，当前覆盖 16 个低模建筑/门墙实体，并包含等级、HP、标签、工作位、资源输入输出、场景节点绑定，以及部分建筑的修复/升级配置
- `data/action_defs.json`：行动定义，当前包含菜园、食堂、酒窖、铁匠铺、工械坊、马厩、围墙修补、吃饭和睡觉的最小闭环
- `data/weapon_defs.json`：武器定义最小样例，当前包含短剑
- `data/enemy_waves.json`：敌人波次最小样例，当前包含第一波占位
- `data/npc_profiles.json`：NPC 档案配置，当前包含 8 名初始 NPC：托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文；老兵副官开局 `recruited=true`，其他 NPC 初始不可指派

## 当前风险

- 系统设计较大，需要严格按最小闭环推进。
- NPC 自主计划、LLM 对话、战斗系统不能同时展开。
- `game_design.md` 内容较长，Agent 必须按模块精确读取，避免上下文浪费。

## 最近一次变更

- T0402 结构化事件底座：`MemorySystem` 已升级为事件事实源，ActionSystem 工作/吃饭/睡觉/失败路径和 NPC 地点到达会写入结构化事件；`verify_structured_memory_events.gd` 已覆盖全局索引、NPC 当天事件库、地点查询、广场公开查询和 payload schema。

## Godot MCP

- 项目内已安装并启用 `addons/godot_mcp`。
- Codex 端改为 `proxy -> broker -> Godot` 结构，避免多个 Codex 会话直接争抢 Godot 连接。
- 连接自检命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1
```

- 当前验证结果：脚本可正常返回 `Godot MCP connected`。
- 2026-05-19 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图可见标题与基础地面。
- 2026-05-19 T0101 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，Autoload 加载正常，游戏日志无报错。
- 2026-05-19 T0102 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 标题与基础地面仍可见。
- 2026-05-19 T0103 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认低模驿站、HUD 标题和调试标签可见。
- 2026-05-19 T0104 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示标题、时间、资源占位、按钮占位和后端状态占位，且未遮挡主要驿站视角。
- 2026-05-19 T0105 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，`CameraRig` 已挂载 `res://scripts/camera/CameraRig.gd` 并暴露平移、缩放和边界参数。
- 2026-05-19 T0202 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示 `金钱 30`、`粮食 18`、`木材 12`、`石料 8`、`铁 5`；使用临时测试场景验证资源增加、扣除和超额扣除失败逻辑。
- 2026-05-19 T0203 验证：通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；通过临时 Godot 验证脚本确认 `BuildingSystem` 加载 16 个建筑定义、可查询主厅数据、可选中仓库、主厅 ClickArea 已创建；通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认建筑标签显示名称、等级和 HP。
- 2026-05-19 T0204 验证：通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；通过临时 Godot 验证脚本确认选择主厅会打开建筑面板、切换仓库会刷新数据、关闭按钮会隐藏面板；通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 与低模驿站仍正常显示。
- 2026-05-20 T0204 修正验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_panel_mouse_click.gd` 临时验证真实鼠标点击路径，主厅点击可打开建筑面板；通过 `--quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-20 T0205 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 验证建筑受损后可修复、修复/升级会扣除石料、升级会提升等级/Max HP/工作位、资源不足时升级失败且不扣资源；通过 `--quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-20 T0302 验证：通过 `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 验证 8 个 NPC 生成和 `npc_clicked` 信号；通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错，MCP 查找确认 `Main/WorldRoot/Station/NPCs` 下存在 8 个 NPC `Area3D` 节点。
- 2026-05-20 T0303 验证：通过 `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 验证 NPC 面板打开、状态修改后刷新、NPC/建筑面板互斥切换和关闭按钮；通过 `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 回归验证 NPC 生成与点击；通过 Godot MCP 运行主场景，游戏日志无报错，并确认 `Main/UI` 下存在 `NPCPanel`、`BuildingPanel`、`DialogPanel`。
- 2026-05-21 T0304 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 验证 NPC 可通过调试接口依次前往食堂、宿舍、仓库，并在到达后更新地点和地点信息占位；通过 `verify_npc_generation_click.gd`、`verify_npc_panel_state.gd` 回归验证；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-21 T0305 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 验证 NPC 可被调试安排吃饭、睡觉、菜园工作、酒窖酿酒、铁匠铺制造、工械坊制造、围墙修补，资源/派生资源/围墙 HP 与饱食/疲劳会正确结算，行动事件写入 EventLog 占位；通过 `verify_npc_movement_location.gd`、`verify_npc_panel_state.gd`、`verify_npc_generation_click.gd` 回归验证；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-23 T0402 验证：通过 `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 验证结构化事件字段、NPC 当天事件库、全局事件索引、地点查询、广场公开查询和 payload schema；通过 `verify_action_system_basic.gd` 回归行动闭环；通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；Godot MCP `get_state` 正常返回。

