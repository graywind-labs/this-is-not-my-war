from __future__ import annotations

import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


CREATE_NO_WINDOW = 0x08000000


class ProviderConnectionError(RuntimeError):
    pass


def _port_is_available(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.5)
        return probe.connect_ex((host, port)) != 0


def _json_request(url: str, *, method: str = "GET", payload: dict[str, Any] | None = None, timeout: float = 5.0) -> tuple[int, dict[str, Any]]:
    data = None
    headers: dict[str, str] = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = int(response.status)
            body = response.read(1024 * 1024)
    except urllib.error.HTTPError as exc:
        status = int(exc.code)
        body = exc.read(1024 * 1024)
    except urllib.error.URLError as exc:
        raise ProviderConnectionError(f"Unable to reach the provider through the frozen backend: {exc.reason}") from exc
    try:
        decoded = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ProviderConnectionError(f"Backend returned non-JSON data (HTTP {status}).") from exc
    if not isinstance(decoded, dict):
        raise ProviderConnectionError(f"Backend returned an invalid JSON object (HTTP {status}).")
    return status, decoded


def validate_provider_result(status: int, payload: dict[str, Any]) -> dict[str, str]:
    if status != 200 or payload.get("ok") is not True:
        error_code = str(payload.get("error_code", "provider_connection_failed"))
        message = str(payload.get("message", "DeepSeek connection test failed."))
        raise ProviderConnectionError(f"{error_code}: {message} (HTTP {status})")
    provider = str(payload.get("provider", ""))
    model = str(payload.get("model", ""))
    if provider != "deepseek" or not model:
        raise ProviderConnectionError("The packaged backend did not test the expected DeepSeek configuration.")
    return {"provider": provider, "model": model}


def verify_frozen_backend(executable: Path, build_id: str, port: int = 5098) -> dict[str, str]:
    executable = executable.resolve()
    if not executable.is_file():
        raise ProviderConnectionError(f"Frozen backend executable is missing: {executable}")
    host = "127.0.0.1"
    if not _port_is_available(host, port):
        raise ProviderConnectionError(f"Local validation port {port} is already in use.")

    runtime_root = Path(tempfile.mkdtemp(prefix="this_is_not_my_war_provider_check_"))
    child_env = os.environ.copy()
    child_env["DEMO_RUNTIME_ROOT"] = str(runtime_root)
    creationflags = CREATE_NO_WINDOW if os.name == "nt" else 0
    process = subprocess.Popen(
        [
            str(executable),
            "--host",
            host,
            "--port",
            str(port),
            "--parent-pid",
            str(os.getpid()),
            "--build-id",
            build_id,
        ],
        cwd=executable.parent,
        env=child_env,
        creationflags=creationflags,
    )
    try:
        deadline = time.monotonic() + 35.0
        health: dict[str, Any] | None = None
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise ProviderConnectionError("Frozen backend exited before its health check became ready.")
            try:
                status, candidate = _json_request(f"http://{host}:{port}/health", timeout=1.0)
                if status == 200:
                    health = candidate
                    break
            except (OSError, ProviderConnectionError, urllib.error.URLError):
                pass
            time.sleep(0.25)
        if health is None:
            raise ProviderConnectionError("Timed out while starting the frozen backend for provider validation.")
        if health.get("app_profile") != "demo" or health.get("build_id") != build_id:
            raise ProviderConnectionError("Frozen backend health metadata does not match this demo build.")

        status, payload = _json_request(
            f"http://{host}:{port}/config/ai-service/test",
            method="POST",
            payload={},
            timeout=30.0,
        )
        result = validate_provider_result(status, payload)
        result["build_id"] = build_id
        return result
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=8.0)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5.0)
        resolved_runtime = runtime_root.resolve()
        system_temp = Path(tempfile.gettempdir()).resolve()
        if resolved_runtime.parent == system_temp and resolved_runtime.name.startswith("this_is_not_my_war_provider_check_"):
            shutil.rmtree(resolved_runtime, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the embedded DeepSeek key through the frozen demo backend.")
    parser.add_argument("--backend-executable", type=Path, required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--port", type=int, default=5098)
    args = parser.parse_args()
    try:
        result = verify_frozen_backend(args.backend_executable, args.build_id, args.port)
    except ProviderConnectionError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1
    print(json.dumps({"ok": True, **result}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
