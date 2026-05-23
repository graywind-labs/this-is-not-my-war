# AGENTS.md

本项目使用 **Godot 4.6 + VSCode + Codex + Godot MCP** 开发游戏：

**《这不是我的战争》 / This Is Not My War**

本文件是所有 AI Agent 进入项目后的最高优先级协作规则。  
任何代码修改、文件新增、重构、删改前，都必须先阅读本文件。

---

# 0. 项目一句话

玩家是边境驿站守备官。驿站里只有马夫、厨子、园丁、铁匠、老兵副官、神父、医生、工程师等非正规战斗人员。玩家需要通过 AI 对话、资源分配、威胁、欺骗、征召和训练，把这些本不属于战争的人临时组织成防线，守住驿站。

---

# 1. 每次开始任务前必须阅读

按顺序阅读：

1. `AGENTS.md`
2. `docs/PROJECT_BRIEF.md`
3. `docs/CURRENT_STATE.md`
4. `docs/TASKS.md`
5. 如果任务涉及设计内容，须阅读 `game_design.md` 的相关章节；不要默认全文读取。
6. 如果任务涉及架构或代码位置，阅读：
   - `docs/TECH_ARCHITECTURE.md`
   - `docs/GODOT_ARCHITECTURE.md`
   - `docs/MODULE_INDEX.md`
   - `docs/CODING_RULES.md`
7. 如果任务涉及 AI、NPC、事件系统、记忆、Prompt、API，阅读：
   - `docs/AI_NPC_SYSTEM.md`
   - `docs/MEMORY_AND_INFO_SPACE.md`
   - `docs/PROMPTS.md`
   - `docs/API_BUDGET.md`
8. 如果任务涉及历史决策、稳定规则、已知坑，阅读：
   - `docs/DEV_LOG.md`

---

# 2. 上下文节约原则

不要把所有文档一次性读入上下文。  
优先阅读摘要文件，再按模块精确查找。

推荐路径：

```text
PROJECT_BRIEF.md → CURRENT_STATE.md → TASKS.md → MODULE_INDEX.md → 相关模块文档 → game_design.md 相关章节
```

`game_design.md` 是完整玩法设计源，但不是每次任务都需要全文读取。  
当模块文档与 `game_design.md` 冲突时，优先以 `game_design.md` 为设计源，然后更新模块文档中的摘要。

---

# 3. 修改代码前必须确认

开始任何实现前，必须确认：

- 当前任务是否在 `docs/TASKS.md` 中有明确条目。
- 是否影响 `docs/CURRENT_STATE.md` 中描述的当前稳定流程。
- 是否影响已有模块边界。
- 是否需要更新数据结构、配置文件或 Prompt。
- 是否需要同步更新文档。

如果任务未登记，先在 `docs/TASKS.md` 中追加任务，再开始实现。

---

# 4. AI 开发基本原则

1. **优先最小可运行**：先做最小闭环，不要一上来做大系统。
2. **一次只推进一个模块**：不要同时大改 NPC、战斗、UI、后端、记忆系统。
3. **不要擅自扩展需求**：当前没有要求的系统不要主动加入。
4. **优先保持已有稳定功能**：任何修改都不能轻易破坏已可运行流程。
5. **代码、配置、数据分离**：不要把 NPC 档案、建筑数值、敌人波次、Prompt 写死在脚本里。
6. **LLM 不负责权威数值结算**：资源、血量、建筑、战斗、寻路等由程序决定。
7. **输出必须可直接落地**：文件名、路径、类名、节点名、信号名、修改点必须明确。
8. 如果godot mcp连接断了，就报错，不要强行继续
---

# 5. 项目核心不可变设计

除非用户明确要求，否则不得改变以下核心设定：

- 游戏名：《这不是我的战争》
- 场景：中世纪晚期 / 文艺复兴早期感的边境驿站
- 初始 NPC：马夫、厨子、园丁、铁匠、老兵副官、神父、医生、工程师
- 玩家没有可移动角色，以俯视上帝视角管理驿站
- 开局只有老兵副官可被玩家指派
- 其他 NPC 初始由自动计划 + LLM 控制
- 玩家可通过对话让 NPC 同意应征入伍
- 入伍后 NPC 是“可引导单位”，不是完全无人格的 RTS 单位
- NPC 不死亡；HP 清零后原地昏迷，缓慢恢复；医生可加速治疗；恢复到 30% 后复苏
- 战斗事件、逃离事件、昏迷/复苏事件会进入见闻系统
- 广场是公共信息中枢
- Demo 目标是守住 5 波敌人
- 主厅被摧毁则失败

---

# 6. 项目目录约定

推荐目录：

```text
/
├─ AGENTS.md
├─ game_design.md
├─ project.godot
├─ docs/
│  ├─ PROJECT_BRIEF.md
│  ├─ CURRENT_STATE.md
│  ├─ TASKS.md
│  ├─ MODULE_INDEX.md
│  ├─ TECH_ARCHITECTURE.md
│  ├─ GODOT_ARCHITECTURE.md
│  ├─ CODING_RULES.md
│  ├─ DATA_SCHEMA.md
│  ├─ AI_NPC_SYSTEM.md
│  ├─ MEMORY_AND_INFO_SPACE.md
│  ├─ ECONOMY_AND_BUILDINGS.md
│  ├─ COMBAT_SYSTEM.md
│  ├─ UI_UX.md
│  ├─ PROMPTS.md
│  ├─ API_BUDGET.md
│  ├─ DEV_LOG.md
├─ backend/
│  ├─ README.md
│  ├─ app.py
│  ├─ requirements.txt
│  ├─ schemas/
│  ├─ services/
│  └─ data/
├─ data/
│  ├─ npc_profiles.json
│  ├─ building_defs.json
│  ├─ action_defs.json
│  ├─ weapon_defs.json
│  ├─ enemy_waves.json
│  └─ prompts/
└─ res:// Godot 项目资源
   ├─ scenes/
   ├─ scripts/
   ├─ ui/
   └─ assets/
```

如果实际项目目录与此不同，必须先更新 `docs/GODOT_ARCHITECTURE.md` 和 `docs/MODULE_INDEX.md`。

---

# 7. 每次实现后的文档回写要求

每完成一个任务，必须更新对应文档。不得只改代码不改文档。

至少检查并按需更新：

1. `docs/CURRENT_STATE.md`
   - 当前已实现什么？
   - 当前稳定流程是什么？
   - 如何运行和验证？
2. `docs/TASKS.md`
   - 把任务状态从 Todo 改为 Done / Partial / Blocked。
   - 补充新发现的后续任务。
3. `docs/MODULE_INDEX.md`
   - 如果新增/移动文件，更新模块索引。
4. 对应模块文档：
   - NPC 相关 → `docs/AI_NPC_SYSTEM.md`
   - 事件/记忆相关 → `docs/MEMORY_AND_INFO_SPACE.md`
   - 模拟经营/建筑资源 → `docs/ECONOMY_AND_BUILDINGS.md`
   - 战斗相关 → `docs/COMBAT_SYSTEM.md`
   - UI 相关 → `docs/UI_UX.md`
   - 架构相关 → `docs/TECH_ARCHITECTURE.md` / `docs/GODOT_ARCHITECTURE.md`
5. `docs/DEV_LOG.md`
   - 用日期记录本次修改。

---

# 8. 每次回答用户时的交付格式

完成任务后，必须用以下格式报告：

```text
## 本次完成
- ...

## 修改文件
- path/to/file.gd：修改了什么
- docs/xxx.md：更新了什么

## 验证方式
- 用户如何确认功能生效

## 文档回写
- CURRENT_STATE.md：已更新/无需更新，原因
- TASKS.md：已更新/无需更新，原因
- MODULE_INDEX.md：已更新/无需更新，原因

## 风险与下一步
- ...
```

---

# 9. Godot MCP 使用规则

如果可用，优先使用 Godot MCP 辅助理解项目：

- 查看场景树
- 检查节点、脚本绑定、资源路径
- 运行或调试场景
- 查询错误日志
- 创建或修改简单节点

但不要在不了解现有结构时大规模重写 `.tscn` 文件。  
复杂场景变更应先说明计划，再分步执行。

---

# 10. 禁止行为

- 不要把完整 `game_design.md` 复制进代码或 Prompt
- 不要上传api KEY
- 不要把 NPC 设定写死在 GDScript 中
- 不要让 LLM 直接决定资源扣除、伤害、建筑摧毁等权威结果
- 不要在没有任务条目的情况下随意重构
- 不要一次性实现多个大型系统
- 不要删除文档中的稳定决策，除非用户明确要求
- 不要引入没有必要的复杂框架
- 不要让“模拟小镇”压过“边境驿站压力锅”的核心体验

---