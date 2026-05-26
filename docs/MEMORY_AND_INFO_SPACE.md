# MEMORY_AND_INFO_SPACE.md

## 模块目标

记忆系统用于让 NPC 记住自身经历、玩家行为、地点见闻、战斗事件和他人公开遭遇，并在后续计划、对话、征召、逃离、战斗判定、睡前反思中产生影响。

本模块的底层不是“给 LLM 拼一段记忆文本”，而是一套类似埋点系统的事件触发、记录和传播架构。游戏中的事实先被程序记录为事件，再按规则进入 NPC 事件库；公开事件会即时广播到地点/建筑信息节点，由节点转发给当时在场的 NPC，并写入接收者的 NPC 见闻库和后续长期记忆。地点/建筑信息节点不是事件仓库。

世界内称呼规则：所有写入 NPC 事件库、见闻库、Prompt 摘要、睡前总结输入、公告/教学信件等 NPC 可见或 LLM 会当作世界内事实理解的文本，均把玩家称为“守备官”。“玩家”只能用于开发文档和调试命令说明；事件 summary 不得输出以“玩家”为主语的出戏表述。

## 核心原则

- 每个事件必须关联一个 `subject_npc_id`，并首先写入该 NPC 的事件库，表示“这件事发生在他身上”。
- 每个事件必须有 `location_id`。室外事件统一归入 `plaza`。
- 事件库和见闻库分开：事件库记录亲历，见闻库记录 NPC 当场接收到的公开事件广播、状态广播、公告和公开消息；NPC 不会因为进入地点而继承该地点过去发生的事件。
- 进入/离开地点的事件库记录只表达行动事实；完整地点状态只作为进入者的一次性见闻，且不再重复写进进入事件。
- 除进入者的一次性地点状态快照外，建筑和地点状态见闻只传递变化字段，不重复传递未变化的完整快照。
- 当天事件库 + 当天见闻库共同构成 NPC 的短期记忆。
- 对话全文作为对话事件的属性保存，不单独建立谈话库。
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
| `work_started` | `{actor}开始在{location}进行{action}。` | `action_id`, `workstation_id` |
| `work_completed` | `{actor}完成了{action}，消耗{inputs}，产出{outputs}。` | `action_id`, `input_resources`, `output_resources` |
| `repair_assist_started` | `{actor}开始协助修复{location}。` | `action_id`, `building_id`, `engineering_skill` |
| `upgrade_assist_started` | `{actor}开始协助升级{location}。` | `action_id`, `building_id`, `engineering_skill` |
| `dialogue_turn` | `{speaker}对{listener}说：{text}` | `speaker_id`, `listener_id`, `text` |
| `damage_taken` | `{target}受到{actor}造成的{damage}点伤害。` | `damage`, `hp_before`, `hp_after` |

`actor_ids`、`target_ids` 和 `location_id` 负责保留稳定事实属性；summary 模板负责 UI、调试日志和 prompt 摘要。不要把事件系统做成试图从任意主宾关系自动生成句子的万能事件句子生成器。

## 必备事件类型

T0402 的底层架构至少应为以下事件类型预留类型常量、payload 扩展和查询能力：

- 日常与计划：`wake_up`、`plan_created`、`reflection_started`、`sleep_started`、`sleep_ended`。
- 移动与地点：`location_entered`、`location_exited`。
- 工作与生活：`work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`。
- 对话：`dialogue_started`、`dialogue_turn`、`dialogue_ended`。每轮文本、说话者、听者、是否提出应征、是否承诺/威胁/欺骗等都写入 `payload`。
- 玩家交互：`money_given`、`equipment_given`、`equipment_changed`、`order_assigned`、`npc_attacked_by_player`。
- 成长与状态：`skill_improved`、`npc_recruited`、`npc_left_recruited_state`。
- 战斗：`combat_started`、`combat_ended`、`attack_made`、`damage_taken`、`low_hp_triggered`、`unconscious_started`、`healing_started`、`healing_completed`、`revived`、`escape_started`、`escaped`。
- 建筑与资源见闻：`building_damaged`、`building_repaired`、`building_upgraded`、`resource_changed`。

第一版实现可以只接入少量现有行动事件，但接口与数据结构不得把未来事件类型堵死。

## 当前实现状态

T0402 已实现结构化事件底座，T0403 已实现地点信息节点与进入快照，T0404 已实现广场公开信息即时广播，T0405 已实现 NPC 短期记忆容器：

- `MemorySystem` 是当前事件事实源，维护全局事件索引、NPC 当天事件库、NPC 见闻库占位和广场公开事件查询。地点/广场节点不应成为事件历史存储，MemorySystem 也不提供按地点查询事件的长期接口。
- `add_event(event)` 会规范化事件字段，补齐 `event_id`、`day`、`time`、`actor_ids`、`target_ids`、`location_id`、`visibility`、`importance`、`summary` 和 `payload`，并要求事件具备 `subject_npc_id`。
- 每个事件首先写入 `subject_npc_id` 对应 NPC 的当天事件库；`local_public` 事件会即时广播给事件地点当前在场 NPC，并写入接收者见闻库。广场事件也走同一规则，地点为 `plaza`。
- 现有 `ActionSystem` 已写入 `work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`、`sleep_started`、`sleep_ended`。工作/吃饭/睡觉按 `local_public` 写入，会即时广播给同地点当前在场 NPC 的见闻库；协助修复/协助升级也按 `local_public` 写入，事件地点为 `plaza`，会广播给广场当前在场 NPC。`NPCSystem` 到达地点时写入 `location_entered`。
- 已提供 `get_all_events()`、`get_npc_daily_events(npc_id)`、`get_npc_witness_events(npc_id)`、`get_npc_short_term_memory(npc_id)`、`get_npc_short_term_memory_ids(npc_id)`、`get_plaza_events()` 和对应调试接口。
- 玩家非对话交互可通过 `record_player_interaction(...)` 写入目标 NPC 事件库，并按 `private` / `local_public` 可见性即时广播；当前已有 `debug_record_player_money_given(...)` 和 `debug_record_player_attack_npc(...)` 用于验证给钱与攻击事件。
- 玩家非对话交互的运行时 actor id 使用 `guard_officer`，summary 使用“守备官”，避免把“玩家”写入 NPC 记忆或后续 LLM 参考文本。
- `NPCPanel` 会分开显示当前 NPC 的事件库和见闻库最近摘要，调试工具可通过 `debug_get_npc_short_term_memory(...)` 区分查看两类记录。
- `MemorySystem` 当前维护广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊的信息节点，保存 `people_present`、当前公告/命令和进入快照所需的当前状态；`move_npc_between_locations(...)` 只维护当前在场人员，并给进入者写入一次 `location_entry_snapshot` 见闻。
- 所有建筑都有可传播外部状态：`level` 和 `condition`（`intact` / `damaged` / `repairing` / `upgrading`）。HP、Max HP、修复/升级剩余时长仍可由建筑系统和 UI 查询，但不参与信息节点状态比较，也不会因自身变化触发见闻传播。可进入建筑额外拥有可传播内部状态：当前在场 NPC 和每个工位的空闲/占用者；工位数量本身不参与状态比较。不可进入建筑不向地点快照暴露工位和内部 NPC。
- 广场快照没有自身建筑 HP，但通过 `building_external_states` 继承所有建筑的可传播外部状态；`key_entities` 当前作为兼容别名指向同一组外部状态。室外或不可进入实体来源的公开事件默认归入 `location_id == "plaza"` 并使用 `local_public`。
- 广场公告文本变更会更新广场当前状态，并生成 `plaza_notice_changed` 广场公开事件；公告牌只是主厅前的公告输入/显示接口，不是建筑信息节点。任一建筑的可传播外部状态变化都会生成带具体建筑名和具体状态的 `plaza_status_changed` 广场公开状态事件，当时在广场的 NPC 会把这些信息写入见闻库；summary 不使用“建筑状态更新”这类空泛前缀。
- `location_entered` / `location_exited` 事件库记录只保留进入/离开的行动事实；完整地点状态不再重复塞入亲历事件。进入者通过见闻库获得一次当前状态快照：进入广场时接收所有建筑外部状态，进入可进入建筑时接收该建筑完整外部 + 内部状态，包括当前在场 NPC 和工位占用。已经在场的 NPC 只接收“某人进入/离开某地”的 `local_public` 事件，不再额外收到完整在场 NPC 列表。
- 后续地点或建筑状态变化只写入变化字段对应的见闻，不重新广播完整地点快照。例如建筑受损只广播受损，升级只广播等级变化，单个工位占用变化只广播该工位变化；未变化的建筑等级、工位、公告和在场人员不重复进入见闻库。广场建筑状态见闻使用 `changed_fields`，可进入建筑内部工位变化使用 `changed_workstations`。
- 主厅、围墙、城门、后门、仓库不作为常规进入空间；NPC 移动到这类实体时，信息节点状态归入广场快照。

当前仍不实现睡前总结、日记、知识图谱、LLM 记忆摘要、战斗本体、真实玩家交互按钮或公告输入 UI；这些仍由后续任务推进。旧式“地点继承历史事件”不再作为后续目标。

T0004 后，GM 面板已暴露记忆/见闻相关调试入口，便于在 `Main.tscn` 前端验证此前主要依赖脚本的能力：查看地点快照、写入广场公告、广播广场公开事件、记录守备官给钱/攻击事件、查询 NPC 短期记忆和全局事件列表。GM 面板只调用 `MemorySystem` 现有接口或 `debug_*` 接口，不新增独立记忆事实源。

## 三层信息结构

### 1. NPC Event Log

每个 NPC 拥有当天事件库，记录发生在自己身上的事件。

示例：

- 醒来并开始制定计划。
- 进入食堂。
- 离开宿舍。
- 与玩家对话，完整对话内容写入事件 `payload`。
- 开始/结束工作，产出和消耗由程序结算后写入。
- 被给予金钱、装备或任务。
- 受击、昏迷、治疗、复苏、逃离。

### 2. Location / Building Info Node

每个可进入地点拥有信息节点。地点包括广场和建筑内部。信息节点只保存当前状态并负责广播，不保存事件历史。

地点/建筑信息节点保存：

- 当前有哪些 NPC 在场。
- 建筑外部状态：等级、完好/受损/正在修复/正在升级。HP 和剩余修复/升级时长不参与传播。
- 可进入建筑的内部状态：每个工作位/床位/功能位的空闲/占用状态与占用者，以及当前在建筑内的 NPC。工位数量不参与传播。
- 当前公告或公共命令；只有广场状态保存当前公告文本，公告牌只是输入/显示接口。
- NPC 进入地点时应写入进入者见闻库的一次性状态快照。

NPC 进入地点时，系统生成 `location_entered` 事件；该事件写入进入者事件库，只表达“某人进入了某地”。进入者随后在见闻库获得一次当前地点状态快照：进入广场时获得当前公告与所有建筑外部状态；进入可进入建筑时获得该建筑外部状态、当前在场 NPC 与工位/床位占用。进入者不会继承该地点过去发生的公开事件。

`location_entered` 是本地公开事件。地点节点会把进入事件转发给进入前已经在场的其他 NPC；他们只收到“某人进入了某地”这条事件见闻，不再额外收到完整建筑状态或在场人员列表。建筑内“现在有谁”由进入/离开事件自然表达。

NPC 离开地点时，系统生成 `location_exited` 事件；事件 `location_id` 使用离开的地点，写入离开者事件库，并以 `local_public` 转发给该地点仍在场的 NPC。该事件只表达“某人离开了某地”，不附带完整地点状态，也不触发建筑内 NPC 列表广播。

当地点内发生 `local_public` 事件时，事件先进入所属 NPC 的事件库，再发送到地点节点。地点节点把事件即时转发给当前在场 NPC，接收者写入自己的见闻库；转发完成后地点节点不保存该事件。

当地点或建筑状态变化时，见闻库只接收变化字段，不接收完整状态快照。例如建筑受损、修复完成、升级完成、公告变化或某个工位占用变化分别生成对应的字段级见闻；未变化的建筑等级、在场人员、工位和公告不重复广播。人员进出不再作为“完整内部状态变化”广播，统一由 `location_entered` / `location_exited` 事件表达。

### 3. NPC Witness Log

每个 NPC 拥有当天见闻库，记录自己通过地点/广场广播、公告、状态变化或公共事件获得的信息。

见闻库不同于事件库：见闻不表示“这件事发生在我身上”，而表示“我知道了这件事”。后续对话和反思应能区分亲历与听闻。

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

不可进入实体不建立常规室内信息节点。它们只有可传播外部状态，不暴露内部 NPC、工位或床位状态；受损、修复、升级等外部状态变化如果公开，则通过广场节点即时广播。NPC 进入广场时，进入者的见闻库应获得所有建筑的可传播外部状态；`location_entered` 事件本身只记录进入广场的行动事实。

广场没有建筑 HP，但它是所有室外事件广播、公告当前内容、广场战斗状态、室外人员状态和全体建筑可传播外部状态的公共信息中枢。

## 广场公开见闻

会通过广场信息节点公开广播的事件包括：

- 战斗开始与结束。
- 敌我大致人数。
- 广场或室外发生的公开事件。
- 任一建筑的可传播外部状态变化，包括等级变化、受损、开始修复、修复完成、开始升级或升级完成。HP 变化和剩余修复/升级时长变化不广播。
- 某 NPC HP 低于 30%。
- 某 NPC 击倒或击杀敌人。
- 某 NPC 昏迷、被治疗、复苏。
- 某 NPC 逃离或试图逃离。
- 玩家在公共场合攻击、威胁、赠予、承诺或公告。

NPC 进入广场时只接收广场当前状态、当前公告文本和所有建筑外部状态；不会继承过去已经广播过的广场事件。

## 短期记忆

NPC 当天短期记忆由两部分组成：

- `event_log`：自己的亲历事件。
- `witness_log`：自己获得的见闻。

当天 LLM 调用时不直接塞入全部事件，而应按用途生成摘要：

- 对话：优先注入与玩家、当前 NPC、当前地点相关的事件和见闻。
- 计划：注入当天关键经历、地点状态、资源压力和未完成目标。
- 战斗判定：注入亲历伤害、见闻中的战况、玩家承诺或威胁。
- 睡前总结：注入当天完整事件库和见闻库的筛选摘要。

## 睡前总结

每天睡前，NPC 根据当天事件库和见闻库生成：

1. 第一人称日记。
2. 知识图谱增量或更新。

总结完成后，清空当天短期事件库和见闻库缓存；是否保留原始事件用于调试或存档，由后续存档任务决定。

## 记忆注入原则

每次 LLM 调用不要注入所有历史，只注入：

- NPC 人设核心。
- 当前状态。
- 当前地点状态和 NPC 已接收的地点相关见闻。
- 当天短期记忆摘要。
- 与当前对话对象相关的知识图谱条目。
- 与玩家相关的高重要性记忆。
- 最近日记和高重要度长期事件。
