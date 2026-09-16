from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from .prepare_demo_staging import DemoStagingError, load_config
except ImportError:
    from prepare_demo_staging import DemoStagingError, load_config


SECRET_ENV_NAMES = (
    "THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY",
    "DASHSCOPE_API_KEY",
    "VOICE_WORKSPACE_ID",
    "VOICE_BASE_URL",
)


def _required_secret(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise DemoStagingError(f"Required secret environment value is missing: {name}")
    return value


def _bootstrap_source(config: dict, build_id: str, secrets: dict[str, str]) -> str:
    environment = {
        "APP_PROFILE": "demo",
        "DEMO_BUILD_ID": build_id,
        "LLM_PROVIDER": str(config["llm_provider"]),
        "LLM_API_KEY": secrets["THIS_IS_NOT_MY_WAR_DEMO_DEEPSEEK_API_KEY"],
        "LLM_BASE_URL": str(config["llm_base_url"]),
        "LLM_MODEL": str(config["llm_model"]),
        "LLM_PROVIDER_TOTAL_TIMEOUT_SECONDS": str(config["llm_provider_total_timeout_seconds"]),
        "LLM_FALLBACK_TO_MOCK": "false",
        "LLM_FORCE_JSON_RESPONSE": "true",
        "LLM_THINKING_MODE": "disabled",
        "LLM_BUDGET_MAX_CALLS": "0",
        "LLM_BUDGET_MAX_INPUT_TOKENS": "0",
        "LLM_BUDGET_MAX_OUTPUT_TOKENS": "0",
        "LLM_BUDGET_MAX_TOTAL_TOKENS": "0",
        "LLM_BUDGET_MAX_COST": "0",
        "LLM_DAILY_BUDGET_MAX_CNY": "0",
        "LLM_AUDIT_LOG_INCLUDE_PAYLOADS": "false",
        "VOICE_PROVIDER": str(config["voice_provider"]),
        "VOICE_MODEL": str(config["voice_model"]),
        "DASHSCOPE_API_KEY": secrets["DASHSCOPE_API_KEY"],
        "VOICE_WORKSPACE_ID": secrets["VOICE_WORKSPACE_ID"],
        "VOICE_BASE_URL": secrets["VOICE_BASE_URL"],
    }
    return (
        "import os\n"
        f"_ENV = {environment!r}\n"
        "for _name, _value in _ENV.items():\n"
        "    os.environ[_name] = _value\n"
        "from backend.demo_server import main\n"
        "raise SystemExit(main())\n"
    )


def build_backend(source_root: Path, output_root: Path, work_root: Path, build_id: str) -> Path:
    source_root = source_root.resolve()
    output_root = output_root.resolve()
    work_root = work_root.resolve()
    if output_root.exists():
        raise DemoStagingError(f"Backend output already exists: {output_root}")
    if work_root.exists():
        raise DemoStagingError(f"Backend work directory already exists: {work_root}")
    config = load_config(source_root)
    secrets = {name: _required_secret(name) for name in SECRET_ENV_NAMES}
    work_root.mkdir(parents=True)
    bootstrap = work_root / "demo_backend_bootstrap.py"
    bootstrap.write_text(_bootstrap_source(config, build_id, secrets), encoding="utf-8")
    dist_root = work_root / "dist"
    spec_root = work_root / "spec"
    pyinstaller_work = work_root / "pyinstaller"
    prompt_source = source_root / "data" / "prompts"
    voice_config_source = source_root / "data" / "dialogue_input_config.json"
    icon = source_root / str(config["branding_icon_ico"])
    if not icon.is_file():
        raise DemoStagingError(f"Backend icon is missing: {icon}")
    command = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--onedir",
        "--noconsole",
        "--name",
        "ThisIsNotMyWarBackend",
        "--icon",
        str(icon),
        "--contents-directory",
        "_internal",
        "--paths",
        str(source_root),
        "--add-data",
        f"{prompt_source}{os.pathsep}data/prompts",
        "--add-data",
        f"{voice_config_source}{os.pathsep}data",
        "--distpath",
        str(dist_root),
        "--workpath",
        str(pyinstaller_work),
        "--specpath",
        str(spec_root),
        str(bootstrap),
    ]
    try:
        completed = subprocess.run(
            command,
            cwd=source_root,
            check=False,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if completed.returncode != 0:
            raise DemoStagingError(f"PyInstaller failed with exit code {completed.returncode}.")
        built_root = dist_root / "ThisIsNotMyWarBackend"
        if not (built_root / "ThisIsNotMyWarBackend.exe").is_file():
            raise DemoStagingError("Frozen backend executable was not produced.")
        shutil.copytree(built_root, output_root)
        return output_root / "ThisIsNotMyWarBackend.exe"
    finally:
        if bootstrap.exists():
            bootstrap.unlink()
        for name in SECRET_ENV_NAMES:
            secrets[name] = ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Freeze the demo backend with PyInstaller.")
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--work-root", type=Path, required=True)
    parser.add_argument("--build-id", required=True)
    args = parser.parse_args()
    executable = build_backend(args.source_root, args.output_root, args.work_root, args.build_id)
    print(json.dumps({"ok": True, "executable": str(executable)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
