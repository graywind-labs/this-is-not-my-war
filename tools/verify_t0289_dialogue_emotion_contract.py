from pathlib import Path
import os
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from pydantic import ValidationError

from backend.app import normalize_dialogue_emotion, create_app
from backend.schemas import PlayerNPCDialogueResponse
from backend.services.model_adapter import ModelAdapter
from tools.verify_dialogue_mock_endpoint import _base_payload


EMOTION_IDS = {
    "none", "happy", "relieved", "angry", "sad", "afraid",
    "surprised", "confused", "determined",
}


def _response(emotion: str) -> dict:
    return {
        "replyer_id": "cook_01",
        "reply_text": "我听见了。",
        "emotion": emotion,
    }


def main() -> None:
    for emotion_id in EMOTION_IDS:
        assert PlayerNPCDialogueResponse(**_response(emotion_id)).emotion == emotion_id
    try:
        PlayerNPCDialogueResponse(**_response("wary"))
    except ValidationError:
        pass
    else:
        raise AssertionError("Free-form dialogue emotions must not pass the response schema")

    assert normalize_dialogue_emotion("谨慎") == "none"
    assert normalize_dialogue_emotion("fearful") == "afraid"
    assert normalize_dialogue_emotion("坚定") == "determined"
    assert normalize_dialogue_emotion("provider-invented-value") == "none"

    adapter = ModelAdapter()
    system_prompt = adapter._prompt_template_for_call_type("dialogue")
    schema_hint = adapter._schema_hint_for_call_type("dialogue", _base_payload("你好"))
    for emotion_id in EMOTION_IDS:
        assert emotion_id in system_prompt
        assert emotion_id in schema_hint
    assert "没有明显情绪" in system_prompt

    os.environ["LLM_PROVIDER"] = "mock"
    os.environ.pop("LLM_API_KEY", None)
    client = create_app().test_client()
    normal = client.post("/npc/dialogue", json=_base_payload("今晚吃什么？"))
    assert normal.status_code == 200, normal.get_json()
    assert normal.get_json()["emotion"] in EMOTION_IDS

    recruitment = client.post(
        "/npc/dialogue",
        json=_base_payload("请应征入伍，和我们一起守住驿站。", recruitment=True),
    )
    assert recruitment.status_code == 200, recruitment.get_json()
    assert recruitment.get_json()["emotion"] == "determined"

    print("T0289_DIALOGUE_EMOTION_CONTRACT_OK")


if __name__ == "__main__":
    main()
