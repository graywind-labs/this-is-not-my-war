import json
import os
from pathlib import Path
import sys
from unittest.mock import patch

import requests


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402


FORMAL_CALL_TYPES = [
    "dialogue",
    "plan_revision_judgement",
    "plan_day",
    "revise_plan",
    "battle_judgement",
    "daily_reflection",
]


class _FakeResponse:
    status_code = 200
    text = ""

    def __init__(self, finish_reason: str = "stop") -> None:
        self._finish_reason = finish_reason

    def json(self) -> dict:
        return {
            "choices": [
                {
                    "finish_reason": self._finish_reason,
                    "message": {
                        "content": json.dumps(
                            {"ok": True, "debug_reason": "verify_llm_call_audit"},
                            ensure_ascii=False,
                        )
                    },
                }
            ],
            "usage": {
                "prompt_tokens": 20,
                "completion_tokens": 12,
            },
        }


class _FakeStreamingResponse:
    status_code = 200
    text = ""
    headers = {"Content-Type": "text/event-stream; charset=utf-8"}

    def iter_lines(self, chunk_size: int = 1, decode_unicode: bool = True):
        del chunk_size, decode_unicode
        content = json.dumps(
            {"ok": True, "debug_reason": "streaming_audit"},
            ensure_ascii=False,
        )
        midpoint = len(content) // 2
        chunks = [
            ": keep-alive",
            "",
            "data: " + json.dumps({
                "choices": [{
                    "delta": {"content": content[:midpoint]},
                    "finish_reason": None,
                }],
                "usage": None,
            }, ensure_ascii=False),
            "data: " + json.dumps({
                "choices": [{
                    "delta": {"content": content[midpoint:]},
                    "finish_reason": "stop",
                }],
                "usage": None,
            }, ensure_ascii=False),
            "data: " + json.dumps({
                "choices": [],
                "usage": {
                    "prompt_tokens": 20,
                    "completion_tokens": 12,
                },
            }, ensure_ascii=False),
            "data: [DONE]",
        ]
        yield from chunks


class _FakeIdleTimeoutStreamingResponse:
    status_code = 200
    text = ""
    headers = {"Content-Type": "text/event-stream; charset=utf-8"}

    def iter_lines(self, chunk_size: int = 1, decode_unicode: bool = True):
        del chunk_size, decode_unicode
        raise requests.ReadTimeout("stream idle")
        yield


def _payload(call_type: str) -> dict:
    return {
        "meta": {
            "request_id": f"verify_{call_type}",
            "call_type": call_type,
            "source": "backend_test",
            "requires_time_slowdown": True,
        },
        "npc_id": "cook_01",
    }


def main() -> None:
    for deprecated_name in [
        "LLM_MAX_TOKENS",
        "LLM_PLAN_DAY_MAX_TOKENS",
        "LLM_PLAN_REVISION_MAX_TOKENS",
        "LLM_TIMEOUT_SECONDS",
    ]:
        os.environ[deprecated_name] = "1"

    assert not {
        "max_tokens",
        "plan_day_max_tokens",
        "plan_revision_max_tokens",
        "timeout_seconds",
    }.intersection(ModelAdapterConfig.__dataclass_fields__)

    for call_type in FORMAL_CALL_TYPES:
        adapter = ModelAdapter(
            ModelAdapterConfig(
                provider="deepseek",
                api_key="test_key",
                fallback_to_mock=False,
            )
        )
        with patch(
            "backend.services.model_adapter.requests.post",
            return_value=_FakeResponse(),
        ) as fake_post:
            result = adapter.generate(call_type, _payload(call_type))
        assert result.ok, call_type
        request_body = fake_post.call_args.kwargs["json"]
        assert "max_tokens" not in request_body, call_type
        assert request_body["stream"] is True, call_type
        assert fake_post.call_args.kwargs["stream"] is True, call_type
        assert fake_post.call_args.kwargs["timeout"] == (10.0, 120.0), call_type

        retry_adapter = ModelAdapter(
            ModelAdapterConfig(
                provider="deepseek",
                api_key="test_key",
                fallback_to_mock=False,
            )
        )
        with patch(
            "backend.services.model_adapter.requests.post",
            side_effect=[_FakeResponse("length"), _FakeResponse("stop")],
        ) as retry_post:
            retry_result = retry_adapter.generate(call_type, _payload(call_type))
        assert retry_result.ok, call_type
        assert retry_post.call_count == 2, call_type
        assert retry_result.usage["attempt_count"] == 2, call_type
        for request in retry_post.call_args_list:
            assert "max_tokens" not in request.kwargs["json"], call_type
        retry_prompt = retry_post.call_args_list[1].kwargs["json"]["messages"][0]["content"]
        assert "上一次" in retry_prompt, call_type

    streaming_adapter = ModelAdapter(
        ModelAdapterConfig(
            provider="deepseek",
            api_key="test_key",
            fallback_to_mock=False,
        )
    )
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeStreamingResponse(),
    ):
        streaming_result = streaming_adapter.generate("dialogue", _payload("dialogue"))
    assert streaming_result.ok
    assert streaming_result.content["debug_reason"] == "streaming_audit"
    assert streaming_result.usage["finish_reason"] == "stop"

    idle_timeout_adapter = ModelAdapter(
        ModelAdapterConfig(
            provider="deepseek",
            api_key="test_key",
            fallback_to_mock=False,
        )
    )
    with patch(
        "backend.services.model_adapter.requests.post",
        return_value=_FakeIdleTimeoutStreamingResponse(),
    ):
        idle_timeout_result = idle_timeout_adapter.generate(
            "dialogue",
            _payload("dialogue"),
        )
    assert not idle_timeout_result.ok
    assert idle_timeout_result.usage["exception_type"] == "ProviderIdleTimeout"

    snapshot = ModelAdapter(
        ModelAdapterConfig(provider="deepseek", api_key="test_key")
    ).get_runtime_config_snapshot()
    assert snapshot["client_output_token_limit_applied"] is False
    assert snapshot["provider_streaming"] is True
    assert snapshot["provider_connect_timeout_seconds"] == 10.0
    assert snapshot["provider_idle_timeout_seconds"] == 120.0
    assert not {
        "max_tokens",
        "plan_day_max_tokens",
        "plan_revision_max_tokens",
        "timeout_seconds",
    }.intersection(snapshot)

    llm_bridge_source = (
        REPO_ROOT / "scripts" / "systems" / "LLMBridge.gd"
    ).read_text(encoding="utf-8")
    for removed_timeout_name in [
        "dialogue_request_timeout_seconds",
        "plan_request_timeout_seconds",
        "plan_revision_request_timeout_seconds",
        "battle_judgement_request_timeout_seconds",
        "daily_reflection_request_timeout_seconds",
    ]:
        assert removed_timeout_name not in llm_bridge_source
    assert "if is_zero_approx(timeout_seconds):" in llm_bridge_source
    assert "return 0" in llm_bridge_source

    backend_app_source = (REPO_ROOT / "backend" / "app.py").read_text(encoding="utf-8")
    assert "def model_success_payload" in backend_app_source
    assert backend_app_source.count("return jsonify(model_success_payload(") == 6
    assert backend_app_source.count("return jsonify(model_success_payload(response_model, result, normalizations))") == 2
    assert '"model_normalizations"' in backend_app_source

    daily_plan_source = (
        REPO_ROOT / "scripts" / "systems" / "DailyPlanSystem.gd"
    ).read_text(encoding="utf-8")
    assert "FORMAL_PLAN_MAX_CONCURRENT := 8" in daily_plan_source
    assert '"max_observed_concurrent"' in daily_plan_source

    daily_reflection_source = (
        REPO_ROOT / "scripts" / "systems" / "DailyReflectionSystem.gd"
    ).read_text(encoding="utf-8")
    assert "FIRST_SLEEP_SUMMARY_MAX_CONCURRENT := 8" in daily_reflection_source
    assert 'provider == "mock"' in daily_reflection_source
    assert 'LLM_REFLECTION_SOURCE := "llm_daily_reflection"' in daily_reflection_source
    assert 'MOCK_REFLECTION_SOURCE := "mock_daily_reflection"' in daily_reflection_source
    assert "backend_daily_reflection" not in daily_reflection_source

    godot_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (REPO_ROOT / "scripts").rglob("*.gd")
    )
    assert "mock_revision" not in godot_sources

    print("verify_llm_call_audit: ok")


if __name__ == "__main__":
    main()
