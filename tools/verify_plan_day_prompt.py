from pathlib import Path
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.schemas import (  # noqa: E402
    ActionCandidate,
    CurrentOrderContext,
    DailyPlanResponse,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    ShortTermMemoryContext,
)
from backend.app import create_app  # noqa: E402
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402


class _FakePlanResponse:
    status_code = 200
    text = ""

    def __init__(self, content: dict | None = None, raw_content: str = "", finish_reason: str = "stop") -> None:
        import json

        content_text = raw_content if raw_content else json.dumps(content, ensure_ascii=False)
        self._body = {
            "choices": [
                {
                    "finish_reason": finish_reason,
                    "message": {
                        "content": content_text,
                    }
                }
            ],
            "usage": {
                "prompt_tokens": 456,
                "completion_tokens": 512,
            },
        }

    def json(self) -> dict:
        return self._body


def _allowed_actions() -> list[ActionCandidate]:
    return [
        ActionCandidate(action_id="work_garden", name="照料菜园", location_id="garden", tags=["work"]),
        ActionCandidate(action_id="eat_at_dining_hall", name="吃饭", location_id="dining_hall", tags=["eat"]),
        ActionCandidate(action_id="sleep_in_dormitory", name="睡觉", location_id="dormitory", tags=["sleep"]),
        ActionCandidate(action_id="idle", name="等待", location_id=None, tags=["idle"]),
    ]


def _base_payload() -> dict:
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="gardener_01",
            name="伊沃",
            background_job="园丁",
            personality=["沉默", "固执"],
            desires=["让菜园撑过围城"],
            fears=["粮食见底"],
            boundaries=["不接受把伤员赶去送死"],
        ),
        state=NPCStateContext(
            hp=100,
            max_hp=100,
            satiety=78,
            fatigue=22,
            current_location="garden",
            current_location_name="菜园",
            recruited=True,
            skills={"耕种": 72, "厨艺": 18, "工程": 24},
        ),
        current_order=CurrentOrderContext(
            text="白天优先准备粮食，傍晚去广场听警铃。",
            issued_by="guard_officer",
            issued_day=2,
            issued_time="06:30:00",
            revision=3,
        ),
        short_term_memory=ShortTermMemoryContext(),
        knowledge_graph={"guard_officer": {"trust": "谨慎信任"}},
        location_context={"location_id": "garden", "workstations": [{"id": "garden_plot_01", "status": "free"}]},
    )
    return {
        "meta": ModelRequestMeta(
            request_id="verify_plan_day_prompt",
            call_type="plan_day",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=2, time="07:00:00", hour=7).model_dump(),
        "station_context": build_station_context([
            {"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"}
        ]),
        "npc": npc.model_dump(),
        "allowed_actions": [action.model_dump() for action in _allowed_actions()],
        "current_building_states": {"garden": {"level": 1, "hp": 90}, "dormitory": {"level": 1, "hp": 100}},
        "current_resource_states": {"grain": 18, "meal": 4},
        "planning_rules": [
            "返回 24 个小时计划项，每个 hour 0-23 恰好出现一次。",
            "计划至少包含 6 个工作阶段。",
            "只能选择 allowed_actions 中的 action_id，或选择 idle。",
            "current_order 只是守备官当前指令参考，不是强制行动。",
        ],
    }


def _valid_plan() -> dict:
    plan = []
    for hour in range(24):
        if hour <= 5 or hour >= 22:
            item = {
                "hour": hour,
                "action_kind": "sleep",
                "action_id": "sleep_in_dormitory",
                "location_id": "dormitory",
                "target_id": None,
                "priority": 70,
                "reason": "夜间休息以恢复疲劳。",
            }
        elif hour in {6, 12, 18}:
            item = {
                "hour": hour,
                "action_kind": "eat",
                "action_id": "eat_at_dining_hall",
                "location_id": "dining_hall",
                "target_id": None,
                "priority": 80,
                "reason": "按时吃饭维持体力。",
            }
        elif 8 <= hour <= 14 and hour != 12:
            item = {
                "hour": hour,
                "action_kind": "work",
                "action_id": "work_garden",
                "location_id": "garden",
                "target_id": None,
                "priority": 75,
                "reason": "响应守备官指令，优先准备粮食。",
            }
        else:
            item = {
                "hour": hour,
                "action_kind": "idle",
                "action_id": "idle",
                "location_id": None,
                "target_id": None,
                "priority": 40,
                "reason": "留在广场观察情况。",
            }
        plan.append(item)
    return {
        "ok": True,
        "npc_id": "gardener_01",
        "plan_day": 2,
        "plan": plan,
        "summary": "白天集中照料菜园，兼顾吃饭和休息，并把守备官指令作为参考。",
        "debug_reason": "使用 allowed_actions、24 阶段、至少 6 个工作阶段和 current_order 约束。",
    }


def main() -> None:
    payload = _base_payload()
    adapter = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key="test_key", fallback_to_mock=False))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakePlanResponse(_valid_plan()),
    ) as fake_post:
        result = adapter.generate("plan_day", payload)
    assert result.ok
    plan_response = DailyPlanResponse(**result.content)
    assert len(plan_response.plan) == 24
    assert sum(1 for item in plan_response.plan if item.action_id == "work_garden") >= 6

    request_body = fake_post.call_args.kwargs["json"]
    system_prompt = request_body["messages"][0]["content"]
    assert "max_tokens" not in request_body
    assert request_body["thinking"] == {"type": "disabled"}
    assert request_body["temperature"] == 0.4
    assert result.usage["finish_reason"] == "stop"
    assert result.usage["thinking_mode"] == "disabled"
    runtime_snapshot = adapter.get_runtime_config_snapshot()
    assert runtime_snapshot["client_output_token_limit_applied"] is False
    assert runtime_snapshot["thinking_mode"] == "disabled"
    required_prompt_fragments = [
        "每日计划 Prompt",
        "24 个阶段",
        "至少 6 个阶段",
        "allowed_actions",
        "action_id 只能使用",
        "current_order",
        "不能绕过 allowed_actions",
        "eligible=false",
        "available_now=false",
        "required_ability=主持弥撒",
        "required_active_action_id",
        "attend_mass",
        "pray_at_chapel",
        "主持弥撒期间普通祈祷不可进行",
        "不指定病床、训练位、祈祷席等位置编号",
        "往昔·近日",
        "传达敌情",
        "日记字符串保留",
        "第 N 天 + 时间",
        "不得决定资源、HP、建筑、移动、伤害等权威结算",
    ]
    for fragment in required_prompt_fragments:
        assert fragment in system_prompt, fragment
    assert "玩家" not in result.content["summary"]

    invalid_plan = _valid_plan()
    invalid_plan["plan"][8]["action_id"] = "invented_action"
    app = create_app()
    app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key="test_key", fallback_to_mock=False))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakePlanResponse(invalid_plan),
    ):
        response = app.test_client().post("/npc/plan_day", json=payload)
    assert response.status_code == 502, response.get_json()
    invalid_body = response.get_json()
    assert invalid_body["error_code"] == "model_output_invalid"
    assert any("invented_action" in detail for detail in invalid_body["details"])
    assert invalid_body["usage"]["success"] is False
    assert invalid_body["usage"]["exception_type"] == "SchemaValidationError"

    retry_adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        side_effect=[
            _FakePlanResponse(raw_content='{"ok":true,"plan":[', finish_reason="length"),
            _FakePlanResponse(_valid_plan()),
        ],
    ) as retry_post:
        retry_result = retry_adapter.generate("plan_day", payload)
    assert retry_result.ok
    assert retry_post.call_count == 2
    assert "max_tokens" not in retry_post.call_args_list[0].kwargs["json"]
    assert "max_tokens" not in retry_post.call_args_list[1].kwargs["json"]
    assert retry_result.usage["attempt_count"] == 2

    print("verify_plan_day_prompt: ok")


if __name__ == "__main__":
    main()
