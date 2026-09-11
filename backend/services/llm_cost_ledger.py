import json
import threading
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LLM_COST_LEDGER_PATH = REPO_ROOT / "backend" / "logs" / "llm_cost_ledger.jsonl"

_LOCKS_GUARD = threading.Lock()
_PATH_LOCKS: dict[str, threading.RLock] = {}


class LLMCostLedger:
    """Append-only provider-attempt usage ledger plus in-flight daily reservations."""

    def __init__(
        self,
        *,
        enabled: bool,
        path: str = "",
        daily_limit_cny: float = 0.0,
        timezone_name: str = "Asia/Shanghai",
        request_reserve_cny: float = 0.0,
    ) -> None:
        self.enabled = bool(enabled)
        self.path = self._resolve_path(path)
        self.daily_limit_cny = max(0.0, float(daily_limit_cny))
        self.timezone_name = str(timezone_name).strip() or "Asia/Shanghai"
        self.request_reserve_cny = max(0.0, float(request_reserve_cny))
        try:
            self._timezone = ZoneInfo(self.timezone_name)
        except ZoneInfoNotFoundError:
            if self.timezone_name == "Asia/Shanghai":
                self._timezone = timezone(timedelta(hours=8), name="Asia/Shanghai")
            else:
                self.timezone_name = "UTC"
                self._timezone = timezone.utc
        self._lock = _lock_for_path(self.path)
        self._reservations: dict[str, float] = {}
        self._session = _empty_totals()
        self._last_error = ""
        self._last_error_timestamp = ""

    def reserve(
        self,
        *,
        audit_id: str,
        attempt_count: int,
    ) -> tuple[str, str]:
        if not self.enabled or self.daily_limit_cny <= 0.0:
            return "", ""
        reservation_id = "%s:%d:%s" % (
            str(audit_id),
            int(attempt_count),
            uuid.uuid4().hex,
        )
        with self._lock:
            daily = self._read_day_totals_unlocked(self._current_day())
            if self._last_error:
                return "", "cost ledger unavailable: %s" % self._last_error
            in_flight = sum(self._reservations.values())
            projected = daily["estimated_cost_cny"] + in_flight + self.request_reserve_cny
            if projected > self.daily_limit_cny + 1e-9:
                return "", (
                    "daily cost ¥%.6f + in-flight reserve ¥%.6f + request reserve ¥%.6f "
                    "would exceed daily limit ¥%.2f (%s)"
                ) % (
                    daily["estimated_cost_cny"],
                    in_flight,
                    self.request_reserve_cny,
                    self.daily_limit_cny,
                    self.timezone_name,
                )
            self._reservations[reservation_id] = self.request_reserve_cny
        return reservation_id, ""

    def settle(
        self,
        reservation_id: str,
        *,
        audit_id: str,
        call_type: str,
        provider: str,
        model: str,
        attempt_count: int,
        prompt_tokens: int,
        prompt_cache_hit_tokens: int,
        prompt_cache_miss_tokens: int,
        completion_tokens: int,
        cache_hit_cost_per_million: float,
        cache_miss_cost_per_million: float,
        output_cost_per_million: float,
    ) -> dict[str, Any]:
        prompt_tokens = max(0, int(prompt_tokens))
        cache_hit_tokens = max(0, int(prompt_cache_hit_tokens))
        cache_miss_tokens = max(0, int(prompt_cache_miss_tokens))
        completion_tokens = max(0, int(completion_tokens))
        if cache_hit_tokens + cache_miss_tokens <= 0:
            cache_miss_tokens = prompt_tokens
        elif cache_hit_tokens + cache_miss_tokens < prompt_tokens:
            cache_miss_tokens += prompt_tokens - cache_hit_tokens - cache_miss_tokens
        input_tokens = max(prompt_tokens, cache_hit_tokens + cache_miss_tokens)
        estimated_cost_cny = round(
            (
                cache_hit_tokens * max(0.0, float(cache_hit_cost_per_million))
                + cache_miss_tokens * max(0.0, float(cache_miss_cost_per_million))
                + completion_tokens * max(0.0, float(output_cost_per_million))
            )
            / 1_000_000.0,
            8,
        )
        record = {
            "schema_version": 1,
            "event": "provider_usage",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "day": self._current_day(),
            "timezone": self.timezone_name,
            "audit_id": str(audit_id),
            "call_type": str(call_type),
            "provider": str(provider),
            "model": str(model),
            "attempt_count": int(attempt_count),
            "prompt_tokens": prompt_tokens,
            "prompt_cache_hit_tokens": cache_hit_tokens,
            "prompt_cache_miss_tokens": cache_miss_tokens,
            "completion_tokens": completion_tokens,
            "input_tokens": input_tokens,
            "output_tokens": completion_tokens,
            "total_tokens": input_tokens + completion_tokens,
            "estimated_cost_cny": estimated_cost_cny,
        }
        with self._lock:
            if reservation_id:
                self._reservations.pop(reservation_id, None)
            if self.enabled:
                self._append_unlocked(record)
            _accumulate(self._session, record)
        return record

    def settle_direct_cost(
        self,
        reservation_id: str,
        *,
        audit_id: str,
        call_type: str,
        provider: str,
        model: str,
        attempt_count: int,
        estimated_cost_cny: float,
    ) -> dict[str, Any]:
        """Settle providers billed by duration or request instead of tokens."""
        record = {
            "schema_version": 1,
            "event": "provider_usage",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "day": self._current_day(),
            "timezone": self.timezone_name,
            "audit_id": str(audit_id),
            "call_type": str(call_type),
            "provider": str(provider),
            "model": str(model),
            "attempt_count": int(attempt_count),
            "prompt_tokens": 0,
            "prompt_cache_hit_tokens": 0,
            "prompt_cache_miss_tokens": 0,
            "completion_tokens": 0,
            "input_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
            "estimated_cost_cny": round(
                max(0.0, float(estimated_cost_cny)),
                8,
            ),
        }
        with self._lock:
            if reservation_id:
                self._reservations.pop(reservation_id, None)
            if self.enabled:
                self._append_unlocked(record)
            _accumulate(self._session, record)
        return record

    def release(self, reservation_id: str) -> None:
        if not reservation_id:
            return
        with self._lock:
            self._reservations.pop(reservation_id, None)

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            day = self._current_day()
            daily = self._read_day_totals_unlocked(day) if self.enabled else _empty_totals()
            in_flight = round(sum(self._reservations.values()), 8)
            remaining = (
                None
                if self.daily_limit_cny <= 0.0
                else round(max(0.0, self.daily_limit_cny - daily["estimated_cost_cny"] - in_flight), 8)
            )
            return {
                "enabled": self.enabled,
                "currency": "CNY",
                "path": self._display_path(),
                "day": day,
                "timezone": self.timezone_name,
                "daily_limit_cny": self.daily_limit_cny,
                "request_reserve_cny": self.request_reserve_cny,
                "in_flight_reserved_cny": in_flight,
                "remaining_cny": remaining,
                "daily": daily,
                "session": dict(self._session),
                "last_error": self._last_error,
                "last_error_timestamp": self._last_error_timestamp,
            }

    def _read_day_totals_unlocked(self, day: str) -> dict[str, Any]:
        totals = _empty_totals()
        if not self.path.exists():
            return totals
        try:
            with self.path.open("r", encoding="utf-8") as ledger_file:
                for raw_line in ledger_file:
                    line = raw_line.strip()
                    if not line:
                        continue
                    try:
                        record = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if (
                        isinstance(record, dict)
                        and record.get("event") == "provider_usage"
                        and str(record.get("day", "")) == day
                    ):
                        _accumulate(totals, record)
        except Exception as exc:
            self._set_error(exc)
        return totals

    def _append_unlocked(self, record: dict[str, Any]) -> None:
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            line = json.dumps(
                record,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
                default=str,
            )
            with self.path.open("a", encoding="utf-8", newline="\n") as ledger_file:
                ledger_file.write(line)
                ledger_file.write("\n")
        except Exception as exc:
            self._set_error(exc)

    def _set_error(self, exc: Exception) -> None:
        self._last_error = "%s: %s" % (exc.__class__.__name__, str(exc))
        self._last_error_timestamp = datetime.now(timezone.utc).isoformat()

    def _current_day(self) -> str:
        return datetime.now(self._timezone).date().isoformat()

    @staticmethod
    def _resolve_path(raw_path: str) -> Path:
        if not str(raw_path).strip():
            return DEFAULT_LLM_COST_LEDGER_PATH.resolve()
        configured = Path(str(raw_path).strip()).expanduser()
        if not configured.is_absolute():
            configured = REPO_ROOT / configured
        return configured.resolve()

    def _display_path(self) -> str:
        try:
            return self.path.relative_to(REPO_ROOT).as_posix()
        except ValueError:
            return str(self.path)


def _empty_totals() -> dict[str, Any]:
    return {
        "attempt_count": 0,
        "input_tokens": 0,
        "prompt_cache_hit_tokens": 0,
        "prompt_cache_miss_tokens": 0,
        "output_tokens": 0,
        "total_tokens": 0,
        "estimated_cost_cny": 0.0,
    }


def _accumulate(totals: dict[str, Any], record: dict[str, Any]) -> None:
    totals["attempt_count"] += 1
    for key in (
        "input_tokens",
        "prompt_cache_hit_tokens",
        "prompt_cache_miss_tokens",
        "output_tokens",
        "total_tokens",
    ):
        totals[key] += int(record.get(key, 0) or 0)
    totals["estimated_cost_cny"] = round(
        float(totals["estimated_cost_cny"])
        + float(record.get("estimated_cost_cny", 0.0) or 0.0),
        8,
    )


def _lock_for_path(path: Path) -> threading.RLock:
    path_key = str(path)
    with _LOCKS_GUARD:
        lock = _PATH_LOCKS.get(path_key)
        if lock is None:
            lock = threading.RLock()
            _PATH_LOCKS[path_key] = lock
        return lock
