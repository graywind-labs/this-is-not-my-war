from pathlib import Path
import os
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import (  # noqa: E402
    CurrentOrderContext,
    DailyReflectionResponse,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    ShortTermMemoryContext,
)


def _payload() -> dict:
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="doctor_01",
            name="莉娜",
            background_job="医生",
            personality=["冷静", "说话直接", "讨厌把牺牲说得轻巧"],
            desires=["让伤员活下来", "保住诊所的秩序"],
            fears=["所有人都把命令看得比止血更重要"],
            boundaries=["不会把昏迷者当成可消耗的东西"],
        ),
        state=NPCStateContext(
            hp=86,
            max_hp=100,
            satiety=66,
            fatigue=81,
            current_location="dormitory",
            current_location_name="宿舍",
            recruited=False,
            skills={"医术": 84, "工程": 20, "剑盾": 6},
            equipment={},
        ),
        current_order=CurrentOrderContext(
            text="今晚先睡，醒来后优先照看伤员，不要被任何人催去城门。",
            issued_by="guard_officer",
            issued_day=2,
            issued_time="21:20:00",
            revision=2,
        ),
        short_term_memory=ShortTermMemoryContext(
            experienced_events=[
                {
                    "event_id": "evt_heal",
                    "type": "healing_completed",
                    "summary": "莉娜结束了对布鲁诺的治疗。",
                    "importance": 80,
                }
            ],
            witnessed_events=[
                {
                    "event_id": "evt_alarm",
                    "type": "combat_alarm_rang",
                    "summary": "莉娜听到了警铃，守备官正在召集所有人。",
                    "importance": 70,
                }
            ],
        ),
        knowledge_graph={
            "by_subject": {
                "guard_officer": {
                    "impression": {
                        "value": "会下急命令，但今天允许医生照看伤员",
                        "confidence": 0.65,
                    }
                }
            }
        },
        location_context={"location_id": "dormitory", "people_present": ["doctor_01"]},
        plaza_context={"notice": "第 3 天傍晚可能有敌袭。"},
    )
    return {
        "meta": ModelRequestMeta(
            request_id="verify_daily_reflection_prompt_real",
            call_type="daily_reflection",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=2, time="22:30:00", hour=22).model_dump(),
        "npc": npc.model_dump(),
        "day_events": [
            {
                "event_id": "evt_heal",
                "type": "healing_completed",
                "summary": "莉娜结束了对布鲁诺的治疗。",
                "importance": 80,
                "memory_kind": "experienced",
            },
            {
                "event_id": "evt_alarm",
                "type": "combat_alarm_rang",
                "summary": "莉娜听到了警铃，守备官正在召集所有人。",
                "importance": 70,
                "memory_kind": "witnessed",
            },
        ],
        "existing_diary_entries": ["我不喜欢他们把命令说得像止血布。"],
    }


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_daily_reflection_prompt_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_MAX_TOKENS"] = "1800"
    os.environ["LLM_TEMPERATURE"] = "0.4"

    client = create_app().test_client()
    response = client.post("/npc/daily_reflection", json=_payload())
    assert response.status_code == 200, response.get_json()
    body = response.get_json()
    reflection = DailyReflectionResponse(**body)
    assert reflection.npc_id == "doctor_01"
    assert reflection.day == 2
    assert reflection.diary_entry
    assert reflection.memory_summary
    assert "玩家" not in reflection.diary_entry
    assert "玩家" not in reflection.memory_summary
    for update in reflection.knowledge_graph_updates:
        assert update.subject
        assert update.relation
        assert update.value
        assert "玩家" not in update.subject
        assert "玩家" not in update.relation
        assert "玩家" not in update.value

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] >= 1
    assert usage["summary"]["failed"] == 0
    assert all(record["fallback_used"] is False for record in usage["records"])

    print(
        "verify_daily_reflection_prompt_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} calls={usage['summary']['count']}"
    )


if __name__ == "__main__":
    main()
