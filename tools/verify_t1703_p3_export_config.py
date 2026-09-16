from __future__ import annotations

import json
from pathlib import Path

from release.export_demo_client import resolve_godot, verify_godot_version
from release.prepare_demo_staging import load_config


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    config = load_config(ROOT)
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    assert 'name="Windows Desktop Demo"' in preset
    assert 'platform="Windows Desktop"' in preset
    assert 'custom_features="demo"' in preset
    assert 'export_filter="all_resources"' in preset
    assert 'include_filter="*.json,*.txt,*.csv"' in preset
    assert "encrypt_pck=false" in preset
    assert "binary_format/embed_pck=false" in preset
    assert 'application/icon="res://assets/branding/this_is_not_my_war.ico"' in preset
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert 'config/icon="res://assets/branding/this_is_not_my_war_icon_1024.png"' in project
    assert 'config/windows_native_icon="res://assets/branding/this_is_not_my_war.ico"' in project
    godot = resolve_godot()
    actual = verify_godot_version(godot, str(config["godot_version"]))
    print(json.dumps({
        "ok": True,
        "task": "T1703-P3",
        "godot_version": actual,
        "preset": config["godot_export_preset"],
        "template_sha256": config["godot_template_archive_sha256"],
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
