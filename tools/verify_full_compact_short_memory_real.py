from pathlib import Path
import os
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from tools.station_context_fixture import build_station_context
from tools.verify_dialogue_prompt_real import _base_payload


REQUEST_ID = "verify_full_compact_short_memory_real"


def _memory_event(
    index: int,
    *,
    event_type: str = "work_started",
    summary: str = "",
    importance: int = 35,
) -> dict:
    return {
        "type": event_type,
        "summary": summary or f"格伦随后处理了第 {index} 项普通事务。",
        "importance": importance,
        "day": 3,
        "time": f"{15 + (index // 60):02d}:{index % 60:02d}:00",
    }


def _payload() -> dict:
    payload = _base_payload(
        REQUEST_ID,
        "格伦，你刚才为什么把铁匠铺工作改成了照料菜园？"
        "现在仓库里已经有20份铁，但请按你自己的短期记忆说明当时改计划的直接原因，"
        "不要用当前库存改写过去。",
    )
    payload.update({
        "npc_id": "blacksmith_01",
        "npc_name": "格伦",
        "npc_setting": {
            "background_job": "铁匠",
            "personality": ["务实", "寡言", "重视材料和工序"],
            "desires": ["让铁匠铺持续运转", "不浪费有限材料"],
            "fears": ["无料空耗工时", "制造计划脱离库存现实"],
            "boundaries": ["不把尚未获得的材料当作已经到货"],
        },
        "station_context": build_station_context([
            {"npc_id": "blacksmith_01", "name": "格伦", "identity": "铁匠"},
            {"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"},
        ]),
        "npc_state": {
            "hp": 100,
            "max_hp": 100,
            "satiety": 72,
            "fatigue": 28,
            "money": 2,
            "wine": 0,
            "recruited": False,
            "unconscious": False,
            "escaped": False,
            "equipment": {},
            "current_action": "work_garden",
            "current_location": "garden",
        },
        "current_order": {},
        "dialogue_state": {
            "visibility": "local_public",
            "location_id": "garden",
            "location_name": "菜园",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", "blacksmith_01"],
        },
        "location_context": {
            "location_id": "garden",
            "location_name": "菜园",
            "people_present": ["blacksmith_01"],
        },
        "long_memory": {
            "diary": ["打铁最怕拿还没到手的料去排工序。"],
            "knowledge_graph": {
                "blacksmith": {"rule": "制造前先核对实际铁料"}
            },
        },
        "allowed_actions": [
            {
                "action_id": "work_blacksmith",
                "name": "推进铁匠铺制造",
                "action_kind": "work",
                "location_id": "blacksmith",
                "tags": ["work"],
                "context": {"authority": "ActionSystem"},
            },
            {
                "action_id": "work_garden",
                "name": "照料菜园",
                "action_kind": "work",
                "location_id": "garden",
                "tags": ["work"],
                "context": {"authority": "ActionSystem"},
            },
            {
                "action_id": "sleep_in_dormitory",
                "name": "睡觉",
                "action_kind": "sleep",
                "location_id": "dormitory",
                "tags": ["sleep"],
                "context": {"authority": "ActionSystem"},
            },
        ],
    })
    payload["station_context"]["basic_resource_reserves"] = [
        {"resource_id": "grain", "name": "粮食", "amount": 3},
        {"resource_id": "meal", "name": "餐食", "amount": 2},
        {"resource_id": "wood", "name": "木材", "amount": 5},
        {"resource_id": "stone", "name": "石料", "amount": 4},
        {"resource_id": "iron", "name": "铁", "amount": 20},
    ]

    experienced_events = [
        {
            "type": "plan_revised",
            "summary": "格伦重估计划，把原定的铁匠铺制造改成照料菜园。",
            "importance": 80,
            "day": 3,
            "time": "14:00:00",
            "details": {
                "trigger": "work_failed",
                "reason": "当时铁匠铺因铁料不足，无法继续当前制造工序。",
                "resource_gap": {
                    "resource_id": "iron",
                    "available": 0,
                    "required": 2,
                },
                "plan_segments": [
                    {
                        "from_hour": 14,
                        "to_hour": 16,
                        "action_id": "work_garden",
                        "location_id": "garden",
                    }
                ],
            },
        }
    ]
    experienced_events.extend(_memory_event(index) for index in range(1, 13))

    witnessed_events = [
        {
            "type": "resource_changed",
            "summary": "守备官后来把仓库铁料调整为20份。",
            "importance": 65,
            "day": 3,
            "time": "15:20:00",
            "details": {
                "resource_id": "iron",
                "amount_after": 20,
                "change_source": "gm",
            },
        }
    ]
    witnessed_events.extend(
        _memory_event(
            index,
            event_type="location_entered",
            summary=f"格伦看见第 {index} 名站员经过广场。",
            importance=15,
        )
        for index in range(1, 13)
    )
    payload["short_memory"] = {
        "experienced_events": experienced_events,
        "witnessed_events": witnessed_events,
    }
    return payload


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print(
            "verify_full_compact_short_memory_real: skipped "
            "(non-mock LLM_PROVIDER and LLM_API_KEY required)"
        )
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    client = create_app().test_client()
    response = client.post("/npc/dialogue", json=_payload())
    body = response.get_json()
    assert response.status_code == 200, body
    assert body["model_provider"] == provider, body
    assert body["model_fallback_used"] is False, body

    reply = str(body["reply_text"]).replace(" ", "")
    assert "铁" in reply, reply
    assert any(fragment in reply for fragment in ["不足", "不够", "缺铁", "没铁", "没有铁"]), reply
    assert any(fragment in reply for fragment in ["当时", "那时", "之前", "原先", "后来", "现在"]), reply

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    records = [
        record
        for record in usage["records"]
        if record.get("request_id") == REQUEST_ID
    ]
    assert len(records) == 1, records
    record = records[0]
    assert record["success"] is True, record
    assert record["fallback_used"] is False, record

    print(
        "verify_full_compact_short_memory_real: ok "
        f"provider={record['provider']} model={record['model']} "
        f"input_tokens={record['input_tokens']} output_tokens={record['output_tokens']} "
        f"estimated_cost={record['estimated_cost']:.8f} reply={body['reply_text']!r}"
    )


if __name__ == "__main__":
    main()
