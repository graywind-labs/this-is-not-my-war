from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

try:
    from .prepare_demo_staging import DemoStagingError, sha256_file
except ImportError:
    from prepare_demo_staging import DemoStagingError, sha256_file


def verify_package_manifest(package_root: Path) -> dict[str, Any]:
    package_root = package_root.resolve()
    manifest_path = package_root / "BUILD_MANIFEST.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise DemoStagingError("Published package manifest is missing or invalid.") from exc
    entries = manifest.get("files")
    if not isinstance(entries, list):
        raise DemoStagingError("Published package manifest does not contain a file list.")

    expected: dict[str, dict[str, Any]] = {}
    for item in entries:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str):
            raise DemoStagingError("Published package manifest contains an invalid file entry.")
        relative = item["path"]
        if relative in expected or relative == "BUILD_MANIFEST.json":
            raise DemoStagingError(f"Published package manifest contains an invalid path: {relative}")
        expected[relative] = item

    actual = {
        path.relative_to(package_root).as_posix(): path
        for path in package_root.rglob("*")
        if path.is_file() and path != manifest_path
    }
    if set(actual) != set(expected):
        missing = sorted(set(expected) - set(actual))
        unexpected = sorted(set(actual) - set(expected))
        raise DemoStagingError(
            "Published package file list mismatch; missing="
            + ",".join(missing)
            + " unexpected="
            + ",".join(unexpected)
        )

    total_size = 0
    for relative, path in actual.items():
        expected_entry = expected[relative]
        size = path.stat().st_size
        total_size += size
        if size != int(expected_entry.get("size", -1)):
            raise DemoStagingError(f"Published package size mismatch: {relative}")
        if sha256_file(path) != str(expected_entry.get("sha256", "")):
            raise DemoStagingError(f"Published package hash mismatch: {relative}")
    if len(actual) != int(manifest.get("file_count", -1)):
        raise DemoStagingError("Published package file count does not match its manifest.")
    if total_size != int(manifest.get("total_size", -1)):
        raise DemoStagingError("Published package total size does not match its manifest.")
    return {"ok": True, "file_count": len(actual), "total_size": total_size}


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify every copied demo package file against BUILD_MANIFEST.json.")
    parser.add_argument("--package-root", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify_package_manifest(args.package_root), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
