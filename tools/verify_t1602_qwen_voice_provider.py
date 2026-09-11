from __future__ import annotations

import io
import json
import struct
import sys
import tempfile
import wave
from pathlib import Path
from unittest.mock import patch

import requests


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.app import create_app
from backend.schemas import QWEN_NATIVE_VOICE_EMOTIONS, VoiceAnalyzeResponse
from backend.services.voice_model_adapter import VoiceModelAdapter, VoiceModelAdapterConfig


class FakeResponse:
    def __init__(self, status_code: int, payload=None, *, invalid_json: bool = False):
        self.status_code = status_code
        self._payload = payload
        self._invalid_json = invalid_json

    def json(self):
        if self._invalid_json:
            raise json.JSONDecodeError("invalid", "", 0)
        return self._payload


def make_wav(duration_seconds: float = 1.0, frame_rate: int = 8_000) -> bytes:
    output = io.BytesIO()
    with wave.open(output, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(frame_rate)
        wav_file.writeframes(struct.pack("<h", 0) * int(duration_seconds * frame_rate))
    return output.getvalue()


def response_payload(transcript: str, emotion: str | None):
    annotations = []
    if emotion is not None:
        annotations.append({"type": "audio_info", "language": "zh", "emotion": emotion})
    return {
        "id": "chatcmpl-test",
        "model": "qwen3-asr-flash",
        "choices": [{
            "message": {
                "role": "assistant",
                "content": transcript,
                "annotations": annotations,
            },
        }],
        "usage": {"seconds": 1},
    }


def adapter(**overrides) -> VoiceModelAdapter:
    values = {
        "provider": "qwen3_asr_flash",
        "model": "qwen3-asr-flash",
        "api_key": "test-key-never-log",
        "base_url": "https://{WorkspaceId}.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
        "workspace_id": "llm-test-workspace",
        "timeout_seconds": 12.0,
        "cost_per_second_cny": 0.00022,
    }
    values.update(overrides)
    return VoiceModelAdapter(VoiceModelAdapterConfig(**values))


def analyze(instance: VoiceModelAdapter, request_id: str = "voice_t1602"):
    return instance.analyze(
        request_id=request_id,
        npc_id="veteran_01",
        dialogue_id="dialogue_t1602",
        duration_seconds=1.25,
        audio_bytes=make_wav(1.25),
        locale="zh",
    )


def test_native_emotions_and_request_contract() -> None:
    for emotion, label in QWEN_NATIVE_VOICE_EMOTIONS.items():
        def fake_post(url, *, headers, json, timeout):
            assert url == (
                "https://llm-test-workspace.cn-beijing.maas.aliyuncs.com/"
                "compatible-mode/v1/chat/completions"
            )
            assert headers["Authorization"] == "Bearer test-key-never-log"
            assert timeout == 12.0
            assert json["model"] == "qwen3-asr-flash"
            assert json["stream"] is False
            assert json["asr_options"] == {"enable_itn": False, "language": "zh"}
            data = json["messages"][0]["content"][0]["input_audio"]["data"]
            assert data.startswith("data:audio/wav;base64,UklGR")
            return FakeResponse(200, response_payload("我需要你保卫驿站。", emotion))

        instance = adapter()
        with patch("backend.services.voice_model_adapter.requests.post", side_effect=fake_post):
            result = analyze(instance, f"voice_{emotion}")
        assert result.ok
        assert result.provider == "alibaba_dashscope"
        assert result.transcript == "我需要你保卫驿站。"
        assert result.emotion == emotion
        assert result.emotion_label == label
        assert result.emotion_applied is True
        assert result.usage["http_status"] == 200
        assert result.usage["provider"] == "alibaba_dashscope"
        assert result.usage["estimated_cost_cny"] == 0.000275
        assert result.usage["fallback_used"] is False

    snapshot = adapter().get_runtime_config_snapshot()
    assert snapshot["real_provider_implemented"] is True
    assert snapshot["real_provider_configured"] is True
    assert "api_key" not in snapshot
    assert "base_url" not in snapshot
    assert "workspace_id" not in snapshot


def test_emotion_degradation_preserves_transcript() -> None:
    for raw_emotion in (None, "sarcastic"):
        with patch(
            "backend.services.voice_model_adapter.requests.post",
            return_value=FakeResponse(200, response_payload("继续守住这里。", raw_emotion)),
        ):
            result = analyze(adapter())
        assert result.ok
        assert result.transcript == "继续守住这里。"
        assert result.emotion == "none"
        assert result.emotion_label == ""
        assert result.emotion_applied is False
        assert result.usage["degradation_source"] == "emotion_normalization"


def test_provider_failures_are_explicit() -> None:
    cases = [
        (FakeResponse(401, {"error": {"code": "InvalidApiKey", "message": "denied"}}), "voice_provider_auth_failed", 401),
        (FakeResponse(429, {"error": {"code": "Throttled", "message": "slow down"}}), "voice_provider_rate_limited", 429),
        (FakeResponse(500, {"error": {"code": "InternalError", "message": "retry"}}), "voice_provider_http_error", 500),
        (FakeResponse(200, invalid_json=True), "voice_provider_invalid_response", 200),
        (FakeResponse(200, response_payload(" ", "neutral")), "voice_provider_invalid_response", 200),
    ]
    for fake_response, expected_code, expected_status in cases:
        with patch(
            "backend.services.voice_model_adapter.requests.post",
            return_value=fake_response,
        ):
            result = analyze(adapter())
        assert not result.ok
        assert result.error_code == expected_code
        assert result.usage["http_status"] == expected_status
        assert result.usage["fallback_used"] is False
        assert "denied" not in result.usage["failure_reason"]
        assert "slow down" not in result.usage["failure_reason"]

    with patch(
        "backend.services.voice_model_adapter.requests.post",
        side_effect=requests.ReadTimeout("timeout"),
    ):
        timeout_result = analyze(adapter())
    assert timeout_result.error_code == "voice_provider_timeout"
    assert timeout_result.usage["exception_type"] == "ProviderTimeout"

    with patch(
        "backend.services.voice_model_adapter.requests.post",
        side_effect=requests.ConnectionError("offline"),
    ):
        transport_result = analyze(adapter())
    assert transport_result.error_code == "voice_provider_transport_error"
    assert transport_result.usage["exception_type"] == "ConnectionError"


def test_endpoint_status_projection() -> None:
    app = create_app()
    app.testing = True
    app.config["VOICE_MODEL_ADAPTER"] = adapter()
    client = app.test_client()

    with patch(
        "backend.services.voice_model_adapter.requests.post",
        return_value=FakeResponse(429, {"error": {"code": "Throttled"}}),
    ):
        response = client.post(
            "/voice/analyze",
            data={
                "request_id": "voice_http_429",
                "npc_id": "veteran_01",
                "dialogue_id": "dialogue_http_429",
                "locale": "zh",
                "audio": (io.BytesIO(make_wav()), "recording.wav"),
            },
            content_type="multipart/form-data",
        )
    assert response.status_code == 429
    assert response.get_json()["error_code"] == "voice_provider_rate_limited"
    assert response.get_json()["fallback_used"] is False

    with patch(
        "backend.services.voice_model_adapter.requests.post",
        return_value=FakeResponse(200, response_payload("守住驿站。", "angry")),
    ):
        response = client.post(
            "/voice/analyze",
            data={
                "request_id": "voice_http_ok",
                "npc_id": "veteran_01",
                "dialogue_id": "dialogue_http_ok",
                "locale": "zh",
                "audio": (io.BytesIO(make_wav()), "recording.wav"),
            },
            content_type="multipart/form-data",
        )
    assert response.status_code == 200
    payload = VoiceAnalyzeResponse.model_validate(response.get_json())
    assert payload.transcript == "守住驿站。"
    assert payload.emotion == "angry"
    assert payload.emotion_label == "愤怒地"
    assert payload.model_provider == "alibaba_dashscope"
    assert payload.model_fallback_used is False


def test_shared_daily_budget_blocks_before_provider() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        instance = adapter(
            cost_ledger_enabled=True,
            cost_ledger_path=str(Path(temp_dir) / "voice-ledger.jsonl"),
            daily_budget_max_cny=0.001,
            daily_budget_request_reserve_cny=0.0066,
        )
        with patch("backend.services.voice_model_adapter.requests.post") as provider_post:
            result = analyze(instance, "voice_budget_blocked")
        assert result.ok is False
        assert result.error_code == "voice_budget_exceeded"
        assert result.usage["exception_type"] == "BudgetExceeded"
        assert result.usage["fallback_used"] is False
        provider_post.assert_not_called()

    with tempfile.TemporaryDirectory() as temp_dir:
        ledger_path = Path(temp_dir) / "voice-ledger.jsonl"
        instance = adapter(
            cost_ledger_enabled=True,
            cost_ledger_path=str(ledger_path),
            daily_budget_max_cny=1.0,
            daily_budget_request_reserve_cny=0.0066,
        )
        with patch(
            "backend.services.voice_model_adapter.requests.post",
            return_value=FakeResponse(200, response_payload("守住驿站。", "neutral")),
        ):
            result = analyze(instance, "voice_budget_settled")
        assert result.ok
        records = [json.loads(line) for line in ledger_path.read_text(encoding="utf-8").splitlines()]
        assert len(records) == 1
        assert records[0]["call_type"] == "voice_transcription_emotion"
        assert records[0]["provider"] == "alibaba_dashscope"
        assert records[0]["estimated_cost_cny"] == 0.000275


def main() -> None:
    test_native_emotions_and_request_contract()
    test_emotion_degradation_preserves_transcript()
    test_provider_failures_are_explicit()
    test_endpoint_status_projection()
    test_shared_daily_budget_blocks_before_provider()
    print("verify_t1602_qwen_voice_provider: ok")


if __name__ == "__main__":
    main()
