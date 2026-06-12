# DEV_LOG.md

## 2026-06-12 T1103B 未入伍 NPC 避战模式

- `CombatSystem` 接入未入伍 NPC 避战移动：工作模式中敌人进入范围会切到 `avoid_combat`，睡觉中的未入伍 NPC 只在被敌人攻击时进入避战。
- 避战 NPC 会选择驿站内安全点并通过 `NPCSystem.move_npc_to_world_position(...)` 移动；避战不设置战斗 `combat_mode`，不攻击敌人，也不使用逃离驿站出口。
- 敌军清空后，避战 NPC 回到 `work` 且不请求计划重评估；避战中应征成功时，若仍有敌军则进入 `combat`，无敌军则回到 `work`。
- `MemorySystem` 新增 `avoidance_started` / `avoidance_ended` 事件类型、必填 payload 和 summary；NPC 行动状态摘要支持前往避战点。
- GM 面板新增“模拟避战”按钮和 `avoid_npc <npc_id>` 命令，敌人快照包含 `active_avoidances` 与最近避战结果。
- 新增 `tools/verify_avoid_combat_mode.gd`，覆盖未入伍接敌避战、睡觉例外、避战安全点、清敌退出不重评估、避战中应征分流、事件写入和 GM 入口。
- 验证通过：`godot --headless --path . --script tools/verify_avoid_combat_mode.gd`、`godot --headless --path . --script tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务仍不实现我方反击、敌人受击 / 倒下、逃离驿站、战时公开对话心理结果或低血量自身心理判定。

## 2026-06-12 T1103A 统一 NPC 行为模式状态机

- `NPCSystem` 新增 `states.behavior_mode` 权威运行时字段，支持工作 / 集结 / 战斗 / 避战 / 昏迷 / 逃离模式，并保留 `combat_mode` 作为旧集结与坐骑视觉兼容字段。
- `CombatSystem` 接入行为模式切换规则：警铃集结进入 `rally`，接敌进入 `combat`，集合点等待 1 游戏小时未接敌回到 `work` 且不重评估计划，敌军清空后战斗 NPC 回到 `work` 并请求重评估计划，复苏 NPC 按场上敌军和入伍状态分流。
- 睡觉 NPC 不因范围接敌自动进入战斗或避战；被敌人直接攻击时，已入伍者进入战斗，未入伍者进入避战。
- 模式切换会中断普通行动、移动、可取消 LLM 和当前对话；`DialogSystem.force_end_dialogue_for_npc(...)` 用于强制关闭对话并取消未完成回复。
- `MemorySystem` 新增 `npc_mode_changed` 结构化事件摘要；NPC 面板显示当前行为模式，GM 面板新增“行为模式快照”“推进集结等待”按钮和 `behavior_modes` / `advance_rally_wait [game_seconds]` 命令。
- 新增 `tools/verify_behavior_mode_state_machine.gd`，覆盖警铃集结、集结超时、接敌入战、清敌退出、睡觉接敌例外、被攻击入战、复苏分流和 GM 入口。
- 验证通过：`godot --headless --path . --script res://tools/verify_behavior_mode_state_machine.gd`、`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务只实现行为模式状态机和切换边界；未入伍 NPC 避战移动策略、战时公开对话心理结果、低血量自身心理判定、我方反击和完整战斗结算仍在后续任务。

## 2026-06-12 行为模式与战斗心理设计同步

- 设计源 `game_design.md` 新增工作 / 集结 / 战斗 / 避战四种行为模式定义，明确模式触发、退出和互斥边界。
- 取消旧式“战斗触发时全员心理判定”，改为集结 / 战斗 / 避战模式下的战时公开对话结构化意向，以及战斗中 HP 低于 30% 的自身心理判定。
- 明确集结模式到达集合点后等待 1 游戏小时仍未接敌则回到工作模式且不重评估计划；战斗模式在敌军清空后回到工作模式并重评估计划；未入伍避战模式只在敌军清空后回到工作模式。
- 明确战时公开对话强制同地点公开，Prompt 继承 T0603 上下文并额外注入 `battlefield_context`；已入伍 NPC 输出 `wartime_reaction`，未入伍避战 NPC 仍沿用应征结果逻辑。
- `TASKS.md` 新增 T1103A / T1103B，并重写 T1201 / T1202 等后续任务，避免后续实现重新走旧的全员战斗前判定方案。
- 本次只更新设计和任务文档，未修改运行时代码。

## 2026-06-12 T1103 警铃与集结

- HUD 警铃按钮接入 `CombatSystem.trigger_combat_alarm("hud")`；GM 面板新增“警铃集结”按钮和 `alarm` / `rally` 命令。
- `CombatSystem` 新增警铃集结权威流程：所有 NPC 写入 `combat_alarm_rang` 私有事件，入伍且有主武器、当前可行动的 NPC 会被排入城门外防线；近战 / 骑兵在前排，弓弩 / 骑射在后排。
- 集结会通过 `ActionSystem.interrupt_npc_action(..., "combat_alarm")` 打断普通日常行动并释放工位，再调用 `NPCSystem.move_npc_to_world_position(...)` 前往阵位；`debug_get_combat_snapshot()` 现在包含 `active_rallies` 和 `last_alarm_result`。
- `NPC.gd` 新增运行时低模骑乘和面向敌人方向标记；只有 `combat_mode == "rally"` 或 `"combat"` 且 `combat_mounted == true` 时显示坐骑，日常工作模式不骑马。
- 若集结途中遭遇一定范围内敌人，NPC 会停止移动并进入 `combat_ready` 占位状态，写入 `combat_rally_encountered_enemy`；这仍不实现我方攻击、敌人受击或完整战斗开始 / 结束流程。
- `MemorySystem` 新增 `combat_alarm_rang`、`combat_rally_started`、`combat_rally_encountered_enemy` 事件摘要和行动状态翻译。
- 新增 `tools/verify_combat_alarm_rally.gd`，覆盖 HUD 警铃、GM 命令、未入伍过滤、近战前排 / 远程后排、骑乘表现和集结途中遭遇敌人切换。
- 验证通过：`godot --headless --path . --script res://tools/verify_combat_alarm_rally.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_equipment_system.gd`。

## 2026-06-12 T1102 敌人目标优先级

- `CombatSystem` 接入敌人目标选择、逻辑时间推进、移动和敌方单向攻击；附近可行动 NPC 会优先成为目标，否则按城门/围墙、仓库、主厅选择仍有 HP 的建筑。
- 敌人攻击 NPC 时复用 `NPCSystem.apply_damage_to_npc(...)`，NPC HP 清零仍进入昏迷；敌人攻击建筑时调用 `BuildingSystem.apply_damage_to_building(...)`，扣除建筑 HP、刷新建筑标签并写入 `building_damaged` 结构化事件。
- `GameState` 新增 `game_over`、`game_result`、`failure_reason` 和 `set_game_over(...)`，主厅 HP 清零时写入 `failure/main_hall_destroyed` 失败占位状态。
- `NPCSystem` 新增只读 `get_npc_world_position(...)`，供 CombatSystem 判断附近可行动 NPC；`CombatSystem.debug_get_combat_snapshot()` 现在包含敌人目标、当前行动和最近 AI 推进结果。
- GM 面板“战斗 / 敌人”分组新增“推进敌人AI”按钮和 `step_enemies [game_seconds]` 命令。
- 新增 `tools/verify_enemy_target_priority.gd`，并扩展 `tools/verify_gm_panel.gd` 覆盖新 GM 入口。
- 验证通过：`godot --headless --path . --script res://tools/verify_enemy_target_priority.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务只实现敌方单向攻击和失败状态占位；我方自动攻击、敌人受击 / 倒下、完整战斗开始 / 结束流程和正式胜负界面仍留给 T1104、T1106 和 M13。

## 2026-06-12 T1101 敌人配置与敌人生成

- `data/enemy_waves.json` 扩展为 5 波 Demo 敌人配置，后续波次在人数、HP、攻击、防御和兵种组合上逐步增强。
- `CombatSystem` 接入波次配置读取、查询、生成、清空和快照调试接口，可在 `Main/WorldRoot/Station/Enemies` 下生成正门外低模敌人实体；敌人保留 HP、武器类型、单位类型、攻击、防御、移动速度和目标偏好。
- `Main.tscn` 扩大正门外地面与正门道路，`CameraRig` 扩展 Z 轴视野，保证敌人生成在正门外森林方向且可被观察。
- GM 面板新增“战斗 / 敌人”分组，支持生成第一波、生成指定波次、查看敌人快照、清空敌人，并补充 `spawn_wave` / `enemy_wave` / `enemies` / `clear_enemies` 命令。
- 新增 `tools/verify_enemy_wave_generation.gd`，并扩展 `tools/verify_gm_panel.gd` 覆盖 T1101 数据、生成位置、GM 按钮、命令和清理流程。
- 验证通过：`godot --headless --path . --script res://tools/verify_enemy_wave_generation.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- 边界：本任务不实现敌人移动、目标 AI、攻击、伤害、战斗开始/结束或事件写入，这些留给 T1102 / T1104 / T1106。

## 2026-06-12 T1006 发送后才打断对话与对话窗攻击闭环

- NPC 面板“对话”改为只打开 DialogPanel 和查看历史，不再立刻打断行动、取消 LLM 或请求结束后的计划重评估。
- 玩家在对话窗实际发送消息或点击攻击后，才取消目标 NPC 的可取消 LLM 请求并打断工作 / 吃饭 / 睡觉等普通行动；普通消息未等 NPC 回复就结束会取消本轮异步 LLM，不写 `dialogue_turn`，不触发对话重评估。
- 对话窗等待 NPC 回复期间输入框仍可编辑，但发送和攻击按钮禁用，避免同一轮回复前重复提交。
- 攻击入口从 NPC 面板移到对话窗：点击后先扣 HP 并写入“守备官攻击了你以示惩戒”的 `damage_taken`，再请求 NPC 作出攻击语境回复；关闭等待中的攻击回复不会撤销攻击，结束时仍触发一次计划重评估。
- `DialogPanel` 将“提出应征”改为右上角 toggle，攻击按钮放到发送旁；`NPCPanel` 保留给钱和装备入口，不再直接扣血。
- 验证通过：`godot --headless --path . --quit-after 1`、`godot --headless --path . --script res://tools/verify_dialogue_sleep_summary_boundaries.gd`、`godot --headless --path . --script res://tools/verify_dialogue_ui.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_npc_proactive_talk.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_reevaluation.gd`、`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_mock_endpoint.py`；并通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，日志无报错。

## 2026-06-11 T1005 对话打断、LLM 状态提示与首次睡眠总结优先级

- 玩家对话现在会打断工作 / 吃饭 / 睡觉等普通日常行动，并取消目标 NPC 的可取消 LLM 活动状态；取消后的计划 / 对话结果不会继续应用。
- 首次睡眠总结改为每天第一次睡觉且持续睡眠满 1 个游戏小时后触发；总结发起到应用完成期间通过 NPCSystem 深度睡眠锁阻止对话、消息、行动中断和行动改派。
- 总结期间发布给已入伍 NPC 的指令仍保存并写入事件，但计划重评估延后到醒来后执行。
- 对话、每日计划、计划修订和首次睡眠总结都会申请并释放 TimeSystem 慢速；`/npc/daily_reflection` 保持接口名不变，玩法语义改为首次睡眠总结。
- NPC 头顶新增 LLM 状态标记：普通 LLM 等待显示 `...`，首次睡眠总结显示禁止标记；NPC 面板名字旁显示“正在思考 / 正在计划下一步行动 / 正在熟睡”。
- GM 面板新增 `llm_state <npc_id>` 只读入口，查看 NPC LLM 活动、首次睡眠总结锁和延后重评估状态。
- 新增 `tools/verify_dialogue_sleep_summary_boundaries.gd`，更新 `tools/verify_daily_reflection_system.gd`。
- 验证通过：`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`godot --headless --path . --script res://tools/verify_dialogue_sleep_summary_boundaries.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`、`godot --headless --path . --script res://tools/verify_npc_order.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-11 T1004 睡前总结与短期记忆清空

- 新增 `DailyReflectionSystem` 并挂载到 `Main/Systems/DailyReflectionSystem`，监听 `sleep_started`；每名 NPC 每天首次睡觉生成睡前总结，重复睡眠不自动重复写入，GM 可 force 调试。
- `LLMBridge` 新增 `/npc/daily_reflection` 请求和 payload 构造，注入共享 NPC 上下文、当前指令、当天事件 / 见闻摘要和已有日记；当时睡前总结默认不申请 TimeSystem 慢速，已在 T1005 修正为首次睡眠总结必须慢速。
- Flask 后端新增 `POST /npc/daily_reflection`，使用 `DailyReflectionRequest` / `DailyReflectionResponse` 校验输入输出；Mock provider 覆盖 `daily_reflection`。
- `NPCSystem` 新增长期记忆读取和睡前总结应用接口，写入 `diary`，并把知识图谱更新合并到 `knowledge_graph.patches` / `knowledge_graph.by_subject` 占位结构。
- `MemorySystem` 新增 `clear_npc_short_term_memory(...)`，只清空指定 NPC 当天事件库 / 见闻库索引，不删除全局事件档案。
- `NPCPanel` 新增日记滚动区；`GMPanel` 新增睡前总结、长期记忆和最近总结按钮，以及 `reflect_npc`、`long_memory`、`reflection_result` 命令。
- 新增 `tools/verify_daily_reflection_system.gd` 与 `tools/verify_daily_reflection_endpoint.py`，并扩展 `tools/verify_gm_panel.gd`、`tools/verify_mock_model_adapter.py`。
- 验证通过：`godot --headless --path . --script res://tools/verify_daily_reflection_system.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_daily_plan_llm.gd`、`python tools/verify_backend_schemas.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_daily_reflection_endpoint.py`、`python tools/verify_plan_day_endpoint.py`、`godot --headless --path . --quit-after 1`。

## 2026-06-11 T1003 LLM / Mock 版制定计划接口

- Flask 后端新增 `POST /npc/plan_day`，用 `DailyPlanRequest` / `DailyPlanResponse` 校验每日计划 Mock 输入输出。
- Mock `plan_day` 会按 NPC 熟练度和行动白名单选择真实可执行工作行动，并返回睡觉、吃饭、工作、等待组成的 24 小时计划。
- `LLMBridge` 新增每日计划 payload 与 `/npc/plan_day` 请求，注入最新 `current_order`、短期记忆、长期记忆、地点 / 广场上下文、资源快照、建筑状态、行动白名单和计划规则；请求期间申请 TimeSystem 慢速并在成功 / 失败 / 超时后释放。
- `DailyPlanSystem` 新增 `generate_daily_plan_for_npc(...)`：成功时应用 `mock_plan_day` 并写入 `plan_created`，失败、输出不合法、非 24 阶段或工作阶段不足时应用 `rule_plan_fallback`。
- GM 面板 `plan_generate` 改为 LLM / Mock 优先并自动规则降级，新增 `plan_generate_rule` 纯规则入口，`plan_request` 可查看最近每日计划生成结果。
- 新增 `tools/verify_daily_plan_llm.gd` 与 `tools/verify_plan_day_endpoint.py`。
- 验证通过：`verify_backend_schemas.py`、`verify_mock_model_adapter.py`、`verify_plan_day_endpoint.py`、`verify_plan_revision_endpoint.py`、`verify_daily_plan_llm.gd`、临时以 `LLM_PROVIDER=mock` 和 `T1003_BACKEND_URL=http://127.0.0.1:5056` 启动 Flask 后再次运行 `verify_daily_plan_llm.gd`、`verify_daily_plan_reevaluation.gd`、`verify_daily_plan_system.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-11 T1002 行动异常与计划重评估

- `DailyPlanSystem` 接入统一计划重评估：行动失败、目标建筑不可用、资源不足、工位占用、对话打断、守备官攻击、主动交涉结束 / 超时、战斗警报占位和新指令会触发重评估。
- `LLMBridge` 新增计划修订 payload 与 `/npc/revise_plan` 请求，注入最新 `current_order`、当前计划、失败计划项、失败类型和行动白名单；请求期间申请 TimeSystem 慢速并在成功 / 失败 / 超时后释放。
- Flask 后端新增 `/npc/revise_plan`，用 `PlanRevisionRequest` / `PlanRevisionResponse` 校验 Mock 修订输出。
- 重评估成功写入 `plan_revised` 并执行当前小时修订项；后端不可用或输出失败时写入 `rule_revision_fallback` 并执行规则降级项。
- GM 面板新增“立即重评估”和 `plan_revise <npc_id> [reason]`，最近请求面板同时显示 NPCSystem 请求和 DailyPlanSystem 结果。
- 新增 `tools/verify_daily_plan_reevaluation.gd` 与 `tools/verify_plan_revision_endpoint.py`。
- 验证通过：`verify_daily_plan_reevaluation.gd`、临时以 `LLM_PROVIDER=mock` 和 `T1002_BACKEND_URL=http://127.0.0.1:5055` 启动 Flask 后再次运行 `verify_daily_plan_reevaluation.gd`、`verify_plan_revision_endpoint.py`、`verify_daily_plan_system.gd`、`verify_npc_order.gd`、`verify_gm_panel.gd`、`verify_npc_proactive_talk.gd`、`verify_backend_schemas.py`、`verify_mock_model_adapter.py`、`godot --headless --path . --quit-after 1`。

## 2026-06-10 T1001 规则版每日计划

- 新增 `DailyPlanSystem` 并挂载到 `Main/Systems/DailyPlanSystem`，可生成规则版 24 小时计划，默认按 NPC 熟练度选择工作行动，计划中工作阶段不少于 6 个。
- `NPCSystem` 新增计划存取与系统中断移动接口；`ActionSystem` 新增当前行动查询与 `interrupt_npc_action(...)`，计划切换时可安全释放工位、训练、治疗或移动状态。
- `MemorySystem` 接入 `plan_created` payload 校验和确定性 summary；计划生成会写入 NPC 私有事件库。
- GM 面板新增生成计划、执行当前计划、查看计划按钮，以及 `plan_generate` / `plan_execute` / `plan` 命令。
- 新增 `tools/verify_daily_plan_system.gd`，覆盖 24 小时计划、至少 6 个工作阶段、计划事件入库、小时打点执行、同小时重复执行和计划切换打断。
- 验证通过：`verify_daily_plan_system.gd`、`verify_gm_panel.gd`、`verify_action_system_basic.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `Main.tscn` 后游戏日志为空。
- 备注：`tools/verify_time_system.gd` 当前仍有旧断言期望“暂停后挂起工作在几帧内产出资源”，与现行 T0801 之后的 1 小时持续工作语义不一致，本次未改该旧验证脚本。

## 2026-06-10 T0016 建筑面板工位显示优化

- `BuildingPanel` 移除独立“当前工作位 x/x”汇总行，场景默认占位改为 `工位：--`。
- 工位、床位和训练位改为按类型分组显示 `空闲数/总数：占用者`；空闲数和总数来自真实工位数组，占用者通过 `NPCSystem` 显示 NPC 名字。
- 诊所、训练场等多类型建筑会分别显示医生 / 病床、教官 / 受训者等位置；无占用者显示“空闲”，多个占用者用顿号分隔。
- 新增 `tools/verify_building_panel_workstations.gd`，覆盖新显示格式、占用者名字、多类型分组和无工位建筑。
- 验证通过：`verify_building_panel_workstations.gd`、`verify_building_repair_upgrade.gd`、`verify_work_output_framework.gd`。

## 2026-06-10 T0015 NPC 成长 UI 与 GM 入伍入口修正

- NPC 面板移除独立“成长”说明文本，改为在 HP 行右侧显示 `经验：当前 / 阈值`。
- 属性行改为内联显示力量和智力；只有存在未分配技能点且对应属性未达上限时，才在属性数值旁显示 `+1` 按钮，最后一个点用完后按钮自动消失。
- GM 面板 NPC 分组新增“设为入伍”按钮和 `recruit_npc <npc_id>` 命令，调用 `NPCSystem.set_npc_recruited(...)`，让选中 NPC 进入可发布指令 / 可分配装备的入伍状态。
- 更新 `tools/verify_skill_progression.gd`、`tools/verify_npc_panel_state.gd` 和 `tools/verify_gm_panel.gd`，覆盖新 UI 和 GM 入伍入口。
- 验证通过：`verify_npc_panel_state.gd`、`verify_skill_progression.gd`、`verify_gm_panel.gd`、`verify_npc_order.gd`、`verify_npc_panel_interactions.gd`、`verify_dialogue_ui.gd`、`verify_equipment_system.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `Main.tscn` 后游戏日志为空。

## 2026-06-10 T0904 职业熟练度与经验升级

- `NPCSystem` 新增运行时 `progression` 成长结构，`increase_npc_skill(...)` 成为统一熟练度增长入口；工作、诊所和训练的熟练度提升会同步增加技能经验与总经验，每 5 点总经验产生 1 个未分配技能点。
- 按当前设计改为玩家分配技能点：新增 `assign_npc_attribute_point(...)` / `debug_assign_attribute_point(...)`，只能把未分配技能点投入力量或智力，AI 只可在后续对话/计划中建议倾向，不能自行消耗技能点或改写属性。
- `NPCPanel` 接入成长展示与玩家分配技能点入口；该入口后续已按 T0015 调整为 HP 行右侧经验与属性数值旁条件显示 `+1`。`GMPanel` 新增技能点分配入口和 `assign_attribute <npc_id> <strength|intelligence>` 命令。
- `MemorySystem` 新增 `attribute_improved` 事件，并让 `skill_improved` payload 记录经验与技能点变化；新增 `tools/verify_skill_progression.gd` 覆盖工作、训练、诊所成长、技能点生成、玩家属性分配、NPC 面板和 GM 命令。
- 同步更新 `game_design.md`、`AI_NPC_SYSTEM.md`、`DATA_SCHEMA.md`、`UI_UX.md`、`GM_PANEL.md`、`MEMORY_AND_INFO_SPACE.md`、`ECONOMY_AND_BUILDINGS.md`、`GODOT_ARCHITECTURE.md`、`MODULE_INDEX.md`、`CURRENT_STATE.md` 和 `TASKS.md`。
- 验证通过：`godot --headless --path . --script res://tools/verify_skill_progression.gd`。

## 2026-06-10 T0014 GM 行动入口、NPC 记忆滚动区与弹窗互斥

- GM 面板行动区去掉并列的工作、吃饭、睡觉、当教官和当受训者按钮；普通行动统一通过行动下拉和“指定行动”触发，协助修复、协助升级、协助治疗等带目标参数入口保留。
- NPC 面板事件库和见闻库改为固定高度滚动区，完整显示当前 NPC 的事件 / 见闻内容，刷新后自动滚到底部，用户仍可手动上滑查看旧记录。
- NPC 面板点击“对话”或“指令”不再自动关闭 NPC 面板；`DialogPanel` 与 `OrderPanel` 互斥，打开其中一个会关闭另一个，避免中央弹窗重叠。
- 更新 `tools/verify_gm_panel.gd`、`tools/verify_npc_panel_state.gd`、`tools/verify_dialogue_ui.gd` 和 `tools/verify_npc_order.gd` 的断言，覆盖新 UI 行为。
- 验证通过：`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`verify_npc_panel_interactions.gd`、`verify_npc_order.gd`、临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py` 后运行 `verify_dialogue_ui.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-10 T0903 训练场与武器熟练度提升

- `data/building_defs.json` 将训练场拆分为 `training_instructor` 教官工位和 `training_student` 受训位，训练场升级当前增加受训位。
- `data/action_defs.json` 新增 `work_training_instructor` 和 `receive_weapon_training`；无武器且无坐骑的 NPC 不能训练或执教，受训者需要训练场内已有有效教官。
- `ActionSystem.gd` 实现教官独自练习、带受训者训练、受训者按当前主武器 / 坐骑提升武器熟练度或骑术、教官教学时提升“教练”、训练按单位时间消耗疲劳和饱食，以及教官/受训者项目熟练度差影响训练速度。
- `MemorySystem.gd` 补充训练相关 `skill_improved` summary；GM 面板可通过行动下拉指派训练行动，并保留 `train_instructor` / `train_student` 命令。
- 新增 `tools/verify_training_system.gd`，并扩展 `tools/verify_gm_panel.gd` 覆盖训练场 GM 入口和普通行动下拉；`tools/verify_action_system_basic.gd` 同步当前酒窖产出缩放断言。
- 验证通过：`verify_training_system.gd`、`verify_gm_panel.gd`、`verify_action_system_basic.gd`、`verify_work_output_framework.gd`、`verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_clinic_treatment.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0902 兵种判定

- `EquipmentSystem` 新增 `get_unit_type_snapshot(npc_id)`，返回兵种 id、中文标签、主武器类型、武器 class、是否有坐骑、坐骑 id 和完整装备槽快照，供 GM 面板和后续战斗系统只读使用。
- GM `unit_type <npc_id>` 改为输出完整兵种快照，方便验证“马匹整备库存”与“NPC 已装备坐骑槽”不是同一件事。
- 新增 `tools/verify_unit_type_classification.gd`，覆盖无武器、剑盾、长杆、弓、弩、近战武器 + 坐骑、远程武器 + 坐骑，以及“只有坐骑/只有库存不算骑兵”的边界。
- 验证通过：`godot --headless --path . --script res://tools/verify_unit_type_classification.gd`。

## 2026-06-09 T0013 移除短剑旧占位装备

- 删除 `data/weapon_defs.json` 中的旧占位主武器定义；正式主武器只保留剑盾、长杆、弓和弩。
- 移除 `NPCSystem.gd` 中旧占位武器兼容入口，正式装备统一通过 `EquipmentSystem` 选择具体主武器。
- `tools/verify_equipment_system.gd`、`tools/verify_hud_resources.gd` 和 `tools/verify_unit_type_classification.gd` 增加回归断言，确认旧占位武器不会再进入装备系统、HUD 详情或兵种判定。
- 验证通过：`verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_hud_resources.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0012 HUD 详情面板与 GM 面板定位修正

- HUD 主资源栏去掉装备/器械详情中已有的聚合库存：武器、盔甲、马匹整备和工程器械，保留第纳尔、粮食、餐食、酒、木材、石料和铁。
- “装备”和“器械”详情面板改为贴近各自按钮左下方打开，并根据可用屏幕范围夹住位置。
- GM 面板改为跟随 `GM` 按钮附近打开；拖动按钮时已打开面板同步重定位并保持在可用屏幕范围内，面板高度收紧以减少遮挡 HUD。
- 更新 `tools/verify_hud_resources.gd` 和 `tools/verify_gm_panel.gd`，覆盖 HUD 主栏去重、详情面板定位、GM 面板跟随按钮和边界钳制。
- 验证通过：`verify_hud_resources.gd`、`verify_gm_panel.gd`、`verify_equipment_system.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

## 2026-06-09 T0011 HUD 完整资源库存与装备器械详情

- `scripts/ui/HUD.gd` 改为按 `ResourceSystem.get_resource_ids()` 动态生成资源栏，直接显示第纳尔、粮食、餐食、酒、武器、盔甲、工程器械、马匹整备、木材、石料和铁。
- HUD 资源栏新增“装备”“器械”按钮；装备详情显示武器 / 盔甲 / 马匹整备库存、可分配装备定义和已分配数量，器械详情显示工程器械库存与当前未部署边界。
- `ResourceSystem` 新增 `get_resource_definition(...)`，`EquipmentSystem.get_armor_ids(...)` 修正为稳定返回 `Array[String]`，避免详情读取盔甲槽位时触发类型错误。
- 新增 `tools/verify_hud_resources.gd` 覆盖全量资源显示、派生库存刷新、装备详情和器械详情入口。
- 验证通过：`verify_hud_resources.gd`、`verify_equipment_system.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

## 2026-06-09 T0901 库存与装备系统

- 新增 `res://scripts/systems/EquipmentSystem.gd` 并挂载到 `Main/Systems/EquipmentSystem`，作为装备库存、装备槽和兵种判定的权威入口。
- `data/weapon_defs.json` 补齐剑盾、长杆、弓、弩等主武器类型；新增 `data/armor_defs.json` 和 `data/mount_defs.json`，覆盖头盔、胸甲、腕甲、腿甲和坐骑槽。
- 装备主武器消耗 `weapons`，装备盔甲消耗 `armor`，装备坐骑消耗 `horse_readiness`；换装会返还旧装备对应库存。只有已入伍 NPC 可被守备官直接分配装备。
- NPC 面板新增主武器选择，装备后显示当前装备和战斗定位；GM 面板新增装备武器、装备盔甲、装备坐骑和兵种查看入口及命令。
- 装备事件复用 `MemorySystem.record_player_interaction(...)` 写入 `equipment_given` / `equipment_changed`，并按 `private` / `local_public` 传播给同地点见闻。
- 新增 `tools/verify_equipment_system.gd`，并更新 `verify_npc_panel_interactions.gd`、`verify_gm_panel.gd`。
- 验证通过：`verify_equipment_system.gd`、`verify_npc_panel_interactions.gd`、`verify_gm_panel.gd`、`verify_blacksmith_metal_gear.gd`、`verify_workshop_ranged_devices.gd`、`verify_stable_horse_care.gd`、`verify_npc_panel_state.gd`、`godot --headless --path . --quit-after 1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

## 2026-06-09 T0010 忽略本机 VSCode Godot 路径配置

- `.gitignore` 新增 `.vscode/settings.json`，避免两台电脑不同 Godot 路径在 Git 同步时反复产生冲突或脏改动。
- 执行 `git rm --cached .vscode/settings.json`，让 Git 停止跟踪该文件，但保留本机文件；已确认 `.vscode/settings.json` 仍存在。
- 验证通过：`godot --headless --path . --quit-after 1`、`tools/check_godot_mcp.ps1`。

## 2026-06-09 T0009 Godot MCP 运行桥接类缓存启动失败修复

- 排查 Git 同步后项目跑不起来的问题，确认 `main` 已与 `origin/main` 对齐，仅 `.vscode/settings.json` 有本机 Godot 路径改动；A 电脑改动未显示为丢失或冲突。
- 直接启动 `godot --headless --path . --quit-after 1` 时，`MCPGameBridge` Autoload 因找不到 `MCPRuntimeStateSampler` 类型解析失败；文件实际存在，问题来自 Godot 全局类缓存未登记该 `class_name`。
- `addons/godot_mcp/game_bridge/mcp_game_bridge.gd` 改为 `preload("mcp_runtime_state_sampler.gd")` 并通过预加载脚本创建 sampler，不再依赖 `.godot/global_script_class_cache.cfg`。
- `_handle_watch_start(...)` 的 `start_result` 显式标注为 `Dictionary`，避免动态 sampler 实例导致类型推断失败。
- 验证通过：`godot --headless --path . --quit-after 1`、`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`tools/check_godot_mcp.ps1`；通过 Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志为空。

## 2026-06-09 T0008 NPC 面板内容增多时向上溢出修复

- 修复 NPC 面板内容变多时向上下两个方向扩展，导致顶部越出屏幕的问题。
- `Main.tscn` 中 `Main/UI/NPCPanel` 和内部 `PanelContainer` 的垂直增长方向改为向下，保留右上角顶边作为固定基准。
- `tools/verify_npc_panel_state.gd` 增加长事件库/见闻库文本回归，确认内容膨胀时 `PanelContainer` 不会向上越过 NPC 面板顶边。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --quit-after 1`。
- Godot MCP 自检通过：`addon_status` connected，当前打开场景为 `res://scenes/main/Main.tscn`。

## 2026-06-09 T0808 小诊所治疗行动完善

- `data/building_defs.json` 中小诊所拆分为 `clinic_doctor` 医生工位和 `patient_bed` 病床，诊所升级当前增加病床。
- `data/action_defs.json` 新增 `work_clinic_doctor` 和 `receive_clinic_treatment`，让医生坐诊/研读医术和病人占床成为两个独立行动选项。
- `ActionSystem` 新增诊所治疗逻辑：医生在岗且受伤未昏迷 NPC 占床时才推进治疗；治疗按逻辑时间消耗第纳尔并恢复 HP，医术、智力和诊所等级提高恢复速度；病人回满 HP 后释放病床。
- 医生无病人时会以慢速研读医学著作并通过 `skill_improved` 事件提升医术，治疗中也会少量提升医术；T0808 阶段只处理医术最小增长，现已在 T0904 接入统一经验、技能点和玩家属性分配规则。
- `NPCSystem` 新增 `restore_npc_hp(...)` 和 `increase_npc_skill(...)`，供诊所治疗与医术最小成长调用。
- 新增 `tools/verify_clinic_treatment.gd`，验证诊所工位/病床、研读医术、病床治疗、金钱消耗、医术/智力/诊所等级效率、治疗完成事件和病床释放。
- 验证通过：`verify_clinic_treatment.gd`、`verify_npc_unconscious_healing.gd`、`verify_work_output_framework.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0807 酒窖酿酒与出售边界

- `data/action_defs.json` 的 `work_tavern` 明确使用 `stat="intelligence"`，消耗 1 份粮食，产出 `wine` 酒派生库存。
- 酒窖工作沿用 T0801 统一效率公式：酿酒熟练度、智力和酒窖建筑等级会缩短单位酿造周期；`output_scaling` 会按酿酒、智力和酒窖等级提高实际酒库存产出。
- 将厨子布鲁诺的酿酒熟练度从 38 调整为 58，以符合 `game_design.md` 中厨子具备酿酒优势的定位。
- 新增 `tools/verify_tavern_wine_trade.gd`，验证酒窖配置、酿酒/智力/建筑等级效率、粮食消耗、酒库存产出、完成事件 payload、缺粮失败，以及酿酒完成不会在商人交易系统实现前自动增加第纳尔。
- 当前不实现饮酒，也不实现商队出售酒换钱；出售部分已补到 T1507 商人交易系统，要求接住 T0807 的 `wine` 库存。
- 验证通过：`verify_tavern_wine_trade.gd`、`verify_action_system_basic.gd`、`verify_work_output_framework.gd`、`verify_dining_hall_meals.gd`、`verify_garden_grain_output.gd`、`verify_workshop_ranged_devices.gd`、`verify_stable_horse_care.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0806 马厩马匹喂养与恢复

- `data/action_defs.json` 的 `work_stable` 明确使用 `stat="strength"`，消耗 1 份粮食，产出 `horse_readiness` 马匹整备派生库存。
- 马厩工作沿用 T0801 统一效率公式：养马熟练度、力量和马厩建筑等级会缩短单位照料周期；`output_scaling` 会按养马、力量和马厩等级提高实际马匹整备产出。
- 新增 `tools/verify_stable_horse_care.gd`，验证马厩配置、养马/力量/建筑等级效率、粮食消耗、马匹整备库存产出、完成事件 payload 和缺粮失败。
- 当前不实现坐骑装备槽、NPC 胯下骑乘表现、战斗移动速度加成、进入战斗时骑兵策略切换或卸下回马厩；这些已补到 T0901/T0902/T1103/T1105 的后续安排。
- 验证通过：`verify_stable_horse_care.gd`。

## 2026-06-09 T0805 工械坊弓弩与防御器械

- `data/action_defs.json` 的 `work_workshop` 明确使用 `stat="intelligence"`，消耗 2 份木材，产出 1 份 `weapons` 和 1 份 `defense_devices` 派生库存。
- 工械坊工作沿用 T0801 统一效率公式：工程熟练度、智力和工械坊建筑等级会缩短单位制作周期；本次不实现具体弓/弩装备条目、装备外观、弩床/拒马部署、自动攻击或阻挡结算。
- 新增 `tools/verify_workshop_ranged_devices.gd`，验证工械坊配置、工程/智力/建筑等级效率、木材消耗、武器/工程器械库存产出、完成事件 payload 和缺木失败。
- 更新 T0901 后续安排：正式库存与装备系统需要接住 T0805 进入 `weapons` 的木质远程武器占位，并把主武器区分为剑盾、长杆、弓、弩等类型；T1508 继续负责消耗 `defense_devices` 并部署工程器械。
- 验证通过：`verify_workshop_ranged_devices.gd`、`verify_action_system_basic.gd`、`verify_work_output_framework.gd`、`verify_blacksmith_metal_gear.gd`、`verify_garden_grain_output.gd`、`verify_dining_hall_meals.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-09 T0804 铁匠铺金属武器和盔甲

- `data/action_defs.json` 的 `work_blacksmith` 明确使用 `stat="strength"`，消耗 2 份铁，产出 1 份 `weapons` 和 1 份 `armor` 派生库存。
- 铁匠铺工作沿用 T0801 统一效率公式：打铁熟练度、力量和铁匠铺建筑等级会缩短单位制作周期；本次不实现装备部位、品质、耐久或外观。
- 新增 `tools/verify_blacksmith_metal_gear.gd`，验证铁匠铺配置、打铁/力量/建筑等级效率、铁消耗、武器/盔甲库存产出、完成事件 payload 和缺铁失败。
- 在 T0901 任务中补充后续安排：正式库存与装备系统需要接住 T0804 的 `weapons` / `armor` 派生库存，再映射到主武器、头盔、胸甲、腕甲、腿甲等可装备数据。
- 验证通过：`verify_blacksmith_metal_gear.gd`、`verify_work_output_framework.gd`、`verify_dining_hall_meals.gd`、`verify_garden_grain_output.gd`。

## 2026-06-09 T0803 菜园粮食产出

- `data/action_defs.json` 的 `work_garden` 增加 `stat="strength"` 与 `output_scaling`，菜园基础产出 2 份粮食，并由耕种熟练度、力量和菜园等级提高实际产出。
- `ActionSystem` 新增配置化工作产出缩放计算；工作完成时按缩放后的 `output_resources` 增加资源，并把实际产出写入 `work_completed` 事件 payload。未配置缩放的工作保持固定产出。
- 新增 `tools/verify_garden_grain_output.gd`，验证菜园产粮、耕种影响产出、力量影响产出、菜园等级影响产出，以及完成事件记录缩放后的粮食产出。
- 更新 T0801 工作框架验证，避免继续假设菜园永远固定产出 2 粮食。
- 验证通过：`verify_garden_grain_output.gd`、`verify_work_output_framework.gd`、`verify_dining_hall_meals.gd`。

## 2026-06-09 T0802 食堂粮食加工餐食

- 新增 `tools/verify_dining_hall_meals.gd`，把 T0802 从 T0801 框架中拆出为独立验收：验证 `work_dining_hall` 消耗粮食、产出餐食、使用厨艺，并验证厨艺和食堂等级会缩短加工周期。
- 验证吃饭行动优先消耗餐食；餐食恢复 50 点饱食度，粮食恢复 25 点饱食度。
- 验证食堂工作和吃饭完成事件写入 NPC 事件库，payload 保留资源输入、资源输出、食物资源和饱食恢复量。
- 验证通过：`godot --headless --path . --script res://tools/verify_dining_hall_meals.gd`。

## 2026-06-09 T0007 工作中 NPC 状态刷新抢回面板修复

- 修复工作中 NPC 的 `npc_state_changed` 持续刷新会在玩家切到建筑面板后重新打开 NPC 面板的问题。
- `NPCPanel` 现在只在自身可见且刷新目标仍是当前 NPC 时响应状态刷新；点击建筑隐藏 NPC 面板后，工作、饱食、疲劳等后续状态变化不会再把它弹出。
- `tools/verify_npc_panel_state.gd` 增加回归用例：NPC 面板切到建筑面板后模拟同一 NPC 工作状态刷新，确认右上角保持建筑面板。
- 验证通过：`verify_npc_panel_state.gd`、`verify_work_output_framework.gd`、`verify_gm_panel.gd`。

## 2026-06-09 T0801 职业工作产出框架

- `BuildingSystem` 新增 `claim_workstation(...)` / `release_workstation(...)`，工作位占用和释放由建筑系统权威维护，工位变化继续通过 `building_state_changed` 触发地点内部状态广播。
- `ActionSystem` 的工作行动接入统一效率公式：NPC 对应熟练度、力量/智力属性和建筑等级会缩短单位工作周期；低熟练不会慢于配置基准，高熟练 NPC 会更快完成同一单位产出。
- 工作开始写入实际 `workstation_id`、`building_id`、基础时长、有效时长和效率倍率；完成、资源失败或中断会释放工位并写入结构化事件。
- 新增 `tools/verify_work_output_framework.gd`，覆盖高熟练更快、工位占用/释放、占满拒绝第二名工人、资源不足失败不占工位、地点内部状态广播和事件写入。
- 验证通过：`verify_work_output_framework.gd`、`verify_action_system_basic.gd`、`verify_location_info_nodes.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-05 T0705 NPC 主动找守备官交涉

- `NPCSystem` 新增主动交涉状态与调试入口：可让 NPC 进入 `proactive_talk`，默认持续 1 游戏小时，触发时写入 `private` `proactive_talk_started`，超时或对话结束后请求计划重评估。
- `NPC.gd` 运行时创建 `ProactiveTalkBubble` 问号气泡；点击有主动交涉状态的 NPC 会优先打开对话，不先弹出 NPC 面板。
- `DialogSystem` 新增 `start_proactive_player_dialogue(...)`，复用既有玩家-NPC 对话面板，把 NPC 预先确定的开场问题作为第一条历史显示，并写入 `proactive_talk_message`。
- `MemorySystem` 新增 `proactive_talk_started` / `proactive_talk_message` 事件类型、必需 payload 和确定性 summary；玩家后续回复继续走既有 `dialogue_turn`。
- GM 面板新增主动交涉按钮、`start_proactive` 命令和 `proactive` 状态查询；新增 `tools/verify_npc_proactive_talk.gd`。
- 验证通过：`verify_npc_proactive_talk.gd`、`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`verify_npc_order.gd`、`verify_npc_panel_interactions.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-05 T0704 反馈修正：移除 NPC 面板要求休息按钮

- 移除 `NPCPanel` 的“要求休息/请求治疗”按钮及自动选择治疗者逻辑；休息、治疗这类意图由已入伍 NPC 的自然语言指令承担，既有 GM / ActionSystem 调试入口保留。
- 将给钱数量 `SpinBox` 从交互可见性行移动到“给钱”按钮旁边，让金额输入与给钱动作直接关联。
- 给钱数量输入框新增数字过滤，字母键不会写入金额文本；按 WASD 时会释放金额框焦点，让相机移动继续响应。
- 新增 `UIInputFocusManager` 并挂载到 `Main/UI`，让任意 `LineEdit` / `TextEdit` 在点击输入框外时释放焦点；NPC 给钱金额框、对话输入框和指令 TextEdit 已加入回归验证。
- 更新 `tools/verify_npc_panel_interactions.gd`，改为验证休息/治疗按钮不存在，并继续覆盖给钱、占位装备、攻击、公开见闻、LLM 短期记忆上下文和输入框点击外部失焦。
- 验证通过：`godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd`、`godot --headless --path . --quit-after 1`。

## 2026-06-05 T0704 NPC 面板非对话交互记忆

- `NPCPanel` 新增非对话交互区：可选择私下 / 同地点公开，赠予第纳尔、给予旧占位武器、攻击；给钱数量输入框紧邻“给钱”按钮。
- `NPCSystem` 新增 `give_money_to_npc(...)` 和旧占位武器入口：前者扣除全局第纳尔并增加目标 NPC 随身金钱，后者消耗 1 个全局 `weapons` 并写入装备事件；二者都复用 `MemorySystem.record_player_interaction(...)`，不重做事件系统。旧占位武器入口已在 T0013 后移除。
- 攻击按钮复用 `NPCSystem.apply_damage_to_npc(...)`，保持 HP、昏迷和恢复结算权威边界不变；NPC 面板不提供休息 / 治疗按钮。
- 新增 `tools/verify_npc_panel_interactions.gd`，覆盖给钱事件、同地点见闻、占位装备、攻击扣血、广场公开事件、后续 LLMBridge 短期记忆上下文，并检查休息/治疗按钮不存在。
- 验证通过：`verify_npc_panel_interactions.gd`、`verify_npc_panel_state.gd`、`verify_gm_panel.gd`、`verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。`verify_dialogue_ui.gd` 本次未通过的原因是本机 5000 端口由 deepseek provider 后端响应，非本次 Godot 改动导致。

## 2026-06-04 T0703A 当前指令接入 NPC LLM 上下文与计划重评估

- 后端新增 `CurrentOrderContext`，接入共享 `NPCContext` 和对话顶层 `NPCDialogueRequest`；计划、修订、战斗判定、主动交涉、反思和知识图谱更新等复用共享上下文时自动携带最新指令。
- Godot `LLMBridge` 统一注入最新 `current_order`，保存最近注入快照；GM 新增“最近指令注入”按钮和 `last_order_injection` 命令。
- 新指令重评估请求保存最新指令和 `rule_fallback_deferred` 结果；完整计划应用仍归尚未实现的 T1002，当前不直接修改行动或权威数值。
- 验证通过：后端 Schema / Mock / 对话接口、Python 编译、LLMBridge HTTP、对话 UI、NPC 指令、GM 面板、结构化记忆与项目加载检查；Godot MCP 主场景运行无日志错误。

> 按日期记录开发过程。  
> 每次完成任务后追加，不要覆盖历史。

## 2026-06-04

### T0703 入伍 NPC 自然语言指令入口与存储
完成：
- 已入伍 NPC 的旧“指派（占位）”替换为可用“指令”按钮；新增 `Main/UI/OrderPanel` 多行自由文本编辑、预填、发布和关闭流程。
- `NPCSystem` 权威保存结构化 `current_order`，仅在文本变化时递增修订号、写入 `private` `order_assigned` 并发出统一计划重评估请求；相同文本或关闭无副作用。
- 8 名初始 NPC 配置补齐 `current_order`；MemorySystem 固定生成“守备官制定了新的指令。”摘要。
- GM 新增发布/查看指令和查看最近计划重评估请求入口；新增 `tools/verify_npc_order.gd`。

验证：
- `verify_npc_order.gd`、`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`verify_npc_generation_click.gd`、`verify_structured_memory_events.gd`、`verify_npc_short_term_memory_container.gd` 与项目加载通过。
- Godot MCP 连接正常，运行 `Main.tscn` 无游戏日志报错。

### T0702 提出应征与征召结果
完成：
- `DialogPanel` 新增“提出应征”按钮，点击后把下一次玩家消息标记为应征请求，发送后自动清除。
- `DialogSystem` 校验后端 `accept` / `reject`，接受时调用 `NPCSystem.set_npc_recruited(...)` 更新权威状态，拒绝时保持原状态。
- 应征请求与结果写入该轮 `dialogue_turn.payload`；`MemorySystem` 将 `recruitment_result` 纳入对话事件必需字段。
- NPC 面板会立即显示已入伍，并仅对已入伍 NPC 显示禁用的“指派（占位）”按钮；未提前实现 T0703。

验证：
- `tools/verify_dialogue_ui.gd` 覆盖应征按钮、一次性请求、接受、拒绝、NPC 状态、指派占位与事件 payload。
- `verify_npc_panel_state.gd`、`verify_structured_memory_events.gd`、`verify_llm_bridge.gd`、`verify_gm_panel.gd`、后端 Schema/接口验证和项目加载通过。
- Godot MCP 连接正常。

### T0701 对话 UI
完成：
- NPC 面板新增“对话”按钮；`Main/UI/DialogPanel` 接入 NPC 名字、公开性、轮次、历史、自由文本输入、发送和结束按钮。
- `DialogSystem` 接通 `LLMBridge`，维护玩家-NPC 不限轮次会话与 NPC-NPC 默认 5 轮会话。
- `MemorySystem` 为对话事件增加 payload 校验与确定性摘要；对话事件进入所有参与 NPC 事件库，`local_public` 只广播给同地点第三者。
- 新增 `tools/verify_dialogue_ui.gd`；未实现 T0702 征召状态切换。
- 修复“同地点公开”开关被永久禁用：首轮发送前可切换并同步会话公开性，首轮发送后锁定。
- 对话事件降噪：移除 `dialogue_started` / `dialogue_ended` 入库与广播，只保留实际发生的 `dialogue_turn`。

验证：
- `tools/verify_dialogue_ui.gd`、`tools/verify_llm_bridge.gd` 在隔离 `mock` 后端下通过。
- `verify_structured_memory_events.gd`、`verify_npc_panel_state.gd`、`verify_gm_panel.gd`、后端 Schema/接口验证和项目加载通过。
- Godot MCP 连接正常，运行主场景无游戏日志报错。

### T0005 修正 Godot MCP 多会话单例边界
完成：
- 确认 Codex 每个会话都需要自己的 stdio proxy；此前 proxy 按同父进程清理 sibling 的逻辑会主动关闭旧会话，正是旧会话收到 `Transport closed` 的根因。
- 移除 `godot-mcp-proxy.mjs` 的 proxy lock 与 sibling kill，proxy 现在只随所属会话 stdin 关闭而退出。
- 调整 `godot-mcp-broker.mjs` 启动顺序：先监听单例端口 `8765`，再建立唯一的 Godot `6550` WebSocket 连接，消除并发首次启动 race。
- 将旧 `start-godot-mcp.ps1` 改为只启动 broker，不再终止其他 MCP 进程，也不再绕过 broker 直连 Godot。
- 更新 `tools/check_godot_mcp.ps1`，多个 session-local proxy 视为正常；新增 `tools/verify_godot_mcp_topology.mjs` 做可重复拓扑验证。

验证：
- `node tools/verify_godot_mcp_topology.mjs` 验证多个 proxy 可共存、只保留一个 broker / Godot 连接，并验证关闭一个 proxy 不影响另一个。
- 冷启动并发验证通过；`start-godot-mcp.ps1` 重复运行后仍只保留一个 broker 和一条 Godot 连接。
- `powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1` 返回 `Godot MCP connected`。

## 2026-06-03

### T0604A LLMBridge 原生 HTTP 传输层
完成：
- 将 `scripts/systems/LLMBridge.gd` 的传输层从 T0604 临时 `curl.exe` / 临时 JSON 请求体文件替换为 Godot 原生 `HTTPClient` 状态机。
- 保持 LLMBridge 对上层接口稳定：`check_health()`、`request_npc_dialogue(...)`、T0603 payload 构造、错误字典、`backend_status_changed` 和 TimeSystem 慢速注册/释放语义不变。
- 新实现覆盖连接、请求、响应体读取、HTTP 响应解析、非法 JSON、后端 `ok=false` 与超时错误；会影响当前事态的请求在成功、失败或超时后都会释放慢速请求。
- `tools/verify_llm_bridge.gd` 新增静态防回退检查，确认 `LLMBridge.gd` 不含 `curl.exe`、`OS.execute`、临时请求体文件名或旧写文件函数。
- 回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`GODOT_ARCHITECTURE.md`、`AI_NPC_SYSTEM.md` 和 `API_BUDGET.md`，继续明确正式架构为 Godot 客户端请求游戏服务器后端，再由后端调用 LLM Provider；Godot 客户端不保存供应商 API Key。

验证：
- `godot --headless --path . --script res://tools/verify_llm_bridge.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `python tools/verify_dialogue_mock_endpoint.py` 通过。
- `python tools/verify_backend_schemas.py` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T1407 后端服务器部署任务登记
完成：
- 在 `docs/TASKS.md` 的 M14 新增 P0 任务 T1407：部署游戏后端到服务器。
- 明确服务器运行入口仍是 `backend/app.py`；本地开发可继续 `python backend/app.py`，正式部署不得使用 Flask debug server。
- 任务要求后续补齐生产 WSGI 启动方式、生产依赖、`backend/README.md` 部署说明、环境变量、日志、健康检查、限流、预算、重启策略和 Godot 后端地址配置。
- 同步更新 `TECH_ARCHITECTURE.md` 和 `CURRENT_STATE.md`，让后端部署方向从总览文档也能看到。

### T0604A 任务登记与 T0604 踩坑复盘
完成：
- 在 `docs/TASKS.md` 新增 P0 任务 T0604A，要求把 `LLMBridge` 的临时 `curl.exe` 传输层替换为 Godot 原生 HTTP。
- 将 T0701 对话 UI 的前置任务改为 T0604A，避免在临时传输层上继续叠加玩家对话与征召流程。
- 在 `TECH_ARCHITECTURE.md`、`GODOT_ARCHITECTURE.md`、`MODULE_INDEX.md`、`API_BUDGET.md`、`AI_NPC_SYSTEM.md` 和 `CURRENT_STATE.md` 中明确正式方向：玩家电脑运行 Godot 客户端，请求游戏服务器后端；服务器后端调用 LLM Provider、持有 API Key、负责并发、限流、降级、成本统计和调用日志。玩家自行配置 API Key 仅作为未来可选 BYOK / 开发模式，不是 Demo 必需路径。

T0604 踩坑归因：
- 主要问题是 Godot HTTP 传输层和 headless 验证方式，没有暴露 NPC、记忆、Prompt 或前后端职责边界的整体架构问题。
- Godot 原生 HTTP 首次尝试卡在信号等待、节点生命周期和异步请求验证方式上；后续 T0604A 需要显式请求状态机、完成回调和超时兜底。
- 同步等待异步 HTTP 结果会让验证脚本挂起；所有成功、失败、超时和降级路径都必须释放 TimeSystem 慢速请求。
- Windows 命令行传中文 JSON、引号和换行容易破坏请求体；T0604 使用 `curl.exe` + 临时 JSON 文件只是为了先保住最小闭环，不是分发方案。
- 本机环境变量残留非 mock provider 且缺少 Key 时，后端会按设计返回 provider unavailable；后续验证应显式使用 mock 或隔离环境。

后续避免：
- 先完成 T0604A，再推进 T0701/T0702。
- 任何真实 LLM 接入都必须走后端 Model Adapter，Godot 客户端不得保存真实供应商 API Key 或直连模型供应商。
- 对会影响即时事态的 LLM 请求，验证必须覆盖成功、失败、超时、后端关闭和慢速释放。

### T0604 Godot LLMBridge
完成：
- 新增 `scripts/systems/LLMBridge.gd` 并挂载到 `Main/Systems/LLMBridge`。
- `LLMBridge` 支持后端地址配置、`GET /health`、`POST /npc/dialogue`、T0603 对话 payload 构造、后端失败/超时错误结果、TimeSystem 慢速请求注册与释放。
- HUD 后端状态改为读取 `LLMBridge`，GM 面板新增后端健康检查、对话 Mock 和应征 Mock 调试入口。
- 新增 `tools/verify_llm_bridge.gd`，覆盖 payload 字段对齐、后端关闭不崩、health、dialogue Mock、慢速注册与成功/失败后释放。
- 回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`GODOT_ARCHITECTURE.md`、`AI_NPC_SYSTEM.md`、`API_BUDGET.md` 和 `GM_PANEL.md`。

验证：
- `godot --headless --path . --script res://tools/verify_llm_bridge.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `python tools/verify_dialogue_mock_endpoint.py` 通过。
- `python tools/verify_backend_schemas.py` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0603 `/npc/dialogue` Mock 接口
完成：
- `backend/app.py` 新增 `POST /npc/dialogue`，请求体校验为 T0603 版 `NPCDialogueRequest`，Mock 输出校验为 `NPCDialogueResponse`。
- `backend/schemas/npc_ai.py` 重整对话 Schema：输入覆盖目标 NPC 设定、说话者名称/文本/上下文、是否提出应征、当前轮次/最大轮次、NPC 状态、对话公开性、短期记忆、长期记忆和地点快照；输出使用 `replyer_id`、`reply_text`、`response_kind`、`recruitment_result` 和 `should_end_dialogue`。
- `backend/services/model_adapter.py` 的 `dialogue` Mock 分支支持玩家-NPC 应征 `accept` / `reject`，并在 NPC-NPC 对话轮次接近上限时倾向结束对话。
- 新增 `tools/verify_dialogue_mock_endpoint.py`，覆盖 `/npc/dialogue` HTTP 调用、应征 accept/reject、NPC-NPC 结束倾向和非法请求 400。
- 回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`DATA_SCHEMA.md`、`AI_NPC_SYSTEM.md`、`MEMORY_AND_INFO_SPACE.md`、`PROMPTS.md`、`API_BUDGET.md`、`backend/README.md`、`backend/schemas/README.md` 和 `game_design.md`。

验证：
- `python tools/verify_dialogue_mock_endpoint.py` 通过。
- `python tools/verify_mock_model_adapter.py` 通过。
- `python tools/verify_backend_schemas.py` 通过。
- Python 编译检查通过。

### T0602 Mock Model Adapter
完成：
- `backend/services/model_adapter.py` 默认 provider 改为 `mock`，`.env` 不存在或未设置 `LLM_PROVIDER` 时可直接返回 Mock JSON。
- 新增 `ModelAdapter.generate(...)`、`ModelAdapterResult` 和 `ModelUsageRecord`，按调用类型返回稳定内容，并记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用、成功/失败状态。
- Mock 当前覆盖对话、每日计划、计划修订、战斗判定、睡前总结、知识图谱更新、主动交涉、玩家话术分类和通用兜底响应；每日计划固定返回 24 条计划项。
- `backend/app.py` 新增 `POST /mock/model` 调试接口；非法 JSON / 非对象 payload 返回 400，非 mock provider 未配置 `LLM_API_KEY` 时返回明确错误。
- 新增 `tools/verify_mock_model_adapter.py`，并回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`API_BUDGET.md` 和后端 README。

验证：
- `python tools/verify_mock_model_adapter.py` 通过。
- `python tools/verify_backend_schemas.py` 通过。
- `python -m py_compile backend/app.py backend/services/model_adapter.py tools/verify_mock_model_adapter.py tools/verify_backend_schemas.py` 通过。

### T0601 后端 Schema
完成：
- 新增 `backend/schemas/common.py`，定义后端 AI 请求共享上下文：游戏时间、请求元信息、NPC 身份/状态、短期记忆摘要、行动候选和通用错误响应。
- 新增 `backend/schemas/npc_ai.py`，覆盖 NPC 对话、每日计划、计划异常重评估、战斗判定、睡前总结、知识图谱更新、主动找守备官交涉和玩家话术分类的请求/响应模型。
- 新增 `backend/schemas/__init__.py`、`backend/schemas/README.md` 和 `tools/verify_backend_schemas.py`。
- 回写 `CURRENT_STATE.md`、`TASKS.md`、`MODULE_INDEX.md`、`TECH_ARCHITECTURE.md`、`DATA_SCHEMA.md`、`PROMPTS.md` 和后端 README。

验证：
- `python tools/verify_backend_schemas.py` 通过。
- `python -m py_compile backend/schemas/common.py backend/schemas/npc_ai.py backend/schemas/__init__.py tools/verify_backend_schemas.py` 通过。
- Flask `create_app().test_client().get("/health")` 返回 200。

### T0502A 睡觉期间停止接收见闻
完成：
- `MemorySystem.add_witness_event(...)` 的见闻接收判定扩展为拒绝 `current_action == "sleep_in_dormitory"` 的 NPC。
- 睡觉 NPC 不再接收同地点/同建筑 `local_public` 事件、地点/建筑状态广播、公告或进入快照；自己的 `sleep_started` / `sleep_ended` 仍写入事件库。
- `tools/verify_action_local_public_broadcast.gd` 增加睡觉期间拒收 public 见闻、睡醒后恢复接收的回归断言。

验证：
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。

### T0409 广场 NPC 状态快照补齐
完成：
- `MemorySystem.get_location_snapshot(...)` 现在会为广场和可进入建筑统一生成 `people_statuses`；NPC 进入广场时，`location_context` 和一次性 `location_entry_snapshot` 见闻都能看到广场上 NPC 的生命状态与行动状态。
- 广场进入快照 summary 新增“在场人员状态”段落，沿用健康/受伤/昏迷、治疗者和精简中文行动状态的同一套格式。
- `tools/verify_location_info_nodes.gd` 增加广场 `people_statuses` 与 summary 断言。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

## 2026-06-02

### T0005 Godot MCP transport 断开复盘
完成：
- 复盘本次连接异常：Godot MCP 工具返回 `Transport closed`，但 `tools/check_godot_mcp.ps1` 一度仍返回 `Godot MCP connected`，说明 Godot 插件和 `broker -> Godot` 链路未先断，当前 Codex 会话的 stdio MCP transport 已关闭。
- 清理残留 headless Godot 验证进程后，重启 `godot-mcp-broker.mjs`，broker health 与 listTools 均可手动返回。
- 重启/刷新 Codex 后，`project.addon_status` 和 `editor.get_state` 恢复正常。
- 将本次教训回写到 `CURRENT_STATE.md` 的 Godot MCP 段落和 `TASKS.md` 的 T0005 复盘：后续排查要区分 Godot 插件监听、broker 健康、Codex MCP transport 三层；`Transport closed` 不一定表示 Godot 插件掉线。

验证：
- `powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1` 返回 `Godot MCP connected`。
- Godot MCP `project.addon_status` 返回 `connected: true`、`versions_match: true`。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

### T0407/T0503 建筑内 NPC 状态快照
完成：
- `MemorySystem` 的可进入建筑快照新增 `people_statuses`，进入者的 `location_entry_snapshot` 见闻会写出建筑内 NPC 的生命状态与行动状态。
- 生命状态分为健康、受伤、昏迷；昏迷者如有治疗者，会在状态文本中写明治疗者。行动状态由 `current_action` 翻译成精简中文。
- `ActionSystem` 新增只读 `get_healing_helpers_for_target(...)`，供信息节点查询当前治疗者，不参与权威结算。
- `tools/verify_location_info_nodes.gd` 和 `tools/verify_npc_unconscious_healing.gd` 增加建筑内 NPC 状态断言。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0503 事件摘要降噪
完成：
- `revived` summary 改为只表达 NPC 苏醒，不再展示 HP 恢复到多少。
- `healing_completed` payload 和 summary 不再包含原因字段。
- `tools/verify_npc_unconscious_healing.gd` 增加复苏 HP 文本和治疗完成原因字段的隐藏验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_unconscious_natural_recovery.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0503 治疗事件归属修正
完成：
- 修正协助治疗事件归属：治疗开始/完成进入治疗者和被治疗者事件库；同地点其他在场 NPC 获得见闻；治疗者不再把自己的治疗事件收到见闻库。
- 治疗事件 payload 和 summary 不再暴露医术熟练度。
- `tools/verify_npc_unconscious_healing.gd` 增加治疗事件归属与医术字段隐藏验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0503 治疗昏迷 NPC
完成：
- `NPCSystem` 新增 `assist_unconscious_recovery(...)`，按医术熟练度计算协助治疗恢复速度；低医术几乎没有额外加成，高医术会明显快于自然恢复。
- `ActionSystem` 新增 `debug_assign_heal_assist(healer_npc_id, target_npc_id)`，治疗者会前往昏迷目标所在信息地点；目标必须昏迷，每个目标最多 2 名治疗者。
- 治疗开始立即消耗 1 枚第纳尔，持续治疗期间每 1800 游戏秒继续消耗 1 枚第纳尔；资源不足时治疗指派失败或治疗中止。
- `MemorySystem` 增加 `healing_started` / `healing_completed` payload 校验和确定性 summary；治疗事件写入治疗者和目标 NPC 事件库，并写入同地点其他在场 NPC 的见闻库。
- `data/action_defs.json` 新增 `assist_heal` / `targeted_heal` 行动定义，普通 `assign_action` 不直接执行，必须通过带目标的协助治疗接口。
- GM 面板新增治疗目标下拉、协助治疗按钮和 `assist_heal <healer_npc_id> <target_npc_id>` 命令。
- 新增 `tools/verify_npc_unconscious_healing.gd` 覆盖 T0503 验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_unconscious_healing.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_unconscious_natural_recovery.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

## 2026-05-26

### T0502 昏迷自然恢复
完成：
- `NPCSystem` 监听 `TimeSystem.logical_time_tick`，让昏迷 NPC 按每游戏小时 2 HP 自然恢复；暂停时无逻辑 tick，因此恢复也暂停。
- HP 达到 Max HP 30% 后自动复苏，设置 `unconscious=false`、`current_action=idle`，并发出 `npc_revived`。
- `MemorySystem` 增加 `revived` payload 校验和确定性 summary；复苏事件按 NPC 当前信息地点 `local_public` 广播给同地点 NPC。
- 追加 T0502A：`MemorySystem.add_witness_event(...)` 会拒绝给昏迷 NPC 写入见闻，昏迷期间不接收地点/广场广播、状态广播、公告或进入快照；复苏后自动恢复接收。
- GM 面板新增 `recover_npc <npc_id> <game_seconds>` 命令，调用 `NPCSystem.debug_advance_unconscious_recovery(...)`，便于快速验证自然恢复。
- 新增 `tools/verify_npc_unconscious_natural_recovery.gd` 覆盖 T0502/T0502A 验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_unconscious_natural_recovery.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0409 广场进入快照与室内经由广场移动链
完成：
- `MemorySystem` 的广场 `location_entry_snapshot` summary 现在会写出广场当前在场 NPC、公告牌文本和所有建筑可传播外部状态；payload 继续保留 `people_present`、`current_notice`、`building_external_states` / `key_entities`。
- `NPCSystem` 将地点切换和进出事件记录收敛为统一逻辑；室内信息地点切换到另一个室内信息地点时，会记录“离开原地点 -> 进入广场 -> 离开广场 -> 进入目标地点”的事件链。
- 正常移动到达和 `debug_enter_location_immediately(...)` 共用同一套地点切换路径；当前物理移动仍是低模直线占位。
- `tools/verify_location_info_nodes.gd` 覆盖广场进入快照和室内经由广场事件链；`tools/verify_npc_movement_location.gd` 同步不可进入仓库归入广场信息节点的当前架构。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0501 NPC HP 扣除与昏迷状态
完成：
- `NPCSystem` 新增 `apply_damage_to_npc(...)` / `debug_damage_npc(...)`，负责权威扣除 NPC HP；HP 降到 0 后设置 `unconscious=true`、`current_action=unconscious` 并停止移动。
- `ActionSystem` 在 NPC 昏迷后清除 pending / active 行动，并拒绝继续指派工作、吃饭、睡觉、协助修复/升级；`NPCSystem.move_npc_to_building(...)` 同样拒绝移动昏迷 NPC。
- `MemorySystem` 增加 `damage_taken` / `unconscious_started` payload 校验和确定性 summary；昏迷事件以 `local_public` 广播到 NPC 当前信息地点，让同地点 NPC 收到见闻。
- `GMPanel` 的 `attack_npc` / 新增 `damage_npc` 命令改为调用 NPC 扣血接口；`verify_gm_panel.gd` 增加扣血昏迷检查。
- 新增 `tools/verify_npc_damage_unconscious.gd` 覆盖 T0501 验证。

验证：
- `godot --headless --path . --script res://tools/verify_npc_damage_unconscious.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0408 收敛广场公开事件可见性
完成：
- 事件可见性只保留 `private` 与 `local_public`；广场广播改为 `location_id == "plaza"` 的本地公开事件。
- `MemorySystem` 将广场公告、广场状态、手动广场广播和协助修复/升级事件统一走地点广播路径，并将广场事件查询接口改为 `get_plaza_events()` / `debug_get_plaza_events()`。
- `ActionSystem` 协助修复/协助升级开始事件改为广场本地公开事件。
- `GMPanel` 可见性下拉移除旧广场专用公开项，攻击事件默认使用 `local_public`。
- `tools/verify_plaza_local_public_broadcast.gd` 替换旧广场专用广播验证脚本，并同步更新结构化事件、短期记忆和行动验证。

验证：
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0407 精简地点事件与建筑状态见闻
完成：
- `location_entered` / `location_exited` 现在只记录进入/离开的行动事实，不再在事件 payload 或 summary 中携带完整地点状态。
- NPC 进入新信息地点时，进入者会在见闻库获得一次 `location_entry_snapshot` 当前状态快照；已经在该地点的 NPC 只收到本地公开的进入/离开事件。
- NPC 离开地点时生成 `location_exited`，事件 `location_id` 使用被离开的地点，并广播给仍在该地点的 NPC。
- 建筑状态变化见闻改为字段级差量：外部状态使用 `changed_fields`，工位占用变化使用 `changed_workstations`，不再复制完整广场或建筑快照。
- 更新 `tools/verify_location_info_nodes.gd` 与 `tools/verify_plaza_local_public_broadcast.gd` 覆盖 T0407 规则。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

## 2026-05-25

### 建筑修复覆盖、进入快照与协助事件位置修正
完成：
- `data/building_defs.json` 为城门、后门、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所和工械坊补齐 `repair` 配置，验证所有建筑都可修复。
- NPC 进入可进入建筑时，`location_entered` 摘要和进入者收到的当前状态见闻会立即包含建筑外部状态、建筑内 NPC 和工位占用状态。
- 协助修复/协助升级改为广场行为：NPC 在室内时先移动到广场；协助开始事件写入 `location_id == "plaza"` 的 `local_public`，目标建筑保留在 `payload.building_id`。
- `BuildingSystem` 的协助者有效性改为要求 NPC 仍在广场且当前行动仍是协助对应建筑。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。

### T0205/T0305/T0403/T0404/T0405 建筑升级倒计时与见闻降噪
完成：
- `BuildingSystem.upgrade_building(...)` 改为点击时一次性扣除资源并创建升级作业，随 `logical_time_tick` 推进；倒计时完成后才提升等级、Max HP 和可配置工作位奖励。
- 建筑受损、正在修复或正在升级时不可开始升级；升级期间不可开始修复。所有建筑定义都补齐了 `upgrade` 最小配置。
- `ActionSystem` 新增 `debug_assign_upgrade_assist(npc_id, building_id)`；NPC 可协助正在升级的建筑并按工程熟练度提供加速，升级完成后自动回到 idle。
- `MemorySystem` 的建筑可传播外部状态收窄为等级和完好/受损/正在修复/正在升级；HP、Max HP、剩余修复/升级时长不再触发见闻传播。可传播内部状态收窄为在场 NPC 和每个工位的占用/空闲状态，工位数量不再触发传播。
- 建筑状态见闻 summary 改为直接表达实际信息，不再使用“建筑状态更新”这类空泛前缀。
- `BuildingPanel` 显示升级倒计时进度、剩余时间、速度倍率和协助人数；`GMPanel` 新增协助升级按钮与 `assist_upgrade <npc_id> <building_id>` 命令。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。

### T0403/T0404/T0405 建筑状态与见闻广播修正
完成：
- `MemorySystem` 监听 `building_state_changed`，任一建筑外部状态变化都会同步到广场 `building_external_states` / `key_entities`，并生成带具体建筑名的 `plaza_status_changed` 见闻。
- 可进入建筑状态变化会生成 `location_status_changed` 本地见闻；NPC 进入广场获得所有建筑外部状态，进入可进入建筑获得该建筑外部 + 内部状态。
- 建筑状态快照拆分外部状态（HP、等级、完好/受损/正在修复、剩余修复时长）和内部状态（在场 NPC、工位数量、占用/空闲状态）；不可进入建筑不暴露内部 NPC 或工位。
- `data/building_defs.json` 移除主厅、仓库、围墙、城门的旧内部工位占位；围墙升级不再增加内部工位。
- 更新 `tools/verify_location_info_nodes.gd`、`tools/verify_plaza_local_public_broadcast.gd`、`tools/verify_building_repair_upgrade.gd` 覆盖全建筑外部状态、内部字段隔离、状态见闻命名和不可进入建筑无工位规则。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0006 修复建筑修复进度抢占右上角面板
完成：
- `EventBus` 新增 `building_state_changed(building_id)`，区分建筑状态刷新与玩家/调试选择建筑。
- `BuildingSystem` 在建筑受损、开始修复、修复进度推进、协助者变化、修复完成和升级时发出 `building_state_changed`，不再复用 `building_clicked`。
- `BuildingPanel` 仍通过 `building_clicked` 打开建筑，但只在自身可见且当前显示同一建筑时响应 `building_state_changed` 刷新。
- `tools/verify_npc_panel_state.gd` 增加回归用例：开始修复受损建筑后点击 NPC，再推进修复时间，确认右上角保持 NPC 面板。

验证：
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0305 行动系统持续时间修订
完成：
- `ActionSystem` 的工作、吃饭、睡觉改为到达地点后进入 active 行动，随 `TimeSystem.logical_time_tick` 推进，不再瞬时完成。
- `data/action_defs.json` 改用 `duration_seconds`：工作 3600 秒、吃饭 1200 秒、睡觉 23400 秒。
- 吃饭按 20 分钟恢复约 50 点饱食度结算；睡觉按 6.5 小时降低 100 点疲劳结算；工作保留 1 小时最小批次，完成后结算当前占位投入/产出。
- 更新行动验证脚本，使测试显式推进逻辑时间后再检查完成事件和数值变化。

验证：
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。

### T0005 加固 Godot MCP proxy 自恢复
完成：
- 排查到这次 MCP “又连不上”的直接原因不是 Godot 插件掉了，而是同一个 `codex` 父进程下残留了两个 `godot-mcp-proxy.mjs`；其中旧的那个没有 broker 子进程，属于孤立 proxy。
- 更新 `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`，加入 `%USERPROFILE%\.codex\godot-mcp-proxy.lock`。新 proxy 启动时会检查同父进程的旧 proxy，命中后先清理再接管，退出时再移除自己的 lock。
- 更新 `tools/check_godot_mcp.ps1`，除了原来的连接判断外，额外提示“多 proxy”与“proxy 在但 broker 不在”两类故障。
- 将这次经验精简回写到 `CURRENT_STATE.md` 和 `TASKS.md` 的 Godot MCP 相关位置，后续排查优先先看自检脚本和 proxy/broker 进程关系。
- 追加修正：再次复发时确认旧逻辑只会清理 lock 指向的单个 proxy，连续多次拉起后更早的残留 proxy 仍会留下。已改为按同一个 `codex` 父进程枚举所有 `godot-mcp-proxy.mjs`，在启动时一次性清理其余旧实例。

验证：
- `powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1` 返回 `Godot MCP connected`。
- Godot MCP `project.addon_status` 返回 `connected: true`、`versions_match: true`。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。
- 清理孤立 proxy 后，只剩 1 条有效的 `proxy -> broker` 链路。

## 2026-05-24

### T0205/T0305 建筑修复 UI 与协助行为清理
完成：
- `BuildingPanel` 不再把修复/升级消耗常驻显示在面板正文；悬停修复/升级按钮时，在按钮旁显示资源消耗和条件提示框。
- `BuildingSystem` 会在 NPC 状态变化和修复推进前清理无效协助者；NPC 离开对应建筑或被改派后，协助人数和速度加成立即移除。
- `ActionSystem` 的协助修复保留为 `debug_assign_repair_assist(npc_id, building_id)` 这一套带建筑参数的统一行为；移除 `data/action_defs.json` 中固定“修补围墙”行动，避免 GM 行动下拉与协助修复按钮表达重复。
- `GMPanel` 行动分组新增“修复目标”建筑下拉，让“协助修复”按钮可直接选择目标建筑。
- 建筑操作提示框增加屏幕边界夹取；靠近右侧等边缘时会翻到按钮内侧或保持在可视区域内。
- `tools/verify_action_system_basic.gd` 增加“协助者离开后移除加成”的回归检查。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现真实每日计划自动挑选修复目标；仍保留在 T1001 TODO。

### T0205/T0305 建筑修复倒计时与 NPC 协助修复
完成：
- `BuildingSystem.repair_building(...)` 改为点击时一次性扣除资源并创建修复作业；HP 随 `logical_time_tick` 按进度逐步恢复，不再瞬间修复。
- 修复时长由缺失 HP、建筑等级和 `data/building_defs.json` 中的 `repair.seconds_per_missing_hp` / `repair.level_time_factor` 计算。
- 新增修复状态查询与 NPC 协助接口：`get_repair_status(...)`、`is_repair_in_progress(...)`、`add_repair_helper(...)`、`remove_repair_helper(...)`。
- `ActionSystem` 新增 `debug_assign_repair_assist(npc_id, building_id)`；NPC 到达正在修复的建筑后按工程熟练度加速倒计时，多个 NPC 可叠加，修复完成后回到 idle。
- `GMPanel` 新增 `assist_repair <npc_id> <building_id>` 命令，并在建筑快照中可观察修复状态。
- `MemorySystem` 预留并格式化 `repair_assist_started` 事件。

验证：
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现真实每日计划自动选择协助修复；已把“规则计划可把协助修复作为候选行为并选择目标”加入 T1001 TODO。

### T0403 修复行动事件 local_public 广播
完成：
- 修复 `ActionSystem` 行动事件可见性：工作、吃饭、睡觉开始/完成/失败事件不再以 `private` 写入，而是以 `local_public` 写入 `MemorySystem`。
- 同地点当前在场 NPC 会收到这些活动/工作事件并写入见闻库；行动者本人仍只保留亲历事件，不重复写入自己的见闻库。
- 新增 `tools/verify_action_local_public_broadcast.gd`，覆盖工作、吃饭、睡觉三类行动事件的本地公开广播。

验证：
- `godot --headless --path . --script res://tools/verify_action_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `editor.get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未新增 GM 面板入口；现有行动指派和记忆查询入口已经可以手动验证该修复。

### T0406 统一玩家交互事件世界内称呼
完成：
- `MemorySystem.record_player_interaction(...)` 将玩家相关 actor id 写为 `guard_officer`，并在 payload 中补充 `actor_display_name = "守备官"`。
- 玩家非对话交互 summary 模板改为“守备官给了/守备官攻击了/守备官指派了”等世界内称呼，不再把“玩家”写入 NPC 记忆文本。
- `tools/verify_npc_short_term_memory_container.gd` 增加给钱与攻击事件 summary 检查，确保包含“守备官”、不包含“玩家”，且 actor id 为 `guard_officer`。
- 更新设计源、NPC、记忆、Prompt、数据结构、GM、模块索引、当前状态和任务文档中的称呼规则。

验证：
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

未做：
- 未重命名现有 `record_player_interaction(...)` / `npc_attacked_by_player` 等开发接口和事件类型，避免破坏当前任务、验证脚本和后续模块引用；世界内文本已统一为“守备官”。

### T0206 将公告牌移出建筑数据结构
完成：
- 从 `data/building_defs.json` 删除 `notice_board` 建筑定义，建筑定义数量由 16 调整为 15。
- 保留 `Main.tscn` 中主厅前 `NoticeBoard` 视觉占位；它不再绑定 `BuildingSystem`，不拥有 HP、等级、工作位、修复或升级。
- 明确公告文本的权威状态仍由广场信息节点保存，公告变更继续生成 `plaza_notice_changed` 并广播给当前在广场的 NPC。
- 更新建筑、数据结构、记忆信息、Godot 架构、模块索引、当前状态、任务列表和设计源中的相关说明。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/building_defs.json` 合法，且不包含 `notice_board`。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。

未做：
- 未新增公告编辑 UI；现有 GM 广场公告入口继续作为验证入口。

### T0004 建立 GM 调试面板与验证工作流
完成：
- 新增 `scripts/ui/GMPanel.gd`，在 `Main/UI/GMPanel` 下提供可拖动半透明 `GM` 按钮、GM 面板窗口、命令输入框、执行结果区和分组调试按钮。
- GM 面板顶部 `GM_ENABLED` 常量可用 `true` / `false` 切换开发/上线显示。
- GM 面板当前覆盖资源、时间、建筑、NPC、行动、记忆/见闻/广场公告等 M1-M4 已完成但前端不易直接验证的关键能力。
- 新增 `docs/GM_PANEL.md`，记录开关、分组、命令、维护规则和验证方式。
- 更新 `AGENTS.md`：每次任务完成时若新增功能无法直接在前端验证，必须给 GM 面板新增或替换调试入口，并同步更新 GM 文档。
- 新增 `tools/verify_gm_panel.gd`，覆盖 GM 面板加载、打开、资源命令、建筑受损、时间设置、NPC 地点进入、给钱事件、广场公告和结果输出。

验证：
- `godot --headless --path . --script res://tools/verify_gm_panel.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，清空旧日志后游戏日志无报错，截图可见 GM 按钮与面板。

未做：
- 未新增新的权威结算系统；GM 面板只调用已有系统接口或 `debug_*` 接口。
- 未实现真实对话、征召、战斗、昏迷/治疗/复苏或后端 LLM 调用。

### T0405 实现 NPC 短期记忆容器
完成：
- `MemorySystem` 新增 `get_npc_short_term_memory(...)` / `get_npc_short_term_memory_ids(...)`，将当天 `event_log` 与 `witness_log` 作为独立容器暴露给后续 LLM 输入。
- 新增 `record_player_interaction(...)`，玩家非对话交互会先进入目标 NPC 事件库，再按 `private` / `local_public` 可见性广播给事件地点当时在场 NPC；广场交互使用 `location_id == "plaza"`。
- 新增 `debug_record_player_money_given(...)` 和 `debug_record_player_attack_npc(...)`，用于验证给钱和攻击事件写入；本次不实现真实按钮、HP 扣除或昏迷。
- `NPCPanel` 新增事件库和见闻库最近摘要，监听 `npc_memory_changed` 自动刷新。
- 新增 `tools/verify_npc_short_term_memory_container.gd`，覆盖短期记忆容器、给钱/攻击交互、见闻广播和面板区分显示。

验证：
- `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。

未做：
- 未做睡前总结、知识图谱更新、LLM 接入、真实交互 UI、真实攻击扣血或昏迷。

### T0404 实现广场公开信息即时广播
完成：
- `MemorySystem` 将广场事件统一为 `location_id == "plaza"` 的 `local_public`，当前在广场的 NPC 会把事件写入见闻库。
- 室外或不可进入实体来源的公开事件会规范化为 `location_id == "plaza"`，并在 payload 中保留 `source_location_id`。
- 广场快照明确没有自身建筑 HP，并提供主厅、围墙、城门、仓库 `key_entities`、当前在场 NPC 数和敌人数。
- 广场公告文本变更会生成 `plaza_notice_changed` 广场公开事件；关键目标受损、修复或升级会生成 `plaza_status_changed` 广场公开状态事件。
- `BuildingSystem` 在关键目标受损、修复或升级时通知 `MemorySystem` 进行广场状态广播。
- 新增 `tools/verify_plaza_local_public_broadcast.gd`，覆盖广场本地公开事件、公告、关键实体状态、广场快照字段和见闻库写入。
验证：
- `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 通过。
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
未做：
- 未实现战斗本体、昏迷/复苏系统、逃离行为、公告输入 UI 或 LLM 解读。

### T0403 实现地点信息节点与进入快照

完成：
- 在 `scripts/systems/MemorySystem.gd` 中建立可进入地点信息节点，覆盖广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊。
- 地点节点维护 `people_present`、当前公告/命令和进入快照；主厅、围墙、城门、仓库状态归入广场 `key_entities`。
- `NPCSystem` 到达地点时会更新旧地点/新地点在场人员，并把 `location_entered.payload.location_snapshot` 写入事件库。
- `local_public` 事件会即时广播给事件地点当前在场 NPC，并写入接收者见闻库；地点节点不保存事件历史。
- `BuildingSystem.get_building_location_context(...)` 优先读取 `MemorySystem.get_location_snapshot(...)`，让 UI / NPC 状态使用同一套当前状态快照。
- 新增 `tools/verify_location_info_nodes.gd`，覆盖地点人数进出、进入快照、广场关键实体状态和本地公开事件见闻转发。

验证：
- `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 通过。
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现完整广场公开信息规则、战斗公开事件、公告输入 UI、睡前总结或 LLM 记忆摘要。

## 2026-05-23

### T0402 架构适配检查

完成：
- 检查 T0403 前已完成代码是否仍隐含旧的“地点/建筑保存事件历史并供后来 NPC 继承”模型。
- `BuildingSystem.get_building_location_context(...)` 删除 `recent_events` 占位，改为 `current_public_note_ids` / `public_notes` 当前状态占位。
- 删除 `MemorySystem` 的按地点查询事件 API 与内部索引，避免继续暗示地点/建筑保存事件历史。
- `BuildingPanel` 和验证脚本中的旧措辞同步为“地点状态 / 结构化事件日志”。

验证：
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。

### T0402 实现结构化事件底座

完成：
- `MemorySystem` 从最小 EventLog 占位升级为结构化事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场公开事件查询；地点/广场节点不作为事件历史存储。
- 结构化事件统一包含 `event_id`、`day`、`time`、`type`、`subject_npc_id`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary`、`payload`。
- 已预留 T0402 要求的事件类型，并为 `location_entered`、`work_started`、`work_completed`、`work_failed`、`eat_completed` 等实现确定性 summary 模板和必需 payload 字段声明。
- `ActionSystem` 工作/吃饭/睡觉/失败路径已迁移到结构化事件；`NPCSystem` 到达地点时写入 `location_entered`。
- `EventBus` 增加 `event_recorded`、`npc_memory_changed`、`location_info_changed` 信号。
- 新增 `tools/verify_structured_memory_events.gd`，覆盖结构化字段、NPC 事件库、全局索引、广场公开查询和 payload schema。

验证：
- `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP `get_state` 正常返回，当前打开 `res://scenes/main/Main.tscn`。

未做：
- 未实现地点/广场即时广播、知识图谱、日记、LLM 记忆摘要、对话或战斗。

## 2026-05-22

### T0401 暂停输入与暂停结算语义修正

完成：
- 确认 `SpeedButton` 只调用 `TimeSystem.cycle_speed()`，空格和 `PauseButton` 只调用 `TimeSystem.toggle_paused()`，空格不会改变 `x1` / `x2` / `x4` 速度倍率。
- `ActionSystem` 监听 `gameplay_pause_changed`；暂停期间已到位行动只保留 pending，不执行资源消耗/产出、饱食/疲劳变化或 EventLog 结算，恢复后再结算。
- `game_design.md` 补充暂停设计：暂停停止逻辑时间、NPC 移动、战斗和资源/状态结算，但不冻结 UI、后端请求或 LLM 对话/判定等待。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过，覆盖空格不改速度、NPC 暂停移动、暂停期间行动不结算且恢复后结算。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- Godot MCP 运行 `res://scenes/main/Main.tscn` 后游戏日志无报错。

未做：
- 当前仍未实现真实 LLM 对话、NPC-NPC 对话、战斗系统或真实时间驱动生产；本次只补齐暂停底层语义和已接入行动结算的暂停保护。

## 2026-05-21

### T0401 逻辑时间倍率与 LLM 等待减速架构

完成：
- `TimeSystem` 增加 LLM 等待减速请求接口：`request_time_slowdown(...)`、`release_time_slowdown(...)`、`clear_time_slowdowns()`。
- 新增有效逻辑倍率读取接口：`get_effective_time_scale()`、`get_numeric_delta_multiplier()`、`get_game_delta_seconds(...)`。
- `EventBus` 新增 `time_scale_changed(...)` 与 `logical_time_tick(...)`，用于后续资源、计划、战斗数值按逻辑时间倍率结算。
- 默认 LLM 等待倍率为 `1/60`，即默认速度下现实 1 秒 = 游戏 1 秒；该机制不修改 `Engine.time_scale`，不改变 NPC 移动或动画速度。
- 更新 `game_design.md`、架构、AI、经济、战斗、Prompt、API 预算和任务路线图中的相关说明。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过，覆盖 LLM 等待减速、释放后恢复玩家倍率和数值倍率接口。
- `godot --headless --path . --quit-after 1` 通过。
- `verify_action_system_basic.gd`、`verify_npc_panel_state.gd` 回归通过。

未做：
- 未将真实 LLMBridge、资源产出、计划调度或战斗数值实际接入逻辑倍率；已在后续任务中补充要求。

### T0401 秒级时间显示与控制修正

完成：
- `GameState` 增加 `current_minute` / `current_second`，`TimeSystem` 改为按游戏秒推进并写回 `HH:MM:SS`。
- `EventBus` 增加 `time_changed(day, hour, minute, second)`，HUD 使用该信号连续刷新时间显示。
- `HUD` 的 `SpeedButton` 改为只循环 `x1` / `x2` / `x4` 流速。
- `Main/UI/HUD` 新增 `PauseButton`，用于暂停/继续；空格键绑定到同一暂停/继续逻辑。
- `tools/verify_time_system.gd` 补充秒级流逝、速度按钮、暂停按钮和空格暂停验证。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现每日计划、战斗倒计时或 LLM 时间减速。

### T0401 实现 TimeSystem

完成：
- 在 `scripts/systems/TimeSystem.gd` 中实现基础时间推进：一天 24 小时，默认现实 1 秒 = 游戏内 1 分钟，每 60 游戏分钟推进 1 小时。
- 增加暂停与 `x1` / `x2` / `x4` 加速切换接口，并将 `HUD` 的时间按钮接到 `TimeSystem.cycle_speed()`。
- 在 `EventBus.gd` 中补充 `day_started(day)`；`GameState.set_time(...)` 会在跨天时发出 `day_started`，并继续发出 `hour_started(day, hour)`。
- `HUD.gd` 监听 `hour_started` / `day_started` 刷新天数、小时和阶段文本。
- 新增 `tools/verify_time_system.gd`，覆盖时间推进、暂停、加速、跨天信号和 HUD 刷新。

验证：
- `godot --headless --path . --script res://tools/verify_time_system.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd`、`verify_npc_panel_state.gd`、`verify_action_system_basic.gd` 回归通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 LLM 时间减速、每日计划或战斗倒计时。

### NPC 面板属性显示修正

完成：
- `NPCPanel` 新增属性行，显示 `stats.strength` / 力量和 `stats.intelligence` / 智力。
- 面板显示顺序调整为：姓名、HP、属性、专长、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、职业熟练度、武器熟练度。
- `tools/verify_npc_panel_state.gd` 增加属性文本与 HP/属性/专长顺序验证。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- Godot MCP 本次连接失败：`ECONNREFUSED 127.0.0.1:8765`，未作为本次验证项。

### T0305 资源消耗与生产对齐修正

完成：
- 修正 `ActionSystem._execute_work(...)`：无 `output_resources` 的工作现在也会正确结算饱食/疲劳、写入 EventLog 并返回成功。
- `BuildingSystem` 新增 `restore_building_hp(...)`，支持工作行动恢复建筑 HP。
- `data/action_defs.json` 按 `game_design.md` 补齐酒窖酿酒、铁匠铺制造武器/盔甲、工械坊制造工程器械、马厩产出马匹整备占位，以及围墙修补恢复 HP。
- `data/resource_defs.json` 新增酒、武器、盔甲、工程器械、马匹整备派生资源。
- 扩展 `tools/verify_action_system_basic.gd`，覆盖派生资源生产、无普通产出工作和围墙修补 HP 变化。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/resource_defs.json` 和 `data/action_defs.json` 合法。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 派生资源仍是库存占位，不实现装备分配、器械部署、马匹实体、出售酒或复杂熟练度效率。

### T0305 实现简单行动系统

完成：
- `ActionSystem` 接入 `data/action_defs.json`，提供调试指派工作、吃饭、睡觉和指定行动的接口。
- 行动指派会先复用 `NPCSystem.move_npc_to_building(...)` 前往目标建筑；2026-05-25 起，到达后进入持续行动并随逻辑时间结算。
- 菜园工作产出粮食，食堂工作消耗粮食产出餐食；吃饭优先消耗餐食并恢复更多饱食度，没有餐食时消耗粮食；睡觉降低疲劳。2026-05-25 起，吃饭和睡觉恢复/消耗按持续时间逐步发生。
- `MemorySystem` 新增最小 EventLog 占位，行动成功或失败会记录事件。
- `data/resource_defs.json` 新增餐食资源，`data/action_defs.json` 扩展工作 / 吃饭 / 睡觉行动配置。
- 新增 `tools/verify_action_system_basic.gd` 验证最小行动闭环。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 LLM 日程、训练、战斗、工作位占用或复杂职业产出。

### 熟练度架构修正

完成：
- 按 `game_design.md` 8.4 固定 NPC 熟练度全集：职业熟练度 `养马`、`厨艺`、`耕种`、`打铁`、`教练`、`酿酒`、`医术`、`工程`；武器熟练度 `剑盾`、`长杆`、`弓`、`弩`、`骑术`。
- `data/npc_profiles.json` 中每名 NPC 均补齐 13 个熟练度维度，并移除 `搬运`、`草药`、`护甲制作`、`指挥`、`祈祷`、`劝解`、`木工` 等非设计源技能。
- `NPCSystem` 新增固定熟练度枚举、`normalize_skills(...)` 和 `get_npc_specialties(...)`，职业倾向由高熟练度推导，不再依赖硬职业字段。
- `NPCPanel` 改为显示“专长”，并分组显示职业熟练度与武器熟练度。
- 新增 `tools/verify_npc_skill_schema.gd` 验证每名 NPC 的技能全集。

验证：
- PowerShell `ConvertFrom-Json` 验证 `data/npc_profiles.json` 合法，且每名 NPC 刚好 13 个固定熟练度。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_skill_schema.gd` 通过。

### NPC 主界面标签与短名修正

完成：
- 将 `data/npc_profiles.json` 中 8 名 NPC 的显示名改为短名：托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文。
- 简化 `NPC.gd` 头顶标签，主场景只显示姓名、HP 和当前行动。
- 职业、是否入伍等详细信息仍保留在 `NPCPanel` 中显示。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- `verify_npc_generation_click.gd`、`verify_npc_panel_state.gd`、`verify_npc_movement_location.gd` 均通过。

### T0304 实现基础移动与地点进入

完成：
- `BuildingSystem` 新增 `get_building_entry_position(...)`，为 NPC 移动提供建筑入口目标点。
- `BuildingSystem` 新增 `get_building_location_context(...)`，返回地点信息读取占位。
- `NPC.gd` 新增 `move_to_location(...)` 和 `movement_arrived`，支持简单直线移动。
- `NPCSystem` 新增 `move_npc_to_building(...)`、`debug_move_npc_to_building(...)` 和 `debug_move_selected_npc_to_building(...)`。
- NPC 到达建筑后写回 `current_location`、`current_location_name`、`location_context`，并发出 `npc_state_changed`。
- 新增 `tools/verify_npc_movement_location.gd`，覆盖调试移动到食堂、宿舍、仓库和地点状态更新。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- 通过 Godot MCP 打开并运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现复杂避障、真实日程计划、工作/吃饭/睡觉行动结算、对话、征召、战斗或 LLM。

## 2026-05-20

### T0303 实现 NPC 基础状态与 NPC 面板

完成：
- 新增 `scripts/ui/NPCPanel.gd` 并接入 `Main/UI/NPCPanel`。
- NPC 面板当时显示姓名、职业、HP、饱食度、疲劳度、金钱、昏迷、入伍、当前行动和技能熟练度；2026-05-21 已改为显示由固定熟练度推导的专长。
- `EventBus` 新增 `npc_state_changed(npc_id)`。
- `NPCSystem` 新增 `get_npc_state(...)`、`update_npc_state(...)`、`set_npc_state_value(...)`，状态变化后会刷新 NPC 标签并通知 UI。
- `NPC.gd` 头顶调试标签在当时补充了入伍状态、昏迷和 HP 摘要；2026-05-21 已按主界面降噪要求改为短姓名、HP 和当前行动。
- `BuildingPanel` 与 `NPCPanel` 支持点击对象互斥切换。
- 新增 `tools/verify_npc_panel_state.gd` 覆盖面板打开、状态刷新、面板切换和关闭。

验证：
- `godot --headless --path . --quit-after 1` 通过。
- `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 通过。
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，并确认 `Main/UI` 下存在 `NPCPanel`、`BuildingPanel`、`DialogPanel`。

未做：
- 未实现 NPC 状态自然变化、治疗、对话、移动、征召或战斗。

## 2026-05-18

### 初始化文档结构

完成：

- 创建项目管理文档种子。
- 创建 `AGENTS.md` 协作规则。
- 创建核心模块文档。
- 明确文档回写流程。

影响文件：

- `AGENTS.md`
- `docs/PROJECT_BRIEF.md`
- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- 其他模块文档

待办：

- 初始化 Godot 项目。
- 初始化后端目录。
- 将现有完整策划案放入 `game_design.md`。

## 2026-05-19

### T0002 初始化后端目录

完成：
- 创建 Flask 后端入口 `backend/app.py`。
- 实现 `GET /health`，返回 `{"ok": true, "service": "war-not-mine-backend"}`。
- 确认 `backend/requirements.txt` 包含 `flask`、`python-dotenv`、`pydantic`、`requests`。
- 新增 `backend/.env.example` 作为本地配置模板；真实 API Key 不写入仓库。
- 创建 `backend/schemas/`、`backend/services/`、`backend/data/`，并使用 `.gitkeep` 保留空目录。
- 新增最小 `backend/services/model_adapter.py`，作为后续 LLM 供应商隔离边界。
- 更新 `.gitignore`，忽略 `backend/.env`。

验证：
- `python -m compileall backend` 通过。
- 安装 `backend/requirements.txt` 后，通过 Flask test client 验证 `GET /health` 返回 HTTP 200 和 `{"ok": true, "service": "war-not-mine-backend"}`。
- 启动 `python backend/app.py` 后，通过 `http://127.0.0.1:5000/health` 验证返回 `{"ok":true,"service":"war-not-mine-backend"}`。

未做：
- 未修改 Godot 场景。
- 未实现 NPC、战斗、资源或 AI 对话。

### T0001 初始化 Godot 项目结构

完成：
- 创建 `res://scenes/main/Main.tscn` 作为最小可运行主场景。
- 主场景包含 `WorldRoot/Station/Ground`、`Systems`、`UI/HUD`、`CameraRig/Camera3D` 和 `SunLight`。
- 补齐 Godot 目录骨架：`scenes/main/`, `scenes/world/`, `scenes/npc/`, `scenes/enemy/`, `scenes/buildings/`, `scenes/ui/`, `scripts/core/`, `scripts/systems/`，并用 `.gitkeep` 保留空目录。
- 设置 `project.godot` 的 `run/main_scene` 为 `res://scenes/main/Main.tscn`。
- 通过 Godot MCP 运行主场景，游戏日志无报错，截图可见标题与基础地面。

影响文件：
- `project.godot`
- `scenes/main/Main.tscn`
- `scenes/**/.gitkeep`
- `scripts/**/.gitkeep`
- `ui/.gitkeep`
- `assets/.gitkeep`
- `data/.gitkeep`
- `docs/CURRENT_STATE.md`
- `docs/TASKS.md`
- `docs/MODULE_INDEX.md`
- `docs/DEV_LOG.md`
- `docs/CHANGELOG.md`

未做：
- 未实现 NPC、战斗、建筑交互、资源系统、时间系统或后端。

### 稳定 Godot MCP 启动与自检
完成：
- 定位 Godot MCP 频繁断开的根因：同一个 `codex.exe` 下重复拉起 `godot-mcp` 实例，Godot 插件会用 “Replaced by new client” 替换旧连接。
- 修复 `tools/check_godot_mcp.ps1` 解析错误和乱码提示，改为可用的连接自检脚本。
- 将 Codex 全局 `godot-mcp` 启动命令改为 `node C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`。
- 新增 `godot-mcp-broker.mjs`，由单例 broker 负责唯一的 Godot WebSocket 连接；多个 Codex 会话只连接本机 proxy。
- 本机验证 broker 可正常健康检查，并能成功调用 `editor.get_state` 读取 Godot 编辑器状态。

换机补充：
- 新环境若仍配置为 `npx.cmd -y @satelliteoflove/godot-mcp`，切换 Codex 会话仍会重复直连 Godot `6550`，需要改为 `node %USERPROFILE%\.codex\scripts\godot-mcp-proxy.mjs`。
- Windows 下 broker 直接 `spawn("npx.cmd")` 可能报 `spawn EINVAL`；更稳妥的方式是直接启动 npm cache 中的 `@satelliteoflove/godot-mcp/dist/cli.js`。
- `tools/check_godot_mcp.ps1` 自检不要用 TCP 主动探测 Godot `6550`，裸 TCP 连接会被 Godot MCP 插件当作新客户端并顶掉 broker；只检查监听状态，真实验证走 proxy 调用 `editor.get_state`。
- 修复后应只看到 broker 与其唯一 `godot-mcp` 子进程，Godot `6550` 只有 1 条有效客户端连接；本机 broker 默认监听 `127.0.0.1:6551`。

影响文件：
- `tools/check_godot_mcp.ps1`
- `C:\Users\JT\.codex\config.toml`
- `C:\Users\JT\.codex\scripts\godot-mcp-broker.mjs`
- `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`

### T0101 建立核心 Autoload 与系统骨架

完成：
- 新增 `scripts/core/EventBus.gd`，声明资源、时间、建筑点击、NPC 点击和公开事件基础信号。
- 新增 `scripts/core/GameState.gd`，保存当前天数、小时和战斗状态。
- 新增 `scripts/core/ConfigLoader.gd`，提供 JSON 配置读取入口，并在文件缺失或解析失败时给出明确错误。
- 在 `project.godot` 中注册 `EventBus`、`GameState`、`ConfigLoader` Autoload，保留既有 `MCPGameBridge`。
- 新增 `TimeSystem.gd`、`ResourceSystem.gd`、`BuildingSystem.gd`、`NPCSystem.gd`、`MemorySystem.gd` 空系统脚本占位。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 清空旧日志后再次运行，游戏日志无报错。

未做：
- 未实现 NPC、建筑点击、资源变化、时间推进、后端连接或战斗逻辑。

### T0102 扩展 Main 场景节点结构

完成：
- 将 `res://scenes/main/Main.tscn` 整理为 `WorldRoot/Station`、`Systems`、`UI`、`CameraRig` 的标准结构。
- 在 `WorldRoot/Station` 下保留 `Ground`，并补齐 `Buildings`、`NPCs`、`Enemies`、`Props` 容器。
- 在 `Systems` 下补齐 `TimeSystem`、`ResourceSystem`、`BuildingSystem`、`NPCSystem`、`ActionSystem`、`MemorySystem`、`CombatSystem`、`DialogSystem`。
- 新增 `ActionSystem.gd`、`CombatSystem.gd`、`DialogSystem.gd` 空系统脚本占位，并绑定到 Main 场景。
- 在 `UI` 下保留 `HUD/TitleLabel`，并新增隐藏占位 `NPCPanel`、`BuildingPanel`、`DialogPanel`。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认当前 HUD 标题与基础地面仍可见。

未做：
- 未实现点击逻辑、NPC、资源数值、战斗或对话 UI。

### T0103 创建低模驿站 Blockout

完成：
- 在 `res://scenes/main/Main.tscn` 中扩展低模驿站空间占位。
- 在 `WorldRoot/Station/Buildings` 下新增主厅、宿舍、食堂、仓库、围墙、城门、后门等几何体占位。
- 在 `WorldRoot/Station/Props` 下新增广场、正门道路、后门道路和商人入口占位。
- 补齐酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、主厅前公告牌视觉占位等 T0103 要求的剩余占位区域。
- 为 P0 占位区域添加 `Label3D` 调试标签，便于后续建筑系统和导航接入。
- 扩大地面尺寸并调整俯视相机，让启动后可看到完整驿站布局。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认 HUD 标题、完整低模驿站和调试标签可见。

追加调整：
- 根据反馈扩大地面和围墙范围，并重新拉开建筑间距。
- 将建筑更明显地分散到中央广场、生活区、生产区、防务区和后门入口周边。
- 再次通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认拥挤感降低。

反馈修正：
- 补齐围墙四角闭合，让驿站院墙更像完整防御边界。
- 将公告牌缩小并移动到主厅正面，符合公共信息挂在主厅前的设想。
- 再次通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现建筑数据、建筑点击、生产、NPC、导航或战斗逻辑。

### T0104 建立 HUD 基础界面

完成：
- 在 `res://scenes/main/Main.tscn` 的 `Main/UI/HUD` 下补齐标题、天数、小时/阶段、资源占位、加速按钮、警铃按钮和后端状态占位。
- 新增 `res://scripts/ui/HUD.gd`，从 `GameState` 读取当前天数和小时，并根据小时显示清晨/白昼/黄昏/夜间阶段。
- 资源显示保持占位值 `--`，后端状态固定为未连接占位；加速和警铃按钮不触发真实逻辑。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- 截图确认 HUD 可见，并且没有遮挡主要驿站视角。

未做：
- 未实现真实资源变化、时间推进、警铃逻辑、后端连接或对话 UI。

### T0201 创建基础数据文件

完成：
- 新增 `data/resource_defs.json`，包含第纳尔、粮食、木材、石料、铁五类基础资源的最小配置。
- 新增 `data/building_defs.json`，包含主厅建筑的最小配置。
- 新增 `data/action_defs.json`，包含修补围墙行动的最小配置。
- 新增 `data/weapon_defs.json`，包含早期武器最小配置；该旧占位武器已在 T0013 后移除，正式主武器只保留剑盾、长杆、弓和弩。
- 新增 `data/enemy_waves.json`，包含第一波敌人占位配置。
- 新增 `data/npc_profiles.json`，包含老兵副官占位档案。
- 更新 `DATA_SCHEMA.md`，补齐资源、武器、敌人波次 schema，并让已有示例与实际 JSON 字段一致。
- 更新 `MODULE_INDEX.md`，记录新增数据文件的用途、依赖和当前状态。

验证：
- 使用 PowerShell `ConvertFrom-Json` 验证 6 个 JSON 文件格式合法，且均为非空数组。
- 通过临时 Godot 脚本调用 `ConfigLoader.load_data_file(...)` 读取 6 个文件，确认每个文件均返回数组数据。
- 通过 Godot MCP 自检确认连接正常。

未做：
- 未实现资源系统、建筑系统、NPC 生成、战斗波次生成或 LLM 接入。

### T0105 实现基础摄像机控制

完成：
- 新增 `res://scripts/camera/CameraRig.gd`，绑定到 `Main/CameraRig`。
- 支持 WASD 键盘平移、鼠标中键拖拽平移、鼠标滚轮缩放。
- 通过 X/Z 边界和缩放距离限制，避免摄像机离开驿站太远。
- 保留当前高机位俯视角，只移动 `CameraRig` 和调整 `Camera3D` 本地距离。

验证：
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`。
- 游戏日志无报错。
- Godot MCP 确认 `/root/Main/CameraRig` 已挂载 `res://scripts/camera/CameraRig.gd`，并暴露平移、缩放和边界参数。
- 使用 `godot --headless --path . --quit-after 1` 验证项目加载无错误。

未做：
- 未实现角色控制、镜头旋转或自由第一人称视角。

### T0202 实现 ResourceSystem

完成：
- 在 `scripts/systems/ResourceSystem.gd` 中实现基础资源初始化和读写接口。
- 启动时通过 `ConfigLoader.load_data_file("resource_defs.json")` 读取第纳尔、粮食、木材、石料、铁的初始值和下限。
- 提供 `get_resource(id)`、`add_resource(id, amount)`、`can_afford(cost_dict)`、`spend_resources(cost_dict)`。
- 提供 `debug_add_resource(...)` 和 `debug_spend_resources(...)` 作为临时测试入口。
- 资源变化通过 `EventBus.resource_changed` 发出，`scripts/ui/HUD.gd` 监听信号并显示真实资源数值。

验证：
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过临时测试场景验证：初始金钱 30；调试增加 5 后扣除 10 成功；粮食扣除 2 成功；超额扣除 9999 金钱失败且没有产生负数。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示 `金钱 30`、`粮食 18`、`木材 12`、`石料 8`、`铁 5`。

未做：
- 未实现商人交易、建筑生产或工作产出。

### T0203 实现 BuildingSystem 与建筑实体

完成：
- 扩展 `data/building_defs.json`，当时覆盖 16 个建筑/门墙实体；2026-05-24 T0206 已将公告牌移出建筑定义，当前为 15 个建筑/门墙实体。
- 在 `scripts/systems/BuildingSystem.gd` 中实现建筑配置读取、基础状态保存、`get_building(...)` / `get_building_ids()` / `get_building_snapshot()` 查询接口。
- 通过 `scene_nodes` 将配置绑定到 `Main/WorldRoot/Station/Buildings` 下的低模节点。
- 为绑定建筑运行时创建 `Area3D/CollisionShape3D` 点击区，左键点击后发出 `EventBus.building_clicked(building_id)`。
- 将建筑调试标签更新为名称、等级和 HP，便于确认基础状态。

验证：
- `data/building_defs.json` 可被 PowerShell `ConvertFrom-Json` 解析；当时包含 16 条建筑定义，2026-05-24 T0206 后当前为 15 条。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 使用临时 Godot 验证脚本确认当时 `BuildingSystem` 加载 16 个建筑定义、主厅数据可查询、仓库可选中、主厅 ClickArea 已创建；2026-05-24 T0206 后公告牌不再加载为建筑。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认建筑标签显示名称、等级和 HP。
- Godot MCP 查找确认运行时创建了 19 个 `ClickArea` 节点，覆盖多段围墙、城门和主要建筑。

未做：
- 未实现建筑面板、升级、修复、生产、敌人攻击或建筑 HP 扣除。

### T0204 实现建筑面板

完成：
- 新增 `scripts/ui/BuildingPanel.gd`，监听 `EventBus.building_clicked` 并从 `BuildingSystem` 读取建筑基础状态。
- 扩展 `Main/UI/BuildingPanel`，显示建筑名称、等级、HP / Max HP、工位状态和地点信息占位；工位展示后续已在 T0016 调整为按类型显示空闲数 / 总数与占用者。
- 修复、升级按钮保持禁用，仅作为后续 T0205 的 UI 占位。
- 面板右上角关闭按钮可隐藏面板；未知建筑或无建筑时面板保持隐藏。

验证：
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 使用临时 Godot 验证脚本确认选择主厅会打开面板、切换仓库会刷新数据、关闭按钮会隐藏面板。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 与低模驿站仍正常显示。

未做：
- 未实现建筑修复、升级、生产、储存/消耗展示或敌人攻击。

### T0204 建筑面板真实点击修正

完成：
- 修正点击建筑时不能显示面板的问题。
- 在 `scripts/ui/HUD.gd` 中让 HUD 根节点忽略鼠标，避免全屏 Control 背板拦截 3D 建筑点击。
- 在 `scripts/systems/BuildingSystem.gd` 中增加 `_unhandled_input` 射线拾取，从当前相机向鼠标位置投射并识别带有 `building_id` 的点击区。

验证：
- 使用临时 Godot 验证脚本模拟真实鼠标点击主厅，确认 `BuildingPanel` 打开且显示“主厅”。
- 使用 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 验证项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

### T0205 建立建筑修复与升级占位逻辑

完成：
- 在 `scripts/systems/BuildingSystem.gd` 中实现建筑修复、升级、可用性检查和临时受损调试入口。
- 修复/升级统一通过 `ResourceSystem.spend_resources` 扣除石料；资源不足时不扣资源、不改变建筑状态。
- 在 `scripts/ui/BuildingPanel.gd` 中接通修复/升级按钮，并根据建筑 HP、等级、配置和资源状态自动启用或禁用。
- 在 `data/building_defs.json` 为主厅、宿舍、食堂、仓库、围墙加入 `repair` / `upgrade` 配置；围墙升级会提升等级、Max HP，并增加 1 个修复工作位。
- 新增 `tools/verify_building_repair_upgrade.gd`，覆盖 T0205 的最小验收路径。

验证：
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 通过。
- `Godot_v4.6.2-stable_win64_console.exe --headless --path . --quit-after 1` 通过，项目加载无错误。
- `tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现复杂升级树、美术变化、生产结算、敌人攻击或战斗系统联动。

## 2026-05-20

### T0301 完成 8 个初始 NPC 数据草案

完成：
- 将 `data/npc_profiles.json` 从老兵副官占位档案扩展为 8 名初始 NPC：马夫、厨子、园丁、铁匠、老兵副官、神父、医生、工程师。
- 每名 NPC 均补齐 `id`、`name`、`gender`、`appearance`、`background_story`、`personality`、`desires`、`fears`、`abilities`、`states`、`skills`、`recruited`、`equipment`、`plan`、`short_term_memory`、`knowledge_graph`、`diary` 等字段。
- 老兵副官 `veteran_deputy_01` 设为女性且 `recruited=true`；医生 `doctor_01` 设为女性；其他 NPC 初始 `recruited=false`。
- 更新 `AI_NPC_SYSTEM.md`、`DATA_SCHEMA.md`、`MODULE_INDEX.md`、`CURRENT_STATE.md`、`TASKS.md` 和 `CHANGELOG.md`，让文档中的 NPC 列表与数据一致。

验证：
- 使用 PowerShell `ConvertFrom-Json` 验证 `data/npc_profiles.json` 格式合法。
- 确认 NPC 数量为 8，且只有老兵副官 `recruited=true`。
- 使用 `godot --headless --path . --quit-after 1` 验证项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。

未做：
- 未实现 NPC 场景、NPCSystem 生成、点击、移动、对话、征召或 LLM 接入。

### T0302 创建 NPC 场景与 NPCSystem

完成：
- 新增 `scenes/npc/NPC.tscn`，作为通用 NPC 低模占位场景。
- 新增 `scripts/npc/NPC.gd`，保存唯一 `npc_id`，显示 NPC 调试标签，并在点击时发出 `EventBus.npc_clicked`。
- 扩展 `scripts/systems/NPCSystem.gd`，启动时读取 `data/npc_profiles.json` 并在 `Main/WorldRoot/Station/NPCs` 下生成 8 个 NPC。
- 提供 `get_npc(...)`、`get_npc_ids()`、`get_npc_count()` 和 `debug_select_npc(...)`，便于后续面板和验证脚本接入。
- 新增 `tools/verify_npc_generation_click.gd`，验证 NPC 生成数量和点击事件。

验证：
- `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 通过。
- `godot --headless --path . --quit-after 1` 通过，项目加载无错误。
- 通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错。
- Godot MCP 查找确认 `Main/WorldRoot/Station/NPCs` 下生成 8 个 NPC `Area3D` 节点。

未做：
- 未实现 NPC 移动、状态面板、行动计划、对话、征召、战斗或 LLM 接入。

备注：
- 本次排查到一次 MCP 断连原因：Godot 插件仍在 `127.0.0.1:6550` 监听，但 `godot-mcp-broker.mjs` 未在 `127.0.0.1:8765` 监听，只剩 proxy 进程。手动启动 broker 后恢复，`tools/check_godot_mcp.ps1` 返回 `Godot MCP connected`。
