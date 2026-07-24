from __future__ import annotations

import os
from pathlib import Path
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from tools.station_context_fixture import build_station_context  # noqa: E402
from tools.verify_dialogue_prompt_real import _base_payload  # noqa: E402


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    has_key = bool(os.getenv("LLM_API_KEY", "").strip())
    if provider == "mock" or not has_key:
        print("verify_station_context_real: skipped (non-mock LLM_PROVIDER and LLM_API_KEY required)")
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"

    station_context = build_station_context(
        [
            {"npc_id": "stableman_01", "name": "托马", "identity": "马夫"},
            {"npc_id": "cook_01", "name": "布鲁诺", "identity": "厨子"},
            {"npc_id": "gardener_01", "name": "伊沃", "identity": "园丁"},
            {"npc_id": "blacksmith_01", "name": "格伦", "identity": "铁匠"},
            {"npc_id": "veteran_deputy_01", "name": "艾达", "identity": "老兵副官"},
            {"npc_id": "priest_01", "name": "马塞尔", "identity": "神父"},
            {"npc_id": "doctor_01", "name": "莉娜", "identity": "医生"},
        ],
        basic_resource_amounts={
            "grain": 23,
            "meal": 4,
            "wood": 17,
            "stone": 9,
            "iron": 6,
        },
    )
    payload = _base_payload(
        "verify_station_context_real_dialogue",
        (
            "先别谈其他事务。只按 station_context 用一句话回答，并逐字包含："
            "在站医生‘莉娜’、建筑‘主厅’和‘小诊所’、工作模式行为‘吃饭’和‘找某个 NPC 对话’，"
            "以及‘未入伍者遇敌会躲避、低士气者可能临阵脱逃’。不要补名单外人物、建筑或行为。"
        ),
    )
    payload["station_context"] = station_context
    payload["current_order"] = {}
    payload["short_memory"] = {"experienced_events": [], "witnessed_events": []}
    payload["long_memory"] = {}

    client = create_app().test_client()
    response = client.post("/npc/dialogue", json=payload)
    body = response.get_json()
    assert response.status_code == 200, body
    reply_text = str(body.get("reply_text", ""))
    for expected_text in ("莉娜", "主厅", "小诊所", "吃", "躲", "士气"):
        assert expected_text in reply_text, reply_text
    assert any(text in reply_text for text in ("对话", "找她", "去找", "找人说话", "说话")), reply_text
    assert any(text in reply_text for text in ("临阵脱逃", "逃离", "跑路", "可能跑")), reply_text
    assert "欧文" not in reply_text, reply_text
    assert body.get("model_provider") == provider, body
    assert body.get("model_fallback_used") is False, body

    cycle_payload = _base_payload(
        "verify_station_context_activity_cycle_real_dialogue",
        (
            "我在菜园干了一上午，但这一轮活还没做完。现在若离开菜园去广场，"
            "粮食会不会在没人继续照料时自行产出？只按驿站规则用一句话说明，"
            "并说清持续参与、周期完成和离岗后的关系。"
        ),
    )
    cycle_payload["station_context"] = station_context
    cycle_payload["current_order"] = {}
    cycle_payload["short_memory"] = {"experienced_events": [], "witnessed_events": []}
    cycle_payload["long_memory"] = {}

    cycle_response = client.post("/npc/dialogue", json=cycle_payload)
    cycle_body = cycle_response.get_json()
    assert cycle_response.status_code == 200, cycle_body
    cycle_reply = str(cycle_body.get("reply_text", ""))
    assert any(
        text in cycle_reply
        for text in ("持续", "继续工作", "继续照料", "留在菜园", "一直干", "接着干")
    ), cycle_reply
    assert any(text in cycle_reply for text in ("周期", "一轮", "做完", "完成")), cycle_reply
    assert any(text in cycle_reply for text in ("不会", "不能", "不再", "没有")), cycle_reply
    assert any(text in cycle_reply for text in ("产出", "收成", "粮食", "结果")), cycle_reply
    assert cycle_body.get("model_provider") == provider, cycle_body
    assert cycle_body.get("model_fallback_used") is False, cycle_body

    resource_upgrade_payload = _base_payload(
        "verify_station_context_resources_upgrade_real_dialogue",
        (
            "只按 station_context 和 allowed_actions 回答：先用阿拉伯数字逐项报出粮食、餐食、"
            "木材、石料、铁的当前储备，再说明工械坊正在升级时你能选择什么行动来加快进度。"
            "不要提任何未公开库存。"
        ),
    )
    resource_upgrade_payload["station_context"] = station_context
    resource_upgrade_payload["allowed_actions"].append({
        "action_id": "assist_upgrade",
        "name": "协助升级工械坊",
        "action_kind": "assist_upgrade",
        "location_id": "plaza",
        "target_id": "workshop",
        "target_kind": "building",
        "target_name": "工械坊",
        "tags": ["assist_upgrade", "engineering"],
        "context": {"building_level": 1},
    })
    resource_upgrade_payload["current_order"] = {}
    resource_upgrade_payload["short_memory"] = {
        "experienced_events": [],
        "witnessed_events": [],
    }
    resource_upgrade_payload["long_memory"] = {}

    resource_upgrade_response = client.post(
        "/npc/dialogue",
        json=resource_upgrade_payload,
    )
    resource_upgrade_body = resource_upgrade_response.get_json()
    assert resource_upgrade_response.status_code == 200, resource_upgrade_body
    resource_upgrade_reply = str(resource_upgrade_body.get("reply_text", ""))
    for expected_amount in ("23", "4", "17", "9", "6"):
        assert expected_amount in resource_upgrade_reply, resource_upgrade_reply
    for expected_text in ("粮食", "餐食", "木材", "石料", "铁", "协助", "升级", "工械坊"):
        assert expected_text in resource_upgrade_reply, resource_upgrade_reply
    for hidden_text in ("第纳尔", "酒", "武器", "盔甲", "马匹"):
        assert hidden_text not in resource_upgrade_reply, resource_upgrade_reply
    assert resource_upgrade_body.get("model_provider") == provider, resource_upgrade_body
    assert resource_upgrade_body.get("model_fallback_used") is False, resource_upgrade_body

    print(
        "verify_station_context_real: ok "
        f"provider={body.get('model_provider')} model={body.get('model_name')} "
        f"context_reply={reply_text!r} cycle_reply={cycle_reply!r} "
        f"resource_upgrade_reply={resource_upgrade_reply!r}"
    )


if __name__ == "__main__":
    main()
