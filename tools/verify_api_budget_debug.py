from pathlib import Path
import os
import sys
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

    _clear_llm_budget_env()
    os.environ.pop("LLM_PROVIDER", None)
    print("verify_api_budget_debug: ok")


if __name__ == "__main__":
    main()
