from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402


class _FakeProviderResponse:
    status_code = 200
    text = ""
    headers: dict[str, str] = {}

    def __init__(self, content: dict) -> None:
        self._body = {
            "choices": [{
                "finish_reason": "stop",
                "message": {"content": json.dumps(content, ensure_ascii=False)},
            }],
            "usage": {
                "prompt_tokens": 800,
                "completion_tokens": 300,
            },
        }

    def json(self) -> dict:
        return self._body


def _item(
    hour: int,
    action_id: str,
    action_kind: str,
    location_id: str | None,
    *,
    target_id: str | None = None,
    dialogue_goal: str = "",
) -> dict:
    return {
        "hour": hour,
        "action_kind": action_kind,
        "action_id": action_id,
        "location_id": location_id,
        "target_id": target_id,
        "priority": 70,
        "reason": "专项契约测试",
        "dialogue_goal": dialogue_goal,
    }


def _allowed_actions() -> list[dict]:
    return [
        {
            "action_id": "work_clinic_doctor",
            "name": "诊所坐诊",
            "action_kind": "work",
            "location_id": "clinic",
            "target_id": None,
            "tags": ["work", "clinic_doctor"],
        },
        {
            "action_id": "talk_to_npc",
            "name": "找马塞尔对话",
            "action_kind": "chat",
            "target_id": "priest_01",
            "target_kind": "npc",
            "target_name": "马塞尔",
            "tags": ["chat", "npc_dialogue"],
        },
        {
            "action_id": "talk_to_npc",
            "name": "找布鲁诺对话",
            "action_kind": "chat",
            "target_id": "cook_01",
            "target_kind": "npc",
            "target_name": "布鲁诺",
            "tags": ["chat", "npc_dialogue"],
        },
        {
            "action_id": "visit_location",
            "name": "前往食堂停留",
            "action_kind": "visit",
            "location_id": "dining_hall",
            "target_id": "dining_hall",
            "target_kind": "location",
            "target_name": "食堂",
            "tags": ["visit"],
        },
        {
            # Even a malformed caller-provided whitelist must not authorize self-talk.
            "action_id": "talk_to_npc",
            "name": "错误的自我对话候选",
            "action_kind": "chat",
            "target_id": "doctor_01",
            "target_kind": "npc",
            "target_name": "莉娜",
            "tags": ["chat", "npc_dialogue"],
        },
        {
            "action_id": "idle",
            "name": "等待",
            "action_kind": "idle",
            "location_id": None,
            "target_id": None,
            "tags": ["idle"],
        },
        {
            "action_id": "seek_guard_officer",
            "name": "寻找守备官",
            "action_kind": "seek_guard_officer",
            "location_id": None,
            "target_id": None,
            "tags": ["proactive_talk"],
        },
        {
            "action_id": "escaping_station",
            "name": "逃离驿站",
            "action_kind": "escape",
            "location_id": None,
            "target_id": None,
            "tags": ["escape"],
        },
    ]


def _npc() -> dict:
    return {
        "identity": {
            "npc_id": "doctor_01",
            "name": "莉娜",
            "background_job": "医生",
            "personality": ["冷静", "尽责"],
            "desires": ["照顾伤员"],
            "fears": ["诊所无法运转"],
            "boundaries": ["不放弃危重伤员"],
        },
        "state": {
            "hp": 100,
            "max_hp": 100,
            "satiety": 80,
            "fatigue": 20,
            "current_location": "clinic",
            "current_location_name": "诊所",
            "recruited": False,
            "skills": {"medical": 82},
        },
        "current_order": {
            "text": "优先照顾伤员。",
            "issued_by": "guard_officer",
            "issued_day": 1,
            "issued_time": "07:30:00",
            "revision": 1,
        },
        "short_term_memory": {
            "recent_events": [],
            "recent_dialogue": [],
            "recent_witnesses": [],
        },
        "knowledge_graph": {},
        "location_context": {},
    }


def _daily_payload() -> dict:
    return {
        "meta": {
            "request_id": "verify_plan_action_contract_daily",
            "call_type": "plan_day",
            "source": "backend_test",
            "requires_time_slowdown": True,
        },
        "game_time": {"day": 1, "time": "08:00:00", "hour": 8},
        "station_context": build_station_context([
            {"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"}
        ]),
        "npc": _npc(),
        "allowed_actions": _allowed_actions(),
        "current_building_states": {},
        "current_resource_states": {},
        "planning_rules": ["通常应强烈优先安排至少 6 个工作阶段，但这不是程序硬门槛。"],
    }


def _daily_response(talk_item: dict) -> dict:
    plan = []
    for hour in range(24):
        if 8 <= hour <= 13:
            plan.append(_item(hour, "work_clinic_doctor", "work", "clinic"))
        else:
            plan.append(_item(hour, "idle", "idle", None))
    plan[14] = talk_item
    return {
        "ok": True,
        "npc_id": "doctor_01",
        "plan_day": 1,
        "plan": plan,
        "summary": "坐诊并与工位占用者协调。",
        "debug_reason": "验证行动目标组合。",
    }


def _revision_payload() -> dict:
    current_plan = []
    for hour in range(24):
        if 8 <= hour <= 13:
            current_plan.append(_item(hour, "work_clinic_doctor", "work", "clinic"))
        else:
            current_plan.append(_item(hour, "idle", "idle", None))
    return {
        "meta": {
            "request_id": "verify_plan_action_contract_revision",
            "call_type": "revise_plan",
            "source": "backend_test",
            "requires_time_slowdown": True,
        },
        "game_time": {"day": 1, "time": "08:00:00", "hour": 8},
        "station_context": build_station_context([
            {"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"}
        ]),
        "npc": _npc(),
        "current_plan": current_plan,
        "failed_plan_item": current_plan[8],
        "revision_scope": "selected_hours",
        "revision_hours": [8, 14],
        "current_work_phase_count": 6,
        "minimum_work_phase_count": 6,
        "past_work_phase_count": 0,
        "minimum_remaining_work_phase_count": 6,
        "replacement_work_phase_required_if_non_work": True,
        "failure_type": "workstation_occupied",
        "failure_summary": "诊所工位被马塞尔占用。",
        "failure_context": {
            "blocked_by_npcs": [{"npc_id": "priest_01", "name": "马塞尔"}],
        },
        "allowed_actions": _allowed_actions(),
        "current_building_states": {
            "clinic": {
                "workstations": [{
                    "id": "clinic_desk_01",
                    "type": "clinic_doctor",
                    "status": "occupied",
                    "occupied_by": "priest_01",
                }],
            },
        },
        "current_resource_states": {},
    }


def _talk_to_priest(hour: int = 8) -> dict:
    item = _item(
        hour,
        "talk_to_npc",
        "chat",
        None,
        target_id="priest_01",
        dialogue_goal="马塞尔，我需要诊所工位，我们能协调一下吗？",
    )
    item.pop("location_id")
    return item


def _selected_hours_revision(payload: dict) -> dict:
    revised_plan = [
        copy.deepcopy(item)
        for item in payload["current_plan"]
        if item["hour"] in payload["revision_hours"]
    ]
    revised_plan[0] = _talk_to_priest(payload["game_time"]["hour"])
    revised_plan[1] = _item(14, "work_clinic_doctor", "work", "clinic")
    return {
        "ok": True,
        "npc_id": "doctor_01",
        "revised_plan": revised_plan,
        "immediate_action": copy.deepcopy(revised_plan[0]),
        "summary": "先协调工位，并仅调整指定时段。",
        "debug_reason": "目标合法且保留六段工作。",
    }


def _post_fake(route: str, payload: dict, model_output: dict):
    app = create_app()
    app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeProviderResponse(model_output),
    ):
        return app.test_client().post(route, json=payload)


def _assert_business_rejection(response, expected_fragment: str) -> None:
    assert response.status_code == 502, response.get_json()
    body = response.get_json()
    assert body["error_code"] == "model_output_invalid"
    assert body["fallback_used"] is False
    assert any(expected_fragment in detail for detail in body["details"]), body["details"]


def _verify_daily_target_contract() -> None:
    payload = _daily_payload()
    legal = _daily_response(_talk_to_priest(14))
    app = create_app()
    app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeProviderResponse(legal),
    ) as fake_post:
        response = app.test_client().post("/npc/plan_day", json=payload)
    assert response.status_code == 200, response.get_json()
    assert response.get_json()["plan"][14]["dialogue_goal"]
    provider_payload = json.loads(
        fake_post.call_args.kwargs["json"]["messages"][1]["content"]
    )
    talk_candidates = [
        candidate
        for candidate in provider_payload["allowed_actions"]
        if candidate["action_id"] == "talk_to_npc"
    ]
    assert talk_candidates
    assert all("location_id" not in candidate for candidate in talk_candidates)

    missing_target = copy.deepcopy(legal)
    missing_target["plan"][14]["target_id"] = None
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, missing_target),
        "action/target combination",
    )

    invented_target = copy.deepcopy(legal)
    invented_target["plan"][14]["target_id"] = "invented_npc_01"
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, invented_target),
        "action/target combination",
    )

    redundant_location = copy.deepcopy(legal)
    redundant_location["plan"][14]["location_id"] = "clinic"
    redundant_location_response = _post_fake(
        "/npc/plan_day",
        payload,
        redundant_location,
    )
    assert redundant_location_response.status_code == 200, redundant_location_response.get_json()
    redundant_location_body = redundant_location_response.get_json()
    assert redundant_location_body["plan"][14]["location_id"] is None
    assert redundant_location_body["model_normalizations"] == [{
        "field": "location_id",
        "path": "plan[14].location_id",
        "hour": 14,
        "action_id": "talk_to_npc",
        "target_id": "priest_01",
        "model_value": "clinic",
        "canonical_value": None,
        "source": "dynamic_npc_target",
    }]

    self_target = copy.deepcopy(legal)
    self_target["plan"][14]["target_id"] = "doctor_01"
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, self_target),
        "cannot be the acting NPC",
    )

    wrong_kind = copy.deepcopy(legal)
    wrong_kind["plan"][14]["action_kind"] = "work"
    normalized_response = _post_fake("/npc/plan_day", payload, wrong_kind)
    assert normalized_response.status_code == 200, normalized_response.get_json()
    normalized_body = normalized_response.get_json()
    assert normalized_body["plan"][14]["action_kind"] == "chat"
    assert normalized_body["model_normalizations"] == [{
        "field": "action_kind",
        "path": "plan[14].action_kind",
        "hour": 14,
        "action_id": "talk_to_npc",
        "target_id": "priest_01",
        "location_id": None,
        "model_value": "work",
        "canonical_value": "chat",
        "source": "exact_allowed_action_candidate",
    }]

    ambiguous_payload = copy.deepcopy(payload)
    ambiguous_payload["allowed_actions"].append(copy.deepcopy(
        next(
            action
            for action in ambiguous_payload["allowed_actions"]
            if action["action_id"] == "talk_to_npc"
            and action["target_id"] == "priest_01"
        )
    ))
    _assert_business_rejection(
        _post_fake("/npc/plan_day", ambiguous_payload, wrong_kind),
        "action_kind 'work' does not match action_id 'talk_to_npc'",
    )

    # Reproduce the real-provider startup failure: the selected visit tuple is
    # valid, while the model labels its redundant kind as semantic "rest".
    visit_with_rest_kind = _daily_response(_item(
        14,
        "visit_location",
        "rest",
        "dining_hall",
        target_id="dining_hall",
    ))
    visit_response = _post_fake("/npc/plan_day", payload, visit_with_rest_kind)
    assert visit_response.status_code == 200, visit_response.get_json()
    visit_body = visit_response.get_json()
    assert visit_body["plan"][14]["action_kind"] == "visit"
    assert visit_body["model_normalizations"][0]["model_value"] == "rest"
    assert visit_body["model_normalizations"][0]["canonical_value"] == "visit"

    schema_invalid_kind = copy.deepcopy(legal)
    schema_invalid_kind["plan"][14]["action_kind"] = "dance"
    schema_invalid_response = _post_fake(
        "/npc/plan_day",
        payload,
        schema_invalid_kind,
    )
    assert schema_invalid_response.status_code == 502, schema_invalid_response.get_json()
    assert schema_invalid_response.get_json()["error_code"] == "model_output_invalid"
    assert schema_invalid_response.get_json()["fallback_used"] is False

    missing_dialogue_goal = copy.deepcopy(legal)
    missing_dialogue_goal["plan"][14]["dialogue_goal"] = "   "
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, missing_dialogue_goal),
        "talk_to_npc requires a non-empty dialogue_goal",
    )

    low_work_plan = copy.deepcopy(legal)
    for index, item in enumerate(low_work_plan["plan"]):
        if item["action_id"] == "work_clinic_doctor":
            low_work_plan["plan"][index] = _item(item["hour"], "idle", "idle", None)
    low_work_response = _post_fake("/npc/plan_day", payload, low_work_plan)
    assert low_work_response.status_code == 200, low_work_response.get_json()


def _verify_exact_null_candidate_contract() -> None:
    payload = _daily_payload()

    legal_seek = _daily_response(_item(
        14,
        "seek_guard_officer",
        "seek_guard_officer",
        None,
    ))
    response = _post_fake("/npc/plan_day", payload, legal_seek)
    assert response.status_code == 200, response.get_json()

    seek_with_invented_location = copy.deepcopy(legal_seek)
    seek_with_invented_location["plan"][14]["location_id"] = "plaza"
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, seek_with_invented_location),
        "action/target/location combination",
    )

    seek_with_invented_target = copy.deepcopy(legal_seek)
    seek_with_invented_target["plan"][14]["target_id"] = "guard_officer"
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, seek_with_invented_target),
        "action/target/location combination",
    )

    legal_escape = _daily_response(_item(
        14,
        "escaping_station",
        "escape",
        None,
    ))
    response = _post_fake("/npc/plan_day", payload, legal_escape)
    assert response.status_code == 200, response.get_json()

    escape_with_invented_location = copy.deepcopy(legal_escape)
    escape_with_invented_location["plan"][14]["location_id"] = "front_gate"
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, escape_with_invented_location),
        "action/target/location combination",
    )

    legal_idle = _daily_response(_item(14, "idle", "idle", None))
    response = _post_fake("/npc/plan_day", payload, legal_idle)
    assert response.status_code == 200, response.get_json()

    idle_with_invented_location = copy.deepcopy(legal_idle)
    idle_with_invented_location["plan"][14]["location_id"] = "plaza"
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, idle_with_invented_location),
        "action/target/location combination",
    )

    idle_with_invented_target = copy.deepcopy(legal_idle)
    idle_with_invented_target["plan"][14]["target_id"] = "doctor_01"
    _assert_business_rejection(
        _post_fake("/npc/plan_day", payload, idle_with_invented_target),
        "action/target/location combination",
    )


def _verify_revision_contract_and_prompt() -> None:
    payload = _revision_payload()
    talk = _talk_to_priest()
    valid_revision = _selected_hours_revision(payload)
    response = _post_fake("/npc/revise_plan", payload, valid_revision)
    assert response.status_code == 200, response.get_json()
    assert response.get_json()["immediate_action"]["target_id"] == "priest_01"

    wrong_kinds = copy.deepcopy(valid_revision)
    wrong_kinds["revised_plan"][0]["action_kind"] = "rest"
    wrong_kinds["immediate_action"]["action_kind"] = "work"
    normalized_response = _post_fake("/npc/revise_plan", payload, wrong_kinds)
    assert normalized_response.status_code == 200, normalized_response.get_json()
    normalized_body = normalized_response.get_json()
    assert normalized_body["revised_plan"][0]["action_kind"] == "chat"
    assert normalized_body["immediate_action"]["action_kind"] == "chat"
    assert {
        item["path"] for item in normalized_body["model_normalizations"]
    } == {"revised_plan[0].action_kind", "immediate_action.action_kind"}

    missing_immediate_action = copy.deepcopy(valid_revision)
    missing_immediate_action["immediate_action"] = None
    derived_immediate = _post_fake("/npc/revise_plan", payload, missing_immediate_action)
    assert derived_immediate.status_code == 200, derived_immediate.get_json()
    assert derived_immediate.get_json()["immediate_action"]["hour"] == 8

    omitted_immediate_action = copy.deepcopy(valid_revision)
    omitted_immediate_action.pop("immediate_action")
    derived_omitted_immediate = _post_fake(
        "/npc/revise_plan",
        payload,
        omitted_immediate_action,
    )
    assert derived_omitted_immediate.status_code == 200, derived_omitted_immediate.get_json()
    assert derived_omitted_immediate.get_json()["immediate_action"]["hour"] == 8

    missing_dialogue_goal = copy.deepcopy(valid_revision)
    missing_dialogue_goal["revised_plan"][0]["dialogue_goal"] = ""
    missing_dialogue_goal["immediate_action"]["dialogue_goal"] = ""
    _assert_business_rejection(
        _post_fake("/npc/revise_plan", payload, missing_dialogue_goal),
        "talk_to_npc requires a non-empty dialogue_goal",
    )

    drops_required_work = copy.deepcopy(valid_revision)
    for item in drops_required_work["revised_plan"]:
        if item["hour"] != 8 and item["action_kind"] == "work":
            item.update(_item(item["hour"], "idle", "idle", None))
    low_work_revision_response = _post_fake(
        "/npc/revise_plan",
        payload,
        drops_required_work,
    )
    assert low_work_revision_response.status_code == 200, low_work_revision_response.get_json()

    redundant_locations = copy.deepcopy(valid_revision)
    redundant_locations["revised_plan"][0]["location_id"] = "clinic"
    redundant_locations["immediate_action"]["location_id"] = "clinic"
    normalized_locations_response = _post_fake(
        "/npc/revise_plan",
        payload,
        redundant_locations,
    )
    assert normalized_locations_response.status_code == 200, normalized_locations_response.get_json()
    normalized_locations_body = normalized_locations_response.get_json()
    assert normalized_locations_body["revised_plan"][0]["location_id"] is None
    assert normalized_locations_body["immediate_action"]["location_id"] is None
    assert {
        item["path"] for item in normalized_locations_body["model_normalizations"]
    } == {"revised_plan[0].location_id", "immediate_action.location_id"}

    # A destroyed building is correctly removed from the *current* whitelist. Old
    # future work slots remain valid historical plan entries, while their count is
    # advisory rather than a response rejection condition.
    destroyed_payload = copy.deepcopy(payload)
    destroyed_payload["allowed_actions"] = [
        action for action in destroyed_payload["allowed_actions"]
        if action["action_id"] != "work_clinic_doctor"
    ]
    destroyed_payload["allowed_actions"].append({
        "action_id": "work_garden",
        "name": "照料菜园",
        "action_kind": "work",
        "location_id": "garden",
        "target_id": None,
        "tags": ["work"],
    })
    destroyed_revision = copy.deepcopy(valid_revision)
    for index, item in enumerate(destroyed_revision["revised_plan"]):
        if item["action_id"] == "work_clinic_doctor":
            destroyed_revision["revised_plan"][index] = _item(
                item["hour"], "work_garden", "work", "garden"
            )
    destroyed_response = _post_fake("/npc/revise_plan", destroyed_payload, destroyed_revision)
    assert destroyed_response.status_code == 200, destroyed_response.get_json()

    adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeProviderResponse(valid_revision),
    ) as fake_post:
        result = adapter.generate("revise_plan", payload)
    assert result.ok, result.message
    prompt = fake_post.call_args.kwargs["json"]["messages"][0]["content"]
    for fragment in [
        "failure_type=workstation_occupied",
        "failure_context.blocked_by_npcs",
        "应优先考虑当面交涉、询问或协调",
        "不要习惯性让 NPC 原地等待",
        "dialogue_goal",
        "replacement_work_phase_required_if_non_work",
        "minimum_remaining_work_phase_count",
        "minimum_work_phase_count",
        "action_kind",
        "`talk_to_npc` 是目标 NPC 驱动的动态追踪行动",
        "不输出 `location_id`",
    ]:
        assert fragment in prompt, fragment


def main() -> None:
    _verify_daily_target_contract()
    _verify_exact_null_candidate_contract()
    _verify_revision_contract_and_prompt()
    print("verify_plan_action_contract: ok")


if __name__ == "__main__":
    main()
