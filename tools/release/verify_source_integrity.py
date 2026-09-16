from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from .prepare_demo_staging import DemoStagingError, verify_source_hashes
except ImportError:
    from prepare_demo_staging import DemoStagingError, verify_source_hashes


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify that release construction did not mutate development files.")
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--staging-manifest", type=Path, required=True)
    args = parser.parse_args()
    try:
        manifest = json.loads(args.staging_manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise DemoStagingError("Unable to read the staging integrity manifest.") from exc
    expected = manifest.get("source_integrity")
    if not isinstance(expected, dict) or not expected:
        raise DemoStagingError("The staging manifest does not contain source integrity hashes.")
    verify_source_hashes(args.source_root.resolve(), {str(key): str(value) for key, value in expected.items()})
    print(json.dumps({"ok": True, "verified_files": sorted(expected)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
