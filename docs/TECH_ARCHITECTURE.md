# TECH_ARCHITECTURE.md

## T0123 美术表现与权威模拟的规划边界

美术升级不建立第二套建筑、NPC、战斗或地点权威。Quaternius Mesh、Skeleton、AnimationTree、碰撞、导航、屋顶透明、粒子、贴花、布娃娃和 UI Theme 均属于表现 / 空间执行层；资源、HP、伤害、建筑等级、位置容量、行动进度、事件与记忆仍由现有系统决定。

T0127 的真实室内迁移需要把物理位置与权威地点重新对齐，但不会让碰撞或动画成为事实源。目标数据流为：

```text
ActionSystem 请求并预留位置
  -> NPCSystem / NavigationAgent3D 执行到门口和室内 Marker 的路径
  -> 穿过门口时提交 current_location / people_present
  -> 抵达具体 Marker 后把 reserved_by 提交为 occupied_by
  -> ActionSystem 才开始权威行动计时与结算
```

离开、升级清退、行动失败、昏迷、战斗打断和逃离使用反向 / 中止事务，不能提前把仍在室内的 NPC 写成广场人员，也不能留下幽灵预留。该合同目前只登记为后续实现目标；T0127 前运行时仍沿用入口占位流程。

## T0116 对话执行前异步边界

DailyPlanSystem 是计划对话预检编排器：执行签名通过后先发复核，不先中断 ActionSystem。LLMBridge 只负责构造上下文和 HTTP 生命周期；Backend 只校验模型决策；continue / modify 的最终 ActionSystem / NPCSystem 调用及 cancel 的计划重估都由 DailyPlanSystem 完成。请求上下文保存 day/hour/plan_version/item_identity，所有回调先比对再落地。

制造失败数据沿 `CraftingSystem result -> ActionSystem work_failed payload -> MemorySystem -> LLM compact projection` 单向传播。ActionSystem 只对失败码做稳定中文映射，不再用缺失 message 的默认值猜原因；资源和阶段结算权威边界不变。

## T0115 陈旧失败隔离与主动交涉交接

```text
ActionSystem 权威失败
  -> plan_revision_judgement 选择小时
  -> revise_plan 返回选中小时
     -> Godot 对当前小时比较 action_id + target + dialogue_goal
        ├─ 原样重复失败项：不落地，留在同一 stage-two 有界重试
        └─ 合法新项：合并计划并派发
           -> seek_guard_officer
              -> NPCSystem 原子写 proactive_talk_started + 空失败上下文
              -> 单次 npc_state_changed

玩家点击主动交涉
  -> DialogSystem 创建并激活同一草稿
     ├─ 规划中 / 状态竞态拒绝：清草稿，保留 proactive
     └─ 激活成功：NPCSystem 才消费 proactive，进入 NPC 发起对话
```

失败去重不再依赖“新行动恰好没有触发状态通知”。所有本次审计覆盖的新行动入口在通知观察者前提交完整状态；建筑移动、世界目标移动和主动交涉都用非失败 start result 覆盖旧终态。目标比较兼容 provider Schema 的顶层专用字段与内部计划的嵌套 `target`，并把 `dialogue_goal` 纳入主动交涉 / 对话类 one-shot 身份，避免不同诉求被误判为同一活动。

DialogSystem 的草稿激活返回值必须同时满足 `ok=true / activated=true / dialogue_id` 与刚创建草稿一致，不能把“草稿已被同步监听器撤销”当作成功。UI 不拥有回滚职责；NPCSystem 只根据最终业务结果消费主动交涉。没有新增 endpoint、Schema、Prompt、EventBus 信号或第二套计划权威。

## T0114 虔诚—陨石权威数据流

```text
ActionSystem active 祈祷有效秒
  -> PietySystem 共享累计 / 100 封顶
     -> EventBus.piety_changed
        -> HUD 圆环 / 满值发亮

HUD 合法地面点
  -> PietySystem 满值与边界校验、消费、效果时序
     -> CombatSystem.apply_enemy_area_damage
        -> 仅活动敌人：防御、死亡、清敌 / 战斗结束
     -> MemorySystem：施放 / 落地公开事件
```

PietySystem 是新增的单一权威边界：配置加载、共享值、选点范围、陨石 / 燃烧状态和消费都在这里；ActionSystem 只提交已经发生的 active 时长，HUD 只显示和提交目标。CombatSystem 的范围入口刻意只接触 `_active_enemies`，从结构上隔离 NPC、建筑和我方器械伤害，因此“无友伤”不依赖阵营标签或 UI 过滤。表现节点挂在 `WorldRoot/Station/Effects`，不保存权威状态。

## T0113 对话权威实况投影

```text
DialogSystem 打断前活动 ─┐
NPCSystem 当前装备槽 ────┼─> LLMBridge dialogue truth builder
ActionSystem 训练运行态 ─┘       ├─ activity_truth
                                ├─ equipment_truth
                                └─ training_truth
                                      -> NPCDialogueRequest 成套校验
                                      -> ModelAdapter 保留装备空槽 null
                                      -> dialogue provider
```

该投影是只读冗余事实层，不拥有行动、装备或训练结算权。`activity_truth` 优先读取对话打断快照，避免对话期间的 `talk_to_guard_officer` 覆盖原活动；训练资格按“装备 → 在岗教官 → ActionSystem 环境”顺序给出单一首要 blocker。旧测试客户端可三组全部省略，正式 Godot 请求不会省略；只携带一部分会在 Pydantic 边界失败。

## T0106 全量紧凑记忆数据流

```text
MemorySystem 完整权威事件 / 见闻
  -> LLMBridge 按当前短期索引顺序读取全部记录
     -> summary + 决策相关 details
        ├─ 普通五类：experienced_events / witnessed_events
        └─ 熟睡总结：day_events + memory_kind
  -> Pydantic EventSummary 丢弃旧 payload
  -> ModelAdapter 外层字段白名单再次清洗
     └─ daily_reflection 删除重复 npc.short_term_memory
  -> provider
```

MemorySystem 继续负责完整 payload、事件 ID、传播和快照水位，不因为 token 优化改变权威数据。压缩发生在只读投影层：大结构优先由确定性 summary 表达，24 项计划额外压为连续 `plan_segments`；原因、资源缺口、投入产出、指令变化和其他摘要未充分表达的标量 / 小结构进入 `details`。Model Adapter 的第二层清洗确保旧客户端或测试夹具携带的 `payload / event_id / extra` 不能越过供应商边界。

当前七类正式调用（含执行前复核）均使用同一投影器，不存在独立的“无记忆轻量判别”路径。对话保留等价顶层 `short_memory` 合同；其余调用使用共享 `NPCContext.short_term_memory`。反思在 Godot 内仍可携带 NPC 上下文便于 Schema / 本地调试，但供应商实际请求只保留反思水位对应的全量 `day_events`，避免证据重复与 token 翻倍。

## T0105B 弥撒跨小时完成屏障

```text
hour_started 派发当前小时计划
  -> ActionSystem 判断 NPC 是否仍在主持 / 参加弥撒
     ├─ 否：沿用原计划切换规则
     └─ 是，且新计划不同：保持 active、工位和进度，登记 deferred

ActionSystem 弥撒自然完成
  -> 参礼者恢复独祷
  -> 已到时长的祈祷正常完成
  -> DailyPlanSystem 在同一 deferred 批次按既有依赖顺序
     执行此时的当前小时计划
```

参礼祈祷达到自身时长时只把进度停在上限，不在弥撒中完成或释放祈祷席。弥撒结束后的状态信号只负责唤醒计划屏障；延迟标记不写入事件、记忆或模型上下文。保护只由 `hour_started` 使用，对话、主动改派、建筑失效、昏迷等既有权威中断仍走原路径；普通行动的整点切换与完成策略不变。

## T0105A 弥撒正常结束与中断分流

```text
lead_mass 结束
  ├─ 自身 duration 到期
  │    -> ActionSystem 正常完成
  └─ 对话 / 改派 / 建筑失效等外部原因
       -> ActionSystem 中断

正常完成 -> prayer_resumed_alone.trigger=mass_completed
外部中断 -> prayer_resumed_alone.trigger=mass_leader_stopped
```

正常完成入口复用主持者的 `prayer_completed`、祭坛释放和参礼者恢复独祷逻辑，不由 DailyPlanSystem 伪造事件。T0105B 起，普通计划小时边界不再构造结束原因，而是等待弥撒自身完成；MemorySystem 仍只根据结构化 trigger 选择摘要，LLM 不参与。

## T0101 守备官知识边界数据流

```text
data/npc_initial_long_memory.json
  guard_officer.{role, arrival_at_station, past_before_station, pre_game_relationship}
  -> NPCSystem 初始化 knowledge_graph
     ├─ NPCPanel【知识】中文只读显示
     └─ LLMBridge long_memory / npc.long_term_memory
         -> dialogue / plan_day / plan_revision_judgement
         -> revise_plan / battle_judgement / daily_reflection
```

本任务不增加人物卡、endpoint、`call_type`、响应字段或权威状态。到站时间和开局前总体相处是初始长期认知；“过去未知”是明确知识边界，不是允许模型填空。对话专门限制守备官自我追问；熟睡反思把后来明确自述保存为单独、带“自称”语义的 NPC 主观关系，不能覆盖全局客观过去。

## T0100 宗教信仰人设投影

```text
data/npc_profiles.json.religion="天主教"
  -> NPCPromptProfile.build_setting(...)
     ├─ NPCPanel【背景】
     └─ dialogue.npc_setting
  -> LLMBridge._build_npc_context(...).identity
     -> plan_day / plan_revision_judgement / revise_plan
     -> battle_judgement / daily_reflection
  -> backend NPCIdentity.religion
```

`religion` 是精简、稳定的人物背景字段，不进入知识图谱，也不复制到 `station_context.resident_roster`；它不能替代个性、职业、记忆或实时程序事实。该变更不新增 endpoint、`call_type`、运行时状态或权威结算，正常调用频率不变。

## T0099 对话面板本地交互边界

```text
NPCPanel 记录
  -> MemorySystem.get_all_events()
  -> 只筛守备官—当前 NPC 已完成会话
  -> day / time / append sequence 排序
  -> 仅按 day 输出【第X天】

DialogPanel 可见输入
  ├─ Tab + 应征 toggle 可用
  │    -> 改变 button_pressed
  │    -> 既有 toggled handler
  │    -> DialogSystem.set_recruitment_request_pending(...)
  └─ 每次打开后的第一次攻击
       -> ConfirmationDialog
       ├─ 取消：无系统调用，保护保持
       └─ 确认：既有 DialogSystem.attack_target_npc(...)
            -> 成功后仅本次打开免重复确认
```

日期与攻击确认状态都是 UI 投影 / 防误触状态，不进入 MemorySystem、DialogSystem 会话 Schema 或存档。攻击伤害、惩戒事件、NPC 回复和计划判别仍由既有系统执行；应征快捷键不能绕过 toggle 的 visible / disabled 状态，也不修改 `session_had_recruitment_request` 的既有锁语义。

## T0098 祈祷内部模式状态机

```text
pray_at_chapel pending
  -> 真正抵达小教堂 + 占用祈祷席
  -> 读取当前有效 lead_mass
       ├─ 无主持者 -> prayer_mode=personal_prayer
       └─ 有主持者 -> prayer_mode=mass_attendance

active pray_at_chapel
  ├─ lead_mass 开始 -> 原地切到 mass_attendance
  ├─ 当前主持正常结束 / 异常退出
  │    ├─ 有替换主持者 -> 仅重绑定 provider_npc_id
  │    └─ 无替换主持者 -> 原地切回 personal_prayer
  └─ 祈祷自身时长结束 -> 正常完成 pray_at_chapel
```

模式转换只修改 active action 的 `prayer_mode / provider_npc_id`，不更换 action id，不释放 `chapel_prayer_seat`，不重置 `elapsed_seconds`，也不调用行动失败或计划重估。ActionSystem 写入 `prayer_joined_mass / prayer_resumed_alone`；MemorySystem 生成确定性摘要并按小教堂 `local_public` 广播。DailyPlanSystem 与 LLMBridge 不再包含教堂服务依赖、互斥或失败归一化分支。

## T0097 计划模型决策编译

```text
provider plan item
  -> hour + action_id
  -> 仅按所选行为读取必要选择
       ├─ visit_location                    -> location_id
       ├─ talk_to_npc / assist_heal         -> target_npc_id
       ├─ assist_repair / assist_upgrade    -> building_id
       └─ 固定 / 无目标行为                 -> 无额外选择
  -> 丢弃 action_kind / priority / target_id / 无关 selector / 任意 extra
  -> 用完整 allowed_actions 精确命中候选
  -> 编译内部 PlanItem
       {hour, action_id, action_kind, location_id, target_id,
        priority=50, reason, dialogue_goal}
  -> Flask 完整响应 Schema + 业务校验
  -> Godot 既有计划消费与 ActionSystem 权威执行
```

编译器位于 Model Adapter 的 provider 输出边界。它不会修改 Godot 请求、`PlanItem`、DailyPlanSystem 或 ActionSystem，也不会从无关字段猜目标。固定行为的地点与 kind 来自唯一合法候选，所以模型给 `pray_at_chapel` 多附一个 `target_id=chapel` 或错误地点不会破坏修订；需要目标的行为若专用选择为空或未命中白名单，则先编译为可校验的无效内部组合，再由 HTTP 业务层以 `location_id / target_npc_id / building_id` 对应错误拒绝。

Mock 先投影成同一最小模型决策，再经过同一编译器，避免开发路径绕过边界。修订的 `immediate_action` 继续从编译后的当前小时项确定性生成。模型原始多余字段仍保留在本地审计日志的 `provider_output_parsed` 证据中，但不会进入 Godot 响应或 `model_normalizations`；后者不再承担 action kind / 冗余地点修复。

## T0095/T0096 提交与反思水位数据流

```text
pending(action + target + options + movement_target)
  -> 暂停：NPC 移动冻结，ActionSystem 提交与 logical tick 返回
  -> 恢复：继续原 movement_target
  -> 抵达：NPCSystem 清 movement_target，写实际地点与 idle
  -> ActionSystem 统一提交闸门
       ├─ 地点 / NPC / 服务目标失效：一次结构化失败
       └─ 条件仍成立：申请工位并进入 active
```

移动停止清理与行动失败分开：对话目标 / 服务提供者失效时先使用 `emit_state_changed=false` 收束移动，随后由唯一结构化失败发状态变化，避免 DailyPlanSystem 抢到中间结果。ActionSystem 的逻辑 tick 也检查暂停，即使外部调试误发 tick 也不推进 active。

```text
21:00 summary_window 累计睡眠达标
  -> MemorySystem 原子短期快照（正文 + event_ids / witness_ids）
  -> reflection_period = 上次成功 end .. 本次请求快照时刻
  -> /npc/daily_reflection(summary_window, reflection_period, day_events)
  -> 长期记忆写入
  -> 只从当前短期索引移除本次快照 ID
  -> 保存本次 end，作为下次 start
```

窗口只管资格和归属，水位只管内容，触发时刻只管真实请求时间。请求在飞期间的新 ID 不属于旧快照，因此不会被旧回调清除；漏掉窗口不会推进水位。

## T0094 对话实况、历史投影与夜间总结数据流

```text
守备官第一条有效消息
  -> DialogSystem 在中断前读取 ActionSystem runtime snapshot + 当前计划
  -> interrupted_activity_context（目标私有、仅本会话）
  -> LLMBridge -> NPCDialogueRequest
  -> 对话 Prompt 按“被打断的活动 / 计划不变时暂定恢复”回答
  X 不进入 MemorySystem / EventRecord / 传播 / 长期记忆
```

对话完成仍只写既有 `dialogue_turn`。NPCPanel 的“记录”从 MemorySystem 全局 append-only 事件档案筛选目标 NPC 与守备官会话，按事件 `day / time` 排序；T0099 起只按日期分组，不再计算或显示历史波次标签。短期事件 / 见闻索引被熟睡总结清空后，已完成会话仍可查看；UI 不建立独立数据库。

```text
sleep_in_dormitory 的有效逻辑秒
  -> DailyReflectionSystem 解析 21:00 锚定窗口
  -> 同一 night_<anchor_day>_2100 跨多次睡眠累计
     ├─ 未满 3600 秒：保留 accumulated / remaining
     ├─ 达标但并发或旧请求占用：保持 eligible 可重试
     └─ 达标发起既有 /npc/daily_reflection
          -> 长期记忆成功应用 + 短期索引轮转
          -> completed_windows_by_npc 登记该窗口
```

T0095 起总结窗口及记录范围会进入后端 `DailyReflectionRequest`，帮助模型严格限制正文内容；日记按窗口锚点归档，实际触发日 / 时间独立保存。失败不消耗窗口也不推进内容水位，21:00 边界开启下一窗口。现有深度睡眠锁、最多 8 路并发、TimeSystem 慢速和明确模板降级来源不变。

固定地点行动开始前由 ActionSystem 同时校验 `current_location`、`movement_target` 和 `moving_to_*`；教堂再在 `_start_pray(...)` 做最终到达守卫。T0098 后弥撒开始只扫描 active 祈祷者并原地切换内部模式；pending 祈祷保持原移动与计划，到达后根据当时是否存在有效主持者选择模式。守备官已谈妥的当前参礼承诺仍可让对话计划链重排当前小时，但正式行为统一为 `pray_at_chapel`。

## T0092 双层 LLM 合同

```text
Godot 完整业务请求
  -> Flask 完整请求 Schema
  -> ModelAdapter provider projection
       ├─ 删除 meta / null / 同值副本 / 分支外字段
       └─ 保留人物、记忆、现场事实、白名单
  -> provider 最小 JSON 决定
  -> ModelAdapter deterministic hydration / T0097 plan compiler
       ├─ 固定响应 envelope 与派生布尔值
       └─ 按行为选择字段命中候选，补齐 action_kind / priority / location / internal target
  -> Flask 完整响应 Schema + 业务校验
  -> Godot 既有消费链
```

投影和补齐只在 `ModelAdapter` 的 provider 边界执行，不能代替 Flask / Godot 的业务校验。T0097 起计划项会先丢弃全部模型固定回声和无关字段，再只用行为对应的地点 / NPC / 建筑选择命中候选；真正的行动、必要目标或修订小时错误仍会被拒绝。Mock 也经过同一 hydration，以保证本地和真实 provider 的 Godot 响应形状一致。

## T0091 目标驱动对话计划数据流

```text
LLMBridge allowed_actions
  -> talk_to_npc {action_id, action_kind, target_id, target_kind, target_name}
  -> backend 发给 provider 时再次移除 location_id
  -> T0097 模型用 target_npc_id 选择 NPC
     └─ 其他地点 / 通用目标字段在编译边界直接丢弃
  -> DailyPlanSystem 只保存 target_npc_id
  -> ActionSystem 执行时查询目标实时地点并追踪
```

内部仍使用 action + target + location 的精确候选合同。T0097 只是把 provider 选择改为行为专用字段并由程序编译，不让模型决定寻路，也不放宽对话目标资格、自聊、内部 `action_kind=chat` 或 `dialogue_goal` 校验。

## T0087 对话响应按类型分派

```text
NPCDialogueRequest.dialogue_kind
  ├─ player_npc          -> PlayerNPCDialogueResponse
  ├─ npc_npc             -> NPCNPCDialogueResponse
  └─ escape_intervention -> EscapeInterventionDialogueResponse
                               -> 分支 Schema extra=forbid
                               -> 分支业务校验
                               -> Godot 对应唯一消费字段
```

请求合同保持统一，便于 LLMBridge 继续复用人物、记忆、地点和行动候选构造；响应合同在 HTTP 层按请求类型选择，模型不能再把邀请、应征、战时和逃离字段混装进一个对象。应征权威只消费 `recruitment_result`，NPC-NPC 生命周期只消费 `invitation_result / should_end_dialogue`，逃离权威只消费 `escape_intervention_result=stay|leave`。通用 `intent` 已删除；分支外字段和旧失效意图均在进入 Godot 前以 `model_output_invalid` 拒绝。

供应商偶发把 `emotion / suggested_event_type / debug_reason` 返回为 `null` 时，HTTP 层只对这些非权威元数据替换 Schema 默认值，并把路径、原值、目标值和来源写入 `model_normalizations`。这不会改变 `recruitment_result / invitation_result / should_end_dialogue / wartime_reaction / escape_intervention_result`，也不会触发 Mock fallback。

## T0085 计划工作量软约束与目标失效数据流

```text
BuildingSystem 完成 upgrade / repair
  -> 释放协助者并清空 last_action_failure_context
  -> 下个计划小时仍命中旧 assist_upgrade
     -> DailyPlanSystem 查询实时作业状态
        -> 生成 no_active_upgrade / target_resolved_or_inactive
        -> /npc/plan_revision_judgement 选择受影响小时
        -> /npc/revise_plan 返回新合法行动
           -> 只校验精确小时、白名单、目标/地点、即时行动等硬合同
           -> 合并并立即/延迟可靠派发
```

`minimum_work_phase_count` 等字段为兼容 Schema 与 Prompt 规划上下文继续保留，但 backend 和 Godot 不再据此拒绝响应。`assist_upgrade` 的工作计数与 `location_id=plaza` 在 LLMBridge、DailyPlanSystem 和 backend 之间一致，避免历史计划计数失真或把室外协助重新投影进封闭建筑。

## T0084 固定床位分配数据流

```text
building_defs.json.workstations[].assigned_npc_id
  -> BuildingSystem 规范化位置配置
     -> claim_workstation(dormitory, npc, dormitory_bed)
        ├─ NPC 有固定床：只检查并申请自己的位置
        └─ NPC 无固定床：跳过全部专属位置，只申请未分配床
           -> ActionSystem 保存 workstation_id
              -> 完成 / 中断 / 封闭时只释放 occupied_by

BuildingSystem.get_building(dormitory)
  -> BuildingPanel 只读显示实时“空闲 / XX占用中”，不暴露固定归属
```

归属是建筑配置事实，`occupied_by` 是运行时使用事实，两者不能混用。ActionSystem 不维护第二份 NPC—床位表，UI 不参与分配；LLM 仍只选择“睡觉”行动，不接收床位编号选择权。

## T0083 应征结果的前端投影

后端玩家对话 `PlayerNPCDialogueResponse.recruitment_result` 由 T0087 保留并成为应征唯一结构化结果。Godot 业务层完成既有上下文校验和权威入伍应用后，把有效 `accept / reject` 作为可选元数据写入对应 NPC history turn；UI 按元数据渲染结果，MemorySystem 只读取 turn 的真实文本生成摘要。该分层避免通过会话级 `last_recruitment_result` 给旧回复补错结果，也避免把 UI 文案伪装成模型发言。

## T0081 持续生活消耗与成长数据流

```text
TimeSystem.logical_time_tick(effective_game_seconds)
  -> NPCNeedsSystem
       -> NPCSystem 状态 / behavior_mode
       -> ActionSystem active / external_active 快照
       -> BuildingSystem 修复 / 升级剩余时间
       -> activity_needs.json 唯一速率档位
       -> NPCSystem.update_npc_state(satiety, fatigue)
       -> ActionSystem.advance_timed_action_experience(...)
            -> NPCSystem.increase_npc_skill(...)
            -> MemorySystem.skill_improved
```

`data/action_defs.json` 的每条配置行为只保存 `needs_profile` 引用，不再携带饱食 / 疲劳总量或每小时重复字段；`data/activity_needs.json` 是速率、边界、行为模式映射和动态默认档位的唯一数值源。NPCNeedsSystem 在 tick 开头结算，因此有限 active 行动可用 `duration - elapsed` 截断；建筑协助用 `remaining / speed_multiplier` 截断；治疗协助用复苏前理论秒数截断。剩余时间按 idle 结算，切换档位时保留未满 1 点的小数，钳制到边界时丢弃继续越界方向的余量。

ActionSystem 仍独占行动生命周期、食物恢复、工位 / 资源和成长事件；NPCNeedsSystem 不产出资源、完成行动、恢复 HP 或决定经验技能。BuildingSystem / NPCSystem 只提供有效时间事实，不复制经验计时器。工作 / 训练的既有完成 / 有效时长成长保持原入口，三类 assist 使用 `timed_experience` 配置补齐工程 / 医术成长；非工作行动没有该配置。

## T0080 建筑门口失败与升级协助数据流

```text
BuildingSystem.upgrade_building()
  -> building_state_changed(condition=upgrading)
     ├─ ActionSystem active 依赖行动
     │    -> 立即释放位置 / 周期 -> 清退广场
     │    -> *_failed_building_upgrading(interrupted_phase=active)
     └─ ActionSystem pending 依赖行动
          -> 保留 pending 与移动目标，不产生失败
          -> NPCSystem 抵达建筑入口后查询 BuildingSystem availability
             -> 不可进入：收束到广场并发 npc_building_entry_failed
                -> ActionSystem 清除 pending
                -> *_failed_building_upgrading(
                     interrupted_phase=pending,
                     arrival_check_failed=true
                   )
                -> DailyPlanSystem T0050 判别 -> 按需精确修订

BuildingSystem 当前升级作业
  -> LLMBridge allowed_actions.assist_upgrade
     -> plaza / requires_building_entry=false / counts_as_work_phase=true
     -> DailyPlanSystem + backend 工作阶段统计（Prompt 建议）
     -> LLM 只能选择候选；ActionSystem / BuildingSystem 权威执行与结算
```

`npc_building_entry_failed` 只表达 NPC 已经到达入口且程序拒绝进入的观察事实，不替代 BuildingSystem 可用性判断，也不直接调用 LLM。NPCSystem 先写最终室外地点，再发信号；ActionSystem 拥有 pending 行动和结构化失败，DailyPlanSystem 仍从唯一最终失败启动既有两层链。没有 pending 行动所有权的普通访客只被收束到广场，不伪造计划失败。

LLMBridge 的 `current_building_states.is_upgrading / is_repairing` 必须调用 BuildingSystem 实时查询，不能读取 `get_building()` 中不存在的便利布尔字段。`assist_upgrade.target_id` 仍是被协助建筑，`location_id / execution_location` 才是实际执行地点；Godot 与后端 Prompt 统计使用同一行动语义，但工作量不作为接受门槛。

## T0078 NPC 主动交涉完成数据流

```text
当前计划 seek_guard_officer
  -> NPCSystem 生成问号并由 NPC 发起 player_npc 会话
     -> DialogPanel：取消 disabled + 专用 tooltip
     -> DialogSystem：取消接口权威拒绝
        ├─ 完成
        └─ 挂起满 2 小时 -> 按完成收口
           -> DailyPlanSystem 核对结束时当前计划仍为 seek_guard_officer
              -> judgement.required_revision_hours=[当前小时]
                 -> 后端保留模型选择的额外小时，并权威并入任何遗漏 required 小时
                    -> selected-hours revise_plan（普通动态 allowed_actions）
                       -> T0076 当前小时立即 / deferred 派发
```

`required_revision_hours` 是程序已经确认的范围事实，不是模型建议。后端只归并小时并记录 `model_normalizations`，不替模型选择行动、地点或目标；正式修订、Godot 合并和 ActionSystem 执行校验仍保持原权威边界。守备官发起会话与结束时已不再执行 `seek_guard_officer` 的会话不获得该强制范围。

## T0076 对话延续与当前小时派发数据流

```text
DailyPlanSystem 派发 talk_to_npc（保存来源日/小时/版本/计划项）
  -> ActionSystem pending：接近 / 等待目标计划
     -> 普通 hour_started
        -> ActionSystem 保留 pending 与预约
        -> DailyPlanSystem 为发起者登记 carryover barrier
        -> 跳过新小时计划，不中断移动
     -> DialogSystem invitation / active（继承计划来源）
        -> 普通 hour_started：邀请保留发起者；正式会话保留双方
        -> 对话结束：双方进入同一 resolution group
           ├─ 发起者 judgement.required_revision_hours=[当前小时]
           │    -> selected-hours revise_plan -> normal allowed_actions
           └─ 受邀者普通独立 judgement -> 按需 revise_plan
        -> 全组终态
           -> current-hour deferred marker
           -> 依赖排序派发结束时当前计划

任意 revise_plan 修改当前小时
  -> 合并并写 current-hour dispatch marker
     ├─ 当前可执行：立即正常派发，成功后消费 marker
     ├─ 对话 / 行为模式阻塞：保留 marker，状态解除后派发
     └─ 派发失败：保留 marker，并由权威失败链产生唯一后继修订
```

后端 `PlanRevisionJudgementRequest.required_revision_hours` 是范围下限，不是行动选择。Pydantic 校验排序 / 时效，endpoint 校验响应包含全部 required 小时，ModelAdapter Prompt / 紧凑重试 / Mock 共用同一合同；`PlanRevisionResponse` 的精确选时、即时行动一致性与候选校验不变。

## T0075 配置化完成策略数据流

```text
data/action_defs.json.completion_policy
  -> ActionSystem.initialize() 校验 / 建立行为目录
     -> DailyPlanSystem 派发当前计划项
        ├─ active 与新小时 action + 必要 target 相同
        │    -> 采用既有 runtime，保留进度
        ├─ 新小时计划不同
        │    -> interrupt_npc_action -> 正常派发新项
        ├─ repeat_while_planned 成功 completed
        │    -> deferred -> 再读当前计划 -> 清除本阶段签名
        │       -> 正常派发 / 重新校验下一周期
        └─ once_per_plan_hour 已消费
             -> 日期 + 小时 + 逻辑计划项去重（不含 plan_version）
             -> 不重复派发
```

普通 `(day, hour, plan_version, action, target, dialogue_goal)` 签名仍负责同一计划版本的幂等派发；生产成功回调只有在配置策略与当前逻辑计划项都匹配时才可受控清除签名。每小时单次记录独立于计划版本，避免同小时修订后重复吃饭 / 饮酒。续开通过 deferred 调用发生，使 ActionSystem 先完成旧周期结算和 `work_completed` 记录，再产生下一周期 `work_started`；重新派发失败继续进入原有结构化失败与计划修改判别，没有新建资源或制造结算路径。

## T0073 指令发布到计划变化的数据流

```text
OrderPanel 发布自由文本
  -> NPCSystem.publish_npc_order(...)
     -> current_order + private order_assigned
     -> npc_plan_reevaluation_requested(reason=order_changed)
        -> DailyPlanSystem 当前小时 selected_hours 修订
           -> LLMBridge /npc/revise_plan（包含最新 current_order）
              -> 后端 Schema / Prompt / 白名单校验
                 -> 合并回权威 24 小时计划
```

UI 叙事文字只表达成员会“尽量遵循”，不改变上述权威边界。指令发布不会直接调用 ActionSystem；只有真实 provider 返回、通过精确小时集合与行动白名单校验的修订才会改变 DailyPlanSystem 计划。T0073 的确定性专项锁定 payload 注入和合并边界，真实专项确认 `order_changed` 可把当前计划从空闲改为前往指定地点。

## T0071 NPC-NPC 对话私有上下文边界

```text
回复者 NPC 自身
  -> npc_setting / npc_state / short_memory / long_memory
     / location_context / current_order / target_npc

说话者 NPC
  -> speaker_name + speaker_text
     + speaker_context{speaker_id,name,kind,appearance,health_status,state={}}
  -X-> speaker_npc / private NPCContext
```

`LLMBridge.build_npc_dialogue_payload(...)` 是正式对话 payload 的唯一构造点，不再调用 `_build_npc_context(...)` 构造说话者。后端 `NPCDialogueRequest.speaker_npc` 只接受 `null`，`SpeakerContext.state` 必须为空；因此旧客户端、手工请求或未来重构不能把说话者的短期 / 长期记忆、`current_order`、地点上下文、技能 / 属性或个人资源重新混入回复者请求。模型只能从回复者自己的信息空间、对方已说出的文本和可观察外表 / 健康作答。

其余五类正式请求继续各自携带唯一目标 NPCContext，没有第二名 NPCContext。`talk_to_npc` 候选只提供目标 id / 名称，不再投影目标当前地点、行动或入伍状态；ActionSystem 在计划真正执行时读取目标权威地点并追踪移动。其他 `allowed_actions` 仍承担程序合法性与路由约束，但 Prompt 明确其元数据不自动转化为目标 NPC 见闻。

## T0070 全员名册与仓库容量数据流

```text
NPCSystem 全部登记实体
  -> LLMBridge._build_station_context(...)
     -> resident_roster[{npc_id,name,identity,recruited,in_station}]
        -> 六类请求 / Pydantic StationResidentContext / Prompt

data/resource_defs.json.warehouse_capacity
  + BuildingSystem.warehouse.level
     -> ResourceSystem 容量 / 剩余量 / 原子入库
        ├─ ActionSystem 工作产出预检
        ├─ MerchantSystem 购买预检
        ├─ BuildingPanel 仓库上限行
        └─ HUD 资源悬停提示
```

名册标签和容量均由 Godot 权威状态投影，后端与 LLM 只读。没有 `warehouse_capacity` 的资源视为无限，而不是容量 0；配置为受限的六项资源在批量入库前整体校验，失败时不得先扣输入。UI 不缓存或计算容量，始终调用 ResourceSystem。仓库受击资源损失尚未接入这条数据流。

## T0077 每日人民币硬预算与 provider 尝试账本

```text
ModelAdapter.generate(...)
  -> 进程内累计预算检查
  -> LLMCostLedger.reserve(audit_id:attempt)
     -> 重放 Asia/Shanghai 当日 provider_usage
     -> 已用 + 全部在途预留 + 本次 ¥1.77 <= ¥20
  -> provider HTTP
     -> 读取 prompt_cache_hit/miss + completion usage
     -> LLMCostLedger.settle(...) 释放预留并追加 JSONL
     -> audit provider_response_received 同步保存 billing
  -> /debug/llm_usage
     -> session（当前 ModelAdapter 进程）
     -> daily（从持久化账本重放）
     -> GMPanel 异步顶栏
```

DeepSeek V4 Flash 默认人民币价为缓存命中输入 ¥0.02/M、缓存未命中输入 ¥1/M、输出 ¥2/M。单次预留 ¥1.77 覆盖官方 1M 上下文与 384K 最大输出的缓存未命中理论上界；预留只占用在途额度，拿到真实 usage 后释放未用部分。每个 HTTP 尝试独立结算，所以非法 JSON / 截断后的紧凑重试不会漏算。价格、预留、上限、时区和账本路径均由后端环境配置；配置价格缺失、账本不可读写或预留会越过上限时失败关闭并返回 `budget_exceeded`，不进入 Mock。

JSONL 是跨后端重启的当日费用事实源；`ModelAdapter._usage_records` 继续表达业务调用最终结果，两者不得相加。当前 Flask 部署复用单个 ModelAdapter，进程内锁覆盖 Godot 的并发请求；未来若改为多 worker，必须把预留和追加迁移到支持跨进程原子事务的集中存储后才可继续宣称全局硬预算。

## T0069 LLM 调用持久化审计

`ModelAdapter.generate(...)` 为每次调用创建唯一 `audit_id`，`LLMCallAuditLogger` 以 append-only JSONL 写入同一调用的生命周期事件。正式 provider 在 `_send_chat_completion(...)` 生成请求体后、加入 Authorization 请求头前记录完整 `messages / temperature / thinking / response_format`；流式 SSE 仍由现有传输层聚合，审计保存聚合后的供应商响应和原始模型 `content`，不保存逐个 SSE 网络分块。

```text
call_started(input_payload)
  -> provider_request_sent(attempt, full body, no headers)
     -> provider_response_received(http_status, aggregated response)
        -> provider_output_parsed | provider_output_rejected
  -> call_completed(content, usage, error/fallback)
     -> business_validation_failed (optional, same audit_id)
```

`record_model_output_invalid(...)` 继续原地修改内存 usage，避免调用 / token 双计，同时通过 usage timestamp 找回原 `audit_id` 并追加不可变的业务校验失败事件。日志写盘按解析后的绝对路径使用进程内共享锁，每个事件一次性追加一行；目录创建或写入失败只更新 `audit_log.last_error / last_error_timestamp`，不改变模型业务结果。多进程服务器仍依赖操作系统 append 语义，部署阶段若启用多个 worker，应为各 worker 配置独立文件或接入集中日志收集器。

日志正文保存前递归处理敏感 key、JSON 字符串中的凭据字段、Bearer / `sk-...` 格式和当前配置 API Key。供应商请求头从不传入日志器。`get_runtime_config_snapshot()` 只公开启用状态、JSONL 版本、显示路径、正文开关与最近错误；HTTP / GM 不提供日志下载，避免把人物私密上下文扩散到客户端。

## T0067 LLM 判定复验与原子逃离边界

```text
Godot 权威 NPC / 战场状态
  -> LLMBridge NPCContext
     -> Pydantic NPCStateContext（保留五个模式 / 心理 / 逃离字段）
        -> real provider
           -> Schema + dialogue / battle business validation
              -> Godot apply-time stale validation
                 -> CombatSystem 权威结果

CombatSystem.start_npc_escape(...)
  -> NPCSystem.set_npc_behavior_mode_and_move_to_world_position(...)
     ├─ preflight：NPC、世界节点、移动能力、目标
     ├─ interrupt：行动、对话、LLM、旧移动
     └─ 单次提交：behavior_mode + state_changes + 新移动
  -> 成功后才写 escape_started / active_escapes / escape_intent
```

这条链把“模型意向”“业务可接受”“当前仍有效”“程序已成功提交”分为四层。后端不决定 HP、战斗资格、移动或事件；Godot 也不会把迟到或业务越界的结构化 JSON 当作权威事实。低血量 pending 除 request id 外绑定 `wave_id + started_event_id`，防止同一波编号的新战斗误收旧回复。

DialogSystem 在完成会话并应用暂存战时反应时设置结束中标记。逃离模式切换再次尝试强制结束同一会话，只会得到幂等的 `dialogue_end_in_progress`，不会重复提交对话事件或递归调用。复苏续逃失败不再留下“活动逃离但没有移动”的半状态。

ModelAdapter 在供应商完成生成时先取得真实 token 与 finish 元数据；若随后 HTTP 业务层判定输出无效，`record_model_output_invalid(...)` 会优先用上游 usage timestamp，并结合非空 request id、call type 和 NPC，找到精确的成功 usage 后原地替换为 `SchemaValidationError` 失败记录。这样一次上游请求只消耗一次调用 / token / 预算，重复报告幂等，同时保留真实失败原因；只有找不到对应上游记录时才追加独立失败记录。

## T0063 个人酒转移、行动与 LLM 投影

```text
ResourceSystem.wine
  -> NPCSystem.give_wine_to_npc(...)
     -> npc.states.wine
        -> ActionSystem.get_action_eligibility(...)
        -> spend_npc_owned_resources({wine: 1})
           -> MemorySystem.wine_consumed
              -> 六类后续 NPC 上下文

data/action_defs.json: drink_wine
  -> ActionSystem
     ├─ DailyPlan / dialogue allowed_actions（本人有酒时）
     └─ LLMBridge.station_context.work_mode_actions + description（完整背景目录）
```

NPCSystem 是个人金钱 / 酒持有量和扣减的唯一权威，ResourceSystem 继续只保存驿站库存。LLMBridge 把目标个人 `money / wine` 投影进 NPC 状态，把完整行动说明投影进共享背景目录；后端只校验计划白名单、kind 和可安排数量，不执行扣减。事件上下文承载非数值心理影响，不新增情绪状态或记忆删除路径。本任务不新增 endpoint、call_type、Autoload 或模型调用。

## T0061 人设投影与知识展示边界

```text
data/npc_profiles.json（无 signature_lines；含精简 religion 与宽松 speech_style）
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

`signature_lines` 已从档案、共享构造器、Pydantic `NPCIdentity` 和六类正式 Prompt 移除；不保留兼容镜像。T0100 后身份另含精简 `religion`，人物声音仍只由宽松 `speech_style`、其余根本人设、长期记忆与当前事实共同形成。三篇初始日记的数据结构和投影路径不变：前两篇内容分别承担宏观身世 / 来站原因 / 到站时间与接手工作 / 相遇群像，八人按艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜互相补全；“近日”仍是原有微观片段。

T0061 当时守备官种子图谱只保留一条 `role` 职责关系；T0101 已在同一主体新增三年前到站、来站前经历未知和开局前尽责和睦三条关系。建筑知识主要改写中文 `relation_label / value_label` 的叙事表达；独立机械审校同时把仓库旧的“容量 / 受击丢货 / 减少掠夺”技术值收为当前运行态真实存在的“集中登记 / 正门失守后的受袭次序”，其余技术 `value` 不变。`confidence / day / time` 与替换式更新结构完整保留。NPCPanel 隐藏可信度与更新时间是纯展示过滤，不改变 NPCSystem、后端、存档或 GM 可观察数据。本任务不新增 endpoint、`call_type`、调用频率、场景节点或权威结算。

## T0060 内容重写与日记投影边界

```text
8 字段运行态日记
  -> LLMBridge._build_existing_diary_entries(...)（唯一投影点）
     -> day=0：“往昔·…：正文”
     -> 新熟睡总结：“接到守备命令的第N天 HH:MM:SS：正文”
     -> 无 record_label 的旧 day>0 记录：“第N天 HH:MM:SS：正文”
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

## T0057 建筑升级导致行动失败的数据流（pending 时序由 T0080 修正）

```text
BuildingSystem.upgrade_building()
  -> building_state_changed(condition=upgrading)
  -> ActionSystem 识别真正指向该建筑的 pending / active 行动
     -> pending：保留前往建筑的移动，到入口被拒后才清理待执行动作
     -> active：释放位置 / 周期并将建筑内 NPC 收束到广场
     -> 写 <action_id>_failed_building_upgrading + 权威失败上下文
  -> DailyPlanSystem 规范为 target_unavailable
  -> T0050 action_failure 判别
  -> revision_hours 非空时进入精确阶段修订
```

升级封闭只把真正依赖目标建筑的 pending / active 行动记为失败；active 在状态变化时立即失败，pending 必须等 NPCSystem 在入口重查可进入性后失败。单纯停留者会被清退；没有行动所有权的普通访客到门口被拒时也不会伪造行动失败。ActionSystem 必须在 NPCSystem 完成门口位置收束后一次性写最终 `failed` 状态，避免同步 `npc_state_changed` 用无上下文中间结果抢占失败去重。失败上下文包含 action / building、`condition=upgrading`、`failure_reason=building_upgrading`、pending / active 阶段和中文摘要；LLM 只判断受影响小时及合法替代行动，不决定升级、封闭、移动、位置或失败事实。

## T0055 周期规则的数据边界

新增常识只修改 `data/station_context.json.station_rules` 和六份 Prompt 解释，不新增 Schema 字段或 Godot 结算代码。LLMBridge 仍原样把配置规则注入六类请求；ActionSystem、CraftingSystem、HorseSystem、BuildingSystem、ResourceSystem 等继续各自决定有效参与、周期推进、部分进度与最终结算。LLM 不获得周期计时或资源写权限。

## T0054 驿站常识数据流

```text
data/station_context.json ── 精简简介 / 世界内规则 ┐
NPCSystem ── 全体登记成员及 recruited / in_station     │
BuildingSystem ── 已加载全部建筑                      ├─> LLMBridge._build_station_context(...)
ActionSystem ── 可计划行为定义 + 特殊逃离意向          │
                                                       └─> 六类请求顶层 station_context
                                                            └─> Pydantic StationSceneContext
```

静态叙事规则只在 `data/station_context.json` 维护；人员、建筑和行为类型不复制成 Prompt 专用数据。T0058 后 `StationSceneContext` 要求 `setting_summary / resident_roster / building_roster / work_mode_actions / basic_resource_reserves / station_rules` 全部存在且列表非空。Godot 在每次构建 payload 时读取运行态：离站者立即从人员目录消失；建筑目录保持已配置身份完整，即使某座建筑当前受损 / 摧毁；行为目录包含工作模式可计划类型而不展开每个动态 NPC 目标；基础资源严格只投影五项。

该目录是世界知识层，不是决策授权层。`allowed_actions / allowed_decisions`、`current_building_states / current_resource_states`、NPC state、战场上下文和各系统校验继续负责当前事实与合法性。后端 Schema 和 Prompt 都不得依据背景规则替代权威结算。GM 只读入口调用 LLMBridge 的 debug 快照，不建立第二套组装或结算逻辑。

## T0053/T0076 计划对话延续、失效与共享人物上下文数据流

```text
DailyPlanSystem dispatch talk_to_npc
  -> ActionSystem pending(plan day/hour/version + assigned_plan_item + target)
  -> target llm_activity(kind=plan): keep reservations and wait
  -> logical tick / target-plan retry / hour_started pre-dispatch validation
       ├─ same-day old hour -> keep wait/invite/session + rebuild dispatch marker
       ├─ same-hour item still talks to same target -> continue wait/invite
       └─ same-hour replacement / cross-day / authoritative invalidation
            -> release + stop approach
            -> last_action_result=talk_to_npc_failed_plan_superseded
            -> context(old item + current item + old/current time/version)
            -> DailyPlanSystem T0050 judgement -> optional selected-hours revision
```

ActionSystem 只对带 `plan_action_source=daily_plan` 的 pending 对话应用日计划延续 / 替代规则，避免 GM / 测试直接交谈冒充跨小时日计划。普通同日整点时，DailyPlanSystem 为 pending、邀请中和正式会话重建 carryover marker，暂缓当前小时计划；对话自然结束并完成双方判别 / 必要修订后再派发当前项。真正失效时，移动停止可能同步发出状态信号，因此先用非失败 cleanup reason 停止，再一次性写入最终结构化失败；否则第一条无上下文失败会被 DailyPlanSystem 去重并吞掉真正上下文。DailyPlanSystem 收到失败时优先使用 `failure_context.failed_plan_item`，不能用当前项替代旧失败项。

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
  -> 回复仅 append NPC turn，并暂存 recruitment / wartime / escape branch result

完成：cancel pending reply -> MemorySystem 单次提交整场 dialogue_turn
     -> 应用暂存的程序权威结果 -> T0049/T0050 计划修改判别
取消：cancel pending reply -> 不提交事件 / 不应用暂存结果 -> 恢复合法原行动
挂起：ui_visible=false + NPC 会话锁 + 7200 逻辑秒
     -> 恢复窗口，或超时走取消（含攻击则走完成）
```

客户端取消只使对应 request id / dialogue id 失效；后端即使已经返回，迟到结果也不得再改变历史、事件或 NPC 状态。攻击伤害先由 NPCSystem 权威落地，与会话暂存事务分离。玩家会话事件采用“完成时整场一次提交”，NPC-NPC 则继续采用“每轮成功即提交”，两者不能混用。

## T0046 请求场景、反思 Schema 与公告牌数据流

`backend/schemas/npc_ai.py` 使用 `StationAwareNPCRequest` 为所有携带 NPC 人设的请求提供一份顶层必填 `station_context`；`NPCContext` 本身不嵌套该字段。T0046 先建立动态在站人员基础，T0054 再扩充完整建筑、工作模式行为与世界内规则。`DailyReflectionResponse` 仅含 `diary_entry` 与 `knowledge_graph_updates`，知识 patch 可同时保存技术 `subject / relation / value` 和中文 `subject_label / relation_label / value_label`；不再有 `memory_summary`。

公告牌 UI 只管理草稿。发布后由 `MemorySystem` 校验并权威更新广场 `current_notice / reference_schedule / schedule_advisory_note`。T0065 起，`plaza_notice_changed / plaza_schedule_changed` 是公告牌专用全站广播：发生实际变化的页面各生成一条事件，由 `_broadcast_public_event(...)` 按事件类型选择全部在站 NPC，再通过既有接收资格过滤昏迷、睡觉与离站者；其他 `local_public` 事件仍按地点在场范围转发。广场 `location_entry_snapshot` 在写入见闻前剔除公告牌三项，权威广场快照本身仍保留它们供 UI / GM / 只读系统查询。初始内容来自 `data/notice_board_defaults.json` 并预写初始在站 NPC 见闻；逃离完成时 NPCSystem 调用 MemorySystem 将该 NPC 从全部地点人员节点移除，接收资格也再次过滤离站状态。UI 不直接写见闻或广场事实。

## T0043A 服务提供者—承载者运行时闭环

`data/action_defs.json` 用 `required_active_action_id`、`blocked_by_active_action_id`、`interrupts_action_ids` 与 `complete_with_required_action` 声明诊所 / 训练等依赖和互斥。Godot `ActionSystem` 是唯一生命周期权威：验证服务者的行动、地点、建筑可用性及实际位置占用；协调 pending；开始 / 释放位置；在服务者停止时同步失败依赖者。T0098 后教堂不再使用这些依赖字段：弥撒只改变同一祈祷行动的内部模式。`DailyPlanSystem` 只负责同批派发顺序和接收真实结构化失败，`LLMBridge` 只把仍有效的约束投影为候选上下文。

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

位置数量、名称、类型、固定归属和占用只由 `BuildingSystem` 的建筑状态决定。NPC 只选择行动与建筑，`ActionSystem` 调用 `claim_workstation(...)` 取得合法位置：普通位置使用同类型第一个空位，宿舍床位按 T0084 使用 NPC 自己的固定床或未分配床；无合法位置、升级封闭或建筑摧毁均返回结构化失败。诊所和训练场分别聚合全部在岗医生 / 教官的数量与技能，不建立 UI 或 LLM 决定的一对一配对。

升级的成本、时长、Max HP、位置增量与活动效率增量都来自 `upgrade.level_effects`；固定位置类型拒绝扩容。施工开始后建筑不可进入：室内 active 依赖行动立即以建筑升级失败、释放位置并进入 T0050；路上 pending 继续到入口，只有实际被拒后才以同一权威原因失败。完成后一次应用升级效果。建筑受损倍率与升级加成由 `BuildingSystem` 计算，`ActionSystem` 只消费倍率；UI 可显示精确值，NPC 信息空间只传播分档，避免逐 HP 修复刷屏。LLM 只看行动资格、即时可用性和失败原因，不决定占位、效率、资源、HP 或升级事实。

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
- `backend/schemas/common.py` 和 `backend/schemas/npc_ai.py` 提供后端 AI 请求/响应 Pydantic Schema；统一 `NPCDialogueRequest` 覆盖玩家-NPC、逃离挽留与真实 NPC-NPC 对话，T0087 后按 `dialogue_kind` 分派到三个响应 Schema。NPC-NPC 继续用 `dialogue_phase / invitation_result` 区分邀请与正式会话，并使用 `max_rounds=0` 与一致的软轮次字段；后端和 Godot 校验回复者身份、`response_kind` 及当前分支字段，但不替业务系统结算权威状态。
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
- 工程器械库存消耗、围墙 / 主厅通用槽占用、器械 HP / 防御 / 穿透、弩床 / 箭塔自动攻击和部署事件
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
进入广场见闻快照包含当前在场 NPC、这些 NPC 的生命状态 / 行动状态和建筑外部状态，不含公告牌通告 / 参考日程 / 备注；进入可进入建筑快照包含建筑内 NPC 的生命状态 / 行动状态；室内到室内切换在事件层经由广场
  ↓
LLM 调用前从事件库 + 见闻库生成摘要
```

后端和 LLM 可以根据事件库、见闻库和知识图谱生成解释、对话、计划、日记和知识图谱当前键值更新，但不能直接新增会改变权威数值的事实。对话全文作为对话事件 `payload` 的一部分保存，不单独建立谈话库。

T1506/T1507/T0046 遵守同一边界：`NoticeBoardPanel` 只把通告或参考日程草稿交给 `MemorySystem.set_plaza_notice(...)` / `set_plaza_reference_schedule(...)`，公告牌权威状态只在广场节点；`MerchantPanel` 只把交易意图交给 `MerchantSystem`，由后者校验配置、到访时段、数量和库存，再调用 `ResourceSystem` 结算。成功到达、离开与交易写入结构化广场公开事件，失败交易不修改资源也不伪造成功事件。两条路径均不调用 LLM。

T0107 覆盖 T1508 的围墙专属入口：`DefenseSlotPresenter` 把围墙 / 主厅槽位从 3D 世界投影为圆形 `+` / 等级标记，并只提交 `device_id + slot_id`；BuildingPanel 保留当前建筑的兼容入口。`DefenseDeviceSystem` 校验建筑等级 / 可用性、槽位和库存并原子部署，保存器械 HP / 防御 / 穿透 / 攻速与主厅 `2.0x` 射程；弩床与箭塔通过 CombatSystem 窄接口伤害敌人，敌人也通过 DefenseDeviceSystem 窄接口伤害器械。T0110 后围墙槽所需等级为 `1 / 2 / 4 / 6`，主厅为 `1 / 3 / 5 / 6`；BuildingPanel 通过 `BuildingSystem.get_upgrade_level_effect(...)` 展示下一等级真实成本、工期、Max HP 和扩槽收益。`DefenseDevicePresenter` / `DefenseDeviceView` 仅消费快照创建已部署低模，不能反向决定库存、HP、槽位、射程或攻击事实。该路径不调用 LLM，也不为器械受击 / 摧毁新增信息事件。

T0701/T0051 起，`DialogSystem` 是 Godot 侧会话权威入口：它维护参与者、历史、公开性、轮次和守备官会话生命周期。守备官消息发送后立即写入内存历史；“完成对话”取消仍在等待的回复、把完整历史作为一条 `dialogue_turn` 写入 `MemorySystem`，应用会话中仍暂存的战时 / 挽留意向，并进入 T0049/T0050 判别。“取消对话”不入库、不广播、不应用仍暂存的意向也不判别；“挂起对话”保持 NPC 的 `talk_to_guard_officer` 运行态和原会话。攻击由 `NPCSystem.apply_damage_to_npc(...)` 立即权威扣 HP 并锁定取消，随后完成或超时都会保留攻击历史。T0082 起，“提出应征”是会话内持续开关，第一次带标记的消息发送后 `session_had_recruitment_request` 永久锁定本场取消；该开关随后关闭只影响后续请求，挂起超时仍按完成。完成的守备官会话 summary 从完整 `dialogue_text` 逐句生成，但事件、广播和判别仍各只有一次。`local_public` 完成会话只向同地点非参与者广播一次。判别返回空 `revision_hours` 时只在动作确被本次对话打断、仍匹配当前计划且行为模式允许时恢复原小时行动；非空时才把精确小时交给 DailyPlanSystem。T0702 起，后端只返回应征意向；T0072 起，合法接受回复进入会话历史后立即由 `DialogSystem` 调用 `NPCSystem.set_npc_recruited(...)` 应用，拒绝仍不改变状态。T0029/T0030/T0049 后，自主 NPC-NPC 会话仍按实际完成轮次入库：邀请不计正式轮次，任一方结束标记回复先入库再停止下一次调用，邀请拒绝和正式结束分别为实际参与双方判别。T1103A/T0051 后，行为模式切换调用 `force_end_dialogue_for_npc(...)` 强制完成已有守备官会话、取消未完成回复并优先切换模式，不丢弃已经说出口的消息或攻击事实。

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

## T0107 战斗属性与塔防数据流

```text
npc_profiles / weapon_defs / armor_defs / mount_defs
  -> CombatSystem.get_npc_combat_stats(...)
  -> base / growth / equipment / condition / final
  -> max(0, defense - penetration)
  -> 20 / (20 + effective_defense) 伤害倍率
  -> NPCPanel / GM 只读展示

defense_device_defs
  -> DefenseDeviceSystem（槽位、库存、HP、自动攻击）
  -> DefenseSlotPresenter（世界槽位交互投影）
  -> DefenseDevicePresenter / View（已部署模型）
  <-> CombatSystem（双方伤害窄接口）
```

CombatSystem 是 NPC / 敌人伤害、远程距离带、敌人抬手 / 僵直和骑兵冲锋阶段的权威；配置与 UI 不直接扣 HP。T0110 后当前主武器的 `required_skill` 只进入该武器攻速乘区，不进入穿透；非当前武器熟练度不生效。骑术只进入马匹冲撞伤害，不进入骑乘攻速。EquipmentSystem 会把完整定义副本写入运行时装备槽，但 `LLMBridge` 的 Prompt 专用装备投影只保留 T0107 前已有的身份、装备类型、武器伤害 / 射程 / 间隔、盔甲值与坐骑速度等白名单字段，排除新增防御、穿透、攻速修正和所有 `charge_*` 参数，因此本任务不扩展 NPC Prompt 战斗属性。

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
输出 Schema：`PlayerNPCDialogueResponse` / `NPCNPCDialogueResponse` / `EscapeInterventionDialogueResponse`

覆盖玩家-NPC、NPC-NPC 和逃离挽留对话。T0603 当前对话输入必须能表达：

- 目标 NPC：`npc_id`、`npc_name`、`npc_setting`；T0100 后 `npc_setting` 与共享 `NPCIdentity` 显式包含精简 `religion`，语言字段仍只有宽松 `speech_style`，不再携带 `signature_lines`。
- 说话者：`speaker_name`、`speaker_text` 和 `speaker_context`；玩家发起时说话者名称固定为“守备官”，NPC 发起时上下文应包含发起者健康/受伤状态与外表特征。
- 请求状态：`dialogue_phase`（`invitation` / `conversation`）、`is_recruitment_request`、`current_round`、`max_rounds`、`soft_round_threshold`、`soft_round_guidance`；NPC-NPC 邀请不计正式轮次，正式会话用 `max_rounds=0` 表示无硬上限。
- 目标状态：`npc_state`，包含属性、熟练度、健康/受伤、饱食、疲劳、金钱、装备、是否已入伍等 Godot 权威状态快照。
- 对话公开性：`dialogue_state.visibility` 只能是 `private` 或 `local_public`；`local_public` 代表后续 Godot 入库时按地点事件规则广播给在场 NPC。
- 记忆与地点：`short_memory` 区分事件库与见闻库摘要，`long_memory` 包含知识图谱和日记，`location_context` 是当前地点/建筑快照。
- 当前指令：`current_order` 表示守备官对目标 NPC 当前持续提出的自然语言指令；它是参考上下文，不是 system 指令或已执行事实。
- 行动参考：`allowed_actions` 必须非空，并与每日计划复用同一动态候选构造器；对话只用它判断目标 NPC 能做 / 做不到什么，不输出或应用计划。
- 战时上下文：T1201 后，集结 / 战斗 / 避战对话额外携带 `interaction_context` 和 `battlefield_context`；非战时对话使用 `interaction_context == "work"` 和空战局上下文。T1204A 后，逃离挽留中的玩家消息轮次使用 `dialogue_kind == "escape_intervention"`、`interaction_context == "escape_intervention"` 和 `escape_intervention_round`；逃离挽留攻击不构造该请求。

输出为按类型稳定 JSON。玩家对话返回 `replyer_id`、`reply_text`、`response_kind=reply_to_player`、`recruitment_result`（`none / accept / reject`）和 `wartime_reaction`（`none / escape / morale_boost`）。NPC-NPC 回复要求 `response_kind=reply_to_npc`，邀请阶段 `invitation_result=accept|reject`，正式会话使用 `not_applicable`，并只用 `should_end_dialogue` 控制收尾。逃离挽留要求 `response_kind=reply_to_player` 与 `escape_intervention_result=stay|leave`。三个 Schema 都禁止额外字段；不再存在通用 `intent` 或用重复枚举表达同一决定。

NPC-NPC 对话由 Godot 控制轮次推进：邀请接受后，上一轮回复者的 `reply_text` 仅在没有结束标记时作为下一次请求的 `speaker_text` 输入给另一名 NPC；每一轮模型都能通过 `should_end_dialogue=true` 主动结束。Godot 不按第 3 / 5 轮截断；默认第 6 轮起的收尾只是 Prompt 参考。结束标记所在回复先写入历史 / 事件，再结束且不产生下一次调用。正式路径的邀请和每轮对话都使用真实 provider、分别降速；失败不写未完成轮次，也不用 Mock 伪装成功。实际行动中断、计划重评估、资源、HP 或事件写入仍由 Godot 结算。

### 每日计划

`POST /npc/plan_day`

输入 Schema：`DailyPlanRequest`
输出 Schema：`DailyPlanResponse`

输入必须包含目标 NPC 当前 `current_order`。输出必须是 24 条 `PlanItem`，每条包含小时、行动类型、行动 id、可选地点/目标和理由。计划是建议，不代表资源、移动或行动已经结算；模型可以结合人设、记忆和现场条件调整、推迟或拒绝指令。

当前状态：`/npc/plan_day` 使用 `DailyPlanRequest` / `DailyPlanResponse`，真实 provider 读取独立 Prompt，并校验 0-23 点覆盖和精确行动候选。通常至少 6 个工作阶段是 Prompt 强建议，不是 backend / Godot 的接受门槛。成功响应附加 provider / model / fallback 元数据和 `model_normalizations`（未规范化时为空数组）。其他 Schema、白名单和小时错误仍失败；正式开局与新一天仍只接受真实 `source=llm_plan_day`，失败保持暂停，不使用规则 / Mock 冒充成功。

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

当前状态：`/npc/revise_plan` 使用 `PlanRevisionRequest` / `PlanRevisionResponse`，读取紧凑计划修订 Prompt，并额外校验 NPC id、响应小时集合与请求完全一致、精确行动候选，以及包含当前小时请求时的 `immediate_action`；工作阶段统计继续输入 Prompt，但不再作为业务拒绝条件。成功响应附加 provider / model / fallback 元数据和 `model_normalizations`。Godot 通过异步真实 provider 调用，成功时只合并所选小时；其他失败、重试、过期响应和单后继队列规则不变。

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

当前状态：T1004/T1005/T1405/T0024 已在 Flask 后端接通 `/npc/daily_reflection`，使用 `DailyReflectionRequest` 校验输入、调用 `ModelAdapter.generate("daily_reflection", ...)`，再用 `DailyReflectionResponse` 校验输出并附加 provider 元数据。接口历史名仍是 daily_reflection，当前玩法语义是熟睡总结。Godot 侧 `DailyReflectionSystem` 监听 `sleep_started`、`sleep_ended` 和 `logical_time_tick`；T0094 后按 21:00 锚定窗口累计多段睡眠，达到 1 游戏小时后通过异步接口调用，只有成功应用才完成该窗口。最多允许 8 路同时在飞，并暴露实际峰值、逐 NPC 窗口与完成窗口快照。真实成功标记 `llm_daily_reflection`，显式 Mock provider 标记 `mock_daily_reflection`；缺少来源证明或 fallback 结果不会伪装成真实成功。完成后把日记 / 知识写入长期记忆并轮转该 NPC 当前短期索引。模板降级必须标明来源并保留模型失败日志。该调用会申请 TimeSystem 慢速，且请求发起到应用完成期间 NPC 处于不可打断的深度睡眠锁。

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

T0604 已在 Godot 侧新增 `res://scripts/systems/LLMBridge.gd`，挂载于 `Main/Systems/LLMBridge`；T0604A 已将传输层替换为 Godot 原生 `HTTPClient` 状态机。T0109 补齐异步传输退出生命周期：取消 request id 会通过互斥保护的协作标记终止对应 `HTTPClient.poll()` 循环；`_exit_tree()` 先禁止新异步请求、取消全部传输、释放 TimeSystem 慢速与 NPC LLM 活动，再逐线程 `wait_to_finish()`，因此 worker 不会在桥接节点释放后继续投递 deferred 回调。

T0042 将对话顶层 `npc_setting` 的字段选择提取到 `res://scripts/core/NPCPromptProfile.gd`。LLMBridge 与 NPCPanel 人物背景弹窗都调用这个无状态构造器，因此 Prompt 人设与玩家可见档案共用数据和字段合同；UI 只是只读消费者，不依赖后端在线状态，也不产生额外 API 成本。

当前能力：

- `check_health()` 通过原生 HTTP 请求 `GET /health`，并通过 `backend_status_changed(status_text, ok)` 供 HUD 显示后端状态。
- `request_llm_usage()` / `debug_request_llm_usage()` 通过原生 HTTP 请求 `GET /debug/llm_usage`，供 GM 面板查看 provider、token、费用统计、预算上限 / 剩余额度、fallback 次数和失败原因；该查询不申请 TimeSystem 慢速。
- `debug_get_llm_runtime_snapshot()` 只读返回后端状态、当前 pending LLM 慢速请求数、pending request id、NPC 活动请求、异步请求数量、传输关闭标记、最近线程收束结果、TimeSystem 有效倍率、最近倍率变化原因和逐请求慢速注册 / 释放审计，供 GM 面板与自动化验证等待中的 LLM 请求、时间减速及退出诊断状态。
- `build_npc_dialogue_payload(...)` 按 T0603/T1201/T0029/T0030 Schema 收集目标 NPC 设定、守备官/NPC 说话者上下文、对话阶段、应征标记、当前轮次、NPC-NPC 软轮次阈值 / 指导、NPC 状态、短期记忆、长期记忆、地点快照、`interaction_context` 和必要时的 `battlefield_context`。
- `request_npc_dialogue(...)` / `request_npc_dialogue_async(...)` 通过原生 HTTP 请求 `POST /npc/dialogue`，返回后端业务 JSON 或错误字典；开发模式可返回 mock JSON，生产 / 演示模式不得把真实失败替换成 mock 回复。
- `build_plan_revision_judgement_payload(...)` / `request_plan_revision_judgement_async(...)` 通过 `POST /npc/plan_revision_judgement`，按 `trigger_kind` 把本轮完整对话或程序权威失败事实、判别基线计划和共享人物 / 记忆 / 指令 / 现实条件交给范围判别模型，并只接收精确 `revision_hours`；旧 dialogue 命名方法保留为兼容包装。
- `build_npc_daily_plan_payload(...)` 按 T1003 Schema 收集目标 NPC 共享上下文、当前 `current_order`、短期记忆、长期记忆、地点、广场、资源、建筑状态、行动白名单和计划规则。
- `request_npc_daily_plan(...)` 与 `request_npc_daily_plan_async(...)` 请求 `POST /npc/plan_day`；异步路径用于正式开局批量计划。
- `build_npc_plan_revision_payload(...)` / `request_npc_plan_revision_async(...)` 通过 `POST /npc/revise_plan` 处理判别选中小时或其他直接触发范围的计划修订，payload 使用 `revision_scope=selected_hours` 与精确 `revision_hours`。
- `request_npc_battle_judgement_async(...)` 与 `request_npc_daily_reflection_async(...)` 分别处理低血量心理判定和首次睡眠总结。
- 六类正式业务在 `requires_time_slowdown=true` 时注册 `TimeSystem.request_time_slowdown(...)`，成功、失败、取消或超时后调用 `release_time_slowdown(...)`；正式开局批量计划由 `GameStartupSystem` 全局暂停时间并显式关闭重复慢速。
- `build_npc_dialogue_payload(...)` 与共享 NPC 上下文构造会注入目标 NPC 最新 `current_order`；`get_last_npc_context_injection()` 暴露最近注入快照用于 GM / 自动化验证。

当前传输层不再依赖外部命令。health / usage 等只读短请求使用 2 秒响应超时；正式业务只使用 2 秒后端连接保护，连接成功并发出请求后不设置 Godot 响应总时长。后端关闭、供应商连接 / 空闲错误、非法 JSON 或 `ok=false` 都返回可处理错误字典。常规异步请求取消会立即释放慢速、清除 NPC LLM 活动并协作终止后台 HTTP 轮询，完成回调只发出已取消结果；场景退出则在节点释放前 join 全部线程而不再发信号。正式开局批量计划期间 TimeSystem 已暂停，因此计划请求不重复申请慢速。

T0703A/T1002/T1003/T0022 已将 `current_order` 接入共享 NPC 请求上下文、对话顶层 payload、每日计划请求和计划修订请求，由 `LLMBridge` 统一收集。Godot 保持当前指令、事件事实、行动白名单与结算的权威；后端只负责把该上下文传给模型并校验模型输出。计划修订仍使用独立异步修订链路；正式每日计划只应用真实 `llm_plan_day`，真实 provider 失败时记录错误并保持暂停，不落到 Mock 或规则计划。

验证脚本 `tools/verify_llm_bridge.gd` 覆盖后端关闭、health、对话、usage、慢速释放和退出生命周期静态合同；`tools/verify_llm_bridge_shutdown.gd` 使用本地悬挂 TCP 响应覆盖显式取消、退出拒绝新请求、协作终止与线程 join；`tools/verify_llm_time_slowdown_audit.gd` 覆盖六类正式业务的同步 / 异步慢速注册、释放和只读接口不降速；`verify_dialogue_plan_revision_judgement.py` / `_real.py` 覆盖通用判别层 Schema、Prompt、对话 / 行动失败分支与真实 provider；`verify_action_failure_plan_revision_judgement.gd` 覆盖 Godot 失败分支的空判别、精确选中小时、完整第二层上下文和派发屏障。既有对话与计划专项继续覆盖空集合恢复、旧回包丢弃及非工作模式延迟执行。

T0604 遇到的坑：

- Godot 原生 HTTP 的首次尝试在 headless 脚本验证中被信号等待和节点生命周期卡住；后续需要显式请求状态机、完成回调和超时。
- 同步等待异步 HTTP 结果会导致验证脚本挂起；所有成功、失败和超时路径都必须释放 TimeSystem 慢速请求。
- T0109 前取消请求只释放主线程状态，未通知工作线程退出，节点销毁时仍可能有 `HTTPClient.poll()` 持有旧 Callable；任何异步传输都必须支持协作取消，并由拥有线程的节点在 `_exit_tree()` 中 join。
- Windows 命令行直接传中文 JSON、引号和换行容易破坏请求体；T0604 才临时使用 `curl.exe` + 临时 JSON 文件。
- 本机环境变量残留非 mock provider 且缺少 Key 时，后端应返回 provider unavailable 或可处理错误；验证脚本如需 mock，必须显式使用 mock 或隔离环境，不能把该路径当成真实 provider 验收。
- 这些问题属于 Godot 传输层和开发验证环境问题，不是 NPC、记忆、Prompt 或前后端职责边界的问题。

## API Key

禁止把 API Key 写入仓库。  
真实供应商 API Key 默认只存在于服务器后端环境变量或后端 `.env`，并确保 `.gitignore` 忽略 `.env`。Godot 客户端不得保存、提交、导出或要求玩家在 Demo 阶段必须提供供应商 API Key。

使用真实 API Key 完成测试后，不要提交 `.env`、日志中的 Key、请求头或供应商密钥片段。生产 / 演示环境应关闭自动 mock fallback；无 Key 时应暴露配置错误，而不是返回 mock 内容。
