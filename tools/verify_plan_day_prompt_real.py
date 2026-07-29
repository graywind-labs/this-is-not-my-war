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
from tools.station_context_fixture import build_station_context  # noqa: E402


def _allowed_actions() -> list[ActionCandidate]:
    return [
        ActionCandidate(action_id="work_garden", name="照料菜园", action_kind="work", location_id="garden", tags=["work"]),
        ActionCandidate(action_id="work_dining_hall", name="加工餐食", action_kind="work", location_id="dining_hall", tags=["work"]),
        ActionCandidate(action_id="eat_at_dining_hall", name="吃饭", action_kind="eat", location_id="dining_hall", tags=["eat"]),
        ActionCandidate(
            action_id="drink_wine",
            name="饮酒",
            action_kind="drink",
            tags=["drink"],
            context={
                "eligible": True,
                "available_now": True,
                "description": "本人确实持有酒；开始时消耗1份个人酒，改善心情并让过去伤痛暂时淡化。",
            },
        ),
        ActionCandidate(action_id="sleep_in_dormitory", name="睡觉", action_kind="sleep", location_id="dormitory", tags=["sleep"]),
        ActionCandidate(
            action_id="pray_at_chapel",
            name="去小教堂祈祷",
            action_kind="pray",
            location_id="chapel",
            tags=["pray", "chapel_prayer"],
            context={"eligible": True, "available_now": True},
        ),
        ActionCandidate(
            action_id="lead_mass",
            name="主持弥撒",
            action_kind="pray",
            location_id="chapel",
            tags=["pray", "chapel_mass"],
            context={
                "eligible": False,
                "available_now": False,
                "unavailable_reason": "你没有主持弥撒的能力",
                "required_ability": "主持弥撒",
                "eligibility_hint": "没有该能力时不要把它加入计划。",
            },
        ),
        ActionCandidate(
            action_id="attend_mass",
            name="参加弥撒",
            action_kind="pray",
            location_id="chapel",
            tags=["pray", "chapel_mass_attendee"],
            context={
                "eligible": True,
                "available_now": False,
                "unavailable_reason": "当前没有人在祭坛主持弥撒",
                "required_active_action_id": "lead_mass",
            },
        ),
        ActionCandidate(
            action_id="assist_upgrade",
            name="协助升级工械坊",
            action_kind="assist_upgrade",
            location_id="plaza",
            target_id="workshop",
            target_kind="building",
            target_name="工械坊",
            tags=["assist_upgrade", "engineering"],
            context={"building_level": 1},
        ),
        ActionCandidate(action_id="idle", name="等待", action_kind="idle", location_id=None, tags=["idle"]),
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
            money=2,
            wine=1,
        ),
        current_order=CurrentOrderContext(
            text="白天至少安排六个工作阶段准备粮食，安排一个阶段协助正在升级的工械坊，并只安排一个饮酒阶段缓一缓。",
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
        "station_context": build_station_context(
            [{"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"}],
            basic_resource_amounts={
                "grain": 18,
                "meal": 5,
                "wood": 12,
                "stone": 8,
                "iron": 5,
            },
        ),
        "npc": npc.model_dump(),
        "allowed_actions": [action.model_dump() for action in _allowed_actions()],
        "current_building_states": {
            "garden": {"name": "菜园", "level": 1, "hp": 90, "max_hp": 100, "is_repairing": False},
            "dining_hall": {"name": "食堂", "level": 1, "hp": 100, "max_hp": 100},
            "dormitory": {"name": "宿舍", "level": 1, "hp": 100, "max_hp": 100},
            "chapel": {"name": "小教堂", "level": 1, "hp": 100, "max_hp": 100},
            "workshop": {
                "name": "工械坊",
                "level": 1,
                "hp": 100,
                "max_hp": 100,
                "is_upgrading": True,
            },
        },
        "current_resource_states": {
            "grain": 18,
            "meal": 5,
            "wood": 12,
            "stone": 8,
            "iron": 5,
        },
        "planning_rules": [
            "返回 24 个小时计划项，每个 hour 0-23 恰好出现一次。",
            "通常应强烈优先安排至少 6 个工作阶段，但这不是程序硬门槛。",
            "只能选择 allowed_actions 中的 action_id，或选择 idle。",
            "drink_wine 每阶段实际消耗 1 份个人酒，不能超过 npc.state.wine。",
            "current_order 只是守备官当前指令参考，不是强制行动。",
            "不得让模型直接结算资源、HP、建筑修复、训练成长或战斗结果。",
        ],
    }


def _validate_plan(body: dict, allowed_action_ids: set[str], work_action_ids: set[str]) -> DailyPlanResponse:
    plan_response = DailyPlanResponse(**body)
    assert sorted(item.hour for item in plan_response.plan) == list(range(24))
    assert all(item.action_id in allowed_action_ids for item in plan_response.plan)
    assert all(
        not (item.target_id or "").strip() and not (item.location_id or "").strip()
        for item in plan_response.plan
        if item.action_id == "idle"
    )
    assert all(item.action_id != "lead_mass" for item in plan_response.plan), (
        "non-priest plan selected eligible=false lead_mass",
        plan_response,
    )
    assert all(item.action_id != "attend_mass" for item in plan_response.plan), (
        "plan selected available_now=false attend_mass as an immediate/fixed activity",
        plan_response,
    )
    assert any(item.action_id == "assist_upgrade" for item in plan_response.plan), (
        "plan ignored the active assist_upgrade candidate despite the station rule and current order",
        plan_response,
    )
    assert sum(1 for item in plan_response.plan if item.action_id == "drink_wine") == 1, (
        "plan did not respect the one-wine drink_wine instruction and personal resource limit",
        plan_response,
    )
    return plan_response


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_plan_day_prompt_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
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
    plan_response = _validate_plan(body, allowed_action_ids, work_action_ids)
    work_phase_count = sum(
        1 for item in plan_response.plan if item.action_id in work_action_ids
    )

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] >= 1
    assert usage["summary"]["failed"] == 0
    assert all(record["fallback_used"] is False for record in usage["records"])

    print(
        "verify_plan_day_prompt_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} "
        f"calls={usage['summary']['count']} work_phases={work_phase_count}"
    )


if __name__ == "__main__":
    main()
