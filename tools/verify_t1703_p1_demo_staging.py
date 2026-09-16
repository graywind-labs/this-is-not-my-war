from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
from pathlib import Path

from release.prepare_demo_staging import (
    capture_source_hashes,
    count_audio_manifest_assets,
    load_config,
    prepare_staging,
    verify_source_hashes,
)


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    config = load_config(ROOT)
    expected_audio_count = count_audio_manifest_assets(ROOT / str(config["audio_manifest_source"]))
    before = capture_source_hashes(ROOT, config)
    temp_root = Path(tempfile.mkdtemp(prefix="this_is_not_my_war_t1703_p1_"))
    staging_root = temp_root / "staging"
    try:
        manifest = prepare_staging(ROOT, staging_root)
        project_root = Path(manifest["project_root"])
        profile = manifest["release_profile"]
        assert profile["gm_enabled"] is False
        assert profile["godot_mcp_enabled"] is False
        assert profile["startup_mode"] == 2
        assert profile["demo_user_directory"] == "ThisIsNotMyWarDemo"
        assert profile["audio_asset_count"] == expected_audio_count
        assert profile["audio_manifest_runtime"].endswith(".runtime.txt")
        assert profile["audio_import_artifact_count_removed"] > 0
        manifest_root = project_root / "assets" / "audio" / "manifests"
        assert not list(manifest_root.glob("*.csv"))
        assert not list(manifest_root.glob("*.csv.import"))
        assert not list(manifest_root.glob("*.translation"))
        assert (project_root / profile["audio_manifest_runtime"]).is_file()
        tutorial_config = json.loads(
            (project_root / "data" / "tutorial_config.json").read_text(encoding="utf-8")
        )
        assert "defense_device_damage_multiplier" not in tutorial_config["tutorial_raid"]
        combat_source = (
            project_root / "scripts" / "systems" / "CombatSystem.gd"
        ).read_text(encoding="utf-8")
        assert "tutorial_defense_device_damage_multiplier" not in combat_source
        assert "defense_device_damage_multiplier" not in combat_source
        assert not (project_root / "addons").exists()
        assert not (project_root / "backend").exists()
        assert not (project_root / "docs").exists()
        assert not (project_root / "tools").exists()
        assert not list(project_root.rglob(".env"))
        verify_source_hashes(ROOT, before)

        godot = shutil.which("godot")
        godot_result = {"executed": False, "returncode": None}
        if godot:
            completed = subprocess.run(
                [godot, "--headless", "--path", str(project_root), "--editor", "--quit"],
                cwd=project_root,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=180,
                check=False,
            )
            godot_result = {"executed": True, "returncode": completed.returncode}
            if completed.returncode != 0:
                raise AssertionError(
                    "Staged project failed Godot headless parse:\n"
                    + completed.stdout[-4000:]
                    + completed.stderr[-4000:]
                )
            assert not list(manifest_root.glob("*.csv"))
            assert not list(manifest_root.glob("*.csv.import"))
            assert not list(manifest_root.glob("*.translation"))
        verify_source_hashes(ROOT, before)
        print(json.dumps({
            "ok": True,
            "task": "T1703-P1",
            "staged_roots": profile["staged_roots"],
            "source_integrity_files": sorted(before),
            "godot": godot_result,
            "audio_manifest_runtime": profile["audio_manifest_runtime"],
            "audio_asset_count": profile["audio_asset_count"],
        }, ensure_ascii=False, indent=2))
        return 0
    finally:
        resolved_temp = temp_root.resolve()
        system_temp = Path(tempfile.gettempdir()).resolve()
        if resolved_temp.parent == system_temp and resolved_temp.name.startswith("this_is_not_my_war_t1703_p1_"):
            shutil.rmtree(resolved_temp, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
