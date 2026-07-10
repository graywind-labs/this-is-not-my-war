from pathlib import Path
import os
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import GameTime, ModelRequestMeta, NPCDialogueResponse, SpeakerContext


def _base_payload(request_id: str, text: str) -> dict:
    return {
        "meta": ModelRequestMeta(
            request_id=request_id,
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=3, time="18:00:00", hour=18).model_dump(),
        "dialogue_kind": "player_npc",
        "npc_id": "cook_01",
        "npc_name": "布鲁诺",
        "npc_setting": {
            "background_job": "厨子",
            "personality": ["谨慎", "嘴硬", "讨厌空话"],
            "desires": ["保住食堂", "让普通人吃上一顿热饭"],
            "fears": ["被当成士兵消耗", "粮食见底"],
            "boundaries": ["不能接受无意义牺牲"],
        },
        "speaker_name": "守备官",
        "speaker_text": text,
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，腰间挂着命令书。",
        ).model_dump(),
        "is_recruitment_request": False,
        "current_round": 1,
        "max_rounds": 5,
        "npc_state": {
            "hp": 88,
            "max_hp": 100,
            "satiety": 66,
            "fatigue": 34,
            "money": 1,
            "recruited": False,
            "unconscious": False,
            "escaped": False,
            "equipment": {},
            "current_action": "work_dining_hall",
        },
        "current_order": {
            "text": "优先保证食堂运转，敌人靠近时先保护自己。",
            "issued_by": "guard_officer",
            "issued_day": 3,
            "issued_time": "08:00:00",
            "revision": 2,
        },
        "dialogue_state": {
            "visibility": "local_public",
            "location_id": "dining_hall",
            "location_name": "食堂",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", "cook_01"],
        },
        "interaction_context": "work",
        "battlefield_context": {},
        "short_memory": {
            "experienced_events": [
                {
                    "type": "work_started",
                    "summary": "布鲁诺开始在食堂加工餐食。",
                    "importance": 40,
                }
            ],
            "witnessed_events": [
                {
                    "type": "combat_started",
                    "summary": "广场上传来敌袭警报，几名入伍者正在城门外集结。",
                    "importance": 85,
                }
            ],
        },
        "long_memory": {
            "diary": ["我不想让锅铲变成刀，但我也不想看见孩子们饿着。"],
            "knowledge_graph": {"guard_officer": {"tone": "急迫但会承诺补偿"}},
        },
        "location_context": {
            "location_id": "dining_hall",
            "people_present": ["cook_01"],
            "workstations": [{"id": "kitchen_table", "status": "occupied", "occupied_by": "cook_01"}],
        },
    }


def _post_dialogue(client, payload: dict) -> NPCDialogueResponse:
    response = client.post("/npc/dialogue", json=payload)
    assert response.status_code == 200, response.get_json()
    return NPCDialogueResponse(**response.get_json())


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_dialogue_prompt_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    client = create_app().test_client()

    daily = _post_dialogue(
        client,
        _base_payload("verify_dialogue_prompt_real_daily", "锅里还剩多少餐食？大家今晚能吃上一口热的吗？"),
    )
    assert daily.recruitment_result == "none"
    assert daily.wartime_reaction == "none"

    recruitment_payload = _base_payload(
        "verify_dialogue_prompt_real_recruitment",
        "我需要你应征。不是去送死，是守住食堂门口，别让伤员和粮食断掉。",
    )
    recruitment_payload["is_recruitment_request"] = True
    recruitment = _post_dialogue(client, recruitment_payload)
    assert recruitment.recruitment_result in {"accept", "reject"}

    wartime_payload = _base_payload(
        "verify_dialogue_prompt_real_wartime",
        "城门外的人在看着你。你有刀盾，也有退路，但现在我需要你多撑一会儿。",
    )
    wartime_payload.update({
        "is_recruitment_request": False,
        "interaction_context": "combat",
        "npc_state": wartime_payload["npc_state"] | {
            "recruited": True,
            "equipment": {"main_weapon": "sword_shield"},
            "behavior_mode": "combat",
        },
        "battlefield_context": {
            "active_enemy_count": 3,
            "friendly_combatants": ["veteran_deputy_01", "cook_01"],
            "station_noncombatants": ["doctor_01", "priest_01"],
            "target_npc": {"npc_id": "cook_01", "behavior_mode": "combat"},
        },
    })
    wartime = _post_dialogue(client, wartime_payload)
    assert wartime.recruitment_result == "none"
    assert wartime.wartime_reaction in {"none", "escape", "morale_boost"}

    escape_payload = _base_payload(
        "verify_dialogue_prompt_real_escape_intervention",
        "别走。你留下，我会补偿你，也会让你守在食堂而不是城门最前面。",
    )
    escape_payload.update({
        "dialogue_kind": "escape_intervention",
        "interaction_context": "escape_intervention",
        "escape_intervention_round": 2,
        "npc_state": escape_payload["npc_state"] | {
            "escape_intent": {"active": True, "status": "escaping", "rounds_used": 1},
        },
    })
    escape = _post_dialogue(client, escape_payload)
    assert escape.intent in {"stay_after_intervention", "leave_after_intervention"}
    assert escape.recruitment_result == "none"
    assert escape.wartime_reaction == "none"

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] >= 4
    assert usage["summary"]["failed"] == 0
    assert all(record["fallback_used"] is False for record in usage["records"])

    print(
        "verify_dialogue_prompt_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} calls={usage['summary']['count']}"
    )


if __name__ == "__main__":
    main()
