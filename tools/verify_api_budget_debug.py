from pathlib import Path
import os
import sys
import tempfile
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = Path(__file__).resolve().parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))


from backend.app import create_app
from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig
from verify_mock_model_adapter import _FakeProviderResponse, _make_payload


def _clear_llm_budget_env() -> None:
    for name in [
        "LLM_BUDGET_MAX_CALLS",
        "LLM_BUDGET_MAX_INPUT_TOKENS",
        "LLM_BUDGET_MAX_OUTPUT_TOKENS",
        "LLM_BUDGET_MAX_TOTAL_TOKENS",
        "LLM_BUDGET_MAX_COST",
        "LLM_DAILY_BUDGET_MAX_CNY",
        "LLM_DAILY_BUDGET_TIMEZONE",
        "LLM_DAILY_BUDGET_REQUEST_RESERVE_CNY",
        "LLM_COST_LEDGER_ENABLED",
        "LLM_COST_LEDGER_PATH",
    ]:
        os.environ.pop(name, None)


def main() -> None:
    _clear_llm_budget_env()

    real_adapter = ModelAdapter(ModelAdapterConfig(
        provider="deepseek",
        api_key="test_key",
        fallback_to_mock=False,
        input_cost_per_million=0.14,
        output_cost_per_million=0.28,
        budget_max_calls=1,
    ))
    payload = _make_payload("dialogue")
    with patch("backend.services.model_adapter.requests.post", return_value=_FakeProviderResponse()):
        first_result = real_adapter.generate("dialogue", payload)
    assert first_result.ok
    assert first_result.usage["provider"] == "deepseek"
    assert first_result.usage["fallback_used"] is False

    second_result = real_adapter.generate("dialogue", payload)
    assert not second_result.ok
    assert second_result.error_code == "budget_exceeded"
    assert second_result.usage["exception_type"] == "BudgetExceeded"
    assert second_result.usage["degradation_source"] == "budget_blocked"
    assert second_result.usage["fallback_used"] is False

    usage_summary = real_adapter.get_usage_summary()
    assert usage_summary["failed"] == 1
    assert usage_summary["budget"]["enabled"] is True
    assert usage_summary["budget"]["limits"]["max_calls"] == 1
    assert usage_summary["budget"]["recent_budget_error"]["request_id"] == "verify_dialogue"

    os.environ["LLM_PROVIDER"] = "mock"
    os.environ["LLM_BUDGET_MAX_INPUT_TOKENS"] = "1"
    client = create_app().test_client()
    response = client.post("/npc/dialogue", json=payload)
    assert response.status_code == 429
    data = response.get_json()
    assert data["ok"] is False
    assert data["error_code"] == "budget_exceeded"
    assert data["fallback_used"] is False
    assert data["usage"]["exception_type"] == "BudgetExceeded"

    usage_response = client.get("/debug/llm_usage")
    assert usage_response.status_code == 200
    usage_data = usage_response.get_json()
    assert usage_data["summary"]["budget"]["enabled"] is True
    assert usage_data["summary"]["recent_failure"]["exception_type"] == "BudgetExceeded"
    assert usage_data["model_adapter"]["budget"]["limits"]["max_input_tokens"] == 1

    with tempfile.TemporaryDirectory() as temp_dir:
        ledger_path = Path(temp_dir) / "daily_cost.jsonl"
        daily_config = ModelAdapterConfig(
            provider="deepseek",
            api_key="test_key",
            fallback_to_mock=False,
            input_cost_per_million=0.14,
            input_cache_hit_cost_per_million=0.01,
            output_cost_per_million=0.28,
            daily_budget_max_cost_cny=0.00003,
            daily_budget_timezone="Asia/Shanghai",
            daily_budget_request_reserve_cny=0.00002,
            cost_ledger_enabled=True,
            cost_ledger_path=str(ledger_path),
        )
        first_process_adapter = ModelAdapter(daily_config)
        with patch("backend.services.model_adapter.requests.post", return_value=_FakeProviderResponse()):
            persisted_first = first_process_adapter.generate("dialogue", payload)
        assert persisted_first.ok
        first_snapshot = first_process_adapter.get_usage_summary()["provider_usage"]
        assert first_snapshot["session"]["attempt_count"] == 1
        assert first_snapshot["timezone"] == "Asia/Shanghai"
        assert first_snapshot["daily"]["input_tokens"] == 123
        assert first_snapshot["daily"]["output_tokens"] == 45
        assert first_snapshot["daily"]["estimated_cost_cny"] > 0.0

        restarted_adapter = ModelAdapter(daily_config)
        restarted_snapshot = restarted_adapter.get_usage_summary()["provider_usage"]
        assert restarted_snapshot["session"]["attempt_count"] == 0
        assert restarted_snapshot["daily"]["attempt_count"] == 1
        blocked_after_restart = restarted_adapter.generate("dialogue", payload)
        assert not blocked_after_restart.ok
        assert blocked_after_restart.error_code == "budget_exceeded"
        assert blocked_after_restart.usage["exception_type"] == "BudgetExceeded"
        assert ledger_path.exists()
        assert len(ledger_path.read_text(encoding="utf-8").splitlines()) == 1

        with patch.dict(os.environ, {
            "LLM_PROVIDER": "deepseek",
            "LLM_MODEL": "deepseek-v4-flash",
            "LLM_COST_LEDGER_PATH": str(Path(temp_dir) / "default_cost.jsonl"),
        }, clear=True):
            default_deepseek_adapter = ModelAdapter()
            default_snapshot = default_deepseek_adapter.get_runtime_config_snapshot()
            assert default_snapshot["pricing_cny_per_million_tokens"] == {
                "input_cache_hit": 0.02,
                "input_cache_miss": 1.0,
                "output": 2.0,
            }
            assert default_snapshot["cost_ledger"]["enabled"] is True
            assert default_snapshot["cost_ledger"]["daily_limit_cny"] == 20.0
            assert default_snapshot["cost_ledger"]["request_reserve_cny"] == 0.05
            assert default_snapshot["cost_ledger"]["timezone"] == "Asia/Shanghai"

    _clear_llm_budget_env()
    os.environ.pop("LLM_PROVIDER", None)
    print("verify_api_budget_debug: ok")


if __name__ == "__main__":
    main()
