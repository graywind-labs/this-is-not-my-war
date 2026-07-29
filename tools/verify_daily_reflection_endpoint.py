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
    DailyReflectionRequest,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    ShortTermMemoryContext,
)
from tools.station_context_fixture import build_station_context  # noqa: E402


def _make_request() -> dict:
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="cook_01",
            name="布鲁诺",
            background_job="厨子",
            personality=["谨慎"],
        ),
        state=NPCStateContext(
            hp=100,
            max_hp=100,
            satiety=72,
            fatigue=80,
            current_location="dormitory",
            current_location_name="宿舍",
            recruited=False,
        ),
        current_order=CurrentOrderContext(
            text="先睡一会儿，醒来后帮忙准备餐食。",
            issued_day=1,
            issued_time="21:30:00",
            revision=1,
        ),
        short_term_memory=ShortTermMemoryContext(),
        knowledge_graph={},
    )
    request = DailyReflectionRequest(
        meta=ModelRequestMeta(
            request_id="verify_daily_reflection",
            call_type="daily_reflection",
            requires_time_slowdown=False,
        ),
        game_time=GameTime(day=1, time="22:00:00", hour=22),
        station_context=build_station_context([
            {"npc_id": "cook_01", "name": "布鲁诺", "identity": "厨子"}
        ]),
        npc=npc,
        summary_window={
            "window_key": "night_1_2100",
            "anchor_day": 1,
            "anchor_time": "21:00:00",
            "end_day": 2,
            "end_time": "21:00:00",
            "diary_label": "接到守备命令的第1天",
            "notice_basis": "守备官在公告牌向驿站众人传达“我们奉命守住此地”的守站告示",
        },
        reflection_period={
            "start": {"day": 1, "time": "06:00:00"},
            "end": {"day": 1, "time": "22:00:00"},
            "start_inclusive": True,
            "start_basis": "守站告示传达后的首个记录范围",
            "end_basis": "本次熟睡总结请求创建时的短期记忆快照",
            "snapshot_event_count": 1,
            "snapshot_witness_count": 0,
        },
        day_events=[
            {
                "event_id": "evt_verify_sleep_started",
                "type": "sleep_started",
                "summary": "布鲁诺开始在宿舍休息。",
                "importance": 40,
            }
        ],
        existing_diary_entries=[],
    )
    return request.model_dump()


def main() -> None:
    client = create_app().test_client()
    response = client.post("/npc/daily_reflection", json=_make_request())
    assert response.status_code == 200, response.get_data(as_text=True)
    body = response.get_json()
    assert body["ok"] is True
    assert body["npc_id"] == "cook_01"
    assert body["day"] == 1
    assert body["diary_entry"]
    assert "memory_summary" not in body
    assert body["knowledge_graph_updates"]
    assert body["knowledge_graph_updates"][0]["subject_label"] == "布鲁诺"
    assert body["knowledge_graph_updates"][0]["relation_label"] == "留意事项"
    assert body["knowledge_graph_updates"][0]["value_label"]
    assert "with_current_order" in body["debug_reason"]
    assert body["model_provider"] == "mock"
    assert body["model_name"] == "mock"
    assert body["model_fallback_used"] is False
    print("verify_daily_reflection_endpoint: ok")


if __name__ == "__main__":
    main()
