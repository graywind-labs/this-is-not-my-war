from __future__ import annotations

import copy
import os
from pathlib import Path
import sys
import time
from typing import Any

import requests


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.schemas import NPCNPCDialogueResponse, PlanRevisionResponse  # noqa: E402
from tools.verify_npc_npc_dialogue_real import _payload as _dialogue_payload  # noqa: E402
from tools.verify_plan_action_contract import _revision_payload  # noqa: E402


BASE_URL = os.getenv("WAR_NOT_MINE_BACKEND_URL", "http://127.0.0.1:5000").rstrip("/")
REQUEST_TIMEOUT_SECONDS = 180


def _request_json(method: str, path: str, payload: dict[str, Any] | None = None) -> tuple[int, dict[str, Any]]:
    try:
        response = requests.request(
            method,
            f"{BASE_URL}{path}",
            json=payload,
            timeout=(10, REQUEST_TIMEOUT_SECONDS),
        )
    except requests.RequestException as exc:
        raise AssertionError(f"backend request failed for {path}: {type(exc).__name__}: {exc}") from exc

    try:
        body = response.json()
    except ValueError as exc:
        preview = response.text[:500].replace("\n", " ")
        raise AssertionError(
            f"backend returned non-JSON for {path}: HTTP {response.status_code}: {preview}"
        ) from exc
    assert isinstance(body, dict), (path, response.status_code, body)
    return response.status_code, body


def _assert_real_runtime() -> tuple[str, str]:
    status, health = _request_json("GET", "/health")
    assert status == 200 and health.get("ok") is True, health
    runtime = health.get("model_adapter", {})
    assert isinstance(runtime, dict), health

    provider = str(runtime.get("provider", "")).strip().lower()
    model = str(runtime.get("model", "")).strip()
    assert provider and provider != "mock", f"port 5000 is not using a real provider: {provider or '<empty>'}"
    assert runtime.get("configured") is True, "port 5000 real provider is not configured"
    assert runtime.get("fallback_to_mock") is False, "port 5000 has mock fallback enabled"
    assert runtime.get("client_output_token_limit_applied") is False, (
        "port 5000 still applies a client output-token cap"
    )
    return provider, model


def _assert_success_provenance(body: dict[str, Any], provider: str) -> None:
    actual_provider = str(body.get("model_provider", "")).strip().lower()
    assert actual_provider == provider, (actual_provider, provider, body)
    assert actual_provider != "mock", body
    assert body.get("model_fallback_used") is False, body
    assert body.get("fallback_used") is not True, body
    assert str(body.get("source", "")).strip().lower() not in {
        "mock",
        "mock_plan_day",
        "mock_revision",
        "rule_plan_fallback",
    }, body


def _assert_usage_record(request_id: str, call_type: str, provider: str) -> None:
    status, usage = _request_json("GET", "/debug/llm_usage")
    assert status == 200 and usage.get("ok") is True, usage
    runtime = usage.get("model_adapter", {})
    assert str(runtime.get("provider", "")).strip().lower() == provider, runtime
    assert runtime.get("fallback_to_mock") is False, runtime

    matching = [
        record
        for record in usage.get("records", [])
        if record.get("request_id") == request_id
    ]
    assert len(matching) == 1, (
        f"expected exactly one usage record for {request_id}, got {len(matching)}"
    )
    record = matching[0]
    assert record.get("call_type") == call_type, record
    assert record.get("success") is True, record
    assert str(record.get("provider", "")).strip().lower() == provider, record
    assert str(record.get("provider", "")).strip().lower() != "mock", record
    assert record.get("fallback_used") is False, record
    assert not str(record.get("degradation_source", "")).strip(), record
    assert not str(record.get("failure_reason", "")).strip(), record
    assert not str(record.get("exception_type", "")).strip(), record


def _verify_workstation_revision(provider: str, unique_suffix: str) -> tuple[str, int]:
    payload = copy.deepcopy(_revision_payload())
    request_id = f"verify_workstation_dialogue_revision_real_{unique_suffix}"
    payload["meta"]["request_id"] = request_id

    status, body = _request_json("POST", "/npc/revise_plan", payload)
    assert status == 200, {"status": status, "body": body}
    _assert_success_provenance(body, provider)

    revision = PlanRevisionResponse.model_validate(body)
    assert revision.npc_id == "doctor_01", revision
    assert [item.hour for item in revision.revised_plan] == payload["revision_hours"], revision
    immediate = revision.immediate_action
    assert immediate is not None, revision
    assert immediate.hour == payload["game_time"]["hour"], immediate
    assert immediate.action_kind == "chat", immediate
    assert immediate.action_id == "talk_to_npc", immediate
    assert immediate.target_id == "priest_01", immediate
    assert immediate.location_id is None, immediate
    assert immediate.dialogue_goal.strip(), immediate

    merged_by_hour = {item["hour"]: item for item in payload["current_plan"]}
    for item in revision.revised_plan:
        merged_by_hour[item.hour] = item.model_dump()
    merged_by_hour[immediate.hour] = immediate.model_dump()
    work_action_ids = {
        candidate["action_id"]
        for candidate in payload["allowed_actions"]
        if any(
            tag in {"work", "clinic_doctor", "training_instructor"}
            for tag in candidate.get("tags", [])
        )
    }
    work_phase_count = sum(
        1
        for item in merged_by_hour.values()
        if item["action_id"] in work_action_ids
    )
    _assert_usage_record(request_id, "revise_plan", provider)
    return request_id, work_phase_count


def _verify_npc_npc_dialogue(provider: str, unique_suffix: str) -> str:
    payload = copy.deepcopy(_dialogue_payload())
    payload["dialogue_phase"] = "invitation"
    payload["current_round"] = 0
    payload["dialogue_state"]["current_round"] = 0
    request_id = f"verify_npc_npc_dialogue_live_{unique_suffix}"
    payload["meta"]["request_id"] = request_id

    status, body = _request_json("POST", "/npc/dialogue", payload)
    assert status == 200, {"status": status, "body": body}
    _assert_success_provenance(body, provider)

    dialogue = NPCNPCDialogueResponse.model_validate({
        key: value
        for key, value in body.items()
        if not key.startswith("model_")
    })
    assert dialogue.replyer_id == "priest_01", dialogue
    assert dialogue.response_kind == "reply_to_npc", dialogue
    assert dialogue.invitation_result in {"accept", "reject"}, dialogue
    assert dialogue.reply_text.strip(), dialogue

    _assert_usage_record(request_id, "dialogue", provider)
    return request_id


def main() -> None:
    provider, model = _assert_real_runtime()
    unique_suffix = str(time.time_ns())
    _, work_phase_count = _verify_workstation_revision(provider, unique_suffix)
    _verify_npc_npc_dialogue(provider, unique_suffix)
    print(
        "verify_workstation_dialogue_revision_real: ok "
        f"provider={provider} model={model} "
        "revision=talk_to_npc target=priest_01 dynamic_location "
        f"work_phases={work_phase_count} dialogue=reply_to_npc fallback_used=false"
    )


if __name__ == "__main__":
    main()
