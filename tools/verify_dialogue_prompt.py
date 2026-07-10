from pathlib import Path
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.schemas import GameTime, ModelRequestMeta, NPCDialogueResponse, SpeakerContext
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig


class _FakeDialogueResponse:
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
                "prompt_tokens": 321,
                "completion_tokens": 67,
            },
        }

    def json(self) -> dict:
        return self._body


def _base_payload() -> dict:
    return {
        "meta": ModelRequestMeta(
            request_id="verify_dialogue_prompt",
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=3, time="18:00:00", hour=18).model_dump(),
        "dialogue_kind": "player_npc",
        "npc_id": "cook_01",
        "npc_name": "布鲁诺",
        "npc_setting": {
            "background_job": "厨子",
            "personality": ["谨慎", "嘴硬"],
            "desires": ["保住食堂", "别让普通人被当成士兵消耗"],
            "fears": ["被逼上战场"],
            "boundaries": ["不能接受无意义牺牲"],
        },
        "speaker_name": "守备官",
        "speaker_text": "守备官请求你应征，帮忙守住食堂和驿站。",
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，腰间挂着命令书。",
        ).model_dump(),
        "is_recruitment_request": True,
        "current_round": 1,
        "max_rounds": 5,
        "npc_state": {
            "hp": 100,
            "max_hp": 100,
            "satiety": 70,
            "fatigue": 25,
            "recruited": False,
            "equipment": {},
            "current_action": "work_dining_hall",
        },
        "current_order": {
            "text": "优先保证食堂运转，敌人靠近时先保护自己。",
            "issued_by": "guard_officer",
            "issued_day": 3,
            "issued_time": "08:00:00",
            "revision": 2,
        },
        "dialogue_state": {
            "visibility": "local_public",
            "location_id": "dining_hall",
            "location_name": "食堂",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", "cook_01"],
        },
        "interaction_context": "work",
        "battlefield_context": {},
        "short_memory": {
            "experienced_events": [
                {
                    "type": "work_started",
                    "summary": "布鲁诺开始在食堂加工餐食。",
                    "importance": 40,
                }
            ],
            "witnessed_events": [
                {
                    "type": "combat_started",
                    "summary": "广场上传来敌袭警报。",
                    "importance": 80,
                }
            ],
        },
        "long_memory": {"diary": ["我不想让锅铲变成刀。"]},
        "location_context": {"location_id": "dining_hall", "people_present": ["cook_01"]},
    }


def _valid_response(**overrides: object) -> dict:
    response = {
        "ok": True,
        "replyer_id": "cook_01",
        "reply_text": "守备官，我听见了。要我站出来，就别把食堂里的人当成柴火。",
        "response_kind": "reply_to_player",
        "intent": "accept_recruitment",
        "emotion": "wary",
        "recruitment_result": "accept",
        "wartime_reaction": "none",
        "should_end_dialogue": False,
        "suggested_event_type": "dialogue_turn",
        "debug_reason": "职业、人设、记忆和 current_order 共同影响应征判断。",
    }
    response.update(overrides)
    return response


def _run_real_adapter_with_fake_provider(payload: dict, fake_content: dict) -> tuple[dict, str]:
    adapter = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key="test_key", fallback_to_mock=False))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeDialogueResponse(fake_content),
    ) as fake_post:
        result = adapter.generate("dialogue", payload)
    assert result.ok
    NPCDialogueResponse(**result.content)
    request_body = fake_post.call_args.kwargs["json"]
    system_prompt = request_body["messages"][0]["content"]
    return result.content, system_prompt


def main() -> None:
    payload = _base_payload()
    content, system_prompt = _run_real_adapter_with_fake_provider(payload, _valid_response())

    required_prompt_fragments = [
        "NPC 对话 Prompt",
        "职业背景",
        "experienced_events",
        "witnessed_events",
        "current_order",
        "提出应征",
        "wartime_reaction",
        "avoid_combat",
        "escape_intervention",
        "stay_after_intervention",
        "leave_after_intervention",
        "不得决定资源、HP、建筑、移动、伤害",
    ]
    for fragment in required_prompt_fragments:
        assert fragment in system_prompt, fragment
    assert "玩家" not in content["reply_text"]
    assert content["recruitment_result"] == "accept"

    wartime_payload = _base_payload()
    wartime_payload.update({
        "is_recruitment_request": False,
        "interaction_context": "combat",
        "speaker_text": "守住门口，别让他们进来。你不是一个人。",
        "npc_state": _base_payload()["npc_state"] | {
            "recruited": True,
            "equipment": {"main_weapon": "sword_shield"},
            "behavior_mode": "combat",
        },
        "battlefield_context": {
            "active_enemy_count": 3,
            "friendly_combatants": ["veteran_deputy_01", "cook_01"],
        },
    })
    wartime_content, _ = _run_real_adapter_with_fake_provider(
        wartime_payload,
        _valid_response(
            intent="continue_talk",
            recruitment_result="none",
            wartime_reaction="morale_boost",
            debug_reason="战斗公开对话产生斗志激昂意向。",
        ),
    )
    assert wartime_content["wartime_reaction"] == "morale_boost"

    escape_payload = _base_payload()
    escape_payload.update({
        "dialogue_kind": "escape_intervention",
        "interaction_context": "escape_intervention",
        "is_recruitment_request": False,
        "speaker_text": "别走，我会补偿你，也需要你见证我们守住这里。",
        "escape_intervention_round": 2,
    })
    escape_content, _ = _run_real_adapter_with_fake_provider(
        escape_payload,
        _valid_response(
            intent="stay_after_intervention",
            recruitment_result="none",
            wartime_reaction="none",
            should_end_dialogue=True,
            debug_reason="逃离挽留选择留下。",
        ),
    )
    assert escape_content["intent"] == "stay_after_intervention"
    assert escape_content["should_end_dialogue"] is True

    print("verify_dialogue_prompt: ok")


if __name__ == "__main__":
    main()
