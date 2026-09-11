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


MEMORY_CASES = {
    "stableman_01": {
        "question": "只根据“往昔·来站前”和“往昔·初到驿站”回答：你是什么出身，为什么离开旧工作，什么时候来到驿站，初到时遇见谁、接下了什么活？",
        "required_groups": (
            ("马场", "商队", "挽马"),
            ("马场", "赶程", "辞"),
            ("三年前", "入冬"),
            ("艾达",),
            ("马厩", "草料", "饮水"),
        ),
    },
    "doctor_01": {
        "question": "只根据开局前长期记忆回答：你为何在去年秋雨前来到驿站，初到时哪些人怎样帮你整理诊所？另外，昏迷的人该在哪里接受帮助？",
        "required_groups": (
            ("河港", "常驻医生"),
            ("去年", "秋雨"),
            ("艾达",),
            ("欧文", "药柜"),
            ("布鲁诺", "烧水"),
            ("马塞尔", "标签"),
            ("倒下", "就地"),
        ),
    },
    "engineer_01": {
        "question": "只根据你的初始知识回答：守备官的基本职责是什么？围墙和主厅从一级到六级各有多少弩床或箭塔槽位，每次升级是否一定加槽，这些器械由谁安排？不要评论守备官的品格。",
        "required_groups": (
            ("防务", "警戒"),
            ("人手", "人员"),
            ("弩床", "箭塔", "器械"),
            ("1、2、2、3、3、4", "1,2,2,3,3,4"),
            ("1、1、2、2、3、4", "1,1,2,2,3,4"),
            ("不一定", "并非", "某些", "有些"),
            ("守备官",),
        ),
        "forbidden_phrases": (
            "尚待观察",
            "仍待观察",
            "是否愿意",
            "是否会",
            "能否信任",
            "品格",
            "两倍",
            "翻倍",
            "加倍",
        ),
    },
}


def _load_json(relative_path: str):
    return json.loads((REPO_ROOT / relative_path).read_text(encoding="utf-8"))


def _format_diary_entry(entry: dict) -> str:
    entry_text = str(entry["entry"]).strip()
    day = int(entry.get("day", 0))
    time_label = str(entry.get("time", "")).strip()
    if day > 0 and time_label:
        return f"第{day}天 {time_label}：{entry_text}"
    if day > 0:
        return f"第{day}天：{entry_text}"
    if time_label:
        return f"{time_label}：{entry_text}"
    return entry_text


def _raise_timeout_floor(variable_name: str, minimum_seconds: float) -> None:
    try:
        configured_seconds = float(os.getenv(variable_name, "0"))
    except ValueError:
        configured_seconds = 0.0
    os.environ[variable_name] = str(max(minimum_seconds, configured_seconds))


def _build_payload(profile: dict, memory: dict, request_id: str, question: str) -> dict:
    profiles = _load_json("data/npc_profiles.json")
    states = dict(profile.get("states", {}))
    return {
        "meta": ModelRequestMeta(
            request_id=request_id,
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=1, time="08:00:00", hour=8).model_dump(),
        "station_context": build_station_context([
            {
                "npc_id": str(item["id"]),
                "name": str(item["name"]),
                "identity": str(item["background_job"]),
            }
            for item in profiles
        ]),
        "dialogue_kind": "player_npc",
        "npc_id": str(profile["id"]),
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
        "speaker_text": question,
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，手里拿着尚未写满的驿站名册。",
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
            "participants": ["guard_officer", str(profile["id"])],
        },
        "interaction_context": "work",
        "battlefield_context": {},
        "short_memory": {"experienced_events": [], "witnessed_events": []},
        "long_memory": {
            "diary": [
                _format_diary_entry(entry)
                for entry in memory["diary"]
            ],
            "knowledge_graph": memory["knowledge_graph"],
        },
        "location_context": {"location_id": "plaza", "location_name": "广场"},
        "allowed_actions": [{
            "action_id": "visit_location",
            "name": "前往并停留在广场",
            "action_kind": "visit",
            "location_id": "plaza",
            "target_id": "plaza",
            "target_kind": "location",
            "target_name": "广场",
            "tags": ["visit", "move", "target_location"],
            "context": {"authority": "ActionSystem"},
        }],
    }


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print(
            "verify_npc_initial_long_memory_real: skipped "
            "(non-mock LLM_PROVIDER and LLM_API_KEY required)"
        )
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    # This acceptance sends the complete seeded graph. Keep process-local transport
    # patience above the short gameplay health-check defaults without editing .env.
    _raise_timeout_floor("LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS", 30.0)
    _raise_timeout_floor("LLM_PROVIDER_IDLE_TIMEOUT_SECONDS", 180.0)
    profiles = {
        str(profile["id"]): profile
        for profile in _load_json("data/npc_profiles.json")
    }
    memory_by_npc = _load_json("data/npc_initial_long_memory.json")
    client = create_app().test_client()
    request_ids: list[str] = []

    for npc_id, case in MEMORY_CASES.items():
        request_id = f"verify_t0061_initial_memory_{npc_id}"
        request_ids.append(request_id)
        response = client.post(
            "/npc/dialogue",
            json=_build_payload(
                profiles[npc_id],
                memory_by_npc[npc_id],
                request_id,
                str(case["question"]),
            ),
        )
        assert response.status_code == 200, {npc_id: response.get_json()}
        body = response.get_json()
        dialogue = PlayerNPCDialogueResponse(**{
            key: value
            for key, value in body.items()
            if not key.startswith("model_")
        })
        assert body["model_provider"] == provider
        assert body["model_fallback_used"] is False
        assert dialogue.replyer_id == npc_id
        assert dialogue.recruitment_result == "none"
        assert dialogue.wartime_reaction == "none"
        assert "玩家" not in dialogue.reply_text
        for keyword_group in case["required_groups"]:
            assert any(keyword in dialogue.reply_text for keyword in keyword_group), {
                "npc_id": npc_id,
                "reply": dialogue.reply_text,
                "expected_any": keyword_group,
            }
        for forbidden_phrase in case.get("forbidden_phrases", ()):
            assert forbidden_phrase not in dialogue.reply_text, {
                "npc_id": npc_id,
                "reply": dialogue.reply_text,
                "forbidden_phrase": forbidden_phrase,
            }
        print(f"{profiles[npc_id]['name']}：{dialogue.reply_text}", flush=True)

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] == len(MEMORY_CASES)
    assert usage["summary"]["failed"] == 0
    records = usage["records"]
    assert {record["request_id"] for record in records} == set(request_ids)
    for record in records:
        assert record["call_type"] == "dialogue"
        assert record["provider"] == provider
        assert record["npc_id"] in MEMORY_CASES
        assert record["success"] is True
        assert record["fallback_used"] is False
        assert not record["failure_reason"]

    print(
        "verify_npc_initial_long_memory_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} "
        f"calls={usage['summary']['count']} fallback_used=false"
    )


if __name__ == "__main__":
    main()
