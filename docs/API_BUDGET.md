# API_BUDGET.md

## T0061 人物上下文收敛成本

本任务不新增 endpoint、`call_type`、正常游戏调用次数、重试、触发条件或输出字段。`signature_lines` 从 8 人档案、`NPCPromptProfile`、共享 `NPCIdentity`、对话 `npc_setting` 和六类正式 Prompt 移除，使每次人物上下文略微缩短；`speech_style`、3 篇初始日记和完整知识图谱仍按原有路径注入，不为节省 token 删除人格连续性或建筑常识。

前两篇日记重写和建筑 `relation_label / value_label` 叙事化属于既有长期记忆内容替换；守备官认识从原有多条开放评估收束为每人一条职责事实，使全体种子关系总数从 227 条降至 222 条，不增加调用频率。`confidence / day / time` 仅在玩家【知识】弹窗隐藏，原始数据、运行态、后端参数、反思更新和 GM 调试仍传输完整字段，因此没有 Schema 迁移或额外调用。文案与 UI 显示本身不会触发模型请求。

T0061 的真实 provider 专项在关闭自动 Mock fallback 的条件下，使用 DeepSeek `deepseek-v4-flash` 完成 3 次业务调用、0 失败：分别核验托马的宏观身世与到站时间线、莉娜的到站群像与昏迷救助常识、欧文的守备官职责与城墙器械位规则，三次均为 `fallback_used=false`。当前六类 Godot 专项最大序列化 payload 字符数为：dialogue 48330、plan_day 47118、plan_revision_judgement 50053、revise_plan 49952、battle_judgement 32057、daily_reflection 29242。字符数不是 provider token 数；这些开发验收调用不改变成品正常频率。

## T0060 文案与时间标签成本

本任务不新增 endpoint、`call_type`、正常游戏调用次数、重试或输出字段。日记运行态仍是 8 字段结构，只在 `LLMBridge._build_existing_diary_entries(...)` 投影为既有 `list[str]`；与只传正文相比，每条日记的时间标签约增加 6–18 个字符。当前 Godot 专项最大序列化 payload 字符数为：dialogue 48436、plan_day 47382、plan_revision_judgement 50305、revise_plan 50216、battle_judgement 32382、daily_reflection 29508。字符数不是 provider token 数，实际 token 与费用仍以 usage 为准。

最终真实 provider 专项使用 3 次验收调用，验证独特人生记忆和“近日”敌情传达前边界。调试验收谓词和时间标签投影前，另有 4 次返回成功的校准调用；一次 LLMBridge 集成测试最初误用本地真实配置并记录 `ProviderIdleTimeout`，随后改用显式 Mock 后端通过。故本轮开发共产生 8 次真实 provider 尝试，最终专项为 3 次调用、0 失败；所有路径均关闭自动 Mock fallback。这些开发调用不改变成品正常频率。

## T0059 初始长期记忆输入成本

本任务不新增 endpoint、`call_type`、正常游戏调用次数、重试或输出字段，但会显著增加六类既有请求的固定输入：每名 NPC 当前有 3 篇初始日记和约 25 个知识主体（15 建筑、7 名其他 NPC、守备官、至少 2 个个人故事主体）。这些内容用于开局即具备人物连续性，不能以空记忆替代。

为避免同一长图谱在单次请求内重复付费，LLMBridge 已移除正式 payload 中旧 `NPCContext.knowledge_graph` 镜像；计划、判别、修订、战时心理与反思只使用 `npc.long_term_memory`。对话只在顶层 `long_memory` 放目标记忆，`target_npc` 不再复制；`speaker_npc` 不携带另一人的私人长期记忆。当前本地最大序列化 payload 字符数：dialogue 48171、plan_day 46943、plan_revision_judgement 49878、revise_plan 49777、battle_judgement 31877、daily_reflection 28978。字符数不是 provider token 数，真实 token / 费用仍以 usage 为准；Godot MCP 莉娜对话运行态样本为 47714 字符。

若长期记忆随多日反思继续增长，应优先做可验证的按主体检索、旧日记压缩或供应商静态前缀缓存；不得删除与当前人物 / 地点 / 对话对象相关的关键认知，也不得让模型自行猜测被裁掉的建筑规则。当前任务先保证语义完整和单次不重复，不新增第二套摘要或隐藏 Mock fallback。

真实 provider 专项最终在 `LLM_FALLBACK_TO_MOCK=false`、连接超时 30 秒、流空闲超时 180 秒的受控配置下通过：DeepSeek `deepseek-v4-flash` 完成莉娜 / 欧文两次独特记忆追问，usage 为 2 次调用、0 失败、`fallback_used=false`。这些是开发验收调用，不改变成品运行频率。

## T0058 五项资源快照与单条升级规则增量

本任务不新增 endpoint、`call_type`、正常游戏调用次数、重试或输出字段。六类既有请求的唯一顶层 `station_context` 增加 5 个短资源项和 1 条规则；计划 / 判别 / 修订原有 `current_resource_states` 从全量库存收窄为同一五项，因此不会继续为隐藏库存支付输入 token。资源每次请求实时读取，但不会单独触发 LLM 调用。

验收额外使用真实 DeepSeek 对话和日计划各一次：对话准确复述五项数量并理解协助升级，日计划实际选择 `assist_upgrade`；两次均 `fallback_used=false`。这些是开发验收调用，不改变成品运行频率。

## T0055 单条规则增量

本任务只在既有 `station_rules` 增加一条短规则，并补充六份系统 Prompt 的解释；不新增 call type、请求、重试或输出字段。固定输入 token 有小幅增加，人员、建筑、行为和规则仍只在顶层注入一次。开发验收针对“离开菜园后是否自动产出”增加一次真实对话语义检查，结果为 `deepseek-v4-flash / fallback_used=false`；这不改变游戏内正常调用频率。

## T0054 共享世界常识的输入成本

本任务不新增 `call_type`、endpoint、重试或游戏内调用频率。六类既有请求的唯一顶层 `station_context` 增加完整建筑目录、工作模式行为类型目录与精简规则；T0055 后当前为五条。人员仍随离站缩短，建筑 / 行为目录由正式配置生成，不在嵌套 NPC、speaker 或 target 中重复。增长只发生在输入 token，输出合同不变。

目录提供稳定世界边界，单次可用候选仍由 `allowed_actions / allowed_decisions` 传入，因而不能为了省 token 删除这些动态权威字段。若后续目录明显增长，优先压缩名称 / 描述或引入经验证的静态前缀缓存，不得改为让模型自行猜测建筑、行为或战斗资格。真实 DeepSeek 已覆盖对话、日计划、判别、修订、战时心理与反思，全部使用真实 provider 且 `fallback_used=false`；没有因本任务引入额外业务调用。

## T0053 上下文增量与跨小时失败调用边界

计划修改范围判别不再省略人物上下文：每次 `/npc/plan_revision_judgement` 增加动态 `station_context`、统一 `NPCContext`（含身份 / 状态 / 指令 / 短期记忆 / `long_term_memory` 日记与知识图谱 / 地点）、合法行动候选及实时建筑 / 资源状态。该增量换取对话、计划、失败判别、正式修订和战时心理的人格一致性；仍沿用既有请求级 usage、token 与费用记录，不增加新的 call_type。

等待目标计划本身仍不调用 LLM。只有日计划来源的等待跨入“不再与同一目标对话”的当前计划项时，程序才产生一次真实行动失败判别；返回空范围则停止，非空才增加一次正式修订调用。因此该路径的新增调用上限与普通 T0050 行动失败相同，为 1 次判别 + 按需 1 次修订，不轮询、不按等待帧计费。战时判定没有新增触发次数，只扩展既有 payload 的长期记忆内容。

## T0052 计划等待不增加调用

本任务不新增端点、`call_type`、Prompt 字段或成功路径调用次数。守备官在 NPC 计划中不能创建对话请求，因此不会为了同一 NPC 取消计划后再补发一份计划；NPC-NPC 动作等待期间也不调用 `/npc/dialogue`、不写行动失败、不启动 `/npc/plan_revision_judgement`。只有目标计划 terminal 且重新校验通过后，才按既有预算发起一次邀请请求。即时失败修订继续过滤计划 / LLM 活动目标，避免选择一个只能排队的目标并制造额外修订循环。

本轮改动不涉及 Prompt、Schema 或 provider 输出效果；互斥 / 等待时序由本地状态活动、fake provider 自动化和 Godot MCP 运行态验证。随后使用已配置后端完成真实 DeepSeek `deepseek-v4-flash` NPC-NPC 邀请接受、邀请拒绝和正式对话业务路径，`response_kind=reply_to_npc`、`fallback_used=false`；等待阶段本身仍为 0 次模型调用。

## T0051 会话收口与请求预算

“完成对话”和“取消对话”都会调用客户端取消接口终止仍在等待的 NPC 回复；“挂起对话”不会取消请求，也不会重复发起请求。玩家在等待时完成后，迟到回复按失效 request id 丢弃，不能为同一句话补发第二次模型调用。两小时挂起超时同样只收口现有请求：普通会话取消，含攻击会话完成。会话提交 / 丢弃、事件广播和暂存权威结果应用都在 Godot 内完成，不新增后端端点或额外 LLM 调用；完成后的计划修改判别仍沿用 T0049/T0050 预算。

## T0050 通用判别层成本边界

T0050 将第六个正式调用通用化为 `call_type=plan_revision_judgement`。每场有实际完成内容的守备官-NPC 对话为目标 NPC 增加 1 次判别；NPC-NPC 对话为两名参与者分别增加 1 次；每次日常行动失败也先增加 1 次判别。判别输出只含是否修订与小时集合，应保持短输出；`revision_hours=[]` 时必须停止，不产生 `/npc/revise_plan` 成本。非空时才再调 1 次 `revise_plan`，修订输出只覆盖精确选中小时。

因此单场守备官-NPC 有效对话和单次行动失败的计划后处理成本都是“1 次判别 + 0 或 1 次修订”，NPC-NPC 为“2 次独立判别 + 0 至 2 次独立修订”。指令变化、战斗 / 复苏和 GM 等其他非对话触发不增加判别调用。判别和后续修订使用不同 request id，分别记录 provider / model / token / 费用、失败原因和 TimeSystem 慢速释放状态。行动失败修订落地后若再次失败，新失败会重新产生一次判别，但仍受同小时连续 3 次落地失败上限保护。

## T0046 上下文成本与真实验收

本任务不增加 LLM `call_type` 或游戏内调用频率。T0046 首次为每个携带 NPC 人设的请求增加一份顶层 `station_context`；T0054 在同一位置扩充建筑、行为和规则，仍不在嵌套 NPC 上下文重复。反思响应移除 `memory_summary`，同时减少输出 token 与后续长期上下文体积。公告牌通告 / 参考日程为程序状态与见闻传播，不发起新 LLM 调用。

2026-07-21 真实 `deepseek / deepseek-v4-flash` 验收时自动 Mock fallback 关闭：反思 1 次、共享场景上下文 4 类业务通过；8 人计划采样 8/8 成功、0 fallback、0 重试，input 126323 / output 13974 tokens。

## T0043A 服务依赖失败的调用预算

本任务不增加新的 LLM `call_type`。医生 / 教官 / 主持者离岗和教堂互斥由 ActionSystem 同步结算；行动失败只复用既有 `revise_plan` 请求链路，因此成本影响仅是确实发生失败时的一次既有计划重评估。依赖者等待仍在前往工位的同批服务者不会提前制造修订调用。

2026-07-21 使用已有 DeepSeek 配置复验 `plan_day`、`revise_plan` 和 `dialogue`，provider=`deepseek`、model=`deepseek-v4-flash`，均未使用 fallback；本任务没有新增接口或常驻调用。

## T0043 位置与资格字段成本边界

建筑位置细化不新增任何 LLM 调用类型、频率或重试。`allowed_actions.context` 增加资格 / 可用性提示，当前地点上下文增加逐位置显示名、容量和占用状态，只带来少量输入 token；不得为每个编号位置复制行动候选，NPC 仍只看到每种行动一条候选。团队效率、受损效率和升级进度由 Godot 权威推进，不调用模型。

本轮若修改实际 Prompt 模板，仍须先跑 mock / schema 测试；环境已有真实 Key 时，再对计划候选资格理解做真实 provider smoke。没有真实 Key 时必须在 T0043 验收结果中明确“真实 API 未验收”，不能以 Mock 代替。

2026-07-21 验收：环境使用真实 `deepseek / deepseek-v4-flash`，自动 Mock fallback 关闭。`/npc/plan_day`、`/npc/revise_plan`、`/npc/dialogue` 均通过且 `fallback_used=false`；额外的非神职园丁计划请求携带可见但 `eligible=false` 的 `lead_mass`，真实结果未选择该行动。位置细化没有增加正式调用类型或游戏内触发频率。

## T0041 对话行动参考成本边界

每次 `/npc/dialogue` 现在都会携带目标 NPC 的动态 `allowed_actions`，但不会因此增加调用次数；增加的是单次对话输入 token。当前目录包含静态行动、可交谈 NPC、可访问地点和实时协助目标，具体条数会随世界状态变化，usage 仍按每个对话 request id 记录真实输入 token 与费用。为保证单一事实源，不在 Prompt 另写一份较短但可能过期的手工清单；如后续需要压缩，应从同一候选目录做无损投影，并保留“列表外当前做不到”的语义。

## T0025/T0030 NPC-NPC 对话调用边界

自主 NPC-NPC 对话先调用一次正式 `call_type=dialogue` 邀请判定；受邀者接受后，每个正式回复轮次再各调用一次，拒绝时只有邀请这 1 次。T0030 后正式对话没有调用次数硬上限：默认软阈值为 5，模型应在事情说完时结束，并从第 6 轮起在无紧急 / 必要事项时告别收尾；紧急 / 必要事项允许继续，因此单场成本必须以 usage 实际记录监控，不能再按固定 4 次封顶估算。行动失败修订调用正式 `call_type=revise_plan`。两类当前场景请求都携带 `requires_time_slowdown=true`，每次邀请 / 回复使用独立 request id，Godot 在请求成功、失败、取消或会话被权威模式打断后释放对应慢速请求。正式路径要求非 Mock provider、`model_fallback_used=false`，不会用 Mock 或规则内容伪装成功。计划修订最多 3 次真实尝试；这些是业务重试边界，不是客户端输出 token 上限。

## 目标

控制 LLM 调用成本，避免 8 个 NPC 高频调用导致 Demo 不可运行。

正式成本与并发边界：

- 玩家电脑上的 Godot 客户端只请求游戏服务器后端，不直接调用 LLM Provider。
- 服务器后端统一持有供应商 API Key，并负责限流、排队、批处理、降级、token/费用统计和异常熔断。
- 本地开发可以显式使用 mock provider 或本机后端验证接口；这不代表玩家最终必须自行启动后端或自行配置 API Key。
- 玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式；即使实现，也必须与默认服务器后端模式隔离，不能让 Godot 导出客户端默认保存真实 Key。
- Mock provider 只用于开发期 Schema / 通信 / 自动化验证。真实 API 测试通过后，生产 / 演示路径必须关闭自动 mock fallback；模型失败应返回可处理错误并记录真实原因，或进入明确标记的规则 / 模板降级。

## 调用优先级

| 优先级 | 任务 |
|---|---|
| 高 | 玩家正在对话的 NPC |
| 高 | 集结 / 战斗 / 避战模式下的战时公开对话 |
| 高 | 守备官发布新指令后立即触发的计划重评估 |
| 高 | 战时 HP 低于 30% 的自身心理判定 |
| 中 | 逃离挽留对话 |
| 中 | NPC 主动找玩家交涉 |
| 中 | 行动异常重评估 |
| 低 | NPC 间闲聊 |
| 最高 | 首次睡眠总结 |
| 低 | 每日计划，可批处理 |

## 调用记录字段

每次模型调用记录：

- 时间
- 调用类型
- 关联事件 id 或触发事件 id
- 关联 NPC id
- Godot 侧请求 id
- provider、model、base_url 标识（不含 Key）
- 是否申请 TimeSystem 慢速
- 慢速申请与释放时间
- 输入 token
- 输出 token
- 估算费用
- 是否成功
- 失败原因
- HTTP 状态或异常类型
- 是否使用 mock、规则降级或模板降级

正式供应商请求不设置客户端单次输出 token 上限。供应商自身的上下文窗口仍然存在；若返回 `finish_reason=length`、空内容或非法 JSON，后端会记录真实原因并使用对应业务的紧凑提示重试一次。`LLM_BUDGET_MAX_*` 是可选的累计预算守门，默认 `0` 关闭，只限制累计调用、累计 token 或累计费用，不限制单次生成长度。

## LLM 等待与时间减速

会影响当前场景即时状态的 LLM 调用，需要由 Godot 侧在发起请求前调用 `TimeSystem.request_time_slowdown(...)`。请求成功、失败、超时或降级后必须释放。

默认慢速倍率为 `1/60`：默认速度下从现实 1 秒 = 游戏 1 分钟减缓为现实 1 秒 = 游戏 1 秒。该倍率只影响逻辑时间、资源/状态/战斗等数值结算，不影响 Godot 全局运行速度、NPC 移动速度或动画速度。

正式开局和跨天后的新一天计划期间，`GameStartupSystem` / `DailyPlanSystem` 直接暂停 `TimeSystem`，因此每个计划请求不重复登记慢速。T0022 将 8 名 NPC 调整为 8 路并发；单人失败只重试真实请求，最多 3 次，8 份 `llm_plan_day` 全部就绪后才恢复时间。任一 NPC 仍失败则整批保持暂停，不使用 Mock 或规则降级。常规运行中的对话、通用计划修改判别、单次每日计划、计划修订、战时低血量心理判定和首次睡眠总结都属于会影响即时状态的正式业务请求，payload 默认为 `requires_time_slowdown=true`。集结 / 战斗 / 避战模式下的守备官对话会影响当前战局意向，应按高优先级立即申请慢速；战时 HP 低于 30% 的自身心理判定同样是高优先级，并且判定等待期间目标 NPC 不可被守备官对话。首次睡眠总结虽然频率低，但它锁定 NPC 当下状态，必须申请慢速并确保请求结束后释放。health / usage 等只读请求和显式 `/mock/model` 后端调试不申请慢速。

T0029/T0030 后 NPC-NPC 邀请判定也属于对话请求，等待期间受邀者继续当前工作，但逻辑时间仍按邀请 request id 降速；接受后的每轮正式回复重新登记新的慢速请求。无硬轮次上限不改变降速规则，每次调用仍必须独立注册并在结束后释放。

T0049/T0050 后，六类正式业务都提供异步 Godot 路径，避免用短同步等待阻塞主线程。T0021 后正式业务不再设置 75 / 90 秒响应总时长：Godot 只对连接本地 / 游戏后端使用 2 秒短连接保护，请求发出后等待后端完成。后端对供应商使用流式 SSE；连接超时和流完全无数据的空闲超时分别配置，持续收到 token 或 keep-alive 时继续等待，不限制模型生成总时长。`LLMBridge.debug_get_llm_runtime_snapshot()` 会记录每个请求的 call_type、是否注册 / 释放慢速及时间戳，便于确认成功、失败、取消、连接 / 空闲错误和降级路径没有遗留减速。

`current_order` 会进入所有面向该 NPC 的 LLM 请求，因此必须限制为单条当前有效指令，不重复注入全部历史版本。历史修改通过 `private` `order_assigned` 事件进入短期记忆摘要；常规请求只额外携带当前文本和最小元数据，避免指令修订不断放大上下文。

## 当前实现状态

- T0602 已实现默认 `mock` provider 的 `ModelAdapter.generate(...)`，可以按调用类型返回稳定 JSON；该能力只作为开发期脚手架和自动化验证入口。
- Mock 调用会记录用途、request id、NPC id、关联事件 id、伪输入/输出 token、估算费用、成功/失败状态和失败原因；mock 费用固定为 0。生产 / 演示真实 provider 失败时不得自动返回 mock 内容伪装成功。
- T1401 已实现 `deepseek` / `openai_compatible` 真实 Model Adapter。DeepSeek 默认 `LLM_BASE_URL=https://api.deepseek.com`、`LLM_MODEL=deepseek-v4-flash`；真实 Key 只从 `LLM_API_KEY` 或服务器 / 本地后端环境读取。T1401A 后 `LLM_FALLBACK_TO_MOCK` 默认关闭，真实 provider 无 Key、请求失败、超时、HTTP 错误、非 JSON 或业务 Schema 校验失败时返回可处理错误并写入 usage；自动 mock fallback 只在显式 `LLM_FALLBACK_TO_MOCK=true` 的开发调试中启用。
- T0049/T0050 后，六类正式 call_type（含通用 `plan_revision_judgement`）均不向供应商发送 `max_tokens`。供应商返回空内容、非法 JSON 或 `finish_reason=length` 时会按 call_type 紧凑重试一次；`/health` 快照显示 `client_output_token_limit_applied=false`，usage 继续记录真实 `finish_reason`、内容长度、尝试次数和失败原因。
- T0021 后，正式供应商请求统一使用 `stream=true` 聚合最终 JSON。旧 `LLM_TIMEOUT_SECONDS` 已拆为 `LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS` 与 `LLM_PROVIDER_IDLE_TIMEOUT_SECONDS`；空闲超时只在流完全没有 token、keep-alive 或其他字节时触发，不是总生成时长上限。
- T0603 已实现 `POST /npc/dialogue` 业务接口，内部复用 `ModelAdapter.generate("dialogue", ...)`，因此对话调用也会产生 usage 记录；业务响应仍只返回 Schema 校验后的模型内容，usage 通过 `GET /debug/llm_usage` 暴露给调试入口。
- 真实 provider 调用会优先读取供应商返回的 prompt / completion token；供应商未返回 usage 时用本地粗略估算。费用估算读取 `LLM_INPUT_COST_PER_M_TOKENS` / `LLM_OUTPUT_COST_PER_M_TOKENS`，未配置时为 0。
- T1406 后，预算守门读取 `LLM_BUDGET_MAX_CALLS`、`LLM_BUDGET_MAX_INPUT_TOKENS`、`LLM_BUDGET_MAX_OUTPUT_TOKENS`、`LLM_BUDGET_MAX_TOTAL_TOKENS` 和 `LLM_BUDGET_MAX_COST`，默认 `0` 表示关闭。任一上限启用后，正式业务接口会在调用模型前检查累计 usage 和本次输入 token 估算；超预算时返回 HTTP 429 / `budget_exceeded`，usage 记录 `exception_type=BudgetExceeded`、`degradation_source=budget_blocked`、request id、call_type、provider/model、NPC id 和失败原因，不自动 mock fallback。
- `POST /mock/model` 可用于后端调试；后续实现对话、计划、判定接口时，服务层应复用 Model Adapter 的 usage 信息，并补齐是否申请 TimeSystem 慢速、慢速申请与释放时间等 Godot 侧字段。
- T0604 已在 Godot 侧实现 `LLMBridge`；T0049/T0050 后对话、通用计划修改判别、每日计划、计划修订、低血量心理判定和首次睡眠总结都按 payload 注册 TimeSystem 慢速请求，并在成功、失败、取消或超时后释放。T1401 新增 `LLMBridge.debug_request_llm_usage()` 与 GM 面板“成本统计”只读入口，用于查看累计调用、token、费用估算、fallback 次数和失败原因。T1406/T0020 后，该入口同时显示预算上限 / 已用 / 剩余、最近预算错误，以及 Godot 侧 `debug_get_llm_runtime_snapshot()` 的等待请求数、pending request id、有效逻辑倍率、最近 TimeSystem 倍率变化原因和逐请求慢速注册 / 释放审计。更完整的多玩家限流、并发队列和服务器部署治理仍归 T1407。
- T0604A 已将 Godot 侧传输层改为原生 `HTTPClient`，不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件，并继续保证失败、超时和降级路径都会释放慢速请求。
- T1006/T0051 起，玩家对话 UI 使用 `LLMBridge.request_npc_dialogue_async(...)` 发起异步 `/npc/dialogue`：发送消息或普通对话攻击才申请慢速和 NPC LLM 活动状态。玩家在回复返回前点击“完成对话”会取消 request id、释放慢速、清除活动状态并丢弃迟到回复，但已立即进入历史的守备官消息会随完整会话入库并触发判别；“取消对话”同样取消请求但不入库、不判别；“挂起对话”不取消请求，NPC 和 TimeSystem 等待状态照常持续。普通对话攻击仍计入 `call_type=dialogue`，攻击事实先由 Godot 结算且锁定取消。逃离挽留攻击不调用 LLM，不申请慢速，不计入 API 成本，并自动完成会话。
- T0050 后，日常行动异常、NPC-NPC 和守备官-NPC 实际对话都先请求异步 `/npc/plan_revision_judgement`，仅非空判别再请求 `/npc/revise_plan`；新指令、战斗 / 复苏和 GM 等其他来源仍直接受限修订。修订输出与 `revision_hours` 完全一致，输出 token 成本随真正受影响的阶段数变化。每次实际请求都注册 TimeSystem 慢速并在成功、失败或取消后释放；Godot 修订失败最多重试 3 次真实请求。若真实响应通过 JSON / Schema 但不满足精确小时集合、工作阶段或白名单业务合同，后端可携带原错误用同一真实 provider 纠正一次，该调用单独写 usage；这不是 Mock / 规则降级。正式路径拒绝 Mock provider、缺少 provider 证明和 `model_fallback_used=true`，最终失败保留原计划和真实错误，不生成 `mock_revision` 或 `rule_revision_fallback`。
- T1003/T1403/T0022 后，每日计划通过 `/npc/plan_day` 走 Model Adapter。正式开局和正式新一天会暂停时间并同时发起 8 个真实请求；常规单次计划请求申请 TimeSystem 慢速。真实 provider 路径读取 `data/prompts/daily_plan_system_prompt.txt`，后端校验 24 个 hour 覆盖、行动白名单和至少 6 个工作阶段，并返回 provider / model / fallback 元数据。Godot 正式路径只接受 `llm_plan_day`；真实 provider 不可用、响应越界或连续 3 次真实请求仍失败时，整批保持暂停并保留失败日志，不使用 `mock_plan_day` 或 `rule_plan_fallback`。
- T1004/T1005/T1405/T0024 起，首次睡眠总结可通过异步 `/npc/daily_reflection` 走 Model Adapter。Godot 侧默认 `requires_time_slowdown=true`，不设置业务响应总时长；总结发起到完成期间 NPC 处于不可打断的深度睡眠锁，因此它不是后台无感调用。符合条件的 8 名 NPC 最多 8 路并发，快照记录实际峰值。后端成功体携带 provider / model / fallback 元数据；真实结果写为 `llm_daily_reflection`，显式开发 Mock 才写 `mock_daily_reflection`。真实 provider 不可用、未配置、缺少来源证明或输出不合法时，`DailyReflectionSystem` 使用本地模板兜底，仍会追加日记、替换式更新知识图谱当前键值并清空该 NPC 当天短期记忆；模板来源和原始失败原因必须可查。
- T1201 后，战时公开对话复用 `call_type=dialogue`，请求 payload 额外携带 `interaction_context=rally|combat|avoid_combat` 和 `battlefield_context`；`LLMBridge` 最近上下文注入快照会标记是否携带战场上下文。低血量自身心理判定使用独立、异步的 `call_type=battle_judgement`，不能与旧式“战斗触发全员判定”混淆；后者已被取消。T1404 后，真实 provider 路径读取 `data/prompts/battle_judgement_system_prompt.txt`，后端会拒绝越界 `decision` 与逃离布尔不一致结果并写入失败 usage；真实 DeepSeek 已完成战时 `/npc/dialogue` 与 `/npc/battle_judgement` smoke 验证，`fallback_used=false`。
- T1204A 后，逃离挽留中“玩家发送消息并等待 NPC 回复”的轮次复用 `call_type=dialogue` 和 `/npc/dialogue`，payload 使用 `dialogue_kind=escape_intervention`、`interaction_context=escape_intervention` 和 `escape_intervention_round=1..5`。它会影响当前逃离状态，因此仍按对话类请求申请 TimeSystem 慢速；后端失败时 Godot 规则降级为 stay/continue 意图，并释放慢速请求、保留真实失败日志。逃离挽留面板内的攻击只由 Godot 权威结算并计 1 轮，不请求 `/npc/dialogue`。

## 真实 API 验收与失败可见性

- 每个涉及 LLM / Prompt 的任务应先跑 mock / schema 自动化测试，再用真实 API Key 对本任务涉及的业务路径做至少一次真实 provider 测试。
- 没有真实 Key 时，不能把真实 LLM 行为标记为完全验收；任务状态应为 Partial / Blocked，或在验收结果中明确真实 API 未测。
- 生产 / 演示配置必须关闭自动 mock fallback。预算超限、无 Key、provider 错误、超时、非 JSON 或 Schema 失败时，返回可处理错误；只有明确保留降级语义的其他系统才能使用规则 / 模板结果，正式每日计划不降级。
- Usage / 日志必须能回答“哪个 request、哪个 call_type、哪个 provider/model、哪个 NPC、为什么失败、是否降级、花了多少 token/费用估算”。这比在失败后生成一段看似正常的 mock 回复更重要。
