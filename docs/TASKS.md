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

## 0.6 LLM 真实 API 验收与 Mock 封存规则

适用于所有涉及 LLM、Prompt、Model Adapter、AI NPC、记忆摘要、计划生成、战斗心理判定、首次睡眠总结、语音情绪识别或 API 额度的任务，也适用于历史任务在后续被重验或重构时的验收。

- Mock 只用于开发期快速验证 Schema、通信、自动化脚本和本地无费用调试；成品 / Demo 不允许用 mock 伪装真实模型成功。
- 基础 mock 测试通过后，若环境中已有真实 API Key，必须用真实 provider 对本任务涉及的业务路径发起至少一次测试。
- 如果任务目标包含真实 LLM / Prompt 行为，但没有完成真实 API 测试，任务不得标记为完全 Done；应标为 Partial / Blocked，或在验收结果中明确“真实 API 未验收”。
- 真实 API 测试通过后，应把 mock 留在显式开发模式、显式 `LLM_PROVIDER=mock` 或 `/mock/model` 调试入口中；生产 / 演示配置必须关闭自动 mock fallback。
- 模型失败、超时、无 Key、HTTP 错误、非 JSON、Schema 校验失败等情况必须返回可处理错误并记录真实失败原因；不得用 mock 内容假装没有失败。
- 规则 / 模板降级可以维持游戏流程，但必须标明 `rule_*_fallback`、`template_*_fallback` 或等价来源，并保留原始模型失败日志；它不是 mock 成功。
- 日志 / usage 至少记录 request id、call_type、provider、model、NPC id（如有）、HTTP 状态或异常类型、失败原因、是否降级和 token / 费用估算；禁止记录 API Key。

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

## T0007 修复工作中 NPC 状态刷新抢回右上角面板

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：
修复 NPC 被指派工作后，玩家先点击该 NPC 打开 NPC 面板，再点击建筑切换到建筑面板时，工作中的 NPC 因持续状态刷新又自动弹出 NPC 面板，导致 UI 重叠的问题。

验收标准：
- 点击工作中的 NPC 后 NPC 面板正常显示。
- 再点击建筑后应切换到建筑面板，NPC 面板保持隐藏。
- 工作中的 NPC 后续 `npc_state_changed` 不会重新打开隐藏的 NPC 面板。
- NPC 面板在自身可见时仍能响应当前 NPC 状态刷新。

验收结果（2026-06-09）：
- `NPCPanel._on_npc_state_changed(...)` 只在面板当前可见且刷新目标仍是当前 NPC 时调用 `show_npc(...)`。
- 已在 `tools/verify_npc_panel_state.gd` 增加回归：NPC 面板切到建筑面板后，模拟同一 NPC 工作状态刷新，确认 NPC 面板不会重新显示。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_work_output_framework.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`。

---

## T0008 修复 NPC 面板内容增多时向上溢出

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：
修复 NPC 面板内容增多时，面板内容向上下两个方向延展，导致顶部超出屏幕的问题。

验收标准：
- NPC 面板打开后仍固定在右上角。
- 事件库、见闻库等内容变长导致面板超过原始高度时，面板顶边保持在屏幕内，不向上扩出可视区域。
- NPC 面板与建筑面板互斥、状态刷新不抢占等既有回归仍通过。

验收结果（2026-06-09）：
- 已将 `Main/UI/NPCPanel` 和内部 `PanelContainer` 的垂直增长方向调整为向下，内容超过原高度时不再以上下居中方式溢出。
- `tools/verify_npc_panel_state.gd` 已增加长事件库/见闻库内容膨胀回归，确认面板内容不会向上越过 NPC 面板顶边。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --quit-after 1`。

---

## T0009 修复 Godot MCP 运行桥接类缓存启动失败

状态：Done
优先级：P0
涉及文档：`GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：
修复换机 / Git 同步后项目启动时报 `Could not find type "MCPRuntimeStateSampler"`，导致 `MCPGameBridge` Autoload 解析失败、`Main.tscn` 跑不起来的问题。

验收标准：
- `godot --headless --path . --quit-after 1` 不再因 `MCPRuntimeStateSampler` 类型解析失败中断。
- Godot MCP 自检仍可连接。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 时游戏日志无报错。
- 修复不改变游戏权威逻辑、资源、HP、事件、NPC 或 UI 结算。

验收结果（2026-06-09）：
- `addons/godot_mcp/game_bridge/mcp_game_bridge.gd` 改为直接 `preload("mcp_runtime_state_sampler.gd")` 创建运行态采样器，不再依赖 `.godot/global_script_class_cache.cfg` 中是否已经登记 `MCPRuntimeStateSampler`。
- `_handle_watch_start(...)` 的 `start_result` 显式标注为 `Dictionary`，避免 sampler 动态实例化后类型推断失败。
- 验证通过：`godot --headless --path . --quit-after 1`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`、Godot MCP 运行 `res://scenes/main/Main.tscn` 后读取游戏日志为空。

---

## T0010 忽略本机 VSCode Godot 路径配置

状态：Done
优先级：P0
涉及文档：`CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：
两台电脑的 Godot 可执行文件路径不同，避免 `.vscode/settings.json` 在 Git 同步时反复产生脏改动或冲突。

验收标准：
- `.gitignore` 忽略 `.vscode/settings.json`。
- 已跟踪的 `.vscode/settings.json` 从 Git 索引移除，但本地文件保留。
- 不影响 Godot 项目加载和 MCP 自检。

验收结果（2026-06-09）：
- `.gitignore` 新增 `.vscode/settings.json` 忽略规则。
- 已执行 `git rm --cached .vscode/settings.json`，Git 后续不再跟踪该本机路径配置；确认本地 `.vscode/settings.json` 文件仍存在。
- 验证通过：`godot --headless --path . --quit-after 1`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`。

---

## T0011 显示完整资源库存与装备器械详情

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `ECONOMY_AND_BUILDINGS.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：
让左上角 HUD 不只显示基础五类资源，而是显示 `ResourceSystem` 中所有资源库存；装备、器械等聚合库存提供可点击详情入口，玩家能看到当前可用装备定义和器械库存状态。

验收标准：
- 左上角 HUD 按 `data/resource_defs.json` 的 `ui_order` 显示全部资源，包括餐食、酒、武器、盔甲、工程器械和马匹整备。
- 资源变化后全部资源标签自动刷新。
- HUD 提供“装备”和“器械”详情按钮，点击后显示对应库存与可用定义。
- UI 只读取 `ResourceSystem` / `EquipmentSystem` / `NPCSystem`，不直接修改资源或装备权威状态。
- 项目加载和相关 HUD 验证通过。

验收结果（2026-06-09）：
- `HUD.gd` 不再手写五个资源 Label，而是按 `ResourceSystem.get_resource_ids()` / `data/resource_defs.json.ui_order` 动态生成全部资源标签。
- HUD 现在显示第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料和铁，资源变化会刷新全部标签。
- 资源栏新增“装备”和“器械”按钮；装备详情显示武器 / 盔甲 / 马匹整备库存、可分配装备定义和已分配装备数量，器械详情显示工程器械库存与未部署边界说明。
- `ResourceSystem` 新增 `get_resource_definition(...)`，供 UI/调试读取资源定义；`EquipmentSystem.get_armor_ids(...)` 修正为稳定返回 `Array[String]`。
- 新增 `tools/verify_hud_resources.gd`，验证全量资源显示、派生资源刷新和装备/器械详情入口。
- 验证通过：`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

---

## T0012 调整 HUD 详情面板与 GM 面板定位

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `GM_PANEL.md`, `ECONOMY_AND_BUILDINGS.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：
修复 HUD 装备 / 器械详情面板和 GM 面板使用固定左上角坐标的问题，并去掉 HUD 主资源栏与详情面板之间的聚合资源重复显示。

验收标准：
- 装备详情面板点击后出现在“装备”按钮左下方，并保持在屏幕内。
- 器械详情面板点击后出现在“器械”按钮左下方，并保持在屏幕内。
- HUD 主资源栏不再重复显示装备 / 器械详情面板已有的聚合库存，例如武器、盔甲、马匹整备和工程器械。
- GM 面板点击后跟随 GM 按钮位置打开，拖动 GM 按钮时已打开的 GM 面板同步重定位，并保持在屏幕内。
- HUD、装备系统、GM 面板相关验证通过。

验收结果（2026-06-09）：
- HUD 主资源栏不再显示装备/器械详情中已有的聚合资源，保留第纳尔、粮食、餐食、酒、木材、石料和铁等直接资源。
- “装备”和“器械”详情面板会分别贴近对应按钮左下方打开，并根据可用屏幕范围夹住位置。
- GM 面板改为跟随 `GM` 按钮附近打开；拖动按钮时已打开面板会同步重定位并保持在可用屏幕范围内，同时压缩面板高度，避免默认覆盖左上角 HUD。
- `tools/verify_hud_resources.gd` 已覆盖主栏去重、装备/器械详情内容和详情面板定位；`tools/verify_gm_panel.gd` 已覆盖 GM 面板跟随按钮和边界钳制。
- 验证通过：`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

---

## T0013 移除短剑旧占位装备

状态：Done
优先级：P0
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `DATA_SCHEMA.md`, `DEV_LOG.md`

任务目标：
移除早期 T0704/T0901 遗留的 `short_sword` / 短剑占位装备，避免和 `game_design.md` 中的正式武器分类产生冲突。正式可装备主武器只保留剑盾、长杆、弓和弩。

验收标准：
- `data/weapon_defs.json` 不再包含 `short_sword` / 短剑。
- NPC 面板、HUD 装备详情、GM 装备下拉和装备系统只暴露剑盾、长杆、弓、弩四类主武器。
- 旧 `give_placeholder_weapon_to_npc(...)` 兼容入口不再保留，正式装备统一走 `EquipmentSystem`。
- 装备系统、兵种判定、HUD 详情和 GM 面板验证通过。

验收结果（2026-06-09）：
- 已删除 `data/weapon_defs.json` 中的 `short_sword` 定义。
- 已移除 `NPCSystem.gd` 的旧 `give_placeholder_weapon_to_npc(...)` 兼容入口。
- `tools/verify_equipment_system.gd`、`tools/verify_hud_resources.gd` 和 `tools/verify_unit_type_classification.gd` 已增加短剑不可出现的回归断言。
- 验证通过：`godot --headless --path . --script res://tools/verify_equipment_system.gd`、`godot --headless --path . --script res://tools/verify_unit_type_classification.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T0014 优化 GM 行动入口、NPC 记忆滚动区与弹窗互斥

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

优化当前 UI 体验，减少 GM 面板行动区冗余按钮，避免 NPC 面板被事件库 / 见闻库无限撑高，并修正 NPC 面板、对话面板、指令面板之间的显示关系。

验收标准：

- GM 面板行动区保留“指定行动 + 行动下拉”作为普通行动入口，去掉旁边单独的工作、吃饭、睡觉、当教官、当受训者等按钮；协助修复、协助升级、协助治疗这类需要额外目标参数的入口可继续保留。
- NPC 面板事件库和见闻库各自显示在固定高度滚动框内，面板不会因事件数量增加而被无限拉长。
- 事件库和见闻库最新内容仍位于最下方，刷新后自动滚动到底部；用户可以手动向上滚动查看旧事件。
- 点击 NPC 面板中的“对话”或“指令”不会自动关闭 NPC 面板。
- 对话面板与指令面板互斥：打开对话会关闭指令，打开指令会结束 / 关闭当前对话；二者不会重叠显示。
- NPC 面板与建筑面板既有互斥、状态刷新不抢占等回归仍通过。

验收结果（2026-06-10）：

- GM 面板行动区已去掉单独的工作、吃饭、睡觉、当教官和当受训者按钮，普通行动统一通过行动下拉和“指定行动”按钮触发；需要额外目标参数的协助修复、协助升级和协助治疗入口继续保留。
- NPC 面板事件库和见闻库改为固定高度滚动框，内容完整保留，刷新后自动滚到底部，面板不会因大量事件继续变高。
- NPC 面板点击“对话”或“指令”不再关闭 NPC 面板；`DialogPanel` 与 `OrderPanel` 互斥，打开其中一个会关闭另一个，避免中央弹窗重叠。
- 已更新 `tools/verify_gm_panel.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_dialogue_ui.gd` 和 `tools/verify_npc_order.gd` 的验收断言。
- 验证通过：`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --script res://tools/verify_npc_order.gd`、临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py` 后运行 `godot --headless --path . --script res://tools/verify_dialogue_ui.gd`、`godot --headless --path . --quit-after 1`。

---

## T0015 修正 NPC 成长 UI 与 GM 入伍入口

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

修正 T0904 后 NPC 面板成长信息的展示密度，并为 GM 面板补充“让选中 NPC 入伍”的调试入口。

验收标准：

- NPC 面板不再显示“成长：...”说明文本。
- 经验显示为 `经验：当前/阈值`，格式类似 HP，并位于 HP 行右侧。
- 力量和智力仍显示在属性行；只有存在未分配技能点时，才在对应属性旁显示可点击 `+1` 按钮。
- 点击 `+1` 后消耗技能点并刷新面板；如果没有剩余技能点，按钮消失。
- GM 面板 NPC 分组提供“设为入伍”按钮，调用 NPCSystem 入伍权威入口，使选中 NPC 变为可指派 / 可发布指令状态。
- NPC 面板、T0904 成长、GM 面板和入伍指令相关验证通过。

验收结果（2026-06-10）：

- NPC 面板已移除独立“成长：...”说明文本，经验改为 HP 行右侧的 `经验：当前 / 阈值`。
- 属性行改为内联显示“力量 X / 智力 Y”；只有有未分配技能点且对应属性未达上限时，才在该属性旁显示 `+1` 按钮。
- 点击属性 `+1` 会调用 `NPCSystem.assign_npc_attribute_point(...)`，用完最后一个未分配技能点后按钮立即消失。
- GM 面板 NPC 分组新增“设为入伍”按钮，并补充 `recruit_npc <npc_id>` 命令；二者都调用 `NPCSystem.set_npc_recruited(...)`，让选中 NPC 进入可发布指令状态。
- 已更新 `tools/verify_skill_progression.gd`、`tools/verify_npc_panel_state.gd` 和 `tools/verify_gm_panel.gd`。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_skill_progression.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_npc_order.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --script res://tools/verify_dialogue_ui.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

---

## T0016 优化建筑面板工位显示

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `ECONOMY_AND_BUILDINGS.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

去掉建筑面板中单独的“当前工作位 x/x”汇总行，把工位容量信息合并到具体工位 / 床位 / 训练位行内展示，减少重复信息。

验收标准：

- 建筑面板不再显示单独的“当前工作位 x/x”汇总行。
- 每种工位按类型分别显示 `工位名 空闲数/总数：占用者`。
- 无占用者时显示“空闲”；存在占用者时显示对应 NPC 名字，多个占用者用顿号分隔。
- 诊所、训练场等多类型位置分别显示，例如医生、病床、教官、受训者各自有自己的空闲数 / 总数。
- 空闲数与总数来自建筑真实工位数组，不能用旧汇总行或写死值代替。
- 建筑面板和工位占用相关验证通过。

验收结果（2026-06-10）：

- `BuildingPanel` 已移除单独的“当前工作位 x/x”汇总行，场景默认占位也改为 `工位：--`。
- 工位显示改为按 `type` 分组，格式为 `工位名 空闲数/总数：占用者`；无占用者显示“空闲”，多个占用者用顿号分隔。
- 占用者由 `NPCSystem.get_npc(...)` 转换为 NPC 名字，不再直接显示 NPC id。
- 小诊所的医生 / 病床、训练场的教官 / 受训者等多类型位置会分别显示，空闲数和总数来自传入的真实工位数组。
- 新增 `tools/verify_building_panel_workstations.gd`，覆盖空闲工位、占用者名字、多类型分组和无工位建筑。
- 验证通过：`godot --headless --path . --script res://tools/verify_building_panel_workstations.gd`、`godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`godot --headless --path . --script res://tools/verify_work_output_framework.gd`。

---

## T0017 升级并对齐 Godot MCP server / addon 版本

状态：Done
优先级：P0
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

解决 Godot MCP 可连接但 Node 侧 server 与项目 addon 版本不一致的问题，优先升级到当前 npm 最新版本，而不是回退 addon。

验收标准：

- Codex MCP 工具 `godot_project.addon_status` 显示 `connected=true`。
- `server_version` 与 `addon_version` 一致。
- `versions_match=true`。
- `tools/check_godot_mcp.ps1` 返回正常连接状态，且不再存在绕过 broker 的直连 Godot MCP 客户端。
- 升级不破坏 `MCPGameBridge` 运行桥接类缓存修复。

验收结果（2026-06-17）：

- 已安装全局 `@satelliteoflove/godot-mcp@4.0.1`，`godot-mcp.cmd --version` 返回 `4.0.1`。
- 已将项目 `addons/godot_mcp` 升级到 `4.0.1`；安装器未能在中文路径下正确落回 addon 目录时，已从全局 npm 包的 `addon` 目录机械恢复到 `addons/godot_mcp`。
- `MCPGameBridge` 已保留 / 补回显式 `preload`：`mcp_runtime_state_sampler.gd`、`key_names.gd`、`joy_names.gd`、`mcp_exec_guard.gd`，避免依赖 `.godot` 全局类缓存。
- 已更新用户目录 `godot-mcp-broker.mjs`，兼容 4.0.1 的新版工具名、无旧 resources 入口结构和新版 tool result 内容格式；旧 Codex 工具壳 `project` / `editor` / `scene` / `resource` 可继续转发到新版 `godot_*` 工具。
- 验证通过：`godot_project.addon_status` 返回 `connected=true`、server/addon 均为 `4.0.1`、`versions_match=true`；`godot_editor.get_state` 正常返回当前 `res://scenes/main/Main.tscn`；`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1` 返回 `Godot MCP connected`；`godot --headless --path . --quit-after 1` 无报错。

---

## T0018 NPC 面板事件库 / 见闻库详情弹窗

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

在 NPC 面板中点击事件库或见闻库时，打开一个更大的详情弹窗，方便查看当前 NPC 的完整亲历事件或见闻详情。

验收标准：

- 点击 NPC 面板中的事件库区域会打开事件库详情弹窗。
- 点击 NPC 面板中的见闻库区域会打开见闻库详情弹窗。
- 弹窗显示当前 NPC 名称、记录条数和更完整的事件字段，例如时间、summary、类型、地点、可见性、参与者、目标和 payload。
- 弹窗右上角有关闭图标，点击后关闭弹窗。
- 弹窗只读取 `MemorySystem` / NPC 面板已有数据，不修改事件库、见闻库或任何权威状态。
- NPC 面板既有固定高度滚动区、自动滚到底部、建筑 / NPC 面板互斥、对话 / 指令弹窗互斥等回归仍通过。

验收结果（2026-06-25）：

- `NPCPanel` 在事件库和见闻库标题 / 正文区域接入点击输入，点击后打开居中的 `NPCMemoryDetailPopup`。
- 详情弹窗显示当前 NPC 名称、事件库 / 见闻库类型、记录条数，以及每条记录的日期、时间、summary、类型、地点、可见性、重要度、事件 ID、参与者、目标和 payload JSON。
- 弹窗右上角 `×` 关闭按钮可关闭；切换 NPC 无效、关闭 NPC 面板或点击建筑时会同步关闭详情弹窗。
- 该弹窗只读取 NPC 面板缓存的事件 / 见闻数组，不修改 `MemorySystem` 或任何权威状态。
- `tools/verify_npc_panel_state.gd` 已覆盖详情弹窗打开、内容显示、关闭按钮、点击连接存在，以及既有 NPC 面板滚动区和互斥回归。

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
涉及文档：`CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

验收标准：
- 每个 Codex 会话保留自己的 `godot-mcp-proxy.mjs`，关闭一个会话不会终止其他会话的 proxy。
- 单例边界只放在 broker：任意并发启动最终只保留 1 个监听 `8765` 的 broker 和 1 条连接 Godot `6550` 的链路。
- `tools/check_godot_mcp.ps1` 可以区分“多 proxy（正常）”“proxy 在但 broker 不在”“直连 Godot 客户端”和“正常连接”状态。
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

架构修正（2026-06-04）：
- 之前“同父进程只能保留一个 proxy”的判断不成立：Codex 每个会话都需要独立 stdio proxy；新 proxy 杀旧 proxy 会直接让旧会话收到 `Transport closed`。
- 已移除 `godot-mcp-proxy.mjs` 的 sibling kill / proxy lock；每个 proxy 仅在自己的 stdin 关闭时退出。
- `godot-mcp-broker.mjs` 改为先抢占单例端口 `8765`，再连接 Godot，避免两个首次启动的 broker 同时连接并互相替换。
- 旧 `start-godot-mcp.ps1` 已移除清理进程和直连 Godot 的逻辑，只允许启动单例 broker。
- 新增 `tools/verify_godot_mcp_topology.mjs`，验证多 proxy、单 broker、单 Godot 连接，以及关闭一个 proxy 不影响其余会话。
---

## T0007 Restore local development dependencies after OS reinstall

状态：Done
优先级：P0
涉及文档：`CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：
在重装电脑后的干净环境中，恢复本项目开发与验证所需的基础工具链。

验收标准：
- `godot` 可从命令行运行，版本符合 Godot 4.6。
- Python 可运行，并能在项目 `.venv` 中安装 `backend/requirements.txt`。
- Node.js / npm 可运行，Godot MCP npm 包可用。
- VSCode 已安装 Godot Tools 与 Python 扩展，项目 Godot 路径指向当前机器可用路径。
- 后端 Schema / Mock / 对话接口验证通过。
- Godot headless 项目加载与关键 GM / LLMBridge 验证通过。
- Godot MCP 插件与 Codex 侧 MCP server 可连接。

验收结果（2026-06-07）：
- 已安装 Python 3.12.10、Node.js 24.16.0 LTS、npm 11.13.0、Godot 4.6.3、`@satelliteoflove/godot-mcp` 3.7.0。
- 已创建 `.venv` 并安装 `backend/requirements.txt`；`.gitignore` 已忽略 `.venv/`。
- 已安装 VSCode Python 扩展；Godot Tools 已存在；`.vscode/settings.json` 已指向 winget Godot 命令别名。
- 验证通过：`tools/verify_backend_schemas.py`、`tools/verify_mock_model_adapter.py`、`tools/verify_dialogue_mock_endpoint.py`、`godot --headless --path . --quit-after 1`、`tools/verify_gm_panel.gd`、`tools/verify_llm_bridge.gd`。
- Godot MCP 插件当前监听 `6550`，`godot-mcp.cmd --version` 返回 `3.7.0`，并已在 `%USERPROFILE%\.codex\config.toml` 增加 `mcp_servers.godot` 入口；但当前 Codex 会话不会热加载新 MCP 配置，自检仍显示“Godot plugin is running, but MCP is not connected”。需要重启/刷新 Codex 后复验。
- 当前 Codex MCP 配置使用 npm 包入口 `cmd /c godot-mcp.cmd`；历史 `proxy -> broker -> Godot` 自定义脚本在本机重装后缺失，后续若需要严格恢复多会话 broker 拓扑，应追加任务重建 `%USERPROFILE%\.codex\scripts\godot-mcp-proxy.mjs` 与 `godot-mcp-broker.mjs`。

追加修复（2026-06-07）：
- 重启 Codex 后，Codex 侧 `godot-mcp` server 已启动，但 `godot_project.addon_status` 返回 `connected=false`；排查发现项目内 `addons/godot_mcp` 仍为 `2.17.0`，与 npm server `3.7.0` 不匹配。
- 已执行 `godot-mcp.cmd --install-addon . --force`，将项目内 Godot MCP addon 升级到 `3.7.0`，并重启 Godot 编辑器。
- 外部 Node 握手验证通过：`serverVersion=3.7.0`、`addonVersion=3.7.0`、`versionsMatch=true`，`get_project_info` 可返回项目名和 `res://scenes/main/Main.tscn`。
- 修复过程中清理了本会话的旧 MCP 子进程，导致当前 Codex MCP transport 返回 `Transport closed`；按历史经验该状态不能在同一会话热恢复，需要再次重启/刷新 Codex 后用 `godot_project.addon_status` 复验。
- 再次重启后，确认 Godot 编辑器、插件端口 `6550` 和 Codex `godot-mcp` 进程都存在，但 Codex 工具仍显示 `connected=false`；外部 Node 分别使用 `127.0.0.1` 与 `localhost` 连接 `6550` 均成功，说明 Godot 侧与 addon 版本已正常。已将 `%USERPROFILE%\.codex\config.toml` 的 `mcp_servers.godot.args` 固定为 `set GODOT_HOST=127.0.0.1&& set GODOT_PORT=6550&& godot-mcp.cmd`，需要再重启 Codex 让新 server 进程读取该配置。
- 继续复验时 `editor.get_state` 返回 “Another MCP server connected and replaced this one”，说明当前 Codex MCP server 已经被其他连接替换并停止重连。已将 `%USERPROFILE%\.codex\config.toml` 改为直接启动 `C:\Users\93741\AppData\Roaming\npm\godot-mcp.cmd`，并通过 `env = { GODOT_HOST = "127.0.0.1", GODOT_PORT = "6550" }` 设置环境变量，避免内联 `cmd /c set ...`。需要重启 Codex，让新的 server 进程以干净状态启动。
- 最终复验通过：重启 Codex 后 `godot_project.addon_status` 返回 `connected=true`，server/addon 均为 `3.7.0` 且 `versions_match=true`；`godot_editor.get_state` 正常返回当前场景 `res://scenes/main/Main.tscn`。
- 换环境复用清单已固化：下次迁移/重装时先锁定 `@satelliteoflove/godot-mcp@3.7.0`，确认 `addons/godot_mcp/plugin.cfg` 与 `godot-mcp.cmd --version` 一致；必要时运行 `godot-mcp.cmd --install-addon . --force` 并重启 Godot；Codex 配置使用直接 `godot-mcp.cmd` 命令和 TOML `env` 表设置 `GODOT_HOST=127.0.0.1`、`GODOT_PORT=6550`；修改 config 后重启 Codex；复验只用 `godot_project.addon_status` / `godot_editor.get_state`，不要在 Codex 已连接时用外部 WebSocket 客户端直连 `6550`。

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
- 工位状态（T0016 后按类型显示空闲数 / 总数与占用者）
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
- 点击建筑后，面板通过 `EventBus.building_clicked(building_id)` 从 `BuildingSystem` 读取建筑名称、等级、HP / Max HP、工作位和地点信息占位；T0016 后工位展示已调整为按类型显示空闲数 / 总数与占用者。
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
- 其他 NPC 初始未入伍，不能接收守备官个人指令。
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
- 菜园工作可产出粮食；食堂工作可消耗粮食产出餐食；酒窖可消耗粮食产出酒；铁匠铺可消耗铁产出武器/盔甲库存占位；工械坊可消耗木材产出工程器械；马厩可消耗粮食产出马匹整备占位；吃饭优先消耗餐食并恢复更多饱食度，没有餐食时消耗粮食；睡觉降低疲劳。
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
- 玩家速度 `x1` / `x2` / `x4` 只影响逻辑时间与工作 / 日常等按时间结算的倍率；T1104A 后明确不直接改变战斗伤害、攻击速度或战斗移动速度。
- 新增 LLM 等待减速底层接口：`request_time_slowdown(request_id, scale, reason)`、`release_time_slowdown(request_id)`、`clear_time_slowdowns()`。
- 默认 LLM 等待倍率为 `1/60`，即默认 `x1` 下从现实 1 秒 = 游戏 1 分钟减缓为现实 1 秒 = 游戏 1 秒。
- 新增 `time_scale_changed(player_scale, effective_scale, numeric_multiplier, reason)` 和 `logical_time_tick(game_delta_seconds, numeric_multiplier)`，供资源、计划、事件等系统按有效逻辑倍率结算；T1104A 后战斗数值不再读取玩家 `x2` / `x4` 作为额外倍率。
- 已补充验证：LLM 等待减速时 `get_game_delta_seconds(1.0)` 返回 1 游戏秒，释放后在无其他上限时恢复玩家设定倍率。

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
- `dialogue_turn`；打开/关闭对话窗口不属于事件
- `money_given`、`equipment_given`、`equipment_changed`、`order_assigned`、正式惩戒攻击使用的 `damage_taken`，以及旧调试 / 兼容事件 `npc_attacked_by_player`
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

- `money_given`、`equipment_given`、`equipment_changed`、`order_assigned`、正式惩戒攻击使用的 `damage_taken` 和旧调试 / 兼容 `npc_attacked_by_player` 等玩家交互 summary 使用“守备官”。
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

历史说明：M6 的 Mock 是开发期脚手架。自 M14 起，凡是历史 LLM / Mock 任务被重验、扩展或接入成品路径，都必须套用 0.6 的真实 API 验收与 mock 封存规则；不得把 M6 的开发默认 mock 当作 Demo / 成品兜底。

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
- 已新增 `backend/schemas/npc_ai.py`，覆盖 NPC 对话（玩家-NPC、NPC-NPC、逃离挽留）、每日计划、计划异常重评估、战斗判定、首次睡眠总结、知识图谱更新、主动找守备官交涉和玩家话术分类的请求/响应模型。
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
- current_order（目标 NPC 当前收到的守备官自然语言指令；由 T0703A 扩展到对话和共享 NPC LLM 上下文，当前已完成的 T0603 程序合同尚未包含）


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
- 后续设计扩展：T0703A 需要在不改变 T0603 既有对话职责的前提下，把 `current_order` 加入目标 NPC 输入；它是参考上下文，不是 system 指令或已执行行动。

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
- LLM 请求等待期间有效逻辑时间倍率降为 `1/60`，请求结束后释放该慢速请求；若没有敌人在场上限等其他请求，则恢复玩家设定倍率。
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

状态：Done
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
- 对话事件写入双方 NPC 事件库；对话全文、说话者名称、听者名称、公开性、当前轮次、最大轮次和征召标记存入事件 `payload`。
- 若 `dialogue_state.visibility == "local_public"`，对话事件按地点规则广播给同地点第三者见闻库；`private` 只进入对话双方事件库。

验收结果（2026-06-04）：
- NPC 面板新增“对话”按钮，可打开 `Main/UI/DialogPanel`；窗口显示 NPC 名字、对话历史、轮次、输入框、发送按钮和结束按钮。
- `DialogSystem` 负责玩家-NPC 会话状态、历史、后端请求和事件入库；玩家-NPC 对话不限轮次，NPC-NPC 对话默认最多 5 轮，双方各发言一次后当前轮次加一。
- 仅实际发生的 `dialogue_turn` 写入参与 NPC 事件库；`dialogue_turn.payload` 保存对话全文、说话者/听者名称、公开性、当前/最大轮次和征召标记，但本任务不修改征召状态。打开或关闭对话窗口不入库、不广播。
- `private` 对话不写入第三者见闻；`local_public` 对话只广播一次给同地点、非参与者且可接收见闻的 NPC。
- 2026-06-04 修复 DialogPanel “同地点公开”开关被永久禁用的问题：首轮发送前可切换并同步到 DialogSystem，首轮发送后锁定。
- 2026-06-04 对话事件降噪：移除 `dialogue_started` / `dialogue_ended` 入库和广播，只保留实际对话轮次 `dialogue_turn`。
- 验证通过：`tools/verify_dialogue_ui.gd`、`tools/verify_llm_bridge.gd`、`tools/verify_structured_memory_events.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_gm_panel.gd`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_mock_endpoint.py`、`godot --headless --path . --quit-after 1`；Godot MCP 运行主场景无游戏日志报错。

---

## T0702 实现“提出应征”按钮与征召结果

状态：Done
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
- 不实现战斗指令或战斗策略。

验收标准：

- NPC 接受后面板显示已入伍。
- 已入伍 NPC 可出现后续“指令”入口占位。
- 拒绝后不改变入伍状态。
- 征召与否被记录在对话事件payload中。

验收结果（2026-06-04）：

- `DialogPanel` 新增“提出应征”按钮；点击后只把下一次玩家对话请求标记为 `is_recruitment_request=true`，发送后自动清除待请求状态。
- `DialogSystem` 只接受合法的 `accept` / `reject` 结果；`accept` 通过 `NPCSystem.set_npc_recruited(...)` 权威更新 NPC `recruited=true`，`reject` 不改变状态。
- 应征请求与结果写入该轮 `dialogue_turn.payload.is_recruitment_request` / `recruitment_result`，并进入目标 NPC 事件库。
- NPC 面板会立即显示已入伍，并仅对已入伍 NPC 显示禁用的“指派（占位）”按钮；T0703 将把该占位替换为自然语言“指令”入口。
- 验证通过：`tools/verify_dialogue_ui.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_structured_memory_events.gd`、`tools/verify_llm_bridge.gd`、`tools/verify_gm_panel.gd`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_mock_endpoint.py`、`godot --headless --path . --quit-after 1`。

---

## T0703 实现入伍 NPC 自然语言指令入口与存储

状态：Done
优先级：P0
前置任务：T0702
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`, `DATA_SCHEMA.md`, `MEMORY_AND_INFO_SPACE.md`

任务目标：

让玩家从已入伍 NPC 面板打开自由文本指令面板，查看、修改并发布该 NPC 的当前指令。正式指令不是行动选项下拉，也不直接调用 ActionSystem 启动工作、吃饭、睡觉、移动、训练或治疗。

实现范围：

- 把当前禁用的“指派（占位）”按钮替换为已入伍 NPC 可用的“指令”按钮。
- 新增指令撰写与发布面板，使用自由文本输入；打开时预填该 NPC 当前 `current_order.text`。
- NPC 信息中保存结构化 `current_order`：当前文本、发布者、最近发布时间和修订号。
- 点击“发布”时比较新旧文本；只有不同才覆盖旧指令并递增修订号。
- 指令变化时写入目标 NPC 的 `private` `order_assigned` 事件，summary 为“守备官制定了新的指令。”，payload 保存新旧文本和修订号。
- 指令变化时发出统一的“请求计划重评估”信号或接口，供 T0703A / T1002 接入真实重评估链路。
- 点击“关闭”或发布相同文本时，不修改数据、不写事件、不触发计划重评估请求。

禁止事项：

- 未入伍 NPC 不能发布或修改个人指令。
- 不把指令文本解析成硬性 ActionSystem 调用。
- 不让 UI 直接修改计划、行动、资源、HP 或战斗结果。
- 不把 `order_assigned` 广播到地点或广场。

验收标准：

- 副官开局可打开指令面板；被征召 NPC 可在入伍状态更新后打开。
- 未征召 NPC 的指令按钮不可用或不显示。
- 已有指令会在再次打开面板时预填，并可被新文本覆盖。
- 发布不同文本会更新 `current_order`、写入一条 `private` `order_assigned` 事件并发出计划重评估请求。
- 发布相同文本或关闭面板后原指令保持不变，无新增事件或重评估请求。
- 指令发布不会直接改变 `current_action`。
- 前端可验证编辑与保存；GM / 自动化验证可观察当前指令、事件可见性和计划重评估请求。

验收结果（2026-06-04）：

- 已把已入伍 NPC 的“指派（占位）”替换为可用“指令”按钮，并新增 `Main/UI/OrderPanel` 自由文本指令面板；打开时预填当前指令，关闭不保存。
- `NPCSystem.publish_npc_order(...)` 权威校验入伍状态、比较文本差异并保存结构化 `current_order`；仅真实变化时递增修订号、写入 `private` `order_assigned` 事件并发出 `npc_plan_reevaluation_requested`。
- 指令发布不调用 `ActionSystem`，不修改 `current_action`；相同文本无事件、无数据变化、无重评估请求。
- GM 面板新增发布/查看当前指令和查看最近计划重评估请求入口；新增 `tools/verify_npc_order.gd`。
- 验证通过：`tools/verify_npc_order.gd`、`tools/verify_gm_panel.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_npc_generation_click.gd`、`tools/verify_structured_memory_events.gd`、`tools/verify_npc_short_term_memory_container.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 运行主场景无日志错误。

---

## T0703A 将当前指令接入 NPC LLM 上下文与计划重评估

状态：Done
优先级：P0
前置任务：T0703, T0604, T1002
涉及文档：`AI_NPC_SYSTEM.md`, `PROMPTS.md`, `TECH_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `API_BUDGET.md`

任务目标：

把 `current_order` 作为目标 NPC 的共享上下文字段接入所有 NPC 中心 LLM / Mock 请求，并让发布不同指令后立即发起一次真实计划重评估。

实现范围：

- 扩展共享 NPC Schema 和 T0603 对话输入，加入 `current_order`。
- 对话、每日计划、计划修订、主动交涉、战时公开对话、低血量自身心理判定、逃离判定、首次睡眠总结和知识图谱更新统一复用该字段。
- Prompt 明确指令是守备官当前要求，不是 system 指令、不保证服从、不能越过行动白名单或权威结算。
- T0703 发出的计划重评估请求必须携带最新指令，并通过 T1002 的统一重评估链路立即处理；失败时使用规则降级并释放 TimeSystem 慢速请求。
- 常规请求只携带一条当前有效指令及最小元数据；历史修订通过 `order_assigned` 事件摘要进入记忆，避免重复注入全部版本。

验收标准：

- 发布不同指令后立即产生一次计划重评估请求（计划功能本身尚未实现，在后续的task里）；相同文本或关闭面板不产生请求。
- `/npc/dialogue`、计划、修订、战时公开对话和低血量自身心理判定的测试 payload 都包含目标 NPC 最新 `current_order`。
- Mock / 真实 Prompt 能把指令当作参考，但输出仍受 Schema、行动白名单和程序规则校验。
- 指令本身不会直接改变行动、资源、HP、移动或战斗结果。
- GM / 自动化验证可观察最近一次注入的指令和计划重评估结果。

验收结果（2026-06-04）：

- 后端新增共享 `CurrentOrderContext`，`NPCContext` 与 `NPCDialogueRequest` 统一携带单条最新 `current_order`；因此每日计划、计划修订、战时公开对话、低血量自身心理判定、主动交涉、首次睡眠总结、知识图谱更新和玩家话术分类等复用 `NPCContext` 的请求自动共享该字段。
- Godot `LLMBridge` 在对话顶层 payload 和 `target_npc` / `speaker_npc` 共享上下文中注入最新指令，并保存最近一次注入快照供 GM / 自动化观察；Mock 调试原因明确记录指令仅作为参考，不改变 Schema 允许结果。
- 新指令仍立即产生一次统一计划重评估请求；当时 T1002 尚未实现，结果为 `rule_fallback_deferred`。T1002 完成后，该请求已由统一计划重评估链路消费，成功时应用 Mock 修订计划，失败时应用规则降级计划。
- GM 面板后端分组新增“最近指令注入”入口和 `last_order_injection` 命令；最近计划重评估请求可同时观察降级结果。
- 验证通过：`python tools/verify_backend_schemas.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、Python 编译检查、`verify_llm_bridge.gd`、`verify_dialogue_ui.gd`、`verify_npc_order.gd`、`verify_gm_panel.gd`、结构化记忆回归和项目加载检查；Godot MCP 连接正常，运行主场景无日志错误。

---

## T0704 实现玩家非对话交互记忆

状态：Done
优先级：P0
前置任务：T0405, T0702
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `AI_NPC_SYSTEM.md`, `UI_UX.md`

任务目标：

玩家除了对话以外的行为也要进入结构化事件系统，并写入目标 NPC 事件库。

交互包括：

- 赠予金钱
- 给予 / 更换装备
- 攻击 NPC 造成伤害

禁止事项：

- 不实现完整装备系统也可先用占位装备。
- 不实现复杂威胁 UI。
- 不重复实现 T0703 已负责的 `order_assigned` 指令事件。

验收标准：

- 给钱事件写入目标 NPC 事件库，并按地点可见性通过地点/广场节点即时广播给当前在场 NPC。
- 攻击事件写入目标 NPC 事件库与广场公开信息。
- 后续对话请求会带上这些记忆摘要。

验收结果（2026-06-05）：

- `NPCPanel` 新增非对话交互区：可选择 `private` / `local_public` 可见性，直接赠予第纳尔、给予旧占位武器、攻击造成 10 点伤害；给钱数量输入框紧邻“给钱”按钮，并只保留数字输入，WASD 等字母键不会写入金额。该旧占位武器入口已在 T0013 后移除，正式装备统一走 T0901 `EquipmentSystem`；T1006 后攻击入口已移至 `DialogPanel`，`NPCPanel` 不再提供直接攻击按钮。
- 新增 `UIInputFocusManager` 挂载到 `Main/UI`：任意 `LineEdit` / `TextEdit` 获得焦点后，点击输入框外任意位置都会释放焦点，后续新增输入框默认遵循同一交互规则。
- 赠予第纳尔由 `NPCSystem.give_money_to_npc(...)` 扣除全局第纳尔、增加目标 NPC 随身金钱，并复用 `MemorySystem.record_player_interaction(...)` 写入 `money_given`；公开时同地点 NPC 会收到见闻。
- 给予装备仅做 T0704 范围内的旧占位武器：消耗 1 个全局 `weapons` 资源，写入 `equipment_given` / `equipment_changed`，不实现 T0901 正式装备库存、兵种或战斗数值。该入口已在 T0013 后移除。
- 攻击仍复用 `NPCSystem.apply_damage_to_npc(...)` 权威扣血入口，写入 `damage_taken`，HP 清零仍走既有昏迷/公开广播链路；T1006 后该入口由对话窗攻击按钮触发，并追加 NPC 攻击语境回复。
- 已移除 NPC 面板里的“要求休息/请求治疗”入口；休息、治疗这类意图由 T0703 的自然语言指令承担，既有 GM / ActionSystem 调试入口不变。
- 新增 `tools/verify_npc_panel_interactions.gd` 覆盖 NPC 面板给钱、公开见闻、占位装备、攻击扣血、广场公开事件、后续 NPC LLM 上下文短期记忆摘要，并检查休息/治疗按钮不存在；同时覆盖 NPC 给钱金额框、对话输入框和指令 TextEdit 点击外部失焦。T1006 后该脚本改为确认攻击入口已移出 NPC 面板，攻击扣血与回复由 `tools/verify_dialogue_ui.gd` 覆盖。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`verify_npc_panel_state.gd`、`verify_gm_panel.gd`、`verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。`verify_dialogue_ui.gd` 需要 5000 端口 mock 后端；本机当前端口被 deepseek provider 后端占用，因此未作为本次通过项。

---

## T0705 实现 NPC 主动找玩家交涉

状态：Done
优先级：P1
前置任务：T0701, T0405
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`

任务目标：

NPC 可主动请求与玩家对话。这作为一个行为进入NPC的可选行为中，在制定计划的时候可以加入行为列表（连带着想和玩家说什么问什么的话）（计划功能尚未在本任务前的任务里实现，如有实现不了的，就加到后面的任务里）。

实现范围：

- 执行该行动后NPC 进入“主动找玩家交涉”状态
- “发起主动交涉”这种行为作为private事件进入发起者的事件库。玩家点击了气泡则不需要变成事件。只按照对话逻辑，NPC对玩家说什么（不同的是，在NPC主动找玩家对话的这种情形里，NPC问的话会先入库），或者玩家如果和NPC说了什么，说的内容按照正常对话逻辑入库。
- 头顶显示问号气泡
- 暂定持续1h，若1h后仍未被玩家点击，则视为该状态结束。
- 玩家点击后打开对话（沿用玩家和NPC对话的面板），把NPC想问什么的话显示出来（这个话在计划阶段就已经确定了，而不是在点击气泡的时候调用LLM生成的），玩家可以回复，然后就进入正常的玩家和NPC对话的逻辑。
- 对话结束后 NPC 重新评估计划。

禁止事项：

- 不接真实 LLM 主动意图也可以先用规则触发。

验收标准：

- 可通过调试按钮让 NPC 主动找玩家。
- 问号气泡显示正确。
- 点击后进入对话。
- 对话结束后气泡消失。
- 若1h后仍未被玩家点击，气泡消失。

验收结果（2026-06-05）：

- `NPCSystem` 新增主动交涉状态：`debug_start_proactive_talk(npc_id, text, duration_seconds)` 可触发 NPC 进入 `proactive_talk`，默认持续 3600 游戏秒；触发时写入 `private` 的 `proactive_talk_started` 事件，完整开场问题进入 payload。
- `NPC.gd` 运行时生成头顶 `?` 气泡；玩家点击有主动交涉的 NPC 时优先打开 `DialogPanel`，不会先弹出 NPC 面板。
- `DialogSystem.start_proactive_player_dialogue(...)` 复用玩家-NPC 对话面板，把 NPC 预先确定的开场问题作为第一条历史显示，并写入 `proactive_talk_message`；玩家后续回复继续走既有 `send_player_message(...)` / `/npc/dialogue` / `dialogue_turn` 逻辑。
- 主动交涉被点击或超时后气泡消失；对话结束或 1 小时超时都会请求计划重评估。当时仍按 T0703A 的 `rule_fallback_deferred` 可观察降级结果处理；T1002 完成后已改为进入统一计划重评估链路并应用 Mock 修订或规则降级计划。
- GM 面板新增“主动交涉”按钮、`start_proactive <npc_id> <text>` 命令和 `proactive <npc_id>` 状态查询。
- 新增 `tools/verify_npc_proactive_talk.gd`，覆盖调试触发、私有事件、问号气泡、点击进入对话、开场问题入库、对话结束重评估和超时消失。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_proactive_talk.gd`、`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`verify_npc_order.gd`、`verify_npc_panel_interactions.gd`、`godot --headless --path . --quit-after 1`。

---

# M8：职业工作、生产与经营闭环

目标：让建筑和 NPC 职业熟练度产生实际经营价值，形成粮食、餐食、酒、装备、马匹、治疗、工程器械等基础产出。

---

## T0801 实现职业工作产出框架

状态：Done
优先级：P0
前置任务：T0305, T0202, T0203
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`

任务目标：

建立统一工作产出公式。

需要考虑：

- 工种
- NPC 对应熟练度加成
- 工作对应力量或智力加成
- 建筑等级加成
- 可进入建筑的真实工位占用与释放
- 产出/消耗一份资源的最小工作周期时长
- TimeSystem 有效逻辑时间倍率
- 单位周期内消耗的资源（原料）
- 单位周期内输出资源（产出）
- 单位周期内疲劳与饱食消耗

禁止事项：

- 不做复杂平衡。
- 不做所有职业特殊逻辑。

验收标准：

- 同一工作若由高熟练或高对应属性的 NPC 执行，产出更高或耗时更短。
- 资源不足时工作失败。
- 工作开始和结束写入结构化事件和 NPC 事件库（为了降噪，连续的多个工作单位周期，只计入第一个周期的开始事件和最后一个周期的结束事件，也就是如果NPC按照计划终止工作或碰到异常中止工作时的结束工作）。
- 工作开始、取消、失败或完成时正确占用/释放可进入建筑工位，并让地点信息节点广播内部状态变化。
- 资源产出/消耗、饱食和疲劳变化使用 `TimeSystem` 的逻辑时间倍率或 `logical_time_tick`，不依赖真实帧率或 NPC 移动速度。
- 在 T0305 持续行动基座上细化工作连续结算：确定各工作是否按小时批次、按分钟消耗投入、按进度产出或支持中途取消返还/损耗，避免后续数值误以为工作是瞬时点击结果。

验收结果（2026-06-09）：
- `BuildingSystem` 新增 `claim_workstation(...)` / `release_workstation(...)` 权威接口，工作开始占用可进入建筑工位，完成、资源失败或中断时释放；工位变化继续由 `MemorySystem` 通过建筑状态信号广播为地点内部状态变化。
- `ActionSystem` 的工作行动新增统一效率公式：NPC 对应熟练度、力量/智力属性和建筑等级会缩短单位工作周期；低熟练不会低于原始时长，高熟练 NPC 能更快完成同一单位产出。
- 工作仍以 `data/action_defs.json` 的 `duration_seconds` 为单位周期基准，调试指派默认执行 1 个工作单位；投入资源在单位完成时扣除，资源不足会写入 `work_failed` 并释放工位，产出和饱食/疲劳仍随 `logical_time_tick` 推进。
- `work_started` / `work_completed` payload 补充 `workstation_id`、`building_id`、`base_duration_seconds`、`duration_seconds` 和 `efficiency_multiplier`，为后续多周期计划工作保留事件降噪边界。
- 新增 `tools/verify_work_output_framework.gd`，验证高熟练更快完成、工位占用/释放、占满工位拒绝第二名工人、资源不足失败不占工位、地点内部状态广播和事件写入。
- 验证通过：`godot --headless --path . --script res://tools/verify_work_output_framework.gd`、`godot --headless --path . --script res://tools/verify_action_system_basic.gd`、`godot --headless --path . --script res://tools/verify_location_info_nodes.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T0802 实现食堂：粮食加工餐食

状态：Done
优先级：P0
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`

验收标准：

- 食堂工作消耗粮食，产出餐食。
- 厨艺、厨房等级影响效率。
- 如果有餐食的话，NPC 优先吃餐食恢复更多饱食度（比直接吃粮食性价比更高）。
- 工作和吃饭事件进入结构化事件与 NPC 事件库。

验收结果（2026-06-09）：
- `data/action_defs.json` 中 `work_dining_hall` 已明确使用 `厨艺`，消耗 1 份粮食并产出 1 份餐食；食堂工位由 T0801 的 `BuildingSystem.claim_workstation(...)` / `release_workstation(...)` 维护。
- 食堂工作效率沿用统一公式：厨艺、智力和食堂建筑等级会缩短单位加工周期；食堂升级后同一厨子的加工时间会进一步缩短。
- `eat_at_dining_hall.food_options` 按餐食优先于粮食排列；餐食恢复 50 点饱食度，粮食恢复 25 点饱食度。
- 新增 `tools/verify_dining_hall_meals.gd`，验证粮食转餐食、厨艺/食堂等级效率、餐食优先吃、餐食性价比高于粮食，以及 `work_started` / `work_completed` / `eat_completed` 事件进入 NPC 事件库。
- 验证通过：`godot --headless --path . --script res://tools/verify_dining_hall_meals.gd`。

---

## T0803 实现菜园：产出粮食

状态：Done
优先级：P0
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`

验收标准：

- 菜园工作产出粮食。
- 耕种熟练度、力量影响产出。
- 建筑等级影响产出。

验收结果（2026-06-09）：
- `data/action_defs.json` 中 `work_garden` 已明确使用 `耕种` 与 `strength`，基础产出 2 份粮食，并通过 `output_scaling` 让耕种熟练度、力量和菜园等级提高粮食产量。
- `ActionSystem` 新增工作产出缩放计算，工作完成时按缩放后的 `output_resources` 增加资源，并把实际产出写入 `work_completed.payload.output_resources`；食堂等未配置 `output_scaling` 的工作仍保持固定产出。
- 新增 `tools/verify_garden_grain_output.gd`，验证菜园产粮、耕种影响产出、力量影响产出、菜园升级影响产出，以及完成事件记录缩放后的粮食产出。
- 验证通过：`godot --headless --path . --script res://tools/verify_garden_grain_output.gd`、`godot --headless --path . --script res://tools/verify_work_output_framework.gd`、`godot --headless --path . --script res://tools/verify_dining_hall_meals.gd`。

---

## T0804 实现铁匠铺：制造金属武器和盔甲

状态：Done
优先级：P0
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`

验收标准：

- 消耗铁制造基础武器或盔甲。
- 打铁、力量影响制作效率。
- 产物进入库存。
- 不需要完整装备外观，但数据可用。

验收结果（2026-06-09）：
- `data/action_defs.json` 中 `work_blacksmith` 已明确使用 `打铁` 与 `strength`，消耗 2 份铁，产出 1 份武器库存与 1 份盔甲库存。
- 铁匠铺工作沿用 T0801 统一效率公式：打铁熟练度、力量和铁匠铺建筑等级会缩短单位制作周期；铁匠铺升级后同一铁匠制作更快。
- 产物进入当前派生资源库存 `weapons` / `armor`，供 T0901 正式库存与装备系统继续细分为主武器、头盔、胸甲、腕甲、腿甲等装备部位。
- 新增 `tools/verify_blacksmith_metal_gear.gd`，验证铁匠铺行动配置、打铁/力量/建筑等级效率、铁消耗、武器/盔甲库存增加、完成事件 payload 和缺铁失败。
- 验证通过：`godot --headless --path . --script res://tools/verify_blacksmith_metal_gear.gd`、`godot --headless --path . --script res://tools/verify_work_output_framework.gd`、`godot --headless --path . --script res://tools/verify_dining_hall_meals.gd`、`godot --headless --path . --script res://tools/verify_garden_grain_output.gd`。

---

## T0805 实现工械坊：制造弓弩与防御器械

状态：Done
优先级：P1
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`

验收标准：

- 消耗木材制造弓、弩或器械。
- 工程、智力影响制作效率。
- 工程器械可先作为库存项，不必立即部署。

验收结果（2026-06-09）：
- `data/action_defs.json` 中 `work_workshop` 已明确使用 `工程` 与 `intelligence`，消耗 2 份木材，产出当前派生库存层面的 1 份 `weapons` 和 1 份 `defense_devices`。
- 工械坊工作沿用 T0801 统一效率公式：工程熟练度、智力和工械坊建筑等级会缩短单位制作周期；工械坊升级后同一工程师制作更快。
- 由于 T0901 正式装备系统尚未实现，弓/弩暂时进入通用 `weapons` 库存；由于 T1508 尚未实现，弩床、拒马等防御器械暂时进入 `defense_devices` 库存，不进行部署、自动攻击或阻挡结算。
- 新增 `tools/verify_workshop_ranged_devices.gd`，验证工械坊行动配置、工程/智力/建筑等级效率、木材消耗、武器/工程器械库存增加、完成事件 payload 和缺木失败。
- 验证通过：`godot --headless --path . --script res://tools/verify_workshop_ranged_devices.gd`、`godot --headless --path . --script res://tools/verify_action_system_basic.gd`、`godot --headless --path . --script res://tools/verify_work_output_framework.gd`、`godot --headless --path . --script res://tools/verify_blacksmith_metal_gear.gd`、`godot --headless --path . --script res://tools/verify_garden_grain_output.gd`、`godot --headless --path . --script res://tools/verify_dining_hall_meals.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T0806 实现马厩：马匹喂养和恢复

状态：Partial
优先级：P1
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`

验收标准：

- 马厩消耗粮食维护马匹。
- 养马影响马匹恢复和再生产。
- 马匹可作为装备坐骑使用。装备的时候，进入战斗模式时，到NPC坐骑槽（表现是在NPC胯下骑着），加快移动速度并且换为骑兵战斗策略（参考战斗机制文档），卸下即回到马厩。日常工作模式不骑马

验收结果（2026-06-09，Partial）：
- 已实现当前可落地的马厩经营闭环：`data/action_defs.json` 中 `work_stable` 使用养马与力量，消耗 1 份粮食，产出 `horse_readiness` 马匹整备派生库存。
- 马厩工作沿用 T0801 统一效率公式：养马熟练度、力量和马厩建筑等级会缩短单位照料周期；`output_scaling` 会让养马、力量和马厩等级提高实际马匹整备产出。
- 新增 `tools/verify_stable_horse_care.gd`，验证马厩行动配置、养马/力量/建筑等级效率、粮食消耗、马匹整备库存增加、完成事件 payload 和缺粮失败。
- T0901/T0902 已实现坐骑装备槽与骑兵判定；T1103 已接入集结 / 接敌时的低模坐骑表现且日常工作不骑马；T1105 已接入骑兵 / 骑射单位的可选战斗策略。当前仍未实现更完整的战斗移动速度加成或卸下回马厩。
- 验证通过：`godot --headless --path . --script res://tools/verify_stable_horse_care.gd`。

---

## T0807 实现酒窖：酿酒与出售

状态：Partial
优先级：P1
前置任务：T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`

验收标准：

- 酒窖消耗粮食产出酒。
- 酿酒影响效率。
- 酒可在商队处（参考文档中的交易部分）出售换金钱。
- 暂不实现饮酒。

验收结果（2026-06-09，Partial）：
- 已实现当前可落地的酒窖经营闭环：`data/action_defs.json` 中 `work_tavern` 使用酿酒与智力，消耗 1 份粮食，产出 `wine` 酒派生库存。
- 酒窖工作沿用 T0801 统一效率公式：酿酒熟练度、智力和酒窖建筑等级会缩短单位酿造周期；`output_scaling` 会让酿酒、智力和酒窖等级提高实际酒库存产出。
- 厨子布鲁诺的酿酒熟练度从 38 调整为 58，使其符合 `game_design.md` 中“厨子初始优势包含酿酒”的定位，同时仍以厨艺作为主职业优势。
- 新增 `tools/verify_tavern_wine_trade.gd`，验证酒窖行动配置、酿酒/智力/建筑等级效率、粮食消耗、酒库存增加、完成事件 payload、缺粮失败，以及酿酒不会在商人系统实现前自动把酒换成第纳尔。
- 当前未实现商队出售酒换金钱；该部分依赖 T1507 商人交易系统，并已在 T1507 中明确接收 T0807 的 `wine` 库存。
- 验证通过：`godot --headless --path . --script res://tools/verify_tavern_wine_trade.gd`、`godot --headless --path . --script res://tools/verify_action_system_basic.gd`、`godot --headless --path . --script res://tools/verify_work_output_framework.gd`、`godot --headless --path . --script res://tools/verify_dining_hall_meals.gd`、`godot --headless --path . --script res://tools/verify_garden_grain_output.gd`、`godot --headless --path . --script res://tools/verify_workshop_ranged_devices.gd`、`godot --headless --path . --script res://tools/verify_stable_horse_care.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T0808 实现小诊所：治疗行动完善

状态：Done
优先级：P0
前置任务：T0503, T0801
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `AI_NPC_SYSTEM.md`

验收标准：

- 医术、智力影响治疗速度。
- 诊所等级影响治疗效率。
- 治疗消耗金钱。
- 当医生在诊所工位，且受伤的NPC进入诊所床位接受治疗时，治疗才会开始。诊所不仅有工位也要有床位。
- 医生在诊所工位而没有NPC进入床位时（没有治疗），医生以极慢的速度增加医术熟练度，事件判定为在研读医学著作。
- 进入治疗/研读医术工位是一个行为选项，NPC进入病床参与治疗是另一个行为选项，两个都在后面的计划机制里可以安排。
- 医生在治疗中获得少量医术熟练度（和所有在工作中增加对应熟练度的逻辑一样）。

验收结果（2026-06-09）：
- 已将 `data/building_defs.json` 中小诊所拆分为 `clinic_doctor` 医生工位和 `patient_bed` 病床；诊所升级当前增加病床。
- 已新增 `data/action_defs.json` 的 `work_clinic_doctor` 与 `receive_clinic_treatment`：医生进入诊所工位坐诊/研读医术，受伤且未昏迷 NPC 进入病床接受治疗，二者是独立行动选项。
- `ActionSystem` 已实现诊所治疗闭环：只有医生在诊所工位且病人占用诊所病床时才推进治疗；治疗随 `logical_time_tick` 消耗第纳尔并恢复 HP，医术、智力和诊所等级提高治疗速度；病人 HP 回满后释放病床。
- 医生无病人时会以较慢节奏通过 `skill_improved` 事件记录“研读医学著作”并提升医术；治疗中也会以较小步进提升医术。T0904 完成后，这些医术增长已接入统一经验、未分配技能点与玩家属性分配规则。
- 新增 `tools/verify_clinic_treatment.gd`，验证诊所工位/病床、医生研读医术、病床治疗、金钱消耗、医术/智力/诊所等级效率和病床释放。
- 验证通过：`godot --headless --path . --script res://tools/verify_clinic_treatment.gd`、`godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd`、`godot --headless --path . --script res://tools/verify_work_output_framework.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

# M9：装备、熟练度、训练与升级

目标：让 NPC 能装备武器/盔甲/坐骑，通过工作、训练和战斗提升熟练度；经验达标获得技能点后，由玩家决定分配到力量或智力。

---

## T0901 实现库存与装备系统

状态：Done
优先级：P0
前置任务：T0804, T0805, T0806
涉及文档：`COMBAT_SYSTEM.md`, `DATA_SCHEMA.md`, `UI_UX.md`

任务目标：

支持 NPC 装备武器、盔甲和坐骑。

T0804 当前产出 `weapons` / `armor` 两类派生库存占位，T0805 当前把工械坊制造的弓/弩也先并入通用 `weapons` 派生库存，T0806 当前把马厩维护/恢复产出并入 `horse_readiness` 马匹整备派生库存。本任务需要把这些库存消耗并映射到可装备数据。

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
- 消耗 T0804 产出的 `weapons` / `armor` 派生库存时，不直接让 UI 决定战斗属性；装备数据、兵种和后续战斗数值仍由装备/战斗系统结算。
- 需要接住 T0805 的木质远程武器占位，把可装备主武器区分为剑盾、长杆、弓、弩等类型；不能继续只用早期占位武器代表所有武器。
- 需要接住 T0806 的 `horse_readiness`，把它转换为可装备坐骑库存或坐骑槽数据；日常工作模式不显示骑乘，进入战斗/集结时再交给战斗表现层处理。

验收结果（2026-06-09）：
- 新增 `EquipmentSystem` 并挂载到 `Main/Systems/EquipmentSystem`，读取 `data/weapon_defs.json`、`data/armor_defs.json` 和 `data/mount_defs.json`；装备主武器消耗 `weapons`，装备盔甲消耗 `armor`，装备坐骑消耗 `horse_readiness`，换装会返还旧装备对应库存。
- `data/weapon_defs.json` 已补齐剑盾、长杆、弓、弩等主武器类型；新增 `data/armor_defs.json` 和 `data/mount_defs.json`，覆盖头盔、胸甲、腕甲、腿甲和坐骑槽。T0013 后旧兼容武器定义已移除，不再作为正式装备数据。
- 只有已入伍 NPC 可由守备官直接分配装备；NPC 面板新增主武器选择并调用 `EquipmentSystem`，GM 面板新增装备武器、装备盔甲、装备坐骑和兵种查看入口及命令。
- 装备事件通过 `MemorySystem.record_player_interaction(...)` 写入 `equipment_given` / `equipment_changed`，按 `private` / `local_public` 可见性传播；同地点 NPC 可收到公开装备见闻。
- `EquipmentSystem.determine_unit_type(...)` / `get_npc_unit_type(...)` 可根据主武器和坐骑槽返回非战斗人员、近战步兵、长杆步兵、弓箭兵、弩兵、近战骑兵或骑射单位；日常模式仍不显示骑乘外观，T1103 已接入集结 / 接敌低模坐骑表现，T1105 已接入按兵种提供的可选战斗策略；更完整的骑兵速度仍留给后续移动数值任务。
- 新增 `tools/verify_equipment_system.gd`，验证已入伍限制、主武器/盔甲/坐骑库存消耗、换装返还、事件入库、公开见闻、兵种判定和 NPC 面板显示。
- 验证通过：`godot --headless --path . --script res://tools/verify_equipment_system.gd`、`verify_npc_panel_interactions.gd`、`verify_gm_panel.gd`、`verify_blacksmith_metal_gear.gd`、`verify_workshop_ranged_devices.gd`、`verify_stable_horse_care.gd`、`verify_npc_panel_state.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

---

## T0902 实现兵种判定

状态：Done
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
- 坐骑来源必须来自 T0901 装备槽，不能直接读取 `horse_readiness` 库存当作 NPC 已骑乘。

验收结果（2026-06-09）：
- `EquipmentSystem.determine_unit_type(...)` 已按主武器和 `equipment.mount` 槽判定：剑盾为近战步兵，长杆为长杆步兵，弓为弓箭兵，弩为弩兵，近战武器 + 坐骑为近战骑兵，远程武器 + 坐骑为骑射单位，无主武器为非战斗人员 / 避战单位。
- 新增 `EquipmentSystem.get_unit_type_snapshot(npc_id)`，返回兵种标签、主武器类型、武器 class、是否有坐骑、坐骑 id 和装备快照，供 GM / 后续战斗系统只读使用。
- GM `unit_type <npc_id>` 现在输出完整兵种快照，便于确认坐骑来源来自 NPC 装备槽而不是 `horse_readiness` 库存。
- 新增 `tools/verify_unit_type_classification.gd`，覆盖全部兵种映射，并验证即使全局存在 `horse_readiness` 库存，NPC 未装备 `equipment.mount` 时也不会被判定为骑兵。
- 验证通过：`godot --headless --path . --script res://tools/verify_unit_type_classification.gd`。

---

## T0903 实现训练场与武器熟练度提升

状态：Done
优先级：P0
前置任务：T0901, T1001
涉及文档：`AI_NPC_SYSTEM.md`, `COMBAT_SYSTEM.md`

验收标准：

- 训练机制。可参考诊所治疗机制，训练也是需要有教官和受训者。教官占据的是训练场的工位，然后受训者占据的是训练场的受训位（就像诊所的医生工位和病床的设计一样）。可选行动里有进入训练场当教官（换个更精炼的名字），和进入训练场当受训者。只有有教官，才能当受训者。没有教官则当受训者这个行为异常。当教官，如果没有受训者，则也会以极缓慢的速度增加教官的武器/骑术熟练度。如果有受训者，则增加受训者的受训项的熟练度和教官的“教练”熟练度（和其他工作加熟练度的逻辑一样）。
- 受训项等同于该NPC当前所持有的武器/坐骑。如果教官没有受训者，那么教官增加自己当前所持有武器/坐骑的熟练度。如果有受训者，则受训者增加当前所持有武器/坐骑的熟练度。如果没有武器也没有坐骑，则无法受训和当教官。如果一个NPC既有武器又有坐骑，那么武器和坐骑熟练度都会增加。
- 训练消耗疲劳和饱食。
- 升级训练场可增加受训位或工位
- 训练也是分成单位时间来计算消耗和提升。
- 教官的教练熟练度可影响训练速度。
- 训练效率则受到当前训练项目对应的教官和受训者熟练度的差值影响。如果当前训练项目教官的熟练度低于受训者，则熟练度提升极小。教官持有什么武器/坐骑，只影响教官在没有受训者的情况下教官自己提升哪一项熟练度；在有受训者的情况下，受训者提升哪一项熟练度则取决于受训者当前持有的武器/坐骑（该情况下教官不再提升自己的武器熟练度，只提升教练熟练度）。比如NPC A是教官，持有剑盾，骑术和弓箭熟练度高；NPC B是受训者，持有弓箭和坐骑，骑术和弓箭熟练度低。在A单独当教练，B没有受训的情况下，A缓慢提升自己的剑盾熟练度；B参与受训后，A不再提升剑盾熟练度（不再是自己练习），而是B根据于A的骑术和弓箭熟练度的差值来更快的提升自己的骑术和弓箭熟练度。

验收结果（2026-06-10）：
- `data/building_defs.json` 已将训练场拆分为 `training_instructor` 教官工位和 `training_student` 受训位；训练场升级当前增加受训位。
- `data/action_defs.json` 新增 `work_training_instructor` / `receive_weapon_training` 两个行动：教官占据教官工位，受训者占据受训位；无装备不能训练或执教，受训者无有效教官时会失败。
- `ActionSystem` 已实现训练闭环：教官无受训者时极慢提升自己当前主武器 / 坐骑对应熟练度；有受训者时受训者按自己的当前主武器 / 坐骑提升武器熟练度或骑术，教官只提升“教练”；训练按单位时间消耗疲劳和饱食。
- 训练速度会读取教官“教练”、训练场等级，以及教官和受训者在当前训练项目上的熟练度差；教官项目熟练度低于受训者时提升明显变慢。教官装备只决定独自训练项目，不决定受训者项目。
- `MemorySystem` 已为 `skill_improved` 增加训练场独自练习、受训和指导训练 summary。
- GM 面板可通过行动下拉指派 `work_training_instructor` / `receive_weapon_training`，并保留 `train_instructor <npc_id>` / `train_student <npc_id>` 命令。
- 新增 `tools/verify_training_system.gd`，覆盖训练场工位、无装备失败、无教官失败、教官独自练习、受训者武器 + 骑术双项成长、教官教学时只涨教练、状态消耗和训练事件。
- 验证通过：`godot --headless --path . --script res://tools/verify_training_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_action_system_basic.gd`、`godot --headless --path . --script res://tools/verify_work_output_framework.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`、`godot --headless --path . --script res://tools/verify_unit_type_classification.gd`、`godot --headless --path . --script res://tools/verify_clinic_treatment.gd`、`godot --headless --path . --quit-after 1`。

---

## T0904 实现职业熟练度与经验升级

状态：Done
优先级：P1
前置任务：T0801, T0903
涉及文档：`AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`

验收标准：

- 工作可以以很缓慢的速度提升职业熟练度。
- 接入 T0808 已有的医术最小增长，统一为所有职业工作可复用的熟练度经验增长规则。
- 战斗或训练提升当前持有的武器/坐骑熟练度。
- 熟练度提升同步增加经验。
- 经验达标获得技能点。
- 技能点可由玩家分配到力量/智力。

验收结果（2026-06-10）：
- `NPCSystem.increase_npc_skill(...)` 已成为统一成长入口：任何熟练度提升都会同步写入 `progression.skill_experience`、`total_experience`，每 5 点总经验获得 1 个未分配技能点。
- 普通职业工作完成时会缓慢提升对应职业熟练度；T0808 诊所研读 / 治疗医术增长和 T0903 训练场武器 / 骑术 / 教练增长都接入同一套经验与技能点规则。
- 新增 `NPCSystem.assign_npc_attribute_point(...)` / `debug_assign_attribute_point(...)`，技能点只能由玩家分配到力量或智力，AI 不再自动消耗技能点。
- NPC 面板的成长入口后续已按 T0015 调整为：HP 行右侧显示 `经验：当前 / 阈值`，力量 / 智力数值旁仅在有未分配技能点且未达上限时显示 `+1`。
- GM 面板新增属性分配按钮和 `assign_attribute <npc_id> <strength|intelligence>` 命令；属性分配写入 `attribute_improved` 事件，summary 使用“守备官”。
- `game_design.md` 与 `AI_NPC_SYSTEM.md` 已同步为“玩家分配技能点，AI 只能建议倾向”的设计。
- 新增 `tools/verify_skill_progression.gd`，覆盖工作、训练、诊所成长，经验达标获得技能点，玩家分配力量，NPC 面板入口和 GM 命令。
- 验证通过：`godot --headless --path . --script res://tools/verify_skill_progression.gd`。

---

# M10：每日计划、行动中断与首次睡眠总结

目标：让 NPC 具备“看起来像在生活”的自动计划系统，并让记忆在每天结束时压缩为长期信息。

---

## T1001 实现规则版每日计划

状态：Done
优先级：P0
前置任务：T0401, T0305, T0801
涉及文档：`AI_NPC_SYSTEM.md`

任务目标：

先不用 LLM，做好NPC根据计划行动的接口。

规则：

- 一天 24 阶段对应24小时，这是计划的基本颗粒度。计划要包含每个阶段做什么行为。
- 将来LLM提示词将会提示至少要安排 6 阶段工作
- 所有的可选行为都可以安排进计划
- 按照计划的安排，到时间了就去执行计划里的下一项行为。如果还没到时间，该行为就已经做完了，就再执行一轮同一个行为；如果到时间了，NPC正在执行计划里的这一行为，则不打断。如果到时间了，NPC还在执行别的行为，则打断该行为，执行计划里的行为。（这是与工作行为相关的逻辑，后续吃饭睡觉、或者遇到异常会有不同的逻辑，但先不管，先统一按这个来）


禁止事项：

- 不调用 LLM。
- 暂不实现异常处理和重新评估计划

验收标准：

- NPC 按计划执行行动。
- 制定的计划写入事件库
- 计划执行以 `TimeSystem` 的逻辑时间打点为准。

验收结果（2026-06-10）：

- 新增 `DailyPlanSystem`，可为 NPC 生成规则版 24 小时计划并写入 NPC 运行时 `plan` 字段；默认规则按熟练度选择工作行动，且计划中工作阶段不少于 6 个。
- `plan_created` 私有事件已接入 `MemorySystem`，payload 保存 `plan_day`、24 项 `items`、`source=rule_default` 和 `work_phase_count`。
- 计划执行通过 `hour_started` 打点；已有计划的 NPC 在当前小时执行对应行动，若计划启动的行动在同一小时提前完成，会再次执行同一小时行动；小时变化且当前行动不同，会通过 `ActionSystem.interrupt_npc_action(...)` 中断后执行新计划项。
- T1001 不调用 LLM，不处理异常重评估；未显式生成计划的 NPC 不会被小时信号自动接管，避免调试行动和旧验证被计划系统误接管。
- GM 面板新增生成计划、执行当前计划和查看计划按钮，并新增 `plan_generate [npc_id|all]`、`plan_execute [npc_id|all]`、`plan <npc_id>` 命令。
- 新增 `tools/verify_daily_plan_system.gd` 覆盖 24 小时计划、至少 6 个工作阶段、`plan_created` 入库、小时打点执行、同小时完成后重复执行和计划变化打断旧行动。
- 验证通过：`godot --headless --path . --script res://tools/verify_daily_plan_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_action_system_basic.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

---

## T1002 实现行动异常与计划重评估（属于日常工作模式而非战斗模式）

状态：Done
优先级：P0
前置任务：T1001
涉及文档：`AI_NPC_SYSTEM.md`

触发异常：

- 目标建筑不可用
- 工作位占用
- 资源不足
- 被玩家对话打断
- 被其他 NPC 对话打断
- 被守备官攻击
- 战斗警报（已被征召且有配武器的除外，已被征召且有配武器的会进入战斗模式逻辑，其他没武器或没被征召的才会触发重评估计划）
- 守备官发布了不同于原内容的新指令

验收标准：

- 异常进入重评估。
- 重评估后 NPC 执行新计划里当前时段的行动。
- 需要 LLM / Mock 重评估时，通过 LLMBridge 申请 TimeSystem 慢速请求（游戏内一秒=现实中一秒），返回后释放。

验收结果（2026-06-11）：

- `DailyPlanSystem` 监听 `npc_plan_reevaluation_requested`，并在行动失败、目标建筑不可用、资源不足、工位占用、对话打断、守备官攻击、主动交涉结束 / 超时、战斗警报占位和守备官新指令后进入统一计划重评估。
- `LLMBridge` 新增 `request_npc_plan_revision(...)` / `build_npc_plan_revision_payload(...)`，调用后端 `/npc/revise_plan`，请求包含目标 NPC 的共享上下文、当前计划、失败计划项、失败类型、行动白名单和最新 `current_order`；请求期间申请 TimeSystem 慢速，请求成功、失败或超时后释放。
- 后端新增 `/npc/revise_plan`，使用 `PlanRevisionRequest` / `PlanRevisionResponse` 校验 Mock 输出；Mock provider 的 `revise_plan` 可返回当前小时 `immediate_action`。
- 重评估成功时，Godot 合并修订计划、写入 `plan_revised` 私有事件并立即执行当前小时行动；后端不可用、非 mock provider 未配置或响应不合法时，写入 `rule_revision_fallback` 规则降级计划并执行当前小时行动。
- GM 面板新增“立即重评估”按钮和 `plan_revise <npc_id> [reason]` 命令；“重评估请求”同时显示 NPCSystem 请求快照与 DailyPlanSystem 最近结果。
- 新增 `tools/verify_daily_plan_reevaluation.gd`，覆盖资源不足触发重评估、后端不可用规则降级、慢速请求释放、计划修订事件入库和可选 live mock 修订；新增 `tools/verify_plan_revision_endpoint.py` 覆盖 Flask `/npc/revise_plan` Mock 端点。
- 验证通过：`verify_daily_plan_reevaluation.gd`、以 `LLM_PROVIDER=mock` 和 `T1002_BACKEND_URL=http://127.0.0.1:5055` 临时启动 Flask 后再次运行 `verify_daily_plan_reevaluation.gd`、`verify_plan_revision_endpoint.py`、`verify_daily_plan_system.gd`、`verify_npc_order.gd`、`verify_gm_panel.gd`、`verify_npc_proactive_talk.gd`、`verify_backend_schemas.py`、`verify_mock_model_adapter.py`、`godot --headless --path . --quit-after 1`。

---

## T1003 实现 LLM / Mock 版制定计划接口

状态：Done
优先级：P1
前置任务：T0602, T1001
涉及文档：`PROMPTS.md`, `AI_NPC_SYSTEM.md`, `API_BUDGET.md`

验收标准：

- 后端提供 `/npc/plan_day`。
- Mock 能返回 24 阶段计划。NPC执行计划。
- 输出 JSON 被校验，不合法则回退重新计划。
- 计划请求的上下文包含目标 NPC 当前指令，长期记忆（知识图谱，日记），短期记忆（事件库、见闻库），NPC人设（包括各种核心人设），当前的时间、地点，NPC的各种状态（如HP，属性，职业和武器熟练度，饱食度疲劳度，金钱，装备，是否入伍..）Prompt 把它们作为参考。以及制定计划的指令提示词（json结构化输出的指令以官方文档里的参数的方式传入，而非混在提示词里）。
- 计划请求过程中必须申请 TimeSystem 慢速。
- 每日首次制定计划和重新评估计划的请求用一个相同的逻辑（它们的不同由上述上下文来识别而非单独另外建一个逻辑）

验收结果（2026-06-11）：

- 后端新增 `POST /npc/plan_day`，使用 `DailyPlanRequest` 校验输入、调用 `ModelAdapter.generate("plan_day", ...)`，再用 `DailyPlanResponse` 校验 24 阶段计划输出；输出不合法时返回可处理错误。
- Mock `plan_day` 现在按 NPC 熟练度和行动白名单选择真实可执行工作行动，并返回 `sleep_in_dormitory`、`eat_at_dining_hall`、工作行动和 `idle` 组成的 24 小时计划，工作阶段不少于 6 个。
- `LLMBridge` 新增 `build_npc_daily_plan_payload(...)` / `request_npc_daily_plan(...)`，请求包含共享 NPC 上下文、当前 `current_order`、长期记忆、短期事件库 / 见闻库摘要、地点、资源、建筑状态、行动白名单和计划规则；请求期间申请 TimeSystem 慢速，成功、失败或超时后释放。
- `DailyPlanSystem.generate_daily_plan_for_npc(...)` 优先应用 `/npc/plan_day` Mock 计划并写入 `plan_created(source=mock_plan_day)`；后端不可用、输出不合法、不是 24 阶段或工作阶段少于 6 个时，回退规则计划并写入 `plan_created(source=rule_plan_fallback)`。
- GM 面板 `plan_generate` 现在触发 LLM / Mock 每日计划生成并自动规则降级，新增 `plan_generate_rule [npc_id|all]` 保留纯规则计划入口；`plan_request` 会显示最近每日计划生成结果。
- 新增 `tools/verify_plan_day_endpoint.py` 和 `tools/verify_daily_plan_llm.gd`，覆盖 Flask `/npc/plan_day`、Godot 侧后端关闭规则降级、慢速释放、live Mock 计划应用、当前小时行动执行和 `current_order` 注入。
- 验证通过：`python tools/verify_backend_schemas.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_plan_revision_endpoint.py`、`godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`、临时以 `LLM_PROVIDER=mock` 和 `T1003_BACKEND_URL=http://127.0.0.1:5056` 启动 Flask 后再次运行 `verify_daily_plan_llm.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_reevaluation.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T1004 实现睡前总结与短期记忆清空

状态：Done
优先级：P1
前置任务：T0405, T0602
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`

验收标准：

- 每天首次睡觉时为 NPC 生成第一人称日记。
- 更新知识图谱当前键值。
- 清空当天事件库和见闻库缓存。
- 日记可在 NPC 面板查看。

完成记录（2026-06-11）：

- 新增 `DailyReflectionSystem` 并挂载到 `Main/Systems`，历史实现为监听 `sleep_started` 后生成睡前总结；T1005 已修正为每天首次睡眠满 1 游戏小时后生成首次睡眠总结，重复睡眠不会重复写日记，GM 可用 force 强制触发。
- `LLMBridge` 接入 `/npc/daily_reflection`，后端不可用或输出无效时由 Godot 模板兜底；T1005 已将其语义改为首次睡眠总结，并改为必须申请 TimeSystem 慢速。
- `NPCSystem.apply_daily_reflection(...)` 写入长期 `diary`，并把 `knowledge_graph_updates` 合并到长期知识图谱结构；T1405 后该结构已收敛为 `knowledge_graph.by_subject[subject][relation]` 替换式当前值，不再写 append-only `patches`。
- `MemorySystem.clear_npc_short_term_memory(...)` 清空指定 NPC 当天事件库和见闻库索引，保留全局事件档案供调试。
- `NPCPanel` 新增日记滚动区；`GMPanel` 历史新增“睡前总结 / 长期记忆 / 最近总结”按钮和 `reflect_npc <npc_id> [force]`、`long_memory <npc_id>`、`reflection_result` 命令；T1005 已把面板文案改为首次睡眠总结并新增 `llm_state`。
- 后端新增正式 `POST /npc/daily_reflection` endpoint，Mock 返回日记、记忆摘要和知识图谱更新；T1405 后真实 Prompt 明确该更新是替换式当前键值。
- 验证通过：`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`、`python tools/verify_daily_reflection_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_plan_day_endpoint.py`、`godot --headless --path . --quit-after 1`。

---

## T1005 实现对话打断、LLM 状态提示与首次睡眠总结优先级

状态：Done
优先级：P1
前置任务：T0701, T1002, T1003, T1004
涉及文档：`AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`, `GM_PANEL.md`, `PROMPTS.md`, `API_BUDGET.md`, `game_design.md`

任务目标：

实现日常模式下玩家对话的高优先级边界、NPC LLM 请求状态展示，以及首次睡眠总结的最高优先级锁。

需要支持：

- 玩家与 NPC 实际发送消息后的对话可打断工作、吃饭、睡觉等普通日常行动；T1006 起只打开对话窗不会打断。
- 玩家与 NPC 实际发送消息或对话窗攻击时可取消该 NPC 正在等待的可取消 LLM 请求，例如闲聊、NPC-NPC 聊天、每日计划或计划重评估；对话结束后按 T1006 的有效轮次 / 攻击事实规则触发计划重评估。
- 每天首次进入睡觉状态后，只有持续睡眠满 1 个游戏小时才触发每日总结。
- 总结从发起到完成期间是不可打断的深度睡眠：不能发消息、不能进入对话、不能被指令发布立即打断，行动系统也不能改派该 NPC。
- 总结期间发布给已入伍 NPC 的自然语言指令仍保存，但计划重评估延后到醒来后自然执行。
- 所有 Godot 侧 LLM 请求都必须申请 TimeSystem 慢速，包括首次睡眠总结。
- NPC 等待聊天 / 计划 LLM 时，主场景头顶显示三点思考标记，NPC 面板名字旁显示“正在思考”或“正在计划下一步行动”。
- NPC 正在总结时，主场景头顶显示禁止标记，NPC 面板名字旁显示“正在熟睡”。

验收标准：

- 睡觉开始不足 1 游戏小时不会生成总结；满 1 游戏小时后才生成当天首次睡眠总结。
- 首次睡眠总结等待期间，`DialogSystem.start_player_dialogue(...)`、`send_player_message(...)` 和 `ActionSystem` 行动改派 / 中断都被拒绝。
- 首次睡眠总结等待期间发布新指令只更新 `current_order` 和事件，不立即发起计划重评估；睡醒后再请求重评估。
- T1006 起，实际发送消息或对话窗攻击才会取消该 NPC 的可取消 LLM 活动状态并打断普通行动；总结活动不可取消。
- 每日计划、计划修订、对话和首次睡眠总结请求均会注册并释放 TimeSystem 慢速。
- NPC 头顶和 NPC 面板能显示思考、计划和熟睡状态。
- 相关设计与当前状态文档中的“睡前总结”命名更新为“首次睡眠总结”或说明历史任务名。

完成记录（2026-06-11）：

- `NPCSystem` 新增 `llm_activity`、首次睡眠总结锁和延后计划重评估状态；总结锁期间 `can_npc_act` 返回 false，发布指令只保存并延后重评估。
- `LLMBridge` 为对话、每日计划、计划修订和首次睡眠总结登记 NPC LLM 活动并申请 TimeSystem 慢速；新增 `cancel_npc_llm_requests(...)`，玩家对话可清除可取消活动并丢弃取消结果，首次睡眠总结不可取消。
- `DialogSystem` 在玩家对话入口检查熟睡锁；T1006 起，取消目标 NPC 可取消 LLM 活动和打断普通行动的时机后移到实际发送消息或对话窗攻击，对话结束按有效轮次 / 攻击事实请求计划重评估。
- `DailyReflectionSystem` 改为睡觉开始后计时，首次睡眠满 1 游戏小时才生成总结；总结请求 / 应用期间设置深度睡眠锁。
- `ActionSystem` 拒绝总结锁期间的行动中断和改派；睡眠完成后会消费延后的计划重评估。
- `NPC.gd` 新增头顶 LLM 标记，`NPCPanel` 名字旁新增 LLM 状态文字，`GMPanel` 新增 `llm_state <npc_id>`。
- 新增 `tools/verify_dialogue_sleep_summary_boundaries.gd`，更新 `tools/verify_daily_reflection_system.gd`。

验证通过：

- `godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`
- `godot --headless --path . --script res://tools/verify_dialogue_sleep_summary_boundaries.gd`
- `godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`
- `godot --headless --path . --script res://tools/verify_npc_order.gd`
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd`
- `godot --headless --path . --script res://tools/verify_gm_panel.gd`
- `godot --headless --path . --quit-after 1`

---

## T1006 实现发送后才打断对话与对话窗攻击闭环

状态：Done
优先级：P1
前置任务：T0701, T0702, T0704, T1005
涉及文档：`AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `game_design.md`

任务目标：

修正玩家误触对话造成 NPC 行动中断的问题，并把守备官攻击 NPC 从 NPC 面板直接扣血改为对话窗内的带回复交互。

需要支持：

- 点击 NPC 面板“对话”只打开对话窗、展示历史，不取消 NPC LLM 请求、不打断当前行动、不触发结束重评估。
- 玩家在对话窗真正发送消息后，才按日常模式对话规则取消目标 NPC 的可取消 LLM 请求、打断普通行动并进入 `/npc/dialogue` 调用。
- 结束对话时，只有本次对话中实际完成过玩家消息与 NPC LLM 回复，才触发对话打断后的计划重评估；只打开查看后关闭不产生副作用。
- 玩家发送后等待 NPC 回复期间，输入框仍可输入文字，但“发送”按钮不可用，避免同一轮回复前重复发送。
- 若玩家在等待 NPC 回复时结束 / 关闭对话，则取消本次对话 LLM；若此前没有完成 NPC 回复，视为无有效对话轮次，不触发对话重评估。
- 攻击入口移动到对话窗，点击后立即扣血并先写入“守备官攻击了你以示惩戒”事件，再调用一次攻击语境的 NPC LLM 回复。
- 攻击后若未等 NPC 回复就结束 / 关闭，攻击事件不撤销，并且结束时触发一次计划重评估。
- 对话窗 UI 中，“提出应征”改为右上角“同地点公开”下方的 toggle；“攻击”按钮放到原“提出应征”位置，即“发送”旁边。

验收标准：

- 只打开并关闭对话窗不会改变 NPC 当前行动、不会取消现有 LLM 活动、不会请求计划重评估。
- 首次发送玩家消息才触发行动打断和可取消 LLM 取消；NPC 回复成功后关闭会触发一次计划重评估。
- 等待回复期间输入框可编辑但发送按钮禁用。
- 攻击按钮只存在于对话窗；NPC 面板不再提供直接攻击按钮。
- 对话窗攻击会扣血、记录惩戒攻击事件、请求 NPC 攻击回复；关闭等待中的攻击回复不会撤销攻击，且会触发一次计划重评估。

完成记录（2026-06-12）：

- `DialogSystem.start_player_dialogue(...)` 改为只打开会话；实际发送消息或攻击时才调用打断 / 可取消 LLM 取消逻辑。
- `DialogSystem.send_player_message(..., async_request=true)` 和 `LLMBridge.request_npc_dialogue_async(...)` 支持 UI 异步等待与结束取消；普通消息未收到 NPC 回复就结束时不写 `dialogue_turn`，不触发对话重评估。
- `DialogSystem.attack_target_npc(...)` 新增对话窗攻击流程：先通过 `NPCSystem.apply_damage_to_npc(...)` 扣 HP 并写惩戒攻击事件，再请求 NPC 回复；未等回复就结束时攻击保留并触发一次计划重评估。
- `NPCSystem.apply_damage_to_npc(...)` 增加可选参数，允许对话攻击覆盖事件 summary 并延后非昏迷攻击的计划重评估。
- `DialogPanel` 把“提出应征”改为右上角 toggle，把“攻击”放到发送旁；等待回复时输入框可编辑，发送 / 攻击按钮禁用。
- `NPCPanel` 移除直接攻击按钮，保留给钱和正式装备武器入口。
- 更新 `tools/verify_dialogue_sleep_summary_boundaries.gd`、`tools/verify_dialogue_ui.gd` 和 `tools/verify_npc_panel_interactions.gd`，覆盖懒打断、异步取消、对话窗攻击和旧 NPC 面板攻击入口移除。

验证通过：

- `godot --headless --path . --quit-after 1`
- `godot --headless --path . --script res://tools/verify_dialogue_sleep_summary_boundaries.gd`
- `godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`
- `godot --headless --path . --script res://tools/verify_dialogue_ui.gd`（临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py`）
- `godot --headless --path . --script res://tools/verify_llm_bridge.gd`（临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py`）
- `godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`（临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py`）
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd`
- `godot --headless --path . --script res://tools/verify_npc_proactive_talk.gd`
- `godot --headless --path . --script res://tools/verify_gm_panel.gd`
- `godot --headless --path . --script res://tools/verify_daily_plan_reevaluation.gd`
- `godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`
- `python tools/verify_backend_schemas.py`
- `python tools/verify_dialogue_mock_endpoint.py`
- Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志为空。

---

# M11：敌人、警铃与基础战斗

目标：敌人能按波次进攻，玩家可摇铃集结入伍 NPC，战斗按照装备与策略自动执行。

---

## T1101 实现敌人配置与敌人生成

状态：Done
优先级：P0
前置任务：T0201
涉及文档：`COMBAT_SYSTEM.md`, `DATA_SCHEMA.md`

任务目标：

实现 `enemy_waves.json` 并按波次生成敌人。

验收标准：

- 至少配置 5 波敌人，一波比一波稍强。
- 敌人有 HP、武器类型/兵种（兵种类型复用NPC的几个兵种类型：剑盾、长杆、弓弩、骑马近战骑马远程等）、攻击力、防御力、移动速度等（这些属性维度将会和己方NPC对等，参考game_design.md里战斗系统的设计）、目标偏好。
- 可通过调试按钮生成第一波敌人。
- 敌人生成位置在正门外稍远的地方（以后场景做好了，将会相当于在驿站门外的树林里出现）。当前正门方向的地面面积太小了需要扩大。

验收结果（2026-06-12）：
- `data/enemy_waves.json` 已配置 5 波敌人，后续波次按人数、HP、攻击力、防御和兵种构成逐步增强。
- 每个敌人组配置 `unit_type`、`weapon_type`、HP / Max HP、攻击力、防御力、移动速度、射程、攻击间隔和目标偏好；兵种覆盖近战步兵、长杆步兵、弓箭兵、弩兵、近战骑兵和骑射单位。
- `CombatSystem` 会读取波次配置，并在 `Main/WorldRoot/Station/Enemies` 下生成低模敌人占位实体，实体保留敌人 id、波次、数值和头顶 HP / 兵种标签。
- 正门外地面与正门道路已扩大，敌人默认生成在 `front_forest` / 正门外远处区域；相机 Z 轴边界已扩展到可观察生成区。
- GM 面板新增“战斗 / 敌人”分组，可通过“生成第一波敌人”按钮、`spawn_wave 1` / `enemy_wave 1` 命令生成第一波，并可查看 `enemies` 快照或 `clear_enemies` 清空敌人。
- 验证通过：`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务不实现敌人目标移动、攻击、伤害、战斗开始/结束状态或胜负结算，这些仍留给 T1102、T1104、T1106 和 M13。

---

## T1102 实现敌人目标优先级

状态：Done
优先级：P0
前置任务：T1101, T0203
涉及文档：`COMBAT_SYSTEM.md`

规则：

1. 攻击城门
2. 攻击仓库
3. 攻击主厅
4. 如果一定范围内有我方单位，优先攻击我方单位

验收标准：

- 敌人会向目标移动。
- 敌人能攻击建筑和我方NPC（现在可先不做具体的攻击动作，以后的攻击会像《人类一败涂地》一样，攻击打到目标身上才算命中掉血）
- 受击目标 HP 会下降。
- 主厅被摧毁可触发游戏失败（失败界面暂为占位）。

验收结果（2026-06-12）：
- `CombatSystem` 已接入敌人目标选择、逻辑时间推进、移动和敌方单向攻击：附近可行动 NPC 在侦测范围内时优先成为目标，否则按城门、仓库、主厅顺序选择仍有 HP 的建筑；T1104C 起不再把围墙作为敌人攻击目标。
- 敌人移动使用 `TimeSystem.logical_time_tick` 的游戏秒推进；GM / 自动化可通过 `debug_step_enemy_ai(...)` 或 `step_enemies [game_seconds]` 手动推进同一套逻辑。
- 敌人攻击 NPC 时复用 `NPCSystem.apply_damage_to_npc(...)`，HP 清零仍进入昏迷；攻击建筑时调用 `BuildingSystem.apply_damage_to_building(...)`，写入 `building_damaged` 结构化事件并刷新建筑状态。
- 主厅 HP 清零时 `GameState` 会写入 `game_over=true`、`game_result="failure"`、`failure_reason="main_hall_destroyed"`，作为后续正式失败界面的占位状态。
- GM 面板“战斗 / 敌人”分组新增“推进敌人AI”按钮和 `step_enemies [game_seconds]` 命令；敌人快照会显示目标、当前行动和最近 AI 推进结果。
- 新增 `tools/verify_enemy_target_priority.gd`，覆盖城门优先、敌人移动并伤害建筑、附近 NPC 抢目标并扣血、目标链路落到主厅和主厅失败状态。
- 验证通过：`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务只实现敌方单向攻击和失败状态占位；我方自动攻击、敌人受击 / 倒下、敌人全灭、战斗开始 / 结束流程和正式胜负结算仍留给 T1104、T1106 和 M13。

---

## T1103 实现警铃与集结

状态：Done
优先级：P0
前置任务：T0702, T0902
涉及文档：`COMBAT_SYSTEM.md`, `UI_UX.md`

任务目标：

玩家点击警铃后，入伍且有武器的 NPC 尝试在城门前面外面集结防线（除非在集结的路上一定范围内遭遇了敌军，就取消该NPC的集结指令直接切换战斗模式）。

规则：

- 近战在前
- 远程在后
- 面向敌人方向
- 未入伍或无武器 NPC 不集结

验收标准：

- HUD 警铃按钮可触发集结。
- 已入伍有武器 NPC 移动到防守位置。
- 已装备坐骑的 NPC 只在战斗/集结模式表现为骑乘；日常工作模式不骑马。
- 未入伍 NPC 不响应。
- 警铃（对所有NPC）与集结事件（只有入伍响应的NPC）写入结构化事件。

验收结果（2026-06-12）：

- HUD `AlarmButton` 已调用 `CombatSystem.trigger_combat_alarm("hud")`；GM 面板新增“警铃集结”按钮和 `alarm` / `rally` 命令，快照中可查看 `active_rallies` 与 `last_alarm_result`。
- 警铃触发时，所有 NPC 都写入 `combat_alarm_rang` 私有结构化事件；只有已入伍、已装备主武器且当前可行动的 NPC 会进入集结。
- 集结会打断普通日常行动并释放工位，随后让 NPC 前往城门外防线；阵型按近战 / 骑兵前排、弓弩 / 骑射后排排列，并标记面向正门外敌人方向。
- 已装备坐骑的 NPC 只在 `rally` / `combat` 模式显示低模坐骑；日常工作模式仍不骑马。
- 若集结途中遭遇一定范围内敌人，NPC 会停止集结并切换为 `combat_ready` 占位状态，写入 `combat_rally_encountered_enemy`。
- 新增 `tools/verify_combat_alarm_rally.gd`，覆盖 HUD 警铃、GM 命令、未入伍过滤、阵型、骑乘表现和遭遇敌人切换。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`。

边界：本任务不实现我方攻击、敌人受击 / 倒下、完整战斗开始 / 结束流程或正式胜负结算，这些仍留给 T1104、T1106 和 M13。

---

## T1103A 统一 NPC 行为模式状态机

状态：Done
优先级：P0
前置任务：T1006, T1103
涉及文档：`COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`, `UI_UX.md`, `GM_PANEL.md`

任务目标：

实现工作模式、集结模式、战斗模式、避战模式的统一运行时状态机，并把 T1103 现有 `combat_mode` 兼容字段逐步收敛到 `states.behavior_mode`。

模式定义：

- `work`：日常 / 工作模式，沿用每日计划、行动异常、对话打断和计划重评估机制。
- `rally`：集结模式，警铃后符合条件的已入伍持武器 NPC 前往城门外防线。
- `combat`：战斗模式，已入伍且有主武器 NPC 接敌后按后续战斗逻辑行动。
- `avoid_combat`：非战斗人员（未入伍，或已入伍但无主武器）遇敌后的避战模式，按敌人方位逐步远离但不离开驿站太远。

验收标准：

- 任一 NPC 快照能显示当前 `behavior_mode`、进入原因和进入时间。
- 警铃触发后，符合条件 NPC 进入 `rally`；未入伍、无武器、昏迷、睡觉或不可行动 NPC 不进入集结。
- 已入伍且有主武器 NPC 在 `work` 或 `rally` 中接敌后进入 `combat`；睡觉中的已入伍持武器 NPC 只有被敌人攻击时才进入 `combat`。
- `rally` NPC 到达集合点后等待 1 游戏小时仍未接敌，会回到 `work` 并继续当前计划，不触发计划重评估。
- 场上敌军全部消失后，`combat` NPC 回到 `work` 并触发计划重评估。
- 模式切换时会中断普通行动、移动、计划 LLM 活动和可取消对话 LLM；若对话框正在打开，强制关闭并丢弃未完成回复。
- 昏迷复苏后按场上敌军、入伍状态和主武器分流：有敌军时进入 `combat` 或 `avoid_combat`，无敌军时进入 `work` 并重评估计划。
- 需要留痕的模式切换写入 `npc_mode_changed` 结构化事件；T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 互转不再写入或广播该事件。
- GM 面板可查看模式快照、手动推进集结等待时间，并观察最近一次模式切换原因。

边界：

- 本任务只实现模式状态机与切换边界，不实现我方攻击、敌人受击、战时对话心理结果或低血量 LLM 判定。

完成记录：

- `NPCSystem` 新增 `states.behavior_mode` 权威字段和 `set_npc_behavior_mode(...)` / `get_npc_behavior_mode_snapshot(...)` / `debug_get_behavior_mode_snapshot(...)`，并继续兼容 T1103 的 `combat_mode` 字段用于旧视觉逻辑。
- `CombatSystem` 接入行为模式触发：警铃进入 `rally`，接敌进入 `combat`，集结点等待 1 游戏小时超时回 `work` 且不触发计划重评估，敌军清空后 `combat` NPC 回 `work` 并触发计划重评估，昏迷复苏后按敌军存在、入伍状态和主武器分流。
- 需要留痕的模式切换会写入 `npc_mode_changed` 结构化事件；T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 互转不再写入或广播该事件。`DialogSystem.force_end_dialogue_for_npc(...)` 可被模式切换调用以强制关闭正在进行的对话并取消未完成回复。
- GM 面板新增“行为模式快照”“推进集结等待”按钮，以及 `behavior_modes` / `advance_rally_wait [game_seconds]` 命令。
- 新增 `tools/verify_behavior_mode_state_machine.gd`，覆盖警铃集结、集结超时、接敌入战、清敌退出、睡觉接敌例外、被攻击入战、复苏分流和 GM 入口。

---

## T1103B 实现未入伍 NPC 避战模式

状态：Done
优先级：P0
前置任务：T1102, T1103A
涉及文档：`COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `GM_PANEL.md`

任务目标：

实现未入伍 NPC 的同级避战模式，区别于已入伍 NPC 在战斗模式中的“避战策略”。

验收标准：

- 未入伍 NPC 在工作模式下敌人进入一定范围时进入 `avoid_combat`；睡觉中的未入伍 NPC 只有被敌人攻击时才进入。
- 避战 NPC 会尝试远离敌人或移动到驿站内相对安全区域，但不会离开驿站太远，也不会进入逃离驿站流程。
- 避战 NPC 不攻击敌人，不被当作可战斗人员。
- 场上敌人全部消失后，避战 NPC 回到 `work`；除非避战期间发生受伤、对话、应征等额外异常，否则不自动调用 LLM 计划重评估。
- 避战中若通过对话同意应征且场上仍有敌人，立即进入 `combat`；若无敌人，则进入 `work` 并成为已入伍 NPC。
- 写入 `avoidance_started` / `avoidance_ended`；T1103D 起，`work <-> avoid_combat` 互转不再写入 `npc_mode_changed`。
- GM 面板可触发或模拟未入伍 NPC 遇敌、查看避战目标和退出条件。

边界：

- 本任务不实现逃离驿站；逃离仍由 T1203 处理。

完成记录：

- `CombatSystem` 已在敌人接触扫描和敌人攻击后维护未入伍 NPC 的 `avoid_combat`：工作模式中接敌进入避战，睡觉中的未入伍 NPC 只在被敌人攻击时进入。
- 避战 NPC 会选择驿站内安全点并通过 `NPCSystem.move_npc_to_world_position(...)` 移动，运行时快照包含避战目标；避战不进入逃离驿站流程，也不设置 `combat_mode` 或攻击行动。
- 场上敌军清空时，避战 NPC 回到 `work` 且不请求计划重评估；避战中被应征入伍时，若仍有敌军则立即进入 `combat`，若无敌军则回到 `work`。
- `MemorySystem` 新增 `avoidance_started` / `avoidance_ended` 事件类型、必填字段和 summary；T1103D 起，`work <-> avoid_combat` 互转不再写入 `npc_mode_changed`。
- GM 面板新增“模拟避战”按钮和 `avoid_npc <npc_id>` 命令；敌人快照会显示 `active_avoidances` 与最近避战结果。
- 新增 `tools/verify_avoid_combat_mode.gd`，覆盖未入伍接敌避战、睡觉例外、避战安全点、清敌退出不重评估、避战中应征分流、事件写入和 GM 入口。
- 后续 T1103C 已修正本任务中的两处旧规则：避战对象扩展为非战斗人员（未入伍或已入伍但无主武器），并且避战中应征入伍但仍无主武器时继续避战，只有装备主武器且仍有敌军时才进入 `combat`。

验证通过：`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T1103C 修正非战斗人员避战判定与四散移动

状态：Done
优先级：P0
前置任务：T1103A, T1103B
涉及文档：`COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `GM_PANEL.md`

任务目标：

把避战对象从“未入伍 NPC”扩展为“非战斗人员”：未入伍 NPC 和已入伍但未分配主武器的 NPC 都不会集结或接战；他们接敌时使用同级 `avoid_combat` 模式。同时将避战移动从固定角落 / 固定安全点改为根据敌人接近方位逐步远离，并带有按 NPC 区分的散射方向，形成四散逃跑效果。

验收标准：

- 未入伍 NPC、已入伍但无主武器 NPC 在工作模式下接敌时进入 `avoid_combat`，不进入 `rally` 或 `combat`。
- 睡觉中的未入伍 NPC、睡觉中的已入伍但无主武器 NPC 不因单纯接近触发避战，只有被敌人攻击时进入 `avoid_combat`。
- 已入伍且有主武器 NPC 仍按原规则集结、接敌进入 `combat`，睡觉时只有被敌人攻击才进入 `combat`。
- 避战目标根据最近敌人方位生成短距离移动点，尝试逐步远离到接敌范围之外；目标保持在驿站范围内，不一次性传送到角落，也不让所有 NPC 跑向同一个点。
- 避战中应征入伍但仍无主武器时继续避战；装备主武器且场上仍有敌人时才切换到 `combat`。
- GM 面板模拟避战和 `tools/verify_avoid_combat_mode.gd` 覆盖上述判定与四散移动。

完成记录（2026-06-17）：

- `CombatSystem` 的接敌、复苏和 GM 避战入口改为使用“已入伍且有主武器”作为可战斗判定；未入伍或已入伍但无主武器 NPC 不集结、不接战，接敌进入 `avoid_combat`。
- `NPCSystem` 的敌人攻击分流同步使用主武器判定；睡觉中的无武器入伍 NPC 不因接近触发避战，但被敌人攻击时进入 `avoid_combat`。
- 避战目标由固定安全点改为按最近敌人方位生成短步长远离目标，并用 NPC / 敌人组合生成稳定散射角，形成逐步四散逃跑效果；目标保持在驿站范围内。
- 避战中应征入伍但仍无主武器时继续避战；获得主武器且场上仍有敌人时切入 `combat`。
- `MemorySystem` 避战行动与事件摘要改为“远离敌人 / 避战方向”语义，不再显示固定避战点。
- 更新 `tools/verify_avoid_combat_mode.gd` 覆盖无武器入伍 NPC 接敌避战、睡觉受击例外、短步长四散目标、应征后继续避战与装备主武器后入战。

验证通过：`godot --headless --path . --quit-after 1`、`godot --headless --path . --script tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script tools/verify_gm_panel.gd`、`git diff --check`（仅提示 `docs/CURRENT_STATE.md` 未来会从 CRLF 转 LF）。

---

## T1103D 降噪工作 / 战斗 / 避战模式切换事件

状态：Done
优先级：P0
前置任务：T1103A, T1103B, T1103C, T1104
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`

任务目标：

去掉冗余的模式切换事件：`work <-> combat` 与 `work <-> avoid_combat` 的互转不再写入 `npc_mode_changed`，也不再因该事件向地点公开广播；战斗、避战、攻击、伤害、警铃、集结、昏迷、复苏等具体事实仍由各自事件记录。

验收标准：

- 工作模式进入战斗模式、战斗模式回到工作模式时，不写入 `npc_mode_changed`，也不通过该事件广播。
- 工作模式进入避战模式、避战模式回到工作模式时，不写入 `npc_mode_changed`，也不通过该事件广播。
- 集结、集结途中接敌、昏迷、复苏、逃离等非上述互转的模式 / 事实事件不受影响。
- `avoidance_started` / `avoidance_ended`、`attack_made`、`damage_taken` 等具体事实事件保留。
- 行为模式快照仍能显示当前 `behavior_mode`、进入原因和进入时间，GM 调试入口不受影响。
- 自动化验证覆盖上述信息降噪。

完成记录（2026-06-17）：

- `NPCSystem.set_npc_behavior_mode(...)` 增加模式事件过滤：默认跳过 `work -> combat`、`combat -> work`、`work -> avoid_combat`、`avoid_combat -> work` 的 `npc_mode_changed` 写入；保留 `force_mode_event` / `suppress_mode_event` 作为特殊入口覆盖。
- `avoidance_started` / `avoidance_ended`、`attack_made`、`damage_taken`、`combat_alarm_rang`、`combat_rally_started`、`combat_rally_encountered_enemy`、`unconscious_started`、`revived` 等具体事实事件不受影响。
- `tools/verify_avoid_combat_mode.gd` 改为验证 `work <-> avoid_combat` 不写 `npc_mode_changed`，同时确认避战开始 / 结束事件仍写入。
- `tools/verify_behavior_mode_state_machine.gd` 改为验证 `work <-> combat` 不写 `npc_mode_changed`，同时确认集结模式切换仍可写入。

验证通过：`godot --headless --path . --quit-after 1`、`godot --headless --path . --script tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script tools/verify_combat_damage.gd`、`godot --headless --path . --script tools/verify_combat_pacing.gd`、`godot --headless --path . --script tools/verify_gm_panel.gd`。

---

## T1104 实现基础攻击与伤害

状态：Done
优先级：P0
前置任务：T0902, T1102, T1103A
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
- 已入伍且有主武器 NPC 只在 `combat` 模式中执行我方攻击。
- `avoid_combat` NPC 不攻击敌人。

禁止事项：

- 不做复杂动画。
- 不做命中率复杂计算。
- 不做战斗中llm判定/逃跑系统。

验收标准：

- 我方和敌人能互相造成伤害。
- NPC HP 清零后昏迷。
- 建筑 HP 会被敌人打掉。
- 敌人被击败后从战斗中移除。
- 攻击间隔、攻击速度、伤害和战斗移动不直接读取玩家 `x2` / `x4` 时间倍率；战斗实时推进由 TimeSystem tick 驱动，敌人在场时由 T1104A 的 `x1` 上限控制有效推进速度。

完成结果：

- `CombatSystem` 已实现已入伍且有主武器 NPC 在 `behavior_mode == "combat"` 中自动攻击敌人；`avoid_combat` NPC 不攻击。
- 我方攻击力读取主武器 `damage` 并按力量修正，攻击间隔读取主武器 `attack_interval` 并按武器熟练度、疲劳、饱食和骑术/坐骑修正。
- 敌人防御读取波次配置 `defense`；NPC 防御读取装备盔甲槽 `armor_value` 总和；实际 HP 扣除统一使用防御减伤函数。
- 敌人 HP 清零后从活动敌人和场景节点中移除；场上敌人清空时沿用行为模式退出规则。
- 敌人攻击 NPC 现在会先经过 NPC 盔甲防御再调用 `NPCSystem.apply_damage_to_npc(...)`；敌人攻击建筑仍由 `BuildingSystem.apply_damage_to_building(...)` 结算。
- 我方攻击写入 `attack_made` 结构化事件，敌方攻击 NPC 的 `damage_taken` payload 记录原始攻击、防御和防御后伤害。
- 新增 `tools/verify_combat_damage.gd` 覆盖我方伤害、敌方伤害、盔甲减伤、攻击间隔、敌人移除、清敌退出和避战不攻击。

验证通过：`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。
---

## T1104A 脱钩战斗数值时间倍率与敌人在场限速

状态：Done
优先级：P0
前置任务：T0401, T1104
涉及文档：`game_design.md`, `COMBAT_SYSTEM.md`, `GODOT_ARCHITECTURE.md`, `TECH_ARCHITECTURE.md`, `GM_PANEL.md`, `MODULE_INDEX.md`

任务目标：

取消战斗数值与玩家时间倍率的绑定。伤害、攻击间隔、攻击速度和移动速度不再因为玩家选择 `x2` / `x4` 而加速；时间倍率主要继续服务工作模式下的资源生产、资源消耗、饱食 / 疲劳和治疗 / 修复等经营结算。

新增战斗时间上限规则：

- 只要场景中存在任意活动敌人，TimeSystem 的有效时间流速上限为 `x1`。
- 若敌人出现前玩家设定为 `x2` / `x4`，敌人在场期间有效倍率压到 `x1`，玩家选择值保留。
- 若敌人在场期间已有 LLM 等待慢速，实际有效倍率继续使用更慢的 LLM 倍率；LLM 请求结束后回到 `x1`。
- 当所有敌人消失后，释放该上限，恢复正常 TimeSystem 逻辑。

验收标准：

- CombatSystem 不再把玩家时间倍率作为战斗伤害、攻击间隔、攻击速度或移动速度的额外倍率输入。
- 敌人生成时注册 `x1` 时间上限，清空 / 击败最后一个敌人后释放。
- LLM 慢速和敌人在场上限可同时存在，并以更慢者为有效倍率。
- GM / 自动化可观察当前 TimeSystem 有效倍率、慢速请求和上限请求。
- 验证脚本覆盖敌人在场限速、LLM 慢速叠加、清敌恢复玩家倍率。

验收结果（2026-06-17）：

- `TimeSystem` 新增有效倍率上限请求接口和倍率快照，玩家选择倍率、LLM 慢速与敌人在场上限共同决定有效倍率。
- `CombatSystem` 在活动敌人存在时注册 `combat_enemy_presence` `x1` 上限，清空敌人或最后一个敌人被移除时释放。
- 战斗伤害、攻击间隔、攻击速度和战斗移动速度不再读取玩家 `x2` / `x4` 作为额外倍率；LLM 慢速仍可通过全局有效倍率放慢战斗推进。
- GM 面板新增时间倍率快照按钮与 `time_snapshot` 命令，敌人快照也暴露 TimeSystem 上限状态。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --quit-after 1`；`git diff --check` 仅提示 `docs/CURRENT_STATE.md` CRLF/LF 转换。

---

## T1104B 校准战斗动作秒与第一波基础节奏

状态：Done
优先级：P0
前置任务：T1104A
涉及文档：`game_design.md`, `COMBAT_SYSTEM.md`, `GODOT_ARCHITECTURE.md`, `TECH_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `UI_UX.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

在 T1104A 取消战斗数值与玩家时间倍率绑定后，重新校准基础战斗节奏。当前 `x1` 时间流速仍是现实 1 秒推进 60 游戏秒，但战斗攻击冷却、攻击间隔和基础战斗移动表现应以“现实观感下的战斗动作秒”为基准，不能把 60 游戏秒直接当作 60 次战斗动作秒使用。

验收标准：

- CombatSystem 明确把 TimeSystem 的游戏秒转换为战斗动作秒后再推进攻击冷却。
- 敌人移动、NPC 攻击和敌方攻击使用一致的战斗动作基准，不因 `x1` 的 1 分钟 / 秒逻辑时间而瞬间多次攻击。
- 第一波敌人与已装备主武器的艾达交战时，不应在单个 `x1` 基准秒内结束；应能观察到攻击冷却、互相扣血和敌人持续存在的过程。
- 自动化验证覆盖第一波节奏、攻击次数上限、NPC HP 变化和敌人未瞬间清空。

验收结果（2026-06-17）：

- `CombatSystem` 新增战斗动作秒换算：`60` 游戏秒折算为 `1` 战斗动作秒后再推进 NPC / 敌人的攻击冷却，避免 `x1` 下现实 1 秒触发几十次攻击。
- 敌人移动仍按 `move_speed * game_delta_seconds / 60` 推进；攻击冷却、武器 `attack_interval` 和敌人 `attack_interval` 使用战斗动作秒。
- 第一波劫掠剑盾手数值调为低强度探路敌人：HP `60`、攻击 `6`、防御 `1`、攻击间隔 `2.4`，让艾达持剑时有可观察的互相攻击过程。
- 新增 `tools/verify_combat_pacing.gd` 覆盖艾达持剑对第一波：单个 `x1` 基准秒只产生一次艾达攻击，敌人不会爆发式连击，第一波不会瞬间清空，完整交战不会过快结束。
- `tools/verify_enemy_target_priority.gd` 按新第一波攻击力延长主厅摧毁推进时间。

验证通过：`godot --headless --path . --script res://tools/verify_combat_pacing.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --quit-after 1`；`git diff --check` 仅提示 `docs/CURRENT_STATE.md` CRLF/LF 转换。

---

## T1104C 移除围墙作为敌人攻击目标

状态：Done
优先级：P0
前置任务：T1102, T1104B
涉及文档：`game_design.md`, `COMBAT_SYSTEM.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

修正敌人进攻路线。当前规则下敌人不再攻击围墙；敌人先攻击城门，城门被攻破后直接转向仓库、主厅或侦测范围内的我方单位。后续“必须从城门进入、不能穿墙”的空间约束留给可进入 / 不可进入对象碰撞体积、导航与路径任务实现。

验收标准：

- `data/enemy_waves.json` 的 `target_preference` 不再包含 `wall`。
- CombatSystem 默认目标偏好不再包含 `wall`，并会过滤旧配置中的 `wall` / `front_wall`。
- 城门 HP 清零后，敌人下一建筑目标应为仓库；仓库清零后再转向主厅。
- 回归验证确认围墙 HP 不会因敌人目标优先级推进而被扣除。

验收结果（2026-06-17）：

- `CombatSystem` 默认目标偏好改为 `front_gate -> warehouse -> main_hall -> nearby_unit`，并新增目标偏好规范化过滤，旧配置中的 `wall` / `front_wall` 不会进入运行时目标偏好。
- 5 波敌人数据均移除了 `target_preference` 中的 `wall`。
- `tools/verify_enemy_target_priority.gd` 已覆盖：生成敌人的目标偏好不含围墙；城门被摧毁后直接选择仓库；围墙 HP 不变；仓库被摧毁后才选择主厅。

验证通过：`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_pacing.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --quit-after 1`。

---

## T1105 实现战斗策略

状态：Done
优先级：P0
前置任务：T1104, T1103A
涉及文档：`COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `UI_UX.md`, `DATA_SCHEMA.md`

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

- 战斗判定或战斗计划只能从与当前装备匹配的策略集合中选择。
- 某个已入伍且有主武器 NPC 当前可用哪些策略，由其当前装备和 `EquipmentSystem` 判定出的兵种决定。
- 具体应用哪种策略由守备官在 NPC 面板手动选择；默认是当前兵种策略列表中的第一项进攻 / 输出策略。`current_order` 不再用于自动选择战斗策略，只继续作为对话、计划和战时心理的参考上下文。
- NPC 面板在“装备武器”旁提供战斗策略下拉框，并只显示当前兵种可用策略。
- 不同策略行为可明显区分。
- 策略选择和变化写入 NPC 事件库。
- 已入伍且有主武器 NPC 的“避战”是 `combat` 模式中的战术策略，不等于非战斗人员的 `avoid_combat` 模式。

验收结果（2026-06-17）：

- `CombatSystem` 新增装备 / 兵种派生的战斗策略集合、策略状态归一化、玩家手动选择入口和 `combat_strategy_selected` 事件。
- `EquipmentSystem` 在主武器或坐骑变化后按新兵种重置默认策略；换盔甲不重置策略。
- `NPCPanel` 在“装备武器”旁新增策略下拉框，玩家可随时为已入伍且有主武器 NPC 选择当前兵种可用策略。
- 策略行为已接入战斗推进：近战主动进攻会接近敌人并攻击；远程最大化输出为站桩射击；保持距离射击会在太近或太远时短步长调整并保持在攻击距离内；近战骑兵可拉开距离再冲击；战斗内避战复用短步长远离敌人的移动逻辑，但保持 `behavior_mode == "combat"`。
- 新增 `tools/verify_combat_strategies.gd`，覆盖策略集合、默认策略、NPC 面板下拉、事件写入、战斗内避战与保持距离射击行为。

验证通过：`godot --headless --path . --script res://tools/verify_combat_strategies.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_pacing.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --quit-after 1`；Godot MCP `addon_status` 与编辑器日志检查正常。

---

## T1105A 修正战斗内避战策略距离边界

状态：Done
优先级：P0
前置任务：T1105, T1103C
涉及文档：`COMBAT_SYSTEM.md`, `CURRENT_STATE.md`

修正已入伍且有主武器 NPC 在战斗模式中选择“避战”策略时的移动边界。战斗内避战应复用非战斗人员避战模式的短步长远离逻辑：根据最近敌人的来袭方向尝试拉开一小段距离；当敌人已经远离到安全阈值外时，NPC 保持 `behavior_mode == "combat"` 并站立等待，不继续向驿站边界或角落移动。

验收标准：

- 战斗内“避战”只在最近敌人距离低于避战安全阈值时发起短步长远离移动。
- 如果敌人已经在安全阈值外，NPC 不攻击、不继续移动，保持 `combat_ready` 等待。
- 如果 NPC 正在执行战斗内避战移动，但最近敌人已经远离到安全阈值外，系统停止该移动并保持等待。
- 验证脚本覆盖近距离短步长移动、远距离等待、不攻击和仍处于 `combat` 模式。

验收结果（2026-06-17）：

- `CombatSystem` 的战斗策略避战分支增加距离边界：最近敌人距离达到非战斗避战安全阈值时返回 `combat_strategy_avoid_holding`，保持 `combat_ready`，不再继续选择下一段避战目标。
- 如果 NPC 正在前往战斗策略避战目标，且最近敌人已经远离到安全阈值外，系统会停止该移动，清空策略移动目标并保持 `behavior_mode == "combat"`。
- `tools/verify_combat_strategies.gd` 已覆盖近距离短步长避战、移动中敌人远离后的停止等待、远距离直接等待、不攻击和战斗模式保持。

验证通过：`godot --headless --path . --script res://tools/verify_combat_strategies.gd`、`godot --headless --path . --script res://tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 编辑器错误日志为空。

---

## T1106 实现战斗开始/结束流程

状态：Done
优先级：P0
前置任务：T1101, T1103A, T1104
涉及文档：`COMBAT_SYSTEM.md`, `CURRENT_STATE.md`

验收标准：

- 敌人波次开始时，在广场广播一次敌军来袭的事件和当前敌我状况：如，敌军来袭，敌人有哪些，我方有哪些兵种（已入伍且有武器的才算），名字+兵种列出来。
- 已入伍且有主武器 NPC 通过接敌进入 `combat`，未入伍或无主武器 NPC 通过遇敌进入 `avoid_combat`。
- 敌人全灭或撤退后，所有 `combat` NPC 退出到 `work` 并重新评估计划。
- 所有 `avoid_combat` NPC 在敌人清空后退出到 `work`；单纯避战结束不强制 LLM 重评估。
- 所有未接敌的 `rally` NPC 在敌人清空或等待超时后退出到 `work`，不触发计划重评估。
- 所有敌人死亡后战斗结束，在广场广播一次结算：比如，敌人已经全被消灭，本次战斗谁谁受伤，谁谁昏迷，谁击杀了几名敌人（这里谁受伤，不限于入伍的NPC，所有受伤/昏迷的NPC全都计入）。
- 战斗后 NPC 回到工作状态并重新评估计划。

验收结果（2026-06-17）：

- `CombatSystem.spawn_wave(...)` 在实际生成敌人后写入广场 `local_public` 的 `combat_started` 事件，payload 包含波次、敌军数量 / 构成、我方已入伍且持主武器 NPC 的姓名 + 兵种、非战斗人员数量。
- `CombatSystem` 维护当前战斗运行态，记录本场 NPC 受伤 / 昏迷、各 NPC 击退敌人数量，并在敌军全灭或 GM 清敌后写入广场 `local_public` 的 `combat_ended` 事件。
- 清敌流程补齐未接敌 `rally` NPC 的退出：`combat` 回 `work` 并请求计划重评估，`avoid_combat` 回 `work` 且不因单纯避战结束重评估，`rally` 回 `work` 且不重评估。
- `MemorySystem` 新增 `combat_started` / `combat_ended` 必填 payload 校验与确定性 summary，摘要会写出敌军来袭、我方可战斗人员、受伤、昏迷和击退统计。
- `debug_get_combat_snapshot()` 现在暴露 `active_battle`、`last_battle_start_result` 和 `last_battle_end_result`，GM 面板既有敌人快照入口可直接观察。
- 新增 `tools/verify_combat_flow.gd`，覆盖战斗开始广播、接敌入战 / 避战、敌人全灭结束广播、受伤 / 击退统计和清敌回工作状态。
- 验证通过：`verify_combat_flow.gd`、`verify_combat_damage.gd`、`verify_combat_alarm_rally.gd`、`verify_avoid_combat_mode.gd`、`verify_combat_strategies.gd`、`verify_combat_time_cap.gd`、`verify_combat_pacing.gd`、`verify_enemy_wave_generation.gd`、`verify_gm_panel.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`。

---

# M12：战斗心理判定、逃离与公开见闻

目标：让战斗不只是数值碰撞，而是能触发 AI 判定、逃离、斗志激昂、昏迷和广场舆论。

---

## T1201 实现战时公开对话心理结果

状态：Done
优先级：P0
前置任务：T0603, T0702, T1103A, T1106
涉及文档：`COMBAT_SYSTEM.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`

任务目标：

在集结 / 战斗 / 避战模式下，守备官主动对话会携带战局上下文，并根据回复产生结构化战时心理意向。

已入伍且有主武器 NPC 在集结 / 战斗模式下：

- 对话强制 `local_public`，同地点公开 toggle 默认开启且不可关闭。
- Prompt 明确当前模式为集结或战斗，并注入战斗 / 集结事件。
- 请求继承 T0603 对话上下文，并额外携带 `battlefield_context`：敌方 / 友方数量、兵种、HP，参战 NPC，驿站内非战斗人员。
- 回复额外输出 `wartime_reaction = none | escape | morale_boost`。
- `morale_boost` 由程序应用为 2 游戏小时斗志 buff，提高一定攻击力和移动速度。
- `escape` 触发逃离流程，由 T1203 的 `CombatSystem.start_npc_escape(...)` 执行移动、离站标记和事件入库。

非战斗人员在避战模式下：

- 对话强制 `local_public`。
- Prompt 明确其正在躲避敌人袭击，并注入 `battlefield_context`。
- 仍可勾选“提出应征”，征召结果沿用日常对话逻辑。
- 如果避战中同意应征但仍无主武器，程序保持 `avoid_combat`；只有已入伍且有主武器、场上仍有敌人时才切入 `combat`。

禁止事项：

- 可先用 Mock，不接真实模型。
- 不实现复杂情绪数值。
- 不重新引入战斗开始时全员判定。

验收标准：

- 集结 / 战斗 / 避战模式下打开对话时，公开 toggle 锁定开启。
- 请求包含 `current_order`、短期事件 / 见闻、地点上下文和 `battlefield_context`。
- 已入伍且有主武器 NPC 回复可返回 `none`、`escape` 或 `morale_boost`。
- `morale_boost` 会写入事件并应用 2 游戏小时 buff；`escape` 会进入逃离流程。
- 避战中的非战斗人员可通过同一对话接受应征；仍无主武器时继续避战，装备主武器且仍有敌军时进入战斗模式。
- 结果写入 NPC 事件库，公开对话按地点广播。
- 后端失败时使用规则判定。
- 对话等待期间申请 TimeSystem 慢速，请求完成、失败、取消或规则降级后释放。

完成记录（2026-06-25）：

- `DialogSystem` 在 `rally` / `combat` / `avoid_combat` 玩家对话中强制 `local_public`，UI toggle 默认开启且锁定。
- `LLMBridge` 的 `/npc/dialogue` payload 新增 `interaction_context` 与 `battlefield_context`，并保留 `current_order`、短期记忆和地点上下文。
- `NPCDialogueResponse` / Mock 新增 `wartime_reaction`；后端不可用时战时对话走规则 fallback。
- `CombatSystem` 应用 `battle_psychology_result`、2 游戏小时 `morale_boost` 攻击 / 移动加成和调试快照；T1203 后 `escape` 直接进入逃离流程，移动期间 `escape_intent.status == "escaping"`。
- 新增 `tools/verify_wartime_dialogue.gd` 覆盖强制公开、payload 注入、fallback、士气、逃离意图和避战应征。

---

## T1202 实现 HP 低于 30% 心理判定

状态：Done
优先级：P0
前置任务：T1104, T1201
涉及文档：`COMBAT_SYSTEM.md`

任务目标：

实现战时 NPC HP 首次低于 30% 的自身心理判定。该判定不只限于参战 NPC：避战中的未入伍 NPC、以及已入伍但无主武器的非战斗人员被敌人追上并打到残血时，也必须触发一次判定。

验收标准：

- 当前战斗 / 敌人在场期间，任一未昏迷、未逃离 NPC 的 HP 从不低于 30% 首次跌破 30% 且仍大于 0 时触发判定；包括 `combat`、`avoid_combat`、被敌人直接攻击后从睡觉转入战斗 / 避战的 NPC。
- 已昏迷、已逃离、HP 已低于 30% 后再次受击、或 HP 直接清零进入昏迷的 NPC 不触发该判定。
- 判定请求继续包含该 NPC 最新 `current_order`，并包含短期事件 / 见闻、地点上下文和 `battlefield_context`。
- 判定请求没有守备官本轮发言。
- 已入伍且有主武器、实际处于 `combat` 模式的 NPC 可返回继续参战、逃离或斗志激昂。
- 不参战 / 避战 NPC 不会触发斗志激昂，也不会继续参战；只允许触发逃离驿站意向，或留在驿站继续避战（无事发生）。
- 每个 NPC 每波最多触发一次。
- 低血量事实和判定结果进入 NPC 事件库与广场公开信息。
- 判定等待期间，玩家不能与该 NPC 对话；如果触发时对话正在进行，强制结束对话、关闭对话框并取消未完成 LLM 请求。
- 判定等待期间申请 TimeSystem 慢速，请求完成、失败或规则降级后释放。

验收结果（2026-06-25）：

- `NPCSystem.apply_damage_to_npc(...)` 在权威扣血后回调 `CombatSystem.handle_npc_damage_applied(...)`，当前战斗中任一 NPC HP 首次从不低于 30% 跌破 30% 且仍大于 0 时触发自身心理判定。
- `LLMBridge.request_npc_battle_judgement(...)` 已接通 `/npc/battle_judgement`，payload 包含最新 `current_order`、短期记忆、地点上下文、`battlefield_context`、低血量事实和 Godot 侧限制后的 `allowed_decisions`。
- 参战且已入伍持主武器的 `combat` NPC 只允许继续参战、逃离或斗志激昂；避战 / 非战斗人员只允许逃离或继续避战，模型越界或后端失败时由 Godot 规则降级。
- 低血量事实写入 `low_hp_triggered`，判定结果写入 `battle_psychology_result`，并进入广场公开事件；每场战斗的 `active_battle.low_hp_judgements` 与 GM 敌人快照暴露最近判定结果。
- 判定期间目标 NPC 处于不可对话的 LLM 活动；若触发时正在对话，会强制结束目标对话并取消未完成回复。请求会申请 TimeSystem 慢速并在完成、失败或规则降级后释放。
- 新增 `tools/verify_low_hp_battle_judgement.gd`，覆盖参战 NPC 继续参战、避战 NPC 继续避战、不重复触发、对话强制结束、低血事件 / 心理事件入库、最新指令注入和慢速释放。

---

## T1203 实现逃离驿站行为

状态：Done
优先级：P0
前置任务：T0304, T1201
涉及文档：`AI_NPC_SYSTEM.md`, `COMBAT_SYSTEM.md`

规则：

- NPC 前往后门。
- 完全离开地图后状态变为 escaped。
- 逃离事件公开到广场。
- 逃离 NPC 不再参与工作和战斗。
- 逃离驿站不同于非战斗人员的避战模式；避战只是留在驿站内躲避敌人。
- 逃离可由战时公开对话的 `escape` 意向、低血量自身心理判定、逃离挽留失败或调试入口触发。

验收标准：

- 可通过判定或调试触发逃离。
- NPC 会走向出口。
- 离开后从可用 NPC 列表中移除或标记。
- 事件记录完整。

完成记录：

- `CombatSystem.start_npc_escape(...)` / `debug_start_npc_escape(...)` 已接入逃离流程，战时公开对话 `escape` 和低血量自身心理判定 `escape_station` 会直接触发 NPC 前往后门外出口。
- 逃离开始写入广场公开 `escape_started`；移动期间 `escape_intent.status == "escaping"`，NPC 切出工作 / 战斗行为，不再接受普通行动或被战斗 AI 当作可行动单位。
- NPC 到达后门外出口后由 `NPCSystem` 标记 `escaped=true`、`behavior_mode="escaped"`、`current_location="outside_station"`，隐藏并取消拾取 NPC 实体，写入广场公开 `escaped` 事件。
- `CombatSystem.debug_get_combat_snapshot()` 暴露 `active_escapes` 与 `last_escape_result`；GM 面板新增“触发逃离”按钮和 `escape_npc <npc_id>` 命令。
- 新增 `tools/verify_escape_station_behavior.gd`，覆盖调试触发、后门移动、行动阻断、离图标记、节点隐藏、广场事件和 GM 命令。

验证通过：`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_low_hp_battle_judgement.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`。

---

## T1204 实现逃离挽留五轮对话

状态：Done
优先级：P1
前置任务：T0701, T1203
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`, `PROMPTS.md`

规则：

- NPC正在逃离时，头上会出现一个特殊的标识警示玩家他正在逃离，UI也会弹出一个提示警示玩家正在有NPC逃离。
- NPC 完全离开前，玩家可进行最多 5 轮对话。
- 玩家仍可在完全离开前与其交互，不同于正常工作模式的交互，正在离开状态的NPC，给钱会让他离开的移动速度更慢，攻击则会让他离开的移动速度更快。如果在这期间昏迷，醒来后依然是正在逃离驿站的状态。
- 对话后 NPC 在回复里包括留下或继续逃离的结构化信息，解析后决定该NPC是留下还是继续逃离。如果在5轮里其中一轮决定留下，则变回工作模式，重新做计划。如果仍要继续逃离，那么玩家可再次发起对话，直到满5轮。

验收标准：

- 逃离 NPC 可被点击打开 NPC 面板，并通过【对话】进入挽留对话。
- 轮数限制生效。
- 结果改变 NPC 状态。
- 事件进入 NPC 事件库和广场公开信息。

完成记录（2026-06-29）：

- `DialogSystem` 新增 `escape_intervention` 对话模式：逃离中 NPC 可通过 NPC 面板【对话】进入同地点公开挽留对话，最大 5 轮，不显示应征开关；T1204A 起打开时暂停逃离移动，关闭或满 5 轮后恢复。
- `CombatSystem` 解析 `stay_after_intervention` / `leave_after_intervention`：留下会停止移动、切回 `work` 并触发计划重评估；继续逃离会保留 `escape_intent.status == "escaping"` 并记录已用轮次。
- 逃离中给钱会降低 `escape_intent.speed_multiplier`，守备官攻击会提高该倍率；逃离期间昏迷会暂停为 `paused_unconscious`，复苏后继续前往后门外出口。
- NPC 头顶新增 `!` 逃离警示，HUD 顶部显示正在逃离的 NPC 名称；`escape_intervention_result` / `escape_speed_changed` 写入 NPC 事件库和广场公开信息。
- `/npc/dialogue` Schema / Mock 支持 `dialogue_kind == "escape_intervention"`、`interaction_context == "escape_intervention"`、`escape_intervention_round` 和 stay/leave 意图。
- 新增 `tools/verify_escape_intervention_dialogue.gd`，覆盖 NPC 面板入口、5 轮限制、打开暂停、关闭恢复、留下 / 继续状态变化、事件入库、给钱减速、逃离攻击无回复计轮和昏迷复苏续逃。

验证通过：`godot --headless --path . --script res://tools/verify_escape_intervention_dialogue.gd`、`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`、`python tools/verify_backend_schemas.py`、`python tools/verify_mock_model_adapter.py`。

---

## T1204A 调整逃离挽留入口、暂停与攻击规则

状态：Done
优先级：P1
前置任务：T1204
涉及文档：`CURRENT_STATE.md`, `AI_NPC_SYSTEM.md`, `UI_UX.md`, `COMBAT_SYSTEM.md`, `PROMPTS.md`, `GM_PANEL.md`, `game_design.md`

规则：

- 逃离 NPC 不再由场景实体点击直接进入挽留；玩家点击 NPC 后打开 NPC 面板，再点击【对话】按钮进入逃离挽留。
- 只要逃离挽留剩余轮次大于 0，【对话】按钮可用；已满 5 轮且没有挽留成功时，【对话】按钮置灰不可点击。
- 进入逃离挽留对话时，NPC 暂停逃离移动；玩家未满 5 轮时关闭面板，NPC 恢复逃离移动，之后仍可再次打开对话并再次暂停。
- 玩家发送消息且 NPC 回复后才计为一轮；满 5 轮仍未挽留成功时自动关闭对话面板，NPC 恢复逃离移动。
- 逃离挽留面板内点击攻击会计为一轮，立刻关闭对话面板并让 NPC 继续逃离；该攻击不向 NPC LLM 发送消息，也不会产生 NPC 回复。

验收标准：

- 逃离中 NPC 点击打开 NPC 面板；【对话】按钮按剩余轮次启用/置灰。
- 进入逃离挽留对话时 NPC 停止移动，关闭或满 5 轮后继续逃离。
- 普通消息 + NPC 回复才计轮；满 5 轮自动关闭。
- 逃离挽留攻击不发起 LLM 请求、不写攻击回复对话事件，计一轮后关闭并继续逃离。

完成记录（2026-06-29）：

- `NPCSystem.handle_npc_clicked(...)` 不再接管逃离 NPC 的点击，逃离 NPC 点击会走正常 NPC 面板入口。
- `NPCPanel` 按 `CombatSystem.get_escape_intervention_state(...)` 控制【对话】按钮：剩余轮次大于 0 时可进入挽留，5 轮用完后置灰并显示禁用提示。
- `CombatSystem` 新增 `pause_escape_for_dialogue(...)` / `resume_escape_after_dialogue(...)`，进入逃离挽留时暂停移动，关闭、攻击或满 5 轮后恢复后门逃离移动。
- `DialogSystem` 调整 `escape_intervention`：玩家消息需等 NPC 回复后才计轮，满 5 轮自动关闭；逃离挽留攻击走无回复分支，只扣 HP、加速、计 1 轮、关闭面板并继续逃离，不请求 LLM、不写攻击回复 `dialogue_turn`。
- `data/action_defs.json` 补充 `escaping_station` 与 `escape_intervention_dialogue` 系统行动，避免逃离和暂停挽留状态显示缺定义。
- 更新 `tools/verify_escape_intervention_dialogue.gd`，覆盖 NPC 面板入口、暂停 / 恢复、五轮置灰、消息计轮、无回复攻击、给钱减速和昏迷复苏续逃。

验证通过：`godot --headless --path . --script res://tools/verify_escape_intervention_dialogue.gd`、`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --quit-after 1`；临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py` 后通过 `godot --headless --path . --script res://tools/verify_dialogue_ui.gd`；Godot MCP 连接、自检、运行 `Main.tscn` 和错误日志检查通过。

---

## T1204B 修正逃离攻击事件与 NPC 面板交互提示

状态：Done
优先级：P1
前置任务：T1204A
涉及文档：`CURRENT_STATE.md`, `UI_UX.md`, `MEMORY_AND_INFO_SPACE.md`, `COMBAT_SYSTEM.md`, `MODULE_INDEX.md`

规则：

- 逃离挽留对话里点击攻击时，只写守备官攻击造成的伤害事件和 `escape_speed_changed` 逃离加速事件。
- 逃离攻击仍计 1 轮并关闭面板、恢复逃离，但不写 `escape_intervention_result`，不出现“听完守备官的话后仍继续逃离驿站”。
- NPC 面板里的给钱 / 装备 / 策略等临时交互提示只属于当前显示对象；切换到另一个 NPC 面板时必须清空。

完成记录（2026-06-29）：

- `DialogSystem._apply_escape_attack_without_reply(...)` 不再调用 `apply_escape_intervention_result(...)`，改为只记录逃离攻击计轮。
- `CombatSystem` 新增 `record_escape_attack_intervention_round(...)`，用于更新逃离挽留已用轮次但不写 `escape_intervention_result` 事件。
- `NPCPanel.show_npc(...)` 在切换到不同 NPC 或隐藏面板时清空 `NPCInteractionResultLabel`，避免给钱成功提示串到其他 NPC。
- `tools/verify_escape_intervention_dialogue.gd` 增加逃离攻击不写 `escape_intervention_result` 的断言。
- `tools/verify_npc_panel_interactions.gd` 增加给钱成功提示切换 NPC 后清空的断言。

验证通过：`godot --headless --path . --script res://tools/verify_escape_intervention_dialogue.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --quit-after 1`。

---

## T1205 完善战场公开信息

状态：Done
优先级：P0
前置任务：T0404, T1106, T1202
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `COMBAT_SYSTEM.md`

公开内容：

- 敌我大致人数
- NPC 行为模式变化：进入集结、昏迷、逃离等需要留痕的切换；非战斗人员避战由 `avoidance_started` / `avoidance_ended` 表达，工作 / 战斗与工作 / 避战互转不广播
- NPC 被打到 30% HP 以下
- NPC 战时对话结果：斗志激昂或逃离意向
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
- 行为模式、避战、斗志激昂、逃离意向事件与地点 / 广场公开规则一致，不把 LLM 输出直接当作权威事件。

完成记录（2026-06-29）：

- 已对照 T1106、T1201、T1202、T1203、T1204A/T1204B 现有实现确认：`combat_started` / `combat_ended`、`combat_rally_started` / `npc_mode_changed`、`avoidance_started` / `avoidance_ended`、`low_hp_triggered`、`battle_psychology_result`、`attack_made`、`unconscious_started`、`healing_started`、`revived`、`escape_started` / `escaped`、`building_damaged` 均由权威系统写入结构化事件；战场室外事件统一走 `location_id == "plaza"` 的 `local_public` 或同地点见闻写入。
- 新增 `tools/verify_battlefield_public_info.gd`，综合覆盖广场旁观者见闻、NPC 面板见闻显示、LLMBridge 对话 payload 的 `witnessed_events`、敌我人数、集结 / 避战 / 低血 / 战时心理 / 击退 / 昏迷 / 治疗 / 复苏 / 逃离 / 建筑受损 / 战斗结束事件，以及 `work <-> combat`、`work <-> avoid_combat` 不再通过 `npc_mode_changed` 广播。
- `tools/verify_wartime_dialogue.gd` 固定使用关闭端口验证规则降级，避免本机已有后端服务导致误判。
- 未新增 GM 面板入口；现有 GM 敌人快照、记忆 / 见闻、伤害、治疗、逃离和建筑调试入口已能触发和观察相关状态。

验证通过：`godot --headless --path . --script res://tools/verify_battlefield_public_info.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_low_hp_battle_judgement.gd`、`godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd`、`godot --headless --path . --script res://tools/verify_escape_station_behavior.gd`、`godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

# M13：波次推进、胜负结算与 Demo 闭环

目标：形成完整可玩的 5 波防守 Demo，有胜利、失败和 NPC 结局总结。

---

## T1301 实现波次倒计时与自动来袭

状态：Done
优先级：P0
前置任务：T0401, T1101
涉及文档：`COMBAT_SYSTEM.md`, `UI_UX.md`

验收标准：

- HUD 显示下一波倒计时。
- 第 3 天或配置时间触发小股敌人。
- 之后按配置触发更强敌人。
- 可手动调试跳到下一波。
- 波次倒计时与触发时间使用 TimeSystem 逻辑时间，不使用真实时间。

完成记录（2026-06-30）：

- `CombatSystem` 新增波次日程状态，按 `data/enemy_waves.json` 的 `trigger_day` / `trigger_hour` / `trigger_minute` / `trigger_second` 在 `logical_time_tick` 中自动触发下一未触发波次，并记录已触发波次，避免同一波重复自动生成。
- HUD 新增 `WaveCountdownLabel`，显示下一波倒计时；敌人在场时同时显示当前波次 / 敌人数量和下一波。
- GM 面板战斗分组新增“跳到下一波”按钮，并补充 `next_wave` / `jump_wave` 命令；该入口只调用 `CombatSystem.debug_trigger_next_wave()`，不在 UI 内自行结算波次。
- 新增 `tools/verify_enemy_wave_schedule.gd`，覆盖 HUD 倒计时、第 3 天 18:00 自动触发第一波、自动触发不重复、GM 按钮 / 命令跳到下一波。

验证通过：`godot --headless --path . --script res://tools/verify_enemy_wave_schedule.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 运行 `res://scenes/main/Main.tscn` 后编辑器错误日志为空。

---

## T1302 实现主厅失败条件

状态：Done
优先级：P0
前置任务：T1102, T1104
涉及文档：`COMBAT_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

验收标准：

- 主厅 HP 清零后进入失败结算。
- 失败原因记录为主厅被摧毁。
- 游戏停止正常推进。
- 显示失败界面占位。

完成记录（2026-06-30）：

- `GameState.set_game_over(...)` 现在记录失败结果、失败原因和结算时间，并通过 `EventBus.game_over_changed` 广播结算状态。
- 主厅被敌人攻击至 HP 清零时，`CombatSystem` 保持原有权威触发路径，记录 `last_failure_result`，并写入 `failure/main_hall_destroyed`。
- `TimeSystem` 监听 game-over 信号，失败后自动暂停并阻止逻辑时间继续推进。
- HUD 新增 `GameOverPanel` 失败占位界面，显示“防守失败”、原因“主厅被摧毁”、失败时间和“游戏已停止正常推进”提示。
- 新增 `tools/verify_main_hall_failure.gd`，覆盖主厅摧毁、失败原因、时间停止和失败占位 UI。

验证通过：`godot --headless --path . --script res://tools/verify_main_hall_failure.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_schedule.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_time_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --quit-after 1`。

---

## T1303 实现无可战斗人员失败条件

状态：Done
优先级：P1
前置任务：T0501, T1203
涉及文档：`COMBAT_SYSTEM.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `DEV_LOG.md`

验收标准：

- 所有可战斗人员离开或昏迷，且下一波无法抵抗时触发失败。
- 失败原因记录清楚。
- 不误判短暂未集结状态。

完成记录（2026-06-30）：

- `CombatSystem` 新增战斗人员可用性快照，已入伍且持主武器、未昏迷、未逃离且未正在逃离的 NPC 计为可抵抗人员；工作、尚未摇铃、尚未集结或尚未接敌不视为不可抵抗。
- 活动敌人在场时，波次生成、逻辑推进、NPC 昏迷、逃离开始和逃离完成都会检查可用性；若存在可战斗人员但全部处于昏迷、已逃离或正在逃离状态，则写入 `failure/no_available_combatants`，记录 `combatant_availability`，并复用 GameState / TimeSystem / HUD 的失败占位结算链路。
- `debug_get_combat_snapshot()` 暴露 `combatant_availability`，GM 面板现有敌人快照可观察可战斗人员总数、可用者和不可用原因；未新增新的 GM 结算按钮。
- HUD 失败原因新增“无可战斗人员”显示。
- 新增 `tools/verify_no_available_combatants_failure.gd`，覆盖有武装守备者但未集结不失败、一名战斗人员逃离后仍有另一名可用者不失败、最后可用战斗人员昏迷后触发失败、失败时间 / HUD / 快照记录。

验证通过：`godot --headless --path . --script res://tools/verify_no_available_combatants_failure.gd`、`godot --headless --path . --script res://tools/verify_main_hall_failure.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_combat_time_cap.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_schedule.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_combat_damage.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 运行 `res://scenes/main/Main.tscn` 后编辑器错误日志为空。

---

## T1304 实现 5 波胜利条件

状态：Done
优先级：P0
前置任务：T1301, T1106
涉及文档：`COMBAT_SYSTEM.md`, `CURRENT_STATE.md`

验收标准：

- 成功守住第 5 波后进入胜利结算。
- 游戏停止继续刷波。
- 显示胜利界面占位。
- 记录剩余资源、建筑状态、NPC 状态。

完成记录（2026-07-03）：

- `CombatSystem` 在包含最终配置波次（当前第 5 波）的战斗清敌后触发 `victory/five_waves_survived`，并在 `last_victory_result` 中保留战斗结束结果与结算快照。
- `GameState.set_game_over(...)` 支持通用 `game_over_reason` 与 `settlement_snapshot`；胜利快照记录剩余资源、建筑 HP / 损毁 / 摧毁状态、驿站是否仍可运转、NPC 可行动 / 昏迷 / 逃离状态。旧 `failure_reason` 仅在失败时保留，兼容既有失败验证。
- HUD `GameOverPanel` 复用为胜负占位界面；胜利时显示“防守成功”、守住 5 波、剩余资源摘要、建筑状态摘要和 NPC 状态摘要。
- 结算后 `spawn_wave(...)` 会拒绝继续生成敌人；自动波次调度也因 `GameState.game_over` 停止推进。
- 新增 `tools/verify_five_wave_victory.gd`，覆盖手动触发 5 波、清敌胜利、停止时间、胜利快照、HUD 胜利占位和结算后拒绝刷波。

验证通过：`godot --headless --path . --script res://tools/verify_five_wave_victory.gd`、`godot --headless --path . --script res://tools/verify_main_hall_failure.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_schedule.gd`、`godot --headless --path . --script res://tools/verify_no_available_combatants_failure.gd`、`godot --headless --path . --script res://tools/verify_combat_flow.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T1305 实现 NPC 结局总结页面

状态：Done
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

完成记录（2026-07-03）：

- `GameState.set_game_over(...)` 会在任意胜负结算时规范化 `settlement_snapshot`，并补齐 `npcs.items` 结局明细：最终状态、是否入伍、最后位置、Mock 最终看法、Mock 后续命运和日记 / 事件记忆依据。
- HUD `GameOverPanel` 详情区改为滚动区；胜利和失败都会显示 `NPC 结局`，每名 NPC 展示最终状态、入伍状态、最后位置、对守备官最终看法和后续命运。结局文案不使用“阵亡”或“死亡”表述。
- 胜利保留 T1304 的剩余资源、建筑状态和 NPC 状态摘要；失败也会显示 NPC 总结，不再只有失败原因和停止推进提示。
- 扩展 `tools/verify_five_wave_victory.gd` 和 `tools/verify_main_hall_failure.gd`，覆盖 NPC 结局字段、HUD 明细和禁用死亡表述。

验证通过：`godot --headless --path . --script res://tools/verify_five_wave_victory.gd`、`godot --headless --path . --script res://tools/verify_main_hall_failure.gd`、`godot --headless --path . --script res://tools/verify_no_available_combatants_failure.gd`、`godot --headless --path . --script res://tools/verify_hud_resources.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 运行 `res://scenes/main/Main.tscn` 后编辑器错误日志为空。

---

# M14：真实 LLM 接入与 Prompt 打磨

目标：在开发期 Mock 闭环稳定后，接入真实模型，逐步替换 Mock 输出，并控制成本。M14 起，Mock 只能作为开发测试工具；真实 API 验收通过后，成品 / Demo 路径必须关闭自动 mock fallback，让模型失败以错误、日志、规则 / 模板降级的形式真实暴露。

---

## T1401 接入真实 Model Adapter

状态：Done
优先级：P1
前置任务：T0602, T0701
涉及文档：`TECH_ARCHITECTURE.md`, `API_BUDGET.md`, `PROMPTS.md`

任务目标：

支持至少一个真实模型供应商。

候选：

- DeepSeek首选，deepseek v4-flash
- MiniMax
- 通义千问
- 智谱

规则：

- API Key 只从环境变量读取。
- 真实供应商 API Key 默认只存在于游戏服务器后端或开发者本地后端环境，Godot 导出客户端不保存、不上传、不直连模型供应商。
- Demo 阶段正式方向是玩家客户端请求服务器后端，由服务器后端调用 LLM；玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式，不作为 Demo 必需路径。
- Mock 只能通过显式开发配置切换，不作为成品 / Demo 默认路径。
- 真实 provider 请求失败不得自动降级到 mock；必须返回可处理错误并记录真实失败原因。规则 / 模板降级可以维持流程，但必须标明来源。
- 所有调用记录 token 和用途。
- 所有失败记录 request id、call_type、provider、model、HTTP 状态或异常类型和失败原因，日志不得包含 API Key。
- Godot 侧所有会影响当前事态的真实模型请求必须与 TimeSystem 慢速请求成对注册/释放。

验收标准：

- 本地 `.env` 配置后可调用真实模型。
- 不提交真实 Key。
- 无 Key 时开发模式可显式使用 Mock；生产 / 演示模式必须报告未配置或返回可处理错误，不得假装模型成功。
- 成本统计可见。
- 请求失败、超时或降级时不会让游戏长期保持慢速逻辑时间。
- 使用真实 API Key 完成至少一次真实 provider smoke test；如果没有真实 Key，本任务只能记录为真实路径未验收。

完成记录（2026-07-07）：

- `backend/services/model_adapter.py` 已支持 `deepseek` / `openai_compatible` 真实模型调用，DeepSeek 默认 `LLM_BASE_URL=https://api.deepseek.com`、`LLM_MODEL=deepseek-v4-flash`，API Key 只从 `LLM_API_KEY` / 本地 `backend/.env` 或服务器环境变量读取。
- 当前代码状态：`LLM_PROVIDER=mock` 仍是本地开发默认路径；非 mock provider 无 Key、请求失败、超时、HTTP 错误或返回非 JSON 时仍支持通过 `LLM_FALLBACK_TO_MOCK=true` 自动降级到 mock，显式设为 `false` 时返回可处理错误。该行为只作为历史实现记录和开发过渡，不再作为 M14 后续验收标准。
- `ModelAdapter` 现在记录 provider、model、call_type、request id、NPC id、关联事件 id、输入 / 输出 token、费用估算、成功状态、fallback_used 和失败原因；`backend/app.py` 复用同一个 adapter 实例并提供 `GET /debug/llm_usage` 只读统计。
- `GET /health` 现在返回 `model_adapter` 运行配置快照，便于确认当前 provider、model、base_url、configured、fallback_to_mock 和 timeout。
- Godot `LLMBridge` 新增 `request_llm_usage()` / `debug_request_llm_usage()`，GM 面板新增“成本统计”按钮和 `llm_usage` 命令；该入口只读取后端统计，不申请 TimeSystem 慢速、不写游戏权威状态。
- `backend/.env.example` 已改为默认 mock，并列出 DeepSeek / OpenAI-compatible 配置项；未提交真实 Key。
- T1401 只接入真实 Model Adapter 和基础 JSON schema guard，NPC 对话、每日计划、战时判定和首次睡眠总结的正式 Prompt 打磨仍由 T1402-T1405 继续。
- 设计修正（2026-07-07）：后续任务必须执行 0.6 的真实 API 验收规则；T1401 的自动 mock fallback 需由 T1401A 封存为开发期能力，不能进入成品 / Demo 默认路径。

验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_mock_model_adapter.py tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_plan_revision_endpoint.py`、`python tools/verify_daily_reflection_endpoint.py`、临时以 `LLM_PROVIDER=mock` 启动 Flask 后运行 `godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T1401A 封存成品 Mock fallback 与真实失败日志

状态：Done
优先级：P0
前置任务：T1401
涉及文档：`TECH_ARCHITECTURE.md`, `API_BUDGET.md`, `PROMPTS.md`, `backend/README.md`, `GM_PANEL.md`

任务目标：

把 T1401 中的自动 mock fallback 从成品 / Demo 路径移出，仅保留为显式开发调试能力；真实 provider 失败时返回可处理错误，日志中能看到真实失败原因。

实现范围：

- 生产 / 演示配置默认 `LLM_FALLBACK_TO_MOCK=false`，真实 provider 失败不得自动返回 mock 内容。
- `LLM_PROVIDER=mock` 和 `/mock/model` 可继续保留，但必须标记为开发 / 自动化测试入口。
- 业务接口在模型失败时返回明确错误结构，Godot 侧释放 TimeSystem 慢速，并按业务需要进入规则 / 模板降级。
- usage / 日志记录 request id、call_type、provider、model、NPC id（如有）、HTTP 状态或异常类型、失败原因、是否规则 / 模板降级和 token / 费用估算。
- 不能把 API Key、完整请求头或敏感环境变量写入日志。

验收标准：

- Mock / schema 自动化测试仍通过。
- 使用真实 API Key 对 `/npc/dialogue` 至少完成一次真实 provider 调用，并在 `GET /debug/llm_usage` 中看到真实 provider、model、token / 费用估算且 `fallback_used=false`。
- 使用错误 Key、无 Key 或模拟 provider 失败时，业务接口返回可处理错误或明确规则 / 模板降级，不返回 mock 回复；日志 / usage 可定位真实失败原因。
- Godot 侧请求失败、超时或业务错误后都会释放 TimeSystem 慢速请求。
- `backend/README.md` 和相关模块文档明确 mock 只用于开发，真实 API 验收通过后不依赖 mock。

完成记录（2026-07-07）：

- `ModelAdapterConfig.fallback_to_mock` 与环境变量默认值已改为 `false`；生产 / 演示路径真实 provider 失败不再自动返回 mock 内容。显式 `LLM_PROVIDER=mock` 和 `/mock/model` 仍作为开发 / 自动化测试入口保留；如确需对比旧行为，必须显式设置 `LLM_FALLBACK_TO_MOCK=true`。
- usage 记录补齐 `http_status`、`exception_type`、`degradation_source`、最近失败摘要和 Schema 校验失败记录；无 Key、HTTP 错误、超时、非 JSON、模型输出不符合业务 Schema 都会返回可处理错误并记录真实原因，不写入 API Key 或请求头。
- Model Adapter 的通用 schema guard 加硬了枚举约束，避免真实 provider 自造 `response_kind`、`intent`、`wartime_reaction` 等字段值；正式角色语气和 Prompt 质量仍留给 T1402-T1405。
- 真实 API 验收：使用本地真实 `LLM_PROVIDER=deepseek` / `LLM_API_KEY` / `LLM_FALLBACK_TO_MOCK=false` 对 `/npc/dialogue` 完成一次真实 provider 调用，返回 200；`GET /debug/llm_usage` 显示 provider=`deepseek`、model=`deepseek-v4-flash`、input_tokens=873、output_tokens=303、`fallback_used=false`。另外无 Key 场景返回 503 `provider_unavailable`，usage 记录 `exception_type=ConfigurationError` 且 `fallback_used=false`。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_mock_model_adapter.py tools/verify_dialogue_mock_endpoint.py tools/verify_plan_day_endpoint.py tools/verify_plan_revision_endpoint.py tools/verify_daily_reflection_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_plan_revision_endpoint.py`、`python tools/verify_daily_reflection_endpoint.py`、`python tools/verify_backend_schemas.py`、临时以 `LLM_PROVIDER=mock` 启动 Flask 后运行 `godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

---

## T1402 打磨 NPC 对话 Prompt

状态：Done
优先级：P1
前置任务：T1401, T0702
涉及文档：`PROMPTS.md`, `AI_NPC_SYSTEM.md`

验收标准：

- NPC 回复符合职业、人设、记忆。
- NPC 回复能参考当前 `current_order`，并可结合人格和现场状态回复。
- “提出应征”时能接受或拒绝。其他需要返回明确选项的场景也要返回相应的选项，比如有的场景里有“斗志高昂”，有的场景有逃离驿站。通过查找game_design来明确哪些场景需要这些选项。
- 输出稳定 JSON。
- 不越权决定程序数值。
- 基础 mock / schema 测试通过后，必须使用真实 API Key 对日常对话、提出应征、战时结构化意向或逃离挽留中本任务触及的路径做真实调用验证；无真实 Key 时不得标记为完全 Done。
- 模型失败时可查询日志发现真实失败原因，且不得返回 mock 回复伪装成功。

完成记录（2026-07-07）：

- 新增 `data/prompts/dialogue_system_prompt.txt`，作为 `/npc/dialogue` 真实 provider 的独立系统 Prompt 模板；`ModelAdapter` 会在 `call_type=dialogue` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- 对话 Prompt 明确目标 NPC 只回复自己，必须参考职业、人设、当前状态、亲历事件、见闻、长期记忆、地点状态和 `current_order`；`current_order` 只作为守备官持续指令参考，不能越权决定行动、资源、HP、建筑、装备、斗志 buff 或逃离移动。
- 已按 `game_design.md` 收敛结构化选项：日常 / 征召使用 `recruitment_result=none|accept|reject`；集结 / 战斗对已入伍持主武器 NPC 使用 `wartime_reaction=none|escape|morale_boost`；避战对话不触发 `wartime_reaction`，继续用征召结果表达是否应征；逃离挽留只允许 `intent=stay_after_intervention|leave_after_intervention`。
- 新增 `tools/verify_dialogue_prompt.py`，用 fake real-provider 请求检查系统 Prompt 包含职业、记忆、`current_order`、征召、战时、避战和逃离挽留约束，并验证返回 JSON 符合 `NPCDialogueResponse`。
- 新增 `tools/verify_dialogue_prompt_real.py`，在本机存在非 mock provider 和真实 `LLM_API_KEY` 时，对 `/npc/dialogue` 的日常对话、提出应征、战时结构化意向和逃离挽留各发起一次真实 provider 调用；无 Key 时明确 skip，不把 mock 当验收。
- 真实 API 验收：使用 `LLM_PROVIDER=deepseek`、`model=deepseek-v4-flash`、`LLM_FALLBACK_TO_MOCK=false` 完成 4 次 `/npc/dialogue` 调用，覆盖日常对话、应征、战时意向和逃离挽留；`/debug/llm_usage` 记录 provider=`deepseek`、calls=4、`fallback_used=false`，且无失败。

验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_dialogue_prompt.py tools/verify_dialogue_prompt_real.py tools/verify_mock_model_adapter.py tools/verify_dialogue_mock_endpoint.py tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt_real.py`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`、`godot --headless --path . --quit-after 1`。

---

## T1403 打磨每日计划 Prompt

状态：Done
优先级：P1
前置任务：T1003, T1401
涉及文档：`PROMPTS.md`, `AI_NPC_SYSTEM.md`

验收标准：

- 能输出 24 阶段计划。
- 至少 6 阶段工作。
- 计划使用行动白名单。
- 计划输入包含当前 `current_order`，但指令不得绕过行动白名单、资源或程序强制层。
- 基础 mock / schema 测试通过后，必须使用真实 API Key 对 `/npc/plan_day` 做真实调用验证；无真实 Key 时不得标记为完全 Done。
- 输出不合法或模型失败时记录真实失败原因，并回退规则计划；不得用 mock 计划伪装真实模型成功。

完成记录（2026-07-07）：

- 新增 `data/prompts/daily_plan_system_prompt.txt`，作为 `/npc/plan_day` 真实 provider 的独立系统 Prompt 模板；`ModelAdapter` 会在 `call_type=plan_day` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- 每日计划 Prompt 明确输出 0-23 点共 24 阶段、至少 6 个工作阶段、只使用 `allowed_actions` 或 `idle`，并要求 `current_order` 只作为守备官当前指令参考，不能越过行动白名单、资源、HP、地点、建筑、工位或程序强制层。
- `/npc/plan_day` 在 `DailyPlanResponse` Schema 校验后新增业务校验：hour 必须覆盖 0-23，`action_id` 必须来自 `allowed_actions` / `idle`，工作阶段必须不少于 6；不合法时返回 `model_output_invalid`、记录失败 usage，Godot 侧继续走既有 `rule_plan_fallback`。
- 新增 `tools/verify_plan_day_prompt.py`，用 fake real-provider 检查 plan_day 系统 Prompt 包含 24 阶段、至少 6 工作阶段、行动白名单、`current_order` 和权威边界约束，并覆盖 Schema 合法但行动越界时后端返回 502 与 usage 失败记录。
- 新增 `tools/verify_plan_day_prompt_real.py`，在本机存在非 mock provider 和真实 `LLM_API_KEY` 时，对 `/npc/plan_day` 发起真实 provider 调用并校验返回计划覆盖 0-23 点、只使用白名单行动且工作阶段不少于 6；无 Key 时明确 skip，不把 mock 当验收。
- 真实 API 验收：使用 `LLM_PROVIDER=deepseek`、model=`deepseek-v4-flash`、`LLM_FALLBACK_TO_MOCK=false` 完成 1 次 `/npc/plan_day` 调用；返回计划为 24 阶段、只使用 `allowed_actions` / `idle` 且工作阶段不少于 6；`/debug/llm_usage` 记录 provider=`deepseek`、calls=1、`fallback_used=false`，无失败。

验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_plan_day_prompt.py tools/verify_plan_day_prompt_real.py tools/verify_plan_day_endpoint.py tools/verify_mock_model_adapter.py`、`python tools/verify_plan_day_prompt.py`、`python tools/verify_plan_day_prompt_real.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt.py`、`godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`、`godot --headless --path . --quit-after 1`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`。

---

## T1404 打磨战时对话与低血量心理 Prompt

状态：Done
优先级：P1
前置任务：T1201, T1202, T1401
涉及文档：`PROMPTS.md`, `COMBAT_SYSTEM.md`

验收标准：

- 集结 / 战斗 / 避战公开对话可用真实模型输出战时结构化意向。
- 战斗中低血量自身心理判定可用真实模型。
- 输出只在允许结果中选择。
- 能引用 NPC 记忆、公开见闻和 `battlefield_context`。
- 能参考该 NPC 当前 `current_order`，但不把指令当成强制参战或强制逃离结果。
- 成本可控。
- 基础 mock / schema 测试通过后，必须使用真实 API Key 对战时公开对话和 `/npc/battle_judgement` 中本任务触及的路径做真实调用验证；无真实 Key 时不得标记为完全 Done。
- 模型失败时记录真实失败原因，并按允许结果规则降级；不得返回 mock 心理结果伪装成功。

完成记录：

- 新增 `data/prompts/battle_judgement_system_prompt.txt`，作为 `/npc/battle_judgement` 真实 provider 的独立低血量自身心理判定系统 Prompt；`ModelAdapter` 在 `call_type=battle_judgement` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- 战时公开对话继续复用 `data/prompts/dialogue_system_prompt.txt`；T1404 验收覆盖 `interaction_context=combat` 的结构化 `wartime_reaction`，并与低血量判定同轮真实 provider smoke 验证。
- `/npc/battle_judgement` 在 `BattleJudgementResponse` Schema 校验后新增业务校验：`decision` 必须来自请求 `allowed_decisions`，`should_start_escape` 只能在 `decision == "escape_station"` 时为 true；越界结果返回 `model_output_invalid` 并写入失败 usage，Godot 保持既有允许结果规则降级。
- 新增 `tools/verify_battle_judgement_prompt.py` fake real-provider 验证脚本，覆盖 Prompt 必含 `battlefield_context`、亲历 / 见闻、`current_order`、行动白名单、非战斗避战约束和逃离布尔一致性，并验证非法模型输出会被后端拒绝。
- 新增 `tools/verify_battle_judgement_prompt_real.py` 真实 provider smoke 验证脚本；2026-07-07 已用真实 DeepSeek `deepseek-v4-flash` 对战时 `/npc/dialogue` 与 `/npc/battle_judgement` 各完成一次调用，`/debug/llm_usage` 显示 calls=2、`fallback_used=false`、failed=0。
- 验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_battle_judgement_prompt.py tools/verify_battle_judgement_prompt_real.py tools/verify_mock_model_adapter.py tools/verify_backend_schemas.py tools/verify_dialogue_prompt.py`、`python tools/verify_battle_judgement_prompt.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt.py`、`python tools/verify_plan_day_prompt.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_battle_judgement_prompt_real.py`、`godot --headless --path . --script res://tools/verify_wartime_dialogue.gd`、`godot --headless --path . --script res://tools/verify_low_hp_battle_judgement.gd`、`godot --headless --path . --quit-after 1`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`。

---

## T1405 打磨首次睡眠总结 Prompt

状态：Done
优先级：P1
前置任务：T1004, T1401
涉及文档：`PROMPTS.md`, `MEMORY_AND_INFO_SPACE.md`

验收标准：

- 每天生成知识图谱更新和第一人称日记。
- 日记符合 NPC 语气。
- 长期记忆起到压缩当天关键事件的效果。
- 基础 mock / schema 测试通过后，必须使用真实 API Key 对 `/npc/daily_reflection` 做真实调用验证；无真实 Key 时不得标记为完全 Done。
- 模型失败时记录真实失败原因；允许使用本地模板完成睡眠流程，但必须标明模板来源，不能把 mock 日记当成真实模型成功。

完成记录（2026-07-07）：

- 新增 `data/prompts/daily_reflection_system_prompt.txt`，作为 `/npc/daily_reflection` 真实 provider 的首次睡眠总结系统 Prompt；`ModelAdapter` 会在 `call_type=daily_reflection` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- 首次睡眠总结 Prompt 明确区分知识图谱和日记：`knowledge_graph_updates` 是以 `subject + relation` 为键的替换式当前状态更新，`diary_entry` 是符合 NPC 语气的第一人称日记并按天增量追加。
- `/npc/daily_reflection` 在 `DailyReflectionResponse` Schema 校验后新增业务校验：`npc_id` 必须匹配请求 NPC、`day` 必须匹配请求日期、日记和摘要不能为空、知识图谱更新字段不能为空、世界内文本必须使用“守备官”而非“玩家”；不合法时记录 `model_output_invalid` usage 并让 Godot 走模板降级。
- `NPCSystem.apply_daily_reflection(...)` 不再把知识图谱写入 append-only `knowledge_graph.patches`；现在会规范化为 `knowledge_graph.by_subject[subject][relation] = 当前值`，同一键后续更新覆盖旧值。日记仍追加到 `diary`，保持增量更新。
- 新增 `tools/verify_daily_reflection_prompt.py` fake real-provider 验证脚本，检查 Prompt 包含首次睡眠总结、亲历 / 见闻区分、`current_order`、替换式知识图谱、增量日记和权威边界，并验证模型输出“玩家”会被后端拒绝。
- 新增 `tools/verify_daily_reflection_prompt_real.py` 真实 provider smoke 验证脚本；2026-07-07 已用真实 DeepSeek `deepseek-v4-flash` 对 `/npc/daily_reflection` 完成一次调用，`/debug/llm_usage` 显示 calls=1、`fallback_used=false`、failed=0。
- `tools/verify_daily_reflection_system.gd` 已更新为验证知识图谱同键替换、日记增量追加和不再生成 `patches`。

验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py backend/schemas/npc_ai.py tools/verify_daily_reflection_prompt.py tools/verify_daily_reflection_prompt_real.py tools/verify_daily_reflection_endpoint.py tools/verify_mock_model_adapter.py tools/verify_backend_schemas.py`、`python tools/verify_daily_reflection_prompt.py`、`python tools/verify_daily_reflection_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_daily_reflection_prompt_real.py`、`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py` 后运行 `godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --quit-after 1`、`python tools/verify_dialogue_prompt.py`、`python tools/verify_plan_day_prompt.py`、`python tools/verify_battle_judgement_prompt.py`。

---

## T1406 实现 API 额度面板 / 调试信息

状态：Done
优先级：P1
前置任务：T1401
涉及文档：`API_BUDGET.md`, `UI_UX.md`

验收标准：

- 后端记录调用次数、类型、token、费用估算。
- Godot 或后端调试页面可查看累计消耗。
- 可查看失败次数、失败原因、provider、model、request id、fallback / 降级来源和最近错误摘要。
- 超预算时生产 / 演示路径返回可处理预算错误或使用明确标记的规则 / 模板降级；Mock 只能作为显式开发模式切换。
- Godot 调试信息可查看当前等待中的 LLM 请求数量、有效逻辑倍率和最近一次 TimeSystem 慢速原因。
- 验收必须包含真实 provider 的 usage 记录；无真实 Key 时只能标记真实费用路径未验收。

完成记录（2026-07-07）：

- `ModelAdapter` 新增预算守门配置：`LLM_BUDGET_MAX_CALLS`、`LLM_BUDGET_MAX_INPUT_TOKENS`、`LLM_BUDGET_MAX_OUTPUT_TOKENS`、`LLM_BUDGET_MAX_TOTAL_TOKENS` 和 `LLM_BUDGET_MAX_COST`，默认 `0` 表示关闭。
- 所有正式业务接口经由同一个 `ModelAdapter.generate(...)` 进入预算检查；超预算时返回 HTTP 429 / `budget_exceeded`，usage 记录 `exception_type=BudgetExceeded`、`degradation_source=budget_blocked`、request id、call_type、provider/model、NPC id、输入 token 估算和失败原因，不触发 mock fallback。
- `GET /debug/llm_usage` 和 `/health` 的 `model_adapter` 快照新增预算信息：上限、已用量、剩余额度、是否启用和最近预算错误；既有 usage 仍保留调用次数、类型、token、费用估算、失败次数、失败原因、http 状态、异常类型、fallback / 降级来源和最近失败。
- `TimeSystem.get_time_scale_snapshot()` 新增 `last_time_scale_reason`；`LLMBridge.debug_get_llm_runtime_snapshot()` 新增只读运行态快照，包含当前等待中的 LLM 慢速请求数、pending request id、NPC 活动请求、异步请求数、后端状态、有效逻辑倍率和最近倍率变化原因。
- GM 面板“成本统计”按钮和 `llm_usage` 命令升级为“LLM 额度 / 调试信息”输出，同时显示后端 usage / budget 和 Godot runtime 快照；不申请 TimeSystem 慢速、不写权威状态。
- `backend/.env.example` 和 `backend/README.md` 补充预算环境变量、预算超限行为和验证命令。
- 新增 `tools/verify_api_budget_debug.py`，覆盖真实 provider fake 调用后的 usage / budget 快照、第二次调用超 `max_calls` 后的 `budget_exceeded` usage，以及 Flask 业务接口在输入 token 预算过低时返回 HTTP 429。
- 真实 provider usage 验收：本轮先运行 `python tools/verify_plan_day_prompt_real.py`，DeepSeek `/npc/plan_day` 超时，业务返回 `provider_unavailable`，usage 记录 `provider=deepseek`、`model=deepseek-v4-flash`、`request_id=verify_plan_day_prompt_real`、`exception_type=ConnectionError`、`fallback_used=false`，证明真实失败原因可见；随后使用真实 DeepSeek 对单次 `/npc/dialogue` 发起短请求，返回 200，`/debug/llm_usage` 显示 `provider=deepseek`、`model=deepseek-v4-flash`、`calls=1`、`failed=0`、`fallback_used=false`。

验证通过：`python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_api_budget_debug.py tools/verify_mock_model_adapter.py`、`python tools/verify_api_budget_debug.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_plan_day_endpoint.py`、`python tools/verify_plan_revision_endpoint.py`、`python tools/verify_daily_reflection_endpoint.py`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、临时以 `LLM_PROVIDER=mock` 启动后端后运行 `godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --quit-after 1`、`powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1`。

---

## T1407 部署游戏后端到服务器

状态：Todo
优先级：P2
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
- 明确服务器环境变量：`LLM_PROVIDER`、`LLM_API_KEY`、模型 base url / model name、超时、单用户/全局限流、预算上限；生产 / 演示配置必须关闭自动 mock fallback。
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
- 不在生产 / 演示服务中用 mock 内容掩盖真实 provider 失败。
- 不在本任务重写 NPC、记忆、战斗或对话业务逻辑。

验收标准：

- 在一台干净服务器或本机模拟生产环境中，可以从仓库安装后端依赖并启动生产 WSGI 服务。
- `GET /health` 可从 Godot 客户端所在机器访问。
- Godot `LLMBridge` 可配置为请求服务器地址，并通过 `/health` 与 `/npc/dialogue`。
- 生产 / 演示后端无真实 Key 时 health / LLM 业务接口会明确报告未配置或返回可处理错误；本地开发可显式启用 mock，但不能作为部署默认。
- 有真实 Key 时通过 Model Adapter 调用真实模型，并在 usage / 日志中看到真实 provider、model、request id、token / 费用估算和 `fallback_used=false`。
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
前置任务：T0202, T0401, T0807
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`

验收标准：

- 每天特定时段商人到后门。
- 玩家可买粮食、木材、石料、铁。
- 玩家可卖酒。
- 交易事件写入结构化事件。
- 需要接住 T0807 的 `wine` 派生库存：出售酒时扣除 `wine`，增加 `money`，价格由交易系统配置决定，不能在酒窖工作完成时自动换钱。

---

## T1508 工程器械部署

状态：Todo
优先级：P2
前置任务：T0805, T1104
涉及文档：`COMBAT_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`

验收标准：

- 消耗 T0805 产出的 `defense_devices` 工程器械库存。
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
- 如果情绪识别接入外部模型或 LLM，基础 mock 测试通过后必须用真实 API Key 验证；失败时记录真实原因并忽略情绪，不得用 mock 情绪伪装识别成功。

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
- 后端断开时仍可运行非 LLM 基础流程；LLM 相关功能必须显示或记录真实失败，并按规则 / 模板降级，不得用 mock 假装模型可用。
- 若演示目标包含 AI 对话或 Prompt 效果，必须完成真实 API Key 测试；无真实 Key 时该部分验收标记为 Partial / Blocked。
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
- 明确哪些功能是真实实现，哪些是规则 / 模板降级或占位；Mock 只能作为开发工具说明，不作为参赛演示里的“真实 AI”展示。
- 演示脚本应包含真实 API 配置检查、失败日志查看路径和无 Key / 后端失败时的可见降级说明。

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
- 生产 / 演示配置默认关闭自动 mock fallback；如提供开发 mock 开关，必须与成品配置隔离并在说明中标记。
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
