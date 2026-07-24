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
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    PlanItem,
    PlanRevisionRequest,
    ShortTermMemoryContext,
)
from tools.station_context_fixture import build_station_context  # noqa: E402


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
    plan = [
        PlanItem(
            hour=hour,
            action_kind="work" if hour < 7 else "idle",
            action_id="work_garden" if hour < 7 else "idle",
            location_id="garden" if hour < 7 else None,
        )
        for hour in range(24)
    ]
    request = PlanRevisionRequest(
        meta=ModelRequestMeta(
            request_id="verify_revise_plan",
            call_type="revise_plan",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        station_context=build_station_context([
            {"npc_id": "veteran_deputy_01", "name": "艾达", "identity": "老兵副官"}
        ]),
        npc=npc,
        current_plan=plan,
        failed_plan_item=plan[10],
        revision_scope="selected_hours",
        revision_hours=[10, 14],
        failure_type="order_changed",
        failure_summary="守备官发布了新指令。",
        current_work_phase_count=7,
        minimum_work_phase_count=6,
        allowed_actions=[
            ActionCandidate(
                action_id="work_garden",
                name="照料菜园",
                location_id="garden",
                tags=["work"],
            )
        ],
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
    assert [item["hour"] for item in body["revised_plan"]] == [10, 14]
    assert body["immediate_action"]["hour"] == 10
    assert body["model_provider"] == "mock"
    assert body["model_fallback_used"] is False
    assert "with_current_order" in body["debug_reason"]

    future_only_request = _make_request()
    future_only_request["revision_hours"] = [14, 18]
    future_only_response = client.post("/npc/revise_plan", json=future_only_request)
    assert future_only_response.status_code == 200, future_only_response.get_data(as_text=True)
    assert [item["hour"] for item in future_only_response.get_json()["revised_plan"]] == [14, 18]
    assert future_only_response.get_json()["immediate_action"] is None

    for obsolete_scope in ["remaining_day", "local_changes"]:
        obsolete_request = _make_request()
        obsolete_request["revision_scope"] = obsolete_scope
        obsolete_response = client.post("/npc/revise_plan", json=obsolete_request)
        assert obsolete_response.status_code == 400, obsolete_response.get_data(as_text=True)

    unsorted_request = _make_request()
    unsorted_request["revision_hours"] = [14, 10]
    assert client.post("/npc/revise_plan", json=unsorted_request).status_code == 400

    past_request = _make_request()
    past_request["revision_hours"] = [9]
    assert client.post("/npc/revise_plan", json=past_request).status_code == 400
    print("verify_plan_revision_endpoint: ok")


if __name__ == "__main__":
    main()
