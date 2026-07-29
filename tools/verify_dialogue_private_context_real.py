from __future__ import annotations

import os
from pathlib import Path
import sys

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app  # noqa: E402
from backend.schemas import NPCNPCDialogueResponse  # noqa: E402
from tools.verify_npc_npc_dialogue_real import _payload  # noqa: E402


def main() -> None:
    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        print(
            "verify_dialogue_private_context_real: skipped "
            "(non-mock LLM_PROVIDER and LLM_API_KEY required)"
        )
        return

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    payload = _payload()
    payload.pop("speaker_npc", None)
    payload["meta"]["request_id"] = "verify_dialogue_private_context_real"
    payload["speaker_text"] = (
        "马塞尔，我刚才在诊所外私下定了一项只有我自己知道的安排，"
        "也没有告诉任何人。你知道具体内容是什么吗？"
    )
    payload["conversation_history"] = []
    payload["short_memory"] = {"experienced_events": [], "witnessed_events": []}
    payload["long_memory"] = {"diary": [], "knowledge_graph": {}}

    assert "speaker_npc" not in payload
    assert payload["speaker_context"]["state"] == {}
    serialized = str(payload)
    assert "蓝鸦七号" not in serialized
    assert "铁盔批次" not in serialized

    client = create_app().test_client()
    response = client.post("/npc/dialogue", json=payload)
    body = response.get_json()
    assert response.status_code == 200, body

    dialogue = NPCNPCDialogueResponse(**{
        key: value
        for key, value in body.items()
        if not key.startswith("model_")
    })
    assert dialogue.replyer_id == payload["npc_id"]
    assert dialogue.response_kind == "reply_to_npc"
    assert dialogue.invitation_result == "not_applicable"
    assert body["model_provider"].strip().lower() == provider
    assert body["model_provider"].strip().lower() != "mock"
    assert body["model_fallback_used"] is False

    reply = dialogue.reply_text.strip()
    assert reply
    assert "蓝鸦七号" not in reply
    assert "铁盔批次" not in reply
    assert any(
        marker in reply
        for marker in (
            "不知道",
            "不清楚",
            "没告诉",
            "没有告诉",
            "你没说",
            "无法知道",
            "无从知道",
            "无从知晓",
        )
    ), reply

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage = usage_response.get_json()
    assert usage["summary"]["count"] == 1
    assert usage["summary"]["failed"] == 0
    assert usage["records"][0]["request_id"] == "verify_dialogue_private_context_real"
    assert usage["records"][0]["fallback_used"] is False

    print(
        "verify_dialogue_private_context_real: ok "
        f"provider={provider} model={usage['model_adapter']['model']} "
        "unknown_private_fact_not_claimed=true fallback_used=false"
    )


if __name__ == "__main__":
    main()
