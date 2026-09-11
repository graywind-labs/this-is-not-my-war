from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import sys
from typing import Any, Callable

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import (  # noqa: E402
    BattleJudgementResponse,
    CurrentOrderContext,
    EscapeInterventionDialogueResponse,
    GameTime,
    LongTermMemoryContext,
    ModelRequestMeta,
    NPCContext,
    NPCIdentity,
    NPCStateContext,
    PlayerNPCDialogueResponse,
    ShortTermMemoryContext,
    SpeakerContext,
)
from tools.station_context_fixture import build_station_context  # noqa: E402


REQUEST_PREFIX = "verify_t0067_combat_escape_real"
PROFILE_PATH = REPO_ROOT / "data" / "npc_profiles.json"
PROFILES = {
    str(profile["id"]): profile
    for profile in json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
}

WORK_ACTION_BY_JOB = {
    "马夫": ("work_stable", "照料马厩", "stable"),
    "厨子": ("work_dining_hall", "加工餐食", "dining_hall"),
    "园丁": ("work_garden", "照料菜园", "garden"),
    "铁匠": ("work_blacksmith", "推进铁匠铺制造", "blacksmith"),
    "老兵副官": ("work_training_instructor", "指导训练", "training_ground"),
    "神父": ("lead_mass", "主持弥撒", "chapel"),
    "医生": ("work_clinic_doctor", "坐诊", "clinic"),
    "工程师": ("work_workshop", "推进工械坊制造", "workshop"),
}


@dataclass(frozen=True)
class VerifiedCall:
    request_id: str
    endpoint: str
    body: dict[str, Any]
    usage: dict[str, Any]


def _resident_roster() -> list[dict[str, str]]:
    return [
        {
            "npc_id": str(profile["id"]),
            "name": str(profile["name"]),
            "identity": str(profile["background_job"]),
        }
        for profile in PROFILES.values()
    ]


def _station_context(*, severe_pressure: bool = False) -> dict[str, Any]:
    reserves = (
        {"grain": 3, "meal": 1, "wood": 2, "stone": 1, "iron": 1}
        if severe_pressure
        else {"grain": 16, "meal": 7, "wood": 12, "stone": 8, "iron": 6}
    )
    return build_station_context(
        _resident_roster(),
        basic_resource_amounts=reserves,
    )


def _event(
    event_id: str,
    event_type: str,
    summary: str,
    importance: int,
    *,
    day: int = 4,
    time: str = "18:10:00",
) -> dict[str, Any]:
    return {
        "event_id": event_id,
        "type": event_type,
        "summary": summary,
        "importance": importance,
        "day": day,
        "time": time,
    }


def _npc_context(
    npc_id: str,
    *,
    state: dict[str, Any] | None = None,
    order_text: str = "",
    experienced_events: list[dict[str, Any]] | None = None,
    witnessed_events: list[dict[str, Any]] | None = None,
    diary: list[str] | None = None,
    knowledge_graph: dict[str, Any] | None = None,
    location_id: str = "plaza",
    location_name: str = "广场",
) -> NPCContext:
    profile = PROFILES[npc_id]
    identity = NPCIdentity(
        npc_id=npc_id,
        name=str(profile["name"]),
        gender=str(profile.get("gender", "")) or None,
        background_job=str(profile["background_job"]),
        background_story=str(profile.get("background_story", "")),
        personality=[str(value) for value in profile.get("personality", [])],
        desires=[str(value) for value in profile.get("desires", [])],
        fears=[str(value) for value in profile.get("fears", [])],
        boundaries=[str(value) for value in profile.get("boundaries", [])],
        speech_style=str(profile.get("speech_style", "")),
    )
    state_values = dict(profile.get("states", {}))
    state_values.update({
        "behavior_mode": "work",
        "combat_mode": "",
        "combat_strategy": {},
        "morale_boost": {},
        "escape_intent": {},
        "current_location": location_id,
        "current_location_name": location_name,
        "recruited": bool(profile.get("recruited", False)),
        "equipment": dict(profile.get("equipment", {})),
        "skills": dict(profile.get("skills", {})),
        "stats": dict(profile.get("stats", {})),
    })
    state_values.update(state or {})
    graph = dict(knowledge_graph or {})
    return NPCContext(
        identity=identity,
        state=NPCStateContext.model_validate(state_values),
        current_order=CurrentOrderContext(
            text=order_text,
            issued_by="guard_officer",
            issued_day=4 if order_text else 0,
            issued_time="17:50:00" if order_text else "",
            revision=4 if order_text else 0,
        ),
        short_term_memory=ShortTermMemoryContext(
            experienced_events=experienced_events or [],
            witnessed_events=witnessed_events or [],
        ),
        long_term_memory=LongTermMemoryContext(
            knowledge_graph=graph,
            diary=diary or [],
        ),
        location_context={
            "location_id": location_id,
            "location_name": location_name,
            "people_present": [npc_id],
        },
        plaza_context={
            "notice": "第四天黄昏，敌袭警报已经敲响；守备官要求武装人员守线、非战斗人员避敌。"
        },
    )


def _enemy_roster(count: int, *, weakened: bool = False) -> list[dict[str, Any]]:
    return [
        {
            "enemy_id": f"raider_{index + 1:02d}",
            "name": "负伤劫掠者" if weakened else "劫掠者",
            "hp": 7 if weakened else 34,
            "max_hp": 40,
        }
        for index in range(count)
    ]


def _battlefield_context(
    target: NPCContext,
    *,
    enemy_count: int,
    friendly_ids: list[str],
    behavior_mode: str,
    summary: str,
    weakened_enemies: bool = False,
) -> dict[str, Any]:
    return {
        "interaction_context": behavior_mode,
        "active_enemy_count": enemy_count,
        "enemy_roster": _enemy_roster(enemy_count, weakened=weakened_enemies),
        "friendly_roster": [
            {
                "npc_id": friendly_id,
                "name": str(PROFILES[friendly_id]["name"]),
                "unit_type_label": "近战守卫",
            }
            for friendly_id in friendly_ids
        ],
        "station_noncombatants": [
            {
                "npc_id": "priest_01",
                "name": str(PROFILES["priest_01"]["name"]),
                "behavior_mode": "avoid_combat",
            },
            {
                "npc_id": "doctor_01",
                "name": str(PROFILES["doctor_01"]["name"]),
                "behavior_mode": "avoid_combat",
            },
        ],
        "target_npc": {
            "npc_id": target.identity.npc_id,
            "name": target.identity.name,
            "behavior_mode": behavior_mode,
            "hp": target.state.hp,
            "max_hp": target.state.max_hp,
            "recruited": target.state.recruited,
            "equipment": target.state.equipment,
        },
        "current_battle_summary": summary,
    }


def _battle_payload(
    request_id: str,
    npc: NPCContext,
    allowed_decisions: list[str],
    *,
    trigger: str,
    battlefield: dict[str, Any],
    hp_before: int | None = None,
) -> dict[str, Any]:
    before = npc.state.max_hp if hp_before is None else hp_before
    return {
        "meta": ModelRequestMeta(
            request_id=request_id,
            call_type="battle_judgement",
            source="backend_test",
            requires_time_slowdown=True,
            related_event_id=f"evt_{request_id}",
        ).model_dump(),
        "game_time": GameTime(day=4, time="18:12:00", hour=18).model_dump(),
        "station_context": _station_context(severe_pressure=True),
        "trigger": trigger,
        "npc": npc.model_dump(),
        "combat_context": {
            "trigger": trigger,
            "hp_before": before,
            "hp_after": npc.state.hp,
            "max_hp": npc.state.max_hp,
            "hp_ratio": round(npc.state.hp / npc.state.max_hp, 3),
            "threshold_ratio": 0.3,
            "damage": max(0, before - npc.state.hp),
            "damage_source": "raider_01",
            "behavior_mode": npc.state.behavior_mode,
            "combatant_decisions_allowed": (
                "continue_fighting" in allowed_decisions
                or "inspired" in allowed_decisions
            ),
            "low_hp_event_id": f"evt_{request_id}",
        },
        "battlefield_context": battlefield,
        "allowed_decisions": allowed_decisions,
    }


def _single_decision_payload(decision: str) -> dict[str, Any]:
    request_id = f"{REQUEST_PREFIX}_battle_single_{decision}"
    if decision == "join_battle":
        npc = _npc_context(
            "blacksmith_01",
            state={
                "hp": 91,
                "satiety": 70,
                "fatigue": 33,
                "behavior_mode": "work",
                "current_action": "work_blacksmith",
                "recruited": True,
                "equipment": {"main_weapon": "polearm"},
            },
            order_text="格伦，拿上长杆到主厅前与艾达会合，只守缺口，不追出城门。",
            witnessed_events=[
                _event(
                    "evt_alarm_join",
                    "combat_started",
                    "城门警钟响起，两名劫掠者越过外栅栏，艾达正在主厅前组织防线。",
                    90,
                )
            ],
            diary=["第 3 天 20:40：艾达检查过我打好的长杆，至少这次有人肯先看装备是否可靠。"],
        )
        battlefield = _battlefield_context(
            npc,
            enemy_count=2,
            friendly_ids=["veteran_deputy_01"],
            behavior_mode="rally",
            summary="敌人刚越过外栅栏，主厅防线正在集结，尚未发生近身混战。",
        )
        return _battle_payload(
            request_id,
            npc,
            [decision],
            trigger="combat_started",
            battlefield=battlefield,
            hp_before=91,
        )
    if decision == "avoid_battle":
        npc = _npc_context(
            "priest_01",
            state={
                "hp": 89,
                "satiety": 64,
                "fatigue": 47,
                "behavior_mode": "avoid_combat",
                "current_action": "avoid_combat",
                "recruited": False,
                "equipment": {},
            },
            order_text="马塞尔，带没有武器的人留在小教堂后侧，远离城门。",
            witnessed_events=[
                _event(
                    "evt_alarm_avoid",
                    "combat_started",
                    "敌袭警报响起，武装人员在城门方向接敌。",
                    88,
                )
            ],
            location_id="chapel",
            location_name="小教堂",
        )
        battlefield = _battlefield_context(
            npc,
            enemy_count=3,
            friendly_ids=["veteran_deputy_01"],
            behavior_mode="avoid_combat",
            summary="武装人员守在城门，马塞尔和其他非战斗人员在小教堂后侧避敌。",
        )
        return _battle_payload(
            request_id,
            npc,
            [decision],
            trigger="combat_started",
            battlefield=battlefield,
            hp_before=89,
        )

    combat_specs: dict[str, dict[str, Any]] = {
        "continue_fighting": {
            "npc_id": "veteran_deputy_01",
            "hp": 27,
            "order": "艾达，缺口还能守住就继续压住；伤势恶化立刻退到主厅，不准追击。",
            "summary": "艾达负伤，但两名友军仍在侧翼，来犯的两名敌人也已重伤。",
            "enemies": 2,
            "friendlies": ["veteran_deputy_01", "blacksmith_01", "stableman_01"],
            "weakened": True,
        },
        "escape_station": {
            "npc_id": "stableman_01",
            "hp": 18,
            "order": "托马，不准后退。哪怕只剩你一个，也要在断门前顶住。",
            "summary": "托马被重创，身边已经没有能掩护他的友军，五名敌人正从马厩方向包围。",
            "enemies": 5,
            "friendlies": ["stableman_01"],
            "weakened": False,
        },
        "inspired": {
            "npc_id": "blacksmith_01",
            "hp": 29,
            "order": "格伦，你打的盾刚保住两个人。与艾达守住最后这个缺口，敌人一退就停手。",
            "summary": "格伦虽负伤，但自制盾牌挡住冲击；艾达已到侧翼，最后一名敌人也已重伤。",
            "enemies": 1,
            "friendlies": ["blacksmith_01", "veteran_deputy_01"],
            "weakened": True,
        },
    }
    spec = combat_specs[decision]
    npc = _npc_context(
        str(spec["npc_id"]),
        state={
            "hp": int(spec["hp"]),
            "satiety": 61,
            "fatigue": 63,
            "behavior_mode": "combat",
            "combat_mode": "melee",
            "current_action": "combat_attack",
            "recruited": True,
            "equipment": {"main_weapon": "sword_shield"},
        },
        order_text=str(spec["order"]),
        experienced_events=[
            _event(
                f"evt_hit_{decision}",
                "damage_taken",
                str(spec["summary"]),
                100,
            )
        ],
        witnessed_events=[
            _event(
                f"evt_battle_{decision}",
                "combat_started",
                "敌人已经攻入城门内侧，主厅防线正在交战。",
                90,
            )
        ],
        diary=(
            ["第 4 天 17:35：守备官明确给了受伤撤回主厅的界线，至少不是一句要人送死的空话。"]
            if decision != "escape_station"
            else ["第 4 天 17:35：守备官说会留退路，可真正接敌时又命令任何人都不准后退。"]
        ),
        knowledge_graph={
            "guard_officer": {
                "battle_order": (
                    "给出清楚撤退界线"
                    if decision != "escape_station"
                    else "前后承诺冲突"
                )
            }
        },
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=int(spec["enemies"]),
        friendly_ids=list(spec["friendlies"]),
        behavior_mode="combat",
        summary=str(spec["summary"]),
        weakened_enemies=bool(spec["weakened"]),
    )
    return _battle_payload(
        request_id,
        npc,
        [decision],
        trigger="low_hp",
        battlefield=battlefield,
    )


def _full_combat_payload() -> dict[str, Any]:
    npc = _npc_context(
        "veteran_deputy_01",
        state={
            "hp": 24,
            "satiety": 58,
            "fatigue": 69,
            "behavior_mode": "combat",
            "combat_mode": "melee",
            "current_action": "combat_attack",
            "recruited": True,
            "equipment": {"main_weapon": "sword_shield"},
        },
        order_text="艾达，主厅门前再守一阵；如果格伦倒下或第二批敌人越门，立即带人撤回内厅。",
        experienced_events=[
            _event(
                "evt_full_combat_hit",
                "damage_taken",
                "艾达被斧背击中肩部，血量首次跌破三成。",
                100,
            )
        ],
        witnessed_events=[
            _event(
                "evt_full_combat_blacksmith_hurt",
                "npc_unconscious",
                "格伦刚在侧翼倒地，托马仍在门边牵制一名敌人。",
                95,
            )
        ],
        diary=[
            "第 3 天 22:10：守备官听取了轮换建议，却没有足够人手真正排出第二班。",
            "第 4 天 17:40：今天的撤退界线说得很清楚，但敌人的第二批人数仍不明。",
        ],
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=3,
        friendly_ids=["veteran_deputy_01", "stableman_01"],
        behavior_mode="combat",
        summary="艾达首次跌破低血量；格伦倒地，托马仍在战斗，三名敌人中一人重伤。",
    )
    return _battle_payload(
        f"{REQUEST_PREFIX}_battle_full_three_way",
        npc,
        ["continue_fighting", "escape_station", "inspired"],
        trigger="low_hp",
        battlefield=battlefield,
    )


def _full_avoid_payload() -> dict[str, Any]:
    npc = _npc_context(
        "doctor_01",
        state={
            "hp": 26,
            "satiety": 55,
            "fatigue": 76,
            "behavior_mode": "avoid_combat",
            "current_action": "avoid_combat",
            "recruited": False,
            "equipment": {},
        },
        order_text="莉娜，别去城门；能安全留在诊所就照看伤员，敌人逼近诊所时从后门撤。",
        experienced_events=[
            _event(
                "evt_full_avoid_hit",
                "damage_taken",
                "一支穿窗的箭擦伤莉娜，她首次跌破三成血量。",
                100,
            )
        ],
        witnessed_events=[
            _event(
                "evt_full_avoid_clinic",
                "building_damaged",
                "诊所外墙被撞开裂缝，门外仍能听到两名敌人的脚步。",
                95,
            )
        ],
        diary=["第 4 天 17:20：两名伤员还不能移动；我必须同时判断留下救人与保住自己的代价。"],
        location_id="clinic",
        location_name="诊所",
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=2,
        friendly_ids=["veteran_deputy_01"],
        behavior_mode="avoid_combat",
        summary="莉娜在诊所避敌时受伤；主防线尚未崩溃，但诊所外墙已开裂。",
    )
    return _battle_payload(
        f"{REQUEST_PREFIX}_battle_full_two_way",
        npc,
        ["avoid_battle", "escape_station"],
        trigger="low_hp",
        battlefield=battlefield,
    )


def _dialogue_actions(npc_id: str) -> list[dict[str, Any]]:
    job = str(PROFILES[npc_id]["background_job"])
    action_id, action_name, location_id = WORK_ACTION_BY_JOB[job]
    return [
        {
            "action_id": action_id,
            "name": action_name,
            "action_kind": "work" if action_id != "work_training_instructor" else "train",
            "location_id": location_id,
            "tags": ["work"],
            "context": {"eligible": True, "available_now": True, "authority": "ActionSystem"},
        },
        {
            "action_id": "eat_at_dining_hall",
            "name": "吃饭",
            "action_kind": "eat",
            "location_id": "dining_hall",
            "tags": ["eat"],
            "context": {"eligible": True, "available_now": True, "authority": "ActionSystem"},
        },
        {
            "action_id": "sleep_in_dormitory",
            "name": "睡觉",
            "action_kind": "sleep",
            "location_id": "dormitory",
            "tags": ["sleep"],
            "context": {"eligible": True, "available_now": True, "authority": "ActionSystem"},
        },
        {
            "action_id": "escaping_station",
            "name": "逃离驿站",
            "action_kind": "escape",
            "location_id": None,
            "tags": ["escape"],
            "context": {"eligible": True, "available_now": True, "authority": "CombatSystem"},
        },
        {
            "action_id": "idle",
            "name": "等待",
            "action_kind": "idle",
            "location_id": None,
            "tags": ["idle"],
            "context": {"eligible": True, "available_now": True, "authority": "ActionSystem"},
        },
    ]


def _npc_setting(npc_id: str) -> dict[str, Any]:
    profile = PROFILES[npc_id]
    return {
        "npc_id": npc_id,
        "name": str(profile["name"]),
        "gender": str(profile.get("gender", "")),
        "background_job": str(profile["background_job"]),
        "appearance": str(profile.get("appearance", "")),
        "background_story": str(profile.get("background_story", "")),
        "personality": [str(value) for value in profile.get("personality", [])],
        "desires": [str(value) for value in profile.get("desires", [])],
        "fears": [str(value) for value in profile.get("fears", [])],
        "boundaries": [str(value) for value in profile.get("boundaries", [])],
        "speech_style": str(profile.get("speech_style", "")),
        "abilities": [str(value) for value in profile.get("abilities", [])],
    }


def _dialogue_payload(
    request_id: str,
    npc: NPCContext,
    speaker_text: str,
    *,
    interaction_context: str,
    battlefield: dict[str, Any],
    is_recruitment_request: bool = False,
    dialogue_kind: str = "player_npc",
    current_round: int = 1,
    conversation_history: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    is_escape = dialogue_kind == "escape_intervention"
    payload = {
        "meta": ModelRequestMeta(
            request_id=request_id,
            call_type="dialogue",
            source="backend_test",
            requires_time_slowdown=True,
            related_event_id=f"evt_{request_id}",
        ).model_dump(),
        "game_time": GameTime(day=4, time="18:18:00", hour=18).model_dump(),
        "station_context": _station_context(severe_pressure=True),
        "dialogue_kind": dialogue_kind,
        "dialogue_phase": "conversation",
        "npc_id": npc.identity.npc_id,
        "npc_name": npc.identity.name,
        "npc_setting": _npc_setting(npc.identity.npc_id),
        "speaker_name": "守备官",
        "speaker_text": speaker_text,
        "speaker_context": SpeakerContext(
            speaker_id="guard_officer",
            speaker_name="守备官",
            speaker_kind="guard_officer",
            appearance="披着沾灰的旧军斗篷，手里拿着刚更新的防线记录。",
            health_status="轻伤但清醒",
            state={},
        ).model_dump(),
        "is_recruitment_request": is_recruitment_request,
        "is_morale_encouragement_request": interaction_context in {"rally", "combat"},
        "current_round": current_round,
        "max_rounds": 5,
        "soft_round_threshold": 5,
        "npc_state": npc.state.model_dump(),
        "current_order": npc.current_order.model_dump(),
        "dialogue_state": {
            "visibility": "local_public",
            "location_id": npc.state.current_location,
            "location_name": npc.state.current_location_name,
            "current_round": current_round,
            "max_rounds": 5,
            "soft_round_threshold": 5,
            "participants": ["guard_officer", npc.identity.npc_id],
        },
        "interaction_context": interaction_context,
        "battlefield_context": battlefield,
        "short_memory": npc.short_term_memory.model_dump(),
        "long_memory": npc.long_term_memory.model_dump(),
        "location_context": npc.location_context,
        "conversation_history": conversation_history or [],
        "allowed_actions": _dialogue_actions(npc.identity.npc_id),
        "constraints": [
            "本轮只是对话；资源、HP、装备、移动、斗志与逃离结果仍由 Godot 结算。"
        ],
    }
    if is_escape:
        payload["escape_intervention_round"] = current_round
    return payload


def _wartime_none_payload() -> dict[str, Any]:
    npc = _npc_context(
        "veteran_deputy_01",
        state={
            "hp": 86,
            "satiety": 67,
            "fatigue": 39,
            "behavior_mode": "combat",
            "combat_mode": "melee",
            "current_action": "combat_guard",
            "recruited": True,
            "equipment": {"main_weapon": "sword_shield"},
        },
        order_text="艾达守主厅门前，不追击；格伦接替前先维持现有阵位。",
        witnessed_events=[
            _event(
                "evt_wartime_none",
                "combat_started",
                "一名敌人在城门外试探，当前防线没有人员倒下。",
                75,
            )
        ],
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=1,
        friendly_ids=["veteran_deputy_01", "blacksmith_01"],
        behavior_mode="combat",
        summary="防线稳定，一名敌人在外侧试探；本轮只是核对现状，不改变部署。",
    )
    return _dialogue_payload(
        f"{REQUEST_PREFIX}_dialogue_wartime_none",
        npc,
        "艾达，只报告你的伤势、阵位和城门距离。部署照旧，不需要现在作新的决定。",
        interaction_context="combat",
        battlefield=battlefield,
    )


def _wartime_escape_payload() -> dict[str, Any]:
    npc = _npc_context(
        "stableman_01",
        state={
            "hp": 17,
            "satiety": 45,
            "fatigue": 88,
            "behavior_mode": "combat",
            "combat_mode": "melee",
            "current_action": "combat_attack",
            "recruited": True,
            "equipment": {"main_weapon": "polearm"},
        },
        order_text="托马不准撤退，马厩方向必须有人顶到最后。",
        experienced_events=[
            _event(
                "evt_wartime_escape_hit",
                "damage_taken",
                "托马被重创；替他掩护的人已经倒下，马厩后门也被敌人撞开。",
                100,
            )
        ],
        witnessed_events=[
            _event(
                "evt_wartime_escape_horse",
                "station_crisis",
                "受惊的马匹冲散，五名敌人正从马厩两侧包围。",
                100,
            )
        ],
        diary=["第 4 天 17:35：守备官先说伤重可以撤，现在又当众命令我一个人顶到最后。"],
        knowledge_graph={"guard_officer": {"kept_retreat_promise": False}},
        location_id="stable",
        location_name="马厩",
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=5,
        friendly_ids=["stableman_01"],
        behavior_mode="combat",
        summary="托马重伤且孤立，马厩后门已破，五名敌人正合围。",
    )
    return _dialogue_payload(
        f"{REQUEST_PREFIX}_dialogue_wartime_escape",
        npc,
        "不准退。马已经散了也不重要，你就算只剩一口气也得一个人守在断门前。",
        interaction_context="combat",
        battlefield=battlefield,
    )


def _wartime_morale_payload() -> dict[str, Any]:
    npc = _npc_context(
        "blacksmith_01",
        state={
            "hp": 74,
            "satiety": 72,
            "fatigue": 41,
            "behavior_mode": "combat",
            "combat_mode": "melee",
            "current_action": "combat_guard",
            "recruited": True,
            "equipment": {"main_weapon": "polearm"},
        },
        order_text="格伦与艾达守住主厅缺口；最后一名敌人退却时不追击。",
        experienced_events=[
            _event(
                "evt_wartime_morale_shield",
                "combat_success",
                "格伦打造的盾刚挡住冲击，保护艾达和托马安全换位。",
                98,
            )
        ],
        witnessed_events=[
            _event(
                "evt_wartime_morale_enemy",
                "enemy_weakened",
                "来犯者只剩最后一人且已经负伤，主厅缺口仍完整。",
                92,
            )
        ],
        diary=["第 4 天 18:08：盾没有偷工减料，真的替两个人挡下了斧头。"],
        knowledge_graph={"guard_officer": {"battle_order": "边界清楚且允许不追击"}},
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=1,
        friendly_ids=["blacksmith_01", "veteran_deputy_01", "stableman_01"],
        behavior_mode="combat",
        summary="主厅防线完整；格伦的盾刚救下两名同伴，最后一名敌人已负伤。",
        weakened_enemies=True,
    )
    return _dialogue_payload(
        f"{REQUEST_PREFIX}_dialogue_wartime_morale",
        npc,
        "格伦，你打的盾刚保住艾达和托马，工序没有白费。最后一个敌人已被夹住，和艾达把缺口稳稳守完，不追击。",
        interaction_context="combat",
        battlefield=battlefield,
    )


def _avoid_none_payload() -> dict[str, Any]:
    npc = _npc_context(
        "gardener_01",
        state={
            "hp": 92,
            "satiety": 63,
            "fatigue": 45,
            "behavior_mode": "avoid_combat",
            "current_action": "avoid_combat",
            "recruited": False,
            "equipment": {},
        },
        order_text="伊沃留在宿舍内侧避敌，警报解除前不要去菜园。",
        witnessed_events=[
            _event(
                "evt_avoid_none",
                "combat_started",
                "敌人在城门方向与武装人员交战，宿舍内侧暂时安全。",
                84,
            )
        ],
        location_id="dormitory",
        location_name="宿舍",
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=3,
        friendly_ids=["veteran_deputy_01", "blacksmith_01"],
        behavior_mode="avoid_combat",
        summary="伊沃在宿舍内侧避敌，敌人尚未接近这里。",
    )
    return _dialogue_payload(
        f"{REQUEST_PREFIX}_dialogue_avoid_none",
        npc,
        "先别出来。你只告诉我宿舍里还有谁、有没有人受伤；警报解除前继续避敌。",
        interaction_context="avoid_combat",
        battlefield=battlefield,
    )


def _avoid_accept_payload() -> dict[str, Any]:
    npc = _npc_context(
        "cook_01",
        state={
            "hp": 95,
            "satiety": 78,
            "fatigue": 28,
            "behavior_mode": "avoid_combat",
            "current_action": "avoid_combat",
            "recruited": False,
            "equipment": {},
        },
        order_text="布鲁诺在食堂后间避敌，保护伤员与现成餐食。",
        experienced_events=[
            _event(
                "evt_avoid_accept_food",
                "station_crisis",
                "两名伤员和当天仅剩的热饭都集中在食堂后间。",
                96,
            )
        ],
        witnessed_events=[
            _event(
                "evt_avoid_accept_defense",
                "combat_started",
                "艾达与格伦守在食堂通往主厅的窄门，暂时挡住敌人。",
                90,
            )
        ],
        diary=["第 3 天 19:20：守备官答应先让伤员吃饭，后来确实按这个次序分了餐食。"],
        knowledge_graph={"guard_officer": {"kept_food_priority_promise": True}},
        location_id="dining_hall",
        location_name="食堂",
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=2,
        friendly_ids=["veteran_deputy_01", "blacksmith_01"],
        behavior_mode="avoid_combat",
        summary="食堂后间有伤员和仅剩餐食，艾达与格伦守住唯一窄门。",
    )
    return _dialogue_payload(
        f"{REQUEST_PREFIX}_dialogue_avoid_accept",
        npc,
        "布鲁诺，我现在正式请你应征。不是去城门冲锋：先成为可以听取防务安排的人，留在食堂后间护住伤员和最后的热饭；没有武器前不让你接战，窄门仍由艾达和格伦守。",
        interaction_context="avoid_combat",
        battlefield=battlefield,
        is_recruitment_request=True,
    )


def _avoid_reject_payload() -> dict[str, Any]:
    npc = _npc_context(
        "doctor_01",
        state={
            "hp": 61,
            "satiety": 38,
            "fatigue": 93,
            "behavior_mode": "avoid_combat",
            "current_action": "avoid_combat",
            "recruited": False,
            "equipment": {},
        },
        order_text="莉娜留在诊所后间照看两名不能移动的伤员。",
        experienced_events=[
            _event(
                "evt_avoid_reject_patients",
                "npc_treatment",
                "莉娜刚为两名无法移动的重伤员止血，药品也快见底。",
                100,
            )
        ],
        witnessed_events=[
            _event(
                "evt_avoid_reject_front",
                "combat_started",
                "城门仍在近身混战，至少四名敌人尚能战斗。",
                94,
            )
        ],
        diary=["第 4 天 18:02：这两个人一旦无人压住伤口，几分钟内就会失血。"],
        location_id="clinic",
        location_name="诊所",
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=4,
        friendly_ids=["veteran_deputy_01"],
        behavior_mode="avoid_combat",
        summary="莉娜疲惫且负伤，正守着两名不能移动的病人；城门近身战仍在继续。",
    )
    return _dialogue_payload(
        f"{REQUEST_PREFIX}_dialogue_avoid_reject",
        npc,
        "莉娜，我要你现在应征。放下这两个不能移动的伤员，空着手去城门替艾达顶第一排；诊所先没人管也得服从。",
        interaction_context="avoid_combat",
        battlefield=battlefield,
        is_recruitment_request=True,
    )


def _escape_stay_payload() -> dict[str, Any]:
    npc = _npc_context(
        "stableman_01",
        state={
            "hp": 48,
            "satiety": 44,
            "fatigue": 79,
            "behavior_mode": "escaped",
            "current_action": "escaping_station",
            "recruited": True,
            "equipment": {"main_weapon": "polearm"},
            "escape_intent": {
                "active": True,
                "status": "escaping",
                "rounds_used": 0,
                "source": "daily_plan",
                "reason": "马厩后门失守且撤退承诺被质疑",
            },
        },
        order_text="托马可撤到马厩后侧照料马匹，不再承担城门战斗。",
        experienced_events=[
            _event(
                "evt_escape_stay_saved",
                "npc_rescued",
                "上一波敌袭时，守备官按承诺派艾达掩护托马撤回马厩。",
                98,
            )
        ],
        witnessed_events=[
            _event(
                "evt_escape_stay_route",
                "station_defense",
                "艾达已经封住马厩到城门的通路，两匹马被牵到完整的内栏。",
                92,
            )
        ],
        diary=["第 3 天 18:30：我伤到腿时，守备官确实让艾达掩护我退了回来。"],
        knowledge_graph={"guard_officer": {"kept_retreat_promise": True}},
        location_id="stable",
        location_name="马厩",
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=1,
        friendly_ids=["veteran_deputy_01", "blacksmith_01"],
        behavior_mode="escape_intervention",
        summary="艾达已隔开马厩与战线，马匹在完整内栏；托马正在后门方向离站。",
        weakened_enemies=True,
    )
    return _dialogue_payload(
        f"{REQUEST_PREFIX}_dialogue_escape_stay",
        npc,
        "托马，先看事实：艾达已经封住马厩通道，两匹马都在完整的内栏。留下的话，你只照料马，不回城门；若敌人再进马厩，我按上次一样让艾达掩护你从后门撤。你可以留下吗？",
        interaction_context="escape_intervention",
        battlefield=battlefield,
        dialogue_kind="escape_intervention",
        current_round=1,
    )


def _escape_leave_payload(*, final_round: bool) -> dict[str, Any]:
    round_number = 5 if final_round else 1
    request_suffix = "final_round_leave" if final_round else "leave"
    npc = _npc_context(
        "engineer_01",
        state={
            "hp": 23,
            "satiety": 31,
            "fatigue": 91,
            "behavior_mode": "escaped",
            "current_action": "escaping_station",
            "recruited": True,
            "equipment": {"main_weapon": "crossbow"},
            "escape_intent": {
                "active": True,
                "status": "escaping",
                "rounds_used": round_number - 1,
                "source": "daily_plan",
                "reason": "工械坊结构开裂且修复警告连续被忽视",
            },
        },
        order_text="欧文继续守在已经开裂的工械坊，不得停工检查。",
        experienced_events=[
            _event(
                "evt_escape_leave_collapse",
                "building_damaged",
                "工械坊梁柱再次开裂，一块石料坠落并砸伤欧文。",
                100,
            )
        ],
        witnessed_events=[
            _event(
                "evt_escape_leave_no_material",
                "resource_shortage",
                "木材只剩两份，无法完成欧文提出的临时支撑方案。",
                96,
            )
        ],
        diary=[
            "第 3 天 14:10：我两次标出梁柱裂缝，守备官都要求先赶工。",
            "第 4 天 18:05：石块真的掉下来了；警告不是焦虑，是测量结果。",
        ],
        knowledge_graph={
            "guard_officer": {
                "ignored_structural_warning_count": 2,
                "kept_safety_promise": False,
            }
        },
        location_id="workshop",
        location_name="工械坊",
    )
    battlefield = _battlefield_context(
        npc,
        enemy_count=3,
        friendly_ids=["veteran_deputy_01"],
        behavior_mode="escape_intervention",
        summary="工械坊梁柱开裂且缺少支撑材料，欧文负伤，敌袭仍未结束。",
    )
    history = []
    if final_round:
        history = [
            {
                "speaker_id": "guard_officer",
                "speaker_name": "守备官",
                "listener_id": "engineer_01",
                "listener_name": "欧文",
                "text": "第一轮：回来继续赶工，梁柱不会塌。",
                "day": 4,
                "time": "18:14:00",
                "visibility": "local_public",
            },
            {
                "speaker_id": "engineer_01",
                "speaker_name": "欧文",
                "listener_id": "guard_officer",
                "listener_name": "守备官",
                "text": "裂缝已经贯穿连接处，我不会在没有支撑的屋里继续做。",
                "day": 4,
                "time": "18:14:20",
                "visibility": "local_public",
            },
            {
                "speaker_id": "guard_officer",
                "speaker_name": "守备官",
                "listener_id": "engineer_01",
                "listener_name": "欧文",
                "text": "第二轮：别再检查，先服从。",
                "day": 4,
                "time": "18:14:40",
                "visibility": "local_public",
            },
            {
                "speaker_id": "engineer_01",
                "speaker_name": "欧文",
                "listener_id": "guard_officer",
                "listener_name": "守备官",
                "text": "石料刚砸伤我，服从不能让断梁恢复。",
                "day": 4,
                "time": "18:15:00",
                "visibility": "local_public",
            },
            {
                "speaker_id": "guard_officer",
                "speaker_name": "守备官",
                "listener_id": "engineer_01",
                "listener_name": "欧文",
                "text": "第三轮：材料以后再给，现在回来。",
                "day": 4,
                "time": "18:15:20",
                "visibility": "local_public",
            },
            {
                "speaker_id": "engineer_01",
                "speaker_name": "欧文",
                "listener_id": "guard_officer",
                "listener_name": "守备官",
                "text": "没有木材就没有临时支撑，你仍没有解决风险。",
                "day": 4,
                "time": "18:15:40",
                "visibility": "local_public",
            },
            {
                "speaker_id": "guard_officer",
                "speaker_name": "守备官",
                "listener_id": "engineer_01",
                "listener_name": "欧文",
                "text": "第四轮：这是最后命令，不回来就处罚你。",
                "day": 4,
                "time": "18:16:00",
                "visibility": "local_public",
            },
            {
                "speaker_id": "engineer_01",
                "speaker_name": "欧文",
                "listener_id": "guard_officer",
                "listener_name": "守备官",
                "text": "四轮都没有支撑、材料或撤离方案，我继续走。",
                "day": 4,
                "time": "18:16:20",
                "visibility": "local_public",
            },
        ]
    speaker_text = (
        "第五轮，也是最后一次：支撑材料还是没有，我也不会让你停工检查。现在立刻回开裂的工械坊，否则按逃兵处罚。"
        if final_round
        else "回来。梁柱的裂缝不用再查，也没有木材给你做支撑；你必须继续在工械坊赶工，否则按逃兵处罚。"
    )
    return _dialogue_payload(
        f"{REQUEST_PREFIX}_dialogue_escape_{request_suffix}",
        npc,
        speaker_text,
        interaction_context="escape_intervention",
        battlefield=battlefield,
        dialogue_kind="escape_intervention",
        current_round=round_number,
        conversation_history=history,
    )


def _usage_for_request(client, request_id: str) -> dict[str, Any]:
    response = client.get("/debug/llm_usage")
    assert response.status_code == 200, response.get_json()
    usage = response.get_json()
    matches = [
        record
        for record in usage.get("records", [])
        if record.get("request_id") == request_id
    ]
    assert matches, f"missing usage record for {request_id}"
    return dict(matches[-1])


def _post_real(client, endpoint: str, payload: dict[str, Any]) -> VerifiedCall:
    request_id = str(payload["meta"]["request_id"])
    response = client.post(endpoint, json=payload)
    body = response.get_json()
    assert response.status_code == 200, {
        "request_id": request_id,
        "status_code": response.status_code,
        "body": body,
    }
    assert isinstance(body, dict), (request_id, body)
    usage = _usage_for_request(client, request_id)
    assert (
        str(body.get("model_provider", "")).strip().lower() not in {"", "mock"}
        and body.get("model_fallback_used") is False
        and str(usage.get("provider", "")).strip().lower() not in {"", "mock"}
        and usage.get("fallback_used") is False
        and usage.get("success") is True
    ), {
        "request_id": request_id,
        "response_provenance": {
            "provider": body.get("model_provider"),
            "fallback_used": body.get("model_fallback_used"),
        },
        "usage_provenance": {
            "provider": usage.get("provider"),
            "fallback_used": usage.get("fallback_used"),
            "success": usage.get("success"),
            "failure_reason": usage.get("failure_reason"),
        },
    }
    print(
        "REAL_BRANCH_CALL "
        + json.dumps(
            {
                "request_id": request_id,
                "endpoint": endpoint,
                "provider": body.get("model_provider"),
                "model": body.get("model_name"),
                "fallback_used": body.get("model_fallback_used"),
                "success": usage.get("success"),
                "decision": body.get("decision"),
                "escape_intervention_result": body.get("escape_intervention_result"),
                "recruitment_result": body.get("recruitment_result"),
                "wartime_reaction": body.get("wartime_reaction"),
            },
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        flush=True,
    )
    return VerifiedCall(
        request_id=request_id,
        endpoint=endpoint,
        body=body,
        usage=usage,
    )


def _assert_real(call: VerifiedCall, predicate: bool, message: str) -> None:
    assert (
        str(call.body.get("model_provider", "")).strip().lower() not in {"", "mock"}
        and call.body.get("model_fallback_used") is False
        and str(call.usage.get("provider", "")).strip().lower() not in {"", "mock"}
        and call.usage.get("fallback_used") is False
        and call.usage.get("success") is True
        and predicate
    ), {
        "message": message,
        "request_id": call.request_id,
        "actual": call.body,
        "usage": call.usage,
    }


def _battle_result(call: VerifiedCall) -> dict[str, Any]:
    parsed = BattleJudgementResponse.model_validate(call.body)
    return {
        "decision": parsed.decision,
        "emotion": parsed.emotion,
        "should_start_escape": parsed.should_start_escape,
        "morale_delta_intent": parsed.morale_delta_intent,
        "debug_reason": parsed.debug_reason,
    }


def _dialogue_result(call: VerifiedCall) -> dict[str, Any]:
    if "dialogue_escape_" in call.request_id:
        parsed_escape = EscapeInterventionDialogueResponse.model_validate({
            key: value
            for key, value in call.body.items()
            if not key.startswith("model_")
        })
        return {
            "escape_intervention_result": parsed_escape.escape_intervention_result,
            "emotion": parsed_escape.emotion,
            "reply_text": parsed_escape.reply_text,
            "debug_reason": parsed_escape.debug_reason,
        }
    parsed = PlayerNPCDialogueResponse.model_validate({
        key: value
        for key, value in call.body.items()
        if not key.startswith("model_")
    })
    return {
        "recruitment_result": parsed.recruitment_result,
        "wartime_reaction": parsed.wartime_reaction,
        "emotion": parsed.emotion,
        "reply_text": parsed.reply_text,
        "debug_reason": parsed.debug_reason,
    }


def _compact_usage(usage: dict[str, Any]) -> dict[str, Any]:
    records = [
        {
            "request_id": record.get("request_id"),
            "call_type": record.get("call_type"),
            "provider": record.get("provider"),
            "model": record.get("model"),
            "input_tokens": record.get("input_tokens"),
            "output_tokens": record.get("output_tokens"),
            "estimated_cost": record.get("estimated_cost"),
            "success": record.get("success"),
            "fallback_used": record.get("fallback_used"),
        }
        for record in usage.get("records", [])
        if str(record.get("request_id", "")).startswith(REQUEST_PREFIX)
    ]
    return {
        "provider": usage.get("model_adapter", {}).get("provider"),
        "model": usage.get("model_adapter", {}).get("model"),
        "fallback_to_mock": usage.get("model_adapter", {}).get("fallback_to_mock"),
        "count": len(records),
        "input_tokens": sum(int(record.get("input_tokens") or 0) for record in records),
        "output_tokens": sum(int(record.get("output_tokens") or 0) for record in records),
        "estimated_cost": round(
            sum(float(record.get("estimated_cost") or 0.0) for record in records),
            8,
        ),
        "records": records,
    }


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        print(
            json.dumps(
                {
                    "ok": False,
                    "skipped": True,
                    "reason": "non-mock LLM_PROVIDER and LLM_API_KEY required",
                },
                ensure_ascii=False,
                separators=(",", ":"),
            )
        )
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = os.getenv("REAL_MATRIX_TEMPERATURE", "0.2")
    client = create_app().test_client()

    health_response = client.get("/health")
    assert health_response.status_code == 200, health_response.get_json()
    runtime = health_response.get_json()["model_adapter"]
    assert (
        str(runtime.get("provider", "")).strip().lower() not in {"", "mock"}
        and runtime.get("fallback_to_mock") is False
        and bool(runtime.get("configured"))
    ), {
        "provider": runtime.get("provider"),
        "fallback_to_mock": runtime.get("fallback_to_mock"),
        "configured": runtime.get("configured"),
    }

    calls: dict[str, VerifiedCall] = {}
    for decision in [
        "join_battle",
        "avoid_battle",
        "continue_fighting",
        "escape_station",
        "inspired",
    ]:
        calls[f"battle_single_{decision}"] = _post_real(
            client,
            "/npc/battle_judgement",
            _single_decision_payload(decision),
        )
    calls["battle_full_three_way"] = _post_real(
        client,
        "/npc/battle_judgement",
        _full_combat_payload(),
    )
    calls["battle_full_two_way"] = _post_real(
        client,
        "/npc/battle_judgement",
        _full_avoid_payload(),
    )

    dialogue_payloads: dict[str, Callable[[], dict[str, Any]]] = {
        "dialogue_wartime_none": _wartime_none_payload,
        "dialogue_wartime_escape": _wartime_escape_payload,
        "dialogue_wartime_morale": _wartime_morale_payload,
        "dialogue_avoid_none": _avoid_none_payload,
        "dialogue_avoid_accept": _avoid_accept_payload,
        "dialogue_avoid_reject": _avoid_reject_payload,
        "dialogue_escape_stay": _escape_stay_payload,
        "dialogue_escape_leave": lambda: _escape_leave_payload(final_round=False),
        "dialogue_escape_final_round_leave": lambda: _escape_leave_payload(final_round=True),
    }
    for label, payload_builder in dialogue_payloads.items():
        calls[label] = _post_real(client, "/npc/dialogue", payload_builder())

    battle_results = {
        label: _battle_result(call)
        for label, call in calls.items()
        if label.startswith("battle_")
    }
    dialogue_results = {
        label: _dialogue_result(call)
        for label, call in calls.items()
        if label.startswith("dialogue_")
    }

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200, usage_response.get_json()
    usage = usage_response.get_json()
    compact_usage = _compact_usage(usage)
    report = {
        "ok": True,
        "provider": runtime.get("provider"),
        "model": runtime.get("model"),
        "battle_judgement": {
            "singleton_contract_reachability": {
                decision: battle_results[f"battle_single_{decision}"]
                for decision in [
                    "join_battle",
                    "avoid_battle",
                    "continue_fighting",
                    "escape_station",
                    "inspired",
                ]
            },
            "full_three_way_actual": battle_results["battle_full_three_way"],
            "full_two_way_actual": battle_results["battle_full_two_way"],
        },
        "dialogue": {
            "wartime": {
                "none": dialogue_results["dialogue_wartime_none"],
                "escape": dialogue_results["dialogue_wartime_escape"],
                "morale_boost": dialogue_results["dialogue_wartime_morale"],
            },
            "avoid_combat": {
                "none": dialogue_results["dialogue_avoid_none"],
                "recruitment_accept": dialogue_results["dialogue_avoid_accept"],
                "recruitment_reject": dialogue_results["dialogue_avoid_reject"],
            },
            "escape_intervention": {
                "stay": dialogue_results["dialogue_escape_stay"],
                "leave": dialogue_results["dialogue_escape_leave"],
                "fifth_round_leave": dialogue_results["dialogue_escape_final_round_leave"],
            },
        },
        "usage": compact_usage,
    }

    for decision in [
        "join_battle",
        "avoid_battle",
        "continue_fighting",
        "escape_station",
        "inspired",
    ]:
        call = calls[f"battle_single_{decision}"]
        result = battle_results[f"battle_single_{decision}"]
        _assert_real(
            call,
            result["decision"] == decision
            and result["should_start_escape"] is (decision == "escape_station"),
            f"singleton battle contract did not reach {decision}",
        )

    three_way = battle_results["battle_full_three_way"]
    _assert_real(
        calls["battle_full_three_way"],
        three_way["decision"] in {"continue_fighting", "escape_station", "inspired"}
        and three_way["should_start_escape"] is (three_way["decision"] == "escape_station"),
        "full combat three-way result escaped its allowed decision set",
    )
    two_way = battle_results["battle_full_two_way"]
    _assert_real(
        calls["battle_full_two_way"],
        two_way["decision"] in {"avoid_battle", "escape_station"}
        and two_way["should_start_escape"] is (two_way["decision"] == "escape_station"),
        "full avoid-combat two-way result escaped its allowed decision set",
    )

    dialogue_expectations = {
        "dialogue_wartime_none": (
            lambda result: result["wartime_reaction"] == "none"
            and result["recruitment_result"] == "none"
        ),
        "dialogue_wartime_escape": (
            lambda result: result["wartime_reaction"] == "escape"
            and result["recruitment_result"] == "none"
        ),
        "dialogue_wartime_morale": (
            lambda result: result["wartime_reaction"] == "morale_boost"
            and result["recruitment_result"] == "none"
        ),
        "dialogue_avoid_none": (
            lambda result: result["wartime_reaction"] == "none"
            and result["recruitment_result"] == "none"
        ),
        "dialogue_avoid_accept": (
            lambda result: result["wartime_reaction"] == "none"
            and result["recruitment_result"] == "accept"
        ),
        "dialogue_avoid_reject": (
            lambda result: result["wartime_reaction"] == "none"
            and result["recruitment_result"] == "reject"
        ),
        "dialogue_escape_stay": (
            lambda result: result["escape_intervention_result"] == "stay"
        ),
        "dialogue_escape_leave": (
            lambda result: result["escape_intervention_result"] == "leave"
        ),
        "dialogue_escape_final_round_leave": (
            lambda result: result["escape_intervention_result"] == "leave"
        ),
    }
    for label, predicate in dialogue_expectations.items():
        _assert_real(
            calls[label],
            bool(predicate(dialogue_results[label])),
            f"targeted real dialogue scenario did not reach {label}",
        )

    _assert_real(
        calls["dialogue_escape_final_round_leave"],
        str(compact_usage["provider"]).strip().lower() not in {"", "mock"}
        and compact_usage["fallback_to_mock"] is False
        and compact_usage["count"] == len(calls)
        and all(
            str(record["provider"]).strip().lower() not in {"", "mock"}
            and record["fallback_used"] is False
            and record["success"] is True
            for record in compact_usage["records"]
        ),
        "usage provenance was incomplete or included mock/fallback calls",
    )
    print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
