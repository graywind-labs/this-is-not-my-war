import os
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

os.environ["LLM_PROVIDER"] = "mock"
os.environ["LLM_FALLBACK_TO_MOCK"] = "false"

from backend.app import create_app
from backend.schemas import (
    CurrentOrderContext,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    PlanItem,
    StationSceneContext,
)
from tools.station_context_fixture import build_station_context


def _payload(dialogue_goal: str, request_id: str) -> dict:
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="engineer_01",
            name="欧文",
            background_job="工程师",
            personality=["谨慎", "务实"],
        ),
        state=NPCStateContext(
            hp=100,
            max_hp=100,
            satiety=70,
            fatigue=20,
            current_location="chapel",
            current_location_name="教堂",
        ),
        current_order=CurrentOrderContext(),
    )
    station_context = StationSceneContext.model_validate(
        build_station_context(
            [{"npc_id": "engineer_01", "name": "欧文", "identity": "工程师"}]
        )
    )
    plan = [
        PlanItem(hour=hour, action_kind="idle", action_id="idle")
        for hour in range(24)
    ]
    intent_item = PlanItem(
        hour=8,
        action_kind="seek_guard_officer",
        action_id="seek_guard_officer",
        priority=80,
        reason="汇报弩床制造情况",
        dialogue_goal=dialogue_goal,
    )
    plan[8] = intent_item
    return {
        "meta": ModelRequestMeta(
            request_id=request_id,
            call_type="dialogue_intent_revalidation",
        ).model_dump(mode="json"),
        "game_time": GameTime(
            day=1,
            time="08:00:00",
            hour=8,
        ).model_dump(mode="json"),
        "station_context": station_context.model_dump(mode="json"),
        "npc": npc.model_dump(mode="json"),
        "planned_intent": {
            "created_day": 1,
            "created_time": "06:05:00",
            "source": "llm_plan_day",
            "plan_item": intent_item.model_dump(mode="json"),
        },
        "current_plan": [item.model_dump(mode="json") for item in plan],
        "allowed_actions": [],
        "current_building_states": {
            "workshop": {
                "name": "工械坊",
                "crafting_project": {
                    "target_name": "弩床",
                    "current_stage_name": "制作底座",
                    "current_stage_cost": {"wood": 1},
                },
            }
        },
        "current_resource_states": {"wood": 8, "iron": 5},
    }


def main() -> None:
    app = create_app()
    client = app.test_client()
    cases = [
        (
            "守备官，我来汇报弩床当前制造进度。",
            "verify_intent_continue",
            "continue",
        ),
        (
            "守备官，我要用旧说法汇报弩床进度。",
            "verify_intent_modify",
            "modify",
        ),
        (
            "守备官，这件事已经解决，不必再谈。",
            "verify_intent_cancel",
            "cancel_and_replan",
        ),
    ]
    for dialogue_goal, request_id, expected_decision in cases:
        response = client.post(
            "/npc/dialogue_intent_revalidation",
            json=_payload(dialogue_goal, request_id),
        )
        assert response.status_code == 200, response.get_json()
        body = response.get_json()
        assert body["ok"] is True
        assert body["decision"] == expected_decision
        if expected_decision == "modify":
            assert body["dialogue_goal"]
            assert body["dialogue_goal"] != dialogue_goal
        else:
            assert body["dialogue_goal"] == ""
    print("verify_dialogue_intent_revalidation: ok")


if __name__ == "__main__":
    main()
