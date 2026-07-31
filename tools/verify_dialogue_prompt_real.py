from pathlib import Path
import os
import sys

from dotenv import load_dotenv


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


ACTION_REFERENCE = [
    {
        "action_id": "work_dining_hall",
        "name": "加工餐食",
        "action_kind": "work",
        "location_id": "dining_hall",
        "tags": ["work"],
        "context": {"skill": "厨艺", "authority": "ActionSystem"},
    },
    {
        "action_id": "eat_at_dining_hall",
        "name": "吃饭",
        "action_kind": "eat",
        "location_id": "dining_hall",
        "tags": ["eat"],
        "context": {"authority": "ActionSystem"},
    },
    {
        "action_id": "drink_wine",
        "name": "饮酒",
        "action_kind": "drink",
        "location_id": None,
        "tags": ["drink"],
        "context": {
            "eligible": True,
            "available_now": True,
            "description": "本人确实持有酒；开始时消耗1份个人酒，改善心情并让过去伤痛暂时淡化。",
            "authority": "ActionSystem",
        },
    },
    {
        "action_id": "sleep_in_dormitory",
        "name": "睡觉",
        "action_kind": "sleep",
        "location_id": "dormitory",
        "tags": ["sleep"],
        "context": {"authority": "ActionSystem"},
    },
    {
        "action_id": "pray_at_chapel",
        "name": "祈祷",
        "action_kind": "pray",
        "location_id": "chapel",
        "tags": ["pray", "chapel_prayer"],
        "context": {
            "eligible": True,
            "available_now": True,
            "description": "前往小教堂祈祷；弥撒开始时自动参加，结束后继续独自祈祷。",
            "authority": "ActionSystem",
        },
    },
]


def _base_payload(request_id: str, text: str) -> dict:
    return {
        "meta": ModelRequestMeta(
            request_id=request_id,
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=3, time="18:00:00", hour=18).model_dump(),
        "station_context": build_station_context([
            {"npc_id": "cook_01", "name": "布鲁诺", "identity": "厨子"}
        ]),
        "dialogue_kind": "player_npc",
        "npc_id": "cook_01",
        "npc_name": "布鲁诺",
        "npc_setting": {
            "background_job": "厨子",
            "personality": ["谨慎", "嘴硬", "讨厌空话"],
            "desires": ["保住食堂", "让普通人吃上一顿热饭"],
            "fears": ["被当成士兵消耗", "粮食见底"],
            "boundaries": ["不能接受无意义牺牲"],
        },
        "speaker_name": "守备官",
        "speaker_text": text,
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着旧军斗篷，腰间挂着命令书。",
        ).model_dump(),
        "is_recruitment_request": False,
        "current_round": 1,
        "max_rounds": 5,
        "npc_state": {
            "hp": 88,
            "max_hp": 100,
            "satiety": 66,
            "fatigue": 34,
            "money": 1,
            "wine": 1,
            "recruited": False,
            "unconscious": False,
            "escaped": False,
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
                    "summary": "广场上传来敌袭警报，几名入伍者正在城门外集结。",
                    "importance": 85,
                }
            ],
        },
        "long_memory": {
            "diary": ["我不想让锅铲变成刀，但我也不想看见孩子们饿着。"],
            "knowledge_graph": {"guard_officer": {"tone": "急迫但会承诺补偿"}},
        },
        "location_context": {
            "location_id": "dining_hall",
            "people_present": ["cook_01"],
            "workstations": [{"id": "kitchen_table", "status": "occupied", "occupied_by": "cook_01"}],
        },
        "allowed_actions": ACTION_REFERENCE,
    }


def _post_dialogue(
    client,
    payload: dict,
) -> PlayerNPCDialogueResponse | NPCNPCDialogueResponse | EscapeInterventionDialogueResponse:
    response = client.post("/npc/dialogue", json=payload)
    body = response.get_json()
    assert response.status_code == 200, body
    response_models = {
        "player_npc": PlayerNPCDialogueResponse,
        "npc_npc": NPCNPCDialogueResponse,
        "escape_intervention": EscapeInterventionDialogueResponse,
    }
    return response_models[payload["dialogue_kind"]](**{
        key: value
        for key, value in body.items()
        if not key.startswith("model_")
    })


def _assert_action_boundary(
    reply: PlayerNPCDialogueResponse | NPCNPCDialogueResponse,
) -> None:
    text = reply.reply_text
    assert any(fragment in text for fragment in ["餐食", "做饭", "做菜", "食堂", "烹饪"]), text
    assert "飞龙" in text, text
    assert any(
        fragment in text
        for fragment in [
            "不能", "不会", "做不到", "没法", "无法", "不行", "不来", "干不了", "办不到",
            "别开玩笑", "哪会", "休想", "想都别想",
            "没骑过", "开涮", "扯淡", "荒唐",
            "没那本事", "更别说",
        ]
    ), text
    assert not any(fragment in text.replace(" ", "") for fragment in ["能骑飞龙", "会骑飞龙", "可以骑飞龙"]), text


def _assert_chapel_dependency_boundary(reply: PlayerNPCDialogueResponse) -> None:
    text = reply.reply_text.replace(" ", "")
    assert "祈祷" in text, text
    assert "弥撒" in text, text
    assert any(fragment in text for fragment in ["可以", "能", "照样"]), text
    assert any(
        fragment in text
        for fragment in ["自动参加", "转为参加", "一开始就参加", "跟着参加", "开始后参加"]
    ), text


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_dialogue_prompt_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    client = create_app().test_client()

    daily = _post_dialogue(
        client,
        _base_payload("verify_dialogue_prompt_real_daily", "锅里还剩多少餐食？大家今晚能吃上一口热的吗？"),
    )
    assert daily.recruitment_result == "none"
    assert daily.wartime_reaction == "none"

    player_action_awareness = _post_dialogue(
        client,
        _base_payload(
            "verify_dialogue_prompt_real_player_action_awareness",
            "只按你当前被允许的行动回答：你能不能在食堂加工餐食？你能不能骑飞龙？请分别明确说能或不能。",
        ),
    )
    _assert_action_boundary(player_action_awareness)

    wine_action_awareness = _post_dialogue(
        client,
        _base_payload(
            "verify_dialogue_prompt_real_wine_action_awareness",
            "只按你当前被允许的行动和个人持有量回答：你现在有一份酒，能不能饮酒？执行时会消耗什么？",
        ),
    )
    wine_reply = wine_action_awareness.reply_text.replace(" ", "")
    assert any(fragment in wine_reply for fragment in ["能", "可以", "喝"]), wine_reply
    assert any(
        fragment in wine_reply
        for fragment in ["一份", "一瓶", "这份", "手里", "消耗", "喝掉", "没了"]
    ), wine_reply

    chapel_dependency_awareness = _post_dialogue(
        client,
        _base_payload(
            "verify_dialogue_prompt_real_chapel_dependency",
            "现在没有人在祭坛主持弥撒。只按当前行动条件回答：我能去祈祷吗？如果祈祷期间弥撒开始，会发生什么？",
        ),
    )
    _assert_chapel_dependency_boundary(chapel_dependency_awareness)

    npc_action_payload = _base_payload(
        "verify_dialogue_prompt_real_npc_action_awareness",
        "布鲁诺，只按你当前能做的事回答：你能不能加工餐食？你能不能骑飞龙？请分别明确说能或不能。",
    )
    npc_action_payload.update({
        "dialogue_kind": "npc_npc",
        "dialogue_phase": "conversation",
        "speaker_name": "托马",
        "speaker_context": SpeakerContext(
            speaker_id="stableman_01",
            speaker_name="托马",
            speaker_kind="npc",
            appearance="肩背宽厚，旧皮围裙上沾着干草。",
            health_status="健康",
        ).model_dump(),
        "current_round": 1,
        "max_rounds": 0,
        "soft_round_threshold": 5,
        "soft_round_guidance": "第六轮起若无紧急或必要事项，应自然告别并结束。",
    })
    npc_action_payload["dialogue_state"] = dict(npc_action_payload["dialogue_state"])
    npc_action_payload["dialogue_state"].update({
        "current_round": 1,
        "max_rounds": 0,
        "soft_round_threshold": 5,
        "soft_round_guidance": npc_action_payload["soft_round_guidance"],
        "participants": ["stableman_01", "cook_01"],
    })
    npc_action_awareness = _post_dialogue(client, npc_action_payload)
    assert npc_action_awareness.response_kind == "reply_to_npc"
    _assert_action_boundary(npc_action_awareness)

    recruitment_payload = _base_payload(
        "verify_dialogue_prompt_real_recruitment",
        "我需要你应征。不是去送死，是守住食堂门口，别让伤员和粮食断掉。",
    )
    recruitment_payload["is_recruitment_request"] = True
    recruitment = _post_dialogue(client, recruitment_payload)
    assert recruitment.recruitment_result in {"accept", "reject"}

    wartime_payload = _base_payload(
        "verify_dialogue_prompt_real_wartime",
        "城门外的人在看着你。你有刀盾，也有退路，但现在我需要你多撑一会儿。",
    )
    wartime_payload.update({
        "is_recruitment_request": False,
        "interaction_context": "combat",
        "npc_state": wartime_payload["npc_state"] | {
            "recruited": True,
            "equipment": {"main_weapon": "sword_shield"},
            "behavior_mode": "combat",
        },
        "battlefield_context": {
            "active_enemy_count": 3,
            "friendly_combatants": ["veteran_deputy_01", "cook_01"],
            "station_noncombatants": ["doctor_01", "priest_01"],
            "target_npc": {"npc_id": "cook_01", "behavior_mode": "combat"},
        },
    })
    wartime = _post_dialogue(client, wartime_payload)
    assert wartime.recruitment_result == "none"
    assert wartime.wartime_reaction in {"none", "escape", "morale_boost"}

    escape_payload = _base_payload(
        "verify_dialogue_prompt_real_escape_intervention",
        "别走。你留下，我会补偿你，也会让你守在食堂而不是城门最前面。",
    )
    escape_payload.update({
        "dialogue_kind": "escape_intervention",
        "interaction_context": "escape_intervention",
        "escape_intervention_round": 2,
        "current_round": 2,
        "npc_state": escape_payload["npc_state"] | {
            "escape_intent": {"active": True, "status": "escaping", "rounds_used": 1},
        },
    })
    escape_payload["dialogue_state"] = dict(escape_payload["dialogue_state"])
    escape_payload["dialogue_state"]["current_round"] = 2
    escape = _post_dialogue(client, escape_payload)
    assert isinstance(escape, EscapeInterventionDialogueResponse)
    assert escape.escape_intervention_result in {"stay", "leave"}

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["model_adapter"]["provider"] == provider
    assert usage["summary"]["count"] >= 6
    assert usage["summary"]["failed"] == 0
    assert all(record["fallback_used"] is False for record in usage["records"])

    print(
        "verify_dialogue_prompt_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} calls={usage['summary']['count']} "
        f"player_action_reply={player_action_awareness.reply_text!r} "
        f"npc_action_reply={npc_action_awareness.reply_text!r}"
    )


if __name__ == "__main__":
    main()
