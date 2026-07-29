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
from backend.schemas import PlayerNPCDialogueResponse
from tools.station_context_fixture import build_station_context


def _load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        print(
            "verify_npc_roster_knowledge_real: skipped "
            "(non-mock LLM_PROVIDER and LLM_API_KEY required)"
        )
        return

    profiles = _load_json(REPO_ROOT / "data" / "npc_profiles.json")
    initial_memory = _load_json(
        REPO_ROOT / "data" / "npc_initial_long_memory.json"
    )
    profile_by_id = {str(profile["id"]): profile for profile in profiles}
    ada = profile_by_id["veteran_deputy_01"]
    roster = [
        {
            "npc_id": str(profile["id"]),
            "name": str(profile["name"]),
            "identity": str(profile["background_job"]),
            "recruited": bool(profile.get("recruited", False)),
            "in_station": str(profile["id"]) != "engineer_01",
        }
        for profile in profiles
    ]
    diary = [
        f'{entry["time"]}：{entry["entry"]}'
        for entry in initial_memory["veteran_deputy_01"]["diary"]
    ]

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    client = create_app().test_client()
    payload = {
        "meta": {
            "request_id": "verify_npc_roster_knowledge_real",
            "call_type": "dialogue",
            "source": "backend_test",
            "requires_time_slowdown": True,
        },
        "game_time": {"day": 2, "time": "14:00:00", "hour": 14},
        "station_context": build_station_context(roster),
        "dialogue_kind": "player_npc",
        "npc_id": "veteran_deputy_01",
        "npc_name": "艾达",
        "npc_setting": {
            key: ada[key]
            for key in (
                "background_job",
                "background_story",
                "personality",
                "desires",
                "fears",
                "boundaries",
                "speech_style",
            )
        },
        "speaker_name": "守备官",
        "speaker_text": (
            "请按你现在掌握的驿站名册，逐个说出八人的名字，说明谁已入伍、"
            "谁未入伍，以及谁已经不在驿站。然后回答：训练场没有受训者时，"
            "教官独自在教官位练习是否仍能提升自己？有人受训时教官又提升什么？"
        ),
        "speaker_context": {
            "speaker_id": "guard_officer",
            "speaker_name": "守备官",
            "speaker_kind": "guard_officer",
        },
        "is_recruitment_request": False,
        "current_round": 1,
        "max_rounds": 5,
        "npc_state": {
            **ada["states"],
            "recruited": True,
            "current_location": "training_ground",
            "current_location_name": "训练场",
            "equipment": {"main_weapon": "sword_shield"},
            "skills": ada["skills"],
            "stats": ada["stats"],
        },
        "current_order": ada["current_order"],
        "dialogue_state": {
            "visibility": "private",
            "location_id": "training_ground",
            "location_name": "训练场",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", "veteran_deputy_01"],
        },
        "interaction_context": "work",
        "short_memory": {"experienced_events": [], "witnessed_events": []},
        "long_memory": {
            "diary": diary,
            "knowledge_graph": initial_memory["veteran_deputy_01"][
                "knowledge_graph"
            ],
        },
        "location_context": {
            "location_id": "training_ground",
            "location_name": "训练场",
            "people_present": ["veteran_deputy_01"],
        },
        "allowed_actions": [
            {
                "action_id": "work_training_instructor",
                "name": "担任训练教官",
                "action_kind": "work",
                "location_id": "training_ground",
                "tags": ["work", "training_instructor"],
                "context": {
                    "eligible": True,
                    "available_now": True,
                    "description": (
                        "没有受训者时，教官独自练习并提升自身武器或骑术；"
                        "有受训者时，教官在指导中提升教练熟练度。"
                    ),
                },
            }
        ],
    }
    response = client.post("/npc/dialogue", json=payload)
    assert response.status_code == 200, response.get_json()
    response_body = response.get_json()
    result = PlayerNPCDialogueResponse(**{
        key: value
        for key, value in response_body.items()
        if not key.startswith("model_")
    })
    reply = result.reply_text.replace(" ", "")

    for name in ("托马", "布鲁诺", "伊沃", "格伦", "艾达", "马塞尔", "莉娜", "欧文"):
        assert name in reply, f"missing roster member {name!r}: {result.reply_text}"
    assert "入伍" in reply, result.reply_text
    assert any(marker in reply for marker in ("未入伍", "没入伍")), result.reply_text
    assert "欧文" in reply and any(
        marker in reply for marker in ("不在驿站", "已经离开", "已离开", "离站")
    ), result.reply_text
    assert any(marker in reply for marker in ("独自", "独练", "自己练")), result.reply_text
    assert any(marker in reply for marker in ("武器", "剑盾", "骑术")), result.reply_text
    assert "教练" in reply, result.reply_text

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["summary"]["count"] == 1
    assert usage["summary"]["failed"] == 0
    assert usage["records"][0]["fallback_used"] is False
    print(
        "verify_npc_roster_knowledge_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} "
        f"reply={result.reply_text!r}"
    )


if __name__ == "__main__":
    main()
