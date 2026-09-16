from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from .prepare_demo_staging import DemoStagingError, load_config
except ImportError:
    from prepare_demo_staging import DemoStagingError, load_config


def build_launcher(source_root: Path, output_root: Path, work_root: Path) -> Path:
    source_root = source_root.resolve()
    output_root = output_root.resolve()
    work_root = work_root.resolve()
    executable = output_root / "启动游戏.exe"
    if output_root.exists():
        raise DemoStagingError(f"Launcher output already exists: {output_root}")
    if work_root.exists():
        raise DemoStagingError(f"Launcher work directory already exists: {work_root}")
    output_root.mkdir(parents=True)
    work_root.mkdir(parents=True)
    config = load_config(source_root)
    icon = source_root / str(config["branding_icon_ico"])
    if not icon.is_file():
        raise DemoStagingError(f"Launcher icon is missing: {icon}")
    dist_root = work_root / "dist"
    command = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--onefile",
        "--noconsole",
        "--name",
        "启动游戏",
        "--icon",
        str(icon),
        "--distpath",
        str(dist_root),
        "--workpath",
        str(work_root / "pyinstaller"),
        "--specpath",
        str(work_root / "spec"),
        str(source_root / "tools" / "release" / "demo_launcher.py"),
    ]
    completed = subprocess.run(command, cwd=source_root, check=False)
    if completed.returncode != 0:
        raise DemoStagingError(f"Launcher PyInstaller failed with exit code {completed.returncode}.")
    built = dist_root / "启动游戏.exe"
    if not built.is_file():
        raise DemoStagingError("Frozen demo launcher was not produced.")
    shutil.copy2(built, executable)
    return executable


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the Windows demo launcher.")
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--work-root", type=Path, required=True)
    args = parser.parse_args()
    executable = build_launcher(args.source_root, args.output_root, args.work_root)
    print(json.dumps({"ok": True, "executable": str(executable)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
