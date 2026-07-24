from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.schemas import (
    BattleJudgementRequest,
    ActionCandidate,
    CurrentOrderContext,
    DailyPlanRequest,
    DailyPlanResponse,
    DailyReflectionRequest,
    DailyReflectionResponse,
    PlanRevisionJudgementRequest,
    PlanRevisionJudgementResponse,
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
    StationSceneContext,
)
from tools.station_context_fixture import build_station_context


def _make_npc_context() -> NPCContext:
    return NPCContext(
        identity=NPCIdentity(
            npc_id="cook_01",
            name="布鲁诺",
            background_job="厨子",
            personality=["谨慎"],
            speech_style="直率絮叨，常用锅和口粮作比。",
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
    station_context = StationSceneContext.model_validate(build_station_context([
        {"npc_id": "cook_01", "name": "布鲁诺", "identity": "厨子"}
    ]))

    dialogue_request = NPCDialogueRequest(
        meta=ModelRequestMeta(
            request_id="verify_dialogue",
            call_type="dialogue",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        station_context=station_context,
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
        allowed_actions=[
            ActionCandidate(
                action_id="work_dining_hall",
                name="加工餐食",
                action_kind="work",
                location_id="dining_hall",
                tags=["work"],
            )
        ],
    )
    assert dialogue_request.npc_id == "cook_01"
    assert dialogue_request.current_order.text == npc.current_order.text
    assert dialogue_request.npc_setting["speech_style"] == "直率絮叨，常用锅和口粮作比。"
    assert "signature_lines" not in dialogue_request.npc_setting
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
    assert response.invitation_result == "not_applicable"

    npc_invitation_request = dialogue_request.model_copy(update={
        "dialogue_kind": "npc_npc",
        "dialogue_phase": "invitation",
        "current_round": 0,
        "max_rounds": 0,
        "soft_round_threshold": 5,
        "soft_round_guidance": "第六轮起若无紧急或必要事项，应自然告别并结束。",
        "dialogue_state": dialogue_request.dialogue_state.model_copy(update={
            "current_round": 0,
            "max_rounds": 0,
            "soft_round_threshold": 5,
            "soft_round_guidance": "第六轮起若无紧急或必要事项，应自然告别并结束。",
        }),
    })
    npc_invitation_response = NPCDialogueResponse(
        replyer_id="cook_01",
        reply_text="好，我听你说。",
        response_kind="reply_to_npc",
        invitation_result="accept",
    )
    assert npc_invitation_request.dialogue_phase == "invitation"
    assert npc_invitation_request.max_rounds == 0
    assert npc_invitation_request.soft_round_threshold == 5
    assert npc_invitation_response.invitation_result == "accept"

    escape_dialogue_request = NPCDialogueRequest(
        meta=ModelRequestMeta(
            request_id="verify_escape_intervention",
            call_type="dialogue",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        station_context=station_context,
        dialogue_kind="escape_intervention",
        npc_id="cook_01",
        npc_name="布鲁诺",
        npc_setting=npc.identity.model_dump(),
        speaker_name="守备官",
        speaker_text="别走，我会补偿你，我们一起守住这里。",
        speaker_context=SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
        ),
        current_round=2,
        max_rounds=5,
        npc_state=npc.state.model_dump() | {"escape_intent": {"active": True, "status": "escaping"}},
        current_order=npc.current_order,
        interaction_context="escape_intervention",
        escape_intervention_round=2,
        short_memory=ShortTermMemoryContext(),
        location_context={"location_id": "plaza"},
        allowed_actions=[
            ActionCandidate(
                action_id="work_dining_hall",
                name="加工餐食",
                action_kind="work",
                location_id="dining_hall",
                tags=["work"],
            )
        ],
    )
    assert escape_dialogue_request.dialogue_kind == "escape_intervention"
    assert escape_dialogue_request.interaction_context == "escape_intervention"
    assert escape_dialogue_request.escape_intervention_round == 2
    escape_response = NPCDialogueResponse(
        replyer_id="cook_01",
        reply_text="我留下。",
        intent="stay_after_intervention",
    )
    assert escape_response.intent == "stay_after_intervention"

    plan = [PlanItem(hour=hour, action_kind="idle", action_id="idle") for hour in range(24)]
    plan_response = DailyPlanResponse(npc_id="cook_01", plan_day=1, plan=plan)
    assert len(plan_response.plan) == 24
    plan_request = DailyPlanRequest(
        meta=ModelRequestMeta(request_id="verify_plan", call_type="plan_day"),
        game_time=game_time,
        station_context=station_context,
        npc=npc,
        allowed_actions=[],
    )
    assert plan_request.npc.current_order.revision == 1

    judgement_request = PlanRevisionJudgementRequest(
        meta=ModelRequestMeta(
            request_id="verify_dialogue_plan_revision_judgement",
            call_type="plan_revision_judgement",
        ),
        game_time=game_time,
        station_context=station_context,
        npc_id="cook_01",
        npc_name="布鲁诺",
        npc=npc,
        dialogue_kind="player_npc",
        dialogue_history=[{
            "speaker_id": "guard_officer",
            "speaker_name": "守备官",
            "listener_id": "cook_01",
            "listener_name": "布鲁诺",
            "text": "下午两点改去训练。",
        }],
        current_plan=plan,
    )
    judgement_response = PlanRevisionJudgementResponse(
        npc_id="cook_01",
        needs_revision=True,
        revision_hours=[14],
    )
    assert judgement_request.npc_id == "cook_01"
    assert judgement_request.npc.identity.personality == ["谨慎"]
    assert judgement_response.revision_hours == [14]

    failed_item = plan[8]
    revision_request = PlanRevisionRequest(
        meta=ModelRequestMeta(request_id="verify_revision", call_type="revise_plan"),
        game_time=game_time,
        station_context=station_context,
        npc=npc,
        current_plan=plan,
        failed_plan_item=failed_item,
        revision_scope="selected_hours",
        revision_hours=[8, 14],
        failure_type="order_changed",
        failure_summary="守备官发布了新指令。",
        allowed_actions=[],
    )
    assert revision_request.npc.current_order.text == npc.current_order.text
    assert revision_request.revision_scope == "selected_hours"
    assert revision_request.revision_hours == [8, 14]

    battle_request = BattleJudgementRequest(
        meta=ModelRequestMeta(
            request_id="verify_battle",
            call_type="battle_judgement",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        station_context=station_context,
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
        station_context=station_context,
        npc=npc,
    )
    reflection_response = DailyReflectionResponse.model_validate({
        "ok": True,
        "npc_id": "cook_01",
        "day": 1,
        "diary_entry": "我把今天的事记在这里。",
        "memory_summary": "旧字段不应再进入响应模型。",
        "knowledge_graph_updates": [{
            "subject": "station",
            "relation": "status",
            "value": "仍在运转",
            "confidence": 0.8,
            "subject_label": "驿站",
            "relation_label": "状态",
            "value_label": "仍在运转",
        }],
    })
    assert "memory_summary" not in reflection_response.model_dump()
    assert reflection_response.knowledge_graph_updates[0].subject_label == "驿站"
    assert reflection_response.knowledge_graph_updates[0].value_label == "仍在运转"
    graph_request = KnowledgeGraphUpdateRequest(
        meta=ModelRequestMeta(request_id="verify_graph", call_type="knowledge_graph_update"),
        game_time=game_time,
        station_context=station_context,
        npc=npc,
        source_summaries=[],
    )
    proactive_request = ProactiveIntentionRequest(
        meta=ModelRequestMeta(request_id="verify_proactive", call_type="proactive_intention"),
        game_time=game_time,
        station_context=station_context,
        npc=npc,
    )
    classification_request = PlayerStrategyClassificationRequest(
        meta=ModelRequestMeta(request_id="verify_classify", call_type="player_strategy_classification"),
        game_time=game_time,
        station_context=station_context,
        npc=npc,
        guard_officer_input="守住这里。",
    )
    for request_with_npc in [battle_request, reflection_request, graph_request, proactive_request, classification_request]:
        assert request_with_npc.npc.current_order.text == npc.current_order.text

    print("verify_backend_schemas: ok")


if __name__ == "__main__":
    main()
