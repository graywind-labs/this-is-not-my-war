import copy
import json
import os
from pathlib import Path
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import (  # noqa: E402
    PlanRevisionJudgementRequest,
    PlanRevisionJudgementResponse,
)
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402


class _FakeResponse:
    status_code = 200
    text = ""

    def __init__(self, content: dict | None = None, raw_content: str = "", finish_reason: str = "stop") -> None:
        content_text = raw_content if raw_content else json.dumps(content, ensure_ascii=False)
        self._body = {
            "choices": [{
                "finish_reason": finish_reason,
                "message": {"content": content_text},
            }],
            "usage": {"prompt_tokens": 320, "completion_tokens": 45},
        }

    def json(self) -> dict:
        return self._body


def _plan_item(hour: int) -> dict:
    return {
        "hour": hour,
        "action_kind": "work" if 8 <= hour <= 13 else "idle",
        "action_id": "work_garden" if 8 <= hour <= 13 else "idle",
        "location_id": "garden" if 8 <= hour <= 13 else None,
        "target_id": None,
        "priority": 60,
        "reason": "照料菜园" if 8 <= hour <= 13 else "按原计划等待",
        "dialogue_goal": "",
    }


def _payload(dialogue_text: str = "守备官，我答应在14点训练，18点去守门。") -> dict:
    return {
        "meta": {
            "request_id": "verify_dialogue_plan_revision_judgement",
            "call_type": "plan_revision_judgement",
            "source": "backend_test",
            "requires_time_slowdown": True,
        },
        "game_time": {"day": 2, "time": "10:15:00", "hour": 10},
        "station_context": build_station_context(
            [
                {"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"},
            ],
            setting_summary="边境驿站正在备战。",
        ),
        "npc_id": "gardener_01",
        "npc_name": "伊沃",
        "npc": {
            "identity": {
                "npc_id": "gardener_01",
                "name": "伊沃",
                "background_job": "园丁",
                "personality": ["谨慎", "爱护活物"],
                "desires": ["保住菜园"],
                "fears": ["无谓牺牲"],
                "boundaries": ["不伤害平民"],
                "speech_style": "沉稳朴素",
            },
            "state": {
                "hp": 86,
                "max_hp": 100,
                "satiety": 62,
                "fatigue": 31,
                "current_action": "idle",
                "current_location": "garden",
                "current_location_name": "菜园",
            },
            "current_order": {
                "text": "先照看菜园，危险时不要冒进。",
                "issued_by": "guard_officer",
                "issued_day": 2,
                "issued_time": "09:00:00",
                "revision": 2,
            },
            "short_term_memory": {
                "experienced_events": [{
                    "event_id": "evt_garden_damage",
                    "type": "building_damaged",
                    "summary": "菜园围栏被袭击损坏。",
                    "day": 2,
                    "time": "09:40:00",
                }],
                "witnessed_events": [],
            },
            "long_term_memory": {
                "knowledge_graph": {"guard_officer|trust": "谨慎信任"},
                "diary": ["守备官答应尽量让大家活下来。"],
            },
            "knowledge_graph": {"guard_officer|trust": "谨慎信任"},
            "location_context": {"location_id": "garden", "location_name": "菜园"},
            "plaza_context": {},
        },
        "trigger_kind": "dialogue",
        "dialogue_kind": "player_npc",
        "dialogue_history": [
            {
                "speaker_id": "guard_officer",
                "speaker_name": "守备官",
                "listener_id": "gardener_01",
                "listener_name": "伊沃",
                "text": "你下午能调整一下安排吗？",
                "day": 2,
                "time": "10:14:00",
                "visibility": "private",
            },
            {
                "speaker_id": "gardener_01",
                "speaker_name": "伊沃",
                "listener_id": "guard_officer",
                "listener_name": "守备官",
                "text": dialogue_text,
                "day": 2,
                "time": "10:15:00",
                "visibility": "private",
            },
        ],
        "dialogue_end_reason": "dialogue_completed",
        "dialogue_context": {"location_id": "garden", "participants": ["guard_officer", "gardener_01"]},
        "allowed_actions": [],
        "current_building_states": {"garden": {"hp": 80}},
        "current_resource_states": {"food": 12},
        "current_plan": [_plan_item(hour) for hour in range(24)],
    }


def _action_failure_payload(force_no_revision: bool = False) -> dict:
    payload = _payload()
    payload["meta"]["request_id"] = "verify_action_failure_plan_revision_judgement"
    payload["trigger_kind"] = "action_failure"
    payload["dialogue_history"] = []
    payload["failed_plan_item"] = copy.deepcopy(payload["current_plan"][10])
    payload["failure_type"] = "workstation_occupied"
    payload["failure_summary"] = "诊所医生工位被莉娜占用。"
    payload["failure_context"] = {
        "building_id": "clinic",
        "workstation_type": "clinic_doctor_station",
        "blocked_by_npc_ids": ["doctor_01"],
        "debug_force_no_revision": force_no_revision,
    }
    payload["current_work_phase_count"] = 6
    payload["minimum_work_phase_count"] = 6
    payload["replacement_work_phase_required_if_non_work"] = True
    return payload


def _valid_response() -> dict:
    return {
        "revision_hours": [14, 18],
        "summary": "两个明确承诺影响原安排。",
        "debug_reason": "仅修改承诺时段。",
    }


def main() -> None:
    payload = _payload()
    request_model = PlanRevisionJudgementRequest.model_validate(payload)
    assert len(request_model.current_plan) == 24
    assert len(request_model.dialogue_history) == 2
    assert request_model.npc.identity.personality == ["谨慎", "爱护活物"]
    assert request_model.npc.long_term_memory.diary

    os.environ["LLM_PROVIDER"] = "mock"
    os.environ.pop("LLM_API_KEY", None)
    mock_client = create_app().test_client()
    changed = mock_client.post("/npc/plan_revision_judgement", json=payload)
    assert changed.status_code == 200, changed.get_json()
    changed_body = changed.get_json()
    assert changed_body["needs_revision"] is True
    assert changed_body["revision_hours"] == [14, 18]
    assert changed_body["model_provider"] == "mock"
    assert changed_body["model_fallback_used"] is False

    unchanged_payload = _payload("今天风很大，我们先谈到这里吧。")
    unchanged = mock_client.post(
        "/npc/plan_revision_judgement",
        json=unchanged_payload,
    )
    assert unchanged.status_code == 200, unchanged.get_json()
    assert unchanged.get_json()["needs_revision"] is False
    assert unchanged.get_json()["revision_hours"] == []

    forced_current_payload = copy.deepcopy(unchanged_payload)
    forced_current_payload["required_revision_hours"] = [10]
    forced_current = mock_client.post(
        "/npc/plan_revision_judgement",
        json=forced_current_payload,
    )
    assert forced_current.status_code == 200, forced_current.get_json()
    assert forced_current.get_json()["needs_revision"] is True
    assert forced_current.get_json()["revision_hours"] == [10]

    empty_dialogue = copy.deepcopy(payload)
    empty_dialogue["dialogue_history"] = []
    assert mock_client.post(
        "/npc/plan_revision_judgement",
        json=empty_dialogue,
    ).status_code == 400

    incomplete_plan = copy.deepcopy(payload)
    incomplete_plan["current_plan"] = incomplete_plan["current_plan"][:-1]
    assert mock_client.post(
        "/npc/plan_revision_judgement",
        json=incomplete_plan,
    ).status_code == 400

    adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeResponse(_valid_response()),
    ) as fake_post:
        result = adapter.generate("plan_revision_judgement", payload)
    assert result.ok
    PlanRevisionJudgementResponse.model_validate(result.content)
    request_body = fake_post.call_args.kwargs["json"]
    provider_payload = json.loads(request_body["messages"][1]["content"])
    assert "max_tokens" not in request_body
    assert "meta" not in provider_payload
    assert "npc_id" not in provider_payload
    assert "npc_name" not in provider_payload
    assert "failed_plan_item" not in provider_payload
    assert "failure_type" not in provider_payload
    assert "failure_summary" not in provider_payload
    assert "failure_context" not in provider_payload
    assert "knowledge_graph" not in provider_payload["npc"]
    assert result.content["ok"] is True
    assert result.content["npc_id"] == "gardener_01"
    assert result.content["needs_revision"] is True
    prompt = request_body["messages"][0]["content"]
    for fragment in [
        "计划修改范围判别器",
        "trigger_kind",
        "dialogue_history",
        "failed_plan_item",
        "npc.long_term_memory",
        "current_order",
        "plan_item_superseded",
        "current_plan",
        "最小且精确",
        "往昔·近日",
        "传达敌情",
        "日记字符串保留",
        "第 N 天 + 时间",
        "不要为了保险把当前小时到 23 点全部列出",
        "总工期与剩余时间",
        "不能把短工期外推到更晚时段",
        "required_revision_hours",
        "主动找守备官交涉",
        "只输出 revision_hours、summary、debug_reason",
        "不得选择行动",
        "failure_context.failure_id",
        "pray_failed_mass_in_progress",
        "pray_failed_mass_started",
        "attend_mass_failed_no_leader",
        "attend_mass_failed_leader_left",
        "必须把当前小时加入 revision_hours",
        "守备官请目标 NPC 现在参加",
        "NPC 清楚答应立即参加",
        "`attend_mass` 当前 `eligible=true / available_now=true`",
    ]:
        assert fragment in prompt, fragment

    retry_adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        side_effect=[
            _FakeResponse(raw_content='{"ok":true', finish_reason="length"),
            _FakeResponse(_valid_response()),
        ],
    ) as retry_post:
        retry_result = retry_adapter.generate(
            "plan_revision_judgement",
            payload,
        )
    assert retry_result.ok
    assert retry_post.call_count == 2
    assert retry_result.usage["attempt_count"] == 2
    retry_prompt = retry_post.call_args_list[1].kwargs["json"]["messages"][0]["content"]
    assert "revision_hours 必须升序去重" in retry_prompt

    invalid_app = create_app()
    invalid_app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    inconsistent = _valid_response()
    inconsistent["needs_revision"] = False
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeResponse(inconsistent),
    ):
        invalid = invalid_app.test_client().post(
            "/npc/plan_revision_judgement",
            json=payload,
        )
    assert invalid.status_code == 200, invalid.get_json()
    assert invalid.get_json()["needs_revision"] is True

    missing_required = _valid_response()
    missing_required["needs_revision"] = False
    missing_required["revision_hours"] = []
    missing_required["summary"] = "模型认为普通对话无需修改。"
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeResponse(missing_required),
    ):
        normalized_required = invalid_app.test_client().post(
            "/npc/plan_revision_judgement",
            json=forced_current_payload,
        )
    assert normalized_required.status_code == 200, normalized_required.get_json()
    assert normalized_required.get_json()["needs_revision"] is True
    assert normalized_required.get_json()["revision_hours"] == [10]
    assert normalized_required.get_json()["model_normalizations"] == [{
        "field": "revision_hours",
        "reason": "required_revision_hours_authoritative_union",
        "from": [],
        "to": [10],
    }]

    action_failure_payload = _action_failure_payload()
    action_request = PlanRevisionJudgementRequest.model_validate(action_failure_payload)
    assert action_request.trigger_kind == "action_failure"

    superseded_payload = _action_failure_payload()
    superseded_payload["failure_type"] = "plan_item_superseded"
    superseded_payload["failure_summary"] = "等待目标制定计划期间同小时计划被新安排替代。"
    superseded_payload["failure_context"].update({
        "target_npc_id": "engineer_01",
        "assigned_day": 2,
        "assigned_hour": 10,
        "failed_day": 2,
        "failed_hour": 11,
        "current_plan_item": _plan_item(11),
        "waited_across_hour": False,
    })
    superseded_request = PlanRevisionJudgementRequest.model_validate(superseded_payload)
    assert superseded_request.failure_type == "plan_item_superseded"
    assert superseded_request.failure_context["waited_across_hour"] is False
    assert superseded_request.npc.long_term_memory.diary

    action_failure = mock_client.post(
        "/npc/plan_revision_judgement",
        json=action_failure_payload,
    )
    assert action_failure.status_code == 200, action_failure.get_json()
    assert action_failure.get_json()["needs_revision"] is True
    assert action_failure.get_json()["revision_hours"] == [10, 14]

    no_revision_payload = _action_failure_payload(True)
    no_revision = mock_client.post(
        "/npc/plan_revision_judgement",
        json=no_revision_payload,
    )
    assert no_revision.status_code == 200, no_revision.get_json()
    assert no_revision.get_json()["needs_revision"] is False
    assert no_revision.get_json()["revision_hours"] == []

    invalid_action_failure = _action_failure_payload()
    invalid_action_failure["failed_plan_item"] = None
    assert mock_client.post(
        "/npc/plan_revision_judgement",
        json=invalid_action_failure,
    ).status_code == 400

    print("verify_dialogue_plan_revision_judgement: ok")


if __name__ == "__main__":
    main()
