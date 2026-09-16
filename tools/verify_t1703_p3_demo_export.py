from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path

from release.ensure_godot_templates import ensure_templates
from release.export_demo_client import export_client
from release.prepare_demo_staging import count_audio_manifest_assets, load_config, prepare_staging


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    temp_root = Path(tempfile.mkdtemp(prefix="this_is_not_my_war_t1703_p3_"))
    try:
        config = load_config(ROOT)
        expected_audio_count = count_audio_manifest_assets(ROOT / str(config["audio_manifest_source"]))
        template_result = ensure_templates(ROOT)
        manifest = prepare_staging(ROOT, temp_root / "staging")
        project_root = Path(manifest["project_root"])
        result = export_client(ROOT, project_root, temp_root / "game")
        executable = Path(str(result["executable"]))
        pack = Path(str(result["pck"]))
        pack_bytes = pack.read_bytes()
        assert b"MCPGameBridge" not in pack_bytes
        assert b"addons/godot_mcp" not in pack_bytes
        assert result["audio_verified"] is True
        assert result["audio_asset_count"] == expected_audio_count
        assert result["audio_categorized_asset_count"] == expected_audio_count
        assert result["audio_loaded_stream_count"] == expected_audio_count
        print(json.dumps({
            "ok": True,
            "task": "T1703-P3",
            "templates_installed_now": template_result["installed"],
            "godot_version": result["godot_version"],
            "executable_size": result["executable_size"],
            "pck_size": result["pck_size"],
            "mcp_payload_absent": True,
            "exported_client_returncode": 0,
            "audio_verified": result["audio_verified"],
            "audio_asset_count": result["audio_asset_count"],
            "audio_loaded_stream_count": result["audio_loaded_stream_count"],
        }, ensure_ascii=False, indent=2))
        return 0
    finally:
        resolved_temp = temp_root.resolve()
        system_temp = Path(tempfile.gettempdir()).resolve()
        if resolved_temp.parent == system_temp and resolved_temp.name.startswith("this_is_not_my_war_t1703_p3_"):
            shutil.rmtree(resolved_temp, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
