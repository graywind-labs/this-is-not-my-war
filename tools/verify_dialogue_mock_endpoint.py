from pathlib import Path
import os
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import GameTime, ModelRequestMeta, NPCDialogueResponse, SpeakerContext


def _base_payload(text: str, recruitment: bool = False) -> dict:
    return {
        "meta": ModelRequestMeta(
            request_id="verify_dialogue_endpoint",
            call_type="dialogue",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=1, time="08:00:00", hour=8).model_dump(),
        "dialogue_kind": "player_npc",
        "npc_id": "cook_01",
        "npc_name": "布鲁诺",
        "npc_setting": {
            "background_job": "厨子",
            "personality": ["谨慎"],
            "desires": ["保住食堂"],
            "fears": ["被当成士兵消耗"],
        },
        "speaker_name": "守备官",
        "speaker_text": text,
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，腰间挂着命令书。",
        ).model_dump(),
        "is_recruitment_request": recruitment,
        "current_round": 1,
        "max_rounds": 5,
        "npc_state": {
            "hp": 100,
            "max_hp": 100,
            "satiety": 70,
            "fatigue": 20,
            "money": 1,
            "recruited": False,
            "equipment": {},
        },
        "dialogue_state": {
            "visibility": "local_public",
            "location_id": "dining_hall",
            "location_name": "食堂",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", "cook_01"],
        },
        "short_memory": {
            "experienced_events": [],
            "witnessed_events": [],
        },
        "long_memory": {
            "knowledge_graph": {},
            "diary": [],
        },
        "location_context": {
            "location_id": "dining_hall",
            "people_present": ["cook_01"],
            "workstations": [{"id": "kitchen_table", "status": "occupied", "occupied_by": "cook_01"}],
        },
    }


def main() -> None:
    os.environ["LLM_PROVIDER"] = "mock"
    os.environ.pop("LLM_API_KEY", None)

    client = create_app().test_client()

    accept_response = client.post(
        "/npc/dialogue",
        json=_base_payload("守备官请求你应征，帮忙守住食堂和驿站。", recruitment=True),
    )
    assert accept_response.status_code == 200
    accept_data = accept_response.get_json()
    parsed_accept = NPCDialogueResponse(**accept_data)
    assert parsed_accept.replyer_id == "cook_01"
    assert parsed_accept.recruitment_result == "accept"
    assert parsed_accept.response_kind == "reply_to_player"

    reject_response = client.post(
        "/npc/dialogue",
        json=_base_payload("守备官要求你立刻拿起武器。", recruitment=True),
    )
    assert reject_response.status_code == 200
    parsed_reject = NPCDialogueResponse(**reject_response.get_json())
    assert parsed_reject.recruitment_result == "reject"

    npc_payload = _base_payload("你听见外面那阵声音了吗？", recruitment=False)
    npc_payload["dialogue_kind"] = "npc_npc"
    npc_payload["speaker_name"] = "托马"
    npc_payload["speaker_context"] = SpeakerContext(
        speaker_id="stableman_01",
        speaker_name="托马",
        speaker_kind="npc",
        appearance="肩背宽厚，旧皮围裙上沾着干草。",
        health_status="健康",
    ).model_dump()
    npc_payload["current_round"] = 4
    npc_payload["max_rounds"] = 4
    npc_payload["dialogue_state"]["current_round"] = 4
    npc_payload["dialogue_state"]["max_rounds"] = 4
    npc_response = client.post("/npc/dialogue", json=npc_payload)
    assert npc_response.status_code == 200
    parsed_npc = NPCDialogueResponse(**npc_response.get_json())
    assert parsed_npc.response_kind == "reply_to_npc"
    assert parsed_npc.should_end_dialogue is True

    bad_response = client.post("/npc/dialogue", json={"npc_id": "cook_01"})
    assert bad_response.status_code == 400
    assert bad_response.get_json()["error_code"] == "validation_error"

    print("verify_dialogue_mock_endpoint: ok")


if __name__ == "__main__":
    main()
