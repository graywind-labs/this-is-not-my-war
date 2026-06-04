from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.schemas import (
    BattleJudgementRequest,
    DailyPlanResponse,
    GameTime,
    ModelRequestMeta,
    NPCContext,
    NPCDialogueRequest,
    NPCDialogueResponse,
    NPCIdentity,
    NPCStateContext,
    PlanItem,
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
        short_memory=ShortTermMemoryContext(),
        location_context={"location_id": "plaza"},
    )
    assert dialogue_request.npc_id == "cook_01"
    response = NPCDialogueResponse(
        replyer_id="cook_01",
        reply_text="守备官，我听见了。",
        recruitment_result="none",
    )
    assert response.replyer_id == "cook_01"

    plan = [PlanItem(hour=hour, action_kind="idle", action_id="idle") for hour in range(24)]
    plan_response = DailyPlanResponse(npc_id="cook_01", plan_day=1, plan=plan)
    assert len(plan_response.plan) == 24

    battle_request = BattleJudgementRequest(
        meta=ModelRequestMeta(
            request_id="verify_battle",
            call_type="battle_judgement",
            requires_time_slowdown=True,
        ),
        game_time=game_time,
        trigger="combat_started",
        npc=npc,
        allowed_decisions=["join_battle", "avoid_battle", "escape_station", "inspired"],
    )
    assert "join_battle" in battle_request.allowed_decisions

    print("verify_backend_schemas: ok")


if __name__ == "__main__":
    main()
