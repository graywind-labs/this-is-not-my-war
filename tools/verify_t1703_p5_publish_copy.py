from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "tools" / "release"
if str(RELEASE_ROOT) not in sys.path:
    sys.path.insert(0, str(RELEASE_ROOT))

from prepare_demo_staging import DemoStagingError
from verify_package_manifest import verify_package_manifest


def _entry(path: Path, root: Path) -> dict[str, object]:
    content = path.read_bytes()
    return {
        "path": path.relative_to(root).as_posix(),
        "size": len(content),
        "sha256": hashlib.sha256(content).hexdigest(),
    }


def main() -> int:
    temp_root = Path(tempfile.mkdtemp(prefix="this_is_not_my_war_t1703_publish_copy_"))
    source = temp_root / "package"
    candidate = temp_root / "dist" / ".t1703-publishing-test"
    final = temp_root / "dist" / "final-package"
    running_client: subprocess.Popen[bytes] | None = None
    try:
        (source / "game").mkdir(parents=True)
        (source / "backend").mkdir()
        shutil.copy2(sys.executable, source / "game" / "client.exe")
        (source / "backend" / "server.bin").write_bytes(b"server-payload")
        files = [_entry(path, source) for path in sorted(source.rglob("*")) if path.is_file()]
        manifest = {
            "file_count": len(files),
            "total_size": sum(int(item["size"]) for item in files),
            "files": files,
        }
        (source / "BUILD_MANIFEST.json").write_text(json.dumps(manifest), encoding="utf-8")
        running_client = subprocess.Popen(
            [str(source / "game" / "client.exe"), "-c", "import time; time.sleep(30)"],
            cwd=source / "game",
        )
        powershell = shutil.which("powershell")
        assert powershell
        copy_env = os.environ.copy()
        copy_env["T1703_TEST_SOURCE"] = str(source)
        copy_env["T1703_TEST_DESTINATION"] = str(candidate)
        subprocess.run(
            [
                powershell,
                "-NoProfile",
                "-Command",
                "Copy-Item -LiteralPath $env:T1703_TEST_SOURCE -Destination $env:T1703_TEST_DESTINATION -Recurse -Force",
            ],
            env=copy_env,
            check=True,
        )
        verified = verify_package_manifest(candidate)
        assert verified["file_count"] == 2
        assert running_client.poll() is None

        move_env = os.environ.copy()
        move_env["T1703_TEST_SOURCE"] = str(candidate)
        move_env["T1703_TEST_DESTINATION"] = str(final)
        subprocess.run(
            [
                powershell,
                "-NoProfile",
                "-Command",
                "Move-Item -LiteralPath $env:T1703_TEST_SOURCE -Destination $env:T1703_TEST_DESTINATION",
            ],
            env=move_env,
            check=True,
        )
        verify_package_manifest(final)

        (final / "game" / "client.exe").write_bytes(b"damaged")
        rejected = False
        try:
            verify_package_manifest(final)
        except DemoStagingError:
            rejected = True
        assert rejected
        print(json.dumps({
            "ok": True,
            "task": "T1703-P5-R1",
            "copied_files_verified": verified["file_count"],
            "source_executable_locked_during_copy": True,
            "candidate_renamed_within_dist": True,
            "corruption_rejected": rejected,
        }, ensure_ascii=False, indent=2))
        return 0
    finally:
        if running_client is not None and running_client.poll() is None:
            running_client.terminate()
            running_client.wait(timeout=5)
        shutil.rmtree(temp_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
