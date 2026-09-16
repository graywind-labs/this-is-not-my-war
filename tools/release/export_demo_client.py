from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

try:
    from .prepare_demo_staging import DemoStagingError, count_audio_manifest_assets, load_config
except ImportError:
    from prepare_demo_staging import DemoStagingError, count_audio_manifest_assets, load_config


def resolve_godot() -> str:
    executable = shutil.which("godot")
    if not executable:
        raise DemoStagingError("Godot executable was not found on PATH.")
    return executable


def verify_godot_version(godot: str, expected: str) -> str:
    completed = subprocess.run(
        [godot, "--version"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    actual = completed.stdout.strip()
    normalized_expected = expected.replace("-", ".")
    if completed.returncode != 0 or not actual.startswith(normalized_expected):
        raise DemoStagingError(f"Godot version mismatch: expected {expected}, got {actual or 'unknown'}.")
    return actual


def verify_exported_audio(executable: Path, expected_asset_count: int) -> dict[str, int | bool]:
    with tempfile.TemporaryDirectory(prefix="this_is_not_my_war_audio_export_") as temp_dir:
        log_path = Path(temp_dir) / "audio_export_smoke.log"
        completed = subprocess.run(
            [
                str(executable),
                "--headless",
                "--quit-after",
                "8",
                "--log-file",
                str(log_path),
                "--",
                "--t1703-audio-export-smoke",
            ],
            cwd=executable.parent,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=90,
            check=False,
        )
        log_text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
        combined = completed.stdout + "\n" + completed.stderr + "\n" + log_text
        if completed.returncode != 0:
            raise DemoStagingError("Exported client audio smoke failed:\n" + combined[-8000:])
        marker = re.search(r"T1703_DEMO_AUDIO_READY assets=(\d+) categorized=(\d+)", combined)
        if marker is None:
            raise DemoStagingError("Exported client did not report the demo audio readiness marker.")
        asset_count = int(marker.group(1))
        categorized_count = int(marker.group(2))
        streams = re.search(r"T1703_DEMO_AUDIO_STREAMS loaded=(\d+)", combined)
        loaded_stream_count = int(streams.group(1)) if streams is not None else -1
        if (
            asset_count != expected_asset_count
            or categorized_count != expected_asset_count
            or loaded_stream_count != expected_asset_count
        ):
            raise DemoStagingError(
                "Exported audio manifest mismatch: "
                f"expected {expected_asset_count}, assets={asset_count}, "
                f"categorized={categorized_count}, streams={loaded_stream_count}."
            )
        forbidden = (
            "AudioManager could not open",
            "references unknown asset",
            "AudioManager missing runtime audio",
            "AudioManager failed to load runtime audio",
        )
        problems = [message for message in forbidden if message in combined]
        if problems:
            raise DemoStagingError("Exported client audio errors: " + ", ".join(problems))
        return {
            "verified": True,
            "asset_count": asset_count,
            "categorized_asset_count": categorized_count,
            "loaded_stream_count": loaded_stream_count,
        }


def export_client(source_root: Path, project_root: Path, output_root: Path) -> dict[str, str | int]:
    source_root = source_root.resolve()
    project_root = project_root.resolve()
    output_root = output_root.resolve()
    if output_root.exists():
        raise DemoStagingError(f"Client output already exists: {output_root}")
    config = load_config(source_root)
    preset = str(config["godot_export_preset"])
    godot = resolve_godot()
    actual_version = verify_godot_version(godot, str(config["godot_version"]))
    if not (project_root / "export_presets.cfg").is_file():
        raise DemoStagingError("Staged project is missing export_presets.cfg.")
    output_root.mkdir(parents=True)
    executable = output_root / "ThisIsNotMyWar.exe"
    completed = subprocess.run(
        [godot, "--headless", "--path", str(project_root), "--export-release", preset, str(executable)],
        cwd=project_root,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
        timeout=900,
    )
    if completed.returncode != 0:
        raise DemoStagingError(
            "Godot release export failed:\n" + completed.stdout[-6000:] + completed.stderr[-6000:]
        )
    pack = output_root / "ThisIsNotMyWar.pck"
    if not executable.is_file() or executable.stat().st_size == 0:
        raise DemoStagingError("Godot release executable was not produced.")
    if not pack.is_file() or pack.stat().st_size == 0:
        raise DemoStagingError("Godot release PCK was not produced.")
    audio_manifest = source_root / str(config["audio_manifest_source"])
    audio = verify_exported_audio(executable, count_audio_manifest_assets(audio_manifest))
    return {
        "ok": 1,
        "godot_version": actual_version,
        "executable": str(executable),
        "executable_size": executable.stat().st_size,
        "pck": str(pack),
        "pck_size": pack.stat().st_size,
        "audio_verified": bool(audio["verified"]),
        "audio_asset_count": int(audio["asset_count"]),
        "audio_categorized_asset_count": int(audio["categorized_asset_count"]),
        "audio_loaded_stream_count": int(audio["loaded_stream_count"]),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Export the staged Godot demo client.")
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(export_client(args.source_root, args.project_root, args.output_root), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
