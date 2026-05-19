# DATA_SCHEMA.md

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
  "id": "canteen",
  "name": "食堂",
  "level": 1,
  "hp": 100,
  "max_hp": 100,
  "workstations": [
    {
      "id": "kitchen_01",
      "type": "cooking",
      "occupied_by": null
    }
  ],
  "inputs": {
    "粮食": 1
  },
  "outputs": {
    "餐食": 1
  }
}
```

## Action Definition

```json
{
  "id": "work_cooking",
  "name": "在食堂做饭",
  "type": "work",
  "location_required": "canteen",
  "skill": "厨艺",
  "base_duration_hours": 1,
  "input_resources": {
    "粮食": 1
  },
  "output_resources": {
    "餐食": 1
  },
  "fatigue_delta": 5,
  "satiety_delta": -5
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
