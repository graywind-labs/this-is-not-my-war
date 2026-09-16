from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path

try:
    from .prepare_demo_staging import DemoStagingError, load_config, sha256_file
except ImportError:
    from prepare_demo_staging import DemoStagingError, load_config, sha256_file


REQUIRED_MEMBERS = (
    "templates/version.txt",
    "templates/windows_debug_x86_64.exe",
    "templates/windows_release_x86_64.exe",
)


def default_template_root() -> Path:
    app_data = os.getenv("APPDATA", "").strip()
    if not app_data:
        raise DemoStagingError("APPDATA is unavailable; cannot locate Godot export templates.")
    return Path(app_data) / "Godot" / "export_templates"


def default_cache_root() -> Path:
    local_app_data = os.getenv("LOCALAPPDATA", "").strip()
    if local_app_data:
        return Path(local_app_data) / "ThisIsNotMyWarDemoBuildCache" / "godot"
    return Path(tempfile.gettempdir()) / "ThisIsNotMyWarDemoBuildCache" / "godot"


def _download(url: str, destination: Path, expected_size: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".part")
    if partial.exists():
        partial.unlink()
    request = urllib.request.Request(url, headers={"User-Agent": "ThisIsNotMyWar-Demo-Builder"})
    downloaded = 0
    next_report = 10
    try:
        with urllib.request.urlopen(request, timeout=60) as response, partial.open("wb") as handle:
            while True:
                chunk = response.read(4 * 1024 * 1024)
                if not chunk:
                    break
                handle.write(chunk)
                downloaded += len(chunk)
                if expected_size > 0:
                    percent = int(downloaded * 100 / expected_size)
                    if percent >= next_report:
                        print(json.dumps({"stage": "godot_template_download", "percent": min(percent, 100)}))
                        next_report += 10
        partial.replace(destination)
    finally:
        if partial.exists():
            partial.unlink()


def ensure_templates(
    source_root: Path,
    template_root: Path | None = None,
    cache_root: Path | None = None,
) -> dict[str, str | bool]:
    source_root = source_root.resolve()
    config = load_config(source_root)
    version_dir = str(config["godot_template_directory"])
    install_root = (template_root or default_template_root()).resolve() / version_dir
    release_template = install_root / "windows_release_x86_64.exe"
    debug_template = install_root / "windows_debug_x86_64.exe"
    version_file = install_root / "version.txt"
    if release_template.is_file() and debug_template.is_file() and version_file.is_file():
        if version_file.read_text(encoding="utf-8").strip() != version_dir:
            raise DemoStagingError(f"Installed Godot template version.txt does not match {version_dir}.")
        return {"ok": True, "installed": False, "template_root": str(install_root)}

    archive_name = Path(str(config["godot_template_archive_url"])).name
    archive = (cache_root or default_cache_root()).resolve() / archive_name
    expected_size = int(config["godot_template_archive_size"])
    expected_hash = str(config["godot_template_archive_sha256"]).lower()
    if archive.is_file() and (archive.stat().st_size != expected_size or sha256_file(archive) != expected_hash):
        archive.unlink()
    if not archive.is_file():
        _download(str(config["godot_template_archive_url"]), archive, expected_size)
    if archive.stat().st_size != expected_size:
        raise DemoStagingError("Godot template archive size does not match the release manifest.")
    if sha256_file(archive) != expected_hash:
        raise DemoStagingError("Godot template archive SHA-256 does not match the release manifest.")

    install_parent = install_root.parent
    install_parent.mkdir(parents=True, exist_ok=True)
    temp_install = install_parent / f".{version_dir}.installing"
    if temp_install.exists():
        shutil.rmtree(temp_install)
    temp_install.mkdir()
    try:
        with zipfile.ZipFile(archive) as package:
            names = set(package.namelist())
            missing = sorted(set(REQUIRED_MEMBERS) - names)
            if missing:
                raise DemoStagingError("Godot template archive is missing: " + ", ".join(missing))
            for member in REQUIRED_MEMBERS:
                target = temp_install / Path(member).name
                with package.open(member) as source, target.open("wb") as destination:
                    shutil.copyfileobj(source, destination, length=4 * 1024 * 1024)
        if (temp_install / "version.txt").read_text(encoding="utf-8").strip() != version_dir:
            raise DemoStagingError("Godot template archive version.txt is incorrect.")
        if install_root.exists():
            backup = install_parent / f".{version_dir}.previous"
            if backup.exists():
                shutil.rmtree(backup)
            install_root.replace(backup)
        temp_install.replace(install_root)
    finally:
        if temp_install.exists():
            shutil.rmtree(temp_install, ignore_errors=True)
    return {"ok": True, "installed": True, "template_root": str(install_root)}


def main() -> int:
    parser = argparse.ArgumentParser(description="Install the pinned Godot Windows export templates.")
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    parser.add_argument("--template-root", type=Path)
    parser.add_argument("--cache-root", type=Path)
    args = parser.parse_args()
    result = ensure_templates(args.source_root, args.template_root, args.cache_root)
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
