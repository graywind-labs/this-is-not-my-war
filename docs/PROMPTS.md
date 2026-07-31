# PROMPTS.md

## T0116 `dialogue_intent_revalidation`

`data/prompts/dialogue_intent_revalidation_system_prompt.txt` 用于计划对话真正执行前的单独复核。输入明确标注旧意图制定日 / 时刻 / 来源，并提供计划同级当前上下文；输出只允许 `continue / modify / cancel_and_replan`。modify 不能换行动或目标，cancel 只触发 Godot 现有计划重估，模型不在本调用选择替代行动。

Prompt 明确 `completed_stages` 与从 1 开始的 `current_stage_index` 语义，并要求资源声称同时核对当前库存和阶段成本。如果“缺资源”是唯一谈话目的且当前材料已经足够，必须放弃而不能临时发明“汇报进度”等新目的。HTTP 业务校验拒绝 modify 空文本、原样文本或 continue / cancel 携带新文本，并允许同一真实 provider 纠错一次。

## T0113 对话最高优先级权威实况

`dialogue_system_prompt.txt` 在基础场景之前新增显眼的“最高优先级的权威实况”块。`activity_truth / equipment_truth / training_truth` 发生冲突时压过计划、计划 reason / summary、短期 / 长期记忆、地点叙述和角色推测。

Prompt 明确限制：

- 只有 `activity_truth.is_training=true` 才能说自己正在训练；`visit_location + false` 只能解释为拜访 / 停留。
- `equipment_truth.main_weapon / mount=null` 是确实空槽，不得补造武器或坐骑。
- `training_truth.eligible=false` 必须服从对应 blocker；计划写了训练、人在训练场或旧记忆提到教官都不能覆盖。

真实 DeepSeek 以原问题两份约 35k input token 的审计上下文复放：4 次适配器请求和 1 次完整 endpoint 请求都明确尚未训练且因无装备不能训练，均无 fallback。回复仍会错误声称艾达在场，证明本 Prompt 块只解决已显式投影的目标 NPC 自身事实，不应被描述成通用防幻觉方案。

## T0106 全量紧凑短期记忆 Prompt 合同

六份正式系统 Prompt 统一声明：目标 NPC 的短期记忆是熟睡总结轮转后仍在当前索引中的全部亲历 / 见闻，按发生顺序提供，不是“最近若干条”抽样。亲历权重高于见闻；当前库存、状态、地点和战场事实不能反向改写较早记忆中的原因。

每条模型可见记忆只包含 `type / summary / importance / day / time / details?`。`summary` 是程序确定性事实；`details` 只补原因、资源缺口、指令变化、计划段等摘要未充分表达的信息。Prompt 明确禁止臆测被省略的完整旧计划、地点 / 建筑快照、人员 / 敌我阵容或内部 ID。熟睡总结额外以 `memory_kind` 区分亲历 / 见闻，并把 `day_events` 设为唯一完整短期输入，不在 `npc` 下重复同一批记忆。

正式 `plan_revision_judgement` 与历史别名继续映射到 `plan_revision_judgement_system_prompt.txt`。旧 `dialogue_plan_revision_judgement_system_prompt.txt` 只保留兼容说明，避免未来误接回“轻量调用、不注入长短期记忆”的过期合同。

## T0103 NPC-NPC 防复述收尾

`dialogue_system_prompt.txt` 与 Godot 每场会话生成的 `soft_round_guidance` 使用同一规则：`soft_round_threshold` 不是最低 / 目标轮数，模型不得为了等到第 6 轮继续。是否续聊只看会话中已经存在的未决紧急 / 必要事项；只有能推进该事项的新事实、新决定或必要提议才算有效新内容。

原问题已回答、双方已达成一致、对方已收尾，或回复只能确认、复述 / 近义改写历史时，必须用至多一句角色化短收尾并设置 `should_end_dialogue=true`。模型不得为了制造“新内容”主动添加此前不存在的新话题、任务、问题、额外帮助或后续安排。无硬上限和必要事项可继续的设计不变。

真实 DeepSeek 最终覆盖四组已解决话题：截图中的艾达—格伦在正式第 1 轮结束，旧重复历史放到第 3 轮也结束，诊所与马厩场景同样当轮结束；四组与历史文本最高相似度 0.254～0.571，全部 `fallback_used=false`。

## T0101 守备官身份空白与三年背景

六类正式 Prompt 都接收同一四关系种子：守备官负责防务、三年前到站、来站前经历未知、开局前尽责且总体相处和睦。未知过去禁止被对话、计划理由、战时判断或反思补全；总体和睦不等于当前无条件信任、服从或不受真实冲突影响。

`dialogue_system_prompt.txt` 对两类追问使用专门分支：

- 姓名、出身、家庭、来历或来站前职业：没有后来真实自述时明确回答不知道，不按外表、职位或任期推测。
- 三年具体旧事或关系：最多三句，只表达三年前到站、尽责、和睦及没有可确认旧事，最后一句立即转到当前驿站或 NPC 自己的确知近况；禁止举例、引语、日常场景和具体共同经历。

`daily_reflection_system_prompt.txt` 明确“询问自己”不等于披露。守备官后来真正说出口的身份信息只能写成单独的“守备官自称……”主观认知，不能覆盖 `past_before_station=unknown_not_disclosed` 为全局客观过去。

## T0100 宗教信仰提示边界

六份正式 Prompt 现在都可读取根本人设中的精简宗教字段：对话使用 `npc_setting.religion`，其余五类使用 `npc.identity.religion`，当前 8 人统一为“天主教”。该字段是稳定背景，不是信任、服从、道德立场或宗教经历的替代品；只在问题、计划取舍、战时心理或反思经历确实相关时自然参考，不能覆盖各自个性、职业判断、记忆和程序事实。

真实 DeepSeek `deepseek-v4-flash` 已逐人回答宗教信仰与本职工作：8 人均表达天主教 / 信天主，同时仍分别给出马厩、食堂、菜园、铁匠铺、防线、小教堂、诊所与工械坊建议。正式验收 8 次均首次成功且 `fallback_used=false`。

## T0098 合并后的祈祷 / 弥撒提示

日计划、正式修订、范围判别和对话 Prompt 只把 `pray_at_chapel` 与 `lead_mass` 暴露为教堂行为。`attend_mass` 不再是 action、候选或模型输出值；提示只保留一条简明世界规则：NPC 选择祈祷后，如果弥撒已经开始或期间开始，程序会自动让其参礼，弥撒结束后继续独自祈祷。

祈祷内部模式切换不是行动失败，不需要计划范围判别或正式修订。原 `pray_failed_mass_* / attend_mass_failed_*` 双向替代强倾向已从两份修订 Prompt 中移除；守备官与 NPC 若明确谈妥“现在去参加弥撒”，计划层应选择当前小时的 `pray_at_chapel`，到达后的参礼模式由 ActionSystem 决定。

背景记忆和对话提示使用相同口径，不要求模型额外返回模式、主持者或地点。真实 DeepSeek `deepseek-v4-flash` 已完成一次日计划和一组对话承诺的范围判别 + 正式修订，均只选择 `pray_at_chapel`，3 次调用首次成功且 `fallback_used=false`。

## T0097 计划决策字段

`daily_plan_system_prompt.txt` 与 `plan_revision_system_prompt.txt` 不再提 action kind 输出，也不再为每种行为罗列“不得输出哪些无关字段”。每个计划项的正向最小语义是 `hour + action_id`，可附简短 `reason`；真正需要模型选择目标时，字段按目标类型区分：

- `visit_location -> location_id`
- `talk_to_npc / assist_heal -> target_npc_id`
- `assist_repair / assist_upgrade -> building_id`
- `talk_to_npc / seek_guard_officer -> dialogue_goal`

固定工作、吃饭、睡觉、祈祷、主持弥撒等行动无需模型重复地点或 kind。Prompt 只说明上述可用决策字段；Model Adapter 会按所选行为读取必要字段并忽略其余字段，所以模型偶发多输出地点、通用目标、优先级或任意额外内容不会导致固定行为失败。必要的地点 / NPC / 建筑选择仍必须来自同一条 `allowed_actions`，遗漏或自造会被后端拒绝。

动态 schema hint、非法 JSON 紧凑重试和 Mock 输出使用同一合同。T0098 移除独立参加弥撒候选后，`pray_at_chapel` 仍只需 `hour + action_id`；已移除行为会被业务校验拒绝，其他目标行为的字段编译合同不变。

## T0095 熟睡总结的窗口、内容与标题

`daily_reflection_system_prompt.txt` 现在把 `summary_window` 与 `reflection_period` 作为显式输入。前者规定 21:00 窗口、锚点和权威 `diary_label=接到守备命令的第N天`；后者规定从上一次成功请求快照终点到本次请求快照的精确回顾范围。`day_events` 只投影该水位内尚未总结的事件；窗口缺失不要求补造日记，下次可跨日回顾。

“接到守备命令”在 Prompt 中固定解释为守备官通过公告牌向驿站众人传达“我们奉命守住此地”的公开命令。模型不得把它理解为目标 NPC 当天入伍、刚到驿站或收到个人指令，也不得自行在正文添加第 N 天 / 第 N 夜标题。Godot 负责写入权威标签、触发时刻和记录范围。

## T0094 睡眠打断语境与弥撒当前小时（教堂部分已由 T0098 替代）

`dialogue_system_prompt.txt` 解释可选的 `interrupted_activity_context`：它是守备官第一条有效消息真正打断目标 NPC 后才出现的目标私有运行时事实，不是记忆事件。模型必须以 `activity_before_interruption` 识别打断前活动，以 `current_plan_activity / expected_activity_after_dialogue` 理解计划不变时的暂定恢复项；睡眠场景不得把“被叫醒谈话”说成自然睡醒并准备工作，也不得把暂定恢复说成已经执行。

`dialogue_plan_revision_judgement_system_prompt.txt` 对“守备官要求现在参加正在举行的弥撒，且目标 NPC 在本轮明确答应”的会话规定：只要当前小时原计划需要立即改变，就必须把 `game_time.hour` 纳入最小修订集合，不能把已经谈妥的当下承诺判为空。它仍只选小时，不选择行动；T0098 后第二层使用合并后的 `pray_at_chapel`。

T0098 后弥撒开始 / 结束只切换祈祷内部模式，不再构造教堂失败链；通用失败判别与正式修订继续处理其他真实行动失败。

## T0093 建筑工期与连续完成段

`daily_plan_system_prompt.txt`、`plan_revision_judgement_system_prompt.txt` 和 `plan_revision_system_prompt.txt` 各增加一条精简时间规则：必须用 `game_time` 对照 `current_building_states` 的总工期和剩余时间，只把协助、封闭影响或替代安排放在预计完工前，不能把短工期机械延伸到更晚阶段。

正式修订的 `action_completed` 分支同时读取 `failure_context.contiguous_revision_hours`：非空时表示当前小时起连续相同任务的原计划阶段都需要重新安排。精确返回请求中的全部 `revision_hours` 仍是硬合同；只有当前小时承担“不得原样重复已完成 action + target”和 `immediate_action` 一致性约束。

## T0092 最小供应商输出

六份正式 Prompt 和动态 schema hint 不再要求模型回显 `ok`、NPC / 日期、响应分支、固定“不适用”结果或可从主决定推导的布尔值。当前最小输出为：

- 对话：`reply_text / emotion` 加当前分支唯一决定及 `debug_reason`。
- 日计划：`plan / summary / debug_reason`；T0097 起计划项只表达行动决策和行为必需的专用目标字段。
- 范围判别：`revision_hours / summary / debug_reason`，`needs_revision` 由数组是否为空生成。
- 正式修订：`revised_plan / summary / debug_reason`，不返回 `immediate_action`。
- 战时心理：`decision / emotion / morale_delta_intent / debug_reason`，不返回 `should_start_escape`。
- 熟睡总结：`diary_entry / knowledge_graph_updates / debug_reason`，不回显 NPC / 日期；模型读取但不回显 `summary_window / reflection_period`。

输入仍保留能改变人物判断的全部事实，只删除纯传输 `meta`、同值副本、当前分支不可能使用的字段和空占位。默认日计划规则只有 Prompt 一份来源；调用方明确增加的临时规则仍进入请求。紧凑重试提示也使用同一最小合同，避免第一次输出失败后重新要求冗余字段。

## T0091 `talk_to_npc` 目标驱动输出

`daily_plan_system_prompt.txt` 与 `plan_revision_system_prompt.txt` 把固定地点行动和对话行动拆开：工位占用上下文可以说明占用者当下位于诊所，但模型不得把这一瞬时地点绑定进对话计划；运行时会重新查询目标。T0097 起模型用 `target_npc_id` 选择对象，内部 `target_id` 由程序编译。

供应商若仍多返回地点，后端会在计划项编译时直接丢弃，而不是把物理上正确的 `clinic` 当成非法选择。白名单外 NPC、自聊或空 `dialogue_goal` 仍不会被修复。

## T0089 弥撒与普通祈祷的失败替代倾向（已由 T0098 废止）

T0089 的双向失败提示曾用于两个独立行为。T0098 合并后这些 failure id 和独立候选均不存在，相关范围判别与强倾向已从正式 Prompt 删除。

当前模型只决定是否选择 `pray_at_chapel`；选定以后，独自祈祷与参礼之间的转换由程序确定性完成，不向模型发起重估。

T0098 的真实验收已改为“谈妥当前弥撒 -> 当前小时 `pray_at_chapel`”，不再制造祈祷失败。

## T0087 对话输出合同按类型拆分

`dialogue_system_prompt.txt` 与 Model Adapter 的动态 schema hint 现在根据 `dialogue_kind` 只列出当前分支字段：

- `player_npc -> PlayerNPCDialogueResponse`：`replyer_id / reply_text / response_kind=reply_to_player / recruitment_result / wartime_reaction` 及通用非权威元数据。
- `npc_npc -> NPCNPCDialogueResponse`：`replyer_id / reply_text / response_kind=reply_to_npc / invitation_result / should_end_dialogue` 及通用非权威元数据。
- `escape_intervention -> EscapeInterventionDialogueResponse`：`replyer_id / reply_text / response_kind=reply_to_player / escape_intervention_result=stay|leave` 及通用非权威元数据。

三个合同都禁止输出 `intent` 和其他分支字段。应征接受 / 拒绝只用 `recruitment_result`；NPC-NPC 续聊 / 收尾只用 `should_end_dialogue`；逃离挽留只用 `escape_intervention_result`。已从设计删除的 `request_money / request_equipment / request_rest / request_treatment / share_witness / start_escape` 不再出现在枚举、提示或 Mock。供应商若把 `emotion / suggested_event_type / debug_reason` 返回为 `null`，HTTP 层只对这些非权威元数据应用带 `model_normalizations` 记录的默认值；业务枚举仍严格拒绝非法值。

真实 DeepSeek `deepseek-v4-flash` 已用三类合同完成玩家、NPC-NPC、应征、战时和逃离分支，并另验 NPC-NPC 邀请接受 / 拒绝与正式收尾；最终验收均 `fallback_used=false`。

## T0086 已完成行动修订（范围由 T0093 扩展）

`plan_revision_system_prompt.txt` 现在识别 `failure_type=action_completed`：`failed_plan_item` 在此不是失败，而是已经成功完成；模型必须为当前小时剩余时间从普通实时 `allowed_actions` 中选择后续活动。`failure_context.requires_different_current_activity=true` 时，当前小时不得原样重复相同 `action_id + target_id`，但可选择其他目标的同类协助或任何符合人物、状态和现场条件的工作、休息、交谈等合法行为。

这条确定性完成链不调用 `plan_revision_judgement` Prompt，只调用一次正式 `revise_plan`；`revision_hours` 是当前小时起的连续同任务段，精确小时集合、当前小时 `immediate_action` 一致性、白名单、目标 / 地点和 provider 证明仍为硬合同。Godot 另外拒绝当前小时原样重复的完成项并在既有最多 3 次真实修订边界内重试，Prompt 不负责结算完成事实。真实 DeepSeek `deepseek-v4-flash` 已一次改写连续三小时升级协助，`fallback_used=false`。

## T0085 工作阶段是强建议，不是硬门槛

`daily_plan_system_prompt.txt` 继续强烈建议正常情况下至少安排 6 个工作阶段，以维持驿站基础产出，并明确 `assist_upgrade` 是劳动。但人格、健康、危机、逃离意向和现场条件可以支持更少工作；不能为了凑数安排不可执行行动。

`plan_revision_judgement_system_prompt.txt` 与 `plan_revision_system_prompt.txt` 继续接收当前 / 最低工作阶段统计，用来提醒模型尽量维持劳动。该统计不允许范围判别仅为补数量扩大 `revision_hours`，也不允许 backend 或 Godot 拒绝已经满足小时、白名单、目标 / 地点和即时行动合同的结果。升级已结束时，修订层读取本轮 `no_active_upgrade` 上下文，不应继续安排已经失效的 `assist_upgrade`。

## T0083 应征结果显式反馈（Prompt 不变）

本任务不修改对话 Prompt、输出 Schema 或模型判断规则。既有合法 `recruitment_result=accept|reject` 由 Godot 绑定到对应 NPC 回复并渲染颜色 / 符号；系统提示不是模型发言，不进入 `reply_text`，也不要求模型复述结果。

## T0082 应征会话 UI 生命周期（Prompt 不变）

本任务不修改对话 Prompt、输出 Schema 或模型判断规则。每次 `/npc/dialogue` 仍只根据该请求的 `is_recruitment_request` 判断本轮能否返回 `accept / reject`；toggle 是否保持、会话何时锁定取消、挂起超时和完成事件如何显示全文均由 Godot 客户端处理。关闭 toggle 后的新请求恢复 `is_recruitment_request=false`，但不会删除已经发生的会话历史。

## T0080 升级协助的室外与工作阶段语义

对话、日计划、计划修改判别和正式修订 Prompt 统一解释动态候选：`assist_upgrade.target_id` 表示被协助的工程，`location_id=plaza / execution_location=plaza / requires_building_entry=false` 表示实际在广场 / 建筑外搬料、递工具，不需要进入封闭建筑。只要候选同时为 `eligible / available_now`，模型不得用“门锁着、进不去”否认它。

日计划与正式修订把 `assist_upgrade` 视为一个工作阶段；判别层仍只选择受影响小时，不直接选择行动。同一 NPC 原工作建筑因升级在门口失败时，正式修订应优先认真考虑该建筑的合法协助候选，但不是程序强制选择：人设、守备官指令、饥饿疲劳和其他紧急事实仍可支持另一个合法结果。

六类 Prompt 继续遵守信息边界：程序建筑状态可以说明当前工程存在；路上 NPC 在抵达入口前没有由该状态自动生成的个人见闻或行动失败。LLM 不决定入口拒绝、工作量下限、升级速度或完成事实。

## T0078 主动找守备官的必选当前小时

`plan_revision_judgement_system_prompt.txt` 现在同时解释两种 required 当前小时来源：自主 NPC-NPC 对话的实际发起者，以及当前小时按 `seek_guard_officer` 主动找守备官并完成会话的 NPC。两者都表示原对话行动已经完成，范围判别必须覆盖当下后续活动；下一层仍从正常动态 `allowed_actions` 选择。

required 集合是程序事实。若真实模型输出遗漏，后端会保留其其他合法 `revision_hours`、权威并入 required 小时，并在 `model_normalizations` 记录 `required_revision_hours_authoritative_union`；这不生成行动内容，也不使用 Mock 伪装模型输出。正式修订仍必须由真实 provider 输出精确选中阶段和当前小时 `immediate_action`。

## T0076 自主对话发起者的必选当前小时

`plan_revision_judgement_system_prompt.txt` 新增 `required_revision_hours` 硬合同。它不是行动建议，而是程序给范围判别器的最小必选集合：输出必须包含全部 required 小时，仍可加入确实受对话 / 失败影响的未来小时；required 非空时不能返回 `needs_revision=false`。自主 NPC-NPC 对话只为实际发起者设置结束时当前小时，受邀者保持普通独立判别。

该 Prompt 明确原因是发起者的“找人对话”阶段已经完成，下一层必须为当前阶段安排后续活动。下一层 `plan_revision_system_prompt.txt` 仍只从实时 `allowed_actions` 选择工作、生活、拜访、其他可用 NPC 对话或其他合法行为，且 `immediate_action` 必须与当前小时修订项完全一致。T0078 起，真实输出若遗漏 required 小时，由 endpoint 将程序权威范围并入并显式记录 normalization；行动内容仍不由本地硬拼，也不以 Mock 伪装成功。

## T0071 对话 Prompt 私有信息边界

对话 Prompt 现在把输入分成两侧：

- 回复者：完整使用自己的 `npc_setting / npc_state / short_memory / long_memory / location_context / current_order`。
- 说话者：只使用 `speaker_name / speaker_text / speaker_context.appearance / health_status`；`speaker_npc` 必须为空或缺失，`speaker_context.state` 必须为空。

模型不得把说话者未说出口的记忆、见闻、日记、图谱、指令、个人资源或地点私有状态当成回复者知识。`talk_to_npc` 候选不再提供目标实时地点、行动或入伍状态；其他 `allowed_actions` 的目标、地点与当前可用性只用于程序行为边界。若同一事实没有出现在回复者自己的信息空间、共享驿站常识或已发生对话中，回复文本不能主动声称知道。

## T0070 全员名册标签解释

六份正式 Prompt 都明确说明 `station_context.resident_roster` 是全体登记成员而非仅当前在站人员；每行的 `recruited` 表示是否已经入伍，`in_station` 表示是否仍在驿站。模型不得把 `false` 解释成相反状态，也不得因为离站成员仍出现在名单里就宣称其人在站内。名单、标签和长期知识均来自动态 payload，本轮没有在 Prompt 中硬编码 8 人姓名。

艾达的教官独练规则及其他职业规则通过长期知识图谱进入六类上下文，不额外复制成全局 Prompt 条款，避免让所有 NPC 无差别获得专业细节。

## T0069 完整 Prompt 审计边界

正式 provider 每次尝试实际发送的 system / user messages 现在保存在后端 JSONL 的 `provider_request_sent.provider_request_body` 中；紧凑重试会使用同一 `audit_id`、不同 `attempt_count` 单独记录，因此可以看到重试追加提示后的真实 Prompt。`call_started.input_payload` 同时保留序列化前动态业务上下文，便于区分 Prompt 模板、Schema hint 与 Godot 请求事实。

日志不改变任何 Prompt，不向模型追加审计指令，也不保存 Authorization 请求头。若设置 `LLM_AUDIT_LOG_INCLUDE_PAYLOADS=false`，完整 Prompt / payload / response 会被省略，只保留调用元数据和 usage；涉及 Prompt 效果验收时必须保持该项为 true 并妥善保护日志文件。

## T0067 真实分支偏置与待确认修改建议

本轮没有修改任何正式 Prompt，只记录真实 provider 证据。受限为单一允许结果时，战斗的继续参战、避战、逃离和激昂，以及战时对话的 `none / escape / morale_boost`、避战应征接受 / 拒绝、逃离挽留 stay / leave 都能正确返回；真实 Main 的安全、互相掩护场景也自然触发了战时 `morale_boost`。但低血量完整候选下，参战 NPC 在多组场景中持续优先选择首项 `continue_fighting`，极端战时逃离对话也保持 `none`。当前战斗请求约 1.6 万至 2.0 万输入 tokens，角色完整档案、长期记忆、战场信息和守备官指令可能稀释临界决策事实；低温度和结果列表顺序也可能强化首项偏置。

当时日计划 Prompt 同时硬性要求完整 24 小时计划和至少 6 个工作阶段，并反复强调正常工作；`escaping_station` 是终止在站生活的特殊意向，却没有说明选择后余下小时应如何解释。T0085 已把工作数量改成强建议而非程序硬门槛，但逃离终止意向与 24 小时排程的结构冲突仍需单独设计。

建议在用户确认后分步试验，而不是直接改动：

1. 在长上下文前增加程序生成的紧凑 `decision_facts`，只汇总 HP 比例、敌我人数、昏迷友军、关键建筑受损和当前命令是否触碰已知底线；这些必须来自权威状态，不由 Python 猜测人格结论。
2. 为参战三结果与避战两结果提供对称判据和各一条简短正反例，避免只列枚举；单独评估战斗判定温度和选项顺序，但不能简单随机打乱，因为规则 fallback 当前使用首个安全允许项。
3. 将“是否离站”的终止决定与 24 小时工作排程拆开，或明确选中 `escaping_station` 时怎样表达后续在站小时；同时给日计划提供紧凑的站内危机摘要。
4. 保留“承诺必须与权威状态一致”的挽留原则。真实测试显示程序实际撤回危险命令比只在对话中口头承诺更稳定，不建议通过 Prompt 强迫 NPC 相信未兑现承诺。

## T0063 个人酒与饮酒上下文规则

六份正式 NPC Prompt 的共享 `station_context.work_mode_actions` 现在携带 `description`；`drink_wine` 因此与其他可计划行为一样进入 NPC 背景行为目录，不在 Prompt 里维护第二份静态行为表。计划、修订和对话仍只能使用动态 `allowed_actions`，其中饮酒只在目标 NPC 当前确实持有酒时出现。

`npc.state.money / wine`（对话中为 `npc_state.money / wine`）是目标 NPC 本人的权威持有量，不是驿站五项公开资源。计划和修订选择 `drink_wine` 时，每个阶段都会在执行开始由程序实际扣除 1 份个人酒；初始日计划的饮酒阶段数不得超过当前个人酒。无酒失败 `drink_wine_failed_no_wine` 归入资源不足判别，不得在没有新酒的前提下重复安排。

`wine_consumed` 表达“心情改善、过去伤痛暂时淡化”的叙事语境。对话、战时心理和首次睡眠反思可以让这种当下感受影响措辞和判断，但不得新增情绪数值、程序 buff，亦不得删除、否认或覆盖旧日记、知识图谱和历史事件。

## T0061 宽松人物声音与开局认知规则

六份正式 Prompt 不再读取或提及 `signature_lines` / 代表性表达。对话顶层 `npc_setting` 与共享 `NPCIdentity` 的语言倾向只携带宽松 `speech_style`；T0100 后身份另含精简 `religion`。模型应综合职业经验、性格、欲望、恐惧、底线、长期记忆和当前事实生成自然表达，不能把任何旧句子当作台词模板。

“往昔·来站前”应理解为角色宏观身世、来站原因与到站时间；“往昔·初到驿站”应理解为角色接手的工作、最初遇见的人以及八人互相补全的到站历史；“往昔·近日”仍是开局前微观生活。固定到站顺序为艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜。模型可以用这些历史保持人物连续性，但不能把它们当成本日刚发生的事实。

T0061 当时守备官初始知识只提供职责，不提供预设关系评价；T0101 已在不预设个人身份的前提下增加三年前到站、过去未知与低细节尽责和睦背景。模型不得从未知过去编造身份，也不得把总体和睦推成具体旧事或无条件信任。建筑 `value_label` 是世界内叙事化常识，技术 `value` 才是稳定语义键；两者都不能覆盖本次请求的实时建筑、资源、工位与行动候选。该内容调整不新增 Prompt 类型、`call_type`、请求次数或输出字段。

## T0060 直白文风与时间前缀

六份正式 Prompt 统一要求自然、直白、符合母语习惯的中文；人物声音通过句式、用词、关注重点和判断习惯区分，不用晦涩比喻、过度拟人或谜语式表达制造个性。轻微黑色幽默只有在意思一读即懂时使用。

六份 Prompt 都解释日记时间前缀：“往昔·来站前 / 往昔·初到驿站 / 往昔·近日”属于开局前历史，新熟睡总结使用“接到守备命令的第N天 HH:MM:SS”，旧运行态记录继续兼容“第N天 HH:MM:SS”；其中“往昔·近日”明确发生在守备官收到并向众人传达敌情之前。“接到守备命令”专指公告牌向众人公开传达“我们奉命守住此地”，不是 NPC 入伍、刚到驿站或收到个人指令。模型不得从前缀补造人物已知敌袭、征召或既往关系。熟睡总结的 `diary_entry` 仍只输出第一人称正文，不自行添加日期或时间前缀；权威前缀由 Godot 保存并在后续上下文投影时统一生成。

## T0059 初始长期记忆提示规则

六份正式 Prompt 都必须区分“开局前长期记忆”和“本日已发生事实”：

- 对话：用日记延续第一人称口吻，用图谱维持人物 / 建筑认知；实时状态与本轮事实优先。T0101 后守备官种子包含职责、三年前到站、过去未知与开局前尽责和睦的低细节背景；具体身份和开局后人物看法仍只能随真实自述与互动发展。
- 每日计划：过去经验可以影响取舍，但不能被写成今天已经发生的事件，也不能绕过 `allowed_actions`、建筑、资源或状态。
- 计划修改判别：初始记忆只解释某项变化为何重要，不得把旧日记或旧建筑认识伪造成新的 failure，也不得据此预判守备官关系。
- 正式修订：可用既有经历选择合法替代方案；实时候选和权威失败事实优先，守备官职责知识不能直接推出服从、信任或敌意。
- 战时心理：可引用职业创伤、经验与既有关系观察解释意向，但不得补造守备官过去的承诺、伤害或信任，也不得把旧建筑常识当当前战况。
- 首次睡眠反思：种子日记 / 图谱不是当天 `day_events`；只有真实新事实改变认知时才更新对应键，不无意义覆盖初始历史。

六类调用都继续禁止长期记忆改写资源、HP、建筑、装备、移动、入伍、战斗或行动结算。世界内文本统一使用“守备官”，不使用“玩家”。

## T0058 基础资源与建筑升级提示规则

六份正式 Prompt 都必须读取 `station_context.basic_resource_reserves`，把它解释为本次调用时公开的粮食、餐食、木材、石料和铁数量。不得补造第纳尔、酒、装备、器械、马匹或其他未公开库存，也不得直接改变数量。计划 / 判别 / 修订中的 `current_resource_states` 使用同一五项白名单。

`station_rules` 第六条说明建筑升级缓慢推进、成员可协助加快。对话只能在 `allowed_actions` 有目标明确的 `assist_upgrade` 时说当前能协助；该候选在 T0080 后明确为广场 / 室外执行、不需进入目标建筑，并计为工作阶段。日计划与正式修订应认真考虑该候选，尤其避免无故用 `idle` 替代，但仍结合人设和紧急事项决定。判别只选小时，战时心理只选 `allowed_decisions`，反思不能把规则写成已经协助或已经升级完成的事实。

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

对话中的普通寒暄、重复信息或仅短暂打断，以及不再影响原计划的一次性失败，都可返回 `needs_revision=false, revision_hours=[]`。新承诺、新任务、明确时间协调、持续工位 / 目标 / 资源阻塞等才选择受影响小时。工作阶段数量可作为范围选择的次要参考，但第一层不得仅为凑足数量扩展到未受影响的未来阶段。判别非空后，`plan_revision_system_prompt.txt` 继续使用完整修订上下文，且 `revised_plan` 小时必须与请求 `revision_hours` 完全一致。

## T0046 动态驿站上下文与反思输出

所有包含 NPC 根本人设的请求都必须在顶层携带一份 `station_context`；Schema 拒绝缺失字段或空人员 / 建筑 / 行为 / 基础资源 / 规则列表。T0046 最初只定义地点简介与当前在站人员，T0054 扩充世界目录，T0058 再形成六字段常识块，T0070 把人员解释更新为带双标签的全体登记名册；背景可能性不得扩写为当前已发生事实。

`daily_reflection` 只输出第一人称 `diary_entry` 与 `knowledge_graph_updates`，不输出 `memory_summary`。每条知识更新除稳定 `subject / relation / value` 外，还必须输出供中文玩家阅读的 `subject_label / relation_label / value_label`；即使技术值为英文，中文值文本也不得缺失。

## T0043A 服务依赖与教堂行动提示（教堂部分已由 T0098 更新）

每日计划、计划修订和对话 Prompt 都读取候选 `context.required_active_action_id` / `context.blocked_by_active_action_id`。模型必须把病床治疗、接受训练视为需要实时服务者的行动；`available_now=false` 时不得把它选为立即行动，未来时段也只能在确有可协调服务计划时安排。服务者离岗后的失败不能原样重复撞同一依赖。

三份 Prompt 只区分“祈祷”与“主持弥撒”：祈祷不需要神父，主持开始时自动参礼，结束时继续独自祈祷。Prompt 不要求模型选择内部模式；是否在岗、模式切换、位置占用和行动完成均由程序决定。

非神职计划仍不会选择 `eligible=false` 的主持弥撒；合并后的祈祷始终不依赖主持者可用性。

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

`daily_plan_system_prompt.txt` 和 `plan_revision_system_prompt.txt` 要求每项先选择 `action_id`，再仅为真正需要目标的行为复用同一条候选的 `location_id / target_npc_id / building_id`。内部 action kind、目标和固定地点由后端编译。NPC 可以安排找其他 NPC 对话、祈祷、前往地点、主动找守备官交涉或表达逃离意向；`idle` 只表示留在原地，不能替代前往广场。工位占用失败且 `failure_context.blocked_by_npcs` 指明占用者时，若目录存在对应 `talk_to_npc` 候选，修订 Prompt 明确优先考虑当面协调，不用固定“原地等待”模板压制涌现行为。

计划修订同时携带当前工作阶段数、通常建议 6 阶段和“非工作替换是否建议补回工作时段”。T0049 后 `revision_scope` 固定为 `selected_hours`：模型只能返回请求中升序去重的 `revision_hours`。T0085 起，工作数量只用于强规划建议；后端仍拒绝小时集合不精确、越界、白名单 / 目标组合或即时行动不一致，但不因合并后工作阶段较少拒绝合法结果。

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
- T1401A 后，通用 schema guard 会明确列出关键枚举允许值，并要求不确定时使用默认安全值；T0087 起对话分支 guard 还精确列出当前类型字段，避免真实 provider 自造 `response_kind`、`wartime_reaction` 或跨分支结果。该 guard 只保证基础 Schema 可验收，不替代具体业务 Prompt。
- T1402/T0029/T0030 后，NPC 对话 Prompt 已落到 `data/prompts/dialogue_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=dialogue` 时读取；模板覆盖日常对话、NPC-NPC 邀请接受 / 拒绝、无硬上限正式对话、逐轮主动结束与第 6 轮起软性收尾、提出应征、集结 / 战斗公开对话、避战公开对话和逃离挽留，并已完成真实 DeepSeek `/npc/dialogue` 验收。T0100 后模板读取精简 `religion` 与宽松 `speech_style`，并结合人物其他字段、长期记忆和当前处境避免不同 NPC 生成可互换的通用士兵台词。
- T1403/T0022/T0085 后，每日计划 Prompt 已落到 `data/prompts/daily_plan_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=plan_day` 时读取；该模板要求输出 0-23 点共 24 阶段、只使用 `allowed_actions` 或 `idle`，并把通常至少 6 个工作阶段作为强建议而非程序硬门槛。`current_order` 仍只是守备官当前指令参考，不能绕过行动白名单、资源、HP、地点、建筑、工位或程序强制层。后端校验 hour 唯一覆盖与行动白名单，不按工作数量拒绝；Godot 正式路径只重试真实请求。
- 2026-07-16 起，计划修订 Prompt 独立放在 `data/prompts/plan_revision_system_prompt.txt`，由 `ModelAdapter` 在 `call_type=revise_plan` 时读取。T0049 后请求只使用 `selected_hours`，`revised_plan` 必须按升序恰好返回 `revision_hours`；当前小时入选时 `immediate_action` 必须与该项一致，未入选时必须为 `null`。T0085 起后端继续校验 NPC id、精确小时集合、行动白名单和即时行动条件，但不再把合并后工作阶段下限当成硬合同。T0086 起 `action_completed` 要求为已完成的当前项选择不同后续活动。Godot 正式修订只接受真实 provider，失败只重试真实请求，不使用 Mock / 规则修订。
- T0073 未修改计划 Prompt，而是补齐实际效果验收：发布“当前小时优先前往小教堂”的 `current_order` 后，真实 DeepSeek `deepseek-v4-flash` 的 `revise_plan` 返回 `visit_location(chapel)` 并通过 Godot 合并，证明现有 Prompt 会参考指令；该结果不改变“软性参考而非强制行动”的约束。
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

- `npc_id`、`npc_name`、`npc_setting`：目标 NPC 的人设核心，包括职业背景、宗教信仰、外表、背景故事、性格、欲望、恐惧、底线、宽松的 `speech_style` 和能力。T0042 后 Godot 由 `NPCPromptProfile.gd` 统一构造该字典，NPC 面板“背景”弹窗只读展示同一字典，不另写 UI 背景文本；T0061 后不再包含代表性表达，T0100 后显式包含精简 `religion`。
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
- `long_memory`：长期记忆，包括知识图谱和日记。T0059 后它是对话目标的规范长期记忆字段；`target_npc` 只保留共享参与者结构，不重复该图谱 / 日记。T0071 后正式 payload 不再发送 `speaker_npc`，避免说话者的任何私有上下文进入回复者请求。
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
- 若 `dialogue_kind == "escape_intervention"`，Prompt 必须明确目标 NPC 正在逃离驿站，本轮是守备官在其离图前的挽留 / 威胁 / 承诺。请求会携带 `escape_intervention_round`（1 到 5）、`escape_intent`、当前轮次、短期记忆、长期记忆、地点上下文和 `current_order`。模型只能在 `escape_intervention_result` 中输出 `stay` 或 `leave`，不能输出其他分支，也不能直接改变移动、HP、资源或建筑结果。逃离挽留对话中的攻击按钮不发送到模型。

## 对话 Prompt 输出

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "守备官，我可以听你说完，但别把锅里的粮食也算成士兵。",
  "response_kind": "reply_to_player",
  "emotion": "wary",
  "recruitment_result": "none",
  "wartime_reaction": "none",
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "参考 PlayerNPCDialogueResponse"
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
  "emotion": "wary",
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
  "emotion": "tired",
  "should_end_dialogue": true,
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "本轮已说清，主动结束"
}
```

## 每日计划 Prompt 输出

每日计划和计划修订 Prompt 输入必须包含 `current_order`。模型应说明计划如何考虑该指令，但只能从行动白名单中选择合法行动；指令与生存需求、资源、地点或程序强制规则冲突时，可以调整、推迟或拒绝执行。

T1003 当前 `/npc/plan_day` 开发期 Mock 输入对应 `DailyPlanRequest`，至少包含：

- `npc`：共享 NPC 上下文，内含人设、状态、熟练度、装备、当前地点、`current_order`、短期事件库 / 见闻库摘要、知识图谱、日记和地点上下文。
- `allowed_actions`：行动白名单；模型按 T0097 选择 `action_id` 及行为必需的地点 / NPC / 建筑字段，内部 kind、目标和固定地点由候选编译。
- `current_resource_states`：当前资源快照。
- `current_building_states`：当前建筑等级、HP 和修复 / 升级状态快照。
- `planning_rules`：结构化计划要求，例如 24 阶段硬合同、通常至少 6 个工作阶段的强建议、不得越权结算。

开发期 Mock 会按 NPC 熟练度选择可执行工作行动；T1403/T0025/T0085 后真实 provider 路径读取 `data/prompts/daily_plan_system_prompt.txt`，要求计划覆盖 24 小时、只使用精确行动候选，并强烈建议通常至少 6 个工作阶段。后端校验 24 个 hour 覆盖和按行为必需的目标选择，再校验编译后的完整候选；工作数量不是合同。Godot 仍二次校验硬约束，正式开局 / 新一天不合法时保留真实失败并保持暂停，不生成规则或 Mock 计划。

provider 单项示例：

```json
{"hour":14,"action_id":"assist_upgrade","building_id":"workshop","reason":"协助升级"}
```

后端编译并返回 Godot 的稳定响应仍使用完整 `PlanItem`：

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

`/npc/revise_plan` 输入包含当前 24 小时计划、当前失败项、`failure_type`、`failure_summary`、NPC 共享上下文、`current_order`、`allowed_actions`、固定的 `revision_scope=selected_hours` 与非空 `revision_hours`。provider 的 `revised_plan` 必须按升序恰好覆盖 `revision_hours`，不得缺失、增加、重复、乱序或修改未选中小时。
- `immediate_action` 不由模型返回；后端在 `revision_hours` 包含 `game_time.hour` 时从编译后的当前小时项生成，否则为 `null`。
- 修订项使用 T0097 的最小决策字段；`talk_to_npc` 必须提供非空 `dialogue_goal` 且不能以自己为目标。
- 每条 `reason` 不超过 12 个汉字，避免修订响应再次因冗长被截断。
- 响应合并回未选中的原计划后，应认真权衡并尽量维持基础工作量；工作阶段数量不是硬门槛。
- 模型只提出计划，不结算资源、HP、建筑、移动、伤害、治疗、训练或工作产出。

provider 示例：

```json
{
  "revised_plan": [
    {"hour":8,"action_id":"idle","reason":"铁料不足"}
  ],
  "summary":"当前工作缺少资源，暂时调整本小时行动。",
  "debug_reason":"仅修改指定阶段。"
}
```

后端编译后的稳定响应示例：

```json
{
  "ok": true,
  "npc_id": "blacksmith_01",
  "revised_plan": [
    {
      "hour": 8,
      "action_kind": "idle",
      "action_id": "idle",
      "location_id": null,
      "target_id": null,
      "priority": 50,
      "reason": "铁料不足，先等待"
    }
  ],
  "immediate_action": {
    "hour": 8,
    "action_kind": "idle",
    "action_id": "idle",
    "location_id": null,
    "target_id": null,
    "priority": 50,
    "reason": "铁料不足，先等待"
  },
  "summary": "当前工作缺少资源，暂时调整本小时行动。",
  "debug_reason": "只修订失败时段。"
}
```

## 战时对话 Prompt 输出

集结 / 战斗模式下，守备官对已入伍且有主武器 NPC 的主动对话输出使用 `PlayerNPCDialogueResponse`，并带上战时心理意向。`morale_boost` 和 `escape` 只是意向；斗志 buff、逃离移动、事件入库和数值变化由 Godot 程序校验后执行。

```json
{
  "ok": true,
  "replyer_id": "veteran_deputy_01",
  "reply_text": "守备官，说得够明白了。我会把他们拦在门外。",
  "response_kind": "reply_to_player",
  "emotion": "resolved",
  "recruitment_result": "none",
  "wartime_reaction": "morale_boost",
  "suggested_event_type": "dialogue_turn",
  "debug_reason": "集结模式公开对话，参考 battlefield_context 与 current_order"
}
```

避战模式下，非战斗人员仍使用 `recruitment_result` 表达是否接受应征。若返回 `accept` 但仍无主武器，Godot 保持其 `avoid_combat`；若无敌军，则回到工作模式并成为已入伍 NPC；只有已入伍且获得主武器、场上仍有敌军时，Godot 才将其切入战斗模式。

## 逃离挽留 Prompt 输出

逃离挽留使用 `EscapeInterventionDialogueResponse`；`dialogue_kind` 与 `interaction_context` 必须同时为 `escape_intervention`，`escape_intervention_round` 必须在 1 到 5 之间。模型必须输出：

- `escape_intervention_result = "stay"`：NPC 被守备官本轮话术挽留下来。Godot 会停止逃离、切回工作模式、触发计划重评估并写入同名事件。
- `escape_intervention_result = "leave"`：NPC 继续逃离。Godot 会记录已用轮次，未满 5 轮时允许玩家再次挽留，满 5 轮后拒绝第 6 轮。

给钱和攻击不是模型结算：给钱已经由 Godot 扣资源并降低逃离移动倍率；逃离挽留中的攻击已经由 Godot 扣 HP、提高逃离移动倍率、计入 1 轮并关闭对话面板，不会请求模型回复。若攻击导致昏迷，复苏后程序会继续逃离。

```json
{
  "ok": true,
  "replyer_id": "cook_01",
  "reply_text": "守备官，我留下。但你得记住你答应过什么。",
  "response_kind": "reply_to_player",
  "escape_intervention_result": "stay",
  "emotion": "shaken",
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

- 对话请求统一使用 `NPCDialogueRequest`；响应按 `dialogue_kind` 使用 `PlayerNPCDialogueResponse / NPCNPCDialogueResponse / EscapeInterventionDialogueResponse`。输入以 `npc_id`、`speaker_text`、`speaker_context`、`is_recruitment_request`、`dialogue_state`、`short_memory`、`long_memory` 和 `location_context` 为准；旧式 `guard_officer_input` / `propose_recruitment` 仅作为后端过渡别名。
- T0703A 后，`current_order` 已进入共享 NPC 上下文，并由对话、每日计划、计划修订、战时公开对话、低血量自身心理判定、主动交涉、逃离判断、首次睡眠总结和知识图谱更新等 NPC 中心请求复用；不要在每种 Prompt 中用不同字段名重复表达。Mock 的调试原因会标记是否读取到当前指令，但仍只从 Schema 允许结果中输出。
- 每日计划：`DailyPlanRequest` / `DailyPlanResponse`。T1003 已接通 `/npc/plan_day` 与开发期 Mock 测试；T1403 已完成真实 Prompt 和真实 API 验收；T0022 将 Godot 正式应用改为真实 provider 专用、`source=llm_plan_day`、失败不降级。
- 对话 / 行动失败通用计划修改判别：`PlanRevisionJudgementRequest` / `PlanRevisionJudgementResponse`；按 `trigger_kind` 读取对话或权威失败事实，同时读取共享 NPC 人设 / 长短期记忆 / 指令上下文，只输出空或精确 `revision_hours`，不输出新计划。旧 `DialoguePlanRevisionJudgement*` 名仅作兼容。
- 计划异常修订：`PlanRevisionRequest` / `PlanRevisionResponse`
- 战时公开对话使用 `NPCDialogueRequest / PlayerNPCDialogueResponse`，并携带 `interaction_context`、`battlefield_context` 和 `wartime_reaction`；T1404 已完成真实战时公开对话 smoke 验收。
- 低血量自身心理判定：`BattleJudgementRequest` / `BattleJudgementResponse`，用于战时所有 NPC HP 首次低于 30% 的自身判断；参战 NPC 可继续战斗、逃离或斗志激昂，避战 / 非战斗人员只能逃离或继续避战；T1404 已完成真实 Prompt、后端业务校验和真实 API 验收。
- 熟睡总结：`DailyReflectionRequest` / `DailyReflectionResponse`。T1004/T1005 已接通 `/npc/daily_reflection` 开发期 Mock 端点、Godot 调用、模板降级、长期日记写入和短期记忆清空；T0094 后触发时机为当前 21:00 锚定窗口累计睡眠满 1 游戏小时，请求期间不可被对话或指令打断且会申请 TimeSystem 慢速。T1405 已接入真实 Prompt 和真实 API 验收；`knowledge_graph_updates` 是替换式当前知识键值，`diary_entry` 是增量第一人称日记。
- 知识图谱更新、主动交涉、玩家话术分类分别使用 `KnowledgeGraphUpdate*`、`ProactiveIntention*`、`PlayerStrategyClassification*`

## 事件与记忆输入原则

Prompt 不接收 MemorySystem 的原始事件对象，但六类正式 NPC 调用都接收当前短期索引中全部事件 / 见闻的程序化紧凑投影：

- `experienced_events`：NPC 当前索引中的全部亲历，按发生顺序排列。
- `witnessed_events`：NPC 当前索引中的全部见闻，按接收顺序排列。
- 单条记录：`type / summary / importance / day / time / details?`；不含原始 `event_id / payload`。
- `location_context`：当前地点状态摘要。
- `battlefield_context`：战时局势摘要，只在集结 / 战斗 / 避战对话和低血量自身心理判定中注入。
- `plaza_context`：NPC 已接收到的广场见闻摘要，以及广场当前状态；不包含 NPC 未在场时已经广播过的历史事件。
- `current_order`：守备官对该 NPC 当前持续提出的指令；独立于事件投影注入，表示当前有效版本，历史变化仍可从短期记忆读取。

对话全文仍由权威事件 `payload` 保存；MemorySystem 的确定性 `summary` 已按顺序展开已完成会话，因此 LLM 投影只传 summary，不重复传 `dialogue_text / speaker_text / reply_text`，也不另建谈话库。

进入地点时的完整状态快照仍只作为权威见闻出现一次，但模型只读取其确定性 summary；原始 `location_snapshot / building_snapshot` 不进入 Prompt。之后的建筑 / 地点变化继续以字段级摘要进入，例如“围墙受损”“食堂升级中，现在不可进入”“病床1被莉娜占用”“训练场新增训练位3”。摘要只使用位置的玩家可读名称，不向 NPC 暴露内部 ID。
