from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from .prepare_demo_staging import DemoStagingError, count_audio_manifest_assets, load_config, sha256_file
except ImportError:
    from prepare_demo_staging import DemoStagingError, count_audio_manifest_assets, load_config, sha256_file


def _git_output(source_root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=source_root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    return completed.stdout.strip() if completed.returncode == 0 else ""


def _project_version(source_root: Path) -> str:
    text = (source_root / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'(?m)^config/version="([^"]+)"$', text)
    if not match:
        raise DemoStagingError("project.godot does not contain config/version.")
    return match.group(1)


def _file_manifest(package_root: Path) -> tuple[list[dict[str, Any]], int]:
    entries: list[dict[str, Any]] = []
    total = 0
    for path in sorted(item for item in package_root.rglob("*") if item.is_file()):
        if path.name == "BUILD_MANIFEST.json":
            continue
        size = path.stat().st_size
        total += size
        entries.append({
            "path": path.relative_to(package_root).as_posix(),
            "size": size,
            "sha256": sha256_file(path),
        })
    return entries, total


def finalize_package(
    source_root: Path,
    package_root: Path,
    build_id: str,
    deepseek_fingerprint: str,
    voice_fingerprint: str,
) -> Path:
    source_root = source_root.resolve()
    package_root = package_root.resolve()
    required = (
        package_root / "启动游戏.exe",
        package_root / "game" / "ThisIsNotMyWar.exe",
        package_root / "game" / "ThisIsNotMyWar.pck",
        package_root / "backend" / "ThisIsNotMyWarBackend.exe",
    )
    missing = [str(path.relative_to(package_root)) for path in required if not path.is_file()]
    if missing:
        raise DemoStagingError("Cannot finalize incomplete package: " + ", ".join(missing))

    shutil.copy2(
        source_root / "tools" / "release" / "README_试玩说明.template.txt",
        package_root / "README_试玩说明.txt",
    )
    license_root = package_root / "licenses"
    license_root.mkdir(exist_ok=True)
    shutil.copy2(
        source_root / "assets" / "THIRD_PARTY_ASSETS.md",
        license_root / "THIRD_PARTY_ASSETS.txt",
    )
    config = load_config(source_root)
    audio_asset_count = count_audio_manifest_assets(
        source_root / str(config["audio_manifest_source"])
    )
    files, total_size = _file_manifest(package_root)
    git_status = _git_output(source_root, "status", "--porcelain")
    manifest = {
        "schema_version": 1,
        "build_id": build_id,
        "built_at_utc": datetime.now(timezone.utc).isoformat(),
        "project_version": _project_version(source_root),
        "git_head": _git_output(source_root, "rev-parse", "HEAD"),
        "git_dirty": bool(git_status),
        "release_profile": {
            "target": config["target"],
            "godot_version": config["godot_version"],
            "backend_host": config["backend_host"],
            "backend_port": config["backend_port"],
            "backend_profile": config["backend_profile"],
            "llm_provider": config["llm_provider"],
            "llm_base_url": config["llm_base_url"],
            "llm_model": config["llm_model"],
            "llm_fallback_to_mock": config["llm_fallback_to_mock"],
            "voice_provider": config["voice_provider"],
            "voice_model": config["voice_model"],
            "startup_mode": config["startup_mode"],
            "default_display_mode": config["default_display_mode"],
            "gm_enabled": config["gm_enabled"],
            "godot_mcp_enabled": config["godot_mcp_enabled"],
            "branding_icon": config["branding_icon_ico"],
            "audio_manifest_runtime": config["audio_manifest_runtime"],
            "audio_asset_count": audio_asset_count,
        },
        "secret_fingerprints": {
            "deepseek_sha256_12": deepseek_fingerprint,
            "voice_sha256_12": voice_fingerprint,
        },
        "file_count": len(files),
        "total_size": total_size,
        "files": files,
    }
    manifest_path = package_root / "BUILD_MANIFEST.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Create README, licenses, and the demo build manifest.")
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    parser.add_argument("--package-root", type=Path, required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--deepseek-fingerprint", required=True)
    parser.add_argument("--voice-fingerprint", required=True)
    args = parser.parse_args()
    manifest = finalize_package(
        args.source_root,
        args.package_root,
        args.build_id,
        args.deepseek_fingerprint,
        args.voice_fingerprint,
    )
    print(json.dumps({"ok": True, "manifest": str(manifest)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
