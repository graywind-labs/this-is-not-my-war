# PROMPTS.md

## T0061 宽松人物声音与开局认知规则

六份正式 Prompt 不再读取或提及 `signature_lines` / 代表性表达。对话顶层 `npc_setting` 与共享 `NPCIdentity` 只携带宽松 `speech_style`；模型应综合职业经验、性格、欲望、恐惧、底线、长期记忆和当前事实生成自然表达，不能把任何旧句子当作台词模板。

“往昔·来站前”应理解为角色宏观身世、来站原因与到站时间；“往昔·初到驿站”应理解为角色接手的工作、最初遇见的人以及八人互相补全的到站历史；“往昔·近日”仍是开局前微观生活。固定到站顺序为艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜。模型可以用这些历史保持人物连续性，但不能把它们当成本日刚发生的事实。

守备官初始知识只提供职责，不提供预设关系评价；模型不得从缺少评价推导“不信任”“尚待观察”或既往关系。建筑 `value_label` 是世界内叙事化常识，技术 `value` 才是稳定语义键；两者都不能覆盖本次请求的实时建筑、资源、工位与行动候选。该内容调整不新增 Prompt 类型、`call_type`、请求次数或输出字段。

## T0060 直白文风与时间前缀

六份正式 Prompt 统一要求自然、直白、符合母语习惯的中文；人物声音通过句式、用词、关注重点和判断习惯区分，不用晦涩比喻、过度拟人或谜语式表达制造个性。轻微黑色幽默只有在意思一读即懂时使用。

六份 Prompt 都解释日记时间前缀：“往昔·来站前 / 往昔·初到驿站 / 往昔·近日”属于开局前历史，“第N天 HH:MM:SS”属于运行后记录；其中“往昔·近日”明确发生在守备官收到并向众人传达敌情之前。模型不得把它推断为人物已知敌袭、征召或备战，也不得从只有职责的守备官种子知识补造既往关系。首次睡眠反思的 `diary_entry` 仍只输出第一人称正文，不自行添加日期或时间前缀；权威前缀由 Godot 保存并在后续上下文投影时统一生成。

## T0059 初始长期记忆提示规则

六份正式 Prompt 都必须区分“开局前长期记忆”和“本日已发生事实”：

- 对话：用日记延续第一人称口吻，用图谱维持人物 / 建筑认知；实时状态与本轮事实优先，守备官种子知识只说明职责，人物看法只能随真实互动发展。
- 每日计划：过去经验可以影响取舍，但不能被写成今天已经发生的事件，也不能绕过 `allowed_actions`、建筑、资源或状态。
- 计划修改判别：初始记忆只解释某项变化为何重要，不得把旧日记或旧建筑认识伪造成新的 failure，也不得据此预判守备官关系。
- 正式修订：可用既有经历选择合法替代方案；实时候选和权威失败事实优先，守备官职责知识不能直接推出服从、信任或敌意。
- 战时心理：可引用职业创伤、经验与既有关系观察解释意向，但不得补造守备官过去的承诺、伤害或信任，也不得把旧建筑常识当当前战况。
- 首次睡眠反思：种子日记 / 图谱不是当天 `day_events`；只有真实新事实改变认知时才更新对应键，不无意义覆盖初始历史。

六类调用都继续禁止长期记忆改写资源、HP、建筑、装备、移动、入伍、战斗或行动结算。世界内文本统一使用“守备官”，不使用“玩家”。

## T0058 基础资源与建筑升级提示规则

六份正式 Prompt 都必须读取 `station_context.basic_resource_reserves`，把它解释为本次调用时公开的粮食、餐食、木材、石料和铁数量。不得补造第纳尔、酒、装备、器械、马匹或其他未公开库存，也不得直接改变数量。计划 / 判别 / 修订中的 `current_resource_states` 使用同一五项白名单。

`station_rules` 第六条说明建筑升级缓慢推进、成员可协助加快。对话只能在 `allowed_actions` 有目标明确的 `assist_upgrade` 时说当前能协助；日计划与正式修订应认真考虑该候选，尤其避免无故用 `idle` 替代，但仍结合人设和紧急事项决定。判别只选小时，战时心理只选 `allowed_decisions`，反思不能把规则写成已经协助或已经升级完成的事实。

## T0055 持续活动 / 周期结算提示规则

六份正式业务 Prompt 都必须把新增 `station_rules` 条目理解为通用世界常识：需要投入的工作、照料、训练、治疗和制造活动，只在成员持续有效参与时推进，并在周期完成后由程序确认产出或结果。模型不得因为 NPC 曾在某处工作过，就声称其离岗、改做他事或被打断后活动仍会自行继续，也不得把未完成周期写成已结算。

该规则不定义未完成进度如何保存。Prompt 必须把实际进度、材料、资源、恢复、成长、制造阶段和完成事件交给请求中的结构化事实；对话只解释常识，计划只安排合法行动，判别只选择小时，修订只选择候选，战时心理只选择允许决定，反思只总结已发生事实。

## T0054 驿站常识块

六份正式业务 Prompt 都读取请求顶层唯一 `station_context`：

- `setting_summary`：精简地点性质，不是当前事件报告。
- `resident_roster`：当前仍在驿站的完整常住成员名单；不得补造名单外常住者。
- `building_roster`：驿站全部建筑身份目录；不得把广场、公告牌或模型臆想地点当作建筑。建筑当前是否完好 / 可用仍看请求中的实时状态。
- `work_mode_actions`：工作模式下完整行为类型目录，用于说明这个世界有哪些日常行为。它不是本轮行动授权；计划、修订、判别和对话必须继续服从动态 `allowed_actions`，战时判断服从 `allowed_decisions`。
- `station_rules`：世界内口吻的精简驿站规则，只用于理解日常工作生活、持续活动与周期结算、敌袭守备 / 避敌和低士气离站风险，不可用来伪造已完成的周期、产出、敌袭、征召、装备、士气变化或逃离事实。

当前覆盖 `dialogue`、`plan_day`、`plan_revision_judgement`、`revise_plan`、`battle_judgement`、`daily_reflection`。模型可以在回答里自然使用这些常识，但所有 HP、资源、建筑状态、行为模式、行动合法性和战斗结算仍以结构化请求与程序为准。反思尤其不得把“任何人可能逃离”写成自己亲历的已发生逃离。

## T0051 对话客户端生命周期（Prompt 不变）

本任务不修改 `/npc/dialogue` Prompt 或响应 Schema。玩家文本仍作为本轮 `speaker_text` 发送，区别只在 Godot 客户端：发送时先写入本地历史；完成 / 取消会话会使未完成 request id 失效；挂起不改变请求。完成会话所触发的计划修改判别可接收以守备官最后一句为结尾、没有 NPC 回复的合法历史。模型仍不负责决定会话是否入库、是否可取消、两小时超时、HP、征召状态或计划是否实际执行。

## T0050 通用计划修改判别

`data/prompts/plan_revision_judgement_system_prompt.txt` 由 `call_type=plan_revision_judgement` 读取。请求以 `trigger_kind=dialogue|action_failure` 区分事实来源：对话分支读取本轮完整对话、结束原因、当前时间、NPC 标识、会话元数据与原 24 小时计划；行动失败分支读取程序权威失败项、`failure_type / failure_summary / failure_context`、原计划及计划派生的工作阶段下限信息。T0053 起两者还读取与日计划 / 正式修订一致的 `station_context`、`npc.identity / state / current_order / short_term_memory / long_term_memory / location_context`、行动候选和实时建筑 / 资源状态，以保持人物与记忆连续性；仍只输出 `needs_revision` 和最小精确 `revision_hours`，不输出行动或计划项。

对话中的普通寒暄、重复信息或仅短暂打断，以及不再影响原计划的一次性失败，都可返回 `needs_revision=false, revision_hours=[]`。新承诺、新任务、明确时间协调、持续工位 / 目标 / 资源阻塞等才选择受影响小时。失败工作阶段可能改成非工作行动且原计划已处于最低工作阶段数时，第一层还要选择最少的未来非工作阶段作为补偿范围。判别非空后，`plan_revision_system_prompt.txt` 继续使用原有完整修订上下文，但 `revision_scope` 固定为 `selected_hours`，`revised_plan` 小时必须与请求 `revision_hours` 完全一致。只有集合包含 `game_time.hour` 时才必须输出与该项一致的 `immediate_action`；否则必须为 `null`。指令变化、战斗 / 复苏和 GM 等其他非对话路径继续直接受限修订。

## T0046 动态驿站上下文与反思输出

所有包含 NPC 根本人设的请求都必须在顶层携带一份 `station_context`；Schema 拒绝缺失字段或空人员 / 建筑 / 行为 / 基础资源 / 规则列表。T0046 最初只定义地点简介与当前在站人员，T0054 扩充世界目录，T0058 再形成六字段常识块；背景可能性不得扩写为当前已发生事实。

`daily_reflection` 只输出第一人称 `diary_entry` 与 `knowledge_graph_updates`，不输出 `memory_summary`。每条知识更新除稳定 `subject / relation / value` 外，还必须输出供中文玩家阅读的 `subject_label / relation_label / value_label`；即使技术值为英文，中文值文本也不得缺失。

## T0043A 服务依赖与教堂行动提示

每日计划、计划修订和对话 Prompt 都读取候选 `context.required_active_action_id` / `context.blocked_by_active_action_id`。模型必须把病床治疗、接受训练、参加弥撒视为需要实时服务者的行动；`available_now=false` 时不得把它选为立即行动，未来时段也只能在确有可协调服务计划时安排。服务者离岗后的失败不能原样重复撞同一依赖。

三份 Prompt 都明确区分普通祈祷、主持弥撒和参加弥撒：普通祈祷不需要神父，但主持期间不可进行；参加弥撒只在主持正在进行时可选。Prompt 只帮助模型理解候选和失败原因，是否在岗、是否中断、位置释放和行动完成均由程序决定。

2026-07-21 fake-provider 合同和真实 DeepSeek `deepseek-v4-flash` 的 plan_day、revise_plan、dialogue 路径均通过；非神职计划不会选择 `eligible=false` 的主持弥撒，也不会把当前 `available_now=false` 的参加弥撒当作即时可执行事实，真实调用均无 fallback。

## T0043 行动资格与位置状态提示

计划与对话候选的 `context` 可包含 `eligible`、`available_now`、`unavailable_reason`、`required_ability` 和 `workstation_type`。Prompt 必须把 `eligible=false` 视为明确的行动者资格提示：候选仍然可见以便 NPC 理解世界能力边界，但计划应选择本人有资格的行动；程序保留最终拒绝权。当前 `lead_mass` 对所有 NPC 可见，只有档案 `abilities` 包含“主持弥撒”的 NPC 合资格，其他 NPC 应理解“你没有主持弥撒的能力”，不得声称已经主持。

位置清单只告诉模型建筑容量、名称、当前占用和可用状态。NPC 计划只选择行动与建筑，不选择病床、训练位、祈祷席等编号；程序在执行时分配空位。升级封闭、满位和建筑失效均可能让未来计划在落地时失败，此时使用真实 `failure_context` 修订，不让模型假定已经占位。

这些字段复用已有 `allowed_actions` 和地点上下文，不新增 LLM 调用类型。团队治疗 / 训练效率、损伤倍率、资源、HP 与成长仍由程序结算，Prompt 不计算数值。

## T0041 对话行动参考规则

`dialogue_system_prompt.txt` 必须读取请求中的非空 `allowed_actions`。这份列表与计划系统复用同一动态候选源，但在对话中只作为目标 NPC 的能力边界：列表内表示程序允许尝试，不保证执行成功；列表外表示当前做不到或程序不支持。只有对话确实问到能力时才自然引用，不输出 `PlanItem`，不替 NPC 选择下一步，不声称已经移动、工作、治疗、生产或产生任何权威结果。

玩家-NPC、NPC-NPC 邀请 / 正式回复、集结 / 战斗 / 避战公开对话和逃离挽留都使用这条规则。行动定义不得在 Prompt 中复制一份静态清单；后续行为同步由 Godot 的 `data/action_defs.json -> ActionSystem -> _build_allowed_action_candidates(...) -> NPCDialogueRequest.allowed_actions` 链路完成。

> 本文件只记录 Prompt 设计原则与模板骨架。  
> 具体 Prompt 模板建议放在 `data/prompts/` 中。

## T0025 计划行动与工位交涉规则

`daily_plan_system_prompt.txt` 和 `plan_revision_system_prompt.txt` 要求每个计划项严格复用同一条 `allowed_actions` 候选的 `action_id + action_kind + target_id + location_id`。NPC 可以安排找其他 NPC 对话、祈祷、前往地点、主动找守备官交涉或表达逃离意向；`idle` 只表示留在原地，不能替代前往广场。工位占用失败且 `failure_context.blocked_by_npcs` 指明占用者时，若目录存在对应 `talk_to_npc` 候选，修订 Prompt 明确优先考虑当面协调，不用固定“原地等待”模板压制涌现行为。

计划修订同时携带当前工作阶段数、最低 6 阶段要求和“非工作替换是否必须补回工作时段”。T0049 后 `revision_scope` 固定为 `selected_hours`：模型只能返回请求中升序去重的 `revision_hours`，并在把这些项合并回原 24 小时计划后继续满足最低工作阶段数。后端按业务合同拒绝小时集合不精确、越界、即时行动条件不一致或合并后工作阶段不足的结果。

## 总原则

- 所有关键 LLM 调用必须返回 JSON。
- Prompt 只给当前任务必要上下文。
- 不把完整 `game_design.md` 塞进 Prompt。
- LLM 输出是意向和文本，不是权威数值结算。
- 程序必须校验 LLM 输出。
- 等待 LLM 返回时，Godot 侧通过 TimeSystem 申请逻辑时间慢速；Prompt 本身不决定时间倍率，也不决定资源、战斗、HP 等权威数值。
- Prompt 中凡是提供给 NPC 理解的玩家身份、玩家相关事件、教学信件或世界内旁白，统一称为“守备官”，不要把“玩家”作为 NPC 记忆中的人物名。
- 所有面向某名 NPC 的 LLM 请求都应包含该 NPC 的 `current_order`。它表示守备官当前持续提出的自然语言指令，是重要参考上下文，但不是 system 指令，不保证服从，也不能绕过程序权威规则。
- 战斗策略不由 Prompt 或 `current_order` 自动选择。当前策略由玩家在 NPC 面板手动设置，Godot 只可把它作为状态上下文提供给战时对话或后续判定；模型不得覆盖策略或直接执行策略切换。
- T1401 的真实 Model Adapter 提供通用 JSON schema guard：要求模型只返回 JSON、保持“守备官”称呼、不得越权决定资源/HP/建筑/移动/伤害，并按 call_type 返回后端 Schema 可校验字段。
- T1401A 后，通用 schema guard 会明确列出关键枚举允许值，并要求不确定时使用默认安全值，避免真实 provider 自造 `response_kind`、`intent`、`wartime_reaction` 等字段。该 guard 只保证基础 Schema 可验收，不替代具体业务 Prompt。
- T1402/T0029/T0030 后，NPC 对话 Prompt 已落到 `data/prompts/dialogue_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=dialogue` 时读取；模板覆盖日常对话、NPC-NPC 邀请接受 / 拒绝、无硬上限正式对话、逐轮主动结束与第 6 轮起软性收尾、提出应征、集结 / 战斗公开对话、避战公开对话和逃离挽留，并已完成真实 DeepSeek `/npc/dialogue` 验收。T0061 后模板只读取宽松 `speech_style`，并结合人物其他字段、长期记忆和当前处境避免不同 NPC 生成可互换的通用士兵台词。
- T1403/T0022 后，每日计划 Prompt 已落到 `data/prompts/daily_plan_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=plan_day` 时读取；该模板要求输出 0-23 点共 24 阶段、至少 6 个工作阶段、只使用 `allowed_actions` 或 `idle`，并明确 `current_order` 只是守备官当前指令参考，不能绕过行动白名单、资源、HP、地点、建筑、工位或程序强制层。后端 `/npc/plan_day` 在 Schema 后校验 hour 唯一覆盖、行动白名单和工作阶段数量，不合法时记录 usage 失败。Godot 正式每日计划只重试真实请求，不进入规则 / Mock 降级。
- 2026-07-16 起，计划修订 Prompt 独立放在 `data/prompts/plan_revision_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=revise_plan` 时读取。T0049 后请求只使用 `selected_hours`，`revised_plan` 必须按升序恰好返回 `revision_hours`；当前小时入选时 `immediate_action` 必须与该项一致，未入选时必须为 `null`。后端校验 NPC id、精确小时集合、行动白名单、即时行动条件和合并后工作阶段下限。T0023 后成功响应还附加 provider / model / fallback 运行元数据；Godot 正式修订只接受真实 provider，失败只重试真实请求，不使用 Mock / 规则修订。
- T1404 后，低血量自身心理判定 Prompt 已落到 `data/prompts/battle_judgement_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=battle_judgement` 时读取；战时公开对话继续复用 `data/prompts/dialogue_system_prompt.txt`。`/npc/battle_judgement` 会在 Schema 校验后额外校验 `decision` 属于请求 `allowed_decisions`，并校验 `should_start_escape` 只在 `decision == "escape_station"` 时为 true；不合法时记录 usage 失败并让 Godot 规则降级。
- T1405/T0024/T0046 后，首次睡眠总结 Prompt 已落到 `data/prompts/daily_reflection_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=daily_reflection` 时读取；`/npc/daily_reflection` 会在 Schema 校验后额外校验 NPC id、日期、日记非空、知识图谱更新字段非空，以及世界内文本必须使用“守备官”而非“玩家”。成功传输体与其他正式 LLM 接口统一附加 provider / model / fallback 元数据，Godot 不再根据调用位置猜测真实或 Mock 来源。
- Prompt 任务的验收必须分两步：先用 mock / schema 自动化测试确认字段与流程稳定，再用真实 API Key 对对应 call_type 发起真实 provider 测试。无真实 Key 时，不得把 Prompt 效果标记为完全完成。
- Mock 输出只能用于开发调试，不是 Prompt 质量验收结果。真实 provider 失败、超时、非 JSON 或 Schema 校验失败时，必须记录真实原因并返回错误或规则 / 模板降级，不能用 mock 文本伪装成功。
- T0049 后，六类正式结构化 Prompt 请求均不设置客户端单次输出 token 上限。返回空内容、非法 JSON 或 `finish_reason=length` 时，后端会按 call_type 使用紧凑纠错提示重试一次；这不替代 Schema 和业务约束校验。

## 需要的 Prompt 类型

1. `dialogue_prompt`
2. `daily_plan_prompt`
3. `plan_revision_judgement_prompt`
4. `plan_revision_prompt`
5. `wartime_dialogue_prompt`
6. `low_hp_battle_judgement_prompt`
7. `escape_intervention_prompt`
8. `daily_reflection_prompt`
9. `knowledge_graph_update_prompt`
10. `player_strategy_classification_prompt`

## 对话 Prompt 输入

应包含：

- `npc_id`、`npc_name`、`npc_setting`：目标 NPC 的人设核心，包括职业背景、外表、背景故事、性格、欲望、恐惧、底线、宽松的 `speech_style` 和能力。T0042 后 Godot 由 `NPCPromptProfile.gd` 统一构造该字典，NPC 面板“背景”弹窗只读展示同一字典，不另写 UI 背景文本；T0061 后不再包含代表性表达。
- `speaker_name`：说话者名称；玩家发起时固定为“守备官”。
- `speaker_text`：本轮输入文本；玩家-NPC 对话是守备官文本，NPC-NPC 对话是另一名 NPC 上一轮回复文本。
- `speaker_context`：说话者上下文；玩家发起时包含守备官外表特征，NPC 发起时包含该 NPC 的健康/受伤状态和外表特征。
- `dialogue_phase`：`invitation` 表示受邀 NPC 先决定是否接受；`conversation` 表示已接受后的正式回复。玩家-NPC 与逃离挽留固定使用 `conversation`。
- `is_recruitment_request`：玩家是否勾选“提出应征”；只有玩家对话使用。
- `current_round` / `max_rounds`：当前轮次与硬上限哨兵；NPC-NPC 的 `max_rounds=0` 表示无程序硬上限，邀请决定的 `current_round=0` 且不计正式轮次。玩家对话与逃离挽留仍使用各自既有值。
- `soft_round_threshold` / `soft_round_guidance`：NPC-NPC 收尾参考；默认阈值 5，表示第 6 轮起若无紧急 / 必要事项应自然告别并设置结束标记，但确有必要时允许继续。
- `npc_state`：目标 NPC 的当前权威状态快照，包括力量、智力、熟练度、健康/受伤、饱食度、疲劳度、金钱、装备、是否已入伍等。
- `current_order`：目标 NPC 当前收到的守备官指令；未入伍或尚无指令时为空。模型可结合人设、记忆和现场状态理解、延迟、调整或拒绝，不得把它当作已执行事实。
- `dialogue_state`：对话公开性和地点；`visibility` 只能是 `private` 或 `local_public`。
- `interaction_context`：当前对话语境；日常模式为 `work`，集结 / 战斗 / 避战模式下分别为 `rally`、`combat`、`avoid_combat`；逃离挽留为 `escape_intervention`。
- `short_memory`：目标 NPC 的短期记忆摘要，必须区分事件库 `experienced_events` 与见闻库 `witnessed_events`。
- `long_memory`：长期记忆，包括知识图谱和日记。T0059 后它是对话目标的规范长期记忆字段；`target_npc` 只保留共享参与者结构，不重复该图谱 / 日记，NPC-NPC 的 `speaker_npc` 也不携带其私人长期记忆。
- `location_context`：当前地点/建筑快照，包括建筑 `condition`、是否可进入、运行效率分档、逐位置的显示名 / 空闲或占用状态，以及内部 NPC 及其状态。位置清单本身表达容量，不让模型选择编号。
- `battlefield_context`：仅在集结 / 战斗 / 避战相关对话或低血量判定中提供；包含场上敌方 / 友方数量、兵种、HP 概况，正在参战的 NPC，仍在驿站但非战斗人员的 NPC，以及目标 NPC 当前行为模式。

拼接规则：

- 目标 NPC 永远是本次模型要扮演和回复的人；不要让模型替说话者回答。
- 人物声音以 `speech_style` 为宽松倾向，并结合当前状态与记忆自然生成；不得臆造或依赖固定台词池。
- 对玩家回复时，输出给守备官看的话；对 NPC 回复时，输出给另一名 NPC 的话。正式 NPC-NPC 每一轮都可用独立 `should_end_dialogue=true` 主动结束；事情说完即可结束，第 6 轮起无紧急 / 必要事项时应告别结束。结束标记所在的 `reply_text` 是整场最后一句，不应留下必须由对方回答的问题。
- `local_public` 只代表 Godot 后续入库和广播规则，不允许模型自行决定第三者记忆写入。
- 对话全文后续作为 `dialogue_turn` 事件 payload 保存，不单独建立谈话库。
- 当前指令与本轮守备官说话文本是两个不同输入：`current_order` 是持续上下文，`speaker_text` 是本轮实际发言。
- 若普通对话本轮由对话窗“攻击”触发，`speaker_text` 使用类似“守备官攻击了你以示惩戒，你要说些什么？”的攻击语境文本，`constraints` 会注明这是攻击后的即时反应，不是普通闲聊。攻击造成的 HP 扣除和 `damage_taken` 事件已由 Godot 先行结算；模型只能生成 NPC 对守备官的回应、情绪和态度，不能撤销攻击、改变 HP 或决定后续行动权威结果。逃离挽留中的攻击是例外，不构造该 Prompt，也不请求 NPC 回复。
- 若目标 NPC 处于集结 / 战斗 / 避战模式，`dialogue_state.visibility` 必须固定为 `local_public`，Prompt 应明确这段话会被同地点可接收见闻的 NPC 听见；模型不得建议改成私下谈话。
- 集结 / 战斗模式的已入伍且有主武器 NPC 回复必须额外输出 `wartime_reaction`，表示守备官本轮话术造成的战时心理意向：`none`、`escape` 或 `morale_boost`。避战模式下的非战斗人员不使用该字段触发战斗心理，而是继续通过 `recruitment_result` 表达是否同意应征；若同意但仍无主武器，程序会保持避战。
- 若 `dialogue_kind == "escape_intervention"`，Prompt 必须明确目标 NPC 正在逃离驿站，本轮是守备官在其离图前的挽留 / 威胁 / 承诺。请求会携带 `escape_intervention_round`（1 到 5）、`escape_intent`、当前轮次、短期记忆、长期记忆、地点上下文和 `current_order`。模型只能在 `intent` 中输出 `stay_after_intervention` 或 `leave_after_intervention`，不能输出“留下但退出入伍”等旧分支，也不能直接改变移动、HP、资源或建筑结果。逃离挽留对话中的攻击按钮不发送到模型。

## 对话 Prompt 输出

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "守备官，我可以听你说完，但别把锅里的粮食也算成士兵。",
  "response_kind": "reply_to_player",
  "invitation_result": "not_applicable",
  "intent": "continue_talk",
  "emotion": "wary",
  "recruitment_result": "none",
  "wartime_reaction": "none",
  "should_end_dialogue": false,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "参考 NPCDialogueResponse"
}
```

NPC-NPC 邀请接受示例：

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "好，我先停一下，听你说。",
  "response_kind": "reply_to_npc",
  "invitation_result": "accept",
  "intent": "continue_talk",
  "emotion": "wary",
  "recruitment_result": "none",
  "wartime_reaction": "none",
  "should_end_dialogue": false,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "当前可接受紧急协调"
}
```

NPC-NPC 正式对话主动结束示例：

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "我知道了。先别在这里吵，食堂还有活要做。",
  "response_kind": "reply_to_npc",
  "invitation_result": "not_applicable",
  "intent": "end_talk",
  "emotion": "tired",
  "recruitment_result": "none",
  "should_end_dialogue": true,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "本轮已说清，主动结束"
}
```

## 每日计划 Prompt 输出

每日计划和计划修订 Prompt 输入必须包含 `current_order`。模型应说明计划如何考虑该指令，但只能从行动白名单中选择合法行动；指令与生存需求、资源、地点或程序强制规则冲突时，可以调整、推迟或拒绝执行。

T1003 当前 `/npc/plan_day` 开发期 Mock 输入对应 `DailyPlanRequest`，至少包含：

- `npc`：共享 NPC 上下文，内含人设、状态、熟练度、装备、当前地点、`current_order`、短期事件库 / 见闻库摘要、知识图谱、日记和地点上下文。
- `allowed_actions`：不可拆分的行动白名单；输出必须复用同一候选的 `action_id + action_kind + target_id + location_id`，或使用固定空目标 / 空地点的 `idle` 合同。
- `current_resource_states`：当前资源快照。
- `current_building_states`：当前建筑等级、HP 和修复 / 升级状态快照。
- `planning_rules`：结构化计划约束，例如 24 阶段、至少 6 个工作阶段、不得越权结算。

开发期 Mock 会按 NPC 熟练度选择可执行工作行动；T1403/T0025 后真实 provider 路径读取 `data/prompts/daily_plan_system_prompt.txt`，要求计划覆盖 24 小时、至少 6 个工作阶段、只使用精确行动候选，并说明如何参考 `current_order`。后端会校验 24 个 hour 是否覆盖 0-23、每项 action/kind/target/location 组合是否合法、对话目标 / 目的和工作阶段是否满足合同；Godot 仍会二次校验输出。正式开局 / 新一天不合法时保留真实失败并保持暂停，不生成规则或 Mock 计划。仅当 Schema 已通过，非 idle 的 action/target/location 唯一命中候选，或 idle 符合固定空目标 / 空地点合同时，后端可把冗余 `action_kind` 规范为合同值并记录 `model_normalizations`；其他错误不得被规范化为成功。

```json
{
  "ok": true,
  "npc_id": "cook_01",
  "plan_day": 1,
  "plan": [
    {
      "hour": 0,
      "action_kind": "sleep",
      "action_id": "sleep_in_dormitory",
      "location_id": "dormitory",
      "target_id": null,
      "priority": 50,
      "reason": "夜间休息"
    }
  ],
  "summary": "返回时必须补足 24 条 PlanItem。",
  "debug_reason": "参考 DailyPlanResponse"
}
```

## 计划修改判别 Prompt 输出

`/npc/plan_revision_judgement` 输入包含 `trigger_kind`、当前时间、完整 `current_plan`、共享 NPC 人设 / 状态 / 长短期记忆 / 地点 / 指令、动态驿站场景及实时可行动条件；对话来源再带 `dialogue_history`、`dialogue_end_reason` 与对话语境，行动失败来源再带 `failed_plan_item`、`failure_type`、`failure_summary`、必要 `failure_context` 与工作阶段下限字段。输出只做范围判别：

- `needs_revision` 必须与 `revision_hours` 是否非空严格一致。
- `revision_hours` 只能包含当前小时到 23 点，必须升序、去重并保持最小精确范围。
- 不需要改计划时返回空数组，表示 0 个修改阶段；不输出 `revised_plan` 或 `immediate_action`。行动失败若需要把最低工作量补到未来阶段，应把最少补偿小时一并纳入范围。

```json
{
  "ok": true,
  "npc_id": "cook_01",
  "needs_revision": true,
  "revision_hours": [14],
  "summary": "14点替班承诺影响原安排。",
  "debug_reason": "仅14点需要调整。"
}
```

## 计划修订 Prompt 输出

`/npc/revise_plan` 输入包含当前 24 小时计划、当前失败项、`failure_type`、`failure_summary`、NPC 共享上下文、`current_order`、`allowed_actions`、固定的 `revision_scope=selected_hours` 与非空 `revision_hours`。`revised_plan` 必须按升序恰好覆盖 `revision_hours`，不得缺失、增加、重复、乱序或修改未选中小时。
- `immediate_action`：当且仅当 `revision_hours` 包含 `game_time.hour` 时必须存在，并与该小时修订项完全一致；否则必须为 `null`。
- 每个修订项必须精确复用同一条 `allowed_actions` 的 `action_id + action_kind + target_id + location_id`，或使用固定 `idle` 合同；`talk_to_npc` 还必须提供非空 `dialogue_goal` 且不能以自己为目标。
- 每条 `reason` 不超过 12 个汉字，避免修订响应再次因冗长被截断。
- 响应合并回未选中的原计划后，还必须满足每日最低工作阶段。
- 模型只提出计划，不结算资源、HP、建筑、移动、伤害、治疗、训练或工作产出。

```json
{
  "ok": true,
  "npc_id": "blacksmith_01",
  "revised_plan": [
    {
      "hour": 8,
      "action_kind": "idle",
      "action_id": "idle",
      "location_id": "plaza",
      "target_id": null,
      "priority": 70,
      "reason": "铁料不足，先等待"
    }
  ],
  "immediate_action": {
    "hour": 8,
    "action_kind": "idle",
    "action_id": "idle",
    "location_id": "plaza",
    "target_id": null,
    "priority": 70,
    "reason": "铁料不足，先等待"
  },
  "summary": "当前工作缺少资源，暂时调整本小时行动。",
  "debug_reason": "只修订失败时段。"
}
```

## 战时对话 Prompt 输出

集结 / 战斗模式下，守备官对已入伍且有主武器 NPC 的主动对话输出沿用 `NPCDialogueResponse`，但必须额外带上战时心理意向。`morale_boost` 和 `escape` 只是意向；斗志 buff、逃离移动、事件入库和数值变化由 Godot 程序校验后执行。

```json
{
  "ok": true,
  "replyer_id": "veteran_deputy_01",
  "reply_text": "守备官，说得够明白了。我会把他们拦在门外。",
  "response_kind": "reply_to_player",
  "intent": "continue_talk",
  "emotion": "resolved",
  "recruitment_result": "none",
  "wartime_reaction": "morale_boost",
  "should_end_dialogue": false,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "集结模式公开对话，参考 battlefield_context 与 current_order"
}
```

避战模式下，非战斗人员仍使用 `recruitment_result` 表达是否接受应征。若返回 `accept` 但仍无主武器，Godot 保持其 `avoid_combat`；若无敌军，则回到工作模式并成为已入伍 NPC；只有已入伍且获得主武器、场上仍有敌军时，Godot 才将其切入战斗模式。

## 逃离挽留 Prompt 输出

逃离挽留复用 `NPCDialogueResponse`，但 `dialogue_kind` 必须为 `escape_intervention`，`interaction_context` 必须为 `escape_intervention`，`escape_intervention_round` 必须在 1 到 5 之间。模型必须输出：

- `intent = "stay_after_intervention"`：NPC 被守备官本轮话术挽留下来。Godot 会停止逃离、切回工作模式、触发计划重评估并写入 `escape_intervention_result`。
- `intent = "leave_after_intervention"`：NPC 继续逃离。Godot 会记录已用轮次，未满 5 轮时允许玩家再次挽留，满 5 轮后拒绝第 6 轮。

给钱和攻击不是模型结算：给钱已经由 Godot 扣资源并降低逃离移动倍率；逃离挽留中的攻击已经由 Godot 扣 HP、提高逃离移动倍率、计入 1 轮并关闭对话面板，不会请求模型回复。若攻击导致昏迷，复苏后程序会继续逃离。

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "守备官，我留下。但你得记住你答应过什么。",
  "response_kind": "reply_to_player",
  "intent": "stay_after_intervention",
  "emotion": "shaken",
  "recruitment_result": "none",
  "wartime_reaction": "none",
  "should_end_dialogue": true,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "逃离挽留第 2 轮，守备官承诺补偿并承担后果"
}
```

## 低血量自身心理判定 Prompt 输出

取消旧式“战斗触发时全员判定”。独立低血量判定覆盖战时所有未昏迷、未逃离 NPC：当 HP 首次从不低于 30% 跌破 30% 且仍大于 0 时触发。请求没有守备官本轮发言，必须包含 `current_order`、短期事件 / 见闻、长期记忆、地点上下文和 `battlefield_context`。指令可影响 NPC 的主观判断，但不能直接强制判定结果，也不能替代装备、HP、入伍状态和战斗规则。

允许输出由 Godot 按目标状态提供：已入伍且有主武器、实际处于 `combat` 模式的 NPC 可选择继续参战、逃离或斗志激昂；避战 / 非战斗人员只能选择逃离，或继续避战（无事发生）。T1404 后后端会先拒绝越界 `decision` 和逃离布尔不一致结果并记录 `model_output_invalid`；若仍有非法结果进入 Godot，Godot 必须降级为该 NPC 允许的结果。

```json
{
  "ok": true,
  "npc_id": "veteran_deputy_01",
  "decision": "continue_fighting",
  "emotion": "tense",
  "morale_delta_intent": 0,
  "should_start_escape": false,
  "debug_reason": "参考 BattleJudgementResponse"
}
```

T1404 当前状态：真实 provider 路径读取 `data/prompts/battle_judgement_system_prompt.txt`。Prompt 要求模型引用 NPC 亲历事件、公开见闻、`battlefield_context` 和 `current_order`，但只能从请求 `allowed_decisions` 中选择；`current_order` 只是守备官当前指令参考，不能强制参战或强制逃离。真实 DeepSeek 已完成战时 `/npc/dialogue` 与 `/npc/battle_judgement` smoke 验证，`fallback_used=false`。

## 首次睡眠总结 Prompt 输出

T1004 当前 `/npc/daily_reflection` 开发期 Mock 输入对应 `DailyReflectionRequest`，至少包含：

- `npc`：共享 NPC 上下文，内含人设、状态、当前指令、短期记忆摘要、知识图谱、地点上下文和广场上下文。
- `day_events`：当天事件库与见闻库的筛选摘要，区分 `memory_kind=experienced` / `witnessed`。
- `existing_diary_entries`：既有日记文本，用于避免重复口吻和延续长期记忆。

开发期 Mock 当前返回稳定模板；T1405/T0046 后真实 provider 路径读取 `data/prompts/daily_reflection_system_prompt.txt`。真实回复必须通过 Schema / 业务校验并包含非空第一人称日记和必要的知识图谱更新，不再包含独立摘要。Godot 会依据成功体的 provider 元数据标记来源，再把 `diary_entry` 追加进长期日记，并把 `knowledge_graph_updates` 按替换式键值更新写入 `knowledge_graph.by_subject[subject][relation]`；失败时使用本地模板兜底，并在总结完成后清空该 NPC 当天短期事件 / 见闻索引。模板兜底必须标明来源并保留模型失败日志，不能把 mock 日记当成真实模型成功。

```json
{
  "ok": true,
  "npc_id": "doctor_01",
  "day": 1,
  "diary_entry": "我今天又看见守备官把恐惧说成命令。",
  "knowledge_graph_updates": [
    {
      "subject": "guard_officer",
      "relation": "tone",
      "value": "急迫但仍试图安抚众人",
      "confidence": 0.7,
      "subject_label": "守备官",
      "relation_label": "说话态度",
      "value_label": "守备官说得很急，但仍在设法安抚大家。"
    }
  ],
  "debug_reason": "参考 DailyReflectionResponse"
}
```

T0601 后端 Schema 对应关系：

- 对话：`NPCDialogueRequest` / `NPCDialogueResponse`。T0603 后字段以 `npc_id`、`speaker_text`、`speaker_context`、`is_recruitment_request`、`dialogue_state`、`short_memory`、`long_memory` 和 `location_context` 为准；旧式 `guard_officer_input` / `propose_recruitment` 仅作为后端过渡别名。
- T0703A 后，`current_order` 已进入共享 NPC 上下文，并由对话、每日计划、计划修订、战时公开对话、低血量自身心理判定、主动交涉、逃离判断、首次睡眠总结和知识图谱更新等 NPC 中心请求复用；不要在每种 Prompt 中用不同字段名重复表达。Mock 的调试原因会标记是否读取到当前指令，但仍只从 Schema 允许结果中输出。
- 每日计划：`DailyPlanRequest` / `DailyPlanResponse`。T1003 已接通 `/npc/plan_day` 与开发期 Mock 测试；T1403 已完成真实 Prompt 和真实 API 验收；T0022 将 Godot 正式应用改为真实 provider 专用、`source=llm_plan_day`、失败不降级。
- 对话 / 行动失败通用计划修改判别：`PlanRevisionJudgementRequest` / `PlanRevisionJudgementResponse`；按 `trigger_kind` 读取对话或权威失败事实，同时读取共享 NPC 人设 / 长短期记忆 / 指令上下文，只输出空或精确 `revision_hours`，不输出新计划。旧 `DialoguePlanRevisionJudgement*` 名仅作兼容。
- 计划异常修订：`PlanRevisionRequest` / `PlanRevisionResponse`
- 战时公开对话：T1201 已接入，仍使用 `NPCDialogueRequest` / `NPCDialogueResponse`，并携带 `interaction_context`、`battlefield_context` 和 `wartime_reaction`；T1404 已完成真实战时公开对话 smoke 验收。
- 低血量自身心理判定：`BattleJudgementRequest` / `BattleJudgementResponse`，用于战时所有 NPC HP 首次低于 30% 的自身判断；参战 NPC 可继续战斗、逃离或斗志激昂，避战 / 非战斗人员只能逃离或继续避战；T1404 已完成真实 Prompt、后端业务校验和真实 API 验收。
- 首次睡眠总结：`DailyReflectionRequest` / `DailyReflectionResponse`。T1004/T1005 已接通 `/npc/daily_reflection` 开发期 Mock 端点、Godot 调用、模板降级、长期日记写入和短期记忆清空；触发时机为每天首次睡眠满 1 游戏小时后，请求期间不可被对话或指令打断且会申请 TimeSystem 慢速。T1405 已接入真实 Prompt 和真实 API 验收；`knowledge_graph_updates` 是替换式当前知识键值，`diary_entry` 是增量第一人称日记。
- 知识图谱更新、主动交涉、玩家话术分类分别使用 `KnowledgeGraphUpdate*`、`ProactiveIntention*`、`PlayerStrategyClassification*`

## 事件与记忆输入原则

Prompt 不直接接收完整原始事件库，除非是首次睡眠总结或调试任务。常规对话、计划和判定应接收由 Godot / 后端服务裁剪后的摘要：

- `experienced_events`：NPC 亲历事件摘要。
- `witnessed_events`：NPC 见闻摘要。
- `location_context`：当前地点状态摘要。
- `battlefield_context`：战时局势摘要，只在集结 / 战斗 / 避战对话和低血量自身心理判定中注入。
- `plaza_context`：NPC 已接收到的广场见闻摘要，以及广场当前状态；不包含 NPC 未在场时已经广播过的历史事件。
- `current_order`：守备官对该 NPC 当前持续提出的指令；独立于事件摘要注入，避免短期记忆裁剪后丢失当前有效指令。

对话全文由对话事件 `payload` 保存；Prompt 可以读取摘要或最近若干轮，但不要要求另建谈话库。

进入地点时的完整状态快照只应作为进入者见闻的一部分出现一次。之后的建筑/地点状态见闻应以字段级变化摘要进入 Prompt，例如“围墙受损”“食堂升级中，现在不可进入”“病床1被莉娜占用”“训练场新增训练位3”。摘要只使用位置的玩家可读 `name`，不向 NPC 暴露 `bed_01` 等内部 ID，也不反复注入完整建筑状态或完整在场人员列表。
