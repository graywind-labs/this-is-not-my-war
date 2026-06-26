from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.schemas import (
    BattleJudgementRequest,
    CurrentOrderContext,
    DailyPlanRequest,
    DailyPlanResponse,
    DailyReflectionRequest,
    GameTime,
    KnowledgeGraphUpdateRequest,
    ModelRequestMeta,
    NPCContext,
    NPCDialogueRequest,
    NPCDialogueResponse,
    NPCIdentity,
    NPCStateContext,
    PlanItem,
    PlanRevisionRequest,
    PlayerStrategyClassificationRequest,
    ProactiveIntentionRequest,
    ShortTermMemoryContext,
    SpeakerContext,
)


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
            text="优先守住城门，但不要冒进。",
            issued_day=1,
            issued_time="07:30:00",
            revision=1,
        ),
    )


def main() -> None:
    game_time = GameTime(day=1, time="08:00:00", hour=8)
    npc = _make_npc_context()

    dialogue_request = NPCDialogueRequest(
        meta=ModelRequestMeta(
            request_id="verify_dialogue",
            call_type="dialogue",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        npc_id="cook_01",
        npc_name="布鲁诺",
        npc_setting=npc.identity.model_dump(),
        speaker_name="守备官",
        speaker_text="守备官需要你帮忙守住驿站。",
        speaker_context=SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，腰间挂着命令书。",
        ),
        is_recruitment_request=True,
        current_round=1,
        max_rounds=5,
        npc_state=npc.state.model_dump(),
        current_order=npc.current_order,
        interaction_context="combat",
        battlefield_context={
            "active_enemy_count": 2,
            "friendly_combatant_count": 1,
            "station_noncombatants": ["cook_01"],
        },
        short_memory=ShortTermMemoryContext(),
        location_context={"location_id": "plaza"},
    )
    assert dialogue_request.npc_id == "cook_01"
    assert dialogue_request.current_order.text == npc.current_order.text
    assert dialogue_request.interaction_context == "combat"
    assert dialogue_request.battlefield_context["active_enemy_count"] == 2
    response = NPCDialogueResponse(
        replyer_id="cook_01",
        reply_text="守备官，我听见了。",
        recruitment_result="none",
        wartime_reaction="morale_boost",
    )
    assert response.replyer_id == "cook_01"
    assert response.wartime_reaction == "morale_boost"

    plan = [PlanItem(hour=hour, action_kind="idle", action_id="idle") for hour in range(24)]
    plan_response = DailyPlanResponse(npc_id="cook_01", plan_day=1, plan=plan)
    assert len(plan_response.plan) == 24
    plan_request = DailyPlanRequest(
        meta=ModelRequestMeta(request_id="verify_plan", call_type="plan_day"),
        game_time=game_time,
        npc=npc,
        allowed_actions=[],
    )
    assert plan_request.npc.current_order.revision == 1

    failed_item = PlanItem(hour=8, action_kind="work", action_id="garden_work")
    revision_request = PlanRevisionRequest(
        meta=ModelRequestMeta(request_id="verify_revision", call_type="revise_plan"),
        game_time=game_time,
        npc=npc,
        current_plan=[failed_item],
        failed_plan_item=failed_item,
        failure_type="order_changed",
        failure_summary="守备官发布了新指令。",
        allowed_actions=[],
    )
    assert revision_request.npc.current_order.text == npc.current_order.text

    battle_request = BattleJudgementRequest(
        meta=ModelRequestMeta(
            request_id="verify_battle",
            call_type="battle_judgement",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        trigger="low_hp",
        npc=npc,
        combat_context={"hp_before": 100, "hp_after": 25, "threshold_ratio": 0.3},
        battlefield_context={"active_enemy_count": 3, "target_npc": {"behavior_mode": "avoid_combat"}},
        allowed_decisions=["avoid_battle", "escape_station"],
    )
    assert battle_request.trigger == "low_hp"
    assert battle_request.battlefield_context["active_enemy_count"] == 3
    assert "avoid_battle" in battle_request.allowed_decisions
    reflection_request = DailyReflectionRequest(
        meta=ModelRequestMeta(request_id="verify_reflection", call_type="daily_reflection"),
        game_time=game_time,
        npc=npc,
    )
    graph_request = KnowledgeGraphUpdateRequest(
        meta=ModelRequestMeta(request_id="verify_graph", call_type="knowledge_graph_update"),
        game_time=game_time,
        npc=npc,
        source_summaries=[],
    )
    proactive_request = ProactiveIntentionRequest(
        meta=ModelRequestMeta(request_id="verify_proactive", call_type="proactive_intention"),
        game_time=game_time,
        npc=npc,
    )
    classification_request = PlayerStrategyClassificationRequest(
        meta=ModelRequestMeta(request_id="verify_classify", call_type="player_strategy_classification"),
        game_time=game_time,
        npc=npc,
        guard_officer_input="守住这里。",
    )
    for request_with_npc in [battle_request, reflection_request, graph_request, proactive_request, classification_request]:
        assert request_with_npc.npc.current_order.text == npc.current_order.text

    print("verify_backend_schemas: ok")


if __name__ == "__main__":
    main()
