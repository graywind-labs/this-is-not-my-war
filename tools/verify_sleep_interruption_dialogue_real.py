from pathlib import Path
import os
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import (
    GameTime,
    ModelRequestMeta,
    NPCDialogueRequest,
    PlayerNPCDialogueResponse,
    SpeakerContext,
)
from tools.station_context_fixture import build_station_context


REQUEST_ID = "verify_sleep_interruption_dialogue_real"


def _payload() -> dict:
    return {
        "meta": ModelRequestMeta(
            request_id=REQUEST_ID,
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=2, time="00:30:00", hour=0).model_dump(),
        "station_context": build_station_context([
            {"npc_id": "cook_01", "name": "布鲁诺", "identity": "厨子"}
        ]),
        "dialogue_kind": "player_npc",
        "dialogue_phase": "conversation",
        "npc_id": "cook_01",
        "npc_name": "布鲁诺",
        "npc_setting": {
            "background_job": "厨子",
            "personality": ["谨慎", "嘴硬", "睡眠不足时脾气更差"],
            "desires": ["保住食堂", "明早有精神继续做饭"],
            "fears": ["疲惫时把餐食做坏"],
            "boundaries": ["不把尚未做的事说成已经完成"],
            "speech_style": "直白、略带抱怨，但会明确说明眼下事实和接下来的打算。",
        },
        "speaker_name": "守备官",
        "speaker_text": "我刚把你叫起来。你刚才在干什么？谈完以后准备做什么？",
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，站在宿舍床边。",
        ).model_dump(),
        "is_recruitment_request": False,
        "current_round": 1,
        "max_rounds": 999999,
        "npc_state": {
            "hp": 100,
            "max_hp": 100,
            "satiety": 72,
            "fatigue": 70,
            "current_action": "talk_to_guard_officer",
            "behavior_mode": "work",
            "current_location": "dormitory",
            "current_location_name": "宿舍",
            "recruited": False,
            "unconscious": False,
            "escaped": False,
            "equipment": {},
            "money": 1,
            "wine": 0,
        },
        "current_order": {
            "text": "",
            "issued_by": "guard_officer",
            "issued_day": 0,
            "issued_time": "",
            "revision": 0,
        },
        "dialogue_state": {
            "visibility": "private",
            "location_id": "dormitory",
            "location_name": "宿舍",
            "current_round": 1,
            "max_rounds": 999999,
            "participants": ["guard_officer", "cook_01"],
        },
        "interrupted_activity_context": {
            "interrupted_by_guard_officer": True,
            "private_to_target_npc": True,
            "activity_before_interruption": {
                "action_id": "sleep_in_dormitory",
                "action_name": "睡觉",
                "phase": "active",
                "location_id": "dormitory",
                "location_name": "宿舍",
                "workstation_id": "dormitory_bed_03",
                "elapsed_seconds": 1800.0,
                "duration_seconds": 23400.0,
            },
            "current_plan_activity": {
                "action_id": "sleep_in_dormitory",
                "action_name": "睡觉",
                "phase": "planned",
                "day": 2,
                "hour": 0,
                "location_id": "dormitory",
                "location_name": "宿舍",
            },
            "expected_activity_after_dialogue": {
                "action_id": "sleep_in_dormitory",
                "action_name": "睡觉",
                "phase": "planned",
                "day": 2,
                "hour": 0,
                "location_id": "dormitory",
                "location_name": "宿舍",
            },
            "resume_policy": "resume_interrupted_activity_if_plan_unchanged",
            "resume_expected_if_plan_unchanged": True,
        },
        # The interruption is intentionally absent from memory. It is ephemeral
        # session context and must not be disguised as an experienced event.
        "short_memory": {
            "experienced_events": [],
            "witnessed_events": [],
        },
        "long_memory": {
            "knowledge_graph": {},
            "diary": ["往昔·近日：夜里睡够了，第二天的锅才不会出岔子。"],
        },
        "location_context": {
            "location_id": "dormitory",
            "location_name": "宿舍",
            "people_present": ["cook_01"],
        },
        "allowed_actions": [
            {
                "action_id": "sleep_in_dormitory",
                "name": "睡觉",
                "action_kind": "sleep",
                "location_id": "dormitory",
                "tags": ["sleep"],
                "context": {"eligible": True, "available_now": True},
            },
            {
                "action_id": "work_dining_hall",
                "name": "加工餐食",
                "action_kind": "work",
                "location_id": "dining_hall",
                "tags": ["work"],
                "context": {"eligible": True, "available_now": True},
            },
        ],
    }


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        print(
            "verify_sleep_interruption_dialogue_real: skipped "
            "(non-mock LLM_PROVIDER and LLM_API_KEY required)"
        )
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    payload = _payload()
    parsed_request = NPCDialogueRequest.model_validate(payload)
    assert parsed_request.interrupted_activity_context is not None
    assert not parsed_request.short_memory.experienced_events

    client = create_app().test_client()
    response = client.post("/npc/dialogue", json=payload)
    body = response.get_json()
    assert response.status_code == 200, body
    assert body["model_provider"].strip().lower() == provider, body
    assert body["model_fallback_used"] is False, body
    parsed = PlayerNPCDialogueResponse(**{
        key: value for key, value in body.items() if not key.startswith("model_")
    })
    reply = parsed.reply_text.replace(" ", "")
    assert "睡" in reply, reply
    assert any(
        marker in reply
        for marker in ["叫醒", "吵醒", "打断", "刚才在睡", "刚才还在睡", "正睡"]
    ), reply
    assert any(
        marker in reply
        for marker in ["继续睡", "接着睡", "回去睡", "睡完", "再睡", "回床", "躺回"]
    ), reply
    assert not any(
        false_claim in reply
        for false_claim in [
            "刚醒正准备去干活",
            "刚醒来准备去干活",
            "睡醒了准备去干活",
            "马上去干活",
            "正准备去工作",
        ]
    ), reply

    usage = client.get("/debug/llm_usage").get_json()
    records = [
        record
        for record in usage["records"]
        if record.get("request_id") == REQUEST_ID
    ]
    assert records, usage
    assert records[-1]["provider"] == provider
    assert records[-1]["fallback_used"] is False
    assert records[-1]["success"] is True
    print(
        "verify_sleep_interruption_dialogue_real: ok "
        f"provider={provider} model={body['model_name']} reply={parsed.reply_text!r}"
    )


if __name__ == "__main__":
    main()
