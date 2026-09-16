from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "tools" / "release"
if str(RELEASE_ROOT) not in sys.path:
    sys.path.insert(0, str(RELEASE_ROOT))

from verify_branding_icon import verify_branding_icon


def main() -> int:
    result = verify_branding_icon(ROOT)
    launcher_builder = (RELEASE_ROOT / "build_demo_launcher.py").read_text(encoding="utf-8")
    backend_builder = (RELEASE_ROOT / "build_demo_backend.py").read_text(encoding="utf-8")
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert 'config/windows_native_icon="res://assets/branding/this_is_not_my_war.ico"' in project
    assert 'application/icon="res://assets/branding/this_is_not_my_war.ico"' in preset
    assert 'str(config["branding_icon_ico"])' in launcher_builder
    assert 'str(config["branding_icon_ico"])' in backend_builder
    assert '"--icon"' in launcher_builder
    assert '"--icon"' in backend_builder
    print(json.dumps({
        **result,
        "task": "T1703-P5-R2",
        "targets": ["启动游戏.exe", "ThisIsNotMyWar.exe", "ThisIsNotMyWarBackend.exe", "Windows taskbar"],
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
