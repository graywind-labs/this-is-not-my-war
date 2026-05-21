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

T0304 修正后，`skills` 是固定全集，每名 NPC 必须都有且只能有以下 13 个熟练度维度，取值范围 0-100：

- 职业熟练度：`养马`、`厨艺`、`耕种`、`打铁`、`教练`、`酿酒`、`医术`、`工程`
- 武器熟练度：`剑盾`、`长杆`、`弓`、`弩`、`骑术`

`background_job` 只表示叙事背景，不作为权威职业分类。实际“职业倾向 / 专长”由这些熟练度的高低推导；运行时 `NPCSystem.normalize_skills(...)` 会按固定全集补齐缺失值并丢弃未定义技能。

## Building Definition

```json
{
  "id": "main_hall",
  "name": "主厅",
  "level": 1,
  "hp": 180,
  "max_hp": 180,
  "tags": ["command", "failure_target"],
  "scene_nodes": ["MainHall"],
  "workstations": [
    {
      "id": "command_table_01",
      "type": "command",
      "occupied_by": null
    }
  ],
  "inputs": {},
  "outputs": {},
  "repair": {
    "cost": {"stone": 1},
    "hp_restore": 25
  },
  "upgrade": {
    "cost": {"stone": 4},
    "max_level": 3,
    "max_hp_bonus": 30,
    "workstation_bonus": 0,
    "workstation_type": "command"
  }
}
```

`repair` / `upgrade` 为 T0205 起使用的可选字段。未配置时建筑面板会禁用对应按钮；已配置时由 `BuildingSystem` 调用 `ResourceSystem.spend_resources` 进行资源结算。

## Action Definition

```json
{
  "id": "work_garden",
  "name": "照料菜园",
  "type": "work",
  "location_required": "garden",
  "skill": "耕种",
  "base_duration_hours": 1,
  "input_resources": {},
  "output_resources": {
    "grain": 2
  },
  "fatigue_delta": 8,
  "satiety_delta": -4
}
```

T0305 起，行动定义支持三类最小行动：

- `work`：读取 `location_required`、`input_resources`、`output_resources`、`building_hp_restore`、`fatigue_delta`、`satiety_delta` 后由程序结算。
- `eat`：使用 `food_options` 数组定义可消耗食物及饱食度恢复量，当前餐食优先于粮食。
- `sleep`：通过 `fatigue_delta` 和 `satiety_delta` 调整 NPC 状态。

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

## Event Log

```json
{
  "time": "Day3 09:00",
  "type": "battle_public_info",
  "location": "广场",
  "actors": ["doctor_01", "enemy_03"],
  "content": "医生在战斗中被敌人击倒，HP 清零后进入昏迷状态。",
  "importance": 85,
  "visible_to_public_square": true
}
```

## Location Info Space

```json
{
  "id": "chapel",
  "name": "小教堂",
  "building_hp": 100,
  "level": 1,
  "people_present": ["priest_01", "doctor_01"],
  "workstations": [
    {
      "id": "altar",
      "occupied_by": "priest_01"
    }
  ],
  "recent_events": [],
  "public_notes": []
}
```

## LLM Dialogue Response

```json

```

## LLM Battle Judgement Response

```json

```
