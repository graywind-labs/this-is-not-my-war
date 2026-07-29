from pathlib import Path
import copy
import os
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import PlanRevisionResponse  # noqa: E402
from tools.verify_plan_action_contract import _revision_payload  # noqa: E402


def _post_with_real_retries(client, payload: dict, max_attempts: int = 3):
    base_request_id = payload["meta"]["request_id"]
    last_response = None
    for attempt in range(1, max_attempts + 1):
        attempt_payload = copy.deepcopy(payload)
        attempt_payload["meta"]["request_id"] = f"{base_request_id}_attempt_{attempt}"
        last_response = client.post("/npc/revise_plan", json=attempt_payload)
        if last_response.status_code == 200:
            return last_response, attempt
    return last_response, max_attempts


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_plan_revision_prompt_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_THINKING_MODE"] = "disabled"
    os.environ["LLM_TEMPERATURE"] = "0.2"

    client = create_app().test_client()
    payload = _revision_payload()
    payload["allowed_actions"].append({
        "action_id": "receive_clinic_treatment",
        "name": "在诊所病床接受治疗",
        "action_kind": "assist_heal",
        "location_id": "clinic",
        "target_id": None,
        "tags": ["clinic_patient"],
        "context": {
            "eligible": True,
            "available_now": False,
            "unavailable_reason": "诊所没有在岗医生",
            "required_active_action_id": "work_clinic_doctor",
        },
    })
    response, attempts = _post_with_real_retries(client, payload)
    assert response.status_code == 200, response.get_json()
    revision = PlanRevisionResponse(**response.get_json())
    assert revision.npc_id == "doctor_01"
    current_hour = payload["game_time"]["hour"]
    assert [item.hour for item in revision.revised_plan] == payload["revision_hours"]
    assert revision.immediate_action is not None
    assert revision.immediate_action.hour == 8
    assert revision.immediate_action.action_id == "talk_to_npc", revision.immediate_action
    assert revision.immediate_action.target_id == "priest_01", revision.immediate_action
    assert revision.immediate_action.location_id is None, revision.immediate_action
    assert revision.immediate_action.dialogue_goal.strip(), revision.immediate_action
    assert revision.immediate_action.action_id != "receive_clinic_treatment", revision.immediate_action

    merged_by_hour = {item["hour"]: item for item in payload["current_plan"]}
    for item in revision.revised_plan:
        merged_by_hour[item.hour] = item.model_dump()
    merged_by_hour[revision.immediate_action.hour] = revision.immediate_action.model_dump()
    work_action_ids = {
        candidate["action_id"]
        for candidate in payload["allowed_actions"]
        if any(tag in {"work", "clinic_doctor", "training_instructor"} for tag in candidate.get("tags", []))
    }
    work_phase_count = sum(
        1 for item in merged_by_hour.values() if item["action_id"] in work_action_ids
    )

    current_item = next(item for item in revision.revised_plan if item.hour == current_hour)
    assert revision.immediate_action.action_id == current_item.action_id
    assert revision.immediate_action.action_kind == current_item.action_kind
    assert revision.immediate_action.target_id == current_item.target_id
    assert revision.immediate_action.location_id == current_item.location_id

    completion_payload = _revision_payload()
    completion_payload["meta"]["request_id"] = "verify_action_completed_revision_real"
    completion_payload["revision_hours"] = [current_hour]
    completion_payload["replacement_work_phase_required_if_non_work"] = False
    completion_payload["npc"]["state"]["wine"] = 1
    completed_drink = {
        "hour": current_hour,
        "action_kind": "drink",
        "action_id": "drink_wine",
        "location_id": None,
        "target_id": None,
        "priority": 75,
        "reason": "短暂饮酒",
        "dialogue_goal": "",
    }
    completion_payload["current_plan"][current_hour] = copy.deepcopy(completed_drink)
    completion_payload["failed_plan_item"] = copy.deepcopy(completed_drink)
    completion_payload["failure_type"] = "action_completed"
    completion_payload["failure_summary"] = "饮酒已经完成，当前小时仍需安排后续活动。"
    completion_payload["failure_context"] = {
        "condition": "successful_plan_action_completion",
        "completed_action_id": "drink_wine",
        "completion_result": "completed_drink_wine",
        "requires_different_current_activity": True,
    }
    completion_payload["allowed_actions"].append({
        "action_id": "drink_wine",
        "name": "饮酒",
        "action_kind": "drink",
        "location_id": None,
        "target_id": None,
        "tags": ["drink"],
        "context": {
            "eligible": True,
            "available_now": True,
            "description": "消耗一份个人酒。",
        },
    })
    completion_response, completion_attempts = _post_with_real_retries(
        client,
        completion_payload,
    )
    assert completion_response.status_code == 200, completion_response.get_json()
    completion_revision = PlanRevisionResponse(**completion_response.get_json())
    assert [item.hour for item in completion_revision.revised_plan] == [current_hour]
    assert completion_revision.immediate_action is not None
    assert completion_revision.immediate_action.hour == current_hour
    assert completion_revision.immediate_action.action_id != "drink_wine", (
        completion_revision.immediate_action
    )

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["model_adapter"]["client_output_token_limit_applied"] is False
    assert usage["summary"]["count"] >= 1
    assert all(record["fallback_used"] is False for record in usage["records"])
    assert usage["records"][-1]["call_type"] == "revise_plan"
    assert usage["records"][-1]["success"] is True

    print(
        "verify_plan_revision_prompt_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} "
        f"attempts={attempts}+{completion_attempts} "
        f"selected_items={len(revision.revised_plan)} "
        f"completion_action={completion_revision.immediate_action.action_id} "
        f"work_phases={work_phase_count}"
    )


if __name__ == "__main__":
    main()
