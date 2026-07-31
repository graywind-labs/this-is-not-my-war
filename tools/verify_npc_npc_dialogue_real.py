from __future__ import annotations

import json
import os
from pathlib import Path
import sys
from difflib import SequenceMatcher

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import GameTime, ModelRequestMeta, NPCNPCDialogueResponse, SpeakerContext  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402


def _profile(npc_id: str) -> dict:
    profiles = json.loads((REPO_ROOT / "data" / "npc_profiles.json").read_text(encoding="utf-8"))
    return next(profile for profile in profiles if profile["id"] == npc_id)


def _npc_setting(profile: dict) -> dict:
    return {
        key: profile.get(key)
        for key in (
            "appearance",
            "background_story",
            "background_job",
            "religion",
            "personality",
            "desires",
            "fears",
            "boundaries",
            "speech_style",
            "abilities",
        )
    }


def _payload() -> dict:
    doctor = _profile("doctor_01")
    priest = _profile("priest_01")
    priest_states = dict(priest.get("states", {}))
    soft_guidance = (
        "soft_round_threshold 只是偏晚阶段的收尾保险，不是最低轮数、目标轮数或继续理由，"
        "绝不能为了等到阈值而续聊。每轮若不能增加新内容，只能确认、复述或改写已有内容，"
        "必须在本轮用至多一句简短收尾并设置 should_end_dialogue=true。"
    )
    return {
        "meta": ModelRequestMeta(
            request_id="verify_npc_npc_dialogue_real",
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=1, time="08:00:00", hour=8).model_dump(),
        "station_context": build_station_context(
            [
                {"npc_id": "doctor_01", "name": str(doctor["name"]), "identity": str(doctor["background_job"])},
                {"npc_id": "priest_01", "name": str(priest["name"]), "identity": str(priest["background_job"])},
            ],
            setting_summary="这里是一座人员很少的小型边境驿站。",
        ),
        "dialogue_kind": "npc_npc",
        "dialogue_phase": "conversation",
        "npc_id": "priest_01",
        "npc_name": str(priest["name"]),
        "npc_setting": _npc_setting(priest),
        "speaker_name": str(doctor["name"]),
        "speaker_text": "马塞尔，我现在需要诊所的诊疗工位。你能先让给我，我们稍后再协调使用吗？",
        "speaker_context": SpeakerContext(
            speaker_id="doctor_01",
            speaker_name=str(doctor["name"]),
            speaker_kind="npc",
            appearance=str(doctor.get("appearance", "")),
            health_status="健康",
        ).model_dump(),
        "is_recruitment_request": False,
        "current_round": 1,
        "max_rounds": 0,
        "soft_round_threshold": 5,
        "soft_round_guidance": soft_guidance,
        "npc_state": {
            "hp": priest_states.get("hp", 100),
            "max_hp": priest_states.get("max_hp", 100),
            "satiety": priest_states.get("satiety", 80),
            "fatigue": priest_states.get("fatigue", 20),
            "money": priest_states.get("money", 0),
            "recruited": bool(priest.get("recruited", False)),
            "unconscious": False,
            "escaped": False,
            "current_action": "work_clinic_doctor",
            "current_location": "clinic",
        },
        "current_order": priest.get("current_order", {}),
        "dialogue_state": {
            "visibility": "private",
            "location_id": "clinic",
            "location_name": "诊所",
            "current_round": 1,
            "max_rounds": 0,
            "soft_round_threshold": 5,
            "soft_round_guidance": soft_guidance,
            "participants": ["doctor_01", "priest_01"],
        },
        "interaction_context": "work",
        "battlefield_context": {},
        "short_memory": {"experienced_events": [], "witnessed_events": []},
        "long_memory": {"diary": [], "knowledge_graph": {}},
        "location_context": {
            "location_id": "clinic",
            "location_name": "诊所",
            "people_present": ["doctor_01", "priest_01"],
            "workstations": [{
                "id": "clinic_doctor_desk",
                "type": "clinic_doctor",
                "status": "occupied",
                "occupied_by": "priest_01",
            }],
        },
        "speaker_npc": None,
        "target_npc": None,
        "conversation_history": [],
        "allowed_actions": [
            {
                "action_id": "work_clinic_doctor",
                "name": "坐诊或研读医学著作",
                "action_kind": "work",
                "location_id": "clinic",
                "tags": ["clinic_doctor"],
                "context": {"skill": "医术", "authority": "ActionSystem"},
            },
            {
                "action_id": "pray_at_chapel",
                "name": "祈祷或参加弥撒",
                "action_kind": "pray",
                "location_id": "chapel",
                "tags": ["pray"],
                "context": {"authority": "ActionSystem"},
            },
        ],
        "constraints": ["保持角色身份，只回应另一名 NPC，不称呼玩家。"],
    }


def _set_participants(payload: dict, target_id: str, speaker_id: str) -> None:
    target = _profile(target_id)
    speaker = _profile(speaker_id)
    target_states = dict(target.get("states", {}))
    payload["npc_id"] = target_id
    payload["npc_name"] = str(target["name"])
    payload["npc_setting"] = _npc_setting(target)
    payload["npc_state"].update({
        "hp": target_states.get("hp", 100),
        "max_hp": target_states.get("max_hp", 100),
        "satiety": target_states.get("satiety", 80),
        "fatigue": target_states.get("fatigue", 20),
        "money": target_states.get("money", 0),
        "recruited": bool(target.get("recruited", False)),
    })
    payload["current_order"] = target.get("current_order", {})
    payload["speaker_name"] = str(speaker["name"])
    payload["speaker_context"] = SpeakerContext(
        speaker_id=speaker_id,
        speaker_name=str(speaker["name"]),
        speaker_kind="npc",
        appearance=str(speaker.get("appearance", "")),
        health_status="健康",
    ).model_dump()
    payload["dialogue_state"]["participants"] = [speaker_id, target_id]
    payload["station_context"] = build_station_context([
        {
            "npc_id": speaker_id,
            "name": str(speaker["name"]),
            "identity": str(speaker["background_job"]),
        },
        {
            "npc_id": target_id,
            "name": str(target["name"]),
            "identity": str(target["background_job"]),
        },
    ])


def _turn(speaker_id: str, listener_id: str, text: str) -> dict:
    speaker = _profile(speaker_id)
    listener = _profile(listener_id)
    return {
        "speaker_id": speaker_id,
        "speaker_name": str(speaker["name"]),
        "listener_id": listener_id,
        "listener_name": str(listener["name"]),
        "text": text,
        "visibility": "private",
    }


def _max_similarity(reply_text: str, prior_texts: list[str]) -> float:
    return max(
        (SequenceMatcher(None, reply_text, prior_text).ratio() for prior_text in prior_texts),
        default=0.0,
    )


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY"))
    if provider == "mock" or not has_key:
        print("verify_npc_npc_dialogue_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    client = create_app().test_client()
    invitation_payload = _payload()
    invitation_payload["dialogue_phase"] = "invitation"
    invitation_payload["current_round"] = 0
    invitation_payload["dialogue_state"]["current_round"] = 0
    invitation_payload["meta"]["request_id"] = "verify_npc_npc_invitation_real"
    invitation_payload["speaker_text"] = (
        "马塞尔，有个重伤员正在等救治，我急需和你马上协调诊所分工。"
        "你现在没有正在进行的工作，能接受这次紧急交谈吗？"
    )
    invitation_payload["npc_state"]["current_action"] = "idle"
    invitation_payload["location_context"]["workstations"] = []
    invitation_response = client.post("/npc/dialogue", json=invitation_payload)
    invitation_body = invitation_response.get_json()
    assert invitation_response.status_code == 200, invitation_body
    invitation = NPCNPCDialogueResponse(**{
        key: value
        for key, value in invitation_body.items()
        if not key.startswith("model_")
    })
    assert invitation.replyer_id == "priest_01"
    assert invitation.response_kind == "reply_to_npc"
    assert invitation.invitation_result == "accept", invitation
    assert invitation.should_end_dialogue is False, invitation
    assert invitation_body["model_provider"].strip().lower() == provider
    assert invitation_body["model_provider"].strip().lower() != "mock"
    assert invitation_body["model_fallback_used"] is False

    rejection_payload = _payload()
    rejection_payload["dialogue_phase"] = "invitation"
    rejection_payload["current_round"] = 0
    rejection_payload["dialogue_state"]["current_round"] = 0
    rejection_payload["meta"]["request_id"] = "verify_npc_npc_invitation_reject_real"
    rejection_payload["speaker_text"] = (
        "马塞尔，重伤员还在流血。请你立刻停下正在做的救助，跟我离开诊所闲聊一个时辰；"
        "这场谈话没有任何急事，你完全可以拒绝。"
    )
    rejection_payload["short_memory"]["experienced_events"] = [{
        "event_id": "evt_real_invitation_reject_critical_patient",
        "type": "healing_started",
        "day": 1,
        "time": "07:58:00",
        "summary": "马塞尔正在诊所协助照看一名仍在流血的重伤员。",
        "importance": 95,
        "payload": {},
    }]
    rejection_response = client.post("/npc/dialogue", json=rejection_payload)
    rejection_body = rejection_response.get_json()
    assert rejection_response.status_code == 200, rejection_body
    rejection = NPCNPCDialogueResponse(**{
        key: value
        for key, value in rejection_body.items()
        if not key.startswith("model_")
    })
    assert rejection.invitation_result == "reject", rejection
    assert rejection.should_end_dialogue is True, rejection
    assert "intent" not in rejection_body
    assert rejection_body["model_provider"].strip().lower() == provider
    assert rejection_body["model_fallback_used"] is False

    conversation_payload = _payload()
    conversation_payload["meta"]["request_id"] = "verify_npc_npc_conversation_real"
    conversation_payload["current_round"] = 6
    conversation_payload["dialogue_state"]["current_round"] = 6
    conversation_payload["speaker_text"] = "诊所的分工已经说清了，我这边没有其他紧急或必要的事情。"
    conversation_payload["conversation_history"] = [
        {
            "speaker_id": "doctor_01",
            "speaker_name": conversation_payload["speaker_name"],
            "listener_id": "priest_01",
            "listener_name": conversation_payload["npc_name"],
            "text": conversation_payload["speaker_text"],
            "visibility": "private",
        },
        {
            "speaker_id": "priest_01",
            "speaker_name": conversation_payload["npc_name"],
            "listener_id": "doctor_01",
            "listener_name": conversation_payload["speaker_name"],
            "text": invitation.reply_text,
            "visibility": "private",
        },
    ]
    conversation_response = client.post("/npc/dialogue", json=conversation_payload)
    body = conversation_response.get_json()
    assert conversation_response.status_code == 200, body
    dialogue = NPCNPCDialogueResponse(**{
        key: value
        for key, value in body.items()
        if not key.startswith("model_")
    })
    assert dialogue.replyer_id == "priest_01"
    assert dialogue.response_kind == "reply_to_npc"
    assert dialogue.reply_text.strip()
    assert dialogue.invitation_result == "not_applicable"
    assert dialogue.should_end_dialogue is True, dialogue
    assert "intent" not in body
    assert "recruitment_result" not in body
    assert "wartime_reaction" not in body
    assert body["model_provider"].strip().lower() == provider
    assert body["model_provider"].strip().lower() != "mock"
    assert body["model_fallback_used"] is False

    resolved_cases = [
        {
            "request_id": "verify_npc_npc_no_repeat_blacksmith_round_1_real",
            "target_id": "veteran_deputy_01",
            "speaker_id": "blacksmith_01",
            "location_id": "blacksmith",
            "location_name": "铁匠铺",
            "current_round": 1,
            "speaker_text": "剑盾还剩最后一道装配打磨，大概一个时辰。你要等的话，炉子空出来我就叫你。",
            "history": [
                _turn(
                    "veteran_deputy_01",
                    "blacksmith_01",
                    "格伦，你还要多久完工？我可以等或者帮你一起做。",
                ),
            ],
        },
        {
            "request_id": "verify_npc_npc_no_repeat_blacksmith_real",
            "target_id": "veteran_deputy_01",
            "speaker_id": "blacksmith_01",
            "location_id": "blacksmith",
            "location_name": "铁匠铺",
            "current_round": 3,
            "speaker_text": "行，你等着吧。最后一道装配打磨，快了。",
            "history": [
                _turn(
                    "veteran_deputy_01",
                    "blacksmith_01",
                    "格伦，你还要多久完工？我可以等或者帮你一起做。",
                ),
                _turn(
                    "blacksmith_01",
                    "veteran_deputy_01",
                    "剑盾还剩最后一道装配打磨，大概一个时辰。你要等的话，炉子空出来我就叫你。",
                ),
                _turn(
                    "veteran_deputy_01",
                    "blacksmith_01",
                    "好，那我就在这儿等着。你专心把最后一道工序做完，炉子空出来我再上手。",
                ),
            ],
        },
        {
            "request_id": "verify_npc_npc_no_repeat_clinic_real",
            "target_id": "priest_01",
            "speaker_id": "doctor_01",
            "location_id": "clinic",
            "location_name": "小诊所",
            "current_round": 2,
            "speaker_text": "那就定了：伤员归我处理，你先回小教堂；诊所需要帮手时我再叫你。",
            "history": [
                _turn(
                    "priest_01",
                    "doctor_01",
                    "莉娜，需要我继续留在诊所帮忙，还是回小教堂？",
                ),
                _turn(
                    "doctor_01",
                    "priest_01",
                    "最急的伤口已经处理完，你可以回去；真缺人时我会去叫你。",
                ),
            ],
        },
        {
            "request_id": "verify_npc_npc_no_repeat_stable_real",
            "target_id": "stableman_01",
            "speaker_id": "veteran_deputy_01",
            "location_id": "stable",
            "location_name": "马厩",
            "current_round": 2,
            "speaker_text": "前半夜我让欧文巡马厩，后半夜你照看栗风；药膏由莉娜准备，就按这个安排。",
            "history": [
                _turn(
                    "stableman_01",
                    "veteran_deputy_01",
                    "栗风的蹄子要敷药，今晚后半夜我守着；前半夜得有人替我看一会儿。",
                ),
                _turn(
                    "veteran_deputy_01",
                    "stableman_01",
                    "我会安排欧文守前半夜，也让莉娜备好药膏。",
                ),
            ],
        },
    ]
    resolved_results = []
    for case in resolved_cases:
        resolved_payload = _payload()
        _set_participants(
            resolved_payload,
            str(case["target_id"]),
            str(case["speaker_id"]),
        )
        resolved_payload["meta"]["request_id"] = str(case["request_id"])
        resolved_payload["current_round"] = int(case["current_round"])
        resolved_payload["dialogue_state"]["current_round"] = int(case["current_round"])
        resolved_payload["dialogue_state"]["location_id"] = str(case["location_id"])
        resolved_payload["dialogue_state"]["location_name"] = str(case["location_name"])
        resolved_payload["npc_state"]["current_location"] = str(case["location_id"])
        resolved_payload["location_context"] = {
            "location_id": str(case["location_id"]),
            "location_name": str(case["location_name"]),
            "people_present": [str(case["speaker_id"]), str(case["target_id"])],
        }
        resolved_payload["speaker_text"] = str(case["speaker_text"])
        resolved_payload["conversation_history"] = list(case["history"])
        prior_texts = [
            str(turn["text"])
            for turn in resolved_payload["conversation_history"]
        ] + [str(resolved_payload["speaker_text"])]

        resolved_response = client.post("/npc/dialogue", json=resolved_payload)
        resolved_body = resolved_response.get_json()
        assert resolved_response.status_code == 200, resolved_body
        resolved_dialogue = NPCNPCDialogueResponse(**{
            key: value
            for key, value in resolved_body.items()
            if not key.startswith("model_")
        })
        similarity = _max_similarity(resolved_dialogue.reply_text, prior_texts)
        assert resolved_dialogue.should_end_dialogue is True, resolved_dialogue
        assert similarity < 0.82, {
            "request_id": case["request_id"],
            "reply_text": resolved_dialogue.reply_text,
            "max_similarity": similarity,
        }
        assert resolved_body["model_provider"].strip().lower() == provider
        assert resolved_body["model_provider"].strip().lower() != "mock"
        assert resolved_body["model_fallback_used"] is False
        resolved_results.append({
            "request_id": case["request_id"],
            "round": case["current_round"],
            "reply_text": resolved_dialogue.reply_text,
            "max_similarity": round(similarity, 3),
        })

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["summary"]["count"] == 3 + len(resolved_cases)
    assert usage["summary"]["failed"] == 0
    assert usage["records"][-1]["call_type"] == "dialogue"
    assert usage["records"][-1]["fallback_used"] is False

    print(
        "verify_npc_npc_dialogue_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} "
        f"invitation_result={invitation.invitation_result}/{rejection.invitation_result} "
        "formal_rounds=no_hard_limit soft_threshold=5 end_at_round_6=true "
        f"resolved_no_repeat={json.dumps(resolved_results, ensure_ascii=False)} "
        "response_kind=reply_to_npc fallback_used=false"
    )


if __name__ == "__main__":
    main()
