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
from tools.verify_dialogue_plan_revision_judgement import _payload  # noqa: E402
from tools.verify_plan_action_contract import _revision_payload  # noqa: E402


def _post_with_real_retries(
    client,
    payload: dict,
    max_attempts: int = 3,
    path: str = "/npc/plan_revision_judgement",
):
    base_request_id = payload["meta"]["request_id"]
    last_response = None
    for attempt in range(1, max_attempts + 1):
        attempt_payload = copy.deepcopy(payload)
        attempt_payload["meta"]["request_id"] = f"{base_request_id}_attempt_{attempt}"
        last_response = client.post(path, json=attempt_payload)
        if last_response.status_code == 200:
            return last_response, attempt
    return last_response, max_attempts


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print(
            "verify_dialogue_plan_revision_judgement_real: skipped "
            "(non-mock LLM_PROVIDER and LLM_API_KEY required)"
        )
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_THINKING_MODE"] = "disabled"
    os.environ["LLM_TEMPERATURE"] = "0.1"

    client = create_app().test_client()

    changed_payload = _payload(
        "守备官，我明确答应今天14点替你去训练；除此之外都按原计划。"
    )
    changed_payload["meta"]["request_id"] = "verify_dialogue_plan_revision_judgement_real_changed"
    changed_response, changed_attempts = _post_with_real_retries(client, changed_payload)
    assert changed_response.status_code == 200, changed_response.get_json()
    changed = PlanRevisionJudgementResponse.model_validate(changed_response.get_json())
    assert changed.npc_id == "gardener_01"
    assert changed.needs_revision is True, changed
    assert changed.revision_hours == [14], changed
    assert changed_response.get_json()["model_provider"] == provider
    assert changed_response.get_json()["model_fallback_used"] is False

    revision_payload = _revision_payload()
    revision_payload["meta"]["request_id"] = (
        "verify_dialogue_plan_revision_judgement_real_revision"
    )
    revision_payload["game_time"] = copy.deepcopy(changed_payload["game_time"])
    revision_payload["npc"]["identity"].update({
        "npc_id": "gardener_01",
        "name": "伊沃",
        "background_job": "园丁",
    })
    revision_payload["npc"]["long_term_memory"] = copy.deepcopy(
        changed_payload["npc"]["long_term_memory"]
    )
    revision_payload["npc"]["short_term_memory"] = copy.deepcopy(
        changed_payload["npc"]["short_term_memory"]
    )
    revision_payload["current_plan"] = copy.deepcopy(changed_payload["current_plan"])
    revision_payload["failed_plan_item"] = copy.deepcopy(changed_payload["current_plan"][14])
    revision_payload["revision_hours"] = changed.revision_hours
    revision_payload["past_work_phase_count"] = 2
    revision_payload["minimum_remaining_work_phase_count"] = 4
    revision_payload["replacement_work_phase_required_if_non_work"] = False
    revision_payload["failure_type"] = "dialogue_interrupted"
    revision_payload["failure_summary"] = "本轮对话形成了14点训练的新承诺。"
    revision_payload["failure_context"] = {
        "dialogue_history": copy.deepcopy(changed_payload["dialogue_history"]),
        "dialogue_plan_revision_judgement": changed.model_dump(),
    }
    revision_payload["allowed_actions"].append({
        "action_id": "receive_weapon_training",
        "name": "接受武器训练",
        "action_kind": "train",
        "location_id": "training_ground",
        "target_id": None,
        "tags": ["training_student"],
        "context": {"eligible": True, "available_now": True},
    })
    revision_response, revision_attempts = _post_with_real_retries(
        client,
        revision_payload,
        path="/npc/revise_plan",
    )
    assert revision_response.status_code == 200, revision_response.get_json()
    revision = PlanRevisionResponse.model_validate(revision_response.get_json())
    assert [item.hour for item in revision.revised_plan] == changed.revision_hours
    assert revision.immediate_action is None
    assert revision_response.get_json()["model_provider"] == provider
    assert revision_response.get_json()["model_fallback_used"] is False

    unchanged_payload = _payload(
        "守备官，我们只是聊了聊天气。我没有答应新事情，一切按原计划。"
    )
    unchanged_payload["dialogue_history"][0]["text"] = "今天风很大，你还好吗？"
    unchanged_payload["meta"]["request_id"] = "verify_dialogue_plan_revision_judgement_real_unchanged"
    unchanged_response, unchanged_attempts = _post_with_real_retries(client, unchanged_payload)
    assert unchanged_response.status_code == 200, unchanged_response.get_json()
    unchanged = PlanRevisionJudgementResponse.model_validate(unchanged_response.get_json())
    assert unchanged.npc_id == "gardener_01"
    assert unchanged.needs_revision is False, unchanged
    assert unchanged.revision_hours == [], unchanged
    assert unchanged_response.get_json()["model_provider"] == provider
    assert unchanged_response.get_json()["model_fallback_used"] is False

    action_revision_payload = _revision_payload()
    action_judgement_payload = {
        "meta": {
            "request_id": "verify_action_failure_plan_revision_judgement_real",
            "call_type": "plan_revision_judgement",
            "source": "backend_test",
            "requires_time_slowdown": True,
        },
        "game_time": copy.deepcopy(action_revision_payload["game_time"]),
        "station_context": copy.deepcopy(action_revision_payload["station_context"]),
        "npc_id": action_revision_payload["npc"]["identity"]["npc_id"],
        "npc_name": action_revision_payload["npc"]["identity"]["name"],
        "npc": copy.deepcopy(action_revision_payload["npc"]),
        "trigger_kind": "action_failure",
        "dialogue_history": [],
        "failed_plan_item": copy.deepcopy(action_revision_payload["failed_plan_item"]),
        "failure_type": action_revision_payload["failure_type"],
        "failure_summary": action_revision_payload["failure_summary"],
        "failure_context": copy.deepcopy(action_revision_payload["failure_context"]),
        "allowed_actions": copy.deepcopy(action_revision_payload["allowed_actions"]),
        "current_building_states": copy.deepcopy(action_revision_payload["current_building_states"]),
        "current_resource_states": copy.deepcopy(action_revision_payload["current_resource_states"]),
        "current_work_phase_count": action_revision_payload["current_work_phase_count"],
        "minimum_work_phase_count": action_revision_payload["minimum_work_phase_count"],
        "replacement_work_phase_required_if_non_work": True,
        "current_plan": copy.deepcopy(action_revision_payload["current_plan"]),
    }
    action_response, action_judgement_attempts = _post_with_real_retries(
        client,
        action_judgement_payload,
    )
    assert action_response.status_code == 200, action_response.get_json()
    action_judgement = PlanRevisionJudgementResponse.model_validate(
        action_response.get_json()
    )
    assert action_judgement.needs_revision is True, action_judgement
    assert action_judgement.revision_hours == [8, 14], action_judgement
    assert action_response.get_json()["model_provider"] == provider
    assert action_response.get_json()["model_fallback_used"] is False

    action_revision_payload["meta"]["request_id"] = (
        "verify_action_failure_plan_revision_real_revision"
    )
    action_revision_payload["revision_hours"] = action_judgement.revision_hours
    action_revision_payload["failure_context"]["plan_revision_judgement"] = (
        action_judgement.model_dump()
    )
    action_revision_response, action_revision_attempts = _post_with_real_retries(
        client,
        action_revision_payload,
        path="/npc/revise_plan",
    )
    assert action_revision_response.status_code == 200, action_revision_response.get_json()
    action_revision = PlanRevisionResponse.model_validate(
        action_revision_response.get_json()
    )
    assert [item.hour for item in action_revision.revised_plan] == [8, 14]
    assert action_revision.immediate_action is not None
    assert action_revision_response.get_json()["model_provider"] == provider
    assert action_revision_response.get_json()["model_fallback_used"] is False

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    judgement_records = [
        record
        for record in usage["records"]
        if record["call_type"] == "plan_revision_judgement"
    ]
    assert len(judgement_records) >= 3
    assert all(record["fallback_used"] is False for record in judgement_records)
    assert judgement_records[-1]["success"] is True
    revision_records = [
        record
        for record in usage["records"]
        if record["call_type"] == "revise_plan"
    ]
    assert revision_records
    assert revision_records[-1]["success"] is True
    assert revision_records[-1]["fallback_used"] is False

    print(
        "verify_dialogue_plan_revision_judgement_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} "
        f"changed_attempts={changed_attempts} revision_attempts={revision_attempts} "
        f"unchanged_attempts={unchanged_attempts} "
        f"action_judgement_attempts={action_judgement_attempts} "
        f"action_revision_attempts={action_revision_attempts}"
    )


if __name__ == "__main__":
    main()
