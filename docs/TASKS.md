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

## T0094 宿舍与对话记录 UI、弥撒重估、睡眠对话上下文及跨夜熟睡总结修复

状态：Done
优先级：P0
前置任务：T0043A, T0049, T0050, T0082, T0084, T0089
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 固定宿舍床位继续由配置与 BuildingSystem 权威维护，但 BuildingPanel 不再显示“某人专属”；与其他建筑位置统一，只显示“床位X：空闲”或“床位X：某人占用”。
- NPC 面板把原对话入口拆为主【对话】按钮和右侧小【记录】按钮；记录窗口只展示该 NPC 与守备官的过往对话，按游戏日期、时间和波次分组。
- 修复主持弥撒开始时，既有普通祈祷者没有可靠进入行动失败—计划重估链、NPC 可能异地祈祷，以及守备官明确谈妥参加弥撒后没有及时重估的问题；保持“强倾向而非程序硬选行动”的设计。
- 玩家在 NPC 睡眠中主动开启对话时，把被打断的当前活动和对话后应恢复的计划作为本轮私有上下文，避免 NPC 谎称已经睡醒并准备工作；不能把计划描述伪装成已经发生的事件。
- 把“每日一次”熟睡总结改为跨夜睡眠窗口：仅当 NPC 自上一个符合条件的夜间窗口起尚未总结，且在跨夜睡眠段累计达到既有时长阈值时触发；凌晨短暂被对话叫醒后继续睡应累计同一睡眠窗口，不提前消耗当晚总结资格。

验收标准：

- 固定床位分配、重复入睡与未来 NPC 空余床规则不变；宿舍面板只显示实时占用，不泄露专属归属文案。
- NPC 面板中【记录】不发起或恢复对话；记录按日期 / 时间 / 波次展示完整守备官—NPC 历史，并与事件库、见闻库及 NPC-NPC 对话区分。
- 弥撒开始会中断同教堂内全部普通祈祷、释放祈祷席并向 DailyPlanSystem 提交精确 `pray_failed_mass_started`；合法时正式修订强倾向参加当前弥撒。普通祈祷只能在小教堂实际到达并占位后进入 active。
- 守备官对话涉及当前 / 下一步活动时，正式对话 payload 明确包含对话打断前行动和恢复计划；对话结束后的行动恢复与计划重估规则不回归。
- 21:00 起算的夜间总结窗口按跨夜睡眠累计时长触发；凌晨对话短暂打断后继续睡仍属于同一窗口，当天白天补觉不会占用下一晚资格，同一窗口最多成功提交一次总结。
- UI、对话、行动、计划修订、记忆 / 反思专项与项目 headless 回归通过；环境已有真实 Key 时，对弥撒修订和睡眠中对话各完成真实 provider 验收且 `fallback_used=false`。

验收结果（2026-07-28）：

- BuildingPanel 保留固定床位分配但只显示通用空闲 / 占用文案；NPCPanel 新增右侧小【记录】，从全局事件档案按日期、事件时间和历史波次展示完整守备官会话，打开记录不会创建、恢复或打断对话。
- ActionSystem 为所有固定地点行动增加抵达复验；弥撒开始同时处理中断 active 祈祷与仍在移动的 pending 祈祷，后者先无信号收束移动，再只提交一次带完整上下文的 `pray_failed_mass_started`，避免无上下文状态信号抢占重估。守备官已谈妥当前弥撒也会强制把当前小时送入判别，最终仍由 LLM 在合法候选内选择。
- 第一条有效守备官消息携带目标私有 `interrupted_activity_context`，睡眠中 NPC 能说明刚被叫醒及计划不变时继续睡觉；上下文不写事件、见闻或长期记忆。熟睡总结改为 21:00 锚定窗口，跨多次睡眠累计既有 1 小时门槛，失败可重试，同窗只成功应用一次。
- 新增 / 扩展宿舍、记录、弥撒运行时、睡眠对话、夜间窗口专项；相关 UI、对话、行动、日计划、反思、Schema、Mock / endpoint、Prompt 与项目 headless 回归通过。真实 DeepSeek 四次弥撒判别 / 修订及一次睡眠打断对话均首次成功、`fallback_used=false`。Godot MCP 实测床位文案、历史分组、记录按钮只读边界与编辑器零错误。

---

## T0096 Pending 行动暂停恢复与抵达提交一致性

状态：Done
优先级：P0
前置任务：T0043, T0080, T0094
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 穷尽审计所有需要移动后才开始的行动，使暂停只冻结移动和逻辑推进，不删除、完成、失败或重复派发 pending；恢复后继续同一目标与同一行动。
- 所有移动依赖行动都必须在实际抵达、停止移动并重新通过地点 / 建筑 / 工位 / 目标条件校验后才能进入 active、占用位置或产生收益。
- 建筑封闭、昏迷、战斗接管、目标离开、真实对话打断等权威外部变化仍可取消 pending，但每次取消只能产生一次带精确原因的状态变化 / 行动失败。

验收标准：

- 对行动目录中全部可产生 pending 的行动，覆盖途中暂停、抵达临界帧暂停、长时间暂停和恢复；pending 的 action / target / options / movement target 保持，暂停期间无 active、无提前工位占用、无进度或资源结算，恢复抵达后恰好开始一次。
- 暂停期间让建筑或动态 NPC 目标失效，恢复 / 抵达时按既有权威规则产生一次精确失败，不重复释放、重复重估或启动旧行动。
- 既有吃饭、睡觉、工作、训练、治疗、祈祷 / 弥撒、拜访、NPC-NPC 对话与三类协助专项，以及 TimeSystem、结构化事件和项目解析回归通过；Godot MCP 运行态确认暂停 / 恢复不改变 pending。
- 现有 GM 通用“指定行动”、暂停 / 继续、最近行动结果与运行态快照足够构造和观察，不新增第二套行动权威。

验收结果（2026-07-29）：

- ActionSystem 新增统一提交闸门：暂停时任何 pending 都不能提交；恢复后还必须满足 `current_action=idle`、`movement_target` 已清空、实际地点匹配且没有 active，才可申请工位或开始收益。
- 固定地点目录 15 项与 `assist_repair / assist_upgrade / assist_heal / visit_location / talk_to_npc` 五类目标行动均纳入 `verify_pending_action_pause_resume.gd`。专项覆盖暂停保留 pending、抵达临界帧暂停、逻辑 tick 不结算、恢复恰好启动一次、路线原样继续及目标失效单次精确失败。
- `verify_time_system.gd`、弥撒 / 服务依赖、建筑入口失败、基础行动、计划目录、NPC-NPC 对话和昏迷协助治疗回归通过；Godot MCP 4.0.1 / Godot 4.6.2 冻结启动正常且编辑器无错误。

---

## T0095 熟睡总结异步期间的短期记忆增量保留

状态：Done
优先级：P0
前置任务：T0094, T1005
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 熟睡总结请求按发起时的短期记忆快照生成；若请求在飞期间产生新的私有事件或见闻，成功应用时只能轮转已经进入该快照的记录，不能把未被本次总结覆盖的增量一并清空。
- 采用稳定事件 ID / 快照水位或等价的权威边界，不在 UI 或模型侧猜测哪些记忆已经总结。
- 总结内容固定为“上一次成功总结水位之后，到本次请求快照水位为止”的尚未总结经历；某夜未睡够或请求失败时不伪造空白日记，下一次成功总结继续覆盖这段未总结区间。
- 日记归属使用 21:00 夜间窗口锚点而不是实际完成的自然日期。世界内前缀统一表达为“接到守备命令的第N天”，其中“守备命令”明确指守备官在公告牌向众人传达“我们奉命守住此地”的公开命令，不表示 NPC 当天才到驿站、收到个人指令或已经入伍。

验收标准：

- 构造“请求发起后新增事件、随后总结成功”的异步场景，新事件仍保留在 NPC 当前短期索引，快照内旧事件被正常轮转。
- 模型失败 / 模板降级、并发上限、21:00 窗口完成语义、全局 append-only 对话档案与既有深度睡眠锁不回归。
- 同一自然日凌晨与深夜各完成一次时，前者归前一个 21:00 窗口、后者归后一个窗口，日记前缀分别使用不同的“接到守备命令的第N天”；日记 payload 和后续 LLM 上下文保留窗口键、锚点日、实际总结时刻及本次记忆区间。
- Prompt 只总结明确区间内的亲历 / 见闻，不把“接到守备命令的第N天”解释为入伍日、到站日或个人受命日；环境有真实 Key 时完成一次真实 `daily_reflection` 验收且 `fallback_used=false`。

验收结果（2026-07-29）：

- MemorySystem 提供带稳定 `event_ids / witness_ids` 的原子短期快照，并按该快照选择性轮转；异步请求发出后新增的事件继续留在当前短期索引，不会被旧请求清除。
- DailyReflectionSystem 把触发窗口、内容水位和日记归属拆开：每个 21:00 窗口最多成功一次，内容从上次成功快照终点延续到本次请求快照，归档前缀按窗口锚点写为“接到守备命令的第N天”，同时保留实际触发日 / 时间和精确记录范围。
- 后端新增结构化 `summary_window / reflection_period` 合同，Prompt 明确“守备命令”是公告牌上“我们奉命守住此地”的公开命令，不是个人入伍或个人受命。Schema、Mock endpoint、Prompt、Godot 异步水位 / 跨夜窗口专项通过；真实 DeepSeek `deepseek-v4-flash` 一次成功且 `fallback_used=false`。

---

## T0093 完成型行动连续计划段重估与建筑工期规划约束

状态：Done
优先级：P0
前置任务：T0086, T0088
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 修复 Godot `LLMBridge` 把上游合法 `action_completed` 计划修订原因规范化为 `unknown` 的合同遗漏。
- 日计划、计划修改范围判别和正式计划修订必须结合 `game_time` 与建筑作业可读总工期 / 剩余时间安排阶段，不能把短时升级协助机械铺满预计完工后的时段。
- `reevaluate_current_hour_on_completion=true` 的五类行动完成后，不再只修订当前小时；从当前小时开始，把原计划中连续的同一 `action_id + target_id` 阶段一次性交给正式修订，遇到不同任务 / 目标或当天结束立即停止。只有当前一项时仍只修改当前小时。
- 保留 T0086 的真实 provider、跳过范围判别、当前小时即时执行、禁止当前小时原样重复、跨小时陈旧回调丢弃和最多三次正式修订边界。

验收标准：

- `action_completed` 从 DailyPlanSystem 经 LLMBridge 构造正式 payload 后仍保持原枚举。
- 五类完成型行动的配置穷尽集合不变；连续相同任务三小时完成后请求 `revision_hours=[当前, 当前+1, 当前+2]`，下一小时不同任务不被夹带，单小时与跨小时边界保持既有行为。
- 三份计划 Prompt 都用精简规则要求按游戏时间和建筑剩余工期约束受影响 / 协助时段。
- Prompt、Schema、Mock / endpoint、Godot 完成重估与建筑作业回归通过；环境已有真实 Key 时，用真实 provider 验证多小时 `action_completed` 修订且 `fallback_used=false`。
- 现有 GM 指定行动、推进时间、当前计划、`plan_request` 与 LLM 日志足够观察，不新增重复入口或权威结算。

验收结果：

- `LLMBridge` 已保留合法 `action_completed` 枚举；DailyPlanSystem 从完成时的当前小时起，按既有计划项 identity 收集连续相同 `action_id + target` 的小时，遇到第一项不同任务 / 目标即停止，并把完整小时数组一次性交给正式修订。
- 三份计划 Prompt 已分别约束日计划、范围判别和正式修订：必须用 `game_time` 对照建筑总工期 / 剩余时间，只在预计完工前安排协助或受作业影响阶段。
- Godot 专项确认三小时连续 `drink_wine` 请求 `revision_hours=[8,9,10]`、第 11 小时不同任务不被修改、重复完成项触发真实重试、单小时与跨小时边界不变；五类标记行动的穷尽集合保持不变。
- Python Schema、Mock、endpoint、Prompt、行动合同和压缩合同回归，以及 Godot 日计划、修订、完成策略、建筑升级、协助经验回归全部通过。真实 DeepSeek `deepseek-v4-flash` 把 8–10 点三段 `assist_upgrade clinic` 全部改为 `work_clinic_doctor`，`fallback_used=false`，本次请求 6,391 input / 142 output tokens，估算 ¥0.00378988。
- Godot MCP 4.0.1 / Godot 4.6.2 运行态确认枚举、连续段 helper 与五类配置，编辑器错误为空。既有 GM 入口足够验证，未新增按钮或权威结算。

---

## T0092 LLM 等价上下文与响应合同精简

状态：Done
优先级：P0
前置任务：T0087, T0091
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `backend/README.md`, `DEV_LOG.md`

任务目标：

- 精简六类正式 LLM 调用中完全不影响人物判断、玩法功能和 Godot 最终成功响应的重复输入、固定回声字段与空占位。
- 供应商只返回真正需要模型选择的内容；`ok`、目标 NPC、请求日、响应分支、可由主决定推导的布尔值及计划候选固定元数据由后端确定性补齐。
- 保留人物设定、长短期记忆、守备官指令、实时建筑 / 资源 / 战场事实、动态行动白名单、有效叙事输出与所有程序权威校验。

验收标准：

- Godot 到后端的业务请求与后端到 Godot 的成功响应保持兼容；正式 provider 不再接收纯传输元数据、重复人物 / 轮次 / 资源 / 日记 / 战局副本或可省略的 `null`。
- 对话、日计划、范围判别、计划修订、战时心理和首次睡眠总结的 provider 输出合同只要求不可由请求或其他主字段确定的值；后端补齐的值仍通过既有完整响应 Schema 和业务校验。
- 日计划 / 修订的 `action_kind` 由命中的 `allowed_actions` 候选补齐，`priority` 使用程序默认值；`reason / summary / emotion` 及对话行动的 `dialogue_goal` 保留。
- Mock、Schema、endpoint、Prompt、Model Adapter 和 Godot 相关回归通过；若环境已有真实 Key，六类正式 provider 路径全部完成真实验收且 `fallback_used=false`。
- 用真实或同形 payload 对比记录精简前后字符 / token 体量；不以 Mock 伪装真实模型效果。

完成记录（2026-07-28）：

- Model Adapter 新增六类 provider request projection 与完整业务 response hydration；Godot / HTTP Schema 不变，模型不再负责固定回声、派生布尔值、即时行动或计划候选元数据。
- 日计划 / 修订可由唯一 `action_id + target_id` 候选补齐地点；只有候选地点有歧义时才要求模型返回 `location_id`。运行时默认 `planning_rules` 不再重复进入 payload，自定义附加规则继续保留。
- 六类样例输入字符减少 3.62%–11.49%，provider 输出字符减少 7.47%–61.30%；真实同 ID 对话与范围判别 input/output token 分别下降 5.70% / 27.50% 和 9.12% / 39.29%。
- Python 编译、17 个后端专项、7 个 Godot 专项、项目解析与 Godot MCP 检查通过；六类 DeepSeek `deepseek-v4-flash` 真实路径均成功且 `fallback_used=false`，未使用 Mock 伪装真实结果。

---

## T0091 `talk_to_npc` 目标驱动计划合同

状态：Done
优先级：P0
前置任务：T0025, T0049, T0050
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `backend/README.md`, `DEV_LOG.md`

任务目标：

- `talk_to_npc` 只由目标 NPC 决定，不要求模型选择或返回目标当下地点。
- Godot 继续在执行时读取并追踪目标 NPC 的实时地点；计划中的地点不得变成过期目的地或远程知识。
- 后端对该行动只校验 `action_id + target_id`，不因模型省略地点或多余返回目标当下地点而拒绝整份计划；规范化后的权威计划统一保存空地点。

验收标准：

- 日计划与正式修订的 `talk_to_npc` 候选不包含地点选择要求，Prompt 明确该行动只选目标 NPC。
- `PlanItem.location_id` 对其他固定地点行动保持原合同；仅 `talk_to_npc` 允许省略 / 空值，并将非空冗余地点确定性规范化为空且记录 normalization。
- 后端仍拒绝不存在、不可交谈或白名单外的目标，不放宽其他行动的 action / target / location 精确校验。
- Godot 执行 `talk_to_npc` 时仍动态解析目标当前位置并按既有规则最多重定向一次。
- Schema、Prompt、Mock / endpoint、Godot 计划目录与 NPC-NPC 行动回归通过；若环境已有真实 Key，使用真实 provider 验证工位占用后选择占用者交涉并成功落地，`fallback_used=false`。

完成记录（2026-07-28）：

- `LLMBridge` 的对话候选与正式 provider 请求均不再包含地点；DailyPlanSystem 只保存 `target_npc_id`，ActionSystem 继续按目标实时位置接近与追踪。
- 后端为 `talk_to_npc` 增加 action + target 专用匹配与地点规范化；白名单外目标、自聊、错误对话目的仍失败，固定行动的 action / target / location 精确合同未放宽。
- Python Schema / Mock / endpoint / Prompt 与 6 个 Godot 计划 / 对话专项通过；Godot 4.6.2 editor 解析通过，MCP 4.0.1 连接正常且编辑器无错误。
- 真实 DeepSeek `deepseek-v4-flash` 一次返回 `talk_to_npc -> priest_01 / location_id=null`，合并后 6 个工作阶段；NPC-NPC 邀请随后成功。两次均 `fallback_used=false`，未使用 Mock 或规则降级。

---

## T0090 开发期真实 LLM 日额度重置与请求预留校准

状态：Done
优先级：P0
前置任务：T0077, T0022
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `API_BUDGET.md`, `DEV_LOG.md`

任务目标：

- 清除上海时区 2026-07-28 的本地持久化 LLM 费用账本记录，使开发期今日额度归零，并保留可恢复备份。
- 根据截至清理前 347 次真实 provider 尝试的实测费用分布，降低 `LLM_DAILY_BUDGET_REQUEST_RESERVE_CNY`，避免 8 路开局计划因理论极端上界预留而误触发每日 ¥20 门禁。
- 保留每日 ¥20 硬上限、真实 provider、无自动 Mock fallback 和逐次实际 usage 结算。

验收标准：

- 清理前统计记录尝试数、总费用、均值、P95、P99 和最大单次费用；预留值的安全余量与风险有文档说明。
- 原费用账本存在独立备份；活动账本中上海时区 2026-07-28 的 `provider_usage` 记录为 0。
- 后端重启后 `/health` / `/debug/llm_usage` 显示今日已结算金额为 0、单次请求预留为新值、每日上限仍为 ¥20。
- 不删除其他日期记录，不输出或改动 API Key，不启用 Mock fallback。

完成记录（2026-07-28）：

- 清理前 347 次真实 provider 尝试总估算 ¥6.58959012，平均 ¥0.01899017，P95 ¥0.02998008，P99 ¥0.03258096，最大 ¥0.04262264；据此将当前 Flash 请求预留从 ¥1.77 调整为 ¥0.05。
- 停止本项目后端后备份完整账本，仅移除上海时区今日 347 条，保留其他日期 23 条；真实验收产生的 2 条、¥0.00327664 也在二次备份后清除。
- 更新 `.env`、示例配置、ModelAdapter 默认值、后端 README、预算专项和 API 成本文档；每日上限仍为 ¥20，真实 provider 与 `fallback=false` 保持。
- Python 编译、预算专项通过；真实 DeepSeek 私有边界对话成功且 `fallback_used=false`。验收脚本补充合法同义词“无从知晓”后通过。
- 后端重启后 `/health` / `/debug/llm_usage` 确认今日 0 次 / ¥0、在途 ¥0、剩余 ¥20、单次预留 ¥0.05。

---

## T0089 教堂行动失败后的弥撒 / 祈祷优先修订

状态：Done
优先级：P1
前置任务：T0043A, T0050
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- NPC 的普通祈祷因弥撒正在举行或弥撒开始而失败时，如果 `attend_mass` 当前可用，计划判别应选中当前小时，正式修订应强烈倾向改为参加弥撒。
- NPC 的参加弥撒因没有主持者或主持者离岗而失败时，如果 `pray_at_chapel` 当前可用，计划判别应选中当前小时，正式修订应强烈倾向改为普通祈祷。
- 两条规则都是符合现场语义的强倾向，不绕过实时候选、NPC 人格、状态、记忆、守备官指令或程序权威，不把转换写成无条件硬编码。

验收标准：

- 两份计划 Prompt 明确识别 `pray_failed_mass_in_progress / pray_failed_mass_started` 与 `attend_mass_failed_no_leader / attend_mass_failed_leader_left`。
- 对应替代行动当前可用时，第一层不得把本次失败判为无需修订；第二层应优先选择对应教堂行动，只有明确的人格、状态、记忆、指令或更紧迫现实原因才可选择其他合法行动。
- Prompt 合同、Mock / Schema / endpoint 与教堂 Godot 专项通过；若环境已有真实 Key，使用真实 provider 分别验证两个方向且 `fallback_used=false`。

完成记录（2026-07-28）：

- ActionSystem 在所有权威行动失败上下文中补入精确 `failure_id`，解决四个教堂失败进入 LLM 前只剩通用 `target_unavailable`、Prompt 只能依赖中文摘要猜测的问题。
- 范围判别对两个方向的现实可行替代固定选择当前小时；正式修订分别强烈优先 `attend_mass` 与 `pray_at_chapel`，但保留实时白名单、人物连续性、指令和紧急事实的否决空间。
- Prompt 合同、Schema、Mock Model Adapter、计划 endpoint、教堂依赖、行动目录、日计划与项目 smoke 回归通过。真实 DeepSeek `deepseek-v4-flash` 对两个方向各完成 1 次判别 + 1 次修订，全部首次成功且 `fallback_used=false`。
- Godot MCP 4.0.1 / Godot 4.6.2 运行态确认 `pray_failed_mass_in_progress` 时 `attend_mass.available_now=true`，`attend_mass_failed_leader_left` 时 `pray_at_chapel.available_now=true`，编辑器错误为空；既有 GM 入口足够验证，未新增按钮或权威结算。

---

## T0088 建筑工期信息、平缓时间显示与入伍友军颜色

状态：Done
优先级：P1
前置任务：T0043, T0058, T0065, T0072, T0086
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `DEV_LOG.md`

任务目标：

- 建筑开始修复或升级时，在建筑状态传播与 NPC 计划上下文中提供本次作业总工期，并使用“小时/分/秒”的可读格式。
- 建筑面板把修复/升级剩余秒数换算为可读时长；正常 `x1/x2/x4` 下秒位冻结为 `00`，LLM 调用降速期间恢复精确秒数。
- 主界面时钟在正常 `x1/x2/x4` 下仅推进分钟、秒位显示 `00`；LLM 调用降速期间恢复显示游戏秒。
- 其他持续刷新的剩余时间显示沿用同一秒位策略，避免正常速度下快速跳字。
- NPC 入伍后，主场景名称与 NPC 面板名称改为淡绿色；未入伍名称维持原色。

验收标准：

- 修复/升级开始事件与 NPC 可读建筑状态均含总工期可读文本，不以裸秒数作为 NPC 信息。
- 建筑面板修复/升级状态与按钮显示 `x小时x分x秒`；正常速度秒位为 `00`，LLM 降速时显示实际秒。
- HUD 时钟与波次剩余时间在正常速度下秒位固定为 `00`，进入/退出 LLM 降速时立即切换显示策略。
- 入伍状态变化后，场景内与 NPC 面板中的名称立即刷新为淡绿色。
- Godot 无新增脚本错误，相关自动化与真实 provider 验证（环境可用时）通过。

完成记录：

- TimeSystem 统一正常速度分钟精度与 LLM 慢速秒精度；HUD 时钟、波次倒计时及建筑修复 / 升级剩余时间在慢速请求进入 / 退出时立即刷新。
- BuildingSystem 同时保留权威秒数和玩家 / NPC 可读时长；MemorySystem 只传播稳定总工期，不逐秒广播剩余时间；LLMBridge active job 上下文只投影可读总工期与剩余时间。
- 世界 NPC 姓名与状态拆为两个 Label3D，入伍后仅姓名变为淡绿色；NPC 面板姓名同步使用相同颜色。
- 时间、建筑、地点信息、动态上下文、NPC 面板、Schema 与 Prompt 基础回归通过；真实 DeepSeek 升级协助三条业务路径均 `fallback_used=false`。Godot MCP 实机确认正常 / 慢速两套显示与入伍颜色，编辑器错误为空。

---

## T0087 按对话类型拆分 LLM 输出合同并删除失效意图

状态：Done
优先级：P0
前置任务：T0067, T0072, T1201, T1204A, T0029, T0030
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `TECH_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 删除当前设计与 Godot 运行态均不消费的 `request_money`、`request_equipment`、`request_rest`、`request_treatment`、`share_witness`、`start_escape` 对话意图。
- 不再让 `player_npc`、`npc_npc` 与 `escape_intervention` 共用包含全部可选字段的单一响应模型；按对话类型拆分 Pydantic 输出合同和模型字段提示。
- 玩家普通 / 应征对话只返回玩家对话需要的文本、应征结果与战时反应；征召权威只读取 `recruitment_result`，不再要求重复的 `accept_recruitment / reject_recruitment` intent。
- NPC-NPC 邀请 / 正式对话只返回邀请结果与 `should_end_dialogue`；正式续聊和结束继续由 `should_end_dialogue` 唯一控制。
- 逃离挽留只返回独立的留下 / 继续逃离结果；Godot 不再从通用 `intent` 解析该分支。

验收标准：

- 三种 `dialogue_kind` 分别通过自己的响应 Schema 校验，输出其他分支字段或已删除意图时明确拒绝并写入真实校验原因。
- 应征 `accept / reject` 不再依赖第二个重复 intent，布鲁诺式“拒绝结果 + 仍愿继续交谈的文本”可作为合法拒绝回复应用。
- NPC-NPC 邀请接受 / 拒绝、正式自动续聊 / 收尾仍只由 `invitation_result` 与 `should_end_dialogue` 控制。
- 逃离挽留留下、继续逃离与第 5 轮自动收口保持既有程序行为。
- 基础 Schema、Mock endpoint、Prompt、业务合同和 Godot 对话专项回归通过；若环境已有真实 Key，再分别验证玩家应征、NPC-NPC 与逃离挽留真实 provider 输出，且 `fallback_used=false`。

完成记录：

- 三类 Pydantic 响应均使用 `extra="forbid"`；旧 `intent` 与跨分支字段会在 HTTP 层返回 `model_output_invalid`，不再进入 Godot。
- 玩家应征只校验 `recruitment_result`，NPC-NPC 只校验 `invitation_result / should_end_dialogue`，逃离挽留只校验并消费 `escape_intervention_result=stay|leave`。
- Schema、Mock adapter、Prompt、Mock endpoint、业务合同和 Godot 对话专项全部通过；真实 DeepSeek 覆盖玩家、NPC-NPC、邀请接受 / 拒绝和逃离分支，最终验收均为 `fallback_used=false`。

---

## T0086 提前完成计划行动的当前小时重估与倍速快捷键

状态：Done
优先级：P1
前置任务：T0050, T0075, T0076, T0081, T0085
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 对会在当前小时内提前完成并留下较长空闲的计划行动增加数据驱动标记；协助修理、协助升级、协助治疗、接受诊所治疗与饮酒完成后，若当前小时仍是该计划项，直接重估当前小时并在修订成功后立即执行新行动。
- 成功完成重估不经过“是否需要修改”判别层；重估结果不得在同一小时原样重复已经完成的行动，仍可从正常合法行动候选中选择工作、休息、协助、交谈等活动。
- 完成回调延迟到权威时钟更新后再确认日 / 小时、计划项、NPC 空闲与可行动状态；若已跨小时，则由正常小时开始调度接管，不对旧小时发起陈旧重估。
- 审计其他计划行动：重复生产与持续服务沿用既有续作策略；吃饭、睡觉、祈祷、弥撒、拜访等常规或整小时活动不新增完成重估；NPC 交谈和主动找守备官交涉沿用既有对话后重估。
- HUD 默认支持主键盘数字行 `1` / `2` / `3` 直接切换 `x1` / `x2` / `x4`；不响应小键盘数字，也不在文本输入控件聚焦时抢占按键。

验收标准：

- 五类配置标记行动成功完成后仅发起一轮当前小时正式计划修订，payload 使用明确的完成原因、只允许修改当前小时，并携带已完成计划项与结果。
- 当前小时新计划落地后立即执行一次；重复生产、持续行动及未标记的一次性行动行为不变。
- 若行动完成时权威时间已经跨小时，不发送旧小时完成重估，由当前小时正常计划调度接管。
- 自动化验证五类配置清单、特殊完成结果识别、完成后重估 / 立即执行、跨小时去重和主键盘倍速快捷键；Godot MCP 连接正常且运行时无新增错误。
- 基础 Schema / Mock / Prompt 测试通过；若环境已有真实 Key，再验证 `action_completed` 业务路径且 `fallback_used=false`。

验收结果：

- 五类行动配置、不同成功结果识别、完成后单链直接修订、原样重复拒绝 / 真实重试、合法新行动即时执行和跨小时由新计划接管均通过 Godot 专项；T0075 完成策略、T0085 升级结束、T0081 协助有效经验与时间系统回归通过。
- Python Schema、Mock Model Adapter 与计划修订 Prompt fake-provider 测试通过。真实 DeepSeek `deepseek-v4-flash` 一次完成 `action_completed` 修订，把已完成的 `drink_wine` 改为 `work_clinic_doctor`，`fallback_used=false`。
- Godot MCP 4.0.1 / Godot 4.6.2 连接与版本匹配；运行态真实注入主键盘物理键 `3` 后倍率与按钮均为 `x4`，小键盘直调不改变倍率，编辑器错误为空。既有 GM 入口足够验证，未新增按钮或权威结算。

---

## T0085 修复升级协助完成后的计划重估并软化工作阶段下限

状态：Done
优先级：P0
前置任务：T0050, T0075, T0080
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 修复包含 `assist_upgrade` 的计划在建筑升级完成后工作阶段计数变成 0，导致合法修订被后端反复拒绝并保留旧计划的问题。
- 修复升级协助再次投影到 LLM payload 时把室外执行地点错误写成目标建筑，以及目标失效重估复用旧行动失败上下文的问题。
- “每天至少 6 个工作阶段”只保留为日计划 / 修订 Prompt 的强建议和调试统计，不再作为后端或 Godot 接受计划的硬门槛；NPC 可因现场变化形成少于 6 个工作阶段的合法计划。

验收标准：

- `LLMBridge`、`DailyPlanSystem` 与后端对 `assist_upgrade` 的工作阶段统计一致；升级完成后旧升级协助阶段仍能作为历史工作阶段正确计数。
- `assist_upgrade` 往返计划 Schema 后保持 `target_id=<building>`、`location_id=plaza`。
- 目标已解决 / 不可用的计划项产生本轮真实失败上下文，不复用此前建筑升级中断的陈旧上下文。
- `/npc/plan_day`、`/npc/revise_plan` 和 Godot 本地计划应用不再因为工作阶段少于 6 个拒绝合法计划；Prompt 仍明确建议通常至少安排 6 个工作阶段。
- 新增自动化覆盖诊所升级完成后 `assist_upgrade -> work_clinic_doctor` 的受限修订、软工作下限、地点投影与失败上下文；基础 Mock / Schema / endpoint、Godot 计划与升级相关回归通过。
- 若环境已有真实 Key，在基础测试通过后用真实 provider 验证对应业务路径，且 `fallback_used=false`。

验收结果：

- Python 契约、Schema、日计划 / 修订 endpoint、两份计划 Prompt 和范围判别回归通过；0 工作阶段完整日计划与低工作量修订均被接受。
- Godot 专项确认 `assist_upgrade` 计数与 Schema 往返地点正确，诊所升级完成后只产生一轮 `no_active_upgrade` 判别，并成功把当前小时改为 `work_clinic_doctor`；日计划、重估、行动失败与建筑升级相关回归通过。
- 真实 DeepSeek `deepseek-v4-flash` 完成升级结束修订，返回 `work_clinic_doctor @ clinic`，`fallback_used=false`；Godot MCP 连接正常且编辑器错误为空。

---

## T0084 按叙事到站顺序固定 NPC 宿舍床位

状态：Done
优先级：P1
前置任务：T0043, T0061
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `DEV_LOG.md`

任务目标：

- 为 8 名初始 NPC 固定宿舍床位，睡觉时始终申请自己的床，不再按当次空闲顺序重新分配。
- 按既有叙事到站顺序分配床位 1–8：艾达、托马、布鲁诺、伊沃、格伦、欧文、马塞尔、莉娜；床位 9–10 保留为空余床位。
- 床位归属由建筑配置与 BuildingSystem 权威维护，ActionSystem 只申请分配结果，UI 只读显示，不在 GDScript 中按姓名写死。

验收标准：

- 每名初始 NPC 连续两次睡觉都占用同一个配置床位；无论其他 NPC 先后睡觉，归属不变化。
- NPC 不能占用其他初始 NPC 的专属床位；无专属床位的未来 NPC 只能申请未分配床位。
- 点击宿舍时，BuildingPanel 可直接看到床位 1–8 的归属以及当前空闲 / 占用状态，床位 9–10 显示为空余床位。
- 睡眠完成、中断、建筑升级封闭和失败流程仍只释放当前占用，不清除固定归属。
- 固定床位专项、建筑位置 / 面板、睡眠 / 结构化事件和项目 headless 回归通过；Godot MCP 运行态确认床位归属与错误日志为空。

验收结果（2026-07-28）：

- `building_defs.json` 为床位 1–8 配置 `assigned_npc_id`，顺序为艾达、托马、布鲁诺、伊沃、格伦、欧文、马塞尔、莉娜；床位 9–10 不配置归属。
- `BuildingSystem.claim_workstation(...)` 对有专属位置的 NPC 只尝试该位置，对没有专属位置的 NPC 跳过全部专属床；`release_workstation(...)` 继续只清除 `occupied_by`。ActionSystem 睡眠生命周期不维护第二份床位表。
- BuildingPanel 直接显示 1–8 号床的专属 NPC 和空闲 / 占用状态，9–10 号显示“空余床位”；功能前端可见，未新增 GM 入口。
- 新增 `verify_fixed_dormitory_beds.gd`，覆盖叙事顺序、乱序并发、重复申请、未来 NPC 只用空余床、真实睡眠两次复用同床、释放后归属保留和面板文案。
- 固定床位、建筑面板、五建筑位置、基础行动、结构化事件、日计划、首次睡眠总结及项目 headless 回归全部通过。Godot MCP 4.6.2 冻结运行确认布鲁诺连续两次均使用 `dormitory_bed_03`、占用文案正确且编辑器错误为空；验证后已恢复 `startup_mode=1`。
- 本任务未修改 Prompt、后端或模型行为，不调用真实 provider，也不增加 API 成本。

---

## T0083 精简守备官对话事件标题并强化应征结果反馈

状态：Done
优先级：P0
前置任务：T0082, T0072
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 将完成后的守备官-NPC 单事件全文摘要标题从“守备官与 XX 的完整对话”精简为“守备官与 XX 对话”，不改变逐句正文、单事件边界或 NPC-NPC 逐轮入库规则。
- 后端已有 `recruitment_result=accept|reject` 返回时，把结果绑定到对应 NPC 历史回复，并在该回复正下方显示独立结果行：接受为绿色对勾，拒绝为红色叉号。
- 结果提示只作为结构化结果的前端表现，不混入 NPC `reply_text` 或事件逐句对话正文；普通回复和无应征结果的回复不显示提示。

验收标准：

- 完成守备官与托马的多轮对话后，事件摘要以“守备官与托马对话：”开头，不再包含“完整对话”，且仍按原顺序包含所有发言。
- 应征接受回复下方显示绿色“✓ NPC名接受了守备官的应征请求”；拒绝回复下方显示红色“× NPC名拒绝了守备官的应征请求”。
- 接受 / 拒绝提示与产生结果的具体 NPC 回复绑定；后续普通回复不会误显示或覆盖历史结果，事件全文只转写真实发言文本。
- 对话 UI、对话会话生命周期、结构化记忆、NPC 面板及项目 headless 自动化通过；Godot MCP 运行态确认富文本提示、精简事件标题与编辑器错误为空。
- 功能可直接在 `Main.tscn` 对话窗和 NPC 事件库中验证，既有 GM 事件查询足够辅助观察，不新增重复入口。

验收结果（2026-07-28）：

- `MemorySystem` 完成会话标题改为“守备官与 XX 对话”；两轮四句仍只写一条事件，summary 正文继续逐句转写真实 `dialogue_text`。
- `DialogSystem` 只在合法应征响应上给对应 NPC turn 写入 `recruitment_result`；`DialogPanel` 在同一回复块下一行渲染绿色 `✓` 接受或红色 `×` 拒绝，不修改 `reply_text`。
- `verify_dialogue_ui.gd` 覆盖布鲁诺接受与托马拒绝的精确 BBCode；`verify_dialogue_session_lifecycle.gd` 覆盖“守备官与托马对话：”精确标题并禁止旧“完整对话”字样。
- 对话 UI、会话生命周期、结构化记忆、NPC 面板交互 / 状态及静态主场景 headless smoke 全部通过。
- Godot MCP 4.6.2 冻结运行确认两种颜色 / 符号、逐回复结果、精简事件标题、事件正文只含真实发言，编辑器错误为空。验证后 `startup_mode=1` 已恢复，显式 Mock 服务已关闭。
- 本任务未修改后端、Prompt 或模型判断，未调用真实 provider、未增加 API 成本；功能前端可见，未新增 GM 入口。

---

## T0082 修复守备官多轮对话事件显示与应征会话锁

状态：Done
优先级：P0
前置任务：T0051, T0072
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 排查守备官与 NPC 完成多轮对话后，NPC 事件库只显示最后一轮的问题；保留“整场会话只提交一条 `dialogue_turn`”的事件边界，并让该事件的确定性摘要完整呈现会话中的每一句。
- 一次守备官-NPC 会话内，只要玩家曾在“提出应征”开启时发送消息，本场会话的“取消对话”立即禁用且系统入口拒绝取消，只允许完成或挂起；挂起超时按完成收口，不能绕过应征会话锁。
- “提出应征”在当前会话内改为持续开关：开启并发送后保持开启，后续消息默认继续携带应征标记，直到玩家主动关闭或会话结束。

验收标准：

- 两轮守备官-NPC 对话完成后仍只新增一条 `dialogue_turn`，其 `payload.dialogue_text` 与事件 `summary` 都按顺序包含两轮共四句；NPC 面板事件库 / 详情可直接看到完整对话。
- 首次携带应征标记的消息一经发送，取消按钮立即半透明禁用；即使玩家随后关闭应征 toggle，系统取消入口仍拒绝本场会话。
- 应征 toggle 发送后不自动复位；拒绝后继续开启时，下一次发送仍带 `is_recruitment_request=true`。主动关闭后，后续消息恢复为普通对话。
- 应征锁定会话挂起 2 个游戏小时后自动完成并入库；主动交涉、攻击、逃离挽留和 NPC-NPC 对话既有边界不回归。
- 对话生命周期、对话 UI、结构化记忆、NPC 面板及项目 headless 自动化通过；Godot MCP 运行态确认按钮、toggle、完整事件摘要与编辑器错误为空。

验收结果（2026-07-28）：

- 根因确认：完成两轮会话后 `payload.dialogue_text` 已有四句，数据未丢；但 `MemorySystem` summary 只读取 `last_player_text / last_reply_text`，而 NPCPanel 只展示 summary，因此事件库和摘要型短期记忆只看见最后一轮。
- `MemorySystem` 现对 `session_completed=true` 的守备官会话按 `dialogue_text` 原顺序逐句生成全文；仍只写一条 `dialogue_turn`、只广播一次。`DialogSystem` 保持会话内应征开关，并在第一次应征消息发送后用 `session_had_recruitment_request` 锁定取消；`DialogPanel` 同步 disabled / tooltip，挂起超时按完成。
- `verify_dialogue_session_lifecycle.gd` 新增两轮四句单事件、NPC 事件库详情全文、下一轮默认应征、主动关闭恢复普通消息、关闭后仍不可取消和挂起超时完成；`verify_dialogue_ui.gd` 更新 sticky 与 UI 锁断言。
- 对话生命周期、对话 UI、结构化记忆、短期记忆、NPC 面板、主动交涉、战时对话、逃离挽留、玩家对话计划恢复和项目 headless 全部通过。
- Godot MCP 在静止调试 + 显式 Mock 后端下确认：应征发送后 toggle 保持开启、取消 disabled、tooltip 正确、系统取消失败；两轮四句完成后事件数为 1、payload 为 4 句，事件详情逐句显示全文，编辑器错误为空。验证后已恢复 `startup_mode=1` 正式启动配置。
- 本任务未修改 Prompt、Schema、后端接口或模型输出效果，不需要新增真实 provider 语义验收。首次按正式主场景配置启动 MCP 时自动触发现有 8 路 DeepSeek 日计划，账本日尝试从 172 增至 180、估算费用增加约 ¥0.125404；后续专项均切到静止调试和 Mock，未再产生无关真实调用。

---

## T0081 统一持续行动生活消耗与协助工作经验

状态：Done
优先级：P0
前置任务：T0305, T0503, T0801, T0808, T0903, T0904, T1103
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 建立配置化、按有效逻辑时间持续结算的 NPC 生活消耗权威框架，统一覆盖工作、训练、协助、休息、治疗、饮酒、祈祷、对话、移动、集结、避战、战斗、逃离和等待，移除 ActionSystem 中按行动各自重复结算饱食 / 疲劳的旧路径。
- 以现有普通工作每小时饱食 `-3/-4`、疲劳 `+6/+8` 为劳动基准，按活动强度和常识配置各类每小时速率：工作 / 训练 / 协助、对话 / 移动、休息类、等待类和战斗类分别使用明确档位；吃饭继续恢复饱食并小幅增加疲劳，睡眠 / 病床治疗 / 饮酒 / 祈祷消耗饱食并降低疲劳。
- 协助修复、协助升级和协助治疗按真实有效参与时长累计对应工程 / 医术经验；未开始、暂停、离岗、目标已解决和无效协助时间不得获得经验。
- 新增穷尽 `data/action_defs.json` 全部行动定义和全部程序行为模式的自动化测试，保证每项都有且只有一个生活消耗档位，工作 / 训练 / 协助类声明经验规则，其他行动不得误加经验。

验收标准：

- 所有在站、可模拟 NPC 在非暂停逻辑时间内始终能解析到唯一生活消耗档位；暂停、LLM 慢速、玩家加速和敌人在场倍率上限继续服从 TimeSystem 的有效逻辑时间。
- 普通工作、训练和三类协助持续扣饱食并增加疲劳；睡眠、病床治疗、饮酒、祈祷持续扣饱食并降低疲劳；对话、移动、集结、避战、逃离持续扣饱食并增加疲劳；等待以最低非零速率扣饱食并增加疲劳；战斗速率显著高于普通工作。
- 旧工作 / 训练 / 睡眠状态变化不重复结算；吃饭恢复量保持餐食 `+50`、粮食 `+25`，并按进餐时长小幅增加疲劳。
- 六类普通职业工作、诊所医生、训练教官 / 受训者与三类协助均进入统一成长规则；协助修复 / 升级增加工程经验，协助治疗增加医术经验，其他行动不增加经验。
- 穷尽行动目录测试、生活消耗专项、协助经验专项、既有行动 / 训练 / 诊所 / 建筑 / 治疗 / 战斗 / 时间回归和项目 headless 加载通过；Godot MCP 运行态确认关键档位、暂停边界和编辑器错误为空。
- 现有 GM 通用指定行动、推进时间、建筑修复 / 升级、治疗目标、战斗与 NPC 状态入口足够构造并观察所有档位，不新增重复按钮或命令；同步补充 GM 验证说明。

验收结果（2026-07-28）：

- 新增 `data/activity_needs.json` 与 `Main/Systems/NPCNeedsSystem`，统一按有效逻辑秒结算饱食 / 疲劳、小数余量、0–100 边界和有限行动的真实剩余时长；25 个 `action_defs` 行为全部改用唯一 `needs_profile`，旧工作 / 训练 / 睡眠状态扣除字段与训练整小时扣除函数已移除。
- 轻 / 重工作沿用 `-3/+6`、`-4/+8`；移动、集结、避战、逃离、战斗、空闲、对话、吃饭、睡眠、病床、祈祷、饮酒与昏迷休息已配置独立速率。移动按消耗饱食并增加疲劳实现，不采纳需求末句与前文冲突的“移动减少疲劳”。
- `assist_repair / assist_upgrade / assist_heal` 新增 `timed_experience`。统一框架只把建筑作业完成前、目标复苏前的有效秒数交给 ActionSystem；每 3600 秒分别增加工程 / 工程 / 医术 1 点并进入既有总经验。
- 新增 `verify_activity_needs_framework.gd`，动态穷尽 25 个行动、6 种程序行为模式、旧字段清零、档位符号 / 强度、工作经验资格和精确数值；新增 `verify_assist_timed_experience.gd`，覆盖三类协助、分段累计、非工作无经验及治疗中途复苏截断。
- 专项以及 `verify_action_system_basic.gd`、`verify_training_system.gd`、`verify_clinic_treatment.gd`、`verify_npc_unconscious_healing.gd`、`verify_skill_progression.gd`、`verify_time_system.gd`、`verify_npc_movement_location.gd`、`verify_combat_flow.gd`、`verify_avoid_combat_mode.gd`、`verify_escape_station_behavior.gd`、`verify_plan_extended_actions.gd`、`verify_tavern_wine_trade.gd`、`verify_dining_hall_meals.gd` 与项目 headless 加载通过。Godot MCP 4.6.2 已确认 25 项载入、0 配置错误和新系统节点存在；现有 GM 入口足够，未新增按钮 / 命令。

---

## T0080 建筑门口失败重估与升级协助认知修复

状态：Done
优先级：P0
前置任务：T0050, T0057, T0058
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 修正 T0057 的 pending 行动时序：建筑开始升级时，只立即中断已经在建筑内执行的依赖行动；仍在路上的 NPC 不应隔空得知升级，而应继续到达建筑入口，在程序确认无法进入后才以“建筑正在升级”失败并触发统一计划重估。
- 修复 NPC 对升级协助的理解：动态 `assist_upgrade` 候选必须明确表示行动在建筑外 / 广场执行、不需要进入正在升级的建筑，并作为有效劳动计入日计划最低工作阶段。
- 保持 BuildingSystem、ActionSystem、DailyPlanSystem 与 LLM 的权威边界；LLM 只选择合法行动，不直接结算升级或强制指定 NPC 协助。

验收标准：

- pending 工作在目标建筑开始升级后仍保持移动，未到门口前不写行动失败、不发起 `action_failure` 判别。
- NPC 到达升级建筑入口后不能进入，逻辑地点落在广场 / 室外；ActionSystem 写入包含行动、建筑、`condition=upgrading`、`interrupted_phase=pending`、中文摘要和到达失败事实的唯一最终失败，然后 DailyPlanSystem 才触发两段式重估。
- 已在建筑内的 active 依赖行动仍在升级开始时立即失败、释放位置并清退到广场；协助升级自身不被封闭规则误杀。
- 六类动态候选中的 `assist_upgrade` 明确携带室外执行、不需入内、当前可用的上下文；日计划与修订的工作阶段统计把协助升级视为劳动，Godot 与后端校验一致。
- 基础 Mock / Prompt / Schema、Godot 专项与相关回归通过；环境已有真实 Key 时，用真实 provider 验证 NPC 能明确说出“无需进入建筑即可协助”，并在同建筑工作失败的修订中实际选择 `assist_upgrade`，且 `fallback_used=false`。
- 现有 GM“指定行动 → 升级 → plan_request / 最近行动结果”足以构造和观察链路，不新增重复入口；同步更新 GM 验证说明。

验收结果（2026-07-28）：

- BuildingSystem 发出升级状态后，ActionSystem 只立即处理 active 依赖行动；目标相同的 pending 运行态和移动目标保持不变。NPCSystem 在真实到达入口时重新查询可进入性，失败后落在广场并通过新增 `npc_building_entry_failed` 交给 ActionSystem 生成唯一最终失败，避免普通清退中间状态抢占重估。
- `failure_context` 区分门口 pending 与室内 active：前者包含 `arrival_check_failed=true / interrupted_phase=pending` 和“到达入口后发现建筑正在升级”的摘要；后者继续在升级开始时立即释放工位并以 `interrupted_phase=active` 失败。
- `assist_upgrade` 候选明确为广场 / 室外执行、无需进入、当前可用、计为工作阶段；LLMBridge 的 `current_building_states.is_upgrading / is_repairing` 改用 BuildingSystem 实时接口。DailyPlanSystem 与后端日计划 / 修订最低工作量校验均认可该行动。
- Python Schema、Mock adapter、四类 Prompt、日计划 / 修订 endpoint 与 Godot 升级失败、动态上下文、日计划及建筑回归通过；项目 headless 加载通过。真实 DeepSeek 对话明确愿意在广场协助，正式修订实际选择 `assist_upgrade -> workshop / plaza`，均 `fallback_used=false`。
- Godot MCP 4.6.2 冻结 Main 验证路上 pending 未失败、模拟抵达门口后才失败并清退、室内 active 在升级开始时立即失败；运行态候选与建筑升级布尔值正确，编辑器错误为空。现有 GM 组合足够复现，未新增入口。

---

## T0079 合并 NPC 当前计划连续行动并隐藏重复说明

状态：Done
优先级：P1
前置任务：T0023, T0066
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `GODOT_ARCHITECTURE.md`, `UI_UX.md`, `DEV_LOG.md`

任务目标：

- NPC“当前计划”详情中，若计划项 `reason` 去除首尾空白后与行动显示名完全相同，不显示重复的第二行说明。
- 将小时连续、行动与展示语义完全一致的相邻计划项合并为一个时间段，例如 `13:00–16:00  酿造酒｜真实 LLM 日计划`。
- 合并只影响 UI 投影，不修改 24 小时权威计划、Prompt、Schema、来源标记或计划执行。
- 当前小时落在合并时段内时，该时段显示当前项标记；首次打开仍从当前时段之前第二个可见计划行动开始。

验收标准：

- 相同 `action_id / action_name / source / target / priority / dialogue_goal` 且可见 `reason` 相同的连续小时合并；时间不连续或任一展示语义不同则保持分开。
- `reason == action_name` 时只显示行动标题，不显示同文第二行；不同说明继续显示。
- 当前小时标记、首次打开定位、计划更新时刷新、0 点 / 1 点边界和原始 24 小时计划内容保持正确。
- 更新 NPC 面板专项自动化并通过项目加载与 Godot MCP 运行态检查；功能可从 `Main.tscn` 直接验证，不新增 GM 入口。

验收结果（2026-07-28）：

- `NPCPanel` 先把 24 小时计划投影为可见分组：只有相邻小时连续，且 action id / name / kind、source、target、priority、可见 reason、dialogue goal 全部一致时才合并；不同说明、目标或来源不会被吞掉。
- `reason.strip_edges() == action_name` 时只在显示层置空说明；权威计划仍保留原始 `reason`。当前小时命中区间内任一小时都会给整段加 `▶`。
- 首次打开滚动改为按可见分组寻找当前时段及其前两项；00:00 / 01:00 落在 00:00–05:00 合并段时仍从首行开始。计划替换后的打开中刷新与不同说明拆段均已覆盖。
- `verify_npc_panel_state.gd`、`verify_npc_panel_interactions.gd`、`verify_daily_plan_system.gd` 和项目 headless 加载通过。Godot MCP 4.6.2 冻结运行确认 `▶ 13:00–16:00  酿造酒｜真实 LLM 日计划`、行动名仅出现一次、重复说明不存在，编辑器错误为空。
- 本任务只改 UI 与测试，没有修改 Prompt、Schema、后端、LLM 输出或计划执行；功能可直接从 `Main.tscn` 验证，未新增 GM 入口。

---

## T0078 NPC 主动交涉完成后的当前小时重估与不可取消会话

状态：Done
优先级：P1
前置任务：T0049, T0051, T0076, T0705
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `UI_UX.md`, `GM_PANEL.md`, `DEV_LOG.md`, `backend/README.md`, `backend/schemas/README.md`

任务目标：

- NPC 按当前小时 `seek_guard_officer` 计划主动找守备官交涉并完成有效会话后，计划修改判别必须包含结束时当前小时；正式修订继续从正常动态候选中安排工作、休息、拜访、其他对话等后续活动，并沿用 T0076 当前小时立即派发合同。
- 只对 NPC 发起的守备官会话禁用取消：取消按钮半透明不可点击，悬停提示“驿站成员主动交涉不可取消对话”；DialogSystem 权威入口也必须拒绝取消。守备官主动发起的普通会话仍可取消，攻击后的既有不可取消边界保持不变。
- NPC 主动交涉允许完成或挂起；不可取消的挂起会话到期后按完成收口、保存会话并进入计划判别，不能经超时绕过不可取消合同。
- 本任务不增加跨小时 / 跨日延续规则，不改变 `seek_guard_officer` 的等待气泡时长或无人响应超时修订逻辑。

验收标准：

- 当前计划项为 `seek_guard_officer` 且会话由 NPC 发起时，完成后的判别请求固定携带 `required_revision_hours=[当前小时]`；当前计划不是该行动时仍按普通守备官对话独立判断。
- NPC 发起会话中，取消按钮 disabled 且 tooltip 正确，直接调用取消接口返回明确错误；守备官发起会话仍可正常取消。
- required 当前小时的正式修订成功后立即开始新行为；暂时阻塞时沿用可靠 deferred marker。
- 主动交涉专项、普通会话生命周期、UI、Schema / Prompt / Mock、真实 provider 与 Godot MCP 运行态验证通过。

验收结果（2026-07-27）：

- `seek_guard_officer` 主动会话完成时固定请求当前小时；真实模型遗漏 required 时由 HTTP 层保留其他合法选时并权威归并当前小时，正式修订成功后通过统一派发立即开始新行动。
- 主动交涉取消键 disabled，tooltip 为“驿站成员主动交涉不可取消对话。”；DialogSystem 直接取消返回 `dialogue_cancel_locked_by_npc_initiator`。守备官主动普通会话仍可取消，主动会话挂起超时按完成入库。
- 主动交涉、会话生命周期、当前小时派发、NPC-NPC、玩家对话恢复、GM、Schema / Prompt / Mock、项目解析及 diff 检查通过。真实 DeepSeek 的两种 required 判别、当前小时正式修订与既有失败链均一次成功、无 fallback。
- Godot MCP 4.0.1 / Godot 4.6.2 冻结运行确认会话状态、按钮 disabled / tooltip 和系统取消锁，编辑器错误为空；功能可直接从 `Main.tscn` 验证，未新增 GM 入口。

---

## T0077 LLM 完整用量审计、每日 20 元硬预算与 GM 运行成本顶栏

状态：Done
优先级：P0
前置任务：T0069, T1406
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`, `backend/README.md`

任务目标：

- 核验并保留每次 LLM 调用的完整输入、正式供应商请求体、响应、UTC 时间、重试序号、token usage、费用估算与失败信息；请求头和 API Key 必须继续脱敏 / 不落盘。
- 按 DeepSeek V4 Flash 官方人民币价格分别核算缓存命中输入、缓存未命中输入与输出 token；每次正式供应商尝试都必须计费，不能只统计最终成功结果。
- 增加按 `Asia/Shanghai` 自然日持久化的人民币硬预算，默认每日最多 20 元；在供应商请求发出前做并发安全的费用预留，后端重启后仍从当日已用金额继续拦截，超限返回 `budget_exceeded`，不伪装为 Mock 成功。
- GM 面板最上方持续显示本次后端运行累计输入 / 输出 / 总 token、人民币估算，以及今日持久化费用 / 20 元上限；刷新不得阻塞游戏主线程。
- 补充后端持久化 / 重启 / 重试 / 并发预算测试、GM 自动化验证和 Godot MCP 运行检查；若环境已有真实 Key，完成一次受预算保护的真实 provider 验收。

验收标准：

- `/debug/llm_usage` 同时返回本次后端进程 provider 尝试累计与按日持久化账本；重建 ModelAdapter 后当日金额和 token 不清零。
- 每次正式 HTTP 尝试的 DeepSeek `prompt_cache_hit_tokens`、`prompt_cache_miss_tokens`、`completion_tokens` 都进入账本和审计；重试不会漏算。
- 当日已用金额加在途预留达到 20 元时，请求在发给供应商之前失败，HTTP 业务接口返回 429 / `budget_exceeded`。
- 打开 GM 面板后，顶栏无需点击“成本统计”即可异步更新本次运行 token / 人民币与今日预算。

验收结果（2026-07-27）：

- T0069 JSONL 审计复核通过：完整输入、正式 messages、聚合响应、UTC 时间、重试、原始正文、usage 和最终状态均可按 audit id 关联；Authorization / API Key 继续不落盘。
- 新增逐 provider 尝试持久化账本，V4 Flash 默认按官方人民币价 `0.02 / 1 / 2 元每百万 token` 结算；上海自然日重建 adapter 后仍保留当天 token / 费用。单次 ¥1.77 并发预留与每日 ¥20 上限在 HTTP 前拦截，账本 / 定价异常失败关闭。
- GM 顶栏异步显示本次后端运行输入 / 输出 / 总 token、人民币估算和今日金额 / 上限；既有完整成本统计入口保留。
- Python 编译、Schema、Mock adapter、Mock endpoint、审计、预算持久化 / 重启测试、GM 专项和项目 headless 均通过。真实 DeepSeek 对话返回 200、0 fallback，输入 5,827 / 输出 180 / 估算 ¥0.00330188；Godot MCP 运行态顶栏格式和编辑器无错误验证通过。

---

## T0076 NPC 对话跨小时延续与重估后当前行动立即派发

状态：Done
优先级：P1
前置任务：T0025, T0049, T0050, T0053, T0075
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `GM_PANEL.md`, `DEV_LOG.md`, `backend/schemas/README.md`

任务目标：

- NPC 按日计划主动找另一名 NPC 对话后，发起者必须进入计划修改判别，并保证判别至少选中结束时的当前小时；正式修订仍从正常动态候选中选择工作、休息、对话等可执行活动。
- 普通整点到来时，日计划发起且仍在赶路、等待、邀请或正式交谈中的 NPC-NPC 对话继续完成，不被下一小时计划强制打断；对话结束后再执行结束时当前小时的新计划。
- 统一所有计划重估的当前小时落地语义：只要成功修订包含结束时当前小时，就在对话 / 批次屏障和行为模式允许后立即派发一次新行为；暂时不能派发时保留可靠的延迟执行标记，不让 NPC 因一次状态信号或跨小时清理而永久站立。
- 跨日、战斗 / 逃离 / 昏迷等高优先级权威模式继续拥有中断权；对话失败沿用结构化失败与两阶段重估，不绕过合法性、位置、目标、资源和每小时单次行为约束。
- 替换与旧 T0053 普通跨小时失效口径绑定的 GM 入口和自动化，补充跨小时延续、发起者必改当前小时以及各种重估路径即时派发的回归验证。

验收标准：

- 发起者完成 NPC-NPC 对话后，判别请求强制包含结束时当前小时，第二阶段输出与动态行动候选严格一致，并在双人判别屏障释放后立即开始当前小时新行为。
- 对话途中跨越普通整点时，移动 / 等待 / 邀请 / 正式会话不被新小时计划覆盖；结束或失败后只落地当时当前小时，不补播已经错过的小时。
- 指令变化、行动失败、玩家 / NPC 对话等既有修订路径只要成功修改当前小时，均能立即执行或可靠延迟到阻塞解除后执行；专项测试不允许“修订成功但 NPC 长期 idle”。
- Mock / 本地自动化、Godot 项目解析与 MCP 运行验证通过；若环境存在真实 API Key，再完成真实 provider 的判别与正式修订业务路径测试。

验收结果（2026-07-27）：

- ActionSystem 的同日旧小时 `talk_to_npc` 不再被当前计划项过期扫描淘汰；DailyPlanSystem 在整点为 pending 发起者、邀请发起者或正式双方重建 carryover marker，批量派发不再调用普通整点强制结束自主会话。跨日及权威行为模式中断保持原职责。
- DialogSystem 继承 `plan_action_source / assigned_plan_*` 并在结束上下文传递自主发起者。发起者判别请求固定 `required_revision_hours=[当前小时]`，受邀者仍独立；Schema、endpoint、Prompt、紧凑重试与 Mock 均校验 required 子集，正式修订继续使用正常动态候选。
- 当前小时修订统一先登记 dispatch marker；直接派发成功后消费，组屏障 / 行为模式阻塞和派发失败时保留。既有 `verify_plan_revision_remaining_day.gd` 已通过直接当前项、双人屏障、连续后继和行为模式恢复后立即执行验证。
- GM `dialogue_carryover` 已替换旧 `expire_plan_dialogues`，只读显示 pending / active / deferred；相关文档和 `verify_gm_panel.gd` 已同步。
- `verify_npc_npc_dialogue_edges.gd`、`verify_npc_npc_plan_action.gd`、`verify_plan_revision_remaining_day.gd`、`verify_action_failure_plan_revision_judgement.gd`、`verify_order_plan_effect.gd`、`verify_plan_revision_single_successor.gd`、`verify_gm_panel.gd`、Python Schema / endpoint / Mock 专项及 Godot 4.6.2 项目解析通过。
- 真实 DeepSeek `deepseek-v4-flash` 完成发起者 required 当前小时判别与当前小时正式修订；判别首次遗漏 required 后被真实业务校验拒绝并由同 provider 紧凑重试纠正，修订一次成功且返回 `immediate_action`。全程 `LLM_FALLBACK_TO_MOCK=false`、最终 `fallback_used=false`。

---

## T0075 计划行动完成策略与连续生产周期

状态：Done
优先级：P1
前置任务：T0025, T0035, T0043, T0063
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 把正式计划行为在成功完成后的续行语义配置化，形成新增行为必须遵守的统一设计合同。
- 六种通用生产工作在当前小时计划仍为同一行动时，完成一个周期后立即重新校验并开始下一周期，不再空闲等待整点。
- 跨小时时，若新小时计划与当前运行行动及必要目标相同，则保留当前进度继续；若不同，则中断旧行动并执行新小时计划。
- 吃饭、饮酒、睡觉、祈祷、弥撒、对话、拜访等单次行为不得因完成回调在同一计划小时自动重复；计划版本变化也不能绕过严格每小时单次边界。
- 持续服务、条件目标和逃离等行为不套用生产批次重开；完成、失败或目标消失后沿用各自权威生命周期。

验收标准：

- `data/action_defs.json` 为全部 25 个配置行为显式声明合法完成策略；`idle` 使用程序固定策略，未知或缺失策略在自动化中失败，防止后续新增行为遗漏分类。
- `work_garden / work_dining_hall / work_stable / work_tavern / work_blacksmith / work_workshop` 使用连续生产策略；成功完成并写完旧周期事件后，若当前计划仍匹配则延迟续开并重新校验工位、资源、建筑和制造目标。
- 跨小时相同行动不清零运行进度；行动或必要目标不同则中断并派发新小时项。
- 每小时单次行为的消费记录不依赖 `plan_version`；同小时替换计划或显式再次派发不会重复吃饭、饮酒或重放其他单次行为。
- 持续服务 / 受训、条件治疗 / 修复 / 升级、终局逃离及两个非计划系统行为保持各自生命周期，不被自动续开。
- 完成事件顺序固定为旧周期 `*_completed` 在前、新周期 `*_started` 在后；失败续开不形成同步递归或重复判别。
- 新增专项覆盖全行为分类、生产续开、制造阶段、同/异行动跨小时、目标比较、单次行为与计划版本、失败边界和事件顺序；相关既有回归、项目加载和 Godot MCP 检查通过。
- 功能可通过 `Main.tscn` 正常日志、建筑进度及既有 GM 时间 / 指定行动 / 计划入口观察，不新增第二套调试结算。

验收结果（2026-07-27）：

- 全部 25 个配置行为已按六类策略穷尽标注；ActionSystem 初始化校验合法枚举及 `plan_selectable` 一致性，运行态 MCP 检查为 25 项、0 策略错误。
- DailyPlanSystem 在成功完成生产周期后 deferred 续开，确保旧 `work_completed` 先写、新 `work_started` 后写；重新派发继续走工位、资源、建筑、制造目标 / revision 等正式校验，失败与中断不进入自动续开。
- 整点派发沿用既有目标感知运行态比较：同 action / 必要 target 采用当前 active 并保留 `elapsed_seconds`，不同项中断并派发新计划；专项确认被中断的未完成工作不增加完成事件或产出。
- 每小时单次行为增加独立于 `plan_version` 的“日期 + 小时 + 逻辑计划项”消费记录；吃饭提前完成保持空闲，同小时替换计划后返回 `already_executed_once_per_plan_hour`，不会再次扣资源 / 写开始事件。既有玩家对话显式恢复会临时释放该记录，只继续未完成执行。
- 新增 `verify_plan_action_completion_policy.gd`，更新 `verify_plan_slot_dispatch_once.gd`、`verify_daily_plan_system.gd` 与 `verify_player_dialogue_plan_resume.gd`。完成策略、行动目录、基础行动、目标替换、扩展行动、制造管线 / 提醒、普通工作产出和项目解析回归通过。
- Godot MCP 4.0.1 与 addon 版本一致；Godot 4.6.2 冻结运行载入 Main、ActionSystem 和 DailyPlanSystem 正常，编辑器错误为空。现有 GM 入口足够观察，未新增第二套结算。
- 旧 `verify_daily_plan_reevaluation.gd` 的可选真实后端分支仍在既有 LLM slowdown 审计处失败，`verify_plan_revision_remaining_day.gd` 也命中其既有 payload / 后端线程问题；两者失败点不在本任务的完成策略、行动派发或结算路径，本任务未用 Mock 伪装通过。

---

## T0074 制造目标缺失主场景提醒

状态：Done
优先级：P1
前置任务：T0035, T0804, T0805
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `GODOT_ARCHITECTURE.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `DEV_LOG.md`

任务目标：

- 铁匠铺或工械坊尚未选择制造目标时，在主场景对应建筑名称上方显示红色感叹号。
- 鼠标悬停感叹号时显示“未选择制造物品”。
- 点击感叹号时复用既有建筑选择链路，打开对应建筑面板。
- 选择合法制造目标后立即隐藏对应感叹号；清空目标后重新显示。

验收标准：

- 开局两个制造项目都为空时，铁匠铺与工械坊名称上方各有一个可点击红色感叹号。
- 感叹号悬停提示固定为“未选择制造物品”，点击分别打开 `blacksmith` / `workshop` 建筑面板。
- 通过建筑面板选择目标后，对应提醒立即隐藏，另一建筑提醒不受影响；清空目标后提醒恢复。
- 提醒只读取 `CraftingSystem` 项目快照，不自行设置目标、推进阶段或结算资源。
- 新增专项自动化验证，并通过 Godot MCP 运行态外观 / 交互与错误日志检查。

验收结果（2026-07-27）：

- 新增 `CraftingTargetAlertPresenter.gd` 与 `Main/UI/CraftingTargetAlerts`：两个红色 `!` 跟随铁匠铺 / 工械坊名称屏幕位置，靠近视口边缘时自动夹取；低于 320×180 的不可用测试视口隐藏提醒，避免覆盖原有世界点击。
- 提醒只读取 `CraftingSystem.get_project_snapshot(...)` 并监听 `project_changed`；无目标时显示，选择目标后对应提醒立即隐藏，清空后恢复，两个建筑状态互不干扰。
- Godot 原生 tooltip 固定为“未选择制造物品”。真实鼠标点击提醒通过新增的正式 `BuildingSystem.select_building(...)` 复用 `building_clicked -> BuildingPanel`；原 `debug_select_building(...)` 改为委托同一正式入口。
- 新增 `verify_crafting_target_alerts.gd`，覆盖开局两个提醒、红色、名称上方定位、真实鼠标悬停 / 点击、对应面板、独立隐藏及清空恢复。
- 通过制造管线、铁匠铺、工械坊、15 座建筑真实点击、建筑工位面板和项目加载回归。Godot MCP 4.6.2 运行态确认两个提醒、tooltip、工械坊面板打开和选择弓后单独隐藏，编辑器错误为空。
- 功能可直接在 `Main.tscn` 手动验证，未新增 GM 调试入口。

---

## T0073 指令面板叙事文案与指令影响计划验收

状态：Done
优先级：P1
前置任务：T0703, T0703A, T1002, T0023, T0072
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `DEV_LOG.md`

任务目标：

- 移除指令文本框中“自由撰写守备官希望该 NPC 持续参考的指令……”占位文案。
- 指令面板标题从“给 {NPC} 的当前指令”精简为“给 {NPC} 的指令”。
- 面板默认说明改为世界内叙事“驿站成员将尽量遵循守备官的指令行动。”，保留发布成功 / 未变化 / 失败等即时反馈。
- 验证发布不同指令不只保存文本和发出信号，还会在已有 24 小时计划时进入真实计划修订链，并实际改变当前权威计划；不把指令变成强制行动。

验收标准：

- `OrderPanel` 打开时不显示被移除的占位文案，标题和默认说明使用指定叙事文本。
- 既有未入伍拦截、预填、修订号、私有事件、相同文本无副作用和关闭不保存合同保持通过。
- 确定性专项证明发布新指令会把最新 `current_order` 注入修订请求，并将合法修订结果合并到 24 小时权威计划；若环境中有可用真实 provider，追加关闭 Mock fallback 的真实发布指令 → 计划变化验收。
- Godot MCP 运行态确认新文案和空占位，编辑器错误为空；功能可在 `Main.tscn` 前端与既有 GM 当前计划 / 指令入口观察，不新增重复 GM 控件。

验收结果（2026-07-27）：

- `OrderPanel` 已删除输入框 placeholder；动态标题改为“给 {NPC} 的指令”，默认说明改为“驿站成员将尽量遵循守备官的指令行动。”。发布成功 / 未变化 / 失败反馈保持原合同。
- `verify_npc_order.gd` 新增三条运行态 UI 断言，并继续通过未入伍拦截、预填、修订号、私有事件、相同文本无副作用、关闭不保存和新入伍入口回归。
- 新增确定性 `verify_order_plan_effect.gd`：从真实 `OrderPanel` 发布指令，捕获 `order_changed` 当前小时修订请求，使用正式 LLMBridge builder 确认最新 `current_order` 已注入，再证明合法响应把权威 24 小时计划当前项从 `idle` 改成 `visit_location -> chapel`。
- 新增真实 `verify_order_plan_effect_real.gd`：DeepSeek `deepseek-v4-flash`、关闭 Mock fallback，一次正式 `revise_plan` 将老兵副官 08:00 计划从 `idle` 改为前往小教堂；`request_id=godot_revise_plan_1436_0002`，输入 22,884 / 输出 266 tokens，`fallback_used=false`。
- Godot MCP 4.6.2 冻结运行确认“给 艾达 的指令”、新叙事说明、空 placeholder 与面板布局，编辑器错误为空。功能直接在 Main 前端可见，后端影响可复用既有 GM 当前指令 / 最近注入 / 当前计划入口，未新增重复 GM 控件。

---

## T0072 应征接受即时刷新与 NPC 面板文案精简

状态：Done
优先级：P0
前置任务：T0702, T0703, T0704, T0051
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`, `DEV_LOG.md`

任务目标：

- NPC 在守备官对话回复中明确接受应征时，立即写入权威 `recruited` 状态，不再等玩家结束或重新打开对话 / NPC 面板。
- 复用 `npc_state_changed` 让当前已打开的 NPC 面板即时显示“已入伍：是”，并立即显示可用“指令”按钮。
- 保留既有自然语言软性指令闭环：已入伍 NPC 从 NPC 面板打开 `OrderPanel`，指令作为后续计划与判断上下文而非 RTS 强制行动。
- 把 NPC 面板个人库存文案“持有酒”精简为“酒”。

验收标准：

- 对话响应返回 `recruitment_result=accept` 后、对话仍保持打开时，NPC 权威状态与面板“已入伍”字段均已更新，“指令”按钮立即可用。
- 接受应征后的会话取消 / 关闭不会回滚已经明确返回的接受结果；拒绝结果仍不改变入伍状态。
- 自动化覆盖即时状态刷新、即时指令入口、会话事件 payload、精简酒文案和既有指令发布闭环；Godot MCP 运行与错误日志检查通过。
- 功能可直接在 `Main.tscn` 的 NPC / 对话 / 指令面板验证，不新增重复 GM 入口。

验收结果（2026-07-27）：

- 根因确认：`DialogSystem` 只把接受结果写入 `deferred_recruitment_result`，直到 `end_dialogue(...)` 才调用 `set_npc_recruited(...)`；面板监听与刷新逻辑本身正常，但在回复出现时没有权威状态变化可监听。
- 接受结果现在于 NPC 回复进入会话历史后立即提交权威入伍状态；打开中的 NPC 面板同步显示“已入伍：是”并显示可用“指令”按钮。取消 / 完成剩余会话都不回滚已经明确说出口的接受；拒绝保持原状态。
- 既有软性指令前后端链路确认完整：`NPCPanel -> OrderPanel -> NPCSystem.current_order -> LLMBridge / 后端 current_order 上下文 -> 计划重评估`。玩家对话仍须先完成或取消再打开中央指令窗，NPC 面板无需重开。
- NPC 个人酒显示已精简为“酒：N”。对话 UI、会话生命周期、战时应征、NPC 面板交互、指令发布、面板状态 6 项 Godot 专项和项目 headless smoke 通过。
- Godot MCP 4.6.2 冻结主场景直接模拟接受回复时确认：对话仍活动、`recruited=true`、“已入伍：是”、“指令”可用、“酒：0”；编辑器错误为空。功能前端可见，未新增 GM 入口；本任务未修改 Prompt / provider 行为，无需真实 API 调用。

---

## T0071 NPC-NPC 对话私有上下文隔离

状态：Done
优先级：P0
前置任务：T0029, T0040, T0041, T0059, T0069
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

- 修复 NPC-NPC 对话请求把说话者短期记忆注入回复者模型上下文的问题，禁止回复者读取对方未说出口、也未通过亲历 / 见闻合法获得的私有事实。
- 审计六类正式 LLM payload，确认不存在其他跨 NPC 注入短期记忆、长期记忆、私人指令或地点私有上下文的路径。
- 把说话者上下文收敛为当场可观察的姓名、外表和健康状态，以及本轮已经说出口的文本；不把说话者技能、属性、个人金钱 / 酒、指令或记忆作为回复者知识。
- 排查并清除行动候选中的同类侧漏：`talk_to_npc` 只向模型公开可交谈对象身份，不公开对方实时地点、当前行动或征召状态。

验收标准：

- `build_npc_dialogue_payload(...)` 的 NPC 说话者路径不再发送 `speaker_npc`，`speaker_context` 不含记忆、指令、技能、属性、个人资源或地点私有上下文。
- 后端 Schema 拒绝非空 `speaker_npc`，防止旧客户端或手工请求重新携带完整 `NPCContext`；Prompt 明确回复者只能使用自己的记忆与对方已说出口 / 当场可观察的信息。
- 自动化构造“格伦知道铁盔、伊沃不知道”的差异记忆，证明伊沃对话 payload 中不存在铁盔私有事实，同时保留伊沃自己的短期 / 长期记忆。
- 六类 payload 静态与运行态审计、Schema、Mock / fake-provider、Godot headless、项目 smoke 和 Godot MCP 检查通过；若已有真实 API Key，以关闭 Mock fallback 的真实 provider 验证 NPC-NPC 对话未知事实边界。
- 同步回写相关文档；不新增第二套记忆或对话权威系统。

验收结果（2026-07-27）：

- 根因确认：`LLMBridge` 为 NPC 说话者调用 `_build_npc_context(..., false)`，只排除了长期记忆，却仍把说话者短期记忆、当前指令、地点 / 广场上下文和完整状态注入回复者请求。真实审计中伊沃自己的记忆没有铁盔事实，而 `speaker_npc.short_term_memory` 含格伦合法接收的铁盔制造差量。
- 正式对话 payload 已删除 `speaker_npc`；NPC 说话者的 `speaker_context` 只保留姓名、外表、健康状态和空 `state`。回复者自己的顶层长短期记忆、地点与指令保持完整。
- 后端 `speaker_npc` 只接受 `null`，`speaker_context.state` 必须为空；ModelAdapter 不再从 `speaker_npc` 读取 NPC id。Prompt 同步禁止把对方未说出口的私有信息、或行动候选中的程序路由元数据当成回复者见闻。
- 六类运行态 payload 审计没有发现第二条跨 `NPCContext` 注入路径；但发现 `talk_to_npc` 候选曾附带目标的实时地点、当前行动和征召状态，现已改为仅给 `target_id / target_name`，实际移动目的地仍由 `ActionSystem` 执行时权威查询。
- 新增 Godot 差异记忆专项确认格伦私有铁盔批次不进入伊沃任何正式 payload，同时伊沃自己的长短期记忆保留，并验证所有对话候选不再携带他人实时状态。
- Schema、Mock、fake provider、对话 endpoint、六类 Prompt、动态 station context、NPC-NPC 邀请 / 边缘流程和项目 smoke 通过。真实 DeepSeek `deepseek-v4-flash` 1 次明确回答不知道说话者未公开安排，输入 5,581 / 输出 207 tokens，`fallback_used=false`。Godot MCP 运行态确认 LLMBridge 节点与空编辑器错误。
- 现有 GM `npc_talk`、事件 / 见闻查询与后端持久化日志已能观察正式链路，未新增重复 GM 按钮或权威入口。

---

## T0070 NPC 公共在站标签、关键规则认知与仓库容量 UI

状态：Done
优先级：P1
前置任务：T0043, T0046, T0059, T0061, T0069
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `DEV_LOG.md`

任务目标：

- 在所有 NPC 共用的动态驿站居民名单中，为每人提供极简的“已/未入伍”和“在站/离站”标签；不复制私密记忆，不让 LLM 决定权威状态。
- 把“教官没有受训者时也能自行训练并提升能力”以精简世界内叙事补入艾达对训练场的初始知识；审计其他已实现建筑关键规则，把确实重要但现有种子知识遗漏的细节补给应当知道的对应 NPC。
- 在仓库建筑面板显示受仓库等级影响的各类资源当前容量上限，并在 HUD 左上资源项悬停时显示对应上限。

验收标准：

- `station_context.resident_roster` 的每一行包含程序实时生成的 `recruited` 与 `in_station`；完整名单语义与离站保留规则明确，六类正式 LLM 请求、后端 Schema、Mock / Prompt 契约与真实 provider 至少一条业务路径通过。
- 初始知识修改保持数据驱动、叙事化和人物知情边界；静态测试能锁定新增规则，不把未实现机制写成已发生事实。
- ResourceSystem / BuildingSystem 提供仓库容量的权威只读查询和资源增减上限约束；仓库面板逐项显示受容量影响资源的当前上限，HUD 主资源悬停提示同一权威数值。
- UI 只读取系统状态，不自行计算或修改库存；仓库升级后容量显示与实际可存上限同步刷新。
- Godot 专项、后端 Schema / Prompt / endpoint 回归、项目 headless smoke 和 Godot MCP 运行态检查通过；同步回写相关文档。

验收结果（2026-07-27）：

- 六类正式请求的 `resident_roster` 现在始终列出全部 8 名登记 NPC，并逐行携带权威 `recruited / in_station`；离站者不再从基础名单消失。后端两个布尔字段为必填，六份 Prompt 明确禁止把 `in_station=false` 当成在站目标。
- 艾达的训练场知识补入教官独练 / 带训两种成长；规则审计另补托马的坐骑分配资格、布鲁诺的餐食优先价值、莉娜的无病人研读。8 人仓库常识同步为已实现的分资源容量与升级扩容，不声称尚未实现的受击丢货。
- `resource_defs.json` 为粮食、餐食、酒、木材、石料、铁配置逐项容量；1 级依次为 120 / 120 / 60 / 120 / 120 / 120，后续每级增加 60 / 60 / 30 / 60 / 60 / 60。ResourceSystem 权威拒绝单项与批量溢出，工作产出和商人购买均保持失败原子性。
- 仓库建筑面板新增“储存上限”行；HUD 左上受限资源悬停显示同一权威数值，仓库升级后两处同步刷新。第纳尔、具体装备和兼容资源保持无限制，不显示伪上限。
- 静态知识、Schema、六类动态上下文、工作产出、交易、HUD、训练、诊所、马匹、食堂与仓库专项通过。真实 DeepSeek `deepseek-v4-flash` 1 次准确复述 8 人入伍 / 在站状态和教官成长，0 fallback；Godot MCP 4.0.1 / Godot 4.6.2 运行态及 UI 截图通过，编辑器错误为空。
- 修复实现中发现的硬错误：无 `warehouse_capacity` 配置的资源曾因空字典被误判为容量 0；现仅显式非空配置的六种资源受限。T0062 改为 `Partial`，其受击资源损失、损失事件与 GM 观察仍待实现。

---

## T0069 后端 LLM 调用持久化审计日志

状态：Done
优先级：P1
前置任务：T0068
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `TECH_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `backend/README.md`, `DEV_LOG.md`

任务目标：

让 ModelAdapter 的每次调用、正式供应商请求和响应、解析结果、usage、失败与后续 Schema / 业务校验结果以脱敏 JSONL 持久化到后端文件，避免后端重启或控制台输出轮转后失去测试证据。

验收标准：

- 后端默认启用本地 JSONL 调用日志，路径可由环境变量覆盖；运行时目录必须被 Git 忽略，日志写入失败不得中断游戏调用。
- 每次 ModelAdapter 调用保存唯一 audit id、request id、call type、provider、model、NPC / 事件 id、输入 payload、状态和最终 usage。
- 每次真实供应商尝试保存不含 Authorization 请求头的完整 provider JSON body，以及聚合后的原始响应正文、HTTP 状态、finish reason、token 和尝试序号；重试必须逐次可区分。
- Mock、无 Key、预算拦截、HTTP / 超时、非 JSON、截断、Schema / 业务校验失败和 Mock fallback 都有可关联的生命周期事件。
- API Key、Authorization、密码、secret 和常见 token 凭据字段必须递归脱敏；配置中的真实 API Key 即使意外出现在文本值中也必须替换。
- `/health`、`/debug/llm_usage` 和既有 GM“成本统计”可观察日志启用状态、格式、路径与最近写盘错误，但不得通过 HTTP 返回完整日志正文。
- 使用临时日志文件和 fake provider 自动验证成功、重试 / 失败、业务校验改写、并发安全和敏感信息脱敏；测试不得调用真实 provider。
- 同步更新后端说明、架构、Prompt / API 审计边界、模块索引和开发日志。

验收结果（2026-07-27）：

- 新增 `LLMCallAuditLogger`，环境配置创建的后端默认写入 `backend/logs/llm_calls.jsonl`，支持开关、路径和完整正文开关；目录已由 `.gitignore` 排除，写盘错误只进入运行快照，不中断调用。
- 每次调用分配唯一 `audit_id`；完整记录输入 payload、逐次 provider body、聚合响应、原始正文、解析 / 拒绝、HTTP / 异常、usage、fallback、最终结果及后续业务校验失败。正式请求从不把 Authorization headers 交给日志器。
- 敏感 key、序列化 JSON 凭据、Bearer、`sk-...` 和配置 API Key 均在写盘前脱敏。`/health`、usage 与 GM 只返回日志配置 / 错误，不返回正文。
- `verify_llm_persistent_audit_log.py` 覆盖 fake 成功、两次非 JSON 重试、HTTP 503、业务无效关联、24 路并发 Mock、默认环境配置、敏感信息和写盘失败；既有 ModelAdapter、预算、Schema、六类 endpoint / Prompt 回归通过。
- 真实 DeepSeek `deepseek-v4-flash` 在关闭 Mock fallback 后完成 `/npc/dialogue` 与 `/npc/battle_judgement` 各 1 次；日志为 2 个 audit id / 10 条生命周期事件，完整 messages、响应与 token 均存在，0 fallback，API Key / 请求头扫描通过。

---

## T0068 T0067 真实 LLM 94 次调用审计包

状态：Partial
优先级：P1
前置任务：T0067
涉及文档：`CURRENT_STATE.md`, `TASKS.md`, `MODULE_INDEX.md`, `API_BUDGET.md`, `DEV_LOG.md`

任务目标：

整理 T0067 的 94 次真实供应商请求，汇总测试编写的场景话术、正式系统 Prompt、可恢复的完整供应商请求体、usage 元数据和模型返回结果，形成不含 API Key / Authorization 请求头的可检索审计包。

验收标准：

- 按 request id 列出 78 次 Main 唯一请求与 16 次独立定向矩阵请求，保留 call type、NPC、token、成功 / 失败和 fallback 元数据。
- 恢复本次会话仍保存的原始测试输出，并区分原始证据、确定性重建和仅能给出来源 / 摘要的内容。
- 导出测试脚本中由 Agent 编写的守备官话术、命令和压力场景；导出测试时使用的正式系统 Prompt。
- 对静态、确定性的 16 次独立矩阵重建完整 provider 请求体；不得把未持久化的 Main 动态 payload 或原始模型文本伪装成完整原始记录。
- 不重新调用真实 provider，不输出 API Key、Authorization 请求头或无关 Codex 会话内容。
- 更新任务状态、模块索引、API 成本说明和开发日志。

验收结果（2026-07-27）：

- 已生成 `docs/audits/T0067_LLM_94_CALLS/`。`call_inventory.csv` 恰好 94 行：Main 78（battle 7 / dialogue 43 / plan 28）与独立矩阵 16（battle 7 / dialogue 9）。
- 已恢复独立矩阵 16 次的原始业务结果和 usage，并从当时未再改动的 payload builder、正式 Prompt 与 ModelAdapter 排序 JSON 规则确定性重建完整无请求头 provider body；输入 89,562 / 输出 2,614 tokens 与 T0067 原统计一致。
- 已导出三类完整 system Prompt、Agent 编写的 Main 场景命令 / 对话、四份测试脚本快照、39 条去重场景结果事件和 5 份删除前原始 `.out`。
- Main 最终 usage 尾部恢复 12 条历史原始记录，合并旧双计后为 11 个真实 request id；其余 67 次 Main 请求只有 call type 聚合与部分场景输出，动态完整 user payload、原始 SSE 和逐条业务 JSON 当时未持久化。
- 全部生成过程不调用真实 provider；导出的 16 份 provider body 不含 headers，敏感字段扫描通过。
- 任务保持 `Partial`：已经把所有仍可证明的原始证据与确定性重建内容整理完毕，但不能把未保存的 78 次 Main 完整 Prompt / 响应伪造为原始记录。后续 T0069 已按用户要求实现默认启用、可配置关闭的脱敏持久化日志；它只能保护今后的调用，不能补回 T0067 已丢失的正文。

---

## T0067 真实游戏场景战斗心理、日常逃离与挽留全分支验收

状态：Partial
优先级：P0
前置任务：T0025, T1201, T1202, T1203, T1204A, T1402, T1404
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `COMBAT_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

在当前真实 provider、正式 NPC 档案、长短期记忆、地点与战场上下文中，尽量通过 `Main.tscn` 的正式 Godot → 后端 → LLM → Godot 状态链模拟真实游戏场景，系统验收战斗低血量心理、战时 / 避战公开对话、日常计划逃离和逃离挽留全部程序允许结果。

验收标准：

- 先通过 Schema、Prompt、Mock endpoint 与 Godot 既有专项回归；真实 provider 验收必须关闭自动 Mock fallback，usage 可定位 request id、call_type、provider、model、NPC id、成功 / 失败与 fallback 状态。
- 参战 NPC 首次从不低于 30% HP 跌破 30% 且仍大于 0 时，真实 `/npc/battle_judgement` 能分别产生并由 Godot 正确应用 `continue_fighting`、`escape_station`、`morale_boost`；结果进入正式战斗心理事件，逃离与斗志状态实际生效。
- 避战 / 非战斗 NPC 的低血量判定只能产生 `continue_avoiding` 或 `escape_station`，不能越界参战或获得斗志；同时覆盖避战公开对话的正式允许结果和征召后的程序模式边界。
- `escaping_station` 确实进入工作模式日计划 / 修订候选，并能在符合人物、记忆、恐惧和战况压力的真实上下文中由真实计划模型选择；DailyPlanSystem 必须把该特殊意向交给 `CombatSystem.start_npc_escape(...)`，不能仅停留在计划文本。
- 逃离中的正式 `escape_intervention` 对话用真实 provider 覆盖当前 `escape_intervention_result=stay|leave`；验证挽留成功返回工作并重估计划，连续失败达到 5 轮后继续逃离且入口禁用。
- 尽量使用真实游戏运行态和正式系统接口构造场景，不把直接伪造模型响应的单元测试当作真实 LLM 验收；为覆盖低概率分支所做的定向压力场景必须保留正式 payload 和权威状态链，并在结果中区分自然触发与定向触发。
- 发现硬性代码 / 接线 / Schema bug 时直接最小修复并完成 Mock 与真实 provider 回归；若分支因上下文或 Prompt 设计稳定性不足而难以触发，只记录原因、证据与修改建议，不擅自调整软性设计。
- 更新测试记录、当前状态、相关模块文档与开发日志；若没有新增 / 移动文件，`MODULE_INDEX.md` 记录现有验证入口或说明无需结构变更。

验收结果（2026-07-27）：

- 基础回归通过：9 项 Python Schema / Mock / Prompt / endpoint 契约与 8 项 Godot 战斗、逃离、事件、时间专项均为 exit code 0；Godot MCP 4.0.1 与 Godot 4.6.2 保持连接。
- 正式 Main 低血量真实调用 7 次：参战继续战斗、避战继续躲避和避战逃离自然触发并正确应用；参战逃离与斗志激昂在两组定向极端 / 有利上下文中仍返回继续战斗。单结果正式 payload 可分别触发 `join_battle / avoid_battle / continue_fighting / escape_station / inspired`，证明分支可达但完整上下文选择不稳定。
- 正式 Main 战时 / 避战对话已覆盖士气高昂、无应征、接受与拒绝。格伦在 `combat` 中返回 `morale_boost` 并实际获得士气状态；另一场避战对话中接受应征后，无武器时保持避战，实际领取剑盾后由程序自动进入 `combat`；莉娜拒绝不合理的空手前线应征。避战对话始终保持 `wartime_reaction=none`。
- 正式 Main 逃离挽留已覆盖成功与失败：程序先实际撤回危险命令后，托马选择留下并回到 `work`；欧文连续 5 轮选择继续离开，轮次耗尽后保持 `escaping` 且再次开启返回 `round_limit_reached`。战时对话极端逃离场景仍返回 `none`；定向正式 payload 的 `none / escape / morale_boost` 均可达。
- `escaping_station` 已确认存在于日计划候选，手工注入的合法 24 小时计划会经 DailyPlanSystem 实际调用 CombatSystem 并开始离站；但一个基准计划和 3 次权威高压计划均未选择逃离。完整计划仍优先满足至少 6 个工作阶段，故本项仅完成“候选与执行链”，未完成“真实模型自然选择”。
- 修复硬性问题：补齐 `NPCStateContext` 的 `behavior_mode / combat_mode / combat_strategy / morale_boost / escape_intent`；增加对话上下文业务校验；禁止避战 fallback / 应用层产生战时反应；低血量迟到结果增加状态、资格、敌军和 `started_event_id` 复验；逃离模式与移动改为原子提交并修复复苏续逃失败；增加会话结束重入保护；业务校验失败改为原地更新同一条 usage，不再把一次供应商请求重复累计为成功和失败。
- 去重后真实 provider 合计 94 次实际开发验收请求（正式 Main 后端 78 次，独立定向矩阵 16 次），93 次通过业务校验、1 次普通开局 `plan_day` 业务校验失败、0 fallback；输入 1,876,789 tokens，输出 61,520 tokens。修复前运行中后端曾把这 1 次无效输出双记，原始快照显示 79 条 Main usage；审计统计按 request id 去重，修复后新请求不会再双计。
- 任务保持 `Partial`：代码与契约硬故障均已修复，但完整真实上下文中的参战逃离、斗志激昂和日计划主动逃离仍缺少稳定自然样本。建议经用户确认后再调整 Prompt / 上下文，不在本轮擅自改变角色决策风格。

---

## T0066 精简公告牌文案并优化 NPC 当前计划初始定位

状态：Done
优先级：P1
前置任务：T0024, T0046, T0065
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `UI_UX.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

减少公告牌双页中重复解释草稿 / 发布机制的 UI 文案，把玩家可见的“参考日程”统一改为更自然的“日程表”，并让 NPC“当前计划”详情打开时默认从当前执行计划之前的第二项开始显示，使当前项处于第三行，便于同时查看前后计划。

验收标准：

- 公告牌通告页移除“当前已发布通告 N 字（下方为可编辑副本）”和“退出不会保存草稿；只有发布才会……”等冗余说明，不影响草稿取消、发布、清空和全站广播合同。
- 公告牌第二个 Tab、发布按钮和玩家可见相关文案统一使用“日程表”，不再显示“参考日程”。
- 日程表页黄色世界内备注改为“这是建议日程，驿站成员不一定严格按照这个日程，如有特殊事务可自行安排”，并移除底部“新增、编辑和删除只改草稿……”提示；底层 `schedule_advisory_note` 与事件 / NPC 见闻继续使用同一权威文本。
- NPC“当前计划”详情打开时，以当前游戏小时对应计划为当前项；正常情况下显示区第一行从当前项之前第二个计划行动开始，使当前项位于第三行。0 点 / 1 点等不足两个前项时夹取到计划开头，不循环到前一天。
- 详情打开期间的既有刷新滚动保持逻辑不被破坏；事件库 / 见闻库继续定位最新记录，日记 / 知识详情不受影响。
- 更新公告牌和 NPC 面板专项，完成项目 headless 与 Godot MCP 实际 UI 验收。

验收结果（2026-07-27）：

- `NoticeBoardPanel` 移除已发布字数、通告草稿标题和两页默认草稿提示；玩家界面改为“通告 / 日程表”，发布按钮为“发布日程表”，但系统不可用、校验失败、全天重叠和发布结果等即时反馈仍保留。
- `schedule_advisory_note` 更新为指定的世界内文案，黄色标签直接显示权威文本；公告牌草稿取消、清空、独立发布和 T0065 全站单次广播合同保持不变。
- `NPCPanel` 首次打开当前计划时按每个行动实际占用的文本行定位到当前项前两项，并允许滚过文件末尾以保持晚间小时的相对位置；0 / 1 点夹取到首项。弹窗打开后的刷新滚动保持、事件 / 见闻首次到底部和其他详情模式未改变。
- `verify_notice_board_tabs.gd` 与 `verify_npc_panel_state.gd` 覆盖新文案、冗余节点 / 默认提示缺失、08:00 第三项定位及 00:00 / 01:00 边界；公告牌输入、地点信息、普通广场广播、NPC 交互和项目 headless smoke 回归通过。
- Godot MCP 4.0.1 / Godot 4.6.2 运行态读取到“通告 / 日程表”、空默认状态提示、指定黄色文案、无旧标签；08:00 当前计划首个可见行动为 06:00 且 08:00 带当前标记，编辑器错误日志为空。
- 功能可直接在 `Main.tscn` 公告牌和 NPC 面板验证，未新增或替换 GM 入口；本任务不涉及 LLM、Prompt、Schema 或 API 调用。

---

## T0065 公告牌发布改为全站单次广播并移除入场重复内容

状态：Done
优先级：P1
前置任务：T0046, T1506
涉及文档：`PROJECT_BRIEF.md`, `game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

把公告牌通告与参考日程从“发布时只通知广场在场 NPC、后来进入广场再随快照重复获得”改为“守备官发布实际变更时向全站 NPC 单次广播对应页面”，并让广场入场快照不再重复携带公告牌两页内容。

验收标准：

- 守备官发布发生实际变化的通告时，只生成一条 `plaza_notice_changed`，向所有仍在驿站且当前可接收见闻的 NPC 广播一次，不受 NPC 当前位于广场或室内影响。
- 守备官发布发生实际变化的参考日程时，只生成一条 `plaza_schedule_changed`，向同一全站接收范围广播一次；日程见闻继续携带非强制参考备注。
- 通告与参考日程保持独立变更检测：只改通告不广播日程，只改日程不广播通告，两页都改并分别发布时各广播一次；未变化的页面不生成事件。
- 公告牌发布事件 summary 明确区分“守备官更新了通告”和“守备官更新了参考日程”，新内容继续保存在各自事件 payload 中。
- NPC 进入广场时，`location_entry_snapshot` 不再携带或总结当前通告、参考日程与日程备注；广场权威当前状态仍保存这三项，供公告牌 UI、GM 和其他只读系统查询。
- 保持既有昏迷、睡觉、逃离 / 离站 NPC 的见闻接收资格规则，不借本任务改变认知或离站边界。
- 更新公告牌、广场广播与地点快照专项测试，并通过项目 headless 与 Godot MCP 运行态验证。

验收结果（2026-07-27）：

- `MemorySystem` 只对 `plaza_notice_changed / plaza_schedule_changed` 使用全部在站 NPC 接收者，其他 `local_public` 事件仍使用地点 `people_present`；最终写入继续复用既有昏迷、睡觉和离站资格过滤。
- 通告 / 日程接口各自只在内容变化时生成一条事件，summary 分别为“守备官更新了通告…”与“守备官更新了参考日程…”。专项确认只改一页不生成另一页事件，连续发布未变化内容不会增加任何 NPC 见闻。
- 广场权威状态继续保存两页及备注；写入 `location_entry_snapshot` 前剔除 `current_notice / reference_schedule / schedule_advisory_note`，入场 summary 不再提公告牌。公告牌 UI 发布提示同步改为全站广播。
- 10 项 Godot 专项与项目 headless smoke 通过；Godot MCP 4.0.1 / Godot 4.6.2 冻结运行确认 8 名 NPC 对通告和日程分别各收 1 条，室内 NPC 后续进入广场不再获得公告牌字段或摘要，编辑器错误日志为空。
- 功能可直接在 `Main.tscn` 通过公告牌发布并查看任意 NPC 见闻验证；既有 GM 地点快照 / NPC 见闻查询足够辅助观察，未新增 GM 入口。

---

## T0064 修复 Godot MCP 多会话 proxy 生命周期回归与 6550 误报

状态：Done
优先级：P0
前置任务：T0005, T0017
涉及文档：`CURRENT_STATE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

修复当前 Godot MCP 多会话拓扑验证中“关闭一个 session-local proxy 后另一个 proxy 也退出”的生命周期隔离回归，并避免在已有 Godot 编辑器正常监听 `127.0.0.1:6550` 时通过第二个 editor 实例产生误导性的端口占用报错。

验收标准：

- 明确区分 Godot 插件正常监听 `6550`、broker 正常监听 `8765`、broker 到 Godot 的已建立连接，以及当前 Codex stdio transport 是否可用。
- 多个 session-local proxy 可共存；关闭其中一个不会关闭另一个，也不会中断唯一 broker 到 Godot 的连接。
- `tools/check_godot_mcp.ps1` 和拓扑专项能够重复验证上述边界，并给出不会建议误杀正常 Godot 编辑器的诊断信息。
- 通过 broker 实际调用 Godot MCP 的 addon / editor 只读工具，确认项目、编辑器和插件连接可用。
- 项目 headless 验证不再通过启动第二个 `--editor` 实例触发 `6550` 误报；使用不会加载编辑器插件的游戏/headless smoke。

验收结果（2026-07-27）：

- 诊断确认 `6550` 由当前 Godot 4.6.2 编辑器正常监听，`8765` 由唯一 broker 正常监听，broker→Godot 已建立；此前第二个 `--editor` 的端口报错是验证方式错误，不是插件掉线。
- 复现 fresh proxy 因 `C:\Users\JT\AppData\Local\npm-cache\_npx` 已不存在而 `ENOENT` 退出；修复 `C:\Users\JT\.codex\scripts\godot-mcp-proxy.mjs`，优先使用 broker lock / 全局 Godot MCP 4.0.1 包内 SDK，并保留全局独立 SDK 与 npx 回退。
- `tools/verify_godot_mcp_topology.mjs` 增加子 proxy stderr / exit 诊断；fresh proxy 多会话测试重新通过，关闭一条不会影响另一条或 broker→Godot。
- `tools/check_godot_mcp.ps1` 现在显示 6550 正常 owner，并明确不得因监听存在而重复启动第二个 editor 或误杀正常 Godot。
- broker 实际调用 `godot_project.addon_status`、`godot_editor_read.get_state`、`get_log_messages` 均成功：server/addon `4.0.1` 对齐，Godot `4.6.2`，`Main.tscn` 已打开，编辑器错误为空。
- 验证通过：`check_godot_mcp.ps1`、`verify_godot_mcp_topology.mjs`、`godot --headless --path . --quit-after 1`。修复前已关闭的当前会话 stdio transport 需刷新或新开 Codex 会话才能重新注册工具。

---

## T0063 守备官赠酒与 NPC 自主饮酒闭环

状态：Done
优先级：P1
前置任务：T0041, T0704, T0807, T1003
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

让驿站已经能够酿造和出售的酒进入 NPC 个人交互与自主生活闭环：守备官可从 NPC 面板把驿站库存中的酒赠予目标 NPC；NPC 运行态记录个人持酒量，并可在自己确实有酒时把“饮酒”加入计划并由程序权威消耗。

验收标准：

- NPC 面板在“给钱”右侧提供“给酒”与数量输入，复用同一公开 / 私下可见性；成功时从驿站 `wine` 库存扣除对应数量并增加目标 NPC 的个人持酒量，库存不足或数量非法时两侧状态均不改变。
- `data/npc_profiles.json` 与 NPC 运行态在个人金钱旁记录个人酒数量；NPC 面板与六类正式 NPC LLM 状态上下文均可观察当前个人金钱和酒数量，不把个人持酒混入驿站五项公开资源储备。
- `data/action_defs.json` 新增可计划的“饮酒”行为，说明必须由本人实际持有至少 1 份酒；饮酒会由程序扣除 1 份个人酒，不新增情绪数值，也不删除历史记忆，而是通过结构化亲历事件让“心情改善、过去伤痛暂时淡化”进入后续上下文。
- 每日计划、计划修改判别和正式修订只在目标 NPC 当前确实持酒时获得动态 `drink_wine` 候选；执行瞬间再次权威校验，个人酒不足时产生可处理的资源失败并进入既有计划失败判别链。
- 新行为由 `action_defs.json -> ActionSystem -> LLMBridge` 同一链路同步进入 `station_context.work_mode_actions` 与对话 `allowed_actions`，不维护 Prompt 专用手写行为清单；计划与对话 Prompt 明确候选、个人库存与权威扣减边界。
- 赠酒与饮酒事件进入目标 NPC 事件库，公开赠酒 / 饮酒按现有同地点规则进入见闻；专项覆盖 UI、库存原子性、个人状态、候选、计划执行扣减、事件上下文、Schema / Mock / Prompt 与项目 headless。环境已有真实 Key 时追加真实 provider 验收，不允许自动 Mock fallback。

验收结果（2026-07-27）：

- NPC 面板已在“给钱”右侧增加“给酒 + 数量”，显示个人“持有酒”；`give_wine_to_npc(...)` 从驿站库存转入 NPC 个人 `states.wine`，并按可见性写 `wine_given` 事件 / 见闻。
- 新增 `drink_wine` / `action_kind=drink`。候选要求本人持酒，执行开始时通过个人资源接口原子扣 1；不足时记录 `drink_wine_failed_no_wine`，成功时记录 `wine_consumed`，只用事件上下文表达心情改善和伤痛暂时淡化，不创建情绪数值或删除记忆。
- `work_mode_actions.description`、计划 / 对话动态候选和六类正式 NPC 状态上下文已同步个人酒语义；共享五项公开资源边界保持不变。后端拒绝饮酒阶段数超过 NPC 当前个人酒的日计划 / 剩余日修订。
- `verify_npc_wine_drinking.gd`、`verify_npc_panel_interactions.gd`、`verify_dynamic_station_context.gd`、Godot 4.6.2 headless、Schema、六份 fake-provider Prompt 与 Mock endpoint 全部通过。
- 真实 DeepSeek `deepseek-v4-flash` 在关闭 Mock fallback 后通过 plan_day、dialogue、plan_revision_judgement、revise_plan、battle_judgement、daily_reflection 对应验收，所有成功记录均为真实 provider、`fallback_used=false`。
- 功能可直接从 NPC 面板和既有 GM “指定行动 / 资源增减 / 事件查询”组合验证，没有新增 GM 按钮或命令。

---

## T0061 收束 NPC 背景叙事与知识面板展示

状态：Done
优先级：P1
前置任务：T0060
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `UI_UX.md`, `GM_PANEL.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

在 T0060 直白自然的中文风格基础上，重新调整人物信息层级和玩家可见表达：取消会锁死 NPC 说话方式的代表性台词；把“来站前 / 初到驿站”从单一微观事故改为宏观身世与八人相互拼接的到站群像；让守备官和建筑知识保持世界内叙事感；精简“知识”面板的调试元数据展示。

验收标准：

- 正式 NPC 档案和六类 LLM 人设上下文不再提供 `signature_lines` 代表性表达，Prompt 不再要求模仿示例句；保留较宽松的 `speech_style`、人格、欲望、恐惧和底线来维持人物差异。
- 8 篇“往昔·来站前”精简勾勒身世、职业形成、离开旧生活的原因与来到驿站的时间；8 篇“往昔·初到驿站”说明到站后承担的工作和遇到的现有成员，八个视角能拼出一致的到站顺序与驿站生活群像。
- 8 篇“往昔·近日”继续保留 T0060 的微观日常，不预知守备官尚未传达的敌情。
- 每人的守备官知识只保留该职位最基本的职责，不增加“尚待观察”“是否听取意见”等关系判断，也不补写既往互动。
- 15 座建筑的中文认识改为角色在世界内会自然表达的常识，避免直接罗列初始位置数、升级数值、槽位和系统流程；本职建筑仍比其他建筑更具体。除 8 条仓库技术值为消除未实现容量 / 丢货语义而受控迁移外，其余技术 `value` 不变，全部 `confidence / day / time` 保持完整。
- `Main.tscn` 的 NPC“知识”面板不再显示可信度和更新时间，但运行态图谱、后端参数和 GM / 调试数据仍保留这两个字段。
- 更新文案、结构、Prompt、UI 与真实模型专项；静态检查、Mock、Godot headless、Godot MCP 和环境已有 Key 时的真实 provider 均通过，且无自动 Mock fallback。

验收结果（2026-07-24）：

- `data/npc_profiles.json`、共享 `NPCIdentity` / `npc_setting`、`NPCPromptProfile.gd`、背景弹窗和六类正式 Prompt / payload 已移除 `signature_lines`，当前只保留宽松 `speech_style` 与其他根本人设字段。
- 前两篇种子日记已按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜的到站顺序重写为宏观身世与相互拼接的驿站群像；8 篇“往昔·近日”未改，继续位于敌情传达前。
- 每人的守备官初始知识已收为一条职位职责，技术关系键统一为 `role`。15 座建筑的中文认识已改为符合职业视角的世界内常识；为消除当前尚未实现的仓库容量、受击丢货和损失比例语义，8 条仓库技术 `value` 受控迁移为 `central_storage_and_post_breach_attack_target`，其余技术 `value` 不变，222 条关系记录的 `confidence / day / time` 全部完整。
- `NPCPanel` 的“知识”详情只显示中文主体、关系和值；`confidence / day / time` 继续保留在原始 / 运行态记录与 GM `long_memory` 输出中，后端知识补丁仍保留 `confidence`，Godot 继续写入日期和时间。本功能可直接从主场景验证，不新增 GM 入口。
- 静态文案、六份 Prompt、后端 Schema、Model Adapter Mock 与相关 endpoint 全部通过。`verify_npc_character_profiles.gd`、`verify_npc_initial_long_memory.gd`、`verify_npc_panel_state.gd`、`verify_daily_reflection_system.gd`、`verify_gm_panel.gd` 5 个 Godot 专项全部通过；最终最大 payload 字符数为 `battle_judgement=32057 / daily_reflection=29242 / dialogue=48330 / plan_day=47118 / plan_revision_judgement=50053 / revise_plan=49952`。
- 真实 DeepSeek `deepseek-v4-flash` 在关闭自动 Mock fallback 后完成 3 次调用，0 失败，全部 `fallback_used=false`。Godot MCP 4.0.1 / Godot 4.6.2 运行态确认 8 人各 3 篇日记、守备官 `role`、222 条原始元数据、8 条仓库技术值和玩家 UI 元数据隐藏全部正确；莉娜实际知识弹窗显示 27 条关系，编辑器错误日志为空。
- 项目 headless smoke 通过；仅出现既有退出期 `ObjectDB instances leaked at exit` 警告，不是 T0061 新增错误。

---

## T0062 实现仓库容量与受击资源损失闭环

状态：Partial
优先级：P2
前置任务：T0061, T0205, T1102
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `COMBAT_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

把当前仅作为“全站库存记账点和城门失守后攻击目标”的仓库补成程序权威闭环：由配置与系统实现仓库容量、升级后的容量变化，以及仓库受击时可追溯的资源损失；机制完成前，不把这些效果写进 NPC 常识或 Prompt。

验收标准：

- 用数据配置明确仓库各等级容量、纳入容量计算的资源范围、受击触发条件和损失规则；不在 UI、Prompt 或 NPC 文案中硬编码权威数值。
- ResourceSystem、BuildingSystem 与 CombatSystem 使用单一权威路径校验容量和结算受击损失；LLM 不决定能否入库、丢失何种资源或具体数量。
- 资源增加、交易、生产、制造返库和其他入库来源遵守同一容量合同；容量不足时返回明确、可处理且不破坏原子性的结果。
- 仓库受击损失以结构化事件记录受击前后库存、实际损失和触发原因，并按既有广场公开规则传播；不得重复扣除或让 UI 自行结算。
- 仓库修复 / 升级与容量变化保持一致，存量超过新上限等边界有明确规则和自动化覆盖。
- BuildingPanel / HUD / GM 只读显示当前容量、占用与最近损失结果；新增或替换 GM 入口时同步更新 `GM_PANEL.md`。
- T0070 已实现按仓库等级变化的六种大宗资源容量、统一入库约束、BuildingPanel / HUD 显示和 8 人仓库知识；受击丢货仍不得写成已发生机制。
- 容量部分已完成交易 / 生产、项目 headless 与 Godot MCP 运行态验证。剩余工作是配置并实现仓库受击资源损失、结构化损失事件、CombatSystem 接线、GM 观察入口及对应战斗回归。

---

## T0060 重写 8 名 NPC 初始长期记忆文案

状态：Done
优先级：P1
前置任务：T0059
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

根据玩家对 T0059 文案的反馈，整体重写 8 名初始 NPC 的根本人设、24 篇初始日记、个人故事和知识图谱中文叙事。新文案以中文母语者能一次读懂为首要标准，使用清楚、自然、具体的表达；黑色幽默只能建立在明确事实和角色态度上，不再使用晦涩比喻、突兀拟人或为了机巧而机巧的句子。每名 NPC 通过句式、用词、关注点和判断习惯体现不同性格，而不是共享同一种文风。

验收标准：

- `personality / desires / fears / boundaries / background_story / speech_style / signature_lines` 全部逐项重写或审定：保持 §9 的职业核心与底线，背景只保留稳定职业视角、价值尺度与内在矛盾；说话规则和示例改为自然直白的中文，不再要求人物借职业物件反复作比。
- 8 人各 3 篇日记全部重写：来站前写一个可信的人生节点，初到驿站写具体适应经历，近日写守备官收到敌情并对外传达之前的普通驿站生活；近日不得预知敌袭、战争、征召或备战。
- 个人故事主体和对应认知重新设计为容易理解、能解释人物性格的真实生活经历；知识图谱的中文 `value_label` 全量重写，仍覆盖其余 7 人、守备官、15 座正式建筑和至少 2 个个人故事主体。
- 建筑认识继续符合当前程序规则：本职建筑更详细，其他建筑简明但准确；不把广场或公告牌列为建筑，不让认知文本宣称未实现功能或决定权威数值。
- 守备官初始认识保持中立开放，不预设双方已经交谈、守备官已经公开敌情、人物已经信任 / 敌视 / 服从，也不把玩家尚未做出的行为写进过去。
- 文风专项必须覆盖旧版晦涩句、近日战事预知、角色语气差异和自然中文；既有结构、六类 LLM 注入、UI / GM、首次反思、Mock、Godot headless 与 Godot MCP 均需回归。环境有真实 Key 时，用真实 provider 验证模型能准确复述新故事锚点且不误称 NPC 已知敌袭，`fallback_used=false`。

验收结果（2026-07-24）：

> 历史说明：T0061 已进一步移除 T0060 当时保留的 `signature_lines`，并取代前两篇微观日记、守备官开放评估措辞、建筑规则说明式写法和知识面板的可信度 / 更新时间展示；以下仍是 T0060 当时的验收记录。

- 8 人的 7 类档案文案、24 篇日记和 227 条知识图谱中文 `value_label` 已全量重写；每人保持 25 个知识主体，严格覆盖 15 座正式建筑、其余 7 人、守备官和 2 个个人故事主体。本职建筑认知更具体，其他建筑简明且遵守当前程序规则。
- “往昔·近日”统一改为守备官收到并向众人传达敌情之前的普通驿站生活；守备官条目保持未交谈、未传达敌情前的中立开放认识，不预设玩家后续行为或关系结果。
- 8 人现分别通过朴实谨慎、口语抱怨、安静务实、短促严厉、条理复盘、温和完整、临床精确和因果分析等表达习惯形成差异。文案专项会拒绝旧故事主体、晦涩比喻 / 拟人、近日战事预知、相互重复的知识标签和空泛职业套话。
- 六类 NPC payload 把结构化日记统一投影为带时间标签的 `list[str]`：种子记录使用“往昔·来站前 / 往昔·初到驿站 / 往昔·近日”，后续记录使用“第 N 天 HH:MM:SS”。六份 Prompt 同步要求自然直白中文、种子时间边界、实时事实优先与守备官关系开放。
- 静态文案、人物档案、初始长期记忆、六份 Prompt、后端 Schema、Model Adapter Mock、首次睡眠反思、GM、Godot 专项与项目 headless 全部通过。
- 真实 DeepSeek `deepseek-v4-flash` 在禁止 Mock fallback 下准确回答莉娜、欧文、布鲁诺 3 条新记忆路径；3 次调用、0 失败，全部 `fallback_used=false`。
- Godot MCP server / addon 4.0.1 与 Godot 4.6.2 冻结运行 `Main.tscn`，确认 8 人各 `diary=3 / subjects=25 / prefix=true / recent_clean=true`；编辑器无错误，验证后已停止场景。没有新增 GM 入口，继续复用 NPC 面板“日记 / 知识”和 `long_memory <npc_id>`。

---

## T0059 补全 8 名 NPC 初始长期记忆与根本人设

状态：Done
优先级：P1
前置任务：T0046, T0053, T0054, T1501
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

为 8 名初始 NPC 配置与其根本人设一致的初始第一人称日记和知识图谱，让对话、每日计划、计划修改判别、正式修订、战时心理判定与首次睡眠反思从新游戏开始就能理解人物过去、职业经验、驿站建筑和其他在站人物；同时重写简短 `background_story`，只保留最根本、稳定且不与长期记忆重复的人物内核。

验收标准：

- 每名 NPC 至少有来站前、刚到驿站和最近过去三个生命切片，沿用运行时 `diary` 记录格式，以第一人称写作，简短、有个性、有轻微幽默和余味，不写成第三人称人物小传。
- 每名 NPC 的初始 `knowledge_graph` 使用现有 `key_value_replace_v1 / by_subject` 结构，包含与个人故事适配的关键人物或事物、守备官、其余 7 名 NPC，以及 `building_defs.json` 中全部 15 座建筑。
- 建筑认知符合当前游戏规则：本职相关建筑更具体，其他建筑保持粗略但正确；不把广场或公告牌误列为建筑，不让认知文本改写 HP、资源、装备、入伍或行动等程序权威事实。
- 对守备官和玩家尚未发生的关系保持中立开放，不预设善恶、承诺、信任结果或既往互动，为后续玩家行为留出变化空间。
- `background_story` 只保留职业身份、稳定观察方式与根本矛盾，不复述日记历史、具体关系或建筑常识；人格、欲望、恐惧、底线、职业语气与长期记忆相互一致。
- 新增自动化验证 8 人日记格式、知识图谱结构、建筑 / 人物覆盖、中文显示标签、守备官开放性和六类 LLM 共享上下文注入；更新原先假设初始日记为空的专项测试。
- 基础 JSON / Schema、Mock / Prompt、Godot headless 与 Godot MCP 运行态验证通过；如环境已有真实 API Key，再用真实 provider 验证初始长期记忆确实影响对应业务回复且 `fallback_used=false`。

验收结果（2026-07-24）：

> 历史说明：以下人物故事与真实模型问答锚点是 T0059 当时的验收记录；T0060 已全量替换当前人物文案，这些旧故事不再代表现行数据。T0059 的数据结构、加载、去重与隐私边界仍是当前技术基线。

- 新增独立 `data/npc_initial_long_memory.json`：8 人各 3 篇第一人称日记，共 24 篇；每条均使用运行时完整 8 字段，固定 `day=0 / source=initial_long_memory / model_provider="" / model_name="" / model_fallback_used=false / debug_reason=seeded_before_game`。每人图谱均为 `key_value_replace_v1 / by_subject`，覆盖其余 7 人、守备官、全部 15 座配置建筑和至少 2 个个人故事主体。广场、公告牌未误列为建筑。
- 建筑认识已逐条对照当前权威规则审校，修正了“昏迷者进入诊所”“围墙升级增加器械槽”“训练必须同时有武器和坐骑”“围墙当前已阻止穿越”等错误或歧义；本职建筑记录更细，其他建筑保持粗略且正确。所有守备官初始认知均显式保留开放判断。
- 重写 8 人 `background_story`，只保存稳定职业视角、价值尺度与根本矛盾；具体人生节点、人物关系和建筑知识只留在长期记忆。`npc_profiles.json` 的 `diary=[] / knowledge_graph={}` 继续作为空运行字段占位，避免复制第二份种子数据。
- `NPCSystem` 在生成实体前验证初始记忆数据与档案 id 完全对应，再装载日记和替换式图谱；无效或缺失数据会中止 NPC 初始化并报告具体错误。首次睡眠反思仍只追加日记、替换实际发生变化的知识键。
- 六类正式 NPC LLM payload 均注入初始长期记忆。移除 `NPCContext.knowledge_graph` 的运行时重复镜像；当时对话以顶层 `long_memory` 为目标唯一长期记忆，参与者副本不重复私人日记与图谱；T0071 后 `speaker_npc` 已从正式对话请求完全删除。六份 Prompt 同步实时事实优先、初始历史边界与守备官关系开放性。
- 自动化通过：`verify_npc_initial_long_memory.py`、`verify_npc_initial_long_memory.gd`（8 人 / 24 篇完整格式日记 / 15 建筑 / 六类上下文 / 重复 initialize 幂等）、`verify_npc_character_profiles.gd`、`verify_daily_reflection_system.gd`、`verify_gm_panel.gd`、后端 Schema、六份 Prompt 和 `verify_mock_model_adapter.py`。
- 真实 DeepSeek `deepseek-v4-flash` 专项在 `LLM_FALLBACK_TO_MOCK=false` 下通过：当时的莉娜 / 欧文两条旧故事锚点均被准确复述，usage 为 2 次调用、0 失败、`fallback_used=false`。两条旧故事已由 T0060 替换，不再保留为现行文案示例。
- Godot MCP server / addon 4.0.1 与 Godot 4.6.2 冻结运行 `Main.tscn`：8 个 NPC Area3D 实体均存在，每人 3 篇日记、25 个知识主体且包含守备官；莉娜对话顶层长期记忆非空、嵌套 target 长期记忆为空，payload 47714 字符；编辑器错误日志为空，验证后已停止场景。

---

## T0058 向所有 NPC 公开基础资源储备与建筑升级协助常识

状态：Done
优先级：P0
前置任务：T0054, T0055, T0057
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

让所有 NPC 中心 LLM 请求共用的 `station_context` 每次都携带驿站当前对外公开的基础资源储备，只公开粮食、餐食、木材、石料和铁；同时在基础驿站规则中明确建筑升级会缓慢推进，成员可以选择协助正在进行的升级以加快进度。

验收标准：

- 六类正式 NPC LLM 请求的唯一顶层 `station_context` 都包含从 ResourceSystem 当前运行态读取的粮食、餐食、木材、石料和铁，资源变化后的下一次请求立即反映新值。
- 共享资源上下文不得包含第纳尔、酒、聚合装备、具体装备、工程器械、马匹或其他未授权库存；LLM 不获得资源写入或结算权。
- `station_rules` 新增世界内口吻的建筑升级规则，明确升级会缓慢推进，`assist_upgrade` / “协助升级建筑”可加快正在进行的升级；是否存在可协助目标仍以动态 `allowed_actions` 和 BuildingSystem 权威状态为准。
- Schema、六份 Prompt、Mock / endpoint、Godot 六类 payload 与 GM 只读快照同步更新；自动化同时验证资源白名单、实时刷新、升级规则和 `assist_upgrade` 的英文技术值 / 中文名称。
- 环境已有真实 API Key 时，用真实 provider 验证 NPC 能读出当前基础资源并理解协助升级，且 `fallback_used=false`；无可用真实 Key 时标记真实 API 未验收。

验收结果（2026-07-23）：

- `LLMBridge` 在六类 NPC 正式请求共用的唯一顶层 `station_context` 中新增 `basic_resource_reserves`，每次从 ResourceSystem 实时读取粮食、餐食、木材、石料和铁；计划 / 判别 / 修订的 `current_resource_states` 同步收窄为同一白名单。
- `StationSceneContext` 严格要求五项资源按稳定顺序各出现一次，拒绝第纳尔、酒、装备、器械、马匹和其他资源 id。共享资源只读，不改变 ResourceSystem 权威边界。
- `station_rules` 新增第六条“建筑升级缓慢推进，成员可协助加快”。六份 Prompt 已按职责解释：日计划 / 修订在动态 `allowed_actions` 提供 `assist_upgrade` 时认真考虑，没有活动升级目标时不得自造；判别、战时心理和反思不越权选择或伪造完成事实。
- 既有 GM `station_context` 只读输出增加“公开基础资源（5）”并显示六条规则。自动化覆盖 Schema、Mock / endpoint、六份 Prompt、Godot 六类 payload 实时刷新 / 隐藏库存、英文 `assist_upgrade` 技术值与中文名称、计划目录和 GM。
- 真实 DeepSeek `deepseek-v4-flash` 对话准确复述粮食 23、餐食 4、木材 17、石料 9、铁 6，并说明选择“协助升级工械坊”；真实 `/npc/plan_day` 生成合法 24 小时计划并实际包含 `assist_upgrade`，均 `fallback_used=false`。
- Godot MCP server / addon 4.0.1 与 Godot 4.6.2 运行态确认粮食从 18 变为 20 后下一次上下文即时刷新，五项之外无资源泄露，升级规则和中英文行动字段正确；清理旧日志后重新运行无新增编辑器错误。

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

> 历史说明：本任务当时的按类型聚合显示已由 T0043 的逐位置显示覆盖。

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

## T0019 接通三状态启动模式与正式游戏循环

状态：Done
优先级：P0
涉及文档：`AI_NPC_SYSTEM.md`, `GODOT_ARCHITECTURE.md`, `DATA_SCHEMA.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

为 `Main.tscn` 增加统一的三状态启动开关，并让默认启动进入正式游戏循环。正式循环开局时，所有 NPC 都完成一次起床与每日计划制定，然后立即执行当前小时计划；暂不实现新手引导内容，但保留明确占位状态。

启动状态：

- 静止调试：保持当前无自动起床 / 无自动计划的启动状态，供开发调试。
- 正式循环（无新手引导）：开局触发所有 NPC 起床、制定每日计划并执行当前小时行动。
- 正式循环（新手引导占位）：暂时复用正式循环，同时记录新手引导已请求但尚未实现，给 T1505 保留接入点。

验收标准：

- `Main/Systems` 存在统一启动编排系统，并在 Inspector / 场景属性中提供三个互斥状态。
- `Main.tscn` 默认选择“正式循环（无新手引导）”。
- 静止调试状态不自动写入 `wake_up` / `plan_created`，不自动指派 NPC 行动。
- 两个正式状态都会为 8 名 NPC 各写入一次 `wake_up`，生成 24 小时计划，并立即执行第 1 天 06:00 的计划项。
- （T0019 当时验收口径，已由 T0022 覆盖）每日计划当时复用 LLM / Mock / 规则降级；当前正式开局和新一天只允许真实 LLM 成功，仍不新增第二套行动或资源结算。
- 新手引导状态暴露稳定占位快照，但不伪造已实现的教学步骤。
- 新增专项自动化验证，并通过每日计划、NPC 生成和项目加载回归。

验收结果（2026-07-16）：

- 新增 `GameStartupSystem` 并挂载到 `Main/Systems/GameStartupSystem`，Inspector 提供“静止调试 / 正式循环（无新手引导）/ 正式循环（新手引导占位）”三个互斥状态；`Main.tscn` 默认选择正式循环且不启用新手引导。
- 静止调试模式会暂停 `TimeSystem`、关闭 `DailyPlanSystem` 自动执行，并且不写入 `wake_up` / `plan_created`、不指派行动。
- 两个正式模式会先暂停逻辑时间与计划自动执行，为 8 名 NPC 逐人写入私有 `wake_up` 并进入“制定计划”；复用现有 LLM / 显式 Mock 优先和真实失败规则降级路径完成全部 24 小时计划后，再统一执行第 1 天 06:00 的计划项并恢复时间。
- 新手引导模式当前只在启动快照中暴露 `tutorial_requested=true` 与 `tutorial_status=placeholder_not_implemented`，正式游戏循环照常启动，不伪造教学内容。
- Headless 环境默认跳过自动启动，避免既有专项测试被正式循环污染；`tools/verify_game_startup_modes.gd` 会显式覆盖三个模式、8 人起床、计划和当前行动。
- 本功能可直接在 `Main.tscn` 运行并从 Inspector 切换，因此无需新增 GM 面板入口。
- 验证通过：`godot --headless --path . --script res://tools/verify_game_startup_modes.gd`、`verify_daily_plan_system.gd`、`verify_daily_plan_llm.gd`、`verify_structured_memory_events.gd`、`verify_npc_generation_click.gd`、`verify_action_system_basic.gd`、`verify_gm_panel.gd` 与项目 headless 加载；Godot MCP 连接自检通过。

故障修复（2026-07-16，Done）：

- 实机正式启动时 8 次 `/npc/plan_day` 全部返回 HTTP 503；`/debug/llm_usage` 证明真实 DeepSeek 已配置，但模型输出为截断、空字符串或非法 JSON，异常类型均为 `JSONDecodeError`。
- 当时先以扩大计划类输出额度、关闭 DeepSeek thinking 和计划类紧凑重试恢复开局；T0020 已进一步移除全部正式业务调用的客户端单次输出 token 上限，并把截断 / 非法 JSON 重试覆盖到五类正式 call_type。
- （T0019 当时的历史实现，已由 T0022 覆盖）正式开局当时使用最多 2 路并发和单人规则降级；当前实现已改为 8 路并发、每人最多 3 次真实请求，任一仍失败则整批暂停且不降级。
- `/npc/revise_plan` 原先受固定单次输出额度截断，4 次实机失败均为 `finish_reason=length`。现保留 `data/prompts/plan_revision_system_prompt.txt` 的紧凑返回要求，只允许返回 1-3 个变化小时项与当前小时行动；后端额外校验 NPC id、最多 3 项、行动白名单和当前小时，不再发送客户端输出上限。
- Godot 计划重评估改为 `request_npc_plan_revision_async(...)`，不会在主线程同步等待；请求完成后应用模型修订或规则降级并执行当前小时项，超时 / 失败仍释放 TimeSystem 慢速。
- 新增 / 更新 `verify_plan_revision_prompt.py`、`verify_plan_revision_prompt_real.py`、`verify_daily_plan_reevaluation.gd`、`verify_game_startup_modes.gd` 和 `verify_game_startup_real_async.gd`。
- 真实 DeepSeek 验收通过：计划修订和真实开局计划均返回 `finish_reason=stop` 且无 fallback；T0020 又对当前无客户端输出上限的路径完成全 call_type 回归。
- Godot MCP 本轮因重复 Codex 会话导致连接被替换，未用于场景运行验收；已改用 Godot 4.6.2 headless 专项脚本和真实后端路径验证，待关闭重复会话后再做编辑器内复验。

---

## T0020 审计全部 LLM 输出限制与时间降速

状态：Done
优先级：P0
涉及文档：`AI_NPC_SYSTEM.md`, `API_BUDGET.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

移除正式 LLM 业务调用中不必要的单次输出 token 硬限制，避免对话、每日计划、计划修订、战时心理判定或首次睡眠总结再次因固定上限截断为非法 JSON；同时审计所有 Godot LLM 请求是否在影响当前场景状态时按规则暂停或申请 `TimeSystem` 慢速，并在成功、失败、取消、超时和降级后释放。

验收标准：

- 盘点后端所有正式 `call_type` 和供应商请求参数，不再依赖 1200 / 2048 / 4096 等固定单次输出 token 上限。
- 保留独立的累计 API 预算守门；预算上限与单次生成截断必须在配置、usage 和文档中明确区分。
- 所有正式业务接口继续进行 JSON、Schema 和业务白名单校验，失败时记录真实原因并进入明确规则 / 模板降级，不使用 mock 伪装成功。
- 对话、常规每日计划、计划修订、战时低血量心理判定和首次睡眠总结在等待模型时按规则申请慢速；正式开局批量每日计划继续由 `GameStartupSystem` 全局暂停时间。
- 请求成功、失败、取消、超时、业务降级路径都不会遗留慢速请求；只读 health / usage 和显式 mock 调试入口不申请慢速。
- 补充自动化审计，并使用当前真实 provider 对全部已接通正式业务 `call_type` 做回归验证。

验收结果（2026-07-16）：

- `ModelAdapterConfig`、`.env.example`、本地 `.env` 和正式供应商请求均已移除旧单次输出 token 配置；`dialogue`、`plan_day`、`revise_plan`、`battle_judgement`、`daily_reflection` 都不再发送 `max_tokens`。`/health` 暴露 `client_output_token_limit_applied=false`。
- 五类正式 call_type 在返回空内容、非法 JSON 或 `finish_reason=length` 时都会使用对应业务的紧凑提示重试一次；原有 Pydantic Schema 和 NPC id、行动白名单、计划小时、允许判定结果等业务校验保持不变。
- T1406 的 `LLM_BUDGET_MAX_*` 累计预算守门保留且默认关闭。它只限制累计调用、累计 token 或累计费用，不再与单次生成长度混用。
- `LLMBridge` 为五类正式业务提供异步路径；实际 UI / 玩法调用中的玩家对话、NPC-NPC 消息、每日计划、计划修订、低血量心理判定和首次睡眠总结均不再用 2 秒同步等待阻塞主线程。T0020 当时暂设的业务总时长已由 T0021 移除；health / usage 仍使用 2 秒只读短超时。
- 五类正式请求在 `requires_time_slowdown=true` 时注册带 call_type 的 TimeSystem 慢速原因，并在成功、失败、取消、超时或降级后释放；正式开局批量计划使用 `requires_time_slowdown=false`，继续由 `GameStartupSystem` 全局暂停时间。运行态快照新增每个请求的注册 / 释放审计。
- 新增 `tools/verify_llm_call_audit.py` 与 `tools/verify_llm_time_slowdown_audit.gd`。Python mock / Schema / endpoint 回归、Godot 启动 / 计划 / 对话 / 低血量 / 首次睡眠总结回归和项目 headless 加载均通过。
- 当前真实 DeepSeek 已分别通过对话、每日计划、计划修订、战时低血量心理判定和首次睡眠总结业务路径；真实 8 人开局计划批次也通过，未使用 mock fallback。
- Godot MCP 本轮仍因重复 Codex 会话导致连接被替换，未强行继续；场景与系统验证使用 Godot 4.6.2 headless 完成。

---

## T0021 移除 LLM 正常生成的固定总时长误杀

状态：Done
优先级：P0
涉及文档：`API_BUDGET.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

修正 T0020 中按业务类型设置 75 / 90 秒固定总时长的错误边界。模型仍在排队、发送 keep-alive 或持续生成内容时不得被 Godot 客户端按固定墙钟时间判失败；网络连接失败和真正长时间无任何数据仍需返回可处理错误并释放 TimeSystem 慢速。

验收标准：

- Godot 不再为对话、每日计划、计划修订、低血量心理判定和首次睡眠总结设置 75 / 90 秒业务总时长。
- Godot 只对连接本地 / 游戏后端使用短连接超时；业务请求发送后等待后端完成，不因正常生成时间长而主动误杀。
- Model Adapter 使用供应商流式输出或 keep-alive 感知，将超时语义拆分为连接超时和数据空闲超时；持续收到 token / keep-alive 时不触发空闲超时。
- 连接失败、供应商流真正长时间无数据、HTTP 错误、取消和 Schema 失败仍返回可处理错误，记录真实原因并释放慢速。
- 补充自动化验证，覆盖超过旧 75 / 90 秒语义的“仍有进展不超时”配置边界，以及流式 JSON 聚合和空闲超时配置。

验收结果（2026-07-16）：

- `LLMBridge` 已删除五个按 call_type 区分的 75 / 90 秒导出变量；五类正式业务向本地 / 游戏后端发出请求后使用 `response_timeout=0`，即不设置客户端响应总时长。`request_timeout_seconds=2` 现在只用于建立后端连接和 health / usage 等只读短请求。
- Model Adapter 改用 `stream=true` 与 SSE 聚合完整 JSON；持续收到模型 token、DeepSeek 排队 keep-alive 或其他流数据时会继续等待，不存在 30 / 75 / 90 秒墙钟总时长。
- 旧 `LLM_TIMEOUT_SECONDS` 已移除，替换为 `LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS=10` 与 `LLM_PROVIDER_IDLE_TIMEOUT_SECONDS=120`。前者只保护供应商连接建立，后者只处理连接建立后长时间完全无任何数据的死连接，不限制正常生成总时长。
- 流式响应仍记录完整 `finish_reason`、usage 和最终内容；`finish_reason=length`、空内容或非法 JSON 继续按 call_type 紧凑重试一次，Schema 与业务白名单校验不变。
- `tools/verify_llm_call_audit.py` 新增 SSE token 分片、keep-alive、usage 聚合、旧字段移除和连接 / 空闲配置断言；`tools/verify_llm_time_slowdown_audit.gd` 新增业务请求无总响应 deadline、只读请求保留短 deadline 的验证。
- fake provider、Mock、预算、五类 Prompt、Godot 降速、计划重评估、首次睡眠总结、低血量心理判定、三状态开局和项目加载回归均通过。
- 真实 DeepSeek 流式验收通过：对话 4 条、每日计划、计划修订、战时对话 / 低血量判定、首次睡眠总结全部成功；真实 8 NPC 开局异步计划批次也通过，无 mock fallback。
- Godot MCP 本轮仍因重复 Codex 会话导致连接被替换，按规则未强行使用；Godot 4.6.2 headless 与真实后端路径已完成验收。

---

## T0022 正式每日计划禁用 Mock / 规则降级并改为 8 路并发

状态：Done
优先级：P0
涉及文档：`AI_NPC_SYSTEM.md`, `API_BUDGET.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

修复真实每日计划被错误标记为 `mock_plan_day`、正式开局在真实调用失败后仍以 `rule_plan_fallback` 继续游戏的问题。正式游戏每日计划必须由真实 LLM 成功生成；Mock provider、缺少 provider 证明、请求失败或响应非法都不得写入可执行计划。开局 8 名 NPC 改为 8 路并发，失败只允许重试真实请求，不允许 Mock 或规则降级。

验收标准：

- 真实 provider 成功计划的 plan item、`plan_created` 事件和结果统一标记 `source=llm_plan_day`，不再使用 `mock_plan_day`。
- 正式开局明确要求真实 provider；后端为 `mock`、响应缺少真实 provider 标记、请求失败或本地校验失败时，不写入规则 / Mock 计划。
- 开局每日计划批次默认并发数为 8；批次快照暴露最大并发、每名 NPC 尝试次数和重试次数。
- 单个 NPC 的真实计划失败时最多重试 2 次，总计最多 3 次真实请求；仍失败则批次失败，游戏保持暂停、NPC 保持 `planning_day`，不执行任何人的当前小时计划。
- 显式 GM 纯规则计划和显式开发 Mock 验证入口可保留，但不得被正式开局或正式新一天流程调用。
- 更新自动化并用当前真实 DeepSeek 验证 8 NPC 同批并发全部成功、`failed_count=0`、所有 source 为 `llm_plan_day`、无 Mock / 规则降级。

验收结果（2026-07-17）：

- `/npc/plan_day` 成功响应新增 `model_provider`、`model_name`、`model_fallback_used`运行元数据；Godot 正式路径会先通过 `/health` 拒绝未配置 provider、Mock provider 和 `LLM_FALLBACK_TO_MOCK=true`，再拒绝业务响应中缺少真实 provider 证明、`model_provider=mock` 或 `model_fallback_used=true` 的计划。
- 真实每日计划的 result、24 个 plan item 和 `plan_created` 事件统一使用 `source=llm_plan_day`。已删除每日计划 `rule_plan_fallback` 实现；显式开发 Mock 与 GM `plan_generate_rule` 纯规则调试仍隔离保留。
- 正式开局与 `day_started` 都默认 8 路并发，批次快照暴露 `max_concurrent=8`、`max_attempts_per_npc=3`、`retry_count` 和 `attempt_count_by_npc`。单人失败最多重试 2 次真实请求；仍失败则整批保持暂停、禁用自动执行、NPC 保持 `planning_day`。
- 新增 `tools/verify_formal_plan_real_only.gd`：当后端显式为 Mock provider 时，正式路径在业务请求前拒绝，Mock 后端的 `plan_day` 调用数为 0。
- 真实 DeepSeek `deepseek-v4-flash` 验收通过：8 名 NPC 的 request id 在同一启动阶段全部发出，`count=8`、`successful=8`、`failed=0`、`fallback_count=0`，全部 `finish_reason=stop`、`attempt_count=1`；Godot 专项同时校验 8 份计划全部是 `llm_plan_day`。
- 验证通过：`python -m py_compile backend/app.py`、`verify_plan_day_endpoint.py`、`verify_plan_day_prompt.py`、`verify_plan_day_prompt_real.py`、`verify_backend_schemas.py`、`verify_formal_plan_real_only.gd`、`verify_game_startup_real_async.gd`、`verify_game_startup_modes.gd`、`verify_daily_plan_llm.gd`、`verify_daily_plan_system.gd`、`verify_llm_time_slowdown_audit.gd` 和 Godot 4.6.2 headless 项目加载。
- Godot MCP 仍因重复 Codex 会话导致连接被替换，本轮按项目规则未强行继续；场景与真实 provider 验收使用 Godot 4.6.2 headless 与已运行后端完成。

---

## T0023 行动失败真实 LLM 计划重估与 NPC 计划查看体验修复

状态：Done
优先级：P0
前置任务：T0022, T1002, T0405
涉及文档：`AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `UI_UX.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `GM_PANEL.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

修复正式行动失败重估仍把真实响应标记为 `mock_revision`、请求失败后使用 `rule_revision_fallback` 的问题。工位 / 目标位置占用、资源不足及其他日常行动失败都应触发真实 LLM 修订；NPC 面板新增当前生效计划查看入口，并保证事件库 / 见闻库详情在后台刷新时不改变玩家正在阅读的滚动位置。

验收标准：

- 正式计划重估只接受已配置的非 Mock provider 且 `model_fallback_used=false` 的 `/npc/revise_plan` 响应，成功统一标记真实 LLM 来源；失败只重试真实请求，不写入或执行 Mock / 规则修订。
- 工位 / 目标位置被占用、资源不足和其他已有行动失败类型都进入统一计划重估链路；请求期间注册 TimeSystem 慢速，成功、失败或取消后释放。
- 重估成功后覆盖当前生效计划中的修订小时项并立即执行当前小时项；新一天计划继续整体覆盖旧计划。
- NPC 面板在“事件库”上方新增“当前计划”按钮，详情显示该 NPC 当前生效的 24 小时计划并随计划生成 / 修订覆盖更新。
- 事件库和见闻库详情弹窗在新记录到达并刷新时保持当前阅读锚点与滚动位置，不自动跳到顶部。
- 补充自动化并完成 Mock 隔离、行动失败触发、UI 滚动保持、真实 provider 计划修订和项目加载回归。

验收结果（2026-07-17）：

- `/npc/revise_plan` 成功响应新增 `model_provider` / `model_name` / `model_fallback_used`；Godot 正式计划重估先拒绝未配置、Mock 或允许 Mock fallback 的 provider，并再次校验业务响应元数据。
- 资源不足、工位占用和其他已有日常行动 `failed` 结果进入统一异步重估；同类失败去重状态会在后续正常行动 / 成功修订时清理，不会永久阻止再次触发。
- 真实修订成功合并为 `source=llm_plan_revision`，写入 `plan_revised` 并执行当前小时项。请求 / Schema / 本地校验失败最多尝试 3 次真实请求；最终失败保留原计划，不写 Mock / 规则修订或伪成功事件。
- NPC 面板在事件库正上方新增“当前计划”按钮，显示当前 24 小时计划、当前小时、行动、原因和来源；每日计划替换及计划重估后随 `npc_daily_plan_changed` 覆盖刷新。
- 事件库 / 见闻库详情重写文本时保存垂直与水平滚动值，并用刷新代次合并同帧连续更新；新事件 / 见闻不会把玩家正在阅读的位置跳回顶部。
- Mock 隔离验收：独立 `LLM_PROVIDER=mock` 后端的 health 被正式重估拒绝，`/debug/llm_usage` 显示调用数为 0。真实 DeepSeek 验收：`provider=deepseek`、`model=deepseek-v4-flash`、`call_type=revise_plan`、`success=true`、`fallback_used=false`、`finish_reason=stop`，Godot 应用来源为 `llm_plan_revision` 且慢速请求已释放。
- 验证通过：`python -m py_compile backend/app.py`、`verify_plan_revision_endpoint.py`、`verify_backend_schemas.py`、`verify_plan_revision_prompt.py`、`verify_daily_plan_reevaluation.gd`（关闭后端 / Mock 隔离 / 真实 DeepSeek）、`verify_npc_panel_state.gd`、`verify_npc_order.gd`、`verify_daily_plan_system.gd`、`verify_llm_time_slowdown_audit.gd`、`verify_gm_panel.gd` 与 Godot 4.6.2 headless 项目加载。
- Godot MCP 仍因重复 Codex 会话导致连接被替换，本轮按项目规则未强行继续；场景和真实 provider 验收使用 Godot 4.6.2 headless 与当前后端完成。

---

## T0024 NPC 日记 / 知识详情入口与跨天 LLM 并发来源审计

状态：Done
优先级：P0
前置任务：T0022, T0023, T0405, T1002
涉及文档：`AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `UI_UX.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

把 NPC 面板长期信息入口整理为等宽的“当前计划 / 日记 / 知识”三按钮，日记与知识图谱改在详情弹窗阅读；确认首次睡眠总结与跨天计划最多可让 8 名 NPC 同批并发调用真实 LLM，并系统审计正式 LLM 成功结果的 provider 元数据和 Godot 来源映射，消除真实结果被硬编码成 `mock_*` 的同类错误。

验收标准：

- NPC 面板的“当前计划 / 日记 / 知识”三个按钮从左到右等宽排列，每个约占原计划按钮宽度三分之一；日记不再内嵌显示在 NPC 面板。
- 日记按钮打开该 NPC 的逐日总结弹窗；知识按钮打开按主体与关系组织的知识图谱弹窗；计划 / 日记 / 知识在状态刷新时更新且不打断事件库 / 见闻库的阅读滚动位置。
- 首次睡眠总结调度显式限制为最多 8 路并发；同一时刻 8 名符合条件的 NPC 可同时发出请求，批次 / 调试快照可观察实际并发数。
- 正式 `day_started` 跨天计划继续以 8 路并发生成，并有自动化同时验证并发配置与 8 名 NPC 的成功响应。
- `/npc/daily_reflection` 及所有正式 LLM 成功接口统一返回真实 `model_provider`、`model_name`、`model_fallback_used` 元数据；Godot 仅在 provider 确为 Mock 时使用 `mock_*` 来源。
- 完成静态来源审计、基础 Mock / fake provider 自动化、8 路并发回归和当前真实 provider 验收；失败原因保留为真实错误，不用 Mock 伪装成功。

验收结果（2026-07-17）：

- NPC 面板事件库上方已改为“当前计划 / 日记 / 知识”同排等宽三按钮；日记不再内嵌。T0046 起日记弹窗只显示逐日第一人称记录，不再显示独立 `memory_summary`；T0046 当时知识弹窗会显示当前值、可信度和最后更新时间，T0061 已进一步收为只显示中文主体 / 关系 / 值。
- 计划、日记和知识详情随权威状态更新；事件库 / 见闻库既有滚动位置保持逻辑继续通过自动化，刷新不会打断玩家阅读。
- `DailyReflectionSystem` 新增 `FIRST_SLEEP_SUMMARY_MAX_CONCURRENT=8` 与异步快照，真实 8 NPC 专项观察到 `active_count=8`、`max_observed_concurrent=8`，8 份结果均写为 `llm_daily_reflection`。
- `DailyPlanSystem` 批次快照新增实际峰值；真实开局与 `day_started` 跨天各完成一轮 8 路并发，均为 8 成功、0 失败、0 fallback、来源 `llm_plan_day`，全部完成后才恢复时间。
- 后端五个正式 LLM 成功接口改用统一 `model_success_payload(...)` 附加 provider / model / fallback 元数据；Godot 来源审计确认不存在 `mock_revision`，睡眠总结只在 provider 明确为 Mock 时使用 `mock_daily_reflection`，缺失来源证明或模型 fallback 不伪装成真实成功。
- 当前真实 DeepSeek usage：`daily_reflection=8`、`plan_day=16`，合计 24 成功、0 失败、0 fallback，全部 `finish_reason=stop`、`attempt_count=1`。显式 Mock 后端的正式计划隔离仍通过，调用数为 0。
- 验证通过：Python compile、daily reflection / battle / plan / revision endpoint 与 Prompt、Schema、LLM 静态审计；Godot 项目加载、NPC 面板、首次睡眠总结、本地模板、真实 8 路总结、每日计划、真实开局 + 跨天、正式 Mock 隔离、低血量判定、指令、LLM 降速和 GM 面板回归。
- Godot MCP 本轮仍因重复 Codex 会话连接被替换，按项目规则未强行继续；场景与真实 provider 验收使用 Godot 4.6.2 headless 和当前后端完成。

---

## T0025 NPC-NPC 自主对话计划行动与设计行动白名单补齐

状态：Done
优先级：P0
前置任务：T0023, T0701, T0705, T1002
涉及文档：`AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `GM_PANEL.md`, `UI_UX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

把已存在的 NPC-NPC 对话底层能力接入正式每日计划与行动失败重估，使 NPC 可选择带目标的“找某个 NPC 对话”行动、移动到目标所在地点、暂时打断双方普通行动并自动完成有限轮对话；对话结束后，仍可行动且处于工作模式的参与者进入统一计划重评估。同步对照 `game_design.md` 的计划可选行动，补齐设计中应由计划选择但当前未进入 `allowed_actions` 或没有执行闭环的行动。

验收标准：

- `talk_to_npc`（或等价配置化行动）进入每日计划和计划修订 `allowed_actions`，要求合法 `target_id` 且不能选择自己、昏迷/逃离/深睡或不存在的目标。
- 发起者会前往目标当前信息地点；到达并确认双方可对话后开始 NPC-NPC 对话，普通工作被打断且工位释放，对话最多进行配置轮次，不依赖玩家手动输入。
- NPC-NPC 每轮继续使用真实 `/npc/dialogue`、保留 provider/usage/慢速与失败原因；正式路径不得用 Mock 伪装成功。结束、失败、取消或高优先级模式切换后不遗留行动、移动、对话锁或 TimeSystem 慢速。
- 对话实际完成轮次写入双方事件库，并按地点公开规则传播；结束后仍可行动且处于 `behavior_mode=work` 的参与者进入统一真实计划重评估。
- 工位占用失败的修订 Prompt 在目标占用者可交涉时可选择对话，而不是被固定示例诱导为原地 `idle`；对话目标及交涉目的进入结构化计划项。
- 对照 `game_design.md` 计划行动清单完成审计：应由计划选择的缺失项补齐；战斗、逃离等程序强制模式与玩家专属行为保持在各自权威系统，不伪装成普通日程行动。
- 新增自动化覆盖计划白名单、目标校验、移动、打断释放工位、自动轮次、事件传播、结束重估、并发互斥、失败清理及设计行动清单回归；完成真实 provider NPC-NPC 对话路径验收。
- 真实 8 路开局若模型选中了合法 `action_id + target_id + location_id`，但把其冗余 `action_kind` 写成语义近似的其他枚举，后端仅允许从唯一白名单候选确定性规范化该字段；不得更换行动、目标或地点，也不得把其他 Schema / 业务错误伪装成成功。

验收结果（2026-07-17）：

- 新增配置化 `talk_to_npc`、`pray_at_chapel`、`visit_location`、`seek_guard_officer`，并将设计中的逃离意向保留为由 CombatSystem 执行的特殊计划候选；`escape_intervention_dialogue` 继续排除在日程之外。动态协助候选只在存在昏迷者、修复或升级任务时出现。
- 工位失败上下文会携带占用者 ID、姓名、行动、地点和工位快照。真实修订 Prompt 可选择具体占用者；即时目录排除已有对话、对话接近预定、规划 / LLM 活动、非工作模式与不可行动目标，未来日计划仍可保留短暂规划中的 NPC 作为将来对话目标。
- NPC 对话执行已覆盖移动 / 一次重定向、双方预定、独立邀请接受 / 拒绝、接受后普通行动打断与工位释放、最多 3 轮真实异步回复、事件入库、结束后对仍可行动且处于 work 模式的参与者独立重评估、玩家只读对话草稿、高优先级行为模式、跨小时清理、迟到修订丢弃和新失败排队。无 Mock / 规则计划修订伪装成功。
- 后端按 `action_id + action_kind + target_id + location_id` 精确校验；修订若把第 6 个工作时段改成对话，必须同时补回工作时段。真实 DeepSeek 工位占用修订返回 `talk_to_npc -> priest_01 @ clinic`，合并后 6 个工作阶段；真实 NPC-NPC 回复为 `reply_to_npc`，两条链路均 `fallback_used=false`。
- 真实 8 路开局曾暴露合法唯一候选的冗余 `action_kind` 被模型写成近义枚举；后端现只在 Schema 已通过且 `action_id + target_id + location_id` 唯一命中候选时规范化该字段，并通过 `model_normalizations` 记录原值、规范值和路径。未知枚举、重复候选、目标 / 地点 / 对话目标或工作阶段等错误仍返回失败。
- 验证通过：`verify_plan_action_catalog.gd`、`verify_plan_extended_actions.gd`、`verify_plan_target_replacement.gd`、`verify_training_plan_coordination.gd`、`verify_plan_revision_single_successor.gd`、`verify_plan_revision_late_failure_bound.gd`、`verify_plan_slot_dispatch_once.gd`、`verify_npc_npc_plan_action.gd`、`verify_npc_npc_dialogue_edges.gd`、`verify_action_system_basic.gd`、`verify_daily_plan_system.gd`、`verify_daily_plan_reevaluation.gd`、`verify_structured_memory_events.gd`、`verify_npc_proactive_talk.gd`、`verify_behavior_mode_state_machine.gd`、`verify_dialogue_sleep_summary_boundaries.gd`、`verify_llm_time_slowdown_audit.gd`、`verify_gm_panel.gd`，隔离 Mock 后端的 UI 自动化，Python Schema / Prompt / endpoint / LLM 静态审计，以及真实 `verify_workstation_dialogue_revision_real.py`。
- 规范化修复后的真实正式开局为 8/8 成功、0 失败、0 fallback、峰值并发 8，所有计划均为 `source=llm_plan_day`。Godot MCP 已连接用户当前编辑器，server/addon 均为 4.0.1 且版本一致；运行 `Main.tscn`、读取 8 名 NPC 计划来源及编辑器错误日志均正常。
- Godot 计划归一化改为按每项声明的 `hour` 建表后再排列 0-23；模型返回数组乱序不会交换行动时段，重复、越界或缺失小时会拒绝。`verify_daily_plan_system.gd` 已覆盖乱序还原及重复、缺失、越界小时拒绝。

---

## T0026 统一宿舍床位容量与睡眠占用权威

状态：Done（由 T0043 合并验收）
优先级：P1
前置任务：T0025
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`, `CURRENT_STATE.md`

任务目标：

对齐当前设计稿“宿舍固定 10 个床位”与建筑定义 / 睡眠执行。睡眠开始、结束、失败和中断应真实申请 / 释放床位，并让建筑面板、地点快照与计划候选看到一致容量；具体实现与验收已合并到 T0043。

验收结果（2026-07-21）：宿舍固定 10 个 `dormitory_bed`，睡眠自动申请 / 释放空床，满位返回真实失败；升级不扩床，只提高睡眠恢复效率和 Max HP。专项验收见 T0043。

---

## T0027 区分未来日计划候选与立即可执行修订候选

状态：Done
优先级：P1
前置任务：T0025
涉及文档：`AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`, `PROMPTS.md`, `TECH_ARCHITECTURE.md`

任务目标：

把“未来某小时可以安排”和“当前小时此刻可以落地”显式区分。即时修订候选应暴露并校验 `available_now` 或等价条件，覆盖资源、工位、目标与权威模式；未来日计划仍允许合理预期的暂时忙碌目标，避免仅依赖 Prompt 理解即时可执行性。

---

## T0028 NPC-NPC 自主对话气泡与只读进程 UI

状态：Done
优先级：P0
前置任务：T0025, T0701, T1005
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `UI_UX.md`, `GM_PANEL.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

让进行自主 NPC-NPC 对话的双方在世界中持续显示小型对话气泡。玩家点击任一参与者的气泡时，打开只读对话进程窗口，实时查看本轮双方发言、当前轮次和 LLM 等待状态；关闭旁听窗口不得结束、取消或提升后台自主对话。专项验证自主对话每一轮 `/npc/dialogue` 请求都会注册 TimeSystem 慢速，并在成功、失败或取消后释放。

验收标准：

- 自主 NPC-NPC 正式对话接受后，双方头顶均显示可点击的小型对话气泡；邀请待定 / 拒绝阶段不伪装成已经开聊，正式会话结束、失败、取消或高优先级中断后双方气泡消失。
- 点击任一气泡打开既有 `DialogPanel` 的只读旁听模式，显示双方姓名、当前 / 最大轮次、等待状态和本次会话历史；不显示玩家输入、发送、攻击或应征操作。
- 旁听窗口只观察匹配的 `dialogue_id`，实时刷新当前会话；玩家关闭窗口只关闭 UI，不调用 `end_dialogue()`，不取消 LLM 请求，不触发计划重评估。
- 自主对话继续不自动弹窗、不抢玩家输入焦点；若对话自然结束，已打开的旁听窗口保留最终记录并明确显示结束状态，玩家可自行关闭。
- 每一轮异步 `/npc/dialogue` 使用 `requires_time_slowdown=true`，按 `llm_dialogue_wait` 注册慢速；请求成功、失败、启动失败或取消后均释放，不遗留 TimeSystem 请求。
- 新增自动化覆盖双方气泡、气泡点击、只读 UI、实时轮次更新、关闭不打断、结束清理和逐轮慢速注册 / 释放，并回归现有玩家对话与自主对话路径。

验收结果（2026-07-20）：

- `NPC.gd` 为自主 NPC-NPC 会话双方运行时创建独立 `AutonomousDialogueBubble`：浅色小气泡内显示三点，拥有单独点击区；只在匹配的自主 `dialogue_id` 有效时显示，结束、失败、取消或权威中断后随双方状态刷新消失。
- 点击任一参与者气泡通过 `EventBus.npc_dialogue_bubble_clicked` 打开既有 `DialogPanel` 的只读旁听模式。窗口显示双方正式姓名、当前 / 最大轮次、公开性、等待第几轮 LLM 回复及本次历史；等待首轮时也显示已经说出口但尚未完整入库的开场内容。
- 旁听模式隐藏输入、发送、攻击、应征和公开性操作，关闭按钮只清理本地 UI，不调用 `end_dialogue()`、不取消请求、不触发计划重评估。会话自然结束后双方气泡消失，已打开窗口保留最终记录和结束状态，直到玩家自行关闭。
- `DialogSystem.send_npc_message(...)` 每一轮显式传入 `requires_time_slowdown=true`。`LLMBridge` 在每个异步请求返回 pending 前按 `llm_dialogue_wait` 注册 TimeSystem 慢速，并在成功、失败、启动失败或取消时释放；连续三轮专项确认每轮单独注册 / 释放且玩家倍率恢复。
- Fake provider UI 专项、真实 DeepSeek Godot 旁听 + 慢速专项和真实后端 NPC-NPC Schema 路径均通过；真实响应 provider=`deepseek`、model=`deepseek-v4-flash`、`response_kind=reply_to_npc`、`fallback_used=false`。玩家对话 UI、自主计划行动、竞态边界、NPC 面板和项目解析回归通过。
- 本功能可直接在 `Main.tscn` 观察；既有 GM `npc_talk <speaker> <target> [opening]` 可稳定构造双方气泡，因此不新增重复 GM 按钮或命令。

---

## T0029 对齐 NPC 对话邀请、三轮上限与结束重评估

状态：Done
优先级：P0
前置任务：T0025, T0028, T0701
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `DATA_SCHEMA.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

把自主 NPC-NPC 对话统一为“发起邀请 → 受邀方先接受 / 拒绝 → 接受后最多三轮”的正式合同。受邀方拒绝前不得先打断其当前工作；每个正式对话回复都可通过独立结构化字段主动结束。自主对话结束后双方重评估计划；玩家与 NPC 产生至少一次有效 LLM 回复后结束对话时，目标 NPC 重评估计划。

验收标准：

- `game_design.md`、行动定义、Godot 运行常量和 Prompt 明确统一为 NPC-NPC 正式对话最多 3 轮，不再保留 5 轮旧值。
- 自主发起时先向受邀 NPC 发出独立邀请判定；响应明确为 `accept` 或 `reject`。接受前不占用 / 打断受邀者普通工作，拒绝后不进入正式轮次。
- 接受后才让双方进入 `talk_to_npc` 状态；邀请文本与接受回复进入会话历史，但不占正式三轮计数。
- 每轮正式回复都可在 `reply_text` 之外设置 `should_end_dialogue=true`，无需等到最后一轮；达到第 3 轮时程序强制结束。
- 接受后的正常结束、提前结束及邀请拒绝都会对仍可行动且处于 work 模式的双方各发起一次计划重评估；玩家对话只有在至少完成一次有效 LLM 回复，或已经提交攻击事实时，结束才重评估目标，单纯打开 / 关闭或回复完成前取消不触发。
- Fake provider 自动化、后端 Schema / Prompt 测试、Godot 专项回归通过；有可用真实 Key 时，真实 NPC 邀请接受 / 拒绝与正式回复路径均不得使用 mock 或 fallback。

验收结果（2026-07-20）：

> 历史说明：本任务建立的邀请阶段、逐轮结束字段和玩家有效对话重评估仍有效；其中“正式会话最多 3 轮”与“邀请拒绝后双方重评估”的口径已由 T0030 替代。

- `game_design.md`、`data/action_defs.json`、`DialogSystem`、`ActionSystem`、`DailyPlanSystem` 与对话 Prompt 已统一为自主 NPC-NPC 正式对话最多 3 轮。邀请开场 / 决定保留在历史中，但 `current_round` 仍为 0；正式第 3 轮程序强制结束。
- `/npc/dialogue` 新增 `dialogue_phase=invitation|conversation` 与 `invitation_result=accept|reject|not_applicable`。后端拒绝超过 3 轮、邀请未明确决定、拒绝却未结束、接受却提前结束，以及正式回复重复携带邀请决定等跨字段错误。
- ActionSystem 到达目标后先发邀请判定。邀请 pending 期间受邀者保持原行动与工位且没有 `active_dialogue_id`；接受后才中断双方并显示对话气泡，拒绝直接结束且不进入正式轮次。邀请与每轮正式回复都使用独立 request id 和 TimeSystem 慢速。
- 正式对话任意一轮的结构化 `should_end_dialogue=true` 都会提前结束；自然 3 轮、第一轮主动结束与邀请拒绝专项均确认双方各重评估一次。玩家有效回复结束后目标恰好重评估一次；仅打开 / 关闭或未完成回复取消仍为 0 次，攻击事实例外保持重评估。
- `verify_dialogue_invitation_contract.gd`、`verify_npc_npc_plan_action.gd`、`verify_npc_npc_dialogue_edges.gd`、`verify_dialogue_sleep_summary_boundaries.gd`、旁听 UI、Python Schema / Prompt / endpoint / business contract 和 LLM 静态审计通过。真实 DeepSeek `deepseek-v4-flash` 已分别返回邀请 `accept`、邀请 `reject` 和正式 `reply_to_npc`，`fallback_used=false`；Godot 真实邀请 + 正式回复逐次慢速注册 / 释放与旁听回归通过。

---

## T0030 NPC-NPC 无硬上限会话与单方拒绝重评估

状态：Done
优先级：P0
前置任务：T0029
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `DATA_SCHEMA.md`, `UI_UX.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

移除自主 NPC-NPC 正式对话的 3 / 5 轮硬上限，继续把当前轮次作为 LLM 参考，并增加第 6 轮起的软性结束建议。任意一方在自己的正式回复中输出结束标记时，以该回复作为最后一句直接结束，不再请求另一方回复。邀请被拒绝时只让发起邀请者重评估计划，拒绝者保持原计划；被接受的正式会话结束后双方重评估。

验收标准：

- NPC-NPC 请求不再携带会导致程序强制截止的硬轮次上限；Godot 不按轮次数值结束，UI 不再显示 `当前 / 最大` 的硬上限。
- `current_round`、软性阈值和软性指导进入每轮请求上下文：事情说完即可结束；从第 6 轮起，若没有紧急或必要事项，应输出告别语并设置结束标记，紧急 / 必要事项允许继续。
- 任意正式回复的 `should_end_dialogue=true` 都会让该 `reply_text` 作为会话最后一句写入历史 / 事件，且不再产生下一次 NPC LLM 请求。
- 邀请被拒绝时，仅发起者触发计划重评估；拒绝者不被打断、不释放工位、不重评估。邀请被接受后的正式会话结束时，双方各重评估一次。
- Fake provider、Schema / Prompt / endpoint、Godot 会话与旁听专项通过；有真实 Key 时，真实 provider 验证软性轮次提示和结束标记，不得使用 Mock / fallback。

验收结果（2026-07-20）：

- NPC-NPC 会话状态与后端请求统一使用 `max_rounds=0` 表示无程序硬上限，新增 `soft_round_threshold=5` 与非空 `soft_round_guidance`；Godot 不再按轮次值截断，旁听 UI 改为显示当前轮次、无硬上限与第 6 轮起建议收尾。
- Prompt 将 `current_round`、软阈值和收尾规则作为参考：当前事情谈完即可在最后一句自然告别并设置 `should_end_dialogue=true`；第 6 轮起若无紧急 / 必要事项应告别结束，确有必要可继续。
- 正式回复先追加到历史与 `dialogue_turn` 事件，再检查结束标记；任一方设置结束后立即终止，不调度下一次 LLM。专项 Fake 会话已越过软阈值运行至第 7 轮，确认不存在第 3 / 5 轮程序截断，并确认最后一句后无额外请求。
- 邀请被拒绝时 `reevaluation_targets_on_end` 仅保留发起者；拒绝者未被打断、工位 / 当前行动保持且不重评估。接受后的正式会话结束仍让双方各重评估一次。
- Python Schema、Prompt、Mock endpoint、业务合同和 Model Adapter 回归通过；Godot 邀请合同、计划行动、竞态、旁听 UI、LLMBridge 与逐轮降速审计通过。真实 DeepSeek `deepseek-v4-flash` 验证邀请接受、拒绝及第 6 轮非紧急收尾，均 `fallback_used=false`；真实 Godot 邀请 + 正式回复旁听链路及两次慢速注册 / 释放通过。

---

## T0031 NPC-NPC 实时旁听复验与艾达初始剑盾

状态：Done
优先级：P0
前置任务：T0028, T0030, T0901
涉及文档：`game_design.md`, `CURRENT_STATE.md`, `UI_UX.md`, `AI_NPC_SYSTEM.md`, `DATA_SCHEMA.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

确保自主 NPC-NPC 对话气泡可点击打开实时旁听弹窗，会话进行中逐轮刷新，结束后弹窗保留直到玩家手动关闭；会话仍进行时，关闭后可再次点击任一参与者气泡重开同一会话。让已入伍的老兵副官艾达在新游戏初始化时直接装备剑盾，不消耗玩家开局库存。

验收标准：

- 接受邀请后的双方气泡均可点击；点击打开只读弹窗并实时显示当前会话历史和等待状态。
- 会话进行中手动关闭弹窗不结束 / 取消后台对话，可再次点击任一参与者气泡打开同一 `dialogue_id` 的最新记录。
- 会话自然结束后气泡消失，但已经打开的弹窗保留最终文本，不自动关闭；玩家可手动关闭。
- 艾达的新游戏初始装备槽包含正式 `sword_shield` 主武器，兵种判定为剑盾近战；该初始化不通过玩家赠送入口、不扣减全局武器库存，也不伪造赠送事件。
- 新增 / 更新自动化覆盖上述 UI 生命周期和艾达初始装备，并回归装备、兵种、战斗、NPC-NPC 旁听和项目解析。

验收结果（2026-07-20）：

- 复验确认已接受的自主 NPC-NPC 会话会为双方显示独立可点击气泡；点击进入既有 `DialogPanel` 只读旁听，逐次 `dialogue_updated` 实时刷新历史、轮次和当前等待状态。
- 玩家在 LLM pending 时关闭旁听不会结束会话或取消请求；再次点击任一参与者气泡会按同一 `dialogue_id` 恢复最新待回复文本。自然结束后双方气泡清理，已打开窗口保留最后一句和结束状态，直到玩家手动关闭。
- 艾达档案新增 `initial_equipment.main_weapon=sword_shield`；`EquipmentSystem` 在定义加载后从正式武器配置装载完整槽位，空槽才应用，不走玩家装备入口、不扣 `weapons`、不写 `equipment_given`。玩家后续换装继续正常返还旧剑盾库存并写 `equipment_changed`。
- 更新专项断言并通过 `verify_npc_npc_dialogue_observer_ui.gd`、`verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_combat_pacing.gd`、`verify_combat_alarm_rally.gd`、`verify_combat_strategies.gd`、`verify_no_available_combatants_failure.gd`、NPC 档案 / 生成 / HUD 资源回归及 `godot --headless --path . --quit-after 2` 项目加载。气泡与装备均可直接在 `Main.tscn` 前端观察，已有 GM `npc_talk` / `unit_type` 足够辅助复验，无需新增调试入口。

---

## T0032 修复自主对话气泡真实鼠标点击

状态：Done
优先级：P0
前置任务：T0028, T0031
涉及文档：`CURRENT_STATE.md`, `UI_UX.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

修复玩家在主场景中能看到 NPC-NPC 对话气泡、但真实鼠标点击无法打开旁听弹窗的问题。现有 debug 直接调用验证不足，必须按实际 Camera3D 屏幕投影与 Godot 3D 拾取链路复现并覆盖。

验收标准：

- 对话气泡出现后，屏幕上点击气泡可稳定打开同一 `dialogue_id` 的只读旁听弹窗。
- 气泡点击不会被 NPC 本体点击区抢占，也不会意外打开 NPC 面板。
- 双方气泡都可点击；关闭旁听后仍可通过真实鼠标点击重新打开。
- 自动化必须模拟实际屏幕坐标鼠标点击，不能只调用 `debug_click_dialogue_bubble()`。
- 回归 NPC 本体点击、旁听实时更新 / 结束保留与项目加载。

验收结果（2026-07-20）：

- 根因是 `NPCSystem` 全局 `_unhandled_input` 先做 3D 射线拾取；命中气泡子 `Area3D` 后沿父节点找到 NPC id，错误进入 NPC 本体选择并消费输入，气泡自己的 `input_event` 因此永远收不到该点击。
- `AutonomousDialogueBubble` 新增 `interaction_kind`、`npc_id`、`dialogue_id` 元数据；`NPCSystem` 改为返回结构化世界交互，气泡命中直接发出 `npc_dialogue_bubble_clicked`，NPC 本体命中才进入原面板选择。
- `verify_npc_npc_dialogue_observer_ui.gd` 不再依赖 debug 直调：用 Camera3D 把双方气泡世界坐标投影到屏幕坐标，再向 Viewport 推送真实鼠标移动 / 按下 / 释放。验证双方首次打开和关闭后重开都成功、同一会话不变、NPC 面板不误开；对话结束后再真实点击 NPC 本体，面板仍正常打开。
- 验证通过：真实鼠标旁听专项、`verify_npc_generation_click.gd`、`verify_npc_panel_state.gd`、`verify_npc_npc_dialogue_edges.gd` 与项目 headless 加载。功能直接在主场景可见，现有 GM `npc_talk` 足以造出测试会话，无需新增 GM 入口。

---

## T0033 玩家对话可选剩余日计划重估与马塞尔酿酒人设

状态：Done
优先级：P0
前置任务：T0029, T0032, T1003
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `UI_UX.md`, `DATA_SCHEMA.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `DEV_LOG.md`

任务目标：

在马塞尔的人设中简短补充“擅长酿酒”，但不把酿酒描述为其本职工作。为 NPC 与守备官的玩家对话增加“是否重估计划”开关：守备官主动发起时默认关闭，NPC 主动找守备官时默认开启；开启后，只有至少完成一轮有效 LLM 回复的对话在结束时才重估目标 NPC 从当前小时到当天结束的全部计划。

验收标准：

- 马塞尔的档案明确包含简短的“擅长酿酒”，且仍保持神父职业定位。
- 玩家-NPC 对话面板显示“结束后重估计划”开关；守备官主动发起默认关闭，NPC 主动发起默认开启，旁听模式不显示该开关。
- 开关关闭时，仅打开 / 关闭、未完成回复和普通有效对话结束都不触发对话型计划重估；攻击事实仍按独立异常规则触发重估。
- 开关开启时，完成至少一轮有效 LLM 回复并结束后，只触发一次真实计划重估，并要求覆盖当前小时至 23 点的全部剩余小时；已过去小时保持不变。
- 后端与 Godot 双层校验“剩余日全量重估”小时范围和行动白名单；正式路径不使用 Mock / 规则降级。
- 补充自动化并回归玩家对话、NPC 主动交涉、计划修订、UI 与项目加载；有真实 Key 时验证一次真实剩余日计划重估。

验收结果（2026-07-20）：

- 马塞尔档案已补充简短的“他擅长酿酒”，职业仍为神父。
- 对话面板已提供“结束后重估计划”开关：守备官主动对话默认关闭，NPC 主动交涉默认开启；只读旁听与逃离挽留不显示。
- 开启后，仅完成至少一轮有效 NPC LLM 回复的玩家对话会在结束时发出一次剩余日重评估；T0044 后关闭时只恢复本次对话确实打断且仍匹配当前计划的当前小时行动，攻击仍走独立强制重评估。
- `remaining_day` 修订由 Godot 与后端共同要求完整覆盖当前小时至 23 点，保留过去小时、精确匹配当前即时行动与行动白名单；正式路径不使用 Mock / 规则降级。
- Python Schema / Prompt / endpoint、Godot UI / 对话边界 / 主动交涉 / 修订范围和项目加载回归通过；真实 DeepSeek `deepseek-v4-flash` 返回 16 个剩余小时项，`fallback_used=false`。

---

## T0034 同步工械坊、铁匠铺、马厩与具体库存设计

状态：Done
优先级：P0
前置任务：T0804, T0805, T0806, T0901, T1508
涉及文档：`game_design.md`, `ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`, `UI_UX.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `COMBAT_SYSTEM.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `CURRENT_STATE.md`, `TASKS.md`, `DEV_LOG.md`

任务目标：

在改代码前先冻结四组设计合同：铁匠铺 / 工械坊的目标选择与分阶段制造、按具体物品保存的库存与装备条件、马匹个体生态、NPC 马匹分配与战时上下马。设计必须继续遵守程序权威结算和建筑信息节点的字段级传播规则。

验收标准：

- 列出 `game_design.md` 已规定且当前 Demo 要制造的全部金属武器 / 盔甲、木质武器 / 箭矢和工程器械，并明确归属建筑、阶段数、逐阶段材料和具体库存 ID。
- 明确工作周期、阶段完成 / 中断 / 换目标 / 成品入库、多工位并行、资源扣除与确认弹窗规则。
- 明确制造状态和马匹数量只属于可进入建筑的内部 `special_state`：进入者收到当前快照，在场且可接收见闻的 NPC 只收到字段级差量；它们不进入广场建筑外部状态。
- 明确两匹初始成年马、马匹 HP / 饱食 / 进食 / 恢复 / 繁育 / 成长 / 养马额外 HP，以及建筑面板逐匹展示口径和可配置平衡参数。
- 明确马匹分配要求、幼马限制、武器收回联动、日常留在马厩、集结 / 战斗骑乘离厩和退出战斗返厩边界。
- 后续实现拆为 T0035-T0038，避免一次同时重写制造、库存、马匹和战斗。

验收结果（2026-07-20）：

- 已从设计源闭合铁匠铺 6 种、工械坊 5 种具体目标；补充箭束，不把泛称“简易塔防装置”解释成已删除的拒马。
- 已冻结配方阶段 / 材料、周期中断、整数阶段保留、多工位、revision、换目标确认与具体成品入库规则。
- 已冻结两匹初始成年马、个体生态、稀有繁育、成长 / 成年阈值、养马额外 HP、具体分配和战时上下马参数。
- 已在经济、Schema、UI、AI/NPC、记忆、战斗与架构文档中同步 `special_state` 严格室内传播边界；T0035-T0038 已于同日按该合同实现并回归。

---

## T0035 实现铁匠铺 / 工械坊目标选择与阶段制造

状态：Done
优先级：P0
前置任务：T0034
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`, `UI_UX.md`, `MEMORY_AND_INFO_SPACE.md`, `GODOT_ARCHITECTURE.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `DEV_LOG.md`

验收标准：

- 配方和阶段材料完全配置化；没有选择合法目标时，`work_blacksmith` / `work_workshop` 在占用工位和推进周期前失败。
- 一个完整工作周期原子完成一个阶段；中断只清除该 NPC 未完成的周期进度，已经完成的阶段保留。
- 同一建筑多个工位可并行贡献同一目标的不同工作周期；阶段完成仍由系统串行落账，不重复产出。
- 换目标会放弃该建筑当前项目的全部已完成阶段并中断旧目标工作；有任意已完成或进行中进度时必须经确认弹窗同意。
- 全部阶段完成后只增加对应具体物品库存 1 件，并把同一目标重置为 0 阶段，允许后续继续生产。
- 建筑面板提供目标下拉、阶段 / 总阶段文本与包含当前周期部分进度的进度条；UI 不直接扣资源或写阶段。
- 制造目标 / 阶段进入建筑内部 `special_state`，按进入快照和字段级室内差量传播；不公开到广场。
- 覆盖无目标、缺材料、阶段完成、中断保留、换目标确认 / 取消、完成入库、多工位与信息传播自动化。

验收结果（2026-07-20）：

- 新增配置化 CraftingSystem 与 11 个冻结配方；铁匠铺 / 工械坊未选目标时在占用工位前失败，周期只提交一个阶段，中断只丢弃当期小数进度。
- 换目标由 revision 中断旧周期并清零整数阶段；建筑面板在非零进度时显示“是 / 否”确认，阶段、当前周期和具体库存均由权威系统快照展示。
- 阶段提交时复验并原子扣料，全部阶段结束只增加对应 `item_*` 1 件并保留目标连续生产；升级后的两个工位可并行周期、串行提交连续阶段。
- 制造特殊状态只传播目标和整数阶段；专项及历史制造回归通过：`verify_crafting_pipeline.gd`、`verify_blacksmith_metal_gear.gd`、`verify_workshop_ranged_devices.gd`、`verify_action_system_basic.gd`。

---

## T0036 实现具体物品库存与按库存装备 / 部署

状态：Done
优先级：P0
前置任务：T0035
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`, `UI_UX.md`, `COMBAT_SYSTEM.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `DEV_LOG.md`

验收标准：

- 剑盾、长杆武器、弓、弩、铁盔、锁子甲、铁护腕、铁护腿、箭束、弩床、箭塔分别保存库存；不再以 `weapons` / `armor` / `defense_devices` 的可消费通用数量替代。
- 装备某件武器或某个盔甲部位时，只消耗该具体物品库存；库存为 0 时不能装备，换装归还旧具体物品。
- 部署弩床 / 箭塔时只消耗对应器械库存，另一种器械库存不能替代。
- HUD 详情、NPC 面板、建筑面板和 GM 入口展示具体库存；箭束本任务只作为具体库存，不擅自加入战斗弹药消耗。
- 现有装备、兵种、战斗策略、器械部署和故事初始剑盾边界回归通过。

验收结果（2026-07-20）：

- 11 种成品均使用独立 `item_*` 库存；武器 / 四个盔甲部位按定义中的 `source_resource_id` 精确消耗、换装返还，库存不足时由 EquipmentSystem 拒绝。
- 弩床与箭塔分别只消耗自己的具体器械；箭束只入库、不在本任务扩展弹药结算。旧聚合资源保留兼容定义但正式路径隐藏且禁止消费。
- NPC / 建筑 / HUD / GM 均改为具体库存；艾达的故事初始剑盾继续不扣库存。装备、器械、兵种与 UI 专项回归通过。

---

## T0037 实现马匹个体生态与马厩面板

状态：Done
优先级：P0
前置任务：T0034
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`, `UI_UX.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `DEV_LOG.md`

验收标准：

- 新游戏从配置生成两匹不同 ID 的成年马；每匹马拥有 HP、自然 HP 上限、养马额外 HP、饱食度、饱食度上限、成长度、成年状态、位置、喂食状态和分配状态。
- 马在马厩内缓慢掉饱食，马厩外加速掉饱食；只有在马厩内且缺口达到阈值时才开始持续进食，周期完成后原子消耗粮食并恢复饱食。
- 非战斗状态下，受伤马匹非常缓慢地消耗自身饱食恢复 HP，自动恢复只到自然 HP 上限；养马额外 HP 只能由有效养马工作重新培养。
- 只有马厩存在有效 `work_stable` 养马人时才推进繁育、幼马成长和额外 HP 培养；繁育每游戏分钟按养马能力低概率判定，至少两匹成年可繁育马，判定次数为成年可繁育马数减一。
- 幼马自然 HP / 饱食上限随成长提高；达到成年阈值即可参与分配 / 繁育，但成年后仍可继续成长到自然上限。
- 马厩 BuildingPanel 逐匹显示状态；建筑内部 `special_state` 只暴露马厩内总数 / 成年数 / 幼马数，不向 NPC 传播个体 HP、饱食、名字或分配详情。
- 提供可重复的调试推进 / 强制繁育接口和自动化，GM 只调用这些系统接口。

验收结果（2026-07-20）：

- 新增 HorseSystem 与配置化马匹平衡；新游戏生成“栗风”“灰鬃”两匹独立成年马，并实现厩内外饱食消耗、持续进食、耗饱食自然恢复、照料驱动成长 / 额外 HP 和低概率生育。
- 有效养马人取当前 `work_stable` 中养马能力最高者；成年阈值、幼马成长上限和马厩等级只提高生育概率的边界均已落实。
- 马厩面板逐匹显示 HP、饱食、成长、进食、位置和分配状态；建筑特殊状态严格只含物理在厩总数 / 成年数 / 小马数。GM 调试接口与生态专项通过。

---

## T0038 实现 NPC 马匹分配与战时上下马联动

状态：Done
优先级：P0
前置任务：T0036, T0037
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`, `COMBAT_SYSTEM.md`, `DATA_SCHEMA.md`, `CURRENT_STATE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `DEV_LOG.md`

验收标准：

- NPC 面板可从具体成年、未分配且当前在马厩的马匹中选择；只有已入伍且有主武器的 NPC 可获分配，幼马、已分配马、离厩马和不满足条件的 NPC 均被权威系统拒绝。
- 同一匹马最多分配给一名 NPC；分配后日常模式仍留在马厩，不因装备槽存在而立即离厩。
- 收回 NPC 主武器时自动解除马匹分配并清空坐骑槽；更换主武器保留分配，单独收回盔甲不影响马匹。
- NPC 进入 `rally` / `combat` 时自动骑乘已分配马并让该马离开马厩；退出这两种模式时马返回马厩。逃离、昏迷或失去合法装备时按规则解除 / 返回，不遗留占用。
- 兵种和既有战斗坐骑表现继续只读取 NPC 坐骑槽；马匹 HP 受战斗伤害仍留给后续战斗任务。
- 自动化覆盖资格、唯一分配、幼马拒绝、武器联动、战时离厩 / 返厩、建筑数量差量和兵种策略回归。

验收结果（2026-07-20）：

- NPC 面板只列出成年、未分配且物理在厩的马；HorseSystem 权威校验“已入伍 + 有主武器”，并保证一马一人。武器 / 盔甲 / 马匹下拉选择会即时刷新操作按钮。
- 分配后马在日常仍留马厩；`rally` / `combat` 自动骑乘离厩，退出战斗、工作或昏迷时返厩，失去入伍资格 / 主武器或逃离时自动解除分配。
- 装备槽继续保存带真实 `horse_id` 的兼容投影，兵种和战斗策略沿用既有读取边界；马匹战斗伤害按范围留给后续任务。资格、上下马、数量差量、装备和兵种回归通过。

---

## T0039 扩大右上角 NPC / 建筑面板并精简冗余提示

状态：Done
优先级：P0
涉及文档：`UI_UX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：
让右上角 NPCPanel / BuildingPanel 充分利用当前窗口的可用高度并适当增加宽度，减少查看完整内容时的纵向滚动；移除 NPC 未入伍或尚未分配马匹时的冗余坐骑说明，以及建筑未选择制造目标、切换制造目标风险的常驻说明。

验收标准：

- 两个面板固定在右上角，并随窗口高度延伸到安全边距内。
- 常用 NPC 与建筑内容在当前窗口下无需向下滚动即可完整查看；动态超长内容仍保留滚动保护。
- NPCPanel 不再常驻显示“尚未入伍，不能分配马匹”与“当前未分配马匹……”提示。
- BuildingPanel 不再常驻显示“尚未选择制造目标……”与“更换目标会放弃已完成阶段……”提示；真实切换确认弹窗仍保留风险说明。
- UI 自动化回归、项目加载和 Godot MCP 运行验证通过。

验收结果（2026-07-21）：

- NPCPanel 改为 800px 双栏布局并延伸至窗口上下 16px 安全边距；默认 1152×648 运行时正文高 536 / 可用高 592，外层滚动条关闭，事件与见闻摘要仍保留各自滚动。
- BuildingPanel 扩为 460px 并使用相同高度边界；铁匠铺、工械坊、围墙、主厅和当前马厩内容均可在默认窗口中直接访问，马匹子列表扩大到 310px，更多动态马匹仍可独立滚动。
- NPC 未入伍 / 合法但未分配马匹时不再显示冗余说明；制造未选目标及已有目标时不再常驻显示冗余说明，真实非零进度切换确认弹窗仍保留损失详情。
- `verify_npc_panel_state.gd`、`verify_crafting_pipeline.gd`、`verify_horse_ecology_assignment.gd` 与项目加载通过；Godot MCP 默认窗口运行检查确认两块面板外层均无垂直滚动。

---

## T0040 重做右上角对象面板的内容自适应布局

状态：Done
优先级：P0
前置任务：T0039
涉及文档：`UI_UX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：
修正 T0039 固定占满可用高度和 NPC 双栏导致的大面积空白、横向阅读与放大窗口不协调问题。NPCPanel 恢复单栏纵向信息层级；NPCPanel / BuildingPanel 均由当前可见内容决定自然高度，只把窗口安全高度作为上限，并在窗口尺寸变化时重新适配。

验收标准：

- NPCPanel 使用单栏布局，面板高度始终大于宽度。
- 两个面板的高度随当前 NPC / 建筑内容量收缩，不因窗口放大而强制拉到屏幕底部。
- 内容自然高度超过窗口安全高度时只在此时启用外层滚动；窗口放大后可恢复到内容自然高度。
- 面板保持右上角 16px 安全边距，窗口放大 / 缩小时自动重新定位和计算宽高。
- T0039 已移除的冗余马匹 / 制造说明不恢复，非零制造进度切换确认仍保留。
- 默认窗口与用户截图对应的大窗口均完成 Godot MCP 尺寸和视觉检查；专项回归及项目加载通过。

完成情况：

- NPCPanel 已撤销 T0039 双栏重排，恢复基础状态、长期信息、事件 / 见闻、交互与装备依次向下的单栏阅读顺序；宽度按窗口在 380-440px 间响应并保持纵向比例。
- NPCPanel / BuildingPanel 均先按最终宽度完成换行，再以正文组合最小高度 + 24px 内边距计算面板高度；窗口安全高度只作为上限，视口尺寸变化会重新计算位置与尺寸。
- BuildingPanel 宽度在 360-420px 间响应；马匹子列表按实际卡片自然高度和剩余窗口空间伸缩，默认窗口只保留子列表滚动、不出现外层双滚动，大窗口下完整两匹卡片无需滚动。
- 空的 NPC 临时交互结果行会隐藏；T0039 已删除的马匹 / 制造冗余说明保持删除，真实制造进度损失确认未变。
- `verify_npc_panel_state.gd` 覆盖默认 1152×648 与 2048×1109 布局、NPC 单栏 / 高宽比 / 自然高度 / 右侧边距，以及主厅 / 马厩内容量变化；制造、马匹专项和项目加载通过。Godot MCP 实测默认主厅面板 360×218、无滚动；默认马厩 360×614、仅马匹列表滚动；大窗口模拟 NPC 440×1017、马厩 409.6×601，均无外层滚动或大面积空白，编辑器错误日志为空。

---

## T0041 非计划 NPC 对话注入可选行动参考

状态：Done
优先级：P0
前置任务：T0025, T0029, T0033, T1402
涉及文档：`AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

让 NPC-NPC 与玩家-NPC 的所有 `/npc/dialogue` 非计划调用都携带目标 NPC 当前可选行动参考，使模型知道程序允许尝试哪些行动、列表外的行动当前做不到；该参考只用于理解和回答，不把对话变成计划生成，也不允许模型直接执行行动或结算权威状态。行动参考必须复用 `data/action_defs.json` 驱动的计划候选目录，后续新增或修改行为时不维护第二份手写清单。

验收标准：

- 玩家-NPC、NPC-NPC 邀请与 NPC-NPC 正式对话的请求都携带非空 `allowed_actions`；战时、征召、主动交涉、攻击回应和逃离挽留等复用 `/npc/dialogue` 的子路径自动继承。
- 对话 Prompt 明确 `allowed_actions` 只是能力边界参考，不要求输出计划；NPC 只能把列表中的行动描述为当前可尝试能力，列表外行动应明确为当前做不到，且不能声称已执行。
- 对话行动参考与每日计划复用同一动态候选构造函数；新增配置化行动进入计划候选后会自动进入对话参考，不复制行动 ID 清单。
- 后端 Schema / Prompt / endpoint 与 Godot payload 自动化覆盖行动参考存在性、玩家-NPC / NPC-NPC 两类调用、与计划候选一致性，以及“能做 / 做不到”回答边界。
- 基础 Mock / fake-provider 测试通过；环境有真实 Key 时，分别完成玩家-NPC 与 NPC-NPC 真实 provider 能力认知对话，且 `fallback_used=false`。

验收结果（2026-07-21）：

- `LLMBridge.build_npc_dialogue_payload(...)` 已直接复用日计划 `_build_allowed_action_candidates(npc_id, true)` 填充 `allowed_actions`；没有新增手写行为 ID 清单。`NPCDialogueRequest` 要求至少一条候选，遗漏会返回 400 `validation_error`。
- Prompt 已明确候选只是能力边界：列表内可尝试但仍受程序校验，列表外当前做不到；对话不生成计划、不选择下一步、不声称行动已执行。
- Godot 专项覆盖 2 类对话关系和 7 个具体上下文：`player_npc/work|rally|combat|avoid_combat`、`escape_intervention`、`npc_npc/invitation|conversation`。T0041 验收当时 7/7 与同 NPC 的日计划候选逐项一致、共 31 条；T0043A 新增并接入教堂行动后当前为 33 条。
- `verify_backend_schemas.py`、`verify_dialogue_prompt.py`、`verify_dialogue_mock_endpoint.py`、`verify_dialogue_business_contract.py`、`verify_mock_model_adapter.py`、`verify_api_budget_debug.py`、`verify_battle_judgement_prompt.py`、`verify_dialogue_action_reference.gd`、`verify_npc_character_profiles.gd`、`verify_wartime_dialogue.gd` 和项目 headless 加载通过。
- 真实 DeepSeek `deepseek-v4-flash` 完成 6 次 `/npc/dialogue` 验收，`failed=0`、`fallback_used=false`。玩家-NPC 回答确认“加工餐食没问题”，并以“连马都没骑过”否认骑飞龙；NPC-NPC 回答同样确认能加工餐食并否认骑飞龙。
- Godot MCP 4.0.1 server/addon 版本一致；从编辑器冻结运行 `Main.tscn`、推进 3 帧并定位运行态 `LLMBridge` 成功，编辑器错误日志为空。
- 功能可由玩家直接在 `Main.tscn` 现有对话界面提问验证，未新增权威状态或专属调试操作，因此不增加 GM 面板入口。

---

## T0042 NPC 面板人物背景弹窗

状态：Done
优先级：P1
前置任务：T0040, T1501
涉及文档：`UI_UX.md`, `AI_NPC_SYSTEM.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`, `game_design.md`

任务目标：

在 NPC 面板顶部姓名旁新增“背景”按钮，点击后用现有详情弹窗展示该 NPC 已进入 LLM Prompt 的人物设定。展示内容直接读取 `data/npc_profiles.json` 的同一份档案字段，不新增或复制背景文案，确保玩家看到的人设与模型收到的人设一致。

验收标准：

- “背景”按钮位于 NPC 面板最上方标题行、姓名旁边，且不破坏 T0040 的响应式单栏布局。
- T0042 当时弹窗展示 `LLMBridge._build_npc_setting(...)` 注入的外貌、背景故事、职业背景、性格、欲望、恐惧、底线、说话风格、代表性表达和能力字段；T0061 已删除代表性表达，现为其余 9 项。
- 切换 NPC 后弹窗只显示当前 NPC 的档案；档案字段缺失时安全显示“暂无”，不读取独立 UI 文案。
- 自动化测试验证按钮位置、弹窗开关、字段与 NPC 档案一致性和切换 NPC 无旧内容残留；项目加载与可视运行无错误。
- 功能可直接从 `Main.tscn` 点击 NPC 验证，不新增 GM 面板入口。

验收结果（2026-07-21）：

- `NPCBackgroundButton` 已位于 NPC 面板标题行姓名之后，点击复用现有详情弹窗显示 10 项 Prompt 人设字段。
- 新增 `NPCPromptProfile.gd` 作为 `npc_setting` 构造单一代码入口；LLMBridge 与 NPCPanel 均调用该入口，UI 不保存第二份背景文案。
- `verify_npc_panel_state.gd` 已验证按钮位置、10 项字段与当前档案一致、弹窗关闭，以及艾达切换到布鲁诺后旧背景不残留；T0040 默认 / 大窗口响应式布局断言继续通过。
- `verify_npc_character_profiles.gd`、`verify_dialogue_action_reference.gd` 和项目 headless 加载通过，确认人物 Prompt 与上一任务的对话行动参考未回归。
- Godot MCP 4.0.1 冻结运行 `Main.tscn`，实际打开艾达人物背景弹窗并完成画面检查；server/addon 版本一致，编辑器错误日志为空。
- 本任务不改变 Prompt 内容或调用次数，只把既有 Prompt 人设向玩家只读展示，因此无需新增 Mock / 真实 provider 调用验收。

---

## T0043 建筑位置、协作效率与升级封闭规则

状态：Done
优先级：P0
前置任务：T0016, T0025, T0026, T0037
涉及文档：`game_design.md`, `ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`, `PROMPTS.md`, `API_BUDGET.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

将教堂、诊所、训练场、食堂和宿舍的服务位置统一纳入建筑权威状态：程序按位置类型自动分配空位，面板逐位置显示占用情况；医生与教官以人数和技能共同提高治疗、训练效率；建筑升级可按配置增加非固定位置、效率和 HP，并在施工期间完全封闭；建筑受损统一降低活动效率。

本轮设计合同（覆盖旧口径）：

- 小教堂固定 `1` 个祭坛和 `10` 个祈祷席；祈祷使用祈祷席，主持弥撒使用祭坛。主持弥撒候选对所有 NPC 可见，但只有具备神父弥撒资格的 NPC 能执行，其他 NPC 会得到明确失败原因并触发计划重估。
- 小诊所初始 `1` 个诊疗位和 `2` 张病床；训练场初始 `1` 个教官位和 `2` 个训练位。升级可按级别同时增加服务位置、承载位置、效率和 HP。
- 食堂初始 `1` 个灶台且可升级扩展，固定 `10` 个用餐席；宿舍固定 `10` 张床。用餐席和宿舍床位不扩容，升级分别提高进食和睡眠恢复效率。
- 同类型位置由程序选择第一个空位，NPC 不指定编号；满位、建筑升级中或建筑被摧毁时返回可处理失败并进入计划重估。
- 同一诊所内全部在岗医生的医术等能力共同作用于全部病床；同一训练场内全部在岗教官的教练能力与相关技能共同作用于全部训练位，不建立手工一对一配对。
- 升级有资源消耗和持续时间；开始升级即中断并释放建筑内行动及位置、拒绝进入和使用，完成后一次应用容量、效率与 Max HP 奖励并重新开放。
- 建筑 HP 越低，工作、治疗、训练、进食与睡眠等单位时间推进效率越低；升级中或 HP 为 `0` 时效率为 `0`。
- 建筑面板不用“主动工位/被动工位”分类词，按配置顺序逐项显示，例如 `诊疗位1：莉娜占用中`、`病床2：空闲`。容量、名称、占用、可用状态与效率均属于建筑状态，并按地点信息空间规则暴露。

验收标准：

- 五座建筑的初始位置数量、固定/可扩展规则与上述合同一致，升级奖励支持同级多个位置增量和效率增量。
- 吃饭、睡觉、祈祷、主持弥撒、坐诊、接受治疗、指导训练、接受训练等行动均申请对应位置，完成/中断/失败时释放；无空位会产生真实失败上下文并触发重估。
- 非神父能在行动候选中看到主持弥撒及资格提示，但程序拒绝执行；具备资格的神父可占用祭坛执行。
- 多名医生/教官的数量与能力会提高病床/训练位人员的单位时间收益，建筑受损会降低所有受影响活动效率。
- 升级期间建筑不可进入和使用，已有使用者被安全中断并退出；升级完成后新容量、效率与 HP 生效。
- 建筑面板逐位置显示名称、编号、空闲或占用者；建筑状态快照及地点信息差量包含容量和占用变化。
- 新增专项自动化覆盖容量、位置分配、资格失败、多人效率、升级封闭、损伤效率和 UI 文案；相关既有回归与项目 headless 加载通过。

验收结果（2026-07-21）：

- `building_defs.json` 已落地五座建筑的准确初始位置、固定类型和逐级 `level_effects`：诊所 / 训练场升级至 3 级后分别为 `2+4`，食堂 3 级为 3 个灶台 + 固定 10 个用餐席，小教堂和宿舍固定容量不变；升级可同时增加 Max HP 与活动效率。
- BuildingSystem 统一提供建筑可用性、可进入性、精确受损 / 活动效率和自动位置申请；升级开始会封闭建筑、清退人员并释放位置，完成后一次应用配置奖励。NPCSystem 在移动发起和到达时复验封闭 / 摧毁状态。
- ActionSystem 已把吃饭、睡觉、祈祷、主持弥撒、诊疗和训练接到具体位置；满位返回结构化失败。普通祈祷不依赖神父，非神父可看到 `lead_mass` 及资格提示但程序拒绝，神父可占用祭坛。全部在岗医生 / 教官分别形成共享团队贡献，建筑受损会降低工作、恢复和成长效率。
- BuildingPanel 按配置顺序逐位置显示“名称：空闲 / 姓名占用中”，并显示建筑状态与精确运作效率；MemorySystem 传播外部效率分档以及室内位置新增、移除、改名、改类型和占用差量，精确 HP / 效率 / 剩余时长保持降噪。
- LLMBridge 的计划与对话候选包含 `eligible / available_now / unavailable_reason / required_ability`；三份 Prompt 明确禁止选择无资格行动和位置编号。Mock / Schema / Prompt 测试通过；真实 DeepSeek `deepseek-v4-flash` 顺序验证 `/npc/plan_day`、`/npc/revise_plan`、`/npc/dialogue`，无 fallback，并额外确认非神职园丁没有选择 `eligible=false` 的主持弥撒。
- 新增 `verify_building_service_positions.gd`，覆盖初始容量、自动空位、满位、弥撒资格、神父离站后普通祈祷、吃饭 / 睡觉占位、多人诊疗 / 训练、升级封闭 / 扩容与受损降效；建筑、行动、移动、面板、地点信息、每日计划与 Prompt 相关回归通过。锻造重估夹具同步先设置制造目标，并补齐 `insufficient_stage_resources -> resource_insufficient` 标准化。
- Godot MCP 4.0.1 与 Godot 4.6.2 连接正常、版本一致；冻结运行 `Main.tscn` 后读取到五建筑准确位置数量、神父 / 非神父弥撒资格及诊所面板 `诊疗位1 / 病床1 / 病床2` 逐项文本，编辑器无新增错误。
- 本任务覆盖 T0016 的按类型聚合 UI 历史口径、T0403/T0405/T0407 的“位置数量不传播”历史降噪口径，以及 T0025 的“神父离站后祈祷失败”旧口径；旧记录仅保留为当时实现历史。

---

## T0043A 服务依赖中断与教堂弥撒参与闭环

状态：Done
优先级：P0
前置任务：T0043
涉及文档：`game_design.md`, `ECONOMY_AND_BUILDINGS.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

补齐诊所、训练场和教堂中“服务者位置 + 承载位置”的开始条件与周期内依赖中断规则，并把教堂活动明确拆分为普通祈祷、主持弥撒和参加弥撒。

本轮设计合同：

- `receive_clinic_treatment` 开始时必须至少有一名有效在岗医生；周期内全部医生退出、失效或离开诊疗位时，病床治疗立即失败并释放病床。
- `receive_weapon_training` 开始时必须至少有一名有效在岗教官；周期内全部教官退出、失效或离开教官位时，受训立即失败并释放训练位。
- `pray_at_chapel` 是不依赖神父的普通祈祷，神父离站后仍可执行；但主持弥撒期间不可开始普通祈祷，弥撒开始时已经进行的普通祈祷也会失败并释放祈祷席。
- 新增 `attend_mass`：只有祭坛上存在有效 `lead_mass` 主持者时才可开始，占用一个祈祷席，不要求参与者具备“主持弥撒”能力。
- 主持弥撒正常完成时，同场仍在参加弥撒的 NPC 一同完成；主持弥撒异常中断、主持者离开或祭坛失效时，所有参加者立即失败并释放祈祷席。
- 上述开始失败和周期中断必须写入结构化失败上下文，释放位置，并进入既有计划重估；LLM 候选只暴露实时资格 / 可用性，不决定主持、占位或结算事实。

验收标准：

- 自动化覆盖诊疗 / 训练无服务者的开始失败、服务者中途退出导致承载者失败，以及位置释放和计划重估上下文。
- 自动化覆盖神父离站后的普通祈祷、弥撒期间普通祈祷失败、主持开始打断已有祈祷、无主持者不能参加弥撒、正常主持带动参加者完成、异常主持中断使参加者失败。
- `attend_mass` 进入计划 / 对话候选、GM 行动下拉、地点状态和事件链；非神父仍能看见但不能执行 `lead_mass`。
- Prompt、Mock / Schema、本地自动化、真实 provider（环境有 Key 时）、项目 headless 和 Godot MCP 运行态验证通过。

验收结果（2026-07-21）：

- `action_defs.json` 已为诊所病床、训练位和参加弥撒声明持续服务依赖；普通祈祷与主持弥撒声明互斥，主持开始会中断普通祈祷。
- ActionSystem 支持同批服务者在路上时依赖者等待、服务者到岗后自动重试；活动开始后最后一名医生 / 教官 / 主持者离岗会立即失败全部对应承载者、释放位置、保存 failure context、写结构化事件并触发既有计划重评估。
- `attend_mass` 已进入日计划 / 修订 / 对话候选、GM 通用行动下拉和运行态快照；主持正常完成时参加者共同完成，异常中断时共同失败。MemorySystem 按 action id 区分普通祈祷、主持和参加弥撒摘要。
- `verify_service_dependency_interruptions.gd` 覆盖三座建筑的开始失败、中途离岗、位置释放、教堂互斥及弥撒正常 / 异常收束；建筑、诊所、训练、计划、事件、候选、GM、面板、地点和项目加载回归全部通过。
- Python Schema、Mock endpoint 与三份 Prompt 合同通过；真实 DeepSeek `deepseek-v4-flash` 的 `plan_day`、`revise_plan` 和 7 次 `dialogue` 均通过且 `fallback_used=false`，教堂问答明确“无人主持仍可普通祈祷、不能参加弥撒”。对话 / 计划共享候选专项为 7/7 上下文、当前 33 条候选。
- Godot MCP 4.0.1 / Godot 4.6.2 连接正常且版本一致；冻结运行态确认弥撒前参加不可用、主持开始使普通祈祷失败、参加者绑定 `priest_01`、主持离岗后得到 `attend_mass_failed_leader_left` 且全部位置释放，编辑器无错误。

---

## T0044 对话后当前计划恢复与信息面板交互收敛

状态：Done
优先级：P0
前置任务：T0043A、T1006
涉及文档：`AI_NPC_SYSTEM.md`, `UI_UX.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

修正守备官有效对话结束后未重估时无法继续当前小时计划的问题，并收敛马厩、未入伍交互、事件 / 见闻详情和对象面板悬停反馈。

本轮设计合同：

- 守备官与 NPC 的有效对话会照常中断当前行动；对话结束时，若确实打断的是当前小时计划行动、未勾选结束后重估、未实施攻击且 NPC 仍可行动并处于日常工作模式，则重新执行被打断的原计划行动。该恢复只绕过本次对话前留下的“本计划阶段已执行”签名，不放宽正常计划去重。
- 仅打开再关闭、NPC 对话前本就空闲、被打断行动与当前计划不一致、重估计划、攻击、逃离 / 战斗等权威行为模式接管时不得恢复旧计划；恢复时如当前计划本身已不可执行，沿用既有结构化失败或重估流程。
- 马厩面板移除“马厩马匹”重复标题；摘要统一为“在厩 / 离厩”，逐匹只显示分配对象，不再重复骑手字段。
- 未入伍导致装备、盔甲、马匹或战斗策略控件禁用时，悬停提示“需先说服该人物应征入伍，才能进行这项操作。”；入伍后恢复各控件自身说明。
- 事件库 / 见闻库大号详情只展示与面板小框一致的玩家可见时间和摘要，不暴露事件 ID、内部类型、地点 ID、可见性、重要度、参与者 ID、目标 ID或 payload。
- 消除 NPC / 建筑对象面板底部悬停提示造成的闪烁黑框，修复不得改变资源、修复、升级或交互结算权威。

验收标准：

- 自动化覆盖“确实打断当前计划行动的有效对话 + 不重估”恢复当前小时计划，并确认空闲对话、重估 / 攻击等分支仍不恢复。
- 自动化覆盖马厩精简文案、未入伍禁用控件提示以及事件 / 见闻详情的字段白名单。
- 修复 / 升级提示仍可阅读，NPC / 马厩面板不再出现面板外反复显隐的黑框。
- 相关专项、项目 headless 与 Godot MCP 主场景运行态验证通过。

验收结果（2026-07-21）：

- DialogSystem 会记录本次有效玩家对话是否确实打断了运行时行动及其行动 ID；DailyPlanSystem 专用恢复入口只在该 ID 与当前小时计划行动相同，且保存签名与当前日 / 小时 / 计划版本 / 行动目标完全一致时清除签名并复用正常派发。NPC 原本空闲时不会重放本小时已完成短行动；普通重复派发仍返回 `already_executed_this_plan_phase`。
- 马厩面板移除重复标题，摘要改为“在厩 / 离厩”，逐匹只保留分配对象；未入伍 NPC 的武器、盔甲、马匹和战斗策略禁用控件统一显示征召前置提示。
- 事件库 / 见闻库详情改为与紧凑框相同的“时间 + summary”，不再显示内部字段或 payload；底层事件结构与 GM / 系统查询保持不变。
- NPCPanel / BuildingPanel 布局刷新保留当前高度等待换行计算，不再先撑至最大高度；建筑修复 / 升级浮动提示迁至 `Main/UI` 覆盖层，不再参与 BuildingPanel 最小尺寸计算。
- 新增 `verify_player_dialogue_plan_resume.gd`，并扩展 NPC 面板、交互、建筑位置与修复升级专项。相关 13 项 Godot 专项、项目 headless 均通过；Godot MCP 运行态确认马厩文案、全部征召提示、事件详情白名单和悬停前后面板高度一致，编辑器无错误。

---

## T0045 建筑进度面板、镜头粘键与属性成长文案修正

状态：Done
优先级：P0
前置任务：T0040, T0043, T0044
涉及文档：`CURRENT_STATE.md`, `UI_UX.md`, `GODOT_ARCHITECTURE.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `DEV_LOG.md`

任务目标：
修复建筑开始修复 / 升级及其持续状态刷新时右上角面板再次出现大面积空白；排查并修复俯视镜头偶发持续向下移动、表现如 S 键未释放的问题；把力量 / 智力属性提升事件从“守备官分配技能点”改为 NPC 自身通过体力 / 脑力锻炼获得能力提升的世界内叙事。

验收标准：

- 建筑进入修复 / 升级、进度刷新及完成后，BuildingPanel 都按当前可见内容自然高度收缩，不出现满高空白或尺寸闪烁。
- CameraRig 不直接轮询可能粘滞的全局物理按键状态；窗口失焦、文本输入焦点和按键释放后不会继续平移，中键拖拽也会在失焦时复位。
- `attribute_improved` 力量文案为“{NPC}通过锻炼体力，力量从 x 提高到 y。”，智力文案为“{NPC}通过锻炼脑力，智力从 x 提高到 y。”，不出现“守备官”。
- 建筑修复 / 升级、镜头输入和成长 / 记忆专项回归通过；Godot MCP 实际运行检查无错误。

验收结果（2026-07-21）：

- BuildingPanel 按建筑缓存已排版的稳定高度；修复 / 升级信号当帧不再使用过期满滚动内容高度，容器排版后再精确贴合。首次打开 / 切换建筑时透明测量，不暴露中间空面板。
- CameraRig 已改为事件式 WASD 状态；按键释放、窗口失焦、文本输入聚焦都会停止平移，窗口失焦同时取消中键拖拽。
- `attribute_improved` 事件 actor 改为 NPC 自身，力量 / 智力分别生成“锻炼体力 / 脑力”的精确摘要，不再出现“守备官”。
- `verify_building_repair_upgrade.gd`、`verify_camera_rig_input.gd`、`verify_skill_progression.gd` 与项目 headless 通过。Godot MCP 运行态确认围墙面板升级前 502px、升级中 554px、空白差 0；S 输入释放后镜头位置保持不变，按键缓存为 0，编辑器无错误。

---

## T0046 收敛长期记忆、注入动态驿站场景与扩展公告牌

状态：Done
优先级：P0
前置任务：T0024, T0405, T1005, T1405, T1506
涉及文档：`CURRENT_STATE.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `PROMPTS.md`, `API_BUDGET.md`, `UI_UX.md`, `GM_PANEL.md`, `DEV_LOG.md`

任务目标：

按当前中文玩家体验收敛首次睡眠长期记忆，只保留第一人称日记并让知识图谱以中文可读方式显示；所有包含 NPC 根本人设上下文的 LLM 请求统一加入不含战争任务的动态边境驿站基础场景简介；把公告牌扩展为“通告 / 参考日程”双页，并让初始与后续内容沿用广场信息节点规则进入 NPC 见闻。

验收标准：

- `DailyReflectionResponse`、Prompt、Godot 写入结构和日记 UI 不再生成、保存、显示或注入独立 `memory_summary`；长期记忆只保留增量第一人称日记和替换式知识图谱。
- 知识图谱内部允许继续使用稳定技术键 / 值，但 NPC 面板所有 subject / relation / value 都显示为中文；常见 NPC、地点、守备官、关系键和技术值均有中文映射，未知内容也不得把蛇形英文或英文技术值直接暴露给中文玩家。
- 所有携带共享 NPC 根本人设的 LLM 请求通过同一字段获得基础场景简介：当前是一个小型边境驿站、当前仍在驿站内的人员姓名与身份；名单从运行态 NPC 状态动态生成，逃离 / 离开者即时除名；简介不写具体守城任务、敌袭目标或抵抗要求。
- 公告牌面板使用专业可读的“通告 / 参考日程”双 Tab。通告编辑器打开时读取已发布文本，退出 / 关闭不保存，只有“发布”才更新广场当前通告并广播。
- 新游戏预置符合守备官口吻的战争告知与勤勉工作 / 应征号召；该初始通告无需玩家再次发布便属于广场当前状态，并预先写入所有初始 NPC 的见闻库。
- 参考日程由多条“开始时间、结束时间、内容”记录组成，支持新增、编辑与删除；初始日程综合 8 名 NPC 的正式计划倾向，使用通用“工作”措辞，覆盖睡眠、三餐、工作、每日一次弥撒及休息 / 祈祷，并明确它只是建议、不要求 NPC 严格遵守。
- 参考日程发布 / 更新后成为广场当前状态的一部分，即时写入当时在广场且可接收信息的 NPC 见闻；后来进入广场的 NPC 在当前状态快照中获得最新通告与参考日程。相关见闻始终附带“通用建议日程，仅供参考；有特殊事务可自行安排”的语义。
- 公告牌 UI 不自行决定事实，只调用 MemorySystem 的公告牌内容接口；公告牌仍不是建筑，不新增 HP、等级、工位、修复或升级数据。
- 新增专项自动化覆盖长期记忆 Schema、中文知识 UI、动态在站名单、通告草稿取消、日程增删改、初始见闻、广场即时广播和后来进入快照；既有公告、记忆、Prompt、LLM、GM 与主场景回归通过。
- Prompt / Schema 基础 Mock 验证通过；若环境已有真实 API Key，使用真实 provider 验证 8 名 NPC 计划倾向以及受影响的首次睡眠总结 / 共享场景上下文路径，并记录 provider、model、request id 与 `fallback_used=false`。

验收结果（2026-07-21）：

- `DailyReflectionResponse`、Model Adapter、Prompt、DailyReflectionSystem、NPCSystem 与 NPCPanel 均已移除独立 `memory_summary`；旧日记在运行时规范化时剔除该字段。长期记忆只追加第一人称日记并替换式更新知识图谱。
- `KnowledgeGraphPatch` 新增 `subject_label / relation_label / value_label`；反思 Prompt 与业务校验要求三类中文显示文本，NPCPanel 对稳定技术键 / 值、NPC、地点、守备官、常见关系及未知内容都提供中文显示 / 保底，不直出蛇形英文或英文技术值。
- 所有继承 `StationAwareNPCRequest` 的 NPC 人设请求都有一份顶层必填且在站名单非空的 `station_context`；`LLMBridge` 从当前运行态生成中文姓名 / 身份名单，一人逃离 / 离站后从 8 人缩减为 7 人。本条记录的是 T0046 当时的两字段简介合同；T0054 已在同一顶层对象中扩充完整建筑、工作行为和驿站规则。
- `data/notice_board_defaults.json` 提供守备官口吻的初始通告、10 条通用参考日程与固定参考性备注。`NoticeBoardPanel` 已改为“通告 / 参考日程”双 Tab；退出 / 关闭丢弃草稿，只有发布才分别调用 `MemorySystem.set_plaza_notice(...)` / `set_plaza_reference_schedule(...)`。日程支持时间段与内容的增删改，且不替换 NPC 个人计划。
- 通告 / 参考日程均属于广场当前状态；更新生成 `plaza_notice_changed` / `plaza_schedule_changed` 并即时广播给当时在场且可接收信息的 NPC，后续入场快照包含当前内容。新游戏初始通告和日程已预写全部初始在站 NPC 见闻，日程见闻始终带“仅用作参考、可自行安排”语义。逃离完成者会从地点人员节点移除且不再接收公告牌见闻；日程覆盖全天时新增草稿会明确提示调整重叠时段。公告牌仍不是建筑。
- Mock / Schema / fake-provider 与 Godot headless 专项通过，覆盖日记 Schema、中文知识 UI、动态 8→7 在站名单、通告草稿取消、日程增删改、初始见闻、广场即时广播与后续入场快照。Godot MCP 本轮不可调用，已按项目规则报告，未强行继续。
- 真实 provider 为 `deepseek / deepseek-v4-flash`，自动 Mock fallback 关闭。收紧 `value_label` 中文合同后的反思 1 次（request id=`verify_daily_reflection_prompt_real`）与携带共享场景的对话 / 每日计划 / 计划修订 / 战斗判定 4 类路径通过（对话专项 request id=`verify_station_context_real_dialogue`），均 `fallback_used=false`。8 人计划倾向采样 8/8 成功、0 失败、0 fallback、0 重试；usage 为 input 126323 / output 13974 tokens。样本中睡眠、三餐、工作、祈祷 / 弥撒和晚间休息的共同倾向已用于校准初始通用参考日程。

---

## T0047 修复建筑面板透明测量竞态与误触升级

状态：Done
优先级：P0
前置任务：T0045
涉及文档：`CURRENT_STATE.md`, `UI_UX.md`, `GODOT_ARCHITECTURE.md`, `ECONOMY_AND_BUILDINGS.md`, `DEV_LOG.md`

任务目标：

修复玩家真实点击建筑后 BuildingPanel 偶发永久透明、看似没有打开的问题，并阻止透明测量期间的面板和操作按钮拦截世界点击、误触发修复或升级。

验收标准：

- 首次打开、连续切换和快速点击不同建筑时，BuildingPanel 均在有限帧内恢复可见并贴合当前内容高度，不会永久停留在 `alpha=0` 或 1px 高度。
- 透明测量期间 BuildingPanel 整体不接收鼠标，隐藏的修复 / 升级按钮不会响应玩家本想投向世界的点击。
- 使用 Camera3D 投影后的真实屏幕坐标逐帧发送鼠标移动、按下和释放，覆盖全部可见建筑；每次都校验选中建筑、面板建筑、可见度、透明度和高度。
- 未明确点击面板操作按钮时，建筑等级、HP、资源和修复 / 升级作业不得改变。
- 建筑修复 / 升级、NPC / 建筑面板切换、制造、马匹和项目加载回归通过；Godot MCP 主场景运行无新增错误。

验收结果（2026-07-22）：

- 根因是透明测量协程直接等待 `VBoxContainer.sort_children`；容器未再次排序时协程永久挂起，留下 `visible=true / alpha=0 / height=1` 的可输入面板，后续世界点击可能命中透明修复 / 升级按钮。
- BuildingPanel 改为每个测量阶段最多 4 帧逐帧采样，并用 fit generation 丢弃旧任务；统一收尾恢复高度、透明度和交互。透明阶段通过 `mouse_behavior_recursive=MOUSE_BEHAVIOR_DISABLED` 屏蔽全部动态子控件，修复 / 升级回调增加隐藏 / 透明 / 测量中守卫。
- 新增 `tools/verify_building_panel_real_click.gd`，使用 Camera3D 投影并向 Viewport 发送真实鼠标移动 / 按下 / 释放，覆盖全部 15 个建筑 ID；全部在有限帧内显示正确，HP、等级、资源、修复 / 升级状态均未变化。
- `verify_building_panel_real_click.gd`、`verify_building_repair_upgrade.gd`、`verify_building_panel_workstations.gd`、`verify_npc_panel_state.gd`、`verify_crafting_pipeline.gd`、`verify_horse_ecology_assignment.gd` 与项目 headless 加载通过。Godot MCP 冻结主场景复验主厅面板 `alpha=1 / 360×270`、无升级、无资源变化，编辑器错误日志为空。
- 本功能可直接在 `Main.tscn` 点击建筑验证，不新增 GM 入口。

---

## T0048 统一所有计划重估为剩余日全量重排

状态：Done
优先级：P0
前置任务：T0023, T0025, T0030, T0033
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

取消行动失败、NPC-NPC 对话、指令变化等触发路径仍使用 1-3 个小时局部修订的旧合同。所有正式计划重估统一为：保留当前小时之前的既有计划，并由真实 LLM 完整重排当前小时到当天 23 点的每一个剩余阶段，与玩家对话开启“结束后重估计划”后的行为一致。

> 历史说明：本任务的全量 `remaining_day` 合同已由 T0049 取代。当前对话路径先判别、再仅修订精确小时；非对话路径默认直接修订当前小时。以下验收结果仅记录 T0048 当时已完成的历史实现。

验收标准：

- `DailyPlanSystem` 的行动失败、NPC-NPC 正式对话结束、邀请拒绝、守备官指令变化、攻击、主动交涉结束 / 超时、战斗结束 / 复苏及 GM 手动入口都只能发起 `remaining_day` 修订。
- Godot payload、Python Schema、后端业务校验、Mock 合同和 Prompt 不再提供 `local_changes` 分支；`revised_plan` 必须恰好覆盖当前小时至 23 点，过去小时保持不变。
- `immediate_action` 必须与当前小时的全量修订项一致；合并后的全天计划继续满足行动白名单、即时可用性和最低工作阶段规则。
- 在途重估的后继队列继续保留最新失败上下文，跨小时 / 跨计划版本的旧结果仍被丢弃，不因全量重排产生重复行动或无限修订。
- 补充自动化覆盖行动失败、NPC-NPC 对话和通用手动触发的统一范围；先跑 Mock / Schema / 本地回归，有真实 Key 时再完成真实 provider 剩余日修订验收。

验收结果（2026-07-22）：

- `DailyPlanSystem` 删除局部范围常量和分支，所有直接调用、EventBus 触发、在途后继和 GM 手动入口都固定携带 `remaining_day`；`LLMBridge` 即使收到旧范围选项也会强制输出唯一剩余日范围。
- `PlanRevisionRequest` 只接受 `Literal["remaining_day"]`；后端、Mock、紧凑重试和 Prompt 统一要求从当前小时至 23 点逐小时完整返回，`immediate_action` 与起始项一致。过去小时由 Godot 合并时保留，旧局部值在 Schema 层返回 validation error。
- `verify_plan_revision_remaining_day.gd` 新增行动失败、NPC-NPC `dialogue_completed` 和 GM 手动入口捕获，确认三者均发出相同范围；单后继队列、迟到失败上限、每日计划、玩家对话恢复、NPC-NPC 对话、主动交涉、服务依赖和 GM 回归通过。
- Python Schema、Mock adapter、Prompt、endpoint、行动合同、usage 审计和项目解析通过。真实 DeepSeek `deepseek-v4-flash` 剩余日修订一次返回 16 项，`fallback_used=false`；真实工位占用修订返回 `talk_to_npc -> priest_01 @ clinic`、共 16 个剩余小时项且保留 15 个工作阶段，随后 NPC-NPC 回复同样无 fallback。
- Godot MCP server / addon 均为 4.0.1，运行冻结主场景后把旧 `local_changes` 选项传入实际 `LLMBridge`，运行态 payload 仍为 `remaining_day`、起始小时 8、当前计划 24 项；编辑器错误日志为空。
- 现有 GM `plan_revise` 已直接覆盖新语义并可查看当前计划，无需新增重复入口；`docs/GM_PANEL.md` 已将说明替换为剩余日全量重排。

---

## T0049 对话后计划修改判别层与记忆详情默认定位最新

状态：Done
优先级：P0
前置任务：T0023, T0025, T0030, T0033, T0044, T0048
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `UI_UX.md`, `MEMORY_AND_INFO_SPACE.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

用“轻量判别 → 按需局部重估”取代 T0048 在对话结束后无条件重排剩余日的笨重流程。所有实际发生的 NPC-NPC 与守备官-NPC 对话结束后，先让真实 LLM 结合本轮对话和该 NPC 原 24 小时计划返回需要修改的精确小时集合；集合为空表示不修改且不得调用计划重估。集合非空时，第二次真实 LLM 调用继续携带既有完整重估上下文，但只允许输出判别出的小时。移除守备官对话面板中的手动“结束后重估计划”选项。事件库 / 见闻库详情首次打开时默认定位到最底部的最新记录，后台刷新仍保留玩家正在阅读的位置。

验收标准：

- 新增独立、可审计的对话后计划修改判别业务调用；轻量输入只包含当前时间、NPC 身份、对话类型、本轮实际对话、结束原因、轻量会话元数据和 NPC 原计划，不携带完整站点、记忆、人设、行动候选或当前指令；输出为去重、升序、不得早于当前小时的 `revision_hours`，空数组代表 0 个修改阶段。
- 玩家-NPC 和 NPC-NPC 的每个相关 NPC 都先独立判别；无有效对话内容、仅打开后关闭或取消未完成回复不触发。判别为空时不调用 `/npc/revise_plan`，被玩家对话打断且仍匹配原计划的当前行动按既有恢复规则继续。
- 双目标 NPC-NPC 会话在任一判别发起前为双方预注册组派发屏障，不论是否跨小时，都等待双方第一层与必要第二层全部终态后按计划依赖顺序放行；跨小时玩家对话也等目标 NPC 判别链终态后再派发新小时计划。终态失败 / 取消必须释放屏障。
- 判别非空时，计划修订请求保留此前的人设、状态、记忆、地点、资源、建筑、行动白名单、当前指令、失败上下文和完整原计划，只把响应小时严格限制为 `revision_hours`；未选小时保持不变。只有包含当前小时才允许 / 要求即时行动并重新派发当前阶段。
- 行动失败、指令变化、战斗 / 复苏和 GM 等非对话触发不经过对话判别层，直接使用受限小时修订，默认 `revision_hours=[current_hour]`，不再无条件完整重排当天剩余小时。
- 守备官-NPC 普通 / 主动交涉对话 UI 不再显示或保存“结束后重估计划”开关，由 NPC 判别结果决定；对话内已提交攻击即使没有完成 NPC 回复也作为有效事实进入同一判别，不由玩家开关豁免。非对话伤害另按其触发入口处理。
- 事件库与见闻库详情首次打开在排版完成后滚到最底部；弹窗已经打开时的增量刷新继续恢复刷新前滚动位置，不强制把正在读旧记录的玩家拉回底部。
- 判别结果与后续修订结果可从既有 GM 计划 / LLM 调试入口观察；先完成 Schema、Prompt、Mock、本地 Godot 自动化，再在已有真实 Key 时验收判别与受限重估真实链路。

验收结果（2026-07-22）：

- 后端已新增 `/npc/dialogue_plan_revision_judgement` 与独立 Schema / Prompt；第一层 payload 只含本轮对话、原 24 小时计划、时间、NPC 标识和轻量会话元数据。判别为空时停止，非空时 `/npc/revise_plan` 以 `selected_hours` 精确返回同一小时集合，Godot 仅合并这些项。
- 守备官-NPC、主动交涉、逃离挽留、对话内攻击及 NPC-NPC 邀请拒绝 / 正式会话均接入自主判别；玩家强制开关已删除。NPC-NPC 双方屏障、跨小时玩家对话、旧 D1 / 新 D2 回包乱序、stage2 同步启动失败、future-only 版本变更和失败 followup 均有定向回归，旧请求与排队请求不会提前或重复派发当前行动。
- 事件库 / 见闻库详情在布局完成后首次定位最底部；打开后的增量刷新恢复原滚动位置。`verify_dialogue_ui.gd`、`verify_npc_panel_state.gd`、`verify_npc_panel_interactions.gd` 与 `verify_gm_panel.gd` 通过。
- Python Schema、判别端点、精确修订端点、Prompt、行动合同、Mock 隔离与 usage 审计通过。真实 DeepSeek `deepseek-v4-flash` 验证了修改 `[14]`、第二层严格返回 `[14]` 以及不修改 `[]` 三条路径，均一次成功且 `fallback_used=false`。
- Godot 计划 / 对话专项、迟到失败上限、单后继、玩家恢复、NPC-NPC、主动交涉和睡眠边界回归通过；headless 解析通过。Godot MCP server / addon 4.0.1 匹配，冻结运行最新 `Main.tscn` 8 帧无警告，运行树不存在旧重估 toggle，编辑器错误日志为空。

---

## T0050 统一行动失败与对话后的两阶段计划重估

状态：Done
优先级：P0
前置任务：T0023, T0049
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

将日常行动失败后的计划处理统一到 T0049 的“轻量判别 → 按需精确阶段修订”链路。行动失败时，先让真实 LLM 结合权威失败事实、原 24 小时计划和轻量必要上下文判断是否需要修改；若不需要，返回 0 个阶段并停止。若需要，则返回需要修改的精确 `revision_hours`，第二次真实 LLM 修订继续携带既有完整失败重估上下文，但只允许改写这些阶段。

验收标准：

- 工位占用、资源不足、目标 / 建筑不可用及其他日常计划行动失败先调用独立可审计的计划修改判别，不再直接以 `[current_hour]` 调用 `/npc/revise_plan`。
- 判别输入包含当前时间、NPC 标识、原 24 小时计划、失败计划项、程序权威 `failure_type` / `failure_summary` 和必要的结构化失败上下文；第一层不重复注入完整人设、记忆、站点状态、行动候选或当前指令，也不输出行动。
- 判别输出沿用 `needs_revision + revision_hours` 合同；空集合表示不修改且不得调用第二层，非空集合必须升序、去重、不早于当前小时。
- 第二层保留行动失败原有的人设、状态、记忆、地点、资源、建筑、行动白名单、当前指令、失败上下文和完整原计划，只允许返回第一层判别出的精确阶段；未选阶段保持不变。
- 对话后链路继续使用本轮对话作为判别事实；行动失败链路使用程序权威失败事实。两者共享同一判别 Schema、Prompt、后端接口和修订合并合同，但来源与上下文字段可审计区分。
- 判别失败或取消时保留原计划并释放 LLM 慢速 / 派发锁；判别为空时不得形成修订重试循环。判别非空后的修订仍遵循真实 provider、最多三次尝试、过期响应丢弃和落地失败上限。
- 既有 GM 最近判别 / 修订结果入口能够观察行动失败两阶段链路；补齐 Mock、Schema、Prompt、endpoint、Godot 行动失败专项，并在已有真实 Key 时验证真实判别和受限修订。

完成结果（2026-07-22）：

- 已新增通用 `/npc/plan_revision_judgement`、`PlanRevisionJudgementRequest/Response` 和 `plan_revision_judgement_system_prompt.txt`；对话与行动失败用 `trigger_kind` 区分，旧对话专用命名保留兼容。
- `DailyPlanSystem` 已让明确日常行动失败先走第一层；空集合终止，非空才把原失败完整上下文和精确选中小时交给 `/npc/revise_plan`，等待期间纳入既有修订互斥、队列、过期校验、慢速与派发屏障。
- Python 全量非真实专项通过；真实 DeepSeek `deepseek-v4-flash` 行动失败判别返回 `[8, 14]`，第二层严格返回 `[8, 14]` 且 `fallback_used=false`。Godot 行动失败专项、真实资源不足两段式路径及计划、对话、工位、诊疗、GM 回归通过；同一失败在新计划阶段重新发生时会再次判别。

---

## T0051 可拖动弹窗与守备官会话完成 / 取消 / 挂起生命周期

状态：Done
优先级：P0
前置任务：T0049, T0050, T0701, T1006
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

让主界面的常用弹窗支持从顶部标题栏拖动并保持在可用视口内；把守备官-NPC 对话的单一“结束对话”拆为“完成对话 / 取消对话 / 挂起对话”，明确对话入库、计划修改判别、LLM 取消与 NPC 行动占用边界；玩家消息在点击发送后立即出现在历史中，不再等待 NPC 回复后才同时显示。

验收标准：

- DialogPanel、OrderPanel、NoticeBoardPanel、MerchantPanel、NPCPanel、BuildingPanel 及 NPC 详情弹窗可从顶部栏拖动，拖动结束后保持在当前可用视口内；GM 按钮既有拖动行为不受影响。
- “完成对话”沿用原结束语义：取消尚未完成的本轮 NPC LLM 回复，保存本次完整会话；只要已有守备官发言、NPC 发言或已提交攻击事实，就进入 T0049/T0050 的计划修改判别。玩家在等待回复时完成会话时，以已经即时显示的最后一条守备官消息作为结尾。
- “取消对话”取消未完成 LLM、丢弃本次守备官-NPC 会话，不写 `dialogue_turn`、不广播见闻、不触发计划修改判别，并恢复仍合法的被打断原行动；一旦本次对话提交过攻击，取消按钮置灰且系统拒绝取消。
- “挂起对话”只隐藏窗口，不结束、不入库、不触发计划判别、不取消正在等待的回复。NPC 继续保持与守备官对话的占用状态；挂起最多持续 2 个游戏小时，超时自动取消。若会话含不可撤销攻击事实，超时必须保留攻击与相关判别边界，不能把伤害伪装成未发生。
- 被挂起 NPC 头顶显示颜色区别于 NPC-NPC 自主对话的可点击气泡；点击气泡恢复同一 `dialogue_id` 的窗口、历史、等待状态和输入。NPC 面板“对话”按钮左上角显示橙色圆点，点击同样恢复挂起会话。
- 玩家点击发送后，守备官消息立即追加到对话历史，再异步等待 NPC 回复；等待期间仍可编辑下一条草稿，但发送 / 攻击保持禁用。迟到的已取消回复不得重新写入历史、事件或 NPC 状态。
- 守备官-NPC 的 `dialogue_turn` 只在完成会话时提交；取消会话不在事件库 / 见闻库留下本轮内容。NPC-NPC 自主对话仍按既有逐轮入库和旁听合同运行。
- 新增本地 Godot 自动化，覆盖拖动、即时消息、完成等待中请求、取消、攻击禁用取消、挂起 / 恢复、橙点 / 气泡与 2 游戏小时超时；基础 Mock / 现有对话、计划、记忆、NPC 面板和项目加载回归通过。

验收结果（2026-07-22）：

- 新增共享 `DraggablePanel.gd` 并接入对话、指令、公告牌、商人、NPC、建筑、NPC 记忆详情和 HUD 库存详情；运行态验证拖动位置保持并受视口限制。
- `DialogSystem` 已实现完成 / 取消 / 挂起、即时守备官消息、等待中完成、整场单事件提交、结构化结果延迟应用、攻击锁定取消、7200 逻辑秒超时和 `talk_to_guard_officer` 占用；`DialogPanel`、NPC 气泡和 NPC 面板橙点完成对应交互。
- `verify_dialogue_session_lifecycle.gd`、`verify_dialogue_ui.gd`、`verify_escape_intervention_dialogue.gd`、`verify_wartime_dialogue.gd`、`verify_npc_panel_state.gd` 与项目 headless 解析通过；相关计划恢复、主动交涉、睡眠边界、HUD、建筑、商人和对话引用回归通过。
- 已通过真实 DeepSeek `deepseek-v4-flash` 复验对话业务路径，usage 显示 `provider=deepseek`、`fallback_used=false`；Godot MCP 运行态确认三类按钮、拖动坐标、挂起占用、橙点 / 橙色气泡及点击恢复。

---

## T0052 NPC 制定计划期间的对话互斥与自主对话等待

状态：Done
优先级：P0
前置任务：T0049, T0050, T0051, T1005, T1006
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `UI_UX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `API_BUDGET.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

让日计划生成与即时计划重评估成为不可被对话打断的临界阶段：守备官入口明确置灰，系统调用也必须拒绝取消计划；NPC-NPC 对话动作遇到正在制定 / 重估计划的目标时保留动作与参与者预约，等待目标思考结束后再启动邀请流程。

验收标准：

- NPC 的 `llm_activity.kind == "plan"` 且处于活动状态时，NPC 面板“对话”按钮半透明禁用，悬停提示“NPC正在思考”；计划请求结束后按钮随状态刷新恢复。
- `DialogSystem` 在创建守备官对话草稿、激活草稿、发送首条消息等权威入口拒绝计划中目标，返回可处理的 `npc_planning`，且不得提升对话 epoch、取消计划 LLM 请求或打断其当前行动。
- NPC-NPC `talk_to_npc` 动作允许把计划中的 NPC 作为等待目标；发起者到达后保留 pending action 与双方预约，不立即写行动失败，也不触发失败型计划重估。
- 目标的计划 LLM 活动结束后，`ActionSystem` 自动重试原 pending action，再启动既有 NPC-NPC 邀请请求；目标失去行动能力、离开工作模式或进入不可打断状态时仍按既有规则失败并清理预约。
- 新增 / 扩展本地 Godot 自动化覆盖按钮状态、守备官权威入口不取消计划、NPC-NPC 等待与状态清除后的自动续接；项目 headless 解析和相关对话 / 计划回归通过。

验收结果（2026-07-22）：

- `NPCPanel` 已按 `llm_activity.kind=plan` 禁用对话按钮并显示“NPC正在思考”；`DialogSystem` 三层权威守卫统一返回 `npc_planning`，计划活动和原行动保持不变。
- `ActionSystem` 的自主对话 pending options 新增 `waiting_for_target_plan`；目标计划中保留双方预约且不发邀请 / 不写失败，计划清除后由状态信号延迟续接。`LLMBridge` 即时修订候选恢复当前可执行过滤，日计划保留稍后可交谈目标。
- `verify_dialogue_sleep_summary_boundaries.gd`、`verify_npc_npc_dialogue_edges.gd`、`verify_plan_action_catalog.gd` 及 NPC 面板、对话 UI、计划恢复、会话生命周期、NPC-NPC 计划行动回归通过；项目 headless 解析通过。Godot MCP 运行态确认按钮、tooltip、`npc_planning`、计划未取消，以及等待阶段 pending / reservation 均正确。
- 本任务不修改 Prompt、Schema 或 provider 输出合同；已使用配置后端的真实 DeepSeek `deepseek-v4-flash` 复验 NPC-NPC 邀请接受 / 拒绝与正式对话，`response_kind=reply_to_npc`、`fallback_used=false`。互斥 / 等待时序仍由 Godot 状态与 fake provider 精确控制验证。

---

## T0053 跨小时对话等待失效与 LLM 人设 / 记忆上下文一致性

状态：Done
优先级：P0
前置任务：T0050, T0052, T1202, T1404
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `COMBAT_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

> 历史说明：本任务的“普通同日跨小时即失效”口径已由 T0076 取代。当前已经开始接近 / 等待 / 邀请 / 正式交谈的日计划对话会跨普通整点延续；同小时计划替代、跨日和权威状态失效仍保留结构化失败。以下内容记录 T0053 当时实现。

任务目标：

让日计划发起的 NPC-NPC 对话在等待目标制定 / 重估计划期间持续校验当前计划项；跨小时后若说话者当前计划已不再要求与原目标对话，则以结构化行动失败退出等待并进入统一两阶段计划重估。同时统一日计划、重估判别、正式重估、对话和战时心理判定的人设、状态、短期记忆、长期记忆与当前指令上下文，保证同一 NPC 在不同 LLM 阶段的人格和心理依据一致。

验收标准：

- 仅日计划派发的 `talk_to_npc` 记录来源小时与目标；跨小时后若当前计划项不再是与同一目标对话，则释放双方预约、停止旧对话动作并写入带原 / 当前小时、原 / 当前计划项和等待原因的结构化失败；GM / 测试直接发起的对话不受此规则误伤。
- 上述失败通过既有 T0050 行动失败入口先请求计划修改范围判别，非空时再正式重估；判别层和正式重估层都收到同一 `failure_type`、`failure_summary`、`failure_context` 与失败计划项。
- 日计划、计划修改范围判别和正式重估共享 NPC 人设 / 当前状态、短期记忆、长期记忆、地点与当前指令上下文；对话既有同类上下文保持不回退。
- 战时加入战斗 / 避战 / 逃离心理判定继续携带 NPC 人设 / 当前状态、短期记忆、长期记忆、地点、当前指令和战场事实，并新增自动化防回退断言。
- Prompt、Schema、Mock / 本地自动化与真实 provider 业务路径验证完成；模型失败仍保留真实失败信息且不得自动伪装成 Mock 成功。

完成结果（2026-07-22）：

- `ActionSystem` / `DailyPlanSystem` 已让日计划对话记录来源日、小时、版本和原计划项；逻辑推进、计划结束重试及整点派发前都会复验当前 `talk_to_npc + target`。失配时释放双方预约、停止接近并写 `talk_to_npc_failed_plan_superseded`，上下文保留原 / 当前项与时间；DailyPlanSystem 使用真正的旧失败项进入 T0050 判别。非日计划直接对话不受影响。
- `PlanRevisionJudgementRequest` 已继承 `StationAwareNPCRequest` 并必填统一 `NPCContext`、候选、建筑 / 资源状态；共享 NPC 上下文新增 `long_term_memory={knowledge_graph, diary}`。日计划、范围判别、正式修订和低血量战时心理统一携带人设、状态、指令、长短期记忆与地点，失败事实在两阶段原样传递；Prompt 和 Schema 支持 `plan_item_superseded`。
- GM 新增调用既有权威过期扫描接口的 `expire_plan_dialogues` 命令；它不构造等待或伪造失败，只处理当前已经失效的等待。Python Schema / Mock / Prompt / endpoint、Godot 跨小时 / 两阶段 / 动态场景 / 日计划 / 对话 / 战时回归与 headless 解析通过。真实 DeepSeek `deepseek-v4-flash` 的对话判别、行动失败判别、两类正式修订、战时对话和低血量心理均一次成功、`fallback_used=false`。
- Godot MCP server / addon 4.0.1 版本一致；运行态探针确认 plan_day、plan_revision_judgement 和 battle_judgement 均含 station、identity、state、order、short / long memory 与 location，新增代码后编辑器无新增错误。

---

## T0055 补充持续活动与周期产出常识

状态：Done
优先级：P0
前置任务：T0054
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `MEMORY_AND_INFO_SPACE.md`, `ECONOMY_AND_BUILDINGS.md`, `PROMPTS.md`, `API_BUDGET.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

在所有 NPC 中心 LLM 请求共用的 `station_rules` 中补充通用的持续活动 / 周期结算常识，让 NPC 明白工作、照料、训练、治疗、制造等需要成员持续参与的活动，只在有效持续期间推进并在程序确认周期完成后结算相应产出或结果；离岗、改做他事或被中断后，不能假定活动会在无人参与时自行继续产出。

验收标准：

- 新规则使用世界内驿站口吻，不引用“游戏机制”“tick”“ActionSystem”等出戏技术词。
- 规则同时覆盖产出、制造进度、恢复与成长等周期结果，不把菜园写成唯一特例，也不擅自规定所有活动的未完成进度都归零；是否保留进度继续由程序权威决定。
- 六类正式 Prompt 都能读取该规则，并明确背景规则不能让模型声称未完成或无人持续参与的活动已经产生结果。
- 既有 GM `station_context` 入口可观察新增规则；更新自动化为 5 条规则并完成 Schema / Mock / Godot payload 验证。环境已有真实 Key 时，用真实 provider 验证 NPC 不再认为离开菜园后仍会自动产出，且 `fallback_used=false`。

验收结果（2026-07-22）：

- `data/station_context.json` 新增第五条世界内规则，通用覆盖工作、照料、训练、治疗和制造：只有持续有效参与并完成相应周期后才由驿站实际记录结算；离岗、改做他事或被打断后不会无人自动产出，未完成进度是否保留仍交给具体程序。
- 六份正式 Prompt 均增加未完成周期 / 离岗产出边界；Schema 与 Godot 动态上下文专项要求规则数为 5，并逐类验证规则随六类 payload 注入。
- Schema、Mock / endpoint、Prompt、Godot payload、GM 和项目 headless 验证通过。真实 DeepSeek `deepseek-v4-flash` 回答“活计得有人一直干，周期到了才算数；一离岗进度就停，没人接着干就没产出”，`fallback_used=false`。
- Godot MCP 4.0.1 server/addon 版本一致；冻结运行 `Main.tscn` 从真实 LLMBridge 快照读取 8 人 / 15 建筑 / 22 种工作行为 / 5 条规则并命中新周期规则，编辑器无新增错误。

---

## T0056 强化马厩成长、额外 HP 与繁育反馈

状态：Done
优先级：P1
前置任务：T0037, T0806
涉及文档：`game_design.md`, `DATA_SCHEMA.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

让照料马厩的长期收益在马匹个体状态和马厩面板中直接可见，并让初始马保留可培养空间。

验收标准：

- 每匹马的玩家可见状态将基础 HP 与照料额外 HP 拆分显示；额外 HP 继续由 HorseSystem 权威结算。
- 每匹成年在厩马保存并显示独立繁育概率；存在至少两匹成年在厩马且有效养马人在岗时，概率从 0 随有效照料分钟、养马能力和马厩等级逐渐增长。
- 每个完整照料分钟按当前累积概率执行现有低概率繁育判定；成功出生一匹幼马后，参与繁育的成年马概率归零并进入配置化冷却，冷却期间概率不增长。
- 初始“栗风 / 灰鬃”成长值设为刚达到成年阈值，仍可通过有效照料继续成长到 100%。
- 新增或更新自动化，覆盖初始成长、额外 HP 拆分、概率增长、出生重置、冷却冻结和马厩 UI 文案；通过项目 headless 与 Godot MCP 运行验收。

验收结果（2026-07-23）：

- `data/horse_defs.json` 将两匹初始马调整为 60% 刚成年，并配置逐分钟概率增量、概率上限和 1440 游戏分钟繁育冷却；HorseSystem 继续权威结算成长、总 HP、照料额外 HP、繁育概率和出生。
- 公开马匹快照拆分 `base_hp` 与 `extra_hp / extra_hp_cap`；马厩面板逐匹显示基础 HP、照料额外 HP、饱食、成长和两位小数繁育概率，冷却时显示剩余天数 / 小时。
- 有效 `work_stable` 照料按完整游戏分钟为每匹符合条件的成年在厩马累积概率；出生成功后本轮成年候选概率归零并冷却，冷却期间概率保持 0，但成长与额外 HP 不被阻断。
- 新增 `verify_horse_care_feedback.gd`。马匹反馈、马厩照料、马匹生态 / 分配、建筑面板、NPC 面板、GM、HUD、装备、兵种、战斗集结共 10 项相关回归及主场景 headless 启动全部通过。
- Godot MCP 冻结运行确认照料中的托马会同时推进成长、额外 HP 与繁育概率；必成繁育后马匹数 2→3、亲本概率清零、冷却为 86400 游戏秒，UI 显示“繁育概率 0.00%（冷却 1天0小时）”，编辑器无新增错误。

---

## T0057 建筑升级中断依赖行动并触发失败重估

状态：Done
优先级：P0
前置任务：T0043, T0050
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `MODULE_INDEX.md`, `GM_PANEL.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

当 NPC 正在前往某座建筑执行活动，或已经在该建筑内执行依赖活动时，如果建筑开始升级并导致活动无法继续，必须以“建筑升级”为程序权威原因结束该行动，并进入 T0050 统一的“行动失败范围判别 → 按需精确阶段修订”链路，不能只中断后停在原地。

验收标准：

- 升级启动会同时覆盖前往目标建筑的 pending 行动和建筑内 active 行动；两者都停止移动 / 释放位置，并把 NPC 逻辑地点收束到广场。
- 最终 `last_action_result` 是可被统一失败链识别的行动失败，`last_action_failure_context` 明确包含目标建筑、`condition=upgrading`、建筑升级中文原因和失败摘要。
- 中断移动或释放行动产生的同步状态信号不得抢先触发无上下文失败，也不得吞掉最终升级失败。
- `DailyPlanSystem` 接住该失败后先触发 `trigger_kind=action_failure` 的范围判别；判别非空时再进入既有精确阶段修订。
- 新增本地 Godot 自动化覆盖“路上被升级打断”和“进行中被升级打断”两条链路，并通过相关建筑 / 计划回归、项目 headless 与 Godot MCP 运行验收。

验收结果（2026-07-23）：

- `ActionSystem._on_building_state_changed(...)` 只把真正指向封闭建筑的 pending / active 依赖行动收束为 `<action_id>_failed_building_upgrading`；中断移动 / 周期并释放位置后，最终上下文一次性写入 action / building、`condition=upgrading`、pending / active 阶段、移动前地点、`failure_reason=building_upgrading` 与中文摘要。单纯停留 / 普通移动只清退或停止，广场上的协助升级不受误伤。
- `DailyPlanSystem` 将 `building_upgrading / building_unavailable` 规范为现有 `target_unavailable`，复用 T0050 `trigger_kind=action_failure` 判别；没有新增 Schema、Prompt、call type 或第二套升级重估。
- 新增 `verify_building_upgrade_action_failure.gd`，覆盖食堂路上 pending 失败、菜园内 active 失败、移动 / 位置清理、中文失败上下文、第一层空判别和非空后的第二层精确修订。
- 建筑位置、修复升级、服务依赖、日计划重估、T0050 两阶段、基础行动、GM、项目 headless、Godot MCP 连接和 `git diff --check` 均通过。真实 DeepSeek `deepseek-v4-flash` 的行动失败判别与精确修订均一次成功、`fallback_used=false`；Godot MCP 运行态确认 active 菜园活动升级后退出到广场并写入正确失败，编辑器无新增错误。
- 不新增 GM 入口：既有“指定行动 → 建筑升级 → 最近行动结果 / `plan_request`”已能构造并观察权威失败与重估链。

---

## T0054 扩充 NPC LLM 驿站常识上下文

状态：Done
优先级：P0
前置任务：T0041, T0046, T0053, T1103A, T1203
涉及文档：`game_design.md`, `AI_NPC_SYSTEM.md`, `PROMPTS.md`, `API_BUDGET.md`, `DATA_SCHEMA.md`, `TECH_ARCHITECTURE.md`, `GODOT_ARCHITECTURE.md`, `GM_PANEL.md`, `MODULE_INDEX.md`, `CURRENT_STATE.md`, `DEV_LOG.md`

任务目标：

扩充所有 NPC 中心 LLM 请求共用的 `station_context`：除当前在站 NPC 名单外，加入驿站完整建筑名单、工作模式下的完整行为类型目录，以及不出戏的精简驿站规则，让对话、每日计划、计划修改判别、正式修订、战时心理判定和首次睡眠反思都理解一致的基本环境与行为边界。

验收标准：

- `station_context` 明确声明驿站建筑仅限 `data/building_defs.json` / BuildingSystem 当前配置中的完整名单；公告牌和广场不得误列为建筑。
- `station_context` 的工作模式行为目录从 `data/action_defs.json` / ActionSystem 的可计划行动定义自动生成，不在 Prompt 或 GDScript 中维护第二份静态行为名单；动态目标、资格和即时可用性仍以每次请求的 `allowed_actions` 与程序校验为准。
- 精简驿站规则使用世界内叙事口吻说明：成员平时在驿站工作和生活；遇敌时已入伍且装备主武器者保卫驿站，未入伍或无主武器者尽量在站内避敌；士气低落时任何成员都可能离开甚至临阵脱逃，使留下者更危险。
- 六类正式 NPC LLM 请求都只在顶层携带一份扩充后的 `station_context`，不在嵌套人物上下文重复，也不让背景规则覆盖资源、HP、建筑、行动、行为模式和战斗等程序权威事实。
- 更新六份业务 Prompt 对新增字段的解释；Schema、Mock / fake-provider、Godot payload 和相关回归通过。若环境已有真实 API Key，再完成受影响业务路径的真实 provider 验收并确认 `fallback_used=false`。

验收结果（2026-07-22）：

- 新增 `data/station_context.json` 保存精简场景简介与四条世界内驿站规则；LLMBridge 从 NPCSystem、BuildingSystem、ActionSystem 动态组装当前人员、全部建筑和工作模式行为类型，不在 GDScript 或 Prompt 维护第二份名单。
- `StationSceneContext` 已收紧为五个必填字段；六类正式业务 payload 和六份 Prompt 均只携带一份顶层上下文。完整行为目录不替代本次 `allowed_actions / allowed_decisions`，背景规则不替代 HP、资源、建筑、行为模式与战斗等程序事实。
- GM 面板新增只读“驿站上下文”按钮与 `station_context` 命令，可直接查看当前人员、建筑、工作行为和规则，不产生结算或状态修改。
- Schema、Mock / endpoint、Prompt、Godot 动态上下文、GM 与项目 headless 验证通过。真实 DeepSeek `deepseek-v4-flash` 完成对话、每日计划、计划修改判别、正式修订、战时心理和首次睡眠反思路径，全部 `fallback_used=false`。
- Godot MCP 4.0.1 server/addon 版本一致；冻结运行 `Main.tscn` 后从真实 LLMBridge 快照读取 8 名在站成员、15 座建筑、22 种工作模式行为和 4 条规则，广场 / 运行态守备官对话入口均未误入目录，编辑器无新增错误。

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
- `Main.tscn` 中的 `NoticeBoard` 模型当时保留为主厅前视觉占位和后续公告输入/显示接口，不再由 `BuildingSystem` 绑定点击区、HP 标签或建筑面板；T1506 已用独立脚本接入该接口。
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

> 历史说明：本任务当时排除位置数量传播的口径已由 T0043 覆盖；当前室内位置增删 / 改名 / 改类型 / 占用按 ID 传播。

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

> 历史说明：本任务当时的建筑状态降噪记录由 T0043 细化；精确 HP / 效率仍降噪，但位置容量变化和外部效率分档会传播。

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

> 历史说明：本任务当时禁止传播位置数量的口径已由 T0043 覆盖；当前继续只发差量，但位置新增 / 移除属于合法差量。

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

- 已在 `backend/app.py` 新增正式 `POST /npc/dialogue` Mock 业务接口，请求体先校验为 `NPCDialogueRequest`；T0087 后 Mock 输出按对话类型校验为三个封闭响应 Schema。非法 JSON / schema 错误返回 400，模型输出不合法返回 502，非 mock provider 无 Key 返回 503。
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
- 对话 UI 维护 NPC-NPC 对话当前轮次与最大轮次（T0029 后正式上限为 3 轮，邀请决定不计轮次）；逃离挽留保留独立 5 轮语义（玩家与普通 NPC 对话不限轮次）

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
- `DialogSystem` 负责玩家-NPC 会话状态、历史、后端请求和事件入库；玩家-NPC 对话不限轮次，T0029 后 NPC-NPC 先经邀请判定，接受后正式对话最多 3 轮。
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
- T0703 发出的计划重评估请求必须携带最新指令，并通过统一重评估链路立即处理。（该任务当时采用规则降级；T0023 后正式链路失败保留原计划、不再降级，并释放 TimeSystem 慢速请求。）
- 常规请求只携带一条当前有效指令及最小元数据；历史修订通过 `order_assigned` 事件摘要进入记忆，避免重复注入全部版本。

验收标准：

- 发布不同指令后立即产生一次计划重评估请求（计划功能本身尚未实现，在后续的task里）；相同文本或关闭面板不产生请求。
- `/npc/dialogue`、计划、修订、战时公开对话和低血量自身心理判定的测试 payload 都包含目标 NPC 最新 `current_order`。
- Mock / 真实 Prompt 能把指令当作参考，但输出仍受 Schema、行动白名单和程序规则校验。
- 指令本身不会直接改变行动、资源、HP、移动或战斗结果。
- GM / 自动化验证可观察最近一次注入的指令和计划重评估结果。

验收结果（2026-06-04）：

- 后端新增共享 `CurrentOrderContext`，`NPCContext` 与 `NPCDialogueRequest` 统一携带单条最新 `current_order`；因此每日计划、计划修订、战时公开对话、低血量自身心理判定、主动交涉、首次睡眠总结、知识图谱更新和玩家话术分类等复用 `NPCContext` 的请求自动共享该字段。
- Godot `LLMBridge` 当时在对话顶层 payload 和 `target_npc` / `speaker_npc` 共享上下文中注入最新指令，并保存最近一次注入快照供 GM / 自动化观察；T0071 已废止对话中的 `speaker_npc` 注入，说话者指令不再进入回复目标上下文。Mock 调试原因明确记录指令仅作为参考，不改变 Schema 允许结果。
- 新指令仍立即产生一次统一计划重评估请求；当时 T1002 尚未实现，结果为 `rule_fallback_deferred`。T1002 完成后曾应用 Mock / 规则修订；该历史口径已由 T0023 覆盖，当前只接受真实 `llm_plan_revision`。
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
- 对话结束后的计划处理遵循 T0049：完成有效回复后先由 NPC 判别精确 `revision_hours`，非空才修订；面板不再提供人为开关。1 小时无人响应超时没有实际对话内容，作为非对话状态变化直接修订当前小时。

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
- 主动交涉被点击或超时后气泡消失；对话结束或 1 小时超时都会请求计划重评估。当时仍按 T0703A 的 `rule_fallback_deferred` 可观察降级结果处理；T1002 曾应用 Mock / 规则修订，该历史口径已由 T0023 的真实专用重估覆盖。
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
- 由于 T0901 正式装备系统尚未实现，弓/弩暂时进入通用 `weapons` 库存；由于当时 T1508 尚未实现，弩床、箭塔等防御器械暂时进入 `defense_devices` 库存，不进行部署或自动攻击结算。
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
- GM 面板新增属性分配按钮和 `assign_attribute <npc_id> <strength|intelligence>` 命令；属性分配写入 `attribute_improved` 事件。T0045 后 summary 改为 NPC 通过锻炼体力 / 脑力获得对应属性提升。
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
- 计划执行通过 `hour_started` 打点；T1001 当时允许同一小时提前完成后重复执行，T0025 已由 `(day, hour, plan_version, action_id, target_id, dialogue_goal)` 单次派发签名覆盖：同一版本同一时段只派发一次，计划版本变化后才可重新落地当前项。小时变化且当前行动不同，会通过 `ActionSystem.interrupt_npc_action(...)` 中断后执行新计划项。
- T1001 不调用 LLM，不处理异常重评估；未显式生成计划的 NPC 不会被小时信号自动接管，避免调试行动和旧验证被计划系统误接管。
- GM 面板新增生成计划、执行当前计划和查看计划按钮，并新增 `plan_generate [npc_id|all]`、`plan_execute [npc_id|all]`、`plan <npc_id>` 命令。
- 新增 `tools/verify_daily_plan_system.gd` 覆盖 24 小时计划、至少 6 个工作阶段、`plan_created` 入库、小时打点执行和计划变化打断旧行动；T0025 另由 `verify_plan_slot_dispatch_once.gd` 覆盖同一时段只派发一次。
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
- 需要模型重评估时，通过 LLMBridge 申请 TimeSystem 慢速请求（游戏内一秒=现实中一秒），返回后释放。（T0023 后正式路径只允许真实 LLM。）

验收结果（2026-06-11）：

- `DailyPlanSystem` 监听 `npc_plan_reevaluation_requested`，并在行动失败、目标建筑不可用、资源不足、工位占用、对话打断、守备官攻击、主动交涉结束 / 超时、战斗警报占位和守备官新指令后进入统一计划重评估。
- `LLMBridge` 新增 `request_npc_plan_revision(...)` / `build_npc_plan_revision_payload(...)`，调用后端 `/npc/revise_plan`，请求包含目标 NPC 的共享上下文、当前计划、失败计划项、失败类型、行动白名单和最新 `current_order`；请求期间申请 TimeSystem 慢速，请求成功、失败或超时后释放。
- 后端新增 `/npc/revise_plan`，使用 `PlanRevisionRequest` / `PlanRevisionResponse` 校验 Mock 输出；Mock provider 的 `revise_plan` 可返回当前小时 `immediate_action`。
- （T1002 历史实现，已由 T0023 覆盖）当时后端失败会写入 `rule_revision_fallback`；当前正式重估只接受 `llm_plan_revision`，最终失败保留原计划且不写 `plan_revised`。
- GM 面板新增“立即重评估”按钮和 `plan_revise <npc_id> [reason]` 命令；“重评估请求”同时显示 NPCSystem 请求快照与 DailyPlanSystem 最近结果。
- 新增 `tools/verify_daily_plan_reevaluation.gd`；T1002 当时覆盖后端不可用规则降级和可选 live mock，T0023/T0025 后当前脚本覆盖资源 / 工位失败触发、正式 Mock 隔离、真实修订、最终失败保留原计划、慢速释放和计划修订事件；`tools/verify_plan_revision_endpoint.py` 继续覆盖 Flask 端点合同。
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
- （T1003 历史实现，已由 T0022 覆盖）`DailyPlanSystem.generate_daily_plan_for_npc(...)` 当时会写入 `mock_plan_day` 或 `rule_plan_fallback`；当前正式每日计划只接受 `llm_plan_day`，失败不降级。
- （T1003 历史实现，已由 T0022 覆盖）GM `plan_generate` 当时会触发 Mock / 规则降级；当前 `plan_generate` 只请求真实 provider 且失败不降级，`plan_generate_rule` 仍保留为独立纯规则调试入口。
- `tools/verify_plan_day_endpoint.py` 和 `tools/verify_daily_plan_llm.gd` 已由 T0022 更新：覆盖 provider 元数据、真实失败不降级、慢速释放、显式开发 Mock 计划和 `current_order` 注入。
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
- 后端新增正式 `POST /npc/daily_reflection` endpoint；历史 Mock 曾返回日记、记忆摘要和知识图谱更新，T0046 已移除该独立摘要，当前 Mock / 真实 Prompt 均只返回第一人称日记和替换式知识图谱当前键值。
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
- 玩家对话响应 / Mock 包含 `wartime_reaction`；T0087 后对应类型为 `PlayerNPCDialogueResponse`。后端不可用时战时对话走规则 fallback。
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
- `CombatSystem` 解析当前 `escape_intervention_result=stay|leave`：留下会停止移动、切回 `work` 并触发计划重评估；继续逃离会保留 `escape_intent.status == "escaping"` 并记录已用轮次。
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
- Model Adapter 的通用 schema guard 加硬了枚举约束；T0087 后对话再按类型限制 `response_kind`、业务结果和可出现字段，避免真实 provider 自造枚举或跨分支输出。正式角色语气和 Prompt 质量仍由 T1402-T1405 维护。
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
- 已按 `game_design.md` 收敛结构化选项：日常 / 征召使用 `recruitment_result=none|accept|reject`；集结 / 战斗对已入伍持主武器 NPC 使用 `wartime_reaction=none|escape|morale_boost`；避战对话不触发 `wartime_reaction`，继续用征召结果表达是否应征；T0087 后逃离挽留使用 `escape_intervention_result=stay|leave`。
- 新增 `tools/verify_dialogue_prompt.py`，用 fake real-provider 请求检查系统 Prompt 包含职业、记忆、`current_order`、征召、战时、避战和逃离挽留约束；T0087 后按三种响应 Schema 验证返回 JSON。
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
- 输出不合法或模型失败时记录真实失败原因。T0022 后正式开局 / 新一天保持暂停并只重试真实请求，不回退规则计划，也不得用 mock 计划伪装真实模型成功。

完成记录（2026-07-07）：

- 新增 `data/prompts/daily_plan_system_prompt.txt`，作为 `/npc/plan_day` 真实 provider 的独立系统 Prompt 模板；`ModelAdapter` 会在 `call_type=plan_day` 时读取该模板，并继续叠加通用 JSON / Schema guard。
- 每日计划 Prompt 明确输出 0-23 点共 24 阶段、至少 6 个工作阶段、只使用 `allowed_actions` 或 `idle`，并要求 `current_order` 只作为守备官当前指令参考，不能越过行动白名单、资源、HP、地点、建筑、工位或程序强制层。
- `/npc/plan_day` 在 `DailyPlanResponse` Schema 校验后校验 hour 0-23 覆盖、`allowed_actions` / `idle` 白名单和至少 6 个工作阶段；不合法时返回 `model_output_invalid` 并记录失败 usage。T1403 当时的 Godot `rule_plan_fallback` 已由 T0022 删除，当前正式每日计划保持暂停并只重试真实请求。
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

状态：Done
优先级：P1
前置任务：T1402
涉及文档：`AI_NPC_SYSTEM.md`, `game_design.md`

验收标准：

- 8 名 NPC 有明确姓名。
- 每人有职业语气、欲望、恐惧、底线。
- 对话中能体现职业身份。
- 不写过长背景，保持 Demo 可控。

完成记录（2026-07-16）：

- 保留并正式确认 8 名 NPC 姓名：托马 / 马夫、布鲁诺 / 厨子、伊沃 / 园丁、格伦 / 铁匠、艾达 / 老兵副官、马塞尔 / 神父、莉娜 / 医生、欧文 / 工程师。
- `data/npc_profiles.json` 为每人补齐简短 `speech_style` 和 3 条 `signature_lines`；既有性格、欲望、恐惧、底线按 `game_design.md` 第 9 章收敛，背景继续保持 Demo 级短文本，并清理世界内人设中的“玩家”称呼。
- `LLMBridge` 将职业语气和台词样例同时注入 `/npc/dialogue` 的 `npc_setting` 与共享 `NPCContext.identity`；后端 `NPCIdentity` 新增对应字段，计划、判定和首次睡眠总结可复用同一人设来源。
- 对话 Prompt 明确要求从目标 NPC 的职业经验出发回应、吸收措辞习惯但不逐字复读样例，避免 8 人生成可互换的通用士兵台词；首次睡眠总结同步参考职业语气。
- 未新增 GM 入口：8 个姓名可直接在 `Main.tscn` 的 NPC 标签 / 面板查看，职业语气可通过既有正常对话入口手动验证；现有 GM 对话和 LLM usage 入口仍可辅助观察请求与真实 provider 记录。
- 新增 `tools/verify_npc_character_profiles.gd`，覆盖 8 人姓名 / 职业、人设字段、短背景、职业关键词、世界内“守备官”称呼和 Godot LLM payload 注入；新增 `tools/verify_npc_character_dialogue_real.py`，读取正式档案并逐人调用真实 `/npc/dialogue`。
- 真实 provider 验收：DeepSeek `deepseek-v4-flash` 对 8 名 NPC 各完成一次“说明日常职责并给守备官建议”的对话，回复分别体现马厩、食堂、菜园、铁匠铺、防线、小教堂、小诊所和工械坊身份；`/debug/llm_usage` 显示 calls=8、failed=0、`fallback_used=false`。
- T1501 历史验收（已由 T0061 取代）：Godot MCP 4.0.1 当时运行 `Main.tscn` 后读取到每人 3 条 `signature_lines`；当前正式档案、`npc_setting` 与共享身份均已删除该字段。
- 验证通过：`python -m py_compile backend/schemas/common.py tools/verify_backend_schemas.py tools/verify_dialogue_prompt.py tools/verify_npc_character_dialogue_real.py`、`python tools/verify_backend_schemas.py`、`python tools/verify_dialogue_prompt.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_plan_day_prompt.py`、`python tools/verify_battle_judgement_prompt.py`、`python tools/verify_daily_reflection_prompt.py`、`python tools/verify_npc_character_dialogue_real.py`、`godot --headless --path . --script res://tools/verify_npc_character_profiles.gd`、`godot --headless --path . --script res://tools/verify_npc_skill_schema.gd`、`godot --headless --path . --script res://tools/verify_npc_generation_click.gd`、`godot --headless --path . --quit-after 1`。

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

## T1506 增加公告输入

状态：Done
优先级：P2
前置任务：T0404, T0701
涉及文档：`MEMORY_AND_INFO_SPACE.md`, `UI_UX.md`

验收标准：

- 玩家可通过主厅前公告牌界面写公告。
- 公告更新为广场当前状态，并即时广播给当前在广场的 NPC；公告牌不作为建筑保存状态。

完成记录（2026-07-16）：

- `NoticeBoard.gd` 为主厅前现有模型补充点击区、相机射线拾取和当前公告预览；`NoticeBoardPanel.gd` 提供自由文本发布与清空入口。
- 发布统一调用 `MemorySystem.set_plaza_notice(...)`：文本只保存在广场 `current_notice`，生成 `plaza_notice_changed` 广场公开事件并即时写入当时在场且可接收见闻的 NPC；相同文本不会重复广播。
- 公告牌仍未进入 `building_defs.json`，不具备 HP、等级、工位、修复或升级。
- 功能可在 `Main.tscn` 直接点击验证，因此未新增 GM 入口；`verify_notice_board_input.gd` 覆盖界面输入、广场状态、当前在场/室内 NPC 广播边界和非建筑边界。

---

## T1507 商人交易系统

状态：Done
优先级：P2
前置任务：T0202, T0401, T0807
涉及文档：`ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`

验收标准：

- 每天特定时段商人到后门。
- 玩家可买粮食、木材、石料、铁。
- 玩家可卖酒。
- 交易事件写入结构化事件。
- 需要接住 T0807 的 `wine` 派生库存：出售酒时扣除 `wine`，增加 `money`，价格由交易系统配置决定，不能在酒窖工作完成时自动换钱。

完成记录（2026-07-16）：

- 新增 `data/merchant_defs.json`：后门商队每日 `10:00-16:00` 到访；粮食/木材/石料/铁买价分别为 2/3/4/5 第纳尔，酒卖价为 7 第纳尔，时段与价格均由配置读取。
- `MerchantSystem.gd` 监听逻辑时间，控制后门商人标记与交易可用性；`MerchantPanel.gd` 显示库存、数量和配置中的买卖报价，UI 只调用系统接口，不自行结算。
- 买入由 ResourceSystem 扣钱并增加对应资源；卖酒扣除 `wine` 并增加 `money`。余额/库存不足或商人离场时不改变状态，也不写成功事件；酒窖完成酿酒仍不会自动换钱。
- 到达、离开和成功交易分别写入 `merchant_arrived`、`merchant_departed`、`merchant_trade_completed` 结构化广场公开事件，交易 payload 包含方向、资源、数量、单价、总价和资源/金钱差量。
- 功能可在 `Main.tscn` 直接验证，现有 GM 改时间/加资源入口已足够辅助验收，因此未新增 GM 入口；`verify_merchant_trade_system.gd` 覆盖时段、买入、卖酒、失败交易、离场和事件结构。

---

## T1508 工程器械部署

状态：Done
优先级：P2
前置任务：T0805, T1104
涉及文档：`COMBAT_SYSTEM.md`, `ECONOMY_AND_BUILDINGS.md`

验收标准：

- 消耗 T0805 产出的 `defense_devices` 工程器械库存。
- 弩床或箭塔可部署在围墙。
- 两类器械均可自动攻击敌人。
- 工程技能影响制造效率。
- 部署事件进入结构化事件并按广场公开规则广播，不绑定部署 NPC。

完成记录（2026-07-16）：

- 新增 `data/defense_device_defs.json` 与 `DefenseDeviceSystem`：弩床 / 箭塔类型、围墙部署槽、库存消耗、部署合法性和运行态均由配置与系统权威维护；重复占槽或条件不满足时不扣库存。
- 弩床与箭塔均按战斗动作秒自动选择射界内敌人，并通过 `CombatSystem.apply_defense_device_attack(...)` 复用敌人防御、HP、击退与战斗结束结算；箭塔使用较低单次伤害和更短攻击间隔，与弩床共用同一自动攻击结构。
- 2026-07-16 需求修订后，部署不再选择或校验 NPC，`deploy_device(device_id, slot_id)` 由玩家直接触发。成功后生成以守备官为主体的 `defense_device_deployed` 广场公开结构化事件；器械实际攻击另写 `defense_device_triggered`，两类事件都不进入任何 NPC 的亲历事件库。
- 工程技能对制造效率继续复用 T0805 `work_workshop` 的“工程 + 智力 + 工械坊等级”耗时缩放，本任务未复制第二套生产规则。
- 围墙 BuildingPanel 新增可直接验证的器械部署区，只选择器械与槽位；低模表现由独立 `DefenseDevicePresenter` / `DefenseDeviceView` 承担，稳定保留 `ModelMount` 与配置 `presentation.model_scene` 契约，T15 正式模型、动画和特效可替换表现而不改权威结算。
- 未新增 GM 专用入口：功能可从 `Main.tscn` 围墙面板直接部署，既有 GM 加工程器械、刷敌人与推进战斗入口已足够辅助验收。
- 验证通过：`godot --headless --path . --script res://tools/verify_defense_device_deployment.gd`、`verify_workshop_ranged_devices.gd`、`verify_combat_damage.gd`、`verify_enemy_target_priority.gd`、`verify_structured_memory_events.gd`、`verify_combat_flow.gd`、`verify_combat_pacing.gd`、`verify_building_panel_workstations.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_hud_resources.gd`、`verify_gm_panel.gd`、`verify_merchant_trade_system.gd`、`verify_notice_board_input.gd` 与项目 headless 加载；Godot MCP 4.0.1 运行态确认系统节点、围墙部署 UI、部署实例、库存扣除和事件结构，编辑器错误日志为空。

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

## T1510 公告牌独立道具低模改造

状态：Todo
优先级：P2
前置任务：T0206, T1506
涉及文档：`GODOT_ARCHITECTURE.md`, `ECONOMY_AND_BUILDINGS.md`, `UI_UX.md`, `CURRENT_STATE.md`

任务目标：

参考用户提供的木制立式告示牌样式，把公告牌改为立在主厅侧边地面上的独立场景道具，同时保持既有公告输入与广场广播逻辑。

验收标准：

- `NoticeBoard` 位于 `WorldRoot/Station/Props`，不再挂在 `Buildings` 下，也不依附主厅模型。
- 低模外观至少包含木制立柱 / 横梁、浅色告示板和地面底座细节，可在俯视视角下辨认。
- 点击仍打开既有公告输入界面，世界预览仍随广场当前公告刷新。
- 公告牌不进入 `building_defs.json`，没有 HP、等级、工位、修复或升级状态，也不打开 BuildingPanel。
- 主场景和公告专项回归无报错，并完成可视化运行检查。

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
