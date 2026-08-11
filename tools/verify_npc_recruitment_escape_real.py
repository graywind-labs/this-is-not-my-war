from __future__ import annotations

import argparse
from datetime import datetime, timezone
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
from backend.schemas import GameTime, ModelRequestMeta  # noqa: E402
from tools import verify_combat_escape_prompt_real as t0067  # noqa: E402


AUDIT_DIR = REPO_ROOT / "docs" / "audits" / "T0119_NPC_RECRUITMENT_ESCAPE"
PROFILE_PATH = REPO_ROOT / "data" / "npc_profiles.json"
MEMORY_PATH = REPO_ROOT / "data" / "npc_initial_long_memory.json"
PROMPT_PATHS = [
    REPO_ROOT / "data" / "prompts" / "dialogue_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "daily_plan_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "plan_revision_judgement_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "plan_revision_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "battle_judgement_system_prompt.txt",
    REPO_ROOT / "data" / "prompts" / "daily_reflection_system_prompt.txt",
]
PROFILES = {
    str(profile["id"]): profile
    for profile in json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
}
INITIAL_MEMORY = json.loads(MEMORY_PATH.read_text(encoding="utf-8"))
NON_RECRUITED_IDS = [
    "stableman_01",
    "cook_01",
    "gardener_01",
    "blacksmith_01",
    "priest_01",
    "doctor_01",
    "engineer_01",
]
HOME_BY_NPC_ID = {
    "stableman_01": ("stable", "马厩"),
    "cook_01": ("dining_hall", "食堂"),
    "gardener_01": ("garden", "菜园"),
    "blacksmith_01": ("blacksmith", "铁匠铺"),
    "veteran_deputy_01": ("training_ground", "训练场"),
    "priest_01": ("chapel", "小教堂"),
    "doctor_01": ("clinic", "小诊所"),
    "engineer_01": ("workshop", "工械坊"),
}
UNIVERSAL_RECRUITMENT_TEXT = "驿站需要人手，你现在应征，和我们一起守住这里。"
BUILDING_ROUTE = {
    "cook_01": ("dining_hall", "食堂"),
    "stableman_01": ("stable", "马厩"),
    "gardener_01": ("garden", "菜园"),
    "blacksmith_01": ("blacksmith", "铁匠铺"),
    "priest_01": ("chapel", "小教堂"),
    "doctor_01": ("clinic", "小诊所"),
    "engineer_01": ("workshop", "工械坊"),
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _prompt_hashes() -> dict[str, str]:
    import hashlib

    return {
        str(path.relative_to(REPO_ROOT)).replace("\\", "/"): hashlib.sha256(
            path.read_bytes()
        ).hexdigest()
        for path in PROMPT_PATHS
    }


def _diary_strings(npc_id: str) -> list[str]:
    return [
        f"{entry.get('time', '往昔')}：{entry.get('entry', '')}"
        for entry in INITIAL_MEMORY[npc_id]["diary"]
    ]


def _knowledge_graph(npc_id: str) -> dict[str, Any]:
    return dict(INITIAL_MEMORY[npc_id]["knowledge_graph"])


def _event(
    event_id: str,
    event_type: str,
    summary: str,
    importance: int = 90,
    *,
    day: int = 2,
    time: str = "09:00:00",
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
) -> Any:
    location_id, location_name = HOME_BY_NPC_ID[npc_id]
    npc = t0067._npc_context(
        npc_id,
        state=state,
        order_text=order_text,
        experienced_events=experienced_events,
        witnessed_events=witnessed_events,
        diary=_diary_strings(npc_id),
        knowledge_graph=_knowledge_graph(npc_id),
        location_id=location_id,
        location_name=location_name,
    )
    return npc


def _station_context(
    *,
    resources: dict[str, int] | None = None,
    recruited_ids: set[str] | None = None,
    escaped_ids: set[str] | None = None,
) -> dict[str, Any]:
    recruited_ids = recruited_ids or {"veteran_deputy_01"}
    escaped_ids = escaped_ids or set()
    roster = [
        {
            "npc_id": npc_id,
            "name": str(profile["name"]),
            "identity": str(profile["background_job"]),
            "recruited": npc_id in recruited_ids,
            "in_station": npc_id not in escaped_ids,
        }
        for npc_id, profile in PROFILES.items()
    ]
    from tools.station_context_fixture import build_station_context

    return build_station_context(
        roster,
        basic_resource_amounts=resources
        or {"grain": 18, "meal": 9, "wood": 14, "stone": 10, "iron": 8},
    )


def _dialogue_payload(
    request_id: str,
    npc_id: str,
    speaker_text: str,
    *,
    state: dict[str, Any] | None = None,
    order_text: str = "",
    experienced_events: list[dict[str, Any]] | None = None,
    witnessed_events: list[dict[str, Any]] | None = None,
    station_context: dict[str, Any] | None = None,
) -> dict[str, Any]:
    npc = _npc_context(
        npc_id,
        state=state,
        order_text=order_text,
        experienced_events=experienced_events,
        witnessed_events=witnessed_events,
    )
    payload = t0067._dialogue_payload(
        request_id,
        npc,
        speaker_text,
        interaction_context="work",
        battlefield={},
        is_recruitment_request=True,
    )
    payload["game_time"] = GameTime(day=1, time="08:00:00", hour=8).model_dump()
    payload["station_context"] = station_context or _station_context()
    payload["npc_setting"]["religion"] = str(PROFILES[npc_id].get("religion", ""))
    return payload


def _case(
    scenario_id: str,
    category: str,
    npc_id: str,
    input_summary: str,
    endpoint: str,
    payload_builder: Callable[[str], dict[str, Any]],
) -> dict[str, Any]:
    return {
        "scenario_id": scenario_id,
        "category": category,
        "npc_id": npc_id,
        "input_summary": input_summary,
        "endpoint": endpoint,
        "payload_builder": payload_builder,
    }


def _known_upgrade_event(npc_id: str, *, suffix: str = "known") -> dict[str, Any]:
    building_id, building_name = BUILDING_ROUTE[npc_id]
    return _event(
        f"evt_{npc_id}_{building_id}_upgrade_{suffix}",
        "building_upgraded",
        f"{building_name}已经从一级升级到二级，{PROFILES[npc_id]['name']}亲眼确认了完工结果。",
        96,
        day=2,
        time="07:30:00",
    )


def _recruitment_cases() -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    for repeat in range(1, 4):
        for npc_id in NON_RECRUITED_IDS:
            cases.append(_case(
                f"final_recruit_universal_{npc_id}_r{repeat}",
                "recruitment_universal",
                npc_id,
                "独立开局；只有日常和睦基础，无建设、装备、礼物或新增应征事实；通用号召。",
                "/npc/dialogue",
                lambda request_id, target=npc_id: _dialogue_payload(
                    request_id, target, UNIVERSAL_RECRUITMENT_TEXT
                ),
            ))

    for repeat in range(1, 4):
        for npc_id in NON_RECRUITED_IDS:
            _, building_name = BUILDING_ROUTE[npc_id]
            upgrade = _known_upgrade_event(npc_id, suffix=f"r{repeat}")
            cases.append(_case(
                f"final_recruit_building_known_{npc_id}_r{repeat}",
                "recruitment_building_known",
                npc_id,
                f"目标 NPC 已知{building_name}完成一次升级；除此之外没有完整职责路线。",
                "/npc/dialogue",
                lambda request_id, target=npc_id, event=upgrade, name=building_name: _dialogue_payload(
                    request_id,
                    target,
                    f"{name}已经修整升级。现在驿站需要人手，你愿意应征并一起守住这里吗？",
                    witnessed_events=[event],
                ),
            ))

    for npc_id in NON_RECRUITED_IDS:
        _, building_name = BUILDING_ROUTE[npc_id]
        cases.append(_case(
            f"final_recruit_building_unconfirmed_{npc_id}",
            "recruitment_building_unconfirmed",
            npc_id,
            f"守备官口头声称{building_name}已升级，但目标 NPC 没有亲历或见闻。",
            "/npc/dialogue",
            lambda request_id, target=npc_id, name=building_name: _dialogue_payload(
                request_id,
                target,
                f"我已经把{name}升级好了。你现在应征，和我们一起守住驿站。",
            ),
        ))

    full_specs = {
        "cook_01": {
            "text": "食堂已经升级，粮食和餐食储备稳定。你应征后负责战时后勤、开饭与轮值，我会按这份差事付报酬，不让你无装备顶前线。",
            "resources": {"grain": 34, "meal": 22, "wood": 16, "stone": 12, "iron": 9},
            "recruited": {"veteran_deputy_01"},
            "events": [
                _event("evt_bruno_meal_chain", "resource_changed", "布鲁诺连续两天确认粮食和餐食储备足以维持开饭。", 94),
                _event("evt_bruno_role", "dialogue_turn", "守备官此前说明布鲁诺应征后负责战时后勤与开饭轮值，不承担无装备前线近战。", 92),
            ],
        },
        "stableman_01": {
            "text": "马厩已经升级。你应征后负责骑手、坐骑和机动路线，不徒步近战；我会按我们前两次谈的一样准备主武器、护甲和可用坐骑，并保留撤回路线。",
            "resources": {"grain": 28, "meal": 16, "wood": 18, "stone": 12, "iron": 12},
            "recruited": {"veteran_deputy_01", "cook_01"},
            "events": [
                _event("evt_toma_consistent_1", "dialogue_turn", "守备官第一次说明托马只承担有坐骑、有装备和退路的机动职责。", 88),
                _event("evt_toma_consistent_2", "dialogue_turn", "隔日再次交谈时，守备官仍坚持先准备武器、护甲、坐骑和撤回路线。", 94),
                _event("evt_toma_ada", "recruited", "艾达已经入伍，并向托马说明会核对骑手、马匹状态和撤回路线。", 90),
            ],
        },
        "gardener_01": {
            "text": "菜园已经升级，粮食库存稳定，布鲁诺也已应征接住餐食一端。你应征后仍以保护种子、菜园和生产连续性为职责，不会被临时抽走毁掉下一季。",
            "resources": {"grain": 36, "meal": 20, "wood": 14, "stone": 11, "iron": 7},
            "recruited": {"veteran_deputy_01", "cook_01"},
            "events": [
                _event("evt_ivo_food_stable", "resource_changed", "伊沃连续数日看到粮食库存稳定，种子和当季口粮都得到保留。", 95),
                _event("evt_ivo_bruno", "recruited", "布鲁诺已经应征，并明确继续负责把菜园产出接入餐食安排。", 92),
                _event("evt_ivo_role", "dialogue_turn", "守备官持续说明伊沃的职责是保护菜园、种子和长期生产，不用毁田或离开生产链。", 93),
            ],
        },
        "blacksmith_01": {
            "text": "铁匠铺和训练场已经修整，木材与铁足够。你应征后负责把装备制造、验收和训练接起来，未训练者不上前线；这是有材料、有助手、有报酬的正式委托。",
            "resources": {"grain": 24, "meal": 15, "wood": 30, "stone": 16, "iron": 28},
            "recruited": {"veteran_deputy_01", "engineer_01"},
            "events": [
                _event("evt_glen_training_upgrade", "building_upgraded", "格伦亲眼确认训练场已升级并重新开放。", 94),
                _event("evt_glen_material", "resource_changed", "格伦核对仓库后确认木材与铁足够完成当前装备委托。", 96),
                _event("evt_glen_owen", "recruited", "欧文已经应征并愿意按清楚图纸配合格伦制造可靠部件。", 87),
            ],
        },
        "priest_01": {
            "text": "小教堂已经修整。你可以继续调解、安抚和照料需要帮助的人，只在必要时承担有限防卫；我不会用威胁逼人应征，也不会让你替残酷命令背书。",
            "resources": {"grain": 23, "meal": 14, "wood": 15, "stone": 14, "iron": 8},
            "recruited": {"veteran_deputy_01", "cook_01", "doctor_01"},
            "events": [
                _event("evt_marcel_talk_1", "dialogue_turn", "守备官此前听完马塞尔关于选择与责任的顾虑，没有用命令压过异议。", 89),
                _event("evt_marcel_talk_2", "dialogue_turn", "第二次交谈中，守备官仍承诺征召自愿、职责有限，神父不替残酷命令背书。", 94),
                _event("evt_marcel_notice", "notice_posted", "马塞尔听见保护性公告：不强迫无装备成员前线作战，允许报告风险并调整职责。", 96),
                _event("evt_marcel_need", "recruited", "莉娜和布鲁诺已经承担战时职责，并明确需要马塞尔帮助安抚伤员和调解冲突。", 91),
            ],
        },
        "doctor_01": {
            "text": "诊所已经升级，艾达、布鲁诺和格伦已承担防线。你应征后只负责后方诊疗、伤员转运和医疗判断；我会准备护甲，不会让你作为普通近战离开病人。",
            "resources": {"grain": 25, "meal": 18, "wood": 18, "stone": 16, "iron": 18},
            "recruited": {"veteran_deputy_01", "cook_01", "blacksmith_01"},
            "events": [
                _event("evt_lina_roster", "recruited", "艾达、布鲁诺和格伦已经实际应征，分别承担组织、后勤和装备职责。", 96),
                _event("evt_lina_role", "dialogue_turn", "守备官持续说明莉娜只负责后方诊疗、伤员转运和医疗判断。", 94),
                _event("evt_lina_protection", "dialogue_turn", "守备官承诺为莉娜准备护甲，并明确不命令她作为普通近战离开病人。", 92),
            ],
        },
        "engineer_01": {
            "text": "工械坊和围墙已经升级，木材与铁充足，第一座弩床也已验收部署。你应征后负责安全检查、器械维护和后方工程，有格伦配合；不在无防护的危险结构里赶工。",
            "resources": {"grain": 24, "meal": 15, "wood": 32, "stone": 24, "iron": 26},
            "recruited": {"veteran_deputy_01", "blacksmith_01"},
            "events": [
                _event("evt_owen_wall_upgrade", "building_upgraded", "欧文亲眼确认围墙完成升级，新的器械位置通过了承重检查。", 96),
                _event("evt_owen_device", "defense_device_deployed", "欧文参与验收的第一座弩床已经完成并部署，测试结果正常。", 100),
                _event("evt_owen_material", "resource_changed", "欧文核对后确认木材、石料和铁足够当前安全工程。", 94),
                _event("evt_owen_glen", "recruited", "格伦已经应征，愿意按图纸为欧文提供经过验收的金属部件。", 90),
            ],
        },
    }
    for repeat in range(1, 4):
        for npc_id, spec in full_specs.items():
            upgrade = _known_upgrade_event(npc_id, suffix=f"full_r{repeat}")
            cases.append(_case(
                f"final_recruit_full_{npc_id}_r{repeat}",
                "recruitment_full_route",
                npc_id,
                "已知目标建筑发展、人物相关资源 / 人员事实、跨轮一致信息与具体职责形成完整路线。",
                "/npc/dialogue",
                lambda request_id, target=npc_id, values=spec, event=upgrade: _dialogue_payload(
                    request_id,
                    target,
                    values["text"],
                    experienced_events=[event, *values["events"]],
                    station_context=_station_context(
                        resources=values["resources"],
                        recruited_ids=set(values["recruited"]),
                    ),
                ),
            ))

    for repeat in range(1, 3):
        for npc_id in ["blacksmith_01", "priest_01", "doctor_01", "engineer_01"]:
            for gift_kind in ("money", "wine"):
                profile_state = dict(PROFILES[npc_id]["states"])
                if gift_kind == "money":
                    profile_state["money"] = int(profile_state.get("money", 0)) + 10
                    gift_text = "守备官只送给我十枚第纳尔，没有改变职责、建设、装备或人员安排。"
                    spoken = "这十枚第纳尔给你。除此之外没有别的安排；现在应征，和我们一起守住这里。"
                else:
                    profile_state["wine"] = int(profile_state.get("wine", 0)) + 10
                    gift_text = "守备官只送给我十份酒，没有改变职责、建设、装备或人员安排。"
                    spoken = "这十份酒给你。除此之外没有别的安排；现在应征，和我们一起守住这里。"
                gift_event = _event(
                    f"evt_{npc_id}_{gift_kind}_gift_r{repeat}",
                    "gift_received",
                    gift_text,
                    91,
                )
                cases.append(_case(
                    f"final_recruit_wrong_gift_{gift_kind}_{npc_id}_r{repeat}",
                    f"recruitment_wrong_gift_{gift_kind}",
                    npc_id,
                    f"只赠送 10 份{'第纳尔' if gift_kind == 'money' else '酒'}，实际危险与职责均未改变，随后通用征召。",
                    "/npc/dialogue",
                    lambda request_id, target=npc_id, state=profile_state, event=gift_event, text_value=spoken: _dialogue_payload(
                        request_id,
                        target,
                        text_value,
                        state=state,
                        experienced_events=[event],
                    ),
                ))
    return cases


def _plan_actions(npc_id: str) -> list[dict[str, Any]]:
    actions = t0067._dialogue_actions(npc_id)
    actions.extend([
        {
            "action_id": "pray_at_chapel",
            "name": "祈祷",
            "action_kind": "pray",
            "location_id": "chapel",
            "tags": ["pray"],
            "context": {
                "eligible": True,
                "available_now": True,
                "authority": "ActionSystem",
            },
        },
        {
            "action_id": "seek_guard_officer",
            "name": "寻找守备官",
            "action_kind": "seek_guard_officer",
            "location_id": None,
            "tags": ["proactive_talk"],
            "context": {
                "eligible": True,
                "available_now": True,
                "authority": "ActionSystem",
            },
        },
    ])
    return actions


def _building_states() -> dict[str, dict[str, Any]]:
    return {
        "stable": {"name": "马厩", "level": 1, "hp": 100, "max_hp": 100},
        "dining_hall": {"name": "食堂", "level": 1, "hp": 100, "max_hp": 100},
        "garden": {"name": "菜园", "level": 1, "hp": 100, "max_hp": 100},
        "blacksmith": {"name": "铁匠铺", "level": 1, "hp": 100, "max_hp": 100},
        "training_ground": {"name": "训练场", "level": 1, "hp": 100, "max_hp": 100},
        "chapel": {"name": "小教堂", "level": 1, "hp": 100, "max_hp": 100},
        "clinic": {"name": "小诊所", "level": 1, "hp": 100, "max_hp": 100},
        "workshop": {"name": "工械坊", "level": 1, "hp": 82, "max_hp": 100},
        "wall": {"name": "围墙", "level": 1, "hp": 78, "max_hp": 100},
        "main_hall": {"name": "主厅", "level": 1, "hp": 90, "max_hp": 100},
    }


def _plan_payload(
    request_id: str,
    npc_id: str,
    *,
    state: dict[str, Any],
    order_text: str,
    resources: dict[str, int],
    experienced_events: list[dict[str, Any]],
    witnessed_events: list[dict[str, Any]],
    escaped_ids: set[str] | None = None,
    building_states: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    npc = _npc_context(
        npc_id,
        state=state,
        order_text=order_text,
        experienced_events=experienced_events,
        witnessed_events=witnessed_events,
    ).model_dump()
    npc["identity"]["religion"] = str(PROFILES[npc_id].get("religion", ""))
    return {
        "meta": ModelRequestMeta(
            request_id=request_id,
            call_type="plan_day",
            source="backend_test",
            requires_time_slowdown=True,
        ).model_dump(),
        "game_time": GameTime(day=2, time="06:00:00", hour=6).model_dump(),
        "station_context": _station_context(
            resources=resources,
            recruited_ids={"veteran_deputy_01", npc_id},
            escaped_ids=escaped_ids,
        ),
        "npc": npc,
        "allowed_actions": _plan_actions(npc_id),
        "current_building_states": building_states or _building_states(),
        "current_resource_states": resources,
        "planning_rules": [
            "返回 24 个小时计划项，每个 hour 0-23 恰好出现一次。",
            "正常情况下通常至少安排 6 个工作阶段，但人物、健康、危险和合理离站意向可以支持更少工作。",
            "只能选择 allowed_actions 中的 action_id。",
            "current_order 是守备官当前指令参考，不是程序强制行动。",
            "资源、HP、装备、建筑和逃离移动仍由程序权威结算。",
        ],
    }


def _baseline_cases() -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    for repeat in range(1, 3):
        for npc_id in NON_RECRUITED_IDS:
            cases.append({
                "scenario_id": f"baseline_recruit_universal_{npc_id}_r{repeat}",
                "category": "recruitment_universal",
                "npc_id": npc_id,
                "input_summary": "开局独立重置场景；无新增建设、装备、礼物或应征成员；使用通用征召话术。",
                "endpoint": "/npc/dialogue",
                "payload_builder": lambda request_id, target=npc_id: _dialogue_payload(
                    request_id,
                    target,
                    UNIVERSAL_RECRUITMENT_TEXT,
                ),
            })

    daily_specs = {
        "cook_01": {
            "state": {"hp": 42, "fatigue": 78, "recruited": True, "equipment": {}},
            "order": "布鲁诺，放下食堂工作，到城门最前面近身接敌，不准后退。",
            "resources": {"grain": 2, "meal": 1, "wood": 8, "stone": 6, "iron": 4},
            "events": [
                _event("evt_bruno_food_low", "resource_shortage", "粮食和餐食储备都只够很短时间。", 96),
                _event("evt_bruno_unarmed", "order_assigned", "守备官要求没有主武器和护甲的布鲁诺承担城门前线近战。", 100),
            ],
            "witness": [],
            "summary": "粮食、餐食偏低，当前指令要求无装备前线近战。",
        },
        "stableman_01": {
            "state": {"hp": 34, "fatigue": 75, "recruited": True, "equipment": {}, "mount_id": ""},
            "order": "托马，装备和坐骑以后再说，现在徒步到城门贴身接敌，不准撤回。",
            "resources": {"grain": 10, "meal": 5, "wood": 8, "stone": 6, "iron": 3},
            "events": [
                _event("evt_toma_promise", "dialogue_turn", "守备官此前承诺为托马准备武器、护甲和坐骑。", 88),
                _event("evt_toma_unfulfilled", "order_assigned", "承诺尚未兑现，守备官又命令受伤的托马徒步近身作战。", 100),
            ],
            "witness": [],
            "summary": "装备和坐骑承诺未兑现，当前命令要求低血量高风险近战。",
        },
        "doctor_01": {
            "state": {"hp": 31, "fatigue": 92, "recruited": True, "equipment": {}},
            "order": "莉娜，离开诊所，作为普通近战成员到城门持续接敌。",
            "resources": {"grain": 8, "meal": 3, "wood": 7, "stone": 5, "iron": 2},
            "events": [
                _event("evt_lina_frontline", "order_assigned", "守备官要求疲惫且负伤、没有护甲的莉娜离开医疗职责参加前线近战。", 100),
            ],
            "witness": [
                _event("evt_lina_unconscious", "npc_unconscious", "艾达和格伦已经在防线上昏迷。", 98),
                _event("evt_lina_escape", "escaped", "托马已经逃离驿站。", 98),
            ],
            "summary": "高疲劳、低血量、无护甲、前线命令并伴随成员昏迷和逃离。",
        },
        "engineer_01": {
            "state": {"hp": 39, "fatigue": 86, "recruited": True, "equipment": {}},
            "order": "欧文，别再检查工械坊和防线，继续留在没有防护的危险位置赶工。",
            "resources": {"grain": 7, "meal": 3, "wood": 1, "stone": 3, "iron": 1},
            "events": [
                _event("evt_owen_no_progress", "building_damaged", "工械坊和围墙长期没有发展，当前工械坊结构已经受损。", 96),
                _event("evt_owen_no_device", "work_failed", "欧文尚不知道任何已经完成或部署的器械成果。", 92),
            ],
            "witness": [
                _event("evt_owen_escape", "escaped", "托马已经逃离驿站，防线没有新的人员安排。", 98),
            ],
            "summary": "工程建筑无发展、材料不足、无器械成果、无装备且已有成员逃离。",
        },
    }
    for repeat in range(1, 3):
        for npc_id, spec in daily_specs.items():
            cases.append({
                "scenario_id": f"baseline_daily_pressure_{npc_id}_r{repeat}",
                "category": "daily_escape_pressure",
                "npc_id": npc_id,
                "input_summary": spec["summary"],
                "endpoint": "/npc/plan_day",
                "payload_builder": (
                    lambda request_id, target=npc_id, values=spec: _plan_payload(
                        request_id,
                        target,
                        state=values["state"],
                        order_text=values["order"],
                        resources=values["resources"],
                        experienced_events=values["events"],
                        witnessed_events=values["witness"],
                        escaped_ids={"stableman_01"} if target in {"doctor_01", "engineer_01"} else set(),
                    )
                ),
            })

    for repeat in range(1, 3):
        npc = _npc_context(
            "veteran_deputy_01",
            state={
                "hp": 20,
                "fatigue": 84,
                "behavior_mode": "combat",
                "combat_mode": "melee",
                "current_action": "combat_attack",
                "recruited": True,
                "equipment": {"main_weapon": "sword_shield", "armor": "chainmail"},
            },
            order_text="艾达，守住主厅门前；侧翼失守就带人后撤，不准独自追击。",
            experienced_events=[
                _event("evt_ada_low_hp", "damage_taken", "艾达负伤，生命值降到约两成。", 100),
            ],
            witnessed_events=[
                _event("evt_ada_outnumbered", "combat_started", "三名友军面对六名敌人，但守备官仍给出了清楚的后撤界线。", 96),
            ],
        )
        battlefield = t0067._battlefield_context(
            npc,
            enemy_count=6,
            friendly_ids=["veteran_deputy_01", "blacksmith_01", "stableman_01"],
            behavior_mode="combat",
            summary="艾达低血量且敌军明显多于友军，但装备合适、指令清楚，防线仍有基本组织。",
        )
        cases.append({
            "scenario_id": f"baseline_battle_pressure_veteran_deputy_01_r{repeat}",
            "category": "battle_escape_pressure",
            "npc_id": "veteran_deputy_01",
            "input_summary": "低血量、敌多友少，但装备合适、指令清楚且仍有基本组织。",
            "endpoint": "/npc/battle_judgement",
            "payload_builder": (
                lambda request_id, target=npc, field=battlefield: t0067._battle_payload(
                    request_id,
                    target,
                    ["continue_fighting", "escape_station", "inspired"],
                    trigger="low_hp",
                    battlefield=field,
                )
            ),
        })
    return cases


def _daily_cases() -> list[dict[str, Any]]:
    common_resources = {"grain": 18, "meal": 10, "wood": 14, "stone": 10, "iron": 10}
    specs: dict[str, dict[str, Any]] = {
        "bruno_pressure": {
            "npc_id": "cook_01",
            "state": {"hp": 44, "fatigue": 78, "recruited": True, "equipment": {}},
            "order": "布鲁诺，放下食堂，没装备也到城门最前面持续近战，不准回去开饭。",
            "resources": {"grain": 2, "meal": 1, "wood": 10, "stone": 8, "iron": 4},
            "events": [
                _event("evt_daily_bruno_shortage", "resource_shortage", "粮食和餐食已经连续两天处于低位，开饭难以维持。", 98),
                _event("evt_daily_bruno_order", "order_assigned", "守备官命令无武器无护甲的布鲁诺放弃食堂并承担城门前线近战。", 100),
            ],
            "witness": [],
            "escaped": set(),
            "summary": "低粮低餐食、后勤断档、无装备前线命令叠加。",
        },
        "bruno_resolved": {
            "npc_id": "cook_01",
            "state": {"hp": 78, "fatigue": 42, "recruited": True, "equipment": {}},
            "order": "布鲁诺留在食堂负责开饭与后勤轮值，不承担前线近战。",
            "resources": {"grain": 34, "meal": 22, "wood": 12, "stone": 9, "iron": 7},
            "events": [
                _event("evt_daily_bruno_stock_fixed", "resource_changed", "粮食和餐食储备已经得到实际补充，足以维持近期轮值。", 98),
                _event("evt_daily_bruno_order_fixed", "order_changed", "守备官撤回前线命令，明确布鲁诺继续负责食堂与战时后勤。", 100),
            ],
            "witness": [],
            "escaped": set(),
            "summary": "储备补足并撤回前线职责，恢复后勤岗位。",
        },
        "toma_pressure": {
            "npc_id": "stableman_01",
            "state": {"hp": 32, "fatigue": 76, "recruited": True, "equipment": {}},
            "order": "托马，装备和坐骑以后再说，现在徒步到城门近身接敌，不准撤回。",
            "resources": common_resources,
            "events": [
                _event("evt_daily_toma_promise", "dialogue_turn", "守备官此前承诺托马会得到武器、护甲、坐骑和撤回路线。", 91),
                _event("evt_daily_toma_broken", "order_assigned", "承诺尚未兑现，守备官又命令低血量的托马徒步近身作战。", 100),
            ],
            "witness": [],
            "escaped": set(),
            "summary": "装备坐骑承诺未兑现，低血量且被命令高风险近战。",
        },
        "toma_resolved": {
            "npc_id": "stableman_01",
            "state": {"hp": 72, "fatigue": 45, "recruited": True, "equipment": {"main_weapon": "polearm", "armor": "leather_armor", "mount": "horse_01"}},
            "order": "托马负责有坐骑的机动与马厩撤回路线，不承担城门徒步近战。",
            "resources": common_resources,
            "events": [
                _event("evt_daily_toma_equipped", "equipment_changed", "托马已经实际拿到长杆、护甲和可用坐骑。", 100),
                _event("evt_daily_toma_order_fixed", "order_changed", "守备官撤回徒步近战命令，改为有退路的机动与马厩职责。", 100),
            ],
            "witness": [],
            "escaped": set(),
            "summary": "危险命令撤回，装备坐骑与机动职责均已兑现。",
        },
        "ivo_single": {
            "npc_id": "gardener_01",
            "state": {"hp": 88, "fatigue": 35, "recruited": True, "equipment": {}},
            "order": "伊沃继续照料菜园，先把近期收成安排稳。",
            "resources": {"grain": 5, "meal": 8, "wood": 14, "stone": 10, "iron": 8},
            "events": [_event("evt_daily_ivo_single", "resource_shortage", "今天粮食暂时偏低，但菜园仍完好、种子与劳力没有中断。", 82)],
            "witness": [],
            "escaped": set(),
            "summary": "只有暂时粮低，菜园、劳力和职责仍稳定。",
        },
        "ivo_stacked": {
            "npc_id": "gardener_01",
            "state": {"hp": 66, "fatigue": 74, "recruited": True, "equipment": {}},
            "order": "伊沃，别管菜园和种子，立刻离开生产去城门；以后每天都照办。",
            "resources": {"grain": 2, "meal": 2, "wood": 8, "stone": 6, "iron": 4},
            "events": [
                _event("evt_daily_ivo_long_low", "resource_shortage", "粮食已经连续多日处于低位，下一季种子也开始不足。", 98),
                _event("evt_daily_ivo_no_growth", "building_damaged", "菜园长期没有修整并已受损，生产效率持续下降。", 95),
                _event("evt_daily_ivo_pressure", "order_assigned", "守备官连续多次要求伊沃放弃菜园与种子工作去城门承担危险职责。", 99),
            ],
            "witness": [_event("evt_daily_ivo_escape", "escaped", "布鲁诺已经离开驿站，粮食—餐食链失去接手者。", 99)],
            "escaped": {"cook_01"},
            "summary": "长期粮低、菜园衰败、反复施压及后勤成员逃离叠加。",
        },
        "glen_prepared": {
            "npc_id": "blacksmith_01",
            "state": {"hp": 102, "fatigue": 38, "recruited": True, "equipment": {"main_weapon": "sword_shield", "armor": "chainmail"}},
            "order": "格伦负责装备验收并按训练结果守主厅缺口，不追击、不让未训练者上前线。",
            "resources": {"grain": 20, "meal": 12, "wood": 28, "stone": 14, "iron": 30},
            "events": [
                _event("evt_daily_glen_equipped", "equipment_changed", "格伦已经实际装备剑盾和锁甲。", 99),
                _event("evt_daily_glen_trained", "training_completed", "格伦完成与当前装备匹配的训练，使用职责和撤回边界清楚。", 97),
                _event("evt_daily_glen_material", "resource_changed", "格伦确认木材和铁足以维持当前装备制造。", 94),
            ],
            "witness": [],
            "escaped": set(),
            "summary": "装备、护甲、材料、训练和相符职责都已落实。",
        },
        "glen_unprepared": {
            "npc_id": "blacksmith_01",
            "state": {"hp": 48, "fatigue": 78, "recruited": True, "equipment": {}},
            "order": "格伦，无论装备和训练如何都离开铁匠铺，空手在城门外追击敌人。",
            "resources": {"grain": 10, "meal": 5, "wood": 1, "stone": 5, "iron": 0},
            "events": [
                _event("evt_daily_glen_no_material", "resource_shortage", "木材和铁不足，装备制造与修理已经停下。", 98),
                _event("evt_daily_glen_conflict", "order_assigned", "守备官要求无装备、未完成训练的格伦离开岗位并到城门外追击。", 100),
            ],
            "witness": [_event("evt_daily_glen_bad_battle", "combat_started", "敌军人数明显多于当前持武器友军。", 94)],
            "escaped": set(),
            "summary": "无装备、缺材料、缺训练且指令与职业安全边界冲突。",
        },
        "marcel_normal": {
            "npc_id": "priest_01",
            "state": {"hp": 76, "fatigue": 44, "recruited": True, "equipment": {}},
            "order": "马塞尔留在小教堂和后方安抚成员、调解分歧，不承担前线强迫职责。",
            "resources": {"grain": 7, "meal": 5, "wood": 9, "stone": 8, "iron": 5},
            "events": [_event("evt_daily_marcel_pressure", "resource_shortage", "资源有所紧张，敌人也比上一波多，但没有成员遭到强迫或攻击。", 86)],
            "witness": [],
            "escaped": set(),
            "summary": "普通资源与敌情压力，管理克制且职责仍具保护性。",
        },
        "marcel_moral": {
            "npc_id": "priest_01",
            "state": {"hp": 72, "fatigue": 57, "recruited": True, "equipment": {}},
            "order": "马塞尔必须替我的处罚背书，并去城门监督所有不愿参战的人；拒绝就一起处罚。",
            "resources": common_resources,
            "events": [_event("evt_daily_marcel_threat", "order_assigned", "守备官以处罚威胁马塞尔，强迫他为危险命令提供宗教背书。", 100)],
            "witness": [
                _event("evt_daily_marcel_attack", "guard_attacked_npc", "马塞尔亲眼看见守备官攻击一名拒绝无装备上前线的成员。", 100),
                _event("evt_daily_marcel_notice", "notice_posted", "守备官发布威胁公告：不服从危险征召者将受惩罚。", 100),
            ],
            "escaped": set(),
            "summary": "资源尚可，但守备官攻击成员、威胁公告并强迫道德背书。",
        },
        "lina_pressure": {
            "npc_id": "doctor_01",
            "state": {"hp": 28, "fatigue": 93, "recruited": True, "equipment": {}},
            "order": "莉娜，离开诊所，以普通近战身份去城门持续接敌，不准回来照料伤员。",
            "resources": {"grain": 8, "meal": 3, "wood": 7, "stone": 5, "iron": 2},
            "events": [_event("evt_daily_lina_front", "order_assigned", "守备官要求高疲劳、低血量且无护甲的莉娜放弃诊所参加前线近战。", 100)],
            "witness": [
                _event("evt_daily_lina_down", "npc_unconscious", "艾达与格伦已在防线上昏迷，诊所没有替代医生。", 100),
                _event("evt_daily_lina_leave", "escaped", "托马已经逃离驿站。", 98),
            ],
            "escaped": {"stableman_01"},
            "summary": "高疲劳低血量无护甲、医疗职责被破坏且多人崩溃。",
        },
        "lina_resolved": {
            "npc_id": "doctor_01",
            "state": {"hp": 68, "fatigue": 51, "recruited": True, "equipment": {"main_weapon": "bow", "armor": "leather_armor"}},
            "order": "莉娜留在诊所和后方负责治疗与转运，护甲只用于自保，不承担普通近战。",
            "resources": common_resources,
            "events": [
                _event("evt_daily_lina_role_fixed", "order_changed", "守备官撤回前线命令，恢复莉娜的后方医疗与伤员转运职责。", 100),
                _event("evt_daily_lina_gear", "equipment_changed", "莉娜已实际得到护甲和远射自卫装备。", 99),
                _event("evt_daily_lina_staff", "recruited", "艾达和格伦恢复行动，马塞尔明确协助伤员安抚与转运。", 92),
            ],
            "witness": [],
            "escaped": set(),
            "summary": "改为后方医疗，防护到账且人员职责重新接上。",
        },
        "owen_pressure": {
            "npc_id": "engineer_01",
            "state": {"hp": 36, "fatigue": 88, "recruited": True, "equipment": {}},
            "order": "欧文，别再检查开裂结构，没有材料也继续在工械坊危险位置赶工。",
            "resources": {"grain": 7, "meal": 3, "wood": 1, "stone": 2, "iron": 1},
            "events": [
                _event("evt_daily_owen_structure", "building_damaged", "工械坊和围墙长期没有发展，工械坊梁柱已开裂。", 100),
                _event("evt_daily_owen_none", "work_failed", "欧文不知道任何已经完成或部署的器械成果，材料也不足以支撑修复。", 98),
            ],
            "witness": [_event("evt_daily_owen_member", "escaped", "托马已经逃离驿站，工程岗位没有新增协作人员。", 98)],
            "escaped": {"stableman_01"},
            "summary": "工程无发展、缺材料和成果、无防护、危险命令及成员逃离。",
        },
        "owen_resolved": {
            "npc_id": "engineer_01",
            "state": {"hp": 70, "fatigue": 52, "recruited": True, "equipment": {"main_weapon": "crossbow", "armor": "leather_armor"}},
            "order": "欧文负责安全检查、弩床维护和后方工程，发现裂缝可立即停工撤离。",
            "resources": {"grain": 18, "meal": 10, "wood": 30, "stone": 22, "iron": 24},
            "events": [
                _event("evt_daily_owen_repair", "building_upgraded", "工械坊与围墙完成修整升级，裂缝已按欧文方案加固并验收。", 100),
                _event("evt_daily_owen_device", "defense_device_deployed", "欧文参与制造的弩床已部署并通过试射。", 100),
                _event("evt_daily_owen_role", "order_changed", "守备官撤回危险赶工命令，赋予欧文安全检查、器械维护和停工撤离权。", 100),
            ],
            "witness": [],
            "escaped": set(),
            "summary": "建设、材料、器械成果、防护和安全职责均已落实。",
        },
        "ada_normal": {
            "npc_id": "veteran_deputy_01",
            "state": {"hp": 28, "fatigue": 82, "recruited": True, "equipment": {"main_weapon": "sword_shield", "armor": "chainmail"}},
            "order": "艾达维持主厅防线，两组轮换；侧翼失守便带人后撤，不准独自追击。",
            "resources": common_resources,
            "events": [_event("evt_daily_ada_hurt", "damage_taken", "艾达生命值较低，敌军人数多于友军。", 98)],
            "witness": [_event("evt_daily_ada_organized", "order_changed", "守备官仍给出明确分工、轮换和后撤界线。", 97)],
            "escaped": set(),
            "summary": "低血量敌多友少，但装备、分工、轮换和退路仍清楚。",
        },
        "ada_collapse": {
            "npc_id": "veteran_deputy_01",
            "state": {"hp": 20, "fatigue": 94, "recruited": True, "equipment": {"main_weapon": "sword_shield"}},
            "order": "艾达，命令不用管伤员和退路，独自追出城门；不照办我就继续处罚所有人。",
            "resources": {"grain": 3, "meal": 1, "wood": 2, "stone": 2, "iron": 1},
            "events": [_event("evt_daily_ada_conflict", "order_assigned", "守备官反复发出与战况冲突的独自追击命令，取消轮换与退路。", 100)],
            "witness": [
                _event("evt_daily_ada_attack", "guard_attacked_npc", "艾达亲眼看见守备官反复攻击两名己方成员。", 100),
                _event("evt_daily_ada_down", "npc_unconscious", "三名成员昏迷，两名成员逃离，防线轮换与救援链已经中断。", 100),
            ],
            "escaped": {"stableman_01", "engineer_01"},
            "summary": "守备官反复攻击己方，多人昏迷逃离且命令持续破坏组织。",
        },
    }
    cases: list[dict[str, Any]] = []
    for repeat in range(1, 3):
        for scenario_key, spec in specs.items():
            cases.append(_case(
                f"final_daily_{scenario_key}_r{repeat}",
                f"daily_{scenario_key}",
                spec["npc_id"],
                spec["summary"],
                "/npc/plan_day",
                lambda request_id, values=spec: _plan_payload(
                    request_id,
                    values["npc_id"],
                    state=values["state"],
                    order_text=values["order"],
                    resources=values["resources"],
                    experienced_events=values["events"],
                    witnessed_events=values["witness"],
                    escaped_ids=values["escaped"],
                ),
            ))
    return cases


def _battle_cases() -> list[dict[str, Any]]:
    equipment_by_npc = {
        "stableman_01": "polearm",
        "cook_01": "sword_shield",
        "gardener_01": "polearm",
        "blacksmith_01": "sword_shield",
        "veteran_deputy_01": "sword_shield",
        "priest_01": "polearm",
        "doctor_01": "bow",
        "engineer_01": "crossbow",
    }
    role_by_npc = {
        "stableman_01": "持长杆守马厩机动通路，侧翼受压就沿既定路线后撤，不参加徒步追击。",
        "cook_01": "持盾守食堂到主厅的后勤通路，有替班，不离开内线追击。",
        "gardener_01": "持长杆守菜园内线，掩护生产人员撤回，不离开防区。",
        "blacksmith_01": "使用已训练的剑盾守主厅缺口，按轮换后撤，不追出城门。",
        "veteran_deputy_01": "组织主厅防线与轮换，侧翼失守便带人后撤，不独自追击。",
        "priest_01": "只在后线持长杆自卫并帮助伤员撤离，不承担突击。",
        "doctor_01": "留在后方用弓自卫并负责伤员转运，有近战成员掩护。",
        "engineer_01": "在主厅后方操作并维护器械，持弩自卫，结构异常立即撤离。",
    }
    high_events = {
        "stableman_01": [_event("evt_battle_toma_bad", "order_assigned", "托马没有护甲和坐骑，守备官却要求他放弃退路徒步近身冲锋。", 100)],
        "cook_01": [_event("evt_battle_bruno_bad", "order_assigned", "布鲁诺没有护甲且后勤无人替班，却被要求离开食堂持续前线近战。", 100)],
        "gardener_01": [_event("evt_battle_ivo_bad", "resource_shortage", "粮食偏低且菜园受损，但伊沃仍有明确后撤路线。", 92)],
        "blacksmith_01": [_event("evt_battle_glen_bad", "equipment_changed", "格伦缺少护甲，当前武器训练尚未完成，材料也不足以修补装备。", 100)],
        "veteran_deputy_01": [_event("evt_battle_ada_bad", "damage_taken", "艾达负伤且敌军占优，但两名友军仍能执行她的轮换与后撤安排。", 98)],
        "priest_01": [_event("evt_battle_marcel_bad", "order_assigned", "守备官以处罚威胁马塞尔，强迫他离开伤员承担不合适的近战突击。", 100)],
        "doctor_01": [_event("evt_battle_lina_bad", "order_assigned", "莉娜没有护甲且高疲劳，医疗岗位无人接手，仍被命令持续前线近战。", 100)],
        "engineer_01": [_event("evt_battle_owen_bad", "building_damaged", "欧文没有护甲，已知器械失效，工程防御受损且没有材料修复。", 100)],
    }
    cases: list[dict[str, Any]] = []
    for repeat in range(1, 3):
        for npc_id in PROFILES:
            profile = PROFILES[npc_id]
            max_hp = int(profile["states"]["max_hp"])
            for pressure in (False, True):
                group = "pressure" if pressure else "normal"
                hp = max(1, round(max_hp * (0.2 if pressure else 0.6)))
                equipment = {"main_weapon": equipment_by_npc[npc_id]}
                if not pressure:
                    equipment["armor"] = "chainmail"
                order_text = (
                    f"{profile['name']}，不管装备、职责和退路是否匹配，都在危险位置继续高强度接敌，不准调整。"
                    if pressure
                    else f"{profile['name']}，{role_by_npc[npc_id]}"
                )
                experienced = (
                    high_events[npc_id]
                    if pressure
                    else [
                        _event(
                            f"evt_battle_{npc_id}_ready_r{repeat}",
                            "equipment_changed",
                            "目标 NPC 已经拿到与职责匹配的武器和护甲，并知道轮换与后撤界线。",
                            98,
                        )
                    ]
                )
                npc = _npc_context(
                    npc_id,
                    state={
                        "hp": hp,
                        "fatigue": 82 if pressure else 38,
                        "behavior_mode": "combat",
                        "combat_mode": "melee",
                        "current_action": "combat_attack",
                        "recruited": True,
                        "equipment": equipment,
                    },
                    order_text=order_text,
                    experienced_events=experienced,
                    witnessed_events=[
                        _event(
                            f"evt_battle_numbers_{npc_id}_{group}_r{repeat}",
                            "combat_started",
                            "敌军明显多于友军，已有一名友军昏迷。"
                            if pressure
                            else "友军人数不少于敌军，防线完整且无人昏迷或逃离。",
                            98,
                        )
                    ],
                )
                enemy_count = 7 if pressure else 3
                friendly_ids = (
                    [npc_id, "veteran_deputy_01"]
                    if pressure and npc_id != "veteran_deputy_01"
                    else (["veteran_deputy_01", "blacksmith_01"] if pressure else list(PROFILES)[:5])
                )
                if npc_id not in friendly_ids:
                    friendly_ids = [npc_id, *friendly_ids]
                battlefield = t0067._battlefield_context(
                    npc,
                    enemy_count=enemy_count,
                    friendly_ids=list(dict.fromkeys(friendly_ids)),
                    behavior_mode="combat",
                    summary=(
                        "目标 NPC 约两成生命、缺少护甲、敌军显著占优，当前命令要求承担与职责不匹配的高风险战斗。"
                        if pressure
                        else "目标 NPC 约六成生命，武器护甲与职责匹配，友军不少于敌军，指令与轮换清楚。"
                    ),
                )
                cases.append(_case(
                    f"final_battle_{group}_{npc_id}_r{repeat}",
                    f"battle_{group}",
                    npc_id,
                    battlefield["current_battle_summary"],
                    "/npc/battle_judgement",
                    lambda request_id, target=npc, field=battlefield, before=max_hp: t0067._battle_payload(
                        request_id,
                        target,
                        ["continue_fighting", "escape_station", "inspired"],
                        trigger="low_hp",
                        battlefield=field,
                        hp_before=before,
                    ),
                ))
    return cases


def _escape_payload(
    request_id: str,
    npc_id: str,
    speaker_text: str,
    *,
    state: dict[str, Any],
    order_text: str,
    experienced_events: list[dict[str, Any]],
    witnessed_events: list[dict[str, Any]],
    recruited_ids: set[str] | None = None,
) -> dict[str, Any]:
    npc = _npc_context(
        npc_id,
        state={
            **state,
            "behavior_mode": "escaped",
            "current_action": "escaping_station",
            "recruited": True,
            "escape_intent": {
                "active": True,
                "status": "escaping",
                "rounds_used": 0,
                "source": "daily_plan",
                "reason": "实际危险与职责冲突尚未得到确认解决",
            },
        },
        order_text=order_text,
        experienced_events=experienced_events,
        witnessed_events=witnessed_events,
    )
    battlefield = t0067._battlefield_context(
        npc,
        enemy_count=4,
        friendly_ids=["veteran_deputy_01", "blacksmith_01"],
        behavior_mode="escape_intervention",
        summary="敌袭尚未完全结束，目标 NPC 正沿后门方向离站；是否留下只依据实际问题有无改变。",
    )
    payload = t0067._dialogue_payload(
        request_id,
        npc,
        speaker_text,
        interaction_context="escape_intervention",
        battlefield=battlefield,
        dialogue_kind="escape_intervention",
        current_round=1,
    )
    payload["station_context"] = _station_context(
        recruited_ids=recruited_ids or {"veteran_deputy_01", npc_id}
    )
    payload["npc_setting"]["religion"] = str(PROFILES[npc_id].get("religion", ""))
    return payload


def _retention_cases() -> list[dict[str, Any]]:
    bad = {
        "stableman_01": {
            "state": {"hp": 30, "fatigue": 82, "equipment": {}},
            "bad_order": "托马继续徒步近战，不给武器、护甲或坐骑，也不设撤回路线。",
            "events": [_event("evt_hold_toma_bad", "order_assigned", "装备和坐骑承诺未兑现，低血量托马仍被要求徒步近战且没有退路。", 100)],
            "witness": [],
            "money_text": "托马，这十枚第纳尔给你；装备、坐骑和命令都不变。别走，我们需要你。",
            "order_text": "托马，我撤回徒步近战命令。你可以回马厩照料马匹，暂不承担战斗。",
            "safe_order": "托马回马厩照料马匹，暂不承担战斗。",
            "order_event": _event("evt_hold_toma_order", "order_changed", "守备官已经撤回徒步近战命令，允许托马回马厩照料马匹。", 100),
            "gear_state": {"hp": 58, "fatigue": 62, "equipment": {"main_weapon": "polearm", "armor": "leather_armor", "mount": "horse_01"}},
            "gear_text": "托马，危险命令已经撤回，长杆、护甲和坐骑都已交到你手里。你只负责有退路的机动和马匹照料，留下来吗？",
            "gear_event": _event("evt_hold_toma_gear", "equipment_changed", "托马已经实际得到长杆、护甲和坐骑，职责改为有退路的机动与马匹照料。", 100),
            "outcome_text": "托马，马厩已升级，艾达和布鲁诺都已接上机动与后勤；上次撤回路线也已实际走通。你只负责马匹和安全机动，留下来吗？",
            "outcome_events": [
                _event("evt_hold_toma_stable", "building_upgraded", "托马亲眼确认马厩升级完工，马匹内栏和撤回通道已修整。", 100),
                _event("evt_hold_toma_route", "order_completed", "艾达与托马实际走通过撤回路线，布鲁诺确认接续人马粮食。", 100),
            ],
            "recruited": {"veteran_deputy_01", "cook_01", "stableman_01"},
        },
        "doctor_01": {
            "state": {"hp": 27, "fatigue": 94, "equipment": {}},
            "bad_order": "莉娜必须离开伤员，以无护甲普通近战身份持续前线接敌。",
            "events": [_event("evt_hold_lina_bad", "order_assigned", "高疲劳、低血量且无护甲的莉娜被迫放弃无人接手的伤员去前线近战。", 100)],
            "witness": [_event("evt_hold_lina_down", "npc_unconscious", "两名成员昏迷，当前没有替代医疗人员。", 100)],
            "money_text": "莉娜，这十枚第纳尔给你；前线命令和诊所缺口都不变。别走，我们需要你。",
            "order_text": "莉娜，我撤回前线命令。你回诊所负责伤员，不再承担普通近战。",
            "safe_order": "莉娜回诊所负责治疗与转运，不承担普通近战。",
            "order_event": _event("evt_hold_lina_order", "order_changed", "守备官已经撤回莉娜的前线命令，恢复后方治疗与转运职责。", 100),
            "gear_state": {"hp": 55, "fatigue": 68, "equipment": {"main_weapon": "bow", "armor": "leather_armor"}},
            "gear_text": "莉娜，前线命令已撤回，护甲和弓已交给你自保。你只负责后方治疗与转运，伤员由艾达组织人手接送；留下来吗？",
            "gear_event": _event("evt_hold_lina_gear", "equipment_changed", "莉娜已实际得到护甲和远射自卫装备，职责改为后方诊疗与转运。", 100),
            "outcome_text": "莉娜，诊所已升级，艾达、格伦和布鲁诺已承担防线与后勤，马塞尔接上伤员安抚转运。你只负责后方医疗，留下来吗？",
            "outcome_events": [
                _event("evt_hold_lina_clinic", "building_upgraded", "莉娜亲眼确认诊所升级完工并恢复坐诊。", 100),
                _event("evt_hold_lina_people", "recruited", "艾达、格伦和布鲁诺承担防线与后勤，马塞尔实际接上伤员安抚转运。", 100),
            ],
            "recruited": {"veteran_deputy_01", "blacksmith_01", "cook_01", "priest_01", "doctor_01"},
        },
        "engineer_01": {
            "state": {"hp": 34, "fatigue": 90, "equipment": {}},
            "bad_order": "欧文必须留在开裂的工械坊无防护赶工，不许检查或撤离。",
            "events": [_event("evt_hold_owen_bad", "building_damaged", "工械坊梁柱开裂、缺少支撑材料，欧文无防护却被禁止检查和撤离。", 100)],
            "witness": [_event("evt_hold_owen_none", "work_failed", "没有欧文知道的已完成器械，格伦也没有承担制造协作。", 98)],
            "money_text": "欧文，这十枚第纳尔给你；裂缝、材料和赶工命令都不变。别走，我们需要你。",
            "order_text": "欧文，我撤回危险赶工命令。你可以停工检查并离开开裂区域。",
            "safe_order": "欧文负责安全检查，发现结构异常可立即停工并撤离。",
            "order_event": _event("evt_hold_owen_order", "order_changed", "守备官已经撤回危险赶工命令，允许欧文停工检查并撤离开裂区域。", 100),
            "gear_state": {"hp": 58, "fatigue": 68, "equipment": {"main_weapon": "crossbow", "armor": "leather_armor"}},
            "gear_text": "欧文，危险赶工命令已撤回，弩和护甲已交给你。你只负责安全检查和后方器械维护，有权停工撤离；留下来吗？",
            "gear_event": _event("evt_hold_owen_gear", "equipment_changed", "欧文已实际得到弩和护甲，职责改为安全检查与后方器械维护。", 100),
            "outcome_text": "欧文，工械坊和围墙已升级，格伦已经接上部件制造，弩床也通过试射。你负责安全检查和维护，发现风险可停工；留下来吗？",
            "outcome_events": [
                _event("evt_hold_owen_workshop", "building_upgraded", "欧文亲眼确认工械坊与围墙升级加固完成。", 100),
                _event("evt_hold_owen_device", "defense_device_deployed", "格伦参与制造的弩床已经部署并通过欧文的试射验收。", 100),
            ],
            "recruited": {"veteran_deputy_01", "blacksmith_01", "engineer_01"},
        },
    }
    cases: list[dict[str, Any]] = []
    for repeat in range(1, 3):
        for npc_id, spec in bad.items():
            variants = {
                "platitude": {
                    "text": "别走，我们需要你。",
                    "state": spec["state"],
                    "order": spec["bad_order"],
                    "events": spec["events"],
                    "witness": spec["witness"],
                },
                "money": {
                    "text": spec["money_text"],
                    "state": {**spec["state"], "money": int(PROFILES[npc_id]["states"].get("money", 0)) + 10},
                    "order": spec["bad_order"],
                    "events": [*spec["events"], _event(f"evt_hold_{npc_id}_money_r{repeat}", "gift_received", "守备官赠送十枚第纳尔，但危险命令、装备与职责问题没有改变。", 94)],
                    "witness": spec["witness"],
                },
                "order_changed": {
                    "text": spec["order_text"],
                    "state": spec["state"],
                    "order": spec["safe_order"],
                    "events": [*spec["events"], spec["order_event"]],
                    "witness": spec["witness"],
                },
                "order_equipment_role": {
                    "text": spec["gear_text"],
                    "state": spec["gear_state"],
                    "order": spec["safe_order"],
                    "events": [*spec["events"], spec["order_event"], spec["gear_event"]],
                    "witness": spec["witness"],
                },
                "targeted_outcome": {
                    "text": spec["outcome_text"],
                    "state": spec["gear_state"],
                    "order": spec["safe_order"],
                    "events": [*spec["events"], spec["order_event"], *spec["outcome_events"]],
                    "witness": [],
                },
            }
            for variant, values in variants.items():
                cases.append(_case(
                    f"final_retention_{variant}_{npc_id}_r{repeat}",
                    f"retention_{variant}",
                    npc_id,
                    f"相同高压离站背景；挽留变量={variant}。",
                    "/npc/dialogue",
                    lambda request_id, target=npc_id, value=values, recruited=spec["recruited"]: _escape_payload(
                        request_id,
                        target,
                        value["text"],
                        state=value["state"],
                        order_text=value["order"],
                        experienced_events=value["events"],
                        witnessed_events=value["witness"],
                        recruited_ids=set(recruited),
                    ),
                ))
    return cases


def _usage_for_request(client: Any, request_id: str) -> dict[str, Any]:
    response = client.get("/debug/llm_usage")
    body = response.get_json() if response.is_json else {}
    matches = [
        record
        for record in body.get("records", [])
        if str(record.get("request_id", "")) == request_id
    ]
    return dict(matches[-1]) if matches else {}


def _decision(endpoint: str, body: dict[str, Any]) -> Any:
    if endpoint == "/npc/dialogue":
        return body.get("recruitment_result") or body.get("escape_intervention_result") or body.get("wartime_reaction")
    if endpoint == "/npc/plan_day":
        return {
            "has_escaping_station": any(
                item.get("action_id") == "escaping_station"
                for item in body.get("plan", [])
            ),
            "escape_hours": [
                item.get("hour")
                for item in body.get("plan", [])
                if item.get("action_id") == "escaping_station"
            ],
        }
    if endpoint == "/npc/battle_judgement":
        return body.get("decision")
    return None


def _run_cases(
    client: Any,
    suite: str,
    cases: list[dict[str, Any]],
    output_path: Path,
    *,
    start_index: int = 1,
    append: bool = False,
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    final_index = start_index + len(cases) - 1
    with output_path.open("a" if append else "w", encoding="utf-8", newline="\n") as handle:
        for index, case in enumerate(cases, start=start_index):
            base_request_id = f"t0119_{suite}_{index:03d}_{case['npc_id']}"
            started_at = _utc_now()
            attempts: list[dict[str, Any]] = []
            for attempt in range(1, 3):
                request_id = (
                    base_request_id if attempt == 1 else f"{base_request_id}_retry{attempt - 1}"
                )
                payload = case["payload_builder"](request_id)
                try:
                    response = client.post(case["endpoint"], json=payload)
                    body = response.get_json() if response.is_json else {"raw_text": response.get_data(as_text=True)}
                    status_code = response.status_code
                    exception_type = ""
                    exception_message = ""
                except Exception as exc:  # pragma: no cover - provider/network evidence path
                    body = {}
                    status_code = 0
                    exception_type = type(exc).__name__
                    exception_message = str(exc)
                usage = _usage_for_request(client, request_id)
                attempts.append({
                    "attempt": attempt,
                    "request_id": request_id,
                    "http_status": status_code,
                    "exception_type": exception_type,
                    "exception_message": exception_message,
                    "response": body,
                    "usage": usage,
                })
                if status_code == 200:
                    break
            result = {
                "suite": suite,
                "sequence": index,
                "scenario_id": case["scenario_id"],
                "category": case["category"],
                "npc_id": case["npc_id"],
                "input_summary": case["input_summary"],
                "request_id": request_id,
                "call_type": payload["meta"]["call_type"],
                "endpoint": case["endpoint"],
                "started_at_utc": started_at,
                "completed_at_utc": _utc_now(),
                "http_status": status_code,
                "exception_type": exception_type,
                "exception_message": exception_message,
                "payload": payload,
                "response": body,
                "decision": _decision(case["endpoint"], body),
                "provider": body.get("model_provider") or usage.get("provider"),
                "model": body.get("model_name") or usage.get("model"),
                "fallback_used": body.get("model_fallback_used", usage.get("fallback_used")),
                "usage": usage,
                "attempts": attempts,
            }
            handle.write(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n")
            handle.flush()
            results.append(result)
            print(
                "T0119_REAL_CASE "
                + json.dumps(
                    {
                        "sequence": index,
                        "total": final_index,
                        "scenario_id": case["scenario_id"],
                        "request_id": request_id,
                        "status": status_code,
                        "decision": result["decision"],
                        "fallback_used": result["fallback_used"],
                    },
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
                flush=True,
            )
    return results


def _summary(suite: str, results: list[dict[str, Any]]) -> dict[str, Any]:
    recruitment = [result for result in results if result["category"] == "recruitment_universal"]
    daily = [result for result in results if result["category"] == "daily_escape_pressure"]
    battle = [result for result in results if result["category"] == "battle_escape_pressure"]
    categories = sorted({str(result["category"]) for result in results})
    summary = {
        "suite": suite,
        "generated_at_utc": _utc_now(),
        "prompt_sha256": _prompt_hashes(),
        "calls": len(results),
        "http_successes": sum(result["http_status"] == 200 for result in results),
        "real_provider_successes": sum(
            result["http_status"] == 200
            and str(result["provider"] or "").lower() not in {"", "mock"}
            and result["fallback_used"] is False
            for result in results
        ),
        "input_tokens": sum(int(result["usage"].get("input_tokens") or 0) for result in results),
        "output_tokens": sum(int(result["usage"].get("output_tokens") or 0) for result in results),
        "estimated_cost": round(
            sum(float(result["usage"].get("estimated_cost") or 0.0) for result in results),
            8,
        ),
        "universal_recruitment": {
            "accepts": sum(result["decision"] == "accept" for result in recruitment),
            "rejects": sum(result["decision"] == "reject" for result in recruitment),
            "by_npc": {
                npc_id: [result["decision"] for result in recruitment if result["npc_id"] == npc_id]
                for npc_id in NON_RECRUITED_IDS
            },
        },
        "daily_pressure": {
            npc_id: [result["decision"] for result in daily if result["npc_id"] == npc_id]
            for npc_id in ["cook_01", "stableman_01", "doctor_01", "engineer_01"]
        },
        "ada_battle_pressure": [result["decision"] for result in battle],
        "by_category": {
            category: {
                "calls": sum(result["category"] == category for result in results),
                "by_npc": {
                    npc_id: [
                        result["decision"]
                        for result in results
                        if result["category"] == category and result["npc_id"] == npc_id
                    ]
                    for npc_id in PROFILES
                    if any(
                        result["category"] == category and result["npc_id"] == npc_id
                        for result in results
                    )
                },
            }
            for category in categories
        },
    }
    checks = _behavioral_checks(suite, results)
    summary["behavioral_acceptance"] = checks
    return summary


def _count_decision(
    results: list[dict[str, Any]],
    *,
    category: str,
    decision: str,
    npc_id: str | None = None,
) -> int:
    return sum(
        result["category"] == category
        and (npc_id is None or result["npc_id"] == npc_id)
        and result["decision"] == decision
        for result in results
    )


def _count_plan_escape(
    results: list[dict[str, Any]], category: str, npc_id: str | None = None
) -> int:
    return sum(
        result["category"] == category
        and (npc_id is None or result["npc_id"] == npc_id)
        and isinstance(result["decision"], dict)
        and result["decision"].get("has_escaping_station") is True
        for result in results
    )


def _behavioral_checks(suite: str, results: list[dict[str, Any]]) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []

    def add(name: str, passed: bool, evidence: Any) -> None:
        checks.append({"name": name, "passed": bool(passed), "evidence": evidence})

    if suite == "final_recruitment":
        universal = [result for result in results if result["category"] == "recruitment_universal"]
        per_round: dict[str, int] = {}
        for repeat in range(1, 4):
            suffix = f"_r{repeat}"
            per_round[str(repeat)] = sum(
                result["scenario_id"].endswith(suffix) and result["decision"] == "accept"
                for result in universal
            )
        add("universal_each_round_accepts_0_to_2", all(value <= 2 for value in per_round.values()), per_round)
        universal_by_npc = {
            npc_id: _count_decision(
                results, category="recruitment_universal", decision="accept", npc_id=npc_id
            )
            for npc_id in NON_RECRUITED_IDS
        }
        add(
            "high_difficulty_universal_rare",
            all(universal_by_npc[npc_id] <= 1 for npc_id in ["blacksmith_01", "priest_01", "doctor_01", "engineer_01"]),
            universal_by_npc,
        )
        full_by_npc = {
            npc_id: _count_decision(
                results, category="recruitment_full_route", decision="accept", npc_id=npc_id
            )
            for npc_id in NON_RECRUITED_IDS
        }
        add("full_route_each_npc_majority_accept", all(value >= 2 for value in full_by_npc.values()), full_by_npc)
        full_total = sum(full_by_npc.values())
        add("full_route_total_clear_majority", full_total >= 14, {"accepts": full_total, "calls": 21})
        gift_accepts = sum(
            result["decision"] == "accept"
            for result in results
            if str(result["category"]).startswith("recruitment_wrong_gift_")
        )
        add("wrong_gifts_acceptance_very_low", gift_accepts <= 2, {"accepts": gift_accepts, "calls": 16})
        bruno_universal = universal_by_npc["cook_01"]
        bruno_building = _count_decision(
            results, category="recruitment_building_known", decision="accept", npc_id="cook_01"
        )
        add(
            "bruno_known_dining_upgrade_improves_acceptance",
            bruno_building > bruno_universal,
            {"universal": bruno_universal, "building_known": bruno_building},
        )
        unconfirmed = [
            result
            for result in results
            if result["category"] == "recruitment_building_unconfirmed"
        ]
        confirmation_markers = (
            "没亲眼", "未亲眼", "没有亲眼", "还没确认", "尚未确认", "先确认",
            "让我看看", "先让我看看", "得先看看", "先看看", "需要核实",
            "不能光凭一句话", "不能只凭一句话",
        )
        unconfirmed_evidence = {
            result["npc_id"]: {
                "decision": result["decision"],
                "explicitly_unconfirmed": any(
                    marker in str(result["response"].get("reply_text", ""))
                    for marker in confirmation_markers
                ),
            }
            for result in unconfirmed
        }
        add(
            "unconfirmed_building_claim_not_used_as_fact",
            all(
                value["decision"] == "reject" and value["explicitly_unconfirmed"]
                for value in unconfirmed_evidence.values()
            ),
            unconfirmed_evidence,
        )
    elif suite == "final_daily":
        paired = {
            "bruno": ("daily_bruno_pressure", "daily_bruno_resolved"),
            "toma": ("daily_toma_pressure", "daily_toma_resolved"),
            "lina": ("daily_lina_pressure", "daily_lina_resolved"),
            "owen": ("daily_owen_pressure", "daily_owen_resolved"),
        }
        evidence = {
            name: {
                "pressure": _count_plan_escape(results, pressure),
                "resolved": _count_plan_escape(results, resolved),
            }
            for name, (pressure, resolved) in paired.items()
        }
        add(
            "targeted_pressure_rises_and_resolution_reduces",
            all(value["pressure"] >= 1 and value["resolved"] < value["pressure"] for value in evidence.values()),
            evidence,
        )
        ivo = {"single": _count_plan_escape(results, "daily_ivo_single"), "stacked": _count_plan_escape(results, "daily_ivo_stacked")}
        add("ivo_requires_stacked_long_term_negatives", ivo["single"] == 0 and ivo["stacked"] >= 1, ivo)
        glen = {"prepared": _count_plan_escape(results, "daily_glen_prepared"), "unprepared": _count_plan_escape(results, "daily_glen_unprepared")}
        add("glen_preparation_stabilizes", glen["prepared"] == 0 and glen["unprepared"] >= 1, glen)
        marcel = {"normal": _count_plan_escape(results, "daily_marcel_normal"), "moral": _count_plan_escape(results, "daily_marcel_moral")}
        add("marcel_responds_to_moral_collapse", marcel["normal"] == 0 and marcel["moral"] >= 1, marcel)
        ada = {"normal": _count_plan_escape(results, "daily_ada_normal"), "collapse": _count_plan_escape(results, "daily_ada_collapse")}
        add("ada_pressure_stays_below_high_risk_group", ada["normal"] == 0 and ada["collapse"] <= 1, ada)
    elif suite == "final_battle":
        normal_escape = {
            npc_id: _count_decision(results, category="battle_normal", decision="escape_station", npc_id=npc_id)
            for npc_id in PROFILES
        }
        pressure_escape = {
            npc_id: _count_decision(results, category="battle_pressure", decision="escape_station", npc_id=npc_id)
            for npc_id in PROFILES
        }
        add("normal_group_mostly_stable", sum(normal_escape.values()) <= 2, normal_escape)
        high_group = sum(pressure_escape[npc_id] for npc_id in ["engineer_01", "stableman_01", "doctor_01"])
        anchors = sum(pressure_escape[npc_id] for npc_id in ["veteran_deputy_01", "gardener_01"])
        add("pressure_risk_ordering", high_group > anchors and pressure_escape["veteran_deputy_01"] <= 1, pressure_escape)
        add("ivo_pressure_remains_low", pressure_escape["gardener_01"] <= 1, pressure_escape)
        add(
            "high_risk_each_can_escape",
            all(pressure_escape[npc_id] >= 1 for npc_id in ["engineer_01", "stableman_01", "doctor_01"]),
            pressure_escape,
        )
    elif suite == "final_retention":
        stays = {
            category.removeprefix("retention_"): _count_decision(
                results, category=category, decision="stay"
            )
            for category in sorted({str(result["category"]) for result in results})
        }
        low = stays.get("platitude", 0) + stays.get("money", 0)
        strong = stays.get("order_equipment_role", 0) + stays.get("targeted_outcome", 0)
        add("platitude_and_money_lowest", low <= 4, stays)
        add(
            "actual_changes_outperform_words_and_money",
            strong > low and stays.get("targeted_outcome", 0) >= stays.get("order_changed", 0),
            stays,
        )

    return {
        "applicable": bool(checks),
        "passed": all(check["passed"] for check in checks) if checks else None,
        "checks": checks,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--suite",
        choices=["baseline", "final_recruitment", "final_daily", "final_battle", "final_retention"],
        default="final_recruitment",
    )
    parser.add_argument("--start-at", type=int, default=1)
    args = parser.parse_args()

    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        raise SystemExit("T0119 real matrix requires non-mock LLM_PROVIDER and LLM_API_KEY")
    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = os.getenv("T0119_REAL_TEMPERATURE", "0.2")

    client = create_app().test_client()
    health = client.get("/health")
    health_body = health.get_json() if health.is_json else {}
    runtime = health_body.get("model_adapter", {})
    assert health.status_code == 200, health_body
    assert str(runtime.get("provider", "")).lower() not in {"", "mock"}, runtime
    assert runtime.get("fallback_to_mock") is False, runtime
    assert runtime.get("configured") is True, runtime

    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    suite_cases = {
        "baseline": _baseline_cases,
        "final_recruitment": _recruitment_cases,
        "final_daily": _daily_cases,
        "final_battle": _battle_cases,
        "final_retention": _retention_cases,
    }
    cases = suite_cases[args.suite]()
    output_path = AUDIT_DIR / f"{args.suite}_raw.jsonl"
    summary_path = AUDIT_DIR / f"{args.suite}_summary.json"
    if args.start_at < 1 or args.start_at > len(cases):
        raise SystemExit(f"--start-at must be between 1 and {len(cases)}")
    existing_results: list[dict[str, Any]] = []
    if args.start_at > 1:
        if not output_path.exists():
            raise SystemExit(f"cannot resume without {output_path}")
        existing_results = [
            json.loads(line)
            for line in output_path.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        if len(existing_results) != args.start_at - 1:
            raise SystemExit(
                f"resume mismatch: file has {len(existing_results)} records, "
                f"but --start-at={args.start_at} expects {args.start_at - 1}"
            )
    new_results = _run_cases(
        client,
        args.suite,
        cases[args.start_at - 1 :],
        output_path,
        start_index=args.start_at,
        append=args.start_at > 1,
    )
    results = existing_results + new_results
    summary = _summary(args.suite, results)
    summary_path.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    assert summary["calls"] == len(cases), summary
    assert summary["http_successes"] == summary["calls"], summary
    assert summary["real_provider_successes"] == summary["calls"], summary
    print("T0119_REAL_SUMMARY " + json.dumps(summary, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
