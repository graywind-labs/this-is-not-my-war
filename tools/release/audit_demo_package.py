from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

try:
    from .prepare_demo_staging import DemoStagingError
except ImportError:
    from prepare_demo_staging import DemoStagingError


ALLOWED_ROOTS = {
    "启动游戏.exe",
    "game",
    "backend",
    "licenses",
    "README_试玩说明.txt",
    "BUILD_MANIFEST.json",
}
FORBIDDEN_NAMES = {".git", ".godot", ".vscode", "__pycache__", "AGENTS.md", "game_design.md"}
FORBIDDEN_SUFFIXES = {".env", ".py", ".pyc", ".pyo", ".spec"}


def _contains_bytes(path: Path, needle: bytes) -> bool:
    if not needle:
        return False
    overlap = max(0, len(needle) - 1)
    tail = b""
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(4 * 1024 * 1024)
            if not chunk:
                return False
            block = tail + chunk
            if needle in block:
                return True
            tail = block[-overlap:] if overlap else b""


def audit_package(package_root: Path) -> dict[str, int | bool]:
    package_root = package_root.resolve()
    actual_roots = {item.name for item in package_root.iterdir()}
    if actual_roots != ALLOWED_ROOTS:
        raise DemoStagingError(
            "Package root allowlist mismatch; unexpected="
            + ",".join(sorted(actual_roots - ALLOWED_ROOTS))
            + " missing="
            + ",".join(sorted(ALLOWED_ROOTS - actual_roots))
        )
    files = [item for item in package_root.rglob("*") if item.is_file()]
    forbidden = []
    for path in files:
        relative_parts = set(path.relative_to(package_root).parts)
        if relative_parts & FORBIDDEN_NAMES or path.name in FORBIDDEN_NAMES:
            forbidden.append(path.relative_to(package_root).as_posix())
        if path.suffix.lower() in FORBIDDEN_SUFFIXES or path.name.lower().endswith(".env"):
            forbidden.append(path.relative_to(package_root).as_posix())
    if forbidden:
        raise DemoStagingError("Forbidden files entered package: " + ", ".join(sorted(set(forbidden))))

    demo_key = os.getenv("THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY", "").encode("utf-8")
    voice_key = os.getenv("DASHSCOPE_API_KEY", "").encode("utf-8")
    development_key = os.getenv("DEVELOPMENT_DEEPSEEK_API_KEY_FOR_AUDIT", "").encode("utf-8")
    if not demo_key or not voice_key:
        raise DemoStagingError("Package audit requires the authorized key values through process environment.")
    secret_violations = []
    for path in files:
        relative = path.relative_to(package_root)
        in_backend = relative.parts[0] == "backend"
        if development_key and _contains_bytes(path, development_key):
            secret_violations.append(f"development DeepSeek key in {relative.as_posix()}")
        if not in_backend and _contains_bytes(path, demo_key):
            secret_violations.append(f"demo DeepSeek key outside backend in {relative.as_posix()}")
        if not in_backend and _contains_bytes(path, voice_key):
            secret_violations.append(f"voice key outside backend in {relative.as_posix()}")
    if secret_violations:
        raise DemoStagingError("Secret isolation audit failed: " + "; ".join(secret_violations))

    pck = package_root / "game" / "ThisIsNotMyWar.pck"
    if _contains_bytes(pck, b"MCPGameBridge") or _contains_bytes(pck, b"addons/godot_mcp"):
        raise DemoStagingError("Godot MCP content remains in exported PCK.")
    manifest = json.loads((package_root / "BUILD_MANIFEST.json").read_text(encoding="utf-8"))
    release = manifest.get("release_profile", {})
    expected = {
        "backend_profile": "demo",
        "llm_provider": "deepseek",
        "llm_model": "deepseek-v4-pro",
        "llm_fallback_to_mock": False,
        "voice_provider": "qwen3_asr_flash",
        "startup_mode": 2,
        "default_display_mode": "fullscreen",
        "gm_enabled": False,
        "godot_mcp_enabled": False,
        "branding_icon": "assets/branding/this_is_not_my_war.ico",
        "audio_manifest_runtime": "assets/audio/manifests/audio_asset_manifest.runtime.txt",
    }
    mismatches = [key for key, value in expected.items() if release.get(key) != value]
    if mismatches:
        raise DemoStagingError("Package release profile mismatch: " + ", ".join(mismatches))
    audio_asset_count = release.get("audio_asset_count")
    if not isinstance(audio_asset_count, int) or isinstance(audio_asset_count, bool) or audio_asset_count <= 0:
        raise DemoStagingError("Package release profile has an invalid derived audio_asset_count.")
    return {
        "ok": True,
        "file_count": len(files),
        "development_key_absent": True,
        "authorized_keys_isolated_to_backend": True,
        "mcp_payload_absent": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit the assembled Windows demo package.")
    parser.add_argument("--package-root", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(audit_package(args.package_root), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
