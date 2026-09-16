from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "tools" / "release"
if str(RELEASE_ROOT) not in sys.path:
    sys.path.insert(0, str(RELEASE_ROOT))

from verify_demo_provider_connection import ProviderConnectionError, validate_provider_result


def main() -> int:
    accepted = validate_provider_result(200, {
        "ok": True,
        "provider": "deepseek",
        "model": "deepseek-v4-pro",
    })
    assert accepted == {"provider": "deepseek", "model": "deepseek-v4-pro"}

    rejected = 0
    for status, payload in (
        (401, {"ok": False, "error_code": "provider_auth_failed", "message": "Authentication failed."}),
        (200, {"ok": True, "provider": "mock", "model": "mock"}),
        (200, {"ok": False, "error_code": "provider_connection_failed"}),
    ):
        try:
            validate_provider_result(status, payload)
        except ProviderConnectionError:
            rejected += 1
    assert rejected == 3
    print(json.dumps({
        "ok": True,
        "task": "T1703-P5",
        "accepted_provider": accepted["provider"],
        "rejected_invalid_results": rejected,
        "secret_transport": "embedded_backend_only",
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
