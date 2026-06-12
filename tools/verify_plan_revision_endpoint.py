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
    CurrentOrderContext,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    PlanItem,
    PlanRevisionRequest,
    ShortTermMemoryContext,
)


def _make_request() -> dict:
    game_time = GameTime(day=1, time="10:00:00", hour=10)
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="veteran_deputy_01",
            name="艾达",
            background_job="老兵副官",
        ),
        state=NPCStateContext(
            hp=100,
            max_hp=100,
            satiety=80,
            fatigue=20,
            current_location="plaza",
            current_location_name="广场",
            recruited=True,
        ),
        current_order=CurrentOrderContext(
            text="今天优先训练和修补防线，但不要把自己耗垮。",
            issued_day=1,
            issued_time="10:00:00",
            revision=1,
        ),
        short_term_memory=ShortTermMemoryContext(),
    )
    plan = [PlanItem(hour=hour, action_kind="idle", action_id="idle") for hour in range(24)]
    request = PlanRevisionRequest(
        meta=ModelRequestMeta(
            request_id="verify_revise_plan",
            call_type="revise_plan",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        npc=npc,
        current_plan=plan,
        failed_plan_item=plan[10],
        failure_type="order_changed",
        failure_summary="守备官发布了新指令。",
        allowed_actions=[],
    )
    return request.model_dump()


def main() -> None:
    app = create_app()
    client = app.test_client()
    response = client.post("/npc/revise_plan", json=_make_request())
    assert response.status_code == 200, response.get_data(as_text=True)
    body = response.get_json()
    assert body["ok"] is True
    assert body["npc_id"] == "veteran_deputy_01"
    assert body["immediate_action"]["action_id"] == "idle"
    assert "with_current_order" in body["debug_reason"]
    print("verify_plan_revision_endpoint: ok")


if __name__ == "__main__":
    main()
