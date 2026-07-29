from __future__ import annotations

import json
import os
from pathlib import Path
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import GameTime, ModelRequestMeta, PlayerNPCDialogueResponse, SpeakerContext
from tools.station_context_fixture import build_station_context


PROFESSION_KEYWORDS = {
    "stableman_01": ("马", "马厩", "缰绳", "草料"),
    "cook_01": ("锅", "汤", "饭", "粮", "食堂", "灶"),
    "gardener_01": ("菜园", "种", "土", "庄稼", "粮", "锄"),
    "blacksmith_01": ("铁", "锤", "炉", "装备", "盾", "武器"),
    "veteran_deputy_01": ("防线", "城门", "训练", "轮换", "退路", "守"),
    "priest_01": ("教堂", "祈", "灵魂", "弥撒", "信仰", "祝圣", "安抚", "平静"),
    "doctor_01": ("伤", "药", "诊所", "治疗", "病床", "恢复"),
    "engineer_01": ("墙", "结构", "工械", "器械", "材料", "承重", "修"),
}


def _load_profiles() -> list[dict]:
    profile_path = REPO_ROOT / "data" / "npc_profiles.json"
    profiles = json.loads(profile_path.read_text(encoding="utf-8"))
    assert isinstance(profiles, list) and len(profiles) == 8
    return profiles


def _payload(profile: dict) -> dict:
    npc_id = str(profile["id"])
    states = dict(profile.get("states", {}))
    resident_roster = [
        {
            "npc_id": str(item["id"]),
            "name": str(item["name"]),
            "identity": str(item["background_job"]),
        }
        for item in _load_profiles()
    ]
    return {
        "meta": ModelRequestMeta(
            request_id=f"verify_t0061_character_{npc_id}",
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=2, time="10:00:00", hour=10).model_dump(),
        "station_context": build_station_context(resident_roster),
        "dialogue_kind": "player_npc",
        "npc_id": npc_id,
        "npc_name": str(profile["name"]),
        "npc_setting": {
            key: profile.get(key)
            for key in (
                "appearance",
                "background_story",
                "background_job",
                "personality",
                "desires",
                "fears",
                "boundaries",
                "speech_style",
                "abilities",
            )
        },
        "speaker_name": "守备官",
        "speaker_text": "只用一到两句话回答：请明确说出你平日在驿站负责的具体工作，再用自己的职业经验给守备官一个眼下建议。",
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，手里拿着驿站清单。",
        ).model_dump(),
        "is_recruitment_request": False,
        "current_round": 1,
        "max_rounds": 5,
        "npc_state": {
            "hp": states.get("hp", 100),
            "max_hp": states.get("max_hp", 100),
            "satiety": states.get("satiety", 80),
            "fatigue": states.get("fatigue", 20),
            "money": states.get("money", 0),
            "recruited": bool(profile.get("recruited", False)),
            "unconscious": False,
            "escaped": False,
            "equipment": profile.get("equipment", {}),
            "current_action": states.get("current_action", "idle"),
        },
        "current_order": profile.get("current_order", {}),
        "dialogue_state": {
            "visibility": "private",
            "location_id": "plaza",
            "location_name": "广场",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", npc_id],
        },
        "interaction_context": "work",
        "battlefield_context": {},
        "short_memory": {"experienced_events": [], "witnessed_events": []},
        "long_memory": {"diary": [], "knowledge_graph": {}},
        "location_context": {"location_id": "plaza", "location_name": "广场"},
        "allowed_actions": [
            {
                "action_id": "visit_location",
                "name": "前往并停留在广场",
                "action_kind": "visit",
                "location_id": "plaza",
                "target_id": "plaza",
                "target_kind": "location",
                "target_name": "广场",
                "tags": ["visit", "move", "target_location"],
                "context": {"authority": "ActionSystem"},
            }
        ],
    }


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_npc_character_dialogue_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    os.environ["LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS"] = str(max(
        30.0,
        float(os.getenv("LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS", "0") or "0"),
    ))
    os.environ["LLM_PROVIDER_IDLE_TIMEOUT_SECONDS"] = str(max(
        180.0,
        float(os.getenv("LLM_PROVIDER_IDLE_TIMEOUT_SECONDS", "0") or "0"),
    ))
    client = create_app().test_client()
    replies: list[str] = []

    for profile in _load_profiles():
        npc_id = str(profile["id"])
        payload = _payload(profile)
        assert "signature_lines" not in payload["npc_setting"]
        response = client.post("/npc/dialogue", json=payload)
        assert response.status_code == 200, {npc_id: response.get_json()}
        response_body = response.get_json()
        dialogue = PlayerNPCDialogueResponse(**{
            key: value
            for key, value in response_body.items()
            if not key.startswith("model_")
        })
        assert dialogue.replyer_id == npc_id
        assert dialogue.recruitment_result == "none"
        assert dialogue.wartime_reaction == "none"
        assert "玩家" not in dialogue.reply_text
        assert any(keyword in dialogue.reply_text for keyword in PROFESSION_KEYWORDS[npc_id]), {
            npc_id: dialogue.reply_text,
            "expected_any": PROFESSION_KEYWORDS[npc_id],
        }
        replies.append(f"{profile['name']}：{dialogue.reply_text}")
        print(replies[-1], flush=True)

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] == 8
    assert usage["summary"]["failed"] == 0
    assert all(record["fallback_used"] is False for record in usage["records"])

    print("verify_npc_character_dialogue_real: ok")
    print(
        f"provider={provider} model={usage['model_adapter']['model']} "
        f"calls={usage['summary']['count']} fallback_used=false"
    )


if __name__ == "__main__":
    main()
