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
  "equipment": {},
  "plan": [],
  "short_term_memory": [],
  "knowledge_graph": {},
  "diary": []
}
```

T0301 起，`data/npc_profiles.json` 已使用该结构补齐 8 名初始 NPC。`gender`、`appearance`、`background_story`、`abilities`、`plan`、`short_term_memory` 为 NPC 档案必填基础字段；`background_job` 只保留叙事出身，`boundaries`、`stats` 继续供后续计划、征召、对话和战斗心理判定使用。开局只有 `veteran_deputy_01` 的 `recruited` 为 `true`，其他 NPC 均为 `false`。

T0304 起，运行时 `NPCSystem` 会读取并更新 `states` 下的 `hp`、`max_hp`、`satiety`、`fatigue`、`money`、`unconscious`、`escaped`、`current_action` 字段，并将 `stats.strength` / 力量、`stats.intelligence` / 智力、`recruited` 与 `skills` 展示到 NPC 面板。移动系统会在运行时补齐和更新 `current_location`、`current_location_name`、`movement_target`、`movement_target_name` 和 `location_context`；这些字段当前作为地点进入占位，不要求手动写入 `data/npc_profiles.json`。当前不实现自然变化、治疗结算、真实日程或 LLM 地点解读。

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

只有可进入建筑使用 `workstations` 表达内部状态。主厅、围墙、城门、后门、仓库等不可进入建筑应保留 HP、等级、修复/升级等权威状态，但 `workstations` 为空，且不会在广场外部状态中暴露内部 NPC 或工位。NPC 见闻传播使用的建筑外部状态只包含等级和完好/受损/正在修复/正在升级。

公告牌不使用 Building Definition。主厅前的 `NoticeBoard` 节点只是视觉占位和后续公告输入接口，不能配置 `hp`、`max_hp`、`workstations`、`repair` 或 `upgrade`；公告文本应写入广场 Location Info Node 的当前状态。

## Action Definition

```json
{
  "id": "work_garden",
  "name": "照料菜园",
  "type": "work",
  "location_required": "garden",
  "skill": "耕种",
  "duration_seconds": 3600,
  "input_resources": {},
  "output_resources": {
    "grain": 2
  },
  "fatigue_delta": 8,
  "satiety_delta": -4
}
```

T0305 起，行动定义支持三类 JSON 最小行动；2026-05-25 起，行动时长优先使用 `duration_seconds`，旧的 `base_duration_hours` 仅保留为兼容字段。行动抵达地点后按 TimeSystem 逻辑秒推进，不应在抵达瞬间完成。协助修复/协助升级是运行时参数化行为，不作为每个建筑一条固定 JSON 行动：

- `work`：读取 `location_required`、`duration_seconds`、`input_resources`、`output_resources`、`fatigue_delta`、`satiety_delta` 后由程序结算。当前以 3600 秒作为最小工作批次，批次结束时结算输入、产出和状态变化。
- `eat`：使用 `food_options` 数组定义可消耗食物及饱食度恢复量，当前餐食优先于粮食。标准餐食时长为 1200 秒，完整进餐恢复约 50 点饱食度。
- `sleep`：通过 `duration_seconds`、`fatigue_delta` 和 `satiety_delta` 调整 NPC 状态。当前睡眠基准为 23400 秒降低 100 点疲劳，并按逻辑秒逐步结算。

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

必备事件类型方向：

- 日常与计划：`wake_up`、`plan_created`、`reflection_started`、`sleep_started`、`sleep_ended`
- 移动与地点：`location_entered`、`location_exited`
- 工作与生活：`work_started`、`work_completed`、`work_failed`、`repair_assist_started`、`upgrade_assist_started`、`eat_started`、`eat_completed`
- 对话：`dialogue_started`、`dialogue_turn`、`dialogue_ended`
- 玩家交互：`money_given`、`equipment_given`、`equipment_changed`、`order_assigned`、`npc_attacked_by_player`
- 成长与状态：`skill_improved`、`npc_recruited`、`npc_left_recruited_state`
- 战斗：`combat_started`、`combat_ended`、`attack_made`、`damage_taken`、`low_hp_triggered`、`unconscious_started`、`healing_started`、`healing_completed`、`revived`、`escape_started`、`escaped`
- 建筑与资源：`building_damaged`、`building_repaired`、`building_upgraded`、`resource_changed`

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
    "output_resources": {"grain": 2},
    "building_hp_restore": 0,
    "satiety_delta": -4,
    "fatigue_delta": 8,
    "duration_seconds": 3600
  }
}
```

T0404 adds plaza state event types: `plaza_notice_changed` and `plaza_status_changed`; T0403/T0405 now also use `location_status_changed` for current building-state broadcasts. Plaza snapshots use `building_external_states` for every building's propagatable external state; `key_entities` is kept as a compatibility alias for that same external-state dictionary. The plaza itself has no building HP and exposes `has_building_hp == false` and `current_enemy_count`. Status event summaries must name the specific building and concrete state that changed, without generic prefixes such as "建筑状态更新".

Revised event payload rule: `location_entered` and `location_exited` only store movement facts such as `from_location_id` and `to_location_id`. They do not store full `location_snapshot` payloads. The entering NPC receives one separate witness entry containing the current location snapshot. NPCs already present receive only the local public enter/exit event; they do not receive a duplicate full `people_present` snapshot. Later state events should carry changed fields only, such as a changed building condition, a level change, a notice change, or one workstation occupancy change.

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

地点/建筑信息节点只描述当前状态和广播所需的路由信息，不保存事件历史。`current_public_note_ids` / `public_notes` 用于当前公告或命令；普通建筑不拥有公告牌字段，当前公告文本只保存在广场状态中。公开事件发生时由节点即时转发给当时在场的 NPC，接收者把事件写入自己的 `witness_log`。NPC 进入地点时，完整当前状态只写给进入者的见闻库；已经在场的 NPC 通过 `location_entered` / `location_exited` 事件得知人员变化，不再接收完整 `people_present` 状态。除进入者的一次性快照外，状态广播应使用字段级差量。

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

主厅、围墙、城门、后门、仓库等不可进入实体不作为 NPC 常规进入地点；它们只提供可传播外部状态，不暴露内部 NPC 或工位状态。所有建筑的可传播外部状态进入广场 `building_external_states`。受损、修复、升级和等级变化等公开状态变化通过广场节点即时广播给当时在场的 NPC。HP、Max HP、剩余修复/升级时长和工位数量不属于传播状态。NPC 进入广场时，应在进入者的见闻库写入这些当前状态，但 `location_entered` 事件本身只记录进入广场的行动事实，不包含过去事件历史。

## LLM Dialogue Response

```json

```

## LLM Battle Judgement Response

```json

```
