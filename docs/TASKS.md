# TASKS.md

> 本文件是 Agent 开发入口。  
> 每次开始实现前，必须确认任务在本文件中有明确条目。  
> 每次完成后，必须更新状态、验收结果和后续任务。

任务状态：

- `Todo`：未开始
- `Doing`：正在做
- `Partial`：部分完成，可运行但未完全达标
- `Blocked`：受阻，需要用户或外部条件
- `Done`：已完成并验证

---

# 当前里程碑

## M0：项目骨架与文档闭环

目标：建立 Godot + 后端 + 文档协作的最小工程结构。

### T0001 初始化 Godot 项目结构

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

### T0002 初始化后端目录

状态：Todo  
优先级：P0  
涉及文档：`TECH_ARCHITECTURE.md`, `API_BUDGET.md`, `MODULE_INDEX.md`

验收标准：

- 存在 `backend/app.py`。
- 存在后端 README。
- 存在基础服务目录：`schemas/`, `services/`, `data/`。
- 能启动一个本地健康检查接口。
- 不包含任何真实 API Key。

### T0003 建立文档回写流程

状态：Todo  
优先级：P0  
涉及文档：全部核心文档

验收标准：

- 每次任务完成后更新 `CURRENT_STATE.md`。
- 每次任务完成后更新 `TASKS.md`。
- 新增代码文件后更新 `MODULE_INDEX.md`。
- 每次功能完成写入 `DEV_LOG.md` 和 `CHANGELOG.md`。

---

## M1：最小可运行驿站

目标：进入 Godot 后能看到驿站地图、资源栏、时间和基础建筑。

### T0101 创建 Main 场景

状态：Todo  
优先级：P0

验收标准：

- 启动进入主场景。
- 有基础 Camera、Light、World Root。
- 有简化低模地面。
- 有 UI 层。

### T0102 创建基础建筑实体

状态：Todo  
优先级：P0

验收标准：

- 至少有主厅、宿舍、食堂、仓库、围墙。
- 建筑可被点击。
- 建筑面板显示名称、HP、等级。
- 建筑数据来自配置，不写死在场景脚本中。

### T0103 创建资源系统

状态：Todo  
优先级：P0

验收标准：

- 显示金钱、粮食、木材、石料、铁。
- 可通过调试按钮改变资源。
- 资源系统有统一读写接口。

### T0104 创建时间系统

状态：Todo  
优先级：P0

验收标准：

- 一天 24 阶段。
- 正常时间流逝。
- 可暂停、加速。
- 可触发阶段切换信号。

---

## M2：NPC 最小闭环

目标：至少一个 NPC 能读取配置、移动、执行简单计划。

### T0201 创建 NPC 数据配置

状态：Todo  
优先级：P0

验收标准：

- `data/npc_profiles.json` 包含 8 个初始 NPC 草案。
- 每个 NPC 有职业、性格、状态、属性、熟练度。
- Godot 能读取并生成 NPC。

### T0202 创建 NPC 基础状态

状态：Todo  
优先级：P0

验收标准：

- NPC 有 HP、饱食度、疲劳度、金钱、昏迷状态。
- 状态可在 UI 中显示。
- HP 清零后进入昏迷而不是死亡。

### T0203 创建简单行动系统

状态：Todo  
优先级：P0

验收标准：

- NPC 可前往某建筑。
- NPC 可执行工作、吃饭、睡觉三种基础行动。
- 行动结束后写入事件日志。

---

## M3：AI 对话与征召

目标：玩家能与 NPC 对话，并通过对话让 NPC 接受或拒绝应征。

### T0301 后端对话接口

状态：Todo  
优先级：P0

验收标准：

- Godot 向后端发送 NPC 状态与玩家输入。
- 后端返回结构化 JSON。
- 失败时有降级文本。

### T0302 NPC 对话 UI

状态：Todo  
优先级：P0

验收标准：

- 玩家点击 NPC 可打开对话。
- 玩家输入文本。
- 显示 NPC 回复。
- 可点击“提出应征”。

### T0303 征召状态切换

状态：Todo  
优先级：P0

验收标准：

- NPC 接受后 `recruited=true`。
- 入伍 NPC 可被玩家指派任务。
- 拒绝后保持自由行动。

---

## M4：战斗、防守与昏迷复苏

目标：敌人攻击，入伍 NPC 防守，NPC 昏迷、治疗、复苏，战场事件公开到广场。

### T0401 警铃与集结

状态：Todo  
优先级：P0

### T0402 敌人波次

状态：Todo  
优先级：P0

### T0403 基础战斗

状态：Todo  
优先级：P0

### T0404 昏迷、治疗、复苏

状态：Todo  
优先级：P0

### T0405 战场公开见闻

状态：Todo  
优先级：P0

---

### T0004 Stabilize Godot MCP startup

状态：Done  
优先级：P0  
涉及文档：`CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`, `CHANGELOG.md`

验收标准：
- Codex 的 `godot-mcp` 启动入口改为单实例包装脚本，新的启动会清理旧实例。
- 只保留 1 条有效的 Godot MCP 客户端连接到 Godot 编辑器。
- `tools/check_godot_mcp.ps1` 可以正常报告连接状态，不再出现脚本解析错误。

# Backlog

- NPC 主动找玩家交涉，头顶问号气泡。
- 每日计划 LLM 生成。
- 睡前总结与第一人称日记。
- 知识图谱更新。
- 公告牌。
- 商人交易。
- 建筑升级。
- 工程器械部署。
- 语音输入。
- 情绪识别。
