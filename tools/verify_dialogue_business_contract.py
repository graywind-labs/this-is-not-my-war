from __future__ import annotations

import copy
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from tools.verify_dialogue_prompt import (  # noqa: E402
    _base_payload,
    _valid_escape_response,
    _valid_npc_response,
    _valid_player_response,
)
from tools.verify_plan_action_contract import _post_fake  # noqa: E402


def _assert_business_rejection(
    response,
    expected_fragment: str,
    response_model_name: str,
) -> None:
    assert response.status_code == 502, response.get_json()
    body = response.get_json()
    assert body["error_code"] == "model_output_invalid", body
    assert body["message"] == f"{response_model_name} failed business validation.", body
    assert body["fallback_used"] is False, body
    assert any(expected_fragment in detail for detail in body["details"]), body["details"]


def _assert_schema_rejection(response, response_model_name: str) -> None:
    assert response.status_code == 502, response.get_json()
    body = response.get_json()
    assert body["error_code"] == "model_output_invalid", body
    assert body["message"] == f"Model output did not match {response_model_name}.", body
    assert body["fallback_used"] is False, body


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
    payload["npc_state"]["escape_intent"] = {
        "active": True,
        "status": "escaping",
        "intervention_rounds_used": 0,
        "intervention_max_rounds": 5,
    }
    return payload


def main() -> None:
    player_payload = copy.deepcopy(_base_payload())
    player_payload["is_recruitment_request"] = False
    player_payload["speaker_text"] = "食堂今晚还能正常开饭吗？"
    valid_player = _post_fake(
        "/npc/dialogue",
        player_payload,
        _valid_player_response(recruitment_result="none"),
    )
    assert valid_player.status_code == 200, valid_player.get_json()
    assert valid_player.get_json()["model_provider"] == "deepseek"
    assert valid_player.get_json()["model_fallback_used"] is False

    nullable_metadata = _valid_player_response(recruitment_result="none")
    nullable_metadata["suggested_event_type"] = None
    normalized_metadata = _post_fake(
        "/npc/dialogue",
        player_payload,
        nullable_metadata,
    )
    assert normalized_metadata.status_code == 200, normalized_metadata.get_json()
    normalized_body = normalized_metadata.get_json()
    assert normalized_body["suggested_event_type"] == "dialogue_turn"
    assert normalized_body["model_normalizations"] == []

    fixed_echoes_are_derived = _post_fake(
        "/npc/dialogue",
        player_payload,
        _valid_player_response(
            ok=False,
            replyer_id="priest_01",
            response_kind="reply_to_npc",
            suggested_event_type=None,
            recruitment_result="none",
        ),
    )
    assert fixed_echoes_are_derived.status_code == 200, fixed_echoes_are_derived.get_json()
    fixed_body = fixed_echoes_are_derived.get_json()
    assert fixed_body["ok"] is True
    assert fixed_body["replyer_id"] == "cook_01"
    assert fixed_body["response_kind"] == "reply_to_player"
    assert fixed_body["suggested_event_type"] == "dialogue_turn"
    ignored_recruitment_echo = _post_fake(
        "/npc/dialogue",
        player_payload,
        _valid_player_response(recruitment_result="accept"),
    )
    assert ignored_recruitment_echo.status_code == 200, ignored_recruitment_echo.get_json()
    assert ignored_recruitment_echo.get_json()["recruitment_result"] == "none"
    ignored_wartime_echo = _post_fake(
        "/npc/dialogue",
        player_payload,
        _valid_player_response(
            recruitment_result="none",
            wartime_reaction="morale_boost",
        ),
    )
    assert ignored_wartime_echo.status_code == 200, ignored_wartime_echo.get_json()
    assert ignored_wartime_echo.get_json()["wartime_reaction"] == "none"

    # The removed unified fields must fail at schema validation instead of leaking
    # back into the player-facing output contract.
    legacy_player = _valid_player_response(recruitment_result="none")
    legacy_player["intent"] = "continue_talk"
    _assert_schema_rejection(
        _post_fake("/npc/dialogue", player_payload, legacy_player),
        "PlayerNPCDialogueResponse",
    )
    wrong_branch_player = _valid_player_response(recruitment_result="none")
    wrong_branch_player["should_end_dialogue"] = False
    _assert_schema_rejection(
        _post_fake("/npc/dialogue", player_payload, wrong_branch_player),
        "PlayerNPCDialogueResponse",
    )

    recruitment_payload = copy.deepcopy(player_payload)
    recruitment_payload["is_recruitment_request"] = True
    recruitment_payload["speaker_text"] = "我正式请求你应征，一起守住驿站。"
    for result in ["accept", "reject"]:
        valid_recruitment = _post_fake(
            "/npc/dialogue",
            recruitment_payload,
            _valid_player_response(recruitment_result=result),
        )
        assert valid_recruitment.status_code == 200, valid_recruitment.get_json()
        assert "intent" not in valid_recruitment.get_json()
    _assert_business_rejection(
        _post_fake(
            "/npc/dialogue",
            recruitment_payload,
            _valid_player_response(recruitment_result="none"),
        ),
        "recruitment request requires recruitment_result accept or reject",
        "PlayerNPCDialogueResponse",
    )

    combat_payload = copy.deepcopy(player_payload)
    combat_payload["interaction_context"] = "combat"
    combat_payload["npc_state"].update({
        "recruited": True,
        "behavior_mode": "combat",
        "equipment": {"main_weapon": {"weapon_id": "sword_shield"}},
    })
    for reaction in ["none", "escape", "morale_boost"]:
        valid_combat = _post_fake(
            "/npc/dialogue",
            combat_payload,
            _valid_player_response(
                recruitment_result="none",
                wartime_reaction=reaction,
            ),
        )
        assert valid_combat.status_code == 200, valid_combat.get_json()

    ineligible_combat_payload = copy.deepcopy(combat_payload)
    ineligible_combat_payload["npc_state"]["equipment"] = {}
    _assert_business_rejection(
        _post_fake(
            "/npc/dialogue",
            ineligible_combat_payload,
            _valid_player_response(
                recruitment_result="none",
                wartime_reaction="escape",
            ),
        ),
        "without recruited status and a main weapon",
        "PlayerNPCDialogueResponse",
    )

    avoid_payload = copy.deepcopy(player_payload)
    avoid_payload["interaction_context"] = "avoid_combat"
    avoid_payload["npc_state"]["behavior_mode"] = "avoid_combat"
    valid_avoid = _post_fake(
        "/npc/dialogue",
        avoid_payload,
        _valid_player_response(recruitment_result="none"),
    )
    assert valid_avoid.status_code == 200, valid_avoid.get_json()
    for reaction in ["escape", "morale_boost"]:
        ignored_avoid_reaction = _post_fake(
            "/npc/dialogue",
            avoid_payload,
            _valid_player_response(
                recruitment_result="none",
                wartime_reaction=reaction,
            ),
        )
        assert ignored_avoid_reaction.status_code == 200, ignored_avoid_reaction.get_json()
        assert ignored_avoid_reaction.get_json()["wartime_reaction"] == "none"
    avoid_recruitment_payload = copy.deepcopy(avoid_payload)
    avoid_recruitment_payload["is_recruitment_request"] = True
    for recruitment_result in ["accept", "reject"]:
        valid_avoid_recruitment = _post_fake(
            "/npc/dialogue",
            avoid_recruitment_payload,
            _valid_player_response(recruitment_result=recruitment_result),
        )
        assert valid_avoid_recruitment.status_code == 200, valid_avoid_recruitment.get_json()

    npc_payload = _npc_npc_payload()
    valid_npc = _post_fake("/npc/dialogue", npc_payload, _valid_npc_response())
    assert valid_npc.status_code == 200, valid_npc.get_json()
    assert valid_npc.get_json()["response_kind"] == "reply_to_npc"
    assert "intent" not in valid_npc.get_json()

    legacy_npc = _valid_npc_response()
    legacy_npc["intent"] = "continue_talk"
    _assert_schema_rejection(
        _post_fake("/npc/dialogue", npc_payload, legacy_npc),
        "NPCNPCDialogueResponse",
    )
    wrong_branch_npc = _valid_npc_response()
    wrong_branch_npc["recruitment_result"] = "none"
    _assert_schema_rejection(
        _post_fake("/npc/dialogue", npc_payload, wrong_branch_npc),
        "NPCNPCDialogueResponse",
    )

    invitation_payload = copy.deepcopy(npc_payload)
    invitation_payload["dialogue_phase"] = "invitation"
    invitation_payload["current_round"] = 0
    invitation_payload["dialogue_state"]["current_round"] = 0
    valid_accept = _post_fake(
        "/npc/dialogue",
        invitation_payload,
        _valid_npc_response(invitation_result="accept", should_end_dialogue=False),
    )
    assert valid_accept.status_code == 200, valid_accept.get_json()
    valid_reject = _post_fake(
        "/npc/dialogue",
        invitation_payload,
        _valid_npc_response(invitation_result="reject", should_end_dialogue=True),
    )
    assert valid_reject.status_code == 200, valid_reject.get_json()
    _assert_business_rejection(
        _post_fake("/npc/dialogue", invitation_payload, _valid_npc_response()),
        "invitation requires invitation_result accept or reject",
        "NPCNPCDialogueResponse",
    )
    derived_rejection_end = _post_fake(
        "/npc/dialogue",
        invitation_payload,
        _valid_npc_response(
            invitation_result="reject",
            should_end_dialogue=False,
        ),
    )
    assert derived_rejection_end.status_code == 200, derived_rejection_end.get_json()
    assert derived_rejection_end.get_json()["should_end_dialogue"] is True
    counted_invitation_payload = copy.deepcopy(invitation_payload)
    counted_invitation_payload["current_round"] = 1
    counted_invitation_payload["dialogue_state"]["current_round"] = 1
    _assert_business_rejection(
        _post_fake(
            "/npc/dialogue",
            counted_invitation_payload,
            _valid_npc_response(
                invitation_result="accept",
                should_end_dialogue=False,
            ),
        ),
        "npc_npc invitation current_round must be 0",
        "NPCNPCDialogueResponse",
    )
    invalid_round_payload = copy.deepcopy(npc_payload)
    invalid_round_payload["max_rounds"] = 3
    invalid_round_payload["dialogue_state"]["max_rounds"] = 3
    _assert_business_rejection(
        _post_fake("/npc/dialogue", invalid_round_payload, _valid_npc_response()),
        "npc_npc max_rounds must be 0",
        "NPCNPCDialogueResponse",
    )
    missing_soft_guidance = copy.deepcopy(npc_payload)
    missing_soft_guidance["soft_round_guidance"] = ""
    missing_soft_guidance["dialogue_state"]["soft_round_guidance"] = ""
    _assert_business_rejection(
        _post_fake("/npc/dialogue", missing_soft_guidance, _valid_npc_response()),
        "requires non-empty soft_round_guidance",
        "NPCNPCDialogueResponse",
    )

    escape_payload = _escape_payload()
    for result in ["stay", "leave"]:
        valid_escape = _post_fake(
            "/npc/dialogue",
            escape_payload,
            _valid_escape_response(escape_intervention_result=result),
        )
        assert valid_escape.status_code == 200, valid_escape.get_json()
        assert "intent" not in valid_escape.get_json()
        assert "should_end_dialogue" not in valid_escape.get_json()

    legacy_escape = _valid_escape_response()
    legacy_escape["intent"] = "stay_after_intervention"
    _assert_schema_rejection(
        _post_fake("/npc/dialogue", escape_payload, legacy_escape),
        "EscapeInterventionDialogueResponse",
    )
    wrong_branch_escape = _valid_escape_response()
    wrong_branch_escape["wartime_reaction"] = "none"
    _assert_schema_rejection(
        _post_fake("/npc/dialogue", escape_payload, wrong_branch_escape),
        "EscapeInterventionDialogueResponse",
    )

    final_escape_payload = copy.deepcopy(escape_payload)
    final_escape_payload["current_round"] = 5
    final_escape_payload["dialogue_state"]["current_round"] = 5
    final_escape_payload["escape_intervention_round"] = 5
    valid_final_leave = _post_fake(
        "/npc/dialogue",
        final_escape_payload,
        _valid_escape_response(escape_intervention_result="leave"),
    )
    assert valid_final_leave.status_code == 200, valid_final_leave.get_json()

    missing_escape_round = copy.deepcopy(escape_payload)
    missing_escape_round.pop("escape_intervention_round")
    _assert_business_rejection(
        _post_fake(
            "/npc/dialogue",
            missing_escape_round,
            _valid_escape_response(escape_intervention_result="leave"),
        ),
        "requires escape_intervention_round",
        "EscapeInterventionDialogueResponse",
    )
    mismatched_escape_round = copy.deepcopy(escape_payload)
    mismatched_escape_round["escape_intervention_round"] = 2
    _assert_business_rejection(
        _post_fake(
            "/npc/dialogue",
            mismatched_escape_round,
            _valid_escape_response(escape_intervention_result="leave"),
        ),
        "escape_intervention_round must match current_round",
        "EscapeInterventionDialogueResponse",
    )
    mismatched_escape_context = copy.deepcopy(escape_payload)
    mismatched_escape_context["interaction_context"] = "work"
    _assert_business_rejection(
        _post_fake(
            "/npc/dialogue",
            mismatched_escape_context,
            _valid_escape_response(escape_intervention_result="leave"),
        ),
        "must appear together",
        "EscapeInterventionDialogueResponse",
    )

    print("verify_dialogue_business_contract: ok")


if __name__ == "__main__":
    main()
