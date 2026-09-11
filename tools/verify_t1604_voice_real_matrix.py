from __future__ import annotations

import json
import sys
from pathlib import Path

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.app import create_app
from backend.schemas import QWEN_NATIVE_VOICE_EMOTIONS, VoiceAnalyzeResponse


FORBIDDEN_USAGE_KEYS = {"audio", "audio_base64", "api_key", "authorization"}


def _contains_forbidden_key(value: object) -> bool:
    if isinstance(value, dict):
        return any(
            str(key).lower() in FORBIDDEN_USAGE_KEYS or _contains_forbidden_key(item)
            for key, item in value.items()
        )
    if isinstance(value, list):
        return any(_contains_forbidden_key(item) for item in value)
    return False


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_t1604_voice_real_matrix.py SAMPLE_DIRECTORY")
    sample_dir = Path(sys.argv[1]).resolve()
    manifest_path = sample_dir / "manifest.json"
    if not manifest_path.is_file():
        raise SystemExit("manifest.json not found")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))

    load_dotenv(REPO_ROOT / "backend" / ".env", override=True)
    app = create_app()
    app.testing = True
    client = app.test_client()
    results: list[dict[str, object]] = []
    failures = 0
    total_cost = 0.0

    for index, file_name in enumerate(manifest.get("samples", [])):
        audio_path = (sample_dir / str(file_name)).resolve()
        if audio_path.parent != sample_dir or not audio_path.is_file():
            raise SystemExit(f"invalid sample path: {file_name}")
        request_id = f"voice_t1604_real_{index:02d}"
        with audio_path.open("rb") as handle:
            response = client.post(
                "/voice/analyze",
                data={
                    "request_id": request_id,
                    "npc_id": "veteran_01",
                    "dialogue_id": "dialogue_t1604_real_matrix",
                    "locale": "zh",
                    "audio": (handle, audio_path.name),
                },
                content_type="multipart/form-data",
            )
        payload = response.get_json(silent=True) or {}
        usage = payload.get("usage") or {}
        safe_result = {
            "sample": audio_path.name,
            "http_status": response.status_code,
            "ok": payload.get("ok", False),
            "request_id": payload.get("request_id", ""),
            "transcript": payload.get("transcript", ""),
            "emotion": payload.get("emotion", ""),
            "emotion_label": payload.get("emotion_label", ""),
            "duration_seconds": payload.get("duration_seconds", 0.0),
            "provider": payload.get("model_provider", ""),
            "model": payload.get("model_name", ""),
            "fallback_used": payload.get("model_fallback_used", payload.get("fallback_used")),
            "estimated_cost_cny": usage.get("estimated_cost_cny"),
            "error_code": payload.get("error_code", ""),
        }
        if response.status_code == 200:
            parsed = VoiceAnalyzeResponse.model_validate(payload)
            assert parsed.request_id == request_id
            assert parsed.model_provider == "alibaba_dashscope"
            assert parsed.model_name == "qwen3-asr-flash"
            assert parsed.model_fallback_used is False
            assert parsed.emotion in {*QWEN_NATIVE_VOICE_EMOTIONS, "none"}
            assert not _contains_forbidden_key(usage)
            total_cost += float(usage.get("estimated_cost_cny") or 0.0)
        else:
            failures += 1
        results.append(safe_result)

    output = {
        "generator": manifest.get("generator", ""),
        "voice_name": manifest.get("voice_name", ""),
        "culture": manifest.get("culture", ""),
        "gender": manifest.get("gender", ""),
        "sample_count": len(results),
        "failures": failures,
        "estimated_cost_cny": round(total_cost, 8),
        "limitations": manifest.get("limitations", []),
        "results": results,
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
