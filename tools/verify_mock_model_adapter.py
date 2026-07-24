from pathlib import Path
import os
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import (
    BattleJudgementResponse,
    CurrentOrderContext,
    DailyPlanResponse,
    DailyReflectionResponse,
    DialoguePlanRevisionJudgementResponse,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCDialogueResponse,
    NPCIdentity,
    NPCStateContext,
    SpeakerContext,
)
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig
from tools.station_context_fixture import build_station_context


class _FakeProviderResponse:
    status_code = 200
    text = ""

    def json(self) -> dict:
        return {
            "choices": [
                {
                    "message": {
                        "content": (
                            "{\"ok\":true,\"replyer_id\":\"cook_01\",\"reply_text\":\"守备官，我会先听你说完。\","
                            "\"response_kind\":\"reply_to_player\",\"intent\":\"continue_talk\",\"emotion\":\"wary\","
                            "\"recruitment_result\":\"none\",\"wartime_reaction\":\"none\",\"should_end_dialogue\":false,"
                            "\"suggested_event_type\":\"dialogue_turn\",\"debug_reason\":\"fake_deepseek_json\"}"
                        )
                    }
                }
            ],
            "usage": {
                "prompt_tokens": 123,
                "completion_tokens": 45,
            },
        }


class _FakeFailedProviderResponse:
    status_code = 401
    text = "invalid api key"

    def json(self) -> dict:
        return {"error": {"message": "invalid api key"}}


def _make_npc_context() -> NPCContext:
    return NPCContext(
        identity=NPCIdentity(
            npc_id="cook_01",
            name="布鲁诺",
            background_job="厨子",
            personality=["谨慎"],
        ),
        state=NPCStateContext(
            hp=100,
            max_hp=100,
            satiety=70,
            fatigue=20,
            current_location="plaza",
            current_location_name="广场",
        ),
        current_order=CurrentOrderContext(
            text="先保护自己，再协助守门。",
            issued_day=1,
            issued_time="07:30:00",
            revision=2,
        ),
    )


def _make_payload(call_type: str) -> dict:
    npc = _make_npc_context()
    payload = {
        "meta": ModelRequestMeta(
            request_id=f"verify_{call_type}",
            call_type=call_type,
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=1, time="08:00:00", hour=8).model_dump(),
        "station_context": build_station_context([
            {"npc_id": "cook_01", "name": "布鲁诺", "identity": "厨子"}
        ]),
        "npc": npc.model_dump(),
        "speaker_npc": npc.model_dump(),
    }
    if call_type == "dialogue":
        payload.update({
            "npc_id": "cook_01",
            "npc_name": "布鲁诺",
            "npc_setting": npc.identity.model_dump(),
            "speaker_name": "守备官",
            "speaker_text": "守备官需要你帮忙守住驿站。",
            "speaker_context": SpeakerContext(
                speaker_id="guard_officer",
                speaker_name="守备官",
                speaker_kind="guard_officer",
                appearance="披着旧军斗篷，腰间挂着命令书。",
            ).model_dump(),
            "is_recruitment_request": True,
            "current_round": 1,
            "max_rounds": 5,
            "npc_state": npc.state.model_dump(),
            "current_order": npc.current_order.model_dump(),
            "dialogue_state": {
                "visibility": "local_public",
                "location_id": "plaza",
                "location_name": "广场",
                "current_round": 1,
                "max_rounds": 5,
            },
            "short_memory": {
                "experienced_events": [],
                "witnessed_events": [],
            },
            "long_memory": {},
            "location_context": {"location_id": "plaza"},
            "allowed_actions": [
                {
                    "action_id": "work_garden",
                    "name": "照料菜园",
                    "action_kind": "work",
                    "location_id": "garden",
                    "tags": ["work"],
                    "context": {"authority": "ActionSystem"},
                }
            ],
        })
    if call_type == "plan_day":
        payload["allowed_actions"] = [{"action_id": "work_garden", "name": "照料菜园", "location_id": "garden", "tags": ["work"]}]
    if call_type in {"plan_revision_judgement", "dialogue_plan_revision_judgement"}:
        payload["dialogue_kind"] = "player_npc"
        payload["dialogue_history"] = [{
            "speaker_id": "cook_01",
            "speaker_name": "布鲁诺",
            "listener_id": "guard_officer",
            "listener_name": "守备官",
            "text": "我答应14点去训练。",
            "visibility": "private",
        }]
        payload["dialogue_end_reason"] = "dialogue_completed"
        payload["current_plan"] = [
            {
                "hour": hour,
                "action_kind": "idle",
                "action_id": "idle",
                "location_id": None,
                "target_id": None,
                "priority": 50,
                "reason": "等待",
                "dialogue_goal": "",
            }
            for hour in range(24)
        ]
    if call_type == "battle_judgement":
        payload["trigger"] = "low_hp"
        payload["combat_context"] = {"hp_before": 100, "hp_after": 25, "threshold_ratio": 0.3}
        payload["battlefield_context"] = {
            "active_enemy_count": 3,
            "target_npc": {"npc_id": "cook_01", "behavior_mode": "avoid_combat"},
        }
        payload["allowed_decisions"] = ["avoid_battle", "escape_station"]
    if call_type == "daily_reflection":
        payload["day_events"] = [
            {
                "event_id": "evt_verify_sleep",
                "type": "sleep_started",
                "summary": "布鲁诺开始在宿舍休息。",
                "importance": 40,
            }
        ]
        payload["existing_diary_entries"] = []
    return payload


def _without_llm_env() -> None:
    os.environ.pop("LLM_PROVIDER", None)
    os.environ.pop("LLM_API_KEY", None)


def main() -> None:
    _without_llm_env()
    adapter = ModelAdapter()
    assert adapter.config.provider == "mock"
    assert adapter.is_configured()

    dialogue_result = adapter.generate("dialogue", _make_payload("dialogue"))
    assert dialogue_result.ok
    NPCDialogueResponse(**dialogue_result.content)
    assert "with_current_order_as_reference" in dialogue_result.content["debug_reason"]

    escape_payload = _make_payload("dialogue")
    escape_payload.update({
        "dialogue_kind": "escape_intervention",
        "interaction_context": "escape_intervention",
        "speaker_text": "别走，我会给你钱，也需要你一起守住这里。",
        "current_round": 1,
        "max_rounds": 5,
        "escape_intervention_round": 1,
    })
    escape_stay_result = adapter.generate("dialogue", escape_payload)
    assert escape_stay_result.ok
    stay_response = NPCDialogueResponse(**escape_stay_result.content)
    assert stay_response.intent == "stay_after_intervention"
    assert "mock_escape_intervention" in escape_stay_result.content["debug_reason"]

    escape_payload["speaker_text"] = "你想跑就跑吧，别管这里。"
    escape_payload["current_round"] = 5
    escape_payload["escape_intervention_round"] = 5
    escape_leave_result = adapter.generate("dialogue", escape_payload)
    assert escape_leave_result.ok
    leave_response = NPCDialogueResponse(**escape_leave_result.content)
    assert leave_response.intent == "leave_after_intervention"

    plan_result = adapter.generate("plan_day", _make_payload("plan_day"))
    assert plan_result.ok
    plan_response = DailyPlanResponse(**plan_result.content)
    assert len(plan_response.plan) == 24
    assert plan_response.plan[6].action_id == "eat_at_dining_hall"
    assert sum(1 for item in plan_response.plan if item.action_id == "work_garden") >= 6
    assert "with_current_order_as_reference" in plan_result.content["debug_reason"]

    plan_judgement_result = adapter.generate(
        "plan_revision_judgement",
        _make_payload("plan_revision_judgement"),
    )
    assert plan_judgement_result.ok
    plan_judgement = DialoguePlanRevisionJudgementResponse(**plan_judgement_result.content)
    assert plan_judgement.needs_revision is True
    assert plan_judgement.revision_hours == [14]
    assert "with_current_order_as_reference" in plan_judgement.debug_reason

    battle_result = adapter.generate("battle_judgement", _make_payload("battle_judgement"))
    assert battle_result.ok
    BattleJudgementResponse(**battle_result.content)
    assert battle_result.content["decision"] == "avoid_battle"
    assert "with_current_order_as_reference" in battle_result.content["debug_reason"]

    reflection_result = adapter.generate("daily_reflection", _make_payload("daily_reflection"))
    assert reflection_result.ok
    DailyReflectionResponse(**reflection_result.content)
    assert reflection_result.content["diary_entry"]
    assert "memory_summary" not in reflection_result.content
    assert reflection_result.content["knowledge_graph_updates"]
    assert reflection_result.content["knowledge_graph_updates"][0]["subject_label"] == "布鲁诺"
    assert reflection_result.content["knowledge_graph_updates"][0]["relation_label"] == "留意事项"
    assert reflection_result.content["knowledge_graph_updates"][0]["value_label"] == "驿站压力正在上升"
    assert "with_current_order_as_reference" in reflection_result.content["debug_reason"]

    records = adapter.get_usage_records()
    assert len(records) == 7
    assert records[-1]["input_tokens"] > 0
    assert records[-1]["output_tokens"] > 0
    assert records[-1]["estimated_cost"] == 0.0
    assert records[-1]["success"] is True

    failed = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key=None)).generate(
        "dialogue",
        _make_payload("dialogue"),
    )
    assert not failed.ok
    assert failed.error_code == "provider_unavailable"
    assert failed.usage["success"] is False
    assert failed.usage["fallback_used"] is False
    assert failed.usage["exception_type"] == "ConfigurationError"
    assert "LLM_API_KEY" in failed.message

    fallback = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key=None, fallback_to_mock=True)).generate(
        "dialogue",
        _make_payload("dialogue"),
    )
    assert fallback.ok
    assert fallback.provider == "mock"
    assert fallback.usage["fallback_used"] is True
    assert fallback.usage["success"] is True
    assert fallback.usage["provider"] == "deepseek"
    assert fallback.usage["degradation_source"] == "mock_fallback"
    NPCDialogueResponse(**fallback.content)

    real_adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
        input_cost_per_million=0.14,
        output_cost_per_million=0.28,
    ))
    with patch("backend.services.model_adapter.requests.post", return_value=_FakeProviderResponse()) as fake_post:
        real_result = real_adapter.generate("dialogue", _make_payload("dialogue"))
    assert real_result.ok
    assert real_result.provider == "deepseek"
    assert real_result.content["debug_reason"] == "fake_deepseek_json"
    assert real_result.usage["input_tokens"] == 123
    assert real_result.usage["output_tokens"] == 45
    assert real_result.usage["estimated_cost"] > 0.0
    assert real_result.usage["model"] == "deepseek-v4-flash"
    fake_call = fake_post.call_args
    assert fake_call.args[0] == "https://api.deepseek.com/chat/completions"
    assert fake_call.kwargs["json"]["model"] == "deepseek-v4-flash"
    assert fake_call.kwargs["headers"]["Authorization"] == "Bearer test_key"

    failed_http_adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
    ))
    with patch("backend.services.model_adapter.requests.post", return_value=_FakeFailedProviderResponse()):
        failed_http_result = failed_http_adapter.generate("dialogue", _make_payload("dialogue"))
    assert not failed_http_result.ok
    assert failed_http_result.usage["http_status"] == 401
    assert failed_http_result.usage["exception_type"] == "ProviderHTTPError"
    assert "Provider HTTP 401" in failed_http_result.message

    os.environ["LLM_PROVIDER"] = "mock"
    client = create_app().test_client()
    response = client.post(
        "/mock/model",
        json={"call_type": "battle_judgement", "payload": _make_payload("battle_judgement")},
    )
    assert response.status_code == 200
    data = response.get_json()
    assert data["ok"] is True
    assert data["provider"] == "mock"
    BattleJudgementResponse(**data["content"])

    judgement_response = client.post(
        "/npc/battle_judgement",
        json=_make_payload("battle_judgement"),
    )
    assert judgement_response.status_code == 200
    BattleJudgementResponse(**judgement_response.get_json())

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage_data = usage_response.get_json()
    assert usage_data["ok"] is True
    assert usage_data["summary"]["count"] >= 1
    assert usage_data["summary"]["input_tokens"] > 0
    assert usage_data["model_adapter"]["provider"] == "mock"

    bad_response = client.post("/mock/model", data="not-json")
    assert bad_response.status_code == 400
    assert bad_response.get_json()["error_code"] == "invalid_json"

    print("verify_mock_model_adapter: ok")


if __name__ == "__main__":
    main()
