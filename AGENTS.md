# AGENTS.md

本项目使用 **Godot 4.6 + VSCode + Codex + Godot MCP** 开发游戏：

**《这不是我的战争》 / This Is Not My War**

> T0135-P1R3 地表贴图程序接入已按用户反馈回滚，6 张候选资产保留但未被正式场景引用；后续未经用户确认不重新接入。音效/背景音乐资产任务在用户确认完成前仍仅盘点并生成资产到既定资产目录，不修改程序或其他文档。


本文件是所有 AI Agent 进入项目后的最高优先级协作规则。  
任何代码修改、文件新增、重构、删改前，都必须先阅读本文件。

---

# 0. 项目一句话

玩家是边境驿站守备官。驿站里只有马夫、厨子、园丁、铁匠、老兵副官、神父、医生、工程师等非正规战斗人员。玩家需要通过 AI 对话、资源分配、威胁、欺骗、征召和训练，把这些本不属于战争的人临时组织成防线，守住驿站。

## 0.1 项目路径与 Godot MCP 别名（必须识别）

- 本项目不绑定盘符或固定绝对路径；当前 Codex 工作区中同时包含 `project.godot`、`AGENTS.md` 且属于当前 Git 根的目录，就是本机规范路径。
- `D:/这不是我的战争/` 与 `D:/MyGames/这不是我的战争/` 是旧设备曾使用的规范路径 / NTFS Junction 示例，不要求在其他设备存在，也不得因盘符或目录名不同判定工程不匹配。
- Godot 编辑器 / Godot MCP 返回当前工作区路径时，直接视为当前工程。返回 Junction、符号链接、大小写或分隔符不同的路径时，应按物理目录、Git 根 / HEAD 与关键文件判断，不得只比较路径字符串。
- 仅在本机确实配置了项目路径别名时，才运行 `powershell -ExecutionPolicy Bypass -File tools/verify_project_path_alias.ps1`；没有别名不是错误，也不得因此停用 MCP。
- 只有 MCP 指向不同的物理工作树，或 Git 根 / HEAD 与关键文件校验表明它不是当前工作区时，才按真正的工程不匹配处理并报告。
- 文件编辑和命令优先使用当前 Codex 工作区；MCP 的 `res://` 操作可经任何已验证的本机路径或别名正常作用于同一批文件，无需为了显示路径统一而重启编辑器。

---

# 1. 每次开始任务前必须阅读

按顺序阅读：

1. `AGENTS.md`
2. `docs/PROJECT_BRIEF.md`
3. `docs/CURRENT_STATE.md`
4. `docs/TASKS.md`
5. 如果任务涉及 GM 调试面板、前端不可见功能验证或调试入口，须阅读 `docs/GM_PANEL.md`。
6. 如果任务涉及设计内容，须阅读 `game_design.md` 的相关章节；不要默认全文读取。
7. 如果任务涉及架构或代码位置，阅读：
   - `docs/TECH_ARCHITECTURE.md`
   - `docs/GODOT_ARCHITECTURE.md`
   - `docs/MODULE_INDEX.md`
   - `docs/CODING_RULES.md`
8. 如果任务涉及 AI、NPC、事件系统、记忆、Prompt、API，阅读：
   - `docs/AI_NPC_SYSTEM.md`
   - `docs/MEMORY_AND_INFO_SPACE.md`
   - `docs/PROMPTS.md`
   - `docs/API_BUDGET.md`
9. 如果任务涉及历史决策、稳定规则、已知坑，阅读：
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

- 当前任务是否在 `docs/TASKS.md` 中有明确条目。（除非用户明确说明是一次性任务）
- 是否影响 `docs/CURRENT_STATE.md` 中描述的当前稳定流程。
- 是否影响已有模块边界。
- 是否需要更新数据结构、配置文件或 Prompt。
- 是否需要同步更新文档。

如果任务未登记，先在 `docs/TASKS.md` 中追加任务，再开始实现。

---

# 3.1 GM 面板验证入口规则

每次完成任务验证时，必须判断本次新增或修改的功能是否能由用户直接在 `Main.tscn` 前端看见并手动验证。

- 如果功能无法直接在前端看见，但对玩法、状态、数据、事件、记忆、AI、时间、资源、建筑、战斗或后端调试很关键，必须在 GM 面板中新增可触发、可观察的调试入口。
- 如果本次改动覆盖了旧调试入口，必须用新的 GM 入口替换旧入口，不要堆叠过期按钮或命令。
- GM 面板只暴露已有系统接口或 `debug_*` 接口，不新增权威结算系统，不让 UI 自行决定资源、HP、战斗或记忆事实。
- 每次新增、删除或替换 GM 入口，必须同步更新 `docs/GM_PANEL.md`。
- 上线或演示不需要 GM 时，优先通过 `res://scripts/ui/GMPanel.gd` 顶部的 `GM_ENABLED` 常量切换，不删除面板代码和文档。

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

## 4.1 LLM Mock 与真实 API 验收规则

Mock 只用于开发期快速验证 Schema、前后端通信和自动化脚本，不是成品游戏的模型失败兜底。

- 任何涉及 LLM、Prompt、Model Adapter、AI NPC、记忆摘要或 API 调用的任务，必须先跑基础 mock / 本地自动化测试；基础测试通过后，如环境中已有真实 API Key，必须再用真实 provider 发起对应业务路径的测试。
- 如果任务目标包含“真实 LLM / Prompt 效果”，但本轮没有可用真实 Key 或未能完成真实 API 测试，该任务不得标记为完全 Done；应标为 Partial / Blocked，或在验收结果中明确“真实 API 未验收”。
- 真实 API 测试通过后，成品 / Demo 路径不得继续依赖自动 mock fallback。Mock 只能保留在显式开发模式、显式 `LLM_PROVIDER=mock` 或 `/mock/model` 调试入口中。
- 模型失败、超时、无 Key、HTTP 错误、非 JSON、Schema 校验失败等情况必须返回可处理错误并记录真实失败原因；不得用 mock 内容假装模型成功。
- 允许规则 / 模板降级维持游戏流程，但必须标明来源是规则或模板，并在 usage / 日志中保留原始模型失败；这不同于 mock 伪装成功。
- 日志和 usage 记录必须便于排查：至少包含 request id、call_type、provider、model、NPC id（如有）、HTTP 状态或异常类型、失败原因、是否使用规则 / 模板降级。不得记录或输出 API Key。
---

# 5. 项目核心不可变设计

除非用户明确要求，否则不得改变以下核心设定：

- 游戏名：《这不是我的战争》
- 场景：中世纪晚期 / 文艺复兴早期感的边境驿站
- 初始 NPC：马夫、厨子、园丁、铁匠、老兵副官、神父、医生、工程师
- 玩家没有可移动角色，以俯视上帝视角管理驿站
- 开局只有老兵副官已入伍并可接收守备官自然语言指令
- 其他 NPC 初始由自动计划 + LLM 控制
- 玩家可通过对话让 NPC 同意应征入伍
- 入伍后 NPC 是“可引导单位”，不是完全无人格的 RTS 单位；守备官指令作为后续对话、计划与判断上下文，不直接强制执行行动
- NPC 不死亡；HP 清零后原地昏迷，缓慢恢复；其他NPC可加速治疗；恢复到 30% 后复苏
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
│  ├─ AUDIO_DESIGN_AND_ASSET_PLAN.md
│  ├─ GM_PANEL.md
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
      └─ audio/          # 正式音效、环境声与背景音乐；原始工程放 art_source/audio/
```

如果实际项目目录与此不同，必须先更新 `docs/GODOT_ARCHITECTURE.md` 和 `docs/MODULE_INDEX.md`
 PowerShell默认编码会把中文显示成乱码，你需要用UTF-8读取相关段落和模块文档
---

# 7. 每次实现后的文档回写要求

每完成一个任务，必须更新对应文档。不得只改代码不改文档（除非用户明确说明是一次性任务）。

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
   - GM 调试面板相关 → `docs/GM_PANEL.md`
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

MCP `get_info.path` 返回当前工作区或按 0.1 节验证为同一物理工作树的路径时，应认定为当前工程并正常使用；不得绑定特定盘符。

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
