import os
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


os.environ["LLM_PROVIDER"] = "mock"
os.environ.pop("LLM_API_KEY", None)

from backend.app import create_app  # noqa: E402
from backend.schemas import (  # noqa: E402
    ActionCandidate,
    CurrentOrderContext,
    DailyPlanRequest,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    ShortTermMemoryContext,
)
from tools.station_context_fixture import build_station_context  # noqa: E402


def _make_request() -> dict:
    game_time = GameTime(day=1, time="07:00:00", hour=7)
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="gardener_01",
            name="伊沃",
            background_job="园丁",
            personality=["沉默", "固执"],
        ),
        state=NPCStateContext(
            hp=100,
            max_hp=100,
            satiety=80,
            fatigue=20,
            current_location="garden",
            current_location_name="菜园",
            recruited=False,
        ),
        current_order=CurrentOrderContext(
            text="今天尽量多准备粮食，但别把自己累倒。",
            issued_day=1,
            issued_time="06:30:00",
            revision=1,
        ),
        short_term_memory=ShortTermMemoryContext(),
    )
    request = DailyPlanRequest(
        meta=ModelRequestMeta(
            request_id="verify_plan_day",
            call_type="plan_day",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        station_context=build_station_context([
            {"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"}
        ]),
        npc=npc,
        allowed_actions=[
            ActionCandidate(
                action_id="work_garden",
                name="照料菜园",
                location_id="garden",
                tags=["work"],
            ),
            ActionCandidate(
                action_id="eat_at_dining_hall",
                name="吃饭",
                location_id="dining_hall",
                tags=["eat"],
            ),
            ActionCandidate(
                action_id="sleep_in_dormitory",
                name="睡觉",
                location_id="dormitory",
                tags=["sleep"],
            ),
        ],
        current_resource_states={"grain": 18, "meal": 0},
        current_building_states={"garden": {"level": 1, "hp": 90}},
        planning_rules=["通常应强烈优先安排至少 6 个工作阶段，但这不是程序硬门槛。"],
    )
    return request.model_dump()


def main() -> None:
    app = create_app()
    client = app.test_client()
    response = client.post("/npc/plan_day", json=_make_request())
    assert response.status_code == 200, response.get_data(as_text=True)
    body = response.get_json()
    assert body["ok"] is True
    assert body["model_provider"] == "mock"
    assert body["model_fallback_used"] is False
    assert body["npc_id"] == "gardener_01"
    assert len(body["plan"]) == 24
    work_count = sum(1 for item in body["plan"] if item["action_id"] == "work_garden")
    assert work_count >= 6
    assert body["plan"][6]["action_id"] == "eat_at_dining_hall"
    assert body["plan"][0]["action_id"] == "sleep_in_dormitory"
    assert "with_current_order" in body["debug_reason"]
    print("verify_plan_day_endpoint: ok")


if __name__ == "__main__":
    main()
