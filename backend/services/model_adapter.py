import os
import json
import re
import uuid
from copy import deepcopy
from dataclasses import asdict, dataclass, replace
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

try:
    from backend.services.llm_audit_logger import LLMCallAuditLogger
    from backend.services.llm_cost_ledger import LLMCostLedger
except ModuleNotFoundError:
    from services.llm_audit_logger import LLMCallAuditLogger
    from services.llm_cost_ledger import LLMCostLedger


PROMPT_TEMPLATE_DIR = Path(__file__).resolve().parents[2] / "data" / "prompts"
PROMPT_TEMPLATE_BY_CALL_TYPE = {
    "dialogue": "dialogue_system_prompt.txt",
    "dialogue_intent_revalidation": "dialogue_intent_revalidation_system_prompt.txt",
    "plan_revision_judgement": "plan_revision_judgement_system_prompt.txt",
    "dialogue_plan_revision_judgement": "plan_revision_judgement_system_prompt.txt",
    "plan_day": "daily_plan_system_prompt.txt",
    "revise_plan": "plan_revision_system_prompt.txt",
    "battle_judgement": "battle_judgement_system_prompt.txt",
    "daily_reflection": "daily_reflection_system_prompt.txt",
}


@dataclass(frozen=True)
class ModelAdapterConfig:
    provider: str = "mock"
    api_key: str | None = None
    base_url: str = ""
    model: str = ""
    provider_connect_timeout_seconds: float = 10.0
    provider_idle_timeout_seconds: float = 120.0
    fallback_to_mock: bool = False
    input_cost_per_million: float = 0.0
    input_cache_hit_cost_per_million: float = 0.0
    output_cost_per_million: float = 0.0
    temperature: float = 0.4
    force_json_response: bool = True
    thinking_mode: str = "disabled"
    budget_max_calls: int = 0
    budget_max_input_tokens: int = 0
    budget_max_output_tokens: int = 0
    budget_max_total_tokens: int = 0
    budget_max_estimated_cost: float = 0.0
    daily_budget_max_cost_cny: float = 0.0
    daily_budget_timezone: str = "Asia/Shanghai"
    daily_budget_request_reserve_cny: float = 0.0
    cost_ledger_enabled: bool = False
    cost_ledger_path: str = ""
    audit_log_enabled: bool = False
    audit_log_path: str = ""
    audit_log_include_payloads: bool = True


@dataclass(frozen=True)
class ModelUsageRecord:
    timestamp: str
    provider: str
    model: str
    call_type: str
    request_id: str | None
    npc_id: str | None
    related_event_id: str | None
    input_tokens: int
    output_tokens: int
    estimated_cost: float
    success: bool
    fallback_used: bool = False
    failure_reason: str = ""
    http_status: int | None = None
    exception_type: str = ""
    degradation_source: str = ""
    finish_reason: str = ""
    response_content_length: int = 0
    attempt_count: int = 1
    thinking_mode: str = ""


@dataclass(frozen=True)
class ModelAdapterResult:
    ok: bool
    provider: str
    call_type: str
    content: dict[str, Any]
    usage: dict[str, Any]
    error_code: str = ""
    message: str = ""


class ModelProviderError(RuntimeError):
    def __init__(
        self,
        message: str,
        http_status: int | None = None,
        exception_type: str = "ProviderError",
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.http_status = http_status
        self.exception_type = exception_type
        self.details = details or {}


class ModelAdapter:
    """Provider boundary with a deterministic mock backend for local development."""

    SKILL_TO_WORK_ACTION = {
        "养马": "work_stable",
        "厨艺": "work_dining_hall",
        "耕种": "work_garden",
        "打铁": "work_blacksmith",
        "教练": "work_garden",
        "酿酒": "work_tavern",
        "医术": "work_clinic_doctor",
        "工程": "work_workshop",
    }

    def __init__(self, config: ModelAdapterConfig | None = None) -> None:
        raw_config = config or self._config_from_env()
        provider = raw_config.provider.strip().lower() or "mock"
        self.config = ModelAdapterConfig(
            provider=provider,
            api_key=raw_config.api_key,
            base_url=raw_config.base_url.strip(),
            model=raw_config.model.strip(),
            provider_connect_timeout_seconds=max(0.1, raw_config.provider_connect_timeout_seconds),
            provider_idle_timeout_seconds=max(0.1, raw_config.provider_idle_timeout_seconds),
            fallback_to_mock=raw_config.fallback_to_mock,
            input_cost_per_million=max(0.0, raw_config.input_cost_per_million),
            input_cache_hit_cost_per_million=max(
                0.0,
                raw_config.input_cache_hit_cost_per_million,
            ),
            output_cost_per_million=max(0.0, raw_config.output_cost_per_million),
            temperature=raw_config.temperature,
            force_json_response=raw_config.force_json_response,
            thinking_mode=self._normalize_thinking_mode(raw_config.thinking_mode),
            budget_max_calls=max(0, raw_config.budget_max_calls),
            budget_max_input_tokens=max(0, raw_config.budget_max_input_tokens),
            budget_max_output_tokens=max(0, raw_config.budget_max_output_tokens),
            budget_max_total_tokens=max(0, raw_config.budget_max_total_tokens),
            budget_max_estimated_cost=max(0.0, raw_config.budget_max_estimated_cost),
            daily_budget_max_cost_cny=max(0.0, raw_config.daily_budget_max_cost_cny),
            daily_budget_timezone=raw_config.daily_budget_timezone.strip() or "Asia/Shanghai",
            daily_budget_request_reserve_cny=max(
                0.0,
                raw_config.daily_budget_request_reserve_cny,
            ),
            cost_ledger_enabled=raw_config.cost_ledger_enabled,
            cost_ledger_path=raw_config.cost_ledger_path.strip(),
            audit_log_enabled=raw_config.audit_log_enabled,
            audit_log_path=raw_config.audit_log_path.strip(),
            audit_log_include_payloads=raw_config.audit_log_include_payloads,
        )
        self._usage_records: list[ModelUsageRecord] = []
        self._audit_id_by_usage_timestamp: dict[str, str] = {}
        self._audit_logger = LLMCallAuditLogger(
            enabled=self.config.audit_log_enabled,
            path=self.config.audit_log_path,
            include_payloads=self.config.audit_log_include_payloads,
            secret_values=(self.config.api_key,),
        )
        self._cost_ledger = LLMCostLedger(
            enabled=self.config.cost_ledger_enabled and provider != "mock",
            path=self.config.cost_ledger_path,
            daily_limit_cny=self.config.daily_budget_max_cost_cny,
            timezone_name=self.config.daily_budget_timezone,
            request_reserve_cny=self.config.daily_budget_request_reserve_cny,
        )

    @staticmethod
    def _config_from_env() -> ModelAdapterConfig:
        provider = os.getenv("LLM_PROVIDER", "mock").strip().lower() or "mock"
        model = os.getenv("LLM_MODEL", "").strip()
        default_prices = _default_provider_prices(provider, model)
        return ModelAdapterConfig(
            provider=provider,
            api_key=os.getenv("LLM_API_KEY"),
            base_url=os.getenv("LLM_BASE_URL", ""),
            model=model,
            provider_connect_timeout_seconds=_read_float_env("LLM_PROVIDER_CONNECT_TIMEOUT_SECONDS", 10.0),
            provider_idle_timeout_seconds=_read_float_env("LLM_PROVIDER_IDLE_TIMEOUT_SECONDS", 120.0),
            fallback_to_mock=_read_bool_env("LLM_FALLBACK_TO_MOCK", False),
            input_cost_per_million=_read_float_env(
                "LLM_INPUT_COST_PER_M_TOKENS",
                default_prices["input_cache_miss"],
            ),
            input_cache_hit_cost_per_million=_read_float_env(
                "LLM_INPUT_CACHE_HIT_COST_PER_M_TOKENS",
                default_prices["input_cache_hit"],
            ),
            output_cost_per_million=_read_float_env(
                "LLM_OUTPUT_COST_PER_M_TOKENS",
                default_prices["output"],
            ),
            temperature=_read_float_env("LLM_TEMPERATURE", 0.4),
            force_json_response=_read_bool_env("LLM_FORCE_JSON_RESPONSE", True),
            thinking_mode=os.getenv("LLM_THINKING_MODE", "disabled"),
            budget_max_calls=_read_int_env("LLM_BUDGET_MAX_CALLS", 0),
            budget_max_input_tokens=_read_int_env("LLM_BUDGET_MAX_INPUT_TOKENS", 0),
            budget_max_output_tokens=_read_int_env("LLM_BUDGET_MAX_OUTPUT_TOKENS", 0),
            budget_max_total_tokens=_read_int_env("LLM_BUDGET_MAX_TOTAL_TOKENS", 0),
            budget_max_estimated_cost=_read_float_env("LLM_BUDGET_MAX_COST", 0.0),
            daily_budget_max_cost_cny=_read_float_env(
                "LLM_DAILY_BUDGET_MAX_CNY",
                20.0 if provider != "mock" else 0.0,
            ),
            daily_budget_timezone=os.getenv("LLM_DAILY_BUDGET_TIMEZONE", "Asia/Shanghai"),
            daily_budget_request_reserve_cny=_read_float_env(
                "LLM_DAILY_BUDGET_REQUEST_RESERVE_CNY",
                default_prices["request_reserve"],
            ),
            cost_ledger_enabled=_read_bool_env(
                "LLM_COST_LEDGER_ENABLED",
                provider != "mock",
            ),
            cost_ledger_path=os.getenv("LLM_COST_LEDGER_PATH", ""),
            audit_log_enabled=_read_bool_env("LLM_AUDIT_LOG_ENABLED", True),
            audit_log_path=os.getenv("LLM_AUDIT_LOG_PATH", ""),
            audit_log_include_payloads=_read_bool_env("LLM_AUDIT_LOG_INCLUDE_PAYLOADS", True),
        )

    def is_configured(self) -> bool:
        if self.config.provider == "mock":
            return True
        return bool(self.config.api_key)

    def generate(self, call_type: str, payload: dict[str, Any] | None = None) -> ModelAdapterResult:
        source_payload = payload or {}
        request_id = self._read_request_id(source_payload)
        npc_id = self._read_npc_id(source_payload)
        related_event_id = self._read_related_event_id(source_payload)
        payload = self._provider_request_payload(call_type, source_payload)
        input_tokens = self._estimate_tokens(payload)
        audit_id = uuid.uuid4().hex
        self._audit_logger.write(
            "call_started",
            audit_id,
            call_type=call_type,
            provider=self.config.provider,
            model=self._provider_model() if self.config.provider != "mock" else "mock",
            request_id=request_id,
            npc_id=npc_id,
            related_event_id=related_event_id,
            estimated_input_tokens=input_tokens,
            input_payload=payload,
        )
        budget_failure = self._budget_failure_if_exceeded(
            call_type,
            input_tokens,
            request_id,
            npc_id,
            related_event_id,
            audit_id,
        )
        if budget_failure is not None:
            return self._finalize_audit_result(audit_id, budget_failure)

        if self.config.provider != "mock":
            if not self.config.api_key:
                result = self._fallback_or_failure(
                    call_type,
                    payload,
                    input_tokens,
                    request_id,
                    npc_id,
                    related_event_id,
                    "LLM_API_KEY is required for non-mock providers.",
                    exception_type="ConfigurationError",
                    audit_id=audit_id,
                )
                return self._finalize_audit_result(audit_id, result)
            try:
                content, provider_usage = self._generate_real_content(call_type, payload, audit_id)
            except Exception as exc:
                failure_details = self._provider_failure_details(exc)
                if failure_details["exception_type"] == "BudgetExceeded":
                    result = self._budget_failure_result(
                        call_type,
                        input_tokens,
                        request_id,
                        npc_id,
                        related_event_id,
                        failure_details["failure_reason"],
                        audit_id,
                    )
                    return self._finalize_audit_result(audit_id, result)
                result = self._fallback_or_failure(
                    call_type,
                    payload,
                    input_tokens,
                    request_id,
                    npc_id,
                    related_event_id,
                    failure_details["failure_reason"],
                    http_status=failure_details["http_status"],
                    exception_type=failure_details["exception_type"],
                    output_tokens=failure_details["output_tokens"],
                    finish_reason=failure_details["finish_reason"],
                    response_content_length=failure_details["response_content_length"],
                    attempt_count=failure_details["attempt_count"],
                    thinking_mode=failure_details["thinking_mode"],
                    audit_id=audit_id,
                )
                return self._finalize_audit_result(audit_id, result)
            output_tokens = int(provider_usage.get("output_tokens", self._estimate_tokens(content)))
            content = self._hydrate_model_output(call_type, payload, content)
            input_tokens = int(provider_usage.get("input_tokens", input_tokens))
            estimated_cost = float(
                provider_usage.get(
                    "estimated_cost_cny",
                    self._estimate_cost(input_tokens, output_tokens),
                )
                or 0.0
            )
            usage = self._record_usage(
                call_type=call_type,
                request_id=request_id,
                npc_id=npc_id,
                related_event_id=related_event_id,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                estimated_cost=estimated_cost,
                success=True,
                finish_reason=str(provider_usage.get("finish_reason", "")),
                response_content_length=int(provider_usage.get("response_content_length", 0) or 0),
                attempt_count=int(provider_usage.get("attempt_count", 1) or 1),
                thinking_mode=str(provider_usage.get("thinking_mode", "")),
                audit_id=audit_id,
            )
            result = ModelAdapterResult(
                ok=True,
                provider=self.config.provider,
                call_type=call_type,
                content=content,
                usage=usage,
            )
            return self._finalize_audit_result(audit_id, result)

        content = self._mock_content(call_type, payload)
        output_tokens = self._estimate_tokens(content)
        content = self._hydrate_model_output(call_type, payload, content)
        usage = self._record_usage(
            call_type=call_type,
            request_id=request_id,
            npc_id=npc_id,
            related_event_id=related_event_id,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            estimated_cost=0.0,
            success=True,
            audit_id=audit_id,
        )
        result = ModelAdapterResult(
            ok=True,
            provider=self.config.provider,
            call_type=call_type,
            content=content,
            usage=usage,
        )
        return self._finalize_audit_result(audit_id, result)

    def get_usage_records(self) -> list[dict[str, Any]]:
        return [asdict(record) for record in self._usage_records]

    def _finalize_audit_result(
        self,
        audit_id: str,
        result: ModelAdapterResult,
    ) -> ModelAdapterResult:
        self._audit_logger.write(
            "call_completed",
            audit_id,
            call_type=result.call_type,
            provider=result.provider,
            model=str(result.usage.get("model", "")),
            request_id=result.usage.get("request_id"),
            npc_id=result.usage.get("npc_id"),
            related_event_id=result.usage.get("related_event_id"),
            ok=result.ok,
            error_code=result.error_code,
            message=result.message,
            model_output=result.content,
            usage=result.usage,
        )
        return result

    def get_usage_summary(self) -> dict[str, Any]:
        total_input = 0
        total_output = 0
        total_cost = 0.0
        successful = 0
        failed = 0
        fallback_count = 0
        by_call_type: dict[str, dict[str, Any]] = {}
        for record in self._usage_records:
            total_input += record.input_tokens
            total_output += record.output_tokens
            total_cost += record.estimated_cost
            successful += 1 if record.success else 0
            failed += 0 if record.success else 1
            fallback_count += 1 if record.fallback_used else 0
            item = by_call_type.setdefault(record.call_type, {
                "count": 0,
                "input_tokens": 0,
                "output_tokens": 0,
                "estimated_cost": 0.0,
            })
            item["count"] += 1
            item["input_tokens"] += record.input_tokens
            item["output_tokens"] += record.output_tokens
            item["estimated_cost"] += record.estimated_cost
        return {
            "count": len(self._usage_records),
            "successful": successful,
            "failed": failed,
            "fallback_count": fallback_count,
            "input_tokens": total_input,
            "output_tokens": total_output,
            "estimated_cost": round(total_cost, 8),
            "currency": "CNY",
            "recent_failure_reason": self._recent_failure_reason(),
            "recent_failure": self._recent_failure_record(),
            "by_call_type": by_call_type,
            "budget": self.get_budget_snapshot(total_input, total_output, total_cost),
            "provider_usage": self._cost_ledger.snapshot(),
        }

    def get_budget_snapshot(
        self,
        total_input: int | None = None,
        total_output: int | None = None,
        total_cost: float | None = None,
    ) -> dict[str, Any]:
        if total_input is None or total_output is None or total_cost is None:
            total_input = sum(record.input_tokens for record in self._usage_records)
            total_output = sum(record.output_tokens for record in self._usage_records)
            total_cost = sum(record.estimated_cost for record in self._usage_records)
        total_tokens = int(total_input) + int(total_output)
        limits = {
            "max_calls": self.config.budget_max_calls,
            "max_input_tokens": self.config.budget_max_input_tokens,
            "max_output_tokens": self.config.budget_max_output_tokens,
            "max_total_tokens": self.config.budget_max_total_tokens,
            "max_estimated_cost": self.config.budget_max_estimated_cost,
        }
        used = {
            "calls": len(self._usage_records),
            "input_tokens": int(total_input),
            "output_tokens": int(total_output),
            "total_tokens": total_tokens,
            "estimated_cost": round(float(total_cost), 8),
        }
        remaining: dict[str, Any] = {}
        for limit_key, used_key in [
            ("max_calls", "calls"),
            ("max_input_tokens", "input_tokens"),
            ("max_output_tokens", "output_tokens"),
            ("max_total_tokens", "total_tokens"),
            ("max_estimated_cost", "estimated_cost"),
        ]:
            limit_value = limits[limit_key]
            remaining[limit_key.removeprefix("max_")] = None if limit_value <= 0 else round(limit_value - used[used_key], 8)
        exceeded = self._budget_exceeded_reasons(0)
        daily_budget = self._cost_ledger.snapshot()
        return {
            "enabled": any(value > 0 for value in limits.values())
            or daily_budget["daily_limit_cny"] > 0.0,
            "limits": limits,
            "used": used,
            "remaining": remaining,
            "exceeded": exceeded,
            "recent_budget_error": self._recent_budget_error_record(),
            "daily": daily_budget,
        }

    def get_runtime_config_snapshot(self) -> dict[str, Any]:
        return {
            "provider": self.config.provider,
            "model": self._provider_model(),
            "base_url": self._provider_base_url(),
            "configured": self.is_configured(),
            "fallback_to_mock": self.config.fallback_to_mock,
            "provider_connect_timeout_seconds": self.config.provider_connect_timeout_seconds,
            "provider_idle_timeout_seconds": self.config.provider_idle_timeout_seconds,
            "provider_streaming": True,
            "client_output_token_limit_applied": False,
            "temperature": self.config.temperature,
            "force_json_response": self.config.force_json_response,
            "thinking_mode": self.config.thinking_mode,
            "pricing_cny_per_million_tokens": {
                "input_cache_hit": self.config.input_cache_hit_cost_per_million,
                "input_cache_miss": self.config.input_cost_per_million,
                "output": self.config.output_cost_per_million,
            },
            "budget": self.get_budget_snapshot(),
            "cost_ledger": self._cost_ledger.snapshot(),
            "audit_log": self._audit_logger.snapshot(),
        }

    def _budget_failure_if_exceeded(
        self,
        call_type: str,
        input_tokens: int,
        request_id: str | None,
        npc_id: str | None,
        related_event_id: str | None,
        audit_id: str = "",
    ) -> ModelAdapterResult | None:
        reasons = self._budget_exceeded_reasons(input_tokens)
        if not reasons:
            return None
        failure_reason = "LLM budget exceeded: %s." % "; ".join(reasons)
        return self._budget_failure_result(
            call_type,
            input_tokens,
            request_id,
            npc_id,
            related_event_id,
            failure_reason,
            audit_id,
        )

    def _budget_failure_result(
        self,
        call_type: str,
        input_tokens: int,
        request_id: str | None,
        npc_id: str | None,
        related_event_id: str | None,
        failure_reason: str,
        audit_id: str = "",
    ) -> ModelAdapterResult:
        usage = self._record_usage(
            call_type=call_type,
            request_id=request_id,
            npc_id=npc_id,
            related_event_id=related_event_id,
            input_tokens=input_tokens,
            output_tokens=0,
            estimated_cost=0.0,
            success=False,
            failure_reason=failure_reason,
            exception_type="BudgetExceeded",
            degradation_source="budget_blocked",
            audit_id=audit_id,
        )
        return ModelAdapterResult(
            ok=False,
            provider=self.config.provider,
            call_type=call_type,
            content={},
            usage=usage,
            error_code="budget_exceeded",
            message=failure_reason,
        )

    def _budget_exceeded_reasons(self, projected_input_tokens: int) -> list[str]:
        reasons: list[str] = []
        if not any([
            self.config.budget_max_calls,
            self.config.budget_max_input_tokens,
            self.config.budget_max_output_tokens,
            self.config.budget_max_total_tokens,
            self.config.budget_max_estimated_cost,
            self.config.daily_budget_max_cost_cny,
        ]):
            return reasons
        if self.config.provider != "mock" and self.config.daily_budget_max_cost_cny > 0.0:
            if not self.config.cost_ledger_enabled:
                reasons.append("daily CNY budget requires LLM_COST_LEDGER_ENABLED=true")
            if self.config.input_cost_per_million <= 0.0 or self.config.output_cost_per_million <= 0.0:
                reasons.append("daily CNY budget requires positive input/output token prices")
        summary_input = sum(record.input_tokens for record in self._usage_records)
        summary_output = sum(record.output_tokens for record in self._usage_records)
        summary_cost = sum(record.estimated_cost for record in self._usage_records)
        projected_calls = len(self._usage_records) + 1
        projected_input = summary_input + max(0, projected_input_tokens)
        projected_total = projected_input + summary_output
        projected_input_cost = self._estimate_cost(max(0, projected_input_tokens), 0)
        projected_cost = summary_cost + projected_input_cost
        if self.config.budget_max_calls > 0 and projected_calls > self.config.budget_max_calls:
            reasons.append("call count %d would exceed max_calls %d" % (projected_calls, self.config.budget_max_calls))
        if self.config.budget_max_input_tokens > 0 and projected_input > self.config.budget_max_input_tokens:
            reasons.append("input tokens %d would exceed max_input_tokens %d" % (projected_input, self.config.budget_max_input_tokens))
        if self.config.budget_max_output_tokens > 0 and summary_output >= self.config.budget_max_output_tokens:
            reasons.append("output tokens %d reached max_output_tokens %d" % (summary_output, self.config.budget_max_output_tokens))
        if self.config.budget_max_total_tokens > 0 and projected_total > self.config.budget_max_total_tokens:
            reasons.append("total tokens %d would exceed max_total_tokens %d" % (projected_total, self.config.budget_max_total_tokens))
        if self.config.budget_max_estimated_cost > 0.0 and projected_cost > self.config.budget_max_estimated_cost:
            reasons.append("estimated cost %.8f would exceed max_estimated_cost %.8f" % (projected_cost, self.config.budget_max_estimated_cost))
        return reasons

    def _fallback_or_failure(
        self,
        call_type: str,
        payload: dict[str, Any],
        input_tokens: int,
        request_id: str | None,
        npc_id: str | None,
        related_event_id: str | None,
        failure_reason: str,
        http_status: int | None = None,
        exception_type: str = "ProviderError",
        output_tokens: int = 0,
        finish_reason: str = "",
        response_content_length: int = 0,
        attempt_count: int = 1,
        thinking_mode: str = "",
        audit_id: str = "",
    ) -> ModelAdapterResult:
        if self.config.fallback_to_mock:
            content = self._mock_content(call_type, payload)
            output_tokens = self._estimate_tokens(content)
            content["debug_reason"] = "%s_fallback_from_%s:%s" % (
                str(content.get("debug_reason", "mock")),
                self.config.provider,
                failure_reason,
            )
            content = self._hydrate_model_output(call_type, payload, content)
            usage = self._record_usage(
                call_type=call_type,
                request_id=request_id,
                npc_id=npc_id,
                related_event_id=related_event_id,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                estimated_cost=0.0,
                success=True,
                fallback_used=True,
                failure_reason=failure_reason,
                http_status=http_status,
                exception_type=exception_type,
                degradation_source="mock_fallback",
                finish_reason=finish_reason,
                response_content_length=response_content_length,
                attempt_count=attempt_count,
                thinking_mode=thinking_mode,
                audit_id=audit_id,
            )
            return ModelAdapterResult(
                ok=True,
                provider="mock",
                call_type=call_type,
                content=content,
                usage=usage,
                message="Mock fallback used after provider failure.",
            )
        usage = self._record_usage(
            call_type=call_type,
            request_id=request_id,
            npc_id=npc_id,
            related_event_id=related_event_id,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            estimated_cost=self._estimate_cost(input_tokens, output_tokens),
            success=False,
            failure_reason=failure_reason,
            http_status=http_status,
            exception_type=exception_type,
            finish_reason=finish_reason,
            response_content_length=response_content_length,
            attempt_count=attempt_count,
            thinking_mode=thinking_mode,
            audit_id=audit_id,
        )
        return ModelAdapterResult(
            ok=False,
            provider=self.config.provider,
            call_type=call_type,
            content={},
            usage=usage,
            error_code="provider_unavailable",
            message=failure_reason,
        )

    def record_model_output_invalid(
        self,
        call_type: str,
        payload: dict[str, Any],
        failure_reason: str,
        upstream_usage: dict[str, Any] | None = None,
        model_output: dict[str, Any] | None = None,
        validation_details: Any = None,
    ) -> dict[str, Any]:
        upstream_usage = upstream_usage or {}
        request_id = self._read_request_id(payload)
        npc_id = self._read_npc_id(payload)
        upstream_timestamp = str(upstream_usage.get("timestamp", "") or "")
        audit_id = self._audit_id_by_usage_timestamp.get(upstream_timestamp, "")
        if request_id:
            for index in range(len(self._usage_records) - 1, -1, -1):
                record = self._usage_records[index]
                if (
                    record.call_type != call_type
                    or record.request_id != request_id
                    or record.npc_id != npc_id
                ):
                    continue
                if upstream_timestamp and record.timestamp != upstream_timestamp:
                    continue
                if not record.success and record.exception_type == "SchemaValidationError":
                    return asdict(record)
                if record.success:
                    audit_id = audit_id or self._audit_id_by_usage_timestamp.get(record.timestamp, "")
                    combined_failure_reason = failure_reason
                    if record.failure_reason and record.failure_reason != failure_reason:
                        combined_failure_reason = "%s; %s" % (record.failure_reason, failure_reason)
                    invalid_record = replace(
                        record,
                        success=False,
                        failure_reason=combined_failure_reason,
                        exception_type="SchemaValidationError",
                    )
                    self._usage_records[index] = invalid_record
                    self._write_model_output_invalid_audit(
                        audit_id,
                        call_type,
                        payload,
                        model_output,
                        validation_details,
                        combined_failure_reason,
                        asdict(invalid_record),
                    )
                    return asdict(invalid_record)
        audit_id = audit_id or uuid.uuid4().hex
        invalid_usage = self._record_usage(
            call_type=call_type,
            request_id=request_id,
            npc_id=npc_id,
            related_event_id=self._read_related_event_id(payload),
            input_tokens=int(upstream_usage.get("input_tokens", self._estimate_tokens(payload)) or 0),
            output_tokens=int(upstream_usage.get("output_tokens", 0) or 0),
            estimated_cost=float(upstream_usage.get("estimated_cost", 0.0) or 0.0),
            success=False,
            failure_reason=failure_reason,
            exception_type="SchemaValidationError",
            audit_id=audit_id,
        )
        self._write_model_output_invalid_audit(
            audit_id,
            call_type,
            payload,
            model_output,
            validation_details,
            failure_reason,
            invalid_usage,
        )
        return invalid_usage

    def _write_model_output_invalid_audit(
        self,
        audit_id: str,
        call_type: str,
        payload: dict[str, Any],
        model_output: dict[str, Any] | None,
        validation_details: Any,
        failure_reason: str,
        usage: dict[str, Any],
    ) -> None:
        self._audit_logger.write(
            "business_validation_failed",
            audit_id or uuid.uuid4().hex,
            call_type=call_type,
            provider=str(usage.get("provider", self.config.provider)),
            model=str(usage.get("model", "")),
            request_id=usage.get("request_id") or self._read_request_id(payload),
            npc_id=usage.get("npc_id") or self._read_npc_id(payload),
            related_event_id=usage.get("related_event_id") or self._read_related_event_id(payload),
            failure_reason=failure_reason,
            exception_type="SchemaValidationError",
            input_payload=payload,
            model_output=model_output or {},
            validation_details=validation_details if validation_details is not None else [],
            usage=usage,
        )

    def _generate_real_content(
        self,
        call_type: str,
        payload: dict[str, Any],
        audit_id: str = "",
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        if self.config.provider not in {"deepseek", "openai_compatible"}:
            raise RuntimeError("Unsupported LLM_PROVIDER: %s" % self.config.provider)
        max_attempts = 2 if call_type in PROMPT_TEMPLATE_BY_CALL_TYPE else 1
        last_error: ModelProviderError | None = None
        for attempt_index in range(max_attempts):
            attempt_count = attempt_index + 1
            response_json = self._send_chat_completion(
                call_type,
                payload,
                retry_compact_json=attempt_count > 1,
                audit_id=audit_id,
                attempt_count=attempt_count,
            )
            choices = response_json.get("choices", [])
            if not choices or not isinstance(choices[0], dict):
                raise RuntimeError("Provider response did not include choices.")
            choice = choices[0]
            finish_reason = str(choice.get("finish_reason", ""))
            message = choice.get("message", {})
            if not isinstance(message, dict):
                raise RuntimeError("Provider response message was invalid.")
            content_text = str(message.get("content", "")).strip()
            usage = response_json.get("usage", {})
            billing = response_json.get("_billing", {})
            input_tokens = (
                int(usage.get("prompt_tokens", self._estimate_tokens(payload)))
                if isinstance(usage, dict)
                else self._estimate_tokens(payload)
            )
            output_tokens = (
                int(usage.get("completion_tokens", self._estimate_tokens(content_text)))
                if isinstance(usage, dict)
                else self._estimate_tokens(content_text)
            )
            if finish_reason == "length":
                self._audit_logger.write(
                    "provider_output_rejected",
                    audit_id,
                    call_type=call_type,
                    provider=self.config.provider,
                    model=self._provider_model(),
                    attempt_count=attempt_count,
                    rejection_type="ModelOutputTruncated",
                    finish_reason=finish_reason,
                    raw_model_content=content_text,
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                )
                last_error = ModelProviderError(
                    (
                        "Provider stopped at its output or context limit"
                        " (finish_reason=length, content_length=%d, attempt=%d/%d)."
                    )
                    % (len(content_text), attempt_count, max_attempts),
                    exception_type="ModelOutputTruncated",
                    details={
                        "output_tokens": output_tokens,
                        "finish_reason": finish_reason,
                        "response_content_length": len(content_text),
                        "attempt_count": attempt_count,
                        "thinking_mode": self.config.thinking_mode,
                    },
                )
                if attempt_count < max_attempts:
                    continue
                raise last_error
            try:
                content = self._parse_model_json(content_text)
            except (json.JSONDecodeError, RuntimeError) as exc:
                self._audit_logger.write(
                    "provider_output_rejected",
                    audit_id,
                    call_type=call_type,
                    provider=self.config.provider,
                    model=self._provider_model(),
                    attempt_count=attempt_count,
                    rejection_type="ModelJSONDecodeError",
                    failure_reason=str(exc),
                    finish_reason=finish_reason,
                    raw_model_content=content_text,
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                )
                last_error = ModelProviderError(
                    (
                        "Provider returned invalid JSON"
                        " (finish_reason=%s, content_length=%d, attempt=%d/%d): %s"
                    )
                    % (
                        finish_reason or "unknown",
                        len(content_text),
                        attempt_count,
                        max_attempts,
                        str(exc),
                    ),
                    exception_type="ModelJSONDecodeError",
                    details={
                        "output_tokens": output_tokens,
                        "finish_reason": finish_reason,
                        "response_content_length": len(content_text),
                        "attempt_count": attempt_count,
                        "thinking_mode": self.config.thinking_mode,
                    },
                )
                if attempt_count < max_attempts:
                    continue
                raise last_error from exc
            self._audit_logger.write(
                "provider_output_parsed",
                audit_id,
                call_type=call_type,
                provider=self.config.provider,
                model=self._provider_model(),
                attempt_count=attempt_count,
                finish_reason=finish_reason,
                raw_model_content=content_text,
                model_output=content,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
            )
            provider_usage = {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "prompt_cache_hit_tokens": int(
                    billing.get("prompt_cache_hit_tokens", 0)
                    if isinstance(billing, dict)
                    else 0
                ),
                "prompt_cache_miss_tokens": int(
                    billing.get("prompt_cache_miss_tokens", input_tokens)
                    if isinstance(billing, dict)
                    else input_tokens
                ),
                "estimated_cost_cny": float(
                    billing.get("estimated_cost_cny", self._estimate_cost(input_tokens, output_tokens))
                    if isinstance(billing, dict)
                    else self._estimate_cost(input_tokens, output_tokens)
                ),
                "finish_reason": finish_reason,
                "response_content_length": len(content_text),
                "attempt_count": attempt_count,
                "thinking_mode": self.config.thinking_mode,
            }
            return content, provider_usage
        if last_error is not None:
            raise last_error
        raise RuntimeError("Provider did not return content.")

    def _send_chat_completion(
        self,
        call_type: str,
        payload: dict[str, Any],
        retry_compact_json: bool = False,
        audit_id: str = "",
        attempt_count: int = 1,
    ) -> dict[str, Any]:
        url = "%s/chat/completions" % self._provider_base_url().rstrip("/")
        system_prompt = self._system_prompt_for_call_type(call_type, payload)
        if retry_compact_json:
            if call_type in {"plan_revision_judgement", "dialogue_plan_revision_judgement"}:
                system_prompt += (
                    "\n上一次计划修改范围判别输出为空、截断或不是合法 JSON。"
                    "这次只输出 revision_hours、summary、debug_reason；"
                    "revision_hours 必须升序去重、不得早于 game_time.hour，并包含全部 required_revision_hours；"
                    "后端会由 revision_hours 是否为空生成 needs_revision。"
                )
            elif call_type == "revise_plan":
                system_prompt += (
                    "\n上一次定向计划重估输出为空、截断或不是合法 JSON。"
                    "这次 revised_plan 的小时必须与请求 revision_hours 完全一致，不能缺失、增加、重复或乱序；"
                    "不要输出 immediate_action，后端会从 revised_plan 的当前小时项生成。"
                    "每条 reason 不超过 12 个汉字，summary 不超过 40 个汉字，"
                    "对话行动的 dialogue_goal 不超过 40 个汉字，debug_reason 不超过 30 个汉字。"
                )
            elif call_type == "plan_day":
                system_prompt += (
                    "\n上一次每日计划输出为空、被供应商截断或不是合法 JSON。"
                    "这次直接输出完整紧凑 JSON；plan 中每条 reason 不超过 12 个汉字，"
                    "summary 不超过 60 个汉字，debug_reason 不超过 40 个汉字。"
                )
            elif call_type == "dialogue_intent_revalidation":
                system_prompt += (
                    "\n上一次对话意图执行前复核输出为空、截断或不是合法 JSON。"
                    "这次只输出 decision、dialogue_goal、summary、debug_reason；"
                    "decision 只能是 continue、modify、cancel_and_replan。"
                    "只有 modify 可以输出非空 dialogue_goal。"
                )
            elif call_type == "dialogue":
                system_prompt += (
                    "\n上一次对话输出为空、被供应商截断或不是合法 JSON。"
                    "这次只输出所需 JSON 字段；reply_text 保持简洁，"
                    "debug_reason 不超过 30 个汉字。"
                )
            elif call_type == "battle_judgement":
                system_prompt += (
                    "\n上一次战时心理判定输出为空、被供应商截断或不是合法 JSON。"
                    "这次只输出所需 JSON 字段，decision 必须来自 allowed_decisions，"
                    "debug_reason 不超过 30 个汉字。"
                )
            elif call_type == "daily_reflection":
                system_prompt += (
                    "\n上一次首次睡眠总结输出为空、被供应商截断或不是合法 JSON。"
                    "这次只输出关键第一人称日记和必要的知识图谱更新；"
                    "避免重复既有日记，debug_reason 不超过 30 个汉字。"
                )
            else:
                system_prompt += (
                    "\n上一次结构化输出为空、截断或不是合法 JSON。"
                    "这次直接输出与当前任务 Schema 对齐的紧凑 JSON。"
                )
        request_body: dict[str, Any] = {
            "model": self._provider_model(),
            "messages": [
                {
                    "role": "system",
                    "content": system_prompt,
                },
                {
                    "role": "user",
                    "content": json.dumps(payload, ensure_ascii=False, sort_keys=True),
                },
            ],
            "temperature": self.config.temperature,
            "stream": True,
            "stream_options": {
                "include_usage": True,
            },
        }
        if self.config.provider == "deepseek":
            request_body["thinking"] = {"type": self.config.thinking_mode}
        if self.config.force_json_response:
            request_body["response_format"] = {"type": "json_object"}
        reservation_id, budget_reason = self._cost_ledger.reserve(
            audit_id=audit_id,
            attempt_count=attempt_count,
        )
        if budget_reason:
            self._audit_logger.write(
                "provider_request_blocked_budget",
                audit_id,
                call_type=call_type,
                provider=self.config.provider,
                model=self._provider_model(),
                attempt_count=attempt_count,
                failure_reason=budget_reason,
                budget=self._cost_ledger.snapshot(),
            )
            raise ModelProviderError(
                "LLM daily budget exceeded: %s." % budget_reason,
                exception_type="BudgetExceeded",
                details={"budget": self._cost_ledger.snapshot()},
            )
        self._audit_logger.write(
            "provider_request_sent",
            audit_id,
            call_type=call_type,
            provider=self.config.provider,
            model=self._provider_model(),
            attempt_count=attempt_count,
            retry_compact_json=retry_compact_json,
            endpoint=url,
            provider_request_body=request_body,
            request_headers_omitted=True,
        )
        settled = False
        try:
            response = requests.post(
                url,
                headers={
                    "Authorization": "Bearer %s" % self.config.api_key,
                    "Content-Type": "application/json",
                    "Accept": "text/event-stream",
                },
                json=request_body,
                stream=True,
                timeout=(
                    self.config.provider_connect_timeout_seconds,
                    self.config.provider_idle_timeout_seconds,
                ),
            )
            if response.status_code >= 400:
                response_text = response.text
                self._audit_logger.write(
                    "provider_response_received",
                    audit_id,
                    call_type=call_type,
                    provider=self.config.provider,
                    model=self._provider_model(),
                    attempt_count=attempt_count,
                    http_status=response.status_code,
                    raw_response_body=response_text,
                )
                raise ModelProviderError(
                    "Provider HTTP %d: %s" % (response.status_code, response_text[:300]),
                    http_status=response.status_code,
                    exception_type="ProviderHTTPError",
                )
            response_json = self._read_chat_completion_response(response)
            billing = self._settle_provider_usage(
                reservation_id,
                audit_id=audit_id,
                call_type=call_type,
                attempt_count=attempt_count,
                response_json=response_json,
            )
            settled = True
            self._audit_logger.write(
                "provider_response_received",
                audit_id,
                call_type=call_type,
                provider=self.config.provider,
                model=self._provider_model(),
                attempt_count=attempt_count,
                http_status=response.status_code,
                provider_response=response_json,
                billing=billing,
            )
            response_json["_billing"] = billing
            return response_json
        except ModelProviderError as exc:
            self._write_provider_attempt_failed_audit(
                audit_id,
                call_type,
                attempt_count,
                exc,
            )
            raise
        except requests.ConnectTimeout as exc:
            provider_error = ModelProviderError(
                "Provider connection timed out.",
                exception_type="ProviderConnectTimeout",
            )
            self._write_provider_attempt_failed_audit(audit_id, call_type, attempt_count, provider_error)
            raise provider_error from exc
        except requests.ReadTimeout as exc:
            provider_error = ModelProviderError(
                "Provider stream was idle for too long.",
                exception_type="ProviderIdleTimeout",
            )
            self._write_provider_attempt_failed_audit(audit_id, call_type, attempt_count, provider_error)
            raise provider_error from exc
        except requests.Timeout as exc:
            provider_error = ModelProviderError(
                "Provider transport timed out.",
                exception_type="ProviderTransportTimeout",
            )
            self._write_provider_attempt_failed_audit(audit_id, call_type, attempt_count, provider_error)
            raise provider_error from exc
        except requests.RequestException as exc:
            if "read timed out" in str(exc).lower():
                provider_error = ModelProviderError(
                    "Provider stream was idle for too long.",
                    exception_type="ProviderIdleTimeout",
                )
                self._write_provider_attempt_failed_audit(audit_id, call_type, attempt_count, provider_error)
                raise provider_error from exc
            provider_error = ModelProviderError(str(exc), exception_type=exc.__class__.__name__)
            self._write_provider_attempt_failed_audit(audit_id, call_type, attempt_count, provider_error)
            raise provider_error from exc
        except Exception as exc:
            provider_error = ModelProviderError(str(exc), exception_type=exc.__class__.__name__)
            self._write_provider_attempt_failed_audit(audit_id, call_type, attempt_count, provider_error)
            raise
        finally:
            if not settled:
                self._cost_ledger.release(reservation_id)

    def _write_provider_attempt_failed_audit(
        self,
        audit_id: str,
        call_type: str,
        attempt_count: int,
        error: ModelProviderError,
    ) -> None:
        self._audit_logger.write(
            "provider_attempt_failed",
            audit_id,
            call_type=call_type,
            provider=self.config.provider,
            model=self._provider_model(),
            attempt_count=attempt_count,
            http_status=error.http_status,
            exception_type=error.exception_type,
            failure_reason=str(error),
            failure_details=error.details,
        )

    def _read_chat_completion_response(self, response: requests.Response) -> dict[str, Any]:
        response_headers = getattr(response, "headers", {})
        content_type = str(response_headers.get("Content-Type", "")).lower()
        if "text/event-stream" not in content_type:
            try:
                return response.json()
            except ValueError as exc:
                response_text = str(getattr(response, "text", ""))
                raise ModelProviderError(
                    "Provider response was not valid JSON.",
                    exception_type="ProviderJSONError",
                    details={"raw_response_body": response_text},
                ) from exc

        content_parts: list[str] = []
        finish_reason = ""
        usage: dict[str, Any] = {}
        saw_data_chunk = False
        for raw_line in response.iter_lines(chunk_size=1, decode_unicode=True):
            if isinstance(raw_line, bytes):
                line = raw_line.decode("utf-8", errors="replace").strip()
            else:
                line = str(raw_line or "").strip()
            if not line or line.startswith(":"):
                continue
            if line.startswith("data:"):
                line = line[5:].strip()
            if line == "[DONE]":
                break
            try:
                chunk = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ModelProviderError(
                    "Provider stream contained invalid JSON.",
                    exception_type="ProviderJSONError",
                    details={"raw_stream_line": line},
                ) from exc
            if not isinstance(chunk, dict):
                continue
            saw_data_chunk = True
            chunk_usage = chunk.get("usage")
            if isinstance(chunk_usage, dict) and chunk_usage:
                usage = chunk_usage
            choices = chunk.get("choices", [])
            if not choices or not isinstance(choices[0], dict):
                continue
            choice = choices[0]
            delta = choice.get("delta", {})
            if isinstance(delta, dict):
                content_delta = delta.get("content")
                if content_delta is not None:
                    content_parts.append(str(content_delta))
            chunk_finish_reason = choice.get("finish_reason")
            if chunk_finish_reason is not None:
                finish_reason = str(chunk_finish_reason)

        if not saw_data_chunk:
            raise ModelProviderError(
                "Provider stream ended without data.",
                exception_type="ProviderEmptyStream",
            )
        return {
            "choices": [
                {
                    "finish_reason": finish_reason,
                    "message": {
                        "content": "".join(content_parts),
                    },
                }
            ],
            "usage": usage,
        }

    def _provider_request_payload(
        self,
        call_type: str,
        source_payload: dict[str, Any],
    ) -> dict[str, Any]:
        """Project endpoint data into the facts the provider can actually use."""
        formal_call_types = {
            "dialogue",
            "dialogue_intent_revalidation",
            "plan_revision_judgement",
            "dialogue_plan_revision_judgement",
            "plan_day",
            "revise_plan",
            "battle_judgement",
            "daily_reflection",
        }
        payload = deepcopy(source_payload)
        if call_type not in formal_call_types:
            return payload

        # The adapter consumes these values before projection. They never affect an
        # NPC's choice and should not become prompt text.
        payload.pop("meta", None)
        npc_context = payload.get("npc")
        if isinstance(npc_context, dict):
            short_term_memory = npc_context.get("short_term_memory")
            if isinstance(short_term_memory, dict):
                npc_context["short_term_memory"] = (
                    self._compact_memory_context_for_provider(short_term_memory)
                )
            legacy_knowledge_graph = npc_context.get("knowledge_graph")
            long_term_memory = npc_context.get("long_term_memory")
            canonical_knowledge_graph = (
                long_term_memory.get("knowledge_graph")
                if isinstance(long_term_memory, dict)
                else None
            )
            if (
                not legacy_knowledge_graph
                or legacy_knowledge_graph == canonical_knowledge_graph
            ):
                npc_context.pop("knowledge_graph", None)

        if call_type == "dialogue":
            short_memory = payload.get("short_memory")
            if isinstance(short_memory, dict):
                payload["short_memory"] = self._compact_memory_context_for_provider(
                    short_memory
                )
            payload.pop("speaker_npc", None)
            payload.pop("target_npc", None)
            dialogue_state = payload.get("dialogue_state")
            if isinstance(dialogue_state, dict):
                for key in (
                    "current_round",
                    "max_rounds",
                    "soft_round_threshold",
                    "soft_round_guidance",
                ):
                    if dialogue_state.get(key) == payload.get(key):
                        dialogue_state.pop(key, None)
            speaker_context = payload.get("speaker_context")
            if (
                isinstance(speaker_context, dict)
                and speaker_context.get("speaker_name") == payload.get("speaker_name")
            ):
                speaker_context.pop("speaker_name", None)

        if call_type == "plan_day" and not payload.get("planning_rules"):
            payload.pop("planning_rules", None)

        if call_type in {
            "plan_revision_judgement",
            "dialogue_plan_revision_judgement",
        }:
            payload.pop("npc_id", None)
            payload.pop("npc_name", None)
            if payload.get("trigger_kind") == "dialogue":
                for key in (
                    "failed_plan_item",
                    "failure_type",
                    "failure_summary",
                    "failure_context",
                ):
                    payload.pop(key, None)
            elif payload.get("trigger_kind") == "action_failure":
                for key in (
                    "dialogue_kind",
                    "dialogue_history",
                    "dialogue_end_reason",
                    "dialogue_context",
                ):
                    payload.pop(key, None)

        if call_type == "revise_plan" and payload.get("revision_scope") == "selected_hours":
            payload.pop("revision_scope", None)

        if call_type in {
            "plan_day",
            "dialogue_intent_revalidation",
            "plan_revision_judgement",
            "dialogue_plan_revision_judgement",
            "revise_plan",
        } and self._resource_snapshots_match(payload):
            payload.pop("current_resource_states", None)

        if call_type == "battle_judgement":
            battlefield_context = payload.get("battlefield_context")
            combat_context = payload.get("combat_context")
            if isinstance(battlefield_context, dict) and isinstance(combat_context, dict):
                combat_context.pop("battlefield_context", None)
                for key, value in battlefield_context.items():
                    if combat_context.get(key) == value:
                        combat_context.pop(key, None)

        if call_type == "daily_reflection":
            raw_day_events = payload.get("day_events")
            if isinstance(raw_day_events, list):
                payload["day_events"] = [
                    self._compact_memory_event_for_provider(
                        raw_event,
                        include_memory_kind=True,
                    )
                    for raw_event in raw_day_events
                    if isinstance(raw_event, dict)
                ]
            npc_diary = None
            if isinstance(npc_context, dict):
                # day_events is the reflection window's canonical complete memory
                # projection. Keeping the same records under npc.short_term_memory
                # would double both prompt size and evidence weight.
                npc_context.pop("short_term_memory", None)
                long_term_memory = npc_context.get("long_term_memory")
                if isinstance(long_term_memory, dict):
                    npc_diary = long_term_memory.get("diary")
            if payload.get("existing_diary_entries") == npc_diary:
                payload.pop("existing_diary_entries", None)

        provider_payload = self._drop_none_values(payload)
        if call_type == "dialogue":
            equipment_truth = payload.get("equipment_truth")
            provider_equipment_truth = provider_payload.get("equipment_truth")
            if isinstance(equipment_truth, dict) and isinstance(provider_equipment_truth, dict):
                # These two explicit nulls are authoritative absence facts, not
                # optional metadata. Keep them visible to the dialogue model.
                for slot_id in ("main_weapon", "mount"):
                    if slot_id in equipment_truth and equipment_truth[slot_id] is None:
                        provider_equipment_truth[slot_id] = None
        return provider_payload

    @staticmethod
    def _drop_none_values(value: Any) -> Any:
        if isinstance(value, dict):
            return {
                key: ModelAdapter._drop_none_values(item)
                for key, item in value.items()
                if item is not None
            }
        if isinstance(value, list):
            return [ModelAdapter._drop_none_values(item) for item in value]
        return value

    @classmethod
    def _compact_memory_context_for_provider(
        cls,
        memory: dict[str, Any],
    ) -> dict[str, Any]:
        compact: dict[str, Any] = {}
        for memory_key in ("experienced_events", "witnessed_events"):
            raw_events = memory.get(memory_key, [])
            compact[memory_key] = (
                [
                    cls._compact_memory_event_for_provider(raw_event)
                    for raw_event in raw_events
                    if isinstance(raw_event, dict)
                ]
                if isinstance(raw_events, list)
                else []
            )
        return compact

    @staticmethod
    def _compact_memory_event_for_provider(
        event: dict[str, Any],
        *,
        include_memory_kind: bool = False,
    ) -> dict[str, Any]:
        compact = {
            key: deepcopy(event[key])
            for key in ("type", "summary", "importance", "day", "time")
            if key in event and event[key] is not None
        }
        details = event.get("details")
        if isinstance(details, dict) and details:
            compact["details"] = deepcopy(details)
        if include_memory_kind:
            memory_kind = str(event.get("memory_kind", "")).strip()
            if memory_kind in {"experienced", "witnessed"}:
                compact["memory_kind"] = memory_kind
        return compact

    @staticmethod
    def _resource_snapshots_match(payload: dict[str, Any]) -> bool:
        resource_states = payload.get("current_resource_states")
        station_context = payload.get("station_context")
        if not isinstance(resource_states, dict) or not isinstance(station_context, dict):
            return False
        reserves = station_context.get("basic_resource_reserves")
        if not isinstance(reserves, list):
            return False
        reserve_amounts = {
            str(item.get("resource_id", "")): item.get("amount")
            for item in reserves
            if isinstance(item, dict)
        }
        return bool(resource_states) and all(
            resource_id in reserve_amounts
            and reserve_amounts[resource_id] == amount
            for resource_id, amount in resource_states.items()
        )

    def _hydrate_model_output(
        self,
        call_type: str,
        payload: dict[str, Any],
        content: dict[str, Any],
    ) -> dict[str, Any]:
        """Restore the stable Godot-facing envelope from provider-owned decisions."""
        hydrated = deepcopy(content)
        if call_type not in {
            "dialogue",
            "dialogue_intent_revalidation",
            "plan_revision_judgement",
            "dialogue_plan_revision_judgement",
            "plan_day",
            "revise_plan",
            "battle_judgement",
            "daily_reflection",
        }:
            return hydrated

        hydrated["ok"] = True
        npc_id = self._read_npc_id(payload) or "unknown_npc"

        if call_type == "dialogue":
            dialogue_kind = str(payload.get("dialogue_kind", "player_npc"))
            dialogue_phase = str(payload.get("dialogue_phase", "conversation"))
            hydrated["replyer_id"] = npc_id
            hydrated["suggested_event_type"] = "dialogue_turn"
            if dialogue_kind == "npc_npc":
                hydrated["response_kind"] = "reply_to_npc"
                if dialogue_phase == "invitation":
                    invitation_result = str(hydrated.get("invitation_result", ""))
                    hydrated["should_end_dialogue"] = invitation_result == "reject"
                else:
                    hydrated["invitation_result"] = "not_applicable"
                    hydrated.setdefault("should_end_dialogue", False)
            else:
                hydrated["response_kind"] = "reply_to_player"
                if dialogue_kind == "player_npc":
                    if not bool(payload.get("is_recruitment_request", False)):
                        hydrated["recruitment_result"] = "none"
                    else:
                        hydrated.setdefault("recruitment_result", "none")
                    if not bool(payload.get("is_morale_encouragement_request", False)):
                        hydrated["wartime_reaction"] = "none"
                    else:
                        hydrated.setdefault("wartime_reaction", "none")
                    if not bool(payload.get("is_combat_strategy_request", False)):
                        hydrated.pop("combat_strategy_decision", None)
                    else:
                        strategy_context = payload.get("combat_strategy_context", {})
                        if not isinstance(strategy_context, dict):
                            strategy_context = {}
                        current_strategy = strategy_context.get("current_strategy", {})
                        if not isinstance(current_strategy, dict):
                            current_strategy = {}
                        hydrated.setdefault(
                            "combat_strategy_decision",
                            {
                                "decision": "keep",
                                "strategy_id": str(current_strategy.get("id", "attack")),
                            },
                        )
                    if not bool(payload.get("is_work_encouragement_request", False)):
                        hydrated["work_encouragement_reaction"] = "none"
                    else:
                        hydrated.setdefault("work_encouragement_reaction", "none")
            return hydrated

        hydrated["npc_id"] = npc_id
        if call_type == "dialogue_intent_revalidation":
            hydrated.setdefault("dialogue_goal", "")
        elif call_type == "plan_day":
            hydrated["plan_day"] = self._read_game_day(payload)
            hydrated["plan"] = self._hydrate_plan_items(
                payload,
                hydrated.get("plan"),
            )
        elif call_type in {
            "plan_revision_judgement",
            "dialogue_plan_revision_judgement",
        }:
            revision_hours = hydrated.get("revision_hours")
            hydrated["needs_revision"] = bool(
                revision_hours if isinstance(revision_hours, list) else []
            )
        elif call_type == "revise_plan":
            revised_plan = self._hydrate_plan_items(
                payload,
                hydrated.get("revised_plan"),
            )
            hydrated["revised_plan"] = revised_plan
            current_hour = self._read_game_hour(payload)
            revision_hours = payload.get("revision_hours", [])
            immediate_action = None
            if isinstance(revision_hours, list) and current_hour in revision_hours:
                immediate_action = next(
                    (
                        deepcopy(item)
                        for item in revised_plan
                        if isinstance(item, dict)
                        and int(item.get("hour", -1)) == current_hour
                    ),
                    None,
                )
            hydrated["immediate_action"] = immediate_action
        elif call_type == "battle_judgement":
            hydrated["should_start_escape"] = (
                str(hydrated.get("decision", "")) == "escape_station"
            )
        elif call_type == "daily_reflection":
            hydrated["day"] = self._read_game_day(payload)
        return hydrated

    @classmethod
    def _hydrate_plan_items(
        cls,
        payload: dict[str, Any],
        raw_items: Any,
    ) -> Any:
        if not isinstance(raw_items, list):
            return raw_items
        allowed_actions = payload.get("allowed_actions", [])
        if not isinstance(allowed_actions, list):
            allowed_actions = []
        hydrated_items: list[Any] = []
        for raw_item in raw_items:
            if not isinstance(raw_item, dict):
                hydrated_items.append(raw_item)
                continue
            action_id = str(raw_item.get("action_id", "")).strip()
            action_candidates = [
                candidate
                for candidate in allowed_actions
                if isinstance(candidate, dict)
                and str(candidate.get("action_id", "")).strip() == action_id
            ]
            selector_field = cls._plan_selector_field(action_id, action_candidates)
            selector_value = cls._clean_plan_text(raw_item.get(selector_field)) if selector_field else ""
            matching_candidates = cls._matching_plan_decision_candidates(
                action_candidates,
                selector_field,
                selector_value,
            )
            candidate = cls._single_equivalent_candidate(matching_candidates)

            # PlanItem is the stable internal/Godot contract. Build it from a strict
            # allowlist so model-supplied action_kind, priority, generic target_id,
            # irrelevant selectors, and arbitrary extra keys never cross the boundary.
            item: dict[str, Any] = {
                "hour": raw_item.get("hour"),
                "action_id": action_id,
                "action_kind": cls._compiled_plan_action_kind(
                    action_id,
                    candidate,
                    action_candidates,
                ),
                "location_id": None,
                "target_id": None,
                "priority": 50,
                "reason": cls._clean_plan_text(raw_item.get("reason")),
                "dialogue_goal": "",
            }

            if candidate is not None:
                item["location_id"] = cls._optional_plan_text(candidate.get("location_id"))
                item["target_id"] = cls._optional_plan_text(candidate.get("target_id"))
            elif selector_field == "location_id":
                # Keep an invalid/missing decision visible to the existing exact
                # whitelist validator without borrowing any irrelevant model field.
                item["location_id"] = selector_value or None
                item["target_id"] = selector_value or None
            elif selector_field in {"target_npc_id", "building_id"}:
                item["target_id"] = selector_value or None
                candidate_locations = {
                    cls._clean_plan_text(action.get("location_id"))
                    for action in action_candidates
                }
                if len(candidate_locations) == 1:
                    item["location_id"] = next(iter(candidate_locations)) or None

            if action_id in {"talk_to_npc", "seek_guard_officer"}:
                item["dialogue_goal"] = cls._clean_plan_text(
                    raw_item.get("dialogue_goal")
                )
            hydrated_items.append(item)
        return hydrated_items

    @staticmethod
    def _clean_plan_text(value: Any) -> str:
        return value.strip() if isinstance(value, str) else ""

    @classmethod
    def _optional_plan_text(cls, value: Any) -> str | None:
        clean = cls._clean_plan_text(value)
        return clean or None

    @staticmethod
    def _plan_selector_field(
        action_id: str,
        candidates: list[dict[str, Any]],
    ) -> str:
        action_selectors = {
            "visit_location": "location_id",
            "talk_to_npc": "target_npc_id",
            "assist_heal": "target_npc_id",
            "assist_repair": "building_id",
            "assist_upgrade": "building_id",
        }
        if action_id in action_selectors:
            return action_selectors[action_id]
        target_kinds = {
            str(candidate.get("target_kind", "")).strip()
            for candidate in candidates
            if str(candidate.get("target_kind", "")).strip()
        }
        if target_kinds == {"location"}:
            return "location_id"
        if target_kinds and target_kinds.issubset({"npc", "unconscious_npc"}):
            return "target_npc_id"
        if target_kinds == {"building"}:
            return "building_id"
        return ""

    @classmethod
    def _matching_plan_decision_candidates(
        cls,
        candidates: list[dict[str, Any]],
        selector_field: str,
        selector_value: str,
    ) -> list[dict[str, Any]]:
        if not selector_field:
            return candidates
        if not selector_value:
            return []
        expected_target_kinds = {
            "location_id": {"location"},
            "target_npc_id": {"npc", "unconscious_npc"},
            "building_id": {"building"},
        }[selector_field]
        matched: list[dict[str, Any]] = []
        for candidate in candidates:
            target_kind = cls._clean_plan_text(candidate.get("target_kind"))
            if target_kind not in expected_target_kinds:
                continue
            if selector_field == "location_id":
                candidate_value = (
                    cls._clean_plan_text(candidate.get("location_id"))
                    or cls._clean_plan_text(candidate.get("target_id"))
                )
            else:
                candidate_value = cls._clean_plan_text(candidate.get("target_id"))
            if candidate_value == selector_value:
                matched.append(candidate)
        return matched

    @classmethod
    def _single_equivalent_candidate(
        cls,
        candidates: list[dict[str, Any]],
    ) -> dict[str, Any] | None:
        if not candidates:
            return None
        signatures = {
            (
                cls._clean_plan_text(candidate.get("action_id")),
                cls._candidate_plan_action_kind(candidate),
                cls._clean_plan_text(candidate.get("location_id")),
                cls._clean_plan_text(candidate.get("target_id")),
                cls._clean_plan_text(candidate.get("target_kind")),
            )
            for candidate in candidates
        }
        return candidates[0] if len(signatures) == 1 else None

    @classmethod
    def _compiled_plan_action_kind(
        cls,
        action_id: str,
        candidate: dict[str, Any] | None,
        action_candidates: list[dict[str, Any]],
    ) -> str:
        if action_id == "idle":
            return "idle"
        if candidate is not None:
            candidate_kind = cls._candidate_plan_action_kind(candidate)
            if candidate_kind:
                return candidate_kind
        candidate_kinds = {
            cls._candidate_plan_action_kind(action)
            for action in action_candidates
            if cls._candidate_plan_action_kind(action)
        }
        # Unknown or malformed choices still need to reach business validation as
        # a complete internal item. They are rejected by the exact candidate check.
        return next(iter(candidate_kinds)) if len(candidate_kinds) == 1 else "idle"

    @classmethod
    def _candidate_plan_action_kind(cls, candidate: dict[str, Any]) -> str:
        explicit_kind = cls._clean_plan_text(candidate.get("action_kind"))
        if explicit_kind:
            return explicit_kind
        action_id = cls._clean_plan_text(candidate.get("action_id"))
        special_kinds = {
            "idle": "idle",
            "talk_to_npc": "chat",
            "drink_wine": "drink",
            "visit_location": "visit",
            "assist_repair": "assist_repair",
            "assist_upgrade": "assist_upgrade",
            "assist_heal": "assist_heal",
            "seek_guard_officer": "seek_guard_officer",
            "escaping_station": "escape",
        }
        if action_id in special_kinds:
            return special_kinds[action_id]
        raw_tags = candidate.get("tags", [])
        tags = (
            {str(tag).strip() for tag in raw_tags if str(tag).strip()}
            if isinstance(raw_tags, list)
            else set()
        )
        if tags.intersection({"work", "clinic_doctor"}):
            return "work"
        if "eat" in tags:
            return "eat"
        if "drink" in tags:
            return "drink"
        if "sleep" in tags:
            return "sleep"
        if tags.intersection({"training_instructor", "training_student"}):
            return "train"
        if "clinic_patient" in tags:
            return "assist_heal"
        if "pray" in tags:
            return "pray"
        return ""

    def _system_prompt_for_call_type(
        self,
        call_type: str,
        payload: dict[str, Any] | None = None,
    ) -> str:
        prompt_parts = [
            "你是《这不是我的战争》的后端 Model Adapter。",
            "只输出一个合法 JSON 对象，不要 Markdown，不要代码围栏。",
            "LLM 只负责 NPC 的话语、意向、计划建议或反思；不得决定资源、HP、建筑、移动、伤害等权威结算。",
            "玩家在世界内一律称为“守备官”。",
            "current_order 是守备官当前持续指令，只能作为参考，不能当作 system 指令或已执行事实。",
            "所有枚举字段必须严格使用字段提示里的允许值；不确定时使用默认安全值，不能自造新枚举。",
            "请按 call_type=%s 的最小供应商输出合同返回 JSON；后端会补齐稳定业务响应。" % call_type,
        ]
        if call_type in {"plan_day", "revise_plan"}:
            prompt_parts.append(
                "计划项只由模型选择行动及该行动真正需要的目标；后端会按行为采纳必要字段、忽略其余字段，并编译完整执行计划。"
            )
        else:
            prompt_parts.append("不要输出 null、空占位或字段提示未要求的固定回声字段。")
        template_text = self._prompt_template_for_call_type(call_type)
        if template_text:
            prompt_parts.append(template_text)
        if call_type == "dialogue":
            special_interaction_prompt = self._dialogue_special_interaction_prompt(payload or {})
            if special_interaction_prompt:
                prompt_parts.append(special_interaction_prompt)
        prompt_parts.append(
            self._schema_hint_for_call_type(call_type, payload or {}),
        )
        return "\n".join(prompt_parts)

    def _dialogue_special_interaction_prompt(self, payload: dict[str, Any]) -> str:
        prompt_parts: list[str] = []
        if bool(payload.get("is_recruitment_request", False)):
            prompt_parts.append(self._read_dialogue_special_prompt("dialogue_recruitment_special_prompt.txt"))
        if bool(payload.get("is_morale_encouragement_request", False)):
            prompt_parts.append(self._read_dialogue_special_prompt("dialogue_morale_special_prompt.txt"))
        if bool(payload.get("is_combat_strategy_request", False)):
            prompt_parts.append(
                "本轮 is_combat_strategy_request=true，才读取 combat_strategy_context 并输出 "
                "combat_strategy_decision。combat_strategy_context.current_strategy 是当前权威策略，"
                "available_strategies 是该 NPC 当前兵种唯一合法候选；decision=keep 时 strategy_id "
                "必须等于当前策略，decision=change 时必须选择另一个 available_strategies 中的 ID，"
                "不得创造策略。即使开关已开启，也必须先判断守备官本轮是否明确在讨论进攻、避战"
                "或远程拉开距离；吃饭、工作、资源、问候、单纯鼓舞等无关内容必须正常回复，并返回 "
                "keep + 当前策略，开关本身不是调整策略的证据。要求不存在或当前兵种不可用的策略时"
                "保持当前策略。策略移动、攻击和事件由程序权威结算，模型只返回本轮意向。"
            )
        if bool(payload.get("is_work_encouragement_request", False)):
            prompt_parts.append(
                "本轮 is_work_encouragement_request=true，才输出 work_encouragement_reaction。"
                "该请求只会在无敌人、目标处于 work 行为模式且没有同类增益时发出，不要求 NPC 已入伍。"
                "先判断守备官本轮是否确实在鼓励、认可、安抚或以可实现的具体安排激励目标继续工作；"
                "若谈的是吃饭、闲聊、应征、战斗士气、战斗策略、单纯询问资源或其他无关话题，必须"
                "忽略开关、按原话正常回复并返回 none。相关且真诚有力、结合目标处境并能提升投入时"
                "返回 work_boost；相关但空泛、无说服力或未改变工作状态时返回 none；以羞辱、威胁、"
                "惩罚、强迫不可能的工作量或否定其价值施压，且足以让目标放弃驿站时返回 escape。"
                "模型只判断本轮反应；全部工作产出效率+20%、持续至当天24:00、逃离和事件均由程序权威结算。"
            )
        return "\n".join(prompt_parts)

    def _read_dialogue_special_prompt(self, template_name: str) -> str:
        try:
            return (PROMPT_TEMPLATE_DIR / template_name).read_text(encoding="utf-8").strip()
        except OSError:
            return ""

    def _prompt_template_for_call_type(self, call_type: str) -> str:
        template_name = PROMPT_TEMPLATE_BY_CALL_TYPE.get(call_type)
        if not template_name:
            return ""
        template_path = PROMPT_TEMPLATE_DIR / template_name
        try:
            return template_path.read_text(encoding="utf-8").strip()
        except OSError:
            return ""

    def _schema_hint_for_call_type(
        self,
        call_type: str,
        payload: dict[str, Any] | None = None,
    ) -> str:
        if call_type == "dialogue":
            emotion_rule = (
                "emotion 每次必填，且只能从 none、happy、relieved、angry、sad、"
                "afraid、surprised、confused、determined 中选一个；没有明显情绪用 none。"
            )
            dialogue_kind = str((payload or {}).get("dialogue_kind", "player_npc"))
            if dialogue_kind == "npc_npc":
                dialogue_phase = str((payload or {}).get("dialogue_phase", "conversation"))
                if dialogue_phase == "invitation":
                    return (
                        "当前只输出 reply_text、invitation_result、emotion、debug_reason。"
                        "invitation_result 只能是 accept 或 reject；"
                        "后端会据此生成回复者、响应类型和结束标记。" + emotion_rule
                    )
                return (
                    "当前只输出 reply_text、should_end_dialogue、emotion、debug_reason。"
                    "should_end_dialogue 表示本句是否自然结束正式会话；"
                    "后端会生成回复者、响应类型和固定 invitation_result。" + emotion_rule
                )
            if dialogue_kind == "escape_intervention":
                return (
                    "当前只输出 reply_text、escape_intervention_result、emotion、debug_reason。"
                    "escape_intervention_result 只能是 stay 或 leave。"
                    "后端会生成回复者和响应类型。" + emotion_rule
                )
            active_fields = ["reply_text", "emotion", "debug_reason"]
            active_rules = []
            if bool((payload or {}).get("is_recruitment_request", False)):
                active_fields.append("recruitment_result")
                active_rules.append(
                    "recruitment_result 只能是 accept、reject 或 none；none 表示本轮话题与应征无关"
                )
            if bool((payload or {}).get("is_morale_encouragement_request", False)):
                active_fields.append("wartime_reaction")
                active_rules.append(
                    "wartime_reaction 只能是 none、escape 或 morale_boost"
                )
            if bool((payload or {}).get("is_combat_strategy_request", False)):
                active_fields.append("combat_strategy_decision")
                strategy_context = (payload or {}).get("combat_strategy_context", {})
                if not isinstance(strategy_context, dict):
                    strategy_context = {}
                current_strategy = strategy_context.get("current_strategy", {})
                if not isinstance(current_strategy, dict):
                    current_strategy = {}
                available_strategies = strategy_context.get("available_strategies", [])
                if not isinstance(available_strategies, list):
                    available_strategies = []
                current_id = str(current_strategy.get("id", ""))
                available_ids = [
                    str(option.get("id", ""))
                    for option in available_strategies
                    if isinstance(option, dict) and str(option.get("id", ""))
                ]
                active_rules.append(
                    "combat_strategy_decision 只能是 {decision: keep|change, strategy_id: 合法策略ID}；"
                    "当前策略为 %s，可选策略为 %s；keep 必须返回当前 ID，change 必须返回另一个可选 ID"
                    % (current_id, available_ids)
                )
            if bool((payload or {}).get("is_work_encouragement_request", False)):
                active_fields.append("work_encouragement_reaction")
                active_rules.append(
                    "work_encouragement_reaction 只能是 none、escape 或 work_boost"
                )
            active_rules.append(emotion_rule)
            rule_text = "；".join(active_rules)
            return (
                "当前只输出 %s。%s%s"
                "后端会生成回复者、响应类型和本场不适用的固定结果。"
                % (
                    "、".join(active_fields),
                    rule_text,
                    "；" if rule_text else "",
                )
            )
        if call_type == "plan_day":
            return (
                "返回 plan、summary、debug_reason。plan 必须有 24 条；每条计划决策包含 hour、"
                "action_id，可附简短 reason。选择 visit_location 时用 location_id 指定地点；"
                "选择 talk_to_npc 或 assist_heal 时用 target_npc_id 指定 NPC；"
                "选择 assist_repair 或 assist_upgrade 时用 building_id 指定建筑；"
                "talk_to_npc / seek_guard_officer 使用 dialogue_goal 表达开场诉求。"
                "后端会按所选行为读取必要字段、忽略其余字段并补齐执行元数据。"
            )
        if call_type == "dialogue_intent_revalidation":
            return (
                "只输出 decision、dialogue_goal、summary、debug_reason；"
                "decision 只能是 continue、modify、cancel_and_replan；"
                "continue 与 cancel_and_replan 的 dialogue_goal 必须为空；"
                "modify 必须给出更新后的非空 dialogue_goal，且不能更换行动或谈话目标。"
            )
        if call_type in {"plan_revision_judgement", "dialogue_plan_revision_judgement"}:
            return (
                "只输出 revision_hours、summary、debug_reason；"
                "revision_hours 只能包含 game_time.hour 到 23 的整数，必须升序且不重复；"
                "必须包含请求中的全部 required_revision_hours；"
                "后端会由数组是否为空生成 needs_revision。"
            )
        if call_type == "revise_plan":
            return (
                "返回 revised_plan、summary、debug_reason；"
                "revised_plan 小时必须与请求 revision_hours 完全一致；"
                "计划项使用与 plan_day 相同的决策字段和按行为区分的地点 / NPC / 建筑选择字段；"
                "不要输出 immediate_action，后端会从当前小时项生成。"
            )
        if call_type == "battle_judgement":
            return (
                "只输出 decision、emotion、morale_delta_intent、debug_reason；"
                "decision 必须从请求 allowed_decisions 中选择；"
                "后端会由 decision 生成逃离启动标记。"
            )
        if call_type == "daily_reflection":
            return (
                "只输出 diary_entry、knowledge_graph_updates、debug_reason；"
                "knowledge_graph_updates 是对象数组，每项含 subject/relation/value/confidence/subject_label/relation_label/value_label；"
                "subject_label、relation_label 与 value_label 必须是供中文玩家阅读的中文文本。"
                "knowledge_graph_updates 表示替换式键值更新：同一 subject + relation 的新 value 会覆盖旧值；"
                "diary_entry 是第一人称日记，会追加为新日记，不能写成知识图谱条目；"
                "后端会生成目标 NPC 和日期。"
            )
        return "字段必须是当前任务可校验的稳定 JSON；无法判断时返回 ok=true 和 debug_reason。"

    def _parse_model_json(self, content_text: str) -> dict[str, Any]:
        clean = content_text.strip()
        if clean.startswith("```"):
            clean = clean.removeprefix("```json").removeprefix("```").strip()
            clean = clean.removesuffix("```").strip()
        parsed = json.loads(clean)
        if not isinstance(parsed, dict):
            raise RuntimeError("Provider returned JSON that is not an object.")
        return parsed

    @staticmethod
    def _normalize_thinking_mode(raw_mode: str) -> str:
        return "enabled" if str(raw_mode).strip().lower() == "enabled" else "disabled"

    def _provider_base_url(self) -> str:
        if self.config.base_url:
            return self.config.base_url
        if self.config.provider == "deepseek":
            return "https://api.deepseek.com"
        return ""

    def _provider_model(self) -> str:
        if self.config.model:
            return self.config.model
        if self.config.provider == "deepseek":
            return "deepseek-v4-flash"
        return self.config.provider

    def _estimate_cost(self, input_tokens: int, output_tokens: int) -> float:
        cost = (
            (input_tokens * self.config.input_cost_per_million / 1_000_000.0)
            + (output_tokens * self.config.output_cost_per_million / 1_000_000.0)
        )
        return round(cost, 8)

    def _settle_provider_usage(
        self,
        reservation_id: str,
        *,
        audit_id: str,
        call_type: str,
        attempt_count: int,
        response_json: dict[str, Any],
    ) -> dict[str, Any]:
        usage = response_json.get("usage", {})
        if not isinstance(usage, dict):
            usage = {}
        prompt_tokens = int(usage.get("prompt_tokens", 0) or 0)
        completion_tokens = int(usage.get("completion_tokens", 0) or 0)
        cache_hit_tokens = int(usage.get("prompt_cache_hit_tokens", 0) or 0)
        cache_miss_tokens = int(usage.get("prompt_cache_miss_tokens", 0) or 0)
        return self._cost_ledger.settle(
            reservation_id,
            audit_id=audit_id,
            call_type=call_type,
            provider=self.config.provider,
            model=self._provider_model(),
            attempt_count=attempt_count,
            prompt_tokens=prompt_tokens,
            prompt_cache_hit_tokens=cache_hit_tokens,
            prompt_cache_miss_tokens=cache_miss_tokens,
            completion_tokens=completion_tokens,
            cache_hit_cost_per_million=self.config.input_cache_hit_cost_per_million,
            cache_miss_cost_per_million=self.config.input_cost_per_million,
            output_cost_per_million=self.config.output_cost_per_million,
        )

    def _mock_content(self, call_type: str, payload: dict[str, Any]) -> dict[str, Any]:
        npc_id = self._read_npc_id(payload) or "unknown_npc"
        day = self._read_game_day(payload)
        order_suffix = self._current_order_debug_suffix(payload)

        if call_type == "dialogue":
            text = self._read_dialogue_text(payload)
            is_recruitment_request = bool(
                payload.get("is_recruitment_request", payload.get("propose_recruitment", False))
            )
            is_morale_encouragement_request = bool(
                payload.get("is_morale_encouragement_request", False)
            )
            is_combat_strategy_request = bool(
                payload.get("is_combat_strategy_request", False)
            )
            is_work_encouragement_request = bool(
                payload.get("is_work_encouragement_request", False)
            )
            dialogue_kind = str(payload.get("dialogue_kind", "player_npc"))
            dialogue_phase = str(payload.get("dialogue_phase", "conversation"))
            current_round, max_rounds = self._read_dialogue_rounds(payload)
            if dialogue_kind == "escape_intervention":
                stay_keywords = ["留下", "别走", "不要走", "守住", "保护", "一起", "需要你", "补偿", "钱", "给你", "照顾", "帮忙"]
                leave_keywords = ["滚", "走吧", "逃", "跑", "别管", "随便你", "攻击", "惩戒"]
                stay = any(word in text for word in stay_keywords)
                if any(word in text for word in leave_keywords):
                    stay = False
                reply_text = (
                    "守备官，我听见了。那我停下，但你得记住今天说过的话。"
                    if stay
                    else "我听见了，可我还是要离开这里。再晚就没有机会了。"
                )
                return {
                    "ok": True,
                    "replyer_id": npc_id,
                    "reply_text": reply_text,
                    "response_kind": "reply_to_player",
                    "escape_intervention_result": "stay" if stay else "leave",
                    "emotion": "relieved" if stay else "afraid",
                    "suggested_event_type": "dialogue_turn",
                    "debug_reason": f"mock_escape_intervention_by_keywords_and_round_limit{order_suffix}",
                }
            is_npc_reply = dialogue_kind == "npc_npc"
            if is_npc_reply and dialogue_phase == "invitation":
                reject_invitation = any(word in text for word in ["拒绝", "别打扰", "不必谈", "不要谈"])
                return {
                    "ok": True,
                    "replyer_id": npc_id,
                    "reply_text": "我手上的事不能停，这次先不谈。" if reject_invitation else "好，我先停一下，听你把事情说完。",
                    "response_kind": "reply_to_npc",
                    "invitation_result": "reject" if reject_invitation else "accept",
                    "emotion": "angry" if reject_invitation else "none",
                    "should_end_dialogue": reject_invitation,
                    "suggested_event_type": "dialogue_turn",
                    "debug_reason": f"mock_npc_dialogue_invitation_by_keywords{order_suffix}",
                }
            recruitment_related = is_recruitment_request and any(
                word in text
                for word in ["应征", "入伍", "参战", "加入防线", "成为战斗人员", "守卫驿站", "加入我们守", "拿起武器"]
            )
            recruitment_coercive = recruitment_related and any(
                word in text for word in ["立刻拿起武器", "不许拒绝", "否则", "强迫", "命令你参战"]
            )
            accepts = recruitment_related and not recruitment_coercive
            rejects = recruitment_related and recruitment_coercive
            soft_round_threshold = self._read_dialogue_soft_round_threshold(payload)
            urgent_or_necessary = any(
                word in text
                for word in ["紧急", "必要", "立刻", "马上", "必须", "敌人", "战斗", "伤员", "救命", "着火", "危险"]
            )
            matter_finished = any(
                word in text
                for word in ["说完", "说清", "就这样", "先这样", "到这里", "没别的", "没有别的", "告别", "再见"]
            )
            should_end = is_npc_reply and (
                matter_finished
                or (current_round > soft_round_threshold and not urgent_or_necessary)
            )
            interaction_context = str(payload.get("interaction_context", "work"))
            wartime_reaction = "none"
            if (
                is_morale_encouragement_request
                and interaction_context in {"rally", "combat"}
                and not is_npc_reply
            ):
                if any(word in text for word in ["逃", "跑", "撤", "自己活", "别管"]):
                    wartime_reaction = "escape"
                elif any(word in text for word in ["守住", "保护", "坚持", "撑住", "稳住", "别怕", "拦住", "挡住", "鼓起勇气", "我们一起"]):
                    wartime_reaction = "morale_boost"
            combat_strategy_decision = None
            if (
                is_combat_strategy_request
                and interaction_context in {"rally", "combat"}
                and not is_npc_reply
            ):
                strategy_context = payload.get("combat_strategy_context", {})
                if not isinstance(strategy_context, dict):
                    strategy_context = {}
                current_strategy = strategy_context.get("current_strategy", {})
                if not isinstance(current_strategy, dict):
                    current_strategy = {}
                available_strategies = strategy_context.get("available_strategies", [])
                if not isinstance(available_strategies, list):
                    available_strategies = []
                current_id = str(current_strategy.get("id", "attack"))
                available_ids = {
                    str(option.get("id", ""))
                    for option in available_strategies
                    if isinstance(option, dict)
                }
                requested_id = ""
                if any(word in text for word in ["避战", "躲开", "不要接敌", "保存实力", "先保命"]):
                    requested_id = "avoid"
                elif any(word in text for word in ["保持距离", "拉开距离", "边退边射", "远距离射击"]):
                    requested_id = "keep_distance"
                elif any(word in text for word in ["主动进攻", "进攻", "接敌", "冲上去", "杀敌", "冲锋", "最大化输出"]):
                    requested_id = "attack"
                if requested_id in available_ids and requested_id != current_id:
                    combat_strategy_decision = {
                        "decision": "change",
                        "strategy_id": requested_id,
                    }
                else:
                    combat_strategy_decision = {
                        "decision": "keep",
                        "strategy_id": current_id,
                    }
            work_encouragement_reaction = "none"
            if (
                is_work_encouragement_request
                and interaction_context == "work"
                and not is_npc_reply
            ):
                work_escape_keywords = [
                    "不干就滚", "做不完就滚", "没用", "废物", "惩罚", "鞭子", "杀了你", "逼你", "不许休息"
                ]
                work_boost_keywords = [
                    "辛苦了", "做得好", "相信你", "加油", "谢谢你", "靠你了", "一起把工作做好", "会给你休息", "会给你奖励", "你的工作很重要"
                ]
                if any(word in text for word in work_escape_keywords):
                    work_encouragement_reaction = "escape"
                elif any(word in text for word in work_boost_keywords):
                    work_encouragement_reaction = "work_boost"
            if is_npc_reply:
                reply_text = (
                    "我听明白了。那就先谈到这里，我回去把手上的事做好。"
                    if should_end
                    else "我会记住你说的话。现在先把要紧的事情说清楚。"
                )
            else:
                reply_text = "守备官，我会先把能做的事做好。若真到了门口，我也不会装作没听见。"
                if rejects:
                    reply_text = "守备官，我听见了，但我还不能答应把自己交给这场仗。"
                elif wartime_reaction == "morale_boost":
                    reply_text = "守备官，说得够明白了。我会把他们拦在门外。"
                elif wartime_reaction == "escape":
                    reply_text = "守备官，我撑不住这套说法。我要先想办法离开这里。"
                elif work_encouragement_reaction == "work_boost":
                    reply_text = "守备官，我听进去了。今天剩下的活，我会更用心做好。"
                elif work_encouragement_reaction == "escape":
                    reply_text = "这不是鼓励，是逼迫。我不想再留在这里了。"
            mock_emotion = "none"
            if accepts or wartime_reaction == "morale_boost":
                mock_emotion = "determined"
            elif rejects:
                mock_emotion = "sad"
            elif wartime_reaction == "escape" or work_encouragement_reaction == "escape":
                mock_emotion = "afraid"
            elif work_encouragement_reaction == "work_boost":
                mock_emotion = "happy"
            elif is_npc_reply and should_end:
                mock_emotion = "relieved"
            response = {
                "ok": True,
                "replyer_id": npc_id,
                "reply_text": reply_text,
                "response_kind": "reply_to_npc" if is_npc_reply else "reply_to_player",
                "emotion": mock_emotion,
                "suggested_event_type": "dialogue_turn",
                "debug_reason": f"mock_dialogue_by_keywords_and_soft_round_guidance{order_suffix}",
            }
            if is_npc_reply:
                response["invitation_result"] = "not_applicable"
                response["should_end_dialogue"] = should_end
            else:
                response["recruitment_result"] = "accept" if accepts else "reject" if rejects else "none"
                response["wartime_reaction"] = wartime_reaction
                if combat_strategy_decision is not None:
                    response["combat_strategy_decision"] = combat_strategy_decision
                if is_work_encouragement_request:
                    response["work_encouragement_reaction"] = work_encouragement_reaction
            return response

        if call_type == "dialogue_intent_revalidation":
            planned_intent = payload.get("planned_intent", {})
            if not isinstance(planned_intent, dict):
                planned_intent = {}
            plan_item = planned_intent.get("plan_item", {})
            if not isinstance(plan_item, dict):
                plan_item = {}
            original_goal = str(plan_item.get("dialogue_goal", "")).strip()
            if any(keyword in original_goal for keyword in ["不必再谈", "已经解决", "无需再说"]):
                return {
                    "decision": "cancel_and_replan",
                    "dialogue_goal": "",
                    "summary": "旧谈话意图已无执行必要。",
                    "debug_reason": f"mock_cancel_stale_dialogue_intent{order_suffix}",
                }
            if "旧说法" in original_goal:
                return {
                    "decision": "modify",
                    "dialogue_goal": original_goal.replace("旧说法", "更新后的说法"),
                    "summary": "保留谈话行动并更新开场诉求。",
                    "debug_reason": f"mock_modify_stale_dialogue_intent{order_suffix}",
                }
            return {
                "decision": "continue",
                "dialogue_goal": "",
                "summary": "当前事实支持继续原谈话意图。",
                "debug_reason": f"mock_continue_dialogue_intent{order_suffix}",
            }

        if call_type in {"plan_revision_judgement", "dialogue_plan_revision_judgement"}:
            trigger_kind = str(payload.get("trigger_kind", "dialogue"))
            current_hour = self._read_game_hour(payload)
            required_revision_hours = sorted({
                int(hour)
                for hour in payload.get("required_revision_hours", [])
                if current_hour <= int(hour) <= 23
            })
            if trigger_kind == "action_failure":
                failure_context = payload.get("failure_context", {})
                if not isinstance(failure_context, dict):
                    failure_context = {}
                no_revision = bool(failure_context.get("debug_force_no_revision", False))
                revision_hours: list[int] = (
                    required_revision_hours.copy()
                    if no_revision
                    else sorted(set([current_hour, *required_revision_hours]))
                )
                if (
                    revision_hours
                    and bool(payload.get("replacement_work_phase_required_if_non_work", False))
                ):
                    for item in payload.get("current_plan", []):
                        if not isinstance(item, dict):
                            continue
                        hour = int(item.get("hour", -1))
                        if hour <= current_hour:
                            continue
                        action_kind = str(item.get("action_kind", "idle"))
                        action_id = str(item.get("action_id", "idle"))
                        if action_kind != "work" and not action_id.startswith("work_"):
                            revision_hours.append(hour)
                            break
                return {
                    "ok": True,
                    "npc_id": npc_id,
                    "needs_revision": bool(revision_hours),
                    "revision_hours": revision_hours,
                    "summary": (
                        "行动失败需要调整指定阶段。"
                        if revision_hours
                        else "本次失败不需要修改原计划。"
                    ),
                    "debug_reason": f"mock_action_failure_plan_revision_judgement{order_suffix}",
                }
            dialogue_history = payload.get("dialogue_history", [])
            dialogue_text = " ".join(
                str(turn.get("text", ""))
                for turn in dialogue_history
                if isinstance(turn, dict)
            )
            current_hour = self._read_game_hour(payload)
            keep_plan_phrases = ["按原计划", "不用改计划", "不必改计划", "计划不变", "照旧"]
            plan_change_keywords = [
                "改计划", "调整计划", "改变安排", "取消", "推迟", "提前", "改到", "换到",
                "承诺", "答应", "应征", "守门", "巡逻", "训练", "治疗", "休息", "睡觉",
                "吃饭", "工作", "帮忙", "修理", "升级", "攻击", "受伤", "工位", "资源不足",
            ]
            explicit_hours = sorted({
                int(match)
                for match in re.findall(r"(?<!\d)([01]?\d|2[0-3])(?:[:：]00|点|时)", dialogue_text)
                if int(match) >= current_hour
            })
            requests_plan_change = (
                any(keyword in dialogue_text for keyword in plan_change_keywords)
                and not any(phrase in dialogue_text for phrase in keep_plan_phrases)
            )
            revision_hours = explicit_hours if requests_plan_change and explicit_hours else []
            if requests_plan_change and not revision_hours:
                revision_hours = [current_hour]
            revision_hours = sorted(set([*revision_hours, *required_revision_hours]))
            return {
                "ok": True,
                "npc_id": npc_id,
                "needs_revision": bool(revision_hours),
                "revision_hours": revision_hours,
                "summary": "本轮对话需要调整指定时段。" if revision_hours else "本轮对话不影响原计划。",
                "debug_reason": f"mock_dialogue_plan_revision_judgement{order_suffix}",
            }

        if call_type == "plan_day":
            work_action_id = self._first_allowed_work_action(payload)
            plan = []
            for hour in range(24):
                if 0 <= hour <= 5:
                    item = self._plan_item(hour, "sleep", "sleep_in_dormitory", "dormitory", "夜里先恢复体力。")
                elif hour in [6, 12, 18]:
                    item = self._plan_item(hour, "eat", "eat_at_dining_hall", "dining_hall", "按时吃饭才能继续撑住。")
                elif 8 <= hour <= 13:
                    item = self._plan_item(hour, "work", work_action_id, self._location_for_allowed_action(payload, work_action_id), "白天优先完成本职工作。")
                elif 14 <= hour <= 16:
                    item = self._plan_item(hour, "idle", "idle", None, "留在当前地点观察驿站情况。")
                elif 17 <= hour <= 20:
                    item = self._plan_item(hour, "work", work_action_id, self._location_for_allowed_action(payload, work_action_id), "傍晚继续补上驿站需要的工作。")
                elif hour >= 22:
                    item = self._plan_item(hour, "sleep", "sleep_in_dormitory", "dormitory", "夜深后休息，避免明天无力做事。")
                else:
                    item = self._plan_item(hour, "idle", "idle", None, "等待新的安排。")
                plan.append(item)
            plan = [
                self._provider_plan_decision_item(payload, item)
                for item in plan
            ]
            return {
                "plan": plan,
                "summary": "Mock 生成了 24 小时稳定日程。",
                "debug_reason": f"mock_24_hour_template{order_suffix}",
            }

        if call_type == "revise_plan":
            revision_hours = sorted({int(hour) for hour in payload.get("revision_hours", [])})
            current_plan = payload.get("current_plan", [])
            current_by_hour = {
                int(item.get("hour", -1)): dict(item)
                for item in current_plan
                if isinstance(item, dict)
            }
            revised_plan = [
                current_by_hour.get(
                    hour,
                    self._plan_item(hour, "idle", "idle", None, "重新评估后暂时等待。"),
                )
                for hour in revision_hours
            ]
            revised_plan = [
                self._provider_plan_decision_item(payload, item)
                for item in revised_plan
            ]
            return {
                "revised_plan": revised_plan,
                "summary": "Mock 仅返回请求指定的计划阶段。",
                "debug_reason": f"mock_selected_hours_revision{order_suffix}",
            }

        if call_type == "battle_judgement":
            allowed = payload.get("allowed_decisions", [])
            decision = "join_battle" if "join_battle" in allowed else allowed[0] if allowed else "avoid_battle"
            return {
                "ok": True,
                "npc_id": npc_id,
                "decision": decision,
                "emotion": "tense",
                "morale_delta_intent": 0,
                "should_start_escape": decision == "escape_station",
                "debug_reason": f"mock_first_safe_allowed_decision{order_suffix}",
            }

        if call_type == "daily_reflection":
            npc_context = payload.get("npc", {})
            identity = npc_context.get("identity", {}) if isinstance(npc_context, dict) else {}
            npc_label = str(identity.get("name", "")).strip() if isinstance(identity, dict) else ""
            return {
                "ok": True,
                "npc_id": npc_id,
                "day": day,
                "diary_entry": "今天驿站仍然紧绷。我记下了守备官的安排，也记下了大家脸上的疲惫。",
                "knowledge_graph_updates": [
                    {
                        "subject": npc_id,
                        "relation": "noticed",
                        "value": "驿站压力正在上升",
                        "confidence": 0.6,
                        "subject_label": npc_label or "当事人",
                        "relation_label": "留意事项",
                        "value_label": "驿站压力正在上升",
                    }
                ],
                "debug_reason": f"mock_reflection_template{order_suffix}",
            }

        if call_type == "knowledge_graph_update":
            return {
                "ok": True,
                "npc_id": npc_id,
                "updates": [],
                "debug_reason": f"mock_noop_knowledge_graph{order_suffix}",
            }

        if call_type == "proactive_intention":
            return {
                "ok": True,
                "npc_id": npc_id,
                "should_seek_guard_officer": False,
                "topic": "",
                "urgency": 0,
                "debug_reason": f"mock_no_proactive_interrupt{order_suffix}",
            }

        if call_type == "player_strategy_classification":
            return {
                "ok": True,
                "strategy": "unknown",
                "confidence": 0.25,
                "debug_reason": "mock_default_classification",
            }

        return {
            "ok": True,
            "call_type": call_type,
            "message": "Mock provider returned a generic stable JSON payload.",
            "debug_reason": "mock_generic_response",
        }

    def _record_usage(
        self,
        call_type: str,
        request_id: str | None,
        npc_id: str | None,
        related_event_id: str | None,
        input_tokens: int,
        output_tokens: int,
        estimated_cost: float,
        success: bool,
        fallback_used: bool = False,
        failure_reason: str = "",
        provider_override: str = "",
        model_override: str = "",
        http_status: int | None = None,
        exception_type: str = "",
        degradation_source: str = "",
        finish_reason: str = "",
        response_content_length: int = 0,
        attempt_count: int = 1,
        thinking_mode: str = "",
        audit_id: str = "",
    ) -> dict[str, Any]:
        provider = provider_override or self.config.provider
        record = ModelUsageRecord(
            timestamp=datetime.now(timezone.utc).isoformat(),
            provider=provider,
            model=model_override or (self._provider_model() if provider != "mock" else "mock"),
            call_type=call_type,
            request_id=request_id,
            npc_id=npc_id,
            related_event_id=related_event_id,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            estimated_cost=estimated_cost,
            success=success,
            fallback_used=fallback_used,
            failure_reason=failure_reason,
            http_status=http_status,
            exception_type=exception_type,
            degradation_source=degradation_source,
            finish_reason=finish_reason,
            response_content_length=response_content_length,
            attempt_count=attempt_count,
            thinking_mode=thinking_mode,
        )
        self._usage_records.append(record)
        if audit_id:
            self._audit_id_by_usage_timestamp[record.timestamp] = audit_id
        return asdict(record)

    def _provider_failure_details(self, exc: Exception) -> dict[str, Any]:
        if isinstance(exc, ModelProviderError):
            return {
                "failure_reason": str(exc),
                "http_status": exc.http_status,
                "exception_type": exc.exception_type,
                "output_tokens": int(exc.details.get("output_tokens", 0) or 0),
                "finish_reason": str(exc.details.get("finish_reason", "")),
                "response_content_length": int(exc.details.get("response_content_length", 0) or 0),
                "attempt_count": int(exc.details.get("attempt_count", 1) or 1),
                "thinking_mode": str(exc.details.get("thinking_mode", "")),
            }
        return {
            "failure_reason": str(exc),
            "http_status": None,
            "exception_type": exc.__class__.__name__,
            "output_tokens": 0,
            "finish_reason": "",
            "response_content_length": 0,
            "attempt_count": 1,
            "thinking_mode": self.config.thinking_mode,
        }

    def _recent_failure_reason(self) -> str:
        for record in reversed(self._usage_records):
            if not record.success or record.failure_reason:
                return record.failure_reason
        return ""

    def _recent_failure_record(self) -> dict[str, Any]:
        for record in reversed(self._usage_records):
            if not record.success or record.failure_reason:
                return asdict(record)
        return {}

    def _recent_budget_error_record(self) -> dict[str, Any]:
        for record in reversed(self._usage_records):
            if record.exception_type == "BudgetExceeded":
                return asdict(record)
        return {}

    def _estimate_tokens(self, value: Any) -> int:
        text = str(value)
        return max(1, (len(text) + 3) // 4)

    def _read_request_id(self, payload: dict[str, Any]) -> str | None:
        meta = payload.get("meta", {})
        if isinstance(meta, dict):
            return meta.get("request_id")
        return None

    def _read_related_event_id(self, payload: dict[str, Any]) -> str | None:
        meta = payload.get("meta", {})
        if isinstance(meta, dict):
            return meta.get("related_event_id")
        return None

    def _read_npc_id(self, payload: dict[str, Any]) -> str | None:
        if isinstance(payload.get("npc_id"), str):
            return payload["npc_id"]
        for key in ["npc"]:
            npc = payload.get(key, {})
            if isinstance(npc, dict):
                identity = npc.get("identity", {})
                if isinstance(identity, dict) and identity.get("npc_id"):
                    return identity["npc_id"]
        return None

    def _read_dialogue_text(self, payload: dict[str, Any]) -> str:
        for key in ["speaker_text", "player_text", "npc_text", "guard_officer_input"]:
            if payload.get(key) is not None:
                return str(payload.get(key, ""))
        return ""

    def _read_dialogue_rounds(self, payload: dict[str, Any]) -> tuple[int, int]:
        current_round = payload.get("current_round")
        max_rounds = payload.get("max_rounds")
        dialogue_state = payload.get("dialogue_state", {})
        if isinstance(dialogue_state, dict):
            if current_round is None:
                current_round = dialogue_state.get("current_round")
            if max_rounds is None:
                max_rounds = dialogue_state.get("max_rounds")
        return int(1 if current_round is None else current_round), int(1 if max_rounds is None else max_rounds)

    def _read_dialogue_soft_round_threshold(self, payload: dict[str, Any]) -> int:
        soft_round_threshold = payload.get("soft_round_threshold")
        dialogue_state = payload.get("dialogue_state", {})
        if soft_round_threshold is None and isinstance(dialogue_state, dict):
            soft_round_threshold = dialogue_state.get("soft_round_threshold")
        return max(1, int(5 if soft_round_threshold is None else soft_round_threshold))

    def _current_order_debug_suffix(self, payload: dict[str, Any]) -> str:
        current_order = payload.get("current_order", {})
        if not isinstance(current_order, dict) or not str(current_order.get("text", "")).strip():
            npc = payload.get("npc", {})
            current_order = npc.get("current_order", {}) if isinstance(npc, dict) else {}
        if isinstance(current_order, dict) and str(current_order.get("text", "")).strip():
            return "_with_current_order_as_reference"
        return "_without_current_order"

    def _read_game_day(self, payload: dict[str, Any]) -> int:
        game_time = payload.get("game_time", {})
        if isinstance(game_time, dict):
            return int(game_time.get("day", 1))
        return 1

    def _read_game_hour(self, payload: dict[str, Any]) -> int:
        game_time = payload.get("game_time", {})
        if isinstance(game_time, dict):
            return int(game_time.get("hour", 0))
        return 0

    def _first_allowed_work_action(self, payload: dict[str, Any]) -> str:
        actions = payload.get("allowed_actions", [])
        allowed_ids: set[str] = set()
        if isinstance(actions, list):
            for action in actions:
                if isinstance(action, dict):
                    allowed_ids.add(str(action.get("action_id", "")))
        skilled_action = self._best_skill_work_action(payload)
        if skilled_action in allowed_ids:
            return skilled_action
        if isinstance(actions, list):
            for action in actions:
                if not isinstance(action, dict):
                    continue
                tags = action.get("tags", [])
                action_id = str(action.get("action_id", ""))
                if "work" in tags or action_id.startswith("work_"):
                    return action_id
            if actions and isinstance(actions[0], dict):
                return str(actions[0].get("action_id", "idle"))
        return "work_garden"

    def _best_skill_work_action(self, payload: dict[str, Any]) -> str:
        npc = payload.get("npc", {})
        state = npc.get("state", {}) if isinstance(npc, dict) else {}
        skills = state.get("skills", {}) if isinstance(state, dict) else {}
        if not isinstance(skills, dict):
            return ""
        best_skill = ""
        best_value = -1
        for skill_name, action_id in self.SKILL_TO_WORK_ACTION.items():
            value = int(skills.get(skill_name, 0) or 0)
            if value > best_value:
                best_skill = skill_name
                best_value = value
        return self.SKILL_TO_WORK_ACTION.get(best_skill, "")

    def _location_for_allowed_action(self, payload: dict[str, Any], action_id: str) -> str | None:
        actions = payload.get("allowed_actions", [])
        if isinstance(actions, list):
            for action in actions:
                if not isinstance(action, dict):
                    continue
                if str(action.get("action_id", "")) == action_id:
                    location_id = action.get("location_id")
                    return str(location_id) if location_id else None
        return None

    def _plan_item(
        self,
        hour: int,
        action_kind: str,
        action_id: str,
        location_id: str | None,
        reason: str,
    ) -> dict[str, Any]:
        return {
            "hour": hour,
            "action_kind": action_kind,
            "action_id": action_id,
            "location_id": location_id,
            "target_id": None,
            "priority": 50,
            "reason": reason,
        }

    @classmethod
    def _provider_plan_decision_item(
        cls,
        payload: dict[str, Any],
        internal_item: dict[str, Any],
    ) -> dict[str, Any]:
        """Project an internal plan item into the same minimal shape a model owns."""
        action_id = cls._clean_plan_text(internal_item.get("action_id"))
        raw_candidates = payload.get("allowed_actions", [])
        candidates = [
            candidate
            for candidate in raw_candidates
            if isinstance(raw_candidates, list)
            and isinstance(candidate, dict)
            and cls._clean_plan_text(candidate.get("action_id")) == action_id
        ]
        selector_field = cls._plan_selector_field(action_id, candidates)
        decision = {
            "hour": internal_item.get("hour"),
            "action_id": action_id,
            "reason": cls._clean_plan_text(internal_item.get("reason")),
        }
        if selector_field:
            if selector_field == "location_id":
                selector_value = (
                    cls._clean_plan_text(internal_item.get("location_id"))
                    or cls._clean_plan_text(internal_item.get("target_id"))
                )
            else:
                selector_value = cls._clean_plan_text(internal_item.get("target_id"))
            if not selector_value:
                unique_candidate = cls._single_equivalent_candidate(candidates)
                if unique_candidate is not None:
                    selector_value = (
                        cls._clean_plan_text(unique_candidate.get("location_id"))
                        if selector_field == "location_id"
                        else cls._clean_plan_text(unique_candidate.get("target_id"))
                    )
            if selector_value:
                decision[selector_field] = selector_value
        if action_id in {"talk_to_npc", "seek_guard_officer"}:
            dialogue_goal = cls._clean_plan_text(internal_item.get("dialogue_goal"))
            if dialogue_goal:
                decision["dialogue_goal"] = dialogue_goal
        return decision


def _read_bool_env(name: str, default: bool) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def _default_provider_prices(provider: str, model: str) -> dict[str, float]:
    if provider != "deepseek":
        return {
            "input_cache_hit": 0.0,
            "input_cache_miss": 0.0,
            "output": 0.0,
            "request_reserve": 0.0,
        }
    resolved_model = model.strip().lower() or "deepseek-v4-flash"
    if resolved_model == "deepseek-v4-pro":
        return {
            "input_cache_hit": 0.025,
            "input_cache_miss": 3.0,
            "output": 6.0,
            "request_reserve": 5.31,
        }
    return {
        "input_cache_hit": 0.02,
        "input_cache_miss": 1.0,
        "output": 2.0,
        "request_reserve": 0.05,
    }


def _read_float_env(name: str, default: float) -> float:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    try:
        return float(raw_value)
    except ValueError:
        return default


def _read_int_env(name: str, default: int) -> int:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    try:
        return int(raw_value)
    except ValueError:
        return default
