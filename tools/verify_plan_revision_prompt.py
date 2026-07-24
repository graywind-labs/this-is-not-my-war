from pathlib import Path
import copy
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import PlanRevisionResponse  # noqa: E402
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402


class _FakeRevisionResponse:
    status_code = 200
    text = ""

    def __init__(self, content: dict | None = None, raw_content: str = "", finish_reason: str = "stop") -> None:
        import json

        content_text = raw_content if raw_content else json.dumps(content, ensure_ascii=False)
        self._body = {
            "choices": [{
                "finish_reason": finish_reason,
                "message": {"content": content_text},
            }],
            "usage": {
                "prompt_tokens": 900,
                "completion_tokens": 260,
            },
        }

    def json(self) -> dict:
        return self._body


def _plan_item(hour: int, action_id: str, action_kind: str, location_id: str, reason: str) -> dict:
    return {
        "hour": hour,
        "action_kind": action_kind,
        "action_id": action_id,
        "location_id": location_id,
        "target_id": None,
        "priority": 70,
        "reason": reason,
    }


def _payload() -> dict:
    current_plan = [
        _plan_item(hour, "work_blacksmith", "work", "blacksmith", "继续打铁")
        for hour in range(24)
    ]
    return {
        "meta": {
            "request_id": "verify_plan_revision_prompt",
            "call_type": "revise_plan",
            "source": "backend_test",
            "requires_time_slowdown": True,
            "related_event_id": None,
        },
        "game_time": {"day": 2, "time": "08:00:00", "hour": 8},
        "station_context": build_station_context([
            {"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"}
        ]),
        "npc": {
            "identity": {
                "npc_id": "blacksmith_01",
                "name": "奥托",
                "background_job": "铁匠",
                "personality": ["务实"],
                "desires": ["守住铁匠铺"],
                "fears": ["铁料耗尽"],
                "boundaries": ["不凭空制造材料"],
            },
            "state": {
                "hp": 100,
                "max_hp": 100,
                "satiety": 75,
                "fatigue": 25,
                "current_location": "blacksmith",
                "current_location_name": "铁匠铺",
                "recruited": False,
                "skills": {"打铁": 80},
            },
            "current_order": {
                "text": "",
                "issued_by": "guard_officer",
                "issued_day": 0,
                "issued_time": "",
                "revision": 0,
            },
            "short_term_memory": {
                "recent_events": [],
                "recent_dialogue": [],
                "recent_witnesses": [],
            },
            "knowledge_graph": {},
            "location_context": {},
        },
        "current_plan": current_plan,
        "failed_plan_item": current_plan[8],
        "revision_scope": "selected_hours",
        "revision_hours": [8, 14],
        "current_work_phase_count": 24,
        "minimum_work_phase_count": 6,
        "past_work_phase_count": 8,
        "minimum_remaining_work_phase_count": 0,
        "replacement_work_phase_required_if_non_work": False,
        "failure_type": "resource_insufficient",
        "failure_summary": "铁料不足，当前打铁行动失败。",
        "allowed_actions": [
            {
                "action_id": "work_blacksmith",
                "name": "打铁",
                "location_id": "blacksmith",
                "target_id": None,
                "tags": ["work"],
            },
            {
                "action_id": "idle",
                "name": "等待",
                "location_id": None,
                "target_id": None,
                "tags": ["idle"],
            },
        ],
    }


def _valid_revision() -> dict:
    revised_plan = [
        _plan_item(hour, "work_blacksmith", "work", "blacksmith", "重估剩余打铁安排")
        for hour in [8, 14]
    ]
    return {
        "ok": True,
        "npc_id": "blacksmith_01",
        "revised_plan": revised_plan,
        "immediate_action": copy.deepcopy(revised_plan[0]),
        "summary": "只重新安排指定时段。",
        "debug_reason": "仅覆盖指定小时。",
    }


def main() -> None:
    payload = _payload()
    adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeRevisionResponse(_valid_revision()),
    ) as fake_post:
        result = adapter.generate("revise_plan", payload)
    assert result.ok
    revision = PlanRevisionResponse(**result.content)
    assert [item.hour for item in revision.revised_plan] == [8, 14]
    assert revision.immediate_action is not None

    request_body = fake_post.call_args.kwargs["json"]
    system_prompt = request_body["messages"][0]["content"]
    assert "max_tokens" not in request_body
    assert request_body["thinking"] == {"type": "disabled"}
    assert adapter.get_runtime_config_snapshot()["client_output_token_limit_applied"] is False
    for fragment in [
        "revision_scope` 固定为 `selected_hours",
        "必须与请求的 `revision_hours` 完全一致",
        "不得为了输出即时行动而擅自增加当前小时",
        "原计划中其他小时由程序保留",
        "allowed_actions",
        "current_order",
        "eligible=false",
        "available_now=false",
        "required_ability=主持弥撒",
        "required_active_action_id",
        "attend_mass",
        "pray_at_chapel",
        "blocked_by_active_action_id=lead_mass",
        "不指定某一张病床、某个训练位或其他位置编号",
        "往昔·近日",
        "传达敌情",
        "日记字符串保留",
        "第 N 天 + 时间",
        "不得直接结算资源、HP、建筑、移动、伤害",
    ]:
        assert fragment in system_prompt, fragment

    retry_adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        side_effect=[
            _FakeRevisionResponse(raw_content='{"ok":true,"revised_plan":[', finish_reason="length"),
            _FakeRevisionResponse(_valid_revision()),
        ],
    ) as retry_post:
        retry_result = retry_adapter.generate("revise_plan", payload)
    assert retry_result.ok
    assert retry_post.call_count == 2
    assert "max_tokens" not in retry_post.call_args_list[0].kwargs["json"]
    assert "max_tokens" not in retry_post.call_args_list[1].kwargs["json"]
    assert "revised_plan 的小时必须与请求 revision_hours 完全一致" in retry_post.call_args_list[1].kwargs["json"]["messages"][0]["content"]
    assert retry_result.usage["attempt_count"] == 2

    app = create_app()
    app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeRevisionResponse(_valid_revision()),
    ):
        response = app.test_client().post("/npc/revise_plan", json=payload)
    assert response.status_code == 200, response.get_json()
    assert [item["hour"] for item in response.get_json()["revised_plan"]] == [8, 14]

    obsolete_payload = copy.deepcopy(payload)
    obsolete_payload["revision_scope"] = "remaining_day"
    obsolete_response = app.test_client().post("/npc/revise_plan", json=obsolete_payload)
    assert obsolete_response.status_code == 400, obsolete_response.get_json()

    missing_selected_hour_revision = _valid_revision()
    missing_selected_hour_revision["revised_plan"] = missing_selected_hour_revision["revised_plan"][:-1]
    invalid_selected_app = create_app()
    invalid_selected_app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeRevisionResponse(missing_selected_hour_revision),
    ):
        invalid_selected_response = invalid_selected_app.test_client().post(
            "/npc/revise_plan",
            json=payload,
        )
    assert invalid_selected_response.status_code == 502, invalid_selected_response.get_json()
    assert any(
        "selected_hours revised_plan" in detail
        for detail in invalid_selected_response.get_json()["details"]
    )

    future_payload = copy.deepcopy(payload)
    future_payload["revision_hours"] = [14]
    future_revision = _valid_revision()
    future_revision["revised_plan"] = [future_revision["revised_plan"][1]]
    future_revision["immediate_action"] = None
    future_app = create_app()
    future_app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeRevisionResponse(future_revision),
    ):
        future_response = future_app.test_client().post("/npc/revise_plan", json=future_payload)
    assert future_response.status_code == 200, future_response.get_json()
    assert future_response.get_json()["immediate_action"] is None

    print("verify_plan_revision_prompt: ok")


if __name__ == "__main__":
    main()
