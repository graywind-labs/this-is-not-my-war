from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def main() -> int:
    runtime_root = Path(tempfile.mkdtemp(prefix="this_is_not_my_war_t1703_p2_"))
    test_env = {
        "APP_PROFILE": "demo",
        "DEMO_BUILD_ID": "t1703-p2-test",
        "DEMO_RUNTIME_ROOT": str(runtime_root),
        "AI_SERVICE_CONFIG_DIR": str(runtime_root / "ai_service"),
        "LLM_PROVIDER": "deepseek",
        "LLM_API_KEY": "test-demo-deepseek-key-not-real",
        "LLM_BASE_URL": "https://api.deepseek.com",
        "LLM_MODEL": "deepseek-v4-pro",
        "LLM_PROVIDER_TOTAL_TIMEOUT_SECONDS": "120",
        "LLM_FALLBACK_TO_MOCK": "false",
        "LLM_BUDGET_MAX_CALLS": "0",
        "LLM_DAILY_BUDGET_MAX_CNY": "0",
        "LLM_AUDIT_LOG_ENABLED": "false",
        "LLM_COST_LEDGER_ENABLED": "false",
        "VOICE_PROVIDER": "qwen3_asr_flash",
        "VOICE_MODEL": "qwen3-asr-flash",
        "DASHSCOPE_API_KEY": "test-demo-voice-key-not-real",
        "VOICE_WORKSPACE_ID": "test-workspace",
        "VOICE_BASE_URL": "https://test-workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
    }
    old_env = {key: os.environ.get(key) for key in test_env}
    os.environ.update(test_env)
    try:
        from backend.app import create_app

        app = create_app()
        client = app.test_client()
        health = client.get("/health")
        assert health.status_code == 200
        payload = health.get_json()
        assert payload["service"] == "war-not-mine-backend"
        assert payload["app_profile"] == "demo"
        assert payload["build_id"] == "t1703-p2-test"
        assert payload["model_adapter"]["provider"] == "deepseek"
        assert payload["model_adapter"]["model"] == "deepseek-v4-pro"
        assert payload["model_adapter"]["fallback_to_mock"] is False
        assert payload["model_adapter"]["provider_total_timeout_seconds"] == 120.0
        assert payload["voice_model_adapter"]["provider"] == "qwen3_asr_flash"
        assert client.get("/debug/llm_usage").status_code == 404
        assert client.post("/mock/model", json={"call_type": "generic", "payload": {}}).status_code == 404
        config = client.get("/config/ai-service")
        assert config.status_code == 200
        config_payload = config.get_json()
        assert config_payload["trial_provider"] == "deepseek"
        serialized_config = json.dumps(config_payload)
        assert test_env["LLM_API_KEY"] not in serialized_config
        assert test_env["DASHSCOPE_API_KEY"] not in serialized_config
        print(json.dumps({
            "ok": True,
            "task": "T1703-P2",
            "app_profile": payload["app_profile"],
            "build_id": payload["build_id"],
            "provider": payload["model_adapter"]["provider"],
            "model": payload["model_adapter"]["model"],
            "voice_provider": payload["voice_model_adapter"]["provider"],
            "development_api_status": 404,
        }, ensure_ascii=False, indent=2))
        return 0
    finally:
        for key, value in old_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    raise SystemExit(main())
