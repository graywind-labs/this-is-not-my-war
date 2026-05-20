# CURRENT_STATE.md

> 本文件描述“当前项目真实状态”。每次完成任务后必须更新。
> 不要在这里写未来愿景；未来内容写入 `TASKS.md` 或模块设计文档。

## 当前版本

版本：`0.0.12-building-repair-upgrade`
状态：已完成 Godot 项目入口、可扩展 Main 场景节点结构、低模驿站 Blockout、基础 HUD、基础摄像机控制、核心 Autoload 骨架、基础 JSON 数据文件、基础 ResourceSystem、基础 BuildingSystem、基础建筑面板、建筑修复/升级最小闭环，以及 Flask 后端骨架和 `/health` 健康检查；尚未实现 NPC 生成、生产、时间推进、战斗和 AI 对话。

## 当前已实现内容

- [x] Godot 项目初始化
- [x] 核心 Autoload 骨架
- [x] Main 标准节点结构
- [x] 基础地图
- [x] HUD 基础界面
- [x] 基础摄像机控制
- [ ] NPC 基础实体
- [x] 建筑基础实体
- [x] 建筑基础面板
- [x] 建筑修复与升级最小逻辑
- [ ] 时间系统
- [x] 资源系统
- [ ] 对话系统
- [x] LLM 后端骨架
- [ ] 征召系统
- [ ] 战斗系统
- [ ] 昏迷/治疗/复苏
- [ ] 见闻系统
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
ResourceSystem 从 data/resource_defs.json 初始化第纳尔、粮食、木材、石料、铁
  ↓
BuildingSystem 从 data/building_defs.json 初始化建筑基础状态并绑定低模建筑节点
  ↓
显示 HUD 标题、天数、小时/阶段、真实资源数值、加速/警铃按钮占位和后端状态占位
  ↓
建筑调试标签显示名称、等级和 HP，真实鼠标点击建筑可发出 building_clicked(building_id)
  ↓
右上角建筑面板显示被点击建筑的名称、等级、HP、工作位、地点信息占位和修复/升级消耗，可关闭；修复/升级按钮按条件启用并调用 BuildingSystem
  ↓
玩家可用 WASD、鼠标中键拖拽和滚轮在受限边界内查看驿站
```

低模驿站当前包含主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌占位和调试标签。2026-05-19 已扩大地面与围墙范围，并重新拉开建筑间距，让中央广场、生活区、生产区、防务区和后门入口更易辨认；随后补齐围墙四角闭合，并把公告牌缩小移动到主厅正面。HUD 当前显示 `ResourceSystem` 初始化后的五类资源数值：第纳尔、粮食、木材、石料、铁；加速按钮、警铃按钮和后端状态不触发真实逻辑。建筑当前由 `BuildingSystem` 读取 `data/building_defs.json` 绑定到低模节点，标签显示名称、等级和 HP，运行时点击区可识别建筑 ID 并发出 `building_clicked`；2026-05-20 已修正 HUD 背板拦截问题，真实鼠标点击建筑会通过相机射线拾取打开 `BuildingPanel`。`BuildingPanel` 监听该事件并显示建筑名称、等级、HP、工作位、地点信息占位和修复/升级消耗摘要；修复/升级按钮会调用 `BuildingSystem`，并由 `ResourceSystem` 扣除石料。尚未实现 NPC、生产、时间推进、AI 对话或战斗。

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
- `scripts/ui/HUD.gd`：HUD 展示脚本，读取 `GameState` 的天数/小时，监听 `resource_changed` 并刷新资源显示、按钮和后端状态占位
- `scripts/ui/BuildingPanel.gd`：建筑面板脚本，监听 `building_clicked` 并展示建筑基础信息，可触发建筑修复/升级
- `scripts/camera/CameraRig.gd`：基础俯视摄像机控制，支持 WASD/鼠标中键平移、滚轮缩放和边界限制
- `scripts/core/EventBus.gd`：全局事件总线，声明基础跨系统信号
- `scripts/core/GameState.gd`：全局运行状态，保存天数、小时和战斗状态
- `scripts/core/ConfigLoader.gd`：JSON 配置读取入口，提供缺失/解析错误提示
- `scripts/systems/ResourceSystem.gd`：基础资源系统，从 `data/resource_defs.json` 初始化资源，提供读取、增加、扣除和负数保护接口，并通过 `resource_changed` 通知 HUD
- `scripts/systems/BuildingSystem.gd`：基础建筑系统，从 `data/building_defs.json` 初始化建筑状态，绑定低模建筑节点，创建运行时点击区，发出 `building_clicked`，并提供修复/升级接口
- `scripts/systems/TimeSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd`：后续系统的空脚本占位
- `data/resource_defs.json`：基础资源定义，包含第纳尔、粮食、木材、石料、铁
- `data/building_defs.json`：建筑定义，当前覆盖 16 个低模建筑/门墙实体，并包含等级、HP、标签、工作位、资源输入输出、场景节点绑定，以及部分建筑的修复/升级配置
- `data/action_defs.json`：行动定义最小样例，当前包含修补围墙
- `data/weapon_defs.json`：武器定义最小样例，当前包含短剑
- `data/enemy_waves.json`：敌人波次最小样例，当前包含第一波占位
- `data/npc_profiles.json`：NPC 档案最小样例，当前包含老兵副官占位档案

## 当前风险

- 系统设计较大，需要严格按最小闭环推进。
- NPC 自主计划、LLM 对话、战斗系统不能同时展开。
- `game_design.md` 内容较长，Agent 必须按模块精确读取，避免上下文浪费。

## 最近一次变更

- T0205 实现建筑修复与升级最小闭环：`BuildingSystem.gd` 支持修复/升级请求并通过 `ResourceSystem` 扣除石料，`BuildingPanel.gd` 的按钮会根据 HP、等级和资源状态启用/禁用，`data/building_defs.json` 为主厅、宿舍、食堂、仓库、围墙加入修复/升级配置；通过无头启动、验证脚本和 Godot MCP 主场景运行验证无报错。

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
