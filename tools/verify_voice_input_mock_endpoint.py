from __future__ import annotations

import io
import json
import struct
import sys
import wave
from pathlib import Path

from pydantic import ValidationError


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import QWEN_NATIVE_VOICE_EMOTIONS, VoiceAnalyzeResponse
from backend.services.voice_model_adapter import (
    VoiceModelAdapter,
    VoiceModelAdapterConfig,
    load_dialogue_input_config,
)


EXPECTED_EMOTIONS = {
    "neutral": "平静地",
    "happy": "愉快地",
    "sad": "悲伤地",
    "disgusted": "厌恶地",
    "angry": "愤怒地",
    "fearful": "恐惧地",
    "surprised": "惊讶地",
}


def make_wav(duration_seconds: float, frame_rate: int = 8_000) -> bytes:
    frame_count = int(duration_seconds * frame_rate)
    output = io.BytesIO()
    with wave.open(output, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(frame_rate)
        wav_file.writeframes(struct.pack("<h", 0) * frame_count)
    return output.getvalue()


def post_voice(client, audio: bytes | None, **overrides):
    data = {
        "request_id": "voice_test_001",
        "npc_id": "veteran_01",
        "dialogue_id": "dialogue_test_001",
        "locale": "zh",
    }
    data.update(overrides)
    if audio is not None:
        data["audio"] = (io.BytesIO(audio), "recording.wav")
    return client.post("/voice/analyze", data=data, content_type="multipart/form-data")


def main() -> None:
    limits = load_dialogue_input_config()
    assert limits.player_message_max_characters == 300
    assert limits.voice_recording_max_seconds == 30
    assert limits.voice_upload_max_bytes == 6_291_456
    assert QWEN_NATIVE_VOICE_EMOTIONS == EXPECTED_EMOTIONS
    try:
        VoiceAnalyzeResponse(
            request_id="voice_schema_invalid",
            dialogue_id="dialogue_schema_invalid",
            transcript="测试。",
            emotion="afraid",
            emotion_label="害怕地",
            emotion_applied=True,
            duration_seconds=1.0,
            model_provider="mock",
            model_name="qwen3-asr-flash",
            usage={},
        )
    except ValidationError:
        pass
    else:
        raise AssertionError("Voice schema accepted a non-native emotion alias.")

    app = create_app()
    app.testing = True
    app.config["VOICE_MODEL_ADAPTER"] = VoiceModelAdapter(VoiceModelAdapterConfig(
        provider="mock",
    ))
    client = app.test_client()

    response = post_voice(client, make_wav(1.0))
    assert response.status_code == 200, response.get_json()
    payload = VoiceAnalyzeResponse.model_validate(response.get_json())
    assert payload.transcript == "我需要你保卫驿站。"
    assert payload.emotion == "angry"
    assert payload.emotion_label == "愤怒地"
    assert payload.emotion_applied is True
    assert payload.model_provider == "mock"
    assert payload.model_name == "qwen3-asr-flash"
    assert payload.model_fallback_used is False

    exact_limit = post_voice(client, make_wav(30.0), request_id="voice_exact_30")
    assert exact_limit.status_code == 200, exact_limit.get_json()

    too_long = post_voice(client, make_wav(30.001), request_id="voice_too_long")
    assert too_long.status_code == 413
    assert too_long.get_json()["error_code"] == "audio_too_long"

    empty = post_voice(client, b"", request_id="voice_empty")
    assert empty.status_code == 400
    assert empty.get_json()["error_code"] == "recording_empty"

    invalid = post_voice(client, b"not a wav", request_id="voice_invalid")
    assert invalid.status_code == 400
    assert invalid.get_json()["error_code"] == "audio_invalid"

    missing_audio = post_voice(client, None, request_id="voice_missing_audio")
    assert missing_audio.status_code == 400
    assert missing_audio.get_json()["error_code"] == "recording_empty"

    missing_meta = post_voice(client, make_wav(1.0), request_id="")
    assert missing_meta.status_code == 400
    assert missing_meta.get_json()["error_code"] == "validation_error"

    oversized = post_voice(
        client,
        b"R" * (limits.voice_upload_max_bytes + 1),
        request_id="voice_oversized",
    )
    assert oversized.status_code == 413
    assert oversized.get_json()["error_code"] == "audio_too_large"

    app.config["VOICE_MODEL_ADAPTER"] = VoiceModelAdapter(VoiceModelAdapterConfig(
        provider="mock",
        mock_transcript="测试未知情绪。",
        mock_emotion="sarcastic",
    ))
    unknown_emotion = post_voice(client, make_wav(1.0), request_id="voice_unknown")
    assert unknown_emotion.status_code == 200, unknown_emotion.get_json()
    unknown_payload = unknown_emotion.get_json()
    assert unknown_payload["emotion"] == "none"
    assert unknown_payload["emotion_label"] == ""
    assert unknown_payload["emotion_applied"] is False
    assert unknown_payload["usage"]["degradation_source"] == "emotion_normalization"

    app.config["VOICE_MODEL_ADAPTER"] = VoiceModelAdapter(VoiceModelAdapterConfig(
        provider="alibaba_dashscope",
    ))
    unavailable = post_voice(client, make_wav(1.0), request_id="voice_real_not_ready")
    assert unavailable.status_code == 503
    assert unavailable.get_json()["error_code"] == "voice_provider_unavailable"
    assert unavailable.get_json()["fallback_used"] is False

    usage = client.get("/debug/llm_usage")
    assert usage.status_code == 200
    voice_usage = usage.get_json()["voice"]
    assert voice_usage["summary"]["count"] == 1
    assert voice_usage["records"][0]["request_id"] == "voice_real_not_ready"
    assert voice_usage["records"][0]["fallback_used"] is False

    config_json = json.loads(
        (REPO_ROOT / "data" / "dialogue_input_config.json").read_text(encoding="utf-8")
    )
    assert config_json["player_message_max_characters"] == 300
    print("verify_voice_input_mock_endpoint: ok")


if __name__ == "__main__":
    main()
