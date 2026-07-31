# AI_NPC_SYSTEM.md

## T0116 计划对话意图执行前复核

每日计划和正式修订仍可为 `talk_to_npc / seek_guard_officer` 预先写 `dialogue_goal`，但该文本现在只是带制定时间的旧意图。计划应用时会保存 `intent_created_day / intent_created_time / intent_source`；执行到该小时后，DailyPlanSystem 在中断现有行动、开始追踪目标、发邀请或创建主动交涉问号之前请求一次真实 LLM 复核。

复核拥有与计划同级的当前 NPC / 记忆 / 指令 / 地点 / 居民 / 建筑 / 资源 / 行动候选 / 24 小时计划，并额外获得制造项目的 `completed_stages / current_stage_index / current_stage_cost`。它只可继续原文、改写同一行动同一目标的首句，或放弃并触发既有当前小时计划重估；不能自己选替代行动或改资源。等待期间同签名去重，返回时校验日、小时、计划版本和 `action + target + dialogue_goal`，迟到结果不落地。

## T0115 失败重估与主动交涉事务边界

行动失败判别仍由真实 LLM 选择需要修改的小时，正式修订仍由真实 LLM 给出这些小时的新计划；Godot 新增的是落地前的权威一致性校验。若 `trigger_kind=action_failure` 且修订包含当前小时，返回项不能与 `failed_plan_item` 具有相同的 `action_id + target + dialogue_goal`。违反时返回 `failed_action_repeated`，保留原计划并沿当前 stage-two 的最多 3 次重试继续请求，不制造新的 stage-one 判别链。

`seek_guard_officer` 的可见行为仍是 NPC 头顶 `?`，不是朝一个世界坐标寻路。主动交涉运行态由 NPCSystem 独占；DialogSystem 只有成功激活 NPC 发起的 `player_npc` 会话后，NPCSystem 才清除该状态。`llm_activity.kind=plan` 会用 `...` 暂时覆盖问号并拒绝对话，但不会消费交涉；活动清除后问号恢复。草稿创建和激活之间若发生规划、行为模式或可行动性变化，整个交接失败且可重试。

新行动开始必须先替换上一行动的终态结果，再发 `npc_state_changed`。主动交涉和移动入口现显式写入非失败的 start result 并清空失败上下文；这样 DailyPlanSystem 只能消费当前真实失败，不能把旧失败归因给刚开始的交涉或赶路。该规则不改变人物自主性、计划 one-shot 语义、对话内容生成或资源 / 制造结算权威。

## T0113 对话中的行动、装备与训练权威实况

LLMBridge 在构造每个对话请求时额外生成 `activity_truth / equipment_truth / training_truth`。它们不建立新的训练权威：行动真相来自现有 ActionSystem 运行态或 DialogSystem 保存的打断前活动，装备来自 NPCSystem 当前装备槽，训练资格复用现有可训练装备判据、在岗教官和 ActionSystem 环境资格。

打断后的 `npc_state.current_action=talk_to_guard_officer` 仍只表示正在对话；`activity_truth.action_id` 才是开口前实际活动。拜访训练场保持 `visit_location + is_training=false`，不会因为当前计划 reason 写着“训练”、短期记忆提到教官或 NPC 身处训练场而升级成训练事实。无主武器 / 坐骑且两个槽均无 `required_skill` 时，训练真相固定为 `eligible=false / blocker=no_trainable_equipment`。

这三组字段只增强目标 NPC 的事实约束，不改变计划生成 / 修订、记忆摘要、行动白名单、工位占用、熟练度增长或失败重估。真实复放已消除 5/5 次“格伦已经在训练”的说法，但模型仍会从旧记忆推断艾达在场；后者不在本次三个目标 NPC 自身真相字段的覆盖范围内。

## T0106 全量紧凑短期记忆

对话、日计划、计划修改范围判别、正式修订、低血量战时心理和熟睡总结现在都读取目标 NPC 当前短期索引中的全部亲历与见闻，不再分别只取最后 8 条。列表保持原始发生顺序且继续区分 `experienced_events / witnessed_events`；亲历是自身经历，模型权重高于听见 / 看见的公开见闻。

模型读取的是程序生成的记忆投影，不是 MemorySystem 原始事件对象。每条记录固定包含 `type / summary / importance / day / time`，只有摘要没有充分表达的决策事实才进入可选 `details`。原因、资源缺口、投入产出、指令变化和行动目标可以保留；重复 24 小时计划改为连续 `plan_segments`；事件 ID、完整 payload、地点 / 建筑快照、敌我阵容和已在 summary 中展开的对话正文不会进入供应商上下文。

当前库存、地点和战场上下文仍是“现在”的权威事实，旧记忆是“当时发生过什么”。Prompt 要求模型按时间区分两者，不能因为 GM 后来补了铁就把较早的缺铁重估改写成“菜园缺人”。熟睡总结使用带 `memory_kind` 的全量紧凑 `day_events` 作为唯一短期证据副本，避免同一事实在 `npc.short_term_memory` 中重复加权。

## T0103 NPC-NPC 对话收尾与防复述

自主 NPC-NPC 正式会话继续使用 T0030 的 `max_rounds=0` 无硬上限合同。`soft_round_threshold=5` 只表示偏晚阶段的收尾保险，绝不是最低轮数、目标长度或“尚未到收尾轮次”的继续理由；紧急 / 必要事项确实尚未说清时仍允许超过阈值。

每次正式回复都必须先检查 `conversation_history + speaker_text` 中是否存在尚未解决的紧急或必要事项。只有本轮能用新事实、新决定或必要提议推进该既有事项时才能继续；若原问题已完整回答、双方已达成一致、对方已经收尾，或当前回复只能确认、复述 / 近义改写旧内容，模型必须用至多一句符合角色口吻的短收尾并返回 `should_end_dialogue=true`。不得为避免结束临时创造新话题、新任务、新问题、额外帮助或后续安排。

Godot 仍只消费结构化结束字段：结束回复先写入历史 / 事件，再立即结束且不调下一轮；没有新增语义重复判定器、硬轮次截断或 UI 权威。真实铁匠铺复现确认邀请阶段已经回答后，正式第 1 轮就结束；旧重复历史放在第 3 轮时也立即收尾。

## T0101 守备官共同背景与认知边界

每名初始 NPC 对守备官的根本知识统一为四项：职责、三年前到站、来站前经历未知、在该 NPC 认识他以来一向尽责且与成员总体相处和睦。前三项是明确事实 / 明确未知，第四项是低细节共同背景；它不包含任何具体事件、对话、共同任务、承诺、恩怨或无条件信任。

对话中，守备官询问姓名、出身、家庭或来站前经历时，NPC 只能依据自己后来真实听到的自述回答；没有自述就明确说不知道。询问三年相处故事时，最多三句：概括三年前到站、尽责、和睦，说明没有可确认的具体旧事，随后立即转到当前驿站或自己的确知近况。不得用职业、外表或日常常识补写玩家过去。

计划、战时心理和关系判断可以把“此前尽责和睦”当作初始低细节印象，但不能据此无条件服从。熟睡反思中，守备官后来明确说出的个人资料只能作为该 NPC 的“守备官自称……”认知保存；守备官问“我是谁”不是披露，也不会自动写成全站客观身份。

## T0100 统一宗教信仰人设

8 名初始 NPC 的根本人设统一新增 `religion="天主教"`。现有背景故事没有其他教派、无神论或宗教身份冲突，因此不改写职业内核与长期记忆；马塞尔既有神父、教区和弥撒经历与该字段一致。

`religion` 与其他根本人设字段同源：对话使用 `npc_setting.religion`，日计划、修改范围判别、正式修订、战时心理和熟睡总结使用 `npc.identity.religion`，NPC 面板【背景】显示“宗教信仰：天主教”。Prompt 仅在话题或经历相关时自然参考，不得把共同信仰写成 8 人共同性格、服从倾向或相同虔诚程度，也不得补造宗教经历。

## T0099 对话 UI 不扩张模型职责

`Tab` 只是 `DialogPanel` 对“提出应征” CheckButton 的本地快捷操作，最终仍调用 `DialogSystem.set_recruitment_request_pending(...)`；它不新增对话字段、不自动发送消息，也不能绕过等待、已入伍或已接受应征时的禁用状态。首次攻击确认同样只包裹既有 `attack_target_npc(...)`：取消时完全不发起攻击或 LLM，确认后普通惩戒回复与逃离攻击分流保持原合同。纯日期对话记录只改变玩家 UI 分组，不改变模型看到的短期 / 长期记忆。

## T0105B 弥撒跨小时计划接管

模型仍只制定逐小时计划，不需要输出“延迟执行”字段，也不需要预测子帧误差。DailyPlanSystem 在整点读取到与当前弥撒不同的新计划时，将该计划保存为弥撒结束后的当前小时接管项：主持者继续 `lead_mass`，参礼者继续同一个 `pray_at_chapel + mass_attendance`。弥撒结束后使用当时最新的当前小时计划，而不是锁死旧快照；动态目标、工位、资格和行为模式仍在真正派发时重新校验。

该保护只属于普通整点接管。玩家 / NPC 对话、计划修订即时派发、建筑失效、昏迷和其他权威中断仍沿用既有流程；其他行动也不获得“必须做完”特权。参礼者个人祈祷时长先满时由 ActionSystem 保持在弥撒中，结束后先恢复独祷语义，再完成祈祷或切换到积压计划，不产生教堂失败或 LLM 重估。

## T0098 合并后的祈祷行为

计划目录只保留 `pray_at_chapel` 与 `lead_mass`。NPC 是否去小教堂祈祷仍由人物、状态、记忆、指令和模型决定；“独自祈祷 / 参加弥撒”不再是模型需要选择的两个行为，而是祈祷 active 状态中的程序模式。

祈祷者抵达并占用祈祷席后，根据有效 `lead_mass` 进入 `personal_prayer` 或 `mass_attendance`。主持开始时 active 祈祷者原地参礼，主持正常完成或异常退出且没有替换主持者时原地恢复独自祈祷；pending 祈祷者保持原移动，到达后按实时状态进入正确模式。整个过程保留计划身份、位置和累计时长，不生成失败，不请求计划重估。

对话中若 NPC 明确答应现在参加弥撒，当前小时修订选择 `pray_at_chapel`；到达后的模式由 ActionSystem 确定。`allowed_actions`、背景知识和 Prompt 不再暴露 `attend_mass`，只用一句规则说明祈祷会随弥撒自动参礼、结束后继续。

## T0097 计划模型只返回决策

日计划与正式修订现在把 provider 输出和游戏内部计划彻底分开。模型每项始终决定 `hour + action_id`；只有行为本身需要选择目标时才额外决定：拜访为 `location_id`，找 NPC / 协助治疗为 `target_npc_id`，协助修复 / 升级为 `building_id`。`reason` 继续是简短人物理由，`dialogue_goal` 只对找 NPC 或主动找守备官有执行 / 表达意义。

Model Adapter 不再相信或校验模型返回的 `action_kind / priority / target_id` 等内部字段。它先根据 `action_id` 判断唯一需要读取的选择字段，把其他字段全部丢弃，再从本次动态 `allowed_actions` 精确命中候选并生成原有完整 `PlanItem`。固定工作、饮食、睡眠、祈祷、主持弥撒、等待、逃离等行为的 kind 与地点由候选确定；模型即使多给地点、目标、错误 kind 或额外对话诉求也不会改变执行计划。

必要选择不会被忽略或猜测：`visit_location` 缺少合法地点、NPC 目标行为缺少合法 NPC、建筑协助缺少合法建筑时，HTTP 业务校验会明确拒绝。旧通用 `target_id` 只是模型侧无关字段，不能代替专用选择。编译后的 Godot 合同、动态 NPC 追踪、建筑外协助地点、工位申请、行动进度、失败重估和 ActionSystem 最终资格校验完全不变。

## T0095/T0096 Pending 提交与熟睡总结语义

行动调度把 pending 与 active 视为两个明确阶段。暂停期间 NPC 节点不移动，ActionSystem 不执行 pending 提交，也不推进 active 逻辑 tick；恢复后仅当 `current_action=idle`、`movement_target` 为空、实际地点满足、NPC 可行动且不存在 active 时才提交。固定地点行动、诊所 / 训练 / 弥撒依赖者、修复 / 升级 / 治疗协助、拜访和 NPC-NPC 对话都服从同一闸门。建筑、目标 NPC 或服务提供者失效仍可权威取消，但移动清理使用无信号收束，最终结构化失败是唯一可供计划重估观察的结果。

熟睡总结的三个概念互不代替：`summary_window` 决定资格与日记归属，`reflection_period` 决定模型允许回顾的时间边界，MemorySystem 的事件 ID 快照决定成功后可轮转的精确短期索引。某一窗口没睡够或请求失败时不生成占位日记；下次成功仍从上次成功水位继续，因此允许记录范围跨日。日记前缀“接到守备命令的第N天”中的 N 来自 21:00 窗口锚点；“守备命令”是公告牌公开消息，不是入伍状态或个人指令。

## T0094 对话打断实况、弥撒续接与夜间总结窗口

守备官第一条有效消息真正打断 NPC 行动时，DialogSystem 会在中断前抓取运行时行动与当前计划，形成仅供目标 NPC 使用的 `interrupted_activity_context`。其中 `activity_before_interruption` 表示开口前正在进行或前往进行的真实活动，`current_plan_activity / expected_activity_after_dialogue` 表示当前计划与“计划不变时”的暂定恢复项。该上下文随本场后续对话请求复用，但不是事件、见闻或长期记忆；模型不得因为对话时 `current_action=talk_to_guard_officer` 就声称旧活动已经自然完成。被睡眠打断时，NPC 应知道自己刚被叫醒，以及计划不变时谈完仍会继续睡觉。

所有固定地点行动在真正开始前都必须再次确认 NPC 已抵达目标且不在移动途中。教堂活动另有 `_start_pray(...)` 最终守卫；未实际到达小教堂时返回结构化的 `*_failed_target_unavailable_not_arrived`，不能占用祭坛或祈祷席。室内出发的移动被系统中断时，NPCSystem 按既有室内经广场路由把逻辑地点与世界位置一并收束到广场，避免人物已在广场却仍被认作身处教堂。

T0098 后弥撒开始不再中断 active 或 pending 祈祷。active 祈祷者原地切到参礼模式；pending 祈祷者继续前往教堂，并在抵达时按祭坛实时状态开始。守备官与 NPC 在本轮明确谈妥“现在参加弥撒”时，对话范围判别仍可把当前小时纳入修订，但第二层统一选择 `pray_at_chapel`，不再生成教堂失败或双向替代提示。

熟睡总结不再按自然日做僵硬的“一天一次”去重。每个 NPC 使用从当日 21:00 到次日 21:00 的窗口 `night_<anchor_day>_2100`，同一窗口内多段睡眠累计到既有 1 游戏小时门槛；对话叫醒、短暂离床再睡不会清零。只有长期记忆成功应用后才把该窗口标为完成；21:00 后进入新窗口，白天补觉仍归前一晚窗口。T0095 起日记归属使用窗口锚点，实际触发日 / 时间作为独立元数据保留；GM `force` 调试仍可显式绕过去重。

## T0093 完成型行动连续计划段与工期约束

`LLMBridge` 的计划失败类型规范化现在显式保留 `action_completed`，避免完成事实在 Godot 正式修订 payload 中退化为 `unknown`。`reevaluate_current_hour_on_completion` 的五类行动配置不变；完成时从当前小时起，DailyPlanSystem 按计划项 identity 收集连续相同 `action_id + target` 的阶段，第一项不同任务 / 目标即形成边界，单项仍只修订当前小时。

该连续小时数组直接进入正式修订，不经过范围判别；`failure_context.contiguous_revision_hours` 同步说明范围来源。只有当前小时禁止原样重复完成项，当前小时修订落地后仍立即派发，跨小时陈旧回调、三次真实重试和 ActionSystem 权威校验保持不变。

日计划、范围判别和正式修订现在都被明确要求结合 `game_time` 与 `current_building_states.total_duration / remaining_time`。模型只应在预计完工前安排建筑协助或封闭影响，不得因为上午计划是连续格子就把短工期机械外推；工期仍是程序只读事实，模型不能改倒计时或宣布工程完成。

## T0092 最小 provider 合同与完整游戏合同

六类正式 NPC 调用区分“游戏业务合同”和“供应商生成合同”。Godot 继续发送既有业务请求、接收完整响应；Model Adapter 在供应商边界删除纯传输元数据、确定性重复副本、分支外上下文和 `null`，模型只判断人物话语、行动、修改小时、战时心理或记忆内容。

后端从请求和模型主决定补齐固定字段：对话的回复者 / 响应类型 / 不适用结果，计划的 NPC / 日期 / 完整内部项，范围判别的 `needs_revision`，修订的 `immediate_action`，战时判定的 `should_start_escape`，反思的 NPC / 日期。T0097 起计划的地点、NPC、建筑选择使用行为专用字段，`action_kind / priority / internal target / 固定 location` 全由程序编译。补齐后仍经过完整 Schema、动态白名单和业务规则校验；非法行动、必要目标或漏选小时不会被掩盖。

人物设定、长短期记忆、`current_order`、公开驿站事实、实时建筑 / 资源 / 战场状态、行动资格和叙事输出全部保留。`reason / summary / emotion / morale_delta_intent / dialogue_goal / diary_entry / knowledge_graph_updates / debug_reason` 仍有 UI、事件、人物记忆或诊断用途，没有为了省 token 删除。

## T0091 对话计划只绑定 NPC 目标

`talk_to_npc` 的计划候选不提供固定 `location_id`。生成计划时看到的目标当前地点只是瞬时上下文，不能成为固定目的地；T0097 起模型使用 `target_npc_id` 选择对象，计划落地时仍只保存该 NPC，ActionSystem 在接近与重定向阶段继续查询目标实时位置。

后端编译后仍要求内部 `action_kind=chat`、非自聊、非空 `dialogue_goal` 和合法动态目标。供应商多返回的瞬时地点或通用目标在 T0097 编译边界直接丢弃，不进入 `model_normalizations`；拜访与两类协助分别使用地点、NPC、建筑专用选择后再精确编译内部目标与地点。

## T0089 教堂行动失败后的意图延续（已由 T0098 废止）

ActionSystem 的 `last_action_failure_context` 仍携带与 `last_action_result` 一致的精确 `failure_id`，供诊所、训练、位置、建筑等真实失败使用。T0098 后祈祷的弥撒模式切换不进入该失败链。

原先两个独立教堂行为之间的双向替代规则已删除；祈祷选定后的参礼 / 独祷切换由程序完成。

人格、当前状态、记忆、守备官指令或更紧迫事实仍决定 NPC 是否选择祈祷；ActionSystem 继续权威校验主持资格、祈祷席、抵达、开始与完成。

## T0088 计划上下文中的建筑作业工期

`LLMBridge._build_building_state_context()` 不再只告诉模型建筑“正在修复 / 正在升级”。活动作业同时提供可读的 `total_duration`、`remaining_time`、整数进度百分比和协助人数，供日计划、修改范围判别与正式修订参考。模型上下文不暴露裸秒数字段，BuildingSystem 的权威秒数仍只用于程序结算。

作业总工期是稳定事实，可随“开始修复 / 开始升级”的外部状态变化进入人物见闻；剩余时间是请求构造时的实时只读投影，不按秒写入事件 / 见闻。模型可以据此安排工作、休息或协助，但不能修改倒计时、宣布完成或结算等级 / HP。

入伍颜色仅是 `recruited` 权威状态的 UI 投影。应征接受仍由 `recruitment_result` 经 NPCSystem 落地，颜色不参与 LLM 判断，也不改变行动资格、战斗资格或指令合同。

## T0087 对话决策字段单一来源

对话请求仍复用一套人物与信息空间构造，但输出按类型封闭：

- 守备官对话只读取 `PlayerNPCDialogueResponse`；应征接受 / 拒绝只由 `recruitment_result` 表达，战时意向只由 `wartime_reaction` 表达。
- NPC-NPC 对话只读取 `NPCNPCDialogueResponse`；邀请由 `invitation_result` 表达，正式续聊 / 收尾只由 `should_end_dialogue` 表达。
- 逃离挽留只读取 `EscapeInterventionDialogueResponse.escape_intervention_result=stay|leave`。

旧通用 `intent` 及其失效选项已删除。模型文本可以在拒绝应征后继续解释或提出其他条件，不会因为“文本没有结束谈话”而推翻结构化拒绝；程序也不会从台词猜测入伍、结束或逃离结果。三个响应 Schema 禁止跨分支字段，Godot 只消费当前分支的唯一决定字段。

## T0086 短活动完成后的续接（范围由 T0093 扩展）

`data/action_defs.json` 以可选布尔字段 `reevaluate_current_hour_on_completion` 标记“目标解决或短时完成后，不应在原计划项上空等到整点”的行为。当前穷尽集合为 `assist_repair`、`assist_upgrade`、`assist_heal`、`receive_clinic_treatment` 和 `drink_wine`。DailyPlanSystem 仍只处理由当前日计划真正派发的成功完成：建筑协助识别 `completed_assist_*`，协助治疗识别 `assist_heal_completed_*`，病床识别 `clinic_treatment_completed`，饮酒识别 `completed_drink_wine`；手工调试结果、失败或中断不能冒充完成。

完成后延迟一帧确认权威 day / hour、计划项 identity、NPC 空闲、可行动和 `behavior_mode=work`。若仍是同一小时和同一计划项，直接使用 `failure_type=action_completed` 修订当前小时起连续相同 action + target 的原计划段，不先调用“是否需要修改”判别；这是已经完成后必然需要后续安排的确定性事实。修订仍从实时普通 `allowed_actions` 中选择，成功合并后共用 T0076 可靠派发立即执行当前小时新项。Prompt 与 Godot 双重禁止当前小时原样重复相同 `action_id + target_id`；其他目标的同类协助仍可合法选择。

若完成 tick 同时跨过整点，deferred 回调看到权威小时变化后直接退出，由 `hour_started` 正常执行新小时计划，不修改旧小时。六类生产继续用 `repeat_while_planned` 自行续周期，持续医生 / 训练保持运行态；吃饭、睡觉、祈祷、主持弥撒、拜访等常规或整小时活动不增加额外 LLM 调用。自主 NPC-NPC 对话与主动找守备官交涉继续使用各自对话后 required-current-hour 合同。

## T0085 可塑工作量与升级目标失效

计划系统仍向模型提供 `current_work_phase_count / minimum_work_phase_count / replacement_work_phase_required_if_non_work`，但这些字段只用于强规划建议和可观测统计。模型通常应维持基础劳动；人格、健康、危机、逃离意向或现场目标变化也可以形成少于 6 个工作阶段的合法日计划 / 修订。后端与 Godot 不得为凑数拒绝整份响应或扩大 `revision_hours`，真正的小时、白名单、目标 / 地点、资格和即时行动合同仍为硬约束。

`assist_upgrade` 在历史 / 当前计划里始终计作劳动，Schema 表达为 `action_id=assist_upgrade / target_id=<building> / location_id=plaza`。当工程已经完成，DailyPlanSystem 不把旧的“建筑正在升级”失败继续喂给模型，而是根据 BuildingSystem 当前事实生成 `failure_reason=no_active_upgrade / condition=target_resolved_or_inactive`，再让范围判别选择真正受影响的小时。修订成功后按既有当前小时可靠派发链立即执行新行动。

## T0083 应征结果的逐回复表现

既有 `/npc/dialogue` 响应与业务校验不变：只有带应征标记的守备官消息才允许返回 `recruitment_result=accept|reject`。Godot 应用合法结果后，将枚举附在产生它的 NPC history turn 上，供对话 UI 明确显示；模型的 `reply_text` 不拼接系统提示，Prompt、provider、Schema 和入伍权威均未改变。

接受仍立即由 NPCSystem 写入权威 `recruited=true`，拒绝仍保持原状态。新增的绿色对勾 / 红色叉号只是既有结构化结果的前端投影，不让 LLM 生成颜色、符号或系统文案。

## T0082 守备官应征会话持续状态

“提出应征”不再是发送后自动清除的一次性标记，而是当前守备官-NPC 会话内的持续选项。开启后，每次发送默认都向既有 `/npc/dialogue` 请求提供 `is_recruitment_request=true`，直到玩家主动关闭；不新增 endpoint、响应字段或模型职责。第一次带标记的消息发送时，DialogSystem 同时写入 `session_had_recruitment_request=true`，从此本场取消入口永久锁定，toggle 后续关闭只改变新消息标记，不能抹去已经说出口的应征要求。

该会话仍可完成或挂起；挂起两小时后按完成收口。NPC 的 `accept / reject` 仍由既有回复业务校验处理，合法 `accept` 继续即时写入 NPCSystem 权威入伍状态。完整会话事件摘要由 MemorySystem 从 `dialogue_text` 逐句生成，计划判别继续收到同一完整历史。

## T0080 建筑门口观察与升级协助语义

NPC 对建筑封闭的认知遵守物理到达边界。建筑开始升级时，已经在内部执行依赖行动的 NPC 会立即因环境变化失败并被清退；仍在路上的 NPC 保留 pending 行动和移动目标，不生成失败、见闻或计划判别。只有抵达入口、程序重新确认建筑不可进入后，才写 `arrival_check_failed=true / interrupted_phase=pending` 的“到达门口后发现升级”失败，并由 DailyPlanSystem 启动原有两段式重估。

`assist_upgrade` 是目标指向升级建筑、执行地点位于广场 / 建筑外的劳动。动态候选明确包含 `eligible=true / available_now=true / execution_location=plaza / requires_building_entry=false / counts_as_work_phase=true` 和 `work` 标签。模型用 `building_id` 选择被协助建筑，不需要判断内部 `target_id` 或执行地点，也不得为了满足最低工作量而排除该行动；它仍可结合人格、指令和其他紧急事项选择别的合法候选。

实时 `current_building_states.is_upgrading / is_repairing` 来自 BuildingSystem 查询，不从建筑数据字典猜测。LLM 只选择动态候选；入口拒绝、移动落点、行动失败、工作阶段合法性和升级加速均由程序权威处理。

## T0078 主动找守备官交涉后的行动续接

NPC 发起的 `player_npc` 主动交涉只有在结束时当前计划项仍为 `seek_guard_officer` 时，才会固定重排当前小时。判别 payload 携带 `dialogue_initiator=npc`、`proactive_talk=true` 和 `required_revision_hours=[game_time.hour]`；后端把 required 集合权威并入模型选择，模型仍可按对话影响增加未来阶段，但不能让已经完成的主动交涉继续占据当前时段。

第二层不维护专用“交涉后行为表”，仍从实时 `allowed_actions` 选择工作、吃饭、休息、拜访、找其他 NPC 对话或其他合法活动。包含当前小时的正式修订成功后共用 T0076 立即 / deferred 派发，因此不会只改计划而让 NPC 站到下一小时。若对话结束时当前计划已经变化，则按普通守备官对话判断，不强行覆盖新安排。

NPC 主动交涉不能取消，但可以完成或挂起。挂起两小时到期会保存现有会话并进入同一判别链；守备官主动会话仍可取消并按“无事发生”恢复。该生命周期差异由 DialogSystem 权威判断，UI 只显示按钮状态。

## T0076 对话跨小时延续与当前计划落地

日计划 `talk_to_npc` 的生命周期现在覆盖“接近目标 → 等待目标结束计划 → 邀请判定 → 正式交谈 → 对话后计划链”。`assigned_plan_day / assigned_plan_hour / assigned_plan_version / assigned_plan_item` 会从 DailyPlanSystem 经 ActionSystem 传入 DialogSystem。普通同日整点只改变当前计划读取位置，不撤销已经开始的对话生命周期：pending 发起者继续移动 / 等待，邀请阶段保留发起者，正式会话保留双方；新小时计划以 deferred marker 等待对话结束。跨日不继承，战斗 / 逃离 / 昏迷等行为模式仍由各自权威中断。

自主 NPC-NPC 对话有实际内容并结束后，发起者的范围判别请求必须携带 `required_revision_hours=[game_time.hour]`。Schema 和 endpoint 要求响应 `revision_hours` 包含全部 required 小时，Prompt 和真实 provider 紧凑重试遵守同一合同；受邀者继续按对话影响独立判别。发起者当前阶段的第二层修订仍使用 LLMBridge 实时生成的普通 `allowed_actions`，不新增“对话后行为”白名单，也不由 LLM 绕过资源、地点、目标、工位或行为模式校验。

当前小时修订的落地统一使用可靠派发标记。非阻塞时在修订合并后立即调用正常计划派发；对话组未完成、NPC 不在工作模式或派发暂时失败时保留 `{day,hour,plan_version,scheduled,mark_revision_applied}`，状态恢复后按医生 / 教官 / 普通 / 承载者 / 对话依赖顺序执行。只有真正开始、采用已运行项或有意执行 `idle` 才消费本次派发；`already_executed_once_per_plan_hour` 不再被当作“新计划已经落地”。这样指令、行动失败、玩家对话和 NPC-NPC 对话等既有修订来源共用相同“修改当前小时就立即执行或可靠延迟”的合同。

## T0075 计划行动完成策略

所有 `data/action_defs.json` 行为必须显式声明 `completion_policy`。这是计划执行语义的必填合同，不是给 LLM 自由解释的提示：ActionSystem 装载时只接受下列六个值，缺失、未知值或 `not_plan_selectable` 与 `plan_selectable` 冲突时跳过该定义并记录配置错误。程序合成的 `idle` 不进入配置，固定为当前小时只保持空闲、整点重新读取计划。

| 策略 | 当前穷尽分类 | 完成 / 跨小时语义 |
|---|---|---|
| `repeat_while_planned` | `work_garden`、`work_dining_hall`、`work_stable`、`work_tavern`、`work_blacksmith`、`work_workshop` | 成功完成一个结算周期后，若当前计划仍是同一逻辑行动，则在旧周期完成事件写入后重新校验并立即开始下一周期；失败、中断、资源 / 工位 / 目标不足不续开 |
| `continuous_until_plan_changes` | `work_training_instructor`、`receive_weapon_training`、`work_clinic_doctor` | 本身是持续服务状态，不人为切成“完成后重开”的生产批次；只要跨小时计划仍匹配就保留运行态，计划改变或服务生命周期失败时退出 |
| `until_target_resolved` | `receive_clinic_treatment`、`assist_repair`、`assist_upgrade`、`assist_heal` | 持续到病人恢复、建筑作业完成、昏迷目标复苏等权威目标解决；目标完成 / 消失后结束，不按计划文字自动创建第二个目标周期 |
| `once_per_plan_hour` | `eat_at_dining_hall`、`drink_wine`、`sleep_in_dormitory`、`pray_at_chapel`、`lead_mass`、`talk_to_npc`、`visit_location`、`seek_guard_officer` | 同一个“日期 + 小时 + action + 必要 target + dialogue goal”成功派发一次后即消费，替换 `plan_version` 也不能重放同一逻辑项。默认提前完成后不自动重复；T0086 的 `drink_wine` 会转为当前小时后续计划重估。不同目标 / 交涉目标属于不同逻辑项；玩家对话打断后的既有显式恢复入口只是继续未完成执行，不算自动重放 |
| `terminal` | `escaping_station` | 交给 CombatSystem 的单向逃离生命周期，不由普通行动完成回调续开 |
| `not_plan_selectable` | `escape_intervention_dialogue`、`talk_to_guard_officer` | 仅供系统运行态 / 显示，不进入每日计划目录 |

整点派发先比较当前权威运行态与新小时计划。行动及必要目标相同就直接采用既有运行态，保留当前周期 `elapsed_seconds`、工位和制造 revision；不同则沿既有强制切换路径中断旧行动，再执行新小时项。因此跨小时不会因“还是同一件事”损失快完成的制造周期，也不会因旧行动拖延而跳过新小时的不同安排。

`repeat_while_planned` 的续开使用 deferred 调度，保证旧周期 `*_completed` 先于新周期 `*_started`。续开仍走正常 ActionSystem 校验，所以制造目标、项目 revision、阶段材料、建筑、工位、NPC 可行动状态和行为模式都必须再次合法；任何失败只进入既有失败判别 / 计划重估，不同步递归重试。后续新增行为时必须先选择上述策略、更新本表与专项分类测试，禁止依靠 action id 前缀或完成结果字符串猜测可重复性。

## T0073 当前指令对计划的实际影响

已入伍 NPC 的 `current_order` 不是仅供界面展示的字段。发布不同文本后，NPCSystem 以 `order_changed` 请求当前小时计划修订；LLMBridge 在正式 `revise_plan` payload 的目标 NPC 上下文中注入最新指令，DailyPlanSystem 只把通过真实 provider、Schema、精确小时集合、行动白名单和工作阶段下限校验的结果合并回权威 24 小时计划。

确定性专项已锁定完整调用链，真实 DeepSeek `deepseek-v4-flash` 也把“当前小时优先前往小教堂”的指令落实为 `idle -> visit_location(chapel)`。这只证明指令能影响计划，不意味着 NPC 必须机械服从：Prompt 仍允许其结合人设、记忆、现场状态和程序规则调整、推迟或拒绝，资源、地点资格、HP、战斗与行动执行仍由 Godot 权威校验。

## T0071 NPC-NPC 对话知情边界

每次 NPC-NPC 对话调用只让模型扮演当前回复者。回复者完整读取自己的身份、状态、长短期记忆、地点上下文和守备官指令；对话对象只以姓名、外表、健康状态和本轮已经说出口的文字出现。另一名 NPC 的事件库、见闻库、日记、知识图谱、私人指令、技能 / 属性、金钱 / 酒和地点私有上下文都不属于回复者知识，不能为了“人物连续性”注入。

T0071 修复前，对话 builder 使用 `_build_npc_context(speaker_npc_id, ..., false)`：`false` 只移除了长期记忆，仍会携带说话者短期记忆、指令和地点上下文。真实场景中格伦在铁匠铺合法获知制造目标为铁盔，随后该私有短期记忆被放入伊沃的回复请求，模型据此让伊沃说出“我听说你那边已经定下要打铁盔”。现在该路径已删除并由后端 Schema 双重拒绝。

六类请求审计没有发现其他跨 NPCContext 注入：计划、判别、修订、战时心理与反思始终以当前 NPC 为唯一人物上下文。审计另发现 `talk_to_npc` 候选曾携带目标实时地点、行动和入伍状态；这些字段并非执行所需，现已删除，执行时由 ActionSystem 权威查找 / 追踪目标。其他动态候选仍只定义可尝试行动，不授予角色知识。

## T0070 全员动态名册与职业规则认知

六类正式 NPC 请求的 `station_context.resident_roster` 现在始终列出全部 8 名登记成员，每人显式携带 `recruited` 与 `in_station` 两个布尔标签。逃离或已经处于 `outside_station` 的人不再从名册消失，而是保留身份并把 `in_station=false`；模型必须区分“未入伍”和“不在驿站”，不能用缺席或猜测补状态。名单来自 NPCSystem 当前状态，不在 Prompt 里维护静态副本。

初始知识图谱新增四条职业相关、已由程序实现但此前容易被忽略的规则：艾达知道训练场无受训者时教官独自练习会提高自己的武器或骑术，有受训者时则增长教练熟练度；莉娜知道诊所无病人时医生研习医术、有病人时团队共同治疗；托马知道成年马只能分配给已入伍且持主武器者，集结或战斗时坐骑会随骑手离厩；布鲁诺知道成餐比直接吃粮更耐饱。全部 8 人的仓库认识也加入六项资源按等级扩容的已实现事实，但仍不宣称仓库受击会丢货。

## T0077 NPC LLM 用量与预算边界

每日人民币账本按正式供应商的每次 HTTP 尝试计数，不按 NPC 事件数、业务成功数或 JSONL 生命周期行数计数。自动紧凑重试、业务最终失败和不同 NPC 的并发请求都会消耗同一上海自然日预算；Mock、规则 / 模板降级不写入真实 provider 费用账本。

预算拦截只阻止新的供应商尝试，不改变 NPC 性格、记忆、计划或程序权威状态。上层系统继续按现有可处理错误决定保留原计划或使用明确标记的规则 / 模板降级；禁止把 `budget_exceeded` 改写为模型成功或写入伪造的 NPC 话语。

## T0069 NPC LLM 诊断证据

NPC 对话、日计划、计划修改判别 / 修订、战时心理和首次睡眠反思的完整动态输入现在可在后端 JSONL 中按 `audit_id / request_id / npc_id / call_type` 检索。该日志只记录模型边界的输入、输出和校验，不写回 NPC 事件、见闻、日记或知识图谱，也不成为权威游戏状态；Godot 仍只应用通过 Schema、业务规则和迟到复验的结果。

完整日志可能包含 NPC 私人记忆、守备官对话和未被业务层接受的模型文本，因此不得作为广场公共信息、玩家 UI 内容或模型后续记忆源。业务校验失败以追加事件保留原始证据，但不会因日志存在而绕过既有拒绝 / 降级流程。

## T0067 战斗、日计划逃离与挽留真实模型结论

后端 `NPCStateContext` 现显式接收 Godot 已发送的 `behavior_mode / combat_mode / combat_strategy / morale_boost / escape_intent`。修复前这些字段会被 Pydantic 默认忽略，导致模型看到的状态丢失而不报错；现在六类继承 `NPCContext` 的正式请求都保留这些权威投影，LLM 仍无权直接修改它们。

对话响应除 Schema 外还执行上下文业务校验：逃离挽留只能用于 `dialogue_kind` 或 `interaction_context=escape_intervention`，必须匹配当前轮次且只返回 stay / leave；避战对话的 `wartime_reaction` 必须是 `none`；应征勾选与 `recruitment_result / intent` 必须一致；只有已入伍且持主武器的集结 / 战斗目标可返回战时逃离或斗志结果。真实 Main 已覆盖战时士气高昂、避战无应征、应征接受、应征拒绝、挽留成功和五轮失败。

`escaping_station` 确实由动态行动目录进入日计划候选，且合法计划执行时会由 DailyPlanSystem 交给 CombatSystem 的权威逃离入口。基准 1 次和高压 3 次真实 `plan_day` 都没有选择该项，因此目前只确认“可见 + 可执行”，没有确认完整日计划会稳定自主选择。后续不能用强行注入计划冒充模型自然选择。

真实选择证据表明上下文改变会影响挽留：只在台词中承诺撤回命令时，托马曾留下也曾继续逃离；当已入伍托马的危险 `current_order` 由程序实际更新为安全安排后，同一真实链返回 `escape_intervention_result=stay` 并成功回到工作。五轮不撤回底线冲突的场景则连续返回 `leave` 并耗尽入口。

## T0066 当前计划详情读取边界

NPCPanel 的“当前计划”继续只读 DailyPlanSystem 已生效的完整计划，不截断、不重排、不修改计划，也不触发 LLM。首次打开详情时，以 `GameState.current_hour` 对应的计划项为当前执行项，视图从该项之前第二个计划行动开始；0 点 / 1 点不足两项时夹取到当天开头，不读取或拼接前一天计划。打开后的计划替换 / 刷新继续保持玩家当前滚动位置。

## T0061 人物表达、历史切片与认知展示合同

`data/npc_profiles.json` 不再保存 `signature_lines` / “代表性表达”。`scripts/core/NPCPromptProfile.gd`、对话顶层 `npc_setting`、共享 `NPCIdentity` 和六类正式 LLM 上下文的语言倾向只保留宽松 `speech_style`；T0100 后身份另含精简 `religion`。模型必须结合性格、职业、长期记忆和当下事实自然组织语言，不能依赖固定台词池。T1501 / T0060 中关于台词样例注入的旧口径由本节取代。

三篇开局日记继续使用既有 8 字段结构，但前两篇承担不同层级的叙事职责：“往昔·来站前”宏观勾勒身世、职业来路、离开原处的原因和到站时间；“往昔·初到驿站”记录接手的工作与遇见的人。八人的到站顺序固定为艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜，各人的第二篇从不同角度互相咬合，拼成驿站逐渐恢复运转的群像。“往昔·近日”保留 T0060 已确认的开局前微观生活片段。

T0061 当时每名 NPC 对守备官只有一条技术键为 `role` 的开局职责认知；T0101 已新增三年前到站、来站前经历未知和开局前尽责和睦三条关系，但仍不得伪造具体旧事、身份或无条件信任。15 座建筑知识继续覆盖真实规则，但玩家可见 `relation_label / value_label` 必须写成人物在驿站生活中会形成的常识，不使用“初始、升级后、槽位、效率、结算”等说明书腔。T0061 当时从仓库条目移除了尚未实现的容量语义；T0070 容量落地后已重新加入按等级扩容常识，受击丢货 / 减少掠夺仍不写入。`confidence / day / time` 元数据全部保留。`NPCPanel` 的【知识】弹窗只显示中文主体、关系和值，不显示可信度与更新时间；NPCSystem、反思更新、后端参数和 GM 原始调试仍保留这些字段。

## T0060 八名 NPC 文案与开局认知合同

8 名 NPC 的根本人设、三篇初始日记和中文知识图谱已统一改为专业、直白、自然的中文。人物差异不再依赖晦涩比喻或刻意拟人，而由句式、用词、关注重点和判断习惯体现：托马朴实谨慎，布鲁诺口语化且爱抱怨，伊沃安静务实，格伦简短严厉，艾达条理分明，马塞尔温和完整，莉娜临床精确，欧文讲原因与解决办法。清楚易懂的轻微黑色幽默可以保留，但不得妨碍事实理解。

“往昔·近日”严格发生在守备官收到并向众人传达敌情之前，只能记录普通驿站生活，不得暗示人物已经知道敌袭、征召或备战安排。T0061 曾把守备官种子收敛为唯一职责事实；T0101 在保持玩家身份开放的前提下补入三年前到站、过去未知和开局前尽责和睦三项低细节认知。每人的图谱继续覆盖全部 15 座正式建筑：本职建筑记录更具体的用途和关键规则，其他建筑保持粗略但准确的世界内认识；这些认识仍不替代运行时权威状态与结算。

## T0059 开局人物历史与长期认知

8 名初始 NPC 的根本人设与具体人生历史现已分层：`npc_profiles.json.background_story` 只保存不随玩家互动改变的职业视角、价值尺度和根本矛盾；`npc_initial_long_memory.json` 保存每人来站前、初到驿站、近日三个第一人称生命切片，以及其对人物、建筑和个人往事的当前认知。这样同一职业信息不再在系统人设、日记和知识图谱三处反复讲述。

T0108 后，8 人对围墙 / 主厅工程器械位置的开局前认知与当前建筑配置一致：围墙六级数量为 `1 / 2 / 2 / 3 / 3 / 4`，主厅为 `1 / 1 / 2 / 2 / 3 / 4`，一次升级最多增加一个且部分等级不增加，主厅位置使弩床 / 箭塔射程变为 `2.0x`。这仍是 `npc_initial_long_memory.json` 中的稳定长期知识，不是新增人物属性或 Prompt Schema；防御、穿透和攻速等战斗数值仍不会作为 NPC Prompt 属性注入。

每人初始知识图谱覆盖其余 7 人、守备官、15 座正式建筑和至少 2 个个人故事主体。本职建筑有多条具体规则，其他建筑保持世界内口吻的粗略但正确认识；T0101 后守备官条目固定职责、三年前到站、来站前经历未知和开局前尽责和睦四项认知，不预写具体旧事或玩家身份。

NPCSystem 在生成实体前同时校验档案和初始记忆，缺失、未知 id、空日记、非 `key_value_replace_v1` 图谱或空关系都会让初始化明确失败。加载后六类正式 LLM 业务均读取这份运行态长期记忆：对话使用唯一顶层 `long_memory`，计划 / 判别 / 修订 / 战时心理 / 反思使用 `npc.long_term_memory`。`target_npc` 不复制目标长期记忆；T0071 后说话者只使用公开 `speaker_context`，不再注入另一 NPC 的任何完整人物或记忆上下文。

长期记忆是人格连续性和判断材料，不是程序权威。若初始建筑认知或过去印象与当前建筑、资源、行动候选、当天事件冲突，始终以实时程序字段和已发生事件为准；后续反思只在真实新事实支持时追加日记或替换认知。

## T0058 共享基础资源认知与升级协助

所有 NPC 中心 LLM 调用现在都从唯一顶层 `station_context.basic_resource_reserves` 获得驿站当前粮食、餐食、木材、石料和铁。该快照每次调用重新读取，不公开驿站第纳尔、酒、装备、器械、马匹或其他库存；NPC 可以据此对话和安排，但不能直接改写数量。T0063 起，目标 `npc.state.money / wine` 另表示该 NPC 本人实际持有量，不属于共享公开库存。

共享规则明确建筑升级会缓慢推进，成员可通过 `assist_upgrade` / “协助升级建筑”加快正在进行的工程。完整 `work_mode_actions` 告诉 NPC 这种行为存在；只有本次 `allowed_actions` 中出现某座建筑的动态候选时才表示当前可选，计划和修订不得从基础规则自造升级目标。

## T0055 持续活动与周期结算常识

`station_rules` 新增一条所有成员都理解的驿站常识：工作、照料、训练、治疗和制造等活动，只有在成员持续参与的有效时间内才推进，并在完成相应周期后由驿站实际记录结算产出或结果。离开岗位、改做他事或被高优先级事件打断后，活动不会在无人持续参与时自行继续产出。这样，模型不能再把“上午在菜园工作过”推断成“下午离开后菜园仍自动产粮”。

这条规则仍不是结算器。是否完成周期、结算了多少、当前小数进度是否保留、材料是否扣除、恢复或成长是否发生，全部以 ActionSystem 及对应权威系统提供的结构化事实为准。规则刻意使用“未完成进度是否保留以实际记录为准”，避免错误地把制造周期中断归零等特定规则扩散到所有活动。

## T0054 共享驿站常识与世界边界

所有 NPC 中心正式请求继续继承 `StationAwareNPCRequest`，唯一顶层 `station_context` 在 T0058 后固定包含六部分：精简地点简介、全体登记成员及当前标签、驿站全部建筑、工作模式下完整行为类型目录、五项公开基础资源、当前六条世界内驿站规则。人员、建筑、行为和资源分别来自对应权威系统，禁止在 Prompt、Schema 或 GDScript 中另写静态运行态副本。广场和公告牌不是建筑；仅运行态对话 / 逃离干预动作也不是工作模式计划行为。

这些规则只告诉人物如何理解所在世界：成员平时在站内工作和生活；需要持续参与活动并完成周期才会结算结果；敌袭时已入伍且装备主武器者保卫驿站；未入伍或没有主武器者尽量在站内避敌；士气低落时任何人都可能离开甚至临阵脱逃，使留下者处境更危险。这些是叙事与推理背景，不是状态结算。实际进度、产出、入伍、武器、士气、敌情、行动资格、资源和行为模式必须读取本次请求的权威状态；模型不得凭规则宣称事件已经发生。

`work_mode_actions` 是完整“行为类型目录”，用于防止模型补造世界外行为；每项的 `description` 可说明稳定前提和上下文影响。计划 / 修订 / 普通对话仍以本次动态 `allowed_actions` 为可尝试的精确候选，战时心理仍以 `allowed_decisions` 为输出边界。对话、每日计划、计划修改判别、正式修订、战时心理和首次睡眠反思只在顶层注入一次，共享 NPCContext、speaker / target 或记忆子结构不得复制它。

## T0053 跨小时对话等待与跨阶段人物上下文

只有 `DailyPlanSystem` 派发的 `talk_to_npc` 才在 ActionSystem pending options 中写入 `plan_action_source=daily_plan`、来源日 / 小时、计划版本和完整原计划项。T0076 覆盖 T0053 原“普通跨小时失效”口径：同一天跨小时后，即使当前计划已经移动到下一项，已经开始接近 / 等待的旧对话仍继续；只有同一小时内计划项被新修订替代、跨日，或权威目标 / 模式失效时才退出。仍走 `plan_item_superseded` 的失败会在 `last_action_failure_context` 保存原 `failed_plan_item`、当前计划项、来源 / 当前时间和版本、原目标及等待状态，DailyPlanSystem 必须使用原失败项启动 T0050 判别。非日计划的 GM / 测试对话不冒充日计划跨小时延续。

`PlanRevisionJudgementRequest` 不再是无人物上下文的轻量合同。日计划、对话 / 行动失败修改范围判别、正式修订和低血量战时心理判定统一使用 `NPCContext`：`identity`、权威 `state`、`current_order`、`short_term_memory`、`long_term_memory={knowledge_graph, diary}`、`location_context`；顶层携带动态 `station_context`。判别与修订还读取当前行动候选、建筑 / 资源状态；失败分支在两层之间原样传递 `failed_plan_item / failure_type / failure_summary / failure_context`。第一层仍只决定 `revision_hours`，不得输出行动或结算事实。战时加入战斗 / 继续避战 / 逃离的心理判断同样必须以这套人物与记忆上下文结合 `combat_context / battlefield_context`，不能另造一套人格。

## T0052 计划临界阶段与对话互斥

每日计划、计划修改判别和计划修订等待都使用 `llm_activity.kind=plan`。该活动从请求登记到 terminal 清理期间视为不可被对话取消的计划临界阶段：`DialogSystem` 在守备官草稿创建、草稿激活和首次消息 / 攻击真正生效前都检查 `NPCSystem.is_npc_plan_llm_active(...)`，返回 `npc_planning` 后不得推进 dialogue epoch、调用 LLM 取消或中断 NPC 当前行动。普通对话回复等其他 `cancellable=true` 活动仍沿用既有实际交互打断合同；深睡和战时心理判定继续使用各自更高优先级保护。

NPC-NPC 计划行动采用“可等待目标”而不是把计划活动当永久不可用：发起者可以接近目标，抵达后 `ActionSystem` 在 pending options 写入 `waiting_for_target_plan=true`，保留双方预约、开场目的和 `talk_to_npc` 运行态归属。目标的计划活动清除后，`npc_state_changed` 只安排一次延迟重试；重试时重新校验地点、行动能力、工作模式和不可打断状态，全部合法才调用原 `start_autonomous_npc_dialogue(...)` 邀请路径。等待本身不写失败，不触发 T0050 判别。即时失败修订仍排除计划 / LLM 活动目标，正式日计划可把并行计划中的 NPC 作为稍后交谈目标。

## T0051 守备官会话生命周期与 NPC 占用

守备官-NPC 会话现在把“窗口是否显示”与“会话是否仍活动”分开。普通对话第一次发送、攻击或挂起草稿时才真正打断 NPC 当前普通行动，记录被打断的运行时 action，并把 NPC 运行态设为 `current_action=talk_to_guard_officer`、`active_dialogue_id=<本会话>`；逃离挽留继续使用 `escape_intervention_dialogue`。挂起只写 `ui_visible=false`、`suspended=true` 和 7200 逻辑秒倒计时，不释放会话槽、原行动恢复令牌或正在等待的 LLM。

完成会话会先取消尚未返回的对话请求，再以已经存在的历史结尾提交会话事件；历史只要非空就进入 T0049/T0050 判别，因此玩家最后一句未获回复时也会触发。取消会话只允许在 `attack_committed=false`、不是 NPC 主动交涉且尚未发送应征消息时执行：取消 LLM、清空未提交历史、跳过事件 / 见闻 / 计划判别，并恢复仍匹配的原行动。两小时挂起超时时，普通可取消会话自动取消；含攻击事实、NPC 主动发起或已发送应征消息的会话因不可取消而自动完成。迟到异步响应因 `dialogue_id/request_id` 已失效而直接丢弃。

T0072 后，应征接受在模型合法回复回来并进入历史时立即由 NPCSystem 权威应用，取消剩余会话不会回滚；拒绝仍不改变状态。战时反应和逃离挽留结构化结果继续只暂存于会话，完成时才由 CombatSystem 权威应用，取消不会留下士气或逃离决定副作用。HP 伤害仍在攻击点击时立即结算，永不回滚。NPC-NPC 自主对话不使用此生命周期，继续逐轮入库和双方计划判别。

## T0050 统一计划修改判别层

T0050 将日常行动失败接入 T0049 已建立的两阶段机制。`PlanRevisionJudgementRequest` 通过 `trigger_kind=dialogue|action_failure` 区分事实来源：对话分支读取本轮完整对话、结束原因和会话元数据；行动失败分支读取程序权威 `failed_plan_item`、`failure_type`、`failure_summary`、必要的 `failure_context`、原 24 小时计划，以及从原计划派生的工作阶段下限信息。T0053 起两类分支都额外注入与日计划 / 正式修订一致的驿站、NPC 人设 / 状态、短期 / 长期记忆、行动候选、建筑 / 资源和 `current_order`，但仍不输出行动。

第一层统一返回 `needs_revision + revision_hours`。空集合表示 0 个修改阶段并立即终止；行动失败后 NPC 可以保持空闲等待下一阶段，但不会伪造修订。非空集合才进入完整 `/npc/revise_plan` 上下文，第二层只允许改写判别出的精确小时。工作阶段统计只提醒模型尽量维持产出，第一层不得仅为凑足 6 个阶段选择未受影响小时。

行动失败判别期间复用计划修订互斥锁、排队、过期版本丢弃、TimeSystem 慢速和对话派发屏障。判别为空 / 失败会释放锁且不产生第二层；判别非空后，原失败事实与判别结果一并进入第二层。同一计划阶段内可抑制重复状态通知，但进入新小时会清除失败去重缓存，因此同名失败在后续阶段重新发生时必须再次判别。修订落地后再次失败时，新权威失败也先重新判别，再按原有连续 3 次落地失败上限停止，不能绕过判别形成双后继或无限循环。守备官新指令、战斗结束 / 复苏和 GM 手动修订不属于日常行动失败，继续直接进入受限修订。

## T0049 对话后计划修改判别层

T0049 取代 T0048 “对话结束即全量重排剩余日”的口径。所有有实际完成内容的 NPC-NPC 与守备官-NPC 对话结束后，`DialogSystem` 为每名相关 NPC 独立请求通用 `plan_revision_judgement` 的 `trigger_kind=dialogue` 分支。判别输入包含当前时间、NPC id / 名称、对话类型、本轮完整对话、结束原因、会话元数据、该 NPC 原 24 小时计划，以及 T0053 统一的人设 / 状态 / 长短期记忆 / 指令 / 现实条件上下文。输出 `revision_hours` 必须去重、升序、不早于当前小时。空数组明确表示 0 个修改阶段，不得再调用 `/npc/revise_plan`。

只有判别非空时，`DailyPlanSystem` 才发起第二次真实 LLM 修订。该请求保留人设、状态、短期 / 长期记忆、地点、资源、建筑、行动白名单、当前指令、完整原计划和对话上下文，但 `revision_scope=selected_hours` 且输出必须恰好覆盖 `revision_hours`。未选小时不变；只有选中当前小时时才要求与当前项一致的 `immediate_action`，未选当前小时时必须为 `null` 且不重放当前行动。T0050 起日常行动失败也经过同一通用判别层；指令变化、战斗 / 复苏和 GM 等其他非对话原因继续直接修订。

NPC-NPC 双目标会话在发起任一参与者的判别前，由 `DailyPlanSystem` 预注册同一 `dialogue_id` 的计划派发屏障；无论是否跨小时，都要等双方第一层判别和各自必要的第二层修订全部终态，再按服务者、普通行动、依赖者、对话的计划依赖顺序放行，防止先完成的一方启动新行动并使另一方响应因对话 epoch 变化而过期。玩家-NPC 会话若以 `plan_hour_changed` 结束，也要延迟目标 NPC 的新小时派发，直到该 NPC 的判别 / 必要修订链终态。失败或取消同样必须释放屏障，不能永久卡住日程执行。

## T0046 共享基础场景与长期记忆输出

所有携带 NPC 根本人设的请求继承 `StationAwareNPCRequest`，并在顶层只携带一份必填且名单非空的 `station_context`。T0046 最初只提供地点简介和动态在站人员；T0054 已扩充建筑、工作模式行为与精简驿站规则；T0070 再把人员改为全体登记成员，并要求 `recruited / in_station` 两个标签。逃离、`behavior_mode=escaped` 或已在 `outside_station` 的 NPC 会保留在名册中并标为不在站，整个上下文仍不在嵌套 speaker / target 中重复。

首次睡眠反思只产生第一人称 `diary_entry` 和替换式 `knowledge_graph_updates`，不再产生独立 `memory_summary`。知识更新同时携带 `subject_label / relation_label / value_label` 中文显示文本；内部 `subject / relation / value` 仍可用稳定技术键 / 值，NPCPanel 必须映射为中文且对未知键和值使用中文保底。T0061 后玩家知识弹窗不展示 `confidence / day / time`，但这些元数据继续保存在运行态、后端请求 / 响应和 GM 调试视图中。

## T0044 守备官对话结束后的当前计划恢复

守备官发送消息后，玩家-NPC 对话会中断 NPC 的普通行动。若本次对话确实打断了正在执行的当前小时计划行动，且对话后判别返回空 `revision_hours`，NPC 仍可行动并处于 `behavior_mode=work`，DailyPlanSystem 应重新派发被打断的原计划行动。该入口同时校验“被打断的运行时行动 ID == 当前计划行动 ID”，只清除当前 NPC 本阶段的计划执行签名，再复用正常计划执行与资格校验；它不关闭常规的同小时重复派发保护，也不绕过建筑、位置、服务依赖、资源或目标可用性判断。

只打开再关闭对话窗不构成行动中断，也没有有效对话内容，因此不执行判别或恢复；NPC 原本空闲时完成对话，也不得重放本小时已经结束的短行动。判别选中当前小时、昏迷、逃离、集结、战斗或避战等分支由各自权威流程接管，不直接恢复旧计划。恢复时如果原计划已经不可执行，沿用计划系统既有失败 / 重估语义。

## T0043A 服务依赖行动生命周期

`receive_clinic_treatment`、`receive_weapon_training` 分别持续依赖 `work_clinic_doctor`、`work_training_instructor`。ActionSystem 在依赖者到岗申请位置前再次验证有效服务者；同批派发时若服务者仍在移动，依赖者可等待服务者到岗。依赖行动开始后，只要全部有效服务者退出，依赖者就立即得到结构化失败、释放位置并触发计划重评估，不等待替补。

教堂候选只有 `pray_at_chapel` 祈祷与 `lead_mass` 主持弥撒。祈祷无需神父，也不与弥撒互斥；主持开始、结束只改变祈祷者内部模式。每日计划同批派发顺序仍让诊所 / 训练服务者优先、普通行动其次、依赖者随后、对话最后，减少遍历顺序造成的伪失败；程序仍在每次执行时做最终权威复验。

## T0057 建筑升级失败重估合同（pending 时序由 T0080 修正）

建筑升级是程序已经确认的高优先级事实。NPC 正在前往目标建筑执行活动时继续移动，抵达入口且确认无法进入后才以 pending 阶段失败；NPC 已经在建筑内执行依赖活动时，以 active 阶段立即失败、释放位置并退出到广场。两者都写入可被 DailyPlanSystem 识别的 `*_failed_building_upgrading`，并在 `failure_context` 中保留建筑、行动、阶段、`condition=upgrading`、`failure_reason=building_upgrading` 和中文摘要；pending 另含 `arrival_check_failed=true`。

计划判别与正式修订继续使用现有 Schema 的 `failure_type=target_unavailable`，精确升级原因由 `failure_summary / failure_context` 承载。模型不得否认建筑已经开始升级，也不得让 NPC 继续进入或使用该建筑；第一层只选择需要修改的小时，非空时第二层才选择当前合法替代行动。协助升级发生在广场，不属于被升级建筑内部依赖行动，不能被该封闭规则误杀。

## T0043 位置行动、可见资格与失败重估合同

每日计划和对话行动参考继续共用 `data/action_defs.json` 候选源。吃饭、睡觉、祈祷、主持弥撒、坐诊、接受治疗、指导训练和接受训练分别申请建筑定义中的具体位置类型；NPC 不输出位置编号。除睡眠外，ActionSystem 在执行瞬间申请一个同类空位；睡眠由 BuildingSystem 根据 `assigned_npc_id` 返回该 NPC 的固定床，初始 8 人按既有叙事到站顺序使用床位 1–8，没有固定床位的未来 NPC 只能使用未分配床位。满位、固定床被占、升级封闭、建筑失效、服务依赖缺失或资格不符都写入 `last_action_failure_context` 并触发既有计划修订链路，LLM 不选择或改写床位归属。

T0063 新增 `drink_wine`：只有目标 NPC 当前 `states.wine >= 1` 时才进入其动态计划 / 对话候选；ActionSystem 开始执行时通过 NPC 个人资源接口再次原子校验并扣除 1。成功写 `wine_consumed`，只把“心情改善、过去伤痛暂时淡化”投影到后续上下文；不建立情绪数值，也不删除任何记忆。无酒写 `drink_wine_failed_no_wine`，DailyPlanSystem 按资源不足进入既有失败判别。

`lead_mass` 是“可见但受资格限制”的特例：所有 NPC 的候选目录都保留它，候选上下文携带 `eligible`、`available_now`、`unavailable_reason` 和 `required_ability=主持弥撒`。模型应让无资格者极少选择它；即使选择，程序仍确定性拒绝。资格读取 NPC 档案的 `abilities`，不按 `background_job`、姓名或固定 NPC ID 判断。普通 `pray_at_chapel` 不要求神父在场。

诊所和训练场采用建筑内团队模型，不把受服务者绑定给某一个医生或教官。每个逻辑推进周期重新读取全部有效诊疗位 / 教官位占用者，汇总人数和相应技能，再乘建筑升级与损伤效率，应用到全部病床 / 训练位。LLM 只选择行动，不计算治疗量、技能增长、资源扣除、位置占用或升级结果。

升级启动是高优先级程序事实：正在使用位置的 active 行动立即以建筑升级失败并退出广场；指向该建筑的待执行 / 移动中 pending 行动继续到入口，程序拒绝进入后才失败并进入统一重估。没有依赖行动的停留 / 访问者只清退，不伪造失败。升级协助本身发生在广场、不需入内，仍可继续并计为工作阶段。

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

正式每日计划和失败修订都从同一动态 `allowed_actions` 目录选行动。目录覆盖设计稿 10.3 的前往建筑、职业工作、吃饭、睡觉、祈祷、诊所治疗、NPC-NPC 对话、训练，以及特殊的主动找守备官交涉和逃离意向；修复 / 升级 / 昏迷治疗协助只在实时目标存在时加入。`talk_to_npc` 的 provider 决策必须使用同一候选对应的 `target_npc_id`，不选择地点，也不能选择自己、昏迷、逃离、深睡、非工作行为模式或不存在的 NPC；内部 kind 与目标由程序编译。

计划执行 `talk_to_npc` 时，发起者先追踪目标当前地点；目标移动后最多重定向一次。接近期间双方由 ActionSystem 预定，防止第三人并发抢占；已有权威对话时，即时计划修订不会再暴露必然失败的对话候选。到达后先走邀请判定，接受后才打断双方普通行动并释放工位，再使用真实 `/npc/dialogue` 自动轮流回复，直到任一方输出结束标记或高优先级条件中断。后端与 Godot 都要求 `replyer_id` 等于目标 NPC、`response_kind=reply_to_npc` 且邀请 / 正式阶段和软轮次字段一致。每个邀请交换和完成轮次写入双方事件库；任一已实际发生的邀请拒绝或正式会话结束后，两名参与者都各自请求 T0049 判别，仅判别非空者进入受限小时修订。战斗、避战、集结、昏迷和逃离等高优先级权威状态不会被日常计划或对话恢复逻辑覆盖。

24 小时计划先按每项声明的 `hour` 建表再排成 0-23，模型数组乱序不会交换行动时段，重复 / 越界 / 缺失小时会被拒绝。同批当前时段计划按“教官 → 其他非对话 → 受训者 → 对话”顺序派发，避免依赖 NPC 遍历顺序。运行态比较包含 action、target、必要 location 和 dialogue goal；普通派发仍以日、小时和计划版本签名幂等，T0075 在其上增加配置化完成策略：生产工作成功完成可受控清除签名并续开，单次行为另有不依赖计划版本的小时消费记录。修订请求绑定请求日、小时和计划版本，并使用单后继队列；迟到响应不会覆盖新计划，连续 3 次迟到落地失败后停止自动续修。正式计划 / 修订不使用 Mock 或规则降级；T0097 在完整 Schema 前只读取行为必要决策并丢弃其余模型字段，编译后的候选、小时、自聊和对话诉求错误仍失败。

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

T1501 已把 8 名 NPC 从数据草案收敛为 Demo 正式短档案。T0100 后每名 NPC 另有精简 `religion="天主教"`；在 `personality`、`desires`、`fears`、`boundaries` 之外，语言表达仍只由以下宽松字段限定：

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

`LLMBridge` 会把 `religion` 与 `speech_style` 放入对话 `npc_setting` 和共享 `NPCContext.identity`。对话 Prompt 要求模型从职业经验、性格、长期记忆与当前处境出发回应，并避免可互换的通用士兵台词；宗教信仰只在相关话题中自然参考，首次睡眠总结也遵守同一边界。

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

T0081 起，`NPCNeedsSystem` 成为全部 NPC 持续生活消耗的唯一入口。它读取 `data/activity_needs.json`，按 tick 开始时的移动、行动、战斗行为模式或昏迷状态选择唯一档位，再按有效逻辑秒连续结算饱食和疲劳。idle 仍会缓慢消耗；对话、拜访和移动只消耗生活状态、不增加经验；所有职业工作、训练和协助行为都消耗饱食、增加疲劳并进入现有成长体系；睡觉、病床治疗、饮酒和祈祷消耗饱食但恢复疲劳；集结、避战、逃离和战斗逐级提高压力，战斗档位最高。吃饭的食物恢复仍由 ActionSystem 结算，同时 `eat` 档位增加少量疲劳。

T0063 后，驿站 `wine` 还可通过 `NPCSystem.give_wine_to_npc(...)` 转入 NPC 个人 `states.wine`。个人酒与全局酒分开；`spend_npc_owned_resources(...)` 是饮酒的权威扣减入口，UI 和 LLM 都不能自行修改。

T0034 冻结的制造、具体库存和马匹合同现已由 T0035-T0038 实现：

- `work_blacksmith` / `work_workshop` 只有在对应建筑已经由玩家选中合法制造目标时才能开始。一个完整工作周期只提交一个配置阶段；周期被对话、改派、战斗、昏迷、离岗等打断时，该 NPC 本周期的小数进度归零，但建筑已完成整数阶段不回退。多工位可并行跑周期，提交时由 CraftingSystem 按 revision 原子领取下一阶段、扣除阶段材料并最终增加 11 项具体库存中的对应成品；NPC、LLM 和计划文本均不能直接指定完成阶段或产出成品。
- `work_stable` 的输入 / 输出资源为空，不再把粮食转换成匿名 `horse_readiness`。只有至少一名 NPC 正在马厩有效工作时，HorseSystem 才取在岗者中的最高“养马”熟练度推进逐马繁育概率、幼马 / 未完全成长成年马的成长和额外 HP 培养；多个工位不重复叠加照料能力。至少两匹成年在厩、非冷却马才逐分钟累积概率并执行最多 `N - 1` 次判定，成功后候选概率归零并冷却 1 游戏日。马匹饱食消耗、仅在厩内进行的持续进食、厩内外自然 HP 恢复和繁育冷却由 HorseSystem 随逻辑时间独立推进，NPC 工作只提供照料能力。马厩每升 1 级只让繁育概率增量增加 10%，不加速成长或额外 HP 培养。
- `HorseSystem` 权威保存唯一马匹实体和分配关系。只有已入伍且持主武器的 NPC 可分配成年、未分配、物理在厩马；分配后日常仍在厩，进入 `rally / combat` 才变为 `ridden`，退出战时状态返厩。收回主武器、取消入伍或逃离会自动解除分配；`equipment.mount` 仅保存具体 `horse_id / horse_name` 投影。
- 每日计划 / 修订可以选择这些工作意图，但 ActionSystem 在执行时仍须校验制造目标、马厩位置、工位和 NPC 可行动状态。计划 LLM 不能生成马、选择出生结果、扣粮、完成阶段或改写具体库存；弃用的 `weapons / armor / defense_devices / horse_readiness` 也不再是合法正式产出或消费来源。

2026-05-24 起新增协助修复行为；2026-05-25 起新增协助升级行为。`debug_assign_repair_assist(npc_id, building_id)` 与 `debug_assign_upgrade_assist(npc_id, building_id)` 都是带建筑参数的独立行为，可让 NPC 在广场协助正在修复或正在升级的建筑，并按工程熟练度加速对应倒计时；NPC 如果在室内，会先前往广场再开始协助。如果 NPC 离开广场或被改派其他行动，`BuildingSystem` 会移除其协助人数和速度加成。T0081 起，两类协助按真正推动作业的有效时长累计工程经验，每 3600 有效游戏秒增加 1 点“工程”；目标作业在 tick 中途结束时，超出完成时点的时间不再计算生活消耗或经验。协助修复/升级事件写为 `location_id == "plaza"` 的 `local_public`。计划系统只能安排意图并调用行动白名单，不能让 LLM 直接结算资源、建筑、经验或 HP。

T0501 起，`NPCSystem.apply_damage_to_npc(...)` / `debug_damage_npc(...)` 负责权威 HP 扣除。HP 降到 0 时 NPC 进入昏迷而不是死亡，停止移动，`current_action` 变为 `unconscious`，头顶标签与 NPC 面板会显示昏迷状态。昏迷 NPC 不能移动或执行工作、吃饭、睡觉、协助修复/升级等行动。

T0502 起，昏迷 NPC 会随 `TimeSystem.logical_time_tick` 自然恢复 HP，当前速率为每游戏小时 2 HP；HP 达到 Max HP 的 30% 后自动复苏，`unconscious=false`，`current_action=idle`，后续移动和行动指派重新允许。复苏会写入 `revived` 事件并按当前信息地点 `local_public` 广播。

T0503 起，其他可行动 NPC 可通过 `ActionSystem.debug_assign_heal_assist(healer_npc_id, target_npc_id)` 协助治疗昏迷目标。治疗者会前往目标所在信息地点；目标必须处于昏迷状态，每个目标最多 2 名治疗者。治疗开始和持续治疗会消耗全局第纳尔；医术熟练度会转化为额外 HP 恢复速度，低医术几乎没有额外加成，医生的高医术会明显快于自然恢复。T0081 起，协助者每 3600 有效治疗秒增加 1 点“医术”；NPCSystem 依据目标当前 HP、30% 复苏阈值、自然恢复和所有治疗者加速，返回本 tick 真正有效的治疗秒数，避免目标已经复苏后继续获得生活消耗或经验。治疗开始/完成事件会写入治疗者和目标的事件库，并写入同地点其他在场 NPC 的见闻库；事件信息不暴露医术熟练度。

T0808 起，小诊所治疗补齐为两个独立行动；T0043 将它们的位置合同统一为 `work_clinic_doctor -> clinic_doctor_station` 诊疗位与 `receive_clinic_treatment -> clinic_patient_bed` 病床。初始容量为 1 个诊疗位、2 个病床，两类都可由升级扩展。每个逻辑推进周期都汇总全部有效诊疗位占用者的人数、医术和相关属性，得到共享诊疗团队效率并作用于全部病床；再与诊所升级和损伤效率合成最终 HP 恢复速率。无病人时，诊疗位上的 NPC 以很慢节奏研读医学著作；医术增长继续进入统一经验与技能点规则。

T0903 起，训练场补齐为两个独立行动；T0043 将它们的位置合同统一为 `work_training_instructor -> training_instructor_station` 教官位与 `receive_weapon_training -> training_practice_slot` 训练位。初始容量为 1 个教官位、2 个训练位，两类都可由升级扩展。训练项目由受训者当前武器 / 坐骑决定；每个逻辑推进周期汇总全部有效教官位占用者的人数、“教练”和对应项目熟练度，得到共享指导团队效率并作用于全部训练位；再与训练场升级和损伤效率合成最终训练速率。无受训者时，教官仍极慢练习自己当前装备；有受训者时，教官只提升“教练”。

T0904 起，`NPCSystem.increase_npc_skill(...)` 是统一成长入口。普通职业工作完成时会以很慢速度提升该行动配置的职业熟练度；诊所研读 / 治疗、训练场独自练习 / 受训 / 指导训练也复用同一入口。T0081 将协助修复、协助升级和协助治疗的有效时长成长接入同一入口；非工作行动（idle、移动、对话、吃饭、睡觉、祈祷、饮酒、病床恢复、集结、避战、逃离、战斗）不会仅因生活消耗而获得经验。每次熟练度实际增加都会写入运行时 `progression.skill_experience` 和 `progression.total_experience`；当前每 5 点总经验产生 1 个 `unspent_skill_points`。技能点不由 AI 自动分配，必须由玩家在 NPC 面板或 GM 调试入口调用 `NPCSystem.assign_npc_attribute_point(...)` 分配到力量或智力。AI 后续可以根据背景、近期行为和目标给出建议或倾向，但不能自行消耗技能点，也不能直接改写力量 / 智力权威状态。T0045 后属性分配仍写入 `private` 的 `attribute_improved` 事件，但世界内 summary 把 NPC 自身作为 actor，力量 / 智力分别表达为锻炼体力 / 脑力所得，不再写“守备官分配”。

T0502A 起，昏迷 NPC 不接收地点/广场公开广播、建筑/地点状态广播、公告或进入快照，见闻库暂停更新；事件库仍记录发生在自己身上的受伤、昏迷、复苏等亲历事件。复苏后见闻接收自动恢复，但不会补收昏迷期间错过的信息。

2026-06-03 起，睡觉 NPC 使用同一条见闻接收规则：当 `current_action == "sleep_in_dormitory"` 时，该 NPC 不会把同建筑内发生的 `local_public` 事件、地点/建筑状态广播、公告或进入快照写入见闻库；自己的入睡和醒来仍进入事件库。睡醒回到可行动状态后，只从后续广播继续接收见闻，不补收睡觉期间错过的信息。

T1004/T1005/T1405/T0046 建立了熟睡总结、长期写入与深度睡眠锁；T0094 将触发调度修订为 21:00 锚定窗口。同一窗口内实际睡眠可跨多次中断累计，满 1 个游戏小时才触发 `DailyReflectionSystem`，成功应用后该窗口不再自动重复。系统通过异步 `/npc/daily_reflection` 把当前短期事件库和见闻库摘要交给后端（开发期可使用 Mock，Prompt 任务必须使用真实 API 验收），后端不可用时使用本地模板，生成第一人称日记和知识图谱当前键值更新，不再生成并列的长期摘要。反思从发起请求到应用完成期间，NPC 进入不可打断的深度睡眠锁：玩家对话、消息、行动改派和普通中断都会被拒绝；已入伍 NPC 仍可保存新指令，但计划重评估延后到醒来后执行。结果由 `NPCSystem.apply_daily_reflection(...)` 把 `diary_entry` 追加到长期 `diary`，并把 `knowledge_graph_updates` 按 `subject + relation` 替换式写入 `knowledge_graph.by_subject`；随后轮转该 NPC 当前短期事件 / 见闻索引。NPC 面板可查看日记和 LLM 状态，GM 面板可强制触发、查看长期记忆和 21:00 窗口快照。模板降级必须保留模型失败日志，不得用 mock 日记伪装真实模型成功。

T1305 起，胜利和失败结算会为每名 NPC 生成结局总结快照。`GameState.set_game_over(...)` 读取 NPC 当前权威状态、入伍状态、最后位置、长期日记和当天事件，生成确定性 Mock 字段：最终状态（可行动 / 昏迷 / 逃离）、是否入伍、对守备官最终看法、后续命运和记忆依据。该结局总结只用于 HUD 结算页展示，不会写回事件库、见闻库或长期记忆，也不会让 AI 反向改写 HP、逃离、入伍或地点事实。NPC 不死亡，因此结算文案不使用“阵亡”或“死亡”描述 NPC。

T0701-T0705 已实现 Godot 前端对话、最小征召、指令发布和主动交涉最小闭环。已入伍 NPC 可从 NPC 面板打开 `OrderPanel`，自由查看、修改并发布一条持续生效的 `current_order`；`NPCSystem.publish_npc_order(...)` 只在文本变化时更新指令、写入私有 `order_assigned` 并发出计划重评估请求。若 NPC 正处于首次睡眠总结锁，指令仍保存，但重评估延后到醒来后。T0015 后 GM 面板可调用 `NPCSystem.set_npc_recruited(...)` 将选中 NPC 设为入伍，用于调试指令、装备和训练入口；T0072 后正式对话返回合法接受结果时立即提交同一权威状态并刷新 NPC 面板，不再等会话完成。`NPCSystem.debug_start_proactive_talk(...)` 可让 NPC 进入主动找守备官交涉状态，显示问号气泡，点击后打开既有对话面板并把预先确定的开场问题放入会话缓冲；1 小时无人点击则状态结束。

T1001 起，`DailyPlanSystem` 可生成规则版 24 小时调试计划并保存到 NPC `plan` 字段，写入 `plan_created` 事件，并按 `hour_started` 调用 `ActionSystem` 执行当前小时行动；T0025 后普通派发以同一计划版本 / 小时签名幂等，T0075 后短行动是否续开改由 `completion_policy` 决定：六种生产工作成功完成可在当前逻辑计划项不变时立即开始下一周期，每小时单次行为不因新 `plan_version` 重放；T0086 的五类配置标记短 / 目标行为在成功完成后改为直接修订并立即执行当前小时后续安排。T0050 后，实际对话与日常行动失败都先调用通用判别层，仅在返回非空 `revision_hours` 时进入真实 `/npc/revise_plan`；已经成功完成的标记行动、主动交涉超时、战斗结束 / 复苏和新指令等确定性来源直接修订。T0023 后，计划修订通过 `LLMBridge.request_npc_plan_revision_async(...)` 在后台调用真实 `/npc/revise_plan`；工位占用、资源不足以及其他已有 `failed` 行动结果先进入 `request_plan_revision_judgement_async(...)`。等待期间 NPC 显示 LLM 活动并注册 TimeSystem 慢速；Godot 只接受带非 Mock provider 证明且 `model_fallback_used=false` 的响应，成功合并为 `llm_plan_revision`。只有修订包含当前小时时才执行即时项；失败最多重试 3 次真实请求且不应用 Mock / 规则修订。T0051 后，打开后取消空会话无副作用；玩家消息发送即进入会话历史，完成会话时即使 NPC 回复未返回也会取消请求、把已有历史入库并触发判别。取消会话不入库、不应用仍暂存的战时 / 挽留意向且不判别；T0072 的合法应征接受是已经提交的权威状态，不随取消回滚。挂起会话让 NPC 保持 `talk_to_guard_officer`，最多 2 游戏小时后自动取消。攻击一旦发生则不能取消，完成或攻击后的挂起超时都会保留攻击历史并进入统一判别。

T1003/T1403/T0022/T0085 起，每日计划可通过 `/npc/plan_day` 生成 24 阶段计划，请求包含当前 `current_order`、短期/长期记忆、地点、资源、建筑状态和行动白名单。正式开局和跨天后的新一天只接受已配置的真实 provider；后端成功响应携带 `model_provider` / `model_name` / `model_fallback_used`，Godot 将通过验证的计划统一写为 `source=llm_plan_day`。后端校验 24 个 hour 覆盖与行动白名单；通常至少 6 个工作阶段只保留为 Prompt 强建议。其他真实失败仍只重试真实请求，不写入规则 / Mock 计划。

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
- `location_context`：地点当前状态读取占位，不包含地点历史事件。广场权威状态仍保存公告牌当前通告、参考日程及非强制备注，供公告牌 UI / GM / 只读上下文查询；但 NPC 的广场 `location_entry_snapshot` 只包含当前在场 NPC、在场 NPC 状态和所有建筑的可传播外部状态，不再重复携带公告牌两页。进入可进入建筑时包含该建筑的等级、`condition`、`is_enterable`、运行效率分档，以及在场 NPC、NPC 状态和完整逐位置清单。每个位置使用玩家可读名称表达空闲 / 占用；位置新增、移除、改名、改类型或换占用者时，在场 NPC 获得字段级差量。在场 NPC 的生命状态只表达健康、受伤、昏迷，行动状态由 `current_action` 翻译成精简中文。HP 具体数值、精确效率和剩余修复 / 升级时长不进入 NPC 见闻；容量不用额外聚合数字表达，而由完整位置清单及其增删差量自然得出。

T0035/T0037 已按 T0034 冻结合同在 `location_context.internal_state.special_state` 中实现严格白名单：铁匠铺 / 工械坊只包含制造目标与整数阶段；马厩只包含物理在厩马匹的总数、成年数和小马数。当前制造周期的小数进度、逐匹马的名称 / HP / 饱食 / 成长 / 进食 / 分配信息不得进入 NPC 地点上下文。NPC 只有进入该建筑时获得完整当前快照，或在仍处于该建筑且未昏迷 / 未睡觉时获得字段级变化；建筑外 NPC 与广场快照不得获得这些实时内部状态。离开后，后续 LLM 只能看到该 NPC 已经合法收进见闻的旧信息，不能绕过 MemorySystem 查询全局最新值。

这些字段由地点上下文与见闻链路按可见性传给后续 LLM 请求，但不授予 LLM 查询建筑全局实时状态或修改权威制造 / 马匹状态的权限。

## 事件、见闻与短期记忆

T0405 后，NPC 的短期记忆不再视为一个扁平文本列表，而由两类运行时记录组成：

- NPC 事件库：发生在该 NPC 身上的事件，例如醒来、制定计划、进入/离开地点、工作、吃饭、睡觉、对话、收到或修改守备官指令、被给予金钱/装备、升级、受击、昏迷、治疗、复苏、逃离等。
- NPC 见闻库：该 NPC 从地点/广场即时广播、状态变化广播、公告或他人公开事件中获得的信息；昏迷或睡觉期间暂停更新。

NPC 进入地点时，系统生成 `location_entered` 事件并写入进入者事件库；该事件只记录“某人进入了某地”，不附带完整建筑状态。进入者随后在见闻库获得一次当前状态快照：进入广场时获得当前广场在场 NPC、广场在场 NPC 的生命状态 / 行动状态和所有建筑可传播外部状态，不包含公告牌通告、参考日程或备注；进入某个可进入建筑时获得该建筑外部 + 内部状态，包括当前在场 NPC、建筑内 NPC 的生命状态 / 行动状态和工位占用。公告牌两页在守备官发布实际变更时分别向全站当前可接收见闻的 NPC 广播一次，不受地点影响；只改一页不广播另一页。已经在该地点的其他 NPC 只收到 `location_entered` 本地公开事件，不再额外收到完整人员状态。NPC 不会因为进入某建筑而继承该建筑过去发生的事件。

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

T1203 后，逃离不再只是 pending 意向。`CombatSystem.start_npc_escape(...)` 会让 NPC 写入 `escape_started`、切出工作 / 战斗 / 避战行为并前往后门外出口；逃离移动期间 `escape_intent.status == "escaping"`，普通行动和战斗 AI 不再把该 NPC 当作可用单位。抵达出口后 `NPCSystem` 标记 `escaped=true`、`behavior_mode="escaped"`、`current_location="outside_station"`，隐藏并取消拾取 NPC 实体，写入广场公开 `escaped` 事件。逃离 NPC 被点击会先打开 NPC 面板；轮次未用完时，玩家点击【对话】进入 `dialogue_kind == "escape_intervention"` 的同地点公开挽留对话。挽留打开或挂起时 CombatSystem 保持逃离暂停，完成、取消或满 5 轮时恢复；请求携带 `escape_intervention_round`、当前 `escape_intent`、短期记忆、长期记忆、地点上下文和 `current_order`。T0087 后模型或规则降级只返回暂存的 `escape_intervention_result=stay|leave`，完成时才由 CombatSystem 停止或继续逃离、记录轮次并写入同名事件；取消不应用结果。给钱 / 守备官攻击分别调整程序权威的逃离移动倍率；逃离挽留攻击不向 NPC LLM 发送消息、不产生 NPC 回复，只计 1 轮、锁定取消并自动完成会话。逃离期间昏迷会暂停为 `paused_unconscious`，复苏后继续逃离。

## 已入伍 NPC 指令机制

正式玩家指令系统不是 ActionSystem 的行动下拉，也不是 RTS 式强制命令：

- T0072 后，守备官对话返回合法 `recruitment_result=accept` 时立即调用 `NPCSystem.set_npc_recruited(...)`；不再等对话结束。`npc_state_changed` 会让仍打开的 NPC 面板立刻显示入伍状态和指令入口，取消剩余对话不会撤销已经说出口的接受结果。
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
