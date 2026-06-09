# DATA_SCHEMA.md

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

T0305 起，`resource_defs.json` 增加派生资源 `meal` / 餐食、`wine` / 酒、`weapons` / 武器、`armor` / 盔甲、`defense_devices` / 工程器械、`horse_readiness` / 马匹整备，用于行动系统内部结算。HUD 当前仍只展示基础资源。

## NPC Profile

```json
{
  "id": "stableman_01",
  "name": "托马",
  "gender": "male",
  "background_job": "马夫",
  "appearance": "肩背宽厚，常穿沾着干草和马汗味的旧皮围裙。",
  "background_story": "托马在马厩工作多年，认为自己的职责是让马活下来。",
  "personality": ["谨慎", "重感情", "怕死"],
  "desires": ["保护马厩", "活下来"],
  "fears": ["被派上前线", "马匹被征用"],
  "boundaries": ["不能接受无意义牺牲"],
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
  "recruited": false,
  "current_order": {
    "text": "",
    "issued_by": "guard_officer",
    "issued_day": 0,
    "issued_time": "",
    "revision": 0
  },
  "equipment": {},
  "plan": [],
  "short_term_memory": [],
  "knowledge_graph": {},
  "diary": []
}
```

T0301 起，`data/npc_profiles.json` 已使用该结构补齐 8 名初始 NPC。`gender`、`appearance`、`background_story`、`abilities`、`plan`、`short_term_memory` 为 NPC 档案必填基础字段；`background_job` 只保留叙事出身，`boundaries`、`stats` 继续供后续计划、征召、对话和战斗心理判定使用。开局只有 `veteran_deputy_01` 的 `recruited` 为 `true`，其他 NPC 均为 `false`。

T0703 已为每名初始 NPC 配置并在运行时规范化 `current_order`。它保存守备官对该 NPC 当前持续提出的自然语言指令，而不是已执行行动：`text` 是当前文本，`issued_by` 固定为 `guard_officer`，`issued_day` / `issued_time` 记录最近一次变更时间，`revision` 在指令文本变化时递增。未入伍或尚无指令时 `text` 为空。发布相同文本或关闭指令面板不得修改该结构。

T0304 起，运行时 `NPCSystem` 会读取并更新 `states` 下的 `hp`、`max_hp`、`satiety`、`fatigue`、`money`、`unconscious`、`escaped`、`current_action` 字段，并将 `stats.strength` / 力量、`stats.intelligence` / 智力、`recruited` 与 `skills` 展示到 NPC 面板。移动系统会在运行时补齐和更新 `current_location`、`current_location_name`、`movement_target`、`movement_target_name` 和 `location_context`；这些字段当前作为地点进入占位，不要求手动写入 `data/npc_profiles.json`。T0808 起，诊所治疗可通过运行时恢复受伤 NPC 的 HP，并可最小提升医术；当前不实现真实日程、通用职业经验升级或 LLM 地点解读。

T0501 起，`NPCSystem.apply_damage_to_npc(...)` 会扣除 `states.hp`，并在 HP 降到 0 时设置 `states.unconscious=true`、`states.current_action="unconscious"`、清空移动目标。T0502/T0503 起，昏迷 NPC 会自然恢复，也可被其他 NPC 协助治疗；HP 恢复到 Max HP 30% 后复苏。昏迷 NPC 不会死亡，也不能移动或执行行动。

T0402 设计更新后，运行时短期记忆不再建议只用一个扁平 `short_term_memory` 数组表达。后续应拆分为当天 `event_log` 与 `witness_log`：前者记录发生在该 NPC 身上的事件 ID，后者记录该 NPC 通过地点/广场即时广播、状态广播或公告获得的见闻事件 ID。NPC 不会因为进入地点而继承该地点过去发生的事件。`data/npc_profiles.json` 可继续保留 `short_term_memory` 作为初始空字段兼容占位，但运行时 MemorySystem 应以 NPC 事件库和见闻库为准。

T0304 修正后，`skills` 是固定全集，每名 NPC 必须都有且只能有以下 13 个熟练度维度，取值范围 0-100：

- 职业熟练度：`养马`、`厨艺`、`耕种`、`打铁`、`教练`、`酿酒`、`医术`、`工程`
- 武器熟练度：`剑盾`、`长杆`、`弓`、`弩`、`骑术`

`background_job` 只表示叙事背景，不作为权威职业分类。实际“职业倾向 / 专长”由这些熟练度的高低推导；运行时 `NPCSystem.normalize_skills(...)` 会按固定全集补齐缺失值并丢弃未定义技能。

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
  "workstations": [
    {
      "id": "bed_01",
      "type": "rest",
      "occupied_by": null
    }
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
    "workstation_bonus": 1,
    "workstation_type": "rest"
  }
}
```

`repair` / `upgrade` 为 T0205 起使用的可选字段。已配置时由 `BuildingSystem` 调用 `ResourceSystem.spend_resources` 进行资源结算。2026-05-24 起，`repair` 的资源会在修复开始时一次性扣除，`seconds_per_missing_hp` 和 `level_time_factor` 用于计算倒计时修复时长；`hp_restore` 保留为旧配置兼容字段，不再表示点击后瞬间恢复。2026-05-25 起，所有建筑都应具备 `upgrade` 最小配置；升级同样在开始时一次性扣除资源并创建倒计时升级作业，完成后才应用等级、Max HP 和工作位奖励。

只有可进入建筑使用 `workstations` 表达内部状态。T0801 起，运行时工位占用和释放由 `BuildingSystem.claim_workstation(...)` / `release_workstation(...)` 修改 `occupied_by`；地点信息节点只读取该状态并广播变化字段，不自行决定工作位权威状态。T0808 起，小诊所使用 `clinic_doctor` 表达医生坐诊/研读医术工位，使用 `patient_bed` 表达治疗病床；二者必须是不同工位类型。主厅、围墙、城门、后门、仓库等不可进入建筑应保留 HP、等级、修复/升级等权威状态，但 `workstations` 为空，且不会在广场外部状态中暴露内部 NPC、NPC 状态或工位。NPC 见闻传播使用的建筑外部状态只包含等级和完好/受损/正在修复/正在升级。运行时地点快照会为广场和可进入建筑生成 `people_statuses`，用于表达当前在场 NPC 的生命状态和行动状态；它来自 NPC 运行时状态，不要求写入 `data/building_defs.json`。

公告牌不使用 Building Definition。主厅前的 `NoticeBoard` 节点只是视觉占位和后续公告输入接口，不能配置 `hp`、`max_hp`、`workstations`、`repair` 或 `upgrade`；公告文本应写入广场 Location Info Node 的当前状态。

## Action Definition

```json
{
  "id": "work_garden",
  "name": "照料菜园",
  "type": "work",
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
  "fatigue_delta": 8,
  "satiety_delta": -4
}
```

T0305 起，行动定义支持多类 JSON 最小行动；2026-05-25 起，行动时长优先使用 `duration_seconds`，旧的 `base_duration_hours` 仅保留为兼容字段。行动抵达地点后按 TimeSystem 逻辑秒推进，不应在抵达瞬间完成。协助修复/协助升级是运行时参数化行为，不作为每个建筑一条固定 JSON 行动：

- `work`：读取 `location_required`、`duration_seconds`、`input_resources`、`output_resources`、`fatigue_delta`、`satiety_delta` 后由程序结算。T0801 起，`duration_seconds` 是单位工作周期基准；实际周期时长由 `ActionSystem` 按 NPC 对应 `skill`、力量/智力属性和建筑等级计算，低熟练不会慢于基准，高熟练或高等级建筑会缩短耗时。可选 `stat` 指定该工作使用的属性，未填时由 `ActionSystem` 按技能类型默认选择力量或智力。工作开始占用目标建筑工位，单位完成时结算输入、产出和状态变化，完成、失败或中断时释放工位。T0802 起，食堂行动 `work_dining_hall` 固定表达 1 份粮食加工为 1 份餐食，使用 `skill="厨艺"`。T0803 起，菜园行动 `work_garden` 使用可选 `output_scaling`：`resources` 指定参与加成的输出资源；`skill_per_bonus` 表示每多少点对应熟练度增加 1 份产出；`attribute_baseline` / `attribute_per_bonus` 表示属性超过基线后每多少点增加 1 份产出；`building_level_bonus=true` 表示建筑等级每高 1 级增加 1 份产出。T0806 起，马厩行动 `work_stable` 同样使用 `output_scaling`，把养马、力量和马厩等级折算为 `horse_readiness` 的额外产出。T0807 起，酒窖行动 `work_tavern` 使用 `stat="intelligence"` 和 `output_scaling`，把酿酒、智力和酒窖等级折算为 `wine` 的额外产出；出售酒换钱不在行动定义中结算。未配置 `output_scaling` 的工作仍按固定 `output_resources` 结算。
- `eat`：使用 `food_options` 数组定义可消耗食物及饱食度恢复量，当前餐食优先于粮食；餐食恢复 50 点饱食度，粮食恢复 25 点饱食度。标准进食时长为 1200 秒，恢复按进度逐步应用。
- `sleep`：通过 `duration_seconds`、`fatigue_delta` 和 `satiety_delta` 调整 NPC 状态。当前睡眠基准为 23400 秒降低 100 点疲劳，并按逻辑秒逐步结算。
- `targeted_heal`：需要运行时传入昏迷目标 NPC，不可通过普通 `assign_action` 直接执行。当前 `assist_heal` 读取 `requires_target="unconscious_npc"`、`target_limit_per_target`、`resource_cost_interval_seconds`、`input_resources.money` 和 `skill="医术"` 作为行为声明；具体目标校验、费用扣除、医术加速和 HP 恢复由 `ActionSystem` / `NPCSystem` 结算。
- `clinic_doctor`：T0808 新增，用于小诊所医生工位。读取 `location_required="clinic"`、`workstation_type="clinic_doctor"`、`skill="医术"`、`stat="intelligence"`、`study_skill_interval_seconds`、`treatment_skill_interval_seconds`、`resource_cost_interval_seconds` 和 `input_resources.money`。医生在岗且无病床病人时，按研读医学著作逻辑缓慢提升医术；有病人占床时推进治疗。
- `clinic_patient`：T0808 新增，用于小诊所病床。读取 `location_required="clinic"` 与 `workstation_type="patient_bed"`。只有受伤且未昏迷 NPC 可通过普通 `assign_action` 执行；病人占床本身不恢复 HP，必须有 `clinic_doctor` 行动中的医生在岗才开始治疗。

`assist_repair` 由 `ActionSystem.debug_assign_repair_assist(npc_id, building_id)` 接收 `building_id` 参数，并读取 `BuildingSystem` 当前是否存在修复作业。`assist_upgrade` 由 `ActionSystem.debug_assign_upgrade_assist(npc_id, building_id)` 接收 `building_id` 参数，并读取 `BuildingSystem` 当前是否存在升级作业。不要在 `data/action_defs.json` 中新增类似“修补围墙”或“升级菜园”的固定建筑行动；建筑 HP、资源预付、修复/升级倒计时和协助者加成都由 `BuildingSystem` 结算。协助修复/协助升级都是室外广场行为，事件 `location_id` 固定为 `plaza`，`visibility` 固定为 `local_public`，payload 通过 `building_id` 保留实际目标建筑。

## Weapon Definition

```json
{
  "id": "short_sword",
  "name": "短剑",
  "type": "melee",
  "range": 1.5,
  "damage": 12,
  "attack_interval": 1.2,
  "required_skill": "剑盾",
  "tags": ["one_handed"]
}
```

## Enemy Wave

```json
{
  "id": "wave_01",
  "wave_number": 1,
  "trigger_day": 3,
  "trigger_hour": 18,
  "spawn_point": "front_gate",
  "enemies": [
    {
      "enemy_id": "raider_basic",
      "count": 3
    }
  ],
  "notes": "第一波用于验证最小战斗闭环。"
}
```

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
- `importance`：用于 LLM 摘要、见闻裁剪和睡前总结。
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

格式化器负责把 ID 展开成显示名，例如 `blacksmith_01` 展开为格伦，`work_make_weapons` 展开为打造武器，`iron` 展开为铁。底层事件继续保存稳定 ID。

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

必备事件类型方向：

- 日常与计划：`wake_up`、`plan_created`、`reflection_started`、`sleep_started`、`sleep_ended`
- 移动与地点：`location_entered`、`location_exited`
- 工作与生活：`work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`
- 对话：`dialogue_turn`；打开/关闭对话窗口不属于事件
- 玩家交互：`money_given`、`equipment_given`、`equipment_changed`、`order_assigned`、`npc_attacked_by_player`；`order_assigned` 固定为 `private`
- 成长与状态：`skill_improved`、`npc_recruited`、`npc_left_recruited_state`
- 战斗：`combat_started`、`combat_ended`、`attack_made`、`damage_taken`、`low_hp_triggered`、`unconscious_started`、`healing_started`、`healing_completed`、`revived`、`escape_started`、`escaped`
- 建筑与资源：`building_damaged`、`building_repaired`、`building_upgraded`、`resource_changed`

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
    "max_rounds": 5
  }
}
```

对话事件首先进入说话者与听者双方的事件库；如果事件 `visibility == "local_public"`，再由事件地点按公开规则广播给同地点第三者的见闻库。后端 `/npc/dialogue` 只返回回复文本与意向，不直接写入该 payload。

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
    "satiety_delta": -4,
    "fatigue_delta": 8,
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

`healing_completed` 使用 `healer_npc_id`、`target_npc_id` 和 `money_spent` 字段，不写入原因字段。治疗开始/完成会分别写入治疗者和目标 NPC 的事件库，并写入目标当前信息地点其他在场 NPC 的见闻库；事件信息不暴露医术熟练度。`revived` 的 summary 只表达 NPC 苏醒，不展示 HP 恢复到多少。

T0404 adds plaza state event types: `plaza_notice_changed` and `plaza_status_changed`; T0403/T0405 now also use `location_status_changed` for current building-state broadcasts. Plaza snapshots use `building_external_states` for every building's propagatable external state; `key_entities` is kept as a compatibility alias for that same external-state dictionary. The plaza itself has no building HP and exposes `has_building_hp == false` and `current_enemy_count`. Status event summaries must name the specific building and concrete state that changed, without generic prefixes such as "建筑状态更新".

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
  ],
  "daily_summary": ""
}
```

`event_log` 和 `witness_log` 都保存事件 ID，具体事件内容由 MemorySystem 的事件存储查询。这样可以避免重复复制大 payload，也能区分亲历与听闻。

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
    ]
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
      "condition": "intact"
    },
    "chapel": {
      "level": 1,
      "condition": "intact"
    }
  }
}
```

主厅、围墙、城门、后门、仓库等不可进入实体不作为 NPC 常规进入地点；它们只提供可传播外部状态，不暴露内部 NPC、NPC 状态或工位状态。所有建筑的可传播外部状态进入广场 `building_external_states`。受损、修复、升级和等级变化等公开状态变化通过广场节点即时广播给当时在场的 NPC。HP、Max HP、剩余修复/升级时长和工位数量不属于传播状态。NPC 进入广场时，应在进入者的见闻库写入当前广场在场 NPC、这些 NPC 的生命状态/行动状态、当前公告文本和这些建筑当前状态，但 `location_entered` 事件本身只记录进入广场的行动事实，不包含过去事件历史。

## LLM Dialogue Response

T0601 后，后端 AI Schema 放在 `backend/schemas/`，使用 Pydantic 定义。Schema 是前后端数据合同，不调用真实模型，不执行 HP、资源、建筑、移动或战斗等权威结算。

共享上下文位于 `backend/schemas/common.py`：

- `GameTime`：`day`、`time`、`hour`。
- `ModelRequestMeta`：`request_id`、`call_type`、来源、是否需要 TimeSystem 慢速、关联事件 id。
- `NPCContext`：NPC 身份、运行时状态、短期记忆摘要、知识图谱、当前地点上下文和广场上下文；T0703A 后还包含当前 `current_order`。
- `ShortTermMemoryContext`：分开的 `experienced_events` 与 `witnessed_events`。
- `ActionCandidate`：后续计划/修订可选择的行动候选。

对话 Schema 位于 `backend/schemas/npc_ai.py`：

- `NPCDialogueRequest`：覆盖 `player_npc`、`npc_npc`、`escape_intervention`。T0603 后输入以目标 NPC `npc_id` / `npc_name` / `npc_setting`，说话者 `speaker_name` / `speaker_text` / `speaker_context`，`is_recruitment_request`，`current_round` / `max_rounds`，`npc_state`，`dialogue_state`，`short_memory`，`long_memory` 和 `location_context` 为主。
- `NPCDialogueResponse`：返回 `replyer_id`、`reply_text`、`response_kind`、`intent`、`emotion`、`recruitment_result`、`should_end_dialogue` 和建议事件类型。回复玩家时读取 `recruitment_result`；回复 NPC 时读取 `reply_text` 与 `should_end_dialogue`。它只表达 NPC 意向；征召状态变化和事件写入由 Godot 系统完成。

T0703A 后，`backend/schemas/common.py` 使用 `CurrentOrderContext` 规范化当前文本、发布者、最近发布时间和修订号。共享 `NPCContext` 和 `NPCDialogueRequest` 都包含 `current_order`；`DailyPlanRequest`、`PlanRevisionRequest`、`BattleJudgementRequest`、主动交涉、逃离判断、睡前总结和知识图谱更新等 NPC 中心请求复用同一字段。该字段是参考上下文，不是权威行动或 system prompt。

## LLM Battle Judgement Response

战斗判定 Schema：

- `BattleJudgementRequest`：包含触发类型 `combat_started` / `low_hp` / `escape_check`、NPC 上下文、战斗上下文和允许判定结果。
- `BattleJudgementResponse`：返回 `join_battle`、`avoid_battle`、`continue_fighting`、`escape_station` 或 `inspired` 等意向，以及情绪和调试原因。伤害、移动、逃离和状态仍由 Godot 结算。

其他 T0601 后端 AI Schema：

- `DailyPlanRequest` / `DailyPlanResponse`：每日计划；响应必须包含 24 条 `PlanItem`。
- `PlanRevisionRequest` / `PlanRevisionResponse`：计划执行失败或异常后的计划修订。
- `DailyReflectionRequest` / `DailyReflectionResponse`：睡前总结、日记和知识图谱增量。
- `KnowledgeGraphUpdateRequest` / `KnowledgeGraphUpdateResponse`：独立知识图谱更新。
- `ProactiveIntentionRequest` / `ProactiveIntentionResponse`：NPC 是否主动找守备官交涉。
- `PlayerStrategyClassificationRequest` / `PlayerStrategyClassificationResponse`：把守备官话术分类为说服、利诱、威胁、欺骗、安抚、交易、命令或未知。
