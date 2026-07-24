from pathlib import Path
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import (  # noqa: E402
    CurrentOrderContext,
    DailyReflectionResponse,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    ShortTermMemoryContext,
)
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402


class _FakeReflectionResponse:
    status_code = 200
    text = ""

    def __init__(self, content: dict) -> None:
        import json

        self._body = {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(content, ensure_ascii=False),
                    }
                }
            ],
            "usage": {
                "prompt_tokens": 512,
                "completion_tokens": 320,
            },
        }

    def json(self) -> dict:
        return self._body


def _payload() -> dict:
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="doctor_01",
            name="莉娜",
            background_job="医生",
            personality=["冷静", "厌恶无谓牺牲"],
            desires=["让伤员活下来"],
            fears=["诊所没有足够的钱和时间"],
            boundaries=["不能接受把昏迷者当成死人"],
        ),
        state=NPCStateContext(
            hp=88,
            max_hp=100,
            satiety=64,
            fatigue=79,
            current_location="dormitory",
            current_location_name="宿舍",
            recruited=False,
            skills={"医术": 82, "工程": 18},
        ),
        current_order=CurrentOrderContext(
            text="今晚先睡，醒来后优先照看伤员。",
            issued_by="guard_officer",
            issued_day=2,
            issued_time="21:20:00",
            revision=2,
        ),
        short_term_memory=ShortTermMemoryContext(
            experienced_events=[
                {
                    "event_id": "evt_heal",
                    "type": "healing_completed",
                    "summary": "莉娜结束了对布鲁诺的治疗。",
                    "importance": 80,
                }
            ],
            witnessed_events=[
                {
                    "event_id": "evt_notice",
                    "type": "plaza_notice_changed",
                    "summary": "广场公告改为今晚节省餐食。",
                    "importance": 50,
                }
            ],
        ),
        knowledge_graph={
            "by_subject": {
                "guard_officer": {
                    "impression": {
                        "value": "急迫，但还会允许医生照看伤员",
                        "confidence": 0.6,
                    }
                }
            }
        },
        location_context={"location_id": "dormitory", "people_present": ["doctor_01"]},
        plaza_context={"notice": "今晚节省餐食。"},
    )
    return {
        "meta": ModelRequestMeta(
            request_id="verify_daily_reflection_prompt",
            call_type="daily_reflection",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=2, time="22:30:00", hour=22).model_dump(),
        "station_context": build_station_context([
            {"npc_id": "doctor_01", "name": "莉娜", "identity": "医生"}
        ]),
        "npc": npc.model_dump(),
        "day_events": [
            {
                "event_id": "evt_heal",
                "type": "healing_completed",
                "summary": "莉娜结束了对布鲁诺的治疗。",
                "importance": 80,
                "memory_kind": "experienced",
            },
            {
                "event_id": "evt_notice",
                "type": "plaza_notice_changed",
                "summary": "广场公告改为今晚节省餐食。",
                "importance": 50,
                "memory_kind": "witnessed",
            },
        ],
        "existing_diary_entries": ["我不喜欢他们把勇敢说成止血布。"],
    }


def _valid_reflection() -> dict:
    return {
        "ok": True,
        "npc_id": "doctor_01",
        "day": 2,
        "diary_entry": "我今晚终于躺下时，手上还像沾着布鲁诺的体温。守备官说醒来后先照看伤员，这句话至少还像一句人话。",
        "knowledge_graph_updates": [
            {
                "subject": "guard_officer",
                "relation": "impression",
                "value": "急迫，但仍承认医生应先照看伤员",
                "confidence": 0.75,
                "subject_label": "守备官",
                "relation_label": "印象",
                "value_label": "急迫，但仍承认医生应先照看伤员",
            },
            {
                "subject": "dining_hall",
                "relation": "risk",
                "value": "餐食正在被节省，伤员恢复可能受影响",
                "confidence": 0.65,
                "subject_label": "食堂",
                "relation_label": "风险",
                "value_label": "餐食正在被节省，伤员恢复可能受影响",
            },
        ],
        "debug_reason": "区分亲历治疗和听闻公告；知识图谱为替换式键值更新，日记为增量追加。",
    }


def main() -> None:
    payload = _payload()
    adapter = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key="test_key", fallback_to_mock=False))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeReflectionResponse(_valid_reflection()),
    ) as fake_post:
        result = adapter.generate("daily_reflection", payload)
    assert result.ok
    reflection_response = DailyReflectionResponse(**result.content)
    assert reflection_response.diary_entry
    assert reflection_response.knowledge_graph_updates[0].subject == "guard_officer"
    assert "memory_summary" not in reflection_response.model_dump()
    assert reflection_response.knowledge_graph_updates[0].subject_label == "守备官"

    request_body = fake_post.call_args.kwargs["json"]
    system_prompt = request_body["messages"][0]["content"]
    required_prompt_fragments = [
        "首次睡眠总结 Prompt",
        "knowledge_graph_updates 是替换式更新",
        "subject + relation",
        "value 为当前关键信息",
        "diary_entry 是增量更新",
        "第一人称",
        "memory_kind=experienced",
        "memory_kind=witnessed",
        "current_order",
        "subject_label",
        "relation_label",
        "value_label",
        "中文玩家",
        "往昔·近日",
        "传达敌情",
        "字符串保留",
        "第 N 天 + 时间",
        "只写第一人称正文",
        "自然、直白",
        "不得决定或改写 HP、资源、建筑、移动、伤害",
    ]
    for fragment in required_prompt_fragments:
        assert fragment in system_prompt, fragment
    assert "memory_summary" not in system_prompt

    invalid_reflection = _valid_reflection()
    invalid_reflection["knowledge_graph_updates"][0]["subject_label"] = "玩家"
    app = create_app()
    app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key="test_key", fallback_to_mock=False))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeReflectionResponse(invalid_reflection),
    ):
        response = app.test_client().post("/npc/daily_reflection", json=payload)
    assert response.status_code == 502, response.get_json()
    invalid_body = response.get_json()
    assert invalid_body["error_code"] == "model_output_invalid"
    assert any("守备官" in detail for detail in invalid_body["details"])
    assert invalid_body["usage"]["success"] is False
    assert invalid_body["usage"]["exception_type"] == "SchemaValidationError"

    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeReflectionResponse(_valid_reflection()),
    ):
        valid_response = app.test_client().post("/npc/daily_reflection", json=payload)
    assert valid_response.status_code == 200, valid_response.get_json()
    valid_body = valid_response.get_json()
    assert valid_body["model_provider"] == "deepseek"
    assert valid_body["model_name"]
    assert valid_body["model_fallback_used"] is False
    assert "memory_summary" not in valid_body

    print("verify_daily_reflection_prompt: ok")


if __name__ == "__main__":
    main()
