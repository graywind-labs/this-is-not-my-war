# CURRENT_STATE.md

> 本文件描述“当前项目真实状态”。每次完成任务后必须更新。
> 不要在这里写未来愿景；未来内容写入 `TASKS.md` 或模块设计文档。

## 当前版本

版本：`0.0.152-npc-memory-diegetic`

T0061 当前状态：8 名 NPC 的正式档案现以 `background_story / personality / desires / fears / boundaries / speech_style` 等稳定人设字段维持差异，不再保存或注入 `signature_lines`。人物背景弹窗与六类正式 NPC LLM 请求共用的身份上下文都已移除“代表性表达”；`speech_style` 只描述宽松、稳定的表达习惯，不再把 NPC 限定在几句样例台词里。

每名 NPC 仍有“往昔·来站前 / 往昔·初到驿站 / 往昔·近日”3 篇第一人称日记和 25 个知识主体。前两篇现改为宏观人生切片：“来站前”交代身世、职业形成、离开旧生活的原因和到站时间，“初到驿站”交代接手的工作及当时已经在站的人。八个视角拼成一致的到站顺序：艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜；“往昔·近日”继续保留 T0060 的微观驿站日常，并严格位于守备官传达敌情之前。

知识图谱仍覆盖 15 座正式建筑、其余 7 名 NPC、守备官和 2 个个人故事主体。每人的守备官主体只保留统一技术关系键 `role`，内容仅说明统筹驿站防务、警戒与危急时的人手安排，不预写“尚待观察”、信任、敌意、服从或品格判断。建筑中文 `relation_label / value_label` 已改为人物在世界内会自然表达的常识；本职建筑更细，其他建筑更粗，不再把初始位置数、升级数值、槽位或结算流程直接写成规则说明书。

T0061 对知识技术值有一项受控迁移：当前程序尚未实现仓库容量、受击丢货或损失比例，因此 8 人各自唯一一条仓库认识的 `value` 统一改为 `central_storage_and_post_breach_attack_target`，只表达“全站库存以仓库账为准，以及城门失守后敌人按当前目标优先级进攻仓库”；其余知识技术 `value` 不变。当前全图共有 222 条关系记录，222 条 `confidence / day / time` 均完整保留。仓库容量与受击资源损失闭环只登记为后续 T0062，本轮没有把未实现机制写回程序或 NPC 常识。

NPCPanel 的“知识”详情现在只向玩家显示中文主体、关系和值，不再显示“可信度”或“更新于……”；初始 / 运行态知识记录与 GM `long_memory <npc_id>` 仍完整保留 `confidence / day / time`，后端 `KnowledgeGraphPatch.confidence` 和反思日期合同也未改，Godot 继续在写入时记录日期与时间。该变化可直接在 `Main.tscn` 的“背景 / 日记 / 知识”入口验证，因此没有新增 GM 命令或按钮。

对话、每日计划、计划修改判别、正式修订、战时心理和首次睡眠反思六类 payload 继续读取唯一规范初始长期记忆，并继续把结构化日记投影为带标签的 `list[str]`：开局种子使用“往昔·来站前 / 往昔·初到驿站 / 往昔·近日”，游戏内后续日记使用“第 N 天 HH:MM:SS”。六类身份上下文现在都只携带宽松 `speech_style`，不携带固定样例句；目标长期记忆的去重和 NPC 私人记忆隔离边界保持不变。

T0061 最终验收：静态文案、六份 Prompt、后端 Schema、Model Adapter Mock 和相关 endpoint 全部通过；`verify_npc_character_profiles.gd`、`verify_npc_initial_long_memory.gd`、`verify_npc_panel_state.gd`、`verify_daily_reflection_system.gd`、`verify_gm_panel.gd` 5 个 Godot 专项全部通过。最终六类最大 payload 字符数分别为 `battle_judgement=32057 / daily_reflection=29242 / dialogue=48330 / plan_day=47118 / plan_revision_judgement=50053 / revise_plan=49952`。项目 headless smoke 通过，仅保留既有退出期 `ObjectDB instances leaked at exit` 警告。

真实 DeepSeek `deepseek-v4-flash` 在禁止自动 Mock fallback 的配置下完成 3 次调用，0 失败，全部 `fallback_used=false`。Godot MCP 4.0.1 / Godot 4.6.2 运行态确认 8 人均为 3 篇种子日记，守备官关系键统一为 `role`，222 条原始知识元数据完整，8 条仓库 `value` 均为 `central_storage_and_post_breach_attack_target`，玩家知识弹窗不显示可信度 / 更新时间；莉娜实际知识弹窗显示 27 条关系，编辑器错误日志为空。

T0060 的自然直白中文、人物差异、24 篇日记结构和 25 主体图谱仍是现行内容基础；其中固定代表性表达、前两篇的微观写法、守备官“开放评估”措辞和玩家知识面板元数据展示已经由 T0061 取代。T0060 当时的真实 DeepSeek、Mock、Godot 和 MCP 验收记录继续作为历史记录，不代表 T0061 的最终验收结果。

T0060 验收：文案静态检查、六份 Prompt、后端 Schema、Model Adapter Mock、人物档案、初始长期记忆、首次睡眠反思、GM 与项目 headless / Godot 专项均通过。真实 DeepSeek `deepseek-v4-flash` 在 `LLM_FALLBACK_TO_MOCK=false` 下完成莉娜、欧文、布鲁诺 3 条新记忆路径，3 次调用、0 失败且全部 `fallback_used=false`。Godot MCP 4.0.1 / Godot 4.6.2 冻结运行确认 8 人均为 `diary=3 / subjects=25 / prefix=true / recent_clean=true`，编辑器错误日志为空，验证后已停止场景。

T0059 保留的当前技术基线：`data/npc_initial_long_memory.json` 继续作为独立种子数据源；8 人 `background_story` 只保存职业观察方式、稳定价值尺度与根本矛盾，`npc_profiles.json` 的运行态日记 / 图谱字段保持空占位。`NPCSystem` 在生成实体前严格校验 NPC id、日记、图谱结构和非空关系，再把种子深拷贝到运行态；首次睡眠反思仍追加日记并按 `subject + relation` 替换知识键。T0059 当时的人物故事、句子和真实模型问答锚点均已由 T0060 全量文案替换，不再代表当前数据。

T0058 当前状态：所有 NPC 中心正式 LLM 请求共用的顶层 `station_context` 新增 `basic_resource_reserves`，每次构建 payload 时从 ResourceSystem 当前运行态读取粮食、餐食、木材、石料和铁。Schema 严格要求这 5 项各出现一次；计划 / 判别 / 修订旧有的 `current_resource_states` 也同步收窄为同一白名单，不再向模型公开第纳尔、酒、聚合装备、具体装备、器械、马匹或其他库存。该上下文只提供只读事实，不授予 LLM 资源结算权。

T0058 建筑升级常识：`station_rules` 当前为 6 条，新增“建筑升级缓慢推进，成员可以协助正在进行的升级以加快进度”。六份正式 Prompt 都解释资源白名单与升级边界；日计划 / 修订只有在动态 `allowed_actions` 真正出现 `assist_upgrade` 目标候选时才可选择，并被要求认真考虑该行动，没有升级作业时不能自造目标。GM `station_context` 只读入口会显示 5 项公开资源和 6 条规则。

T0058 验收：Schema、Mock、endpoint、六份 Prompt、Godot 六类动态 payload、计划行动目录、GM 和项目 headless 验证通过。真实 DeepSeek `deepseek-v4-flash` 准确回答粮食 23、餐食 4、木材 17、石料 9、铁 6，并选择“协助升级工械坊”作为 24 小时计划项，均 `fallback_used=false`。Godot MCP 4.0.1 / Godot 4.6.2 冻结运行确认粮食 18→20 后下一次上下文立即刷新，`assist_upgrade` 技术值为英文、显示名为“协助升级建筑”，新增运行无编辑器错误。

T0057 当前状态：建筑开始升级时，`ActionSystem` 会区分真正依赖该建筑的 pending / active 行动与单纯停留 / 普通移动。正在前往建筑执行活动的 pending 行动会停止移动，正在建筑内执行的 active 行动会释放位置并退出到广场；两者最终统一写为 `<action_id>_failed_building_upgrading`，上下文保留行动 / 建筑、`condition=upgrading`、pending / active 阶段、移动前地点和“建筑正在升级”中文摘要。`DailyPlanSystem` 将该原因规范为 `target_unavailable`，进入 T0050 的 `trigger_kind=action_failure` 范围判别；非空结果继续进入精确阶段修订，不再只中断后停在原地。

T0057 验收：新增 `verify_building_upgrade_action_failure.gd`，覆盖食堂路上 pending 失败与菜园内 active 失败、位置 / 移动清理、中文失败上下文、第一层判别和非空后的第二层修订。建筑位置、建筑修复升级、服务依赖、日计划重估、T0050 两阶段、基础行动、GM 及项目 headless 加载通过；真实 DeepSeek `deepseek-v4-flash` 的行动失败判别与精确修订均一次成功、`fallback_used=false`。Godot MCP 4.0.1 / Godot 4.6.2 冻结运行确认 active 菜园活动升级后退出到广场、结果与上下文正确，编辑器无新增错误。既有 GM “指定行动 / 升级 / plan_request”已能构造和观察完整链路，无需新增入口。

T0056 当前状态：栗风 / 灰鬃从成长 100% 改为刚达到成年阈值的 60%，开局自然 HP / 饱食上限随成长为 76 / 80，仍可在有效 `work_stable` 照料下成长到 100%。HorseSystem 公开快照新增拆分后的 `base_hp` 与 `extra_hp / extra_hp_cap`，马厩卡片分别显示“基础 HP”和“照料额外 HP”，不改变权威总 HP 与额外 HP 先承伤规则。

T0056 繁育反馈：每匹成年在厩、非冷却马独立保存 `breeding_probability`。至少两匹候选且有效养马人在岗时，每个完整照料分钟按基础 0.005% × 养马能力 × 马厩等级增长概率，再用累积概率执行最多 `N - 1` 次判定；单分钟最多出生一匹。成功后本次成年候选概率归零并进入 1440 游戏分钟冷却，冷却期间概率保持 0，但成长和额外 HP 继续推进。马厩卡片显示两位小数概率与冷却剩余时间；功能可直接从主场景马厩面板验证，未新增 GM 入口。

T0055 当前状态：共享 `station_rules` 的持续活动 / 周期结算常识仍有效。NPC 被明确告知：工作、照料、训练、治疗和制造等活动只在成员持续参与的有效时间内推进，并在相应周期完成后由驿站实际记录结算产出或结果；成员离岗、改做他事或被打断后，活动不会在无人持续参与时自行继续产出，未完成进度是否保留仍以具体程序记录为准。真实 DeepSeek 菜园专项明确回答离岗后进度停止、无人接手就没有产出，`fallback_used=false`；T0058 后当前规则总数为 6。

T0054/T0058 当前状态：所有 NPC 中心正式 LLM 请求共用的顶层 `station_context` 现为 `setting_summary / resident_roster / building_roster / work_mode_actions / basic_resource_reserves / station_rules`。在站人员、建筑、行为和五项公开资源都从当前权威系统动态生成；`data/station_context.json` 只保存精简世界内简介与当前六条驿站规则。完整行为目录只说明世界能力边界；每次请求的 `allowed_actions / allowed_decisions`、NPC 状态、资源、建筑与战场事实继续由程序权威限定。

T0054 调用与验收：对话、每日计划、计划修改判别、正式修订、战时心理判定、首次睡眠反思六类 payload 与对应 Prompt 都只注入一份上述上下文。Schema / Mock / endpoint / Godot 专项、GM `station_context` 只读观察入口与项目 headless 加载均通过；真实 DeepSeek `deepseek-v4-flash` 已完成六条业务路径，均 `fallback_used=false`。T0058 后冻结运行主场景读取到 8 人、15 建筑、22 种工作行为、5 项公开资源和 6 条规则。

T0053 当前状态：日计划派发的 `talk_to_npc` 会在 pending options 记录来源日 / 小时、计划版本和原计划项。发起者等待目标制定 / 重估计划期间，`ActionSystem` 会在逻辑时间推进、目标计划结束重试和 `DailyPlanSystem` 整点派发前复验发起者当前计划；若当前项已不再是与同一目标对话，则释放双方预约、停止旧接近移动，并写入 `talk_to_npc_failed_plan_superseded`。失败上下文同时保留原 `failed_plan_item`、当前计划项、原 / 当前小时与版本、目标和是否跨小时，随后进入 T0050 的“判别 → 按需精确修订”链。GM / 测试直接调用的非日计划对话没有 `plan_action_source=daily_plan`，不会被计划阶段变更误杀。

T0053 LLM 上下文：`PlanRevisionJudgementRequest` 现继承 `StationAwareNPCRequest`，第一层判别与正式日计划 / 第二层修订一样携带动态 `station_context` 和统一 `npc`：职业与人格、欲望 / 恐惧 / 底线、当前状态、`current_order`、亲历 / 见闻短期记忆、包含知识图谱和日记的 `long_term_memory`、地点上下文；同时保留失败事实、原计划、行动候选及实时建筑 / 资源状态。第二层继续原样接收第一层的 `failure_type / failure_summary / failure_context / failed_plan_item`。低血量参战 / 避战 / 逃离心理判定也复用同一完整 `npc` 上下文和战场事实。真实 DeepSeek `deepseek-v4-flash` 已完成对话判别、行动失败判别、精确修订和战时心理路径，全部一次成功且 `fallback_used=false`。

T0052 当前状态：NPC 的每日计划生成、计划修改判别和计划修订统一以 `llm_activity.kind=plan` 标记为计划临界阶段。该状态活动时，NPC 面板“对话”按钮使用 Godot disabled 半透明样式，悬停提示“NPC正在思考”；`DialogSystem` 的草稿创建、激活和首次消息 / 攻击权威入口均返回 `npc_planning`，不会提升 dialogue epoch、取消计划请求或打断原行动。计划状态清除后，按钮随 `npc_state_changed` 自动恢复。

T0052 自主对话边界：日计划仍可把并行制定计划的 NPC 作为稍后交谈目标，但即时失败修订只提供当前可执行目标。已有 `talk_to_npc` 动作遇到目标仍在制定 / 重估计划时，发起者可继续接近，到达后保留 pending action、原开场白和双方预约，不写行动失败，也不触发失败型计划重估；目标计划活动结束后由状态信号延后一帧自动续接既有邀请流程。目标昏迷、逃离、离开工作模式或进入深睡 / 战时不可打断状态时，仍按原规则失败并清理预约。Godot 自动化 / MCP 已覆盖锁定与续接，真实 DeepSeek `deepseek-v4-flash` 邀请接受 / 拒绝及正式 NPC-NPC 对话复验通过，`fallback_used=false`。

T0051 当前状态：主界面常用弹窗已统一支持从顶部栏拖动并限制在可用视口内，覆盖对话、NPC、建筑、指令、公告牌、商人、NPC 详情和 HUD 库存详情。守备官-NPC 对话拆为“完成 / 取消 / 挂起”：玩家消息发送即显示；完成在等待中也会取消回复、以守备官最后一句结尾、整场一次入库并触发 T0049/T0050 判别；取消不入库、不广播、不判别，并恢复合法原行动；挂起保留会话 / 等待 / NPC 行动占用，头顶显示橙色恢复气泡、NPC 面板对话按钮显示橙点，2 游戏小时后自动取消。攻击先行权威结算且使取消置灰，含攻击的挂起会话超时自动完成。

T0051 事件边界：守备官-NPC 的应征、战时反应和逃离挽留结果先暂存在会话，只有完成时才应用；取消因此不会留下结构化副作用。`dialogue_turn` 在完成时提交整场 `dialogue_text`，可合法以无 NPC 回复的守备官消息结尾。NPC-NPC 自主对话仍逐轮写事件。专项自动化已覆盖拖动、即时消息、完成等待请求、取消不留痕、攻击锁、挂起 / 恢复、气泡 / 橙点和普通 / 攻击超时；真实 DeepSeek 对话调用已复验 `provider=deepseek`、`model=deepseek-v4-flash`、`fallback_used=false`。

T0050 当前状态：日常计划行动失败已与对话后的计划修改统一为“两段式”链路。第一层调用真实 `/npc/plan_revision_judgement`，通过 `trigger_kind=action_failure` 读取程序权威的失败计划项、失败类型 / 摘要 / 必要上下文、原 24 小时计划和工作阶段下限，先返回 0 个或若干个精确 `revision_hours`；T0053 起该层同时读取与日计划 / 正式修订一致的人设、状态、长短期记忆、地点、指令、驿站、候选和实时环境上下文。空集合保留原计划，不再调用修订。非空时第二层继续携带同一完整 NPC / 驿站 / 记忆 / 指令 / 行动候选 / 失败上下文，但只允许 `/npc/revise_plan` 输出第一层选中的小时。持续工位、目标或资源阻塞可同时选择当前失败阶段和受影响的未来阶段；若失败工作将改成非工作且原计划已在最低工作阶段数，判别层会把最少的未来补偿工作阶段纳入修改范围。同一阶段的重复状态通知会去重，但失败缓存会在新小时清空，因此相同冲突在后续阶段重新发生时仍会再次判别。守备官新指令、战斗结束 / 复苏、主动交涉超时和 GM 手动触发等不是日常行动失败的来源继续直接受限修订。

T0049 当前状态：所有实际发生的守备官-NPC 与 NPC-NPC 对话结束后，目标 NPC 都先通过真实 `/npc/plan_revision_judgement`（旧 `/npc/dialogue_plan_revision_judgement` 仅保留兼容），结合本轮完整对话和原计划快速返回需要修改的精确小时集合 `revision_hours`。空集合表示 0 个阶段，不调用 `/npc/revise_plan`；若对话确实打断了仍有效的当前小时行动，则恢复原行动。非空集合才进入第二次完整上下文计划修订，并将输出严格限制在这些小时；未选小时保持不变。NPC-NPC 对话由双方分别判别。对话窗内已经发生的攻击也作为本轮内容进入判别，即使攻击回复被取消或逃离攻击没有 NPC 回复，HP / 事件事实都不撤销。守备官对话窗已移除“结束后重估计划”开关，由 NPC 自行判断；事件库 / 见闻库详情首次打开默认滚到最底部，已打开时刷新仍保留玩家当前位置。T0048 的 `remaining_day` 全量重排仅保留为历史方案，已由本任务取代。

T0049 时序补充：所有双目标 NPC-NPC 对话都会在双方判别前预注册同一会话组的当前计划派发屏障，不以跨小时为条件；只有双方第一层判别和各自必要的第二层修订都进入终态后，才按计划依赖顺序统一放行。玩家-NPC 对话跨过小时边界时，也会把目标 NPC 的新小时派发延迟到判别 / 必要修订链终态，避免一方新行动推进对话 epoch 后让另一份合法响应过期。T0053 起第一层除本轮对话、原计划和会话元数据外，也使用与其他 NPC LLM 阶段一致的人设、状态、长短期记忆、地点、当前指令、驿站和现实条件上下文，但仍只输出修改范围，不制定行动。

T0049 验收补充：旧 generation 的 D1 判别仍在 HTTP 返回途中时，不再阻塞已经完成的 D2 会话恢复；对话修订后排队的普通失败 followup 在启动和回包终态前持续阻塞旧行动重派，之后才消费或放行 ready marker。Python 判别 / 修订 / Prompt / Mock / usage 专项和 Godot 计划、对话、UI 专项均通过；真实 DeepSeek `deepseek-v4-flash` 的修改 `[14]`、严格第二层 `[14]` 与不修改 `[]` 均一次成功且无 fallback。Godot MCP 4.0.1 冻结运行最新主场景 8 帧无警告，旧强制重估节点不存在，编辑器错误日志为空。

T0050 验收补充：Python Mock / Schema / Prompt / endpoint 专项验证了行动失败的非空 `[10, 14]`、空集合和非法缺失失败项；真实 DeepSeek `deepseek-v4-flash` 判别返回 `[8, 14]`，第二层严格只修订 `[8, 14]` 且无 fallback。Godot 专项验证空判别不启动第二层、非空判别只修改所选小时、第一层等待会阻塞旧计划重派、新阶段同名失败可再次判别；真实资源不足路径完成判别、修订、`plan_revised` 事件和慢速释放，并通过既有计划、对话、工位、诊疗和 GM 回归。

T0047 当前状态：已修复 BuildingPanel 偶发点不开和未点击却开始升级的同一根因。旧透明测量协程直接等待 `VBoxContainer.sort_children`，在该容器没有再次排序时会永久挂起，使面板保持 `visible=true / alpha=0` 并继续接收鼠标；后续世界点击可能实际落到透明的修复 / 升级按钮。现在每个测量阶段改为最多 4 帧的代次校验逐帧采样，所有退出路径都会收尾；透明阶段用 `mouse_behavior_recursive=DISABLED` 禁用整棵面板输入，修复 / 升级回调也会拒绝不可见或仍在测量的调用，完成显示后才恢复交互。

T0046 当前状态：首次睡眠反思的长期输出已收敛为“第一人称日记 + 替换式知识图谱”，`DailyReflectionResponse`、真实 / Mock 模型输出、Godot 存储和日记 UI 不再生成、保存、显示或回注独立 `memory_summary`；旧运行时日记中的同名字段会在规范化时剔除。知识图谱继续用稳定 `subject / relation / value` 技术值替换式存储，同时保存中文 `subject_label / relation_label / value_label`；NPC 知识详情优先显示这三类中文文本，并对 NPC、守备官、地点、常见关系、常见技术值和未知内容提供中文映射 / 保底，不向中文玩家暴露蛇形英文键或英文技术值。

T0046 LLM 上下文（已由 T0054 扩充）：所有携带 NPC 根本人设的请求 Schema 继承同一 `StationAwareNPCRequest`，并在请求顶层只注入一份必填 `station_context`；空在站名单同样拒绝进入业务调用。`LLMBridge` 每次从当前 NPC 运行态动态生成名单；`escaped=true`、`behavior_mode=escaped` 或 `current_location=outside_station` 的人立即除名。T0054 在这一基础上加入数据驱动建筑、工作模式行为和精简驿站规则，仍不在嵌套 speaker / target 中复制。

T0046 公告牌：`NoticeBoardPanel` 现为“通告 / 参考日程”双 Tab。两页打开时都从 `MemorySystem` 读取已发布状态，编辑只修改本地草稿，退出 / 关闭丢弃，只有“发布”才调用权威接口。参考日程支持开始时间、结束时间、内容的增删改与重叠校验；初始日程为 00:00-06:00 睡觉、06:00-07:00 早餐、07:00-12:00 工作、12:00-13:00 午餐、13:00-17:00 工作、17:00-18:00 休息／祈祷、18:00-19:00 晚餐、19:00-20:00 弥撒、20:00-22:00 休息／祈祷、22:00-24:00 睡觉。它始终携带“这是通用的建议日程，仅用作参考，不必严格按照这个日程；如有特殊事务，可以自行安排。”备注，不替换 NPC 个人计划。

公告牌的已发布通告和参考日程都保存在广场当前状态。变更分别生成 `plaza_notice_changed` / `plaza_schedule_changed` 并即时广播给当时在广场且可接收信息的 NPC；后来进入广场者从入场快照获得当前版本。`data/notice_board_defaults.json` 提供守备官口吻的初始战事通告、参考日程和备注；新游戏初始化时两条内容已预先写入全部初始在站 NPC 的见闻库。公告牌仍不是建筑，没有 HP、等级、工位、修复或升级数据。

T0040/T0044/T0045/T0047 当前布局：NPCPanel 使用 380-440px 单栏响应式布局，BuildingPanel 使用 360-420px 响应式布局；两者都由可见内容决定自然高度，窗口只提供上下 16px 的高度上限，并在尺寸变化时重新计算。BuildingPanel 在修复 / 升级高频刷新时保留该建筑上一次已测得高度，容器完成排版后再更新自然高度；首次打开或切换建筑时会在透明状态下完成有上限的逐帧测量，不暴露满高空面板，也不接收鼠标。建筑操作悬停框位于 `Main/UI` 覆盖层，不参与 BuildingPanel 最小尺寸计算。
状态：已完成 Godot 项目入口、低模驿站、基础经营/时间/地点/记忆/NPC 昏迷治疗闭环、T0043/T0043A 五建筑逐位置 / 团队效率 / 服务依赖中断 / 三类教堂活动 / 升级封闭 / 受损降效闭环、T0044 对话后原小时计划恢复与对象面板信息收敛、T0046 日记 / 中文知识图谱 / 动态在站场景上下文 / 公告牌双页闭环、T0801-T0808 职业工作产出与诊所治疗闭环、T0901 正式库存与装备系统、T0902 独立兵种判定、T0903 训练场与武器/骑术熟练度提升、T0904 通用熟练度经验 / 技能点与玩家分配力量 / 智力、T1001-T1005 每日计划/重评估/首次睡眠总结与长期记忆闭环、T1006 对话窗攻击与异步取消边界、T0052 计划临界阶段对话互斥与自主对话等待续接、T1101 敌人波次配置与正门外敌人调试生成、T1102 敌人目标优先级 / 移动 / 建筑和 NPC 攻击、T1103 警铃与入伍持武器 NPC 城门外集结、T1103A 统一 NPC `behavior_mode` 状态机、T1103B/T1103C 非战斗人员避战触发与短步长四散移动、T1103D 工作 / 战斗 / 避战模式互转事件降噪、T1104 基础自动攻击与伤害、属性/防御减伤、攻击间隔、敌人 HP 扣除和清零移除、T1104A 战斗数值脱钩玩家时间倍率与敌人在场 `x1` 时间上限、T1104C 移除围墙作为敌人攻击目标、T1105 不同兵种战斗策略与 NPC 面板手动策略下拉框、T1105A 战斗内避战策略距离边界修正、T1106 战斗开始 / 结束广场事件与清敌统计、T1201 战时公开对话心理结果、T1202 战时低血量自身心理判定、T1203 逃离驿站行为、T1204/T1204A/T1204B 逃离挽留五轮对话、NPC 面板入口、对话暂停逃离移动、逃离攻击无 LLM 回复且不写挽留结果事件、NPC 面板切换清理临时交互提示、T1205 战场公开信息综合验收、T1301 波次倒计时与按配置时间自动来袭、T1302 主厅摧毁失败条件 / 失败占位界面 / 停止正常推进、T1303 无可战斗人员失败条件、T1304 第 5 波胜利条件 / 胜利占位界面 / 结算快照、T1305 NPC 结局总结页面、T1401 DeepSeek / OpenAI-compatible 真实 Model Adapter、T1401A 成品 / Demo 默认关闭自动 mock fallback 与真实失败 usage 记录、T1402 NPC 对话 Prompt 模板与真实 API 验收、T1403 每日计划 Prompt 模板与真实 API 验收、T1404 战时公开对话与低血量心理 Prompt 真实 API 验收、T1405 首次睡眠总结 Prompt、替换式知识图谱更新和第一人称日记真实 API 验收、T1406 API 额度 / 调试信息面板、T1501 8 名 NPC 正式姓名、职业语气与个性台词、T1506 公告牌自由文本输入与广场广播、T1507 后门商人时段与买卖交易、T1508 围墙弩床 / 箭塔无部署者部署、自动攻击与表现层适配契约、T0035-T0039 分阶段具体物品制造、真实马匹生态 / 分配 / 战时骑乘、建筑特殊状态传播与右上角对象面板扩容、T0011-T0016 HUD / GM / NPC / 建筑 UI 修正、Godot MCP 4.0.1 运行桥接、Flask 后端与原生 HTTP `LLMBridge`；T0701-T0705 已接通对话、征召、已入伍 NPC 自然语言指令编辑、最新指令向共享 NPC LLM / Mock 上下文的统一注入、NPC 面板给钱/正式装备武器等非对话交互入口，以及 NPC 主动找守备官交涉的调试触发、问号气泡、点击进入对话和 1 小时超时消失闭环。尚未实现命中/格挡、其他职业特殊生产平衡，以及正式工程器械模型、动画与特效。

补充：T0044 的对话后恢复边界继续保留，但触发条件由 T0049 判别层统一决定：有效对话的 `revision_hours` 为空时，只有对话确实打断的运行时行动与当前小时计划行动一致、NPC 仍可行动且处于工作模式，DialogSystem 才让 DailyPlanSystem 重新派发原行动。该专用入口仅清除这次被对话打断的当前计划阶段签名；普通同小时重复派发、对话前本就空闲、判别选择当前小时、仅查看后关闭或高优先级模式都不会误恢复。

补充：T0044 UI 收敛后，马厩摘要写为“在厩 / 离厩”，逐匹只保留“分配”字段；未入伍 NPC 的武器、盔甲、马匹和战斗策略禁用控件会提示需先应征入伍。事件库 / 见闻库大号详情与小框一样只显示时间和摘要，内部结构化字段继续供系统 / GM 使用；T0049 起详情首次打开会定位到最底部的最新记录，打开期间刷新则保留当前阅读位置。对象面板刷新不再先显示最大高度空白区，修复 / 升级悬停框也不会撑高 BuildingPanel。

补充：T0045 后 CameraRig 不再每帧轮询全局物理按键，而是跟踪当前窗口收到的 WASD 按下 / 释放事件；窗口失焦会清空平移按键并取消中键拖拽，文本输入控件聚焦时不移动镜头。力量 / 智力点击分配仍由 NPCSystem 权威扣除技能点，但 `attribute_improved` 世界内摘要改为 NPC 通过锻炼体力 / 脑力提高对应能力，不再写“守备官分配”。

补充：T0025/T0029/T0030 后，正式日计划与行动失败修订可选择带精确 NPC 目标的 `talk_to_npc`。发起者会追踪目标、预定双方；到达后先用独立 `/npc/dialogue` 邀请判定让受邀者选择接受或拒绝，决定前不打断受邀者当前工作、不释放其工位。接受后才让双方进入 `talk_to_npc` 并自动轮流回复；邀请开场与接受回复进入历史但不计正式轮次。NPC-NPC 正式会话不再有 3 / 5 轮程序硬上限，`max_rounds=0` 明确表示无限制，`current_round` 与 `soft_round_threshold=5` 只作为 LLM 收尾参考：事情谈完即可自然告别并输出 `should_end_dialogue=true`，第 6 轮起无紧急 / 必要事项时应告别结束，有必要则可继续。任一方输出结束标记后，该方 `reply_text` 先作为最后一句写入历史 / 事件，随后直接结束且不再调用另一方 LLM。T0049 起，无论邀请拒绝还是正式会话结束，只要存在实际对话内容，双方都会基于各自原计划独立调用判别层；`revision_hours=[]` 保持原计划，非空才各自修订精确选中小时。即时修订会排除已有对话、接近预定、当前计划 / LLM 活动和非工作行为模式的目标，计划版本、同一时段单次派发签名、单后继队列与连续 3 次落地失败上限共同防止重复行动、迟到覆盖和无限修订；24 小时计划按每项声明的 `hour` 建表，模型数组乱序不会再交换行动时段，重复 / 越界小时会被拒绝。后端和 Godot 双层校验 NPC-NPC `replyer_id` / `response_kind` / 邀请阶段 / 软轮次字段。真实 DeepSeek 已验证邀请接受、邀请拒绝和第 6 轮非紧急收尾，均为 `reply_to_npc`、`fallback_used=false`；真实正式开局复验仍为 8/8 成功、峰值并发 8、0 fallback，全部来源为 `llm_plan_day`。

补充：T0041 后，所有 `/npc/dialogue` 非计划请求都必须携带非空 `allowed_actions`。Godot 直接复用每日计划的动态候选构造器，因此行为项只维护在 `data/action_defs.json` 及其运行时目标扩展链路中；对话 Prompt 只把候选当成“能尝试 / 列表外当前做不到”的能力边界，不生成计划、不声称已执行。当前覆盖玩家-NPC 与 NPC-NPC 两类关系、共 7 个 Prompt 子上下文：日常、集结、战斗、避战、逃离挽留、NPC-NPC 邀请、NPC-NPC 正式回复；征召、主动交涉后的回复和普通惩戒攻击回复复用同一玩家-NPC 构造器。Godot 专项确认 7/7 上下文与日计划候选一致，当前测试状态下为 33 条；真实 DeepSeek 玩家-NPC 与 NPC-NPC 问答都确认布鲁诺能加工餐食、不能骑飞龙，6 次整体验收调用无失败、无 fallback。

补充：T0042 后，NPC 面板顶部姓名右侧提供“背景”按钮；T0061 起，共用详情弹窗展示外貌、背景故事、职业背景、性格、欲望、恐惧、底线、说话风格和能力，不再显示代表性表达。弹窗与 `LLMBridge` 都通过 `scripts/core/NPCPromptProfile.gd` 从当前 NPC 档案构造同一份 `npc_setting`，没有独立 UI 背景文案；切换 NPC 时已打开详情会刷新为新档案。该入口只读且可直接在主场景验证，不新增 GM 操作，也不产生 LLM 调用。

补充：T0043 后，小教堂固定祭坛 1 + 祈祷席 10，小诊所初始诊疗位 1 + 病床 2，训练场初始教官位 1 + 训练位 2，食堂初始灶台 1 + 固定用餐席 10，宿舍固定床位 10。诊疗位 / 病床、教官位 / 训练位和灶台可按逐级配置扩容；固定位置不扩容。吃饭、睡觉、祈祷、主持弥撒、坐诊 / 治疗和执教 / 受训均自动申请同类型第一个空位，满位返回结构化失败；普通祈祷不依赖神父，`lead_mass` 对所有 NPC 可见但只有具备“主持弥撒”能力者可执行。全部在岗医生共同提高全部病床恢复，全部在岗教官共同提高全部训练位成长。升级有成本和时长，开始即封闭建筑、清退人员并中断 / 释放位置；完成后一次应用 Max HP、位置和活动效率奖励。建筑受损按 HP 单调降低实际活动效率。BuildingPanel 逐位置显示名称与占用，并显示精确效率；MemorySystem 对外传播效率分档，室内按位置 ID 传播增删 / 改名 / 改类型 / 占用差量，精确 HP、精确倍率和剩余时长不进入 NPC 信息空间。

补充：T0043A 后，病床治疗和训练位受训必须在开始及持续期间分别有有效在岗医生 / 教官；同批服务者尚在路上时依赖者会等待，到岗后自动重试，活动开始后服务者全部离岗则承载者立即失败、释放位置并进入计划重评估。教堂行动拆为普通祈祷、主持弥撒、参加弥撒：普通祈祷仍不需要神父，但主持期间不可进行且弥撒开始会中断已有祈祷；参加弥撒占用祈祷席并绑定祭坛主持者，主持正常结束时共同完成，异常退出时共同失败。候选、对话参考、三份 Prompt、GM 通用行动下拉、运行态快照和结构化事件均已接入 `attend_mass`。

补充：T0028/T0030/T0031 后，自主 NPC-NPC 对话进行时双方头顶持续显示可点击的三点小气泡；点击任一气泡打开 `DialogPanel` 只读旁听模式，实时显示双方姓名、当前轮次、“无硬上限 / 第 6 轮起建议收尾”、等待状态、已经说出口的本轮内容和完整历史。旁听模式不提供玩家输入、发送、攻击、应征或公开性修改；关闭只隐藏窗口，不结束会话、不取消 LLM、不触发计划重评估，会话尚未结束时可再次点击任一参与者气泡，以同一 `dialogue_id` 恢复最新历史与等待状态。自然结束后气泡从双方头顶消失，已打开旁听窗保留最终记录，直到玩家手动关闭。每一轮 NPC-NPC `/npc/dialogue` 都显式 `requires_time_slowdown=true`，按 `llm_dialogue_wait` 将有效逻辑倍率降到 `1/60` 并在该轮成功、失败、启动失败或取消后释放。2026-07-20 真实 DeepSeek Godot 专项验证完成邀请与正式回复的可点击旁听、真实回复、逐次慢速注册 / 释放和倍率恢复，provider=`deepseek`、model=`deepseek-v4-flash`、无 fallback；T0031 fake provider 回归进一步锁定关闭后重开同一会话与自然结束后手动关闭边界。

补充：T0031 后，艾达的 NPC 档案以 `initial_equipment.main_weapon=sword_shield` 声明开局故事装备。`EquipmentSystem` 在新游戏初始化时从正式 `weapon_defs.json` 装载完整剑盾槽位，因此艾达开局即判定为近战步兵；这不是守备官赠送行为，不消耗任何驿站库存，也不写入 `equipment_given`。后续玩家为艾达换装会按具体定义消耗 / 返还 `item_sword_shield` 等对应物品，并写入正常的 `equipment_changed` 事件。

补充：T0032 修复了气泡可见但真实鼠标点不开的问题。根因是 `NPCSystem._unhandled_input(...)` 的全局 3D 射线比 `Area3D.input_event` 更早处理命中：射线击中子气泡后沿父节点取得 NPC id，把它误当作 NPC 本体点击并立即消费事件。气泡现在保存明确的 `interaction_kind + npc_id + dialogue_id` 元数据；全局拾取先返回结构化交互，命中自主对话气泡时直接广播旁听请求，只有命中 NPC 本体时才打开 NPC 面板。自动化已按 Camera3D 投影出的真实屏幕坐标向 Viewport 推送鼠标事件，验证双方气泡打开 / 重开、不会误开 NPC 面板，以及对话结束后 NPC 本体点击仍正常。

补充：T0033 曾加入的“结束后重估计划”开关已由 T0049 删除。玩家主动对话与 NPC 主动交涉采用同一规则：完成至少一轮实际对话后，NPC 根据完整对话和原计划自行返回 `revision_hours`；空集合不修订并在满足恢复边界时继续被打断的原行动，非空集合才调用 `/npc/revise_plan` 精确改写所选小时。对话窗攻击一旦提交即成为实际对话内容并进入同一判别，不由玩家开关豁免，也不会因回复取消而撤销事实。

补充：T0029 后，邀请判定也是独立真实 LLM 调用并单独申请 / 释放 `llm_dialogue_wait` 慢速；只有接受后双方头顶才出现正式对话气泡。T0049 将玩家-NPC 普通消息的计划处理资格登记在“NPC 有效 LLM 回复成功应用”之后，并在会话结束时自动调用计划修改判别；发送后在回复完成前关闭不会因刚刚的行动打断误触发判别。攻击是例外的已提交对话事实：即使回复尚未完成，结束时仍把攻击轮写入判别上下文。

补充：T1401A 后，项目 LLM 验收规则已落到代码路径：Mock 仅用于显式 `LLM_PROVIDER=mock`、`/mock/model` 或显式 `LLM_FALLBACK_TO_MOCK=true` 的开发调试；`ModelAdapterConfig.fallback_to_mock` 和环境默认值均为 `false`。真实 provider 失败、无 Key、HTTP 错误、超时、非 JSON 或业务 Schema 校验失败时，业务接口返回可处理错误并在 `/debug/llm_usage` 记录 request id、call_type、provider、model、NPC id、HTTP 状态或异常类型、失败原因、fallback / 降级来源和 token / 费用估算，不用 mock 伪装成功。2026-07-07 已使用真实 DeepSeek `/npc/dialogue` smoke test 验证 provider=`deepseek`、model=`deepseek-v4-flash`、`fallback_used=false`。

补充：T1501 确立的 8 名 NPC 姓名和职业差异继续有效：托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文。T0061 已从正式档案、共享 NPC 身份 Schema、对话 `npc_setting` 和六类 Prompt 中移除当时加入的 3 条 `signature_lines`，当前只用职业身份、人格、欲望、恐惧、底线和宽松 `speech_style` 维持表达差异。2026-07-16 的 8 次真实 DeepSeek 职业身份调用仍是 T1501 的历史验收，不替代 T0061 的最终真实模型复验。

补充：T1506/T1507 后，主厅前公告牌可点击打开自由文本界面，发布内容由 `MemorySystem` 保存为广场 `current_notice` 并即时广播给当前广场 NPC；公告牌仍不是建筑。后门商队每天 `10:00-16:00` 可交易，粮食/木材/石料/铁买价和酒卖价读取 `data/merchant_defs.json`；`MerchantSystem` 通过 `ResourceSystem` 权威结算并写入到达、离开、成功交易结构化广场事件，酿酒完成不会自动出售。

补充：T1508/T0036 后，围墙建筑面板按器械类型消耗具体库存：弩床只消耗 `item_wall_ballista`，箭塔只消耗 `item_wall_arrow_tower`；两类器械都按战斗动作秒自动攻击射界内敌人，箭塔使用较低单次伤害和更短攻击间隔。部署由玩家直接操作，只选择器械与槽位，不绑定 NPC。`DefenseDeviceSystem` 负责具体库存、槽位、运行态、自动攻击与事件权威，`CombatSystem` 只提供设备伤害结算窄接口。部署 / 触发事件以守备官为主体，不进入 NPC 亲历事件库，但按广场公开规则进入当前在场 NPC 的见闻。表现层使用独立 `DefenseDevicePresenter` / `DefenseDeviceView`，每个实例保留 `ModelMount` 与可选 `presentation.model_scene`，当前低模占位可在 T15 美术阶段直接替换，不要求改动部署、战斗或记忆逻辑。

补充：T0035/T0036 后，`CraftingSystem` 已接管铁匠铺与工械坊制造项目。建筑面板分别列出设计冻结的全部配方；未选目标时 `work_blacksmith` / `work_workshop` 不能开始。难度以 1-8 个阶段表达，一个完整工作周期提交一个阶段并原子扣除该阶段材料；中断只清除当前周期的小数进度，已提交阶段保留。切换项目会中断该建筑当前制造行动并放弃原项目全部阶段，进度非零时必须在确认弹窗中选择“是”才执行。全部阶段完成后，成品进入对应 `item_*` 具体库存，项目保留并从第 1 阶段开始下一件。制造目标与整数阶段通过建筑 `internal_state.special_state.production` 复用既有地点快照 / 差量传播规则；小数工作进度只在建筑面板显示，不进入 NPC 信息空间。

补充：T0037/T0038/T0056 后，`HorseSystem` 已以真实马匹实体替代 `horse_readiness` 匿名库存，开局马厩有栗风、灰鬃两匹 60% 成长的刚成年马。每匹马独立保存总 HP、基础 HP 派生值、自然 HP 上限、照料额外 HP、饱食、成长、繁育概率 / 冷却、进食、位置、分配和骑乘状态；马厩面板逐匹拆分显示这些玩家可见状态。马在马厩内缓慢掉饱食、缺口达到阈值后进入持续进食并在结束时消耗粮食，离厩后饱食消耗加快且不能进食；受损后会非常缓慢地消耗饱食恢复到自然 HP 上限，照料额外 HP 受损后不会自然恢复。只有马厩内存在有效 `work_stable` 养马人时才推进成长、额外 HP 和繁育概率；至少两匹非冷却成年在厩马才累积概率并判定，成功后候选归零并冷却 1 游戏日。马厩每升一级只把概率增量提高 10%，不加速成长、进食或自然恢复。马厩建筑特殊状态只传播物理在厩的总数 / 成年数 / 小马数，个体详情仍只供玩家面板读取。

补充：T0019/T0022 后，`Main/Systems/GameStartupSystem` 提供三状态启动开关。默认“正式循环（无新手引导）”会在第 1 天 06:00 暂停逻辑时间和计划自动执行，为 8 名 NPC 逐人记录私有 `wake_up`、清空旧计划并显示 `planning_day / 制定计划`；随后以 8 路并发请求真实 LLM。真实计划统一标记 `source=llm_plan_day`；每名 NPC 失败时只重试真实请求，最多 3 次，不使用 Mock 或规则降级。只有 8 人全部成功后才统一执行当前小时项并恢复时间；任一 NPC 仍失败则整批失败，游戏保持暂停，所有 NPC 保持 `planning_day`。同一真实专用规则也用于跨天后的新一天计划。“静止调试”仍不生成起床、计划或行动；“正式循环（新手引导占位）”复用同一正式循环。Headless 自动化默认跳过自动启动，由专项脚本显式选择模式。

补充：T0020/T0049/T0050 后，正式 `dialogue`、`plan_revision_judgement`、`plan_day`、`revise_plan`、`battle_judgement`、`daily_reflection` 请求均不再向供应商发送客户端单次输出 token 上限，避免结构化 JSON 因固定额度被截断。供应商返回空内容、非法 JSON 或 `finish_reason=length` 时，六类调用都会使用对应业务的紧凑提示自动重试一次；Schema、NPC id、行动白名单、计划小时和战时允许结果等业务校验继续生效。`/health` 的适配器快照会显示 `client_output_token_limit_applied=false`，usage 继续记录真实 `finish_reason`、内容长度、尝试次数和失败原因。累计调用量、累计 token 和累计费用预算仍由独立 `LLM_BUDGET_MAX_*` 守门控制，默认 `0` 关闭，不等同于单次生成上限。

补充：T0020 完成 Godot 全部正式 LLM 调用的异步与时间降速审计；T0021 进一步移除了当时暂设的 75 / 90 秒业务总时长。对话、常规每日计划、计划修订、战时低血量心理判定和首次睡眠总结请求发送后会等待后端完成，不会因模型正常生成时间较长被 Godot 主动误杀；Godot 只在连接本地 / 游戏后端时使用 2 秒短连接保护。后端到供应商改为流式 SSE，连接建立由 `LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS` 保护，连接建立后只在 `LLM_PROVIDER_IDLE_TIMEOUT_SECONDS` 内完全收不到 token、keep-alive 或其他数据时失败；持续有进展则一直等待完整 JSON。所有会影响当前场景状态的请求都会按 `requires_time_slowdown` 注册带 call_type 的慢速原因，并在成功、失败、取消、连接 / 空闲错误或规则 / 模板降级后释放；正式开局批量计划继续由 `GameStartupSystem` 全局暂停时间，不重复登记慢速。

补充：T1402 后，`/npc/dialogue` 真实 provider 路径会读取 `data/prompts/dialogue_system_prompt.txt` 作为独立对话系统 Prompt，并继续叠加通用 JSON / Schema guard。该模板要求 NPC 回复符合职业、人设、状态、亲历事件、见闻、长期记忆、地点状态和 `current_order`，并按设计限制结构化选项：日常 / 征召使用 `recruitment_result=none|accept|reject`，集结 / 战斗中已入伍持主武器 NPC 使用 `wartime_reaction=none|escape|morale_boost`，避战对话保持 `wartime_reaction=none` 并继续通过征召结果表达是否应征，逃离挽留只允许 `intent=stay_after_intervention|leave_after_intervention`。2026-07-07 已用真实 DeepSeek 对日常对话、提出应征、战时结构化意向和逃离挽留各完成一次 `/npc/dialogue` 调用，`/debug/llm_usage` 显示 calls=4、provider=`deepseek`、model=`deepseek-v4-flash`、`fallback_used=false`。

补充：T1403/T0022/T0025 后，`/npc/plan_day` 真实 provider 路径会读取 `data/prompts/daily_plan_system_prompt.txt` 作为独立每日计划系统 Prompt，并继续叠加通用 JSON / Schema guard。该模板要求模型输出 0-23 点共 24 阶段、至少 6 个工作阶段、只使用 `allowed_actions` / `idle`，并把 `current_order` 限定为守备官当前指令参考，不得绕过行动白名单、资源、HP、地点、建筑、工位或程序强制层。后端会在 Schema 校验后额外校验 hour 覆盖、行动白名单和工作阶段数量，并在成功响应中返回 provider / model / fallback 元数据；若 Schema 已通过且 action、target、location 唯一命中一条白名单候选，仅冗余 `action_kind` 可按该候选确定性规范化，记录到 `model_normalizations` 后仍继续全部业务校验。Godot 正式每日计划只接受已配置的非 Mock provider 且 `model_fallback_used=false` 的响应；不合法时记录真实失败并保持暂停，不写入规则 / Mock 计划。2026-07-17 真实 8 NPC 并发验收显示 provider=`deepseek`、model=`deepseek-v4-flash`、8 成功、0 失败、0 fallback、峰值并发 8。

补充：T0023/T0049/T0050 后，工位占用、资源不足及其他明确的日常行动失败先进入真实通用计划修改判别；空集合保留原计划，非空才把精确 `revision_hours` 与既有完整失败上下文交给真实 `/npc/revise_plan`。后端成功响应携带 `model_provider` / `model_name` / `model_fallback_used`；Godot 正式路径只接受非 Mock 且无 fallback、且小时集合精确匹配请求的结果，成功合并为 `source=llm_plan_revision`，只覆盖选中小时并按行为模式决定是否立即执行当前小时项。失败最多进行 3 次真实请求，不生成或执行 `mock_revision` / `rule_revision_fallback`。NPC 面板在事件库上方新增“当前计划”入口；计划整体替换或重估后详情同步覆盖刷新。事件库 / 见闻库详情首次打开定位到最底部，打开期间的新记录刷新保留玩家当前滚动位置。

补充：T0024/T0049 后，NPC 面板把“当前计划 / 日记 / 知识”改为事件库上方同排等宽的三个按钮；日记不再占用面板内嵌滚动框，日记与知识图谱分别在详情弹窗阅读。首次睡眠总结显式限制为最多 8 路并发并暴露实际峰值；正式开局与 `day_started` 跨天计划批次也记录实际并发峰值。后端六个正式 LLM 成功接口统一附加 `model_provider` / `model_name` / `model_fallback_used`，Godot 睡眠总结仅在 provider 确为 Mock 时标记 `mock_daily_reflection`，真实结果固定为 `llm_daily_reflection`。2026-07-17 真实 DeepSeek 验收共 24 次：睡眠总结 8 次、开局计划 8 次、跨天计划 8 次，24 成功、0 失败、0 fallback，全部 `finish_reason=stop`。

补充：T1404 后，战时公开对话继续由 `data/prompts/dialogue_system_prompt.txt` 约束集结 / 战斗 / 避战公开对话的 `wartime_reaction`；`/npc/battle_judgement` 真实 provider 路径新增读取 `data/prompts/battle_judgement_system_prompt.txt` 作为低血量自身心理判定系统 Prompt。该模板要求模型引用 `battlefield_context`、NPC 亲历事件、公开见闻和 `current_order`，但只能从请求的 `allowed_decisions` 中选择，且 `current_order` 不能强制参战或强制逃离。后端在 `BattleJudgementResponse` Schema 校验后额外校验 `decision` 必须属于 `allowed_decisions`，并校验 `should_start_escape` 只在 `decision == "escape_station"` 时为 true；越界结果记录 `model_output_invalid` usage 并由 Godot 按允许结果规则降级。2026-07-07 已用真实 DeepSeek 对战时 `/npc/dialogue` 与 `/npc/battle_judgement` 各完成一次调用，`/debug/llm_usage` 显示 calls=2、provider=`deepseek`、model=`deepseek-v4-flash`、`fallback_used=false`。

补充：T1405/T0046 后，`/npc/daily_reflection` 真实 provider 路径会读取 `data/prompts/daily_reflection_system_prompt.txt` 作为首次睡眠反思系统 Prompt，并继续叠加通用 JSON / Schema guard。长期输出只有两类：`knowledge_graph_updates` 是替换式键值更新，以 `subject + relation` 为键记录当前关键信息，同时携带给中文 UI 的 `subject_label / relation_label / value_label`；`diary_entry` 是第一人称日记，按天增量追加。不再输出第三份 `memory_summary`。后端在 `DailyReflectionResponse` Schema 校验后额外校验 NPC id、日期、日记非空、三类中文显示文本非空且含中文，以及世界内文本必须使用“守备官”而非“玩家”。Godot 侧 `NPCSystem.apply_daily_reflection(...)` 不再写入 append-only `knowledge_graph.patches`，而是规范化为 `knowledge_graph.by_subject[subject][relation] = 当前值`；同一键后续反思会覆盖旧值，日记仍继续追加。2026-07-21 真实 DeepSeek `deepseek-v4-flash` 已在收紧 `value_label` 合同后再验一次，request id=`verify_daily_reflection_prompt_real`，`fallback_used=false`。

补充：T1406 后，`ModelAdapter` 支持 `LLM_BUDGET_MAX_CALLS`、`LLM_BUDGET_MAX_INPUT_TOKENS`、`LLM_BUDGET_MAX_OUTPUT_TOKENS`、`LLM_BUDGET_MAX_TOTAL_TOKENS` 和 `LLM_BUDGET_MAX_COST` 预算守门，默认 `0` 表示关闭。预算超限时业务接口返回 HTTP 429 / `budget_exceeded`，并在 `/debug/llm_usage` 记录 `exception_type=BudgetExceeded`、`degradation_source=budget_blocked`、request id、call_type、provider/model、NPC id 和失败原因，不会自动 mock fallback。`/debug/llm_usage` 与 `/health` 的 adapter 快照会暴露预算上限、已用量、剩余额度和最近预算错误。Godot 侧 `LLMBridge.debug_get_llm_runtime_snapshot()` 可查看当前等待中的 LLM 请求数、pending slowdown request id、NPC 活动请求、有效逻辑倍率和 `TimeSystem.last_time_scale_reason`；GM `llm_usage` / “成本统计”会同时显示后端 usage / budget 和 Godot 运行态快照。本轮真实 DeepSeek 验收包含一次 `/npc/plan_day` 超时失败 usage（`provider=deepseek`、`model=deepseek-v4-flash`、`exception_type=ConnectionError`、`fallback_used=false`）和一次成功 `/npc/dialogue` usage（calls=1、failed=0、`fallback_used=false`）；预算超限路径已用自动化脚本验证。

补充：T1103/T1103A/T1103B/T1103C 已实现 HUD 警铃触发集结、统一行为模式状态机和非战斗人员避战模式：所有 NPC 写入 `combat_alarm_rang` 事件，入伍且有主武器、当前可行动且非睡觉的 NPC 进入 `behavior_mode == "rally"` 并前往城门外防线；阵型按近战 / 骑兵前排、弓弩 / 骑射后排排列，集结和接敌状态显示面向敌方方向标记，已装备坐骑的 NPC 只在集结 / 接敌模式显示低模坐骑。若集结途中或集合点附近遭遇敌人，已入伍且有主武器 NPC 会进入 `behavior_mode == "combat"` 与 `combat_ready` 占位状态，写入 `combat_rally_encountered_enemy` 和必要的 `npc_mode_changed`。未入伍 NPC、以及已入伍但无主武器 NPC 在工作模式中接敌会进入 `behavior_mode == "avoid_combat"`，按最近敌人的接近方位生成短步长散射目标，逐步远离到接敌范围之外，写入 `avoidance_started`；睡觉中的非战斗人员只有被敌人攻击才进入避战。避战中应征入伍但仍无主武器时继续避战，装备主武器且仍有敌军时进入 `combat`。到达集合点等待 1 游戏小时仍未接敌时会回到 `work`，不触发计划重评估；场上敌人清空时，`combat` NPC 回到 `work` 并触发计划重评估，`avoid_combat` NPC 回到 `work` 且不触发计划重评估，并写入 `avoidance_ended`；T1103D 起，`work <-> combat` 与 `work <-> avoid_combat` 的互转不再写入 `npc_mode_changed` 或通过该事件广播。昏迷复苏后按场上敌军、入伍状态和主武器分流到 `combat`、`avoid_combat` 或 `work`。T1104 后，`combat` 模式中的入伍持武器 NPC 会按武器射程、力量、熟练度和攻击间隔自动攻击敌人，敌人 HP 清零后从战斗中移除；敌人攻击 NPC 会先按盔甲防御减伤再扣 HP。T1104A 后，玩家 `x2` / `x4` 不再提高战斗伤害、攻击间隔、攻击速度或战斗移动速度；只要活动敌人存在，CombatSystem 会把 TimeSystem 有效倍率上限设为 `x1`，LLM 慢速可进一步降速，清敌后释放上限并恢复玩家选择的倍率。T1105 后，入伍且有主武器 NPC 的可选战斗策略由当前装备和兵种决定，玩家可在 NPC 面板“装备武器”旁的下拉框手动选择当前策略；默认使用该兵种第一项进攻 / 输出策略，换主武器或坐骑后会重置到新兵种默认策略。远程最大化输出为站桩射击，保持距离射击会在仍尽量保持射程内的前提下小幅拉开距离，近战主动进攻会接近并攻击，战斗策略中的避战复用短步长避战移动但仍属于 `combat` 模式；T1105A 后，战斗内避战只在最近敌人低于避战安全阈值时短步长远离，敌人已远离到阈值外时保持 `combat_ready` 等待，不再继续退向驿站边界或角落。T1106 后，敌人波次生成会在广场广播 `combat_started`，写出敌军构成和我方已入伍持武器战斗人员；敌军全灭或被清空会广播 `combat_ended`，统计本场受伤 / 昏迷 NPC 和各 NPC 击退敌人数量，并让未接敌 `rally` NPC 回到 `work` 且不重评估计划。T1201 后，集结 / 战斗 / 避战模式下守备官主动对话强制同地点公开并注入 `battlefield_context`；已入伍且有主武器 NPC 可返回 `wartime_reaction`，`morale_boost` 会写入事件并应用 2 游戏小时攻击 / 移动加成，`escape` 会进入 T1203 逃离流程。T1202 后，战时任一未昏迷、未逃离 NPC 的 HP 首次跌破 30% 且仍大于 0 会触发低血量自身心理判定；参战 NPC 可继续参战、逃离或斗志激昂，避战 / 非战斗人员只可逃离或继续避战。T1203 后，逃离 NPC 会朝后门外出口移动，移动期间不再参与工作或战斗，到达后 `escaped=true`、实体隐藏并写入广场公开 `escaped` 事件。T1204B 后，逃离 NPC 头顶显示 `!` 警示且 HUD 显示逃离警告；玩家点击逃离 NPC 会先打开 NPC 面板，再点击【对话】进入最多 5 轮 `escape_intervention` 挽留对话。对话打开时暂停逃离移动，未满 5 轮关闭后恢复移动且可再次打开，满 5 轮仍未成功会自动关闭并让【对话】置灰。玩家消息需等 NPC 回复后才计 1 轮；逃离挽留攻击计 1 轮、立即关闭面板、继续逃离，不请求 NPC LLM 回复，也不写 `escape_intervention_result`。留下会停止移动、回到 `work` 并触发计划重评估；继续逃离会记录轮次并保持逃离。给钱会降低逃离移动倍率，逃离挽留攻击会提高逃离移动倍率并只写 `escape_speed_changed`；若逃离期间昏迷，`escape_intent.status` 暂停为 `paused_unconscious`，复苏后继续前往后门。基础胜负结算和 NPC 结局总结已接入，命中 / 格挡仍未实现。

补充：T1104B 后，CombatSystem 将 `60` 游戏秒折算为 `1` 战斗动作秒推进我方和敌方攻击冷却，并让敌人移动使用同一动作秒级位移基准；TimeSystem 的 `x1` 仍表示现实 1 秒推进游戏内 1 分钟，但不会再把这 60 游戏秒当成 60 秒攻速冷却。第一波劫掠者已调为低强度探路敌人，艾达装备剑盾时应能看到十几秒量级的互相攻击过程，而不是在一个基准秒内瞬间结束。

补充：T1104C 后，敌人规则 AI 不再攻击围墙。所有敌人波次的目标偏好已移除 `wall`，CombatSystem 默认和运行时目标偏好都会过滤旧配置中的 `wall` / `front_wall`；敌人在没有附近可行动 NPC 时按城门、仓库、主厅推进。城门被攻破后直接转向仓库；“必须从城门进入、不能穿越围墙”的空间路径约束留给后续碰撞体积 / 导航任务。

补充：运行时已区分工作模式、集结模式、战斗模式和非战斗人员避战模式，并取消旧式“战斗触发时全员心理判定”的实现路径。集结 / 战斗 / 避战公开对话结构化战时意向已接入；T1202 后，战时任一 NPC HP 首次低于 30% 的自身心理判定已接入，避战 / 非战斗人员只允许逃离或继续避战，不触发斗志激昂或继续参战。

补充：T1205 后，战场公开信息已完成综合验收：敌袭开始 / 结束、集结、必要行为模式切换、避战开始 / 结束、低血量、战时心理结果、NPC 击退敌人、昏迷、治疗、复苏、逃离、建筑受损等事实均由权威系统写入结构化事件，并通过广场或同地点规则进入当前在场 NPC 的见闻库；`LLMBridge` 对话 payload 和 NPC 面板见闻库均可读取这些公开见闻摘要。

## 当前已实现内容

- [x] Godot 项目初始化
- [x] 核心 Autoload 骨架
- [x] Main 标准节点结构
- [x] 基础地图
- [x] HUD 基础界面
- [x] GM 调试面板
- [x] 基础摄像机控制
- [x] NPC 基础实体
- [x] NPC 基础状态与面板
- [x] NPC HP 扣除与昏迷状态
- [x] NPC 基础移动与地点进入
- [x] 地点信息节点与进入快照
- [x] NPC 工作 / 吃饭 / 睡觉最小行动闭环
- [x] 8 名初始 NPC 正式姓名、职业语气与个性台词
- [x] 8 名初始 NPC 的独立开局长期日记、知识图谱与根本人设
- [x] 建筑基础实体
- [x] 建筑基础面板
- [x] 建筑修复与升级最小逻辑
- [x] 时间系统
- [x] 资源系统
- [x] HUD 资源库存显示与装备/器械详情入口
- [x] 对话系统
- [x] LLM 后端骨架
- [x] 后端 AI Schema
- [x] 后端 NPC 对话开发期 Mock 接口
- [x] 真实 Model Adapter 与开发期 Mock 调试
- [x] 成品 Mock fallback 封存与真实 API 验收
- [x] NPC 对话 Prompt 模板与真实 provider 验收
- [x] 所有非计划 NPC 对话自动注入配置化可选行动参考
- [x] 每日计划 Prompt 模板与真实 provider 验收
- [x] 战时公开对话与低血量心理 Prompt 模板与真实 provider 验收
- [x] API 额度 / 调试信息面板与预算超限错误
- [x] Godot LLMBridge
- [x] 征召系统
- [x] 入伍 NPC 自然语言指令入口与存储
- [x] 规则版 24 小时每日计划接口与按小时执行
- [x] 三状态启动开关与默认正式游戏循环
- [x] 真实 LLM 正式每日计划、8 路并发与失败暂停；Mock / 纯规则只保留显式调试入口
- [x] 行动异常先经真实计划修改判别，非空才触发精确小时 `/npc/revise_plan`；失败保留原计划且无 Mock / 规则修订降级
- [x] 首次睡眠总结、长期日记和短期记忆清空
- [x] NPC 面板非对话交互入口
- [x] NPC 面板事件库 / 见闻库滚动区、详情弹窗与对话 / 指令弹窗互斥
- [x] NPC 主动找玩家交涉
- [x] 职业工作产出框架
- [x] 食堂粮食加工餐食
- [x] 菜园粮食产出
- [x] 铁匠铺具体武器 / 盔甲配方、分阶段制造与项目进度 UI
- [x] 工械坊具体弓弩 / 箭束 / 工程器械配方、分阶段制造与项目进度 UI
- [x] 围墙弩床 / 箭塔无部署者部署、自动攻击、结构化事件与可替换模型挂点
- [x] 具体武器 / 盔甲 / 箭束 / 工程器械库存与逐件装备 / 部署结算
- [x] 马厩真实马匹生态、个体面板、成长 / 生育 / 喂食与战时骑乘生命周期
- [x] 酒窖酿酒库存产出
- [x] 主厅前公告牌自由文本输入、广场当前状态与在场 NPC 即时广播
- [x] 后门商人每日到访、购买基础资源与出售酒交易
- [x] 小诊所医生坐诊/研读医术与病床治疗
- [x] 具体物品库存、装备槽与真实马匹分配系统
- [x] 兵种判定
- [x] 训练场与武器 / 骑术熟练度提升
- [x] 通用熟练度经验、技能点与玩家属性分配
- [x] 敌人波次配置与调试生成
- [x] 敌人目标优先级、移动与攻击
- [x] 基础自动攻击与伤害
- [x] 战斗动作秒与第一波基础节奏校准
- [x] NPC 行为模式状态机
- [x] 非战斗人员避战模式
- [x] 不同兵种战斗策略
- [x] 战斗内避战策略距离边界修正
- [x] 战斗开始 / 结束广场事件与清敌统计
- [x] 战时公开对话心理结果
- [x] 战时低血量自身心理判定
- [x] 逃离驿站行为
- [x] 逃离挽留五轮对话
- [x] 逃离挽留 NPC 面板入口、暂停与无回复攻击规则
- [x] 逃离攻击事件去重与 NPC 面板切换清理交互提示
- [x] NPC 结局总结页面
- [x] 昏迷自然恢复/复苏
- [x] 治疗昏迷 NPC
- [x] 广场公开信息即时广播
- [x] 战场公开信息综合验收
- [x] 波次倒计时与自动来袭
- [x] 主厅摧毁失败条件与失败占位界面
- [x] 无可战斗人员失败条件
- [x] 第 5 波胜利条件与胜利占位界面
- [x] NPC 短期记忆容器
- [ ] 完整见闻系统
- [x] 结构化事件底座
- [x] 基础胜负与 NPC 结局总结
- [x] 基础 JSON 数据文件

## 当前稳定运行流程

```text
启动 Godot
  ↓
加载 EventBus / GameState / ConfigLoader Autoload
  ↓
进入 Main 场景
  ↓
加载 WorldRoot / Station / Systems / UI / CameraRig 标准节点结构
  ↓
显示低模驿站 Blockout、俯视相机、方向光
  ↓
ResourceSystem 从 `data/resource_defs.json` 初始化第纳尔、粮食、餐食、酒、木材、石料、铁，以及剑盾、长杆武器、弓、弩、铁盔、锁子甲、铁护腕、铁护腿、箭束、弩床、箭塔等具体物品库存；`weapons` / `armor` / `defense_devices` / `horse_readiness` 仅为旧测试兼容项，已隐藏并标记 `deprecated=true`、`formal_consumption_allowed=false`
  ↓
EquipmentSystem 从 `data/weapon_defs.json`、`data/armor_defs.json` 和 `data/mount_defs.json` 初始化主武器、盔甲和坐骑兼容投影；新游戏会先把 NPC 档案中的 `initial_equipment` 引用装载为故事初始装备，不扣库存、不写玩家赠送事件。玩家后续装备武器 / 盔甲时只消耗该定义的具体 `source_resource_id`，换装 / 卸装返还同一具体物品；坐骑分配委托 HorseSystem，不能再由 `horse_readiness` 生成。兵种由主武器与 HorseSystem 同步到 `equipment.mount` 的真实马匹投影共同决定
  ↓
CombatSystem 从 data/enemy_waves.json 读取 5 波敌人配置；T1301 后每波可读取 `trigger_day` / `trigger_hour` / `trigger_minute` / `trigger_second`，并在 TimeSystem 的 `logical_time_tick` 中按配置时间自动触发下一未触发波次，第一波默认为第 3 天 18:00，后续按配置逐日增强；CombatSystem 记录已触发波次并通过 `get_wave_schedule_snapshot()` 暴露下一波倒计时状态，避免同一波重复自动生成。可通过调试接口或 GM 面板在 Station/Enemies 下生成正门外低模敌人实体，也可用 GM “跳到下一波” / `next_wave` 调试入口触发下一未触发波次；敌人保留 HP、武器类型、兵种/单位类型、攻击、防御、移动速度、攻击范围、攻击间隔和目标偏好数据；敌人会随 TimeSystem `logical_time_tick` 选择目标并移动，若一定范围内有可行动 NPC 则优先攻击该 NPC，否则默认按城门、仓库、主厅顺序推进；T1104C 起不再攻击围墙，旧配置中的 `wall` / `front_wall` 会被过滤；T1104 后入伍且有主武器的 NPC 只在 `behavior_mode == "combat"` 中按逻辑时间自动攻击范围内敌人，攻击力读取武器伤害并按力量修正，攻击间隔读取武器间隔并按熟练度/疲劳/饱食/坐骑修正，伤害会按敌人或 NPC 防御减伤；T1105 后战斗模式会按玩家手动选择的当前策略决定站桩射击、保持距离射击、主动进攻、拉开距离冲击或战斗内避战，其中战斗内避战只在敌人低于安全阈值时短步长远离，敌人已远离则站立等待；T1104A 后战斗数值不再随玩家 `x2` / `x4` 加速，敌人在场期间 TimeSystem 有效倍率上限为 `x1`，LLM 慢速仍可降到更慢，清敌后释放上限；T1106 后敌人波次生成会写入广场 `combat_started`，包含敌军构成和我方已入伍持武器 NPC 的姓名 / 兵种，敌军全灭或 GM 清敌会写入广场 `combat_ended`，包含本场受伤、昏迷、低血量心理判定和击退敌人的统计；T1201 后战时对话可写入 `battle_psychology_result`、`morale_boost_started` / `morale_boost_ended`，并在 CombatSystem 快照暴露最近一次战时对话结果；T1202 后，战时 NPC HP 首次跌破 30% 且仍大于 0 会请求 `/npc/battle_judgement` 或规则降级，写入 `low_hp_triggered` 与 `battle_psychology_result`，并在快照暴露最近一次低血量判定结果；T1203 后，战时逃离意向或 GM 调试可调用 `start_npc_escape(...)`，写入 `escape_started`、让 NPC 前往后门外出口，离图后写入 `escaped` 并把 NPC 标记为不可用；T1204A 后，逃离中 NPC 点击会先打开 NPC 面板，玩家通过【对话】按钮进入最多 5 轮挽留；对话打开时暂停逃离移动，未满 5 轮关闭后恢复移动且可再次打开，5 轮用完后【对话】置灰；`stay_after_intervention` 会停止逃离并回工作模式，`leave_after_intervention` 会继续逃离，给钱 / 攻击会分别降低 / 提高逃离移动倍率，逃离挽留中的攻击只计一轮并关闭面板、不请求 NPC LLM 回复，昏迷复苏后继续逃离；敌人 HP 清零后从活动敌人和场景节点移除，NPC HP 清零仍走昏迷流程；T1302 后主厅 HP 清零会把 `GameState` 标记为 `failure/main_hall_destroyed`、记录失败时间、广播 game-over、暂停 TimeSystem 并显示 HUD 失败界面；T1303 后，当活动敌人在场且项目中曾存在已入伍持主武器的战斗人员、但这些战斗人员全部处于昏迷、已逃离或正在逃离状态时，CombatSystem 会标记 `failure/no_available_combatants`、记录可战斗人员可用性快照、暂停 TimeSystem 并显示 HUD 失败界面；T1304/T1305 后，包含第 5 波的战斗在敌军清空后会把 `GameState` 标记为 `victory/five_waves_survived`，记录剩余资源、建筑状态和 NPC 结局快照；任意胜负结算都会由 `GameState` 补齐每名 NPC 的最终状态（可行动 / 昏迷 / 逃离）、是否入伍、最后位置、Mock 最终看法、Mock 后续命运和记忆依据，HUD 在滚动结算页显示这些 NPC 结局，且不使用“阵亡”表述；当前不实现命中率
  ↓
BuildingSystem 从 data/building_defs.json 初始化建筑基础状态并绑定低模建筑节点；主厅前公告牌不属于建筑定义
  ↓
CraftingSystem 从 `data/crafting_recipes.json` 初始化铁匠铺 / 工械坊 11 个具体配方和各自项目状态；ActionSystem 在制造工作开始前校验已选择目标与当前阶段材料，一个完整工作周期提交一个阶段，中断当前周期会回退小数进度但保留已完成阶段，全部阶段完成后增加对应 `item_*` 库存；项目整数状态写入建筑 `special_state.production`
  ↓
HorseSystem 从 `data/horse_defs.json` 初始化两匹 60% 成长的刚成年马，并随逻辑时间推进个体饱食、进食、自然恢复、成长、照料额外 HP、累积繁育概率 / 冷却、位置、分配和骑乘；只有在厩工作的有效养马人推动成长、额外 HP 与繁育概率，马厩等级每级只为繁育概率增量增加 10%；物理在厩总数 / 成年数 / 小马数写入建筑 `special_state.horses`
  ↓
NoticeBoard 为主厅前公告牌创建独立点击区并打开 NoticeBoardPanel；“通告 / 参考日程”两页只在发布时分别调用 MemorySystem.set_plaza_notice(...) / set_plaza_reference_schedule(...)，更新广场 current_notice / reference_schedule 并广播对应变更，不写入建筑状态
  ↓
MerchantSystem 从 data/merchant_defs.json 读取每日 10:00-16:00 到访时段和报价，随 TimeSystem 控制后门商人标记；MerchantPanel 只提交买卖请求，ResourceSystem 结算第纳尔、粮食、木材、石料、铁和酒，MemorySystem 记录到达、离开与成功交易事件
  ↓
DefenseDeviceSystem 从 `data/defense_device_defs.json` 读取弩床 / 箭塔和围墙槽位；围墙 BuildingPanel 只提交类型和槽位，系统按器械定义原子扣除 `item_wall_ballista` 或 `item_wall_arrow_tower`、占槽并写入以守备官为主体的部署事件。两类器械都按战斗动作秒调用 CombatSystem 结算射界内敌人伤害；Station/DefenseDevices 只负责生成带 ModelMount 的可替换低模表现
  ↓
NPCSystem 从 data/npc_profiles.json 读取 8 名初始 NPC，并在 Station/NPCs 下生成占位实体
  ↓
GameStartupSystem 按 Inspector 的 `startup_mode` 统一编排开局：默认正式模式恢复时间与计划自动执行，让 8 名 NPC 记录起床、制定计划并执行第 1 天 06:00 项；静止调试模式暂停时间且不启动计划；新手引导模式当前只保留占位快照
  ↓
NPCSystem 可通过 `debug_damage_npc` / GM `attack_npc` 扣除 HP；HP 到 0 时 NPC 原地昏迷，停止移动，行动/移动指派被拒绝，并写入 `damage_taken` / `unconscious_started` 事件；昏迷 NPC 会随 TimeSystem 逻辑时间以每游戏小时 2 HP 的速度自然恢复，达到 Max HP 的 30% 后自动复苏、回到 idle、重新允许行动，并写入 `revived` 事件
  ↓
可通过调试接口让 NPC 前往指定建筑；NPC 实体直线移动，到达后写回 current_location 与 location_context 占位；室内到室内的地点信息与事件链会逻辑上经由广场
  ↓
ActionSystem 可通过调试接口安排 NPC 去工作、吃饭、睡觉、训练或协助治疗昏迷者；若目标建筑/地点不同，会先移动，到达后由 MemorySystem 更新地点 people_present，进入者获得一次地点状态见闻，NPCSystem 生成只记录行动事实的 location_entered / location_exited 事件；若从一个室内地点切到另一个室内地点，事件顺序会插入进入/离开广场，再进入持续行动
  ↓
行动结算由程序随 TimeSystem 逻辑时间执行：工作周期综合 NPC 熟练度 / 属性、建筑升级加成与受损倍率；普通生产、分阶段制造和马匹照料仍由各自权威系统结算。所有需要室内位置的行动由程序自动申请同类型第一个空位，完成、失败、中断、升级封闭或建筑摧毁时释放；NPC 不选编号。诊所聚合全部在岗医生作用于全部病床，训练场聚合全部在岗教官作用于全部训练位。吃饭占用用餐席，睡觉占用宿舍床位，普通祈祷占用祈祷席，主持弥撒占用祭坛；食堂 / 宿舍升级分别缩短恢复周期，建筑受损则拉长周期。协助修复 / 升级仍在广场进行并可按工程熟练度加速作业；行动事件继续以结构化 `local_public` 事实进入 MemorySystem，同地点未昏迷、未睡觉 NPC 接收见闻。
  ↓
显示 HUD 标题、天数、`HH:MM:SS` 时间/阶段、按 `data/resource_defs.json` 顺序生成的主栏资源、装备/器械详情按钮、独立速度按钮、独立暂停/继续按钮、警铃按钮和由 LLMBridge health check 刷新的后端状态；装备详情按武器 / 盔甲 / 箭束逐项显示具体库存，并显示马厩真实总数 / 成年数 / 小马数与已分配数量，器械详情逐项显示弩床 / 箭塔库存；四类旧聚合资源不出现在正式 HUD
  ↓
开发模式下显示半透明可拖动 GM 按钮；点击可在 GM 按钮附近打开 GM 面板，面板会随按钮位置重定位并保持在可用屏幕范围内；通过按钮或命令调试资源、时间、建筑、NPC、装备武器/盔甲/坐骑、兵种判定、敌人波次生成/清空/快照、NPC 扣血/昏迷/自然恢复、行动、逃离驿站、地点快照、广场公告和短期记忆
  ↓
建筑调试标签显示名称、等级和 HP，真实鼠标点击建筑可发出 building_clicked(building_id)
  ↓
NPC 短姓名/HP/当前行动调试标签可见，点击 NPC 可打印并发出 npc_clicked(npc_id)
  ↓
右上角 NPC 面板可显示被点击 NPC 的姓名、HP、HP 右侧的 `经验：当前 / 阈值`、力量 / 智力属性、由熟练度推导的专长、饱食、疲劳、金钱、当前装备与战斗定位、昏迷、入伍、当前行动、职业熟练度和武器熟练度；事件库上方并排提供“当前计划 / 日记 / 知识”三个详情按钮，日记不再内嵌在面板中；当存在未分配技能点且属性未达上限时，面板会在力量或智力数值旁显示 `+1` 按钮，玩家可把技能点分配到对应属性，用完后按钮消失，AI 不会自动消耗技能点；NPC 状态或记忆被系统修改后，只有当前 NPC 面板仍可见时才刷新面板，不会在玩家已切到建筑面板或关闭面板后自动重新弹出；事件库 / 见闻库详情首次打开自动定位到最底部的最新记录，打开期间刷新会保留玩家当前滚动位置，日记和知识图谱在独立详情弹窗中查看；点击事件库或见闻库区域会打开更大的玩家详情弹窗，但只显示与小框一致的时间和摘要，不显示内部事件字段或 payload，点击右上角 `×` 可关闭；面板内容增多时以右上角顶边为固定基准向下延展，不会向上越出屏幕；面板内可选择本次非对话交互可见性并直接给钱；武器 / 盔甲按具体 `item_*` 库存装备 / 卸下，只有已入伍且有主武器的 NPC 才可分配成年、未占用、物理在厩的真实马，小马不能分配，收回主武器会自动取消马匹；未入伍导致这些操作或战斗策略禁用时会显示征召前置提示；给钱数量输入框紧邻“给钱”按钮且只保留数字；攻击入口已移动到对话窗，点击 NPC 面板“对话”只打开窗口，不会立刻打断行动或触发重估；点击“指令”不会关闭 NPC 面板，`DialogPanel` 和 `OrderPanel` 彼此互斥，不会重叠在中央；当前所有 LineEdit / TextEdit 输入框获得焦点后，点击输入框外任意位置都会退出输入状态
  ↓
DialogPanel 显示 NPC 名字、历史对话、公开性、轮次、自由文本输入、发送、攻击，以及“完成对话 / 取消对话 / 挂起对话”三个会话按钮；右上角仅保留“同地点公开”和“提出应征”两个 toggle，不提供强制计划重估选项。玩家消息发送即进入历史；完成会话会取消尚未返回的 NPC 回复、整场入库并在历史非空时判别 `revision_hours`，取消会话则丢弃本次会话且不判别。挂起只隐藏窗口并保持 NPC `talk_to_guard_officer` 占用，头顶橙色 `↩` 气泡和 NPC 面板对话按钮橙点都可恢复，2 游戏小时超时自动取消。对话窗内一旦提交攻击，HP 与伤害事件立即生效，取消按钮置灰；普通攻击可异步请求回复，提前完成只丢弃未完成回复，逃离攻击不请求回复并自动完成无回复会话。应征、战时反应和逃离决定在完成前暂存，取消不会应用。空判别按边界恢复原行动，非空才修订精确小时。
  ↓
GM 或调试接口可让某名可行动 NPC 进入主动找守备官交涉状态；NPC 头顶出现 `?` 气泡并写入私有 `proactive_talk_started` 事件，玩家点击该 NPC 时优先打开对话面板并显示 NPC 预先确定的开场问题。开场文本先保存在会话历史，完成时随整场 `dialogue_turn` 一次提交，取消则不写本次对话内容。玩家参与实际对话后按普通守备官-NPC 对话先判别、再按需修订；若 1 游戏小时内未点击而超时，则作为非对话状态变化直接修订当前小时。真实修订最终失败会保留真实错误和原计划，不应用 Mock 或规则修订。
  ↓
DailyPlanSystem 可为显式调试生成规则版 24 小时计划；正式开局、新一天、计划修改判别和行动失败后的修订只接受真实 provider。计划每小时 1 项并至少包含 6 个工作阶段。计划执行由 `hour_started` 打点触发，并用 `(day, hour, plan_version, action_id, target_id, dialogue_goal)` 记录派发签名：同一计划版本的同一时段只派发一次，短行动提前完成后保持空闲到下个小时或新计划版本，不再重复刷同一行动。小时切换或计划变更时，若 NPC 正在执行不同计划行动，会通过 ActionSystem 中断旧行动再执行新行动。有实际内容的守备官-NPC / NPC-NPC 对话以及明确的日常行动失败，统一先判别 `revision_hours`；对话窗内已提交攻击也属于有效本轮内容。空集合不调用 `/npc/revise_plan`，对话路径仅在原行动确被对话打断且仍有效时恢复；非空集合才以 `revision_scope=selected_hours` 精确修订所选小时。守备官新指令、战斗结束 / 返回工作模式后的复苏、主动交涉无人响应超时和 GM 手动重估等其他来源继续直接受限修订。最多重试 3 次真实请求，最终失败保留原计划和错误，不写 Mock / 规则修订。未显式生成计划的 NPC 不会被小时信号接管；GM 面板可生成、查看、执行和手动触发重评估计划。
  ↓
DailyReflectionSystem 监听 `sleep_started` / `sleep_ended` 和 `logical_time_tick`；每名 NPC 每天首次开始睡觉后，必须持续睡眠满 1 个游戏小时才会通过 `LLMBridge.request_npc_daily_reflection(...)` 请求 `/npc/daily_reflection`。该接口历史名仍是 daily_reflection，但当前玩法语义是“首次睡眠总结”。总结请求会申请 TimeSystem 慢速，后端不可用或输出无效时使用 Godot 模板兜底。总结发起到完成期间 NPC 进入不可打断的深度睡眠锁：对话、发消息、行动改派和普通中断都会被拒绝；已入伍 NPC 仍可保存新指令，但计划重评估延后到醒来后执行。总结成功后写入 NPC 长期日记 `diary`，并把 `knowledge_graph_updates` 合并为替换式 `knowledge_graph.by_subject[subject][relation]` 当前值；同一键后续更新覆盖旧值，不再写入 append-only `patches`。随后调用 `MemorySystem.clear_npc_short_term_memory(...)` 清空该 NPC 当天事件库和见闻库索引；全局事件档案仍保留给调试查询。NPC 面板可查看长期日记，GM 面板可触发首次睡眠总结、查看长期记忆、最近总结结果和 LLM 状态。
  ↓
右上角建筑面板显示被点击建筑的名称、等级、HP、建筑状态、精确运作效率，以及按配置顺序逐项列出的具体位置名称与实际占用情况（例如 `病床1：空闲`、`病床2：某人占用中`），可关闭；不按类型聚合，不显示“主动工位 / 被动工位”，也不再额外显示单独的“当前工作位 x/x”汇总行；修复/升级按钮按条件启用并调用 BuildingSystem，资源消耗和执行条件在按钮悬停提示框中显示；修复和升级都显示倒计时进度、剩余时间、速度倍率和协助人数；NPC 面板和建筑面板会随点击对象互斥切换；建筑修复/升级进度等状态刷新不会把已经切到 NPC 的右上角面板抢回建筑面板；铁匠铺 / 工械坊额外显示目标下拉框、当前阶段、已完成阶段、实时进度条和在制工人，非零进度切换目标会弹出清零确认；马厩额外逐匹显示名称、成年 / 小马、HP、自然 / 照料额外上限、饱食、成长、进食、位置、分配与骑乘状态
  ↓
玩家可用 WASD、鼠标中键拖拽和滚轮在受限边界内查看驿站
```

低模驿站当前包含主厅、宿舍、食堂、仓库、围墙/城门、广场、后门/商人入口、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊、主厅前公告牌和调试标签。2026-05-19 已扩大地面与围墙范围，并重新拉开建筑间距，让中央广场、生活区、生产区、防务区和后门入口更易辨认；随后补齐围墙四角闭合，并把公告牌缩小移动到主厅正面。2026-06-12 已为 T1101 扩大正门外地面和正门道路，使正门外森林方向可作为敌人生成区，并把摄像机 Z 轴边界扩到可查看该区域。2026-07-16 起公告牌可点击输入并预览广场当前公告，但仍不属于建筑数据，不具备 HP、等级、工作位、修复或升级；后门商人标记只在配置到访时段显示并可点击交易。

HUD 当前按 `ResourceSystem.get_resource_ids()` / `data/resource_defs.json.ui_order` 动态显示 `show_in_main_hud != false` 的主栏资源：第纳尔、粮食、餐食、酒、木材、石料和铁；资源变化会刷新对应资源标签。资源栏右侧有“装备”和“器械”详情按钮，打开时面板出现在各自按钮左下方并夹在可用屏幕内；装备详情按武器 / 盔甲 / 箭束列出全部具体 `item_*` 库存，并显示马厩物理在厩总数、成年数、小马数和真实分配数，器械详情列出弩床 / 箭塔的具体库存；四类旧聚合资源被显式隐藏。具体部署与已部署清单从围墙 BuildingPanel 查看。HUD 只读取 `ResourceSystem`、`EquipmentSystem`、`HorseSystem`、`NPCSystem`、`CombatSystem` 和 `GameState`，不直接修改资源、装备、马匹、行动或战斗权威状态；当任一 NPC 的 `escape_intent` 处于 `escaping` 或 `paused_unconscious` 时，HUD 顶部显示“警告：{NPC}正在逃离驿站”。T1302-T1305 后，`GameOverPanel` 会按 `GameState.game_result` 显示失败或胜利结算界面：失败显示原因、时间、停止推进提示和 NPC 结局总结，胜利显示“防守成功”、守住 5 波、剩余资源摘要、建筑状态摘要、NPC 可行动 / 昏迷 / 逃离摘要和每名 NPC 的结局总结；结局明细在滚动区内显示最终状态、入伍状态、最后位置、对守备官最终看法和后续命运。时间显示为 `HH:MM:SS`，会随 `TimeSystem` 每个游戏秒刷新；速度按钮只在 `x1`、`x2`、`x4` 之间循环，暂停/继续由独立按钮控制，也可按空格切换，空格不再触发加速；TimeSystem 当前不改变 Godot 全局速度或 NPC 移动速度，只提供逻辑时间倍率、`logical_time_tick`、`gameplay_pause_changed` 和 LLM 等待慢速请求接口。暂停时逻辑时间停止、NPC 移动停止，尚未到达目标地点的行动保持 pending，已经开始的工作/吃饭/睡觉保持 active，不会在暂停中继续消耗/产出资源或改变饱食/疲劳，恢复后继续按逻辑时间结算；建筑修复/升级倒计时也遵循同一逻辑时间与暂停语义。警铃按钮会调用 `CombatSystem.trigger_combat_alarm("hud")`：所有 NPC 写入 `combat_alarm_rang` 事件，入伍且有主武器、当前可行动的 NPC 打断普通日常行动并前往城门外防线集结；近战 / 骑兵排在前排，弓弩 / 骑射排在后排，集结和接敌状态显示面向敌方方向标记，已装备坐骑的 NPC 只在集结 / 接敌模式显示低模坐骑；若集结途中遇到一定范围内敌人，会停止移动并切换为 `combat_ready`。后端状态由 `LLMBridge` health check 刷新。

建筑当前由 `BuildingSystem` 读取 `data/building_defs.json`，权威维护名称、等级、HP、逐位置状态、可进入 / 可用状态、精确损伤效率、特殊状态和修复 / 升级作业；`NoticeBoard` 不属于建筑。点击低模建筑会打开 `BuildingPanel`，面板显示建筑状态、精确运作效率，并按配置顺序逐项显示 `诊疗位1：空闲` / `病床2：某人占用中` 等具体位置，不按类型聚合，也不使用“主动 / 被动工位”术语。修复 / 升级按钮只调用 BuildingSystem，成本和条件在提示中显示；升级开始后建筑封闭、使用者被退出并释放位置，完成后一次应用逐级配置的 Max HP、位置和效率奖励。`set_building_special_state_section(...)` 仍是制造 / 马匹内部特殊状态唯一写入口。铁匠铺 / 工械坊制造目标、阶段与进度，马厩物理数量与逐匹详情，以及 T0040 的 360-420px 内容自适应布局均保持；UI 不自行结算位置、资源、HP、阶段、马匹或升级事实。

NPC 当前由 `NPCSystem` 读取 `data/npc_profiles.json`，在 `Main/WorldRoot/Station/NPCs` 下生成 8 个低模占位实体，主场景头顶标签只显示短姓名、HP 和当前行动；`NPCPanel` 按姓名、HP 与经验、属性、专长、饱食度、疲劳度、金钱、昏迷、入伍、当前行动、熟练度的顺序展示，其中属性来自 `stats.strength` / 力量和 `stats.intelligence` / 智力，经验来自 `progression.total_experience` 并按技能点阈值显示为 `经验：当前 / 阈值`，玩家可在有未分配技能点时通过属性旁 `+1` 分配到力量或智力，专长由固定熟练度推导，熟练度按职业熟练度、武器熟练度两组展示完整 13 维。点击 NPC 会打印 ID、发出 `npc_clicked(npc_id)` 并打开 `NPCPanel`。 T0036/T0038 后，NPCPanel 还会按具体库存提供主武器与四个盔甲槽的装备 / 卸下，并提供真实成年马分配：要求 NPC 已入伍且有主武器，分配后马仍物理留在马厩，只有 `rally` / `combat` 时 HorseSystem 才将其切为 `ridden`；收回主武器会自动取消马匹分配，小马、已分配马和不在马厩的马不进入候选。T0040 后面板恢复单栏纵向信息流，宽度按窗口在 380-440px 间响应且始终保持高于宽；高度按当前内容自然高度收缩，只在内容超过上下各 16px 的安全高度时启用外层滚动，窗口放大后重新计算并取消不再需要的滚动。事件库 / 见闻库仍各自滚动；未入伍或合法但尚未分配马匹时不再显示冗余说明，无主武器、无可用成年马、逃离和已分配状态仍正常提示；空的临时操作结果行不占面板高度。

`CombatSystem` 当前读取 `data/enemy_waves.json` 的 5 波 Demo 配置，并可在 `Main/WorldRoot/Station/Enemies` 下生成正门外低模敌人；敌人节点保存 `enemy_id`、波次和完整运行时数据，头顶标签显示名称、HP、兵种/单位类型、当前行动和目标；GM 面板可生成第一波、生成指定波次、触发警铃集结、查看敌人 / 集结 / 逃离 / 可战斗人员可用性 / 失败或胜利快照、推进敌人 AI 或清空敌人。敌人会随逻辑时间选择附近 NPC 或关键建筑作为目标，向目标移动并进行攻击；处于 combat 模式且已入伍持主武器的 NPC 会按逻辑时间和玩家当前选择的战斗策略行动，攻击力/间隔/防御减伤按 T1104 公式结算，敌人 HP 清零后移除；T1106 后敌人波次开始 / 结束会写入广场公开事件并维护本场受伤、昏迷、低血量心理判定和击退统计；T1201/T1202 的逃离意向在 T1203 后会触发逃离驿站流程，写入 `escape_started`、移动到后门外出口、离图后写入 `escaped` 并隐藏 NPC 实体；T1204B 后，逃离挽留打开 / 关闭会通过 CombatSystem 暂停或恢复逃离移动，挽留消息结果和逃离速度变化会写入广场公开事件；逃离攻击只写伤害与 `escape_speed_changed`，无回复计轮和昏迷复苏续逃由 CombatSystem 维护；T1302 后主厅摧毁会触发失败结算、暂停正常推进并显示 HUD 失败界面；T1303 后活动敌人在场时若所有已入伍持主武器战斗人员都昏迷、逃离或正在逃离，会触发无可战斗人员失败；T1304/T1305 后第 5 波清敌会触发胜利结算，`GameState.set_game_over("victory", "five_waves_survived", snapshot)` 保存剩余资源、建筑和 NPC 结局快照，`debug_get_combat_snapshot()` 暴露 `last_victory_result`。当前不会进行复杂寻路或命中率。

`NPCSystem` 提供 NPC 状态、成长、属性分配、建筑移动和战斗移动接口；移动发起与到达都会复验建筑可进入性，升级中或摧毁的建筑拒绝进入，既有室内人员会返回广场。到达后通过 `MemorySystem.move_npc_between_locations(...)` 更新 `people_present`、当前位置和一次性 `location_entry_snapshot`；进出事件仍只记录行动事实。地点节点覆盖广场及全部可进入建筑，主厅、围墙、城门、后门、仓库不作为常规室内空间。建筑外部传播等级、condition、is_enterable 和运作效率分档；精确 HP、精确倍率与剩余时长只在系统 / UI。室内状态包含在场 NPC、逐位置 `id/type/name/occupied_by/status` 与特殊状态；位置增删、改名、改类型和占用按 ID 传播差量，不可进入建筑不暴露室内状态。广场通过 `building_external_states` / `key_entities` 保存全部建筑外部状态，`local_public` 只发给当前地点可接收者且地点不保存历史。制造目标 / 整数阶段与马厩物理数量白名单保持，制造小数进度和马匹个体详情仍不进入 NPC 信息空间。

`ActionSystem` 当前读取 `data/action_defs.json`，执行工作、吃饭、睡觉、普通祈祷、主持弥撒、地点拜访、训练、诊所治疗、带目标 NPC 对话以及修复 / 升级 / 昏迷治疗协助；运行态快照暴露 pending / active 的行动、目标、地点、耗时和已占位置。它在指派、移动到达和建筑状态变化时复验资格 / 可用性，升级中或摧毁会强制中断并送回广场；非神父尝试 `lead_mass` 会得到“没有主持弥撒能力”的结构化失败，普通祈祷不受神父离站影响。制造、马厩、成长、治疗、结构化事件、逃离阻断和 LLMBridge 的真实 provider / 无 fallback 边界保持既有实现；`DailyPlanSystem` 还会把制造阶段材料不足规范为 `resource_insufficient` 后进入真实计划重估。

T1104A 补充：TimeSystem 另提供有效倍率上限请求与倍率快照接口；CombatSystem 只在活动敌人存在时注册 `combat_enemy_presence`，把有效倍率最高压到 `x1`，所有敌人清空或最后一个敌人被移除后释放。玩家速度按钮仍保留 `x1` / `x2` / `x4` 选择，但战斗伤害、攻击间隔、攻击速度和战斗移动速度不读取该玩家倍率作为额外数值输入；若战斗中有 LLM 请求等待，实际有效倍率可进一步降到慢速，请求结束后回到敌人在场的 `x1` 上限。

T1104B 补充：战斗 AI 仍由 TimeSystem 的 `logical_time_tick` 触发，但攻击冷却不直接消费原始游戏秒，而是使用 `game_delta_seconds / 60` 得到的战斗动作秒。GM `step_enemies 60` 约等于推进 1 秒战斗动作；`step_enemies 600` 约等于推进 10 秒战斗动作。该换算只影响战斗攻击冷却和战斗移动表现，不影响工作、治疗、建筑修复 / 升级等经营结算。

T1001-T1003/T1403/T0022/T0049/T0050 补充：当前已实现规则版 24 小时计划调试入口、事件入库、按小时执行、异步计划修改判别 / 修订，以及 `/npc/plan_day` 每日计划接口。常规单次计划可申请 TimeSystem 慢速；正式开局和跨天后的新一天批量计划会暂停时间，以 8 路并发请求真实 provider。正式路径只接受 `source=llm_plan_day`，单人失败最多重试 3 次；仍失败则整批保持暂停，不写入 `rule_plan_fallback` 或 `mock_plan_day`，不执行当前项。对话结束和明确的日常行动失败都先判别精确 `revision_hours`，非空才异步修订并只合并所选小时；指令、战斗 / 复苏和 GM 等其他来源继续直接受限修订。

T1004/T1005/T1405 补充：当前已实现首次睡眠总结链路。`DailyReflectionSystem` 监听睡觉开始、结束和逻辑时间，保证同一 NPC 同一天首次睡眠满 1 游戏小时后才自动生成一次总结；总结会写入第一人称日记、替换式更新知识图谱当前键值并清空该 NPC 的当天短期事件/见闻索引。`LLMBridge` 已接入 `/npc/daily_reflection`，失败时使用模板日记降级，并应保留模型失败日志；常规对话、计划修订和首次睡眠总结请求会申请 TimeSystem 慢速，正式开局每日计划批次则由 GameStartupSystem 直接暂停时间。NPC 面板显示长期日记和 LLM 状态，主场景 NPC 头顶显示思考三点或熟睡禁止标记，GM 面板提供 `reflect_npc <npc_id> [force]`、`long_memory <npc_id>`、`reflection_result` 和 `llm_state <npc_id>`。

T0043 后地点 / 广场信息节点继续采用降噪传播：建筑外部比较等级、condition、is_enterable 和 0/25/50/75/100% 运作效率分档；精确 HP、Max HP、精确效率和剩余修复 / 升级时长不触发见闻。广场与室内进入快照都包含在场 NPC 的生命 / 行动状态；室内还包含完整逐位置清单，后续只传播位置新增、移除、改名、改类型或占用差量。升级开始 / 完成会分别传播封闭清退与重新开放 / 新增位置，受损 / 修复只在效率跨档时传播。广场通过 `building_external_states` / `key_entities` 保存全部建筑外部状态，室内差量只广播给该建筑当前可接收者；summary 使用具体建筑和位置名称。

T0407/T0408/T0409/T0046 已实现：NPC 进入可进入建筑时，`location_entered` 事件库记录只保留“进入某地”的行动事实；建筑外部状态、建筑内 NPC、建筑内 NPC 生命 / 行动状态和工位占用状态只作为进入者的一次性 `location_entry_snapshot` 见闻写入。NPC 进入广场时，进入快照会写入当前广场在场 NPC、广场在场 NPC 的生命 / 行动状态、公告牌当前通告、参考日程及非强制备注和所有建筑外部状态。已经在地点内的 NPC 只收到进入 / 离开事件，不再额外收到完整建筑状态、完整 `people_present` 或完整 `people_statuses`。NPC 离开地点时会生成 `location_exited`，事件地点为其离开的地点，并广播给仍在该地点的 NPC；逃离完成时从全部地点人员节点移除且停止接收见闻。室内信息地点切换到另一个室内信息地点时，事件与地点信息层会插入“离开原地点 -> 进入广场 -> 离开广场 -> 进入目标地点”的中转链；当前物理移动仍是直线占位。后续建筑 / 地点状态变化只传递 `changed_fields` / `changed_workstations` 变化字段。协助修复 / 协助升级都是广场行为；NPC 在室内时会先前往广场，协助开始事件写入 `location_id == "plaza"` 的 `local_public`。

T0501/T0502/T0502A/T0503 已实现：`NPCSystem.apply_damage_to_npc(...)` 是当前 NPC HP 扣除权威入口；GM `attack_npc` / `damage_npc` 命令调用该接口。HP 降到 0 后 NPC 设置为昏迷，不死亡，停止移动并显示 `current_action=unconscious`；`ActionSystem` 会清除该 NPC 的 pending / active 行动，后续行动指派和移动调试都会被拒绝。系统会写入 `damage_taken` 和 `unconscious_started` 事件，其中昏迷事件以 `local_public` 广播到 NPC 当前信息地点，同地点 NPC 会收到见闻。昏迷 NPC 会随 `TimeSystem.logical_time_tick` 以每游戏小时 2 HP 的速度自然恢复；HP 达到 Max HP 的 30% 后自动复苏、回到 `idle`、重新允许移动/行动，并写入 `revived` 本地公开事件。昏迷期间 `MemorySystem.add_witness_event(...)` 会拒绝给该 NPC 写入见闻，因此地点/广场广播、状态变化、公告和进入快照都不会进入其见闻库；复苏后自动恢复接收。2026-06-03 起，该接收规则也覆盖睡觉：`current_action == "sleep_in_dormitory"` 的 NPC 不接收同地点/同建筑 public 见闻，睡醒回到可行动状态后恢复接收，不补收睡觉期间错过的信息。GM `recover_npc <npc_id> <game_seconds>` 可用同一套自然恢复规则推进指定 NPC 的恢复。`ActionSystem.debug_assign_heal_assist(healer_npc_id, target_npc_id)` 可让可行动 NPC 前往昏迷目标所在信息地点协助治疗；每名昏迷目标最多 2 名治疗者，治疗开始和持续过程中消耗第纳尔，医术熟练度越高恢复越快，资源不足会失败或中止；治疗开始/完成写入治疗者和目标的结构化事件，并写入同地点其他在场、未昏迷且未睡觉 NPC 的见闻库，事件信息不暴露医术熟练度。当前仍不实现敌人战斗。

T0808/T0043/T0043A 已实现小诊所诊疗位与病床治疗闭环：初始 `clinic_doctor_station ×1 + clinic_patient_bed ×2`，逐级升级可增加两类位置、诊疗效率和 Max HP。`work_clinic_doctor` 占用诊疗位坐诊或研读医学著作，`receive_clinic_treatment` 让受伤且未昏迷 NPC 占用病床。全部在岗医生按人数、医术和智力共同提高全部病床恢复，诊所升级加成提高活动效率，建筑受损倍率降低单位时间恢复；治疗消耗第纳尔。开始治疗必须有有效医生，活动中全部医生离岗会立即使病人失败并释放病床。无病人时医生仍缓慢研读医术，成长进入统一经验 / 技能点规则。

T0903/T0043/T0043A 已实现训练场团队训练闭环：初始 `training_instructor_station ×1 + training_practice_slot ×2`，逐级升级可增加两类位置、训练效率和 Max HP。`work_training_instructor` 与 `receive_weapon_training` 分别自动占用教官位 / 训练位；无武器且无坐骑不能执教或受训，没有有效教官时受训失败，活动中全部教官离岗也会立即使受训者失败并释放训练位。全部在岗教官的“教练”和对应项目技能共同提高全部训练位成长，训练场升级加成提高效率，建筑受损倍率降低单位时间收益；受训者按自身装备提升技能，教官提升“教练”，独处教官仍可慢速自练。训练消耗疲劳 / 饱食并写 `skill_improved`，成长进入统一经验 / 技能点规则。

摄像机当前绑定 `res://scripts/camera/CameraRig.gd`，支持 WASD 平移、鼠标中键拖拽平移和滚轮缩放；移动限制在驿站地面附近，缩放保持现有高机位俯视角，不提供角色控制或第一人称自由视角。

后端当前稳定流程：

```text
进入 backend
  ↓
安装 requirements.txt
  ↓
启动 Flask app.py
  ↓
访问 GET /health
  ↓
返回 {"ok": true, "service": "war-not-mine-backend", "model_adapter": {...}}
  ↓
无 `.env` 或未设置 LLM_PROVIDER 时，当前 ModelAdapter 仍默认使用 mock provider；该默认值只代表本地开发便利，不代表成品 / Demo 验收路径
  ↓
POST /mock/model 可按 call_type 返回稳定 JSON，并附带伪 token 与用途记录；该接口只用于开发调试和自动化验证。业务接口复用同一个 ModelAdapter 实例并记录 provider、model、call_type、request id、NPC id、关联事件 id、输入 / 输出 token、费用估算、成功状态、fallback_used、http_status、exception_type、degradation_source 和失败原因；GET /debug/llm_usage 可查看累计统计、预算上限 / 已用 / 剩余、最近预算错误、最近失败和逐次记录
  ↓
设置 LLM_PROVIDER=deepseek 或 openai_compatible、LLM_API_KEY、LLM_BASE_URL、LLM_MODEL 后，后端可通过 OpenAI 兼容 /chat/completions 调用真实模型；DeepSeek 默认 base_url 为 https://api.deepseek.com，默认模型为 deepseek-v4-flash。T1401A 后默认 LLM_FALLBACK_TO_MOCK=false，真实 provider 无 Key、请求失败、超时、HTTP 错误、非 JSON 或模型输出不符合业务 Schema 时返回可处理错误并记录真实原因；只有显式设置 LLM_PROVIDER=mock、调用 /mock/model 或显式 LLM_FALLBACK_TO_MOCK=true 时才使用开发期 mock。后续真实 Prompt / API 任务必须在 mock 测试后使用真实 API Key 验证
  ↓
POST /npc/dialogue 可按 T0603/T0041 对话 Schema 校验玩家-NPC / NPC-NPC 请求及非空 `allowed_actions`；该行动参考与日计划复用同一动态候选源，只用于能力边界，不产生计划。NPC-NPC 回复还要求 `replyer_id` 为目标 NPC 且 `response_kind=reply_to_npc`；开发期 mock provider 会返回稳定 JSON，真实 provider 路径读取 `data/prompts/dialogue_system_prompt.txt`，并已用真实 DeepSeek 验证日常、应征、战时、逃离挽留、自主 NPC-NPC 和能做 / 做不到问答
POST /npc/plan_day 可按 T1003/T0025 每日计划 Schema 校验请求；真实 provider 路径读取 `data/prompts/daily_plan_system_prompt.txt`，并在响应 Schema 后校验 24 个 hour 覆盖、精确 action/kind/target/location 候选和至少 6 个工作阶段；合法唯一候选的冗余 kind 可确定性规范化并记录，真实 8 路开局为 8/8 成功且 `fallback_used=false`
POST /npc/plan_revision_judgement 通过 trigger_kind 接收对话事实或程序权威的日常行动失败事实、原计划和工作阶段下限；返回可为空的精确 revision_hours，空数组表示不调用修订；旧 /npc/dialogue_plan_revision_judgement 仅保留兼容
POST /npc/revise_plan 接收 selected_hours、精确 revision_hours、当前计划、失败事实、具名工位占用者、实时资源 / 建筑状态和最低工作阶段约束；返回项必须与请求小时集合完全一致，正式路径仅应用真实 provider 结果，失败保留原计划
POST /npc/battle_judgement 可按 T1202 低血量自身心理判定 Schema 校验请求；T1404 后真实 provider 路径会读取 `data/prompts/battle_judgement_system_prompt.txt`，并在响应 Schema 校验后额外校验 `decision` 属于 `allowed_decisions`、`should_start_escape` 与逃离决定一致；已用真实 DeepSeek 验证战时对话与低血量判定且 `fallback_used=false`
  ↓
POST /npc/daily_reflection 可按 DailyReflectionRequest 校验首次睡眠反思请求；开发期 mock provider 与真实 provider 均只返回稳定的第一人称日记和知识图谱替换式更新，不含独立 `memory_summary`；T1405/T0046 后真实 provider 路径读取 `data/prompts/daily_reflection_system_prompt.txt` 并完成真实 API 验收
  ↓
Godot `LLMBridge` 使用原生 `HTTPClient` 请求 `/health`、`/debug/llm_usage` 和各 NPC AI 业务接口；对话、通用计划修改判别、每日计划、计划修订、低血量心理判定与首次睡眠总结均有异步路径。六类正式业务请求在 `requires_time_slowdown=true` 时申请 TimeSystem 慢速，成功、失败、取消或超时后释放；正式开局每日计划批次由 GameStartupSystem 直接暂停时间，不重复登记慢速。Usage 查询不申请慢速、不写权威状态；`debug_get_llm_runtime_snapshot()` 可查看等待请求、pending request id、有效倍率，以及按 call_type 记录的慢速注册 / 释放审计。
```

T0604A 已将 Godot `LLMBridge` 传输层替换为原生 `HTTPClient` 状态机，不再依赖 `curl.exe`、命令行 JSON 转义或临时请求体文件。正式方向锁定为“玩家电脑 Godot 客户端 -> 游戏服务器后端 -> LLM Provider”：供应商 API Key 默认只存在于服务器后端；玩家自行配置 API Key 仅作为未来可选模式，Demo 阶段不要求实现。

后续预期稳定流程：

```text
启动 Godot
  ↓
进入 Main 场景
  ↓
显示驿站地图、时间、资源栏
  ↓
显示至少 1 个 NPC
  ↓
NPC 可移动到建筑并执行简单工作
```

T0703/T0703A/T0014/T1002 更新：已入伍 NPC 面板显示可用“指令”按钮，可打开自由文本 `OrderPanel` 查看、修改并发布 `current_order`。只有文本变化时才更新结构化指令、递增修订号、写入目标 NPC 的 `private` `order_assigned` 事件并发出计划重评估请求；相同文本或关闭面板无副作用。打开指令面板不会关闭 NPC 面板，但会关闭当前 `DialogPanel`；打开对话也会关闭当前 `OrderPanel`，二者互斥不重叠。`LLMBridge` 会把单条最新指令注入对话顶层 payload 和共享 NPC 上下文，后端 `NPCContext` 让计划、修订、战斗判定、主动交涉、反思和知识图谱更新等请求复用同一字段。发布新指令会经由真实计划重评估链路应用当前小时修订；最终失败保留原计划和真实错误，不应用规则 / Mock 修订。最近注入快照、重评估请求和结果可由 GM 查看。

T0704/T0901/T0036/T0038/T1006 更新：NPC 面板已接入非对话交互入口。给钱仍由全局第纳尔权威结算；武器 / 盔甲装备改为逐件消耗对应 `item_*` 库存，卸下或换装逐件返还原物品。马匹不消耗资源库存，NPC 面板把已入伍且有主武器的 NPC、HorseSystem 中成年 / 未分配 / 物理在厩的马作为双重前置；分配后保留真实 `horse_id`，取消分配或收回主武器会同步清空坐骑槽。装备与分配继续写入 `equipment_given` / `equipment_changed`，攻击、逃离挽留、输入焦点和后续 LLM 记忆规则沿用既有实现。

T0705/T1002/T0051 更新：`NPCSystem.debug_start_proactive_talk(...)` 可让 NPC 主动找守备官交涉；触发后 NPC `current_action=proactive_talk`，头顶显示 `?` 气泡，写入 `private` `proactive_talk_started` 事件。点击气泡会清除主动状态并调用 `DialogSystem.start_proactive_player_dialogue(...)`，把预设开场问题作为会话第一条历史显示；开场与玩家后续内容只在“完成对话”时随整场单条 `dialogue_turn` 入库，取消不入库。有效完成进入真实计划修改判别；主动交涉 1 游戏小时未响应仍按既有超时规则处理。

T0801 更新：职业工作产出框架已接入。`BuildingSystem.claim_workstation(...)` / `release_workstation(...)` 是当前工作位占用和释放的权威接口；工作开始时占用可进入建筑工位，完成、失败或中断时释放，并通过既有 `building_state_changed` 让地点信息节点广播内部工位变化。`ActionSystem` 以行动配置 `duration_seconds` 作为单位工作周期，按 NPC 对应熟练度、力量/智力属性和建筑等级缩短周期时长；普通生产在周期完成时扣投入、加产出并结算饱食 / 疲劳，资源不足会写入 `work_failed` 且不保留工位。T0035 后铁匠铺 / 工械坊周期改为提交制造阶段，T0037 后马厩周期不再直接生成库存。调试指派工作当前默认执行 1 个单位周期，后续每日计划可以在此基础上安排连续多周期工作并沿用“首个开始、最终结束”的事件降噪边界。

T0802 更新：食堂加工餐食已作为独立闭环验证。`work_dining_hall` 使用厨艺，消耗 1 份粮食并产出 1 份餐食；厨艺、智力和食堂等级会缩短加工周期。吃饭行动按 `food_options` 优先消耗餐食，餐食恢复 50 点饱食度；无餐食时消耗粮食，恢复 25 点饱食度。工作与吃饭完成事件会写入对应 NPC 的事件库，并在同地点公开广播。

T0803 更新：菜园产粮已作为独立闭环验证。`work_garden` 使用耕种与力量，基础产出 2 份粮食；配置化 `output_scaling` 会让耕种熟练度、力量和菜园等级提高实际粮食产量。工作完成事件的 `payload.output_resources` 记录缩放后的实际产出；未配置产出缩放的食堂等工作保持固定产出。

T0804/T0035 更新：铁匠铺旧“每周期产出聚合武器 / 盔甲”的历史占位已被 CraftingSystem 替代。`work_blacksmith` 仍使用打铁与力量，且工作效率公式继续读取铁匠铺等级；但必须先在建筑面板选择铁盔、铁护腕、长杆武器、铁护腿、剑盾或锁子甲之一。各配方由 2 / 2 / 3 / 3 / 4 / 6 个阶段组成，每个周期只提交一个阶段和该阶段材料，完成全部阶段后才增加对应具体物品库存。

T0805/T0035/T1508 更新：工械坊旧“每周期产出聚合武器 / 工程器械”的历史占位已被 CraftingSystem 替代。`work_workshop` 仍使用工程与智力，且工作效率公式继续读取工械坊等级；建筑面板可选择箭束、弓、弩、弩床或箭塔，对应 1 / 2 / 4 / 6 / 8 个阶段。完成后分别增加 `item_arrow_bundle`、`item_bow`、`item_crossbow`、`item_wall_ballista`、`item_wall_arrow_tower`，弩床 / 箭塔再由 DefenseDeviceSystem 逐件部署。

T0806/T0037/T0038/T0056 更新：马厩旧“消耗粮食产出 `horse_readiness`”是已废弃的历史占位，当前 `work_stable` 不直接消耗 / 产出资源。HorseSystem 以 active 养马人为条件，按养马熟练度推进在厩马成长、照料额外 HP 和逐马累积繁育概率；至少两匹成年非冷却候选才判定，成功后候选归零并冷却 1 游戏日，马厩等级每升一级只使概率增量增加 10%。每匹马独立消耗饱食、进食耗粮和自然恢复，分配后日常仍在厩，只有集结 / 战斗离厩被骑乘；战时结束 / 昏迷返回马厩，失去入伍资格、主武器或逃离时自动解除分配。更完整的马匹战斗受伤与骑乘移动加成仍留给后续战斗任务。

T0901/T0902/T0031/T0036/T0038 更新：`EquipmentSystem` 仍是武器 / 盔甲装备和兵种投影入口，读取 `data/weapon_defs.json`、`data/armor_defs.json` 与 `data/mount_defs.json`。NPC 档案故事初始装备不扣库存；玩家换装按正式定义的具体 `source_resource_id` 先消耗新物品、再返还旧物品，卸装只返还该件具体库存。坐骑接口委托 HorseSystem 分配真实成年马，`equipment.mount` 只保存 HorseSystem 同步的兼容投影。兵种与战斗策略仍按主武器和当前真实马匹投影判断；`weapons`、`armor`、`defense_devices`、`horse_readiness` 仅保留旧测试 / 存档兼容，不得正式消耗。

T0807/T1507 更新：酒窖酿酒经营层与商人出售层保持分离。`work_tavern` 使用酿酒与智力，消耗 1 份粮食，产出当前派生库存层面的 `wine`；酿酒熟练度、智力和酒窖建筑等级会缩短单位酿造周期，并通过 `output_scaling` 提高实际酒库存产出。酿酒完成不自动换钱；玩家只能在商人每日到访时通过 `MerchantSystem.sell_resource("wine", amount)` 按配置卖价扣酒并增加第纳尔。

## 当前运行方式

```bash
godot --path .
```

或在 Godot 编辑器中打开 `project.godot` 后运行项目。当前启动场景为：

```text
res://scenes/main/Main.tscn
```

T0060 初始长期记忆文案专项验证：

```bash
python tools/verify_npc_initial_long_memory.py
python tools/verify_backend_schemas.py
python tools/verify_dialogue_prompt.py
python tools/verify_plan_day_prompt.py
python tools/verify_dialogue_plan_revision_judgement.py
python tools/verify_plan_revision_prompt.py
python tools/verify_battle_judgement_prompt.py
python tools/verify_daily_reflection_prompt.py
python tools/verify_mock_model_adapter.py
godot --headless --path . --script res://tools/verify_npc_initial_long_memory.gd
godot --headless --path . --script res://tools/verify_npc_character_profiles.gd
godot --headless --path . --script res://tools/verify_daily_reflection_system.gd
godot --headless --path . --script res://tools/verify_gm_panel.gd
python tools/verify_npc_initial_long_memory_real.py
```

T0043 建筑位置专项验证：

```bash
godot --headless --path . --script res://tools/verify_building_service_positions.gd
```

T0043A 服务依赖与弥撒生命周期专项验证：

```bash
godot --headless --path . --script res://tools/verify_service_dependency_interruptions.gd
```

T0044 对话恢复与对象面板专项验证：

```bash
godot --headless --path . --script res://tools/verify_player_dialogue_plan_resume.gd
godot --headless --path . --script res://tools/verify_npc_panel_state.gd
godot --headless --path . --script res://tools/verify_npc_panel_interactions.gd
godot --headless --path . --script res://tools/verify_building_panel_workstations.gd
godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd
```

主界面手动验证：点击小诊所、训练场、小教堂、食堂或宿舍，建筑面板会逐位置显示空闲 / 占用；GM 面板可用行动指派、建筑伤害、升级、建筑快照和“推进模拟 1 小时”复验占位、损伤效率与升级封闭。验证弥撒时先让马塞尔主持，再让另一名 NPC 参加或尝试普通祈祷；改派马塞尔即可观察参加者失败和祈祷席释放。验证 T0049 时，确认普通对话窗已没有“结束后重估计划”开关；完成一轮对话后在 GM 最近 LLM 请求 / 计划结果中观察先判别、非空才修订的两阶段链路，空集合时原小时行动继续。分别打开事件库与见闻库详情，应直接看到最底部最新记录；保持弹窗打开并产生新记录时，当前阅读位置不应被强制拉走。

`Main.tscn` 的 `Main/Systems/GameStartupSystem` 节点可在 Inspector 修改 `Startup Mode`：

- `0` 静止调试：暂停逻辑时间，不生成起床 / 计划 / 行动。
- `1` 正式循环（无新手引导）：默认值，8 名 NPC 先显示“制定计划”；全部计划完成后才统一执行并恢复时间。
- `2` 正式循环（新手引导占位）：使用同一“先制定、后统一执行”循环，并保留未实现的新手引导占位状态。

后端已初始化，可用以下方式启动：

```bash
cd backend
python app.py
```

健康检查：

```bash
curl http://127.0.0.1:5000/health
```

## 换环境恢复 Godot MCP 清单

2026-06-07 重装环境后已确认，Godot MCP 必须同时保证“Node 侧 server 版本、项目 addon 版本、Codex MCP 配置、Godot 编辑器连接”四件事一致。下次换电脑、重装系统或迁移项目时按以下顺序处理：

1. 确认基础工具链：`godot --version` 应为 Godot 4.6.x，`node --version`、`npm.cmd --version` 可用。
2. 安装/锁定 Node 侧 MCP：`npm.cmd install -g @satelliteoflove/godot-mcp@4.0.1`，再用 `godot-mcp.cmd --version` 确认是 `4.0.1`。
3. 检查项目 addon：读取 `addons/godot_mcp/plugin.cfg` 的 `version`，必须与 `godot-mcp.cmd --version` 一致。
4. 如果 addon 版本不一致，在项目根目录运行 `godot-mcp.cmd --install-addon . --force`，然后重启 Godot 编辑器。
5. Codex MCP 配置使用直接命令和 TOML `env` 表；路径按当前 Windows 用户名调整：

```toml
[mcp_servers.godot]
command = 'C:\Users\93741\AppData\Roaming\npm\godot-mcp.cmd'
args = []
env = { GODOT_HOST = "127.0.0.1", GODOT_PORT = "6550" }
```

6. 修改 `%USERPROFILE%\.codex\config.toml` 后必须重启 Codex；当前会话不会热加载 MCP 配置。
7. 复验优先使用 Codex 内置 MCP 工具：`godot_project.addon_status` 应显示 `connected=true`、server/addon 都是 `4.0.1`、`versions_match=true`；`godot_editor.get_state` 应返回当前场景 `res://scenes/main/Main.tscn`。
8. Codex 已连接时不要再用外部 Node/WebSocket 客户端直连 `127.0.0.1:6550` 做握手测试，否则会顶掉当前 Codex MCP 连接，并触发 `Another MCP server connected and replaced this one`。
9. `tools/check_godot_mcp.ps1` 返回 `Godot plugin is running, but MCP is not connected` 时，说明 Godot 插件端口存在但 Codex MCP 没接上；先检查 config、重启 Codex，再用 MCP 工具复验。若出现 `Transport closed`，优先重启 Codex 并确认没有外部 MCP 客户端占用连接。

## 当前主要文件

- `AGENTS.md`：AI Agent 项目协作规则
- `game_design.md`：完整游戏设计源
- `docs/PROJECT_BRIEF.md`：项目简报
- `docs/TASKS.md`：任务列表
- `docs/MODULE_INDEX.md`：模块索引
- `backend/app.py`：Flask 后端入口，提供 `GET /health`、`GET /debug/llm_usage`、`POST /mock/model` 和六类正式业务接口；对话计划判别校验精确小时集合，计划 / 修订校验精确 action/kind/target/location 候选、具名对话目标和最低工作阶段，唯一候选的冗余 kind 可确定性规范化并记录 `model_normalizations`；NPC-NPC 对话校验回复者身份与 `response_kind`
- `backend/services/model_adapter.py`：模型适配器边界，当前仍默认 `mock` provider 用于本地开发，支持 `deepseek` / `openai_compatible` 真实模型调用；正式业务请求使用流式 SSE 聚合完整 JSON，不发送客户端单次输出 token 上限、不设置生成总时长，关闭 thinking，并对六类正式 call_type 的空内容、截断或非法 JSON 做一次业务紧凑重试；usage 记录 token / 费用 / 用途、HTTP 状态或异常类型、`finish_reason`、响应长度、尝试次数、Schema 失败、fallback / 降级来源和运行配置快照
- `backend/schemas/common.py`：后端 AI 接口共享上下文 Schema，包含游戏时间、请求元信息、NPC 状态、短期记忆摘要和行动候选
- `backend/schemas/npc_ai.py`：NPC 对话、对话 / 行动失败通用计划修改判别、每日计划、精确小时计划修订、战斗判定、首次睡眠总结、知识图谱更新、主动交涉和玩家话术分类 Schema
- `tools/verify_backend_schemas.py`：后端 Schema 导入与关键模型实例化验证脚本
- `tools/verify_mock_model_adapter.py`：Mock / DeepSeek-compatible Model Adapter、开发期 mock fallback、usage 统计与 `/mock/model` HTTP 调试接口验证脚本
- `tools/verify_dialogue_mock_endpoint.py`：`/npc/dialogue` Mock 业务接口验证脚本
- `tools/verify_dialogue_prompt.py`：`/npc/dialogue` Prompt 模板 fake real-provider 验证脚本
- `tools/verify_dialogue_prompt_real.py`：`/npc/dialogue` Prompt 模板真实 provider smoke 验证脚本
- `tools/verify_battle_judgement_prompt.py`：战时公开对话与 `/npc/battle_judgement` Prompt 模板 fake real-provider 验证脚本
- `tools/verify_battle_judgement_prompt_real.py`：战时公开对话与 `/npc/battle_judgement` Prompt 模板真实 provider smoke 验证脚本
- `tools/verify_dialogue_plan_revision_judgement.py` / `_real.py`：对话 / 行动失败通用计划判别 Schema、Prompt、endpoint、精确第二层范围与真实 provider 专项
- `tools/verify_action_failure_plan_revision_judgement.gd`：Godot 行动失败空 / 非空判别、精确小时修订、完整第二层上下文和等待屏障专项
- `tools/verify_llm_call_audit.py`：后端六类正式 call_type 无客户端输出上限、截断重试与配置快照审计
- `tools/verify_llm_time_slowdown_audit.gd`：Godot 六类正式 LLM 请求的同步 / 异步慢速注册、释放和只读接口不降速审计
- `tools/verify_llm_bridge.gd`：Godot 侧 LLMBridge、HUD 后端状态、对话 Mock、usage 查询和慢速释放验证脚本
- `tools/verify_dialogue_ui.gd`：对话 UI、玩家/NPC 轮次、私人/公开传播和对话事件验证脚本
- `backend/requirements.txt`：Python 后端依赖
- `project.godot`：Godot 项目配置，当前入口为 `res://scenes/main/Main.tscn`
- `scenes/main/Main.tscn`：最小可运行主场景，包含标准 WorldRoot、Systems、UI、CameraRig 节点结构、低模驿站 Blockout 和基础 HUD
- `scripts/systems/GameStartupSystem.gd`：三状态开局编排；正式模式暂停时间，以 8 路并发等待 8 人真实计划全部成功后统一执行并恢复循环
- `scripts/systems/DailyPlanSystem.gd`：每日计划生成、8 路后台真实请求、最多 3 次真实尝试、执行与异步重评估；正式开局 / 新一天失败保持 `planning_day` 且不降级
- `tools/verify_game_startup_modes.gd` / `tools/verify_game_startup_real_async.gd` / `tools/verify_formal_plan_real_only.gd`：验证三个启动模式、计划完成前不执行、8 人真实 `llm_plan_day` 成功后统一执行和正式路径拒绝 Mock provider
- `scripts/ui/HUD.gd`：HUD 展示脚本；主栏按 `show_in_main_hud` 过滤资源，装备 / 器械详情按 `detail_group` 显示具体物品库存，并从 HorseSystem 读取物理在厩和分配数量
- `scripts/systems/LLMBridge.gd`：Godot 侧后端桥接，支持六类正式业务异步请求、业务请求无固定总时长、对应 payload 构造、TimeSystem 慢速注册 / 释放和按 call_type 的运行态审计
- `scripts/systems/DialogSystem.gd`、`scripts/ui/DialogPanel.gd`：对话会话、后端请求编排、事件入库与对话 UI
- `scripts/ui/BuildingPanel.gd`：建筑面板脚本；逐位置显示名称 / 占用、建筑状态和精确效率，并提供修复升级、制造项目和马厩个体只读展示
- `scripts/world/NoticeBoard.gd`、`scripts/ui/NoticeBoardPanel.gd`：公告牌独立点击/预览与“通告 / 参考日程”双 Tab 草稿编辑 UI；发布只调用 MemorySystem 的广场公告牌状态接口
- `scripts/ui/MerchantPanel.gd`：商人交易 UI，显示配置报价和驿站库存，并把买入/卖出请求交给 MerchantSystem
- `scripts/ui/NPCPanel.gd`：NPC 面板脚本；在既有状态 / 计划 / 记忆交互上，按具体库存装备 / 卸下武器和四个盔甲部位，并为满足入伍 + 主武器条件的 NPC 分配 / 取消分配真实成年马
- `scripts/ui/GMPanel.gd`：GM 调试面板脚本，提供可拖动半透明 GM 按钮、命令输入框和资源/时间/建筑/NPC/行动/记忆/LLM usage 调试入口；行动分组用行动下拉 + “指定行动”统一触发普通行动，“修复目标”“升级目标”和“治疗目标”下拉用于测试协助修复/协助升级/协助治疗；顶部 `GM_ENABLED` 常量可切换开发/上线显示
- `scenes/npc/NPC.tscn`：通用 NPC 占位场景，当前为可点击低模实体和短姓名/HP/当前行动标签
- `scripts/npc/NPC.gd`：NPC 展示脚本，保存唯一 ID，刷新调试标签，在点击时发出 `npc_clicked`，支持直线移动到指定地点，并在集结 / 接敌时显示朝向标记和低模坐骑
- `scripts/camera/CameraRig.gd`：基础俯视摄像机控制，支持 WASD/鼠标中键平移、滚轮缩放和边界限制
- `scripts/core/EventBus.gd`：全局事件总线，声明基础跨系统信号；`building_clicked` 表示玩家/调试选择建筑，`building_state_changed` 表示建筑数据刷新
- `scripts/core/GameState.gd`：全局运行状态，保存天数、小时、分钟、秒和战斗状态
- `scripts/core/ConfigLoader.gd`：JSON 配置读取入口，提供缺失/解析错误提示
- `scripts/systems/ResourceSystem.gd`：资源事实源，从 `data/resource_defs.json` 初始化基础资源与 11 种具体物品库存；旧聚合 id 仅兼容保留且不允许正式结算
- `scripts/systems/BuildingSystem.gd`：建筑 / 逐位置 / 可进入性 / 损伤效率 / 修复升级权威；提供 `level_effects`、固定类型保护和 `special_state` 分节接口
- `scripts/systems/NPCSystem.gd`：基础 NPC 系统，从 `data/npc_profiles.json` 生成 8 个 NPC 占位实体，并提供查询、状态更新、调试选择、调试移动、集结世界坐标移动、接敌停止移动和即时进入地点调试接口
- `scripts/systems/ActionSystem.gd`：日常行动权威系统；负责资格、自动占位、团队诊疗 / 训练、周期效率、封闭中断和结构化失败，并继续衔接制造 / 马匹系统
- `scripts/systems/CraftingSystem.gd`：铁匠铺 / 工械坊制造权威系统，读取 11 个配方，维护目标、整数阶段、当前周期进度、材料原子扣除、具体成品入库与建筑特殊状态
- `scripts/systems/HorseSystem.gd`：真实马匹权威系统，维护两匹初始 60% 刚成年马与后续小马的总 / 基础 / 照料额外 HP、饱食、进食、成长、累积繁育概率 / 冷却、位置、分配和战时骑乘；马厩等级每级仅为繁育概率增量增加 10%
- `scripts/systems/MemorySystem.gd`：结构化事件与地点信息系统；传播建筑外部效率分档、室内逐位置增删 / 占用差量和既有特殊状态白名单
- `scripts/systems/MerchantSystem.gd`：读取商人配置、跟随逻辑时间控制后门到访、调用 ResourceSystem 权威结算买卖，并通过 MemorySystem 写入商人公开事件
- `scripts/systems/DefenseDeviceSystem.gd`：读取器械 / 槽位配置，逐件消耗 `item_wall_ballista` / `item_wall_arrow_tower`，权威结算占槽、自动攻击和部署 / 触发事件；部署 API 不需要 NPC
- `scripts/world/DefenseDevicePresenter.gd`、`scripts/world/DefenseDeviceView.gd`、`scenes/defense_devices/DefenseDeviceView.tscn`：消费部署快照生成低模表现，固定提供 `ModelMount` 和可选正式模型实例化入口
- `scripts/systems/TimeSystem.gd`：基础逻辑时间系统，支持 24 小时阶段、秒级显示、暂停、加速、跨天、LLM 等待减速请求、敌人在场有效倍率上限请求、`logical_time_tick` 和 `time_changed` / `time_scale_changed` / `hour_started` / `day_started` 信号
- `scripts/systems/CombatSystem.gd`：敌人波次读取、调试生成、警铃集结、非战斗人员避战、敌人目标优先级 / 移动 / 攻击、双方基础自动攻击、不同兵种战斗策略和战斗开始 / 结束流程系统；读取 `data/enemy_waves.json`，在 `Station/Enemies` 下生成低模敌人实体并提供生成 / 清空 / 快照 / AI 推进调试接口；攻击冷却按战斗动作秒推进，活动敌人存在时注册 TimeSystem `x1` 上限，战斗策略由当前装备 / 兵种提供选项并由玩家手动选择，战斗内避战只在敌人低于安全阈值时短步长远离且够远后等待；波次开始 / 清敌结束会写入广场 `combat_started` / `combat_ended`
- `data/resource_defs.json`：基础资源、11 种具体物品库存及 HUD 分组定义；`weapons` / `armor` / `defense_devices` / `horse_readiness` 只作弃用兼容，不允许正式消耗
- `data/crafting_recipes.json`：铁匠铺 6 个、工械坊 5 个制造配方及 1-8 阶段材料定义
- `data/horse_defs.json`：两匹初始 60% 刚成年马与饱食、进食、恢复、成长、繁育概率增量 / 上限 / 冷却、照料额外 HP 平衡参数
- `data/merchant_defs.json`：后门商人到访时段与粮食/木材/石料/铁买价、酒卖价配置
- `data/defense_device_defs.json`：弩床 / 箭塔、围墙部署槽、权威效果数值与表现元数据配置
- `data/building_defs.json`：15 个建筑 / 门墙实体的等级、HP、场景绑定、逐位置清单、固定位置类型、受损效率、修复和逐级升级效果；包含五座服务建筑的 T0043 数量 / 扩容规则，公告牌不在建筑定义中
- `data/notice_board_defaults.json`：守备官口吻的初始通告、10 条通用参考日程与固定参考性备注；由 MemorySystem 初始化广场状态与初始 NPC 见闻
- `data/action_defs.json`：各职业工作、诊疗 / 训练、吃饭、睡觉、普通祈祷、主持弥撒、地点拜访、NPC-NPC 对话、主动交涉、逃离意向和目标协助行动；位置型行动声明具体 `workstation_type`
- `tools/verify_dialogue_action_reference.gd`：验证 7 个非计划对话上下文都携带非空行动参考，并与同 NPC 的日计划候选逐项一致
- `tools/verify_dining_hall_meals.gd`：T0802 食堂粮食加工餐食、餐食优先进食和事件入库专项验证
- `tools/verify_crafting_pipeline.gd`：11 个配方、未选目标阻止工作、阶段中断 / 保留、切换确认 / 清零、成品入库、特殊状态与建筑面板专项验证
- `tools/verify_horse_ecology_assignment.gd`：初始两匹成年马、喂食 / 恢复 / 成长 / 生育、特殊数量状态、分配与战时离厩 / 回厩专项验证
- `tools/verify_hud_resources.gd`：具体物品主栏隐藏、装备 / 器械详情分组、真实马厩数量和旧聚合库存不泄漏专项验证
- `tools/verify_garden_grain_output.gd`：T0803 菜园产粮、耕种/力量/菜园等级产出加成和完成事件专项验证
- `tools/verify_blacksmith_metal_gear.gd`、`tools/verify_workshop_ranged_devices.gd`、`tools/verify_stable_horse_care.gd`：T0804-T0806 聚合库存时代的历史回归脚本；当前制造 / 马匹正式验收以 `verify_crafting_pipeline.gd` 和 `verify_horse_ecology_assignment.gd` 为准
- `tools/verify_tavern_wine_trade.gd`：T0807 酒窖酿酒/智力/建筑等级效率、粮食消耗、酒库存产出、完成事件和不在酿酒时自动出售专项验证
- `tools/verify_notice_board_input.gd`：T1506 公告输入、广场状态、在场 NPC 广播与非建筑边界专项验证
- `tools/verify_merchant_trade_system.gd`：T1507 商人时段、报价、买入/卖酒、失败原子性和结构化事件专项验证
- `tools/verify_equipment_system.gd`：具体武器 / 盔甲逐件消耗与返还、真实成年马分配、收回主武器自动取消马匹和旧聚合库存不消耗专项验证
- `tools/verify_defense_device_deployment.gd`：弩床 / 箭塔具体库存与占槽原子性、自动攻击、公开见闻和模型挂点专项验证
- `tools/verify_combat_flow.gd`：T1106 战斗开始广播、接敌入战 / 避战、敌人全灭结束广播、受伤 / 昏迷 / 击退统计和清敌回工作状态专项验证
- `data/weapon_defs.json`：剑盾、长杆、弓、弩正式主武器定义；每类指向唯一具体 `source_resource_id`，`attack_interval` 按战斗动作秒解释
- `data/armor_defs.json`：铁盔、锁子甲、铁护腕、铁护腿定义；每个部位指向唯一具体 `source_resource_id`
- `data/mount_defs.json`：真实马匹同步到装备槽时使用的通用骑乘参数模板，不再声明库存来源
- `data/enemy_waves.json`：5 波 Demo 敌人配置，记录生成点、生成位置、敌人数量、HP、武器类型、单位类型、攻击、防御、移动速度、攻击范围、攻击间隔和目标偏好；第一波已按 T1104B 校准为低强度探路敌人；T1104C 起目标偏好不包含围墙
- `data/npc_profiles.json`：NPC 档案配置，当前包含 8 名初始 NPC：托马、布鲁诺、伊沃、格伦、艾达、马塞尔、莉娜、欧文；每人都有短背景、人格、欲望、恐惧、底线和宽松 `speech_style`，不再保存固定 `signature_lines`；老兵副官开局 `recruited=true`，其他 NPC 初始未入伍且不能接收守备官个人指令

## 当前风险

- 系统设计较大，需要严格按最小闭环推进。
- NPC 自主计划、LLM 对话、战斗系统不能同时展开。
- `game_design.md` 内容较长，Agent 必须按模块精确读取，避免上下文浪费。
- Godot 侧 LLMBridge 已使用原生 HTTP，T0701 对话 UI 已在该桥接层上接通；仍不得让客户端保存供应商 API Key 或直连模型供应商。
- 真实 LLM 并发、成本、限流和 API Key 管理必须放在后端；不要把客户端直连模型或玩家必须自带 Key 当作 Demo 默认方向。
- 当前 `backend/app.py` 已是后端应用入口，但仍是本地开发形态；正式给玩家使用前需要执行 T1407，用生产 WSGI 服务、部署文档、环境变量、日志、限流和健康检查把后端部署到服务器。

## 最近一次变更

- T0061 NPC 背景叙事与知识面板收束：移除正式档案、共享身份 Schema、六类 payload / Prompt 和背景弹窗中的固定代表性表达；按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜重写前两篇开局前日记，形成身世与到站群像，近日篇保持 T0060 微观日常；守备官关系统一为职责型 `role`，建筑知识改为职业视角下的世界内常识。为删除未实现的仓库容量 / 丢货暗示，仅迁移 8 条仓库 `value` 为 `central_storage_and_post_breach_attack_target`，其余技术值不变，222 条元数据完整。静态 / Prompt / Schema / Mock / endpoint、5 个 Godot 专项、3 次真实 DeepSeek 和 Godot MCP 运行态验收全部通过；玩家知识弹窗隐藏可信度与更新时间，底层和 GM 继续保留。
- T0056 马匹成长与繁育反馈：栗风 / 灰鬃改为 60% 刚成年开局；HorseSystem 增加逐马累积繁育概率和 1 游戏日产后冷却，BuildingPanel 拆分基础 / 照料额外 HP 并显示概率与冷却。新增专项覆盖初始成长、照料增长、必成出生、归零、冷却冻结和 UI。
- T0055 持续活动 / 周期结算常识：共享规则禁止把未完成周期或离岗后的预期收益当成已发生。真实 DeepSeek 菜园专项确认“周期到了才算数，离岗后无人接手就没产出”，无 fallback；T0058 后当前规则集为 6 条。
- T0054 NPC LLM 驿站常识上下文：新增 `data/station_context.json`，把动态在站人员、BuildingSystem 全建筑目录、ActionSystem 工作模式行为目录和四条世界内驿站规则统一注入六类正式请求；Schema / 六份 Prompt / Mock / Godot / GM 只读入口同步更新。真实 DeepSeek 六条业务路径全部通过且 `fallback_used=false`。
- T0051 可拖动弹窗与守备官会话生命周期：新增统一 `DraggablePanel` 并接入 8 类窗口；DialogSystem 增加完成 / 取消 / 挂起、即时玩家消息、整场事件提交、暂存权威结果、攻击取消锁、橙色恢复气泡 / 橙点和 7200 逻辑秒超时。新增 `verify_dialogue_session_lifecycle.gd`，并更新对话 UI、逃离、战时、睡眠边界、主动交涉、计划竞态和 NPC 面板回归；真实 DeepSeek 对话 usage 复验成功且无 fallback。
- T0041/T0043A 非计划 NPC 对话行动参考：`LLMBridge` 为所有玩家-NPC / NPC-NPC 对话复用日计划动态 `allowed_actions`，后端要求列表非空，Prompt 明确只作能力边界、不生成计划或已执行事实；Godot 覆盖 7 个子上下文和 33 条当前候选（含参加弥撒及依赖上下文），真实 DeepSeek 玩家-NPC / NPC-NPC 能力问答均正确否认列表外“骑飞龙”，6 次调用 0 失败、0 fallback。
- T0035-T0038 制造、具体库存与真实马匹闭环：新增 CraftingSystem / HorseSystem 及对应数据；铁匠铺 / 工械坊按 11 个配方、1-8 个阶段推进具体成品，建筑面板提供目标下拉、进度条和非零进度切换确认；武器 / 盔甲 / 器械逐件结算具体 `item_*`，旧聚合资源仅兼容保留；当时的两匹成年马、生育和额外 HP 基础闭环已由 T0056 进一步改为 60% 刚成年、逐马累积概率 / 冷却和拆分 HP UI。制造 / 马匹专项还覆盖进入快照、仅室内字段差量和个体信息防泄露；具体装备、器械、HUD、NPC 面板、兵种、训练、战斗与 GM 共 27 项整合回归通过，主场景 `--headless --quit-after 1` 通过。
- T1506/T0046 公告牌：主厅前 `NoticeBoard` 可点击打开“通告 / 参考日程”双 Tab；草稿只在“发布”后通过 MemorySystem 更新广场状态，退出丢弃。通告与日程分别生成 `plaza_notice_changed` / `plaza_schedule_changed`，即时广播给当前在场 NPC 并在后续入场快照提供当前内容；初始内容预写全部初始 NPC 见闻，日程始终携带不强制执行的备注。逃离完成者会从地点人员节点移除并停止接收后续见闻；全天已排满时新增草稿会明确提示先调整重叠时段。公告牌仍不是建筑。验证覆盖 `verify_notice_board_input.gd`、`verify_notice_board_tabs.gd`、`verify_escape_station_behavior.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_structured_memory_events.gd` 和项目 headless 加载。
- T0046 长期记忆 / 场景上下文：后端 Schema、Model Adapter、Prompt、DailyReflectionSystem、NPCSystem 与 NPCPanel 一致移除独立 `memory_summary`，并增加主体 / 关系 / 值三类中文显示文本与未知内容中文保底；顶层必填且非空的 `station_context` 统一覆盖携带 NPC 人设的请求，运行态已验证 8 人名单在一人离站后缩减为 7 人。真实 DeepSeek `deepseek-v4-flash` 验证：收紧中文值合同后的反思 1 次、共享场景上下文 4 类业务，8 人计划采样 8/8 成功、0 fallback、0 重试；计划采样 usage 为 input 126323 / output 13974 tokens。Godot MCP 本轮不可调用，已按规则报告并改用 Godot headless 专项与主场景加载验收。
- T1507 商人交易：后门商队按 `data/merchant_defs.json` 每日 10:00-16:00 到访，玩家可按配置购买粮食/木材/石料/铁并出售酒；`MerchantSystem` 调用 ResourceSystem 权威结算，成功后记录商人到达/离开/交易公开事件，失败交易不改变资源。验证通过：`verify_merchant_trade_system.gd`、`verify_tavern_wine_trade.gd`、`verify_hud_resources.gd`、`verify_gm_panel.gd` 和项目 headless 加载。
- T1501 8 名 NPC 姓名与职业语气（历史，T0061 已收束）：T1501 当时为 8 人加入 `speech_style` 和 3 条短 `signature_lines`，并完成 8 次真实 DeepSeek 职业身份对话。T0061 当前已删除固定台词样例及其 Schema / payload / Prompt 注入，只保留宽松 `speech_style` 和职业视角；T1501 的真实调用结果不作为 T0061 验收。
- T1501 Godot MCP 验收（历史，T0061 已收束）：当时运行态确认的 3 条 `signature_lines` 已不再是当前档案合同；当前人物弹窗和共享身份上下文均不提供该字段。
- T1304 第 5 波胜利条件：`CombatSystem` 在包含最终波次的战斗清敌后触发 `victory/five_waves_survived`，`GameState` 记录通用 `game_over_reason` 与 `settlement_snapshot`，快照包含剩余资源、建筑状态和 NPC 可行动 / 昏迷 / 逃离状态；TimeSystem 复用 game-over 广播暂停推进，HUD `GameOverPanel` 显示“防守成功”、守住 5 波、剩余资源 / 建筑 / NPC 摘要。结算后 `spawn_wave(...)` 会拒绝继续生成敌人。新增 `tools/verify_five_wave_victory.gd`。验证通过：`verify_five_wave_victory.gd`、`verify_main_hall_failure.gd`、`verify_enemy_wave_schedule.gd`、`verify_no_available_combatants_failure.gd`、`verify_combat_flow.gd`、`verify_hud_resources.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- T1305 NPC 结局总结页面：`GameState.set_game_over(...)` 会为胜利和失败结算补齐 NPC 结局快照，每名 NPC 记录最终状态（可行动 / 昏迷 / 逃离）、是否入伍、最后位置、Mock 最终看法、Mock 后续命运和日记 / 事件记忆依据；HUD `GameOverPanel` 的详情区改为滚动区，胜利和失败都显示 NPC 结局总结，且验证覆盖不出现“阵亡 / 死亡”表述。验证通过：`verify_five_wave_victory.gd`、`verify_main_hall_failure.gd`、`verify_no_available_combatants_failure.gd`、`verify_hud_resources.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`；Godot MCP 运行 `Main.tscn` 后编辑器错误日志为空。
- T1106 战斗开始/结束流程：`CombatSystem.spawn_wave(...)` 生成敌人后在广场写入 `combat_started`，记录波次、敌军 roster、我方已入伍持主武器 NPC roster 和非战斗人员数量；敌军全灭或 GM 清敌后写入 `combat_ended`，统计本场受伤 / 昏迷 NPC 和各 NPC 击退敌人数量；清敌时 `combat` 回 `work` 并重评估计划，`avoid_combat` 与未接敌 `rally` 回 `work` 且不因单纯退出重评估；战前警铃但尚无敌人时不会被普通逻辑 tick 当作清敌回收。新增 `verify_combat_flow.gd`。验证通过：`verify_combat_flow.gd`、`verify_combat_damage.gd`、`verify_combat_alarm_rally.gd`、`verify_avoid_combat_mode.gd`、`verify_combat_strategies.gd`、`verify_combat_time_cap.gd`、`verify_combat_pacing.gd`、`verify_enemy_wave_generation.gd`、`verify_gm_panel.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`。
- T1104C 移除围墙作为敌人攻击目标：敌人波次和 CombatSystem 默认目标偏好不再包含 `wall`，运行时会过滤旧配置中的 `wall` / `front_wall`；敌人无附近可行动 NPC 时按城门、仓库、主厅推进，城门被攻破后直接转向仓库。`verify_enemy_target_priority.gd` 已覆盖城门破坏后跳过围墙、围墙 HP 不变、仓库破坏后转向主厅。验证通过：`verify_enemy_target_priority.gd`、`verify_enemy_wave_generation.gd`、`verify_combat_damage.gd`、`verify_gm_panel.gd`、`verify_combat_pacing.gd`、`verify_combat_time_cap.gd`、`godot --headless --path . --quit-after 1`。
- T1103D 模式切换事件降噪：`work -> combat`、`combat -> work`、`work -> avoid_combat`、`avoid_combat -> work` 不再写入 `npc_mode_changed` 或通过该事件广播；避战开始 / 结束、攻击、伤害、警铃、集结、昏迷和复苏等具体事实事件保留。验证通过：`godot --headless --path . --quit-after 1`、`verify_avoid_combat_mode.gd`、`verify_behavior_mode_state_machine.gd`、`verify_combat_damage.gd`、`verify_combat_pacing.gd`、`verify_gm_panel.gd`。
- T1104B 战斗动作秒与第一波节奏校准：修正战斗冷却直接消费 TimeSystem 游戏秒导致 `x1` 下现实 1 秒内发生几十次攻击的问题；CombatSystem 现在把 `60` 游戏秒折算为 `1` 战斗动作秒推进双方攻击冷却，敌人移动仍使用 `game_delta_seconds / 60` 的动作秒级位移；第一波劫掠者调为低强度探路敌人。新增 `verify_combat_pacing.gd` 覆盖艾达持剑对第一波的基准节奏，`verify_enemy_target_priority.gd` 按新攻击力延长主厅破坏推进时长。验证通过：`verify_combat_pacing.gd`、`verify_combat_damage.gd`、`verify_enemy_target_priority.gd`、`verify_combat_time_cap.gd`、`verify_gm_panel.gd`、`verify_combat_alarm_rally.gd`、`verify_avoid_combat_mode.gd`、`verify_enemy_wave_generation.gd`、`verify_time_system.gd`、`godot --headless --path . --quit-after 1`；`git diff --check` 仅提示 `docs/CURRENT_STATE.md` CRLF/LF 转换。
- T1104A 战斗时间倍率脱钩与敌人在场限速：战斗伤害、攻击间隔、攻击速度和战斗移动速度不再读取玩家 `x2` / `x4` 作为额外倍率；TimeSystem 新增有效倍率上限请求与倍率快照，CombatSystem 在活动敌人存在时注册 `combat_enemy_presence` `x1` 上限，清敌或最后一个敌人移除后释放；GM 新增时间倍率快照按钮与 `time_snapshot` 命令。验证通过：`verify_combat_time_cap.gd`、`verify_time_system.gd`、`verify_gm_panel.gd`、`verify_combat_damage.gd`、`verify_enemy_target_priority.gd`、`verify_combat_alarm_rally.gd`、`verify_avoid_combat_mode.gd`、`godot --headless --path . --quit-after 1`；`git diff --check` 仅提示 `docs/CURRENT_STATE.md` CRLF/LF 转换。
- T1103 警铃与集结：HUD 警铃和 GM `alarm` / `rally` 现在会调用 `CombatSystem.trigger_combat_alarm(...)`。所有 NPC 写入 `combat_alarm_rang`，入伍且持主武器、当前可行动的 NPC 会打断普通行动并前往城门外防线；近战 / 骑兵前排、弓弩 / 骑射后排，集结和接敌状态显示朝向标记，已装备坐骑的 NPC 只在集结 / 接敌时显示低模坐骑。集结途中遇敌会停止移动并切到 `combat_ready`，写入 `combat_rally_encountered_enemy`。验证通过：`verify_combat_alarm_rally.gd`、`verify_gm_panel.gd`、`verify_enemy_target_priority.gd`、`verify_equipment_system.gd`、`godot --headless --path . --quit-after 1`。
- T1303 无可战斗人员失败条件：`CombatSystem` 会在波次生成、逻辑推进、NPC 昏迷、逃离开始和逃离完成后检查活动敌人在场时的战斗人员可用性；已入伍且持主武器、未昏迷、未逃离且未正在逃离的 NPC 计为可抵抗人员，工作 / 尚未集结 / 尚未接敌状态不会被误判为不可抵抗。若曾存在可战斗人员但全部昏迷、逃离或正在逃离，会把 `GameState` 标记为 `failure/no_available_combatants`、记录可用性快照、暂停 TimeSystem 并显示 HUD 失败结算界面。验证通过：`verify_no_available_combatants_failure.gd`、`verify_main_hall_failure.gd`、`verify_combat_flow.gd`、`verify_combat_time_cap.gd`、`verify_enemy_wave_schedule.gd`、`verify_enemy_target_priority.gd`、`verify_combat_damage.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- T1102/T1302 敌人目标优先级与主厅失败：`CombatSystem` 现在会随逻辑时间为活动敌人选择目标，附近可行动 NPC 优先，否则按城门、仓库、主厅顺序推进；T1104C 起不再把围墙作为敌人攻击目标。敌人会向目标移动并进行接触式攻击，建筑受击写入 `building_damaged`，NPC 受击复用 `NPCSystem.apply_damage_to_npc(...)`；主厅 HP 清零会把 `GameState` 标记为 `failure/main_hall_destroyed`、记录失败时间、暂停 TimeSystem 并显示 HUD 失败结算界面。GM “推进敌人AI”和 `step_enemies [game_seconds]` 可触发相关流程。验证通过：`verify_main_hall_failure.gd`、`verify_enemy_target_priority.gd`、`verify_enemy_wave_generation.gd`、`verify_gm_panel.gd`、`verify_building_repair_upgrade.gd`、`verify_npc_damage_unconscious.gd`、`godot --headless --path . --quit-after 1`。
- T1101 敌人配置与敌人生成：`data/enemy_waves.json` 已配置 5 波逐步增强的敌人，`CombatSystem` 会读取配置并在正门外 `Station/Enemies` 下生成低模敌人实体；GM 面板新增“战斗 / 敌人”分组和 `spawn_wave` / `enemy_wave` / `enemies` / `clear_enemies` 命令；主场景扩大正门外地面、正门道路和摄像机 Z 轴边界。验证通过：`verify_enemy_wave_generation.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- T0014 UI 面板体验修正：GM 面板行动区去掉工作、吃饭、睡觉、当教官和当受训者等并列快捷按钮，普通行动统一由行动下拉和“指定行动”触发；NPC 面板事件库和见闻库改为固定高度滚动区并自动滚到底部；点击“对话”或“指令”不再关闭 NPC 面板，`DialogPanel` 与 `OrderPanel` 互斥不重叠。验证通过：`verify_gm_panel.gd`、`verify_npc_panel_state.gd`、`verify_npc_panel_interactions.gd`、`verify_npc_order.gd`、临时以 `LLM_PROVIDER=mock` 启动 `backend/app.py` 后运行 `verify_dialogue_ui.gd`、`godot --headless --path . --quit-after 1`。
- T0903 训练场与武器熟练度提升：`data/building_defs.json` 将训练场拆为教官工位和受训位，`data/action_defs.json` 新增 `work_training_instructor` / `receive_weapon_training`；`ActionSystem.gd` 实现无装备拒绝、无教官受训失败、教官独自练习、带受训者训练、教官“教练”成长、受训者武器 / 骑术成长、训练疲劳 / 饱食消耗和训练 `skill_improved` 事件；训练可通过 GM 行动下拉或 `train_instructor` / `train_student` 命令验证；新增 `tools/verify_training_system.gd`。验证通过：`verify_training_system.gd`、`verify_gm_panel.gd`、`verify_action_system_basic.gd`、`verify_work_output_framework.gd`、`verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_clinic_treatment.gd`、`godot --headless --path . --quit-after 1`。
- T0015 NPC 成长 UI 与 GM 入伍入口修正：NPC 面板移除独立成长说明文本，经验改为 HP 右侧 `经验：当前 / 阈值`；属性旁 `+1` 只在有未分配技能点时出现，用完后消失。GM 面板新增“设为入伍”按钮和 `recruit_npc` 命令，调用 `NPCSystem.set_npc_recruited(...)`。验证通过：`verify_npc_panel_state.gd`、`verify_skill_progression.gd`、`verify_gm_panel.gd`、`verify_npc_order.gd`、`verify_npc_panel_interactions.gd`、`verify_dialogue_ui.gd`、`verify_equipment_system.gd`、`godot --headless --path . --quit-after 1`，Godot MCP 运行主场景日志为空。
- T0904 职业熟练度与经验升级：`NPCSystem.gd` 新增运行时 `progression`、统一 `increase_npc_skill(...)` 经验入口和 `assign_npc_attribute_point(...)` 玩家分配入口；工作完成会缓慢提升对应职业熟练度，诊所与训练成长同步进入总经验和技能点规则；每 5 点总经验获得 1 个未分配技能点。NPC 面板可在有未分配技能点时通过属性旁 `+1` 分配力量 / 智力，GM 面板支持 `assign_attribute` 命令；属性分配写入 `attribute_improved` 事件。验证通过：`verify_skill_progression.gd`。
- T0013 移除短剑旧占位装备：`data/weapon_defs.json` 删除旧占位主武器定义，正式主武器只保留剑盾、长杆、弓和弩；`NPCSystem.gd` 移除旧占位武器兼容入口；装备系统、HUD 详情和兵种判定验证增加旧占位武器不可出现的回归断言。验证通过：`verify_equipment_system.gd`、`verify_unit_type_classification.gd`、`verify_hud_resources.gd`、`verify_gm_panel.gd`、`godot --headless --path . --quit-after 1`。
- T0011 HUD 完整资源库存与装备/器械详情（历史）：当时曾把武器、盔甲、工程器械和马匹整备聚合库存纳入详情；T0036/T0038 已用具体物品分组和真实马匹数量替换该展示。四类聚合 id 仅作兼容保留、正式 HUD 隐藏且不得正式消耗；同名 `verify_hud_resources.gd` 已迁移为当前具体库存 / 真实马匹回归脚本。
- T0703 入伍 NPC 自然语言指令：新增 `OrderPanel`；`NPCSystem` 权威保存 `current_order`、写入私有 `order_assigned` 并发出计划重评估请求；GM 新增指令观察入口；新增 `tools/verify_npc_order.gd`。
- T0701 对话 UI：NPC 面板新增对话按钮；新增 `scripts/ui/DialogPanel.gd`，`DialogSystem.gd` 接通玩家-NPC / NPC-NPC 会话、历史、轮次、LLMBridge 请求和结构化事件；`MemorySystem` 将对话事件写入所有参与 NPC 事件库，并确保 `local_public` 只广播给同地点第三者。新增 `tools/verify_dialogue_ui.gd`。验证通过相关 UI、LLMBridge、结构化事件、NPC 面板、GM、后端 Schema/接口与项目加载回归。
- T0701 Toggle 修复：DialogPanel 的“同地点公开”开关可在首轮发送前切换并同步到 DialogSystem，首轮发送后锁定；专用验证覆盖私人/公开双向切换与第三者见闻传播。
- T0701 对话事件降噪（历史，已由 T0051 扩展）：打开空窗口不生成事件；当前守备官-NPC 会话改为“完成”时将已有完整历史写入单条 `dialogue_turn`，即使最后一条 NPC 回复尚未返回也保留已经说出口的守备官消息；取消不入库。
- T0702 提出应征与征召结果：DialogPanel 新增一次性“提出应征”标记；Mock 返回 `accept` 后由 NPCSystem 权威更新入伍状态，`reject` 不改变状态；结果写入 `dialogue_turn.payload`，已入伍 NPC 面板显示待由 T0703 替换为自然语言“指令”入口的旧指派占位。
- T0604A LLMBridge 原生 HTTP：`scripts/systems/LLMBridge.gd` 已用 Godot 原生 `HTTPClient` 状态机替换 T0604 的 `curl.exe` / 临时 JSON 文件传输层，保留 payload 构造、错误字典、`backend_status_changed` 和 TimeSystem 慢速注册/释放边界；`tools/verify_llm_bridge.gd` 新增防回退静态检查，确认脚本不含 `curl.exe` / `OS.execute`。验证通过：`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`godot --headless --path . --quit-after 1`。
- T1407 文档任务登记：新增“部署游戏后端到服务器”为 P0 任务，明确服务器运行入口仍是 `backend/app.py`，本地可用 `python backend/app.py`，正式部署必须使用生产 WSGI 服务并补齐 `backend/README.md`、环境变量、日志、限流、预算、健康检查和 Godot 后端地址配置说明。
- T0604A 文档任务登记：新增“替换 LLMBridge 传输层并锁定正式前后端架构”为 P0 任务，明确 T0604 的 `curl.exe` 只是临时本地开发实现；正式方向是玩家电脑运行 Godot 客户端，请求游戏服务器后端，由后端调用 LLM Provider、持有 API Key、控制并发和成本；玩家自行配置 API Key 仅作为未来可选模式。同步把 T0701 前置改为 T0604A，并在架构/API/AI 文档记录 T0604 踩坑。
- T0604 Godot LLMBridge：新增 `scripts/systems/LLMBridge.gd` 并挂载到 `Main/Systems/LLMBridge`，支持后端地址配置、`/health`、`/npc/dialogue`、T0603 对话 payload 收集、请求失败返回错误、请求期间 TimeSystem 慢速注册/释放；HUD 后端状态改为读取 LLMBridge；GM 面板新增 health / 对话 Mock / 应征 Mock 调试入口；新增 `tools/verify_llm_bridge.gd`。验证通过：`godot --headless --path . --script res://tools/verify_llm_bridge.gd`、`godot --headless --path . --script res://tools/verify_gm_panel.gd`、`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_backend_schemas.py`、`godot --headless --path . --quit-after 1`。
- T0603 `/npc/dialogue` Mock 接口：`backend/app.py` 新增正式 `POST /npc/dialogue`，请求和输出分别校验为 T0603 版 `NPCDialogueRequest` / `NPCDialogueResponse`；`backend/services/model_adapter.py` 的 dialogue mock 支持玩家-NPC 应征 accept/reject 和 NPC-NPC 轮次结束倾向；新增 `tools/verify_dialogue_mock_endpoint.py`。验证通过：`python tools/verify_dialogue_mock_endpoint.py`、`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、Python 编译检查。
- T0602 Mock Model Adapter：`backend/services/model_adapter.py` 默认 provider 改为 `mock`，新增 `generate(...)`、按调用类型分支的稳定 JSON、伪 token / 用途记录和非 mock 未配置 Key 的明确失败；`backend/app.py` 新增 `POST /mock/model` 调试接口；新增 `tools/verify_mock_model_adapter.py`。验证通过：`python tools/verify_mock_model_adapter.py`、`python tools/verify_backend_schemas.py`、Python 编译检查。
- T0601 后端 Schema：新增 `backend/schemas/common.py`、`backend/schemas/npc_ai.py`、`backend/schemas/__init__.py` 和 `backend/schemas/README.md`，覆盖对话、每日计划、计划修订、战斗判定、首次睡眠总结、知识图谱更新、主动交涉和玩家话术分类请求/响应；新增 `tools/verify_backend_schemas.py`。验证通过：`python tools/verify_backend_schemas.py`、Python 编译检查、Flask `/health` test client。
- T0502A 睡觉期间停止接收见闻：`MemorySystem.add_witness_event(...)` 的见闻接收判定扩展为拒绝昏迷或 `current_action == "sleep_in_dormitory"` 的 NPC；睡觉者不会收到同地点/同建筑 `local_public` 事件、状态广播、公告或进入快照，睡醒后从后续广播开始恢复接收。验证通过：`verify_action_local_public_broadcast.gd`。
- T0409 广场 NPC 状态快照补齐：`MemorySystem.get_location_snapshot("plaza")` 也会生成 `people_statuses`，进入广场的 NPC 能在 `location_context` 和 `location_entry_snapshot` 见闻 summary 中看到广场上 NPC 的生命状态与行动状态。验证通过：`verify_location_info_nodes.gd`。
- T0407/T0503 建筑内 NPC 状态快照补齐：`MemorySystem` 的可进入建筑快照新增 `people_statuses`，进入者的 `location_entry_snapshot` 见闻现在能看到建筑内 NPC 的生命状态（健康/受伤/昏迷，昏迷时可包含治疗者）与行动状态（由 `current_action` 翻译成精简中文）。`ActionSystem` 新增只读 `get_healing_helpers_for_target(...)` 供信息节点查询当前治疗者。验证通过：`verify_location_info_nodes.gd`、`verify_npc_unconscious_healing.gd`。
- T0503 治疗昏迷 NPC：`ActionSystem` 新增 `debug_assign_heal_assist(healer_npc_id, target_npc_id)`，治疗者会前往昏迷目标所在信息地点，每个目标最多 2 名治疗者；治疗按逻辑时间扣第纳尔并调用 `NPCSystem.assist_unconscious_recovery(...)` 加速 HP 恢复，医术低几乎无加成，高医术恢复明显更快；`MemorySystem` 支持 `healing_started` / `healing_completed` summary 与 payload 校验；治疗事件进入治疗者和被治疗者事件库，同地点其他在场 NPC 获得见闻，事件信息不暴露医术熟练度；GM 新增治疗目标下拉和 `assist_heal <healer_npc_id> <target_npc_id>` 命令。验证通过：`verify_npc_unconscious_healing.gd`、`verify_gm_panel.gd`、`verify_npc_unconscious_natural_recovery.gd`、`verify_npc_damage_unconscious.gd`、`verify_action_system_basic.gd`、`verify_structured_memory_events.gd`、`verify_npc_short_term_memory_container.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`。
- T0502 昏迷自然恢复：`NPCSystem` 监听 `logical_time_tick`，昏迷 NPC 以每游戏小时 2 HP 自然恢复，达到 Max HP 30% 后自动复苏并发出 `npc_revived`；`MemorySystem` 支持 `revived` summary 与 payload 校验；GM 新增 `recover_npc <npc_id> <game_seconds>` 调试命令。验证通过：`verify_npc_unconscious_natural_recovery.gd`、`verify_gm_panel.gd`、`verify_npc_damage_unconscious.gd`、`verify_action_system_basic.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_location_info_nodes.gd`、`godot --headless --path . --quit-after 1`。
- T0502A 昏迷期间停止接收见闻：`MemorySystem.add_witness_event(...)` 现在会拒绝给昏迷 NPC 写入见闻，覆盖地点/广场公开广播、状态广播、公告和进入快照；复苏后见闻接收自动恢复。验证已补入 `verify_npc_unconscious_natural_recovery.gd`。
- T0501 NPC HP 扣除与昏迷状态：`NPCSystem` 新增权威扣血接口和昏迷判定，`ActionSystem` 阻止昏迷 NPC 移动/行动，`MemorySystem` 支持 `damage_taken` / `unconscious_started` summary 与 payload 校验，GM `attack_npc` / `damage_npc` 可直接扣 HP 并触发同地点 `local_public` 昏迷见闻。验证通过：`verify_npc_damage_unconscious.gd`、`verify_gm_panel.gd`、`verify_action_system_basic.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`godot --headless --path . --quit-after 1`。
- T0409 广场进入快照与室内经由广场移动链：`MemorySystem` 的广场进入快照 summary 补齐当前在场 NPC 与公告牌文本；`NPCSystem` 在室内到室内切换时按逻辑事件链插入广场中转，物理移动仍保持低模直线占位。验证通过：`verify_location_info_nodes.gd`、`verify_npc_movement_location.gd`、`verify_npc_short_term_memory_container.gd`、`verify_action_local_public_broadcast.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_action_system_basic.gd`、`verify_structured_memory_events.gd`、`verify_gm_panel.gd` 和 `godot --headless --path . --quit-after 1`。
- T0408 广场公开类型收敛：事件可见性只保留 `private` / `local_public`；广场事件使用 `location_id == "plaza"` 的 `local_public`，协助修复/升级、公告和建筑外部状态广播都走同一地点广播路径。验证通过：`verify_plaza_local_public_broadcast.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1`。
- T0407 地点事件与建筑状态见闻精简：`location_entered` / `location_exited` 只保留进出行动事实，进入者获得一次 `location_entry_snapshot` 状态见闻，已在场 NPC 只收进出事件；建筑/地点状态变化改为 `changed_fields` / `changed_workstations` 字段级差量见闻。验证通过：`verify_location_info_nodes.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_npc_short_term_memory_container.gd`、`verify_action_local_public_broadcast.gd`、`verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1`。
- T0006 建筑修复进度不再抢占右上角面板：`EventBus` 新增 `building_state_changed(building_id)`，`BuildingSystem` 把修复进度、协助者变化、受损、修复完成和升级改为发状态刷新信号，不再复用 `building_clicked`；`BuildingPanel` 只在当前可见且显示同一建筑时响应状态刷新，因此玩家在修复过程中点击 NPC 后会保持 NPC 面板。验证：`godot --headless --path . --script res://tools/verify_npc_panel_state.gd`、`godot --headless --path . --script res://tools/verify_building_repair_upgrade.gd`、`godot --headless --path . --quit-after 1` 通过。
- T0005 Godot MCP 多会话拓扑修正：每个 Codex 会话保留独立 stdio proxy，单例约束只放在 broker；broker 先监听 `8765` 再连接 Godot `6550`，避免并发启动互相顶替。
- T0205/T0305 建筑修复流程修订：`BuildingSystem.repair_building(...)` 现在在点击时一次性扣除资源并创建倒计时修复作业，HP 随 `TimeSystem.logical_time_tick` 逐步恢复；修复时长按缺失 HP、建筑等级和建筑配置计算。`ActionSystem` 新增 `debug_assign_repair_assist(npc_id, building_id)`，NPC 可在修复期间按工程熟练度加速倒计时，多个 NPC 可叠加；若 NPC 离开对应建筑或被改派其他行动，协助人数和倍率会被移除。GM 命令新增 `assist_repair <npc_id> <building_id>`。
- T0406 统一玩家交互事件世界内称呼：玩家非对话交互写入 NPC 事件库 / 见闻库时，actor id 使用 `guard_officer`，summary 使用“守备官”，避免 NPC 记忆和后续 LLM 输入出现以“玩家”为主语的出戏文本。
- T0403 行动事件本地公开广播修复：`ActionSystem` 工作、吃饭、睡觉事件改为 `local_public`，同地点当前在场 NPC 会收到对应见闻；新增 `tools/verify_action_local_public_broadcast.gd` 回归验证。
- T0206 将公告牌移出建筑数据结构：`data/building_defs.json` 删除 `notice_board`，建筑定义调整为 15 个；T1506 后 `NoticeBoard` 已接入独立点击、预览和公告输入，公告文本继续归广场状态保存并广播。
- T0004 GM 调试面板：新增 `Main/UI/GMPanel` 和 `scripts/ui/GMPanel.gd`，把 M1-M4 已完成但前端不易直接验证的资源、时间、建筑、NPC、行动、记忆/见闻和广场公告能力暴露到可拖动 GM 面板；新增 `docs/GM_PANEL.md` 和 `tools/verify_gm_panel.gd`，并将“不可见功能需补 GM 入口”的规则写入 `AGENTS.md` 工作流。

## Godot MCP

- 项目内已安装并启用 `addons/godot_mcp`。
- Codex 端使用 `多个会话独立 proxy -> 单例 broker -> Godot` 结构。多个 proxy 是正常状态；只有 broker 和 `broker -> Godot` 连接必须各自保持单例。
- `godot-mcp-proxy.mjs` 不再枚举或终止其他 proxy；它只在所属 Codex 会话关闭 stdin 时退出。`godot-mcp-broker.mjs` 会先抢占 `127.0.0.1:8765`，成功后才连接 Godot `6550`。
- 连接自检命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_godot_mcp.ps1
```

- 当前验证结果：脚本可正常返回 `Godot MCP connected`。
- 2026-06-07 重装环境恢复：Godot 4.6.3、Node.js 24.16.0 LTS、npm 11.13.0、`@satelliteoflove/godot-mcp` 3.7.0 已安装；Godot 插件正在监听 `6550`，但当前 Codex 会话尚未连接 MCP，`tools/check_godot_mcp.ps1` 返回“Godot plugin is running, but MCP is not connected”。已在 `%USERPROFILE%\.codex\config.toml` 配置 `mcp_servers.godot` 使用 `cmd /c godot-mcp.cmd`，需重启/刷新 Codex 后复验；历史自定义 broker/proxy 脚本在本机用户目录中暂缺。
- 2026-06-07 追加修复：Codex 重启后确认 MCP server 可启动但未连接 Godot，根因是项目 addon `2.17.0` 与 npm server `3.7.0` 版本不一致。已用 `godot-mcp.cmd --install-addon . --force` 升级 `addons/godot_mcp` 到 `3.7.0`，并通过外部 Node 握手确认 `versionsMatch=true`、`get_project_info` 正常返回。当前会话中因清理旧 MCP 子进程导致 Codex transport closed，需要再次重启/刷新 Codex 后复验工具直连。
- 2026-06-07 再次复验：Godot 插件端口与外部握手均正常，但 Codex 当前 `godot-mcp` server 仍显示 `connected=false`。已将 Codex MCP 启动参数固定为 `GODOT_HOST=127.0.0.1`、`GODOT_PORT=6550`，避免默认 host 解析或环境差异；需要重启/刷新 Codex 后让新参数生效。
- 2026-06-07 后续诊断：`editor.get_state` 明确返回 “Another MCP server connected and replaced this one”，当前 Codex MCP server 已停止重连。Codex 配置已改为直接运行 `C:\Users\93741\AppData\Roaming\npm\godot-mcp.cmd`，并使用 TOML `env` 表设置 `GODOT_HOST=127.0.0.1`、`GODOT_PORT=6550`；需要重启/刷新 Codex 才能生效。
- 2026-06-07 最终复验：重启 Codex 后 Godot MCP 工具直连成功，`godot_project.addon_status` 返回 `connected=true`、server/addon 均为 `3.7.0`、`versions_match=true`；`godot_editor.get_state` 正常返回当前打开 `res://scenes/main/Main.tscn`。
- 2026-06-09 启动修复：换机 / Git 同步后 `.godot/global_script_class_cache.cfg` 未登记 `MCPRuntimeStateSampler` 时，`MCPGameBridge` Autoload 会解析失败。`mcp_game_bridge.gd` 现已直接预加载 `mcp_runtime_state_sampler.gd` 创建 sampler，不再依赖全局类缓存；`godot --headless --path . --quit-after 1`、GM 面板验证、NPC 面板验证、MCP 自检和 MCP 运行主场景日志均通过。
- 2026-06-17 版本升级修复：Godot MCP 已升级到 `4.0.1`，Node 侧 `@satelliteoflove/godot-mcp` 与项目 `addons/godot_mcp` 版本一致；`MCPGameBridge` 继续显式预加载 `mcp_runtime_state_sampler.gd`，并新增显式预加载 `key_names.gd`、`joy_names.gd`、`mcp_exec_guard.gd`，避免 4.0.1 新增 helper 类依赖 `.godot` 全局类缓存。用户目录中的 `godot-mcp-broker.mjs` 已兼容 4.0.1 的新版工具名、取消旧 resources 入口并规范化 tool result；验证通过 `godot_project.addon_status`、`godot_editor.get_state`、`tools/check_godot_mcp.ps1` 和 `godot --headless --path . --quit-after 1`。
- 2026-07-17 T0025 复验：当前 Codex 通过既有 broker 正常连接用户编辑器，server/addon 均为 `4.0.1` 且 `versions_match=true`；MCP 运行 `Main.tscn` 后可查询 8 名 NPC 的 24 项 `llm_plan_day` 计划，编辑器无新增游戏错误。端口 `6550` 由编辑器插件监听是正常拓扑，不等于被另一个会话占用。
- 2026-06-09 本机编辑器路径配置处理：`.vscode/settings.json` 已加入 `.gitignore` 并从 Git 索引移除；两台电脑可各自保留本机 Godot 路径，不再通过 Git 同步该文件。
- 多会话拓扑验证命令：`node .\tools\verify_godot_mcp_topology.mjs`。
- 若再次异常，先看 `tools/check_godot_mcp.ps1` 输出：多个 session-local proxy 只会作为正常信息提示；broker 缺失、broker 非单例或绕过 broker 直连 Godot 才会警告。
- 2026-06-02 复盘：这次 `godot_mcp` 工具返回 `Transport closed`，但 `tools/check_godot_mcp.ps1` 一度仍显示 `Godot MCP connected`，说明 Godot 插件和 `broker -> Godot` 连接没有先坏，坏的是当前 Codex 会话内已经关闭的 stdio MCP transport。清理残留 headless Godot 进程并重启 broker 后，外部自检可恢复；但已经关闭的 Codex MCP transport 不能在同一会话内热接回，需重启/刷新 Codex。重启后 `project.addon_status` 与 `editor.get_state` 均恢复正常。
- 历史上已经出现过类似工具链问题：2026-05-19 记录过重复直连 Godot `6550` 导致连接互相顶替；2026-05-25 曾误把多个 proxy 判断为故障并加入 sibling kill，随后确认该逻辑会主动关闭其他 Codex 会话的 transport。本次教训是先区分三层状态：Godot 插件是否监听、broker 是否能健康响应、Codex 暴露的 MCP 工具 transport 是否仍活着；不要只凭 `Transport closed` 判断 Godot 插件已掉线。
- 2026-05-19 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图可见标题与基础地面。
- 2026-05-19 T0101 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，Autoload 加载正常，游戏日志无报错。
- 2026-05-19 T0102 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 标题与基础地面仍可见。
- 2026-05-19 T0103 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认低模驿站、HUD 标题和调试标签可见。
- 2026-05-19 T0104 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示标题、时间、资源占位、按钮占位和后端状态占位，且未遮挡主要驿站视角。
- 2026-05-19 T0105 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，`CameraRig` 已挂载 `res://scripts/camera/CameraRig.gd` 并暴露平移、缩放和边界参数。
- 2026-05-19 T0202 验证：通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 显示 `金钱 30`、`粮食 18`、`木材 12`、`石料 8`、`铁 5`；使用临时测试场景验证资源增加、扣除和超额扣除失败逻辑。
- 2026-05-19 T0203 验证：通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；当时临时 Godot 验证脚本确认 `BuildingSystem` 加载 16 个建筑定义、可查询主厅数据、可选中仓库、主厅 ClickArea 已创建；2026-05-24 T0206 后建筑定义调整为 15 个并移除公告牌建筑定义。通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认建筑标签显示名称、等级和 HP。
- 2026-05-19 T0204 验证：通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；通过临时 Godot 验证脚本确认选择主厅会打开建筑面板、切换仓库会刷新数据、关闭按钮会隐藏面板；通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，游戏日志无报错，截图确认 HUD 与低模驿站仍正常显示。
- 2026-05-20 T0204 修正验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_panel_mouse_click.gd` 临时验证真实鼠标点击路径，主厅点击可打开建筑面板；通过 `--quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-20 T0205 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_building_repair_upgrade.gd` 验证建筑受损后可修复、修复/升级会扣除石料、升级会提升等级/Max HP/工作位、资源不足时升级失败且不扣资源；通过 `--quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-20 T0302 验证：通过 `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 验证 8 个 NPC 生成和 `npc_clicked` 信号；通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；通过 Godot MCP 运行主场景，游戏日志无报错，MCP 查找确认 `Main/WorldRoot/Station/NPCs` 下存在 8 个 NPC `Area3D` 节点。
- 2026-05-20 T0303 验证：通过 `godot --headless --path . --script res://tools/verify_npc_panel_state.gd` 验证 NPC 面板打开、状态修改后刷新、NPC/建筑面板互斥切换和关闭按钮；通过 `godot --headless --path . --script res://tools/verify_npc_generation_click.gd` 回归验证 NPC 生成与点击；通过 Godot MCP 运行主场景，游戏日志无报错，并确认 `Main/UI` 下存在 `NPCPanel`、`BuildingPanel`、`DialogPanel`。
- 2026-05-21 T0304 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_npc_movement_location.gd` 验证 NPC 可通过调试接口依次前往食堂、宿舍、仓库，并在到达后更新地点和地点信息占位；通过 `verify_npc_generation_click.gd`、`verify_npc_panel_state.gd` 回归验证；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-21 T0305 验证：通过 `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://tools/verify_action_system_basic.gd` 验证 NPC 可被调试安排吃饭、睡觉、菜园工作、酒窖酿酒、铁匠铺制造、工械坊制造和建筑协助修复，资源/派生资源/建筑修复进度与饱食/疲劳会正确结算，行动事件写入 EventLog 占位；通过 `verify_npc_movement_location.gd`、`verify_npc_panel_state.gd`、`verify_npc_generation_click.gd` 回归验证；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-23 T0402 验证：通过 `godot --headless --path . --script res://tools/verify_structured_memory_events.gd` 验证结构化事件字段、NPC 当天事件库、全局事件索引、广场公开查询和 payload schema；通过 `verify_action_system_basic.gd` 回归行动闭环；通过 `godot --headless --path . --quit-after 1` 验证项目加载无错误；Godot MCP `get_state` 正常返回。
- 2026-05-24 T0403 验证：通过 `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 验证地点 `people_present` 进出更新、`location_entered` 进入快照、广场主厅/围墙/城门/仓库状态聚合和 `local_public` 见闻广播；通过 `verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1` 回归；通过 Godot MCP 运行主场景，游戏日志无报错。
- 2026-05-24 T0404 验证：通过 `godot --headless --path . --script res://tools/verify_plaza_local_public_broadcast.gd` 验证广场 `local_public` 广播、公告变更广播、关键实体状态变更广播和广场快照字段；通过 `verify_location_info_nodes.gd`、`verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1` 回归。
- 2026-05-26 T0407 验证：通过 `godot --headless --path . --script res://tools/verify_location_info_nodes.gd` 验证 `location_entered` 不带完整快照、进入者只获得一次当前状态见闻、已有 NPC 只收进入/离开事件、`location_exited.location_id` 使用离开地点；通过 `verify_plaza_local_public_broadcast.gd` 验证建筑状态见闻使用变化字段且不复制完整广场/建筑快照；通过 `verify_npc_short_term_memory_container.gd`、`verify_action_local_public_broadcast.gd`、`verify_structured_memory_events.gd`、`verify_action_system_basic.gd` 和 `godot --headless --path . --quit-after 1` 回归。
- 2026-05-24 T0406 验证：通过 `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 验证给钱/攻击交互 summary 使用“守备官”且不包含“玩家”，actor id 使用 `guard_officer`；通过 `godot --headless --path . --script res://tools/verify_gm_panel.gd` 和 `godot --headless --path . --quit-after 1` 回归。
- 2026-05-24 T0405 验证：通过 `godot --headless --path . --script res://tools/verify_npc_short_term_memory_container.gd` 验证 NPC 当天 `event_log` / `witness_log` 短期记忆容器、守备官给钱/攻击调试交互的事件写入和广播，以及 NPC 面板区分显示事件库与见闻库；通过 `verify_structured_memory_events.gd`、`verify_plaza_local_public_broadcast.gd`、`verify_npc_panel_state.gd` 和 `godot --headless --path . --quit-after 1` 回归。
- 2026-05-24 T0004 验证：通过 `godot --headless --path . --script res://tools/verify_gm_panel.gd` 验证 GM 面板加载、窗口打开、资源命令、建筑受损、设置时间、NPC 进入地点、给钱事件、广场公告和结果输出；通过 `verify_time_system.gd`、`verify_building_repair_upgrade.gd`、`verify_action_system_basic.gd`、`verify_npc_short_term_memory_container.gd`、`verify_structured_memory_events.gd` 和 `godot --headless --path . --quit-after 1` 回归；通过 Godot MCP 运行 `res://scenes/main/Main.tscn`，清空旧日志后游戏日志无报错，截图可见 GM 按钮与面板。
