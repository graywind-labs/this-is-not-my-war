# CURRENT_STATE.md

> 本文件描述“当前项目真实状态”。每次完成任务后必须更新。  
> 不要在这里写未来愿景；未来内容写入 `TASKS.md` 或模块设计文档。

## 当前版本

版本：`0.0.1-main-scene`  
状态：已完成 Godot 项目入口与最小可运行 Main 场景，尚未实现 NPC、建筑交互、资源、时间和战斗。

## 当前已实现内容

- [x] Godot 项目初始化
- [ ] 基础地图
- [ ] NPC 基础实体
- [ ] 建筑基础实体
- [ ] 时间系统
- [ ] 资源系统
- [ ] 对话系统
- [ ] LLM 后端
- [ ] 征召系统
- [ ] 战斗系统
- [ ] 昏迷/治疗/复苏
- [ ] 见闻系统
- [ ] 结算系统

## 当前稳定运行流程

```text
启动 Godot
  ↓
进入 Main 场景
  ↓
显示一个基础 3D 地面、俯视相机、方向光
  ↓
显示最小 HUD 标题
```

尚未实现 NPC、建筑点击、资源栏、时间系统、后端或战斗。

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

后端尚未初始化，以下方式暂不可用：

```bash
cd backend
python app.py
```

## 当前主要文件

- `AGENTS.md`：AI Agent 项目协作规则
- `game_design.md`：完整游戏设计源
- `docs/PROJECT_BRIEF.md`：项目简报
- `docs/TASKS.md`：任务列表
- `docs/MODULE_INDEX.md`：模块索引
- `project.godot`：Godot 项目配置，当前入口为 `res://scenes/main/Main.tscn`
- `scenes/main/Main.tscn`：最小可运行主场景

## 当前风险

- 系统设计较大，需要严格按最小闭环推进。
- NPC 自主计划、LLM 对话、战斗系统不能同时展开。
- `game_design.md` 内容较长，Agent 必须按模块精确读取，避免上下文浪费。

## 最近一次变更

- T0001 初始化 Godot 项目结构：创建最小可运行 Main 场景，并设置项目启动入口。

## Godot MCP

- 项目内已安装并启用 `addons/godot_mcp`。
- Codex 端改为 `proxy -> broker -> Godot` 结构，避免多个 Codex 会话直接争抢 Godot 连接。
- 连接自检命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1
```

- 当前验证结果：脚本可正常返回 `Godot MCP connected`。
- 2026-05-19 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图可见标题与基础地面。
