from pathlib import Path
import os
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import (
    BattleJudgementResponse,
    CurrentOrderContext,
    DailyPlanResponse,
    DailyReflectionResponse,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCDialogueResponse,
    NPCIdentity,
    NPCStateContext,
    SpeakerContext,
)
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig


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
        })
    if call_type == "plan_day":
        payload["allowed_actions"] = [{"action_id": "work_garden", "name": "照料菜园", "location_id": "garden", "tags": ["work"]}]
    if call_type == "battle_judgement":
        payload["allowed_decisions"] = ["join_battle", "avoid_battle", "escape_station"]
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

    plan_result = adapter.generate("plan_day", _make_payload("plan_day"))
    assert plan_result.ok
    plan_response = DailyPlanResponse(**plan_result.content)
    assert len(plan_response.plan) == 24
    assert plan_response.plan[6].action_id == "eat_at_dining_hall"
    assert sum(1 for item in plan_response.plan if item.action_id == "work_garden") >= 6
    assert "with_current_order_as_reference" in plan_result.content["debug_reason"]

    battle_result = adapter.generate("battle_judgement", _make_payload("battle_judgement"))
    assert battle_result.ok
    BattleJudgementResponse(**battle_result.content)
    assert "with_current_order_as_reference" in battle_result.content["debug_reason"]

    reflection_result = adapter.generate("daily_reflection", _make_payload("daily_reflection"))
    assert reflection_result.ok
    DailyReflectionResponse(**reflection_result.content)
    assert reflection_result.content["diary_entry"]
    assert reflection_result.content["knowledge_graph_updates"]
    assert "with_current_order_as_reference" in reflection_result.content["debug_reason"]

    records = adapter.get_usage_records()
    assert len(records) == 4
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
    assert "LLM_API_KEY" in failed.message

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

    bad_response = client.post("/mock/model", data="not-json")
    assert bad_response.status_code == 400
    assert bad_response.get_json()["error_code"] == "invalid_json"

    print("verify_mock_model_adapter: ok")


if __name__ == "__main__":
    main()
