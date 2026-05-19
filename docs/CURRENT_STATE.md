# CURRENT_STATE.md

> 本文件描述“当前项目真实状态”。每次完成任务后必须更新。  
> 不要在这里写未来愿景；未来内容写入 `TASKS.md` 或模块设计文档。

## 当前版本

版本：`0.0.8-camera-control`  
状态：已完成 Godot 项目入口、可扩展 Main 场景节点结构、低模驿站 Blockout、基础 HUD、基础摄像机控制、核心 Autoload 骨架、基础 JSON 数据文件，以及 Flask 后端骨架和 `/health` 健康检查；尚未实现 NPC 生成、建筑交互、真实资源变化、时间推进、战斗和 AI 对话。

## 当前已实现内容

- [x] Godot 项目初始化
- [x] 核心 Autoload 骨架
- [x] Main 标准节点结构
- [x] 基础地图
- [x] HUD 基础界面
- [x] 基础摄像机控制
- [ ] NPC 基础实体
- [ ] 建筑基础实体
- [ ] 时间系统
- [ ] 资源系统
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
显示 HUD 标题、天数、小时/阶段、资源占位、加速/警铃按钮占位和后端状态占位
  ↓
玩家可用 WASD、鼠标中键拖拽和滚轮在受限边界内查看驿站
```

低模驿站当前包含主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌占位和调试标签。2026-05-19 已扩大地面与围墙范围，并重新拉开建筑间距，让中央广场、生活区、生产区、防务区和后门入口更易辨认；随后补齐围墙四角闭合，并把公告牌缩小移动到主厅正面。HUD 当前只显示占位信息：资源为 `--`，加速按钮、警铃按钮和后端状态不触发真实逻辑。尚未实现 NPC、建筑点击、真实资源栏、时间推进、AI 对话或战斗。当前系统脚本只提供占位骨架。

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
- `scripts/ui/HUD.gd`：HUD 展示脚本，读取 `GameState` 的天数/小时并刷新资源、按钮和后端状态占位
- `scripts/camera/CameraRig.gd`：基础俯视摄像机控制，支持 WASD/鼠标中键平移、滚轮缩放和边界限制
- `scripts/core/EventBus.gd`：全局事件总线，声明基础跨系统信号
- `scripts/core/GameState.gd`：全局运行状态，保存天数、小时和战斗状态
- `scripts/core/ConfigLoader.gd`：JSON 配置读取入口，提供缺失/解析错误提示
- `scripts/systems/TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd`：后续系统的空脚本占位
- `data/resource_defs.json`：基础资源定义，包含第纳尔、粮食、木材、石料、铁
- `data/building_defs.json`：建筑定义最小样例，当前包含主厅
- `data/action_defs.json`：行动定义最小样例，当前包含修补围墙
- `data/weapon_defs.json`：武器定义最小样例，当前包含短剑
- `data/enemy_waves.json`：敌人波次最小样例，当前包含第一波占位
- `data/npc_profiles.json`：NPC 档案最小样例，当前包含老兵副官占位档案

## 当前风险

- 系统设计较大，需要严格按最小闭环推进。
- NPC 自主计划、LLM 对话、战斗系统不能同时展开。
- `game_design.md` 内容较长，Agent 必须按模块精确读取，避免上下文浪费。

## 最近一次变更

- T0105 实现基础摄像机控制：新增并绑定 `scripts/camera/CameraRig.gd`，支持 WASD 平移、鼠标中键拖拽、滚轮缩放、X/Z 边界限制和缩放距离限制；通过 Godot MCP 运行主场景无报错，并用 headless Godot 验证项目加载无错误。

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
