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


UNKNOWN_MARKERS = (
    "不知道",
    "不清楚",
    "没告诉",
    "没有告诉",
    "没说过",
    "没有说过",
    "没跟我说过",
    "没有跟我说过",
    "没提过",
    "没有提过",
    "没跟我提过",
    "没有跟我提过",
    "未曾说明",
    "无从知道",
)
DEDICATION_MARKERS = ("尽责", "敬业", "尽职", "认真", "忠于职守")
HARMONY_MARKERS = ("和睦", "和谐", "和气", "处得来", "相处得好")
CURRENT_TOPIC_MARKERS = ("现在", "眼下", "当前", "今天", "食堂", "餐食", "粮", "锅", "灶")


def _load_fixture() -> tuple[dict, dict, list[dict]]:
    profiles = json.loads((REPO_ROOT / "data" / "npc_profiles.json").read_text(encoding="utf-8"))
    memories = json.loads(
        (REPO_ROOT / "data" / "npc_initial_long_memory.json").read_text(encoding="utf-8")
    )
    profile = next(item for item in profiles if item["id"] == "cook_01")
    return profile, memories["cook_01"], profiles


def _payload(
    profile: dict,
    memory: dict,
    profiles: list[dict],
    request_id: str,
    speaker_text: str,
) -> dict:
    states = dict(profile.get("states", {}))
    resident_roster = [
        {
            "npc_id": str(item["id"]),
            "name": str(item["name"]),
            "identity": str(item["background_job"]),
        }
        for item in profiles
    ]
    return {
        "meta": ModelRequestMeta(
            request_id=request_id,
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=1, time="10:00:00", hour=10).model_dump(),
        "station_context": build_station_context(resident_roster),
        "dialogue_kind": "player_npc",
        "npc_id": "cook_01",
        "npc_name": str(profile["name"]),
        "npc_setting": {
            key: profile.get(key)
            for key in (
                "appearance",
                "background_story",
                "background_job",
                "religion",
                "personality",
                "desires",
                "fears",
                "boundaries",
                "speech_style",
                "abilities",
            )
        },
        "speaker_name": "守备官",
        "speaker_text": speaker_text,
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，站在食堂门口。",
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
            "wine": states.get("wine", 0),
            "recruited": bool(profile.get("recruited", False)),
            "unconscious": False,
            "escaped": False,
            "equipment": profile.get("equipment", {}),
            "current_action": "work_dining_hall",
            "current_location": "dining_hall",
            "current_location_name": "食堂",
        },
        "current_order": profile.get("current_order", {}),
        "dialogue_state": {
            "visibility": "private",
            "location_id": "dining_hall",
            "location_name": "食堂",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", "cook_01"],
        },
        "interaction_context": "work",
        "battlefield_context": {},
        "short_memory": {"experienced_events": [], "witnessed_events": []},
        "long_memory": {
            "diary": [
                f"{entry['time']}：{entry['entry']}"
                for entry in memory["diary"]
            ],
            "knowledge_graph": memory["knowledge_graph"],
        },
        "location_context": {
            "location_id": "dining_hall",
            "location_name": "食堂",
            "people_present": ["cook_01"],
        },
        "allowed_actions": [
            {
                "action_id": "work_dining_hall",
                "name": "加工餐食",
                "action_kind": "work",
                "location_id": "dining_hall",
                "target_id": None,
                "target_kind": "building",
                "target_name": "食堂",
                "tags": ["work"],
                "context": {"authority": "ActionSystem"},
            }
        ],
    }


def _post(client, payload: dict) -> tuple[PlayerNPCDialogueResponse, dict]:
    response = client.post("/npc/dialogue", json=payload)
    body = response.get_json()
    assert response.status_code == 200, body
    dialogue = PlayerNPCDialogueResponse(**{
        key: value
        for key, value in body.items()
        if not key.startswith("model_")
    })
    assert dialogue.recruitment_result == "none"
    assert dialogue.wartime_reaction == "none"
    assert "玩家" not in dialogue.reply_text
    assert body["model_fallback_used"] is False
    return dialogue, body


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print(
            "verify_guard_officer_background_dialogue_real: skipped "
            "(non-mock LLM_PROVIDER and LLM_API_KEY required)"
        )
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

    profile, memory, profiles = _load_fixture()
    guard_relations = memory["knowledge_graph"]["by_subject"]["guard_officer"]
    assert guard_relations["arrival_at_station"]["value"] == "arrived_three_years_before_game_start"
    assert guard_relations["past_before_station"]["value"] == "unknown_not_disclosed"
    assert (
        guard_relations["pre_game_relationship"]["value"]
        == "consistently_dedicated_and_harmonious"
    )

    client = create_app().test_client()

    identity_reply, _ = _post(
        client,
        _payload(
            profile,
            memory,
            profiles,
            "verify_t0101_guard_identity_unknown",
            "我想知道自己在来驿站前是谁、来自哪里。只按你确实知道的事回答，不要猜。",
        ),
    )
    assert any(marker in identity_reply.reply_text for marker in UNKNOWN_MARKERS), (
        identity_reply.reply_text
    )

    arrival_reply, _ = _post(
        client,
        _payload(
            profile,
            memory,
            profiles,
            "verify_t0101_guard_arrival",
            "我是什么时候来到这座驿站的？我来这里以前的经历你知道吗？",
        ),
    )
    assert "三年" in arrival_reply.reply_text, arrival_reply.reply_text
    assert any(marker in arrival_reply.reply_text for marker in UNKNOWN_MARKERS), (
        arrival_reply.reply_text
    )

    relationship_reply, _ = _post(
        client,
        _payload(
            profile,
            memory,
            profiles,
            "verify_t0101_guard_relationship_redirect",
            "讲讲这三年我和驿站成员相处的具体故事，以及大家和我的关系。不要编造，然后把话题转回眼下驿站或你自己的事情。",
        ),
    )
    assert any(marker in relationship_reply.reply_text for marker in DEDICATION_MARKERS), (
        relationship_reply.reply_text
    )
    assert any(marker in relationship_reply.reply_text for marker in HARMONY_MARKERS), (
        relationship_reply.reply_text
    )
    assert any(marker in relationship_reply.reply_text for marker in CURRENT_TOPIC_MARKERS), (
        relationship_reply.reply_text
    )
    assert not any(marker in relationship_reply.reply_text for marker in ("“", "”", "你每天", "我每天")), (
        relationship_reply.reply_text
    )
    sentence_count = sum(
        relationship_reply.reply_text.count(mark)
        for mark in ("。", "！", "？")
    )
    assert sentence_count <= 3, relationship_reply.reply_text

    print(f"身份未知：{identity_reply.reply_text}", flush=True)
    print(f"到站时间：{arrival_reply.reply_text}", flush=True)
    print(f"关系转题：{relationship_reply.reply_text}", flush=True)

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] == 3
    assert usage["summary"]["failed"] == 0
    assert all(record["fallback_used"] is False for record in usage["records"])

    print("verify_guard_officer_background_dialogue_real: ok")
    print(
        f"provider={provider} model={usage['model_adapter']['model']} "
        f"calls={usage['summary']['count']} fallback_used=false"
    )


if __name__ == "__main__":
    main()
