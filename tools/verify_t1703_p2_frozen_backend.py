from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "tools" / "release"
if str(RELEASE_ROOT) not in sys.path:
    sys.path.insert(0, str(RELEASE_ROOT))

from build_demo_backend import build_backend


def _request(url: str, method: str = "GET") -> tuple[int, dict]:
    request = urllib.request.Request(url, method=method)
    try:
        with urllib.request.urlopen(request, timeout=2.0) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8"))


def main() -> int:
    temp_root = Path(tempfile.mkdtemp(prefix="this_is_not_my_war_t1703_p2_frozen_"))
    fake_env = {
        "THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY": "test-frozen-deepseek-key-not-real",
        "DASHSCOPE_API_KEY": "test-frozen-voice-key-not-real",
        "VOICE_WORKSPACE_ID": "test-frozen-workspace",
        "VOICE_BASE_URL": "https://test-frozen-workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
        "LLM_PROVIDER_TOTAL_TIMEOUT_SECONDS": "999",
    }
    old_env = {name: os.environ.get(name) for name in fake_env}
    os.environ.update(fake_env)
    process = None
    try:
        executable = build_backend(
            ROOT,
            temp_root / "backend",
            temp_root / "work",
            "t1703-p2-frozen-test",
        )
        runtime_root = temp_root / "runtime"
        env = os.environ.copy()
        env["DEMO_RUNTIME_ROOT"] = str(runtime_root)
        process = subprocess.Popen(
            [str(executable), "--port", "5097", "--build-id", "t1703-p2-frozen-test"],
            cwd=executable.parent,
            env=env,
            creationflags=0x08000000 if os.name == "nt" else 0,
        )
        deadline = time.monotonic() + 40.0
        health = None
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise AssertionError(f"Frozen backend exited early with code {process.returncode}.")
            try:
                status, payload = _request("http://127.0.0.1:5097/health")
                if status == 200:
                    health = payload
                    break
            except (OSError, urllib.error.URLError, json.JSONDecodeError):
                pass
            time.sleep(0.25)
        assert health is not None
        assert health["app_profile"] == "demo"
        assert health["build_id"] == "t1703-p2-frozen-test"
        assert health["model_adapter"]["provider"] == "deepseek"
        assert health["model_adapter"]["fallback_to_mock"] is False
        assert health["model_adapter"]["provider_total_timeout_seconds"] == 120.0
        assert health["voice_model_adapter"]["provider"] == "qwen3_asr_flash"
        assert _request("http://127.0.0.1:5097/debug/llm_usage")[0] == 404
        assert _request("http://127.0.0.1:5097/mock/model", "POST")[0] == 404
        assert not list((temp_root / "backend").rglob("*.env"))
        assert not list((temp_root / "backend").rglob("*.py"))
        print(json.dumps({
            "ok": True,
            "task": "T1703-P2",
            "frozen_backend_size": sum(path.stat().st_size for path in (temp_root / "backend").rglob("*") if path.is_file()),
            "app_profile": health["app_profile"],
            "provider": health["model_adapter"]["provider"],
            "voice_provider": health["voice_model_adapter"]["provider"],
            "development_api_status": 404,
        }, ensure_ascii=False, indent=2))
        return 0
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        for name, value in old_env.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value
        resolved_temp = temp_root.resolve()
        system_temp = Path(tempfile.gettempdir()).resolve()
        if resolved_temp.parent == system_temp and resolved_temp.name.startswith("this_is_not_my_war_t1703_p2_frozen_"):
            shutil.rmtree(resolved_temp, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
