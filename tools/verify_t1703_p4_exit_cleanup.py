from __future__ import annotations

import json
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "tools" / "release"
if str(RELEASE_ROOT) not in sys.path:
    sys.path.insert(0, str(RELEASE_ROOT))

import demo_launcher


class FakeProcess:
    def __init__(self, role: str) -> None:
        self.role = role
        self.returncode: int | None = None
        self.terminate_calls = 0
        self.kill_calls = 0
        self.wait_calls = 0

    def poll(self) -> int | None:
        return self.returncode

    def wait(self, timeout: float | None = None) -> int:
        self.wait_calls += 1
        if self.role == "game":
            self.returncode = 0
        elif self.returncode is None:
            self.returncode = 0
        return int(self.returncode)

    def terminate(self) -> None:
        self.terminate_calls += 1
        self.returncode = 0

    def kill(self) -> None:
        self.kill_calls += 1
        self.returncode = -9


def _manifest(build_id: str) -> dict[str, Any]:
    return {
        "build_id": build_id,
        "release_profile": {
            "backend_host": "127.0.0.1",
            "backend_port": 5000,
            "llm_provider": "deepseek",
            "llm_model": "deepseek-v4-pro",
            "voice_provider": "qwen3_asr_flash",
        },
    }


def _health(build_id: str) -> dict[str, Any]:
    return {
        "service": "war-not-mine-backend",
        "app_profile": "demo",
        "build_id": build_id,
        "model_adapter": {
            "provider": "deepseek",
            "model": "deepseek-v4-pro",
            "fallback_to_mock": False,
        },
        "voice_model_adapter": {"provider": "qwen3_asr_flash"},
    }


def _verify_route(root: Path, route: str) -> dict[str, Any]:
    build_id = f"t1703-p4-{route}"
    (root / "backend").mkdir(parents=True, exist_ok=True)
    (root / "game").mkdir(parents=True, exist_ok=True)
    (root / "backend" / "ThisIsNotMyWarBackend.exe").touch()
    (root / "game" / "ThisIsNotMyWar.exe").touch()
    (root / "BUILD_MANIFEST.json").write_text(
        json.dumps(_manifest(build_id), ensure_ascii=False), encoding="utf-8"
    )

    processes: list[FakeProcess] = []
    popen_arguments: list[list[str]] = []

    def fake_popen(arguments: list[str], **_kwargs: Any) -> FakeProcess:
        role = "backend" if not processes else "game"
        process = FakeProcess(role)
        processes.append(process)
        popen_arguments.append(arguments)
        return process

    original_popen = demo_launcher.subprocess.Popen
    original_port = demo_launcher._port_in_use
    original_health = demo_launcher._health_payload
    demo_launcher.subprocess.Popen = fake_popen
    demo_launcher._port_in_use = lambda _host, _port: False
    demo_launcher._health_payload = lambda _host, _port: _health(build_id)
    try:
        result = demo_launcher.run_demo(root, health_timeout=1.0)
    finally:
        demo_launcher.subprocess.Popen = original_popen
        demo_launcher._port_in_use = original_port
        demo_launcher._health_payload = original_health
    assert result == 0
    assert len(processes) == 2
    backend, game = processes
    assert game.wait_calls == 1
    assert backend.terminate_calls == 1
    assert backend.wait_calls == 1
    assert backend.kill_calls == 0
    assert "--parent-pid" in popen_arguments[0]
    return {
        "route": route,
        "game_waited": True,
        "backend_terminated": True,
        "launcher_returns": True,
    }


def main() -> int:
    temp_root = Path(tempfile.mkdtemp(prefix="this_is_not_my_war_t1703_exit_cleanup_"))
    try:
        routes = [
            _verify_route(temp_root / "window_close", "window_close"),
            _verify_route(temp_root / "main_menu_exit", "main_menu_exit"),
        ]
        launcher_source = (RELEASE_ROOT / "demo_launcher.py").read_text(encoding="utf-8")
        menu_source = (ROOT / "scripts" / "ui" / "MainMenu.gd").read_text(encoding="utf-8")
        assert "return game_process.wait()" in launcher_source
        assert "finally:\n        _stop_process(backend_process)" in launcher_source
        assert "get_tree().quit()" in menu_source
        print(json.dumps({
            "ok": True,
            "task": "T1703-P4-R1",
            "routes": routes,
            "backend_parent_watch": True,
        }, ensure_ascii=False, indent=2))
        return 0
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
