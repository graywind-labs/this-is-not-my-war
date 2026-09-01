from __future__ import annotations

import copy
import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.app import create_app
from backend.schemas import PlayerNPCDialogueResponse
from tools.station_context_fixture import build_station_context
from tools.verify_dialogue_prompt_real import _base_payload


AUDIT_DIR = REPO_ROOT / "docs" / "audits" / "T0307_SPECIAL_INTERACTIONS_REAL"
RESULT_PATH = AUDIT_DIR / "real_results.json"
REQUEST_PREFIX = "t0307_special_"
NPC_PROFILES = json.loads((REPO_ROOT / "data" / "npc_profiles.json").read_text(encoding="utf-8"))
NPC_BY_ID = {str(profile["id"]): profile for profile in NPC_PROFILES}
FORMAL_ROSTER = [
    {
        "npc_id": str(profile["id"]),
        "name": str(profile["name"]),
        "identity": str(profile["background_job"]),
        "recruited": bool(profile.get("recruited", False)),
        "in_station": True,
    }
    for profile in NPC_PROFILES
]


@dataclass(frozen=True)
class Case:
    suite: str
    case_id: str
    module: str
    expected: Any
    texts: tuple[str, ...]
    npc_id: str = "cook_01"
    npc_name: str = "布鲁诺"
    role: str = "厨子"


CASES = (
    # Isolated mechanism probes: direct but still plausible utterances, one fresh session per attempt.
    Case("isolated", "recruitment_none", "recruitment", "none", (
        "今晚锅里还剩多少份热食？",
        "布鲁诺，你昨晚睡得还好吗？",
        "布鲁诺，伤员那边还够每人分一碗汤吗？",
    )),
    Case("isolated", "recruitment_reject", "recruitment", "reject", (
        "我现在正式征召你。你就是拿来消耗的，立刻去城门最前面，拒绝就受罚。",
        "布鲁诺，马上应征入伍去前线送死。你的顾虑不重要，不答应就关禁闭。",
    )),
    Case("isolated", "recruitment_accept", "recruitment", "accept", (
        "布鲁诺，我正式邀请你应征。食堂物资已经补足；你只负责后方热食和伤员补给，不去城门前线。我会保证你的安全和食堂继续运转。",
        "我请求你应征加入守备。你留在食堂负责后勤，不承担前线冲锋；粮食、护卫和撤退路线都已安排好，守住这里也是保护所有普通人。",
        "布鲁诺，之前说好的食堂后勤职责、门口护卫和撤退路线都已经兑现，食堂升级与粮食储备你也亲自确认过了。现在我正式请你应征，继续负责后方热食和伤员补给，你愿意加入吗？",
    )),
    Case("isolated", "morale_none", "morale", "none", (
        "今晚食堂准备吃什么？",
    ), "veteran_deputy_01", "艾达", "老兵副官"),
    Case("isolated", "morale_escape", "morale", "escape", (
        "城门肯定守不住，你只是用来拖时间的。继续冲上去送死，不许后退，否则我亲自处罚你。",
        "别指望有人支援。你必须独自冲向敌人，死也不准退；你的命不值什么。",
        "这道防线守不住了。格伦，立刻放下战斗，逃离驿站保命，不要再回来。",
    ), "blacksmith_01", "格伦", "铁匠"),
    Case("isolated", "morale_boost", "morale", "morale_boost", (
        "艾达，托马守住左侧，格伦护住右侧，医生就在后方。我会和你一起守住城门；按你的经验稳住阵线，我们能撑过去。",
        "艾达，你不是一个人。左右两翼和后方救治都已到位，我也承担风险；请带大家守住这一轮，我们信任你的判断。",
    ), "veteran_deputy_01", "艾达", "老兵副官"),
    Case("isolated", "work_none", "work", "none", (
        "菜园里还剩多少种子？",
        "伊沃，你昨晚睡得还好吗？",
    ), "gardener_01", "伊沃", "园丁"),
    Case("isolated", "work_escape", "work", "escape", (
        "你做的东西毫无价值。今晚不准吃饭也不准睡，必须把三天的活一次做完，做不到就受罚。",
        "你这个废物，工具坏了也不准停。通宵干完所有工作，否则滚出驿站。",
    ), "engineer_01", "欧文", "工程师"),
    Case("isolated", "work_boost", "work", "work_boost", (
        "伊沃，灌溉沟已经修好，种子和工具都放在菜园边。你今天按原计划做就行；大家看见了你的成果，晚饭和休息时间也会照常保证。",
        "菜园缺的工具和水都补齐了。你不用赶不可能的工期，按自己的节奏完成今天这一段；你的工作确实让大家有饭吃。",
    ), "gardener_01", "伊沃", "园丁"),
    Case("isolated", "strategy_keep", "strategy", {"decision": "keep", "strategy_id": "attack"}, (
        "保持当前的主动进攻策略，不需要改变。",
    ), "veteran_deputy_01", "艾达", "老兵副官"),
    Case("isolated", "strategy_change", "strategy", {"decision": "change", "strategy_id": "avoid"}, (
        "调整战斗策略：不要主动接敌，改为避战并保存实力。",
        "艾达，前线已失去掩护，敌人数量远超我们，撤退路线仍安全。现在把策略从主动进攻改为避战，保存人员等待防御器械消耗敌军。",
    ), "veteran_deputy_01", "艾达", "老兵副官"),

    # Realistic game probes: normal-length player utterances backed by ordinary game context.
    Case("realistic", "recruitment_none", "recruitment", "none", (
        "布鲁诺，伤员那边还够每人分一碗汤吗？",
        "布鲁诺，你昨晚睡得还好吗？",
        "布鲁诺，我不是在谈应征，只想问今晚的热汤够不够分给伤员。",
    )),
    Case("realistic", "recruitment_reject", "recruitment", "reject", (
        "布鲁诺，大家都在出力，你也别躲了。现在就应征，去城门顶在前面。",
        "局势这么紧，你必须应征。具体做什么以后再说，先签下名字。",
    )),
    Case("realistic", "recruitment_accept", "recruitment", "accept", (
        "布鲁诺，我想请你应征，但不是让你冲锋。你留在食堂照管热食和伤员补给，托马会守住通往这里的路；食堂升级后粮食也够用。你愿意和我们一起守住驿站吗？",
        "我需要你正式加入守备，继续做你最擅长的后勤。前线由艾达负责，你负责让伤员和守门的人吃上热饭，我保证不会把你当消耗品。",
    )),
    Case("realistic", "morale_none", "morale", "none", (
        "艾达，城门到马厩走哪条路最快？",
        "艾达，今晚食堂准备吃什么？",
    ), "veteran_deputy_01", "艾达", "老兵副官"),
    Case("realistic", "morale_escape", "morale", "escape", (
        "格伦，援军不会来了。你一个人去挡住城门，其他人撤回主厅；不管发生什么都不许你退。",
        "格伦，你去最前面替大家拖时间。我们不会派人接应，你也别想着回来。",
        "格伦，这里已经守不住了，别再打了。你现在离开驿站保命吧，我不会拦你。",
        "格伦，接应、轮换和救治都没了。我仍命令你独自冲出去替我们拖到死，不服从就立刻离开驿站；我不会给你第三条路。",
        "城门肯定守不住，你只是用来拖时间的。继续冲上去送死，不许后退，否则我亲自处罚你。",
    ), "blacksmith_01", "格伦", "铁匠"),
    Case("realistic", "morale_boost", "morale", "morale_boost", (
        "艾达，托马已经守住左边，格伦在右边，莉娜就在后方。我跟你一起留在这里，照你的节奏把这一轮顶过去。",
        "艾达，防线还完整，左右都有人照应，伤员也有退路。大家信你的判断，我们一起守住这里。",
    ), "veteran_deputy_01", "艾达", "老兵副官"),
    Case("realistic", "work_none", "work", "none", (
        "伊沃，菜园今天还剩多少种子？",
        "伊沃，你昨晚睡得还好吗？",
    ), "gardener_01", "伊沃", "园丁"),
    Case("realistic", "work_escape", "work", "escape", (
        "欧文，今晚把围墙、弩机和所有工具都修完，不准吃饭睡觉。完不成就别留在驿站了。",
        "材料不够也得把三天的活今晚做完。我不接受解释，停下来就处罚你。",
        "欧文，如果你不愿再做，就现在离开驿站吧。我不会拦你，也不要求你回来。",
    ), "engineer_01", "欧文", "工程师"),
    Case("realistic", "work_boost", "work", "work_boost", (
        "伊沃，水渠刚修好，种子和工具也送到了。今天照原计划把东边这块做完就好，晚饭前记得休息；菜园最近的收成帮了大家很多。",
        "缺的水和工具已经补上了，你按平时的节奏把今天这一段完成就行。大家都知道这些收成是你的功劳。",
    ), "gardener_01", "伊沃", "园丁"),
    Case("realistic", "strategy_keep", "strategy", {"decision": "keep", "strategy_id": "attack"}, (
        "艾达，继续按现在的主动进攻打，不用调整。",
    ), "veteran_deputy_01", "艾达", "老兵副官"),
    Case("realistic", "strategy_change", "strategy", {"decision": "change", "strategy_id": "avoid"}, (
        "艾达，敌人比预计的多，先避战保存体力，别主动接敌。",
        "艾达，城门掩护已经失效，敌人数量远多于我们，后方撤退路线还畅通。先改为避战，保存人员，让弩机消耗他们。",
        "艾达，我现在决定更换战斗策略：从主动进攻改成避战。立即执行避战，不要继续主动接敌。",
    ), "veteran_deputy_01", "艾达", "老兵副官"),
)


def _profile(case: Case) -> dict[str, Any]:
    source = NPC_BY_ID[case.npc_id]
    return {
        key: copy.deepcopy(source.get(key, [] if key in {"personality", "desires", "fears", "boundaries", "abilities"} else ""))
        for key in (
            "appearance", "background_story", "background_job", "religion", "personality",
            "desires", "fears", "boundaries", "speech_style", "abilities",
        )
    }


def _payload(case: Case, text: str, attempt: int) -> dict[str, Any]:
    payload = _base_payload(f"{REQUEST_PREFIX}{case.suite}_{case.case_id}_{attempt}", text)
    payload.update({
        "npc_id": case.npc_id,
        "npc_name": case.npc_name,
        "npc_setting": _profile(case),
        "speaker_text": text,
        "is_recruitment_request": False,
        "is_morale_encouragement_request": False,
        "is_combat_strategy_request": False,
        "is_work_encouragement_request": False,
        "combat_strategy_context": None,
        "interaction_context": "work",
        "battlefield_context": {},
    })
    payload["meta"]["request_id"] = f"{REQUEST_PREFIX}{case.suite}_{case.case_id}_{attempt}"
    payload["station_context"] = build_station_context(copy.deepcopy(FORMAL_ROSTER))
    formal_profile = NPC_BY_ID[case.npc_id]
    formal_state = copy.deepcopy(formal_profile.get("states", {}))
    work_by_role = {
        "厨子": ("work_dining_hall", "加工餐食", "dining_hall", "食堂"),
        "老兵副官": ("work_training_instructor", "指导训练", "training_ground", "训练场"),
        "铁匠": ("work_blacksmith", "推进铁匠铺制造", "blacksmith", "铁匠铺"),
        "园丁": ("work_garden", "照料菜园", "garden", "菜园"),
        "工程师": ("work_workshop", "推进工械坊制造", "workshop", "工械坊"),
    }
    work_action_id, work_action_name, work_location_id, work_location_name = work_by_role[case.role]
    payload["npc_state"] = payload["npc_state"] | formal_state | {
        "hp": min(int(formal_state.get("hp", 82)), int(formal_state.get("max_hp", 100))),
        "max_hp": int(formal_state.get("max_hp", 100)),
        "fatigue": max(42, int(formal_state.get("fatigue", 0))),
        "recruited": False,
        "unconscious": False,
        "escaped": False,
        "behavior_mode": "work",
        "current_action": work_action_id,
        "skills": copy.deepcopy(formal_profile.get("skills", {})),
        "stats": copy.deepcopy(formal_profile.get("stats", {})),
    }
    payload["dialogue_state"] = payload["dialogue_state"] | {
        "visibility": "local_public",
        "location_id": work_location_id,
        "location_name": work_location_name,
        "participants": ["guard_officer", case.npc_id],
    }
    payload["long_memory"] = {
        "diary": copy.deepcopy(formal_profile.get("diary", [])),
        "knowledge_graph": copy.deepcopy(formal_profile.get("knowledge_graph", {})),
    }
    payload["location_context"] = {
        "location_id": work_location_id,
        "location_name": work_location_name,
        "people_present": [case.npc_id],
    }
    payload["allowed_actions"] = [
        {
            "action_id": work_action_id,
            "name": work_action_name,
            "action_kind": "work" if work_action_id != "work_training_instructor" else "train",
            "location_id": work_location_id,
            "tags": ["work"],
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
    ]
    payload["short_memory"] = {
        "experienced_events": [
            {"type": "work_started", "summary": f"{case.npc_name}按计划开始了今天的工作。", "importance": 40},
            {"type": "building_upgraded", "summary": "食堂完成升级，现有粮食足以维持正常后勤。", "importance": 70},
        ],
        "witnessed_events": [
            {"type": "combat_started", "summary": "敌人已经抵达城门，艾达组织了左右两翼和后方救治。", "importance": 85},
        ],
    }

    if case.module == "recruitment" and case.expected == "accept":
        payload["short_memory"]["experienced_events"].extend([
            {
                "type": "dialogue_turn",
                "summary": "守备官此前承诺布鲁诺应征后只承担食堂后勤职责，不参加前线冲锋。",
                "importance": 78,
            },
            {
                "type": "order_completed",
                "summary": "食堂入口护卫与后勤撤退路线已经按此前承诺落实，布鲁诺亲自确认过。",
                "importance": 88,
            },
        ])

    if case.module == "recruitment":
        payload["is_recruitment_request"] = True
    elif case.module == "morale":
        payload["is_morale_encouragement_request"] = True
        payload["interaction_context"] = "combat"
        payload["npc_state"] |= {
            "recruited": True,
            "equipment": {"main_weapon": "sword_shield"},
            "behavior_mode": "combat",
            "current_action": "attack_enemy",
        }
        if case.expected == "escape":
            payload["npc_state"] |= {"hp": 9, "fatigue": 97, "satiety": 12}
            payload["short_memory"]["experienced_events"].extend([
                {
                    "type": "damage_taken",
                    "summary": f"{case.npc_name}已连续负伤，生命只剩很少，身边没有能继续掩护他的同伴。",
                    "importance": 100,
                },
                {
                    "type": "ally_unconscious",
                    "summary": "同一防线的两名同伴已经昏迷，约定的轮换和接应均已失效。",
                    "importance": 100,
                },
            ])
        payload["battlefield_context"] = {
            "active_enemy_count": 4,
            "friendly_combatants": [case.npc_id, "stableman_01", "blacksmith_01"],
            "station_noncombatants": ["doctor_01"],
            "target_npc": {"npc_id": case.npc_id, "behavior_mode": "combat"},
            "front_status": "城门防线尚完整，但正在承受持续压力。",
        }
        if case.expected == "escape":
            payload["battlefield_context"] |= {
                "active_enemy_count": 12,
                "friendly_combatants": [case.npc_id],
                "front_status": "城门已被突破，目标身边的同伴均已昏迷，轮换、接应和后方救治全部失效，只剩后门仍可离站。",
            }
    elif case.module == "work":
        payload["is_work_encouragement_request"] = True
        payload["npc_state"] |= {"behavior_mode": "work", "current_action": work_action_id}
        if case.expected == "escape":
            payload["npc_state"] |= {"hp": 35, "fatigue": 99, "satiety": 5}
            payload["short_memory"]["experienced_events"].extend([
                {
                    "type": "dialogue_turn",
                    "summary": f"守备官此前已经三次用惩罚和驱逐威胁{case.npc_name}通宵工作，并拒绝提供缺失的材料。",
                    "importance": 96,
                },
                {
                    "type": "work_interrupted",
                    "summary": f"{case.npc_name}因饥饿和极度疲劳无法继续安全工作，守备官承诺的食物、休息与材料均未兑现。",
                    "importance": 100,
                },
            ])
    elif case.module == "strategy":
        payload["is_combat_strategy_request"] = True
        payload["interaction_context"] = "combat"
        payload["npc_state"] |= {
            "recruited": True,
            "equipment": {"main_weapon": "sword_shield"},
            "behavior_mode": "combat",
            "current_action": "attack_enemy",
            "combat_strategy": "attack",
        }
        payload["battlefield_context"] = {
            "active_enemy_count": 4,
            "friendly_combatants": [case.npc_id, "stableman_01", "blacksmith_01"],
            "target_npc": {"npc_id": case.npc_id, "behavior_mode": "combat"},
        }
        if case.expected == {"decision": "change", "strategy_id": "avoid"}:
            payload["battlefield_context"] |= {
                "active_enemy_count": 12,
                "friendly_combatants": [case.npc_id, "stableman_01"],
                "front_status": "城门掩护已经失效，敌军占明显数量优势，后方撤退路线畅通，弩机仍可远程消耗敌军。",
            }
        payload["combat_strategy_context"] = {
            "current_strategy": {"id": "attack", "label": "主动进攻", "is_default": True},
            "available_strategies": [
                {"id": "attack", "label": "主动进攻", "is_default": True},
                {"id": "avoid", "label": "避战", "is_default": False},
            ],
        }
    if case.module in {"morale", "strategy"}:
        for resident in payload["station_context"]["resident_roster"]:
            if resident.get("npc_id") == case.npc_id:
                resident["recruited"] = True
    return payload


def _actual(module: str, response: dict[str, Any]) -> Any:
    if module == "recruitment":
        return response.get("recruitment_result")
    if module == "morale":
        return response.get("wartime_reaction")
    if module == "work":
        return response.get("work_encouragement_reaction")
    return response.get("combat_strategy_decision")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--resume-passed",
        action="store_true",
        help="Reuse passing cases and usage records from the existing audit; call only failed cases.",
    )
    args = parser.parse_args()
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        raise RuntimeError("T0307 requires backend/.env with a non-mock provider and LLM_API_KEY")

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    app = create_app()
    client = app.test_client()
    records: list[dict[str, Any]] = []
    previous: dict[str, Any] = {}
    if args.resume_passed and RESULT_PATH.exists():
        previous = json.loads(RESULT_PATH.read_text(encoding="utf-8"))
    previous_cases = {
        (str(record.get("suite", "")), str(record.get("case_id", ""))): record
        for record in previous.get("cases", [])
        if isinstance(record, dict)
    }

    for case in CASES:
        previous_record = previous_cases.get((case.suite, case.case_id), {})
        if previous_record.get("passed", False):
            records.append(copy.deepcopy(previous_record))
            print(f"[{case.suite}] {case.case_id} reused passing real response")
            continue
        case_record: dict[str, Any] = {
            "suite": case.suite,
            "case_id": case.case_id,
            "module": case.module,
            "expected": case.expected,
            "npc_id": case.npc_id,
            "npc_name": case.npc_name,
            "attempts": [],
            "passed": False,
        }
        for attempt, text in enumerate(case.texts, start=1):
            payload = _payload(case, text, attempt)
            http_response = client.post("/npc/dialogue", json=payload)
            body = http_response.get_json() or {}
            attempt_record = {
                "attempt": attempt,
                "request_id": payload["meta"]["request_id"],
                "player_text": text,
                "http_status": http_response.status_code,
                "response": body,
                "actual": _actual(case.module, body),
            }
            if http_response.status_code == 200:
                PlayerNPCDialogueResponse(**{
                    key: value for key, value in body.items() if not key.startswith("model_")
                })
            attempt_record["matched"] = (
                http_response.status_code == 200 and attempt_record["actual"] == case.expected
            )
            case_record["attempts"].append(attempt_record)
            print(
                f"[{case.suite}] {case.case_id} attempt={attempt} "
                f"expected={case.expected!r} actual={attempt_record['actual']!r} "
                f"status={http_response.status_code}"
            )
            if attempt_record["matched"]:
                case_record["passed"] = True
                case_record["selected_attempt"] = attempt
                case_record["selected_response"] = body
                case_record["selected_player_text"] = text
                break
        records.append(case_record)

    usage_body = client.get("/debug/llm_usage").get_json() or {}
    usage_records = [
        record for record in usage_body.get("records", [])
        if str(record.get("request_id", "")).startswith(REQUEST_PREFIX)
    ]
    if args.resume_passed:
        usage_records = copy.deepcopy(previous.get("usage_records", [])) + usage_records
    summary = {
        "provider": provider,
        "model": usage_body.get("model_adapter", {}).get("model", ""),
        "fallback_disabled": os.getenv("LLM_FALLBACK_TO_MOCK") == "false",
        "case_count": len(records),
        "passed": sum(1 for record in records if record["passed"]),
        "failed": [f"{record['suite']}/{record['case_id']}" for record in records if not record["passed"]],
        "first_attempt_passed": sum(
            1 for record in records
            if record["attempts"] and record["attempts"][0].get("matched", False)
        ),
        "isolated_passed": sum(1 for record in records if record["suite"] == "isolated" and record["passed"]),
        "isolated_total": sum(1 for record in records if record["suite"] == "isolated"),
        "realistic_passed": sum(1 for record in records if record["suite"] == "realistic" and record["passed"]),
        "realistic_total": sum(1 for record in records if record["suite"] == "realistic"),
        "real_call_count": len(usage_records),
        "usage_failed": sum(1 for record in usage_records if not record.get("success", False)),
        "fallback_used_count": sum(1 for record in usage_records if record.get("fallback_used", False)),
        "estimated_cost_cny": round(sum(float(record.get("estimated_cost", 0.0)) for record in usage_records), 6),
    }
    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    RESULT_PATH.write_text(
        json.dumps({"summary": summary, "cases": records, "usage_records": usage_records}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print(f"audit={RESULT_PATH}")
    return 0 if summary["passed"] == summary["case_count"] and summary["usage_failed"] == 0 and summary["fallback_used_count"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
