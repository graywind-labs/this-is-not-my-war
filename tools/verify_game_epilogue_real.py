from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from dotenv import load_dotenv


ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / "backend" / ".env", override=False)
sys.path.insert(0, str(ROOT))

from backend.app import create_app


SCENARIOS = {
    "stableman_01": {"recruited": True, "status": "active", "hp": 71, "location": "后门", "order": "守住后门，但先把受伤的马牵回马厩", "fact": "托马应征后守住后门，并在箭雨中把受伤的栗风牵回马厩。"},
    "cook_01": {"recruited": False, "status": "active", "hp": 83, "location": "食堂", "order": "", "fact": "布鲁诺没有入伍，却在五次敌袭之间持续为守卫和伤员准备热饭。"},
    "gardener_01": {"recruited": False, "status": "active", "hp": 76, "location": "菜园", "order": "", "fact": "伊沃拒绝应征，第四波后仍从烧焦的菜畦里抢救出一袋种子。"},
    "blacksmith_01": {"recruited": True, "status": "unconscious", "hp": 0, "location": "正门", "order": "正门失守前不要后退", "fact": "格伦赶制了最后两件锁子甲，随后在正门作战中负伤昏迷，结算时尚未醒来。"},
    "veteran_deputy_01": {"recruited": True, "status": "active", "hp": 42, "location": "主厅", "order": "组织轮换，任何人昏迷后立刻后送", "fact": "艾达组织了五轮防线轮换，并亲自把两名昏迷者送离城门。"},
    "priest_01": {"recruited": False, "status": "escaped", "hp": 88, "location": "驿站外", "order": "", "fact": "马塞尔没有入伍；第四波警报后，他因恐惧从后门离开，此后没有参加最后守城。"},
    "doctor_01": {"recruited": False, "status": "unconscious", "hp": 0, "location": "小诊所", "order": "优先救治昏迷者", "fact": "莉娜没有入伍，连续救治多名伤员，最后在诊所受冲击后昏迷，结算时尚未醒来。"},
    "engineer_01": {"recruited": True, "status": "active", "hp": 55, "location": "围墙", "order": "保证器械安全，再修围墙", "fact": "欧文应征后修复围墙并维护箭塔，最后一波中及时停用了发生裂纹的弩床。"},
}


def build_payload(result: str) -> dict:
    profiles = json.loads((ROOT / "data" / "npc_profiles.json").read_text(encoding="utf-8"))
    npcs = []
    for profile in profiles:
        npc_id = profile["id"]
        scenario = dict(SCENARIOS[npc_id])
        original_status = scenario["status"]
        if result == "failure":
            scenario.update({"status": "escaped", "location": "驿站外"})
        if result == "victory" and npc_id == "priest_01":
            scenario.update({
                "status": "active",
                "location": "小教堂",
                "fact": "马塞尔没有入伍；最后一波中他留在小教堂照看恐慌者，并为撤回来的伤员腾出长凳。",
            })
        status = scenario["status"]
        max_hp = int(profile.get("base_stats", {}).get("max_hp", 100))
        fact_id = f"npc_{npc_id}_turning_point"
        npcs.append({
            "npc_id": npc_id,
            "name": profile["name"],
            "profession": profile["background_job"],
            "background_story": profile.get("background_story", ""),
            "personality": profile.get("personality", [])[:6],
            "desires": profile.get("desires", [])[:6],
            "fears": profile.get("fears", [])[:6],
            "recruited": scenario["recruited"],
            "opening_status": status,
            "escape_circumstance": (
                "before_fall_voluntary" if result == "failure" and original_status == "escaped"
                else "after_fall_forced" if result == "failure"
                else "none"
            ),
            "hp": min(scenario["hp"], max_hp),
            "max_hp": max_hp,
            "final_location": scenario["location"],
            "current_order": {"text": scenario["order"]} if scenario["order"] else {},
            "diary": [f"我记得那一天：{scenario['fact']}"],
            "knowledge": ["守备官的命令与实际选择并不总是一致。"],
            "key_facts": [
                {"fact_id": f"npc_{npc_id}_final", "category": "final_state", "summary": f"{profile['name']}结算时状态为{status}，{'已经' if scenario['recruited'] else '没有'}入伍。"},
                {"fact_id": fact_id, "category": "turning_point", "summary": scenario["fact"]},
            ],
        })
    outcome = "驿站守住第五波敌军，主厅仍然屹立，但多人负伤，两人结算时仍在昏迷。" if result == "victory" else "第五波敌军摧毁主厅，驿站失守；所有初始成员都活着，但众人被迫面对离散与未兑现的安排。"
    return {
        "meta": {"request_id": f"real_epilogue_{result}", "call_type": "game_epilogue", "source": "backend_test", "requires_time_slowdown": False, "related_event_id": None},
        "settlement_id": f"real_acceptance_{result}",
        "fact_snapshot_version": 1,
        "result": result,
        "reason": "five_waves_survived" if result == "victory" else "main_hall_destroyed",
        "game_time": {"day": 6, "time": "19:12:00"},
        "station_summary": {"wave_number": 5, "station_operational": result == "victory", "summary": outcome},
        "global_facts": [{"fact_id": "global_outcome", "category": "settlement", "summary": outcome}],
        "npcs": npcs,
    }


def main() -> None:
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock":
        raise SystemExit("REAL_EPILOGUE_SKIPPED: LLM_PROVIDER is mock")
    if not os.getenv("LLM_API_KEY", "").strip():
        raise SystemExit("REAL_EPILOGUE_SKIPPED: LLM_API_KEY is missing")
    app = create_app()
    client = app.test_client()
    results = {}
    requested_results = tuple(sys.argv[1:]) or ("victory", "failure")
    if any(result not in ("victory", "failure") for result in requested_results):
        raise SystemExit("Usage: verify_game_epilogue_real.py [victory] [failure]")
    for result in requested_results:
        response = client.post("/game/epilogue", json=build_payload(result))
        body = response.get_json()
        if response.status_code != 200:
            raise RuntimeError(f"{result} HTTP {response.status_code}: {body}")
        assert body["model_provider"] != "mock"
        assert body["model_fallback_used"] is False
        assert len(body["npc_endings"]) == 8
        results[result] = body
    print(json.dumps(results, ensure_ascii=False, indent=2))
    print("REAL_GAME_EPILOGUE_%s_OK" % "_".join(result.upper() for result in requested_results))


if __name__ == "__main__":
    main()
