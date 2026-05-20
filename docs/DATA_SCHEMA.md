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

## NPC Profile

```json
{
  "id": "horseman_01",
  "name": "待定",
  "background_job": "马夫",
  "personality": ["谨慎", "重感情", "怕死"],
  "desires": ["保护马厩", "活下来"],
  "fears": ["被派上前线", "马匹被征用"],
  "boundaries": ["不能接受无意义牺牲"],
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
    "unconscious": false
  },
  "skills": {
    "养马": 70,
    "骑术": 45,
    "厨艺": 5,
    "剑盾": 0,
    "弓": 5
  },
  "recruited": false,
  "equipment": {},
  "knowledge_graph": {},
  "diary": []
}
```

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
  "id": "work_repair_wall",
  "name": "修补围墙",
  "type": "work",
  "location_required": "front_wall",
  "skill": "工匠",
  "base_duration_hours": 1,
  "input_resources": {
    "wood": 1,
    "stone": 1
  },
  "output_resources": {},
  "fatigue_delta": 8,
  "satiety_delta": -4
}
```

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
