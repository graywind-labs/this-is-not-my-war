# AI_NPC_SYSTEM.md

## T0061 人物表达、历史切片与认知展示合同

`data/npc_profiles.json` 不再保存 `signature_lines` / “代表性表达”。`scripts/core/NPCPromptProfile.gd`、对话顶层 `npc_setting`、共享 `NPCIdentity` 和六类正式 LLM 上下文只保留宽松的 `speech_style` 作为语言倾向；模型必须结合性格、职业、长期记忆和当下事实自然组织语言，不能依赖固定台词池。T1501 / T0060 中关于台词样例注入的旧口径由本节取代。

三篇开局日记继续使用既有 8 字段结构，但前两篇承担不同层级的叙事职责：“往昔·来站前”宏观勾勒身世、职业来路、离开原处的原因和到站时间；“往昔·初到驿站”记录接手的工作与遇见的人。八人的到站顺序固定为艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜，各人的第二篇从不同角度互相咬合，拼成驿站逐渐恢复运转的群像。“往昔·近日”保留 T0060 已确认的开局前微观生活片段。

每名 NPC 对守备官只有一条技术键为 `role` 的开局职责认知：守备官负责统筹驿站防务、警戒和危急时的人手安排。不得在种子中加入“尚待观察”“是否值得信任”等预设评价，也不得伪造既往互动。15 座建筑知识继续覆盖真实规则，但玩家可见 `relation_label / value_label` 必须写成人物在驿站生活中会形成的常识，不使用“初始、升级后、槽位、效率、结算”等说明书腔。本轮机械审校已从仓库条目移除尚未实现的容量 / 受击丢货 / 减少掠夺语义，改为集中登记与正门失守后的实际受袭次序；其余技术 `value` 不变。`confidence / day / time` 元数据全部保留。`NPCPanel` 的【知识】弹窗只显示中文主体、关系和值，不显示可信度与更新时间；NPCSystem、反思更新、后端参数和 GM 原始调试仍保留这些字段。

## T0060 八名 NPC 文案与开局认知合同

8 名 NPC 的根本人设、三篇初始日记和中文知识图谱已统一改为专业、直白、自然的中文。人物差异不再依赖晦涩比喻或刻意拟人，而由句式、用词、关注重点和判断习惯体现：托马朴实谨慎，布鲁诺口语化且爱抱怨，伊沃安静务实，格伦简短严厉，艾达条理分明，马塞尔温和完整，莉娜临床精确，欧文讲原因与解决办法。清楚易懂的轻微黑色幽默可以保留，但不得妨碍事实理解。

“往昔·近日”严格发生在守备官收到并向众人传达敌情之前，只能记录普通驿站生活，不得暗示人物已经知道敌袭、征召或备战安排。T0061 后，守备官种子认知进一步收敛为唯一职责事实，不附加开放判断句。每人的图谱继续覆盖全部 15 座正式建筑：本职建筑记录更具体的用途和关键规则，其他建筑保持粗略但准确的世界内认识；这些认识仍不替代运行时权威状态与结算。

## T0059 开局人物历史与长期认知

8 名初始 NPC 的根本人设与具体人生历史现已分层：`npc_profiles.json.background_story` 只保存不随玩家互动改变的职业视角、价值尺度和根本矛盾；`npc_initial_long_memory.json` 保存每人来站前、初到驿站、近日三个第一人称生命切片，以及其对人物、建筑和个人往事的当前认知。这样同一职业信息不再在系统人设、日记和知识图谱三处反复讲述。

每人初始知识图谱覆盖其余 7 人、守备官、15 座正式建筑和至少 2 个个人故事主体。本职建筑有多条具体规则，其他建筑保持世界内口吻的粗略但正确认识；T0061 后守备官条目只记录其防务、警戒与危急人手统筹职责，不预写人物评价。

NPCSystem 在生成实体前同时校验档案和初始记忆，缺失、未知 id、空日记、非 `key_value_replace_v1` 图谱或空关系都会让初始化明确失败。加载后六类正式 LLM 业务均读取这份运行态长期记忆：对话使用唯一顶层 `long_memory`，计划 / 判别 / 修订 / 战时心理 / 反思使用 `npc.long_term_memory`。对话 participant 只公开参与当前会话所需的身份、状态和短期上下文，不复制目标记忆，也不向另一 NPC 泄露私人日记 / 图谱。

长期记忆是人格连续性和判断材料，不是程序权威。若初始建筑认知或过去印象与当前建筑、资源、行动候选、当天事件冲突，始终以实时程序字段和已发生事件为准；后续反思只在真实新事实支持时追加日记或替换认知。

## T0058 共享基础资源认知与升级协助

所有 NPC 中心 LLM 调用现在都从唯一顶层 `station_context.basic_resource_reserves` 获得驿站当前粮食、餐食、木材、石料和铁。该快照每次调用重新读取，不公开第纳尔、酒、装备、器械、马匹或其他库存；NPC 可以据此对话和安排，但不能直接改写数量。

共享规则明确建筑升级会缓慢推进，成员可通过 `assist_upgrade` / “协助升级建筑”加快正在进行的工程。完整 `work_mode_actions` 告诉 NPC 这种行为存在；只有本次 `allowed_actions` 中出现某座建筑的动态候选时才表示当前可选，计划和修订不得从基础规则自造升级目标。

## T0055 持续活动与周期结算常识

`station_rules` 新增一条所有成员都理解的驿站常识：工作、照料、训练、治疗和制造等活动，只有在成员持续参与的有效时间内才推进，并在完成相应周期后由驿站实际记录结算产出或结果。离开岗位、改做他事或被高优先级事件打断后，活动不会在无人持续参与时自行继续产出。这样，模型不能再把“上午在菜园工作过”推断成“下午离开后菜园仍自动产粮”。

这条规则仍不是结算器。是否完成周期、结算了多少、当前小数进度是否保留、材料是否扣除、恢复或成长是否发生，全部以 ActionSystem 及对应权威系统提供的结构化事实为准。规则刻意使用“未完成进度是否保留以实际记录为准”，避免错误地把制造周期中断归零等特定规则扩散到所有活动。

## T0054 共享驿站常识与世界边界

所有 NPC 中心正式请求继续继承 `StationAwareNPCRequest`，唯一顶层 `station_context` 在 T0058 后固定包含六部分：精简地点简介、当前在站人员、驿站全部建筑、工作模式下完整行为类型目录、五项公开基础资源、当前六条世界内驿站规则。人员、建筑、行为和资源分别来自对应权威系统，禁止在 Prompt、Schema 或 GDScript 中另写静态运行态副本。广场和公告牌不是建筑；仅运行态对话 / 逃离干预动作也不是工作模式计划行为。

这些规则只告诉人物如何理解所在世界：成员平时在站内工作和生活；需要持续参与活动并完成周期才会结算结果；敌袭时已入伍且装备主武器者保卫驿站；未入伍或没有主武器者尽量在站内避敌；士气低落时任何人都可能离开甚至临阵脱逃，使留下者处境更危险。这些是叙事与推理背景，不是状态结算。实际进度、产出、入伍、武器、士气、敌情、行动资格、资源和行为模式必须读取本次请求的权威状态；模型不得凭规则宣称事件已经发生。

`work_mode_actions` 是完整“行为类型目录”，用于防止模型补造世界外行为；计划 / 修订 / 普通对话仍以本次动态 `allowed_actions` 为可尝试的精确候选，战时心理仍以 `allowed_decisions` 为输出边界。对话、每日计划、计划修改判别、正式修订、战时心理和首次睡眠反思只在顶层注入一次，共享 NPCContext、speaker / target 或记忆子结构不得复制它。

## T0053 跨小时对话等待与跨阶段人物上下文

只有 `DailyPlanSystem` 派发的 `talk_to_npc` 才在 ActionSystem pending options 中写入 `plan_action_source=daily_plan`、来源日 / 小时、计划版本和完整原计划项。等待目标 `llm_activity.kind=plan` 时，ActionSystem 在逻辑时间、计划结束重试及整点新计划派发前读取说话者当前计划；仍为与同一目标对话才继续等待 / 邀请，否则返回 `talk_to_npc_failed_plan_superseded`。该失败的 `last_action_failure_context` 同时保存原 `failed_plan_item`、当前计划项、原 / 当前小时和版本、原目标、等待状态及 `waited_across_hour`，DailyPlanSystem 必须优先用其中的原计划项启动 T0050 判别，不能误把下一小时的新行动当成失败项。非日计划的 GM / 测试对话不参与此过期规则。

`PlanRevisionJudgementRequest` 不再是无人物上下文的轻量合同。日计划、对话 / 行动失败修改范围判别、正式修订和低血量战时心理判定统一使用 `NPCContext`：`identity`、权威 `state`、`current_order`、`short_term_memory`、`long_term_memory={knowledge_graph, diary}`、`location_context`；顶层携带动态 `station_context`。判别与修订还读取当前行动候选、建筑 / 资源状态；失败分支在两层之间原样传递 `failed_plan_item / failure_type / failure_summary / failure_context`。第一层仍只决定 `revision_hours`，不得输出行动或结算事实。战时加入战斗 / 继续避战 / 逃离的心理判断同样必须以这套人物与记忆上下文结合 `combat_context / battlefield_context`，不能另造一套人格。

## T0052 计划临界阶段与对话互斥

每日计划、计划修改判别和计划修订等待都使用 `llm_activity.kind=plan`。该活动从请求登记到 terminal 清理期间视为不可被对话取消的计划临界阶段：`DialogSystem` 在守备官草稿创建、草稿激活和首次消息 / 攻击真正生效前都检查 `NPCSystem.is_npc_plan_llm_active(...)`，返回 `npc_planning` 后不得推进 dialogue epoch、调用 LLM 取消或中断 NPC 当前行动。普通对话回复等其他 `cancellable=true` 活动仍沿用既有实际交互打断合同；深睡和战时心理判定继续使用各自更高优先级保护。

NPC-NPC 计划行动采用“可等待目标”而不是把计划活动当永久不可用：发起者可以接近目标，抵达后 `ActionSystem` 在 pending options 写入 `waiting_for_target_plan=true`，保留双方预约、开场目的和 `talk_to_npc` 运行态归属。目标的计划活动清除后，`npc_state_changed` 只安排一次延迟重试；重试时重新校验地点、行动能力、工作模式和不可打断状态，全部合法才调用原 `start_autonomous_npc_dialogue(...)` 邀请路径。等待本身不写失败，不触发 T0050 判别。即时失败修订仍排除计划 / LLM 活动目标，正式日计划可把并行计划中的 NPC 作为稍后交谈目标。

## T0051 守备官会话生命周期与 NPC 占用

守备官-NPC 会话现在把“窗口是否显示”与“会话是否仍活动”分开。普通对话第一次发送、攻击或挂起草稿时才真正打断 NPC 当前普通行动，记录被打断的运行时 action，并把 NPC 运行态设为 `current_action=talk_to_guard_officer`、`active_dialogue_id=<本会话>`；逃离挽留继续使用 `escape_intervention_dialogue`。挂起只写 `ui_visible=false`、`suspended=true` 和 7200 逻辑秒倒计时，不释放会话槽、原行动恢复令牌或正在等待的 LLM。

完成会话会先取消尚未返回的对话请求，再以已经存在的历史结尾提交会话事件；历史只要非空就进入 T0049/T0050 判别，因此玩家最后一句未获回复时也会触发。取消会话只允许在 `attack_committed=false` 时执行：取消 LLM、清空未提交历史、跳过事件 / 见闻 / 计划判别，并恢复仍匹配的原行动。两小时挂起超时时，普通会话自动取消；含攻击事实的会话因不可取消而自动完成。迟到异步响应因 `dialogue_id/request_id` 已失效而直接丢弃。

应征接受、战时反应和逃离挽留结构化结果在模型回复回来时只暂存于会话，完成时才由 NPCSystem / CombatSystem 权威应用；取消因此不会留下征召、士气或逃离决定副作用。HP 伤害仍在攻击点击时立即结算，永不回滚。NPC-NPC 自主对话不使用此三态生命周期，继续逐轮入库和双方计划判别。

## T0050 统一计划修改判别层

T0050 将日常行动失败接入 T0049 已建立的两阶段机制。`PlanRevisionJudgementRequest` 通过 `trigger_kind=dialogue|action_failure` 区分事实来源：对话分支读取本轮完整对话、结束原因和会话元数据；行动失败分支读取程序权威 `failed_plan_item`、`failure_type`、`failure_summary`、必要的 `failure_context`、原 24 小时计划，以及从原计划派生的工作阶段下限信息。T0053 起两类分支都额外注入与日计划 / 正式修订一致的驿站、NPC 人设 / 状态、短期 / 长期记忆、行动候选、建筑 / 资源和 `current_order`，但仍不输出行动。

第一层统一返回 `needs_revision + revision_hours`。空集合表示 0 个修改阶段并立即终止；行动失败后 NPC 可以保持空闲等待下一阶段，但不会伪造修订。非空集合才进入原有完整 `/npc/revise_plan` 上下文，第二层只允许改写判别出的精确小时。若失败工作阶段可能改为交涉 / 等待且全天计划已经只有最低 6 个工作阶段，第一层应同时选择最少的未来非工作阶段供第二层补回工作量，避免“当前工作改成谈话后只剩 5 段、但又无权修改别的阶段”的不可满足合同。

行动失败判别期间复用计划修订互斥锁、排队、过期版本丢弃、TimeSystem 慢速和对话派发屏障。判别为空 / 失败会释放锁且不产生第二层；判别非空后，原失败事实与判别结果一并进入第二层。同一计划阶段内可抑制重复状态通知，但进入新小时会清除失败去重缓存，因此同名失败在后续阶段重新发生时必须再次判别。修订落地后再次失败时，新权威失败也先重新判别，再按原有连续 3 次落地失败上限停止，不能绕过判别形成双后继或无限循环。守备官新指令、战斗结束 / 复苏和 GM 手动修订不属于日常行动失败，继续直接进入受限修订。

## T0049 对话后计划修改判别层

T0049 取代 T0048 “对话结束即全量重排剩余日”的口径。所有有实际完成内容的 NPC-NPC 与守备官-NPC 对话结束后，`DialogSystem` 为每名相关 NPC 独立请求通用 `plan_revision_judgement` 的 `trigger_kind=dialogue` 分支。判别输入包含当前时间、NPC id / 名称、对话类型、本轮完整对话、结束原因、会话元数据、该 NPC 原 24 小时计划，以及 T0053 统一的人设 / 状态 / 长短期记忆 / 指令 / 现实条件上下文。输出 `revision_hours` 必须去重、升序、不早于当前小时。空数组明确表示 0 个修改阶段，不得再调用 `/npc/revise_plan`。

只有判别非空时，`DailyPlanSystem` 才发起第二次真实 LLM 修订。该请求保留人设、状态、短期 / 长期记忆、地点、资源、建筑、行动白名单、当前指令、完整原计划和对话上下文，但 `revision_scope=selected_hours` 且输出必须恰好覆盖 `revision_hours`。未选小时不变；只有选中当前小时时才要求与当前项一致的 `immediate_action`，未选当前小时时必须为 `null` 且不重放当前行动。T0050 起日常行动失败也经过同一通用判别层；指令变化、战斗 / 复苏和 GM 等其他非对话原因继续直接修订。

NPC-NPC 双目标会话在发起任一参与者的判别前，由 `DailyPlanSystem` 预注册同一 `dialogue_id` 的计划派发屏障；无论是否跨小时，都要等双方第一层判别和各自必要的第二层修订全部终态，再按服务者、普通行动、依赖者、对话的计划依赖顺序放行，防止先完成的一方启动新行动并使另一方响应因对话 epoch 变化而过期。玩家-NPC 会话若以 `plan_hour_changed` 结束，也要延迟目标 NPC 的新小时派发，直到该 NPC 的判别 / 必要修订链终态。失败或取消同样必须释放屏障，不能永久卡住日程执行。

## T0046 共享基础场景与长期记忆输出

所有携带 NPC 根本人设的请求继承 `StationAwareNPCRequest`，并在顶层只携带一份必填且名单非空的 `station_context`。T0046 最初只提供地点简介和动态在站人员；T0054 已扩充建筑、工作模式行为与精简驿站规则。逃离、`behavior_mode=escaped` 或已在 `outside_station` 的 NPC 立即从人员名单除名，整个上下文仍不在嵌套 speaker / target 中重复。

首次睡眠反思只产生第一人称 `diary_entry` 和替换式 `knowledge_graph_updates`，不再产生独立 `memory_summary`。知识更新同时携带 `subject_label / relation_label / value_label` 中文显示文本；内部 `subject / relation / value` 仍可用稳定技术键 / 值，NPCPanel 必须映射为中文且对未知键和值使用中文保底。T0061 后玩家知识弹窗不展示 `confidence / day / time`，但这些元数据继续保存在运行态、后端请求 / 响应和 GM 调试视图中。

## T0044 守备官对话结束后的当前计划恢复

守备官发送消息后，玩家-NPC 对话会中断 NPC 的普通行动。若本次对话确实打断了正在执行的当前小时计划行动，且对话后判别返回空 `revision_hours`，NPC 仍可行动并处于 `behavior_mode=work`，DailyPlanSystem 应重新派发被打断的原计划行动。该入口同时校验“被打断的运行时行动 ID == 当前计划行动 ID”，只清除当前 NPC 本阶段的计划执行签名，再复用正常计划执行与资格校验；它不关闭常规的同小时重复派发保护，也不绕过建筑、位置、服务依赖、资源或目标可用性判断。

只打开再关闭对话窗不构成行动中断，也没有有效对话内容，因此不执行判别或恢复；NPC 原本空闲时完成对话，也不得重放本小时已经结束的短行动。判别选中当前小时、昏迷、逃离、集结、战斗或避战等分支由各自权威流程接管，不直接恢复旧计划。恢复时如果原计划已经不可执行，沿用计划系统既有失败 / 重估语义。

## T0043A 服务依赖行动生命周期

`receive_clinic_treatment`、`receive_weapon_training`、`attend_mass` 分别持续依赖 `work_clinic_doctor`、`work_training_instructor`、`lead_mass`。ActionSystem 在依赖者到岗申请位置前再次验证有效服务者；同批派发时若服务者仍在移动，依赖者可等待服务者到岗。依赖行动开始后，只要全部有效服务者退出，依赖者就立即得到结构化失败、释放位置并触发计划重评估，不等待替补。

教堂候选严格分为 `pray_at_chapel` 普通祈祷、`lead_mass` 主持弥撒、`attend_mass` 参加弥撒。普通祈祷无需神父，但与正在举行的弥撒互斥；主持开始会中断普通祈祷。参加者绑定具体主持者，主持正常结束时共同完成，异常退出时共同失败。每日计划同批派发顺序为服务者优先、普通行动其次、依赖者随后、对话最后，减少遍历顺序造成的伪失败；程序仍在每次执行时做最终权威复验。

## T0057 建筑升级失败重估合同

建筑升级是程序已经确认的高优先级事实。NPC 正在前往目标建筑执行活动时，ActionSystem 以 pending 阶段失败停止移动；NPC 已经在建筑内执行依赖活动时，以 active 阶段失败释放位置并退出到广场。两者都写入可被 DailyPlanSystem 识别的 `*_failed_building_upgrading`，并在 `failure_context` 中保留建筑、行动、阶段、`condition=upgrading`、`failure_reason=building_upgrading` 和“建筑正在升级”的中文摘要。

计划判别与正式修订继续使用现有 Schema 的 `failure_type=target_unavailable`，精确升级原因由 `failure_summary / failure_context` 承载。模型不得否认建筑已经开始升级，也不得让 NPC 继续进入或使用该建筑；第一层只选择需要修改的小时，非空时第二层才选择当前合法替代行动。协助升级发生在广场，不属于被升级建筑内部依赖行动，不能被该封闭规则误杀。

## T0043 位置行动、可见资格与失败重估合同

每日计划和对话行动参考继续共用 `data/action_defs.json` 候选源。吃饭、睡觉、普通祈祷、主持弥撒、参加弥撒、坐诊、接受治疗、指导训练和接受训练分别申请建筑定义中的具体位置类型；NPC 不输出位置编号，ActionSystem 在执行瞬间申请一个同类空位。满位、升级封闭、建筑失效、服务依赖缺失或资格不符都写入 `last_action_failure_context` 并触发既有计划修订链路。

`lead_mass` 是“可见但受资格限制”的特例：所有 NPC 的候选目录都保留它，候选上下文携带 `eligible`、`available_now`、`unavailable_reason` 和 `required_ability=主持弥撒`。模型应让无资格者极少选择它；即使选择，程序仍确定性拒绝。资格读取 NPC 档案的 `abilities`，不按 `background_job`、姓名或固定 NPC ID 判断。普通 `pray_at_chapel` 不要求神父在场。

诊所和训练场采用建筑内团队模型，不把受服务者绑定给某一个医生或教官。每个逻辑推进周期重新读取全部有效诊疗位 / 教官位占用者，汇总人数和相应技能，再乘建筑升级与损伤效率，应用到全部病床 / 训练位。LLM 只选择行动，不计算治疗量、技能增长、资源扣除、位置占用或升级结果。

升级启动是高优先级程序事实：所有指向该建筑的待执行 / 移动中 pending 行动和正在使用位置的 active 行动都以建筑升级为明确原因失败，NPC 逻辑退出至广场并进入统一重估；没有依赖行动的停留者只清退，不伪造失败。升级协助本身发生在广场，仍可继续。

## T0042 Prompt 人设与玩家背景详情共用

`scripts/core/NPCPromptProfile.gd` 是 NPC `npc_setting` 字段集合的单一代码入口。它从 `data/npc_profiles.json` 已加载的当前 NPC 档案读取外貌、背景故事、职业背景、性格、欲望、恐惧、底线、说话风格和能力；`LLMBridge` 用它构造模型输入，`NPCPanel` 的“背景”弹窗用它构造玩家只读详情。UI 不复制任何背景句子，也不新增第二套档案字段。

后续若调整 Prompt 人设字段，应在 `NPCPromptProfile.FIELD_DEFINITIONS` 与 `build_setting(...)` 的同一共享定义中完成，并同步更新 NPC 档案数据；背景弹窗会随当前 NPC 自动读取。该弹窗不改变 NPC 状态、记忆或计划，也不会触发 API 调用。

## T0041 非计划对话的行动能力边界

所有玩家-NPC 与 NPC-NPC `/npc/dialogue` 请求现在都必须携带非空 `allowed_actions`。`LLMBridge.build_npc_dialogue_payload(...)` 不维护手写行为表，而是直接复用每日计划的 `_build_allowed_action_candidates(npc_id, true)`；该目录继续由 `data/action_defs.json`、NPC 当前状态、建筑状态和动态目标共同生成。以后新增行为时，只要它进入同一计划候选构造链路，就会自动进入对话参考。

对话中的 `allowed_actions` 只回答“目标 NPC 的程序能力边界是什么”：列表内行动可被理解为当前允许尝试，执行时仍可能因工位、资源、目标或程序强制模式失败；列表外行动必须视为当前做不到或程序不支持。它不要求模型生成计划、选择下一步，也不表示行动已经执行。当前覆盖 2 类关系（玩家-NPC、NPC-NPC）以及 7 个具体 Prompt 上下文：`player_npc/work`、`rally`、`combat`、`avoid_combat`，`escape_intervention`，`npc_npc/invitation` 和 `npc_npc/conversation`。征召、NPC 主动交涉后的玩家回复和普通惩戒攻击回复复用 `player_npc` 构造器，自动继承同一参考。

## T0029/T0030 自主对话邀请与软轮次合同

计划执行 `talk_to_npc` 时，发起者抵达目标地点后先发出独立邀请请求，`dialogue_phase=invitation`。受邀 NPC 结合当前工作、人设、关系、状态与开场诉求返回 `invitation_result=accept|reject`；邀请待定期间仍保持原行动 / 工位且不写 `active_dialogue_id`。`accept` 后才中断双方普通行动、释放工位并切入正式 `talk_to_npc`；`reject` 记录邀请交换后结束，`current_round` 保持 0。

接受后的 `dialogue_phase=conversation` 没有程序硬性轮次上限，回复必须使用 `invitation_result=not_applicable`。`max_rounds=0` 表示无硬上限；`current_round`、`soft_round_threshold=5` 和 `soft_round_guidance` 每轮进入模型上下文。事情谈完即可由当前回复者在最后一句自然告别并设置 `should_end_dialogue=true`；第 6 轮起若没有紧急 / 必要事项应告别结束，确有必要可继续。结束标记回复先写入历史 / 事件，再直接结束且不调下一次对话 LLM。邀请判定与每轮正式回复都是独立真实 `/npc/dialogue` 调用并分别申请 / 释放 TimeSystem 慢速。正式会话结束后双方各自进入 T0049 判别；邀请被拒绝时，发起者与拒绝者也各自判别，但空结果不打断拒绝者的原行动 / 工位。高优先级状态不会被计划派发覆盖。

玩家-NPC 对话不再显示或保存“结束后重估计划”开关。有效 LLM 回复成功应用后，无论由守备官还是 NPC 主动发起，结束时都由 NPC 自行执行 T0049 判别。判别为空时，只恢复本次对话确实打断且仍匹配当前计划的当前小时行动；非空时只修订判别出的精确小时。只打开 / 关闭窗口、NPC 原本空闲，或普通消息发送后在回复完成前取消，不会伪造完成对话；但已提交的守备官攻击已经是本轮对话事实，即使回复取消或该攻击分支不产生 NPC 回复，也必须进入同一判别。

## T0028 自主对话的可观察状态与逐轮慢速

自主 NPC-NPC 邀请被接受后，DialogSystem 才为双方保存同一 `active_dialogue_id`，NPC 世界节点据此显示可点击三点气泡；邀请 pending 或拒绝不显示已经开聊的气泡。点击气泡只请求匹配 `dialogue_id` 的只读观察快照：玩家能看到双方姓名、当前轮次、“无硬上限 / 第 6 轮起建议收尾”、等待状态、已说出的待回复内容和历史，但不能在该窗口发言、攻击、应征、修改公开性或结束后台会话。关闭旁听不改变任何 NPC / 对话权威状态；对话仍在继续时可再次点击任一参与者气泡，恢复同一 `dialogue_id` 的最新快照。自然结束、失败、取消或高优先级模式中断时，双方会话锁与气泡一起清理，但已经打开的旁听窗口保留最后状态直到玩家手动关闭。

自主邀请与正式会话每一轮都调用 `/npc/dialogue`，并显式携带 `requires_time_slowdown=true`。LLMBridge 在请求返回 pending 之前为该次 request id 注册 `llm_dialogue_wait`，TimeSystem 使用默认 `1/60` 有效倍率；请求成功、失败、启动失败或取消都会释放。下一次邀请 / 正式回复使用新的 request id 再独立注册，不能用上一轮慢速覆盖整个会话，也不能在结束后遗留慢速请求。正式自主对话继续要求非 Mock provider 且 `model_fallback_used=false`。

## T0025 NPC-NPC 自主对话与完整计划行动目录

正式每日计划和失败修订现在都从同一动态 `allowed_actions` 目录选行动。目录覆盖设计稿 10.3 的前往建筑、职业工作、吃饭、睡觉、祈祷、诊所治疗、NPC-NPC 对话、训练，以及特殊的主动找守备官交涉和逃离意向；修复 / 升级 / 昏迷治疗协助只在实时目标存在时加入。`talk_to_npc` 必须使用同一候选中的 `target_id`、`location_id` 和 `action_kind=chat`，不能选择自己、昏迷、逃离、深睡、非工作行为模式或不存在的 NPC。

计划执行 `talk_to_npc` 时，发起者先追踪目标当前地点；目标移动后最多重定向一次。接近期间双方由 ActionSystem 预定，防止第三人并发抢占；已有权威对话时，即时计划修订不会再暴露必然失败的对话候选。到达后先走邀请判定，接受后才打断双方普通行动并释放工位，再使用真实 `/npc/dialogue` 自动轮流回复，直到任一方输出结束标记或高优先级条件中断。后端与 Godot 都要求 `replyer_id` 等于目标 NPC、`response_kind=reply_to_npc` 且邀请 / 正式阶段和软轮次字段一致。每个邀请交换和完成轮次写入双方事件库；任一已实际发生的邀请拒绝或正式会话结束后，两名参与者都各自请求 T0049 判别，仅判别非空者进入受限小时修订。战斗、避战、集结、昏迷和逃离等高优先级权威状态不会被日常计划或对话恢复逻辑覆盖。

24 小时计划先按每项声明的 `hour` 建表再排成 0-23，模型数组乱序不会交换行动时段，重复 / 越界 / 缺失小时会被拒绝。同批当前时段计划按“教官 → 其他非对话 → 受训者 → 对话”顺序派发，避免依赖 NPC 遍历顺序。运行态比较包含 action、target、location 和 dialogue goal；同一计划版本同一时段只派发一次。修订请求绑定请求日、小时和计划版本，并使用单后继队列；迟到响应不会覆盖新计划，连续 3 次迟到落地失败后停止自动续修。正式计划 / 修订不使用 Mock 或规则降级；仅当 Schema 已通过、action/target/location 唯一命中白名单候选时，后端可确定性规范化冗余 `action_kind` 并记录 `model_normalizations`，其他错误仍失败。

## 模块目标

AI NPC 系统负责让 NPC 看起来像有职业、有记忆、有意图的人，而不是普通兵种单位。

## NPC 初始名单

T0301 已在 `data/npc_profiles.json` 补齐 8 名初始 NPC 档案：

| 职业 | id | 姓名 | 性别 | 初始是否已入伍 / 可接收指令 |
|---|---|---|---|---|
| 马夫 | `stableman_01` | 托马 | male | 否 |
| 厨子 | `cook_01` | 布鲁诺 | male | 否 |
| 园丁 | `gardener_01` | 伊沃 | male | 否 |
| 铁匠 | `blacksmith_01` | 格伦 | male | 否 |
| 老兵副官 | `veteran_deputy_01` | 艾达 | female | 是 |
| 神父 | `priest_01` | 马塞尔 | male | 否 |
| 医生 | `doctor_01` | 莉娜 | female | 否 |
| 工程师 | `engineer_01` | 欧文 | male | 否 |

开局仍只有老兵副官 `veteran_deputy_01` 已入伍并可接收守备官指令；T0031 后艾达同时通过 `initial_equipment` 直接装备正式剑盾，开局兵种为近战步兵。该故事初始装备不扣驿站库存，也不产生守备官赠送装备事件。其他 NPC 必须通过后续征召/对话流程同意后才会获得指令入口。

## 人设与职业语气

T1501 已把 8 名 NPC 从数据草案收敛为 Demo 正式短档案。T0061 后，每名 NPC 在 `personality`、`desires`、`fears`、`boundaries` 之外只保留以下宽松语言字段：

- `speech_style`：描述句式、用词、关注顺序和表达习惯，不提供固定台词或必须重复的比喻。

| NPC | 宽松表达倾向 | 核心欲望 / 恐惧 / 底线 |
|---|---|---|
| 托马 | 先说观察到的状态和困难，再给朴素意见 | 保住马匹 / 害怕被迫冲锋 / 不无意义牺牲马匹 |
| 布鲁诺 | 口语化，常把人数、分量和花费说具体 | 让大家吃热饭 / 害怕粮尽与饭桌变病床 / 不虐待俘虏 |
| 伊沃 | 平静说明天气、土壤或进度，再表达判断 | 守住菜园 / 害怕粮田被毁 / 不烧平民粮田 |
| 格伦 | 先说结论，再交代材料、工序或风险 | 让作品用于防御 / 害怕武器被滥用 / 不把未训练者推上前线 |
| 艾达 | 按现状、风险、方案和后果依次说明 | 组织防线并让人活下来 / 害怕无训练者白白送死 / 不接受无意义处决 |
| 马塞尔 | 先听完再温和提出异议，把信仰落到具体后果 | 安抚众人 / 害怕信仰替暴力背书 / 不为残酷命令祝圣 |
| 莉娜 | 先核对事实与风险，再说明结论和代价 | 救治伤员 / 害怕药尽与放弃病人 / 不伤害无防备者 |
| 欧文 | 按问题、原因和解决办法说明，含糊处会追问 | 守住围墙 / 害怕器械失控 / 不做针对平民的陷阱 |

`LLMBridge` 会把 `speech_style` 放入对话 `npc_setting` 和共享 `NPCContext.identity`。对话 Prompt 要求模型从职业经验、性格、长期记忆与当前处境出发回应，并避免可互换的通用士兵台词；首次睡眠总结也参考同一宽松语气，但不受固定句式约束。

## 熟练度架构

NPC 没有写死的程序职业。`background_job` 只记录叙事出身，工作效率、训练倾向、装备表现和后续 AI 判断都应优先读取固定熟练度维度。

每名 NPC 都必须拥有且只能拥有以下 13 个熟练度：

| 类型 | 熟练度 |
|---|---|
| 职业熟练度 | 养马、厨艺、耕种、打铁、教练、酿酒、医术、工程 |
| 武器熟练度 | 剑盾、长杆、弓、弩、骑术 |

职业倾向由高熟练度推导。例如养马高的人可被看作马厩专家，医术高的人可被看作医生，但系统不应把“马夫 / 医生 / 工程师”等作为权威职业枚举。

## 当前运行时实现

T0304 已实现最小 NPC 生成、基础状态读取/更新、面板显示和直线移动闭环：

- `NPCSystem` 从 `data/npc_profiles.json` 读取 8 名初始 NPC 档案。
- 新游戏生成 8 人前装载独立初始长期记忆，NPC 面板从开局即可阅读 3 篇历史日记和中文知识图谱。
- 六类 LLM 请求共享同一运行态记忆事实源；不在 target / speaker 或旧 `knowledge_graph` 镜像中重复注入。
- 通用 `res://scenes/npc/NPC.tscn` 由 `NPCSystem` 实例化到 `Main/WorldRoot/Station/NPCs`。
- 每个 NPC 保存唯一 `npc_id`，主场景头顶调试标签只显示姓名、HP 和当前行动，职业与入伍状态保留在 NPC 面板中。
- 点击 NPC 会打印对应 ID，并通过 `EventBus.npc_clicked(npc_id)` 广播，打开 `Main/UI/NPCPanel`。
- `NPCSystem` 提供 `get_npc(...)`、`get_npc_state(...)`、`update_npc_state(...)` 和 `set_npc_state_value(...)`，后续系统可通过这些接口读取或修改 NPC 基础状态。
- `NPCSystem` 提供固定熟练度枚举与 `normalize_skills(...)`，确保每名 NPC 都拥有完整 13 维熟练度，且不会保留未定义技能。
- NPC 状态修改后会通过 `EventBus.npc_state_changed(npc_id)` 通知 UI 刷新。
- `NPCSystem.move_npc_to_building(...)` / `debug_move_npc_to_building(...)` 可让 NPC 前往指定建筑入口；当前用于调试验证和后续行动系统接入。
- `NPC.gd` 负责简单直线移动，到达目标后发出 `movement_arrived`，由 `NPCSystem` 写回 `current_location`、`current_location_name` 和 `location_context` 地点信息占位。

T0305 后，`ActionSystem` 已能通过调试接口安排 NPC 执行工作、吃饭和睡觉：系统会先复用 `NPCSystem.move_npc_to_building(...)` 前往目标建筑，到达后进入持续行动状态，并随 `TimeSystem.logical_time_tick` 逐步推进，而不是瞬时完成。吃饭当前以 20 分钟为基准，完整进餐恢复约 50 点饱食度；睡觉以 6.5 小时消耗 100 点疲劳为基准，按逻辑秒细分结算。T0801 起，工作以 `data/action_defs.json` 的 `duration_seconds` 作为单位周期基准，开始时占用建筑工位，周期时长会按 NPC 对应熟练度、力量 / 智力属性和建筑等级缩短；完成、失败或中断会释放工位并广播地点内部状态。T0804-T0806 的早期聚合制造 / 马匹整备路径已由 T0035-T0038 覆盖：铁匠铺与工械坊周期提交配置阶段，马厩周期只提供有效照料能力，不直接产出资源。T0807 的酒窖仍消耗粮食并产出 `wine`；行动开始、完成或失败继续写入 `MemorySystem` 的结构化事件。

T0034 冻结的制造、具体库存和马匹合同现已由 T0035-T0038 实现：

- `work_blacksmith` / `work_workshop` 只有在对应建筑已经由玩家选中合法制造目标时才能开始。一个完整工作周期只提交一个配置阶段；周期被对话、改派、战斗、昏迷、离岗等打断时，该 NPC 本周期的小数进度归零，但建筑已完成整数阶段不回退。多工位可并行跑周期，提交时由 CraftingSystem 按 revision 原子领取下一阶段、扣除阶段材料并最终增加 11 项具体库存中的对应成品；NPC、LLM 和计划文本均不能直接指定完成阶段或产出成品。
- `work_stable` 的输入 / 输出资源为空，不再把粮食转换成匿名 `horse_readiness`。只有至少一名 NPC 正在马厩有效工作时，HorseSystem 才取在岗者中的最高“养马”熟练度推进逐马繁育概率、幼马 / 未完全成长成年马的成长和额外 HP 培养；多个工位不重复叠加照料能力。至少两匹成年在厩、非冷却马才逐分钟累积概率并执行最多 `N - 1` 次判定，成功后候选概率归零并冷却 1 游戏日。马匹饱食消耗、仅在厩内进行的持续进食、厩内外自然 HP 恢复和繁育冷却由 HorseSystem 随逻辑时间独立推进，NPC 工作只提供照料能力。马厩每升 1 级只让繁育概率增量增加 10%，不加速成长或额外 HP 培养。
- `HorseSystem` 权威保存唯一马匹实体和分配关系。只有已入伍且持主武器的 NPC 可分配成年、未分配、物理在厩马；分配后日常仍在厩，进入 `rally / combat` 才变为 `ridden`，退出战时状态返厩。收回主武器、取消入伍或逃离会自动解除分配；`equipment.mount` 仅保存具体 `horse_id / horse_name` 投影。
- 每日计划 / 修订可以选择这些工作意图，但 ActionSystem 在执行时仍须校验制造目标、马厩位置、工位和 NPC 可行动状态。计划 LLM 不能生成马、选择出生结果、扣粮、完成阶段或改写具体库存；弃用的 `weapons / armor / defense_devices / horse_readiness` 也不再是合法正式产出或消费来源。

2026-05-24 起新增协助修复行为；2026-05-25 起新增协助升级行为。`debug_assign_repair_assist(npc_id, building_id)` 与 `debug_assign_upgrade_assist(npc_id, building_id)` 都是带建筑参数的独立行为，可让 NPC 在广场协助正在修复或正在升级的建筑，并按工程熟练度加速对应倒计时；NPC 如果在室内，会先前往广场再开始协助。如果 NPC 离开广场或被改派其他行动，`BuildingSystem` 会移除其协助人数和速度加成。协助修复/升级事件写为 `location_id == "plaza"` 的 `local_public`。当前行动仍是最小闭环，计划系统只能安排意图并调用行动白名单，不能让 LLM 直接结算资源、建筑或 HP。

T0501 起，`NPCSystem.apply_damage_to_npc(...)` / `debug_damage_npc(...)` 负责权威 HP 扣除。HP 降到 0 时 NPC 进入昏迷而不是死亡，停止移动，`current_action` 变为 `unconscious`，头顶标签与 NPC 面板会显示昏迷状态。昏迷 NPC 不能移动或执行工作、吃饭、睡觉、协助修复/升级等行动。

T0502 起，昏迷 NPC 会随 `TimeSystem.logical_time_tick` 自然恢复 HP，当前速率为每游戏小时 2 HP；HP 达到 Max HP 的 30% 后自动复苏，`unconscious=false`，`current_action=idle`，后续移动和行动指派重新允许。复苏会写入 `revived` 事件并按当前信息地点 `local_public` 广播。

T0503 起，其他可行动 NPC 可通过 `ActionSystem.debug_assign_heal_assist(healer_npc_id, target_npc_id)` 协助治疗昏迷目标。治疗者会前往目标所在信息地点；目标必须处于昏迷状态，每个目标最多 2 名治疗者。治疗开始和持续治疗会消耗全局第纳尔；医术熟练度会转化为额外 HP 恢复速度，低医术几乎没有额外加成，医生的高医术会明显快于自然恢复。治疗开始/完成事件会写入治疗者和目标的事件库，并写入同地点其他在场 NPC 的见闻库；事件信息不暴露医术熟练度。该功能只覆盖“他人治疗昏迷者”，不等同后续 NPC 主动去诊所治疗或医疗床位系统。

T0808 起，小诊所治疗补齐为两个独立行动；T0043 将它们的位置合同统一为 `work_clinic_doctor -> clinic_doctor_station` 诊疗位与 `receive_clinic_treatment -> clinic_patient_bed` 病床。初始容量为 1 个诊疗位、2 个病床，两类都可由升级扩展。每个逻辑推进周期都汇总全部有效诊疗位占用者的人数、医术和相关属性，得到共享诊疗团队效率并作用于全部病床；再与诊所升级和损伤效率合成最终 HP 恢复速率。无病人时，诊疗位上的 NPC 以很慢节奏研读医学著作；医术增长继续进入统一经验与技能点规则。

T0903 起，训练场补齐为两个独立行动；T0043 将它们的位置合同统一为 `work_training_instructor -> training_instructor_station` 教官位与 `receive_weapon_training -> training_practice_slot` 训练位。初始容量为 1 个教官位、2 个训练位，两类都可由升级扩展。训练项目由受训者当前武器 / 坐骑决定；每个逻辑推进周期汇总全部有效教官位占用者的人数、“教练”和对应项目熟练度，得到共享指导团队效率并作用于全部训练位；再与训练场升级和损伤效率合成最终训练速率。无受训者时，教官仍极慢练习自己当前装备；有受训者时，教官只提升“教练”。

T0904 起，`NPCSystem.increase_npc_skill(...)` 是统一成长入口。普通职业工作完成时会以很慢速度提升该行动配置的职业熟练度；诊所研读 / 治疗、训练场独自练习 / 受训 / 指导训练也复用同一入口。每次熟练度实际增加都会写入运行时 `progression.skill_experience` 和 `progression.total_experience`；当前每 5 点总经验产生 1 个 `unspent_skill_points`。技能点不由 AI 自动分配，必须由玩家在 NPC 面板或 GM 调试入口调用 `NPCSystem.assign_npc_attribute_point(...)` 分配到力量或智力。AI 后续可以根据背景、近期行为和目标给出建议或倾向，但不能自行消耗技能点，也不能直接改写力量 / 智力权威状态。T0045 后属性分配仍写入 `private` 的 `attribute_improved` 事件，但世界内 summary 把 NPC 自身作为 actor，力量 / 智力分别表达为锻炼体力 / 脑力所得，不再写“守备官分配”。

T0502A 起，昏迷 NPC 不接收地点/广场公开广播、建筑/地点状态广播、公告或进入快照，见闻库暂停更新；事件库仍记录发生在自己身上的受伤、昏迷、复苏等亲历事件。复苏后见闻接收自动恢复，但不会补收昏迷期间错过的信息。

2026-06-03 起，睡觉 NPC 使用同一条见闻接收规则：当 `current_action == "sleep_in_dormitory"` 时，该 NPC 不会把同建筑内发生的 `local_public` 事件、地点/建筑状态广播、公告或进入快照写入见闻库；自己的入睡和醒来仍进入事件库。睡醒回到可行动状态后，只从后续广播继续接收见闻，不补收睡觉期间错过的信息。

T1004/T1005/T1405/T0046 起，NPC 每天首次进入睡觉状态后，必须持续睡眠满 1 个游戏小时才会触发 `DailyReflectionSystem`。系统通过异步 `/npc/daily_reflection` 把当天事件库和见闻库摘要交给后端（开发期可使用 Mock，Prompt 任务必须使用真实 API 验收），后端不可用时使用本地模板，生成第一人称日记和知识图谱当前键值更新，不再生成并列的长期摘要。反思从发起请求到应用完成期间，NPC 进入不可打断的深度睡眠锁：玩家对话、消息、行动改派和普通中断都会被拒绝；已入伍 NPC 仍可保存新指令，但计划重评估延后到醒来后执行。结果由 `NPCSystem.apply_daily_reflection(...)` 把 `diary_entry` 追加到长期 `diary`，并把 `knowledge_graph_updates` 按 `subject + relation` 替换式写入 `knowledge_graph.by_subject`；随后清空该 NPC 当天短期事件 / 见闻索引。NPC 面板可查看日记和 LLM 状态，GM 面板可强制触发、查看长期记忆和查看 LLM 状态。模板降级必须保留模型失败日志，不得用 mock 日记伪装真实模型成功。

T1305 起，胜利和失败结算会为每名 NPC 生成结局总结快照。`GameState.set_game_over(...)` 读取 NPC 当前权威状态、入伍状态、最后位置、长期日记和当天事件，生成确定性 Mock 字段：最终状态（可行动 / 昏迷 / 逃离）、是否入伍、对守备官最终看法、后续命运和记忆依据。该结局总结只用于 HUD 结算页展示，不会写回事件库、见闻库或长期记忆，也不会让 AI 反向改写 HP、逃离、入伍或地点事实。NPC 不死亡，因此结算文案不使用“阵亡”或“死亡”描述 NPC。

T0701-T0705 已实现 Godot 前端对话、最小征召、指令发布和主动交涉最小闭环。已入伍 NPC 可从 NPC 面板打开 `OrderPanel`，自由查看、修改并发布一条持续生效的 `current_order`；`NPCSystem.publish_npc_order(...)` 只在文本变化时更新指令、写入私有 `order_assigned` 并发出计划重评估请求。若 NPC 正处于首次睡眠总结锁，指令仍保存，但重评估延后到醒来后。T0015 后 GM 面板可调用 `NPCSystem.set_npc_recruited(...)` 将选中 NPC 设为入伍，用于调试指令、装备和训练入口；正式征召仍由对话完成时提交的同意结果驱动。`NPCSystem.debug_start_proactive_talk(...)` 可让 NPC 进入主动找守备官交涉状态，显示问号气泡，点击后打开既有对话面板并把预先确定的开场问题放入会话缓冲；1 小时无人点击则状态结束。

T1001 起，`DailyPlanSystem` 可生成规则版 24 小时调试计划并保存到 NPC `plan` 字段，写入 `plan_created` 事件，并按 `hour_started` 调用 `ActionSystem` 执行当前小时行动；T0025 后同一计划版本同一小时只派发一次，短行动提前完成后等待下一小时或新计划版本。T0050 后，实际对话与日常行动失败都先调用通用判别层，仅在返回非空 `revision_hours` 时进入真实 `/npc/revise_plan`；主动交涉超时、战斗结束 / 复苏和新指令等其他非对话原因仍直接修订。T0023 后，计划修订通过 `LLMBridge.request_npc_plan_revision_async(...)` 在后台调用真实 `/npc/revise_plan`；工位占用、资源不足以及其他已有 `failed` 行动结果先进入 `request_plan_revision_judgement_async(...)`。等待期间 NPC 显示 LLM 活动并注册 TimeSystem 慢速；Godot 只接受带非 Mock provider 证明且 `model_fallback_used=false` 的响应，成功合并为 `llm_plan_revision`。只有修订包含当前小时时才执行即时项；失败最多重试 3 次真实请求且不应用 Mock / 规则修订。T0051 后，打开后取消空会话无副作用；玩家消息发送即进入会话历史，完成会话时即使 NPC 回复未返回也会取消请求、把已有历史入库并触发判别。取消会话不入库、不应用结构化意向且不判别；挂起会话让 NPC 保持 `talk_to_guard_officer`，最多 2 游戏小时后自动取消。攻击一旦发生则不能取消，完成或攻击后的挂起超时都会保留攻击历史并进入统一判别。

T1003/T1403/T0022 起，每日计划可通过 `/npc/plan_day` 生成 24 阶段计划，请求包含当前 `current_order`、短期/长期记忆、地点、资源、建筑状态和行动白名单。正式开局和跨天后的新一天只接受已配置的真实 provider；后端成功响应携带 `model_provider` / `model_name` / `model_fallback_used`，Godot 将通过验证的计划统一写为 `source=llm_plan_day`。`/npc/plan_day` 真实 provider 路径使用 `data/prompts/daily_plan_system_prompt.txt`，后端校验 24 个 hour 覆盖、行动白名单和至少 6 个工作阶段。真实请求失败或输出不合法时只重试真实请求，不写入规则 / Mock 计划；显式开发 Mock 和 GM 纯规则入口仍与正式路径隔离保留。

T0019/T0022/T0024 起，`GameStartupSystem` 把每日计划接入正式开局。默认模式会先暂停 `TimeSystem` 和计划自动执行，在第 1 天 06:00 为 8 名 NPC 逐人写入私有 `wake_up`、清空旧计划并把 `current_action` 设为 `planning_day`。随后同时发起 8 个真实 `/npc/plan_day` 请求；单人失败最多再试 2 次，仍失败则整批失败。只有 8 份 `llm_plan_day` 计划全部就绪后，系统才统一执行当前小时项并恢复时间；否则所有 NPC 保持 `planning_day`，游戏保持暂停。`DailyPlanSystem` 在 `day_started` 也使用同一整批事务边界，不允许成功一半就提前执行；批次快照同时记录 `max_concurrent=8` 与实际 `max_observed_concurrent`。静止调试模式不生成起床 / 计划 / 行动；新手引导模式当前复用同一正式循环。

T1004/T1005/T1405/T0024 起，首次睡眠总结可通过 `/npc/daily_reflection` 开发期 Mock 或真实后端把当天短期经历沉淀为长期日记和知识图谱当前键值，失败时模板降级；知识图谱同一 `subject + relation` 替换旧值，日记按条追加。符合条件的 8 名初始 NPC 可同批 8 路并发；后端成功体统一携带 provider / model / fallback 元数据，Godot 按真实 provider 标记 `llm_daily_reflection`，只在显式 Mock provider 时标记 `mock_daily_reflection`，缺少来源证明不会被猜成真实成功。T1402 后 `/npc/dialogue` 真实 provider 路径已使用 `data/prompts/dialogue_system_prompt.txt`，覆盖日常对话、提出应征、集结 / 战斗公开对话、避战公开对话和逃离挽留；T1404 后 `/npc/battle_judgement` 真实 provider 路径已使用 `data/prompts/battle_judgement_system_prompt.txt`，并由后端拒绝越界低血量心理结果；T1405 后 `/npc/daily_reflection` 真实 provider 路径已使用 `data/prompts/daily_reflection_system_prompt.txt`，并完成真实 API 验收。Godot 客户端不保存供应商 API Key。

T0020/T0049/T0050 后，后端六类正式 NPC AI 调用不再设置客户端单次输出 token 上限，返回空内容、非法 JSON 或 `finish_reason=length` 时按业务紧凑重试一次。Godot 的对话、通用计划修改判别、常规每日计划、计划修订、低血量心理判定和首次睡眠总结都提供异步请求路径，并在影响当前场景状态时注册 TimeSystem 慢速；成功、失败、取消、超时或规则 / 模板降级都会释放。正式开局批量计划继续由 GameStartupSystem 全局暂停时间。

## LLM Mock 与真实 API 规则

Mock 只用于开发期验证 Schema、通信和自动化脚本。任何 NPC 对话、每日计划、计划修订、战时判定、逃离挽留、主动交涉或首次睡眠总结的 Prompt 打磨任务，都必须在基础 mock 测试通过后用真实 API Key 对相关业务路径做真实 provider 验收；没有真实 Key 时不能把 LLM 行为标记为完全完成。

真实 provider 失败、超时、无 Key、返回非 JSON 或 Schema 校验失败时，系统必须释放 TimeSystem 慢速请求，并在 usage / 日志中保留 request id、call_type、provider、model、NPC id 和真实失败原因。规则 / 模板降级只能用于明确保留降级语义的其他系统，且来源必须可见；T0022/T0023 后的正式每日计划与正式计划重估都禁止 Mock 和规则降级。任何路径都不得用 mock 回复、mock 计划或 mock 日记伪装模型成功。累计 API 预算和单次生成长度必须分开：前者由默认关闭的 `LLM_BUDGET_MAX_*` 控制，后者不由客户端设置固定上限。

T1401A 后，自动 mock fallback 默认关闭；只有显式 `LLM_PROVIDER=mock`、`/mock/model` 或显式 `LLM_FALLBACK_TO_MOCK=true` 的开发调试路径会返回 mock 内容。真实 provider 失败和模型输出不合 Schema 会作为错误或规则 / 模板降级暴露，并写入 `/debug/llm_usage`。

T1402 后，NPC 对话 Prompt 已完成真实 API 验收：本机 DeepSeek `deepseek-v4-flash` 对 `/npc/dialogue` 的日常对话、提出应征、战时结构化意向和逃离挽留各完成一次真实调用，`fallback_used=false`。后续对话质量调参优先修改 `data/prompts/dialogue_system_prompt.txt`，不要把职业人设、NPC 档案或游戏设计全文硬编码进 Python 逻辑。

T1403 后，每日计划 Prompt 已完成真实 API 验收：本机 DeepSeek `deepseek-v4-flash` 对 `/npc/plan_day` 完成一次真实调用，返回 24 阶段计划、只使用 `allowed_actions` / `idle` 且工作阶段不少于 6，`fallback_used=false`。后续计划质量调参优先修改 `data/prompts/daily_plan_system_prompt.txt`，不要把 NPC 档案、行动配置或游戏设计全文硬编码进 Python 逻辑。

T1404 后，战时公开对话与低血量心理 Prompt 已完成真实 API 验收：本机 DeepSeek `deepseek-v4-flash` 对战时 `/npc/dialogue` 与 `/npc/battle_judgement` 各完成一次真实调用，返回的结构化意向均在允许枚举内，`fallback_used=false`。后续战时心理质量调参优先修改 `data/prompts/dialogue_system_prompt.txt` 与 `data/prompts/battle_judgement_system_prompt.txt`，不要把 NPC 记忆摘要、战场事实或允许结果写死进 Python 逻辑。

## 当前地点状态

T0304 起，NPC 运行时 `states` 会补齐以下地点字段：

- `current_location`：当前地点 id，默认 `plaza`，到达建筑后更新为建筑 id。
- `current_location_name`：当前地点显示名，到达建筑后由 `BuildingSystem` 填入。
- `movement_target` / `movement_target_name`：移动中的目标地点；到达后清空。
- `location_context`：地点当前状态读取占位，不包含地点历史事件。进入广场时包含当前广场在场 NPC、在场 NPC 状态、公告牌当前通告、参考日程及非强制备注和所有建筑的可传播外部状态；进入可进入建筑时包含该建筑的等级、`condition`、`is_enterable`、运行效率分档，以及在场 NPC、NPC 状态和完整逐位置清单。每个位置使用玩家可读名称表达空闲 / 占用；位置新增、移除、改名、改类型或换占用者时，在场 NPC 获得字段级差量。在场 NPC 的生命状态只表达健康、受伤、昏迷，行动状态由 `current_action` 翻译成精简中文。HP 具体数值、精确效率和剩余修复 / 升级时长不进入 NPC 见闻；容量不用额外聚合数字表达，而由完整位置清单及其增删差量自然得出。

T0035/T0037 已按 T0034 冻结合同在 `location_context.internal_state.special_state` 中实现严格白名单：铁匠铺 / 工械坊只包含制造目标与整数阶段；马厩只包含物理在厩马匹的总数、成年数和小马数。当前制造周期的小数进度、逐匹马的名称 / HP / 饱食 / 成长 / 进食 / 分配信息不得进入 NPC 地点上下文。NPC 只有进入该建筑时获得完整当前快照，或在仍处于该建筑且未昏迷 / 未睡觉时获得字段级变化；建筑外 NPC 与广场快照不得获得这些实时内部状态。离开后，后续 LLM 只能看到该 NPC 已经合法收进见闻的旧信息，不能绕过 MemorySystem 查询全局最新值。

这些字段由地点上下文与见闻链路按可见性传给后续 LLM 请求，但不授予 LLM 查询建筑全局实时状态或修改权威制造 / 马匹状态的权限。

## 事件、见闻与短期记忆

T0405 后，NPC 的短期记忆不再视为一个扁平文本列表，而由两类运行时记录组成：

- NPC 事件库：发生在该 NPC 身上的事件，例如醒来、制定计划、进入/离开地点、工作、吃饭、睡觉、对话、收到或修改守备官指令、被给予金钱/装备、升级、受击、昏迷、治疗、复苏、逃离等。
- NPC 见闻库：该 NPC 从地点/广场即时广播、状态变化广播、公告或他人公开事件中获得的信息；昏迷或睡觉期间暂停更新。

NPC 进入地点时，系统生成 `location_entered` 事件并写入进入者事件库；该事件只记录“某人进入了某地”，不附带完整建筑状态。进入者随后在见闻库获得一次当前状态快照：进入广场时获得当前广场在场 NPC、广场在场 NPC 的生命状态 / 行动状态、公告牌当前通告、参考日程及非强制备注和所有建筑可传播外部状态，进入某个可进入建筑时获得该建筑外部 + 内部状态，包括当前在场 NPC、建筑内 NPC 的生命状态 / 行动状态和工位占用。已经在该地点的其他 NPC 只收到 `location_entered` 本地公开事件，不再额外收到完整人员状态。NPC 不会因为进入某建筑而继承该建筑过去发生的事件。

NPC 离开地点时，系统生成 `location_exited` 事件，`location_id` 使用其离开的地点；该事件写入离开者事件库，并以 `local_public` 广播给仍在该地点的 NPC。离开事件本身表达了“谁离开了这里”，不再额外广播完整 `people_present`。

NPC 从一个室内信息地点前往另一个室内信息地点时，当前实现会在事件和地点信息层插入广场中转：离开原地点、进入广场、离开广场、进入目标地点。物理表现仍是低模阶段的直线移动占位，不代表最终导航模型。

后续建筑或地点状态变化只进入字段级见闻，例如建筑受损、升级完成、公告变化或某个工位占用变化；未变化的建筑状态和在场人员不重复传递。对话全文也作为对话事件 `payload` 保存，供后续对话、计划和首次睡眠总结引用。

T0603 对话请求的目标 NPC 输入应包含 `npc_id`、`npc_name`、`npc_setting`、`npc_state`、`short_memory`、`long_memory` 和 `location_context`；说话者输入包含 `speaker_name`、`speaker_text` 和 `speaker_context`。T0703A 实现后，所有面向目标 NPC 的对话请求还必须加入该 NPC 的 `current_order`。如果说话者是守备官，名称固定为“守备官”；如果说话者是 NPC，`speaker_context` 应包含发起者健康/受伤状态与外表特征。T0029/T0030 后 NPC-NPC 请求还携带 `dialogue_phase`、`current_round`、`soft_round_threshold` 和 `soft_round_guidance`；邀请先接受 / 拒绝，正式对话无硬上限且每轮都可独立结束。

对 LLM 来说，亲历事件和见闻必须分开摘要：亲历对情绪和判断权重更高，见闻则代表当场听到/看到的信息、公共压力和场景认知。

面向 NPC 的所有玩家相关事件摘要、见闻摘要、对话上下文和后续日记/反思输入，必须把玩家称为“守备官”。“玩家”只作为开发文档里的外部说明词使用，不进入 NPC 可见文本或 LLM 世界内上下文。

当前运行时可通过 `MemorySystem.get_npc_short_term_memory(npc_id)` 获取 `{ event_log, witness_log }` 两个容器，也可通过 `get_npc_short_term_memory_ids(...)` 获取事件 ID 版本。`NPCPanel` 已分开显示事件库和见闻库，并使用固定高度滚动区避免记忆增长撑高面板；地点状态见闻会写明具体建筑名称和状态，例如“围墙受损”“食堂内现在有布鲁诺、莉娜”“在场人员状态：布鲁诺健康，行动：吃饭”“菜园里的 garden_plot_01 状态变为空闲”。T0704 后，守备官给钱可从 NPC 面板触发；T0036/T0038 后，守备官也可在 NPC 面板为已入伍 NPC 装备具体主武器与四部位盔甲，并为满足条件者分配具体成年马，GM 入口复用相同系统接口做验证。T1006 起，守备官攻击入口移入对话窗：攻击先复用 `NPCSystem.apply_damage_to_npc(...)` 扣 HP 并写入惩戒攻击 `damage_taken` 事件，再请求 NPC 对攻击作出 LLM 回复。给钱、装备和攻击会进入目标 NPC 事件库，公开交互会进入同地点 NPC 的见闻库，并随 `LLMBridge` 后续对话上下文的短期记忆摘要传给后端。“要求休息/请求治疗”不作为 NPC 面板按钮，相关意图由已入伍 NPC 的自然语言指令表达。

## T0036/T0038 具体装备与马匹分配当前实现

装备合法性必须读取具体成品库存：剑盾、长杆、弓、弩以及四个盔甲部位各自消耗自己的 `item_*`，不能继续用一份 `weapons` / `armor` 聚合数互换。故事初始装备仍沿用 T0031 的零库存特例；除此之外，EquipmentSystem 是武器 / 盔甲库存扣除与槽位变更的唯一入口，马匹分配则遵循下方 HorseSystem 权威边界。

NPC 面板的马匹分配属于玩家管理操作，不是 NPC 自主计划行动，并遵守：

- 只有已入伍且已经装备主武器的 NPC 才具备分配资格；仅穿盔甲不算“有装备”。
- 只能选择成年、未被其他 NPC 分配且物理上位于马厩的马。每名 NPC 至多一匹，每匹马至多分配给一名 NPC，小马不可分配。
- 分配只建立预留关系。`work` / 日常模式下马仍在马厩，继续参与马厩数量统计、饱食消耗、进食和非战斗恢复。
- NPC 进入 `rally` 或 `combat` 时才自动骑乘，马的 `location` 改为 `ridden` 并离开马厩数量；退出战时模式、未接敌集结超时、战斗结束或 NPC 昏迷后，马返回马厩，分配关系可保留。
- 收回主武器、取消入伍或逃离驿站会自动解除分配并清空坐骑槽；在一把合法主武器之间更换，或只收回盔甲，不解除分配。

HorseSystem 保存马匹实体和唯一分配关系，`equipment.mount` 只保存带 `horse_id` / `horse_name` 的兼容快照供兵种与表现读取。LLM 可以在对话中表达对征用马匹的态度，但不能分配马、让小马成年、结算生育、治疗马或复制坐骑槽。

## NPC 行为层级

## NPC 行为模式

T1103A 起，NPC 当前模式已作为权威运行时状态保存在 `states.behavior_mode` 并可由 NPC 面板 / GM 快照展示。模式至少包括：

- `work` / 工作模式：沿用当前计划系统、行动异常、对话打断和计划重评估机制。
- `rally` / 集结模式：守备官摇响警铃后，已入伍、有主武器且当前可行动的 NPC 前往城门外防线；到达后等待接敌。
- `combat` / 战斗模式：已入伍且有主武器的 NPC 接敌后按兵种、装备、熟练度和守备官手动选择的战斗策略行动。
- `avoid_combat` / 避战模式：非战斗人员（未入伍，或已入伍但无主武器）遇敌后按敌人接近方位逐步远离，但不离开驿站；该模式不同于已入伍持武器 NPC 在战斗模式中的“避战策略”。

模式切换属于程序强制层。LLM 不能直接设置模式，只能通过结构化意向触发程序校验后的模式变化，例如战时对话结果触发逃离、避战对话同意应征后改变入伍状态、低血量心理判定触发斗志或逃离。低血量判定覆盖战时所有未昏迷、未逃离 NPC，但只有已入伍且有主武器、实际处于 `combat` 模式的 NPC 可获得斗志激昂或继续参战；避战 / 非战斗人员只可能触发逃离或继续避战。避战 NPC 只有在已入伍且有主武器、场上仍有敌军时才从避战切入战斗。当前 T1103A/T1103B/T1103C 已实现程序状态机、切换边界和非战斗人员避战移动；T1103D 起，工作 / 战斗与工作 / 避战互转不写入 `npc_mode_changed`，只保留避战开始 / 结束、攻击、受伤等具体事实事件；T1104 起，`combat` 模式中的入伍持武器 NPC 会按程序数值自动攻击范围内敌人并写入攻击事件；T1105 起，当前战斗策略由玩家在 NPC 面板手动选择，并由装备 / 兵种限制可选项。T1201 已实现战时公开对话心理结果；T1202 已实现低血量自身心理判定；T1203 已实现逃离驿站行为。

进入 `rally`、`combat` 或 `avoid_combat` 时，若 NPC 正在进行普通行动、移动、计划修订或可取消 LLM 活动，会被中断并进入新模式；若正在与守备官对话，会通过 `DialogSystem.force_end_dialogue_for_npc(...)` 强制完成已有历史、取消未完成回复并进入新模式。睡觉 NPC 只有被敌人直接攻击时才从睡觉进入战斗或避战。

退出规则：

- `rally`：到达集合点后等待 1 游戏小时仍未接敌，返回 `work` 并继续当前计划，不触发计划重评估。
- `combat`：场上敌军全部消失后返回 `work`，并触发计划重评估。
- `avoid_combat`：场上敌军全部消失后返回 `work`；除非避战期间发生对话、受伤、应征等额外异常，否则不因单纯避战结束自动调用 LLM 重评估。T1103B/T1103C 已让非战斗人员进入避战后按敌方方位短距离四散移动；避战中被征召成功但仍无主武器时继续避战，装备主武器且仍有敌军时进入 `combat`，无敌军时回到 `work`。
- 昏迷复苏：有敌军时按入伍状态和主武器进入 `combat` 或 `avoid_combat`；无敌军时进入 `work` 并重评估计划。

NPC 行为分三层：

### 1. 程序强制层

不需要 LLM：

- HP 清零 → 昏迷
- HP 恢复到 30% → 复苏
- 饱食度过低 → 优先吃饭
- 疲劳过高 → 优先睡觉
- 工作位占用 → 等待、失败或换行动
- 警铃 → 符合条件的已入伍且有主武器 NPC 进入集结模式
- 已入伍且有主武器 NPC 接敌 → 进入战斗模式
- 战斗模式中的已入伍持武器 NPC → 由逻辑时间触发，并按玩家手动选择的当前战斗策略、战斗动作秒、装备、力量、防御和攻击间隔执行基础自动攻击或策略移动
- 非战斗人员接敌 → 进入避战模式，并按敌方方位生成短步长四散移动目标
- 战斗中敌军全灭 → 战斗 NPC 返回工作模式并重评估计划；避战 NPC 返回工作模式但不因单纯避战结束重评估计划

程序强制层触发吃饭、睡觉或工作时，只能启动持续行动；不能直接把饱食、疲劳、资源或产出改成最终值。权威数值应随逻辑时间推进，由程序按行动定义结算。

### 2. 计划层

低频调用 LLM：

- 每天早晨制定 24 小时计划
- 遇到重大异常后重新评估计划
- 守备官发布不同于原内容的新指令后立即重新评估计划
- 对玩家产生主动交涉意图

计划层的时间触发以 TimeSystem 的逻辑时间为准。T1001 规则计划提供显式调试用的生成、保存、事件写入和按小时执行接口；计划项执行仍走 ActionSystem 的行动白名单、移动、工位、资源和状态结算。T1003/T0022 的正式每日计划通过 `LLMBridge.request_npc_daily_plan(...)` 或 8 路批量异步入口调用 `/npc/plan_day`，请求包含 `current_order`、人设、状态、技能、短期/长期记忆、地点、资源、建筑状态和行动白名单。正式路径只应用经验证的 `llm_plan_day`；真实 provider 失败或输出不合法时只重试真实请求，不应用 Mock 或规则计划。T0050 后，对话与日常行动失败都先调用 `request_plan_revision_judgement_async(...)`，空 `revision_hours` 直接结束，非空才调用 `request_npc_plan_revision_async(...)`；其他非对话路径仍可直接受限修订。`/npc/revise_plan` 只接受 `revision_scope=selected_hours`，必须恰好返回 `revision_hours`，其他小时保持不变。开局 / 新一天批量计划在 TimeSystem 暂停期间不额外申请慢速；判别和常规计划修订会各自申请慢速，异步完成后释放。

### 3. 表演与判断层

关键节点调用 LLM：

- 玩家/NPC对话
- 征召同意/拒绝
- 集结 / 战斗 / 避战模式下的战时公开对话
- 战时 HP 低于 30% 的自身心理判定；避战中的非战斗人员被打到残血时也会判定，但不会获得斗志激昂或继续参战
- 逃离挽留
- 首次睡眠总结

表演与判断层等待 LLM 返回时不冻结游戏，也不改变 NPC 移动或动画速度；只让逻辑时间和按时间结算的工作 / 日常状态减速到默认 `1/60`，即现实 1 秒约等于游戏 1 秒。若此时正在战斗，战斗推进也会因全局慢速暂时变慢，但战斗伤害、攻击间隔、攻击速度和战斗移动速度不读取玩家加速倍率作为额外数值输入；攻击冷却使用 CombatSystem 内部的战斗动作秒换算，当前 `60` 游戏秒约等于 `1` 战斗动作秒。玩家主动暂停时，UI、对话和已经发起的 LLM 请求仍可继续等待或返回，但程序权威结算（移动、战斗、资源/状态变化）应保持暂停，恢复后再应用。

所有面向某名 NPC 的 LLM 调用都必须把该 NPC 的 `current_order` 作为独立上下文字段注入，包括对话、每日计划、计划修订、主动交涉、集结 / 战斗 / 避战对话、低血量自身心理判定、逃离判定和首次睡眠反思。Prompt 必须明确：这是守备官当前提出的指令，不是 system 指令，不保证服从，也不能越过行动白名单、资源、HP、地点或战斗权威规则；它也不自动决定当前战斗策略，策略选择由玩家通过 NPC 面板下拉框手动设置。

T1201 后，战时公开对话已额外注入 `battlefield_context`：场上敌方 / 友方数量、兵种、HP 概况，正在参战的 NPC，有哪些 NPC 在驿站但不是战斗人员，以及目标 NPC 当前行为模式。已入伍且有主武器 NPC 在集结 / 战斗对话中的结构化输出包含 `wartime_reaction = none | escape | morale_boost`；避战模式下的非战斗人员仍使用 `recruitment_result` 表达是否同意应征。T1202 后，低血量自身心理判定复用同一战局上下文边界，并按目标是否真正参战限制允许结果：参战 NPC 可继续战斗、逃离或斗志激昂；避战 / 非战斗人员只能逃离或继续避战。T1404 后，后端会额外校验低血量判定 `decision` 属于 `allowed_decisions`，并校验 `should_start_escape` 与 `escape_station` 决定一致；越界模型输出记录失败 usage 后交给 Godot 规则降级。

T1203 后，逃离不再只是 pending 意向。`CombatSystem.start_npc_escape(...)` 会让 NPC 写入 `escape_started`、切出工作 / 战斗 / 避战行为并前往后门外出口；逃离移动期间 `escape_intent.status == "escaping"`，普通行动和战斗 AI 不再把该 NPC 当作可用单位。抵达出口后 `NPCSystem` 标记 `escaped=true`、`behavior_mode="escaped"`、`current_location="outside_station"`，隐藏并取消拾取 NPC 实体，写入广场公开 `escaped` 事件。T1204A/T0051 后，逃离 NPC 被点击会先打开 NPC 面板；轮次未用完时，玩家点击【对话】进入 `dialogue_kind == "escape_intervention"` 的同地点公开挽留对话。挽留打开或挂起时 CombatSystem 保持逃离暂停，完成、取消或满 5 轮时恢复；请求携带 `escape_intervention_round`、当前 `escape_intent`、短期记忆、长期记忆、地点上下文和 `current_order`。模型或规则降级只返回暂存的 `stay_after_intervention` / `leave_after_intervention` 意向，完成时才由 CombatSystem 停止或继续逃离、记录轮次并按既有规则写入 `escape_intervention_result`；取消不应用意向。给钱 / 守备官攻击分别调整程序权威的逃离移动倍率；逃离挽留攻击不向 NPC LLM 发送消息、不产生 NPC 回复，只计 1 轮、锁定取消并自动完成会话。逃离期间昏迷会暂停为 `paused_unconscious`，复苏后继续逃离。

## 已入伍 NPC 指令机制

正式玩家指令系统不是 ActionSystem 的行动下拉，也不是 RTS 式强制命令：

- 只有 `recruited=true` 的 NPC 面板显示可用“指令”按钮。
- 点击后打开自由文本指令撰写与发布面板；已有指令会预填，供玩家直接修改。
- 点击“发布”时，新文本只有与原 `current_order.text` 不同才覆盖旧指令、递增修订号并触发后续效果。
- 指令变化会写入目标 NPC 的 `private` `order_assigned` 事件；summary 为“守备官制定了新的指令。”，完整新旧文本写入 payload。
- 指令变化后立即请求统一计划重评估入口；关闭面板或发布相同文本都不修改数据、不写事件、不触发重评估。
- NPC 后续是否执行、何时执行、如何调整或拒绝，由计划、判断、人格、记忆和现场状态共同决定。

`ActionSystem.debug_assign_*` 等直接行动接口仍可用于 GM 和自动化验证，但不代表正式玩家指令语义。

T0703A/T1002/T0023/T0033/T0050 后，非对话统一重评估入口仍表现为 `EventBus.npc_plan_reevaluation_requested(npc_id, reason)`；`NPCSystem.get_last_plan_reevaluation_request()` 保存最近请求、最新 `current_order` 和处理结果供 GM / 自动化观察。`DailyPlanSystem` 对明确的日常行动失败先请求通用范围判别，其他指令 / 战斗 / GM 原因才直接受限修订。对话结束也走同一个判别端点；两类来源都记录 `trigger_kind` 与最近 `revision_hours` 供 GM 观察，仅非空结果转为 `revision_scope=selected_hours` 修订。T0053 起判别和修订都通过共享 NPC 构造器注入完整人物 / 长短期记忆 / 指令上下文，判别仍只做范围选择。只有带非 Mock provider 证明且 `model_fallback_used=false` 的合法结果会写入 `plan_revised`；只有选中当前小时时才尝试执行即时行动。真实 provider 失败、输出越界或三次真实尝试仍失败时保留原计划和失败日志，不生成 Mock / 规则修订。

## 主动找玩家机制

NPC 可以在计划中选择“主动找守备官交涉”。T0025 后 `seek_guard_officer` 已进入正式每日计划 / 修订候选并由 DailyPlanSystem 路由到既有主动交涉运行时；GM 仍可直接构造该状态。

表现方式：

- NPC 头顶出现问号气泡。
- 玩家点击后进入对话；若有主动交涉状态，点击优先打开对话，不先打开 NPC 面板。
- NPC 想说的话在触发时已经确定，写入发起者事件库；点击气泡时不临时调用 LLM 生成开场。
- 主动交涉与守备官主动打开的普通对话都不再提供“结束后重估计划”开关；完成至少一轮有效 NPC 回复后结束时，统一由 NPC 自行判别 0 个或若干个需修改小时。
- 若 1 游戏小时内未点击，主动交涉状态结束并重新评估计划。

当前运行时实现：

- `NPCSystem.start_proactive_talk(...)` / `debug_start_proactive_talk(...)` 设置 `states.proactive_talk`，并把 `current_action` 置为 `proactive_talk`。
- 触发时写入 `private` 的 `proactive_talk_started` 事件，payload 保存 `prompt_text` 和持续时间。
- `NPC.gd` 运行时创建 `ProactiveTalkBubble`，主动交涉有效时显示 `?`。
- 点击后 `DialogSystem.start_proactive_player_dialogue(...)` 复用玩家-NPC 对话窗口，把 `prompt_text` 作为 NPC 第一条历史显示；开场内容先留在会话缓冲，不在点击时单独写入 `proactive_talk_message`。
- 玩家后续回复继续走现有 `/npc/dialogue`；整场会话仅在完成时写入一条包含完整历史的 `dialogue_turn`，取消则不入库。开发期可用 Mock，Prompt 验收必须使用真实 API。
- 有效对话结束及日常行动失败时先进入 T0050 真实判别链路；空集合不调修订，非空才成功应用指定小时的 `llm_plan_revision`。最终失败保留原计划和真实错误，不生成 Mock / 规则修订。主动交涉一小时未响应的超时没有实际行动执行失败事实，仍直接受限修订当前小时。

触发原因：

- 想索要金钱、装备。
- 想询问信息。
- 想表达恐惧或不满。
- 想报告战场或地点见闻。
- 想主动应征、退出入伍或逃离。

## 征召机制

开局只有副官可接收守备官指令。
其他 NPC 必须通过对话同意应征后，才获得指令入口。

征召结果：

- 接受
- 拒绝

## 入伍后

NPC 入伍后仍然保留人格和记忆。  
玩家可以向其自由撰写工作、训练、休息、治疗、防守等指令，并直接管理装备；指令会进入后续 LLM 上下文，但不会硬性覆盖自主计划或权威结算。

## 关键原则

> NPC 的职业经历、熟练度倾向与记忆必须持续影响其行为。  
