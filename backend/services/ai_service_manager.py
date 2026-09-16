import base64
import ctypes
import json
import os
import threading
from ctypes import wintypes
from dataclasses import replace
from pathlib import Path
from typing import Any, Callable

import requests

try:
    from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig
except ModuleNotFoundError:
    from services.model_adapter import ModelAdapter, ModelAdapterConfig


class AIServiceConfigurationError(ValueError):
    def __init__(self, error_code: str, message: str, http_status: int = 400) -> None:
        super().__init__(message)
        self.error_code = error_code
        self.http_status = http_status


class _DataBlob(ctypes.Structure):
    _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_ubyte))]


class AIServiceManager:
    """Owns the trial/BYOK selection without exposing either API key to Godot."""

    CONFIG_VERSION = 1
    SUPPORTED_PROVIDERS = {"deepseek", "openai_compatible"}

    def __init__(
        self,
        trial_config: ModelAdapterConfig,
        adapter_changed: Callable[[ModelAdapter], None],
    ) -> None:
        # Trial packaging remains environment-driven. The shipped profile sets
        # all game-side limits to zero, while explicit developer/operator limits
        # remain available for diagnostics and hosting safety.
        self._trial_config = replace(
            trial_config,
            fallback_to_mock=False if trial_config.provider != "mock" else trial_config.fallback_to_mock,
        )
        self._adapter_changed = adapter_changed
        self._lock = threading.RLock()
        self._config_dir = self._resolve_config_dir()
        self._config_path = self._config_dir / "ai_service.json"
        self._credential_path = self._config_dir / "ai_service.credential"
        self._mode = "trial"
        self._custom_public: dict[str, str] = {}
        self._load_selection()

    def activate_startup_selection(self) -> None:
        with self._lock:
            config = self._resolve_active_config(allow_missing_custom_key=True)
            self._adapter_changed(ModelAdapter(config))

    def get_public_snapshot(self) -> dict[str, Any]:
        with self._lock:
            active = self._resolve_active_config(allow_missing_custom_key=True)
            configured = bool(active.api_key) if active.provider != "mock" else True
            return {
                "ok": True,
                "mode": self._mode,
                "provider": active.provider,
                "model": self._resolved_model(active),
                "base_url": self._resolved_base_url(active),
                "configured": configured,
                "api_key_present": bool(active.api_key),
                "api_key_persisted_securely": self._mode == "custom" and self._credential_path.exists(),
                "trial_provider": self._trial_config.provider,
                "trial_model": self._resolved_model(self._trial_config),
            }

    def configure(self, payload: dict[str, Any], test_connection: bool = True) -> dict[str, Any]:
        mode = str(payload.get("mode", "trial")).strip().lower()
        if mode not in {"trial", "custom"}:
            raise AIServiceConfigurationError("invalid_ai_mode", "AI service mode must be trial or custom.")

        with self._lock:
            if mode == "trial":
                candidate = self._trial_config
                public_config: dict[str, str] = {}
                secret = ""
            else:
                public_config, secret = self._validate_custom_payload(payload)
                candidate = self._make_custom_config(public_config, secret)

            if test_connection:
                self._probe_provider(candidate)

            self._persist_selection(mode, public_config, secret)
            self._mode = mode
            if mode == "custom":
                self._custom_public = public_config
            self._adapter_changed(ModelAdapter(candidate))
            snapshot = self.get_public_snapshot()
            snapshot["connection_tested"] = test_connection
            return snapshot

    def test(self, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        with self._lock:
            if payload:
                mode = str(payload.get("mode", self._mode)).strip().lower()
                if mode == "custom":
                    public_config, secret = self._validate_custom_payload(payload)
                    candidate = self._make_custom_config(public_config, secret)
                elif mode == "trial":
                    candidate = self._trial_config
                else:
                    raise AIServiceConfigurationError("invalid_ai_mode", "AI service mode must be trial or custom.")
            else:
                candidate = self._resolve_active_config()
            self._probe_provider(candidate)
            return {
                "ok": True,
                "mode": str((payload or {}).get("mode", self._mode)),
                "provider": candidate.provider,
                "model": self._resolved_model(candidate),
                "message": "AI service connection succeeded.",
            }

    def _validate_custom_payload(self, payload: dict[str, Any]) -> tuple[dict[str, str], str]:
        provider = str(payload.get("provider", "openai_compatible")).strip().lower()
        if provider not in self.SUPPORTED_PROVIDERS:
            raise AIServiceConfigurationError("unsupported_ai_provider", "Only DeepSeek and OpenAI-compatible providers are supported.")
        model = str(payload.get("model", "")).strip()
        base_url = str(payload.get("base_url", "")).strip().rstrip("/")
        if provider == "deepseek":
            base_url = base_url or "https://api.deepseek.com"
            model = model or "deepseek-v4-pro"
        if not model:
            raise AIServiceConfigurationError("ai_model_required", "A model name is required for a custom AI service.")
        if not base_url.startswith(("http://", "https://")):
            raise AIServiceConfigurationError("invalid_ai_base_url", "API Base URL must start with http:// or https://.")
        api_key = str(payload.get("api_key", "")).strip()
        requested_public = {"provider": provider, "model": model, "base_url": base_url}
        if not api_key and requested_public == self._custom_public and self._credential_path.exists():
            api_key = self._read_secret()
        if not api_key:
            raise AIServiceConfigurationError("ai_api_key_required", "An API Key is required for a custom AI service.")
        return requested_public, api_key

    def _make_custom_config(self, public_config: dict[str, str], api_key: str) -> ModelAdapterConfig:
        return replace(
            self._without_game_budget(self._trial_config),
            provider=public_config["provider"],
            api_key=api_key,
            model=public_config["model"],
            base_url=public_config["base_url"],
            fallback_to_mock=False,
            input_cost_per_million=0.0,
            input_cache_hit_cost_per_million=0.0,
            output_cost_per_million=0.0,
            cost_ledger_enabled=False,
        )

    @staticmethod
    def _without_game_budget(config: ModelAdapterConfig) -> ModelAdapterConfig:
        return replace(
            config,
            fallback_to_mock=False if config.provider != "mock" else config.fallback_to_mock,
            budget_max_calls=0,
            budget_max_input_tokens=0,
            budget_max_output_tokens=0,
            budget_max_total_tokens=0,
            budget_max_estimated_cost=0.0,
            daily_budget_max_cost_cny=0.0,
            daily_budget_request_reserve_cny=0.0,
            cost_ledger_enabled=False,
        )

    def _resolve_active_config(self, allow_missing_custom_key: bool = False) -> ModelAdapterConfig:
        if self._mode != "custom":
            return self._trial_config
        secret = self._read_secret()
        if not secret and not allow_missing_custom_key:
            raise AIServiceConfigurationError("ai_credential_unavailable", "The saved custom API Key could not be loaded.", 503)
        return self._make_custom_config(self._custom_public, secret)

    def _persist_selection(self, mode: str, public_config: dict[str, str], secret: str) -> None:
        self._config_dir.mkdir(parents=True, exist_ok=True)
        if mode == "custom":
            protected = self._protect_secret(secret)
            self._credential_path.write_bytes(protected)
        config_document = {
            "version": self.CONFIG_VERSION,
            "mode": mode,
            "custom": public_config if mode == "custom" else self._custom_public,
        }
        temporary = self._config_path.with_suffix(".tmp")
        temporary.write_text(json.dumps(config_document, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(self._config_path)

    def _load_selection(self) -> None:
        if not self._config_path.exists():
            return
        try:
            document = json.loads(self._config_path.read_text(encoding="utf-8"))
            mode = str(document.get("mode", "trial"))
            custom = document.get("custom", {})
            if isinstance(custom, dict):
                provider = str(custom.get("provider", ""))
                model = str(custom.get("model", ""))
                base_url = str(custom.get("base_url", ""))
                if provider in self.SUPPORTED_PROVIDERS and model and base_url:
                    self._custom_public = {"provider": provider, "model": model, "base_url": base_url}
                    if mode == "custom":
                        self._mode = "custom"
        except (OSError, ValueError, TypeError):
            self._mode = "trial"
            self._custom_public = {}

    def _probe_provider(self, config: ModelAdapterConfig) -> None:
        if config.provider == "mock":
            return
        if not config.api_key:
            raise AIServiceConfigurationError("ai_api_key_required", "The selected AI service has no API Key.")
        url = "%s/models" % self._resolved_base_url(config).rstrip("/")
        try:
            response = requests.get(
                url,
                headers={"Authorization": "Bearer %s" % config.api_key, "Accept": "application/json"},
                timeout=(config.provider_connect_timeout_seconds, min(config.provider_idle_timeout_seconds, 30.0)),
            )
        except requests.Timeout as exc:
            raise AIServiceConfigurationError("provider_timeout", "AI provider connection timed out.", 504) from exc
        except requests.RequestException as exc:
            raise AIServiceConfigurationError("provider_transport_error", "AI provider connection failed: %s" % type(exc).__name__, 502) from exc
        if response.status_code >= 400:
            message = self._safe_provider_error_message(response)
            if response.status_code in {401, 403}:
                code = "provider_auth_failed"
            elif response.status_code == 429:
                code = "provider_rate_limited"
            else:
                code = "provider_http_error"
            raise AIServiceConfigurationError(code, message, response.status_code)

    @staticmethod
    def _safe_provider_error_message(response: requests.Response) -> str:
        message = "AI provider returned HTTP %d." % response.status_code
        try:
            body = response.json()
            if isinstance(body, dict):
                error = body.get("error", body)
                if isinstance(error, dict):
                    detail = str(error.get("message", error.get("code", ""))).strip()
                    provider_code = str(error.get("code", "")).strip()
                    if detail:
                        message = "%s%s" % (("[%s] " % provider_code) if provider_code else "", detail)
        except (ValueError, TypeError):
            pass
        return message[:500]

    @staticmethod
    def _resolved_base_url(config: ModelAdapterConfig) -> str:
        return config.base_url.rstrip("/") or ("https://api.deepseek.com" if config.provider == "deepseek" else "")

    @staticmethod
    def _resolved_model(config: ModelAdapterConfig) -> str:
        return config.model or ("deepseek-v4-pro" if config.provider == "deepseek" else config.provider)

    @staticmethod
    def _resolve_config_dir() -> Path:
        override = os.getenv("AI_SERVICE_CONFIG_DIR", "").strip()
        if override:
            return Path(override).expanduser().resolve()
        local_app_data = os.getenv("LOCALAPPDATA", "").strip()
        if local_app_data:
            return Path(local_app_data) / "ThisIsNotMyWar" / "ai_service"
        return Path.home() / ".this_is_not_my_war" / "ai_service"

    def _read_secret(self) -> str:
        if not self._credential_path.exists():
            return ""
        try:
            return self._unprotect_secret(self._credential_path.read_bytes())
        except (OSError, ValueError):
            return ""

    @staticmethod
    def _protect_secret(secret: str) -> bytes:
        if os.name != "nt":
            if os.getenv("AI_SERVICE_ALLOW_PLAINTEXT_TEST_STORE", "").strip().lower() in {"1", "true", "yes"}:
                return b"TEST_ONLY:" + base64.b64encode(secret.encode("utf-8"))
            raise AIServiceConfigurationError("secure_storage_unavailable", "Secure API Key storage is unavailable on this platform.", 503)
        return AIServiceManager._crypt_protect_data(secret.encode("utf-8"))

    @staticmethod
    def _unprotect_secret(data: bytes) -> str:
        if data.startswith(b"TEST_ONLY:"):
            return base64.b64decode(data.removeprefix(b"TEST_ONLY:")).decode("utf-8")
        if os.name != "nt":
            return ""
        return AIServiceManager._crypt_unprotect_data(data).decode("utf-8")

    @staticmethod
    def _blob(data: bytes) -> tuple[_DataBlob, Any]:
        buffer = ctypes.create_string_buffer(data)
        return _DataBlob(len(data), ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ubyte))), buffer

    @staticmethod
    def _crypt_protect_data(data: bytes) -> bytes:
        source, source_buffer = AIServiceManager._blob(data)
        output = _DataBlob()
        if not ctypes.windll.crypt32.CryptProtectData(ctypes.byref(source), None, None, None, None, 0, ctypes.byref(output)):
            raise AIServiceConfigurationError("secure_storage_failed", "Windows could not protect the API Key.", 503)
        try:
            return ctypes.string_at(output.pbData, output.cbData)
        finally:
            ctypes.windll.kernel32.LocalFree(output.pbData)
            del source_buffer

    @staticmethod
    def _crypt_unprotect_data(data: bytes) -> bytes:
        source, source_buffer = AIServiceManager._blob(data)
        output = _DataBlob()
        if not ctypes.windll.crypt32.CryptUnprotectData(ctypes.byref(source), None, None, None, None, 0, ctypes.byref(output)):
            raise ValueError("Windows could not unprotect the API Key.")
        try:
            return ctypes.string_at(output.pbData, output.cbData)
        finally:
            ctypes.windll.kernel32.LocalFree(output.pbData)
            del source_buffer
