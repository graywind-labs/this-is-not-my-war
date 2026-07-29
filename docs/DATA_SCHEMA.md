# DATA_SCHEMA.md

## T0095 熟睡总结窗口与记忆水位

`DailyReflectionRequest` 新增两个必填结构：

```json
{
  "summary_window": {
    "window_key": "night_2_2100",
    "anchor_day": 2,
    "anchor_time": "21:00:00",
    "end_day": 3,
    "end_time": "21:00:00",
    "diary_label": "接到守备命令的第2天",
    "notice_basis": "守备官在公告牌向驿站众人传达“我们奉命守住此地”的守备命令"
  },
  "reflection_period": {
    "start": {"day": 1, "time": "23:10:00"},
    "end": {"day": 2, "time": "22:30:00"},
    "start_inclusive": false,
    "start_basis": "上一次成功熟睡总结的请求快照水位",
    "end_basis": "本次熟睡总结请求创建时的短期记忆快照",
    "snapshot_event_count": 4,
    "snapshot_witness_count": 2
  }
}
```

Schema 强制窗口两端均为 21:00、`end_day=anchor_day+1`、标签精确匹配锚点，并要求 `notice_basis` 包含公开命令原文。`reflection_period.end` 不得早于 start。Godot 正式日记在兼容旧 8 字段基础上新增 `record_label / summary_window_key / window_anchor_day / trigger_day / trigger_time / reflection_period`；短期快照另持有内部 `event_ids / witness_ids`，不发送给模型。

## T0094 对话打断上下文与熟睡窗口状态

`NPCDialogueRequest` 新增可空的目标私有运行时字段：

```json
{
  "interrupted_activity_context": {
    "interrupted_by_guard_officer": true,
    "private_to_target_npc": true,
    "activity_before_interruption": {
      "action_id": "sleep_in_dormitory",
      "action_name": "睡觉",
      "phase": "active",
      "location_id": "dormitory",
      "location_name": "宿舍",
      "target_id": "dormitory",
      "workstation_id": "dormitory_bed_01",
      "elapsed_seconds": 1800.0,
      "duration_seconds": 23400.0
    },
    "current_plan_activity": {
      "action_id": "sleep_in_dormitory",
      "action_name": "睡觉",
      "phase": "planned",
      "day": 2,
      "hour": 3,
      "location_id": "dormitory"
    },
    "expected_activity_after_dialogue": {
      "action_id": "sleep_in_dormitory",
      "action_name": "睡觉",
      "phase": "planned",
      "day": 2,
      "hour": 3,
      "location_id": "dormitory"
    },
    "resume_policy": "resume_interrupted_activity_if_plan_unchanged",
    "resume_expected_if_plan_unchanged": true
  }
}
```

活动子项类型为 `DialogueActivityContext`，`phase` 仅允许 `pending / active / external_active / planned`；`day / hour / elapsed_seconds / duration_seconds` 按阶段可空。外层 `DialogueInterruptionContext` 只在真正发生打断时出现，不属于 `EventRecord.payload`。

守备官对话记录不新增第二套 Schema。NPCPanel 从全局 `EventRecord` 读取既有 `dialogue_turn` 的顶层 `day / time` 和 `payload.dialogue_kind / dialogue_text / participant_npc_ids`，再按全局 `combat_started / combat_ended.payload.wave_number` 顺序还原历史波次分组。熟睡总结的客户端调度状态由 `get_async_reflection_snapshot()` 暴露：

```json
{
  "summary_window_anchor": {
    "hour": 21,
    "time": "21:00:00",
    "window_duration_seconds": 86400,
    "required_accumulated_sleep_seconds": 3600
  },
  "sleep_window_states_by_npc": {
    "veteran_deputy_01": {
      "window_key": "night_1_2100",
      "anchor_day": 1,
      "end_day": 2,
      "accumulated_sleep_seconds": 1800.0,
      "remaining_sleep_seconds": 1800.0,
      "summary_status": "accumulating"
    }
  },
  "completed_windows_by_npc": {}
}
```

窗口键既用于 Godot 侧累计、并发等待、重试和成功去重，也随 `summary_window` 进入后端合同约束模型叙事。`DailyReflectionRequest.day` 仍是实际触发日；写入日记的 `day / window_anchor_day` 使用窗口锚点，玩家可见标签固定为“接到守备命令的第N天”，实际触发日 / 时间另存于 `trigger_day / trigger_time`。

## T0088 建筑作业可读时间投影

BuildingSystem 内部继续以 `duration_seconds / remaining_seconds` 保存和结算浮点游戏秒，同时在修复 / 升级状态中增加：

```json
{
  "duration_text": "2小时0分00秒",
  "remaining_text": "1小时35分00秒"
}
```

NPC 可传播建筑外部状态只增加稳定作业字段，不广播持续变化的剩余秒数：

```json
{
  "condition": "upgrading",
  "active_job": "upgrade",
  "job_total_duration_text": "2小时0分00秒"
}
```

六类 NPC LLM 请求复用的 `current_building_states.<building>.repair_job / upgrade_job` 为 `{active, total_duration, remaining_time, progress_percent, helper_count}`；非活动作业为 `{}`。该模型投影不包含裸 `duration_seconds / remaining_seconds`，权威秒数不因此删除。

## T0087 分类型对话响应 Schema

`NPCDialogueRequest` 继续统一承载人物、说话者、记忆、地点、行动候选与 `dialogue_kind`。响应由 endpoint 根据请求类型选择：

```json
// player_npc
{"replyer_id":"cook_01","reply_text":"……","response_kind":"reply_to_player","recruitment_result":"reject","wartime_reaction":"none"}

// npc_npc
{"replyer_id":"priest_01","reply_text":"……","response_kind":"reply_to_npc","invitation_result":"not_applicable","should_end_dialogue":true}

// escape_intervention
{"replyer_id":"cook_01","reply_text":"……","response_kind":"reply_to_player","escape_intervention_result":"stay"}
```

三个响应分别是 `PlayerNPCDialogueResponse`、`NPCNPCDialogueResponse` 和 `EscapeInterventionDialogueResponse`，都设置 `extra="forbid"`。旧 `DialogueIntent` 和 `request_money / request_equipment / request_rest / request_treatment / share_witness / start_escape` 已删除；应征不再重复输出 `accept_recruitment / reject_recruitment`，NPC-NPC 不再输出 `continue_talk / end_talk`，逃离不再输出 `stay_after_intervention / leave_after_intervention`。分支外字段属于模型输出错误。

## T0076 计划修改范围必选小时

`PlanRevisionJudgementRequest` 新增：

```json
{
  "required_revision_hours": [10]
}
```

该字段默认为 `[]`，最多 24 项，必须升序、去重且不得早于 `game_time.hour`。`PlanRevisionJudgementResponse.revision_hours` 必须包含其中全部值；仍可包含其他真正受影响且未过去的小时，`needs_revision` 继续严格等于数组是否非空。自主 NPC-NPC 对话发起者，以及结束时当前计划仍为 `seek_guard_officer` 的 NPC 主动守备官会话，使用 `[结束时当前小时]`；受邀者和其他普通判别默认空数组。若模型遗漏 required 值，HTTP 层将程序权威集合并入并通过 `model_normalizations` 留痕。第二阶段 Schema 不变，仍以 `PlanRevisionRequest.revision_hours` 精确覆盖并在包含当前小时时要求 `immediate_action`。

## T0071 对话说话者公开上下文 Schema

`NPCDialogueRequest` 的回复目标仍由顶层 `npc_* / short_memory / long_memory / location_context / current_order` 定义。说话者只使用：

```json
{
  "speaker_name": "格伦",
  "speaker_text": "伊沃，菜园工位你还要用多久？",
  "speaker_context": {
    "speaker_id": "blacksmith_01",
    "speaker_name": "格伦",
    "speaker_kind": "npc",
    "appearance": "可观察外表",
    "health_status": "健康",
    "state": {}
  }
}
```

`speaker_npc` 是只兼容旧请求中 `null` 的封闭字段；任何非空对象都会被 Pydantic 拒绝。`speaker_context.state` 同样必须为空。请求不能在这两个位置携带另一名 NPC 的记忆、指令、技能、属性、个人资源或地点上下文。

`allowed_actions` 中的 `talk_to_npc` 候选只公开 `target_id / target_name`，不包含 `location_id`，`context` 为空；它不把目标的实时地点、当前行动或征召状态伪装成回复者已知事实。模型输出同样只需给出 `target_id`。动作真正执行时，由 `ActionSystem` 再按 `target_id` 查询目标实时位置并完成权威路由。

## T0070 名册与仓库容量 Schema

`backend.schemas.common.StationResidentContext` 的每个成员现在必填：

```json
{
  "npc_id": "engineer",
  "name": "欧文",
  "identity": "工程师",
  "recruited": false,
  "in_station": false
}
```

`recruited` 与 `in_station` 是相互独立的严格布尔值；离站成员仍保留在 `StationSceneContext.resident_roster`。缺少任一标签的正式请求会被 Schema 拒绝。

`data/resource_defs.json` 对受限资源新增 `warehouse_capacity={level_1,per_level_bonus}`。当前粮食、餐食、木材、石料、铁为 `{120,60}`，酒为 `{60,30}`；未配置或空配置表示不受仓库容量限制。`npc_initial_long_memory.json` 图谱结构未改变，关系总数由 222 增至 226，仓库稳定技术值更新为 `level_based_bulk_storage_and_post_breach_attack_target`。

## T0069 LLM 审计 JSONL Schema v1

`backend/logs/llm_calls.jsonl` 每行是独立 JSON 对象，公共字段为：

```json
{
  "schema_version": 1,
  "timestamp": "UTC ISO-8601",
  "audit_id": "同一次 ModelAdapter 调用的随机唯一 id",
  "event": "call_started|provider_request_sent|provider_response_received|provider_output_parsed|provider_output_rejected|provider_attempt_failed|call_completed|business_validation_failed",
  "call_type": "dialogue|plan_day|...",
  "provider": "deepseek|openai_compatible|mock",
  "model": "provider model",
  "request_id": "可空",
  "npc_id": "可空",
  "related_event_id": "可空"
}
```

事件按职责携带 `input_payload`、`provider_request_body`、`provider_response / raw_response_body`、`raw_model_content / model_output`、`attempt_count / http_status / exception_type / failure_reason`、`usage` 或 `validation_details`。这是 append-only 诊断 Schema：后续业务校验失败追加新事件，不重写历史 JSONL 行；内存 usage 仍可原地修正以避免预算双计。敏感值写入前替换为 `[REDACTED]`，请求 / 响应 headers 不属于该 Schema。

## T0067 战斗状态投影与对话业务合同

`backend.schemas.common.NPCStateContext` 在原有生命、饱食、疲劳、装备和个人资源字段外，显式声明：

```json
{
  "behavior_mode": "work|rally|combat|avoid_combat|escaped|unconscious",
  "combat_mode": "",
  "combat_strategy": {},
  "morale_boost": {},
  "escape_intent": {}
}
```

三个对象字段默认 `{}`，字符串默认空值，以兼容旧请求；它们是 Godot 权威状态的只读投影。修复前 Pydantic 会静默忽略这五项，造成请求成功但模型看不到实际战斗 / 逃离状态。

`DialogueRequest / DialogueResponse` 保持原 Schema，但 endpoint 新增业务组合校验：

- `escape_intervention` 的 kind / context 必须成对，轮次必须与当前上下文一致，intent 只能 stay / leave；留下与最终轮继续离开必须结束会话。
- `is_recruitment_request` 与 `recruitment_result / intent` 必须一致；未勾选应征时结果必须为 `none`。
- `avoid_combat`、普通工作和 NPC-NPC 对话的 `wartime_reaction` 必须为 `none`；只有 `rally / combat` 且目标已入伍并持主武器时允许 `escape / morale_boost`。
- 业务不一致按真实模型输出无效处理并写入 usage，不以 Mock 结果伪装成功。

## T0061 NPC 人设与长期记忆展示合同

- `data/npc_profiles.json`、`NPCPromptProfile.build_setting(...)`、对话 `npc_setting`、共享 `NPCIdentity` 和六类正式 Prompt 均已移除 `signature_lines`；人物表达只保留宽松 `speech_style`，不再维护代表性表达数组。
- `npc_initial_long_memory.json` 结构不变。三篇 `day=0` 日记仍使用相同 8 字段；“来站前”改为宏观身世 / 来站原因 / 到站时间，“初到驿站”改为工作与相遇群像，“近日”保持开局前微观生活。固定到站顺序为艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜。
- 每人的 `guard_officer` 只保留一条技术键为 `role` 的职责关系。建筑中文 `relation_label / value_label` 使用世界内叙事表达；T0061 当时仓库使用集中登记 / 受袭次序技术值，T0070 容量落地后更新为按等级扩容 / 受袭次序技术值，仍不包含受击丢货，`confidence / day / time` 字段全部保留。
- `NPCPanel` 的【知识】弹窗不显示 `confidence / day / time`；NPCSystem 运行态、Pydantic 输入 / 输出、保存结构及 GM 调试仍保留完整字段。本任务没有迁移知识图谱 Schema。

## T0060 文案重写不改变 Schema

T0060 当时不增加、删除或改名任何档案、日记、知识图谱、请求或响应字段；其中人物字段口径已由 T0061 取代并移除 `signature_lines`，长期记忆结构仍不变。初始日记继续使用 T0059 的完整 8 字段；运行态向 LLM 投影后仍是 `list[str]`，`day=0` 使用“往昔·…：正文”，`day>0` 使用“第N天 HH:MM:SS：正文”，并兼容旧纯字符串与缺少日期 / 时间元数据的记录。首次睡眠反思响应中的 `diary_entry` 仍只包含正文。

内容合同收紧为：8 人文风直接且声音可辨；“往昔·近日”发生在守备官收到并传达敌情之前；每人继续覆盖全部 15 座正式建筑，本职建筑认识更详细，其他建筑认识更概括但必须符合现有规则。T0061 进一步把守备官种子认识收敛为唯一职责事实，并把建筑中文内容叙事化。

## T0058 公开基础资源合同

`StationSceneContext` 新增：

```json
{
  "basic_resource_reserves": [
    {"resource_id":"grain","name":"粮食","amount":18},
    {"resource_id":"meal","name":"餐食","amount":0},
    {"resource_id":"wood","name":"木材","amount":12},
    {"resource_id":"stone","name":"石料","amount":8},
    {"resource_id":"iron","name":"铁","amount":5}
  ]
}
```

列表必须按上述顺序恰好包含五项，`amount >= 0`，其他资源 id 由 Schema 拒绝。它是每次请求的只读当前快照，不是资源变更事件，也不是 LLM 输出。T0058 后 `current_resource_states` 的 Godot 正式 payload 同样只投影这五项。

## T0054 扩充驿站场景合同

`StationSceneContext` 当前结构为：

```json
{
  "setting_summary": "...",
  "resident_roster": [{ "npc_id": "...", "name": "...", "identity": "..." }],
  "building_roster": [{ "building_id": "...", "name": "..." }],
  "work_mode_actions": [{ "action_id": "...", "name": "...", "action_kind": "work", "description": "..." }],
  "basic_resource_reserves": [{ "resource_id": "grain", "name": "粮食", "amount": 18 }],
  "station_rules": ["..."]
}
```

六个字段必填，五个数组都必须非空。人员项是当前仍在站者；建筑项是 BuildingSystem 已加载的完整建筑身份；工作行为项是 ActionSystem 可计划类型目录，`action_kind` 复用 `PlanActionKind`，`description` 保存稳定行为前提 / 上下文影响；基础资源项按上节严格白名单。目录不携带当前 HP、占用、资格、动态 target / location 或战场状态，这些事实继续由各请求的实时字段表达。`StationAwareNPCRequest` 只在请求顶层保存一份该对象，嵌套 `NPCContext`、speaker / target 不得重复。

## T0083 对话历史回合的应征结果元数据

完成守备官会话的 `dialogue_text[]` turn 保持既有 `speaker_id / speaker_name / listener_id / listener_name / text / visibility` 字段，并允许产生应征决定的 NPC 回复额外携带：

```json
{
  "recruitment_result": "accept"
}
```

该可选字段只取 `accept | reject`；普通回复和守备官发言省略。它用于把前端提示绑定到具体回复，不替代完成事件顶层的汇总 `payload.recruitment_result`，也不得把“接受 / 拒绝了守备官的应征请求”系统提示拼入 turn `text`。

## T0063 NPC 个人酒与饮酒行动

- `npc_profiles[].states` 和运行态 `NPCStateContext` 在 `money` 旁新增非负整数 `wine`。两者表示 NPC 本人持有资源；不进入 `station_context.basic_resource_reserves` 五项驿站公开库存。
- `Action Definition.personal_resource_cost` 描述个人资源消耗；当前 `drink_wine` 固定为 `{ "wine": 1 }`，`type=drink`，后端 `PlanActionKind` 同步新增 `drink`。
- `wine_given.payload` 必含 `amount / resource_id / npc_wine_before / npc_wine_after`；`wine_consumed.payload` 还必含 `action_id / context_effect`。扣减后的前后值由程序写入，LLM 不生成。
- 日计划业务校验要求 `drink_wine` 阶段数不超过 `npc.state.wine`；修订合并后从当前小时起的剩余饮酒阶段也不得超过当前个人酒。

## T0051 守备官会话运行态与提交事件

守备官-NPC / 逃离挽留活动会话新增运行态字段：`ui_visible: bool`、`suspended: bool`、`suspended_remaining_seconds: float`、`session_status: draft|active|suspended|completed|cancelled`、`attack_committed: bool`、`ended_while_waiting: bool`，以及仅完成时应用的 `deferred_recruitment_result`、`deferred_wartime_response`、`deferred_escape_response`。NPC `states` 同步保存 `active_dialogue_id` 与 `player_dialogue_suspended`；普通会话占用 action 为数据目录中的不可计划项 `talk_to_guard_officer`。

完成后的守备官会话只写一个 `dialogue_turn`。原必填字段保持不变，`dialogue_text` 改为整场有序 turn 数组，并增加：

```json
{
  "session_completed": true,
  "ended_while_waiting": false,
  "attack_committed": false,
  "completed_player_llm_turns": 1,
  "completed_attack_llm_turns": 0,
  "interaction_kind": "guard_npc_dialogue_session",
  "related_event_id": ""
}
```

等待回复时完成允许 `dialogue_text` 最后一项是守备官 turn 且 `reply_text=""`。取消会话不产生 schema 记录。NPC-NPC `dialogue_turn` 仍是逐轮事件，不携带 `session_completed=true`。

## T0046 场景、反思与公告牌数据

- `StationSceneContext` 是 `StationAwareNPCRequest` 顶层必填字段，不复制到嵌套 `NPCContext`。T0046 最初定义 `setting_summary / resident_roster`，T0054 扩充世界目录，T0058 按上节形成含公开基础资源的六字段合同。
- T0053 起 `NPCContext` 显式包含 `long_term_memory = { knowledge_graph, diary[] }`，并与既有 `identity / state / current_order / short_term_memory / location_context / plaza_context` 一起供日计划、计划判别、正式修订、战时心理和反思复用；旧 `knowledge_graph` 字段暂留为兼容镜像。
- `DailyReflectionResponse = { ok, npc_id, day, diary_entry, knowledge_graph_updates, debug_reason }`，不含 `memory_summary`。`KnowledgeGraphPatch` 包含稳定 `subject / relation / value / confidence` 与中文 `subject_label / relation_label / value_label`；反思业务输出要求三类中文文本非空且含中文。运行时日记记录只保存 `day / time / entry / source` 及模型 / 降级调试元数据。
- 广场公告牌状态为 `current_notice`、`reference_schedule[]`、`schedule_advisory_note`；日程项为 `{ id, start_time, end_time, content }`。变更事件为 `plaza_notice_changed / plaza_schedule_changed`，日程 payload 始终携带参考性备注。

## T0045 属性成长语义调整

`attribute_improved` 的 payload 为 `attribute`、`attribute_label`、`before`、`after`、`training_kind`。`training_kind` 取 `physical` / `mental`，用于稳定生成锻炼体力 / 脑力摘要；事件 actor 为成长的 NPC 自身。

## T0043A 行动持续依赖与互斥字段

`Action Definition` 新增四个数据驱动字段：

- `required_active_action_id`：开始和持续期间必须存在的在岗行动；当前用于病床治疗、接受训练和参加弥撒。
- `blocked_by_active_action_id`：另一行动在岗时，本行动不可开始；当前普通祈祷被主持弥撒阻止。
- `interrupts_action_ids`：本行动成功开始后，中断同建筑内列出的互斥行动；当前主持弥撒中断普通祈祷。
- `complete_with_required_action`：依赖行动正常完成时，本行动随之完成；当前仅用于参加弥撒。

`ActionCandidate.context` 和 `ActionSystem.get_runtime_action_snapshot(...)` 暴露相应依赖 / 阻止 action id；活动中的弥撒参加者另暴露 `provider_npc_id`。这些字段描述程序权威前置条件与运行态绑定，不授权 LLM 决定服务者是否真实在岗。

## T0043 建筑位置、升级奖励与行动资格字段

`Building Definition` 的 `workstations` 是位置权威清单。每项至少包含稳定 `id`、位置类型 `type`、玩家显示 `name` 和 `occupied_by`；数组顺序同时是建筑面板显示顺序。位置可选声明 `assigned_npc_id` 作为固定归属，当前只用于宿舍床位：归属者只能申请自己的位置，未归属 NPC 只能申请没有该字段的位置；释放占用不得删除归属。建筑可声明 `fixed_workstation_types`，升级不得为这些类型扩容。运行态额外暴露 `condition`、`is_enterable`、`damage_efficiency_multiplier`、`operational_efficiency_multiplier` 与累计 `efficiency_bonuses`。

升级继续保留旧单一奖励字段兼容，但新配置使用按目标等级索引的 `upgrade.level_effects`：每级可覆盖 `cost`、`duration_seconds`、`max_hp_bonus`，并包含 `workstation_deltas: [{type, count, id_prefix, name_prefix}]` 和 `efficiency_bonuses: {activity_key: additive_bonus}`。完成前不修改等级、容量或效率；升级 job 保存开始级、目标级与已解析奖励。

位置在地点快照中的最小结构为：

```json
{"id":"clinic_patient_bed_01","type":"clinic_patient_bed","name":"病床1","occupied_by":"cook_01","status":"occupied"}
```

位置新增、移除、改名、改类型、占用者或状态变化都参与差量；移除项使用 `removed: true`。外部状态传播 `is_enterable` 与离散运行效率分档，精确 HP 与效率仍由程序和 UI 读取。

`Action Definition` 可声明 `workstation_type`、`required_ability` 与 `eligibility_hint`。`ActionCandidate.context` 对所有 NPC 保留候选，并加入 `eligible`、`available_now`、`unavailable_reason`、`required_ability`、`required_active_action_id` 与 `blocked_by_active_action_id`；这表示“可见但未必有资格或即时条件执行”，不授权 LLM 绕过程序校验。`lead_mass` 要求能力“主持弥撒”，非合资格 NPC 的执行请求必须确定性失败。

## T0025 目标行动与计划修订契约

`ActionCandidate` 现在以 `action_id`、`action_kind`、可选 `location_id`、`target_id`、`target_kind`、`target_name`、`tags` 和 `context` 描述一条合法候选。`PlanItem` 必须回传对应的 `action_kind`，并为对话 / 主动交涉提供 `dialogue_goal`。固定地点行动由后端逐项校验 action、kind、target 与 location 的精确组合；T0091 起 `talk_to_npc` 只按 `action_id + target_id` 命中候选并拒绝 NPC 与自己对话，规范化后的 `location_id` 统一为空。

T0049/T0050 定义通用 `PlanRevisionJudgementRequest` / `PlanRevisionJudgementResponse`。请求携带 `game_time`、目标 NPC 标识、`trigger_kind` 和恰好覆盖 0-23 点的 `current_plan`；`dialogue` 分支要求 `dialogue_kind`、非空 `dialogue_history`、`dialogue_end_reason` 与 `dialogue_context`，`action_failure` 分支要求 `failed_plan_item`、非空 `failure_type` / `failure_summary`、必要 `failure_context` 及工作阶段计数 / 下限。T0053 起该模型继承 `StationAwareNPCRequest`，必填统一 `npc: NPCContext`，并携带 `allowed_actions / current_building_states / current_resource_states`；`npc.identity.npc_id` 必须与顶层 `npc_id` 一致。`failure_type` 包含 `plan_item_superseded`，用于等待期间旧计划项被当前阶段替代；T0086 新增 `action_completed`，表示旧项已经成功完成、当前小时需另排后续活动；T0093 要求 Godot 规范化层保持该合法枚举。响应仍只返回 `needs_revision`、升序去重的 `revision_hours`、`summary` 和 `debug_reason`；`needs_revision` 必须与数组是否非空一致，小时不得早于 `game_time.hour`，空数组表示 0 个修改阶段。旧 `DialoguePlanRevisionJudgement*` 名保留为兼容别名。

`PlanRevisionRequest` 携带 `failure_context`、实时建筑 / 资源状态、`current_work_phase_count`、`minimum_work_phase_count`、`replacement_work_phase_required_if_non_work`、`past_work_phase_count` 和 `minimum_remaining_work_phase_count`。T0049 后 `revision_scope` 只允许 `selected_hours`，且非空 `revision_hours` 必须升序去重、不早于当前小时。`PlanRevisionResponse.revised_plan` 必须按同样顺序恰好覆盖该集合；当前小时入选时 `immediate_action` 必须存在并与该项一致，未入选时必须为 `null`。合并回未选中的原计划后仍必须满足工作阶段下限。T0048 的 `remaining_day` 与 `revision_start_hour` 已被此合同取代。工位失败上下文包含被占工位及 `blocked_by_npc_ids` / `blocked_by_npcs`，因此模型可以结构化选择具体占用者作为 `talk_to_npc.target_id`。合法 `PlanActionKind` 包含 `drink`、`pray`、`visit`、`chat`、三类协助、`seek_guard_officer` 与特殊 `escape`；权威数值结算仍不属于 Schema 输出。

六类正式成功传输体始终包含 `model_normalizations` 数组，当前只有计划 / 修订可能为非空。它记录 Schema 已通过后的确定性规范化：固定地点行动须由 action、target、location 唯一命中候选后才可修正冗余 `action_kind`；`talk_to_npc` 由 action、target 唯一命中后可把模型多余返回的瞬时地点规范化为 `null`，再按候选修正 kind；idle 必须符合固定空目标 / 空地点合同。每项记录字段路径、模型原值、规范值和候选来源。该机制不修复未知枚举、自聊、空 `dialogue_goal`、白名单外目标、固定行动地点变化、重复候选或工作阶段不足。`required_ability` 只表达行动者资格；普通祈祷不再依赖 `requires_present_npc_id`，主持弥撒则用“主持弥撒”能力校验。

## Resource Definition

```json
{
  "id": "money",
  "name": "第纳尔",
  "category": "currency",
  "initial_amount": 30,
  "min_amount": 0,
  "ui_order": 1
}
```

T0305 曾增加 `meal / wine / weapons / armor / defense_devices / horse_readiness` 等派生资源；T0901/T1508 的早期实现也曾直接消费四类聚合库存。T0036 已保留这段历史数据兼容，但 `weapons / armor / defense_devices / horse_readiness` 当前均配置为 `deprecated=true`、`formal_consumption_allowed=false`，不得再由正式行动产出，也不得用于装备、部署或马匹分配。餐食与酒仍是正式数量资源。

T0034 冻结并由 T0035-T0038 实现的当前资源契约是：制造成品分别保存为 `item_sword_shield`、`item_polearm`、`item_bow`、`item_crossbow`、`item_iron_helmet`、`item_mail_chest`、`item_iron_bracers`、`item_iron_greaves`、`item_arrow_bundle`、`item_wall_ballista`、`item_wall_arrow_tower`。装备或部署哪一种，就原子扣除或返还同一种具体库存；这些定义使用 `show_in_main_hud=false` 与 `detail_group=weapon|armor|ammunition|defense_device`，由详情区逐项展示。马匹是 HorseSystem 个体实体，不进入 ResourceSystem。类别总数只能由具体库存 / 马匹实体汇总为只读 UI 摘要，不能成为第二权威来源。

## Merchant Definition

```json
{
  "merchant": {
    "id": "back_gate_merchant",
    "name": "后门商队",
    "location_id": "back_gate",
    "arrival_hour": 10,
    "arrival_minute": 0,
    "departure_hour": 16,
    "departure_minute": 0
  },
  "buy_offers": [
    {"resource_id": "grain", "unit_price": 2}
  ],
  "sell_offers": [
    {"resource_id": "wine", "unit_price": 7}
  ]
}
```

`buy_offers` 从驿站视角表示“买入商人的资源”，当前只允许粮食、木材、石料和铁；`sell_offers` 表示“向商人卖出驿站库存”，当前只允许酒。`unit_price` 是每份资源对应的整数第纳尔，必须大于 0。MerchantSystem 是时段、报价和交易结算权威；UI 不得复制另一份价格或直接修改资源。

## T0059 NPC Initial Long Memory

`data/npc_initial_long_memory.json` 是独立于根本档案的开局前长期记忆种子。顶层必须是以 NPC id 为键的对象，键集合与 `npc_profiles.json` 的 8 个 id 完全一致；每项只能包含 `diary` 与 `knowledge_graph`：

```json
{
  "stableman_01": {
    "diary": [
      {
        "day": 0,
        "time": "往昔·来站前",
        "entry": "我在南边驿路旁的马场长大，先给小马添草，后来替商队照料整队挽马。罗德里克教会我算草料，也让我看清，催一匹病马多走十里，通常只会把省下的钱交给兽医。马场改做赶程生意后，我不肯再拿马的腿脚赌时辰，便辞了工。三年前入冬前，我沿驿路到了这里。",
        "source": "initial_long_memory",
        "model_provider": "",
        "model_name": "",
        "model_fallback_used": false,
        "debug_reason": "seeded_before_game"
      },
      {
        "day": 0,
        "time": "往昔·初到驿站",
        "entry": "艾达把马厩钥匙交给我时，站里只有她算长期留下的人，马却已经有两匹。我接管马厩后的头几个星期，先把饮水、草料和每日检查理顺；她补轮值和用料账，我告诉她哪些动静只是马在做梦。那年冬夜很长，至少我们都知道另一边还有人醒着。",
        "source": "initial_long_memory",
        "model_provider": "",
        "model_name": "",
        "model_fallback_used": false,
        "debug_reason": "seeded_before_game"
      },
      {
        "day": 0,
        "time": "往昔·近日",
        "entry": "这几天栗风左后蹄有些发热，灰鬃又总想抢它的草。我把草槽隔开，给栗风减了负重，每晚再检查一次。布鲁诺嫌我为两匹马多领了一桶热水，念叨完还是把水烧了。我明天得先把用过的桶刷干净。",
        "source": "initial_long_memory",
        "model_provider": "",
        "model_name": "",
        "model_fallback_used": false,
        "debug_reason": "seeded_before_game"
      }
    ],
    "knowledge_graph": {
      "schema_version": "key_value_replace_v1",
      "updated_day": 0,
      "updated_time": "开局前",
      "by_subject": {
        "guard_officer": {
          "role": {
            "value": "station_defense_alert_and_emergency_staff_coordination",
            "confidence": 0.96,
            "subject_label": "守备官",
            "relation_label": "职务",
            "value_label": "守备官统筹驿站的防务与警戒，遇到危急情况也负责安排站里的人手。",
            "day": 0,
            "time": "开局前"
          }
        }
      }
    }
  }
}
```

前三篇日记固定使用“往昔·来站前 / 往昔·初到驿站 / 往昔·近日”，并与后续运行时日记完全共享 8 字段：`day / time / entry / source / model_provider / model_name / model_fallback_used / debug_reason`。“来站前”必须给出宏观身世、来站原因和时间；“初到驿站”必须记录接手工作与最初相遇，并遵循艾达 → 托马 → 布鲁诺 → 伊沃 → 格伦 → 欧文 → 马塞尔 → 莉娜的历史顺序；“近日”是敌情传达前的微观生活。种子固定为 `day=0 / source=initial_long_memory / model_provider="" / model_name="" / model_fallback_used=false / debug_reason=seeded_before_game`，明确说明它不是一次模型调用或 fallback。初始图谱禁止使用 `patches`，每条关系必须有稳定技术 `value`、0..1 `confidence`、中文 `subject_label / relation_label / value_label` 和开局前时间。每人必须覆盖其余 7 名 NPC、只有职责关系的 `guard_officer`、`building_defs.json` 的全部 15 个建筑和至少 2 个个人故事主体；`plaza` 与 `notice_board` 不属于建筑，不作为本任务的固定建筑知识主体。

`data/npc_profiles.json` 中 `diary=[] / knowledge_graph={}` 仍是运行时字段的空占位，禁止再复制种子内容。加载后由 NPCSystem 把种子深拷贝到运行态；后续反思追加日记，并以同一 `subject + relation` 替换知识记录。知识不拥有 HP、资源、建筑、装备、入伍、移动或行动结算权。

## NPC Profile

```json
{
  "id": "stableman_01",
  "name": "托马",
  "gender": "male",
  "background_job": "马夫",
  "appearance": "肩背宽厚，常穿沾着干草和马汗味的旧皮围裙，手上有缰绳磨出的茧。",
  "background_story": "托马把照料生命看成一份必须亲自负责的工作。他会耐心确认马匹的伤病和情绪，不轻易承诺，也不会为了服从而忽视明显风险。对他而言，可靠比逞强重要。",
  "personality": ["耐心谨慎", "重视责任", "不爱逞强"],
  "desires": ["把马匹照料好", "保住马厩和驿站的马", "在危机中让自己和马都活下来"],
  "fears": ["马匹因疏忽受伤", "被迫带着不适合出战的马参加冲锋", "自己的专业判断被随意否定"],
  "boundaries": ["不会接受明知会无谓伤害或牺牲马匹的安排"],
  "speech_style": "说话朴素简短，先描述自己看到的马匹状态和实际困难，再给意见。很少说教，也不会为了显得深刻而绕弯子。",
  "abilities": ["照料马匹", "基础骑术", "运送物资"],
  "stats": {
    "strength": 6,
    "intelligence": 4
  },
  "states": {
    "hp": 100,
    "max_hp": 100,
    "satiety": 80,
    "fatigue": 20,
    "money": 2,
    "unconscious": false,
    "escaped": false,
    "current_action": "idle"
  },
  "skills": {
    "养马": 70,
    "厨艺": 5,
    "耕种": 5,
    "打铁": 5,
    "教练": 5,
    "酿酒": 5,
    "医术": 5,
    "工程": 5,
    "剑盾": 0,
    "长杆": 0,
    "弓": 5,
    "弩": 0,
    "骑术": 45
  },
  "progression": {
    "total_experience": 0,
    "next_skill_point_xp": 5,
    "unspent_skill_points": 0,
    "spent_skill_points": 0,
    "skill_experience": {
      "养马": 0,
      "厨艺": 0,
      "耕种": 0,
      "打铁": 0,
      "教练": 0,
      "酿酒": 0,
      "医术": 0,
      "工程": 0,
      "剑盾": 0,
      "长杆": 0,
      "弓": 0,
      "弩": 0,
      "骑术": 0
    }
  },
  "recruited": false,
  "current_order": {
    "text": "",
    "issued_by": "guard_officer",
    "issued_day": 0,
    "issued_time": "",
    "revision": 0
  },
  "initial_equipment": {},
  "equipment": {},
  "plan": [],
  "short_term_memory": [],
  "knowledge_graph": {},
  "diary": []
}
```

T0301 起，`data/npc_profiles.json` 已使用该结构补齐 8 名初始 NPC。T0061 后，`gender`、`appearance`、`background_story`、`abilities`、`speech_style`、`plan`、`short_term_memory` 为 NPC 档案必填基础字段；`background_job` 只保留叙事出身，`boundaries`、`stats` 继续供后续计划、征召、对话和战斗心理判定使用。`speech_style` 是不锁死句式的表达倾向；`signature_lines` 已从正式档案、构造器与 Schema 移除。开局只有 `veteran_deputy_01` 的 `recruited` 为 `true`，其他 NPC 均为 `false`。

T0059 后 `background_story` 只保存职业身份、稳定观察方式、价值尺度与根本矛盾，不复述具体往事、人物关系或建筑知识；这些可变化、可被后续事件更新的内容属于独立长期记忆。

T0703 已为每名初始 NPC 配置并在运行时规范化 `current_order`。它保存守备官对该 NPC 当前持续提出的自然语言指令，而不是已执行行动：`text` 是当前文本，`issued_by` 固定为 `guard_officer`，`issued_day` / `issued_time` 记录最近一次变更时间，`revision` 在指令文本变化时递增。未入伍或尚无指令时 `text` 为空。发布相同文本或关闭指令面板不得修改该结构。

T1004/T1005 起，运行时 `diary` 保存首次睡眠总结生成的长期日记记录；T0059 后基础档案保持空数组，但新游戏会先从独立 `npc_initial_long_memory.json` 装载 3 篇 `day=0` 初始日记：

```json
{
  "day": 1,
  "time": "22:00:00",
  "entry": "今天我记住了这些事……",
  "source": "llm_daily_reflection",
  "model_provider": "deepseek",
  "model_name": "deepseek-v4-flash",
  "model_fallback_used": false,
  "debug_reason": "根据当天亲历与见闻生成"
}
```

T1405 后，同一任务会把 `DailyReflectionResponse.knowledge_graph_updates` 合并到运行时 `knowledge_graph` 替换式键值结构。知识图谱记录当前关键信息，同一 `subject + relation` 后续更新会覆盖旧值；日记则继续追加。当前最小形状为：

```json
{
  "schema_version": "key_value_replace_v1",
  "updated_day": 1,
  "updated_time": "22:00:00",
  "by_subject": {
    "station": {
      "daily_pressure": {
        "value": "布鲁诺在第1天睡前记住……",
        "confidence": 0.55,
        "subject_label": "驿站",
        "relation_label": "当日压力",
        "value_label": "今天站里的人手一直很紧。",
        "day": 1,
        "time": "22:00:00"
      }
    }
  }
}
```

该结构是 NPC 对当前关键信息的认知状态；LLM 不负责直接改写 HP、资源、建筑或行动事实。玩家【知识】弹窗显示 `subject_label / relation_label / value_label`，不显示 `confidence / day / time`；底层记录、后端合同和 GM 原始调试仍保留这些字段。

T1001 起，运行时 `plan` 可保存规则版每日计划。T1003/T0022 起，同一字段也保存 `/npc/plan_day` 返回且经 Godot 验证的真实 LLM 每日计划。正式开局和正式新一天只允许 `source=llm_plan_day`；Mock 和纯规则计划只能由显式调试入口写入。计划必须是 24 个小时项，每项至少包含：

```json
{
  "hour": 7,
  "action_id": "talk_to_npc",
  "action_name": "与马塞尔交谈",
  "target": {
    "target_id": "priest_01",
    "target_npc_id": "priest_01",
    "location_id": "clinic"
  },
  "priority": 70,
  "dialogue_goal": "协调诊所工位安排。",
  "source": "llm_plan_revision",
  "reason": "协调工位"
}
```

后端 `PlanItem` 在进入 Godot 前包含顶层 `action_kind` / `target_id` / `location_id`；`DailyPlanSystem` 校验后把目标组合归入运行时 `target` 字典，并从行动配置恢复显示名。计划由 `DailyPlanSystem` 生成和执行；正式输出必须精确复用动态候选的 action/kind/target/location 组合，执行时仍由 `ActionSystem` 校验地点、工位、资源、HP 和行动合法性。计划项 `source` 可为正式真实模型的 `llm_plan_day` / `llm_plan_revision`，或显式调试用的 `rule_default` / `mock_plan_day`。T0022/T0023 后不再产生每日计划 `rule_plan_fallback`、计划修订 `mock_revision` 或 `rule_revision_fallback`；正式每日计划失败时保持 `planning_day`，正式修订失败时保留当前计划。计划生成或修订可把当前小时改为 `idle` 安全等待项；`idle` 只表示计划层等待，不是生产行动定义。计划项不是已发生事实；只有实际执行的工作、吃饭、睡觉、祈祷、拜访、训练、治疗或对话事件才代表行动发生。

T0304 起，运行时 `NPCSystem` 会读取并更新 `states` 下的 `hp`、`max_hp`、`satiety`、`fatigue`、`money`、`unconscious`、`escaped`、`current_action` 字段，并将 `stats.strength` / 力量、`stats.intelligence` / 智力、`recruited` 与 `skills` 展示到 NPC 面板。移动系统会在运行时补齐和更新 `current_location`、`current_location_name`、`movement_target`、`movement_target_name` 和 `location_context`；这些字段当前作为地点进入占位，不要求手动写入 `data/npc_profiles.json`。T0808 起，诊所治疗可通过运行时恢复受伤 NPC 的 HP，并可最小提升医术。T0904 起，运行时会补齐 `progression` 成长结构：`total_experience` 记录熟练度提升同步得到的总经验，`skill_experience` 记录各熟练度累计经验，`unspent_skill_points` 是等待玩家分配的技能点，`spent_skill_points` 是已由玩家分配到属性的点数，`next_skill_point_xp` 当前为每 5 点总经验获得 1 个技能点。旧 NPC 档案可以不手动写入 `progression`，加载时会按默认值补齐。

T0901 起，运行时 `equipment` 可包含以下槽位：`main_weapon`、`helmet`、`chest`、`bracers`、`greaves`、`mount`。槽位内容由 `EquipmentSystem` 根据 `weapon_defs.json`、`armor_defs.json` 或 `mount_defs.json` 写入；`NPCSystem` 只保存槽位，不决定库存扣除、装备合法性或兵种。T0031 起，初始档案可用 `initial_equipment` 保存“槽位 -> 正式定义 id”的故事装备引用，例如艾达使用 `{"main_weapon": "sword_shield"}`；`EquipmentSystem` 只在对应运行时槽位为空时装载正式定义，不消耗全局库存、不写守备官 `equipment_given` 事件。没有故事装备的 NPC 继续使用空对象 `{}`，运行时 `equipment` 初值也可保持 `{}`。T0902 起，兵种判定只读取运行时装备结构中的 `main_weapon` 与 `mount` 槽；全局 `horse_readiness` 库存不代表某个 NPC 已骑乘。T1103 起，运行时 `states` 可由 CombatSystem 写入 `combat_mode`、`combat_mounted`、`facing_direction`、`combat_target_enemy_id`、`formation_row` 和 `formation_index` 等临时战斗 / 集结状态；T1103A 起，`states.behavior_mode` 是工作 / 集结 / 战斗 / 避战 / 昏迷 / 逃离的统一模式字段，并保存进入原因和进入时间。T1103B/T1103C 起，非战斗人员避战可临时写入 `avoidance_target_id`、`avoidance_target_name` 和 `avoidance_target_position`，用于 GM / UI 快照查看当前按敌方方位生成的短步长避战方向。T1104 起，战斗中的 NPC 状态可临时写入 `combat_attack_cooldown`、`combat_last_attack_result` 和当前 `combat_target_enemy_id`，用于按战斗推进秒处理攻击间隔和 GM / 自动化观察最近攻击结果；T1104A 起这些冷却不直接读取玩家 `x2` / `x4` 作为攻速倍率。T1105 起，`states.combat_strategy` 保存玩家当前手动选择的战斗策略，`combat_strategy_move_target_id`、`combat_strategy_move_target_name` 和 `combat_strategy_move_target_position` 只表示策略移动的临时目标。T1201 起，`states.morale_boost` 保存战时对话产生的 2 游戏小时斗志 buff；T1204A 起，`states.escape_intent` 保存逃离触发、移动目标、开始 / 完成时间、挽留轮次、对话暂停标记、最近挽留结果和逃离移动倍率，`status` 可为 `escaping`、`paused_unconscious`、`stayed` 或 `escaped`。这些字段不要求写入初始 NPC 档案，且不代表装备库存或 HP 结算。

T0038 后，坐骑槽不再表示由 `horse_readiness` 兑换出的匿名物品，而是 HorseSystem 权威分配关系的兼容快照，至少保存 `horse_id` 与 `horse_name`。只有已入伍且已装备主武器的 NPC 才允许建立该关系；仅有盔甲不满足条件。收回主武器、取消入伍或逃离会自动解除分配并清空 `equipment.mount`；仅更换主武器或收回盔甲不解除。槽位副本不能自行生成、销毁、治疗或移动马匹，完整个体状态始终以 HorseSystem 为准。

T0033 起，马塞尔的 `background_story` 只补充简短的“他擅长酿酒”，`background_job` 仍为神父；该描述是人物能力，不把酿酒改为他的职业或权威工作定义。

`states.combat_strategy` 示例：

```json
{
  "id": "keep_distance",
  "label": "保持距离射击",
  "unit_type": "archer",
  "unit_type_label": "弓箭兵",
  "selected_by": "player",
  "selected_reason": "manual"
}
```

可用策略由当前装备 / 兵种决定；当前策略由玩家在 NPC 面板手动选择，默认使用该兵种第一项进攻 / 输出策略。`current_order` 不自动改写该字段。

`states.behavior_mode` 允许值至少为 `work`、`rally`、`combat`、`avoid_combat`、`unconscious`、`escaped`。T1103 现有 `combat_mode` 仍作为兼容字段服务旧集结 / 坐骑视觉；后续应继续以 `behavior_mode` 表达工作 / 集结 / 战斗 / 避战同级关系。战时斗志激昂 buff 可保存为运行时状态，例如：

```json
{
  "behavior_mode": "combat",
  "morale_boost": {
    "active": true,
    "source_event_id": "evt_day03_101500_veteran_dialogue",
    "started_day": 3,
    "started_time": "10:15:00",
      "duration_seconds": 7200,
      "remaining_game_seconds": 7200,
      "attack_bonus": 0.15,
      "move_speed_bonus": 0.15,
      "trigger": "wartime_dialogue"
    }
}
```

逃离状态示例：

```json
{
  "behavior_mode": "escaped",
  "escaped": false,
  "escape_intent": {
    "active": true,
    "status": "escaping",
    "source_event_id": "evt_day03_101500_veteran_dialogue",
    "escape_started_event_id": "evt_day03_101501_veteran_deputy_01_escape_started",
    "trigger": "wartime_dialogue",
    "interaction_context": "combat",
    "exit_target_id": "back_gate_escape_exit",
    "exit_target_name": "后门外出口",
    "exit_position": {"x": -10.0, "y": 0.0, "z": -24.0},
    "intervention_rounds_used": 0,
    "intervention_max_rounds": 5,
    "last_intervention_decision": "",
    "movement_paused_for_dialogue": false,
    "paused_dialogue_id": "",
    "last_dialogue_resume_reason": "",
    "speed_multiplier": 1.0,
    "started_day": 3,
    "started_time": "10:15:00"
  }
}
```

这些字段由程序根据对话 / 判定结果应用和清除，LLM 不能直接改写具体数值。移动期间 `escaped` 仍为 `false`；NPC 到达后门外出口后，`NPCSystem` 将 `escaped` 改为 `true`，把 `escape_intent.status` 改为 `escaped`，并记录 `completed_day` / `completed_time`。T0087 后，`escape_intervention_result=stay` 只在完成会话时把 `status` 改为 `stayed` 并停止移动；打开或挂起逃离挽留时 `movement_paused_for_dialogue=true` 并保存 `paused_dialogue_id`，完成、取消或满 5 轮继续逃离时清回 `false` 并记录 `last_dialogue_resume_reason`。取消不应用暂存结果；逃离挽留攻击计入 1 轮、不产生 NPC 回复、锁定取消并自动完成会话。逃离期间昏迷会暂记 `paused_unconscious`，复苏后恢复为 `escaping`。

T0501 起，`NPCSystem.apply_damage_to_npc(...)` 会扣除 `states.hp`，并在 HP 降到 0 时设置 `states.unconscious=true`、`states.current_action="unconscious"`、清空移动目标。T0502/T0503 起，昏迷 NPC 会自然恢复，也可被其他 NPC 协助治疗；HP 恢复到 Max HP 30% 后复苏。昏迷 NPC 不会死亡，也不能移动或执行行动。

T0402 设计更新后，运行时短期记忆不再建议只用一个扁平 `short_term_memory` 数组表达。后续应拆分为当天 `event_log` 与 `witness_log`：前者记录发生在该 NPC 身上的事件 ID，后者记录该 NPC 通过地点/广场即时广播、状态广播或公告获得的见闻事件 ID。NPC 不会因为进入地点而继承该地点过去发生的事件。`data/npc_profiles.json` 可继续保留 `short_term_memory` 作为初始空字段兼容占位，但运行时 MemorySystem 应以 NPC 事件库和见闻库为准。

T0304 修正后，`skills` 是固定全集，每名 NPC 必须都有且只能有以下 13 个熟练度维度，取值范围 0-100：

- 职业熟练度：`养马`、`厨艺`、`耕种`、`打铁`、`教练`、`酿酒`、`医术`、`工程`
- 武器熟练度：`剑盾`、`长杆`、`弓`、`弩`、`骑术`

`background_job` 只表示叙事背景，不作为权威职业分类。实际“职业倾向 / 专长”由这些熟练度的高低推导；运行时 `NPCSystem.normalize_skills(...)` 会按固定全集补齐缺失值并丢弃未定义技能。

T0904 起，属性成长不由 AI 自动分配。玩家通过 `NPCSystem.assign_npc_attribute_point(npc_id, "strength"|"intelligence")` 消耗 1 个 `unspent_skill_points`，将 `stats.strength` 或 `stats.intelligence` 提高 1 点；属性当前上限为 10。AI 只能在对话或计划建议中表达倾向，不拥有消耗技能点或改写属性的权威入口。

## Building Definition

```json
{
  "id": "dormitory",
  "name": "宿舍",
  "level": 1,
  "hp": 120,
  "max_hp": 120,
  "tags": ["living", "rest"],
  "scene_nodes": ["Dormitory"],
  "fixed_workstation_types": ["dormitory_bed"],
  "damage_efficiency_floor": 0.25,
  "workstations": [
    {"id":"dormitory_bed_01","type":"dormitory_bed","name":"床位1","assigned_npc_id":"veteran_deputy_01","occupied_by":null},
    {"id":"dormitory_bed_02","type":"dormitory_bed","name":"床位2","assigned_npc_id":"stableman_01","occupied_by":null},
    {"id":"dormitory_bed_03","type":"dormitory_bed","name":"床位3","assigned_npc_id":"cook_01","occupied_by":null},
    {"id":"dormitory_bed_04","type":"dormitory_bed","name":"床位4","assigned_npc_id":"gardener_01","occupied_by":null},
    {"id":"dormitory_bed_05","type":"dormitory_bed","name":"床位5","assigned_npc_id":"blacksmith_01","occupied_by":null},
    {"id":"dormitory_bed_06","type":"dormitory_bed","name":"床位6","assigned_npc_id":"engineer_01","occupied_by":null},
    {"id":"dormitory_bed_07","type":"dormitory_bed","name":"床位7","assigned_npc_id":"priest_01","occupied_by":null},
    {"id":"dormitory_bed_08","type":"dormitory_bed","name":"床位8","assigned_npc_id":"doctor_01","occupied_by":null},
    {"id":"dormitory_bed_09","type":"dormitory_bed","name":"床位9","occupied_by":null},
    {"id":"dormitory_bed_10","type":"dormitory_bed","name":"床位10","occupied_by":null}
  ],
  "inputs": {},
  "outputs": {},
  "repair": {
    "cost": {"stone": 1},
    "hp_restore": 25,
    "seconds_per_missing_hp": 30,
    "level_time_factor": 0.35
  },
  "upgrade": {
    "cost": {"stone": 3},
    "max_level": 2,
    "max_hp_bonus": 20,
    "workstation_bonus": 0,
    "workstation_type": "dormitory_bed",
    "level_effects": {
      "2": {
        "efficiency_bonuses": {"sleep_recovery": 0.2}
      }
    }
  }
}
```

`repair` / `upgrade` 为 T0205 起使用的可选字段。已配置时由 `BuildingSystem` 调用 `ResourceSystem.spend_resources` 进行资源结算。2026-05-24 起，`repair` 的资源会在修复开始时一次性扣除，`seconds_per_missing_hp` 和 `level_time_factor` 用于计算倒计时修复时长；`hp_restore` 保留为旧配置兼容字段，不再表示点击后瞬间恢复。所有建筑都应具备 `upgrade` 最小配置；升级时长可由 `duration_seconds`，或 `seconds_per_current_level + level_time_factor` 配置，未配置时使用系统默认时长。升级在开始时一次性扣除资源并创建倒计时作业，升级期间 `is_enterable=false`、所有内部位置停用，完成后才应用等级、Max HP、非固定位置增量和效率奖励。

只有可进入建筑使用 `workstations` 表达内部状态。T0801 起，运行时位置占用和释放由 `BuildingSystem.claim_workstation(...)` / `release_workstation(...)` 修改 `occupied_by`；地点信息节点只读取该状态并广播差量，不自行决定位置权威状态。T0043 后，小诊所使用 `clinic_doctor_station` / `clinic_patient_bed`，训练场使用 `training_instructor_station` / `training_practice_slot`；升级通过 `workstation_deltas` 增加未列入 `fixed_workstation_types` 的位置。主厅、围墙、城门、后门、仓库等不可进入建筑保留 HP、等级、修复/升级等权威状态，但 `workstations` 为空，也不会暴露内部 NPC 或位置。NPC 可传播外部状态包含等级、`condition`、`is_enterable` 和运行效率分档；可进入建筑的内部状态按位置 ID 传播新增、移除、改名、改类型和占用变化。运行时地点快照还会为广场和可进入建筑生成 `people_statuses`；它来自 NPC 运行时状态，不要求写入 `data/building_defs.json`。

T0035/T0037 后，可进入建筑的 `internal_state.special_state` 已按 T0034 合同实现。该字段不是静态 `building_defs.json` 的自由字典，而是按建筑类型固定白名单、由相应权威系统生成的运行时快照：

- `blacksmith` / `workshop`：只允许 `production.target_item_id`、`target_name`、`completed_stages`、`total_stages`、`current_stage_index`、`current_stage_name`。
- `stable`：只允许 `horses.total`、`adult`、`foal`，且只统计物理上仍在马厩的马。

制造周期的小数进度，以及马匹名字、HP、饱食度、成长、进食和分配详情，均不得进入 `special_state`。进入者获得完整白名单快照；已经在场且未昏迷 / 未睡觉的 NPC 只接收 `location_status_changed(reason=building_internal_special_state_changed)` 中的 `changed_special_state` 字段级差量。该内部状态不进入广场 `building_external_states`，也不向建筑外 NPC 广播。CraftingSystem / HorseSystem 只提交白名单状态，BuildingSystem 保存，MemorySystem 负责裁剪、比较和按地点传播。

公告牌不使用 Building Definition。主厅前的 `NoticeBoard` 节点已由独立脚本提供点击、预览和公告输入，但不能配置 `hp`、`max_hp`、`workstations`、`repair` 或 `upgrade`；公告文本写入广场 Location Info Node 的当前状态。

## Action Definition

```json
{
  "id": "work_garden",
  "name": "照料菜园",
  "type": "work",
  "completion_policy": "repeat_while_planned",
  "location_required": "garden",
  "skill": "耕种",
  "stat": "strength",
  "duration_seconds": 3600,
  "input_resources": {},
  "output_resources": {
    "grain": 2
  },
  "output_scaling": {
    "resources": ["grain"],
    "skill_per_bonus": 50,
    "attribute_baseline": 5,
    "attribute_per_bonus": 3,
    "building_level_bonus": true
  },
  "needs_profile": "heavy_work"
}
```

T0305 起，行动定义支持多类 JSON 最小行动；2026-05-25 起，行动时长优先使用 `duration_seconds`，旧的 `base_duration_hours` 仅保留为兼容字段。行动抵达地点后按 TimeSystem 逻辑秒推进，不应在抵达瞬间完成。T0081 起，`data/action_defs.json` 中每一条行动定义必须且只能通过 `needs_profile` 绑定生活消耗档位；不得再声明 `satiety_delta`、`fatigue_delta`、`satiety_delta_per_hour` 或 `fatigue_delta_per_hour`。所有档位速率统一由 `data/activity_needs.json` 按“点 / 游戏小时”定义，并由 `NPCNeedsSystem` 按有效逻辑秒连续结算。

T0075 起，`completion_policy` 是每条配置行为的必填字段，只允许 `repeat_while_planned / continuous_until_plan_changes / until_target_resolved / once_per_plan_hour / terminal / not_plan_selectable`。`not_plan_selectable` 必须与 `plan_selectable=false` 同时出现，其余策略必须属于计划可选行为；缺失、未知值或二者冲突时 ActionSystem 跳过该定义并记录配置错误。策略分类的完整 action id 表见 `AI_NPC_SYSTEM.md`；后续新增行为必须同步扩展分类专项，不能依赖 `type` 或 id 前缀隐式推断。

T0086 增加可选布尔字段 `reevaluate_current_hour_on_completion`。它不替代 `completion_policy`；T0093 后其兼容字段名不变，语义是该行动成功结束且权威当前小时仍指向同一计划项时，直接重排当前小时起连续相同 action + target 的计划段。当前只能为 `assist_repair / assist_upgrade / assist_heal / receive_clinic_treatment / drink_wine` 设为 `true`；未声明等价于 `false`。完成修订上下文使用 `failure_type=action_completed`，并携带 `condition=successful_plan_action_completion`、`completed_action_id`、`completion_result`、`completed_plan_item`、`requires_different_current_activity=true` 与 `contiguous_revision_hours`；后者必须等于本次精确 `revision_hours`。

各行动类型字段：

- `work`：读取 `location_required`、`workstation_type`、`duration_seconds`、`input_resources`、`output_resources` 和 `needs_profile` 后由程序结算。`duration_seconds` 是单位工作周期基准；实际周期按 NPC 技能 / 属性、建筑等级奖励和建筑损伤效率结算。工作开始申请目标位置，完成、失败或中断时释放。`work_dining_hall` 使用 `dining_kitchen_station` 与 `building_efficiency_key="production"`。T0804-T0806 的聚合制造 / 马匹整备配置属于历史运行态，已被下一条当前覆盖取代。
- T0035/T0037 当前覆盖：`work_blacksmith` / `work_workshop` 使用 `requires_crafting_target=true`，选中该建筑合法制造目标才允许开工；每个完整工作周期只向 CraftingSystem 提交一个阶段，不直接写任何聚合或具体成品产出。周期中断只丢失该 NPC 未完成的小数周期，已提交整数阶段不回退。`work_stable` 的 `input_resources / output_resources` 均为空，只把有效在岗者的最高“养马”能力交给 HorseSystem 推进繁育、成长与额外 HP 培养；马匹进食由 HorseSystem 在进食周期完成时自行原子扣粮。
- `eat`：使用 `workstation_type="dining_seat"` 申请一个用餐席，使用 `food_options` 定义可消耗食物及饱食度恢复量，并以 `building_efficiency_key="meal_recovery"` 应用食堂升级与损伤效率。标准进食时长为 1200 秒，食物恢复按进度逐步应用；`needs_profile="eat"` 同时表达进食仍会增加少量疲劳。
- `sleep`：使用 `workstation_type="dormitory_bed"` 申请一个床位，通过 `duration_seconds` 和 `needs_profile="sleep"` 连续消耗饱食、恢复疲劳，并以 `building_efficiency_key="sleep_recovery"` 应用宿舍升级与损伤效率。当前睡眠基准为 23400 秒降低 100 点疲劳并消耗 13 点饱食。
- `pray`：`pray_at_chapel` 使用 `chapel_prayer_seat`，不要求神父在场，但以 `blocked_by_active_action_id="lead_mass"` 声明互斥；`lead_mass` 使用 `chapel_altar`、要求 `required_ability="主持弥撒"`，并以 `interrupts_action_ids` 中断普通祈祷；`attend_mass` 使用 `chapel_prayer_seat`，以 `required_active_action_id="lead_mass"` 和 `complete_with_required_action=true` 绑定主持生命周期。三者都绑定 `needs_profile="prayer_rest"`。
- `targeted_heal`：需要运行时传入昏迷目标 NPC，不可通过普通 `assign_action` 直接执行。当前 `assist_heal` 读取 `requires_target="unconscious_npc"`、`target_limit_per_target`、`resource_cost_interval_seconds`、`input_resources.money`、`skill="医术"`、`needs_profile="light_work"` 和 `timed_experience` 作为行为声明；具体目标校验、费用扣除、医术加速、有效治疗时长、HP 恢复和成长由 `ActionSystem` / `NPCSystem` 结算。
- `clinic_doctor`：读取 `location_required="clinic"`、`workstation_type="clinic_doctor_station"`、`skill="医术"`、`stat="intelligence"`、`study_skill_interval_seconds`、`treatment_skill_interval_seconds`、`resource_cost_interval_seconds` 和 `needs_profile="light_work"`。无病人时，在诊疗位上的 NPC 缓慢研读医学著作；有病人时，全部在岗医生的人数、医术和相关属性组成团队效率，并同时作用于全部病床。
- `clinic_patient`：读取 `location_required="clinic"`、`workstation_type="clinic_patient_bed"`、`required_active_action_id="work_clinic_doctor"` 和 `needs_profile="clinic_rest"`。只有受伤且未昏迷 NPC 可执行；无在岗医生时开始失败，活动中全部医生离岗时中断失败。团队、诊所升级与损伤效率由程序合成，不建立医生—病人一对一绑定。
- `training_instructor`：读取 `location_required="training_ground"`、`workstation_type="training_instructor_station"`、`skill="教练"`、`stat="intelligence"`、`solo_skill_interval_seconds`、`coaching_skill_interval_seconds`、`student_skill_interval_seconds` 和 `needs_profile="training_instructor"`。NPC 必须有主武器或坐骑才能执行；没有受训者时提升自己当前装备对应武器 / 骑术，有受训者时参与全教官团队效率并提升“教练”。
- `training_student`：读取 `location_required="training_ground"`、`workstation_type="training_practice_slot"`、`required_active_action_id="work_training_instructor"`、`student_skill_interval_seconds` 和 `needs_profile="training_student"`。NPC 必须有主武器或坐骑且训练场已有有效教官才能执行；全部教官离岗时当前受训中断失败。训练项目由受训者当前主武器 / 坐骑决定。全部在岗教官的人数、“教练”和对应项目熟练度组成团队效率，与训练场升级、损伤效率一起作用于全部训练位。
- `system`：T1204A 新增，用于 `escaping_station`、`escape_intervention_dialogue` 等系统状态在地点快照、NPC 面板和记忆摘要中显示中文名称；它不是普通 `assign_action` 可执行行动，但仍必须通过 `needs_profile` 声明其持续生活消耗。

`assist_repair` 由 `ActionSystem.debug_assign_repair_assist(npc_id, building_id)` 接收 `building_id` 参数，并读取 `BuildingSystem` 当前是否存在修复作业。`assist_upgrade` 由 `ActionSystem.debug_assign_upgrade_assist(npc_id, building_id)` 接收 `building_id` 参数，并读取 `BuildingSystem` 当前是否存在升级作业。二者只在 `data/action_defs.json` 中各保留一条参数化行为，不能为每栋建筑复制定义；建筑 HP、资源预付、倒计时和协助者加成都由 `BuildingSystem` 结算。两者使用 `needs_profile="heavy_work"`，并以 `timed_experience={skill:"工程", interval_seconds:3600, amount:1}` 按真正推动作业的有效时长成长。协助治疗使用相同结构按有效治疗时长增加“医术”；目标在当前 tick 中复苏时，超出复苏时点的时间不得结算生活消耗或经验。协助修复/协助升级都是室外广场行为，事件 `location_id` 固定为 `plaza`，`visibility` 固定为 `local_public`，payload 通过 `building_id` 保留实际目标建筑。

## Activity Needs Definition

`data/activity_needs.json` 是 NPC 持续行动饱食 / 疲劳的唯一数值源：

```json
{
  "schema_version": 1,
  "unit": "points_per_game_hour",
  "defaults": {
    "idle_profile": "idle",
    "movement_profile": "movement",
    "unconscious_profile": "unconscious_rest"
  },
  "behavior_mode_profiles": {
    "rally": "rally",
    "combat": "combat",
    "avoid_combat": "avoid_combat",
    "escaped": "escape"
  },
  "profiles": {
    "idle": {"satiety_per_hour": -0.5, "fatigue_per_hour": 0.5},
    "heavy_work": {"satiety_per_hour": -4.0, "fatigue_per_hour": 8.0},
    "combat": {"satiety_per_hour": -8.0, "fatigue_per_hour": 16.0},
    "sleep": {"satiety_per_hour": -2.0, "fatigue_per_hour": -15.3846153846}
  }
}
```

- `satiety_per_hour < 0` 表示消耗饱食，`fatigue_per_hour > 0` 表示增加疲劳，`fatigue_per_hour < 0` 表示恢复疲劳。
- `NPCNeedsSystem` 按 tick 开始时的权威状态为每名 NPC 选择唯一档位，避免移动、行动和行为模式重复扣算；行动在 tick 中途完成时，剩余时间按 idle 结算。
- 小数变化按 NPC 累积余数，写入 `NPCSystem` 时仍保持整数状态；达到 0 / 100 边界后不会保留继续向边界外增长的债务。
- `tools/verify_activity_needs_framework.gd` 必须动态穷尽全部行动定义，检查每条 `needs_profile` 存在、禁用旧生活字段、工作 / 训练 / 协助和休息方向正确，并覆盖所有行为模式映射。

## Weapon Definition

```json
{
  "id": "bow",
  "name": "弓",
  "equipment_slot": "main_weapon",
  "type": "ranged",
  "weapon_class": "bow",
  "combat_role": "archer",
  "source_resource_id": "item_bow",
  "range": 12.0,
  "damage": 10,
  "attack_interval": 1.5,
  "required_skill": "弓",
  "tags": ["wooden", "ranged"]
}
```

T0901 后，`data/weapon_defs.json` 至少包含剑盾、长杆、弓、弩等可装备主武器；T0036 当前实现已让 `source_resource_id` 分别指向 `item_sword_shield`、`item_polearm`、`item_bow`、`item_crossbow`。装备系统只在该具体库存足够时消耗对应一件，卸下时返还同一 ID，并把完整定义副本写入 NPC `equipment.main_weapon`；弃用的 `weapons` 不再参与正式装备。T1104 起，CombatSystem 已读取 `range`、`damage` 和 `attack_interval`：`damage` 作为基础攻击力输入并受 NPC 力量修正，`range` 决定可攻击距离，`attack_interval` 作为基础攻击间隔并受武器熟练度、疲劳、饱食和坐骑 / 骑术修正。T1104B 起，`attack_interval` 的单位是战斗动作秒，CombatSystem 会把 `60` 游戏秒折算为 `1` 战斗动作秒后推进攻击冷却。T1104A 起，玩家时间倍率不参与伤害或攻击速度修正。装备 UI 仍不自行结算伤害。

## Armor Definition

```json
{
  "id": "mail_chest",
  "name": "锁子甲",
  "slot": "chest",
  "source_resource_id": "item_mail_chest",
  "armor_value": 5,
  "weight": 4,
  "tags": ["metal", "body"]
}
```

T0901 后，`data/armor_defs.json` 覆盖 `helmet`、`chest`、`bracers`、`greaves` 四类盔甲槽。T0036 当前实现分别消费 / 返还 `item_iron_helmet`、`item_mail_chest`、`item_iron_bracers`、`item_iron_greaves`，不得以 `armor` 聚合库存互换部位。T1104 起，CombatSystem 已读取四个盔甲槽的 `armor_value` 总和作为 NPC 防御，敌人攻击 NPC 时会先按防御减伤再扣 HP。`weight` 仍只是后续疲劳 / 负重系统的数据，不由 UI 直接结算。

## Mount Definition

```json
{
  "id": "riding_horse",
  "name": "马匹",
  "slot": "mount",
  "speed_bonus": 1.35,
  "required_skill": "骑术",
  "tags": ["horse"]
}
```

T0038 后，`data/mount_defs.json` 只提供通用骑乘战斗参数，不包含 `horse_readiness` 消费来源。实际 `equipment.mount` 必须引用 HorseSystem 中唯一的 `horse_id / horse_name`，由 HorseSystem 建立或解除分配，EquipmentSystem 只写轻量投影。日常工作模式不显示骑乘；进入集结 / 战斗模式时该马的权威位置改为 `ridden`，退出后返厩。T1103 后集结 / 战斗模式会显示低模坐骑；T1105 后坐骑参与兵种判定并决定可选战斗策略，例如近战骑兵可选“主动进攻 / 拉开距离冲击 / 避战”，骑射单位可选“最大化输出 / 保持距离射击 / 避战”。`speed_bonus` 仍只是后续更完整骑乘移动数值的输入，不由 UI 直接结算。

## Defense Device Definition

`data/defense_device_defs.json` 顶层包含 `devices` 与 `slots`。器械定义示例：

```json
{
  "id": "wall_ballista",
  "name": "弩床",
  "inventory_cost": {"item_wall_ballista": 1},
  "required_building_levels": {"wall": 1, "workshop": 1},
  "effect": {
    "kind": "auto_attack",
    "damage": 24,
    "attack_interval": 4.0,
    "range": 32.0,
    "minimum_forward_dot": 0.05,
    "max_attacks_per_tick": 16
  },
  "presentation": {
    "model_scene": "",
    "placeholder_kind": "ballista",
    "placeholder_color": {"r": 0.38, "g": 0.22, "b": 0.10, "a": 1.0}
  }
}
```

槽位定义示例：

```json
{
  "id": "front_wall_ballista_left",
  "name": "前墙左侧平台",
  "building_id": "wall",
  "allowed_device_ids": ["wall_ballista"],
  "position": {"x": -5.0, "y": 1.72, "z": 11.35},
  "rotation_y_degrees": 0.0,
  "facing_direction": {"x": 0.0, "y": 0.0, "z": 1.0}
}
```

`effect.kind` 当前只支持 `auto_attack`，弩床与箭塔使用各自的 `damage`、`attack_interval`、`range`、`minimum_forward_dot` 和 `max_attacks_per_tick`；`attack_interval` 使用战斗动作秒。`position`、`rotation_y_degrees` 和 `facing_direction` 是逻辑部署与射界输入；表现层只能读取。`presentation.model_scene` 是可选 PackedScene 路径，空值时使用低模占位；正式模型统一挂到 `DefenseDeviceView/ModelMount` 下，不承载库存或伤害逻辑。

运行时 deployment snapshot 包含 `deployment_id`、`device_id`、`slot_id`、`building_id`、`status`、`attack_cooldown`、`total_attacks`、`total_damage`、`last_action_result`，以及规范化的器械效果、表现与槽位坐标。部署不包含 NPC id；该运行态由 DefenseDeviceSystem 持有，不写回静态 JSON。

上方 `inventory_cost` 是 T0036 当前结构：弩床只消耗 `item_wall_ballista`，箭塔只消耗 `item_wall_arrow_tower`。DefenseDeviceSystem 会拒绝四种弃用聚合库存成为正式成本，并在部署快照 / 事件中保留具体 `inventory_resource_id` 与 `inventory_cost`。

## Crafting Recipe（T0035 当前实现）

`data/crafting_recipes.json` 的每条配方属于一个建筑，并以有序 `stages` 表达难度。阶段成本之和必须等于完整成品成本；材料只在对应阶段完整提交时原子扣除。

```json
{
  "id": "craft_sword_shield",
  "building_id": "blacksmith",
  "output_item_id": "item_sword_shield",
  "output_amount": 1,
  "stages": [
    {"id": "forge_blade", "name": "锻刃", "cost": {"iron": 1}},
    {"id": "shape_shield", "name": "制盾", "cost": {"wood": 1}},
    {"id": "forge_fittings", "name": "锻造配件", "cost": {"iron": 1}},
    {"id": "assemble_finish", "name": "装配打磨", "cost": {"iron": 1}}
  ]
}
```

合法目录必须完整覆盖：

| 建筑 | 配方 id | 成品库存 id | 阶段数 | 材料总量 |
|---|---|---|---:|---|
| 铁匠铺 | `craft_iron_helmet` | `item_iron_helmet` | 2 | 铁 2 |
| 铁匠铺 | `craft_iron_bracers` | `item_iron_bracers` | 2 | 铁 2 |
| 铁匠铺 | `craft_polearm` | `item_polearm` | 3 | 铁 2、木材 1 |
| 铁匠铺 | `craft_iron_greaves` | `item_iron_greaves` | 3 | 铁 3 |
| 铁匠铺 | `craft_sword_shield` | `item_sword_shield` | 4 | 铁 3、木材 1 |
| 铁匠铺 | `craft_mail_chest` | `item_mail_chest` | 6 | 铁 6 |
| 工械坊 | `craft_arrow_bundle` | `item_arrow_bundle` | 1 | 木材 1 |
| 工械坊 | `craft_bow` | `item_bow` | 2 | 木材 2 |
| 工械坊 | `craft_crossbow` | `item_crossbow` | 4 | 木材 3、铁 1 |
| 工械坊 | `craft_wall_ballista` | `item_wall_ballista` | 6 | 木材 5、铁 1 |
| 工械坊 | `craft_wall_arrow_tower` | `item_wall_arrow_tower` | 8 | 木材 7、铁 1 |

建筑级运行态保存当前 `recipe_id`、项目 `revision`、`completed_stages` 与 `total_stages`。同建筑多个工位可以并行推进各自工作周期，但完整周期提交时必须再次校验 `revision`、领取唯一的下一阶段并扣除该阶段材料。全部阶段完成后只增加 1 件 `output_item_id`，保留目标并把整数阶段重置为 0。更换目标会增加 `revision`、放弃旧项目全部整数阶段并中断旧版本周期；已经扣除的阶段材料不返还。`special_state.production.current_stage_index` 使用 1 起始，等于 `completed_stages + 1`；未选择目标或没有合法当前阶段时为 0，名称为空。小数周期进度只供建筑面板汇总显示，不属于上述 `special_state`。

## Horse Definition / Runtime（T0037-T0038 当前实现）

`data/horse_defs.json` 保存初始马和养马平衡参数，脚本不得写死个体：

```json
{
  "initial_horses": [
    {"horse_id": "horse_chestnut_wind", "name": "栗风", "growth": 0.6},
    {"horse_id": "horse_gray_mane", "name": "灰鬃", "growth": 0.6}
  ],
  "balance": {
    "stable_satiety_loss_per_hour": 0.5,
    "outside_satiety_loss_per_hour": 2.0,
    "feeding_missing_ratio": 0.2,
    "feeding_duration_seconds": 1200,
    "feeding_grain_cost": 1,
    "feeding_satiety_restore": 35,
    "natural_hp_restore_per_hour": 0.2,
    "satiety_cost_per_hp": 0.5,
    "foal_natural_max_hp": 40,
    "foal_max_satiety": 50,
    "adult_natural_max_hp": 100,
    "adult_max_satiety": 100,
    "adult_growth_threshold": 0.6,
    "base_full_growth_care_minutes": 10080,
    "birth_probability_gain_per_care_minute": 0.00005,
    "birth_probability_cap": 1.0,
    "birth_cooldown_minutes": 1440,
    "stable_level_birth_bonus_per_level": 0.1,
    "care_skill_100_bonus_hp_cap": 20
  }
}
```

每匹马的权威运行态至少为：

```json
{
  "horse_id": "horse_chestnut_wind",
  "name": "栗风",
  "growth": 0.6,
  "is_adult": true,
  "hp": 76.0,
  "base_hp": 76.0,
  "natural_max_hp": 76.0,
  "care_bonus_hp": 0.0,
  "care_bonus_cap": 0.0,
  "extra_hp": 0.0,
  "extra_hp_cap": 0.0,
  "satiety": 80.0,
  "max_satiety": 80.0,
  "breeding_probability": 0.0,
  "breeding_cooldown_remaining_seconds": 0.0,
  "breeding_cooldown_active": false,
  "location": "stable",
  "feeding": {"active": false, "elapsed_seconds": 0.0, "progress": 0.0, "waiting_for_grain": false},
  "assigned_npc_id": "",
  "ridden_by_npc_id": "",
  "recovering": false
}
```

`natural_max_hp`、`max_satiety`、`base_hp`、`extra_hp / extra_hp_cap`、`is_adult` 和 `breeding_cooldown_active` 是公开快照派生字段，程序不得相信 UI 或 LLM 传入这些值。权威运行态继续用总 `hp`、`care_bonus_hp / care_bonus_cap`、`breeding_probability` 和 `breeding_cooldown_remaining_seconds` 结算；`base_hp = hp - care_bonus_hp` 只用于把基础生命与照料生命拆开展示。`care_bonus_cap` 是有效养马照料培养出的可持续上限，`care_bonus_hp` 是当前仍保有的额外 HP；自然恢复只能恢复到 `natural_max_hp`，不能补回已损失的额外 HP。`location` 至少区分 `stable` 与 `ridden`；分配关系和骑乘关系必须通过 `horse_id` 唯一对应，不能由装备槽复制实体。

HorseSystem 随 TimeSystem 逻辑时间推进：在厩 / 离厩饱食分别按配置速率下降；只有在厩且饱食缺口达到 20% 才启动 1200 秒进食周期，完成时原子扣除 1 粮食并恢复 35 饱食，缺粮时保留 `waiting_for_grain=true` 等待重试。受伤马无论在厩或离厩都可消耗饱食，以每小时 0.2 HP 的基准自然恢复，但只能恢复到自然 HP 上限。只有有效 `work_stable` 在岗时，系统才使用最高在岗“养马”熟练度推进成长、额外 HP 和逐马繁育概率；至少 2 匹成年在厩且不在冷却的马才增长概率和判定。每个完整有效照料分钟先按 `birth_probability_gain_per_care_minute × 养马能力 × 马厩等级` 增长每匹候选马的概率，再按当前累积值判定最多 `N - 1` 次且单分钟最多出生 1 匹。成功后本次候选概率归零并把冷却设为 `birth_cooldown_minutes × 60` 秒；冷却按逻辑时间下降且期间概率强制为 0。马厩等级每升 1 级使概率增量增加 10%，不作用于成长或额外 HP；新生马从成长 0 开始，达到 0.6 视为成年但继续成长至 1.0。

## Enemy Wave

```json
{
  "id": "wave_01",
  "wave_number": 1,
  "trigger_day": 3,
  "trigger_hour": 18,
  "trigger_minute": 0,
  "trigger_second": 0,
  "spawn_point": "front_forest",
  "spawn_position": {
    "x": 0.0,
    "y": 0.0,
    "z": 29.0
  },
  "spawn_spread": {
    "x": 7.0,
    "z": 3.0
  },
  "enemies": [
    {
      "enemy_type_id": "raider_militia",
      "name": "掠袭民兵",
      "count": 3,
      "unit_type": "melee_infantry",
      "weapon_type": "sword_shield",
      "hp": 60,
      "max_hp": 60,
      "attack_power": 6,
      "defense": 1,
      "move_speed": 3.0,
      "attack_range": 1.5,
      "attack_interval": 2.4,
      "target_preference": ["front_gate", "warehouse", "main_hall"]
    }
  ],
  "notes": "第一波用于验证敌人生成闭环。"
}
```

T1101 起，`data/enemy_waves.json` 是数组，至少配置 5 波 Demo 敌人。`wave_number` 必须从 1 开始可排序；T1301 后 `trigger_day` / `trigger_hour` / `trigger_minute` / `trigger_second` 由 CombatSystem 按 TimeSystem 逻辑时间用于自动来袭，未配置分钟和秒时默认 0。`spawn_position` 使用 Godot 世界坐标，当前正门外生成区的 `z` 应在正门外侧；`spawn_spread` 用于把同组敌人横向/纵向错开，避免重叠生成。敌人组必须包含 `enemy_type_id`、`name`、`count`、`unit_type`、`weapon_type`、`hp`、`max_hp`、`attack_power`、`defense`、`move_speed`、`attack_range`、`attack_interval` 和 `target_preference`。`unit_type` 复用 NPC 兵种分类，例如 `melee_infantry`、`polearm_infantry`、`archer`、`crossbowman`、`cavalry`、`mounted_ranged`；骑乘敌人可额外提供 `mount_type`。T1102 起，`move_speed`、`attack_range`、`attack_interval`、`attack_power` 和 `target_preference` 会驱动敌人目标优先级、移动和敌方攻击；T1104 起，`defense` 会参与敌人受到我方攻击时的实际 HP 伤害计算，`hp` / `max_hp` 会随我方攻击扣除并在清零后移除敌人。T1104B 起，敌人 `attack_interval` 使用战斗动作秒，`move_speed` 也按 `game_delta_seconds / 60` 折算为战斗动作秒级位移。T1104C 起，`target_preference` 不应包含 `wall`，CombatSystem 也会过滤旧配置中的 `wall` / `front_wall`；敌人默认按城门、仓库、主厅推进，附近可行动 NPC 仍优先。T1104A 起，敌人 `move_speed` 和 `attack_interval` 不直接乘玩家 `x2` / `x4` 时间倍率；活动敌人存在期间由 TimeSystem `x1` 上限控制全局推进速度。这些字段仍不由 LLM 改写。

## Event Record

```json
{
  "event_id": "evt_day03_090000_doctor_01_unconscious",
  "day": 3,
  "time": "09:00:00",
  "type": "unconscious_started",
  "subject_npc_id": "doctor_01",
  "actor_ids": ["enemy_03"],
  "target_ids": ["doctor_01"],
  "location_id": "plaza",
  "visibility": "local_public",
  "importance": 85,
  "summary": "莉娜在广场战斗中被敌人击倒并昏迷。",
  "payload": {
    "hp_before": 18,
    "hp_after": 0,
    "damage": 18,
    "weapon_id": "raider_axe"
  }
}
```

事件通用字段：

- `event_id`：唯一事件 ID，建议包含日期、时间、主体 NPC 和类型，便于调试。
- `day` / `time`：权威游戏时间，来自 TimeSystem / GameState。
- `type`：事件类型，详见 `MEMORY_AND_INFO_SPACE.md`。
- `subject_npc_id`：事件所属 NPC，必填；事件首先写入该 NPC 的事件库。
- `actor_ids`：主动参与者，可包含 NPC、守备官、敌人或系统 ID；玩家身份的世界内 actor id 使用 `guard_officer`，面向 NPC / LLM 的显示文本称为“守备官”。
- `target_ids`：事件关联目标索引，可包含 NPC ID、地点 ID、建筑 ID、行动 ID、资源 ID、敌人 ID 等；它不是自然语言“宾语”，而是查询索引。
- `location_id`：事件发生地点；室外事件统一为 `plaza`。
- `visibility`：`private`、`local_public`。广场公开事件使用 `location_id == "plaza"` 的 `local_public`。
- `importance`：用于 LLM 摘要、见闻裁剪和首次睡眠总结。
- `summary`：短文本摘要。
- `payload`：事件类型专属属性。对话全文、战斗伤害数值、建筑状态变化等都放在这里。完整地点状态快照不应放进 `location_entered` / `location_exited` 亲历事件；进入地点时的完整状态应作为进入者的见闻记录。

`summary` 不由 LLM 生成，也不由通用主语/宾语规则自动推断。每个 `type` 必须有确定性 summary 模板和对应 payload schema：

```json
{
  "type": "work_completed",
  "summary_template": "{actor}完成了{action}，消耗{inputs}，产出{outputs}。",
  "required_payload_fields": ["action_id", "input_resources", "output_resources"]
}
```

格式化器负责把 ID 展开成显示名，例如 `blacksmith_01` 展开为格伦，`work_blacksmith` 展开为推进铁匠铺制造，`iron` 展开为铁。底层事件继续保存稳定 ID。

玩家相关事件的 summary 必须使用世界内称呼“守备官”，例如“守备官给了布鲁诺3枚第纳尔。”；不要在 NPC 记忆、见闻或 Prompt 摘要里输出以“玩家”为主语的旧式表述。

T0703 `order_assigned` 事件 payload：

```json
{
  "type": "order_assigned",
  "subject_npc_id": "veteran_deputy_01",
  "actor_ids": ["guard_officer"],
  "target_ids": ["veteran_deputy_01"],
  "visibility": "private",
  "summary": "守备官制定了新的指令。",
  "payload": {
    "previous_order_text": "留在广场观察情况。",
    "new_order_text": "优先协助修复围墙，并留意敌袭。",
    "order_revision": 2
  }
}
```

该事件只表示守备官改变了指令，不表示 NPC 已执行或同意执行。当前有效文本仍以 NPC 信息中的 `current_order` 为准。

T0019 `wake_up` 事件 payload：

```json
{
  "type": "wake_up",
  "subject_npc_id": "gardener_01",
  "actor_ids": ["gardener_01"],
  "target_ids": ["gardener_01"],
  "visibility": "private",
  "payload": {
    "day": 1,
    "hour": 6,
    "reason": "game_start"
  }
}
```

`wake_up` 表示 NPC 在指定游戏日和小时开始安排新一天。开局正式循环使用 `reason=game_start`；事件本身不代表 24 小时计划已成功生成，也不代表当前行动已开始，计划与行动事实仍分别由 `plan_created` 和具体行动事件记录。

T1001 `plan_created` 事件 payload：

```json
{
  "type": "plan_created",
  "subject_npc_id": "gardener_01",
  "actor_ids": ["gardener_01"],
  "target_ids": ["gardener_01"],
  "visibility": "private",
  "payload": {
    "plan_day": 1,
    "items": [],
    "source": "rule_default",
    "work_phase_count": 10
  }
}
```

`items` 保存 24 个小时计划项。正式真实每日计划的 `source` 必须是 `llm_plan_day`；`rule_default` 和 `mock_plan_day` 只用于显式调试。真实 provider 失败时不写入 `plan_created`，也不写入 `rule_plan_fallback`。该事件表示计划被制定，不代表计划项已经执行；后续执行仍由对应行动事件记录。

T1002 `plan_revised` 事件 payload：

```json
{
  "type": "plan_revised",
  "subject_npc_id": "gardener_01",
  "actor_ids": ["gardener_01"],
  "target_ids": ["gardener_01"],
  "visibility": "private",
  "payload": {
    "plan_day": 1,
    "items": [],
    "reason": "order_changed",
    "source": "llm_plan_revision",
    "summary": "Mock 将异常计划修订为等待状态。",
    "work_phase_count": 9
  }
}
```

`source` 正式路径固定为 `llm_plan_revision`。只有带非 Mock provider 证明且 `model_fallback_used=false` 的修订成功后才写 `plan_revised`；真实请求失败、Mock provider、响应越界或本地校验失败都不写事件、不覆盖当前计划。该事件表示 NPC 重新评估了计划；是否移动、工作、吃饭、睡觉或等待仍由随后当前小时计划执行和 `ActionSystem` 结算决定。

必备事件类型方向：

- 日常与计划：`wake_up`、`plan_created`、`plan_revised`、`reflection_started`、`sleep_started`、`sleep_ended`
- 移动与地点：`location_entered`、`location_exited`
- 工作与生活：`work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`、`prayer_started`、`prayer_completed`、`prayer_failed`、`visit_started`、`visit_completed`
- 对话：`dialogue_turn`；打开/关闭对话窗口不属于事件
- 玩家交互：`money_given`、`equipment_given`、`equipment_changed`、`order_assigned`；`order_assigned` 固定为 `private`。正式守备官惩戒攻击写入战斗 / 伤害类 `damage_taken`，payload 保留惩戒语境、攻击者和后续对话关联；`npc_attacked_by_player` 仅作为旧调试 / 兼容事件类型保留。
- 成长与状态：`skill_improved`、`npc_recruited`、`npc_left_recruited_state`
- 属性成长：`attribute_improved`，由玩家分配技能点到力量或智力时写入，payload 包含 `attribute`、`attribute_label`、`before`、`after`、`training_kind`；actor 为实际成长的 NPC
- 战斗与行为模式：`npc_mode_changed`、`combat_alarm_rang`、`combat_rally_started`、`combat_rally_encountered_enemy`、`combat_started`、`combat_ended`、`attack_made`、`damage_taken`、`low_hp_triggered`、`battle_psychology_result`、`morale_boost_started`、`morale_boost_ended`、`avoidance_started`、`avoidance_ended`、`unconscious_started`、`healing_started`、`healing_completed`、`healing_failed`、`revived`、`escape_started`、`escaped`、`escape_intervention_result`、`escape_speed_changed`
- 建筑与资源：`building_damaged`、`building_repaired`、`building_upgraded`、`resource_changed`
- 公告与商人：`plaza_notice_changed`、`merchant_arrived`、`merchant_departed`、`merchant_trade_completed`

T1507 商人事件 payload：

- `merchant_arrived` / `merchant_departed` 必须包含 `merchant_id`、`merchant_name`、`arrival_time`、`departure_time`、`visit_day`。
- `merchant_trade_completed` 必须包含 `merchant_id`、`direction`、`resource_id`、`amount`、`unit_price`、`total_price`、`money_delta`、`resource_delta`；运行时可额外保存 `merchant_name` 和 `resource_name` 供 UI/调试。
- 三类事件固定使用广场 `local_public`。只有资源结算成功后才能写 `merchant_trade_completed`；余额或库存不足不得用成功事件表达失败尝试。

T1104 起，`attack_made` 表示我方 NPC 对敌人完成了一次程序结算攻击。必备 payload 字段包括 `attacker_npc_id`、`target_type`、`target_enemy_id`、`damage`、`hp_before` 和 `hp_after`；运行时还会记录 `weapon_id`、`weapon_name`、`required_skill`、`weapon_skill`、`strength`、`base_damage`、`strength_multiplier`、`raw_attack_power`、`attack_speed_multiplier`、`target_defense`、`max_hp` 和 `defeated` 等调试字段。该事件只记录已经由 CombatSystem 扣除敌人 HP 的事实，不让 LLM 决定伤害。

T1104 起，敌人攻击 NPC 写入的 `damage_taken` payload 可额外包含 `raw_attack_power`、`target_defense` 和 `damage_after_defense`，用于说明敌人配置攻击力、NPC 盔甲防御和实际扣除 HP 的关系。玩家惩戒攻击与其他 NPC 伤害仍可复用 `damage_taken`，不要求这些额外字段。

T1106 起，`combat_started` 表示敌人波次已经生成并进入当前战斗流程。必备 payload 字段包括 `wave_number`、`enemy_count`、`enemy_roster`、`friendly_combatant_count` 和 `friendly_roster`；运行时还会记录 `wave_id`、`reason`、`noncombatant_count` 等调试字段。`enemy_roster` 以数组记录敌人 ID、名称、兵种 / 单位类型、HP、武器和数量来源；`friendly_roster` 以数组记录已入伍且持主武器 NPC 的 ID、姓名、兵种和主武器。该事件固定写入广场 `local_public`，用于表达敌袭开始和敌我态势，不负责权威伤害、资源或胜负结算。

T1106 起，`combat_ended` 表示当前战斗运行态已因敌军全灭、撤退或 GM 清敌结束。必备 payload 字段包括 `wave_number`、`enemy_count`、`injured_npcs`、`unconscious_npcs`、`defeated_by_npc` 和 `reason`；运行时还会记录 `wave_id`、`defeated_enemy_count`、`remaining_enemy_count` 和 `started_event_id`。`injured_npcs` / `unconscious_npcs` 统计本场所有 NPC，不限于已入伍人员；`defeated_by_npc` 按 NPC 记录击退数量和敌人列表。该事件同样固定写入广场 `local_public`，只表达本场已发生的程序事实。

T0603 对话事件 payload 建议：

```json
{
  "type": "dialogue_turn",
  "payload": {
    "speaker_id": "guard_officer",
    "speaker_name": "守备官",
    "listener_id": "cook_01",
    "listener_name": "布鲁诺",
    "text": "守备官请求你应征，帮忙守住驿站。",
    "is_recruitment_request": true,
    "recruitment_result": "accept",
    "dialogue_round": 1,
    "max_rounds": 999999
  }
}
```

对话事件首先进入说话者与听者双方的事件库；如果事件 `visibility == "local_public"`，再由事件地点按公开规则广播给同地点第三者的见闻库。后端 `/npc/dialogue` 只返回回复文本与意向，不直接写入该 payload。

T0029/T0030 后，自主 NPC-NPC 对话邀请也复用 `dialogue_turn`，payload 额外包含 `dialogue_phase="invitation"` 与 `invitation_result="accept|reject"`；邀请交换的 `current_round` 为 0。接受后的正式回复使用 `dialogue_phase="conversation"`、`invitation_result="not_applicable"`、`max_rounds=0`、`soft_round_threshold=5`、`soft_round_guidance` 与逐轮 `should_end_dialogue`。其中 `max_rounds=0` 是“无程序硬上限”哨兵，不是零轮结束。邀请开场 / 决定进入历史和双方事件库，但不增加正式轮次；结束标记所在回复作为最后一句入库后直接结束，不产生下一次 LLM 请求。

T0402 当前运行时查询接口：

- `get_all_events()` / `get_event_log()`：返回当天全局事件索引中的事件副本。
- `get_npc_daily_events(npc_id)`：返回某 NPC 当天亲历事件。
- `get_npc_witness_events(npc_id)`：返回某 NPC 当天见闻事件，当前为后续即时广播接收预留。
- `get_plaza_events()`：返回 `location_id == "plaza"` 且 `visibility == "local_public"` 的广场事件。
- `get_required_payload_fields(type)`：返回指定事件类型的必需 payload 字段声明。

T0402 已接入的行动事件 payload：

```json
{
  "type": "work_completed",
  "payload": {
    "action_id": "work_garden",
    "input_resources": {},
    "output_resources": {"grain": 3},
    "building_hp_restore": 0,
    "needs_profile": "heavy_work",
    "workstation_id": "garden_plot_01",
    "building_id": "garden",
    "base_duration_seconds": 3600,
    "duration_seconds": 2572,
    "efficiency_multiplier": 1.4
  }
}
```

T0501 已接入的伤害与昏迷事件 payload：

```json
{
  "type": "damage_taken",
  "payload": {
    "damage": 18,
    "hp_before": 18,
    "hp_after": 0,
    "damage_source": "guard_officer"
  }
}
```

`unconscious_started` 使用同样的 `damage`、`hp_before`、`hp_after`、`damage_source` 字段，并以 `local_public` 写入 NPC 当前信息地点。

`building_damaged` 由 `BuildingSystem.apply_damage_to_building(...)` 写入，当前用于敌人攻击建筑。payload 包含 `building_id`、`building_name`、`damage`、`hp_before`、`hp_after` 和 `damage_source`；事件地点固定为 `plaza`，可见性默认为 `local_public`，用于把城门、仓库或主厅受损广播给广场当前在场 NPC。围墙仍可通过其他系统受损、修复或升级，但 T1104C 起不是敌人规则攻击目标。主厅 HP 清零后的失败状态写入 `GameState`，不由事件系统直接判定胜负。

T1103 已接入的警铃与集结事件 payload：

```json
{
  "type": "combat_rally_started",
  "payload": {
    "source": "hud",
    "unit_type": "mounted_ranged",
    "unit_type_label": "骑射单位",
    "rally_location_id": "front_gate",
    "rally_location_name": "城门外防线",
    "formation_row": "back",
    "formation_index": 0,
    "has_mount": true
  }
}
```

`combat_alarm_rang` 会写入所有 NPC 的亲历事件库，payload 至少包含 `source`、`npc_count` 和 `active_enemy_count`；未集结原因保留在 `CombatSystem.trigger_combat_alarm(...)` 的返回结果 `ignored` 列表中，不逐个写入警铃事件 payload。`combat_rally_started` 只写给实际开始集结的 NPC；`combat_rally_encountered_enemy` 在集结途中接敌时写入，payload 包含 `enemy_id`、`enemy_name`、`distance` 和 `has_mount`。这些事件只表达警铃、集结、接敌事实，不表达我方攻击、敌人伤害或战斗结算。

行为模式与后续战时心理事件 payload：

```json
{
  "type": "battle_psychology_result",
  "payload": {
    "trigger": "wartime_dialogue",
    "decision": "morale_boost",
    "source_event_id": "evt_day03_101500_veteran_dialogue",
    "battlefield_context_summary": {
      "enemy_count": 4,
      "friendly_combatant_count": 2,
      "noncombatant_count": 5
    }
  }
}
```

低血量触发事件示例：

```json
{
  "type": "low_hp_triggered",
  "payload": {
    "hp_before": 100,
    "hp_after": 25,
    "max_hp": 100,
    "damage": 75,
    "damage_source": "wave_01_enemy_001",
    "damage_event_id": "evt_day01_060000_cook_01_damage_taken_0004",
    "threshold_ratio": 0.3,
    "behavior_mode": "avoid_combat",
    "combatant_decisions_allowed": false,
    "wave_number": 1,
    "wave_id": "wave_01",
    "active_enemy_count": 3
  }
}
```

T1103A 已实现的 `npc_mode_changed` 使用 `npc_id`、`from_mode`、`from_mode_label`、`to_mode`、`to_mode_label`、`reason`。T1103D 起，`npc_mode_changed` 不再覆盖 `work <-> combat` 与 `work <-> avoid_combat` 的互转，这些互转也不通过该事件广播；战斗和避战信息由更具体的攻击、伤害、避战开始 / 结束等事件表达。T1103B/T1103C 已实现的 `avoidance_started` 使用 `enemy_id`、`enemy_name`、`distance`、`reason`、`target_id`、`target_name` 和 `target_position` 记录非战斗人员开始避战；`avoidance_ended` 使用 `reason`、`active_enemy_count`、`target_id` 和 `target_name` 记录避战结束。`morale_boost_started` / `morale_boost_ended` 记录程序已应用或清除的斗志 buff，T1202 起 `morale_boost_started.trigger` 可为 `low_hp`。`battle_psychology_result.trigger` 可为 `wartime_dialogue`、`low_hp` 或后续逃离挽留来源。低血量自身心理判定没有守备官本轮文本，需通过 `battlefield_context_summary` 保留简化战局依据。

T1105 已实现的 `combat_strategy_selected` 使用 `npc_id`、`strategy_id`、`strategy_label`、`unit_type` 和 `unit_type_label`，记录守备官通过 NPC 面板或装备变更默认化流程为某名入伍持武器 NPC 设置当前战斗策略。该事件只表达策略选择事实，不直接结算移动、攻击、HP 或资源。

T0502 已接入的复苏事件 payload：

```json
{
  "type": "revived",
  "payload": {
    "hp_before": 28,
    "hp_after": 30,
    "recovery_source": "natural_recovery"
  }
}
```

`revived` 在 NPC 自然恢复到 Max HP 30% 后写入，按 NPC 当前信息地点以 `local_public` 广播。

T0503 已接入的治疗事件 payload：

```json
{
  "type": "healing_started",
  "payload": {
    "action_id": "assist_heal",
    "healer_npc_id": "doctor_01",
    "target_npc_id": "cook_01",
    "money_spent": 1,
    "max_helpers": 2
  }
}
```

`healing_completed` 使用 `healer_npc_id`、`target_npc_id` 和 `money_spent` 字段，不写入原因字段。`healing_failed` 额外要求 `reason`，用于第纳尔不足、离开治疗地点等已经开始但未正常完成的中止；失败不能写成 `healing_completed`。治疗开始/完成/失败会分别写入治疗者和目标 NPC 的事件库，并写入目标当前信息地点其他在场 NPC 的见闻库；事件信息不暴露医术熟练度。`revived` 的 summary 只表达 NPC 苏醒，不展示 HP 恢复到多少。

T0404 adds plaza state event types: `plaza_notice_changed` and `plaza_status_changed`; T0403/T0405 now also use `location_status_changed` for current building-state broadcasts. T1506 routes NoticeBoardPanel input through `set_plaza_notice(...)`, while the authoritative `current_notice` remains in the plaza node and duplicate text does not create another event. T1507 adds plaza-public merchant arrival, departure, and completed-trade event types. Plaza snapshots use `building_external_states` for every building's propagatable external state; `key_entities` is kept as a compatibility alias for that same external-state dictionary. The plaza itself has no building HP and exposes `has_building_hp == false` and `current_enemy_count`. Status event summaries must name the specific building and concrete state that changed, without generic prefixes such as "建筑状态更新".

Revised event payload rule: `location_entered` and `location_exited` only store movement facts such as `from_location_id` and `to_location_id`. They do not store full `location_snapshot` payloads. The entering NPC receives one separate witness entry containing the current location snapshot. A plaza entry snapshot includes current plaza `people_present`, plaza `people_statuses`, current notice text, and every building's propagatable external state. An enterable-building entry snapshot also includes `people_statuses`, where each present NPC has a parallel life status and concise Chinese action status. NPCs already present receive only the local public enter/exit event; they do not receive a duplicate full `people_present` or `people_statuses` snapshot. Later state events should carry changed fields only, such as a changed building condition, a level change, a notice change, or one workstation occupancy change. Indoor-to-indoor movement should be represented as two location transitions through `plaza`.

## NPC Daily Memory

```json
{
  "npc_id": "doctor_01",
  "day": 3,
  "event_log": [
    "evt_day03_083000_doctor_01_location_entered",
    "evt_day03_090000_doctor_01_unconscious"
  ],
  "witness_log": [
    "evt_day03_084500_stableman_01_escape_started"
  ]
}
```

`event_log` 和 `witness_log` 都保存事件 ID，具体事件内容由 MemorySystem 的事件存储查询。这样可以避免重复复制大 payload，也能区分亲历与听闻。

T1004/T1005 起，首次睡眠总结完成后会清空指定 NPC 当天 `event_log` / `witness_log` 索引，作为短期缓存轮转；全局事件索引仍保留给调试查询和后续存档任务。

## Location / Building Info Node

地点/建筑信息节点只描述当前状态和广播所需的路由信息，不保存事件历史。`current_public_note_ids` / `public_notes` 用于当前公告或命令；普通建筑不拥有公告牌字段，当前公告文本只保存在广场状态中。公开事件发生时由节点即时转发给当时在场的 NPC，接收者把事件写入自己的 `witness_log`。NPC 进入地点时，完整当前状态只写给进入者的见闻库；已经在场的 NPC 通过 `location_entered` / `location_exited` 事件得知人员变化，不再接收完整 `people_present` 或 `people_statuses` 状态。除进入者的一次性快照外，状态广播应使用字段级差量。

```json
{
  "id": "chapel",
  "name": "小教堂",
  "kind": "enterable_building",
  "external_state": {
    "level": 1,
    "condition": "intact"
  },
  "internal_state": {
    "people_present": ["priest_01", "doctor_01"],
    "people_statuses": [
      {
        "npc_id": "priest_01",
        "name": "马塞尔",
        "life_status": "healthy",
        "life_status_text": "健康",
        "healer_npc_ids": [],
        "healer_names": [],
        "action_status": "待命"
      },
      {
        "npc_id": "doctor_01",
        "name": "莉娜",
        "life_status": "unconscious",
        "life_status_text": "昏迷，马塞尔正在治疗",
        "healer_npc_ids": ["priest_01"],
        "healer_names": ["马塞尔"],
        "action_status": "昏迷"
      }
    ],
    "workstations": [
      {
        "id": "altar",
        "status": "occupied",
        "occupied_by": "priest_01"
      }
    ],
    "special_state": {}
  },
  "current_public_note_ids": [],
  "public_notes": []
}
```

广场是特殊地点：

```json
{
  "id": "plaza",
  "name": "广场",
  "kind": "plaza",
  "people_present": ["stableman_01", "veteran_deputy_01"],
  "people_statuses": [
    {
      "npc_id": "stableman_01",
      "name": "托马",
      "life_status": "healthy",
      "life_status_text": "健康",
      "healer_npc_ids": [],
      "healer_names": [],
      "action_status": "待命"
    },
    {
      "npc_id": "veteran_deputy_01",
      "name": "艾达",
      "life_status": "injured",
      "life_status_text": "受伤",
      "healer_npc_ids": [],
      "healer_names": [],
      "action_status": "协助修复围墙"
    }
  ],
  "current_notice": "今晚在主厅前集合。",
  "current_public_note_ids": [],
  "public_notes": [],
  "building_external_states": {
    "main_hall": {
      "level": 1,
      "condition": "intact",
      "is_enterable": false,
      "operational_efficiency": 1.0
    },
    "chapel": {
      "level": 1,
      "condition": "intact",
      "is_enterable": true,
      "operational_efficiency": 1.0
    }
  }
}
```

主厅、围墙、城门、后门、仓库等不可进入实体不作为 NPC 常规进入地点；它们只提供可传播外部状态，不暴露内部 NPC、NPC 状态或位置状态。所有建筑的外部 `level / condition / is_enterable / operational_efficiency` 进入广场 `building_external_states`，其中 `operational_efficiency` 是供 NPC 信息传播的离散分档值；HP、Max HP、精确效率和剩余修复 / 升级时长不直接作为 NPC 见闻字段。可进入建筑内部的位置数量不使用额外聚合数字广播；容量变化通过按位置 ID 的新增 / 移除差量表达，改名、改类型和占用变化同理。NPC 进入广场时，应在进入者的见闻库写入当前广场在场 NPC、这些 NPC 的生命状态 / 行动状态和这些建筑当前外部状态，不写公告牌当前通告、参考日程或非强制备注；公告牌两页只在守备官发布实际变更时通过各自事件向全站可接收见闻的 NPC 广播一次。`location_entered` 事件本身只记录进入广场的行动事实，不包含过去事件历史。

T0035/T0037 后的当前 `special_state` 示例：铁匠铺 / 工械坊使用 `{"production":{"target_item_id":"item_sword_shield","target_name":"剑盾","completed_stages":2,"total_stages":4,"current_stage_index":3,"current_stage_name":"锻造配件"}}`；马厩使用 `{"horses":{"total":2,"adult":2,"foal":0}}`。这两个结构都是室内状态，严禁复制进上方广场 `building_external_states`。在场增量沿用 `location_status_changed`，`reason` 固定为 `building_internal_special_state_changed`，变化字段放入 `changed_special_state`；周期小数进度和马匹个体详情不允许出现在该 payload。

## LLM Dialogue Response

T0601 后，后端 AI Schema 放在 `backend/schemas/`，使用 Pydantic 定义。Schema 是前后端数据合同，不调用真实模型，不执行 HP、资源、建筑、移动或战斗等权威结算。

共享上下文位于 `backend/schemas/common.py`：

- `GameTime`：`day`、`time`、`hour`。
- `ModelRequestMeta`：`request_id`、`call_type`、来源、是否需要 TimeSystem 慢速、关联事件 id。
- `NPCContext`：NPC 身份、运行时状态、短期记忆摘要、`long_term_memory={knowledge_graph, diary}`、当前地点上下文和广场上下文；T0703A 后还包含当前 `current_order`。其中 `NPCIdentity` 在 T0061 后只保留宽松 `speech_style`，不再包含 `signature_lines`。
- `ShortTermMemoryContext`：分开的 `experienced_events` 与 `witnessed_events`。
- `ActionCandidate`：后续计划/修订可选择的行动候选。

对话 Schema 位于 `backend/schemas/npc_ai.py`：

- `NPCDialogueRequest`：覆盖 `player_npc`、`npc_npc`、`escape_intervention`。T0603 后输入以目标 NPC `npc_id` / `npc_name` / `npc_setting`，说话者 `speaker_name` / `speaker_text` / `speaker_context`，`is_recruitment_request`，`current_round` / `max_rounds`，`npc_state`，`dialogue_state`，`short_memory`，`long_memory` 和 `location_context` 为主。T0041 要求 `allowed_actions` 至少一条，并与每日计划复用 `data/action_defs.json` 驱动的动态候选构造链路；它只表示目标 NPC 的对话能力边界，不是计划或已执行行动。T0029 新增 `dialogue_phase=conversation|invitation`；T0030 要求 NPC-NPC 请求顶层与 `dialogue_state` 的 `max_rounds` 都为 0，并携带一致的 `soft_round_threshold` 与非空 `soft_round_guidance`。T0061 后 `npc_setting` 和共享 `NPCIdentity` 只携带宽松 `speech_style`，不再携带 `signature_lines`。T1201 后，战时公开对话额外携带 `interaction_context` 和 `battlefield_context`。逃离挽留中的玩家消息使用 `interaction_context == "escape_intervention"` 和 `escape_intervention_round`；逃离挽留攻击不构造该请求。
- 对话响应：T0087 后玩家、NPC-NPC 与逃离挽留分别使用三个封闭 Schema。NPC-NPC 请求必须由目标 NPC 回复且 `response_kind=reply_to_npc`；邀请阶段 `invitation_result=accept|reject`，拒绝要求 `should_end_dialogue=true`，接受不得在正式对话开始前结束；正式回复使用 `invitation_result=not_applicable`。玩家对话使用 `response_kind=reply_to_player`，应征只由 `recruitment_result` 表达；集结 / 战斗下符合资格者可返回 `wartime_reaction=none|escape|morale_boost`。逃离挽留使用 `response_kind=reply_to_player` 与 `escape_intervention_result=stay|leave`。征召状态、工作打断、战时 buff、逃离、模式切换和事件写入仍由 Godot 权威系统完成。

T0703A 后，`backend/schemas/common.py` 使用 `CurrentOrderContext` 规范化当前文本、发布者、最近发布时间和修订号。共享 `NPCContext` 和 `NPCDialogueRequest` 都包含 `current_order`；`DailyPlanRequest`、`PlanRevisionRequest`、战时公开对话、低血量自身心理判定、主动交涉、逃离判断、首次睡眠总结和知识图谱更新等 NPC 中心请求复用同一字段。该字段是参考上下文，不是权威行动或 system prompt。

## LLM Battle Judgement Response

战斗判定 Schema：

- `BattleJudgementRequest`：取消旧式 `combat_started` 全员判定语义；T1202 后主要用于触发类型 `low_hp`，并保留后续 `escape_check`，包含 NPC 上下文、`combat_context`、`battlefield_context` 和 Godot 提供的允许判定结果。
- `BattleJudgementResponse`：返回 `join_battle`、`avoid_battle`、`continue_fighting`、`escape_station` 或 `inspired` 等意向，以及情绪和调试原因。T1202 中，参战 NPC 允许继续参战、逃离或斗志激昂；避战 / 非战斗人员只允许继续避战或逃离。伤害、buff、移动、逃离和模式状态仍由 Godot 结算。

其他 T0601 后端 AI Schema：

- `DailyPlanRequest` / `DailyPlanResponse`：每日计划；业务响应必须包含 24 条 `PlanItem`。
- `PlanRevisionJudgementRequest` / `PlanRevisionJudgementResponse`：对话与日常行动失败共用的计划影响范围判别。两类都携带动态 `station_context`、统一 NPC 人设 / 状态 / 指令 / 长短期记忆 / 地点、候选与实时环境及原 24 小时计划；`trigger_kind=dialogue` 另要求本轮完整 `dialogue_history`、结束原因和会话元数据，`trigger_kind=action_failure` 另要求程序权威 `failed_plan_item`、`failure_type`、`failure_summary`、必要 `failure_context`、当前 / 建议工作阶段数。工作数量字段为 Prompt 统计兼容项，不是响应接受门槛。输出仍只有空或精确 `revision_hours`，不输出计划项。
- `PlanRevisionRequest` / `PlanRevisionResponse`：通用判别非空或其他程序直接触发后的指定小时计划修订；既有完整修订上下文继续保留，响应小时必须与请求 `revision_hours` 完全一致。
- `DailyReflectionRequest` / `DailyReflectionResponse`：首次睡眠总结、增量日记和替换式知识图谱键值更新。
- `KnowledgeGraphUpdateRequest` / `KnowledgeGraphUpdateResponse`：独立知识图谱更新。
- `ProactiveIntentionRequest` / `ProactiveIntentionResponse`：NPC 是否主动找守备官交涉。
- `PlayerStrategyClassificationRequest` / `PlayerStrategyClassificationResponse`：把守备官话术分类为说服、利诱、威胁、欺骗、安抚、交易、命令或未知。

T0049/T0050 后，六个正式业务端点 `/npc/dialogue`、`/npc/plan_revision_judgement`、`/npc/plan_day`、`/npc/revise_plan`、`/npc/battle_judgement`、`/npc/daily_reflection` 的成功传输体统一额外附加 `model_provider`、`model_name`、`model_fallback_used` 和 `model_normalizations`；该数组在非计划接口及未规范化时为空。字段由后端根据 Model Adapter 结果与确定性候选规范化注入，不属于 LLM 输出 Schema；Godot 用来源字段校验真实结果，不能再把真实成功硬编码为 `mock_*`。旧 `/npc/dialogue_plan_revision_judgement` 保留为同一处理函数的兼容 URL。
