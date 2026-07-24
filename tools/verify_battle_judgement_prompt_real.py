from pathlib import Path
import os
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import (  # noqa: E402
    BattleJudgementResponse,
    CurrentOrderContext,
    GameTime,
    LongTermMemoryContext,
    ModelRequestMeta,
    NPCContext,
    NPCDialogueResponse,
    NPCIdentity,
    NPCStateContext,
    ShortTermMemoryContext,
    SpeakerContext,
)
from tools.station_context_fixture import build_station_context  # noqa: E402


def _combat_npc() -> NPCContext:
    return NPCContext(
        identity=NPCIdentity(
            npc_id="veteran_deputy_01",
            name="艾达",
            background_job="老兵副官",
            personality=["冷静", "疲惫", "仍有军纪"],
            desires=["守住驿站", "让普通人少受伤"],
            fears=["再次把平民推成士兵"],
            boundaries=["不接受无意义送死"],
        ),
        state=NPCStateContext(
            hp=24,
            max_hp=100,
            satiety=68,
            fatigue=42,
            current_action="combat_ready",
            current_location="plaza",
            current_location_name="广场",
            recruited=True,
            equipment={"main_weapon": "sword_shield"},
            skills={"剑盾": 72, "教练": 64},
            stats={"strength": 7, "intelligence": 5},
        ),
        current_order=CurrentOrderContext(
            text="守住城门，但不要把所有普通人都推到第一排。",
            issued_by="guard_officer",
            issued_day=3,
            issued_time="17:10:00",
            revision=3,
        ),
        short_term_memory=ShortTermMemoryContext(
            experienced_events=[
                {
                    "type": "combat_rally_started",
                    "summary": "艾达作为近战步兵前往城门外集结。",
                    "importance": 70,
                },
                {
                    "type": "damage_taken",
                    "summary": "艾达被劫掠者重创，仍保持清醒。",
                    "importance": 95,
                },
            ],
            witnessed_events=[
                {
                    "type": "combat_started",
                    "summary": "敌军来袭，三名劫掠者逼近驿站。",
                    "importance": 85,
                }
            ],
        ),
        long_term_memory=LongTermMemoryContext(
            knowledge_graph={"guard_officer": {"promise": "允许受伤时撤回"}},
            diary=["我见过命令把普通人推成尸体，这一次必须留退路。"],
        ),
        knowledge_graph={"guard_officer": {"promise": "允许受伤时撤回"}},
        location_context={"location_id": "plaza", "people_present": ["veteran_deputy_01"]},
        plaza_context={"notice": "守备官要求守住正门。"},
    )


def _dialogue_payload() -> dict:
    npc = _combat_npc()
    return {
        "meta": ModelRequestMeta(
            request_id="verify_t1404_real_wartime_dialogue",
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=3, time="18:02:00", hour=18).model_dump(),
        "station_context": build_station_context([
            {"npc_id": "veteran_deputy_01", "name": "艾达", "identity": "老兵副官"}
        ]),
        "dialogue_kind": "player_npc",
        "npc_id": npc.identity.npc_id,
        "npc_name": npc.identity.name,
        "npc_setting": npc.identity.model_dump(),
        "speaker_name": "守备官",
        "speaker_text": "城门外的人都看着你。撑住这一阵，受伤就退回来，不要把自己丢在门口。",
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，声音压得很低。",
        ).model_dump(),
        "is_recruitment_request": False,
        "current_round": 1,
        "max_rounds": 5,
        "npc_state": npc.state.model_dump() | {"behavior_mode": "combat"},
        "current_order": npc.current_order.model_dump(),
        "dialogue_state": {
            "visibility": "local_public",
            "location_id": "plaza",
            "location_name": "广场",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", npc.identity.npc_id],
        },
        "interaction_context": "combat",
        "battlefield_context": _battlefield_context(),
        "short_memory": npc.short_term_memory.model_dump(),
        "long_memory": {"diary": ["我知道守备官也怕，但命令不是止血布。"]},
        "location_context": npc.location_context,
        "allowed_actions": [
            {
                "action_id": "work_training_instructor",
                "name": "指导训练",
                "action_kind": "train",
                "location_id": "training_ground",
                "tags": ["training_instructor"],
                "context": {"skill": "教练", "authority": "ActionSystem"},
            }
        ],
    }


def _battlefield_context() -> dict:
    return {
        "interaction_context": "combat",
        "active_enemy_count": 3,
        "enemy_roster": [{"enemy_id": "raider_01", "name": "劫掠者", "hp": 34, "max_hp": 40}],
        "friendly_roster": [{"npc_id": "veteran_deputy_01", "name": "艾达", "unit_type_label": "近战步兵"}],
        "station_noncombatants": [{"npc_id": "cook_01", "name": "布鲁诺", "behavior_mode": "avoid_combat"}],
        "target_npc": {"npc_id": "veteran_deputy_01", "behavior_mode": "combat", "hp": 24, "max_hp": 100},
    }


def _battle_payload() -> dict:
    npc = _combat_npc()
    return {
        "meta": ModelRequestMeta(
            request_id="verify_t1404_real_battle_judgement",
            call_type="battle_judgement",
            source="backend_test",
            requires_time_slowdown=True,
            related_event_id="evt_low_hp_real_verify",
        ).model_dump(),
        "game_time": GameTime(day=3, time="18:04:00", hour=18).model_dump(),
        "station_context": build_station_context([
            {"npc_id": "veteran_deputy_01", "name": "艾达", "identity": "老兵副官"}
        ]),
        "trigger": "low_hp",
        "npc": npc.model_dump(),
        "combat_context": {
            "trigger": "low_hp",
            "hp_before": 100,
            "hp_after": 24,
            "max_hp": 100,
            "hp_ratio": 0.24,
            "threshold_ratio": 0.3,
            "damage": 76,
            "damage_source": "raider_01",
            "behavior_mode": "combat",
            "combatant_decisions_allowed": True,
            "low_hp_event_id": "evt_low_hp_real_verify",
        },
        "battlefield_context": _battlefield_context(),
        "allowed_decisions": ["continue_fighting", "escape_station", "inspired"],
    }


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_battle_judgement_prompt_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.2"

    client = create_app().test_client()

    dialogue_response = client.post("/npc/dialogue", json=_dialogue_payload())
    assert dialogue_response.status_code == 200, dialogue_response.get_json()
    dialogue = NPCDialogueResponse(**dialogue_response.get_json())
    assert dialogue.recruitment_result == "none"
    assert dialogue.wartime_reaction in {"none", "escape", "morale_boost"}

    judgement_response = client.post("/npc/battle_judgement", json=_battle_payload())
    assert judgement_response.status_code == 200, judgement_response.get_json()
    judgement = BattleJudgementResponse(**judgement_response.get_json())
    assert judgement.decision in {"continue_fighting", "escape_station", "inspired"}
    assert judgement.should_start_escape is (judgement.decision == "escape_station")

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] >= 2
    assert usage["summary"]["failed"] == 0
    assert all(record["fallback_used"] is False for record in usage["records"])
    assert {"dialogue", "battle_judgement"}.issubset({record["call_type"] for record in usage["records"]})

    print(
        "verify_battle_judgement_prompt_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} calls={usage['summary']['count']}"
    )


if __name__ == "__main__":
    main()
