from __future__ import annotations

import copy
import os
from pathlib import Path
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import (  # noqa: E402
    PlanRevisionJudgementResponse,
    PlanRevisionResponse,
)
from tools.verify_plan_action_contract import _item, _revision_payload  # noqa: E402


CURRENT_HOUR = 8


def _prayer_candidate() -> dict:
    return {
        "action_id": "pray_at_chapel",
        "name": "祈祷",
        "action_kind": "pray",
        "location_id": "chapel",
        "target_id": None,
        "tags": ["pray"],
        "context": {
            "eligible": True,
            "available_now": True,
            "workstation_type": "chapel_prayer_seat",
            "description": (
                "前往小教堂祈祷；若弥撒已经开始或期间开始，"
                "会自动参加弥撒，弥撒结束后继续独自祈祷。"
            ),
        },
    }


def _idle_candidate() -> dict:
    return {
        "action_id": "idle",
        "name": "等待",
        "action_kind": "idle",
        "location_id": None,
        "target_id": None,
        "tags": ["idle"],
        "context": {"eligible": True, "available_now": True},
    }


def _dialogue_prayer_revision_payload() -> dict:
    payload = _revision_payload()
    payload["meta"]["request_id"] = (
        "verify_dialogue_prayer_commitment_revision_real"
    )
    payload["npc"]["identity"].update({
        "npc_id": "veteran_deputy_01",
        "name": "艾达",
        "background_job": "老兵副官",
        "personality": ["务实", "重视承诺"],
        "desires": ["维持驿站秩序并照看众人"],
        "fears": ["守备安排因失信而瓦解"],
        "boundaries": ["不会用空话敷衍已经答应的事情"],
    })
    payload["npc"]["state"].update({
        "current_location": "plaza",
        "current_location_name": "广场",
        "fatigue": 28,
        "satiety": 74,
    })
    payload["npc"]["current_order"] = {
        "text": "",
        "issued_by": "guard_officer",
        "issued_day": 0,
        "issued_time": "",
        "revision": 0,
    }
    payload["current_plan"] = [
        _item(hour, "idle", "idle", None)
        for hour in range(24)
    ]
    payload["revision_hours"] = [CURRENT_HOUR]
    payload["current_work_phase_count"] = 0
    payload["minimum_work_phase_count"] = 6
    payload["past_work_phase_count"] = 0
    payload["minimum_remaining_work_phase_count"] = 6
    payload["replacement_work_phase_required_if_non_work"] = False
    payload["failure_type"] = "dialogue_interrupted"
    payload["failure_summary"] = (
        "守备官请艾达现在去小教堂祈祷；弥撒已经开始，艾达清楚答应立即前往。"
    )
    payload["failure_context"] = {
        "dialogue_id": "verify_dialogue_prayer_commitment",
        "dialogue_kind": "player_npc",
        "dialogue_end_reason": "dialogue_completed",
        "dialogue_history": [
            {
                "speaker_id": "guard_officer",
                "speaker_name": "守备官",
                "listener_id": "veteran_deputy_01",
                "listener_name": "艾达",
                "text": (
                    "弥撒已经开始了，请你现在去小教堂祈祷，"
                    "到场后直接参加弥撒。"
                ),
                "day": 1,
                "time": "08:10:00",
                "visibility": "private",
            },
            {
                "speaker_id": "veteran_deputy_01",
                "speaker_name": "艾达",
                "listener_id": "guard_officer",
                "listener_name": "守备官",
                "text": "明白，我现在就去小教堂祈祷。",
                "day": 1,
                "time": "08:10:00",
                "visibility": "private",
            },
        ],
        "dialogue_context": {
            "location_id": "plaza",
            "participant_npc_ids": ["veteran_deputy_01"],
            "dialogue_initiator": "player",
        },
    }
    payload["failed_plan_item"] = copy.deepcopy(
        payload["current_plan"][CURRENT_HOUR]
    )
    payload["allowed_actions"] = [_prayer_candidate(), _idle_candidate()]
    payload["current_building_states"] = {
        "chapel": {
            "id": "chapel",
            "name": "小教堂",
            "level": 1,
            "condition": "intact",
            "is_enterable": True,
            "operational_efficiency": 1.0,
        },
    }
    payload["current_resource_states"] = {}
    return payload


def _dialogue_judgement_payload(revision_payload: dict) -> dict:
    return {
        "meta": {
            "request_id": (
                "verify_dialogue_prayer_commitment_judgement_real"
            ),
            "call_type": "plan_revision_judgement",
            "source": "backend_test",
            "requires_time_slowdown": True,
        },
        "game_time": copy.deepcopy(revision_payload["game_time"]),
        "station_context": copy.deepcopy(revision_payload["station_context"]),
        "npc_id": revision_payload["npc"]["identity"]["npc_id"],
        "npc_name": revision_payload["npc"]["identity"]["name"],
        "npc": copy.deepcopy(revision_payload["npc"]),
        "trigger_kind": "dialogue",
        "dialogue_kind": "player_npc",
        "dialogue_history": copy.deepcopy(
            revision_payload["failure_context"]["dialogue_history"]
        ),
        "dialogue_end_reason": "dialogue_completed",
        "dialogue_context": copy.deepcopy(
            revision_payload["failure_context"]["dialogue_context"]
        ),
        "failed_plan_item": copy.deepcopy(revision_payload["failed_plan_item"]),
        "failure_type": revision_payload["failure_type"],
        "failure_summary": revision_payload["failure_summary"],
        "failure_context": copy.deepcopy(revision_payload["failure_context"]),
        "required_revision_hours": [],
        "allowed_actions": copy.deepcopy(revision_payload["allowed_actions"]),
        "current_building_states": copy.deepcopy(
            revision_payload["current_building_states"]
        ),
        "current_resource_states": {},
        "current_work_phase_count": 0,
        "minimum_work_phase_count": 6,
        "replacement_work_phase_required_if_non_work": False,
        "current_plan": copy.deepcopy(revision_payload["current_plan"]),
    }


def _post_with_retries(client, path: str, payload: dict, max_attempts: int = 3):
    base_request_id = payload["meta"]["request_id"]
    last_response = None
    for attempt in range(1, max_attempts + 1):
        attempt_payload = copy.deepcopy(payload)
        attempt_payload["meta"]["request_id"] = (
            f"{base_request_id}_attempt_{attempt}"
        )
        last_response = client.post(path, json=attempt_payload)
        if last_response.status_code == 200:
            return last_response, attempt
    return last_response, max_attempts


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        print(
            "verify_mass_prayer_revision_real: skipped "
            "(non-mock LLM_PROVIDER and LLM_API_KEY required)"
        )
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_THINKING_MODE"] = "disabled"
    os.environ["LLM_TEMPERATURE"] = "0.1"
    client = create_app().test_client()

    revision_payload = _dialogue_prayer_revision_payload()
    judgement_response, judgement_attempts = _post_with_retries(
        client,
        "/npc/plan_revision_judgement",
        _dialogue_judgement_payload(revision_payload),
    )
    assert judgement_response.status_code == 200, judgement_response.get_json()
    judgement = PlanRevisionJudgementResponse.model_validate(
        judgement_response.get_json()
    )
    assert judgement.needs_revision is True, judgement
    assert judgement.revision_hours == [CURRENT_HOUR], judgement
    assert judgement_response.get_json()["model_provider"] == provider
    assert judgement_response.get_json()["model_fallback_used"] is False

    revision_payload["failure_context"][
        "dialogue_plan_judgement"
    ] = judgement.model_dump()
    revision_response, revision_attempts = _post_with_retries(
        client,
        "/npc/revise_plan",
        revision_payload,
    )
    assert revision_response.status_code == 200, revision_response.get_json()
    revision = PlanRevisionResponse.model_validate(revision_response.get_json())
    assert [item.hour for item in revision.revised_plan] == [CURRENT_HOUR]
    assert revision.immediate_action is not None
    assert revision.immediate_action.action_id == "pray_at_chapel", (
        revision.immediate_action
    )
    assert revision.immediate_action.location_id == "chapel"
    assert revision_response.get_json()["model_provider"] == provider
    assert revision_response.get_json()["model_fallback_used"] is False

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    relevant = [
        record
        for record in usage["records"]
        if record["call_type"] in {"plan_revision_judgement", "revise_plan"}
    ]
    assert len(relevant) >= 2
    assert all(record["success"] is True for record in relevant[-2:])
    assert all(record["fallback_used"] is False for record in relevant[-2:])
    print(
        "verify_mass_prayer_revision_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} "
        "dialogue_commitment->pray_at_chapel"
        f"({judgement_attempts}+{revision_attempts})"
    )


if __name__ == "__main__":
    main()
