import json
import os
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402


class FakeProviderResponse:
    def __init__(
        self,
        content: str = '{"ok":true,"debug_reason":"audit_success"}',
        *,
        status_code: int = 200,
        response_text: str = "",
    ) -> None:
        self.status_code = status_code
        self.headers = {"Content-Type": "application/json"}
        self.text = response_text
        self._content = content

    def json(self) -> dict:
        return {
            "choices": [
                {
                    "finish_reason": "stop",
                    "message": {"content": self._content},
                }
            ],
            "usage": {
                "prompt_tokens": 123,
                "completion_tokens": 17,
                "prompt_cache_hit_tokens": 100,
                "prompt_cache_miss_tokens": 23,
            },
        }


def make_payload(request_id: str, **extra) -> dict:
    payload = {
        "meta": {
            "request_id": request_id,
            "call_type": "dialogue",
            "related_event_id": "event_audit_01",
        },
        "npc_id": "cook_01",
        "speaker_text": "请如实回答。",
    }
    payload.update(extra)
    return payload


def read_records(path: Path) -> list[dict]:
    return [
        json.loads(line)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]


def verify_complete_real_call_and_redaction(log_path: Path) -> None:
    configured_secret = "configured-real-secret-123"
    embedded_secret = "payload-only-secret-456"
    adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key=configured_secret,
        fallback_to_mock=False,
        input_cost_per_million=1.0,
        input_cache_hit_cost_per_million=0.02,
        output_cost_per_million=2.0,
        audit_log_enabled=True,
        audit_log_path=str(log_path),
        audit_log_include_payloads=True,
    ))
    payload = make_payload(
        "audit_real_success",
        api_key=embedded_secret,
        password="password-in-payload",
        speaker_text=(
            "配置值 %s；另一个凭据 Bearer transport-secret-789；"
            "常见格式 sk-testsecret987654321。"
        ) % configured_secret,
    )
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=FakeProviderResponse(),
    ):
        result = adapter.generate("dialogue", payload)
    assert result.ok

    records = read_records(log_path)
    events = [record["event"] for record in records]
    assert events == [
        "call_started",
        "provider_request_sent",
        "provider_response_received",
        "provider_output_parsed",
        "call_completed",
    ]
    audit_ids = {record["audit_id"] for record in records}
    assert len(audit_ids) == 1
    provider_request = next(
        record for record in records if record["event"] == "provider_request_sent"
    )
    body = provider_request["provider_request_body"]
    assert body["messages"][0]["role"] == "system"
    assert "call_type=dialogue" in body["messages"][0]["content"]
    assert body["messages"][1]["role"] == "user"
    assert provider_request["request_headers_omitted"] is True
    assert "headers" not in provider_request
    provider_response = next(
        record for record in records if record["event"] == "provider_response_received"
    )
    assert provider_response["provider_response"]["usage"]["prompt_cache_hit_tokens"] == 100
    assert provider_response["billing"]["prompt_cache_miss_tokens"] == 23
    assert provider_response["billing"]["completion_tokens"] == 17
    assert provider_response["billing"]["estimated_cost_cny"] > 0.0
    provider_summary = adapter.get_usage_summary()["provider_usage"]["session"]
    assert provider_summary["input_tokens"] == 123
    assert provider_summary["output_tokens"] == 17
    log_text = log_path.read_text(encoding="utf-8")
    for secret in (
        configured_secret,
        embedded_secret,
        "password-in-payload",
        "transport-secret-789",
        "sk-testsecret987654321",
    ):
        assert secret not in log_text
    assert "[REDACTED]" in log_text
    assert adapter.get_runtime_config_snapshot()["audit_log"]["last_error"] == ""

    invalid_usage = adapter.record_model_output_invalid(
        "dialogue",
        payload,
        "DialogueResponse failed business validation.",
        result.usage,
        model_output=result.content,
        validation_details=["reply_text must not be empty"],
    )
    assert not invalid_usage["success"]
    records = read_records(log_path)
    invalid_record = records[-1]
    assert invalid_record["event"] == "business_validation_failed"
    assert invalid_record["audit_id"] in audit_ids
    assert invalid_record["validation_details"] == ["reply_text must not be empty"]


def verify_retry_and_provider_failure(log_path: Path) -> None:
    adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="retry-secret",
        fallback_to_mock=False,
        audit_log_enabled=True,
        audit_log_path=str(log_path),
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        side_effect=[
            FakeProviderResponse(content="not-json-first"),
            FakeProviderResponse(content="not-json-second"),
        ],
    ):
        result = adapter.generate("dialogue", make_payload("audit_retry_failure"))
    assert not result.ok
    assert result.usage["exception_type"] == "ModelJSONDecodeError"
    records = read_records(log_path)
    assert sum(record["event"] == "provider_request_sent" for record in records) == 2
    assert sum(record["event"] == "provider_output_rejected" for record in records) == 2
    assert records[-1]["event"] == "call_completed"
    assert records[-1]["ok"] is False
    request_events = [
        record for record in records if record["event"] == "provider_request_sent"
    ]
    assert [record["attempt_count"] for record in request_events] == [1, 2]
    assert request_events[1]["retry_compact_json"] is True

    http_log_path = log_path.with_name("http_failure.jsonl")
    http_adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="http-secret-value",
        fallback_to_mock=False,
        audit_log_enabled=True,
        audit_log_path=str(http_log_path),
    ))
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=FakeProviderResponse(
            status_code=503,
            response_text='{"authorization":"Bearer reflected-secret","message":"down"}',
        ),
    ):
        http_result = http_adapter.generate("generic", make_payload("audit_http_failure"))
    assert not http_result.ok
    http_records = read_records(http_log_path)
    failed_attempt = next(
        record for record in http_records if record["event"] == "provider_attempt_failed"
    )
    assert failed_attempt["http_status"] == 503
    assert failed_attempt["exception_type"] == "ProviderHTTPError"
    assert "reflected-secret" not in http_log_path.read_text(encoding="utf-8")


def verify_mock_concurrency_and_write_failure(log_path: Path, temp_root: Path) -> None:
    adapter = ModelAdapter(ModelAdapterConfig(
        provider="mock",
        audit_log_enabled=True,
        audit_log_path=str(log_path),
    ))

    def run_mock(index: int):
        return adapter.generate(
            "generic",
            make_payload("concurrent_%02d" % index, worker=index),
        )

    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(run_mock, range(24)))
    assert all(result.ok for result in results)
    records = read_records(log_path)
    assert len(records) == 48
    assert sum(record["event"] == "call_started" for record in records) == 24
    assert sum(record["event"] == "call_completed" for record in records) == 24
    assert len({
        record["audit_id"]
        for record in records
        if record["event"] == "call_started"
    }) == 24

    bad_path = temp_root / "path_is_a_directory"
    bad_path.mkdir()
    bad_path_adapter = ModelAdapter(ModelAdapterConfig(
        provider="mock",
        audit_log_enabled=True,
        audit_log_path=str(bad_path),
    ))
    result = bad_path_adapter.generate("generic", make_payload("write_failure"))
    assert result.ok
    snapshot = bad_path_adapter.get_runtime_config_snapshot()["audit_log"]
    assert snapshot["last_error"]


def verify_environment_defaults(log_path: Path) -> None:
    env_values = {
        "LLM_PROVIDER": "mock",
        "LLM_AUDIT_LOG_PATH": str(log_path),
    }
    with patch.dict(os.environ, env_values, clear=False):
        os.environ.pop("LLM_AUDIT_LOG_ENABLED", None)
        os.environ.pop("LLM_AUDIT_LOG_INCLUDE_PAYLOADS", None)
        adapter = ModelAdapter()
        snapshot = adapter.get_runtime_config_snapshot()["audit_log"]
        assert snapshot["enabled"] is True
        assert snapshot["include_payloads"] is True
        result = adapter.generate("generic", make_payload("env_default"))
        assert result.ok
    records = read_records(log_path)
    assert [record["event"] for record in records] == [
        "call_started",
        "call_completed",
    ]

    metadata_only_path = log_path.with_name("metadata_only.jsonl")
    metadata_only_adapter = ModelAdapter(ModelAdapterConfig(
        provider="mock",
        audit_log_enabled=True,
        audit_log_path=str(metadata_only_path),
        audit_log_include_payloads=False,
    ))
    assert metadata_only_adapter.generate(
        "generic",
        make_payload("metadata_only"),
    ).ok
    metadata_only_records = read_records(metadata_only_path)
    assert all("input_payload" not in record for record in metadata_only_records)
    assert all("model_output" not in record for record in metadata_only_records)

    disabled_path = log_path.with_name("disabled.jsonl")
    disabled_adapter = ModelAdapter(ModelAdapterConfig(
        provider="mock",
        audit_log_enabled=False,
        audit_log_path=str(disabled_path),
    ))
    assert disabled_adapter.generate("generic", make_payload("disabled")).ok
    assert not disabled_path.exists()


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="t0069_llm_audit_") as temp_dir:
        temp_root = Path(temp_dir)
        verify_complete_real_call_and_redaction(temp_root / "real_success.jsonl")
        verify_retry_and_provider_failure(temp_root / "retry_failure.jsonl")
        verify_mock_concurrency_and_write_failure(
            temp_root / "mock_concurrent.jsonl",
            temp_root,
        )
        verify_environment_defaults(temp_root / "env_default.jsonl")
    print("verify_llm_persistent_audit_log: ok")


if __name__ == "__main__":
    main()
