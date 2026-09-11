from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ["LLM_PROVIDER"] = "mock"
os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.app import create_app


def payload(result: str) -> dict:
    return {
        "meta": {
            "request_id": f"verify_epilogue_{result}",
            "call_type": "game_epilogue",
            "source": "backend_test",
            "requires_time_slowdown": False,
            "related_event_id": None,
        },
        "settlement_id": f"settlement_{result}",
        "fact_snapshot_version": 1,
        "result": result,
        "reason": "five_waves_survived" if result == "victory" else "main_hall_destroyed",
        "game_time": {"day": 6, "time": "18:30:00"},
        "station_summary": {"buildings": {"station_operational": result == "victory"}},
        "global_facts": [{
            "fact_id": "global_outcome",
            "category": "settlement",
            "summary": "驿站守住了五波敌军。" if result == "victory" else "主厅被摧毁，驿站失守。",
        }],
        "npcs": [
            {
                "npc_id": "stableman_01",
                "name": "托马",
                "profession": "马夫",
                "background_story": "照料驿马的人。",
                "personality": ["谨慎", "看重责任"],
                "desires": ["护住马匹"],
                "fears": ["无准备地冒险"],
                "recruited": True,
                "opening_status": "active",
                "hp": 80,
                "max_hp": 108,
                "final_location": "广场",
                "current_order": {"text": "守住后门"},
                "diary": ["我听见了远处的蹄声。"],
                "knowledge": ["守备官：曾经兑现装备承诺"],
                "key_facts": [{
                    "fact_id": "npc_stableman_01_final",
                    "category": "final_state",
                    "summary": "托马在结算时仍可行动，且已经应征入伍。",
                }],
            },
            {
                "npc_id": "doctor_01",
                "name": "莉娜",
                "profession": "医生",
                "background_story": "照料伤员的人。",
                "personality": ["冷静", "珍视生命"],
                "desires": ["救治伤员"],
                "fears": ["诊所被毁"],
                "recruited": False,
                "opening_status": "unconscious",
                "hp": 0,
                "max_hp": 92,
                "final_location": "小诊所",
                "current_order": {},
                "diary": [],
                "knowledge": [],
                "key_facts": [{
                    "fact_id": "npc_doctor_01_final",
                    "category": "final_state",
                    "summary": "莉娜在结算时仍在昏迷，且没有应征入伍。",
                }],
            },
        ],
    }


def main() -> None:
    app = create_app()
    client = app.test_client()
    for result in ("victory", "failure"):
        response = client.post("/game/epilogue", json=payload(result))
        assert response.status_code == 200, response.get_json()
        body = response.get_json()
        assert body["ok"] is True
        assert body["result"] == result
        assert body["model_provider"] == "mock"
        assert body["model_fallback_used"] is False
        assert len(body["npc_endings"]) == 2
        assert {item["npc_id"] for item in body["npc_endings"]} == {"stableman_01", "doctor_01"}
        assert {item["opening_status"] for item in body["npc_endings"]} == {"active", "unconscious"}
        assert all("Mock：" not in item["fate_story"] for item in body["npc_endings"])
        assert all("死亡" not in item["fate_story"] and "阵亡" not in item["fate_story"] for item in body["npc_endings"])
        allowed_tones = (
            {"hopeful", "hopeful_bittersweet", "reconciled"}
            if result == "victory"
            else {"sorrowful", "sorrowful_resilient", "unresolved"}
        )
        assert all(item["tone"] in allowed_tones for item in body["npc_endings"])
    print("GAME_EPILOGUE_ENDPOINT_OK")


if __name__ == "__main__":
    main()
