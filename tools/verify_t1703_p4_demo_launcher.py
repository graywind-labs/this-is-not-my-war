from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "tools" / "release"
if str(RELEASE_ROOT) not in sys.path:
    sys.path.insert(0, str(RELEASE_ROOT))

from demo_launcher import DemoLauncherError, validate_health_payload


def main() -> int:
    manifest = {
        "build_id": "t1703-p4-test",
        "release_profile": {
            "llm_provider": "deepseek",
            "llm_model": "deepseek-v4-pro",
            "voice_provider": "qwen3_asr_flash",
        },
    }
    valid = {
        "service": "war-not-mine-backend",
        "app_profile": "demo",
        "build_id": "t1703-p4-test",
        "model_adapter": {
            "provider": "deepseek",
            "model": "deepseek-v4-pro",
            "fallback_to_mock": False,
        },
        "voice_model_adapter": {"provider": "qwen3_asr_flash"},
    }
    validate_health_payload(valid, manifest)
    rejected = []
    for field, mutate in (
        ("build_id", lambda item: item.__setitem__("build_id", "other")),
        ("provider", lambda item: item["model_adapter"].__setitem__("provider", "mock")),
        ("fallback", lambda item: item["model_adapter"].__setitem__("fallback_to_mock", True)),
        ("voice", lambda item: item["voice_model_adapter"].__setitem__("provider", "mock")),
    ):
        candidate = json.loads(json.dumps(valid))
        mutate(candidate)
        try:
            validate_health_payload(candidate, manifest)
        except DemoLauncherError:
            rejected.append(field)
    assert rejected == ["build_id", "provider", "fallback", "voice"]
    print(json.dumps({
        "ok": True,
        "task": "T1703-P4",
        "accepted_release_health": True,
        "rejected_mismatches": rejected,
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
