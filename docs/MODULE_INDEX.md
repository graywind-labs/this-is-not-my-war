# MODULE_INDEX.md

> 本文件用于帮助 Agent 快速找到模块位置。  
> 每新增、移动、删除重要代码文件，都必须更新这里。

## 文档入口

| 内容 | 文件 |
|---|---|
| 完整玩法设计源 | `game_design.md` |
| Agent 规则 | `AGENTS.md` |
| 项目简报 | `docs/PROJECT_BRIEF.md` |
| 当前状态 | `docs/CURRENT_STATE.md` |
| 任务列表 | `docs/TASKS.md` |
| 技术架构 | `docs/TECH_ARCHITECTURE.md` |
| Godot 架构 | `docs/GODOT_ARCHITECTURE.md` |
| 代码规范 | `docs/CODING_RULES.md` |
| 数据结构 | `docs/DATA_SCHEMA.md` |
| AI NPC 系统 | `docs/AI_NPC_SYSTEM.md` |
| 记忆与信息空间 | `docs/MEMORY_AND_INFO_SPACE.md` |
| 经济与建筑 | `docs/ECONOMY_AND_BUILDINGS.md` |
| 战斗系统 | `docs/COMBAT_SYSTEM.md` |
| UI | `docs/UI_UX.md` |
| Prompt | `docs/PROMPTS.md` |
| API 成本 | `docs/API_BUDGET.md` |
| 长期记忆 | `docs/LONG_TERM_MEMORY.md` |
| 开发日志 | `docs/DEV_LOG.md` |
| 变更记录 | `docs/CHANGELOG.md` |

## Godot 模块规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 主场景 | `res://scenes/main/Main.tscn` | 游戏入口 |
| 驿站地图 | `res://scenes/world/Station.tscn` | 低模驿站 |
| NPC 场景 | `res://scenes/npc/NPC.tscn` | 通用 NPC 实体 |
| 敌人场景 | `res://scenes/enemy/Enemy.tscn` | 通用敌人实体 |
| 建筑场景 | `res://scenes/buildings/Building.tscn` | 通用建筑实体 |
| UI 主界面 | `res://scenes/ui/HUD.tscn` | 资源、时间、按钮 |
| 对话 UI | `res://scenes/ui/DialogPanel.tscn` | NPC 对话 |
| NPC 面板 | `res://scenes/ui/NPCPanel.tscn` | 状态、装备、按钮 |
| 建筑面板 | `res://scenes/ui/BuildingPanel.tscn` | 建筑信息 |

## Godot 当前已创建

路径：`project.godot`  
用途：Godot 项目配置，当前启动场景为 `res://scenes/main/Main.tscn`，并注册 `MCPGameBridge`、`EventBus`、`GameState`、`ConfigLoader` Autoload。  
依赖：Godot 4.6，`addons/godot_mcp` 自动加载配置。  
当前状态：T0101 已验证可打开并运行，核心 Autoload 加载无报错。

路径：`res://scenes/main/Main.tscn`  
用途：最小可运行主场景，包含 `WorldRoot/Station/Ground`、`WorldRoot/Station/Buildings`、`WorldRoot/Station/NPCs`、`WorldRoot/Station/Enemies`、`WorldRoot/Station/Props`、`Systems/*`、`UI/HUD`、`UI/NPCPanel`、`UI/BuildingPanel`、`UI/DialogPanel`、`CameraRig/Camera3D`、`SunLight`。`Buildings` 下已有主厅、宿舍、食堂、仓库、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、公告牌、围墙、城门、后门等低模占位；`Props` 下已有广场、正门道路、后门道路和商人入口占位。  
依赖：绑定 `res://scripts/systems/TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`ActionSystem.gd`、`MemorySystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 作为空系统占位脚本。  
当前状态：T0103 已完成低模驿站 Blockout；HUD 标题和建筑调试标签可见，未实现 NPC、建筑交互、资源、时间推进或战斗。

路径：`res://scenes/world/`, `res://scenes/npc/`, `res://scenes/enemy/`, `res://scenes/buildings/`, `res://scenes/ui/`  
用途：后续世界、NPC、敌人、建筑和 UI 场景目录。  
依赖：暂无。  
当前状态：目录已创建，具体场景待后续任务实现。

路径：`res://scripts/core/`, `res://scripts/systems/`  
用途：后续核心单例与系统脚本目录。  
依赖：暂无。  
当前状态：T0101 已创建核心 Autoload 脚本与部分系统占位脚本。

路径：`res://scripts/core/EventBus.gd`  
用途：全局事件总线，声明基础跨系统信号。  
依赖：作为 Autoload 注册于 `project.godot`。  
当前状态：T0101 已创建；包含 `resource_changed`、`hour_started`、`building_clicked`、`npc_clicked`、`public_event_added`。

路径：`res://scripts/core/GameState.gd`  
用途：全局运行状态，保存当前天数、小时和是否处于战斗中。  
依赖：作为 Autoload 注册于 `project.godot`；需要广播时通过 `/root/EventBus` 查找事件总线。  
当前状态：T0101 已创建；仅提供最小状态字段和设置接口。

路径：`res://scripts/core/ConfigLoader.gd`  
用途：统一 JSON 配置读取入口。  
依赖：作为 Autoload 注册于 `project.godot`；使用 Godot `FileAccess` 和 `JSON`。  
当前状态：T0101 已创建；文件缺失、打开失败、解析失败时会 `push_error` 并返回默认值。

路径：`res://scripts/systems/TimeSystem.gd`  
用途：时间系统占位脚本。  
依赖：暂无。  
当前状态：T0101 已创建；尚未实现时间推进。

路径：`res://scripts/systems/ResourceSystem.gd`  
用途：资源系统占位脚本。  
依赖：暂无。  
当前状态：T0101 已创建；尚未实现资源读写。

路径：`res://scripts/systems/BuildingSystem.gd`  
用途：建筑系统占位脚本。  
依赖：暂无。  
当前状态：T0101 已创建；尚未实现建筑点击或数据绑定。

路径：`res://scripts/systems/NPCSystem.gd`  
用途：NPC 系统占位脚本。  
依赖：暂无。  
当前状态：T0101 已创建；尚未实现 NPC 生成或行为。

路径：`res://scripts/systems/MemorySystem.gd`  
用途：记忆与公开见闻系统占位脚本。  
依赖：暂无。  
当前状态：T0101 已创建；尚未实现事件记录。

路径：`res://scripts/systems/ActionSystem.gd`  
用途：行动系统占位脚本，后续用于工作、吃饭、睡觉、训练等行动调度。  
依赖：暂无。  
当前状态：T0102 已创建并绑定到 `Main/Systems/ActionSystem`；尚未实现行动逻辑。

路径：`res://scripts/systems/CombatSystem.gd`  
用途：战斗系统占位脚本，后续用于攻击、策略和敌人波次。  
依赖：暂无。  
当前状态：T0102 已创建并绑定到 `Main/Systems/CombatSystem`；尚未实现战斗逻辑。

路径：`res://scripts/systems/DialogSystem.gd`  
用途：对话系统占位脚本，后续用于 NPC 对话和后端请求。  
依赖：暂无。  
当前状态：T0102 已创建并绑定到 `Main/Systems/DialogSystem`；尚未实现对话逻辑。

## Godot 脚本规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 事件总线 | `res://scripts/core/EventBus.gd` | 全局信号 |
| 游戏状态 | `res://scripts/core/GameState.gd` | 全局状态 |
| 配置加载 | `res://scripts/core/ConfigLoader.gd` | JSON 配置加载 |
| 时间系统 | `res://scripts/systems/TimeSystem.gd` | 天数、阶段、加速 |
| 资源系统 | `res://scripts/systems/ResourceSystem.gd` | 金钱、粮食等 |
| 建筑系统 | `res://scripts/systems/BuildingSystem.gd` | 建筑 HP、等级、工作位 |
| NPC 系统 | `res://scripts/systems/NPCSystem.gd` | NPC 生成与管理 |
| 行动系统 | `res://scripts/systems/ActionSystem.gd` | 工作、吃饭、睡觉、训练 |
| 对话系统 | `res://scripts/systems/DialogSystem.gd` | 与后端对话 |
| 征召系统 | `res://scripts/systems/RecruitmentSystem.gd` | 入伍状态 |
| 记忆系统 | `res://scripts/systems/MemorySystem.gd` | 事件、见闻、短期记忆 |
| 战斗系统 | `res://scripts/systems/CombatSystem.gd` | 攻击、策略、波次 |
| 昏迷系统 | `res://scripts/systems/UnconsciousSystem.gd` | 昏迷、治疗、复苏 |
| LLM 桥接 | `res://scripts/systems/LLMBridge.gd` | HTTP 请求后端 |

## 数据文件规划

| 内容 | 推荐路径 | 说明 |
|---|---|---|
| NPC 档案 | `data/npc_profiles.json` | 8 个初始 NPC |
| 建筑定义 | `data/building_defs.json` | 建筑 HP、等级、工作位 |
| 行动定义 | `data/action_defs.json` | 工作、吃饭、睡觉等 |
| 武器定义 | `data/weapon_defs.json` | 剑盾、长杆、弓、弩 |
| 敌人波次 | `data/enemy_waves.json` | 5 波 Demo |
| Prompt 模板 | `data/prompts/*.txt` | 计划、对话、判定、总结 |

## 后端模块规划

| 模块 | 推荐路径 | 说明 |
|---|---|---|
| 后端入口 | `backend/app.py` | Flask/FastAPI 入口 |
| 模型适配器 | `backend/services/model_adapter.py` | DeepSeek/MiniMax 等统一接口 |
| 对话服务 | `backend/services/dialog_service.py` | NPC 对话 |
| 计划服务 | `backend/services/planning_service.py` | 每日计划 |
| 判定服务 | `backend/services/judgement_service.py` | 战斗/逃离判定 |
| 记忆服务 | `backend/services/memory_service.py` | 总结、知识图谱 |
| 成本统计 | `backend/services/budget_service.py` | token 与费用 |
| 数据模型 | `backend/schemas/*.py` | Pydantic 或 dataclass |

## 后端当前已创建

路径：`backend/app.py`  
用途：Flask 后端入口，当前提供 `GET /health` 健康检查。  
依赖：`flask`, `python-dotenv`。  
当前状态：T0002 已完成；尚未实现 NPC 对话、计划、判定或真实 LLM 调用。

路径：`backend/requirements.txt`  
用途：记录 Python 后端依赖。  
依赖：至少包含 `flask`, `python-dotenv`, `pydantic`, `requests`。  
当前状态：T0002 已确认可用于安装后端最小依赖。

路径：`backend/.env.example`  
用途：本地 `.env` 配置模板。  
依赖：无。  
当前状态：仅包含变量名和占位值；真实 API Key 必须放入本地 `backend/.env`，不得提交仓库。

路径：`backend/services/model_adapter.py`  
用途：模型供应商适配器的最小边界，后续由对话、计划、判定服务复用。  
依赖：环境变量 `LLM_PROVIDER`, `LLM_API_KEY`。  
当前状态：仅读取配置并提供 `is_configured()`，不发起 LLM 请求。

路径：`backend/schemas/`, `backend/services/`, `backend/data/`  
用途：后端数据模型、服务层和后端本地数据目录。  
依赖：暂时无。  
当前状态：T0002 创建目录骨架，用 `.gitkeep` 保留空目录。

## 更新规则

新增任何实际文件后，在本文件加入：

```text
路径：
用途：
依赖：
当前状态：
```
## Tools

| 内容 | 文件 |
|---|---|
| Godot MCP 连接自检 | `tools/check_godot_mcp.ps1` |
