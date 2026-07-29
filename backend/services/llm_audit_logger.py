import json
import re
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LLM_AUDIT_LOG_PATH = REPO_ROOT / "backend" / "logs" / "llm_calls.jsonl"
REDACTED_VALUE = "[REDACTED]"

_LOCKS_GUARD = threading.Lock()
_PATH_LOCKS: dict[str, threading.Lock] = {}
_BEARER_PATTERN = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+")
_OPENAI_STYLE_KEY_PATTERN = re.compile(r"\bsk-[A-Za-z0-9_-]{8,}\b")
_JSON_CREDENTIAL_PATTERN = re.compile(
    r'(?i)("(?:api[_-]?key|authorization|password|passwd|secret|access[_-]?token|'
    r'refresh[_-]?token|id[_-]?token|client[_-]?secret|token)"\s*:\s*)'
    r'"(?:\\.|[^"\\])*"'
)
_EXACT_SENSITIVE_KEYS = {
    "apikey",
    "authorization",
    "password",
    "passwd",
    "secret",
    "token",
    "accesstoken",
    "refreshtoken",
    "idtoken",
    "clientsecret",
}
_SENSITIVE_KEY_SUFFIXES = (
    "apikey",
    "password",
    "passwd",
    "secret",
    "accesstoken",
    "refreshtoken",
    "idtoken",
)


class LLMCallAuditLogger:
    """Best-effort append-only JSONL logger for complete LLM call evidence."""

    def __init__(
        self,
        *,
        enabled: bool,
        path: str = "",
        include_payloads: bool = True,
        secret_values: Iterable[str | None] = (),
    ) -> None:
        self.enabled = bool(enabled)
        self.include_payloads = bool(include_payloads)
        self.path = self._resolve_path(path)
        self._secret_values = tuple(
            sorted(
                {
                    str(value)
                    for value in secret_values
                    if value is not None and len(str(value)) >= 4
                },
                key=len,
                reverse=True,
            )
        )
        self._last_error = ""
        self._last_error_timestamp = ""
        self._lock = _lock_for_path(self.path)

    def write(self, event: str, audit_id: str, **data: Any) -> bool:
        if not self.enabled:
            return False
        record = {
            "schema_version": 1,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "audit_id": str(audit_id),
            "event": str(event),
        }
        record.update(data)
        if not self.include_payloads:
            for field_name in (
                "input_payload",
                "provider_request_body",
                "provider_response",
                "raw_response_body",
                "raw_model_content",
                "model_output",
                "validation_details",
                "failure_details",
            ):
                record.pop(field_name, None)
        try:
            sanitized = self._sanitize(record)
            line = json.dumps(
                sanitized,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
                default=str,
            )
            with self._lock:
                self.path.parent.mkdir(parents=True, exist_ok=True)
                with self.path.open("a", encoding="utf-8", newline="\n") as log_file:
                    log_file.write(line)
                    log_file.write("\n")
            return True
        except Exception as exc:
            self._last_error = "%s: %s" % (exc.__class__.__name__, str(exc))
            self._last_error_timestamp = datetime.now(timezone.utc).isoformat()
            return False

    def snapshot(self) -> dict[str, Any]:
        return {
            "enabled": self.enabled,
            "format": "jsonl",
            "schema_version": 1,
            "path": self._display_path(),
            "include_payloads": self.include_payloads,
            "last_error": self._last_error,
            "last_error_timestamp": self._last_error_timestamp,
        }

    def _sanitize(self, value: Any, key: str = "") -> Any:
        if key and _is_sensitive_key(key):
            return REDACTED_VALUE
        if isinstance(value, dict):
            return {
                str(item_key): self._sanitize(item_value, str(item_key))
                for item_key, item_value in value.items()
            }
        if isinstance(value, (list, tuple, set)):
            return [self._sanitize(item) for item in value]
        if isinstance(value, str):
            sanitized = value
            for secret_value in self._secret_values:
                sanitized = sanitized.replace(secret_value, REDACTED_VALUE)
            sanitized = _JSON_CREDENTIAL_PATTERN.sub(
                lambda match: '%s"%s"' % (match.group(1), REDACTED_VALUE),
                sanitized,
            )
            sanitized = _BEARER_PATTERN.sub("Bearer %s" % REDACTED_VALUE, sanitized)
            sanitized = _OPENAI_STYLE_KEY_PATTERN.sub(REDACTED_VALUE, sanitized)
            return sanitized
        return value

    @staticmethod
    def _resolve_path(raw_path: str) -> Path:
        if not str(raw_path).strip():
            return DEFAULT_LLM_AUDIT_LOG_PATH.resolve()
        configured = Path(str(raw_path).strip()).expanduser()
        if not configured.is_absolute():
            configured = REPO_ROOT / configured
        return configured.resolve()

    def _display_path(self) -> str:
        try:
            return self.path.relative_to(REPO_ROOT).as_posix()
        except ValueError:
            return str(self.path)


def _lock_for_path(path: Path) -> threading.Lock:
    path_key = str(path)
    with _LOCKS_GUARD:
        lock = _PATH_LOCKS.get(path_key)
        if lock is None:
            lock = threading.Lock()
            _PATH_LOCKS[path_key] = lock
        return lock


def _is_sensitive_key(key: str) -> bool:
    normalized = re.sub(r"[^a-z0-9]", "", key.lower())
    return (
        normalized in _EXACT_SENSITIVE_KEYS
        or any(normalized.endswith(suffix) for suffix in _SENSITIVE_KEY_SUFFIXES)
    )
