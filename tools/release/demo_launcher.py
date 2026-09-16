from __future__ import annotations

import argparse
import ctypes
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


SERVICE_NAME = "war-not-mine-backend"
CREATE_NO_WINDOW = 0x08000000


class DemoLauncherError(RuntimeError):
    pass


def package_root() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parents[2]


def load_manifest(root: Path) -> dict[str, Any]:
    path = root / "BUILD_MANIFEST.json"
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise DemoLauncherError("试玩包的 BUILD_MANIFEST.json 缺失或损坏。") from exc
    if not isinstance(payload, dict) or not str(payload.get("build_id", "")).strip():
        raise DemoLauncherError("试玩包构建编号缺失。")
    return payload


def _port_in_use(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.5)
        return probe.connect_ex((host, port)) == 0


def _health_payload(host: str, port: int, timeout: float = 1.0) -> dict[str, Any] | None:
    try:
        with urllib.request.urlopen(f"http://{host}:{port}/health", timeout=timeout) as response:
            body = response.read(1024 * 1024)
        payload = json.loads(body.decode("utf-8"))
        return payload if isinstance(payload, dict) else None
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, urllib.error.URLError):
        return None


def validate_health_payload(payload: dict[str, Any], manifest: dict[str, Any]) -> None:
    release = manifest.get("release_profile", {})
    model = payload.get("model_adapter", {})
    voice = payload.get("voice_model_adapter", {})
    expected = {
        "service": SERVICE_NAME,
        "app_profile": "demo",
        "build_id": str(manifest["build_id"]),
        "provider": str(release.get("llm_provider", "deepseek")),
        "model": str(release.get("llm_model", "deepseek-v4-pro")),
        "voice_provider": str(release.get("voice_provider", "qwen3_asr_flash")),
    }
    actual = {
        "service": str(payload.get("service", "")),
        "app_profile": str(payload.get("app_profile", "")),
        "build_id": str(payload.get("build_id", "")),
        "provider": str(model.get("provider", "")),
        "model": str(model.get("model", "")),
        "voice_provider": str(voice.get("provider", "")),
    }
    mismatches = [name for name, value in expected.items() if actual[name] != value]
    if model.get("fallback_to_mock") is not False:
        mismatches.append("fallback_to_mock")
    if mismatches:
        raise DemoLauncherError("后端游玩配置检查失败：" + "、".join(sorted(set(mismatches))))


def _show_error(message: str) -> None:
    if os.name == "nt":
        ctypes.windll.user32.MessageBoxW(None, message, "这不是我的战争 - 启动失败", 0x10)
    else:
        print(message, file=sys.stderr)


def _stop_process(process: subprocess.Popen[Any], timeout: float = 8.0) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5.0)


def run_demo(root: Path, health_timeout: float = 35.0, game_arguments: list[str] | None = None) -> int:
    root = root.resolve()
    manifest = load_manifest(root)
    release = manifest.get("release_profile", {})
    host = str(release.get("backend_host", "127.0.0.1"))
    port = int(release.get("backend_port", 5000))
    if host != "127.0.0.1":
        raise DemoLauncherError("试玩后端地址不是受支持的本机地址。")
    backend = root / "backend" / "ThisIsNotMyWarBackend.exe"
    game = root / "game" / "ThisIsNotMyWar.exe"
    if not backend.is_file():
        raise DemoLauncherError("试玩后端文件缺失，请重新解压完整游戏包。")
    if not game.is_file():
        raise DemoLauncherError("游戏主程序缺失，请重新解压完整游戏包。")
    if _port_in_use(host, port):
        raise DemoLauncherError(
            f"本机端口 {port} 已被其他程序占用。请关闭开发后端或其他试玩实例后重试。"
        )

    creationflags = CREATE_NO_WINDOW if os.name == "nt" else 0
    backend_process = subprocess.Popen(
        [
            str(backend),
            "--host",
            host,
            "--port",
            str(port),
            "--parent-pid",
            str(os.getpid()),
            "--build-id",
            str(manifest["build_id"]),
        ],
        cwd=backend.parent,
        creationflags=creationflags,
    )
    try:
        deadline = time.monotonic() + health_timeout
        payload = None
        while time.monotonic() < deadline:
            if backend_process.poll() is not None:
                raise DemoLauncherError("试玩后端启动失败，请查看本机游戏日志。")
            payload = _health_payload(host, port)
            if payload is not None:
                break
            time.sleep(0.25)
        if payload is None:
            raise DemoLauncherError("等待试玩后端就绪超时，请检查安全软件或本机日志。")
        validate_health_payload(payload, manifest)
        game_process = subprocess.Popen([str(game), *(game_arguments or [])], cwd=game.parent)
        return game_process.wait()
    finally:
        _stop_process(backend_process)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(add_help=not getattr(sys, "frozen", False))
    parser.add_argument("--package-root", type=Path)
    parser.add_argument("--smoke-test", action="store_true")
    args = parser.parse_args(argv)
    try:
        game_arguments = ["--headless", "--quit-after", "8"] if args.smoke_test else []
        return run_demo(args.package_root or package_root(), game_arguments=game_arguments)
    except DemoLauncherError as exc:
        _show_error(str(exc))
        return 2
    except Exception:
        _show_error("启动试玩版时发生未预期错误。请重新解压后重试。")
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
