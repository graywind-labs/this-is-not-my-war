from pathlib import Path
import sys
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.schemas import (
    EscapeInterventionDialogueResponse,
    GameTime,
    ModelRequestMeta,
    NPCNPCDialogueResponse,
    PlayerNPCDialogueResponse,
    SpeakerContext,
)
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig
from tools.station_context_fixture import build_station_context


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
        "station_context": build_station_context([
            {"npc_id": "cook_01", "name": "布鲁诺", "identity": "厨子"}
        ]),
        "dialogue_kind": "player_npc",
        "npc_id": "cook_01",
        "npc_name": "布鲁诺",
        "npc_setting": {
            "background_job": "厨子",
            "religion": "天主教",
            "personality": ["谨慎", "嘴硬"],
            "desires": ["保住食堂", "别让普通人被当成士兵消耗"],
            "fears": ["被逼上战场"],
            "boundaries": ["不能接受无意义牺牲"],
            "speech_style": "说话直率，先确认有多少人、多少粮和多少时间；抱怨归抱怨，最后会给出能执行的办法。",
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
        "long_memory": {
            "diary": ["我不想让锅铲变成刀。"],
            "knowledge_graph": {
                "schema_version": "key_value_replace_v1",
                "updated_day": 0,
                "updated_time": "开局前",
                "by_subject": {
                    "guard_officer": {
                        "role": {
                            "value": "station_defense_alert_and_emergency_staff_coordination",
                            "value_label": "守备官负责驿站防务与警戒。",
                        },
                        "arrival_at_station": {
                            "value": "arrived_three_years_before_game_start",
                            "value_label": "守备官三年前来到驿站。",
                        },
                        "past_before_station": {
                            "value": "unknown_not_disclosed",
                            "value_label": "守备官没有说明来站前的经历，我不知道他的过去。",
                        },
                        "pre_game_relationship": {
                            "value": "consistently_dedicated_and_harmonious",
                            "value_label": "守备官一直尽责，与驿站成员相处和睦。",
                        },
                    }
                },
            },
        },
        "location_context": {"location_id": "dining_hall", "people_present": ["cook_01"]},
        "allowed_actions": [
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
                "action_id": "sleep_in_dormitory",
                "name": "睡觉",
                "action_kind": "sleep",
                "location_id": "dormitory",
                "tags": ["sleep"],
                "context": {"authority": "ActionSystem"},
            },
        ],
    }


def _valid_player_response(**overrides: object) -> dict:
    response = {
        "reply_text": "守备官，我听见了。要我站出来，就别把食堂里的人当成柴火。",
        "emotion": "none",
        "recruitment_result": "accept",
        "debug_reason": "职业、人设、记忆和 current_order 共同影响应征判断。",
    }
    response.update(overrides)
    return response


def _valid_npc_response(**overrides: object) -> dict:
    response = {
        "reply_text": "好，我先听你说。",
        "emotion": "none",
        "invitation_result": "not_applicable",
        "should_end_dialogue": False,
        "debug_reason": "NPC 对话轮次判断。",
    }
    response.update(overrides)
    return response


def _valid_escape_response(**overrides: object) -> dict:
    response = {
        "reply_text": "我再信你一次，留下。",
        "emotion": "none",
        "escape_intervention_result": "stay",
        "debug_reason": "逃离挽留选择留下。",
    }
    response.update(overrides)
    return response


def _run_real_adapter_with_fake_provider(payload: dict, fake_content: dict) -> tuple[dict, str, dict]:
    adapter = ModelAdapter(ModelAdapterConfig(provider="deepseek", api_key="test_key", fallback_to_mock=False))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeDialogueResponse(fake_content),
    ) as fake_post:
        result = adapter.generate("dialogue", payload)
    assert result.ok
    response_models = {
        "player_npc": PlayerNPCDialogueResponse,
        "npc_npc": NPCNPCDialogueResponse,
        "escape_intervention": EscapeInterventionDialogueResponse,
    }
    response_models[payload["dialogue_kind"]](**result.content)
    request_body = fake_post.call_args.kwargs["json"]
    system_prompt = request_body["messages"][0]["content"]
    provider_payload = __import__("json").loads(request_body["messages"][1]["content"])
    return result.content, system_prompt, provider_payload


def main() -> None:
    payload = _base_payload()
    content, system_prompt, provider_payload = _run_real_adapter_with_fake_provider(
        payload,
        _valid_player_response(),
    )

    required_prompt_fragments = [
        "NPC 对话 Prompt",
        "职业背景",
        "speech_style",
        "自然、直白",
        "不要为了显得有个性",
        "不是固定句式或台词模板",
        "往昔·近日",
        "传达敌情",
        "【最高优先级的权威实况】",
        "activity_truth",
        "equipment_truth",
        "training_truth",
        "优先于计划、计划 reason / summary",
        "只有 activity_truth.is_training=true",
        "action_id=visit_location",
        "只表示拜访 / 停留",
        "equipment_truth.main_weapon / mount 为 null",
        "blocker=no_trainable_equipment",
        "不得用计划里写了训练、人在训练场",
        "日记字符串保留",
        "第 N 天 + 时间",
        "不是最低轮数、目标轮数或继续对话的理由",
        "绝不能为了等到阈值而续聊",
        "只能确认、复述或换一种说法重复",
        "必须停止重复",
        "对方已经完整回答",
        "双方已经达成一致",
        "不得为了延长对话自行制造新话题、新任务、新问题、额外帮助或后续安排",
        "已经存在的未决紧急或必要事项",
        "三年前来到驿站",
        "你没有告诉过我 / 我不知道",
        "不得替守备官编造身份和故事",
        "一直尽责",
        "相处和睦",
        "reply_text 必须明确使用“尽责 / 敬业 / 尽职”",
        "该分支最多三句",
        "最后一句立即转向当前驿站事务",
        "不得在转题前补充理由、例子、引语、日常场景",
        "不得补造某天发生的事件",
        "立即转向当前驿站事务",
        "职业经验",
        "experienced_events",
        "witnessed_events",
        "只能把自己的 short_memory / long_memory / location_context / current_order",
        "供应商请求不提供 speaker_npc 或 target_npc 人物副本",
        "未说出口的记忆",
        "allowed_actions 中为程序执行和合法性校验提供的目标 / 地点",
        "不自动成为目标 NPC 的见闻",
        "current_order",
        "interrupted_activity_context",
        "activity_before_interruption",
        "expected_activity_after_dialogue",
        "talk_to_guard_officer",
        "刚才正在睡觉",
        "不是事件库、见闻库或长期记忆中的事件",
        "allowed_actions",
        "当前能力边界",
        "context.eligible=false",
        "unavailable_reason",
        "required_ability=主持弥撒",
        "required_active_action_id",
        "blocked_by_active_action_id",
        "pray_at_chapel",
        "弥撒开始时程序会自动让祈祷者参加",
        "弥撒结束后继续独自祈祷",
        "drink_wine",
        "npc_state.wine",
        "程序会扣除 1 份个人酒",
        "不得声称旧记忆已被删除",
        "不是制定或修改计划",
        "列表外行动",
        "当前做不到",
        "提出应征",
        "第一步必须先做相关性闸门",
        "立即结束应征判断",
        "recruitment_result=accept 时",
        "avoid_combat",
        "escape_intervention",
        "escape_intervention_result 只能是 stay 或 leave",
        "dialogue_phase=invitation",
        "invitation_result",
        "不占正式对话轮次",
        "没有程序硬性轮次上限",
        "soft_round_guidance",
        "整场会话最后一句",
        "不得决定资源、HP、建筑、移动、伤害",
    ]
    assert "signature_lines" not in payload["npc_setting"]
    assert "signature_lines" not in system_prompt
    assert "speaker_npc" not in payload
    assert "meta" not in provider_payload
    assert provider_payload["activity_truth"] == payload["activity_truth"]
    assert provider_payload["equipment_truth"] == payload["equipment_truth"]
    assert provider_payload["training_truth"] == payload["training_truth"]
    assert provider_payload["npc_setting"]["religion"] == "天主教"
    guard_knowledge = provider_payload["long_memory"]["knowledge_graph"]["by_subject"]["guard_officer"]
    assert set(guard_knowledge) == {
        "role",
        "arrival_at_station",
        "past_before_station",
        "pre_game_relationship",
    }
    assert guard_knowledge["arrival_at_station"]["value"] == "arrived_three_years_before_game_start"
    assert guard_knowledge["past_before_station"]["value"] == "unknown_not_disclosed"
    assert (
        guard_knowledge["pre_game_relationship"]["value"]
        == "consistently_dedicated_and_harmonious"
    )
    assert "speaker_npc" not in provider_payload
    assert "target_npc" not in provider_payload
    assert "current_round" not in provider_payload["dialogue_state"]
    assert "max_rounds" not in provider_payload["dialogue_state"]
    assert "speaker_name" not in provider_payload["speaker_context"]
    for fragment in required_prompt_fragments:
        assert fragment in system_prompt, fragment
    for inactive_strategy_fragment in [
        "is_combat_strategy_request=true",
        "combat_strategy_context.current_strategy",
        "combat_strategy_decision",
    ]:
        assert inactive_strategy_fragment not in system_prompt, inactive_strategy_fragment
    for inactive_work_fragment in [
        "is_work_encouragement_request=true",
        "work_encouragement_reaction",
        "全部工作产出效率+20%",
    ]:
        assert inactive_work_fragment not in system_prompt, inactive_work_fragment
    for inactive_morale_fragment in [
        "is_morale_encouragement_request=true",
        "wartime_reaction",
        "开关本身不是鼓舞成功的证据",
    ]:
        assert inactive_morale_fragment not in system_prompt, inactive_morale_fragment
    assert "attend_mass" not in system_prompt
    assert "玩家" not in content["reply_text"]
    assert content["recruitment_result"] == "accept"
    assert content["ok"] is True
    assert content["replyer_id"] == "cook_01"
    assert content["response_kind"] == "reply_to_player"
    assert content["wartime_reaction"] == "none"
    assert content["suggested_event_type"] == "dialogue_turn"

    sleep_payload = _base_payload()
    sleep_payload.update({
        "is_recruitment_request": False,
        "speaker_text": "我把你叫起来了。你刚才在做什么，谈完准备做什么？",
        "npc_state": _base_payload()["npc_state"] | {
            "current_action": "talk_to_guard_officer",
            "current_location": "dormitory",
            "current_location_name": "宿舍",
        },
        "interrupted_activity_context": {
            "interrupted_by_guard_officer": True,
            "private_to_target_npc": True,
            "activity_before_interruption": {
                "action_id": "sleep_in_dormitory",
                "action_name": "睡觉",
                "phase": "active",
                "location_id": "dormitory",
                "location_name": "宿舍",
                "workstation_id": "dormitory_bed_02",
                "elapsed_seconds": 1800.0,
                "duration_seconds": 23400.0,
            },
            "current_plan_activity": {
                "action_id": "sleep_in_dormitory",
                "action_name": "睡觉",
                "phase": "planned",
                "day": 3,
                "hour": 18,
                "location_id": "dormitory",
            },
            "expected_activity_after_dialogue": {
                "action_id": "sleep_in_dormitory",
                "action_name": "睡觉",
                "phase": "planned",
                "day": 3,
                "hour": 18,
                "location_id": "dormitory",
            },
            "resume_policy": "resume_interrupted_activity_if_plan_unchanged",
            "resume_expected_if_plan_unchanged": True,
        },
    })
    sleep_content, sleep_prompt, sleep_provider_payload = _run_real_adapter_with_fake_provider(
        sleep_payload,
        _valid_player_response(
            reply_text="我刚才还在睡，是你把我叫醒的。要是计划没变，谈完我还得回去把这一觉睡完。",
            recruitment_result="none",
        ),
    )
    sleep_context = sleep_provider_payload["interrupted_activity_context"]
    assert sleep_context["private_to_target_npc"] is True
    assert (
        sleep_context["activity_before_interruption"]["action_id"]
        == "sleep_in_dormitory"
    )
    assert (
        sleep_context["expected_activity_after_dialogue"]["action_id"]
        == "sleep_in_dormitory"
    )
    assert "刚才还在睡" in sleep_content["reply_text"]
    for inactive_recruitment_fragment in [
        "is_recruitment_request=true",
        "recruitment_result",
        "提出应征",
        "应征校准",
        "第一步必须先做相关性闸门",
        "输出前一致性检查",
    ]:
        assert inactive_recruitment_fragment not in sleep_prompt, inactive_recruitment_fragment

    wartime_payload = _base_payload()
    wartime_payload.update({
        "is_recruitment_request": False,
        "is_morale_encouragement_request": True,
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
    wartime_content, _, _ = _run_real_adapter_with_fake_provider(
        wartime_payload,
        _valid_player_response(
            recruitment_result="none",
            wartime_reaction="morale_boost",
            debug_reason="战斗公开对话产生斗志激昂意向。",
        ),
    )
    assert wartime_content["wartime_reaction"] == "morale_boost"
    wartime_prompt = ModelAdapter(
        ModelAdapterConfig(provider="mock")
    )._system_prompt_for_call_type("dialogue", wartime_payload)
    for morale_fragment in [
        "is_morale_encouragement_request=true",
        "第一步必须先做相关性闸门",
        "战术后撤、避战、保存实力",
        "后撤到驿站内某处",
        "reply_text 中必须直接出现“离开驿站”四个字",
        "wartime_reaction",
        "无关",
        "morale_boost",
        "escape",
        "none",
    ]:
        assert morale_fragment in wartime_prompt, morale_fragment

    strategy_payload = _base_payload()
    strategy_payload.update({
        "is_recruitment_request": False,
        "is_combat_strategy_request": True,
        "interaction_context": "combat",
        "combat_strategy_context": {
            "current_strategy": {"id": "attack", "label": "主动进攻"},
            "available_strategies": [
                {"id": "attack", "label": "主动进攻"},
                {"id": "avoid", "label": "避战"},
            ],
        },
    })
    strategy_prompt = ModelAdapter(
        ModelAdapterConfig(provider="mock")
    )._system_prompt_for_call_type("dialogue", strategy_payload)
    for strategy_fragment in [
        "is_combat_strategy_request=true",
        "combat_strategy_context.current_strategy",
        "combat_strategy_decision",
        "第一步必须先做相关性闸门",
        "无关内容必须立即结束策略判断",
        "必须返回 change + 该候选 ID",
        "change 的 reply_text 必须明确表达同意",
    ]:
        assert strategy_fragment in strategy_prompt, strategy_fragment

    work_payload = _base_payload()
    work_payload.update({
        "is_recruitment_request": False,
        "is_work_encouragement_request": True,
        "interaction_context": "work",
        "speaker_text": "辛苦了，你的工作很重要，我相信你。",
        "npc_state": _base_payload()["npc_state"] | {
            "behavior_mode": "work",
            "work_encouragement_boost": {},
        },
    })
    work_prompt = ModelAdapter(
        ModelAdapterConfig(provider="mock")
    )._system_prompt_for_call_type("dialogue", work_payload)
    for work_fragment in [
        "is_work_encouragement_request=true",
        "work_encouragement_reaction",
        "第一步必须先做相关性闸门",
        "只是询问资源、库存、产量",
        "只有 NPC 自己决定现在开始永久离开驿站",
        "work_boost 的 reply_text",
        "none",
        "work_boost",
        "escape",
        "全部工作产出效率+20%",
        "持续至当天24:00",
    ]:
        assert work_fragment in work_prompt, work_fragment

    invitation_payload = _base_payload()
    invitation_payload.update({
        "dialogue_kind": "npc_npc",
        "dialogue_phase": "invitation",
        "speaker_name": "莉娜",
        "speaker_text": "马塞尔，我想和你谈谈诊所工位。",
        "speaker_context": SpeakerContext(
            speaker_id="doctor_01",
            speaker_name="莉娜",
            speaker_kind="npc",
        ).model_dump(),
        "is_recruitment_request": False,
        "current_round": 0,
        "max_rounds": 0,
        "soft_round_threshold": 5,
        "soft_round_guidance": "第六轮起若无紧急或必要事项，应自然告别并结束。",
    })
    invitation_payload["dialogue_state"] = dict(invitation_payload["dialogue_state"])
    invitation_payload["dialogue_state"]["current_round"] = 0
    invitation_payload["dialogue_state"]["max_rounds"] = 0
    invitation_payload["dialogue_state"]["soft_round_threshold"] = 5
    invitation_payload["dialogue_state"]["soft_round_guidance"] = invitation_payload["soft_round_guidance"]
    invitation_payload["dialogue_state"]["participants"] = ["doctor_01", "cook_01"]
    invitation_content, _, _ = _run_real_adapter_with_fake_provider(
        invitation_payload,
        _valid_npc_response(
            invitation_result="accept",
            reply_text="好，我先听你说。",
        ),
    )
    assert invitation_content["invitation_result"] == "accept"

    formal_payload = dict(invitation_payload)
    formal_payload["dialogue_state"] = dict(invitation_payload["dialogue_state"])
    formal_payload["dialogue_phase"] = "conversation"
    formal_payload["current_round"] = 6
    formal_payload["dialogue_state"]["current_round"] = 6
    formal_content, _, _ = _run_real_adapter_with_fake_provider(
        formal_payload,
        _valid_npc_response(
            invitation_result="not_applicable",
            should_end_dialogue=True,
            reply_text="这一轮已经说清，我们先结束。",
        ),
    )
    assert formal_content["should_end_dialogue"] is True

    escape_payload = _base_payload()
    escape_payload.update({
        "dialogue_kind": "escape_intervention",
        "interaction_context": "escape_intervention",
        "is_recruitment_request": False,
        "speaker_text": "别走，我会补偿你，也需要你见证我们守住这里。",
        "escape_intervention_round": 2,
    })
    escape_content, _, _ = _run_real_adapter_with_fake_provider(
        escape_payload,
        _valid_escape_response(
            escape_intervention_result="stay",
            debug_reason="逃离挽留选择留下。",
        ),
    )
    assert escape_content["escape_intervention_result"] == "stay"
    assert "intent" not in escape_content

    print("verify_dialogue_prompt: ok")


if __name__ == "__main__":
    main()
