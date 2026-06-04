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

## T0006 修复建筑修复进度抢占右上角面板

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `ECONOMY_AND_BUILDINGS.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：
修复建筑正在修复时，玩家点击 NPC 后右上角面板被修复建筑自动切回的问题。

验收标准：
- 玩家点击正在修复的建筑并开始修复后，建筑面板能随修复进度刷新。
- 修复过程中玩家点击 NPC，右上角应保持 NPC 面板，不被正在修复的建筑重新抢占。
- 玩家再次点击建筑时，仍可正常切回建筑面板。
- 现有建筑修复/升级与 NPC 面板回归验证通过。

验收结果（2026-05-25）：
- 已将建筑点击选择与建筑状态刷新拆分为 `building_clicked` / `building_state_changed`。
- `BuildingPanel` 只在当前可见且正在显示对应建筑时响应建筑状态刷新；修复进度不会再抢占 NPC 面板。
- `tools/verify_npc_panel_state.gd` 已覆盖“建筑修复中点击 NPC 后不自动切回建筑面板”的回归用例。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`godot --headless --path . --quit-after 1`。

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

## T0004 建立 GM 调试面板与验证工作流

状态：Done
优先级：P0
涉及文档：`AGENTS.md`, `GM_PANEL.md`, `UI_UX.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`

任务目标：

把 M1 到 M4 已完成但难以直接在主界面验证的关键能力，集中暴露到可拖动的半透明 GM 调试入口中，方便用户在 `Main.tscn` 内直接触发和观察。

实现范围：

- 新增可通过代码常量开关的 GM 调试 UI。
- GM 按钮可拖动、半透明，点击后打开 GM 面板。
- GM 面板提供命令输入框、执行按钮和结果输出区。
- GM 面板提供资源、时间、建筑、NPC、行动、记忆/见闻等 M1-M4 关键调试入口。
- GM 调试入口只调用已有系统接口，不引入新的权威结算系统。
- 新增 `docs/GM_PANEL.md`，记录使用说明、命令和维护规则。
- 在 `AGENTS.md` 工作流中加入规则：若当次实现的功能无法直接在前端验证，则同步给 GM 面板添加或替换调试入口，并更新 GM 文档。

验收标准：

- 启动 `Main.tscn` 后能看到 GM 按钮；代码中可用 true/false 切换显示。
- GM 按钮可拖动；点击可打开/关闭面板。
- 命令输入框可执行常用 GM 命令并显示结果。
- 面板按钮可触发现有资源、时间、建筑、NPC、行动、记忆/见闻调试接口。
- 项目加载无报错，已有 M1-M4 验证脚本回归通过。
- `AGENTS.md`、`docs/GM_PANEL.md`、`docs/MODULE_INDEX.md` 和相关模块文档已回写。

验收结果（2026-05-24）：

- 已新增 `res://scripts/ui/GMPanel.gd`，顶部 `GM_ENABLED` 常量可用 `true` / `false` 切换开发/上线显示。
- 已在 `res://scenes/main/Main.tscn` 的 `Main/UI/GMPanel` 接入 GM 调试面板；启动后显示半透明可拖动 `GM` 按钮，点击可打开面板。
- 面板顶部命令输入框支持 `help`、`add_resource`、`set_time`、`damage_building`、`enter_location`、`work`、`give_money`、`memory`、`location`、`events` 等命令。
- 面板按钮已覆盖资源、时间、建筑、NPC、行动、记忆/见闻/广场公告等 M1-M4 关键调试入口，只调用现有系统接口或 `debug_*` 接口。
- 已新增 `docs/GM_PANEL.md`，记录开关、界面、分组、命令、维护规则和验证方式。
- 已将“前端不可直接验证的关键功能需要加入或替换 GM 面板入口，并同步更新 GM 文档”写入 `AGENTS.md` 工作流。
- 已新增 `tools/verify_gm_panel.gd`，验证 GM 面板加载、窗口打开、资源命令、建筑受损、设置时间、NPC 进入地点、给钱事件、广场公告和结果输出。
- 已通过 `godot --headless --path . --script res://tools/verify_gm_panel.gd` 和 `godot --headless --path . --quit-after 1` 验证；回归验证见 `DEV_LOG.md`。

---

## T0005 Harden Godot MCP proxy restart

状态：Done
优先级：P0
涉及文档：`CURRENT_STATE.md`, `DEV_LOG.md`

验收标准：
- `godot-mcp-proxy.mjs` 启动时会检查同一个 Codex 父进程下的旧 proxy 残留，并替换它，避免同一会话出现多个 proxy。
- `tools/check_godot_mcp.ps1` 可以区分“多 proxy”“proxy 在但 broker 不在”和“正常连接”状态。
- 保留 `proxy -> broker -> Godot` 结构，不回退到多会话直接连接 Godot `6550`。

验收结果（2026-05-25）：
- 本次排查确认真实问题是同一个 `codex` 父进程下残留 2 个 `godot-mcp-proxy.mjs`，其中 1 个没有对应 broker 子进程，属于孤立 proxy。
- 已更新 `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`，启动时会读写 `%USERPROFILE%\.codex\godot-mcp-proxy.lock`，并按同一个 `codex` 父进程枚举所有旧 proxy；命中后先清理其余残留实例再接管，并在退出时清理自己的 lock。
- 已更新 `tools/check_godot_mcp.ps1`，新增“多 proxy”和“proxy 在但 broker 不在”的明确提示。
- 最终验证：MCP 可正常响应 `project.addon_status` 和 `editor.get_state`，自检返回 `Godot MCP connected`，进程只剩 1 条有效的 `proxy -> broker` 链路。

复盘补充（2026-06-02）：
- 这次故障表现为 Codex 内的 Godot MCP 工具返回 `Transport closed`；同时项目自检曾仍返回 `Godot MCP connected`，说明 Godot 插件和 broker 到 Godot 的连接不是第一故障点。
- 清理残留 headless Godot 进程并重启 broker 后，broker health 和 listTools 均正常；但已关闭的 Codex stdio MCP transport 无法在同一会话中热恢复，需要重启/刷新 Codex 后重新建立。
- 后续排查顺序：先运行 `tools/check_godot_mcp.ps1`，再区分 `Godot 插件监听`、`broker 健康`、`Codex MCP transport` 三层；不要把 `Transport closed` 直接等同于 Godot 插件掉线。
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
- 主厅前公告牌视觉占位（非建筑）

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

- 已在 `res://scenes/main/Main.tscn` 中补齐 T0103 所列低模空间占位：主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、主厅前公告牌视觉占位。
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

- 已扩展 `data/building_defs.json`，覆盖主厅、宿舍、食堂、仓库、围墙、城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊 15 个建筑/门墙实体。T0206 已将公告牌移出建筑定义。
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
- 建筑升级与修复一样是倒计时作业，不瞬间完成。
- 受损、正在修复或正在升级的建筑不可开始升级。

验收结果（2026-05-20）：

- 已在 `BuildingSystem.gd` 中实现 `can_repair_building`、`repair_building`、`can_upgrade_building`、`upgrade_building` 和临时验证用 `debug_damage_building`。
- 修复/升级消耗由 `ResourceSystem.spend_resources` 权威结算；资源不足时返回失败，不扣除资源，不改变建筑状态。
- 已在 `data/building_defs.json` 为主厅、宿舍、食堂、仓库、围墙加入 `repair` / `upgrade` 配置；围墙升级会提升等级和 Max HP。不可进入建筑不再保留内部工位占位。
- `BuildingPanel.gd` 的修复/升级按钮现在会触发系统接口，并根据当前 HP、等级和资源是否足够自动启用/禁用。
- 已新增 `tools/verify_building_repair_upgrade.gd` 验证：围墙受损后可用石料修复，升级消耗石料并改变等级、Max HP，石料不足时升级失败且资源不变；不可进入围墙不会暴露内部工位。
- 已通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`--quit-after 1` 和 Godot MCP 主场景运行验证；游戏日志无报错。

修订结果（2026-05-24）：

- 修复从“点击后瞬间恢复 HP”改为“点击时一次性扣除资源并创建倒计时修复作业”；修复中 HP 随 TimeSystem 逻辑时间逐步提高。
- 修复时长按缺失 HP、建筑等级和 `repair.seconds_per_missing_hp` / `repair.level_time_factor` 计算；缺失 HP 越多、等级越高，耗时越长。
- `get_building(...)` 会返回 `repair_status`，包含进度、剩余时间、目标 HP、协助人数和当前速度倍率。
- NPC 可通过 `ActionSystem.debug_assign_repair_assist(npc_id, building_id)` 协助正在修复的建筑；每名协助者按工程熟练度提供小额加速，多个 NPC 可叠加。
- 已更新 `tools/verify_building_repair_upgrade.gd`，验证修复不再瞬间恢复、资源预付、HP 随时间推进并最终回满。

修订结果（2026-05-25）：

- 升级从“点击后瞬间提升等级”改为“点击时一次性扣除资源并创建倒计时升级作业”；倒计时完成后才提升等级、Max HP 和可配置的工作位奖励。
- `can_upgrade_building(...)` 现在要求建筑完好，且不处于修复或升级作业中；受损、正在修复、正在升级或资源不足时都不可升级。
- 所有建筑定义都具备 `repair` / `upgrade` 最小配置；不可进入建筑升级不再增加内部工位。
- `get_building(...)` 会返回 `upgrade_status`，包含进度、剩余时间、协助人数和当前速度倍率。
- 已更新 `tools/verify_building_repair_upgrade.gd`，验证所有建筑可修复且有升级潜力、受损/修复中不可升级、升级不会瞬时完成、升级期间不可修复，且完成后清除升级状态。

---

## T0206 将公告牌移出建筑数据结构

状态：Done
优先级：P0
前置任务：T0203, T0404
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`, `MEMORY_AND_INFO_SPACE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`

任务目标：

明确公告牌不是建筑，避免在建筑系统、建筑数据结构和文档中误导为具备 HP / 等级 / 工作位 / 修复 / 升级的实体。

验收结果（2026-05-24）：

- 已从 `data/building_defs.json` 删除 `notice_board` 建筑定义，建筑定义数量调整为 15。
- `Main.tscn` 中的 `NoticeBoard` 模型保留为主厅前视觉占位和后续公告输入/显示接口，不再由 `BuildingSystem` 绑定点击区、HP 标签或建筑面板。
- 公告文本继续由广场状态保存，写入后通过 `MemorySystem` 生成 `plaza_notice_changed` 并广播给当前在广场的 NPC。
- 已同步更新建筑、数据结构、记忆信息、Godot 架构、模块索引、当前状态和任务文档。

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
- 调试指派会复用 `NPCSystem.move_npc_to_building(...)`；2026-05-25 起，NPC 到达目标建筑后进入持续行动，并随逻辑时间结算。
- 菜园工作可产出粮食；食堂工作可消耗粮食产出餐食；酒窖可消耗粮食产出酒；铁匠铺可消耗铁和木材产出武器/盔甲；工械坊可消耗木材产出工程器械；马厩可消耗粮食产出马匹整备占位；吃饭优先消耗餐食并恢复更多饱食度，没有餐食时消耗粮食；睡觉降低疲劳。
- 已修正无产出工作不会结算饱食/疲劳和 EventLog 的问题。
- `MemorySystem` 已提供最小 EventLog 占位，行动成功/失败会写入事件。
- 已通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 验证吃饭、睡觉、基础生产、派生资源生产和建筑协助修复；并回归通过 `verify_npc_movement_location.gd`、`verify_npc_panel_state.gd`、`verify_npc_generation_click.gd`；通过 Godot MCP 运行主场景，游戏日志无报错。

修订结果（2026-05-25）：

- `ActionSystem` 的工作 / 吃饭 / 睡觉不再在抵达地点后瞬时完成；抵达后会进入 active 行动，随 `TimeSystem.logical_time_tick` 推进。
- `data/action_defs.json` 改用 `duration_seconds` 表达当前行动时长：工作 3600 秒、吃饭 1200 秒、睡觉 23400 秒。
- 吃饭当前以 20 分钟恢复约 50 点饱食度为基准；睡觉以 6.5 小时降低 100 点疲劳为基准；工作当前仍以 1 小时为最小工作批次，批次完成时结算投入、产出、饱食和疲劳。
- 行动开始事件仍即时写入；完成事件只在持续时间结束后写入。暂停时 active 行动不推进，恢复后继续。
- 已更新 `tools/verify_action_system_basic.gd`、`tools/verify_structured_memory_events.gd`、`tools/verify_action_local_public_broadcast.gd` 和 `tools/verify_npc_short_term_memory_container.gd`，验证持续行动和事件广播。
- `ActionSystem` 新增 `debug_assign_upgrade_assist(npc_id, building_id)`；协助修复/协助升级都是带建筑参数的广场行为，NPC 在室内时会先前往广场，再按工程熟练度加速目标建筑倒计时。
- 协助修复/协助升级开始会分别写入 `repair_assist_started` / `upgrade_assist_started` 广场本地公开事件，`location_id == "plaza"` 且 `visibility == "local_public"`；完成后协助 NPC 回到 idle，并写入 `completed_assist_*_<building_id>` 行动结果。
- 已更新 `tools/verify_action_system_basic.gd`，验证协助修复/协助升级发生在广场、事件为广场公开、可提高速度倍率并推进作业完成。

修订结果（2026-05-24）：

- 围墙修补行动不再直接恢复建筑 HP，改为协助已有修复作业；修复资源由 `BuildingSystem.repair_building(...)` 在开始修复时一次性扣除。
- `ActionSystem` 新增 `debug_assign_repair_assist(npc_id, building_id)`；协助修复是一个带建筑参数的统一行为，不再在 `data/action_defs.json` 中保留按建筑写死的“修补围墙”行动。
- 协助修复开始事件已在 2026-05-26 修订为广场本地公开事件：`location_id == "plaza"`，`visibility == "local_public"`，目标建筑保存在 `payload.building_id`。
- 已更新 `tools/verify_action_system_basic.gd`，验证 NPC 协助修复可提高速度倍率、离开广场会移除协助人数和加成、重新协助可推进修复完成并在完成后回到 idle。

修订结果（2026-05-24 UI/GM 清理）：

- `BuildingPanel` 不再把修复/升级资源消耗常驻显示在面板正文中；悬停修复/升级按钮时才在按钮旁显示消耗和条件提示。
- `GMPanel` 的行动下拉不再出现固定“修补围墙”行动；行动分组新增“修复目标”建筑下拉，协助修复统一通过 `assist_repair <npc_id> <building_id>` 命令或“协助修复”按钮携带该建筑参数。
- 建筑操作提示框会在靠近屏幕边缘时自动保持在可视区域内，避免升级/修复按钮靠边时提示框跑出屏幕。
- 已把“资源/条件提示默认放在操作入口悬浮提示框，不堆在信息面板正文”的 UI 原则写入 `docs/UI_UX.md` 和 `game_design.md`。

---

# M4：时间系统、事件系统与信息节点

目标：让一天 24 阶段运转起来，并建立事件、地点/广场即时广播和 NPC 见闻库，为 AI 记忆做准备。地点/建筑节点只保存当前状态，不保存事件历史。

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

状态：Done
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
- 查询 `location_id == "plaza"` 且 `visibility == "local_public"` 的广场事件；广场节点本身不保存事件历史。
- 对现有 ActionSystem 行动完成/失败事件做兼容迁移。
- `target_ids` 支持 NPC、地点、建筑、行动、资源、敌人等不同 ID，不把它当成单一自然语言宾语。
- 每种事件类型定义确定性 summary 模板和 payload schema；summary 不使用 LLM 生成，也不依赖通用主宾语自动拼句。

禁止事项：

- 不实现知识图谱。
- 不实现日记。
- 不接 LLM。
- 不实现地点/广场即时广播逻辑，那是 T0403/T0404。
- 不实现“万能事件句子生成器”；必须按事件类型模板格式化 summary。

验收标准：

- 行动、点击测试或调试按钮能写入结构化事件。
- 至少工作完成、吃饭完成、睡觉完成、行动失败能写入带 `subject_npc_id`、`location_id`、`visibility` 和 `payload` 的事件。
- 能通过调试接口查询某 NPC 当天事件库。
- 能通过调试接口查询全局事件索引。
- 至少为 `location_entered`、`work_started`、`work_completed`、`work_failed`、`eat_completed` 定义 summary 模板和必需 payload 字段。
- `DATA_SCHEMA.md` 与事件结构一致。

验收结果（2026-05-23）：

- `MemorySystem` 已升级为结构化事件事实源，支持全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场公开事件查询；地点/广场节点不作为事件历史存储，不提供按地点查询事件接口。
- 已预留 T0402 要求的事件类型，并为 `location_entered`、`work_started`、`work_completed`、`work_failed`、`eat_completed` 等实现确定性 summary 模板与必需 payload 字段声明。
- `ActionSystem` 的工作、吃饭、睡觉和失败路径已迁移为结构化事件；`NPCSystem` 到达地点时会写入 `location_entered` 事件。
- 已新增 `tools/verify_structured_memory_events.gd`，验证结构化字段、NPC 事件库、全局索引、广场公开查询和 payload schema；同时回归 `tools/verify_action_system_basic.gd`。

---

## T0403 实现地点信息节点与进入快照

状态：Done
优先级：P0
前置任务：T0203, T0402
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`

任务目标：

为可进入地点建立信息节点，并在 NPC 进入地点时生成地点状态快照。信息节点只保存当前状态和在场人员，负责状态广播与公开事件转运，不保存事件历史。

实现范围：

- 可进入地点拥有信息节点：广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊。
- 不可进入实体不建常规进入空间：主厅、围墙、城门、后门、仓库。
- 地点信息节点记录 `people_present`、建筑外部状态、可进入建筑内部状态、工作位/床位占用和当前公告；公告文本只保存在广场状态中，公告牌只是主厅前输入/显示接口。
- NPC 进入地点时写入 `location_entered` 事件。
- `location_entered` 只记录进入行动；进入时地点状态应作为进入者的一次性见闻写入，完整状态不重复进入事件库。
- 所有建筑的外部状态归入广场状态快照；不可进入实体不暴露工位和内部 NPC。
- 地点状态发生变化时，向当前在场 NPC 广播状态变化；NPC 把收到的信息写入见闻库。
- 建筑内发生 `local_public` 事件时，事件即时广播给当前在场 NPC，广播后建筑/地点节点不保存该事件。

禁止事项：

- 不做 LLM 总结。
- 不做复杂传播算法。
- 不做建筑内部模型细化；这里只做数据空间。

验收标准：

- NPC 进入可进入地点后，地点 `people_present` 更新。
- NPC 离开地点后，地点 `people_present` 更新。
- 进入者的见闻库包含当前在场 NPC、这些 NPC 的生命状态/行动状态、建筑等级、完好/受损/正在修复/正在升级、工作位/床位占用和当前公告/命令；建筑 HP、剩余修复/升级时长和工位数量不作为传播状态。
- NPC 进入广场时，payload 包含当前广场在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态。
- 建筑发生 `local_public` 事件后即时广播给该建筑内当前在场 NPC，并写入接收者见闻库；建筑节点不保存事件。

验收结果（2026-05-24）：

- `MemorySystem` 已建立广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊的信息节点，维护 `people_present`、当前公告/命令和进入快照。
- `NPCSystem` 到达地点时会调用 `MemorySystem.move_npc_between_locations(...)` 更新离开/进入地点的在场人员；T0407 后，地点快照只作为进入者的一次性见闻写入，不再复制到 `location_entered` 事件。
- 进入快照已包含当前在场 NPC、这些 NPC 的生命状态/行动状态、建筑等级、完好/受损/正在修复/正在升级、工位/床位占用字段和当前公告/命令；进入广场时会聚合所有建筑可传播外部状态。
- `local_public` 事件会即时广播给事件地点当前在场 NPC，并写入接收者见闻库；地点信息节点不保存事件历史。
- 新增 `tools/verify_location_info_nodes.gd` 验证地点人数进出、进入快照、广场关键实体状态和 `local_public` 见闻转发，并回归 T0402 结构化事件与 T0305 行动闭环。

修复记录（2026-05-24）：

- 修复行动事件可见性漏设问题：`ActionSystem` 写入的工作、吃饭、睡觉开始/完成/失败事件从 `private` 改为 `local_public`，因此同一地点当前在场 NPC 会把这些活动/工作事件写入见闻库。
- 新增 `tools/verify_action_local_public_broadcast.gd`，验证 NPC 在同一地点目击工作、吃饭、睡觉事件时能收到 `work_started` / `work_completed`、`eat_started` / `eat_completed`、`sleep_started` / `sleep_ended` 见闻，且行动者不会把自己的事件重复写为见闻。

修复记录（2026-05-25）：

- 地点进入时当前实现会额外生成一次当前状态见闻广播：进入广场获得当前广场在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态，进入可进入建筑获得该建筑外部 + 内部状态。新规则要求该完整状态只写给进入者的见闻库一次，不再重复写入 `location_entered` 事件 summary / payload。
- 可进入建筑快照拆分为 `external_state` 与 `internal_state`；不可进入建筑只提供外部状态，不暴露工位和内部 NPC。
- `tools/verify_location_info_nodes.gd` 已补充广场继承所有建筑外部状态、外部状态不泄漏内部工位字段的验证。
- 建筑可传播外部状态只计算等级和完好/受损/正在修复/正在升级；HP、剩余修复/升级时长不触发地点状态广播。可传播内部状态只计算在场 NPC 和每个工位占用/空闲，工位数量不触发广播。
- T0407 已收敛：NPC 进入可进入建筑时，`location_entered` 只保留“进入某地”的行动事实；进入者收到的当前状态见闻包含该建筑外部状态、在场 NPC 和工位占用状态；已在建筑内的 NPC 只收到进入/离开事件，不再额外收到完整内部状态。
- 2026-06-02 补齐：进入可进入建筑的一次性状态见闻新增 `people_statuses`，用于表达建筑内 NPC 的生命状态（健康/受伤/昏迷，昏迷时可包含治疗者）与行动状态（由 `current_action` 翻译为精简中文）。2026-06-03 补齐：进入广场的一次性状态见闻也新增 `people_statuses`，用于表达广场当前在场 NPC 的生命状态与行动状态。已在地点内的 NPC 仍只收到进入/离开事件，不接收完整人员状态快照。

---

## T0404 实现广场公开信息即时广播

状态：Done
优先级：P0
前置任务：T0402, T0403
涉及文档：`MEMORY_AND_INFO_SPACE.md`

任务目标：

实现广场作为室外事件和所有建筑外部状态信息的公共信息中枢的机制，并让广场公开事件/状态即时广播给当时已经在广场的 NPC。
公开事件包括：

- 室外发生的公开事件
- NPC 昏迷
- NPC 复苏
- NPC 逃离或试图逃离
- 守备官攻击 NPC
- 战斗触发/结束


场景/建筑状态包括：
- 广场当前公告文本，以及每次状态变更时的信息传递
- 所有建筑的外部状态，以及每次状态变更时的信息传递
- 当前的NPC人数，敌人人数，以及每次状态变更时的信息传递

禁止事项：

- 不实现战斗本体。
- 不实现 LLM 解读。

验收标准：

- 调试触发公开事件/状态变更后，广场节点能把事件/状态广播给当前在场 NPC。
- 接收广播的 NPC 能把公开事件/状态变更写入见闻库。
- 室外事件默认 `location_id == plaza`。
- 广场没有建筑 HP，但能提供所有建筑外部状态快照。
- `MEMORY_AND_INFO_SPACE.md` 更新当前实现范围。

验收结果（2026-05-24）：

- `MemorySystem` 已将广场公开事件统一为 `location_id == "plaza"` 的 `local_public`，当前在广场的 NPC 会把事件写入见闻库。
- 室外或不可进入实体来源的本地公开事件会规范化为 `location_id == "plaza"`，并在 payload 中保留 `source_location_id`。
- 广场快照明确没有自身建筑 HP，并提供所有建筑可传播外部状态 `building_external_states` / `key_entities`，以及当前敌人数。
- 广场公告文本变更会更新广场当前状态，并生成 `plaza_notice_changed` 广场公开事件广播给当时在广场的 NPC；公告牌不作为建筑参与该流程。
- `BuildingSystem` 的任一建筑等级或完好/受损/正在修复/正在升级状态变化会经 `building_state_changed` 通知 `MemorySystem` 生成带具体建筑名的 `plaza_status_changed` 广场公开状态事件；HP 和剩余时间变化不触发广播。
- 新增 `tools/verify_plaza_local_public_broadcast.gd` 验证广场本地公开事件、公告变更、关键实体状态变更、广场快照字段和见闻库写入。

修复记录（2026-05-25）：

- 广场状态从“只继承不可进入实体/关键目标”修正为“继承所有建筑外部状态”。
- 建筑状态见闻 summary 不再只显示模糊的广场状态变化，而是写明具体建筑名、等级或完好/受损/正在修复/正在升级等实际信息，不加入“建筑状态更新”这类空泛前缀。
- 不可进入建筑在广场外部状态中不暴露工位、床位、内部 NPC 等内部信息。
- `tools/verify_plaza_local_public_broadcast.gd` 已补充全建筑外部状态、内部字段隔离和状态见闻命名验证。

---

## T0405 实现 NPC 短期记忆容器

状态：Done
优先级：P0
前置任务：T0402, T0403, T0404
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `AI_NPC_SYSTEM.md`

任务目标：

给每个 NPC 建立当天短期记忆容器，用于后续 LLM 输入。短期记忆由事件库和见闻库组成，不再混成一个文本列表。

实现范围：

- NPC 自身事件写入 `event_log`。
- NPC 当前在场时收到地点/广场公开事件广播、状态变化广播或公告更新时写入 `witness_log`。
- 玩家对 NPC 的非对话交互写入目标 NPC 的 `event_log`，并按可见性（后面玩家可以手动设置本次交互的可见性就像说话声音大小一样）通过地点/广场节点即时广播。
- 可查看 NPC 当前事件库、见闻库。

禁止事项：

- 不做睡前总结。
- 不接 LLM。
- 不做知识图谱更新。

验收标准：

- NPC 工作、吃饭、睡觉、被给予金钱、被攻击等事件进入事件库。
- NPC 在地点内接收到公开事件或状态变化广播后写入见闻库；
- NPC 面板或调试工具能区分查看事件库与见闻库。
- 每天结束时暂不清空，后续任务处理。

验收结果（2026-05-24）：

- `MemorySystem` 已提供 `get_npc_short_term_memory(...)` / `get_npc_short_term_memory_ids(...)`，运行时短期记忆明确拆分为当天 `event_log` 与 `witness_log`。
- 工作、吃饭、睡觉继续由 `ActionSystem` 写入目标 NPC 事件库；新增玩家非对话交互入口 `record_player_interaction(...)`，并提供 `debug_record_player_money_given(...)`、`debug_record_player_attack_npc(...)` 验证给钱和攻击事件写入。
- `local_public` 玩家交互会通过事件地点当前在场人员即时广播，接收 NPC 写入见闻库；广场交互使用 `location_id == "plaza"`，地点/广场节点仍不保存事件历史。
- `NPCPanel` 新增事件库和见闻库最近摘要显示，并监听 `npc_memory_changed` 刷新。
- 新增 `tools/verify_npc_short_term_memory_container.gd`，已验证事件库、见闻库、玩家交互和 NPC 面板区分显示；每天结束暂不清空。

修复记录（2026-05-25）：

- NPC 进入地点获得的当前地点状态会写入 `witness_log`；T0407 后不再同时保存在 `location_entered.payload.location_snapshot`。
- NPC 在广场时会收到任一建筑外部状态变化；NPC 在某个可进入建筑内时会收到该建筑工位变化。T0407 已将这些见闻精简为字段级差量，不再广播完整建筑状态。
- 建筑状态见闻会写明具体建筑，修复“广场上看到状态变化但不知道是哪座建筑受损/修复”的问题。
- HP、剩余修复/升级时长和工位数量不进入见闻传播状态，避免修复/升级过程中因为进度变化制造过密的信息传递。

---

## T0406 统一玩家交互事件世界内称呼

状态：Done
优先级：P0
前置任务：T0405
涉及文档：`game_design.md`, `MEMORY_AND_INFO_SPACE.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `DATA_SCHEMA.md`, `GM_PANEL.md`

任务目标：

避免 NPC 记忆、见闻、Prompt 摘要和后续教学/信件中把玩家写成世界外称呼“玩家”。所有 NPC 会看到或 LLM 会当作世界内事实理解的文本，统一把玩家称为“守备官”。

验收标准：

- `money_given`、`equipment_given`、`equipment_changed`、`order_assigned`、`npc_attacked_by_player` 等玩家交互 summary 使用“守备官”。
- 玩家交互事件的 actor id 使用稳定世界内 ID，不把 `player` 写入 NPC 事件 payload。
- 验证脚本覆盖给钱与攻击事件 summary 不包含“玩家”。
- 相关设计、记忆、NPC、Prompt、数据结构和 GM 文档确定该称呼规则。

验收结果（2026-05-24）：

- `MemorySystem.record_player_interaction(...)` 已将玩家交互 actor id 写为 `guard_officer`，payload 中写入 `actor_display_name = "守备官"`。
- `money_given`、装备/指派、攻击相关 summary 模板已从“玩家……”改为“守备官……”。
- `tools/verify_npc_short_term_memory_container.gd` 已补充给钱和攻击 summary 检查，确保包含“守备官”且不包含“玩家”。
- 已在设计源和相关模块文档中写入“NPC/LLM 世界内文本统一称呼守备官”的规则。

---

## T0407 精简地点事件与建筑状态见闻

状态：Done
优先级：P0
前置任务：T0403, T0405
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`

任务目标：

修正地点进入/离开和建筑状态传播的短期记忆冗余，让事件库只保存亲历行动事实，见闻库只保存必要信息。

实现范围：

- `location_entered` 事件只表达“某 NPC 进入了某地点”，写入进入者事件库；不再在 summary 或 payload 中携带完整建筑状态快照。
- NPC 进入广场或可进入建筑时，进入者在 `witness_log` 中获得一次当前状态快照；进入广场时该快照包含广场当前在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态；进入可进入建筑时该快照包含建筑外部状态、当前在场 NPC、建筑内 NPC 的生命状态/行动状态和工位/床位占用。
- 已经在该地点的 NPC 只收到 `location_entered` 本地公开事件，不再额外收到完整建筑状态、完整 `people_present` 或完整 `people_statuses`。
- NPC 离开地点时生成 `location_exited` 事件，`location_id` 为其离开的地点，写入离开者事件库，并以 `local_public` 广播给仍在该地点的 NPC。
- `location_exited` 不携带完整地点状态，也不额外广播建筑内 NPC 列表；人员变化由进入/离开事件本身表达。
- 建筑或地点状态变化时，只把变化字段写入见闻库，例如建筑受损、开始修复、修复完成、升级完成、公告变化或某个工位占用变化；未变化字段不随事件重复传递。
- 更新验证脚本，覆盖进入者一次性状态见闻、在场者只收进入/离开事件、离开事件地点正确、状态变化为字段级差量。

禁止事项：

- 不新增长期地点事件历史。
- 不让 UI 自行决定 NPC 见闻或建筑状态事实。
- 不把 HP、Max HP、剩余修复/升级时长或工位数量重新纳入 NPC 见闻传播。

验收标准：

- 进入者的事件库中 `location_entered` summary 只包含进入行动，不包含建筑等级、状态、在场 NPC 或工位状态。
- 进入者的见闻库中有且只有一次进入地点当前状态快照。
- 进入前已经在建筑内的 NPC 收到“某人进入了某地”见闻，但没有收到完整建筑状态快照。
- 离开者事件库中生成 `location_exited`，且事件 `location_id` 是离开的地点。
- 留在建筑内的 NPC 收到“某人离开了某地”见闻，但没有收到完整 `people_present` 快照。
- 建筑受损、修复、升级和工位占用变化只产生变化字段见闻，不复制完整建筑外部 + 内部状态。

完成记录：

- `MemorySystem.move_npc_between_locations(...)` 现在只维护地点 `people_present`，并给进入者写入一次 `location_entry_snapshot` 见闻；不再因人员进入/离开额外广播完整地点状态。
- `NPCSystem` 到达或调试进入新信息地点时写入 `location_entered`；离开旧信息地点时写入 `location_exited`，且离开事件的 `location_id` 使用被离开的地点。
- `location_entered` / `location_exited` payload 只保留进出地点 ID，不再携带 `location_snapshot`、完整 `people_present` 或工位状态。
- 建筑状态变化广播改为 `changed_fields` / `changed_workstations` 字段级差量；广场建筑状态见闻不再复制 `plaza_snapshot`、`building_external_states` 或完整 `building_snapshot`。
- `tools/verify_location_info_nodes.gd` 已升级为 T0407 验证；`tools/verify_plaza_local_public_broadcast.gd` 增加字段级状态见闻检查。
- 2026-06-02 补齐：`MemorySystem` 的可进入建筑快照新增 `people_statuses`，`location_entry_snapshot` summary 会写出“在场人员状态”；`tools/verify_location_info_nodes.gd` 已覆盖受伤 NPC 的生命状态和待命行动状态。
- 2026-06-03 补齐：`MemorySystem` 的广场快照也新增 `people_statuses`，进入广场的 `location_entry_snapshot` summary 会写出广场在场 NPC 的生命状态/行动状态；`tools/verify_location_info_nodes.gd` 已覆盖广场健康 NPC 的待命状态。

---

## T0408 收敛广场公开事件可见性

状态：Done
优先级：P0
前置任务：T0404, T0405, T0407
涉及文档：`game_design.md`, `MEMORY_AND_INFO_SPACE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`

任务目标：

移除事件可见性的第三种公开类型，让广场作为普通地点使用 `local_public` 广播。事件可见性只保留 `private` 和 `local_public`；广场公开事件统一表达为 `location_id == "plaza"` 且 `visibility == "local_public"`。

验收结果（2026-05-26）：

- `MemorySystem` 移除旧的广场专用公开类型分支，广场公告、广场状态、手动广场广播和协助修复/升级事件都以 `local_public` 写入 `plaza`。
- 广场事件查询接口改为 `get_plaza_events()` / `debug_get_plaza_events()`，筛选全局事件索引中的广场本地公开事件，不让广场信息节点保存事件历史。
- `ActionSystem` 的 `repair_assist_started` / `upgrade_assist_started` 改为 `visibility == "local_public"` 且 `location_id == "plaza"`。
- GM 面板可见性下拉只保留 `private` / `local_public`，攻击事件默认改为 `local_public`；广场广播按钮调用新的 `debug_broadcast_plaza_event(...)`。
- 旧广场专用广播验证脚本已替换为 `tools/verify_plaza_local_public_broadcast.gd`，并同步更新结构化事件、短期记忆和行动系统验证脚本。

---

## T0409 补齐广场进入快照与室内经由广场移动链

状态：Done
优先级：P0
前置任务：T0403, T0407, T0408
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`

任务目标：

补齐两个地点信息节点细节：NPC 进入广场时，进入者的一次性 `location_entry_snapshot` 见闻必须包含广场当前在场 NPC 与当前公告文本；NPC 从一个室内地点前往另一个室内地点时，逻辑事件链必须先离开原地点、进入广场、离开广场，再进入目标地点。

验收标准：

- 进入广场的快照 payload 与 summary 都能表达当前广场在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和建筑外部状态。
- 室内到室内切换时，事件库按顺序出现 `location_exited(原地点 -> plaza)`、`location_entered(plaza)`、`location_exited(plaza -> 目标地点)`、`location_entered(目标地点)`。
- 地点 `people_present` 最终只保留 NPC 所在的目标地点，广场不会残留错误在场人员。
- 已有地点信息节点、短期记忆和行动系统回归验证通过。

验收结果（2026-05-26）：

- `MemorySystem` 的广场 `location_entry_snapshot` summary 现在会同时写出广场当前在场 NPC、这些 NPC 的生命状态/行动状态、当前公告牌文本和所有建筑可传播外部状态。
- `NPCSystem` 在室内信息地点切换到另一个室内信息地点时，会先按逻辑事件链切到 `plaza`，再进入目标地点；当前物理移动仍保持低模直线占位。
- `debug_enter_location_immediately(...)` 和正常移动到达回调共用同一套地点切换逻辑，避免调试路径与运行路径分叉。
- `tools/verify_location_info_nodes.gd` 已覆盖广场进入快照和室内经由广场事件链；`tools/verify_npc_movement_location.gd` 已按不可进入仓库归入广场信息节点的当前架构更新。

---

# M5：昏迷、治疗与基础医疗闭环

目标：实现 NPC 不死亡机制。HP 清零后昏迷，其他人可协助治疗，HP 到 30% 后复苏。

---

## T0501 实现 HP 扣除与昏迷状态

状态：Done
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
- 昏迷事件按照 `local_public` 公开到昏迷时所处的建筑节点并传播到同一个建筑内的NPC的见闻库。

禁止事项：

- 不实现敌人战斗。
- 不实现治疗。
- 不实现自然恢复。

验收标准：

- 使用调试扣血可让 NPC 昏迷。
- 昏迷状态在 NPC 面板显示。
- 昏迷 NPC 无法执行行动。
- 事件可见于同个建筑的其他NPC见闻库。

验收结果（2026-05-26）：

- `NPCSystem` 新增 `apply_damage_to_npc(...)` / `debug_damage_npc(...)`，权威扣除 NPC HP；HP 降到 0 后设置 `unconscious=true`、`current_action=unconscious` 并停止移动。
- `ActionSystem` 会在 NPC 昏迷后清除 pending / active 行动，后续工作、吃饭、睡觉、协助修复/升级等调试指派都会被拒绝；`NPCSystem.move_npc_to_building(...)` 也拒绝移动昏迷 NPC。
- 昏迷时写入 `damage_taken` 与 `unconscious_started` 结构化事件；昏迷事件使用 `local_public` 发送到 NPC 当前信息地点，同地点 NPC 会收到见闻。
- `NPCPanel` 与 NPC 头顶标签会显示昏迷状态；`EventBus` 增加 `npc_hp_changed` / `npc_unconscious` 信号供后续战斗、治疗和 UI 扩展。
- GM 面板 `attack_npc` / `damage_npc` 命令现在调用 NPC 扣血接口，而不是只写记忆事件；新增 `tools/verify_npc_damage_unconscious.gd` 覆盖扣血、昏迷、行动阻断和同地点见闻传播。
- 验证通过：`verify_npc_damage_unconscious.gd`、`verify_gm_panel.gd`、`verify_action_system_basic.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`。

---

## T0502 实现昏迷自然恢复

状态：Done
优先级：P0
前置任务：T0501, T0401
涉及文档：`COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`

任务目标：

让昏迷 NPC 随时间非常缓慢的恢复 HP。

规则：

- 昏迷状态下每小时恢复少量 HP。
- HP 达到 Max HP 的 30% 后复苏。
- 复苏后重新允许行动。
- 复苏事件进入 NPC 事件库，并按规则公开到所在建筑（local public）。

禁止事项：

- 不实现治疗加速。

验收标准：

- 昏迷 NPC 随时间恢复。
- 到 30% 后自动复苏。
- 复苏后状态正确刷新。
- 事件写入 NPC 事件库并公开信息。

验收结果（2026-05-26）：

- `NPCSystem` 监听 `TimeSystem.logical_time_tick`，昏迷 NPC 每游戏小时自然恢复 2 HP；暂停时没有逻辑 tick，因此不会恢复。
- HP 达到 Max HP 的 30% 后，NPC 自动复苏，`unconscious=false`、`current_action=idle`，并重新允许移动和行动指派。
- 复苏会写入 `revived` 结构化事件，事件按 NPC 当前信息地点以 `local_public` 广播给同地点 NPC。
- `EventBus` 新增 `npc_revived(npc_id)` 信号；`MemorySystem` 增加 `revived` payload 校验与确定性 summary。
- GM 面板新增 `recover_npc <npc_id> <game_seconds>` 命令，只调用 `NPCSystem.debug_advance_unconscious_recovery(...)`，用于前端快速验证自然恢复与复苏。
- 新增 `tools/verify_npc_unconscious_natural_recovery.gd` 覆盖自然恢复、30% 自动复苏、事件/见闻写入和复苏后可行动。
- 验证通过：`verify_npc_unconscious_natural_recovery.gd`、`verify_gm_panel.gd`、`verify_npc_damage_unconscious.gd`、`verify_action_system_basic.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_location_info_nodes.gd`、`godot --headless --path . --quit-after 1`。

---

## T0502A 昏迷/睡觉期间停止接收见闻

状态：Done
优先级：P0
前置任务：T0502
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `AI_NPC_SYSTEM.md`, `COMBAT_SYSTEM.md`

任务目标：

补充不可接收现场信息状态的信息规则：昏迷 NPC 不接收地点/广场公开广播或进入快照，见闻库暂停更新，直到复苏；睡觉 NPC 也不接收同地点/同建筑公开广播、状态广播、公告或进入快照，直到睡醒。

验收结果（2026-05-26）：

- `MemorySystem.add_witness_event(...)` 在写入见闻前检查 NPC 状态；若 `unconscious=true`，直接拒收见闻。
- 该规则覆盖地点 `local_public` 广播、广场公开广播、建筑/地点状态广播和进入快照等所有统一走 `add_witness_event(...)` 的见闻写入路径。
- 昏迷 NPC 自己的亲历事件库不受影响，仍会记录 `damage_taken`、`unconscious_started` 和后续 `revived`。
- 复苏后见闻接收自动恢复。
- `tools/verify_npc_unconscious_natural_recovery.gd` 已补充昏迷期间拒收见闻、复苏后重新接收见闻的验证。

补充验收结果（2026-06-03）：

- `MemorySystem.add_witness_event(...)` 的接收判定扩展为：若 `current_action == "sleep_in_dormitory"`，同样拒收见闻。
- 该规则覆盖睡觉者所在地点/建筑内发生的 `local_public` 事件、建筑/地点状态广播、公告和进入快照；睡醒后从后续广播开始恢复接收，不补收睡觉期间错过的信息。
- 睡觉 NPC 自己的亲历事件库不受影响，仍记录 `sleep_started` / `sleep_ended`。
- `tools/verify_action_local_public_broadcast.gd` 已补充睡觉期间拒收同建筑 public 见闻、睡醒后重新接收的验证。

---

## T0503 实现治疗昏迷 NPC

状态：Done
优先级：P0
前置任务：T0502, T0305
涉及文档：`AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`

任务目标：

让其他NPC能够治疗（根据协助治疗的NPC的医术技能点的大小加速其昏迷苏醒倒计时）昏迷 NPC。

规则：

- 其他NPC可对昏迷NPC进行治疗。
- 治疗随时间消耗金钱。
- 医术熟练度影响治疗加速苏醒的倍率。
- 治疗事件写入目标 NPC 和医生的结构化事件（xx开始协助治疗xx，就像协助修复建筑一样），治疗是local public。
- 治疗这个行为加入NPC们的可选行为列表，并且可以指定目标（只有在昏迷状态的目标可被治疗）（这种对昏迷者的治疗和后面要加的NPC主动去诊所治疗是不一样的两个功能）
- 每个昏迷NPC最多有两个人可以参与治疗。

禁止事项：

- 不实现复杂药品。
- 不实现医疗床位复杂管理。
- 不接 LLM。

验收标准：

- 其他NPC能对昏迷 NPC 执行治疗
- 治疗比自然恢复更快根据。治疗者的医术熟练度决定倍率大小（函数需要医术很低时几乎没有加成，只有医术达到一定水平（比如游戏内医生的技能点）才会有明显加成）
- 资源不足时治疗失败
- 事件记录和广播完整

验收结果（2026-06-02）：

- `ActionSystem` 新增 `debug_assign_heal_assist(healer_npc_id, target_npc_id)`，治疗者会前往昏迷目标所在信息地点后开始协助治疗；目标必须处于昏迷状态，且每个昏迷目标最多 2 名治疗者。
- 治疗开始立即消耗 1 枚第纳尔，持续治疗期间每 1800 游戏秒继续消耗 1 枚第纳尔；第纳尔不足时治疗指派失败或治疗中止。
- `NPCSystem.assist_unconscious_recovery(...)` 按医术熟练度为昏迷恢复增加额外 HP / 小时；低于阈值的医术几乎没有额外加成，医生 `doctor_01` 的高医术会明显快于自然恢复。
- `MemorySystem` 增加 `healing_started` / `healing_completed` payload 校验与确定性 summary；治疗开始/完成会分别写入治疗者和目标 NPC 的事件库，并写入同地点其他在场 NPC 的见闻库；事件信息不暴露医术熟练度。
- `ActionSystem` 提供只读 `get_healing_helpers_for_target(...)`，供 `MemorySystem` 在地点 NPC 状态快照中写明昏迷者当前是否有人治疗以及治疗者是谁。
- `data/action_defs.json` 新增需要目标 NPC 的 `assist_heal` 行动定义；普通 `assign_action` 不直接执行该参数化行动，必须通过带目标的协助治疗接口。
- GM 面板新增“治疗目标”NPC 下拉、协助治疗按钮和 `assist_heal <healer_npc_id> <target_npc_id>` 命令。
- 新增 `tools/verify_npc_unconscious_healing.gd` 覆盖治疗开始、两人上限、持续扣钱、医术加速、复苏、资源不足失败、治疗事件归属和旁观者见闻。
- 2026-06-02 补齐：`tools/verify_npc_unconscious_healing.gd` 已覆盖小诊所快照中昏迷目标的治疗者信息，以及治疗者 `current_action` 被翻译为“协助治疗某人”。
- 验证通过：`verify_npc_unconscious_healing.gd`、`verify_gm_panel.gd`、`verify_npc_unconscious_natural_recovery.gd`、`verify_npc_damage_unconscious.gd`、`verify_action_system_basic.gd`、`verify_structured_memory_events.gd`、`verify_npc_short_term_memory_container.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`。

---

# M6：后端 LLM 接口骨架与 Mock AI

目标：先建立 Godot 与后端的 AI 通信闭环，但默认使用 Mock，不依赖真实模型，不消耗额度。

---

## T0601 创建后端 Schema

状态：Done
优先级：P0
前置任务：T0002
涉及文档：`TECH_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `PROMPTS.md`

任务目标：

在后端创建请求/响应数据结构。

需要覆盖：

- NPC 对话（包括NPC之间对话以及玩家与NPC对话）请求/响应
- 每日计划请求/响应
- 计划执行失败/异常时对计划的重新评估和修订的请求/响应
- 战斗判定请求/响应
- 睡前总结请求/响应
- 以及其他game_design.md里必须的前后端交互情形，尤其是所有需调用LLM的情形（大部分情形应该已经列出）。

禁止事项：

- 不调用真实模型。
- 不实现复杂业务逻辑。

验收标准：

- `backend/schemas/` 中有清晰的数据模型。
- 后端启动无报错。
- 文档与字段一致。

验收结果（2026-06-03）：

- 已新增 `backend/schemas/common.py`，定义 `GameTime`、`ModelRequestMeta`、NPC 上下文、短期记忆摘要、行动候选和通用错误响应。
- 已新增 `backend/schemas/npc_ai.py`，覆盖 NPC 对话（玩家-NPC、NPC-NPC、逃离挽留）、每日计划、计划异常重评估、战斗判定、睡前总结、知识图谱更新、主动找守备官交涉和玩家话术分类的请求/响应模型。
- 已新增 `backend/schemas/__init__.py` 和 `backend/schemas/README.md`，提供统一导出和 schema 边界说明；schema 只表达意图、文本、主观判断和计划建议，不执行真实 LLM 调用，也不改变 HP、资源、建筑或战斗权威结果。
- 已新增 `tools/verify_backend_schemas.py`，验证 schema 可导入、关键请求/响应可实例化、每日计划响应必须包含 24 条计划项。
- 验证通过：`python tools/verify_backend_schemas.py`、`python -m py_compile backend/schemas/common.py backend/schemas/npc_ai.py backend/schemas/__init__.py tools/verify_backend_schemas.py`、Flask `create_app().test_client().get("/health")` 返回 200。

---

## T0602 实现 Mock Model Adapter

状态：Done
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

- 不接真实 DeepSeek

验收标准：

- `.env` 不存在时默认 mock。
- 调用后端接口返回合法 JSON。
- 失败时返回明确错误，不让 Godot 卡死。

验收结果（2026-06-03）：

- `backend/services/model_adapter.py` 默认 provider 改为 `mock`；`.env` 不存在或未设置 `LLM_PROVIDER` 时可直接返回 Mock 结果。
- `ModelAdapter.generate(call_type, payload)` 支持按调用类型返回不同稳定 JSON，当前覆盖 `dialogue`、`plan_day`、`revise_plan`、`battle_judgement`、`daily_reflection`、`knowledge_graph_update`、`proactive_intention`、`player_strategy_classification` 和通用兜底响应。
- Mock 返回会记录调用用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用、成功/失败状态；mock 费用固定为 0。
- `backend/app.py` 新增 `POST /mock/model` 调试接口；非法 JSON / 非对象 payload 返回 400，非 mock provider 且未配置 `LLM_API_KEY` 返回明确 503 错误。
- 已新增 `tools/verify_mock_model_adapter.py`，验证默认 mock、schema 合法性、24 小时计划、伪 token 记录、非 mock 失败和 HTTP 调试接口。
- 验证通过：`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_mock_model_adapter.py tools/verify_backend_schemas.py`。

---

## T0603 实现 `/npc/dialogue` Mock 接口

状态：Done
优先级：P0
前置任务：T0601, T0602
涉及文档：`TECH_ARCHITECTURE.md`, `PROMPTS.md`, `AI_NPC_SYSTEM.md`

任务目标：

实现 NPC 对话（NPC之间的对话以及NPC和玩家的对话）接口。注意：这个任务我临时增改、具体设计了一下，所以如果有当前无法完成的部分，要按照这一版的T0603任务内容增改到后面的对话数据任务里，如有冲突以当前的T0603为准。

输入：

- npc_id
- npc_name
- npc_setting（目标NPC人设的各种设定）
- speaker_name （说话者的名称，如果是玩家，名称为“守备官”）
- player_text/说话的NPC text
- speaker_context（如果发起的对话的是NPC/是NPC之间的对话，如果是NPC发起对话的话，发起者的健康/受伤状态和外表特征（储存在NPC信息库里）也会一并输入；如果是玩家（守备官）发起，守备官的外表特征也会一并输入）
- is_recruitment_request（如果是player对话，玩家将会有一个可勾选的发起recruit选项）
- 对话轮次
- npc_state （包括目标NPC的各种属性（力量智力）、熟练度、健康/受伤、饱食度疲劳度、金钱、装备、是否已入伍等NPC信息系统里代表当前自身状态的东西）
- dialogue_state (当前对话的公开性，对话可选local Public或private，前者会把对话结果作为事件暴露给所在建筑的其他人，按照事件逻辑；后者只会让对话结果进入两个人的事件库)
- short_memory（NPC的事件库（事件库里既有自己的行动事件也有对话事件以及内容，要注意，A与B的对话都会进入A和B的事件库而非见闻库，只有A与B的公开对话才会进入同一建筑里的第三者见闻库）和见闻库里的信息）
- long_memory （长期记忆，包括知识图谱和日记）
- location_context （当前对话发生的地点快照，也就是当前所在建筑的状态，比如是否受损，建筑内部的工位状态，内部的NPC及其状态）


输出分情况：
如果是回复玩家：
- replyer id
- reply text
- recruitment_result：none / accept / reject

如果是回复NPC（NPC之间的对话）：
- reply text
- 是否结束对话

回复者的text要再次作为对另一个NPC对话的输入，按照输入格式拼起来输入给目标NPC。
而且为了控制NPC之间对话的轮次，还需加一个最大轮次的设定以及当前对话的轮次，并且让NPC在轮次快要耗尽时更加输出倾向于结束对话的触发词。

对话入库规则：
对话内容、说话者名称与听者名称作为payload形成对话事件，首先进入对话者的事件库，然后按照正常规则如果是public就广播给在场NPC的见闻库。


禁止事项：

- 不接真实模型。
- 不改 Godot UI。

验收标准：

- 可用 curl 或 HTTP 工具调用。
- 请求“提出应征”时 Mock 可返回 accept 或 reject。
- JSON 结构稳定。

验收结果（2026-06-03）：

- 已在 `backend/app.py` 新增正式 `POST /npc/dialogue` Mock 业务接口，请求体先校验为 `NPCDialogueRequest`，Mock 输出再校验为 `NPCDialogueResponse`，非法 JSON / schema 错误返回 400，模型输出不合法返回 502，非 mock provider 无 Key 返回 503。
- 已按本任务临时增改版重整对话 Schema：输入包含目标 NPC `npc_id` / `npc_name` / `npc_setting`、`speaker_name` / `speaker_text` / `speaker_context`、`is_recruitment_request`、当前轮次 / 最大轮次、`npc_state`、`dialogue_state`、`short_memory`、`long_memory` 和 `location_context`。
- Mock 玩家-NPC 对话会在“提出应征”请求中按关键词稳定返回 `recruitment_result=accept` 或 `reject`；NPC-NPC 对话会在轮次接近 `max_rounds` 时返回 `should_end_dialogue=true`。
- 已新增 `tools/verify_dialogue_mock_endpoint.py`，覆盖 `/npc/dialogue` HTTP 路径、应征 accept/reject、NPC-NPC 结束倾向和非法请求 400。
- 验证通过：`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、Python 编译检查。
- 本任务未改 Godot UI，也未实现 Godot 侧对话事件入库；这些按下方 T0604/T0701/T0702 继续推进。

---

## T0604 实现 Godot LLMBridge

状态：Done
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
- 按 T0603 Schema 从 Godot 收集并发送：目标 NPC 设定、说话者名称 / 文本 / 上下文、`is_recruitment_request`、当前轮次 / 最大轮次、NPC 状态、`dialogue_state`、短期记忆、长期记忆和地点快照等
- 请求失败时返回报错结果
- 发起会影响当前事态的 LLM 请求前，调用 `TimeSystem.request_time_slowdown(...)`
- 请求成功、失败、超时后，必须调用 `TimeSystem.release_time_slowdown(...)`

禁止事项：

- 不实现对话 UI。
- 不实现真实 LLM。
- 不实现征召。

验收标准：

- Godot 能显示后端连接状态。
- 后端关闭时不会崩溃。
- 请求 `/npc/dialogue` 可收到 Mock JSON。
- Godot 发送的请求字段与 T0603 `NPCDialogueRequest` 对齐；玩家发起时 `speaker_name == "守备官"`。
- LLM 请求等待期间有效逻辑时间倍率降为 `1/60`，请求结束后恢复玩家设定倍率。
- 后端失败或超时时不会遗留慢速请求。

验收结果（2026-06-03）：
- 已新增 `res://scripts/systems/LLMBridge.gd` 并挂载到 `Main/Systems/LLMBridge`。
- 支持后端地址配置、`GET /health`、`POST /npc/dialogue` 和 HUD 后端状态刷新；GM 面板新增 `backend_health`、`dialogue_mock <npc_id> <text>`、`dialogue_recruit <npc_id> <text>`。
- Godot 侧会按 T0603 Schema 收集目标 NPC 设定、说话者名称/文本/上下文、应征标记、轮次、NPC 权威状态、对话公开性、短期记忆、长期记忆和地点快照；玩家发起时 `speaker_name == "守备官"`。
- 对话请求期间注册 `TimeSystem.request_time_slowdown(...)`，成功、失败或超时后释放；验证覆盖后端关闭、health、dialogue Mock 和失败后慢速释放。
- 当前只完成桥接与调试入口，不实现对话 UI、对话事件入库、真实 LLM 或征召状态变更。
- 当前传输层使用本机 `curl.exe` 和临时 JSON 文件，是 T0604 为了先打通闭环的临时实现，不是正式客户端分发架构。
- 验证通过：`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`godot --headless --path . --quit-after 1`。

---

## T0604A 替换 LLMBridge 传输层并锁定正式前后端架构

状态：Done
优先级：P0
前置任务：T0604
涉及文档：`TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `API_BUDGET.md`

任务目标：

把 T0604 的临时 `curl.exe` 传输层替换为 Godot 原生 HTTP，并明确正式分发方向：玩家电脑只运行 Godot 客户端；客户端请求游戏服务器后端；服务器后端调用 LLM Provider、持有 API Key、做额度控制和并发治理。玩家自行配置 API Key 只能作为未来可选开发/BYOK 模式，Demo 阶段不是必需路径，也不能成为默认架构。

实现范围：

- `LLMBridge` 使用 Godot 原生 `HTTPRequest` 或 `HTTPClient` 发起 `/health` 与 `/npc/dialogue` 请求。
- 保持 `LLMBridge` 对上层系统的公开职责稳定：payload 构造、错误字典、`backend_status_changed`、TimeSystem 慢速注册/释放都不因传输替换而改变。
- 移除运行时对 `curl.exe`、命令行 JSON 转义和临时请求体文件的依赖。
- 请求必须有超时、失败返回和慢速释放兜底。
- 验证路径必须覆盖编辑器 / `Main.tscn` 运行、headless `--script`、后端关闭失败路径和 `/npc/dialogue` Mock 成功路径。
- 文档中必须继续强调：Godot 导出客户端不保存真实供应商 API Key，不直接调用 DeepSeek / MiniMax / 通义千问 / 智谱等模型接口。

禁止事项：

- 不在 Godot 客户端写入真实 API Key。
- 不让 Godot 直接调用 LLM Provider。
- 不在本任务实现真实 LLM、对话 UI、征召结算或 API 额度面板。
- 不把本地开发用 backend/mock 误写成玩家最终部署必须自行启动的组件。

验收标准：

- `LLMBridge.gd` 运行时不再调用 `curl.exe`。
- `GET /health` 可刷新 HUD/GM 后端状态。
- `POST /npc/dialogue` 可收到 T0603 Mock JSON，且字段仍与 `NPCDialogueRequest` 对齐。
- 后端关闭、超时或返回非法 JSON 时不会崩溃，也不会遗留 TimeSystem 慢速请求。
- `godot --headless --path . --script res://tools/verify_llm_bridge.gd` 通过，验证脚本不依赖 `curl.exe`。
- 相关架构文档明确“客户端 -> 游戏后端 -> LLM Provider”的正式方向，以及 BYOK 仅为未来可选模式。

验收结果（2026-06-03）：

- `res://scripts/systems/LLMBridge.gd` 已用 Godot 原生 `HTTPClient` 状态机替换 T0604 的 `curl.exe` / 临时 JSON 文件传输层。
- `LLMBridge` 对上层保持原接口与职责：继续负责 `/health`、`/npc/dialogue`、T0603 payload 构造、错误字典、`backend_status_changed` 和 TimeSystem 慢速注册/释放。
- 请求路径已覆盖连接失败、请求失败、响应体读取失败、超时、非法 JSON、后端 `ok=false` 和成功 JSON；成功、失败、超时后都会释放慢速请求。
- `tools/verify_llm_bridge.gd` 新增防回退静态检查，确认脚本不含 `curl.exe`、`OS.execute`、临时请求体文件名或旧写文件函数。
- 文档已继续明确正式架构为 Godot 客户端请求游戏服务器后端，再由后端调用 LLM Provider；Godot 导出客户端不保存真实供应商 API Key，不直连 DeepSeek / MiniMax / 通义千问 / 智谱等模型接口，BYOK 仅为未来可选模式。
- 验证通过：`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`godot --headless --path . --quit-after 1`。

备注（T0604 复盘）：

- 第一次尝试 Godot 原生 HTTP 时，headless/脚本验证里的信号等待与节点生命周期没有处理好，导致请求路径反复卡住。
- 同步等待异步 HTTP 返回会让验证脚本挂起，后续实现必须用明确请求状态机、超时和完成回调。
- Windows 命令行传中文 JSON、引号和换行容易被转义破坏，T0604 才临时改为 `curl.exe` + 临时 JSON 文件。
- 环境变量若残留 `LLM_PROVIDER=deepseek` 等非 mock 配置且无 Key，后端会按设计返回 provider unavailable；验证必须显式使用 mock 或隔离环境。
- 这些都是传输层和验证环境问题，不是 NPC、记忆、LLM 架构方向的问题；不能据此改成 Godot 客户端直连真实模型。

---

# M7：玩家对话、征召与非对话交互

目标：玩家能够点击 NPC 对话，通过“提出征召”让 NPC 接受或拒绝；玩家可给钱、给装备、攻击NPC，且这些行为进入结构化事件与 NPC 事件库。

---

## T0701 实现对话 UI

状态：Todo
优先级：P0
前置任务：T0303, T0604A
涉及文档：`UI_UX.md`, `AI_NPC_SYSTEM.md`

任务目标：

点击 NPC 面板上的“对话”后可以打开对话窗口并输入文本。

功能：

- 显示 NPC 名字
- 显示历史对话
- 玩家输入文本
- 发送到后端
- 显示 NPC 回复
- 结束对话按钮
- 对话 UI 维护NPC-NPC 对话当前轮次与最大轮次（暂定5轮，两个npc都发言一次为一轮）；后续逃离挽留复用同一轮次限制语义（玩家与NPC对话不限轮次）

禁止事项：

- 不实现语音。
- 不实现主动找玩家。
- 不实现征召状态切换。

验收标准：

- 点击 NPC 可打开对话 UI。
- 输入文本后能看到 Mock 回复。
- 后端关闭时显示降级回复。
- 对话事件写入双方 NPC 事件库；对话全文、说话者名称、听者名称、公开性、当前轮次、最大轮次和征召标记存入事件 `payload`。
- 若 `dialogue_state.visibility == "local_public"`，对话事件按地点规则广播给同地点第三者见闻库；`private` 只进入对话双方事件库。

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
- 后端返回 `recruitment_result=accept` 后 NPC `recruited=true`
- 征召结果写入本次对话的结构化事件和 NPC 事件库

禁止事项：

- 不实现真实 LLM 判断。
- 不实现战斗指派。

验收标准：

- NPC 接受后面板显示已入伍。
- 已入伍 NPC 可出现指派按钮占位。
- 拒绝后不改变入伍状态。
- 征召与否被记录在对话事件payload中。

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

- 给钱事件写入目标 NPC 事件库，并按地点可见性通过地点/广场节点即时广播给当前在场 NPC。
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
- 可进入建筑的真实工位占用与释放
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
- 工作开始、取消、失败或完成时正确占用/释放可进入建筑工位，并让地点信息节点广播内部状态变化。
- 资源产出/消耗、饱食和疲劳变化使用 `TimeSystem` 的逻辑时间倍率或 `logical_time_tick`，不依赖真实帧率或 NPC 移动速度。
- 在 T0305 持续行动基座上细化工作连续结算：确定各工作是否按小时批次、按分钟消耗投入、按进度产出或支持中途取消返还/损耗，避免后续数值误以为工作是瞬时点击结果。

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
- 装备事件写入目标 NPC 事件库，并按地点可见性通过地点/广场节点即时广播给当前在场 NPC。
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
- 若存在正在修复且仍受损的建筑，规则计划可把协助修复作为候选行为，并按工程熟练度和建筑重要性选择目标
- 若存在正在升级的建筑，规则计划可把协助升级作为候选行为，并按工程熟练度和建筑重要性选择目标
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
- NPC 自动计划能在有正在修复或正在升级的建筑时选择协助修复/协助升级；目标必须来自 `BuildingSystem` 当前状态，不由 LLM 或 UI 自行决定。

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

- 战斗事件自动通过广场节点即时广播给当前在场 NPC。
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
- 真实供应商 API Key 默认只存在于游戏服务器后端或开发者本地后端环境，Godot 导出客户端不保存、不上传、不直连模型供应商。
- Demo 阶段正式方向是玩家客户端请求服务器后端，由服务器后端调用 LLM；玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式，不作为 Demo 必需路径。
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

## T1407 部署游戏后端到服务器

状态：Todo
优先级：P0
前置任务：T0604A, T1401, T1406
涉及文档：`TECH_ARCHITECTURE.md`, `API_BUDGET.md`, `backend/README.md`, `CURRENT_STATE.md`

任务目标：

把当前本地调试用的 `backend/app.py` 整理为可部署到服务器的游戏后端服务，让玩家电脑上的 Godot 客户端可以请求公网/局域网后端，再由后端调用 LLM Provider。

部署入口：

- 服务器运行的 Python Web App 仍以 `backend/app.py` 为应用入口。
- 本地开发可继续使用 `python backend/app.py`。
- 正式部署不得依赖 Flask debug server；需要使用生产 WSGI/ASGI 服务，例如 Linux 下的 `gunicorn backend.app:app`，或 Windows 服务器下的 `waitress-serve --call backend.app:create_app`。

实现范围：

- 整理 `backend/app.py` 的应用工厂和生产入口，确保可被 WSGI 服务加载。
- 补充生产依赖：根据部署方案在 `backend/requirements.txt` 中加入 `gunicorn` 或 `waitress`，不要同时引入不必要的大框架。
- 新增或更新部署说明，至少写入 `backend/README.md`：服务器系统要求、安装依赖、环境变量、启动命令、健康检查、日志位置、重启方式和常见错误。
- 明确服务器环境变量：`LLM_PROVIDER`、`LLM_API_KEY`、模型 base url / model name、超时、单用户/全局限流、预算上限、是否启用 mock fallback。
- 后端必须继续提供 `GET /health`，并可被 Godot 客户端和运维人员用来确认服务可用。
- 部署环境必须禁止提交真实 `.env`；只提交 `.env.example` 或部署文档。
- Godot 侧后端地址必须可配置，导出客户端默认指向服务器后端地址或可由配置覆盖；不得把真实 LLM Key 放入客户端。
- 需要考虑 CORS / Origin / 简单鉴权策略，至少避免完全裸露的无限制公开 LLM 调用接口。
- 需要记录请求日志、错误日志、调用类型、NPC id、request id、token / 费用估算和失败原因。
- 需要有基本限流、超时、并发队列或拒绝策略，避免多个玩家高并发时把 LLM 额度打穿。

禁止事项：

- 不把真实 API Key 写入仓库、Godot 工程或导出包。
- 不让玩家电脑默认直接调用 LLM Provider。
- 不把本地 `python backend/app.py` 当成正式生产启动方式。
- 不在本任务重写 NPC、记忆、战斗或对话业务逻辑。

验收标准：

- 在一台干净服务器或本机模拟生产环境中，可以从仓库安装后端依赖并启动生产 WSGI 服务。
- `GET /health` 可从 Godot 客户端所在机器访问。
- Godot `LLMBridge` 可配置为请求服务器地址，并通过 `/health` 与 `/npc/dialogue`。
- 后端能在无真实 Key 时使用 mock 或明确降级；有真实 Key 时通过 Model Adapter 调用真实模型。
- 并发请求不会导致进程崩溃；超过限流或预算时返回可处理错误。
- 日志中能定位 request id、调用类型、失败原因和预算信息。
- `backend/README.md` 足够指导重新部署，不依赖口头记忆。

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

## T1506 增加黑色幽默事件与公告输入

状态：Todo
优先级：P2
前置任务：T0404, T0701
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`

验收标准：

- 玩家可通过主厅前公告牌界面写公告。
- 公告更新为广场当前状态，并即时广播给当前在广场的 NPC；公告牌不作为建筑保存状态。
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

在数据上的地点信息节点已经稳定后，为可进入建筑逐步增加室内空间和模型表现。

实现范围：

- 宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊可以拥有室内空间或更细的工位/床位模型。
- 室内模型表现必须服从已经实现的地点信息节点数据；不要反过来把信息系统写死在模型节点里。
- 主厅、围墙、城门、后门、仓库仍不可进入，状态继续归入广场当前状态，且只暴露外部状态。

验收标准：

- 至少 1 个可进入建筑有可辨认室内空间占位。
- NPC 进入该建筑时仍使用 T0403 的地点信息节点和进入事件。
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
