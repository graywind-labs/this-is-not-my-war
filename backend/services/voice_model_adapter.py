from __future__ import annotations

import base64
import json
import os
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests

try:
    from backend.schemas import DialogueInputConfig, QWEN_NATIVE_VOICE_EMOTIONS
    from backend.services.llm_cost_ledger import LLMCostLedger
except ModuleNotFoundError:
    from schemas import DialogueInputConfig, QWEN_NATIVE_VOICE_EMOTIONS
    from services.llm_cost_ledger import LLMCostLedger


DIALOGUE_INPUT_CONFIG_PATH = (
    Path(__file__).resolve().parents[2] / "data" / "dialogue_input_config.json"
)

_QWEN_ASR_LOCALES = {
    "zh", "yue", "en", "ja", "de", "ko", "ru", "fr", "pt", "ar",
    "it", "es", "hi", "id", "th", "tr", "uk", "vi", "cs", "da",
    "fil", "fi", "is", "ms", "no", "pl", "sv",
}


def load_dialogue_input_config(
    path: str | Path | None = None,
) -> DialogueInputConfig:
    config_path = Path(path) if path else DIALOGUE_INPUT_CONFIG_PATH
    with config_path.open("r", encoding="utf-8") as handle:
        return DialogueInputConfig.model_validate(json.load(handle))


@dataclass(frozen=True)
class VoiceModelAdapterConfig:
    provider: str = "mock"
    model: str = "qwen3-asr-flash"
    mock_transcript: str = "我需要你保卫驿站。"
    mock_emotion: str = "angry"
    api_key: str | None = None
    base_url: str = ""
    workspace_id: str = ""
    timeout_seconds: float = 30.0
    cost_per_second_cny: float = 0.00022
    cost_ledger_enabled: bool = False
    cost_ledger_path: str = ""
    daily_budget_max_cny: float = 0.0
    daily_budget_timezone: str = "Asia/Shanghai"
    daily_budget_request_reserve_cny: float = 0.0066


@dataclass(frozen=True)
class VoiceModelAdapterResult:
    ok: bool
    provider: str
    model: str
    transcript: str
    emotion: str
    emotion_label: str
    emotion_applied: bool
    usage: dict[str, Any]
    error_code: str = ""
    message: str = ""


@dataclass(frozen=True)
class VoiceUsageRecord:
    timestamp: str
    request_id: str
    call_type: str
    provider: str
    model: str
    npc_id: str
    dialogue_id: str
    duration_seconds: float
    estimated_cost_cny: float
    success: bool
    fallback_used: bool = False
    error_code: str = ""
    failure_reason: str = ""
    http_status: int | None = None
    exception_type: str = ""
    degradation_source: str = ""


class VoiceModelAdapter:
    """Isolated mock / Alibaba Bailian speech-recognition boundary."""

    def __init__(self, config: VoiceModelAdapterConfig | None = None) -> None:
        raw_config = config or VoiceModelAdapterConfig(
            provider=os.getenv("VOICE_PROVIDER", "disabled"),
            model=os.getenv("VOICE_MODEL", "qwen3-asr-flash"),
            mock_transcript=os.getenv(
                "VOICE_MOCK_TRANSCRIPT",
                "我需要你保卫驿站。",
            ),
            mock_emotion=os.getenv("VOICE_MOCK_EMOTION", "angry"),
            api_key=os.getenv("DASHSCOPE_API_KEY"),
            base_url=os.getenv("VOICE_BASE_URL", ""),
            workspace_id=os.getenv("VOICE_WORKSPACE_ID", ""),
            timeout_seconds=_read_positive_float_env("VOICE_TIMEOUT_SECONDS", 30.0),
            cost_per_second_cny=_read_non_negative_float_env(
                "VOICE_COST_PER_SECOND_CNY",
                0.00022,
            ),
            cost_ledger_enabled=_read_bool_env("LLM_COST_LEDGER_ENABLED", False),
            cost_ledger_path=os.getenv("LLM_COST_LEDGER_PATH", ""),
            daily_budget_max_cny=_read_non_negative_float_env(
                "LLM_DAILY_BUDGET_MAX_CNY",
                0.0,
            ),
            daily_budget_timezone=os.getenv(
                "LLM_DAILY_BUDGET_TIMEZONE",
                "Asia/Shanghai",
            ),
            daily_budget_request_reserve_cny=_read_non_negative_float_env(
                "VOICE_DAILY_BUDGET_REQUEST_RESERVE_CNY",
                0.0066,
            ),
        )
        self.config = VoiceModelAdapterConfig(
            provider=raw_config.provider.strip().lower() or "mock",
            model=raw_config.model.strip() or "qwen3-asr-flash",
            mock_transcript=raw_config.mock_transcript.strip(),
            mock_emotion=raw_config.mock_emotion.strip().lower(),
            api_key=(raw_config.api_key or "").strip() or None,
            base_url=raw_config.base_url.strip().rstrip("/"),
            workspace_id=raw_config.workspace_id.strip(),
            timeout_seconds=max(0.1, float(raw_config.timeout_seconds)),
            cost_per_second_cny=max(0.0, float(raw_config.cost_per_second_cny)),
            cost_ledger_enabled=bool(raw_config.cost_ledger_enabled),
            cost_ledger_path=raw_config.cost_ledger_path.strip(),
            daily_budget_max_cny=max(0.0, float(raw_config.daily_budget_max_cny)),
            daily_budget_timezone=(
                raw_config.daily_budget_timezone.strip() or "Asia/Shanghai"
            ),
            daily_budget_request_reserve_cny=max(
                0.0,
                float(raw_config.daily_budget_request_reserve_cny),
            ),
        )
        self._usage_records: list[VoiceUsageRecord] = []
        self._cost_ledger = LLMCostLedger(
            enabled=(
                self.config.cost_ledger_enabled
                and self.config.provider == "qwen3_asr_flash"
            ),
            path=self.config.cost_ledger_path,
            daily_limit_cny=self.config.daily_budget_max_cny,
            timezone_name=self.config.daily_budget_timezone,
            request_reserve_cny=self.config.daily_budget_request_reserve_cny,
        )

    def analyze(
        self,
        *,
        request_id: str,
        npc_id: str,
        dialogue_id: str,
        duration_seconds: float,
        audio_bytes: bytes,
        locale: str = "zh",
    ) -> VoiceModelAdapterResult:
        if self.config.provider == "mock":
            return self._analyze_mock(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
            )
        if self.config.provider == "qwen3_asr_flash":
            return self._analyze_qwen3_asr_flash(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                audio_bytes=audio_bytes,
                locale=locale,
            )

        return self._failure_result(
            request_id=request_id,
            npc_id=npc_id,
            dialogue_id=dialogue_id,
            duration_seconds=duration_seconds,
            error_code="voice_provider_unavailable",
            message="VOICE_PROVIDER is not a supported voice provider.",
            exception_type="ConfigurationError",
        )

    def _analyze_mock(
        self,
        *,
        request_id: str,
        npc_id: str,
        dialogue_id: str,
        duration_seconds: float,
    ) -> VoiceModelAdapterResult:
        transcript = self.config.mock_transcript.strip()
        if not transcript:
            return self._failure_result(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                error_code="voice_provider_invalid_response",
                message="Mock voice transcript must not be empty.",
                exception_type="MockResponseError",
            )

        emotion = self.config.mock_emotion
        emotion_label = QWEN_NATIVE_VOICE_EMOTIONS.get(emotion, "")
        degradation_source = ""
        failure_reason = ""
        if not emotion_label:
            emotion = "none"
            degradation_source = "emotion_normalization"
            failure_reason = "Unknown provider emotion was normalized to none."
        usage = self._record_usage(
            request_id=request_id,
            npc_id=npc_id,
            dialogue_id=dialogue_id,
            duration_seconds=duration_seconds,
            success=True,
            failure_reason=failure_reason,
            degradation_source=degradation_source,
        )
        return VoiceModelAdapterResult(
            ok=True,
            provider="mock",
            model=self.config.model,
            transcript=transcript,
            emotion=emotion,
            emotion_label=emotion_label,
            emotion_applied=bool(emotion_label),
            usage=usage,
        )

    def _analyze_qwen3_asr_flash(
        self,
        *,
        request_id: str,
        npc_id: str,
        dialogue_id: str,
        duration_seconds: float,
        audio_bytes: bytes,
        locale: str,
    ) -> VoiceModelAdapterResult:
        config_error = self._validate_real_provider_config()
        if config_error:
            return self._failure_result(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                error_code="voice_provider_unavailable",
                message=config_error,
                exception_type="ConfigurationError",
            )

        audio_data_uri = "data:audio/wav;base64," + base64.b64encode(audio_bytes).decode("ascii")
        asr_options: dict[str, Any] = {"enable_itn": False}
        normalized_locale = locale.strip().lower()
        if normalized_locale in _QWEN_ASR_LOCALES:
            asr_options["language"] = normalized_locale
        payload = {
            "model": self.config.model,
            "messages": [{
                "role": "user",
                "content": [{
                    "type": "input_audio",
                    "input_audio": {"data": audio_data_uri},
                }],
            }],
            "stream": False,
            "asr_options": asr_options,
        }
        reservation_id, budget_reason = self._cost_ledger.reserve(
            audit_id=request_id,
            attempt_count=1,
        )
        if budget_reason:
            return self._failure_result(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                error_code="voice_budget_exceeded",
                message="The daily voice budget has been reached.",
                failure_reason=budget_reason,
                exception_type="BudgetExceeded",
            )
        try:
            response = requests.post(
                self._provider_endpoint(),
                headers={
                    "Authorization": f"Bearer {self.config.api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
                timeout=self.config.timeout_seconds,
            )
        except requests.Timeout:
            self._cost_ledger.release(reservation_id)
            return self._failure_result(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                error_code="voice_provider_timeout",
                message="The voice provider timed out.",
                exception_type="ProviderTimeout",
            )
        except requests.RequestException as exc:
            self._cost_ledger.release(reservation_id)
            return self._failure_result(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                error_code="voice_provider_transport_error",
                message="The voice provider could not be reached.",
                exception_type=type(exc).__name__,
            )

        if not 200 <= response.status_code < 300:
            error_code = "voice_provider_http_error"
            if response.status_code in {401, 403}:
                error_code = "voice_provider_auth_failed"
            elif response.status_code == 429:
                error_code = "voice_provider_rate_limited"
            elif response.status_code in {408, 504}:
                error_code = "voice_provider_timeout"
            result = self._failure_result(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                error_code=error_code,
                message="The voice provider rejected the request.",
                failure_reason=_provider_failure_reason(response),
                http_status=response.status_code,
                exception_type="ProviderHTTPError",
            )
            self._cost_ledger.release(reservation_id)
            return result

        try:
            response_json = response.json()
        except ValueError:
            result = self._failure_result(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                error_code="voice_provider_invalid_response",
                message="The voice provider returned invalid JSON.",
                http_status=response.status_code,
                exception_type="ProviderJSONError",
            )
            self._cost_ledger.release(reservation_id)
            return result

        transcript, raw_emotion = _parse_qwen_response(response_json)
        if not transcript:
            result = self._failure_result(
                request_id=request_id,
                npc_id=npc_id,
                dialogue_id=dialogue_id,
                duration_seconds=duration_seconds,
                error_code="voice_provider_invalid_response",
                message="The voice provider returned no transcript.",
                http_status=response.status_code,
                exception_type="ProviderResponseError",
            )
            self._cost_ledger.release(reservation_id)
            return result

        emotion = raw_emotion if raw_emotion in QWEN_NATIVE_VOICE_EMOTIONS else "none"
        emotion_label = QWEN_NATIVE_VOICE_EMOTIONS.get(emotion, "")
        degradation_source = ""
        failure_reason = ""
        if emotion == "none":
            degradation_source = "emotion_normalization"
            failure_reason = "Provider emotion was missing or unknown; transcript was preserved."
        usage = self._record_usage(
            request_id=request_id,
            npc_id=npc_id,
            dialogue_id=dialogue_id,
            duration_seconds=duration_seconds,
            success=True,
            failure_reason=failure_reason,
            degradation_source=degradation_source,
            http_status=response.status_code,
            estimated_cost_cny=duration_seconds * self.config.cost_per_second_cny,
        )
        self._cost_ledger.settle_direct_cost(
            reservation_id,
            audit_id=request_id,
            call_type="voice_transcription_emotion",
            provider="alibaba_dashscope",
            model=self.config.model,
            attempt_count=1,
            estimated_cost_cny=duration_seconds * self.config.cost_per_second_cny,
        )
        return VoiceModelAdapterResult(
            ok=True,
            provider="alibaba_dashscope",
            model=self.config.model,
            transcript=transcript,
            emotion=emotion,
            emotion_label=emotion_label,
            emotion_applied=bool(emotion_label),
            usage=usage,
        )

    def _validate_real_provider_config(self) -> str:
        if not self.config.api_key:
            return "DASHSCOPE_API_KEY is not configured."
        if not self.config.base_url and not self.config.workspace_id:
            return "VOICE_BASE_URL or VOICE_WORKSPACE_ID must be configured."
        if "{WorkspaceId}" in self.config.base_url and not self.config.workspace_id:
            return "VOICE_WORKSPACE_ID is required by VOICE_BASE_URL."
        parsed = urlparse(self._provider_endpoint())
        if parsed.scheme != "https" or not parsed.netloc:
            return "VOICE_BASE_URL must resolve to an HTTPS endpoint."
        return ""

    def _provider_endpoint(self) -> str:
        base_url = self.config.base_url
        if "{WorkspaceId}" in base_url:
            base_url = base_url.replace("{WorkspaceId}", self.config.workspace_id)
        if not base_url and self.config.workspace_id:
            base_url = (
                f"https://{self.config.workspace_id}.cn-beijing.maas.aliyuncs.com"
                "/compatible-mode/v1"
            )
        base_url = base_url.rstrip("/")
        if base_url.endswith("/chat/completions"):
            return base_url
        return base_url + "/chat/completions"

    def _failure_result(
        self,
        *,
        request_id: str,
        npc_id: str,
        dialogue_id: str,
        duration_seconds: float,
        error_code: str,
        message: str,
        failure_reason: str = "",
        http_status: int | None = None,
        exception_type: str = "",
    ) -> VoiceModelAdapterResult:
        usage = self._record_usage(
            request_id=request_id,
            npc_id=npc_id,
            dialogue_id=dialogue_id,
            duration_seconds=duration_seconds,
            success=False,
            error_code=error_code,
            failure_reason=failure_reason or message,
            http_status=http_status,
            exception_type=exception_type,
        )
        return VoiceModelAdapterResult(
            ok=False,
            provider=self.config.provider,
            model=self.config.model,
            transcript="",
            emotion="none",
            emotion_label="",
            emotion_applied=False,
            usage=usage,
            error_code=error_code,
            message=message,
        )

    def get_runtime_config_snapshot(self) -> dict[str, Any]:
        return {
            "provider": self.config.provider,
            "model": self.config.model,
            "real_provider_implemented": True,
            "real_provider_configured": bool(
                self.config.api_key and self._provider_endpoint().startswith("https://")
            ),
            "fallback_to_mock": False,
            "native_emotions": list(QWEN_NATIVE_VOICE_EMOTIONS),
            "daily_budget": self._cost_ledger.snapshot(),
        }

    def record_validation_failure(
        self,
        *,
        request_id: str,
        npc_id: str,
        dialogue_id: str,
        error_code: str,
        failure_reason: str,
        duration_seconds: float = 0.0,
    ) -> dict[str, Any]:
        return self._record_usage(
            request_id=request_id,
            npc_id=npc_id,
            dialogue_id=dialogue_id,
            duration_seconds=duration_seconds,
            success=False,
            error_code=error_code,
            failure_reason=failure_reason,
            exception_type="ValidationError",
        )

    def get_usage_records(self) -> list[dict[str, Any]]:
        return [asdict(record) for record in self._usage_records]

    def get_usage_summary(self) -> dict[str, Any]:
        successful = sum(1 for record in self._usage_records if record.success)
        total_seconds = sum(record.duration_seconds for record in self._usage_records)
        total_cost = sum(record.estimated_cost_cny for record in self._usage_records)
        return {
            "count": len(self._usage_records),
            "successful": successful,
            "failed": len(self._usage_records) - successful,
            "fallback_count": 0,
            "duration_seconds": round(total_seconds, 3),
            "estimated_cost_cny": round(total_cost, 8),
            "currency": "CNY",
            "daily_budget": self._cost_ledger.snapshot(),
        }

    def _record_usage(
        self,
        *,
        request_id: str,
        npc_id: str,
        dialogue_id: str,
        duration_seconds: float,
        success: bool,
        error_code: str = "",
        failure_reason: str = "",
        exception_type: str = "",
        degradation_source: str = "",
        http_status: int | None = None,
        estimated_cost_cny: float = 0.0,
    ) -> dict[str, Any]:
        record = VoiceUsageRecord(
            timestamp=datetime.now(timezone.utc).isoformat(),
            request_id=request_id,
            call_type="voice_transcription_emotion",
            provider=(
                "alibaba_dashscope"
                if self.config.provider == "qwen3_asr_flash"
                else self.config.provider
            ),
            model=self.config.model,
            npc_id=npc_id,
            dialogue_id=dialogue_id,
            duration_seconds=round(max(0.0, duration_seconds), 3),
            estimated_cost_cny=round(max(0.0, estimated_cost_cny), 8),
            success=success,
            fallback_used=False,
            error_code=error_code,
            failure_reason=failure_reason,
            http_status=http_status,
            exception_type=exception_type,
            degradation_source=degradation_source,
        )
        self._usage_records.append(record)
        return asdict(record)


def _parse_qwen_response(payload: Any) -> tuple[str, str]:
    if not isinstance(payload, dict):
        return "", ""
    choices = payload.get("choices")
    if not isinstance(choices, list) or not choices:
        return "", ""
    choice = choices[0]
    if not isinstance(choice, dict):
        return "", ""
    message = choice.get("message")
    if not isinstance(message, dict):
        return "", ""
    content = message.get("content", "")
    transcript = content.strip() if isinstance(content, str) else ""
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and isinstance(item.get("text"), str):
                parts.append(item["text"])
        transcript = "".join(parts).strip()
    emotion = ""
    annotations = message.get("annotations")
    if isinstance(annotations, list):
        for annotation in annotations:
            if not isinstance(annotation, dict):
                continue
            if annotation.get("type") not in {None, "audio_info"}:
                continue
            raw_emotion = annotation.get("emotion")
            if isinstance(raw_emotion, str):
                emotion = raw_emotion.strip().lower()
                break
    return transcript, emotion


def _provider_failure_reason(response: requests.Response) -> str:
    provider_code = ""
    try:
        payload = response.json()
    except ValueError:
        payload = None
    if isinstance(payload, dict):
        error = payload.get("error")
        if isinstance(error, dict):
            provider_code = str(error.get("code", "")).strip()
        else:
            provider_code = str(payload.get("code", "")).strip()
    parts = [f"HTTP {response.status_code}"]
    if provider_code:
        parts.append(f"provider_code={provider_code[:80]}")
    return "; ".join(parts)


def _read_positive_float_env(name: str, default: float) -> float:
    try:
        value = float(os.getenv(name, str(default)))
    except (TypeError, ValueError):
        return default
    return value if value > 0.0 else default


def _read_non_negative_float_env(name: str, default: float) -> float:
    try:
        value = float(os.getenv(name, str(default)))
    except (TypeError, ValueError):
        return default
    return value if value >= 0.0 else default


def _read_bool_env(name: str, default: bool) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}
