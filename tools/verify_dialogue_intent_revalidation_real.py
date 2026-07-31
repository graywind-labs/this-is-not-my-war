import os
from pathlib import Path
import sys

import requests


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

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


BASE_URL = os.getenv("BACKEND_BASE_URL", "http://127.0.0.1:5000").rstrip("/")


def _payload(
    request_id: str,
    dialogue_goal: str,
    resources: dict[str, int],
    stage_name: str,
    stage_cost: dict[str, int],
) -> dict:
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="engineer_01",
            name="欧文",
            background_job="工程师",
            personality=["务实", "谨慎"],
            speech_style="先核对材料和进度，再说明需要什么。",
        ),
        state=NPCStateContext(
            hp=100,
            max_hp=100,
            satiety=75,
            fatigue=25,
            current_location="chapel",
            current_location_name="教堂",
        ),
        current_order=CurrentOrderContext(),
    )
    raw_station = build_station_context(
        [{"npc_id": "engineer_01", "name": "欧文", "identity": "工程师"}]
    )
    for reserve in raw_station.get("basic_resource_reserves", []):
        resource_id = str(reserve.get("resource_id", ""))
        if resource_id in resources:
            reserve["amount"] = resources[resource_id]
    station_context = StationSceneContext.model_validate(raw_station)
    plan = [
        PlanItem(hour=hour, action_kind="idle", action_id="idle")
        for hour in range(24)
    ]
    intent_item = PlanItem(
        hour=8,
        action_kind="seek_guard_officer",
        action_id="seek_guard_officer",
        priority=85,
        reason=(
            "汇报弩床制作进度"
            if "汇报弩床制作进度" in dialogue_goal
            else "仅在材料不足时请求调拨"
            if "如果已足就不必谈" in dialogue_goal
            else "汇报弩床制造受阻"
        ),
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
            time="08:20:00",
            hour=8,
        ).model_dump(mode="json"),
        "station_context": station_context.model_dump(mode="json"),
        "npc": npc.model_dump(mode="json"),
        "planned_intent": {
            "created_day": 1,
            "created_time": "06:10:00",
            "source": "llm_plan_day",
            "plan_item": intent_item.model_dump(mode="json"),
        },
        "current_plan": [item.model_dump(mode="json") for item in plan],
        "allowed_actions": [],
        "current_building_states": {
            "workshop": {
                "name": "工械坊",
                "level": 1,
                "hp": 100,
                "max_hp": 100,
                "crafting_project": {
                    "target_recipe_id": "craft_wall_ballista",
                    "target_item_id": "item_wall_ballista",
                    "target_name": "弩床",
                    "project_revision": 3,
                    "completed_stages": 0,
                    "total_stages": 6,
                    "current_stage_index": 1,
                    "current_stage_id": "base",
                    "current_stage_name": stage_name,
                    "current_stage_cost": stage_cost,
                    "stock_amount": 2,
                },
            }
        },
        "current_resource_states": resources,
    }


def main() -> None:
    health = requests.get(f"{BASE_URL}/health", timeout=5).json()
    adapter = health.get("model_adapter", {})
    assert health.get("ok") is True, health
    assert adapter.get("configured") is True, adapter
    assert str(adapter.get("provider", "")).lower() != "mock", adapter
    assert adapter.get("fallback_to_mock") is False, adapter

    cases = [
        (
            "t0116_real_continue",
            "守备官，我来汇报弩床制作进度：当前正在制作底座，已完成0/6阶段。",
            {"wood": 8, "iron": 5},
            "制作底座",
            {"wood": 1},
            "continue",
        ),
        (
            "t0116_real_modify",
            "守备官，弩床当前制作底座缺铁，需要调拨铁料。",
            {"wood": 5, "iron": 5},
            "制作底座",
            {"wood": 6},
            "modify",
        ),
        (
            "t0116_real_cancel",
            "守备官，如果弩床当前材料仍不足，我来请求调拨；如果已足就不必谈。",
            {"wood": 8, "iron": 5},
            "制作底座",
            {"wood": 1},
            "cancel_and_replan",
        ),
    ]
    results: list[str] = []
    for (
        request_id,
        dialogue_goal,
        resources,
        stage_name,
        stage_cost,
        expected_decision,
    ) in cases:
        response = requests.post(
            f"{BASE_URL}/npc/dialogue_intent_revalidation",
            json=_payload(
                request_id,
                dialogue_goal,
                resources,
                stage_name,
                stage_cost,
            ),
            timeout=180,
        )
        body = response.json()
        assert response.status_code == 200, body
        assert body.get("ok") is True, body
        assert body.get("model_fallback_used") is False, body
        assert str(body.get("model_provider", "")).lower() != "mock", body
        assert body.get("decision") == expected_decision, body
        if expected_decision == "modify":
            revised_goal = str(body.get("dialogue_goal", ""))
            assert revised_goal and revised_goal != dialogue_goal, body
            assert "木" in revised_goal, body
        else:
            assert body.get("dialogue_goal") == "", body
        results.append(f"{request_id}:{body['decision']}")
    print(
        "verify_dialogue_intent_revalidation_real: ok (%s)"
        % ", ".join(results)
    )


if __name__ == "__main__":
    main()
