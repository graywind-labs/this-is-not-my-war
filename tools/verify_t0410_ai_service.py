import json
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


class FakeResponse:
    def __init__(self, status_code: int = 200, body=None) -> None:
        self.status_code = status_code
        self._body = body if body is not None else {"data": [{"id": "custom-model"}]}

    def json(self):
        return self._body


def run() -> None:
    with tempfile.TemporaryDirectory(prefix="t0410_ai_service_") as temporary_dir:
        os.environ["AI_SERVICE_CONFIG_DIR"] = temporary_dir
        os.environ["AI_SERVICE_ALLOW_PLAINTEXT_TEST_STORE"] = "true"
        os.environ["LLM_PROVIDER"] = "mock"
        os.environ.pop("LLM_API_KEY", None)

        from backend.app import create_app

        with patch("backend.services.ai_service_manager.requests.get", return_value=FakeResponse()):
            app = create_app()
            client = app.test_client()
            initial = client.get("/config/ai-service")
            assert initial.status_code == 200
            assert initial.get_json()["mode"] == "trial"

            secret = "T0410_SECRET_MUST_NEVER_LEAK"
            configured = client.put("/config/ai-service", json={
                "mode": "custom",
                "provider": "openai_compatible",
                "model": "custom-model",
                "base_url": "https://example.invalid/v1",
                "api_key": secret,
                "test_connection": True,
            })
            assert configured.status_code == 200, configured.get_data(as_text=True)
            snapshot = configured.get_json()
            assert snapshot["mode"] == "custom"
            assert snapshot["api_key_present"] is True
            assert "api_key" not in snapshot
            assert app.config["MODEL_ADAPTER"].config.api_key == secret
            assert app.config["MODEL_ADAPTER"].config.fallback_to_mock is False
            assert app.config["MODEL_ADAPTER"].config.daily_budget_max_cost_cny == 0.0

            config_text = (Path(temporary_dir) / "ai_service.json").read_text(encoding="utf-8")
            assert secret not in config_text
            assert secret not in json.dumps(client.get("/config/ai-service").get_json())

            switched_to_trial = client.put("/config/ai-service", json={"mode": "trial", "test_connection": True})
            assert switched_to_trial.status_code == 200
            switched_back = client.put("/config/ai-service", json={
                "mode": "custom",
                "provider": "openai_compatible",
                "model": "custom-model",
                "base_url": "https://example.invalid/v1",
                "api_key": "",
                "test_connection": True,
            })
            assert switched_back.status_code == 200
            assert app.config["MODEL_ADAPTER"].config.api_key == secret

            restored_app = create_app()
            restored_snapshot = restored_app.test_client().get("/config/ai-service").get_json()
            assert restored_snapshot["mode"] == "custom"
            assert restored_snapshot["api_key_present"] is True
            assert restored_app.config["MODEL_ADAPTER"].config.api_key == secret

        rate_limit_body = {"error": {"code": "insufficient_balance", "message": "Insufficient Balance"}}
        with patch("backend.services.ai_service_manager.requests.get", return_value=FakeResponse(429, rate_limit_body)):
            failed = app.test_client().post("/config/ai-service/test", json={
                "mode": "custom",
                "provider": "deepseek",
                "model": "deepseek-chat",
                "base_url": "https://api.deepseek.com",
                "api_key": "invalid-or-empty-balance",
            })
            assert failed.status_code == 429
            failure = failed.get_json()
            assert failure["error_code"] == "provider_rate_limited"
            assert "insufficient_balance" in failure["message"]

        print("T0410_AI_SERVICE_BACKEND_PASS secure_key=true restart=true route=custom http_429=true")


if __name__ == "__main__":
    run()
