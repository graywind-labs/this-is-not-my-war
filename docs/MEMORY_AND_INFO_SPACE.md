# MEMORY_AND_INFO_SPACE.md

## 模块目标

记忆系统用于让 NPC 记住自身经历、玩家行为、地点见闻、战斗事件和他人公开遭遇，并在后续计划、对话、征召、逃离、战斗判定、首次睡眠反思中产生影响。

本模块的底层不是“给 LLM 拼一段记忆文本”，而是一套类似埋点系统的事件触发、记录和传播架构。游戏中的事实先被程序记录为事件，再按规则进入 NPC 事件库；公开事件会即时广播到地点/建筑信息节点，由节点转发给当时在场的 NPC，并写入接收者的 NPC 见闻库和后续长期记忆。地点/建筑信息节点不是事件仓库。

世界内称呼规则：所有写入 NPC 事件库、见闻库、Prompt 摘要、首次睡眠总结输入、公告/教学信件等 NPC 可见或 LLM 会当作世界内事实理解的文本，均把玩家称为“守备官”。“玩家”只能用于开发文档和调试命令说明；事件 summary 不得输出以“玩家”为主语的出戏表述。

## 核心原则

- 每个事件必须关联一个 `subject_npc_id`，并首先写入该 NPC 的事件库，表示“这件事发生在他身上”。
- 每个事件必须有 `location_id`。室外事件统一归入 `plaza`。
- 事件库和见闻库分开：事件库记录亲历，见闻库记录 NPC 当场接收到的公开事件广播、状态广播、公告和公开消息；NPC 不会因为进入地点而继承该地点过去发生的事件。
- 昏迷 NPC 不接收地点/广场公开广播、状态变化广播、公告或进入快照；其见闻库在昏迷期间暂停更新，直到复苏。亲历事件库不受影响，仍记录受伤、昏迷和复苏等发生在自己身上的事件。
- 睡觉 NPC 与昏迷 NPC 一样不接收见闻；当某 NPC 的 `current_action` 为 `sleep_in_dormitory` 时，同建筑内发生的 `local_public` 事件、地点/建筑状态广播、公告或进入快照都不会写入该 NPC 的见闻库。睡醒并回到可行动状态后，从后续广播开始重新接收见闻，不补收睡觉期间错过的信息。亲历事件库仍记录自己的 `sleep_started` / `sleep_ended`。
- 进入/离开地点的事件库记录只表达行动事实；完整地点状态只作为进入者的一次性见闻，且不再重复写进进入事件。
- 进入地点时，进入者的一次性快照必须包含该地点当前在场 NPC 状态；广场也按地点处理。该状态分为生命状态和行动状态两个平行类别：生命状态只表达健康、受伤、昏迷；昏迷者如有治疗者，写明治疗者是谁。行动状态解析 `current_action` 并翻译成精简中文。
- 除进入者的一次性地点状态快照外，建筑和地点状态见闻只传递变化字段，不重复传递未变化的完整快照。
- 当天事件库 + 当天见闻库共同构成 NPC 的短期记忆。
- 对话全文作为对话事件的属性保存，不单独建立谈话库；A 与 B 的对话轮次首先进入 A 和 B 的事件库，而不是彼此的见闻库。只有 `visibility == "local_public"` 的对话事件，才按地点公开规则广播给同一地点当前在场且可接收见闻的第三者。
- 已入伍 NPC 的当前指令 `current_order` 是 NPC 信息中的持续状态，不属于地点状态。指令内容变化时生成 `private` 的 `order_assigned` 事件，只进入目标 NPC 事件库，不广播到地点或广场；当前指令还应独立注入后续 NPC LLM 请求，不能只依赖事件摘要保留。
- LLM 只解释和回应事件，不负责资源、HP、建筑、战斗等权威结算。
- 面向 NPC / LLM 的玩家相关事件摘要必须使用“守备官”作为称呼；底层可保留稳定技术 ID，但不把“玩家”作为世界内人物名输出。

## 事件结构

事件通用字段：

| 字段 | 说明 |
|---|---|
| `event_id` | 唯一事件 ID |
| `day` / `time` | 游戏日与发生时间 |
| `type` | 事件类型 |
| `subject_npc_id` | 事件所属 NPC，必填 |
| `actor_ids` | 主动参与者，包含 NPC / 守备官 / 敌人 / 系统 |
| `target_ids` | 事件关联目标索引，包含 NPC / 地点 / 建筑 / 行动 / 资源 / 敌人等 ID |
| `location_id` | 发生地点；室外统一为 `plaza` |
| `visibility` | `private`、`local_public` |
| `importance` | 重要度，用于摘要、筛选和长期记忆压缩 |
| `summary` | 给 UI、调试和摘要使用的短文本 |
| `payload` | 类型专属结构化属性 |

`target_ids` 不是自然语言里的“宾语”字段。它是程序索引字段，用来支持查询“哪些事件关联了某个 NPC / 地点 / 建筑 / 行动 / 资源 / 敌人”。例如 `location_entered` 的目标可以是地点 ID，`work_started` 的目标可以同时包含建筑 ID 和行动 ID，`resource_changed` 的目标可以包含资源 ID。

`visibility` 规则：

- `private`：只进入 `subject_npc_id` 的事件库。
- `local_public`：进入 `subject_npc_id` 事件库，并即时广播到所属地点/建筑信息节点；节点转发给当时已经在场的 NPC 后不保存该事件。广场是普通地点，因此广场公开信息统一使用 `location_id == "plaza"` 的 `local_public`。

## Summary 生成规则

`summary` 必须由确定性模板生成，不使用 LLM 总结，也不依赖通用主语/宾语规则自动拼句。

每种事件类型必须定义：

- summary 模板。
- 模板需要读取的 `payload` 字段。
- 可选的 ID 展开规则，例如 NPC id 展开为姓名和职业背景，地点 id 展开为显示名，资源 id 展开为中文名。

示例：

| 事件类型 | 模板 | 关键 payload |
|---|---|---|
| `location_entered` | `{actor}进入了{to_location}。` | `to_location_id`, `from_location_id` |
| `location_exited` | `{actor}离开了{from_location}。` | `from_location_id`, `to_location_id` |
| `plan_created` | `{actor}制定了第{day}天的行动计划，包含{work_phase_count}个工作阶段。` | `plan_day`, `items`, `work_phase_count` |
| `plan_revised` | `{actor}重新评估了当前计划：{summary}。` | `plan_day`, `items`, `reason`, `source`, `summary` |
| `work_started` | `{actor}开始在{location}进行{action}。` | `action_id`, `workstation_id` |
| `work_completed` | `{actor}完成了{action}，消耗{inputs}，产出{outputs}。` | `action_id`, `input_resources`, `output_resources` |
| `repair_assist_started` | `{actor}开始协助修复{location}。` | `action_id`, `building_id`, `engineering_skill` |
| `upgrade_assist_started` | `{actor}开始协助升级{location}。` | `action_id`, `building_id`, `engineering_skill` |
| `dialogue_turn` | `{speaker}对{listener}说：{text}` | `dialogue_id`, `participant_npc_ids`, `dialogue_text`, `speaker_name`, `listener_name`, `speaker_text`, `reply_text`, `visibility`, `current_round`, `max_rounds`, `is_recruitment_request`, `recruitment_result` |
| `order_assigned` | `守备官制定了新的指令。` | `previous_order_text`, `new_order_text`, `order_revision`；T0703 已实现，固定为 `private` |
| `damage_taken` | `{target}受到{actor}造成的{damage}点伤害。` | `damage`, `hp_before`, `hp_after` |
| `healing_started` | `{healer}开始在{location}协助治疗{target}。` | `healer_npc_id`, `target_npc_id`, `money_spent` |
| `healing_completed` | `{healer}结束了对{target}的治疗。` | `healer_npc_id`, `target_npc_id`, `money_spent` |
| `revived` | `{target}在{location}苏醒了。` | `hp_before`, `hp_after`, `recovery_source` |
| `skill_improved` | `{actor}在{location}训练或工作，{skill}略有长进。` | `skill_name`, `amount`, `reason`；T0904 后 payload 还包含 `experience_gained`、`total_experience`、`skill_points_gained`、`unspent_skill_points` |
| `attribute_improved` | `守备官为{target}分配了1点技能点，{attribute}从{before}提高到{after}。` | `attribute`, `attribute_label`, `before`, `after`, `assigned_by`；技能点由玩家分配，不由 AI 自动消耗 |

`actor_ids`、`target_ids` 和 `location_id` 负责保留稳定事实属性；summary 模板负责 UI、调试日志和 prompt 摘要。不要把事件系统做成试图从任意主宾关系自动生成句子的万能事件句子生成器。

## 必备事件类型

T0402 的底层架构至少应为以下事件类型预留类型常量、payload 扩展和查询能力：

- 日常与计划：`wake_up`、`plan_created`、`plan_revised`、`reflection_started`、`sleep_started`、`sleep_ended`。
- 移动与地点：`location_entered`、`location_exited`。
- 工作与生活：`work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`。
- 对话只记录实际完成的 `dialogue_turn`。每轮文本、说话者名称、听者名称、是否提出应征、征召结果、当前轮次、最大轮次、是否承诺/威胁/欺骗等都写入 `payload`；打开或关闭对话窗口不入库、不广播。T1006 起，玩家发送消息后如果在 NPC 回复完成前结束 / 关闭对话，该次 LLM 请求会取消，未完成轮次不写 `dialogue_turn`，也不触发对话结束重评估。NPC 主动交涉的发起意图和预先确定的开场问题分别写入 `proactive_talk_started` / `proactive_talk_message`，玩家后续回复再走正常 `dialogue_turn`。
- 玩家交互：`money_given`、`equipment_given`、`equipment_changed`、`order_assigned`。`order_assigned` 固定为 `private`，完整新旧指令写入 payload。正式守备官惩戒攻击写入 `damage_taken`，并在 payload 中保留惩戒语境、攻击者和后续对话关联；`npc_attacked_by_player` 仅作为旧调试 / 兼容事件类型保留。
- 主动交涉：`proactive_talk_started`、`proactive_talk_message`。前者记录 NPC 发起主动交涉和计划中确定的问题，固定为 `private`；后者记录玩家点击气泡后 NPC 对守备官说出的开场问题。
- 成长与状态：`skill_improved`、`attribute_improved`、`npc_recruited`、`npc_left_recruited_state`。
- 战斗：`combat_started`、`combat_ended`、`attack_made`、`damage_taken`、`low_hp_triggered`、`unconscious_started`、`healing_started`、`healing_completed`、`revived`、`escape_started`、`escaped`。
- 建筑与资源见闻：`building_damaged`、`building_repaired`、`building_upgraded`、`resource_changed`。

第一版实现可以只接入少量现有行动事件，但接口与数据结构不得把未来事件类型堵死。

## 当前实现状态

T0402 已实现结构化事件底座，T0403 已实现地点信息节点与进入快照，T0404 已实现广场公开信息即时广播，T0405 已实现 NPC 短期记忆容器：

- `MemorySystem` 是当前事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场公开事件查询。地点/广场节点不应成为事件历史存储，MemorySystem 也不提供按地点查询事件的长期接口。
- `add_event(event)` 会规范化事件字段，补齐 `event_id`、`day`、`time`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary` 和 `payload`，并要求事件具备 `subject_npc_id`。
- 每个事件首先写入 `subject_npc_id` 对应 NPC 的当天事件库；`local_public` 事件会即时广播给事件地点当前在场 NPC，并写入接收者见闻库。广场事件也走同一规则，地点为 `plaza`。
- 现有 `ActionSystem` 已写入 `work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`、`sleep_started`、`sleep_ended` 和工作 / 训练 / 诊所成长使用的 `skill_improved`。T0904 后 `skill_improved` payload 同步记录经验和技能点变化；玩家把技能点分配到力量或智力时，`NPCSystem` 写入 `attribute_improved`，固定为 `private`。工作/训练/吃饭/睡觉按 `local_public` 写入，会即时广播给同地点当前在场 NPC 的见闻库；协助修复/协助升级也按 `local_public` 写入，事件地点为 `plaza`，会广播给广场当前在场 NPC。`NPCSystem` 到达地点时写入 `location_entered`。
- T1001 起，`DailyPlanSystem` 生成规则版每日计划时写入 `private` 的 `plan_created` 事件。T1003 起，`/npc/plan_day` Mock 成功和规则降级每日计划也写入同一事件。payload 包含 `plan_day`、24 个小时计划项 `items`、`source`（`rule_default` / `mock_plan_day` / `rule_plan_fallback`）和 `work_phase_count`；该事件只表示 NPC 制定了计划，不代表其中任一行动已经完成。T1002 起，计划异常或指令变化后的修订写入 `private` 的 `plan_revised` 事件，payload 记录修订后的 24 小时计划、触发原因、来源 `mock_revision` 或 `rule_revision_fallback` 和摘要；该事件仍不代表资源、HP 或工作产出已结算。
- 已提供 `get_all_events()`、`get_npc_daily_events(npc_id)`、`get_npc_witness_events(npc_id)`、`get_npc_short_term_memory(npc_id)`、`get_npc_short_term_memory_ids(npc_id)`、`get_plaza_events()` 和对应调试接口。
- T1004/T1005 起，`clear_npc_short_term_memory(npc_id)` 可清空指定 NPC 当天事件库和见闻库索引，用于首次睡眠总结完成后的短期缓存轮转；该接口不删除 `_events_by_id` 和全局事件列表，因此调试工具仍可查看当天原始事件档案。
- 玩家非对话交互可通过 `record_player_interaction(...)` 写入目标 NPC 事件库，并按 `private` / `local_public` 可见性即时广播；当前已有 `debug_record_player_money_given(...)` 和 `debug_record_player_attack_npc(...)` 用于验证给钱与攻击事件。T0704 后，`NPCPanel` 已接入前端入口：给钱由 `NPCSystem.give_money_to_npc(...)` 扣除全局第纳尔、增加目标 NPC 随身金钱并写入 `money_given`。T1006 起，正式玩家攻击入口移动到 `DialogPanel`：攻击按钮复用 `NPCSystem.apply_damage_to_npc(...)` 写入带惩戒文案的 `damage_taken`，不重做扣血和昏迷链路；随后请求 NPC 对攻击作出对话回复，回复成功时再写 `dialogue_turn.payload.interaction_kind == "guard_attack"`。若玩家在攻击回复返回前结束对话，攻击事件不撤销，未完成回复不写 `dialogue_turn`，但结束时触发一次计划重评估。T0901 后，装备武器/盔甲/坐骑由 `EquipmentSystem` 结算库存与槽位，再复用 `record_player_interaction(...)` 写入 `equipment_given` / `equipment_changed`。
- T0501 起，NPC 权威扣血由 `NPCSystem.apply_damage_to_npc(...)` 写入 `damage_taken`；HP 清零时额外写入 `unconscious_started`，并按 NPC 当前信息地点以 `local_public` 广播给同地点 NPC。T0502 起，NPC 自然恢复到 Max HP 30% 后写入 `revived`，同样按当前信息地点以 `local_public` 广播给同地点 NPC。T0503 起，协助治疗写入 `healing_started` / `healing_completed`，会同时进入治疗者和目标 NPC 的事件库，并写入同地点其他在场 NPC 的见闻库；治疗事件不在 payload 或 summary 中暴露医术熟练度。昏迷目标自身仍不接收见闻，但其亲历事件库会记录治疗事实。GM `attack_npc` / `damage_npc` 现在调用 NPC 扣血接口；`debug_record_player_attack_npc(...)` 只保留为记忆交互调试入口。
- T0502A 起，`add_witness_event(...)` 会拒绝给昏迷 NPC 写入见闻，因此昏迷者不会收到地点/广场公开广播、状态广播、公告或进入快照；复苏后见闻接收自动恢复。
- 玩家非对话交互的运行时 actor id 使用 `guard_officer`，summary 使用“守备官”，避免把“玩家”写入 NPC 记忆或后续 LLM 参考文本。
- T0701 已由 Godot `DialogSystem` 接入后端对话文本并写入事件库。每个 `dialogue_turn` 作为一个事实事件进入所有参与 NPC 的事件库；若 `visibility == "local_public"`，事件地点只向同地点非参与者广播一次，避免双方各写一份事件造成第三者重复见闻。
- T0705 已接入 NPC 主动交涉事件：触发主动交涉时，`proactive_talk_started` 以 `private` 写入发起者事件库，payload 保存 `prompt_text` 和持续时间；玩家点击气泡后，NPC 预先确定的开场问题以 `proactive_talk_message` 写入事件库，随后玩家回复继续走既有 `dialogue_turn`。
- `NPCPanel` 会分开显示当前 NPC 的事件库和见闻库，并使用固定高度滚动区展示完整记录；调试工具可通过 `debug_get_npc_short_term_memory(...)` 区分查看两类记录。
- `MemorySystem` 当前维护广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊的信息节点，保存 `people_present`、当前公告和进入快照所需的当前状态；`move_npc_between_locations(...)` 只维护当前在场人员，并给进入者写入一次 `location_entry_snapshot` 见闻。进入广场时，这条见闻会同时表达广场当前在场 NPC、广场在场 NPC 的生命状态/行动状态、当前公告文本和所有建筑可传播外部状态。面向单个 NPC 的 `current_order` 不进入地点信息节点。
- 所有建筑都有可传播外部状态：`level` 和 `condition`（`intact` / `damaged` / `repairing` / `upgrading`）。HP、Max HP、修复/升级剩余时长仍可由建筑系统和 UI 查询，但不参与信息节点状态比较，也不会因自身变化触发见闻传播。广场和可进入建筑都会在进入快照中暴露当前在场 NPC 的生命状态/行动状态；可进入建筑额外拥有可传播内部状态：每个工位的空闲/占用者。工位数量本身不参与状态比较。不可进入建筑不向地点快照暴露工位或内部 NPC。
- 广场快照没有自身建筑 HP，但通过 `building_external_states` 继承所有建筑的可传播外部状态；`key_entities` 当前作为兼容别名指向同一组外部状态。室外或不可进入实体来源的公开事件默认归入 `location_id == "plaza"` 并使用 `local_public`。
- 广场公告文本变更会更新广场当前状态，并生成 `plaza_notice_changed` 广场公开事件；公告牌只是主厅前的公告输入/显示接口，不是建筑信息节点。任一建筑的可传播外部状态变化都会生成带具体建筑名和具体状态的 `plaza_status_changed` 广场公开状态事件，当时在广场的 NPC 会把这些信息写入见闻库；summary 不使用“建筑状态更新”这类空泛前缀。
- `location_entered` / `location_exited` 事件库记录只保留进入/离开的行动事实；完整地点状态不再重复塞入亲历事件。进入者通过见闻库获得一次当前状态快照：进入广场时接收广场当前在场 NPC、广场在场 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态，进入可进入建筑时接收该建筑完整外部 + 内部状态，包括当前在场 NPC、建筑内 NPC 的生命状态/行动状态和工位占用。已经在场的 NPC 只接收“某人进入/离开某地”的 `local_public` 事件，不再额外收到完整在场 NPC 列表或完整人员状态列表。
- 后续地点或建筑状态变化只写入变化字段对应的见闻，不重新广播完整地点快照。例如建筑受损只广播受损，升级只广播等级变化，单个工位占用变化只广播该工位变化；未变化的建筑等级、工位、公告和在场人员不重复进入见闻库。广场建筑状态见闻使用 `changed_fields`，可进入建筑内部工位变化使用 `changed_workstations`。
- 主厅、围墙、城门、后门、仓库不作为常规进入空间；NPC 移动到这类实体时，信息节点状态归入广场快照。

T1004/T1005 已实现首次睡眠总结、日记写入、知识图谱占位更新和指定 NPC 短期记忆清空；真实 LLM Prompt 打磨、独立知识图谱更新服务、战斗本体或正式公告输入 UI 仍由后续任务推进。旧式“地点继承历史事件”不再作为后续目标。

T0004 后，GM 面板已暴露记忆/见闻相关调试入口，便于在 `Main.tscn` 前端验证此前主要依赖脚本的能力：查看地点快照、写入广场公告、广播广场公开事件、记录守备官给钱/攻击事件、查询 NPC 短期记忆、触发首次睡眠总结、查看长期记忆、LLM 状态和全局事件列表。GM 面板只调用现有系统接口或 `debug_*` 接口，不新增独立记忆事实源。

## 三层信息结构

### 1. NPC Event Log

每个 NPC 拥有当天事件库，记录发生在自己身上的事件。

示例：

- 醒来并开始制定计划。
- 进入食堂。
- 离开宿舍。
- 与守备官或其他 NPC 对话，完整对话内容、说话者名称、听者名称、公开性和轮次信息写入事件 `payload`。
- 开始/结束工作，产出和消耗由程序结算后写入。
- 被给予金钱、装备，或收到/修改守备官指令。
- 受击、昏迷、治疗、复苏、逃离。

### 2. Location / Building Info Node

每个可进入地点拥有信息节点。地点包括广场和建筑内部。信息节点只保存当前状态并负责广播，不保存事件历史。

地点/建筑信息节点保存：

- 当前有哪些 NPC 在场。
- 当前在场 NPC 的状态：广场和可进入建筑都会在进入快照中保存，生命状态与行动状态并列。生命状态分为健康、受伤、昏迷；昏迷状态如有治疗者则写明治疗者。行动状态来自 `current_action`，但在见闻 summary 中写成短中文。
- 建筑外部状态：等级、完好/受损/正在修复/正在升级。HP 和剩余修复/升级时长不参与传播。
- 可进入建筑的内部状态：每个工作位/床位/功能位的空闲/占用状态与占用者，以及当前在建筑内的 NPC。工位数量不参与传播。
- 当前公告或公开备注；只有广场状态保存当前公告文本，公告牌只是输入/显示接口。单个 NPC 的 `current_order` 不属于地点信息。
- NPC 进入地点时应写入进入者见闻库的一次性状态快照。

NPC 进入地点时，系统生成 `location_entered` 事件；该事件写入进入者事件库，只表达“某人进入了某地”。进入者随后在见闻库获得一次当前地点状态快照：进入广场时获得广场当前在场 NPC、广场在场 NPC 的生命状态/行动状态、当前公告文本与所有建筑外部状态；进入可进入建筑时获得该建筑外部状态、当前在场 NPC、建筑内 NPC 的生命状态/行动状态与工位/床位占用。进入者不会继承该地点过去发生的公开事件。

`location_entered` 是本地公开事件。地点节点会把进入事件转发给进入前已经在场的其他 NPC；他们只收到“某人进入了某地”这条事件见闻，不再额外收到完整建筑状态、在场人员列表或在场人员状态列表。建筑内“现在有谁”由进入/离开事件自然表达。

NPC 离开地点时，系统生成 `location_exited` 事件；事件 `location_id` 使用离开的地点，写入离开者事件库，并以 `local_public` 转发给该地点仍在场的 NPC。该事件只表达“某人离开了某地”，不附带完整地点状态，也不触发建筑内 NPC 列表广播。

NPC 从一个可进入室内地点前往另一个可进入室内地点时，逻辑事件链必须先经过广场：离开原地点、进入广场、离开广场、进入目标地点。当前低模阶段的物理表现仍可使用直线移动占位，但事件库、见闻库和地点 `people_present` 必须按这条逻辑链更新。

当地点内发生 `local_public` 事件时，事件先进入所属 NPC 的事件库，再发送到地点节点。地点节点把事件即时转发给当前在场 NPC，接收者写入自己的见闻库；转发完成后地点节点不保存该事件。

当地点或建筑状态变化时，见闻库只接收变化字段，不接收完整状态快照。例如建筑受损、修复完成、升级完成、公告变化或某个工位占用变化分别生成对应的字段级见闻；未变化的建筑等级、在场人员、工位和公告不重复广播。人员进出不再作为“完整内部状态变化”广播，统一由 `location_entered` / `location_exited` 事件表达。

### 3. NPC Witness Log

每个 NPC 拥有当天见闻库，记录自己通过地点/广场广播、公告、状态变化或公共事件获得的信息。

见闻库不同于事件库：见闻不表示“这件事发生在我身上”，而表示“我知道了这件事”。后续对话和反思应能区分亲历与听闻。

昏迷或睡觉期间 NPC 不具备接收现场信息的能力，见闻库不更新；这不会删除既有见闻，也不会阻止其事件库记录自身受击、昏迷、治疗、复苏、入睡、醒来等亲历事件。NPC 复苏或睡醒后，从后续广播开始重新接收见闻，不补收昏迷或睡觉期间错过的历史广播。

进入地点时的一次性地点状态快照也属于见闻库，不属于事件库。除这次进入快照外，后续地点/建筑状态见闻必须保持字段级增量，避免同一建筑状态在短期记忆里反复复制。

## 地点与建筑边界

可进入地点：

- 广场
- 宿舍
- 食堂
- 酒窖
- 菜园
- 铁匠铺
- 训练场
- 马厩
- 小教堂
- 小诊所
- 工械坊


不可进入实体：

- 主厅
- 围墙
- 城门
- 后门
- 仓库

不可进入实体不建立常规室内信息节点。它们只有可传播外部状态，不暴露内部 NPC、工位或床位状态；受损、修复、升级等外部状态变化如果公开，则通过广场节点即时广播。NPC 进入广场时，进入者的见闻库应获得广场当前在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑的可传播外部状态；`location_entered` 事件本身只记录进入广场的行动事实。

广场没有建筑 HP，但它是所有室外事件广播、公告当前内容、广场战斗状态、室外人员状态和全体建筑可传播外部状态的公共信息中枢。

## 广场公开见闻

会通过广场信息节点公开广播的事件包括：

- 战斗开始与结束。
- 敌我大致人数。
- 广场或室外发生的公开事件。
- 任一建筑的可传播外部状态变化，包括等级变化、受损、开始修复、修复完成、开始升级或升级完成。HP 变化和剩余修复/升级时长变化不广播。
- 某 NPC 击倒或击杀敌人。
- 某 NPC 昏迷、被治疗、复苏。
- 某 NPC 逃离或试图逃离。
- 玩家在公开攻击、赠予或对话。

NPC 进入广场时只接收广场当前在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和所有建筑外部状态；不会继承过去已经广播过的广场事件。

## 短期记忆

NPC 当天短期记忆由两部分组成：

- `event_log`：自己的亲历事件。
- `witness_log`：自己获得的见闻。

当天 LLM 调用时不直接塞入全部事件，而应按用途生成摘要：

- 对话：优先注入与玩家、当前 NPC、当前地点相关的事件和见闻。
- 计划：注入当天关键经历、地点状态、资源压力和未完成目标。
- 战斗判定：注入亲历伤害、见闻中的战况、玩家承诺或威胁。
- 首次睡眠总结：注入当天完整事件库和见闻库的筛选摘要。

## 首次睡眠总结

每天首次进入睡觉状态并持续睡眠满 1 个游戏小时后，NPC 根据当天事件库和见闻库生成：

1. 第一人称日记。
2. 知识图谱增量或更新。

当前实现（T1004/T1005）：

- `DailyReflectionSystem` 监听 `sleep_started`、`sleep_ended` 和 `logical_time_tick`，每名 NPC 每天首次睡眠满 1 游戏小时后生成一次总结；重复睡眠不会自动重复写入，GM 可用 force 调试。
- `LLMBridge.request_npc_daily_reflection(...)` 构造 `DailyReflectionRequest`，传入 NPC 上下文、当天事件 / 见闻筛选摘要和已有日记，调用后端 `/npc/daily_reflection`。该接口历史名仍为 daily_reflection，当前玩法语义是首次睡眠总结；请求会触发 TimeSystem 慢速。
- 总结请求发起到完成期间，NPC 处于不可打断的深度睡眠锁；对话、消息、行动改派和普通中断都会被拒绝。此期间发布的新指令只保存，计划重评估延后到醒来后。
- 后端不可用或输出无效时，Godot 使用确定性模板生成第一人称日记和最小知识图谱更新，保证睡觉流程不被模型阻断。
- `NPCSystem.apply_daily_reflection(...)` 把结果追加到 `diary`，并把 `knowledge_graph_updates` 合并到 `knowledge_graph.patches` 与 `knowledge_graph.by_subject` 占位结构。
- 总结完成后，`MemorySystem.clear_npc_short_term_memory(...)` 清空该 NPC 当天事件库和见闻库索引；全局事件档案仍保留给 GM 和自动化调试查询。
- `NPCPanel` 显示长期日记，并在总结期间显示“正在熟睡”；GM 面板可用 `reflect_npc <npc_id> [force]`、`long_memory <npc_id>`、`reflection_result` 和 `llm_state <npc_id>` 验证。

## 记忆注入原则

每次 LLM 调用不要注入所有历史，只注入：

- NPC 人设核心。
- 当前状态。
- 当前地点状态和 NPC 已接收的地点相关见闻。
- 当天短期记忆摘要。
- 与当前对话对象相关的知识图谱条目。
- 与玩家相关的高重要性记忆。
- 最近日记和高重要度长期事件。
- 当前守备官指令 `current_order`；它作为持续状态独立注入，不因短期事件摘要裁剪而丢失。
