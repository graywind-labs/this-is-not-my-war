from pathlib import Path
import copy
import os
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import (
    EscapeInterventionDialogueResponse,
    GameTime,
    ModelRequestMeta,
    NPCNPCDialogueResponse,
    PlayerNPCDialogueResponse,
    SpeakerContext,
)
from tools.station_context_fixture import build_station_context


def _contract_body(body: dict) -> dict:
    return {key: value for key, value in body.items() if not key.startswith("model_")}


def _base_payload(text: str, recruitment: bool = False) -> dict:
    return {
        "meta": ModelRequestMeta(
            request_id="verify_dialogue_endpoint",
            call_type="dialogue",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=1, time="08:00:00", hour=8).model_dump(),
        "station_context": build_station_context([
            {"npc_id": "cook_01", "name": "布鲁诺", "identity": "厨子"}
        ]),
        "dialogue_kind": "player_npc",
        "npc_id": "cook_01",
        "npc_name": "布鲁诺",
        "npc_setting": {
            "background_job": "厨子",
            "personality": ["谨慎"],
            "desires": ["保住食堂"],
            "fears": ["被当成士兵消耗"],
        },
        "speaker_name": "守备官",
        "speaker_text": text,
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，腰间挂着命令书。",
        ).model_dump(),
        "is_recruitment_request": recruitment,
        "current_round": 1,
        "max_rounds": 5,
        "npc_state": {
            "hp": 100,
            "max_hp": 100,
            "satiety": 70,
            "fatigue": 20,
            "money": 1,
            "recruited": False,
            "equipment": {},
        },
        "activity_truth": {
            "action_id": "work_dining_hall",
            "is_training": False,
        },
        "equipment_truth": {
            "main_weapon": None,
            "mount": None,
            "has_trainable_equipment": False,
        },
        "training_truth": {
            "eligible": False,
            "blocker": "no_trainable_equipment",
        },
        "current_order": {
            "text": "优先保证食堂运转。",
            "issued_by": "guard_officer",
            "issued_day": 1,
            "issued_time": "07:30:00",
            "revision": 1,
        },
        "dialogue_state": {
            "visibility": "local_public",
            "location_id": "dining_hall",
            "location_name": "食堂",
            "current_round": 1,
            "max_rounds": 5,
            "participants": ["guard_officer", "cook_01"],
        },
        "short_memory": {
            "experienced_events": [],
            "witnessed_events": [],
        },
        "long_memory": {
            "knowledge_graph": {},
            "diary": [],
        },
        "location_context": {
            "location_id": "dining_hall",
            "people_present": ["cook_01"],
            "workstations": [{"id": "kitchen_table", "status": "occupied", "occupied_by": "cook_01"}],
        },
        "allowed_actions": [
            {
                "action_id": "work_dining_hall",
                "name": "加工餐食",
                "action_kind": "work",
                "location_id": "dining_hall",
                "tags": ["work"],
                "context": {"skill": "厨艺", "authority": "ActionSystem"},
            }
        ],
    }


def main() -> None:
    os.environ["LLM_PROVIDER"] = "mock"
    os.environ.pop("LLM_API_KEY", None)

    client = create_app().test_client()

    accept_response = client.post(
        "/npc/dialogue",
        json=_base_payload("守备官请求你应征，帮忙守住食堂和驿站。", recruitment=True),
    )
    assert accept_response.status_code == 200
    accept_data = accept_response.get_json()
    parsed_accept = PlayerNPCDialogueResponse(**_contract_body(accept_data))
    assert parsed_accept.replyer_id == "cook_01"
    assert parsed_accept.recruitment_result == "accept"
    assert parsed_accept.response_kind == "reply_to_player"
    assert "intent" not in accept_data
    assert "should_end_dialogue" not in accept_data

    reject_response = client.post(
        "/npc/dialogue",
        json=_base_payload("守备官要求你立刻拿起武器。", recruitment=True),
    )
    assert reject_response.status_code == 200
    parsed_reject = PlayerNPCDialogueResponse(**_contract_body(reject_response.get_json()))
    assert parsed_reject.recruitment_result == "reject"

    unrelated_recruitment_response = client.post(
        "/npc/dialogue",
        json=_base_payload("今晚食堂准备吃什么？", recruitment=True),
    )
    assert unrelated_recruitment_response.status_code == 200
    assert unrelated_recruitment_response.get_json()["recruitment_result"] == "none"

    combat_payload = copy.deepcopy(_base_payload("我们一起稳住阵线，坚持守住城门。"))
    combat_payload["interaction_context"] = "combat"
    combat_payload["npc_state"].update({
        "recruited": True,
        "behavior_mode": "combat",
        "equipment": {"main_weapon": {"weapon_id": "sword_shield"}},
    })
    toggle_off_response = client.post("/npc/dialogue", json=combat_payload)
    assert toggle_off_response.status_code == 200, toggle_off_response.get_json()
    assert toggle_off_response.get_json()["wartime_reaction"] == "none"
    assert "combat_strategy_decision" not in toggle_off_response.get_json()
    assert "work_encouragement_reaction" not in toggle_off_response.get_json()

    combat_payload["is_morale_encouragement_request"] = True
    inspired_response = client.post("/npc/dialogue", json=combat_payload)
    assert inspired_response.status_code == 200, inspired_response.get_json()
    assert inspired_response.get_json()["wartime_reaction"] == "morale_boost"

    unrelated_payload = copy.deepcopy(combat_payload)
    unrelated_payload["speaker_text"] = "今晚食堂准备吃什么？"
    unrelated_response = client.post("/npc/dialogue", json=unrelated_payload)
    assert unrelated_response.status_code == 200, unrelated_response.get_json()
    assert unrelated_response.get_json()["wartime_reaction"] == "none"

    strategy_payload = copy.deepcopy(combat_payload)
    strategy_payload["is_morale_encouragement_request"] = False
    strategy_payload["is_combat_strategy_request"] = True
    strategy_payload["combat_strategy_context"] = {
        "current_strategy": {"id": "attack", "label": "主动进攻", "is_default": True},
        "available_strategies": [
            {"id": "attack", "label": "主动进攻", "is_default": True},
            {"id": "avoid", "label": "避战", "is_default": False},
        ],
    }
    strategy_payload["speaker_text"] = "不要主动接敌，调整为避战并保存实力。"
    strategy_change_response = client.post("/npc/dialogue", json=strategy_payload)
    assert strategy_change_response.status_code == 200, strategy_change_response.get_json()
    assert strategy_change_response.get_json()["combat_strategy_decision"] == {
        "decision": "change",
        "strategy_id": "avoid",
    }

    strategy_unrelated_payload = copy.deepcopy(strategy_payload)
    strategy_unrelated_payload["speaker_text"] = "今晚食堂准备吃什么？"
    strategy_unrelated_response = client.post("/npc/dialogue", json=strategy_unrelated_payload)
    assert strategy_unrelated_response.status_code == 200, strategy_unrelated_response.get_json()
    assert strategy_unrelated_response.get_json()["combat_strategy_decision"] == {
        "decision": "keep",
        "strategy_id": "attack",
    }

    unavailable_strategy_payload = copy.deepcopy(strategy_payload)
    unavailable_strategy_payload["speaker_text"] = "改成保持距离射击。"
    unavailable_strategy_response = client.post("/npc/dialogue", json=unavailable_strategy_payload)
    assert unavailable_strategy_response.status_code == 200, unavailable_strategy_response.get_json()
    assert unavailable_strategy_response.get_json()["combat_strategy_decision"] == {
        "decision": "keep",
        "strategy_id": "attack",
    }

    work_payload = copy.deepcopy(_base_payload("辛苦了，你的工作很重要，我相信你能把今天剩下的活做好。"))
    work_payload["interaction_context"] = "work"
    work_payload["is_work_encouragement_request"] = True
    work_payload["npc_state"]["behavior_mode"] = "work"
    work_boost_response = client.post("/npc/dialogue", json=work_payload)
    assert work_boost_response.status_code == 200, work_boost_response.get_json()
    assert work_boost_response.get_json()["work_encouragement_reaction"] == "work_boost"

    unrelated_work_payload = copy.deepcopy(work_payload)
    unrelated_work_payload["speaker_text"] = "今晚食堂准备吃什么？"
    unrelated_work_response = client.post("/npc/dialogue", json=unrelated_work_payload)
    assert unrelated_work_response.status_code == 200, unrelated_work_response.get_json()
    assert unrelated_work_response.get_json()["work_encouragement_reaction"] == "none"

    escaping_work_payload = copy.deepcopy(work_payload)
    escaping_work_payload["speaker_text"] = "你这个废物，做不完就滚，不许休息。"
    escaping_work_response = client.post("/npc/dialogue", json=escaping_work_payload)
    assert escaping_work_response.status_code == 200, escaping_work_response.get_json()
    assert escaping_work_response.get_json()["work_encouragement_reaction"] == "escape"

    npc_payload = _base_payload("你听见外面那阵声音了吗？", recruitment=False)
    npc_payload["dialogue_kind"] = "npc_npc"
    npc_payload["speaker_name"] = "托马"
    npc_payload["speaker_context"] = SpeakerContext(
        speaker_id="stableman_01",
        speaker_name="托马",
        speaker_kind="npc",
        appearance="肩背宽厚，旧皮围裙上沾着干草。",
        health_status="健康",
    ).model_dump()
    npc_payload["dialogue_phase"] = "conversation"
    soft_guidance = "第六轮起若无紧急或必要事项，应自然告别并输出结束标记。"
    npc_payload["current_round"] = 6
    npc_payload["max_rounds"] = 0
    npc_payload["soft_round_threshold"] = 5
    npc_payload["soft_round_guidance"] = soft_guidance
    npc_payload["dialogue_state"]["current_round"] = 6
    npc_payload["dialogue_state"]["max_rounds"] = 0
    npc_payload["dialogue_state"]["soft_round_threshold"] = 5
    npc_payload["dialogue_state"]["soft_round_guidance"] = soft_guidance
    npc_response = client.post("/npc/dialogue", json=npc_payload)
    assert npc_response.status_code == 200
    parsed_npc = NPCNPCDialogueResponse(**_contract_body(npc_response.get_json()))
    assert parsed_npc.response_kind == "reply_to_npc"
    assert parsed_npc.should_end_dialogue is True
    assert parsed_npc.invitation_result == "not_applicable"
    assert "intent" not in npc_response.get_json()
    assert "recruitment_result" not in npc_response.get_json()

    urgent_payload = dict(npc_payload)
    urgent_payload["dialogue_state"] = dict(npc_payload["dialogue_state"])
    urgent_payload["speaker_text"] = "有紧急伤员，必须立刻继续协调必要的诊疗安排。"
    urgent_response = client.post("/npc/dialogue", json=urgent_payload)
    assert urgent_response.status_code == 200, urgent_response.get_json()
    parsed_urgent = NPCNPCDialogueResponse(**_contract_body(urgent_response.get_json()))
    assert parsed_urgent.should_end_dialogue is False

    invitation_payload = dict(npc_payload)
    invitation_payload["dialogue_state"] = dict(npc_payload["dialogue_state"])
    invitation_payload["dialogue_phase"] = "invitation"
    invitation_payload["current_round"] = 0
    invitation_payload["dialogue_state"]["current_round"] = 0
    invitation_payload["speaker_text"] = "我想和你谈谈诊所工位。"
    invitation_accept = client.post("/npc/dialogue", json=invitation_payload)
    assert invitation_accept.status_code == 200, invitation_accept.get_json()
    parsed_invitation_accept = NPCNPCDialogueResponse(
        **_contract_body(invitation_accept.get_json())
    )
    assert parsed_invitation_accept.invitation_result == "accept"
    assert parsed_invitation_accept.should_end_dialogue is False

    invitation_payload["speaker_text"] = "请拒绝这次邀请，别打扰手上的工作。"
    invitation_reject = client.post("/npc/dialogue", json=invitation_payload)
    assert invitation_reject.status_code == 200, invitation_reject.get_json()
    parsed_invitation_reject = NPCNPCDialogueResponse(
        **_contract_body(invitation_reject.get_json())
    )
    assert parsed_invitation_reject.invitation_result == "reject"
    assert parsed_invitation_reject.should_end_dialogue is True

    escape_payload = copy.deepcopy(_base_payload("别走，我会兑现保护和补给承诺。"))
    escape_payload["dialogue_kind"] = "escape_intervention"
    escape_payload["interaction_context"] = "escape_intervention"
    escape_payload["escape_intervention_round"] = 1
    escape_payload["npc_state"]["escape_intent"] = {
        "active": True,
        "status": "escaping",
        "intervention_rounds_used": 0,
        "intervention_max_rounds": 5,
    }
    escape_response = client.post("/npc/dialogue", json=escape_payload)
    assert escape_response.status_code == 200, escape_response.get_json()
    escape_data = escape_response.get_json()
    parsed_escape = EscapeInterventionDialogueResponse(**_contract_body(escape_data))
    assert parsed_escape.escape_intervention_result == "stay"
    assert "intent" not in escape_data
    assert "recruitment_result" not in escape_data
    assert "should_end_dialogue" not in escape_data

    missing_actions_payload = _base_payload("验证对话行动参考。")
    missing_actions_payload.pop("allowed_actions")
    missing_actions_response = client.post("/npc/dialogue", json=missing_actions_payload)
    assert missing_actions_response.status_code == 400
    assert missing_actions_response.get_json()["error_code"] == "validation_error"

    partial_truth_payload = _base_payload("验证对话权威状态成套校验。")
    partial_truth_payload.pop("training_truth")
    partial_truth_response = client.post("/npc/dialogue", json=partial_truth_payload)
    assert partial_truth_response.status_code == 400
    assert partial_truth_response.get_json()["error_code"] == "validation_error"

    bad_response = client.post("/npc/dialogue", json={"npc_id": "cook_01"})
    assert bad_response.status_code == 400
    assert bad_response.get_json()["error_code"] == "validation_error"

    print("verify_dialogue_mock_endpoint: ok")


if __name__ == "__main__":
    main()
