from pathlib import Path
import os
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
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


def _allowed_actions() -> list[ActionCandidate]:
    return [
        ActionCandidate(action_id="work_garden", name="照料菜园", location_id="garden", tags=["work"]),
        ActionCandidate(action_id="work_dining_hall", name="加工餐食", location_id="dining_hall", tags=["work"]),
        ActionCandidate(action_id="eat_at_dining_hall", name="吃饭", location_id="dining_hall", tags=["eat"]),
        ActionCandidate(action_id="sleep_in_dormitory", name="睡觉", location_id="dormitory", tags=["sleep"]),
        ActionCandidate(action_id="idle", name="等待", location_id="plaza", tags=["idle"]),
    ]


def _payload() -> dict:
    npc = NPCContext(
        identity=NPCIdentity(
            npc_id="gardener_01",
            name="伊沃",
            background_job="园丁",
            personality=["沉默", "固执", "不喜欢空话"],
            desires=["让菜园撑过围城", "证明普通人也能守住自己的活计"],
            fears=["粮食见底", "被迫拿起不熟悉的武器"],
            boundaries=["不能接受浪费粮食"],
        ),
        state=NPCStateContext(
            hp=96,
            max_hp=100,
            satiety=72,
            fatigue=28,
            current_location="garden",
            current_location_name="菜园",
            recruited=True,
            skills={"耕种": 76, "厨艺": 12, "工程": 20, "剑盾": 8},
            equipment={},
        ),
        current_order=CurrentOrderContext(
            text="白天尽量多准备粮食，傍晚听到警铃就回广场，不要逞强。",
            issued_by="guard_officer",
            issued_day=2,
            issued_time="06:30:00",
            revision=3,
        ),
        short_term_memory=ShortTermMemoryContext(),
        knowledge_graph={"guard_officer": {"order_style": "急迫但允许保命"}},
        location_context={
            "location_id": "garden",
            "workstations": [{"id": "garden_plot_01", "status": "free"}],
        },
        plaza_context={"notice": "第 3 天傍晚可能有敌袭。"},
    )
    return {
        "meta": ModelRequestMeta(
            request_id="verify_plan_day_prompt_real",
            call_type="plan_day",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=2, time="07:00:00", hour=7).model_dump(),
        "npc": npc.model_dump(),
        "allowed_actions": [action.model_dump() for action in _allowed_actions()],
        "current_building_states": {
            "garden": {"name": "菜园", "level": 1, "hp": 90, "max_hp": 100, "is_repairing": False},
            "dining_hall": {"name": "食堂", "level": 1, "hp": 100, "max_hp": 100},
            "dormitory": {"name": "宿舍", "level": 1, "hp": 100, "max_hp": 100},
        },
        "current_resource_states": {"grain": 18, "meal": 5, "money": 30},
        "planning_rules": [
            "返回 24 个小时计划项，每个 hour 0-23 恰好出现一次。",
            "计划至少包含 6 个工作阶段。",
            "只能选择 allowed_actions 中的 action_id，或选择 idle。",
            "current_order 只是守备官当前指令参考，不是强制行动。",
            "不得让模型直接结算资源、HP、建筑修复、训练成长或战斗结果。",
        ],
    }


def _validate_plan(body: dict, allowed_action_ids: set[str], work_action_ids: set[str]) -> DailyPlanResponse:
    plan_response = DailyPlanResponse(**body)
    assert sorted(item.hour for item in plan_response.plan) == list(range(24))
    assert all(item.action_id in allowed_action_ids for item in plan_response.plan)
    assert sum(1 for item in plan_response.plan if item.action_id in work_action_ids) >= 6
    return plan_response


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_plan_day_prompt_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_MAX_TOKENS"] = "2600"
    os.environ["LLM_TEMPERATURE"] = "0.2"

    payload = _payload()
    client = create_app().test_client()
    response = client.post("/npc/plan_day", json=payload)
    assert response.status_code == 200, response.get_json()
    body = response.get_json()
    allowed_action_ids = {action.action_id for action in _allowed_actions()}
    allowed_action_ids.add("idle")
    work_action_ids = {
        action.action_id
        for action in _allowed_actions()
        if any(tag in {"work", "clinic_doctor", "training_instructor"} for tag in action.tags)
    }
    _validate_plan(body, allowed_action_ids, work_action_ids)

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] >= 1
    assert usage["summary"]["failed"] == 0
    assert all(record["fallback_used"] is False for record in usage["records"])

    print(
        "verify_plan_day_prompt_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} calls={usage['summary']['count']}"
    )


if __name__ == "__main__":
    main()
