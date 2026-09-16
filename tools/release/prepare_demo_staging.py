from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import shutil
from pathlib import Path
from typing import Any


CONFIG_RELATIVE_PATH = Path("tools/release/demo_build_config.json")


class DemoStagingError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def count_audio_manifest_assets(path: Path) -> int:
    if not path.is_file():
        raise DemoStagingError(f"Audio manifest is missing: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        count = sum(1 for row in csv.DictReader(handle) if str(row.get("asset_id", "")).strip())
    if count <= 0:
        raise DemoStagingError(f"Audio manifest contains no asset rows: {path}")
    return count


def load_config(source_root: Path, config_path: Path | None = None) -> dict[str, Any]:
    resolved_path = (config_path or source_root / CONFIG_RELATIVE_PATH).resolve()
    try:
        data = json.loads(resolved_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise DemoStagingError(f"Unable to load demo build config: {resolved_path}") from exc
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        raise DemoStagingError("Demo build config must be a schema_version=1 object.")
    return data


def capture_source_hashes(source_root: Path, config: dict[str, Any]) -> dict[str, str]:
    result: dict[str, str] = {}
    for relative in config.get("source_integrity_files", []):
        path = (source_root / str(relative)).resolve()
        if not path.is_file():
            raise DemoStagingError(f"Required integrity file is missing: {relative}")
        result[str(relative).replace("\\", "/")] = sha256_file(path)
    return result


def verify_source_hashes(source_root: Path, expected: dict[str, str]) -> None:
    current = {
        relative: sha256_file((source_root / relative).resolve())
        for relative in expected
    }
    changed = sorted(relative for relative, digest in expected.items() if current[relative] != digest)
    if changed:
        raise DemoStagingError(
            "Development workspace changed during staging: " + ", ".join(changed)
        )


def _copy_runtime_allowlist(source_root: Path, project_root: Path, config: dict[str, Any]) -> None:
    if project_root.exists():
        raise DemoStagingError(f"Staging project directory already exists: {project_root}")
    project_root.mkdir(parents=True)
    for relative in config.get("runtime_root_files", []):
        source = source_root / str(relative)
        if not source.is_file():
            raise DemoStagingError(f"Required runtime file is missing: {relative}")
        shutil.copy2(source, project_root / source.name)
    for relative in config.get("runtime_root_directories", []):
        source = source_root / str(relative)
        if not source.is_dir():
            raise DemoStagingError(f"Required runtime directory is missing: {relative}")
        shutil.copytree(source, project_root / source.name, copy_function=shutil.copy2)


def _replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise DemoStagingError(f"Expected exactly one {label}, found {count}.")
    return text.replace(old, new, 1)


def _set_project_setting(text: str, key: str, serialized_value: str) -> str:
    pattern = re.compile(rf"(?m)^{re.escape(key)}=.*$")
    replacement = f"{key}={serialized_value}"
    if pattern.search(text):
        return pattern.sub(replacement, text, count=1)
    application = re.search(r"(?m)^\[application\]\s*$", text)
    if application is None:
        raise DemoStagingError("project.godot is missing [application].")
    insert_at = application.end()
    return text[:insert_at] + "\n\n" + replacement + text[insert_at:]


def _apply_project_overrides(project_root: Path, config: dict[str, Any]) -> None:
    path = project_root / "project.godot"
    text = path.read_text(encoding="utf-8")
    text = re.sub(
        r'(?m)^MCPGameBridge="res://addons/godot_mcp/game_bridge/mcp_game_bridge\.gd"\r?\n?',
        "",
        text,
        count=1,
    )
    text = re.sub(
        r'(?m)^enabled=PackedStringArray\("res://addons/godot_mcp/plugin\.cfg"\)$',
        "enabled=PackedStringArray()",
        text,
        count=1,
    )
    text = re.sub(
        r"(?ms)^\[godot_mcp\]\s*$.*?(?=^\[|\Z)",
        "",
        text,
        count=1,
    )
    text = _set_project_setting(text, "run/main_scene", '"res://scenes/frontend/MainMenu.tscn"')
    text = _set_project_setting(text, "config/use_custom_user_dir", "true")
    user_dir = str(config.get("demo_user_directory", "ThisIsNotMyWarDemo"))
    text = _set_project_setting(
        text,
        "config/custom_user_dir_name",
        json.dumps(user_dir, ensure_ascii=False),
    )
    if "godot_mcp" in text or "MCPGameBridge" in text:
        raise DemoStagingError("Godot MCP references remain in staged project.godot.")
    path.write_text(text, encoding="utf-8", newline="\n")


def _apply_gm_override(project_root: Path) -> None:
    path = project_root / "scripts/ui/GMPanel.gd"
    text = path.read_text(encoding="utf-8")
    text = _replace_once(text, "const GM_ENABLED := true", "const GM_ENABLED := false", "GM flag")
    path.write_text(text, encoding="utf-8", newline="\n")


def _apply_audio_manifest_override(project_root: Path, config: dict[str, Any]) -> int:
    source_relative = Path(str(config.get("audio_manifest_source", "")))
    runtime_relative = Path(str(config.get("audio_manifest_runtime", "")))
    if not source_relative.as_posix() or not runtime_relative.as_posix():
        raise DemoStagingError("Demo audio manifest source/runtime paths are required.")
    source = project_root / source_relative
    runtime = project_root / runtime_relative
    if not source.is_file():
        raise DemoStagingError(f"Demo audio source manifest is missing: {source_relative.as_posix()}")
    if runtime.suffix.lower() != ".txt":
        raise DemoStagingError("Demo runtime audio manifest must use a non-imported .txt extension.")
    runtime.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, runtime)
    asset_count = count_audio_manifest_assets(source)

    manager = project_root / "scripts/systems/AudioManager.gd"
    text = manager.read_text(encoding="utf-8")
    text = _replace_once(
        text,
        f'const MANIFEST_PATH := "res://{source_relative.as_posix()}"',
        f'const MANIFEST_PATH := "res://{runtime_relative.as_posix()}"',
        "release audio manifest path",
    )
    text = _replace_once(
        text,
        "\t_apply_volumes()",
        "\t_apply_volumes()\n"
        "\tif OS.has_feature(\"demo\"):\n"
        "\t\tprint(\"T1703_DEMO_AUDIO_READY assets=%d categorized=%d\" % [_assets.size(), _asset_category_buses.size()])\n"
        "\t\tif \"--t1703-audio-export-smoke\" in OS.get_cmdline_user_args():\n"
        "\t\t\tvar verified_streams := 0\n"
        "\t\t\tfor raw_asset_id in _assets.keys():\n"
        "\t\t\t\tvar info := _assets.get(raw_asset_id, {}) as Dictionary\n"
        "\t\t\t\tif _load_stream(info) != null:\n"
        "\t\t\t\t\tverified_streams += 1\n"
        "\t\t\tprint(\"T1703_DEMO_AUDIO_STREAMS loaded=%d\" % verified_streams)",
        "release audio readiness marker",
    )
    manager.write_text(text, encoding="utf-8", newline="\n")
    return asset_count


def _remove_audio_csv_import_artifacts(project_root: Path, config: dict[str, Any]) -> int:
    source_relative = Path(str(config.get("audio_manifest_source", "")))
    manifest_root = project_root / source_relative.parent
    if not manifest_root.is_dir():
        raise DemoStagingError("Staged audio manifest directory is missing before import cleanup.")
    removed: set[Path] = set()
    for pattern in ("*.csv", "*.csv.import", "*.translation"):
        for path in manifest_root.glob(pattern):
            if path.is_file():
                path.unlink()
                removed.add(path)
    leftovers = [
        path.name
        for pattern in ("*.csv", "*.csv.import", "*.translation")
        for path in manifest_root.glob(pattern)
        if path.is_file()
    ]
    if leftovers:
        raise DemoStagingError(
            "Audio CSV import artifacts remain in staging: " + ", ".join(sorted(set(leftovers)))
        )
    runtime_manifest = project_root / str(config.get("audio_manifest_runtime", ""))
    if not runtime_manifest.is_file():
        raise DemoStagingError("Runtime audio manifest was removed during import cleanup.")
    return len(removed)


def _verify_startup_contract(project_root: Path, config: dict[str, Any]) -> None:
    expected_mode = int(config.get("startup_mode", 2))
    main_text = (project_root / "scenes/main/Main.tscn").read_text(encoding="utf-8")
    menu_text = (project_root / "scripts/ui/MainMenu.gd").read_text(encoding="utf-8")
    if not re.search(rf"(?m)^startup_mode\s*=\s*{expected_mode}\s*$", main_text):
        raise DemoStagingError(f"Main.tscn is not configured for startup_mode={expected_mode}.")
    if not re.search(
        rf"(?m)^const NEW_GAME_TUTORIAL_MODE\s*:=\s*{expected_mode}\s*$",
        menu_text,
    ):
        raise DemoStagingError(
            f"MainMenu.gd is not configured for tutorial startup mode {expected_mode}."
        )
    if str(config.get("default_display_mode", "fullscreen")) != "fullscreen":
        raise DemoStagingError("The demo release config must default to fullscreen.")
    project_text = (project_root / "project.godot").read_text(encoding="utf-8")
    settings_text = (project_root / "scripts/core/ClientSettings.gd").read_text(encoding="utf-8")
    if not re.search(r"(?m)^window/size/mode=3$", project_text):
        raise DemoStagingError("The staged window is not created in fullscreen mode.")
    if 'const DEFAULT_DISPLAY_MODE := "fullscreen"' not in settings_text:
        raise DemoStagingError("Fresh client settings do not default to fullscreen.")


def verify_staged_project(project_root: Path, config: dict[str, Any]) -> dict[str, Any]:
    actual_roots = {item.name for item in project_root.iterdir()}
    forbidden = sorted(set(config.get("forbidden_staging_roots", [])) & actual_roots)
    if forbidden:
        raise DemoStagingError("Forbidden roots entered staged project: " + ", ".join(forbidden))
    expected_roots = {
        Path(str(item)).name
        for item in config.get("runtime_root_files", []) + config.get("runtime_root_directories", [])
    }
    missing = sorted(expected_roots - actual_roots)
    if missing:
        raise DemoStagingError("Staged project is missing allowlisted roots: " + ", ".join(missing))

    project_text = (project_root / "project.godot").read_text(encoding="utf-8")
    gm_text = (project_root / "scripts/ui/GMPanel.gd").read_text(encoding="utf-8")
    if "MCPGameBridge" in project_text or "godot_mcp" in project_text:
        raise DemoStagingError("Godot MCP is still enabled in staged project.")
    if "enabled=PackedStringArray()" not in project_text:
        raise DemoStagingError("Staged editor plugin list is not empty.")
    if "config/use_custom_user_dir=true" not in project_text:
        raise DemoStagingError("Staged project does not use an isolated user directory.")
    expected_user_dir = json.dumps(
        str(config.get("demo_user_directory", "ThisIsNotMyWarDemo")),
        ensure_ascii=False,
    )
    if f"config/custom_user_dir_name={expected_user_dir}" not in project_text:
        raise DemoStagingError("Staged project user directory name is incorrect.")
    expected_icon = str(config.get("branding_icon_source", ""))
    expected_native_icon = str(config.get("branding_icon_ico", ""))
    if f'config/icon="res://{expected_icon}"' not in project_text:
        raise DemoStagingError("Staged project does not use the shared branding source icon.")
    if f'config/windows_native_icon="res://{expected_native_icon}"' not in project_text:
        raise DemoStagingError("Staged project does not use the shared Windows native icon.")
    if not (project_root / expected_icon).is_file() or not (project_root / expected_native_icon).is_file():
        raise DemoStagingError("Staged project is missing the shared branding icon assets.")
    if "const GM_ENABLED := false" not in gm_text or "const GM_ENABLED := true" in gm_text:
        raise DemoStagingError("GM panel was not disabled in staged project.")
    source_manifest = project_root / str(config["audio_manifest_source"])
    runtime_manifest = project_root / str(config["audio_manifest_runtime"])
    audio_manager = (project_root / "scripts/systems/AudioManager.gd").read_text(encoding="utf-8")
    if not source_manifest.is_file() or not runtime_manifest.is_file():
        raise DemoStagingError("Staged project is missing its source or runtime audio manifest.")
    if source_manifest.read_bytes() != runtime_manifest.read_bytes():
        raise DemoStagingError("Staged runtime audio manifest differs from its source CSV.")
    audio_asset_count = count_audio_manifest_assets(runtime_manifest)
    expected_runtime_path = f'res://{config["audio_manifest_runtime"]}'
    if f'const MANIFEST_PATH := "{expected_runtime_path}"' not in audio_manager:
        raise DemoStagingError("Staged AudioManager does not use the runtime text manifest.")
    if "T1703_DEMO_AUDIO_READY" not in audio_manager:
        raise DemoStagingError("Staged AudioManager is missing the exported-audio readiness marker.")
    _verify_startup_contract(project_root, config)
    return {
        "ok": True,
        "gm_enabled": False,
        "godot_mcp_enabled": False,
        "startup_mode": int(config.get("startup_mode", 2)),
        "demo_user_directory": str(config.get("demo_user_directory", "ThisIsNotMyWarDemo")),
        "audio_manifest_runtime": str(config["audio_manifest_runtime"]),
        "audio_asset_count": audio_asset_count,
        "staged_roots": sorted(actual_roots),
    }


def prepare_staging(
    source_root: Path,
    staging_root: Path,
    config_path: Path | None = None,
) -> dict[str, Any]:
    source_root = source_root.resolve()
    staging_root = staging_root.resolve()
    if not (source_root / "project.godot").is_file() or not (source_root / "AGENTS.md").is_file():
        raise DemoStagingError(f"Not a recognized project root: {source_root}")
    if staging_root == source_root or source_root in staging_root.parents:
        raise DemoStagingError("Staging root must be outside the development workspace.")
    if staging_root.exists():
        raise DemoStagingError(f"Staging root already exists: {staging_root}")

    config = load_config(source_root, config_path)
    source_hashes = capture_source_hashes(source_root, config)
    project_root = staging_root / "project"
    _copy_runtime_allowlist(source_root, project_root, config)
    _apply_project_overrides(project_root, config)
    _apply_gm_override(project_root)
    _apply_audio_manifest_override(project_root, config)
    release_snapshot = verify_staged_project(project_root, config)
    release_snapshot["audio_import_artifact_count_removed"] = _remove_audio_csv_import_artifacts(
        project_root,
        config,
    )
    verify_source_hashes(source_root, source_hashes)

    manifest = {
        "schema_version": 1,
        "source_root": str(source_root),
        "project_root": str(project_root),
        "source_integrity": source_hashes,
        "release_profile": release_snapshot,
    }
    (staging_root / "staging_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Create an isolated Godot demo staging project.")
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    parser.add_argument("--staging-root", type=Path, required=True)
    parser.add_argument("--config", type=Path)
    args = parser.parse_args()
    manifest = prepare_staging(args.source_root, args.staging_root, args.config)
    print(json.dumps({
        "ok": True,
        "project_root": manifest["project_root"],
        "release_profile": manifest["release_profile"],
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
