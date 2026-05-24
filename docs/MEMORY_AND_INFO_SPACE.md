# MEMORY_AND_INFO_SPACE.md

## 模块目标

记忆系统用于让 NPC 记住自身经历、玩家行为、地点见闻、战斗事件和他人公开遭遇，并在后续计划、对话、征召、逃离、战斗判定、睡前反思中产生影响。

本模块的底层不是“给 LLM 拼一段记忆文本”，而是一套类似埋点系统的事件触发、记录和传播架构。游戏中的事实先被程序记录为事件，再按规则进入 NPC 事件库；公开事件会即时广播到地点/建筑信息节点，由节点转发给当时在场的 NPC，并写入接收者的 NPC 见闻库和后续长期记忆。地点/建筑信息节点不是事件仓库。

## 核心原则

- 每个事件必须关联一个 `subject_npc_id`，并首先写入该 NPC 的事件库，表示“这件事发生在他身上”。
- 每个事件必须有 `location_id`。室外事件统一归入 `plaza`。
- 事件库和见闻库分开：事件库记录亲历，见闻库记录 NPC 当场接收到的公开事件广播、状态广播、公告和公开消息；NPC 不会因为进入地点而继承该地点过去发生的事件。
- 当天事件库 + 当天见闻库共同构成 NPC 的短期记忆。
- 对话全文作为对话事件的属性保存，不单独建立谈话库。
- LLM 只解释和回应事件，不负责资源、HP、建筑、战斗等权威结算。

## 事件结构

事件通用字段：

| 字段 | 说明 |
|---|---|
| `event_id` | 唯一事件 ID |
| `day` / `time` | 游戏日与发生时间 |
| `type` | 事件类型 |
| `subject_npc_id` | 事件所属 NPC，必填 |
| `actor_ids` | 主动参与者，包含 NPC / 玩家 / 敌人 / 系统 |
| `target_ids` | 事件关联目标索引，包含 NPC / 地点 / 建筑 / 行动 / 资源 / 敌人等 ID |
| `location_id` | 发生地点；室外统一为 `plaza` |
| `visibility` | `private`、`local_public`、`plaza_public` |
| `importance` | 重要度，用于摘要、筛选和长期记忆压缩 |
| `summary` | 给 UI、调试和摘要使用的短文本 |
| `payload` | 类型专属结构化属性 |

`target_ids` 不是自然语言里的“宾语”字段。它是程序索引字段，用来支持查询“哪些事件关联了某个 NPC / 地点 / 建筑 / 行动 / 资源 / 敌人”。例如 `location_entered` 的目标可以是地点 ID，`work_started` 的目标可以同时包含建筑 ID 和行动 ID，`resource_changed` 的目标可以包含资源 ID。

`visibility` 规则：

- `private`：只进入 `subject_npc_id` 的事件库。
- `local_public`：进入 `subject_npc_id` 事件库，并即时广播到所属地点/建筑信息节点；节点转发给当时已经在场的 NPC 后不保存该事件。
- `plaza_public`：进入 `subject_npc_id` 事件库，并即时广播到广场信息节点；如果事件发生在其他可进入地点，也可以同时广播到该地点节点。接收 NPC 写入见闻库，节点不保存事件历史。

## Summary 生成规则

`summary` 必须由确定性模板生成，不使用 LLM 总结，也不依赖通用主语/宾语规则自动拼句。

每种事件类型必须定义：

- summary 模板。
- 模板需要读取的 `payload` 字段。
- 可选的 ID 展开规则，例如 NPC id 展开为姓名和职业背景，地点 id 展开为显示名，资源 id 展开为中文名。

示例：

| 事件类型 | 模板 | 关键 payload |
|---|---|---|
| `location_entered` | `{actor}进入了{to_location}。` | `to_location_id`, `from_location_id`, `location_snapshot` |
| `work_started` | `{actor}开始在{location}进行{action}。` | `action_id`, `workstation_id` |
| `work_completed` | `{actor}完成了{action}，消耗{inputs}，产出{outputs}。` | `action_id`, `input_resources`, `output_resources` |
| `dialogue_turn` | `{speaker}对{listener}说：{text}` | `speaker_id`, `listener_id`, `text` |
| `damage_taken` | `{target}受到{actor}造成的{damage}点伤害。` | `damage`, `hp_before`, `hp_after` |

`actor_ids`、`target_ids` 和 `location_id` 负责保留稳定事实属性；summary 模板负责 UI、调试日志和 prompt 摘要。不要把事件系统做成试图从任意主宾关系自动生成句子的万能事件句子生成器。

## 必备事件类型

T0402 的底层架构至少应为以下事件类型预留类型常量、payload 扩展和查询能力：

- 日常与计划：`wake_up`、`plan_created`、`reflection_started`、`sleep_started`、`sleep_ended`。
- 移动与地点：`location_entered`、`location_exited`。
- 工作与生活：`work_started`、`work_completed`、`work_failed`、`eat_started`、`eat_completed`。
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
- 每个事件首先写入 `subject_npc_id` 对应 NPC 的当天事件库；`local_public` 事件会即时广播给事件地点当前在场 NPC，并写入接收者见闻库；`plaza_public` 事件会即时广播给广场当前在场 NPC，并保留广场公开查询。
- 现有 `ActionSystem` 已写入 `work_started`、`work_completed`、`work_failed`、`eat_started`、`eat_completed`、`sleep_started`、`sleep_ended`；`NPCSystem` 到达地点时写入 `location_entered`。
- 已提供 `get_all_events()`、`get_npc_daily_events(npc_id)`、`get_npc_witness_events(npc_id)`、`get_npc_short_term_memory(npc_id)`、`get_npc_short_term_memory_ids(npc_id)`、`get_plaza_public_events()` 和对应调试接口。
- 玩家非对话交互可通过 `record_player_interaction(...)` 写入目标 NPC 事件库，并按 `private` / `local_public` / `plaza_public` 可见性即时广播；当前已有 `debug_record_player_money_given(...)` 和 `debug_record_player_attack_npc(...)` 用于验证给钱与攻击事件。
- `NPCPanel` 会分开显示当前 NPC 的事件库和见闻库最近摘要，调试工具可通过 `debug_get_npc_short_term_memory(...)` 区分查看两类记录。
- `MemorySystem` 当前维护广场、宿舍、食堂、酒窖、菜园、铁匠铺、训练场、马厩、小教堂、小诊所、工械坊的信息节点，保存 `people_present`、当前公告/命令和进入快照所需的当前状态。
- 广场快照没有自身建筑 HP，但提供主厅、围墙、城门、仓库 `key_entities`，以及当前在场 NPC 数和敌人数；室外或不可进入实体来源的 `plaza_public` 事件默认归入 `location_id == "plaza"`。
- 公告牌内容变更会更新广场当前状态，并生成 `plaza_notice_changed` 广场公开事件；关键目标受损、修复或升级会生成 `plaza_status_changed` 广场公开状态事件，当时在广场的 NPC 会把这些信息写入见闻库。
- `NPCSystem` 到达地点时会更新旧地点与新地点的 `people_present`，并将 `location_entered.payload.location_snapshot` 写入事件库。快照包含当前人数、建筑 HP/等级/可用状态、工位/床位占用字段、当前公告/命令；进入广场时还包含主厅、围墙、城门、仓库的关键状态。
- 主厅、围墙、城门、仓库不作为常规进入空间；NPC 移动到这类实体时，信息节点状态归入广场快照。

当前仍不实现睡前总结、日记、知识图谱、LLM 记忆摘要、战斗本体、真实玩家交互按钮或公告牌编辑 UI；这些仍由后续任务推进。旧式“地点继承历史事件”不再作为后续目标。

## 三层信息结构

### 1. NPC Event Log

每个 NPC 拥有当天事件库，记录发生在自己身上的事件。

示例：

- 醒来并开始制定计划。
- 进入食堂，看到几个人、工位是否空闲、食堂 HP。
- 与玩家对话，完整对话内容写入事件 `payload`。
- 开始/结束工作，产出和消耗由程序结算后写入。
- 被给予金钱、装备或任务。
- 受击、昏迷、治疗、复苏、逃离。

### 2. Location / Building Info Node

每个可进入地点拥有信息节点。地点包括广场和建筑内部。信息节点只保存当前状态并负责广播，不保存事件历史。

地点/建筑信息节点保存：

- 当前有哪些 NPC 在场。
- 建筑 HP、等级、是否可用。
- 工作位/床位/功能位是否空闲，以及被谁占据。
- 当前公告或公共命令；只有广场/公告牌需要保存当前公告文本。
- NPC 进入地点时应读取的状态快照。

NPC 进入地点时，系统生成 `location_entered` 事件；该事件的 `payload.location_snapshot` 保存进入时地点状态。地点节点随后向在场 NPC 广播当前状态。进入者只获得当前状态，不继承该地点过去发生的公开事件。

当地点内发生 `local_public` 事件时，事件先进入所属 NPC 的事件库，再发送到地点节点。地点节点把事件即时转发给当前在场 NPC，接收者写入自己的见闻库；转发完成后地点节点不保存该事件。

### 3. NPC Witness Log

每个 NPC 拥有当天见闻库，记录自己通过地点/广场广播、公告、状态变化或公共事件获得的信息。

见闻库不同于事件库：见闻不表示“这件事发生在我身上”，而表示“我知道了这件事”。后续对话和反思应能区分亲历与听闻。

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
- 仓库

不可进入实体不建立常规室内信息节点。它们的 HP、可用状态归入广场当前状态；受损事件如果公开，则通过广场节点即时广播。NPC 进入广场时，`location_entered.payload.location_snapshot` 应包含主厅、围墙、城门等关键实体当前状态。

广场没有建筑 HP，但它是所有室外事件广播、公告当前内容、广场战斗状态、室外人员状态和不可进入实体状态的公共信息中枢。

## 广场公开见闻

会通过广场信息节点公开广播的事件包括：

- 战斗开始与结束。
- 敌我大致人数。
- 广场或室外发生的公开事件。
- 围墙、城门、主厅、仓库等关键目标受损。
- 某 NPC HP 低于 30%。
- 某 NPC 击倒或击杀敌人。
- 某 NPC 昏迷、被治疗、复苏。
- 某 NPC 逃离或试图逃离。
- 玩家在公共场合攻击、威胁、赠予、承诺或公告。

NPC 进入广场时只接收广场当前状态和公告牌当前内容；不会继承过去已经广播过的广场事件。

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
