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

T0305 起，`resource_defs.json` 增加派生资源 `meal` / 餐食、`wine` / 酒、`weapons` / 武器、`armor` / 盔甲、`defense_devices` / 工程器械、`horse_readiness` / 马匹整备，用于行动系统内部结算。T0901 起，`weapons` / `armor` / `horse_readiness` 也会被 `EquipmentSystem` 消耗，转换为已入伍 NPC 的具体装备槽。T0012 起，HUD 主栏按 `ui_order` 展示非聚合资源，武器、盔甲、马匹整备和工程器械只在装备/器械详情中展示，避免主栏重复。

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
  "equipment": {},
  "plan": [],
  "short_term_memory": [],
  "knowledge_graph": {},
  "diary": []
}
```

T0301 起，`data/npc_profiles.json` 已使用该结构补齐 8 名初始 NPC。`gender`、`appearance`、`background_story`、`abilities`、`plan`、`short_term_memory` 为 NPC 档案必填基础字段；`background_job` 只保留叙事出身，`boundaries`、`stats` 继续供后续计划、征召、对话和战斗心理判定使用。开局只有 `veteran_deputy_01` 的 `recruited` 为 `true`，其他 NPC 均为 `false`。

T0703 已为每名初始 NPC 配置并在运行时规范化 `current_order`。它保存守备官对该 NPC 当前持续提出的自然语言指令，而不是已执行行动：`text` 是当前文本，`issued_by` 固定为 `guard_officer`，`issued_day` / `issued_time` 记录最近一次变更时间，`revision` 在指令文本变化时递增。未入伍或尚无指令时 `text` 为空。发布相同文本或关闭指令面板不得修改该结构。

T1004/T1005 起，运行时 `diary` 保存首次睡眠总结生成的长期日记记录，初始档案仍可为空数组：

```json
{
  "day": 1,
  "time": "22:00:00",
  "entry": "今天我记住了这些事……",
  "memory_summary": "当天关键亲历和见闻摘要。",
  "source": "backend_daily_reflection",
  "debug_reason": "mock_reflection_template"
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
        "day": 1,
        "time": "22:00:00"
      }
    }
  }
}
```

该结构是 NPC 对当前关键信息的认知状态；LLM 不负责直接改写 HP、资源、建筑或行动事实。

T1001 起，运行时 `plan` 可保存规则版每日计划。T1003 起，同一字段也可保存 `/npc/plan_day` 返回的 Mock / LLM 每日计划，或后端失败后的规则降级计划。计划必须是 24 个小时项，每项至少包含：

```json
{
  "hour": 7,
  "action_id": "work_garden",
  "action_name": "照料菜园",
  "source": "rule_default",
  "target": {},
  "reason": "按规则日程安排。"
}
```

计划由 `DailyPlanSystem` 生成和执行；常规 `action_id` 必须来自 `data/action_defs.json`，执行时仍由 `ActionSystem` 校验地点、工位、资源、HP 和行动合法性。T1003 后计划项 `source` 可为 `rule_default`、`mock_plan_day` 或 `rule_plan_fallback`；T1002 计划修订还可产生 `mock_revision` / `rule_revision_fallback`。`mock_*` source 只代表开发期 mock 结果，不得在生产 / 演示路径中用于掩盖真实 provider 失败；真实失败应记录技术日志并使用规则 / 模板降级 source。计划生成或修订可把当前小时改为 `idle` 安全等待项；`idle` 只表示计划层等待，不是生产行动定义。计划项不是已发生事实；只有实际执行的工作、吃饭、睡觉等行动事件才代表行动发生。

T0304 起，运行时 `NPCSystem` 会读取并更新 `states` 下的 `hp`、`max_hp`、`satiety`、`fatigue`、`money`、`unconscious`、`escaped`、`current_action` 字段，并将 `stats.strength` / 力量、`stats.intelligence` / 智力、`recruited` 与 `skills` 展示到 NPC 面板。移动系统会在运行时补齐和更新 `current_location`、`current_location_name`、`movement_target`、`movement_target_name` 和 `location_context`；这些字段当前作为地点进入占位，不要求手动写入 `data/npc_profiles.json`。T0808 起，诊所治疗可通过运行时恢复受伤 NPC 的 HP，并可最小提升医术。T0904 起，运行时会补齐 `progression` 成长结构：`total_experience` 记录熟练度提升同步得到的总经验，`skill_experience` 记录各熟练度累计经验，`unspent_skill_points` 是等待玩家分配的技能点，`spent_skill_points` 是已由玩家分配到属性的点数，`next_skill_point_xp` 当前为每 5 点总经验获得 1 个技能点。旧 NPC 档案可以不手动写入 `progression`，加载时会按默认值补齐。

T0901 起，运行时 `equipment` 可包含以下槽位：`main_weapon`、`helmet`、`chest`、`bracers`、`greaves`、`mount`。槽位内容由 `EquipmentSystem` 根据 `weapon_defs.json`、`armor_defs.json` 或 `mount_defs.json` 写入；`NPCSystem` 只保存槽位，不决定库存扣除、装备合法性或兵种。初始档案仍可为空对象 `{}`。T0902 起，兵种判定只读取该装备结构中的 `main_weapon` 与 `mount` 槽；全局 `horse_readiness` 库存不代表某个 NPC 已骑乘。T1103 起，运行时 `states` 可由 CombatSystem 写入 `combat_mode`、`combat_mounted`、`facing_direction`、`combat_target_enemy_id`、`formation_row` 和 `formation_index` 等临时战斗 / 集结状态；T1103A 起，`states.behavior_mode` 是工作 / 集结 / 战斗 / 避战 / 昏迷 / 逃离的统一模式字段，并保存进入原因和进入时间。T1103B/T1103C 起，非战斗人员避战可临时写入 `avoidance_target_id`、`avoidance_target_name` 和 `avoidance_target_position`，用于 GM / UI 快照查看当前按敌方方位生成的短步长避战方向。T1104 起，战斗中的 NPC 状态可临时写入 `combat_attack_cooldown`、`combat_last_attack_result` 和当前 `combat_target_enemy_id`，用于按战斗推进秒处理攻击间隔和 GM / 自动化观察最近攻击结果；T1104A 起这些冷却不直接读取玩家 `x2` / `x4` 作为攻速倍率。T1105 起，`states.combat_strategy` 保存玩家当前手动选择的战斗策略，`combat_strategy_move_target_id`、`combat_strategy_move_target_name` 和 `combat_strategy_move_target_position` 只表示策略移动的临时目标。T1201 起，`states.morale_boost` 保存战时对话产生的 2 游戏小时斗志 buff；T1204A 起，`states.escape_intent` 保存逃离触发、移动目标、开始 / 完成时间、挽留轮次、对话暂停标记、最近挽留结果和逃离移动倍率，`status` 可为 `escaping`、`paused_unconscious`、`stayed` 或 `escaped`。这些字段不要求写入初始 NPC 档案，且不代表装备库存或 HP 结算。

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

这些字段由程序根据对话 / 判定结果应用和清除，LLM 不能直接改写具体数值。移动期间 `escaped` 仍为 `false`；NPC 到达后门外出口后，`NPCSystem` 将 `escaped` 改为 `true`，把 `escape_intent.status` 改为 `escaped`，并记录 `completed_day` / `completed_time`。T1204A 后，`stay_after_intervention` 会把 `status` 改为 `stayed` 并停止移动；打开逃离挽留时 `movement_paused_for_dialogue=true` 并保存 `paused_dialogue_id`，关闭或满 5 轮继续逃离时清回 `false` 并记录 `last_dialogue_resume_reason`；逃离挽留攻击计入 1 轮但不产生 NPC 回复。逃离期间昏迷会暂记 `paused_unconscious`，复苏后恢复为 `escaping`。

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

只有可进入建筑使用 `workstations` 表达内部状态。T0801 起，运行时工位占用和释放由 `BuildingSystem.claim_workstation(...)` / `release_workstation(...)` 修改 `occupied_by`；地点信息节点只读取该状态并广播变化字段，不自行决定工作位权威状态。T0808 起，小诊所使用 `clinic_doctor` 表达医生坐诊/研读医术工位，使用 `patient_bed` 表达治疗病床；二者必须是不同工位类型。T0903 起，训练场使用 `training_instructor` 表达教官工位，使用 `training_student` 表达受训位；训练场升级可通过 `workstation_type="training_student"` 增加受训位。主厅、围墙、城门、后门、仓库等不可进入建筑应保留 HP、等级、修复/升级等权威状态，但 `workstations` 为空，且不会在广场外部状态中暴露内部 NPC、NPC 状态或工位。NPC 见闻传播使用的建筑外部状态只包含等级和完好/受损/正在修复/正在升级。运行时地点快照会为广场和可进入建筑生成 `people_statuses`，用于表达当前在场 NPC 的生命状态和行动状态；它来自 NPC 运行时状态，不要求写入 `data/building_defs.json`。

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
- `training_instructor`：T0903 新增，用于训练场教官工位。读取 `location_required="training_ground"`、`workstation_type="training_instructor"`、`skill="教练"`、`stat="intelligence"`、`solo_skill_interval_seconds`、`coaching_skill_interval_seconds`、`student_skill_interval_seconds`、`fatigue_delta_per_hour` 和 `satiety_delta_per_hour`。NPC 必须有主武器或坐骑才能执行；没有受训者时提升自己当前装备对应武器 / 骑术，有受训者时提升“教练”。
- `training_student`：T0903 新增，用于训练场受训位。读取 `location_required="training_ground"`、`workstation_type="training_student"`、`student_skill_interval_seconds`、`fatigue_delta_per_hour` 和 `satiety_delta_per_hour`。NPC 必须有主武器或坐骑且训练场已有有效教官才能执行；训练项目由受训者自己的当前主武器 / 坐骑决定。训练速度由程序读取教官“教练”、训练场等级和双方对应项目熟练度差，不由 UI 或 LLM 结算。
- `system`：T1204A 新增，用于 `escaping_station`、`escape_intervention_dialogue` 等系统状态在地点快照、NPC 面板和记忆摘要中显示中文名称；它不是普通 `assign_action` 可执行行动，不包含资源、工位或持续时间结算。

`assist_repair` 由 `ActionSystem.debug_assign_repair_assist(npc_id, building_id)` 接收 `building_id` 参数，并读取 `BuildingSystem` 当前是否存在修复作业。`assist_upgrade` 由 `ActionSystem.debug_assign_upgrade_assist(npc_id, building_id)` 接收 `building_id` 参数，并读取 `BuildingSystem` 当前是否存在升级作业。不要在 `data/action_defs.json` 中新增类似“修补围墙”或“升级菜园”的固定建筑行动；建筑 HP、资源预付、修复/升级倒计时和协助者加成都由 `BuildingSystem` 结算。协助修复/协助升级都是室外广场行为，事件 `location_id` 固定为 `plaza`，`visibility` 固定为 `local_public`，payload 通过 `building_id` 保留实际目标建筑。

## Weapon Definition

```json
{
  "id": "bow",
  "name": "弓",
  "equipment_slot": "main_weapon",
  "type": "ranged",
  "weapon_class": "bow",
  "combat_role": "archer",
  "source_resource_id": "weapons",
  "range": 12.0,
  "damage": 10,
  "attack_interval": 1.5,
  "required_skill": "弓",
  "tags": ["wooden", "ranged"]
}
```

T0901 后，`data/weapon_defs.json` 至少包含剑盾、长杆、弓、弩等可装备主武器。`source_resource_id` 当前统一指向派生库存 `weapons`；装备系统消耗库存后把完整定义副本写入 NPC `equipment.main_weapon`。T1104 起，CombatSystem 已读取 `range`、`damage` 和 `attack_interval`：`damage` 作为基础攻击力输入并受 NPC 力量修正，`range` 决定可攻击距离，`attack_interval` 作为基础攻击间隔并受武器熟练度、疲劳、饱食和坐骑 / 骑术修正。T1104B 起，`attack_interval` 的单位是战斗动作秒，CombatSystem 会把 `60` 游戏秒折算为 `1` 战斗动作秒后推进攻击冷却。T1104A 起，玩家时间倍率不参与伤害或攻击速度修正。装备 UI 仍不自行结算伤害。

## Armor Definition

```json
{
  "id": "mail_chest",
  "name": "锁子甲",
  "slot": "chest",
  "source_resource_id": "armor",
  "armor_value": 5,
  "weight": 4,
  "tags": ["metal", "body"]
}
```

T0901 后，`data/armor_defs.json` 覆盖 `helmet`、`chest`、`bracers`、`greaves` 四类盔甲槽。装备时消耗 1 个 `armor` 派生库存；T1104 起，CombatSystem 已读取四个盔甲槽的 `armor_value` 总和作为 NPC 防御，敌人攻击 NPC 时会先按防御减伤再扣 HP。`weight` 仍只是后续疲劳 / 负重系统的数据，不由 UI 直接结算。

## Mount Definition

```json
{
  "id": "riding_horse",
  "name": "整备马匹",
  "slot": "mount",
  "source_resource_id": "horse_readiness",
  "speed_bonus": 1.35,
  "required_skill": "骑术",
  "tags": ["horse"]
}
```

T0901 后，`data/mount_defs.json` 负责把马厩产出的 `horse_readiness` 映射到 NPC `equipment.mount` 槽。日常工作模式不显示骑乘；T1103 后集结 / 战斗模式会显示低模坐骑；T1105 后坐骑参与兵种判定并决定可选战斗策略，例如近战骑兵可选“主动进攻 / 拉开距离冲击 / 避战”，骑射单位可选“最大化输出 / 保持距离射击 / 避战”。`speed_bonus` 仍只是后续更完整骑乘移动数值的输入，不由 UI 直接结算。

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

`items` 保存 24 个小时计划项。`source` 可为 `rule_default`、`mock_plan_day` 或 `rule_plan_fallback`；后续真实模型来源应使用明确的新 source，真实 provider 失败不得写成 `mock_plan_day`。该事件表示计划被制定，不代表计划项已经执行；后续执行仍由对应行动事件记录。

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
    "source": "mock_revision",
    "summary": "Mock 将异常计划修订为等待状态。",
    "work_phase_count": 9
  }
}
```

`source` 当前可为 `mock_revision` 或 `rule_revision_fallback`；后续真实模型来源应使用明确的新 source，真实 provider 失败不得写成 `mock_revision`。该事件表示 NPC 重新评估了计划；是否移动、工作、吃饭、睡觉或等待仍由随后当前小时计划执行和 `ActionSystem` 结算决定。

必备事件类型方向：

- 日常与计划：`wake_up`、`plan_created`、`plan_revised`、`reflection_started`、`sleep_started`、`sleep_ended`
- 移动与地点：`location_entered`、`location_exited`
- 工作与生活：`work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`
- 对话：`dialogue_turn`；打开/关闭对话窗口不属于事件
- 玩家交互：`money_given`、`equipment_given`、`equipment_changed`、`order_assigned`；`order_assigned` 固定为 `private`。正式守备官惩戒攻击写入战斗 / 伤害类 `damage_taken`，payload 保留惩戒语境、攻击者和后续对话关联；`npc_attacked_by_player` 仅作为旧调试 / 兼容事件类型保留。
- 成长与状态：`skill_improved`、`npc_recruited`、`npc_left_recruited_state`
- 属性成长：`attribute_improved`，由玩家分配技能点到力量或智力时写入，payload 包含 `attribute`、`attribute_label`、`before`、`after`、`assigned_by`
- 战斗与行为模式：`npc_mode_changed`、`combat_alarm_rang`、`combat_rally_started`、`combat_rally_encountered_enemy`、`combat_started`、`combat_ended`、`attack_made`、`damage_taken`、`low_hp_triggered`、`battle_psychology_result`、`morale_boost_started`、`morale_boost_ended`、`avoidance_started`、`avoidance_ended`、`unconscious_started`、`healing_started`、`healing_completed`、`revived`、`escape_started`、`escaped`、`escape_intervention_result`、`escape_speed_changed`
- 建筑与资源：`building_damaged`、`building_repaired`、`building_upgraded`、`resource_changed`

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

- `NPCDialogueRequest`：覆盖 `player_npc`、`npc_npc`、`escape_intervention`。T0603 后输入以目标 NPC `npc_id` / `npc_name` / `npc_setting`，说话者 `speaker_name` / `speaker_text` / `speaker_context`，`is_recruitment_request`，`current_round` / `max_rounds`，`npc_state`，`dialogue_state`，`short_memory`，`long_memory` 和 `location_context` 为主。T1201 后，战时公开对话额外携带 `interaction_context` 和 `battlefield_context`。T1204A 后，逃离挽留中的玩家消息使用 `interaction_context == "escape_intervention"` 和 `escape_intervention_round`，响应 `intent` 只解析 `stay_after_intervention` / `leave_after_intervention`；逃离挽留攻击不构造该请求。
- `NPCDialogueResponse`：返回 `replyer_id`、`reply_text`、`response_kind`、`intent`、`emotion`、`recruitment_result`、`wartime_reaction`、`should_end_dialogue` 和建议事件类型。回复玩家时读取 `recruitment_result`；回复 NPC 时读取 `reply_text` 与 `should_end_dialogue`。集结 / 战斗模式下的已入伍 NPC 回复可返回 `wartime_reaction = none | escape | morale_boost`。它只表达 NPC 意向；征召状态变化、战时 buff、逃离、模式切换和事件写入由 Godot 系统完成。

T0703A 后，`backend/schemas/common.py` 使用 `CurrentOrderContext` 规范化当前文本、发布者、最近发布时间和修订号。共享 `NPCContext` 和 `NPCDialogueRequest` 都包含 `current_order`；`DailyPlanRequest`、`PlanRevisionRequest`、战时公开对话、低血量自身心理判定、主动交涉、逃离判断、首次睡眠总结和知识图谱更新等 NPC 中心请求复用同一字段。该字段是参考上下文，不是权威行动或 system prompt。

## LLM Battle Judgement Response

战斗判定 Schema：

- `BattleJudgementRequest`：取消旧式 `combat_started` 全员判定语义；T1202 后主要用于触发类型 `low_hp`，并保留后续 `escape_check`，包含 NPC 上下文、`combat_context`、`battlefield_context` 和 Godot 提供的允许判定结果。
- `BattleJudgementResponse`：返回 `join_battle`、`avoid_battle`、`continue_fighting`、`escape_station` 或 `inspired` 等意向，以及情绪和调试原因。T1202 中，参战 NPC 允许继续参战、逃离或斗志激昂；避战 / 非战斗人员只允许继续避战或逃离。伤害、buff、移动、逃离和模式状态仍由 Godot 结算。

其他 T0601 后端 AI Schema：

- `DailyPlanRequest` / `DailyPlanResponse`：每日计划；响应必须包含 24 条 `PlanItem`。
- `PlanRevisionRequest` / `PlanRevisionResponse`：计划执行失败或异常后的计划修订。
- `DailyReflectionRequest` / `DailyReflectionResponse`：首次睡眠总结、增量日记和替换式知识图谱键值更新。
- `KnowledgeGraphUpdateRequest` / `KnowledgeGraphUpdateResponse`：独立知识图谱更新。
- `ProactiveIntentionRequest` / `ProactiveIntentionResponse`：NPC 是否主动找守备官交涉。
- `PlayerStrategyClassificationRequest` / `PlayerStrategyClassificationResponse`：把守备官话术分类为说服、利诱、威胁、欺骗、安抚、交易、命令或未知。
