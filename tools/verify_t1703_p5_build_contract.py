from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    script = (ROOT / "tools" / "build_windows_demo.ps1").read_text(encoding="utf-8")
    config = json.loads((ROOT / "tools" / "release" / "demo_build_config.json").read_text(encoding="utf-8"))
    stages = re.findall(r"Write-Stage '([0-9]{2} [^']+)'", script)
    expected_stages = [
        "00 AcquireSecret",
        "01 Preflight",
        "02 PrepareBuildTools",
        "03 CreateIsolatedStaging",
        "04 ApplyAndVerifyReleaseProfile",
        "05 BuildBackend",
        "06 ExportGodotClient",
        "07 BuildLauncher",
        "08 AssemblePackage",
        "09 AuditPackage",
        "10 VerifyDeepSeekConnection",
        "11 SmokeTest",
        "12 VerifySourceIntegrity",
        "13 AtomicPublish",
        "14 Cleanup",
    ]
    assert stages == expected_stages
    assert script.strip().startswith("[CmdletBinding()]")
    assert "param()" in script
    assert "-AsSecureString" in script
    assert "backend\\.env" in script
    assert "DASHSCOPE_API_KEY" in script
    assert "DEVELOPMENT_DEEPSEEK_API_KEY_FOR_AUDIT" in script
    assert "verify_demo_provider_connection.py" in script
    assert "verify_source_integrity.py" in script
    assert "verify_package_manifest.py" in script
    assert "verify_branding_icon.py" in script
    assert "Get-NetTCPConnection -LocalPort $backendPort -State Listen" in script
    assert "No existing process was stopped." in script
    assert "verify_exported_audio" in (ROOT / "tools" / "release" / "export_demo_client.py").read_text(encoding="utf-8")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    client_settings = (ROOT / "scripts" / "core" / "ClientSettings.gd").read_text(encoding="utf-8")
    assert "window/size/mode=3" in project
    assert 'const DEFAULT_DISPLAY_MODE := "fullscreen"' in client_settings
    launcher = (ROOT / "tools" / "release" / "demo_launcher.py").read_text(encoding="utf-8")
    assert "return game_process.wait()" in launcher
    assert "finally:\n        _stop_process(backend_process)" in launcher
    assert "Copy-Item -LiteralPath $packageRoot -Destination $publishCandidate -Recurse" in script
    assert "Move-DirectoryWithRetry $publishCandidate $finalRoot" in script
    assert "Move-DirectoryWithRetry $backupRoot $finalRoot" in script
    assert "/config/ai-service/test" in (ROOT / "tools" / "release" / "verify_demo_provider_connection.py").read_text(encoding="utf-8")
    assert "Remove-Item -LiteralPath $resolvedBuildRoot -Recurse" in script
    assert "git reset" not in script.lower()
    assert "git clean" not in script.lower()
    assert config["llm_provider"] == "deepseek"
    assert config["llm_model"] == "deepseek-v4-pro"
    assert config["llm_provider_total_timeout_seconds"] == 120
    assert config["llm_fallback_to_mock"] is False
    backend_builder = (ROOT / "tools" / "release" / "build_demo_backend.py").read_text(encoding="utf-8")
    assert '"LLM_PROVIDER_TOTAL_TIMEOUT_SECONDS"' in backend_builder
    assert 'config["llm_provider_total_timeout_seconds"]' in backend_builder
    assert config["voice_provider"] == "qwen3_asr_flash"
    assert config["gm_enabled"] is False
    assert config["godot_mcp_enabled"] is False
    assert config["audio_manifest_runtime"].endswith(".runtime.txt")
    assert "audio_asset_count" not in config
    staging_source = (ROOT / "tools" / "release" / "prepare_demo_staging.py").read_text(encoding="utf-8")
    assert "count_audio_manifest_assets" in staging_source
    assert "_remove_audio_csv_import_artifacts" in staging_source
    assert '("*.csv", "*.csv.import", "*.translation")' in staging_source
    print(json.dumps({
        "ok": True,
        "task": "T1703-P5",
        "stages": stages,
        "manual_secret_inputs": ["DeepSeek API Key"],
        "automatic_voice_credentials": True,
        "creates_zip": False,
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
