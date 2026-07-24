from pathlib import Path
import sys
from unittest.mock import patch


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
    NPCIdentity,
    NPCStateContext,
    ShortTermMemoryContext,
)
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402


class _FakeBattleResponse:
    status_code = 200
    text = ""

    def __init__(self, content: dict) -> None:
        import json

        self._body = {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(content, ensure_ascii=False),
                    }
                }
            ],
            "usage": {
                "prompt_tokens": 388,
                "completion_tokens": 72,
            },
        }

    def json(self) -> dict:
        return self._body


def _npc_context(recruited: bool = True, main_weapon: str = "sword_shield") -> NPCContext:
    return NPCContext(
        identity=NPCIdentity(
            npc_id="stableman_01",
            name="托马",
            background_job="马夫",
            personality=["紧张", "讲义气"],
            desires=["保住马厩", "别让同伴被抛下"],
            fears=["被当成真正士兵消耗", "马厩被烧毁"],
            boundaries=["不能接受无意义送死"],
        ),
        state=NPCStateContext(
            hp=24,
            max_hp=100,
            satiety=64,
            fatigue=46,
            current_action="combat_ready",
            current_location="plaza",
            current_location_name="广场",
            recruited=recruited,
            equipment={"main_weapon": main_weapon} if main_weapon else {},
            skills={"剑盾": 38, "骑术": 72, "养马": 82},
            stats={"strength": 6, "intelligence": 4},
        ),
        current_order=CurrentOrderContext(
            text="守住城门，但受伤时先活下来。",
            issued_by="guard_officer",
            issued_day=3,
            issued_time="17:20:00",
            revision=4,
        ),
        short_term_memory=ShortTermMemoryContext(
            experienced_events=[
                {
                    "type": "damage_taken",
                    "summary": "托马受到劫掠者造成的 76 点伤害。",
                    "importance": 90,
                }
            ],
            witnessed_events=[
                {
                    "type": "combat_started",
                    "summary": "敌军来袭：第 1 波，3 名敌人逼近驿站。",
                    "importance": 85,
                }
            ],
        ),
        long_term_memory=LongTermMemoryContext(
            knowledge_graph={"guard_officer": {"order_style": "会要求守门，但允许保命"}},
            diary=["我不是真正的士兵，但也不能把同伴独自丢在墙下。"],
        ),
        knowledge_graph={"guard_officer": {"order_style": "会要求守门，但允许保命"}},
        location_context={"location_id": "plaza", "people_present": ["stableman_01", "veteran_deputy_01"]},
        plaza_context={"notice": "守备官要求所有人留意正门。"},
    )


def _payload(allowed_decisions: list[str], npc: NPCContext | None = None) -> dict:
    npc = npc or _npc_context()
    return {
        "meta": ModelRequestMeta(
            request_id="verify_battle_judgement_prompt",
            call_type="battle_judgement",
            source="backend_test",
            requires_time_slowdown=True,
            related_event_id="evt_low_hp_verify",
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
            "damage_source": "enemy_raider_01",
            "behavior_mode": "combat",
            "combatant_decisions_allowed": "inspired" in allowed_decisions,
            "low_hp_event_id": "evt_low_hp_verify",
        },
        "battlefield_context": {
            "interaction_context": "combat",
            "active_enemy_count": 3,
            "enemy_roster": [{"enemy_id": "enemy_raider_01", "name": "劫掠者", "hp": 40, "max_hp": 40}],
            "friendly_roster": [{"npc_id": "stableman_01", "name": "托马", "unit_type_label": "近战步兵"}],
            "station_noncombatants": [{"npc_id": "cook_01", "name": "布鲁诺", "behavior_mode": "avoid_combat"}],
            "target_npc": {"npc_id": "stableman_01", "behavior_mode": "combat", "hp": 24, "max_hp": 100},
        },
        "allowed_decisions": allowed_decisions,
    }


def _valid_response(**overrides: object) -> dict:
    response = {
        "ok": True,
        "npc_id": "stableman_01",
        "decision": "continue_fighting",
        "emotion": "tense",
        "morale_delta_intent": 0,
        "should_start_escape": False,
        "debug_reason": "参照亲历受伤、battlefield_context、current_order 和 allowed_decisions。",
    }
    response.update(overrides)
    return response


def main() -> None:
    payload = _payload(["continue_fighting", "escape_station", "inspired"])
    adapter = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key="test_key", fallback_to_mock=False))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeBattleResponse(_valid_response(decision="inspired")),
    ) as fake_post:
        result = adapter.generate("battle_judgement", payload)
    assert result.ok
    BattleJudgementResponse(**result.content)
    assert result.content["decision"] == "inspired"

    request_body = fake_post.call_args.kwargs["json"]
    system_prompt = request_body["messages"][0]["content"]
    required_prompt_fragments = [
        "低血量自身心理判定 Prompt",
        "allowed_decisions",
        "battlefield_context",
        "experienced_events",
        "witnessed_events",
        "npc.long_term_memory",
        "diary",
        "current_order",
        "不能把它当成强制参战",
        "只能选择继续避战或逃离驿站",
        "往昔·近日",
        "传达敌情",
        "日记字符串保留",
        "第 N 天 + 时间",
        "should_start_escape",
        "不得决定资源、HP、建筑、移动、伤害",
    ]
    for fragment in required_prompt_fragments:
        assert fragment in system_prompt, fragment
    assert "玩家" not in result.content["debug_reason"]

    avoid_payload = _payload(
        ["avoid_battle", "escape_station"],
        _npc_context(recruited=False, main_weapon=""),
    )
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeBattleResponse(_valid_response(
            decision="avoid_battle",
            debug_reason="非战斗人员继续避战。",
        )),
    ):
        avoid_result = adapter.generate("battle_judgement", avoid_payload)
    assert avoid_result.ok
    assert BattleJudgementResponse(**avoid_result.content).decision == "avoid_battle"

    invalid_payload = _payload(["avoid_battle", "escape_station"], _npc_context(recruited=False, main_weapon=""))
    app = create_app()
    app.config["MODEL_ADAPTER"] = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key="test_key", fallback_to_mock=False))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeBattleResponse(_valid_response(decision="inspired")),
    ):
        response = app.test_client().post("/npc/battle_judgement", json=invalid_payload)
    assert response.status_code == 502, response.get_json()
    body = response.get_json()
    assert body["error_code"] == "model_output_invalid"
    assert any("inspired" in detail for detail in body["details"])
    assert body["usage"]["success"] is False
    assert body["usage"]["exception_type"] == "SchemaValidationError"

    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeBattleResponse(_valid_response(
            decision="escape_station",
            should_start_escape=False,
        )),
    ):
        response = app.test_client().post("/npc/battle_judgement", json=payload)
    assert response.status_code == 502, response.get_json()
    body = response.get_json()
    assert any("should_start_escape" in detail for detail in body["details"])

    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeBattleResponse(_valid_response(decision="inspired")),
    ):
        valid_route_response = app.test_client().post("/npc/battle_judgement", json=payload)
    assert valid_route_response.status_code == 200, valid_route_response.get_json()
    valid_route_body = valid_route_response.get_json()
    assert valid_route_body["model_provider"] == "deepseek"
    assert valid_route_body["model_name"]
    assert valid_route_body["model_fallback_used"] is False

    print("verify_battle_judgement_prompt: ok")


if __name__ == "__main__":
    main()
