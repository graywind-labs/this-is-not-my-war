from __future__ import annotations

import json
import sys
from pathlib import Path

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import VoiceAnalyzeResponse


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_t1602_qwen_voice_provider_real.py AUDIO.wav")
    audio_path = Path(sys.argv[1]).resolve()
    if not audio_path.is_file():
        raise SystemExit("audio file not found")

    load_dotenv(REPO_ROOT / "backend" / ".env", override=True)
    app = create_app()
    app.testing = True
    client = app.test_client()
    with audio_path.open("rb") as handle:
        response = client.post(
            "/voice/analyze",
            data={
                "request_id": "voice_t1602_real_smoke",
                "npc_id": "veteran_01",
                "dialogue_id": "dialogue_t1602_real_smoke",
                "locale": "zh",
                "audio": (handle, "recording.wav"),
            },
            content_type="multipart/form-data",
        )

    payload = response.get_json(silent=True) or {}
    safe_output = {
        "http_status": response.status_code,
        "ok": payload.get("ok"),
        "request_id": payload.get("request_id"),
        "transcript": payload.get("transcript", ""),
        "emotion": payload.get("emotion", ""),
        "emotion_label": payload.get("emotion_label", ""),
        "duration_seconds": payload.get("duration_seconds"),
        "model_provider": payload.get("model_provider", ""),
        "model_name": payload.get("model_name", ""),
        "fallback_used": payload.get(
            "model_fallback_used",
            payload.get("fallback_used"),
        ),
        "error_code": payload.get("error_code", ""),
        "message": payload.get("message", ""),
        "estimated_cost_cny": (payload.get("usage") or {}).get(
            "estimated_cost_cny"
        ),
    }
    print(json.dumps(safe_output, ensure_ascii=False))
    if response.status_code != 200:
        raise SystemExit(1)
    result = VoiceAnalyzeResponse.model_validate(payload)
    assert result.model_provider == "alibaba_dashscope"
    assert result.model_name == "qwen3-asr-flash"
    assert result.model_fallback_used is False


if __name__ == "__main__":
    main()
