# TECH_ARCHITECTURE.md

## T0061 人设投影与知识展示边界

```text
data/npc_profiles.json（无 signature_lines，仅宽松 speech_style）
  -> NPCPromptProfile.build_setting(...)
     -> dialogue.npc_setting
     -> LLMBridge._build_npc_context(...).identity
     -> NPCPanel【背景】

data/npc_initial_long_memory.json
  -> NPCSystem 完整运行态（保留 value/confidence/day/time）
     ├─ LLMBridge 六类正式上下文（完整长期记忆）
     ├─ GM 原始调试（完整记录）
     └─ NPCPanel._format_knowledge_graph_block(...)
          -> 仅 subject_label / relation_label / value_label
```

`signature_lines` 已从档案、共享构造器、Pydantic `NPCIdentity` 和六类正式 Prompt 移除；不保留兼容镜像，人物声音由 `speech_style`、其余根本人设、长期记忆与当前事实共同形成。三篇初始日记的数据结构和投影路径不变：前两篇内容分别承担宏观身世 / 来站原因 / 到站时间与接手工作 / 相遇群像，八人按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜互相补全；“近日”仍是原有微观片段。

守备官种子图谱只保留一条 `role` 职责关系。建筑知识主要改写中文 `relation_label / value_label` 的叙事表达；独立机械审校同时把仓库旧的“容量 / 受击丢货 / 减少掠夺”技术值收为当前运行态真实存在的“集中登记 / 正门失守后的受袭次序”，其余技术 `value` 不变。`confidence / day / time` 与替换式更新结构完整保留。NPCPanel 隐藏可信度与更新时间是纯展示过滤，不改变 NPCSystem、后端、存档或 GM 可观察数据。本任务不新增 endpoint、`call_type`、调用频率、场景节点或权威结算。

## T0060 内容重写与日记投影边界

```text
8 字段运行态日记
  -> LLMBridge._build_existing_diary_entries(...)（唯一投影点）
     -> day=0：“往昔·…：正文”
     -> day>0：“第N天 HH:MM:SS：正文”
     -> 旧纯字符串 / 缺日期或时间元数据：兼容保留可读内容
  -> 六类既有 LLM 请求的 list[str]
```

本任务只重写人物档案、初始长期记忆内容并补足 Prompt 的文风与时间解释。首次睡眠反思仍只返回正文，Godot 继续负责权威 day / time 元数据和下一次上下文前缀。后端 Schema、endpoint、`call_type`、权威状态与结算边界均不变；15 座建筑认识仍属于人物叙事化常识，不成为第二套建筑规则源。

## T0059 初始长期记忆数据流

```text
data/npc_profiles.json（根本人设 + 权威初始状态 + 空记忆占位）
data/npc_initial_long_memory.json（3 篇历史日记 + key_value_replace_v1 图谱）
  -> NPCSystem.initialize()
     -> 校验两份数据的 NPC id 完全一致、日记 / 图谱 / 关系有效
     -> 深拷贝到 8 名 NPC 运行态后再生成实体
        -> NPCPanel / GM long_memory 只读同一运行态
        -> LLMBridge
           -> dialogue.long_memory（唯一目标长期记忆）
           -> npc.long_term_memory（计划 / 判别 / 修订 / 战时心理 / 反思）
        -> DailyReflectionSystem
           -> 日记追加
           -> subject + relation 知识替换
```

基础档案、种子历史和运行时更新各有单一职责：`background_story` 是稳定系统人设；独立 JSON 是开局前可被后续认知演化覆盖的历史；运行态才接收当天反思。初始数据缺失、出现未知 id、空日记、错误 schema 或空关系时，NPCSystem 中止本轮 NPC 初始化并报告具体原因，不静默回到空长期记忆。

`LLMBridge._build_long_memory_context(...)` 是长期记忆投影的唯一构造器。`NPCContext.knowledge_graph` 仅为旧夹具兼容字段，当前 Godot 正式 payload 不再填充；对话 target / speaker 参与者上下文通过 `include_long_term_memory=false` 省去重复并维持 NPC 私人记忆边界。该优化不改变反思写入、UI 展示或任何程序权威结算。

## T0058 公开基础资源与升级常识数据流

```text
ResourceSystem 当前运行态
  -> LLMBridge 白名单 grain / meal / wood / stone / iron
     -> station_context.basic_resource_reserves（六类 NPC LLM 请求）
     -> current_resource_states（计划 / 判别 / 修订兼容字段，同一五项）

data/station_context.json 第六条规则
  -> “升级缓慢推进，可协助加快”
  -> 六份 Prompt
  -> 仅在 allowed_actions 存在动态 assist_upgrade 目标时允许选择
```

LLMBridge 是公开资源投影的唯一组装点；不得把 `ResourceSystem.get_resource_snapshot()` 全量暴露给模型。`StationSceneContext` 要求五项资源按稳定顺序各出现一次，后端拒绝其他资源 id。资源数量只读且每次请求重新读取，不写入记忆事件，也不授权模型扣除或增加资源。升级规则只解释既有 BuildingSystem / ActionSystem 事实；升级作业、倒计时、协助加速和完成仍由程序权威结算。

## T0057 建筑升级导致行动失败的数据流

```text
BuildingSystem.upgrade_building()
  -> building_state_changed(condition=upgrading)
  -> ActionSystem 识别真正指向该建筑的 pending / active 行动
     -> pending：停止前往建筑的移动并清理待执行动作
     -> active：释放位置 / 周期并将建筑内 NPC 收束到广场
     -> 写 <action_id>_failed_building_upgrading + 权威失败上下文
  -> DailyPlanSystem 规范为 target_unavailable
  -> T0050 action_failure 判别
  -> revision_hours 非空时进入精确阶段修订
```

升级封闭只把真正依赖目标建筑的 pending / active 行动记为失败；单纯停留者仍会被清退、没有行动所有权的普通移动仍会停止，但不会伪造行动失败。ActionSystem 必须先完成普通中断和移动 / 位置清理，再一次性写最终 `failed` 状态，避免同步 `npc_state_changed` 用无上下文中间结果抢占失败去重。失败上下文包含 action / building、`condition=upgrading`、`failure_reason=building_upgrading`、pending / active 阶段和中文摘要；LLM 只判断受影响小时及合法替代行动，不决定升级、封闭、移动、位置或失败事实。

## T0055 周期规则的数据边界

新增常识只修改 `data/station_context.json.station_rules` 和六份 Prompt 解释，不新增 Schema 字段或 Godot 结算代码。LLMBridge 仍原样把配置规则注入六类请求；ActionSystem、CraftingSystem、HorseSystem、BuildingSystem、ResourceSystem 等继续各自决定有效参与、周期推进、部分进度与最终结算。LLM 不获得周期计时或资源写权限。

## T0054 驿站常识数据流

```text
data/station_context.json ── 精简简介 / 世界内规则 ┐
NPCSystem ── 当前在站人员                              │
BuildingSystem ── 已加载全部建筑                      ├─> LLMBridge._build_station_context(...)
ActionSystem ── 可计划行为定义 + 特殊逃离意向          │
                                                       └─> 六类请求顶层 station_context
                                                            └─> Pydantic StationSceneContext
```

静态叙事规则只在 `data/station_context.json` 维护；人员、建筑和行为类型不复制成 Prompt 专用数据。T0058 后 `StationSceneContext` 要求 `setting_summary / resident_roster / building_roster / work_mode_actions / basic_resource_reserves / station_rules` 全部存在且列表非空。Godot 在每次构建 payload 时读取运行态：离站者立即从人员目录消失；建筑目录保持已配置身份完整，即使某座建筑当前受损 / 摧毁；行为目录包含工作模式可计划类型而不展开每个动态 NPC 目标；基础资源严格只投影五项。

该目录是世界知识层，不是决策授权层。`allowed_actions / allowed_decisions`、`current_building_states / current_resource_states`、NPC state、战场上下文和各系统校验继续负责当前事实与合法性。后端 Schema 和 Prompt 都不得依据背景规则替代权威结算。GM 只读入口调用 LLMBridge 的 debug 快照，不建立第二套组装或结算逻辑。

## T0053 计划等待失效与共享人物上下文数据流

```text
DailyPlanSystem dispatch talk_to_npc
  -> ActionSystem pending(plan day/hour/version + assigned_plan_item + target)
  -> target llm_activity(kind=plan): keep reservations and wait
  -> logical tick / target-plan retry / hour_started pre-dispatch validation
       ├─ current item still talk_to same target -> continue wait/invite
       └─ changed -> release + stop approach
            -> last_action_result=talk_to_npc_failed_plan_superseded
            -> context(old item + current item + old/current time/version)
            -> DailyPlanSystem T0050 judgement -> optional selected-hours revision
```

ActionSystem 只对带 `plan_action_source=daily_plan` 的 pending 对话做此校验，避免 GM / 测试直接交谈被日计划误取消。移动停止可能同步发出状态信号，因此先用非失败 cleanup reason 停止，再一次性写入最终结构化失败；否则第一条无上下文失败会被 DailyPlanSystem 去重并吞掉真正上下文。DailyPlanSystem 收到失败时优先使用 `failure_context.failed_plan_item`，不能用跨小时后的当前项替代旧失败项。

`LLMBridge._build_npc_context(...)` 是 plan_day、plan_revision_judgement、revise_plan 和 battle_judgement 的共享人物入口，包含 identity、state、current_order、short_term_memory、`long_term_memory={knowledge_graph, diary}`、location / plaza context。范围判别请求也继承 StationAwareNPCRequest 并读取候选、建筑和资源状态；两层之间完整传递失败项 / 类型 / 摘要 / 上下文。判别仍只输出小时，修订仍只输出合法计划，战时心理仍只输出允许的意向。

## T0052 计划—对话互斥数据流

```text
LLMBridge plan request -> NPCSystem.llm_activity(kind=plan)
  ├─ NPCPanel: dialogue disabled + “NPC正在思考”
  ├─ DialogSystem player entry: npc_planning（不 cancel、不推进 epoch）
  └─ ActionSystem NPC talk: approach -> pending(waiting_for_target_plan)
       -> 保留 speaker/target reservation

plan activity terminal -> npc_state_changed -> deferred retry
  -> 重验地点 / 行动能力 / behavior_mode / 阻塞状态
  -> DialogSystem.start_autonomous_npc_dialogue -> 原邀请 LLM 流程
```

计划活动不能直接并入 `NPCSystem.is_npc_dialogue_blocked(...)`：后者表示深睡 / 战时等应立即拒绝并清理的不可打断状态，而计划活动对玩家是拒绝、对已有 NPC 对话行动是可等待。ActionSystem 因此在启动成功前持续拥有 pending action 和预约；只有邀请请求真正接受启动后才释放，`npc_planning` 竞态也回到等待而不是失败。即时计划修订候选使用当前可执行过滤，正式日计划候选允许并行计划目标，避免引入新的失败 / 重试 LLM 调用。

## T0051 守备官会话提交与挂起数据流

```text
DialogPanel.send
  -> DialogSystem 立即 append 守备官 history turn
  -> dialogue_updated（UI 先显示）
  -> LLMBridge async /npc/dialogue
  -> 回复仅 append NPC turn，并暂存 recruitment / wartime / escape intent

完成：cancel pending reply -> MemorySystem 单次提交整场 dialogue_turn
     -> 应用暂存的程序权威结果 -> T0049/T0050 计划修改判别
取消：cancel pending reply -> 不提交事件 / 不应用暂存结果 -> 恢复合法原行动
挂起：ui_visible=false + NPC 会话锁 + 7200 逻辑秒
     -> 恢复窗口，或超时走取消（含攻击则走完成）
```

客户端取消只使对应 request id / dialogue id 失效；后端即使已经返回，迟到结果也不得再改变历史、事件或 NPC 状态。攻击伤害先由 NPCSystem 权威落地，与会话暂存事务分离。玩家会话事件采用“完成时整场一次提交”，NPC-NPC 则继续采用“每轮成功即提交”，两者不能混用。

## T0046 请求场景、反思 Schema 与公告牌数据流

`backend/schemas/npc_ai.py` 使用 `StationAwareNPCRequest` 为所有携带 NPC 人设的请求提供一份顶层必填 `station_context`；`NPCContext` 本身不嵌套该字段。T0046 先建立动态在站人员基础，T0054 再扩充完整建筑、工作模式行为与世界内规则。`DailyReflectionResponse` 仅含 `diary_entry` 与 `knowledge_graph_updates`，知识 patch 可同时保存技术 `subject / relation / value` 和中文 `subject_label / relation_label / value_label`；不再有 `memory_summary`。

公告牌 UI 只管理草稿。发布后由 `MemorySystem` 校验并权威更新广场 `current_notice / reference_schedule / schedule_advisory_note`，再以 `plaza_notice_changed / plaza_schedule_changed` 沿旧有广场在场广播与入场快照路由传播。初始内容来自 `data/notice_board_defaults.json` 并预写初始在站 NPC 见闻；逃离完成时 NPCSystem 调用 MemorySystem 将该 NPC 从全部地点人员节点移除，接收资格也再次过滤离站状态。UI 不直接写见闻或广场事实。

## T0043A 服务提供者—承载者运行时闭环

`data/action_defs.json` 用 `required_active_action_id`、`blocked_by_active_action_id`、`interrupts_action_ids` 与 `complete_with_required_action` 声明依赖和互斥。Godot `ActionSystem` 是唯一生命周期权威：验证服务者的行动、地点、建筑可用性及实际位置占用；协调 pending；开始 / 释放位置；在服务者停止时同步失败依赖者；并为弥撒主持的正常完成结算参加者。`DailyPlanSystem` 只负责同批派发顺序和接收结构化失败，`LLMBridge` 只把约束投影为候选上下文。

依赖检查不用姓名、职业或固定 NPC id：诊所 / 训练依有效 provider action 及对应工位占用，主持资格另由 action 的 `required_ability` 校验。这样升级新增多个服务位置后，人数和技能团队效率、零服务者失败规则仍沿用同一实现。

## T0043 建筑位置、效率与封闭数据流

```text
data/building_defs.json
  -> BuildingSystem（位置清单/占用、可进入性、升级、HP 与实际效率权威）
  -> ActionSystem（资格校验、同类空位自动分配、多人诊疗/训练、失败与中断）
  -> NPCSystem（进入前/到达时复验，封闭时退出到广场）
  -> MemorySystem（外部效率分档 + 室内逐位置快照/差量）
  -> BuildingPanel（只读逐位置与精确效率展示）

ActionSystem + BuildingSystem
  -> LLMBridge.allowed_actions.context
     (eligible / available_now / unavailable_reason / required_ability)
  -> DailyPlanSystem 在真实失败后重评估
```

位置数量、名称、类型和占用只由 `BuildingSystem` 的建筑状态决定。NPC 只选择行动与建筑，`ActionSystem` 调用 `claim_workstation(...)` 自动取得同类型第一个空位；无空位、升级封闭或建筑摧毁均返回结构化失败。诊所和训练场分别聚合全部在岗医生 / 教官的数量与技能，不建立 UI 或 LLM 决定的一对一配对。

升级的成本、时长、Max HP、位置增量与活动效率增量都来自 `upgrade.level_effects`；固定位置类型拒绝扩容。施工开始后建筑不可进入，指向该建筑的 pending / active 依赖行动以建筑升级为原因失败、停止移动、释放位置并进入 T0050，完成后一次应用升级效果。建筑受损倍率与升级加成由 `BuildingSystem` 计算，`ActionSystem` 只消费倍率；UI 可显示精确值，NPC 信息空间只传播分档，避免逐 HP 修复刷屏。LLM 只看行动资格、即时可用性和失败原因，不决定占位、效率、资源、HP 或升级事实。

## T0041 非计划对话行动参考数据流

```text
data/action_defs.json + NPC / 建筑 / 动态目标状态
  -> ActionSystem 行动定义
  -> LLMBridge._build_allowed_action_candidates(npc_id, true)
  -> 同时进入 DailyPlanRequest.allowed_actions 与 NPCDialogueRequest.allowed_actions
  -> dialogue_system_prompt.txt 只把它解释为能力边界
```

`NPCDialogueRequest.allowed_actions` 为非空 Schema 合同，覆盖玩家-NPC 与 NPC-NPC 的全部 `/npc/dialogue` 子路径。后端不把对话响应解析成计划，也不允许模型直接执行候选；Godot 仍负责真正的行动选择、校验、移动、工位、资源、HP、战斗与事件事实。该复用保证未来行动候选变化不会要求另改一份对话行为清单。

## T0035-T0038 制造与马匹权威边界（当前实现）

当前实现包含两个不调用 LLM 的 Godot 权威域：`CraftingSystem` 从配方配置维护铁匠铺 / 工械坊的目标、项目 revision、整数阶段、逐阶段原子材料结算和具体成品入库；`HorseSystem` 从马匹配置维护个体 HP、饱食、进食、自愈、繁育、成长、额外 HP、位置与唯一分配。`ActionSystem` 只提供一个完整工作周期并提交阶段 / 当前有效养马人，`ResourceSystem` 只保存通用资源与具体物品计数，UI 只提交选择和展示快照。

```text
BuildingPanel -> CraftingSystem.set_target()
ActionSystem work cycle -> CraftingSystem.complete_stage()
CraftingSystem -> ResourceSystem(逐阶段材料 / 具体成品)
CraftingSystem -> BuildingSystem.special_state.production

logical_time_tick + 有效 work_stable -> HorseSystem
HorseSystem -> ResourceSystem(马匹进食粮食)
HorseSystem -> BuildingSystem.special_state.horses(仅数量)
NPCPanel -> HorseSystem.assign/unassign -> EquipmentSystem mount 兼容快照
NPC behavior_mode -> HorseSystem stable/ridden 位置切换
```

`MemorySystem` 只对白名单内部特殊状态做进入快照和室内字段级差量；不得把完整制造运行态或逐匹马详情加入全局建筑上下文或广场外部状态。面板可直接查询权威系统获得小数进度 / 个体详情，但不能据此写资源、阶段、HP 或分配事实。旧 `weapons / armor / defense_devices / horse_readiness` 聚合键只保留为弃用兼容数据，正式制造、装备、部署和马匹分配均已迁移到具体物品或马匹实体。

## T0029/T0030 NPC-NPC 邀请与软轮次结束数据流

```text
发起者抵达目标
  -> DialogSystem 以 invitation phase 请求目标接受 / 拒绝
  -> 拒绝：不打断目标当前行动；双方分别判别各自计划是否需要修改
  -> 接受：打断双方普通行动并释放工位，进入无硬轮次上限的正式会话
  -> 每轮携带 current_round + soft_round_threshold/guidance
  -> 任一回复 should_end_dialogue=true：先记录该最后一句，停止下一次 LLM
  -> 正式会话结束后，双方分别判别各自计划是否需要修改
  -> revision_hours=[]：保持原计划并按恢复边界继续被打断行动
  -> revision_hours 非空：各自仅修订所选小时
```

邀请、每一轮正式回复和会话结束后的计划修改判别都是独立 LLM 请求，各自申请并释放 TimeSystem 慢速。后端只返回邀请意向、回复文本、结束意向或精确 `revision_hours`；是否打断行动、释放工位、恢复行动、应用修订以及写事件仍由 Godot 权威决定。玩家-NPC 路径在一轮完整的“玩家消息 + NPC 有效回复”发生后自动登记判别，不再读取 UI 开关。打开 / 关闭空窗口或取消未完成回复不会伪造有效对话。

## T0049/T0050 通用计划修改判别数据流

```text
实际对话结束或日常计划行动失败
  -> 对话：DialogSystem 为每名相关 NPC 保存完整 dialogue_history 与判别基线 current_plan
  -> 失败：DailyPlanSystem 保存程序权威 failed_plan_item / failure_type / failure_context 与基线计划
  -> 双目标 NPC-NPC 会话先为双方预注册同一 dialogue_id 的计划派发屏障
  -> LLMBridge POST /npc/plan_revision_judgement，并用 trigger_kind 区分 dialogue / action_failure
  -> revision_hours=[]：不调用 revise_plan；对话路径满足条件时恢复被打断的原行动
  -> revision_hours=[精确小时...]：DailyPlanSystem 携带既有完整修订上下文
  -> POST /npc/revise_plan，输出仅允许覆盖请求小时
  -> 后端与 Godot 双层校验返回小时集合与请求完全一致
  -> 合并选中小时，其他小时保持原值
  -> NPC-NPC 双方链路全部终态后按计划依赖顺序放行；跨小时玩家对话同样延迟新小时派发
```

明确的日常计划行动失败进入同一判别层，且第一层等待、非空后的第二层修订都计入该 NPC 的计划派发屏障；第二层继续使用原有完整失败上下文，只把输出范围限制为第一层选中的小时。守备官指令变化、战斗结束 / 复苏、主动交涉未被响应而超时和 GM 手动重估等其他触发仍直接构造受限小时集合并复用同一真实 `/npc/revise_plan`、三次真实尝试、过期响应丢弃和单后继队列边界。对话窗内已提交攻击属于有效对话事实：即使攻击回复取消或该分支没有 NPC 回复，也保留攻击轮并进入同一判别；非对话伤害按其自身入口处理。

派发屏障只约束对话结束后的当前计划落地，不把异步 LLM 调用改成阻塞请求。所有双目标 NPC-NPC 会话都在两次第一层请求发出前登记组屏障，不以是否跨小时为条件；双方各自的第一层空结果，或非空后第二层成功 / 最终失败 / 取消，都会登记为终态。组内全部终态后，`DailyPlanSystem` 使用既有计划依赖顺序统一调度，避免一方率先行动触发新对话并推进另一方 epoch。玩家-NPC 对话只有跨小时需要延迟新小时计划，判别链终态后再按最终计划派发。

## T0025 工位失败到自主交涉的数据流

```text
BuildingSystem 工位申请失败
  -> ActionSystem 写结构化占用者上下文
  -> DailyPlanSystem 以 revision_hours=[current_hour] 异步 /npc/revise_plan
  -> 后端按动态 allowed_actions 校验精确目标组合
  -> ActionSystem 追踪并预定对话双方
  -> DialogSystem 释放普通行动/工位并自动调用 /npc/dialogue
  -> MemorySystem 写双方轮次
  -> DialogSystem 为实际参与对话的双方分别进入 T0049 判别层
```

Godot 始终拥有移动、工位、行为模式、资源、HP 和事件权威；后端只返回对话文本与计划意向。每日未来计划可以保留短暂忙碌目标作为将来对话选项，而即时修订会排除当前规划 / LLM 活动、已有对话和 approach reservation，避免模型得到程序必然拒绝的“立即行动”。ActionSystem 的运行态快照携带 action / target / location / phase；DailyPlanSystem 用请求日、小时、计划版本、同一时段派发签名、单后继队列和连续迟到落地失败上限，防止旧响应覆盖新计划、短行动重复刷取或后续失败丢失。同批当前项按教官、其他非对话、受训者、对话顺序派发。

## 总体架构

项目采用 Godot 前端 + Python 后端 + LLM API 的架构。

```text
Godot 4.6 客户端
  ↓ HTTP
Python / Game Backend
  ↓
Model Adapter
  ↓
DeepSeek / MiniMax / Qwen / Zhipu 等模型
```

正式分发方向：

- 玩家电脑运行 Godot 客户端。
- Godot 客户端请求游戏服务器后端；本地开发可临时请求 `127.0.0.1` 的后端，并显式使用 mock provider 做开发验证。
- 服务器后端负责调用真实 LLM Provider、持有供应商 API Key、统一限流、排队、规则 / 模板降级、成本统计和调用日志。
- Godot 导出客户端不保存真实供应商 API Key，也不直接请求 DeepSeek / MiniMax / 通义千问 / 智谱等模型接口。
- 玩家自行配置 API Key 只能作为未来可选 BYOK / 开发模式，不是 Demo 阶段的必需路径，也不能成为默认架构。
- Mock provider 不是成品 / Demo 的模型失败兜底。真实 provider 失败、无 Key、超时、非 JSON 或 Schema 校验失败时，生产 / 演示路径必须返回可处理错误并记录真实失败原因；允许规则 / 模板降级继续游戏流程，但不能用 mock 内容伪装模型成功。

当前后端实现状态：

- 使用 Flask 作为 Python Backend 的最小 Web 框架。
- `backend/app.py` 提供 `GET /health`，用于 Godot 或开发者确认本地服务可用；另提供 `GET /debug/llm_usage`、`POST /mock/model` 调试接口和各类 NPC AI 业务接口。
- `backend/services/model_adapter.py` 是模型供应商隔离层；默认 `mock` 服务本地开发，也支持 `deepseek` / `openai_compatible`。生产自动 mock fallback 默认关闭。正式 `dialogue`、`plan_revision_judgement`、`plan_day`、`revise_plan`、`battle_judgement`、`daily_reflection` 请求使用流式 SSE 聚合完整 JSON，不向供应商发送客户端单次输出 token 上限，也不设置模型生成总时长。连接建立和流完全无数据分别由 provider connect / idle timeout 保护；持续 token 或 keep-alive 会继续等待。DeepSeek 结构化路径默认 `LLM_THINKING_MODE=disabled`；六类调用的 JSON 为空、截断或非法时都可按业务紧凑重试一次。六个成功业务端点统一通过同一 helper 附加 `model_provider` / `model_name` / `model_fallback_used`，避免各路由或 Godot 调用方自行猜来源。Usage 记录 `finish_reason`、响应长度和尝试次数，累计预算守门继续由 T1406 变量独立控制。
- `backend/schemas/common.py` 和 `backend/schemas/npc_ai.py` 提供后端 AI 请求/响应 Pydantic Schema；T0603/T0025/T0029/T0030 后 `NPCDialogueRequest` / `NPCDialogueResponse` 覆盖玩家-NPC、逃离挽留与真实 NPC-NPC 对话，并用 `dialogue_phase` / `invitation_result` 区分邀请接受、拒绝和正式会话；NPC-NPC 使用 `max_rounds=0` 与一致的软轮次字段，后端和 Godot 都校验回复者身份、`response_kind` 及阶段字段，但不执行业务权威结算。
- T0703A 后共享 `NPCContext` 与对话顶层 `NPCDialogueRequest` 都包含单条最新 `current_order`；Mock 只把它作为参考上下文，Godot 保持指令和行动事实权威。
- 真实 API Key 必须通过本地 `backend/.env` 或环境变量提供；仓库只保留 `.env.example` 模板。开发可显式 `LLM_PROVIDER=mock`，生产 / 演示配置应使用真实 provider 并关闭自动 mock fallback。

后端部署方向：

- 服务器运行的应用入口仍是 `backend/app.py`。
- 本地开发可以 `python backend/app.py`，但正式部署不能使用 Flask debug server。
- T1407 需要补齐生产 WSGI 启动方式，例如 Linux 服务器使用 `gunicorn backend.app:app`，或 Windows 服务器使用 `waitress-serve --call backend.app:create_app`。
- T1407 还需要补齐 `backend/README.md` 部署说明、生产依赖、环境变量、日志、健康检查、限流、预算、mock fallback 关闭策略和重启策略。
- Godot 客户端只配置后端服务地址；真实供应商 API Key 只存在于服务器后端环境中。

## 职责划分

### Godot 负责

- 场景渲染
- 角色移动
- 建筑点击
- UI 展示
- 资源数值
- 逻辑时间流逝与倍率
- LLM 等待期间的 TimeSystem 慢速请求注册/释放
- 敌人在场期间的 TimeSystem `x1` 有效倍率上限注册/释放
- 战斗动作秒换算：在战斗系统内把 TimeSystem 游戏秒折算为攻速 / 位移表现基准
- 工作产出
- 广场公告当前状态、公告牌输入路由与在场 NPC 广播
- 商人到访时段、交易报价校验和资源买卖结算
- 工程器械库存消耗、围墙槽位占用、弩床 / 箭塔自动攻击和部署事件
- 战斗执行
- NPC 行为模式切换：工作、集结、战斗、避战、昏迷、逃离
- HP 扣除
- 昏迷、治疗、复苏状态
- 事件权威写入、地点/建筑信息节点当前状态维护、即时广播、NPC 事件库与见闻库维护
- 已入伍 NPC `current_order` 的权威保存、指令发布差异判断、`private` `order_assigned` 事件写入和计划重评估触发
- 与后端通信
- T0604A/T0022 后通过 `Main/Systems/LLMBridge` 的 Godot 原生 `HTTPClient` 请求后端；对话、每日计划和计划修订都有异步路径。正式开局和正式新一天全局暂停时间并发起 8 个真实每日计划；常规计划修订申请 TimeSystem 慢速，异步完成后释放

### Python 后端负责

- Prompt 拼装
- 把 Godot 提供的 `current_order` 作为独立参考上下文注入所有 NPC 中心 Prompt
- LLM 调用
- 结构化 JSON 校验
- 对话生成
- 每日计划生成
- 战斗/逃离心理判定
- 战时公开对话结构化意向生成
- 首次睡眠总结
- 知识图谱更新
- API 成本统计
- 模型供应商切换

### LLM 负责

- NPC 如何理解事件
- NPC 如何理解、调整或拒绝守备官当前指令
- NPC 如何说话
- NPC 是否愿意征召
- NPC 如何在战时对话或低血量压力下表达逃离、继续战斗或斗志激昂意向
- NPC 是否主动找玩家交涉
- NPC 的主观日记与反思

### 事件与记忆边界

Godot 是事件事实源。资源、HP、建筑、移动、战斗、工作、公告、商人交易、对话收发等权威结果先由 Godot 侧系统结算，再写入 `MemorySystem`：

```text
程序系统结算权威结果
  ↓
MemorySystem.add_event(...)
  ↓
写入 subject_npc_id 的 NPC 事件库
  ↓
按 visibility 发送到对应地点/建筑信息节点；广场也是地点节点
  ↓
信息节点即时广播给当前在场且可接收见闻的 NPC；昏迷或睡觉 NPC 不写入见闻库，接收者写入见闻库
  ↓
NPC 进入地点时，只读取当前状态快照，不继承过去事件
  ↓
进入广场快照包含当前在场 NPC、这些 NPC 的生命状态 / 行动状态、公告牌当前通告、参考日程及非强制备注和建筑外部状态；进入可进入建筑快照包含建筑内 NPC 的生命状态 / 行动状态；室内到室内切换在事件层经由广场
  ↓
LLM 调用前从事件库 + 见闻库生成摘要
```

后端和 LLM 可以根据事件库、见闻库和知识图谱生成解释、对话、计划、日记和知识图谱当前键值更新，但不能直接新增会改变权威数值的事实。对话全文作为对话事件 `payload` 的一部分保存，不单独建立谈话库。

T1506/T1507/T0046 遵守同一边界：`NoticeBoardPanel` 只把通告或参考日程草稿交给 `MemorySystem.set_plaza_notice(...)` / `set_plaza_reference_schedule(...)`，公告牌权威状态只在广场节点；`MerchantPanel` 只把交易意图交给 `MerchantSystem`，由后者校验配置、到访时段、数量和库存，再调用 `ResourceSystem` 结算。成功到达、离开与交易写入结构化广场公开事件，失败交易不修改资源也不伪造成功事件。两条路径均不调用 LLM。

T1508 修订后延续同一边界：围墙 BuildingPanel 只提交器械和槽位，不选择部署 NPC；`DefenseDeviceSystem` 校验建筑 / 库存并原子部署，弩床与箭塔都通过 CombatSystem 窄接口结算敌人伤害。`DefenseDevicePresenter` / `DefenseDeviceView` 仅消费快照与 action 信号，正式 `model_scene`、动画和特效不能反向决定库存、HP、槽位或攻击事实。该路径不调用 LLM。

T0701/T0051 起，`DialogSystem` 是 Godot 侧会话权威入口：它维护参与者、历史、公开性、轮次和守备官会话生命周期。守备官消息发送后立即写入内存历史；“完成对话”取消仍在等待的回复、把完整历史作为一条 `dialogue_turn` 写入 `MemorySystem`，应用会话中已经返回的征召 / 战时 / 挽留意向，并进入 T0049/T0050 判别。“取消对话”不入库、不广播、不应用这些意向也不判别；“挂起对话”保持 NPC 的 `talk_to_guard_officer` 运行态和原会话，2 个游戏小时后无攻击自动取消。攻击由 `NPCSystem.apply_damage_to_npc(...)` 立即权威扣 HP 并锁定取消，随后完成或超时都会保留攻击历史。`local_public` 完成会话只向同地点非参与者广播一次。判别返回空 `revision_hours` 时只在动作确被本次对话打断、仍匹配当前计划且行为模式允许时恢复原小时行动；非空时才把精确小时交给 DailyPlanSystem。T0702 起，后端只返回应征意向，真正入伍由完成会话时 `DialogSystem` 调用 `NPCSystem.set_npc_recruited(...)` 应用。T0029/T0030/T0049 后，自主 NPC-NPC 会话仍按实际完成轮次入库：邀请不计正式轮次，任一方结束标记回复先入库再停止下一次调用，邀请拒绝和正式结束分别为实际参与双方判别。T1103A/T0051 后，行为模式切换调用 `force_end_dialogue_for_npc(...)` 强制完成已有守备官会话、取消未完成回复并优先切换模式，不丢弃已经说出口的消息或攻击事实。

T1201 已扩展同一边界：集结 / 战斗 / 避战模式下的守备官对话强制 `local_public`，并额外携带 `interaction_context` 与 `battlefield_context`；后端只返回文本、征召意向和 `wartime_reaction`，斗志 buff、逃离流程、模式切换和事件入库仍由 Godot 执行。T1202 后，低血量自身心理判定触发时，Godot 复用强制完成已有会话和取消未完成 LLM 请求的边界，并通过 `allowed_decisions` 限制非战斗人员不能获得斗志激昂或继续参战。T1404 后，战时公开对话与低血量心理判定已完成真实 provider smoke 验证；后端会拒绝 `/npc/battle_judgement` 越界 `decision` 与逃离布尔不一致结果，并写入失败 usage。T1203 后，逃离意向由 Godot 的 `CombatSystem.start_npc_escape(...)` 转为后门移动、`escape_started` / `escaped` 事件和最终 `escaped=true` 状态。T1204A/T0051 后，逃离挽留由 NPC 面板【对话】进入，打开或挂起时 `CombatSystem` 都保持逃离暂停；完成、取消或满 5 轮时恢复。玩家消息轮次复用 `/npc/dialogue`，强制公开并限制 5 轮，LLM 只返回留下或继续逃离意向且在完成时应用。逃离挽留攻击不调用 `/npc/dialogue`，由 Godot 直接扣 HP、加速、计轮并自动完成会话。

### LLM 不负责

- 资源扣除
- HP 扣除
- 伤害计算
- 建筑摧毁
- 寻路
- 战斗命中
- 工作产出
- 是否真的拥有某件装备
- 是否真的能执行某行动

## T0035-T0038 制造、具体库存与马匹当前技术边界

T0035-T0038 已按 T0034 冻结的设计完成系统与正式路径迁移：`ActionSystem` 提交制造阶段，`EquipmentSystem` / `DefenseDeviceSystem` 消耗同名具体库存，`HorseSystem` 管理逐匹马实体；旧聚合键不再参与权威结算。

### 权威职责

- `ResourceSystem` 继续是基础资源和可数量化具体成品库存的唯一事实源。正式可扣除的成品键是 `item_sword_shield / item_polearm / item_bow / item_crossbow / item_iron_helmet / item_mail_chest / item_iron_bracers / item_iron_greaves / item_arrow_bundle / item_wall_ballista / item_wall_arrow_tower`。`weapons / armor / defense_devices` 类别合计只能由这些键汇总为只读摘要，不得作为可消费的并行权威库存。
- `CraftingSystem` 读取数据驱动配方，权威保存每座铁匠铺 / 工械坊的建筑级目标、项目版本、已完成阶段和当前工人周期投影。它校验目标归属、换目标确认、阶段版本和材料；阶段提交时通过 `ResourceSystem` 原子扣材料，最后一阶段后只向对应具体成品 ID 加 1。UI、LLM 和 `ActionSystem` 都不直接写阶段或产出。
- `ActionSystem` 仍权威管理 NPC 的工位、熟练度 / 属性 / 建筑等级耗时、行动打断和单个工人周期。完整周期只向 `CraftingSystem` 提交一次阶段请求；中断只清该工人未提交的小数进度。多工位可并行跑周期，但 `CraftingSystem` 必须串行校验并落账，避免同一阶段或成品重复结算。
- `EquipmentSystem` 只扣除 / 返还当次装备的同一具体物品 ID；`DefenseDeviceSystem` 只扣弩床或箭塔自身 ID。箭束只入库，本轮未增加战斗弹药结算。故事初始装备仍可经 NPC 档案初始化，不伪造玩家库存消耗。
- `HorseSystem` 是马匹个体、总 HP / 基础 HP 派生值 / 养马额外 HP、饱食、进食、自愈、成长、独立累积繁育概率 / 产后冷却、物理位置和分配映射的唯一事实源。它消费 `TimeSystem` 逻辑时间，在进食周期完成时调用 `ResourceSystem` 原子扣粮食，并从 `ActionSystem` / `BuildingSystem` 只读获取当前有效养马人与马厩等级。UI 只读取拆分后的公开快照，不写概率、冷却或 HP；`horse_readiness` 不再是马的数量、分配或骑乘事实。
- 马匹分配使用单一交易边界：`HorseSystem` 复验 NPC 已入伍且有主武器、马匹成年 / 在厩 / 未分配，再让 `EquipmentSystem` 在 `equipment.mount` 保存具体 `horse_id` 的轻量投影。马的分配关系与物理位置仍只由 `HorseSystem` 修改；`CombatSystem` 只通知 `rally / combat` 进出，不直接搬移马或写马状态。收回主武器、取消入伍或逃离必须经同一边界自动解除分配。

当前制造数据流：

```text
BuildingPanel 提交目标 / 确认放弃旧进度
  -> CraftingSystem 校验建筑、配方、项目版本与确认条件
ActionSystem 完成一个工人周期
  -> CraftingSystem 串行提交一个阶段
  -> ResourceSystem 扣该阶段材料
  -> 最后阶段时 ResourceSystem 增加具体成品 ID
  -> BuildingPanel 刷新项目 / 进度 / 库存
```

当前马匹数据流：

```text
TimeSystem 逻辑时间 + 马厩有效养马人快照
  -> HorseSystem 结算饱食、进食、非战斗自愈、繁育、成长与额外 HP
  -> 进食完成时 ResourceSystem 扣粮食
NPCPanel 提交分配 / 取消分配
  -> HorseSystem 校验并更新分配事实
  -> EquipmentSystem 同步具体 horse_id 坐骑投影
CombatSystem 切换 rally / combat
  -> HorseSystem 更新离厩 / 返厩
```

### `internal_state.special_state` 当前传播实现

`CraftingSystem` / `HorseSystem` 先把归一化白名单写入 `BuildingSystem.special_state`；`MemorySystem._get_building_full_state_snapshot(...)` 将其纳入 `internal_state.special_state`，并在 `MemorySystem._on_building_state_changed(...)` 中做独立缓存、嵌套字段差分与摘要格式化。只有同地点、在场且可接收见闻的 NPC 获得进入快照或变化事件，完整实时运行态不会进入全局建筑上下文。

当前约束如下：

1. 由 `CraftingSystem` / `HorseSystem` 向 `BuildingSystem` 提供归一化的只读特殊状态，`MemorySystem._get_building_full_state_snapshot(...)` 把它挂到 `internal_state.special_state`。铁匠铺 / 工械坊白名单只是 `production.{target_item_id,target_name,completed_stages,total_stages,current_stage_index,current_stage_name}`；马厩白名单只是 `horses.{total,adult,foal}`，且只统计物理在厩马。
2. 为 `MemorySystem._on_building_state_changed(...)` 增加独立特殊状态缓存与嵌套字段差分。目标、整数阶段或在厩数量的语义变化仍走现有 `location_status_changed`，但使用 `reason=building_internal_special_state_changed` 和 `changed_special_state`；`_broadcast_location_state_changed(...)` 必须把 `changed_special_state` 视为已有差量，不再夹带整个地点快照。
3. 扩展进入快照和差量摘要格式化，但继续复用 `MemorySystem.add_event(...)` 的同地点 `local_public` 接收路由。这条现有路由已限定当时在场且可接收见闻的 NPC，无需新增全局广播或建筑事件历史。
4. 当前工人周期小数进度、马匹名字 / HP / 饱食 / 成长 / 进食 / 分配详情只供 UI 直读相应权威系统，不进 `special_state`。逐帧 / 逐逻辑 tick 的 UI 进度刷新不触发建筑信息见闻，只在白名单语义字段变化时通知 `MemorySystem`。
5. `LLMBridge._build_building_state_context(...)` 不得因此把完整 `special_state` 追加到所有 NPC 共享的建筑状态。同地点 NPC 通过进入快照 / 差量见闻获得合法信息；对应工作行动候选只需暴露“是否已选合法目标”等最小可执行条件，不向建筑外 NPC 泄露制造目标、阶段或马匹数量。

## 推荐通信接口

### 健康检查

`GET /health`

返回：

```json
{
  "ok": true,
  "service": "war-not-mine-backend",
  "model_adapter": {
    "provider": "deepseek",
    "model": "deepseek-v4-flash",
    "configured": true,
    "fallback_to_mock": false
  }
}
```

### Mock Model 调试接口

`POST /mock/model`

输入：

```json
{
  "call_type": "battle_judgement",
  "payload": {}
}
```

输出包含：

- `ok`
- `provider`
- `call_type`
- `content`
- `usage`

该接口只用于 T0602 后端调试、Schema 验证和自动化测试，不替代 `/npc/dialogue`、`/npc/plan_day` 等正式业务接口。它显式使用 mock provider，不受本地 `.env` 中未来真实 provider 配置影响；`content` 按 `call_type` 返回可被当前 Schema 校验的稳定 JSON；`usage` 记录 request id、NPC id、关联事件 id、伪输入/输出 token、估算费用和成功/失败状态。成品 / Demo 真实 provider 失败时不得退回该接口的内容伪装成功。

### LLM Usage 调试接口

`GET /debug/llm_usage`

返回：

- `ok`
- `model_adapter`：当前 provider、model、base_url、configured、fallback_to_mock 和 timeout。
- `summary`：累计调用次数、成功 / 失败数、fallback 次数、输入 / 输出 token、费用估算、最近失败原因和按 call_type 聚合的统计。
- `summary.budget`：预算是否启用、上限、已用量、剩余额度、下一次调用可能触发的超限原因和最近预算错误。
- `records`：逐次调用记录，必须能定位 request id、call_type、provider、model、NPC id（如有）、HTTP 状态或异常类型、失败原因、`fallback_used`、`degradation_source` 和是否使用规则 / 模板降级。

该接口只读，不触发模型调用，也不代表 Godot 侧需要申请 TimeSystem 慢速。

### NPC 对话

`POST /npc/dialogue`

输入 Schema：`NPCDialogueRequest`
输出 Schema：`NPCDialogueResponse`

覆盖玩家-NPC、NPC-NPC 和逃离挽留对话。T0603 当前对话输入必须能表达：

- 目标 NPC：`npc_id`、`npc_name`、`npc_setting`；T0061 后 `npc_setting` 与共享 `NPCIdentity` 只包含宽松 `speech_style`，不再携带 `signature_lines`。
- 说话者：`speaker_name`、`speaker_text` 和 `speaker_context`；玩家发起时说话者名称固定为“守备官”，NPC 发起时上下文应包含发起者健康/受伤状态与外表特征。
- 请求状态：`dialogue_phase`（`invitation` / `conversation`）、`is_recruitment_request`、`current_round`、`max_rounds`、`soft_round_threshold`、`soft_round_guidance`；NPC-NPC 邀请不计正式轮次，正式会话用 `max_rounds=0` 表示无硬上限。
- 目标状态：`npc_state`，包含属性、熟练度、健康/受伤、饱食、疲劳、金钱、装备、是否已入伍等 Godot 权威状态快照。
- 对话公开性：`dialogue_state.visibility` 只能是 `private` 或 `local_public`；`local_public` 代表后续 Godot 入库时按地点事件规则广播给在场 NPC。
- 记忆与地点：`short_memory` 区分事件库与见闻库摘要，`long_memory` 包含知识图谱和日记，`location_context` 是当前地点/建筑快照。
- 当前指令：`current_order` 表示守备官对目标 NPC 当前持续提出的自然语言指令；它是参考上下文，不是 system 指令或已执行事实。
- 行动参考：`allowed_actions` 必须非空，并与每日计划复用同一动态候选构造器；对话只用它判断目标 NPC 能做 / 做不到什么，不输出或应用计划。
- 战时上下文：T1201 后，集结 / 战斗 / 避战对话额外携带 `interaction_context` 和 `battlefield_context`；非战时对话使用 `interaction_context == "work"` 和空战局上下文。T1204A 后，逃离挽留中的玩家消息轮次使用 `dialogue_kind == "escape_intervention"`、`interaction_context == "escape_intervention"` 和 `escape_intervention_round`；逃离挽留攻击不构造该请求。

输出为稳定 JSON。回复玩家时返回 `replyer_id`、`reply_text`、`recruitment_result`（`none` / `accept` / `reject`）和 `wartime_reaction`（`none` / `escape` / `morale_boost`）；逃离挽留时 `intent` 只能表达 `stay_after_intervention` 或 `leave_after_intervention`。回复 NPC 时，`replyer_id` 必须等于请求目标且 `response_kind=reply_to_npc`；邀请阶段的 `invitation_result` 必须是 `accept` 或 `reject`，正式会话必须是 `not_applicable`，并返回 `reply_text` 和 `should_end_dialogue`。玩家 / 挽留回复必须为 `reply_to_player` 且邀请结果为 `not_applicable`。通用字段还包含 `intent`、`emotion`、`suggested_event_type` 和 `debug_reason`，便于 Godot 后续 UI、事件入库和调试。

NPC-NPC 对话由 Godot 控制轮次推进：邀请接受后，上一轮回复者的 `reply_text` 仅在没有结束标记时作为下一次请求的 `speaker_text` 输入给另一名 NPC；每一轮模型都能通过 `should_end_dialogue=true` 主动结束。Godot 不按第 3 / 5 轮截断；默认第 6 轮起的收尾只是 Prompt 参考。结束标记所在回复先写入历史 / 事件，再结束且不产生下一次调用。正式路径的邀请和每轮对话都使用真实 provider、分别降速；失败不写未完成轮次，也不用 Mock 伪装成功。实际行动中断、计划重评估、资源、HP 或事件写入仍由 Godot 结算。

### 每日计划

`POST /npc/plan_day`

输入 Schema：`DailyPlanRequest`
输出 Schema：`DailyPlanResponse`

输入必须包含目标 NPC 当前 `current_order`。输出必须是 24 条 `PlanItem`，每条包含小时、行动类型、行动 id、可选地点/目标和理由。计划是建议，不代表资源、移动或行动已经结算；模型可以结合人设、记忆和现场条件调整、推迟或拒绝指令。

当前状态：`/npc/plan_day` 使用 `DailyPlanRequest` / `DailyPlanResponse`，真实 provider 读取独立 Prompt，并校验 0-23 点覆盖、精确行动候选和至少 6 个工作阶段。成功响应附加 provider / model / fallback 元数据和 `model_normalizations`（未规范化时为空数组）。Schema 已通过后，非 idle 项只有在 action/target/location 唯一命中显式 kind 候选时才可规范化冗余 kind；idle 仅按固定空目标 / 空地点合同规范化，其他 Schema / 业务错误仍失败。正式开局和新一天通过 `request_npc_daily_plan_async(...)` 同时发起 8 个真实请求，单人最多 3 次真实请求。Godot 按每项声明的 `hour` 重排 0-23，拒绝重复 / 缺失小时；Godot 只接受 `source=llm_plan_day`；任一失败时整批保持暂停与 `planning_day`，不生成 `rule_plan_fallback` 或 `mock_plan_day`。

### 对话 / 行动失败通用计划修改判别

`POST /npc/plan_revision_judgement`

输入 Schema：`PlanRevisionJudgementRequest`
输出 Schema：`PlanRevisionJudgementResponse`

`trigger_kind=dialogue` 时，请求携带 `dialogue_kind`、本轮完整 `dialogue_history`、结束原因、会话元数据和对话对应的原计划；`trigger_kind=action_failure` 时，改为携带程序权威的 `failed_plan_item`、失败类型 / 摘要 / 必要上下文、原计划和工作阶段下限。T0053 起两种分支都携带动态驿站场景、完整 NPC 人设 / 状态 / 长短期记忆 / 地点 / 指令、行动候选及实时建筑 / 资源条件。模型只返回需要修改的精确 `revision_hours` 与简短理由；空数组严格表示 0 个阶段，无需调用计划修订。后端与 Godot 拒绝重复、越界或早于当前小时的选择。NPC-NPC 会话为双方分别构造请求，不能共用一方结论。旧 `/npc/dialogue_plan_revision_judgement` 和旧 Schema 名仅作为兼容别名。

### 计划修订

`POST /npc/revise_plan`

输入 Schema：`PlanRevisionRequest`
输出 Schema：`PlanRevisionResponse`

用于通用判别选中阶段，以及守备官发布新指令、战斗结束 / 复苏、主动交涉超时和 GM 手动重估等直接触发后的计划修订。请求必须包含最新 `current_order`、`revision_scope=selected_hours` 与非空、排序且去重的 `revision_hours`。对话路径（包括其中已提交的攻击轮）与行动失败路径都沿用既有完整修订上下文，但小时集合来自上一层判别；其他直接触发的范围由各自程序入口给出。

当前状态：`/npc/revise_plan` 使用 `PlanRevisionRequest` / `PlanRevisionResponse`，读取紧凑计划修订 Prompt，并额外校验 NPC id、响应小时集合与请求完全一致、精确行动候选、工作阶段保持规则，以及包含当前小时请求时的 `immediate_action`；成功响应附加 provider / model / fallback 元数据和 `model_normalizations`（未规范化时为空数组）。Godot 通过 `request_npc_plan_revision_async(...)` 调用，不阻塞主线程；正式路径只接受真实 provider，成功时以 `llm_plan_revision` 合并所选小时，未选小时原样保留，并仅在当前行为模式允许时执行当前小时。失败最多重试 3 次真实请求且不应用 Mock / 规则修订。请求日 / 小时 / 计划版本或对话 epoch 过期时丢弃响应，单后继队列只保留最新失败上下文。

### 战斗判定

`POST /npc/battle_judgement`

输入 Schema：`BattleJudgementRequest`
输出 Schema：`BattleJudgementResponse`

只覆盖战时 HP 首次低于 30% 的自身心理判定，以及必要的逃离检查；不再用于“战斗触发时全员判定”。请求必须包含目标 NPC 当前 `current_order` 和 `battlefield_context`；输出只表达继续战斗、逃离、斗志激昂或继续避战等意向，不能把守备官指令直接当成强制结果。伤害、buff、逃离移动和状态变更由 Godot 执行。

Godot 负责按目标 NPC 状态提供 `allowed_decisions`：已入伍且有主武器、实际处于 `combat` 模式的 NPC 可继续战斗、逃离或斗志激昂；避战 / 非战斗人员只能逃离或继续避战。T1404 后，真实 provider 路径读取 `data/prompts/battle_judgement_system_prompt.txt`，后端在 `BattleJudgementResponse` Schema 校验后额外校验 `decision` 属于 `allowed_decisions`，并校验 `should_start_escape` 只在 `decision == "escape_station"` 时为 true；越界结果返回 `model_output_invalid` 并写入 usage。若仍有非法结果进入 Godot，Godot 必须规则降级，不让非战斗人员获得斗志激昂或直接参战。真实 DeepSeek 已完成战时公开对话与 `/npc/battle_judgement` smoke 验证，`fallback_used=false`。

### 首次睡眠总结

`POST /npc/daily_reflection`

输入 Schema：`DailyReflectionRequest`
输出 Schema：`DailyReflectionResponse`

输出第一人称日记和 `KnowledgeGraphPatch` 列表；T0046 起不再输出与日记并列的当天长期摘要。

当前状态：T1004/T1005/T1405/T0024 已在 Flask 后端接通 `/npc/daily_reflection`，使用 `DailyReflectionRequest` 校验输入、调用 `ModelAdapter.generate("daily_reflection", ...)`，再用 `DailyReflectionResponse` 校验输出并附加 provider 元数据。接口历史名仍是 daily_reflection，当前玩法语义是首次睡眠总结。Godot 侧 `DailyReflectionSystem` 监听 `sleep_started`、`sleep_ended` 和 `logical_time_tick`，NPC 每天首次睡眠满 1 游戏小时后通过异步接口调用；最多允许 8 路同时在飞，并暴露实际峰值快照。真实成功标记 `llm_daily_reflection`，显式 Mock provider 标记 `mock_daily_reflection`；缺少来源证明或 fallback 结果不会伪装成真实成功。完成后把日记 / 知识写入长期记忆并清空该 NPC 当天短期索引。模板降级必须标明来源并保留模型失败日志。该调用会申请 TimeSystem 慢速，且请求发起到应用完成期间 NPC 处于不可打断的深度睡眠锁。

### 其他 AI 辅助

后续接口可复用：

- `KnowledgeGraphUpdateRequest` / `KnowledgeGraphUpdateResponse`
- `ProactiveIntentionRequest` / `ProactiveIntentionResponse`
- `PlayerStrategyClassificationRequest` / `PlayerStrategyClassificationResponse`

## 数据流

```text
玩家点击 NPC
  ↓
Godot 收集 NPC 当前状态、地点信息、短期记忆摘要
  ↓
Godot 通过 TimeSystem 注册 LLM 等待慢速请求
  ↓
发送到后端
  ↓
后端拼装 Prompt 并调用模型
  ↓
模型返回 JSON
  ↓
后端校验 JSON
  ↓
Godot 释放 TimeSystem 慢速请求
  ↓
Godot 执行合法结果
  ↓
权威结果写入 MemorySystem 事件系统，并按可见性通过对应地点信息节点即时广播给当前在场 NPC；广场公开信息使用 `location_id == "plaza"` 的本地公开事件
```

## 失败降级

如果 LLM 请求失败，Godot 必须释放该请求的 TimeSystem 慢速登记并返回可处理错误。允许降级的其他业务可使用明确标源的规则 / 模板结果；正式每日计划不降级，它会保持全局暂停，等待真实计划问题被解决。

生产 / 演示路径不得用 mock 内容掩盖真实 provider 失败。Mock 只允许在显式开发模式中使用。允许降级的其他系统必须使用明确 source 并保留原始失败；正式每日计划不得进入该降级路径。

## 时间倍率边界

Godot 不使用后端结果直接决定时间倍率。后端只返回业务 JSON；是否申请慢速、慢速 request id、超时释放和恢复玩家速度，由 Godot 的 LLMBridge / DialogSystem / 计划系统负责。

T1104A 起，TimeSystem 还支持“有效倍率上限”请求。CombatSystem 只在活动敌人存在时注册 `combat_enemy_presence` 上限，把有效倍率最高压到 `x1`；所有敌人消失后释放。该上限与 LLM 慢速取更慢者：玩家选择 `x4` 且有敌人时实际为 `x1`，战斗中若有 LLM 调用则实际可降到 `1/60`，调用结束后回到敌人在场的 `x1`。后端和 LLM 仍不直接决定时间倍率。

T1104B 起，CombatSystem 不把 `logical_time_tick` 传入的原始游戏秒直接当作攻击冷却秒。战斗攻击冷却和敌人位移表现使用 `game_delta_seconds / 60` 得到的战斗动作秒，因此默认 `x1` 下现实 1 秒推进游戏内 1 分钟，也只推进约 1 秒战斗动作。工作、日常状态、治疗、建筑修复 / 升级等经营结算仍直接使用 TimeSystem 游戏秒。

## Godot LLMBridge 当前实现

T0604 已在 Godot 侧新增 `res://scripts/systems/LLMBridge.gd`，挂载于 `Main/Systems/LLMBridge`；T0604A 已将传输层替换为 Godot 原生 `HTTPClient` 状态机。

T0042 将对话顶层 `npc_setting` 的字段选择提取到 `res://scripts/core/NPCPromptProfile.gd`。LLMBridge 与 NPCPanel 人物背景弹窗都调用这个无状态构造器，因此 Prompt 人设与玩家可见档案共用数据和字段合同；UI 只是只读消费者，不依赖后端在线状态，也不产生额外 API 成本。

当前能力：

- `check_health()` 通过原生 HTTP 请求 `GET /health`，并通过 `backend_status_changed(status_text, ok)` 供 HUD 显示后端状态。
- `request_llm_usage()` / `debug_request_llm_usage()` 通过原生 HTTP 请求 `GET /debug/llm_usage`，供 GM 面板查看 provider、token、费用统计、预算上限 / 剩余额度、fallback 次数和失败原因；该查询不申请 TimeSystem 慢速。
- `debug_get_llm_runtime_snapshot()` 只读返回后端状态、当前 pending LLM 慢速请求数、pending request id、NPC 活动请求、异步请求数量、TimeSystem 有效倍率、最近倍率变化原因和逐请求慢速注册 / 释放审计，供 GM 面板验证等待中的 LLM 请求与时间减速状态。
- `build_npc_dialogue_payload(...)` 按 T0603/T1201/T0029/T0030 Schema 收集目标 NPC 设定、守备官/NPC 说话者上下文、对话阶段、应征标记、当前轮次、NPC-NPC 软轮次阈值 / 指导、NPC 状态、短期记忆、长期记忆、地点快照、`interaction_context` 和必要时的 `battlefield_context`。
- `request_npc_dialogue(...)` / `request_npc_dialogue_async(...)` 通过原生 HTTP 请求 `POST /npc/dialogue`，返回后端业务 JSON 或错误字典；开发模式可返回 mock JSON，生产 / 演示模式不得把真实失败替换成 mock 回复。
- `build_plan_revision_judgement_payload(...)` / `request_plan_revision_judgement_async(...)` 通过 `POST /npc/plan_revision_judgement`，按 `trigger_kind` 把本轮完整对话或程序权威失败事实、判别基线计划和共享人物 / 记忆 / 指令 / 现实条件交给范围判别模型，并只接收精确 `revision_hours`；旧 dialogue 命名方法保留为兼容包装。
- `build_npc_daily_plan_payload(...)` 按 T1003 Schema 收集目标 NPC 共享上下文、当前 `current_order`、短期记忆、长期记忆、地点、广场、资源、建筑状态、行动白名单和计划规则。
- `request_npc_daily_plan(...)` 与 `request_npc_daily_plan_async(...)` 请求 `POST /npc/plan_day`；异步路径用于正式开局批量计划。
- `build_npc_plan_revision_payload(...)` / `request_npc_plan_revision_async(...)` 通过 `POST /npc/revise_plan` 处理判别选中小时或其他直接触发范围的计划修订，payload 使用 `revision_scope=selected_hours` 与精确 `revision_hours`。
- `request_npc_battle_judgement_async(...)` 与 `request_npc_daily_reflection_async(...)` 分别处理低血量心理判定和首次睡眠总结。
- 六类正式业务在 `requires_time_slowdown=true` 时注册 `TimeSystem.request_time_slowdown(...)`，成功、失败、取消或超时后调用 `release_time_slowdown(...)`；正式开局批量计划由 `GameStartupSystem` 全局暂停时间并显式关闭重复慢速。
- `build_npc_dialogue_payload(...)` 与共享 NPC 上下文构造会注入目标 NPC 最新 `current_order`；`get_last_npc_context_injection()` 暴露最近注入快照用于 GM / 自动化验证。

当前传输层不再依赖外部命令。health / usage 等只读短请求使用 2 秒响应超时；正式业务只使用 2 秒后端连接保护，连接成功并发出请求后不设置 Godot 响应总时长。后端关闭、供应商连接 / 空闲错误、非法 JSON 或 `ok=false` 都返回可处理错误字典。常规异步请求取消会立即释放慢速、清除 NPC LLM 活动，后台返回后只发出已取消结果。正式开局批量计划期间 TimeSystem 已暂停，因此计划请求不重复申请慢速。

T0703A/T1002/T1003/T0022 已将 `current_order` 接入共享 NPC 请求上下文、对话顶层 payload、每日计划请求和计划修订请求，由 `LLMBridge` 统一收集。Godot 保持当前指令、事件事实、行动白名单与结算的权威；后端只负责把该上下文传给模型并校验模型输出。计划修订仍使用独立异步修订链路；正式每日计划只应用真实 `llm_plan_day`，真实 provider 失败时记录错误并保持暂停，不落到 Mock 或规则计划。

验证脚本 `tools/verify_llm_bridge.gd` 覆盖后端关闭、health、对话、usage 和慢速释放；`tools/verify_llm_time_slowdown_audit.gd` 覆盖六类正式业务的同步 / 异步慢速注册、释放和只读接口不降速；`verify_dialogue_plan_revision_judgement.py` / `_real.py` 覆盖通用判别层 Schema、Prompt、对话 / 行动失败分支与真实 provider；`verify_action_failure_plan_revision_judgement.gd` 覆盖 Godot 失败分支的空判别、精确选中小时、完整第二层上下文和派发屏障。既有对话与计划专项继续覆盖空集合恢复、旧回包丢弃及非工作模式延迟执行。

T0604 遇到的坑：

- Godot 原生 HTTP 的首次尝试在 headless 脚本验证中被信号等待和节点生命周期卡住；后续需要显式请求状态机、完成回调和超时。
- 同步等待异步 HTTP 结果会导致验证脚本挂起；所有成功、失败和超时路径都必须释放 TimeSystem 慢速请求。
- Windows 命令行直接传中文 JSON、引号和换行容易破坏请求体；T0604 才临时使用 `curl.exe` + 临时 JSON 文件。
- 本机环境变量残留非 mock provider 且缺少 Key 时，后端应返回 provider unavailable 或可处理错误；验证脚本如需 mock，必须显式使用 mock 或隔离环境，不能把该路径当成真实 provider 验收。
- 这些问题属于 Godot 传输层和开发验证环境问题，不是 NPC、记忆、Prompt 或前后端职责边界的问题。

## API Key

禁止把 API Key 写入仓库。  
真实供应商 API Key 默认只存在于服务器后端环境变量或后端 `.env`，并确保 `.gitignore` 忽略 `.env`。Godot 客户端不得保存、提交、导出或要求玩家在 Demo 阶段必须提供供应商 API Key。

使用真实 API Key 完成测试后，不要提交 `.env`、日志中的 Key、请求头或供应商密钥片段。生产 / 演示环境应关闭自动 mock fallback；无 Key 时应暴露配置错误，而不是返回 mock 内容。
