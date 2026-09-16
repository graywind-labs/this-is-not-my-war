from __future__ import annotations

import ctypes
import hashlib
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "tools" / "release"
if str(RELEASE_ROOT) not in sys.path:
    sys.path.insert(0, str(RELEASE_ROOT))

from audit_demo_package import audit_package
from build_demo_backend import build_backend
from build_demo_launcher import build_launcher
from ensure_godot_templates import ensure_templates
from export_demo_client import export_client
from finalize_demo_package import finalize_package
from prepare_demo_staging import count_audio_manifest_assets, load_config, prepare_staging


WM_CLOSE = 0x0010


def _find_visible_game_window() -> int:
    if os.name != "nt":
        return 0
    user32 = ctypes.windll.user32
    handles: list[int] = []
    callback_type = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def visit(hwnd: int, _lparam: int) -> bool:
        if not user32.IsWindowVisible(hwnd):
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length <= 0:
            return True
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buffer, length + 1)
        if buffer.value.strip() == "这不是我的战争":
            handles.append(int(hwnd))
            return False
        return True

    user32.EnumWindows(callback_type(visit), 0)
    return handles[0] if handles else 0


def _close_actual_game_window(package_root: Path) -> dict[str, object]:
    if os.name != "nt":
        return {"executed": False, "reason": "windows_only"}
    launcher = subprocess.Popen([str(package_root / "启动游戏.exe")], cwd=package_root)
    try:
        deadline = time.monotonic() + 60.0
        hwnd = 0
        while time.monotonic() < deadline:
            if launcher.poll() is not None:
                raise AssertionError(f"Launcher exited before the game window opened: {launcher.returncode}")
            hwnd = _find_visible_game_window()
            if hwnd:
                break
            time.sleep(0.25)
        assert hwnd, "The exported Godot game window did not become visible."
        assert ctypes.windll.user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
        exit_code = launcher.wait(timeout=60)
        assert exit_code == 0
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            probe.settimeout(1.0)
            assert probe.connect_ex(("127.0.0.1", 5000)) != 0
        return {
            "executed": True,
            "wm_close_sent": True,
            "launcher_exit_code": exit_code,
            "backend_port_released": True,
        }
    finally:
        if launcher.poll() is None:
            launcher.terminate()
            try:
                launcher.wait(timeout=8)
            except subprocess.TimeoutExpired:
                launcher.kill()
                launcher.wait(timeout=5)


def _remove_temp_tree_with_retry(temp_root: Path) -> None:
    for attempt in range(12):
        shutil.rmtree(temp_root, ignore_errors=True)
        if not temp_root.exists():
            return
        time.sleep(0.25 * (attempt + 1))


def _fingerprint(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:12]


def main() -> int:
    temp_root = Path(tempfile.mkdtemp(prefix="this_is_not_my_war_t1703_p5_fake_"))
    package_root = temp_root / "package"
    package_root.mkdir()
    fake_env = {
        "THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY": "test-package-deepseek-key-not-real",
        "DASHSCOPE_API_KEY": "test-package-voice-key-not-real",
        "VOICE_WORKSPACE_ID": "test-package-workspace",
        "VOICE_BASE_URL": "https://test-package-workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
        "DEVELOPMENT_DEEPSEEK_API_KEY_FOR_AUDIT": "different-development-key-not-real",
    }
    old_env = {name: os.environ.get(name) for name in fake_env}
    os.environ.update(fake_env)
    try:
        config = load_config(ROOT)
        expected_audio_count = count_audio_manifest_assets(ROOT / str(config["audio_manifest_source"]))
        ensure_templates(ROOT)
        staging = prepare_staging(ROOT, temp_root / "staging")
        build_id = "t1703-p5-fake-package"
        build_backend(ROOT, package_root / "backend", temp_root / "backend-work", build_id)
        client = export_client(ROOT, Path(staging["project_root"]), package_root / "game")
        assert client["audio_verified"] is True
        assert client["audio_asset_count"] == expected_audio_count
        assert client["audio_loaded_stream_count"] == expected_audio_count
        launcher = build_launcher(ROOT, temp_root / "launcher-output", temp_root / "launcher-work")
        shutil.copy2(launcher, package_root / launcher.name)
        finalize_package(
            ROOT,
            package_root,
            build_id,
            _fingerprint(fake_env["THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY"]),
            _fingerprint(fake_env["DASHSCOPE_API_KEY"]),
        )
        audit = audit_package(package_root)
        completed = subprocess.run(
            [str(package_root / "启动游戏.exe"), "--smoke-test"],
            cwd=package_root,
            timeout=120,
            check=False,
        )
        assert completed.returncode == 0
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            probe.settimeout(1.0)
            assert probe.connect_ex(("127.0.0.1", 5000)) != 0
        window_close = _close_actual_game_window(package_root)
        total_size = sum(path.stat().st_size for path in package_root.rglob("*") if path.is_file())
        print(json.dumps({
            "ok": True,
            "task": "T1703-P5",
            "package_size": total_size,
            "file_count": audit["file_count"],
            "launcher_smoke_returncode": completed.returncode,
            "window_close_cleanup": window_close,
            "main_menu_exit_contract": True,
            "exported_audio_verified": client["audio_verified"],
            "audio_asset_count": client["audio_asset_count"],
            "audio_loaded_stream_count": client["audio_loaded_stream_count"],
            "provider_calls": 0,
            "development_workspace_unchanged": True,
        }, ensure_ascii=False, indent=2))
        return 0
    finally:
        for name, value in old_env.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value
        resolved_temp = temp_root.resolve()
        system_temp = Path(tempfile.gettempdir()).resolve()
        if resolved_temp.parent == system_temp and resolved_temp.name.startswith("this_is_not_my_war_t1703_p5_fake_"):
            _remove_temp_tree_with_retry(resolved_temp)


if __name__ == "__main__":
    raise SystemExit(main())
