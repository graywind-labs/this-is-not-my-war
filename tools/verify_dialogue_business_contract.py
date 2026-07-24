from __future__ import annotations

import copy
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from tools.verify_dialogue_prompt import _base_payload, _valid_response  # noqa: E402
from tools.verify_plan_action_contract import _post_fake  # noqa: E402


def _assert_business_rejection(response, expected_fragment: str) -> None:
    assert response.status_code == 502, response.get_json()
    body = response.get_json()
    assert body["error_code"] == "model_output_invalid", body
    assert body["message"] == "NPCDialogueResponse failed business validation.", body
    assert body["fallback_used"] is False, body
    assert any(expected_fragment in detail for detail in body["details"]), body["details"]


def _npc_npc_payload() -> dict:
    payload = copy.deepcopy(_base_payload())
    payload["dialogue_kind"] = "npc_npc"
    payload["dialogue_phase"] = "conversation"
    payload["is_recruitment_request"] = False
    payload["speaker_name"] = "莉娜"
    payload["speaker_text"] = "马塞尔，我需要和你协调诊所工位。"
    payload["speaker_context"] = {
        "speaker_id": "doctor_01",
        "speaker_name": "莉娜",
        "speaker_kind": "npc",
        "appearance": "穿着便于工作的旧医袍。",
        "health_status": "健康",
        "state": {},
    }
    soft_guidance = (
        "两人讲完当前想讲的事情后自然告别并结束；"
        "current_round 超过 5 且没有紧急或必要事项时应告别并结束。"
    )
    payload["dialogue_state"].update({
        "visibility": "private",
        "location_id": "clinic",
        "location_name": "诊所",
        "participants": ["doctor_01", "cook_01"],
        "current_round": 1,
        "max_rounds": 0,
        "soft_round_threshold": 5,
        "soft_round_guidance": soft_guidance,
    })
    payload["current_round"] = 1
    payload["max_rounds"] = 0
    payload["soft_round_threshold"] = 5
    payload["soft_round_guidance"] = soft_guidance
    return payload


def _escape_payload() -> dict:
    payload = copy.deepcopy(_base_payload())
    payload["dialogue_kind"] = "escape_intervention"
    payload["interaction_context"] = "escape_intervention"
    payload["is_recruitment_request"] = False
    payload["escape_intervention_round"] = 1
    return payload


def _npc_reply(**overrides: object) -> dict:
    values: dict[str, object] = {
        "response_kind": "reply_to_npc",
        "intent": "continue_talk",
        "recruitment_result": "none",
    }
    values.update(overrides)
    return _valid_response(**values)


def _player_reply(**overrides: object) -> dict:
    values: dict[str, object] = {
        "response_kind": "reply_to_player",
        "intent": "continue_talk",
        "recruitment_result": "none",
    }
    values.update(overrides)
    return _valid_response(**values)


def main() -> None:
    player_payload = _base_payload()
    valid_player = _post_fake("/npc/dialogue", player_payload, _player_reply())
    assert valid_player.status_code == 200, valid_player.get_json()
    assert valid_player.get_json()["model_provider"] == "deepseek"
    assert valid_player.get_json()["model_fallback_used"] is False

    wrong_replyer = _player_reply(replyer_id="priest_01")
    _assert_business_rejection(
        _post_fake("/npc/dialogue", player_payload, wrong_replyer),
        "replyer_id did not match request npc_id",
    )

    _assert_business_rejection(
        _post_fake("/npc/dialogue", player_payload, _npc_reply()),
        "expected 'reply_to_player'",
    )

    npc_payload = _npc_npc_payload()
    valid_npc = _post_fake("/npc/dialogue", npc_payload, _npc_reply())
    assert valid_npc.status_code == 200, valid_npc.get_json()
    assert valid_npc.get_json()["response_kind"] == "reply_to_npc"

    _assert_business_rejection(
        _post_fake("/npc/dialogue", npc_payload, _player_reply()),
        "expected 'reply_to_npc'",
    )

    invitation_payload = copy.deepcopy(npc_payload)
    invitation_payload["dialogue_phase"] = "invitation"
    invitation_payload["current_round"] = 0
    invitation_payload["dialogue_state"]["current_round"] = 0
    valid_accept = _post_fake(
        "/npc/dialogue",
        invitation_payload,
        _npc_reply(invitation_result="accept", should_end_dialogue=False),
    )
    assert valid_accept.status_code == 200, valid_accept.get_json()
    valid_reject = _post_fake(
        "/npc/dialogue",
        invitation_payload,
        _npc_reply(invitation_result="reject", intent="end_talk", should_end_dialogue=True),
    )
    assert valid_reject.status_code == 200, valid_reject.get_json()
    _assert_business_rejection(
        _post_fake("/npc/dialogue", invitation_payload, _npc_reply()),
        "invitation requires invitation_result accept or reject",
    )
    _assert_business_rejection(
        _post_fake(
            "/npc/dialogue",
            invitation_payload,
            _npc_reply(invitation_result="reject", intent="continue_talk", should_end_dialogue=False),
        ),
        "rejected npc_npc invitation must set should_end_dialogue=true",
    )
    counted_invitation_payload = copy.deepcopy(invitation_payload)
    counted_invitation_payload["current_round"] = 1
    counted_invitation_payload["dialogue_state"]["current_round"] = 1
    _assert_business_rejection(
        _post_fake(
            "/npc/dialogue",
            counted_invitation_payload,
            _npc_reply(invitation_result="accept", should_end_dialogue=False),
        ),
        "npc_npc invitation current_round must be 0",
    )
    invalid_round_payload = copy.deepcopy(npc_payload)
    invalid_round_payload["max_rounds"] = 3
    invalid_round_payload["dialogue_state"]["max_rounds"] = 3
    _assert_business_rejection(
        _post_fake("/npc/dialogue", invalid_round_payload, _npc_reply()),
        "npc_npc max_rounds must be 0",
    )
    missing_soft_guidance = copy.deepcopy(npc_payload)
    missing_soft_guidance["soft_round_guidance"] = ""
    missing_soft_guidance["dialogue_state"]["soft_round_guidance"] = ""
    _assert_business_rejection(
        _post_fake("/npc/dialogue", missing_soft_guidance, _npc_reply()),
        "requires non-empty soft_round_guidance",
    )

    escape_payload = _escape_payload()
    valid_escape = _post_fake("/npc/dialogue", escape_payload, _player_reply())
    assert valid_escape.status_code == 200, valid_escape.get_json()

    _assert_business_rejection(
        _post_fake("/npc/dialogue", escape_payload, _npc_reply()),
        "expected 'reply_to_player'",
    )

    print("verify_dialogue_business_contract: ok")


if __name__ == "__main__":
    main()
