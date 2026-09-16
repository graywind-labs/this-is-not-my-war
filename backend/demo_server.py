from __future__ import annotations

import argparse
import ctypes
import logging
import os
import threading
import time
from ctypes import wintypes
from pathlib import Path


PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
STILL_ACTIVE = 259


def _runtime_root() -> Path:
    override = os.getenv("DEMO_RUNTIME_ROOT", "").strip()
    if override:
        return Path(override).expanduser().resolve()
    local_app_data = os.getenv("LOCALAPPDATA", "").strip()
    if local_app_data:
        return Path(local_app_data) / "ThisIsNotMyWarDemo"
    return Path.home() / ".this_is_not_my_war_demo"


def configure_demo_environment(build_id: str) -> Path:
    runtime_root = _runtime_root()
    log_root = runtime_root / "logs"
    os.environ["APP_PROFILE"] = "demo"
    os.environ["DEMO_BUILD_ID"] = build_id
    os.environ.setdefault("AI_SERVICE_CONFIG_DIR", str(runtime_root / "ai_service"))
    os.environ.setdefault("LLM_AUDIT_LOG_ENABLED", "true")
    os.environ.setdefault("LLM_AUDIT_LOG_INCLUDE_PAYLOADS", "false")
    os.environ.setdefault("LLM_AUDIT_LOG_PATH", str(log_root / "llm_calls.jsonl"))
    os.environ.setdefault("LLM_COST_LEDGER_ENABLED", "true")
    os.environ.setdefault("LLM_COST_LEDGER_PATH", str(log_root / "llm_cost_ledger.jsonl"))
    log_root.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=log_root / "backend.log",
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    return runtime_root


def _windows_process_alive(pid: int) -> bool:
    kernel32 = ctypes.windll.kernel32
    kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel32.GetExitCodeProcess.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        return False
    try:
        exit_code = wintypes.DWORD()
        if not kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
            return False
        return exit_code.value == STILL_ACTIVE
    finally:
        kernel32.CloseHandle(handle)


def process_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if os.name == "nt":
        return _windows_process_alive(pid)
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def _watch_parent(parent_pid: int, server) -> None:
    while process_alive(parent_pid):
        time.sleep(1.0)
    logging.getLogger(__name__).info("Launcher process exited; stopping demo backend.")
    server.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Production server for the Windows demo package.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5000)
    parser.add_argument("--parent-pid", type=int, default=0)
    parser.add_argument("--build-id", default=os.getenv("DEMO_BUILD_ID", ""))
    args = parser.parse_args(argv)
    if args.host != "127.0.0.1":
        raise SystemExit("The demo backend may only bind to 127.0.0.1.")
    if not args.build_id.strip():
        raise SystemExit("A non-empty demo build id is required.")

    configure_demo_environment(args.build_id.strip())
    from waitress import create_server
    from backend.app import create_app

    server = create_server(create_app(), host=args.host, port=args.port, threads=8)
    if args.parent_pid > 0:
        monitor = threading.Thread(
            target=_watch_parent,
            args=(args.parent_pid, server),
            name="demo-parent-monitor",
            daemon=True,
        )
        monitor.start()
    logging.getLogger(__name__).info(
        "Starting demo backend build=%s host=%s port=%d",
        args.build_id,
        args.host,
        args.port,
    )
    try:
        server.run()
    finally:
        server.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
