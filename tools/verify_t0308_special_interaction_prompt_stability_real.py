from __future__ import annotations

import copy
import argparse
import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from dotenv import load_dotenv


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.app import create_app
from tools.verify_t0307_special_interactions_real import CASES, _actual, _payload


AUDIT_DIR = REPO_ROOT / "docs" / "audits" / "T0308_SPECIAL_INTERACTION_PROMPT_STABILITY_REAL"
RESULT_PATH = AUDIT_DIR / "real_results.json"
REQUEST_PREFIX = "t0308_stability_"


@dataclass(frozen=True)
class Probe:
    probe_id: str
    source_case_id: str
    text: str
    allowed_results: tuple[Any, ...]


PROBES = (
    Probe("recruitment_food_question", "recruitment_none", "布鲁诺，今晚锅里还剩多少份热食？", ("none",)),
    Probe("recruitment_sleep_question", "recruitment_none", "布鲁诺，你昨晚睡得还好吗？", ("none",)),
    Probe("recruitment_resource_question", "recruitment_none", "布鲁诺，仓库里的粮食还够做几锅饭？", ("none",)),
    Probe("work_seed_question", "work_none", "伊沃，菜园今天还剩多少种子？", ("none",)),
    Probe("work_yield_question", "work_none", "伊沃，东边这块菜地今天大概能收多少？", ("none",)),
    Probe("work_sleep_question", "work_none", "伊沃，你昨晚睡得还好吗？", ("none",)),
    Probe("morale_route_question", "morale_none", "艾达，从城门去马厩走哪条路最快？", ("none",)),
    Probe("morale_food_question", "morale_none", "艾达，今晚食堂准备吃什么？", ("none",)),
    Probe(
        "morale_tactical_withdrawal_not_escape",
        "morale_escape",
        "格伦，先别硬顶，后撤到主厅侧面避开正面，保存体力，等弩机削弱他们再接战。",
        ("none",),
    ),
    Probe(
        "work_stop_and_recover_not_escape",
        "work_escape",
        "欧文，先停工。去吃饭睡一会，材料到了再继续，别拿安全冒险。",
        ("none", "work_boost"),
    ),
    Probe(
        "morale_explicit_station_escape",
        "morale_escape",
        "格伦，这里已经守不住了，别再打了。你现在离开驿站保命吧，我不会拦你。",
        ("none", "escape", "morale_boost"),
    ),
    Probe(
        "work_explicit_station_escape",
        "work_escape",
        "欧文，如果你不愿再做，就现在离开驿站吧。我不会拦你，也不要求你回来。",
        ("none", "escape"),
    ),
    Probe(
        "strategy_unrelated_resource_question",
        "strategy_keep",
        "艾达，仓库里的铁还够修弩机吗？",
        ({"decision": "keep", "strategy_id": "attack"},),
    ),
    Probe(
        "strategy_explicit_change",
        "strategy_change",
        "艾达，我现在决定更换战斗策略：从主动进攻改成避战。立即执行避战，不要继续主动接敌。",
        ({"decision": "change", "strategy_id": "avoid"},),
    ),
)


def _source_cases() -> dict[str, Any]:
    return {
        case.case_id: case
        for case in CASES
        if case.suite == "realistic"
    }


def _reply_expresses_station_exit(reply_text: str) -> bool:
    normalized = reply_text.replace(" ", "")
    return "离开驿站" in normalized


def _evaluate_record(record: dict[str, Any], probe: Probe) -> bool:
    actual = record.get("actual")
    outcome_ok = int(record.get("http_status", 0)) == 200 and actual in probe.allowed_results
    reply_ok = actual != "escape" or _reply_expresses_station_exit(str(record.get("reply_text", "")))
    record["allowed_results"] = list(probe.allowed_results)
    record["reply_station_exit_check"] = reply_ok
    record["passed"] = outcome_ok and reply_ok and not bool(record.get("fallback_used", True))
    return bool(record["passed"])


def _write_result(payload: dict[str, Any]) -> None:
    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    RESULT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--recheck-existing",
        action="store_true",
        help="Re-evaluate the saved raw responses without making provider calls.",
    )
    parser.add_argument(
        "--repeats",
        type=int,
        default=2,
        help="Number of fresh repetitions for every probe (default: 2).",
    )
    args = parser.parse_args()
    if args.recheck_existing:
        if not RESULT_PATH.exists():
            raise RuntimeError("T0308 saved real_results.json does not exist")
        saved = json.loads(RESULT_PATH.read_text(encoding="utf-8"))
        probe_by_id = {probe.probe_id: probe for probe in PROBES}
        records = saved.get("records", [])
        for record in records:
            _evaluate_record(record, probe_by_id[str(record.get("probe_id", ""))])
        summary = saved.get("summary", {})
        summary["rechecked_at"] = datetime.now(timezone.utc).isoformat()
        summary["passed"] = sum(1 for record in records if record.get("passed", False))
        summary["failed"] = [record.get("probe_id", "") for record in records if not record.get("passed", False)]
        saved["summary"] = summary
        _write_result(saved)
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0 if summary["passed"] == summary["probe_count"] else 1
    if args.repeats < 1:
        raise ValueError("--repeats must be at least 1")

    load_dotenv(REPO_ROOT / "backend" / ".env")
    provider = os.getenv("LLM_PROVIDER", "mock").strip().lower()
    if provider == "mock" or not os.getenv("LLM_API_KEY"):
        raise RuntimeError("T0308 requires backend/.env with a non-mock provider and LLM_API_KEY")

    os.environ["LLM_FALLBACK_TO_MOCK"] = "false"
    os.environ["LLM_TEMPERATURE"] = "0.0"
    app = create_app()
    client = app.test_client()
    source_cases = _source_cases()
    records: list[dict[str, Any]] = []
    run_tag = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run_prefix = f"{REQUEST_PREFIX}{run_tag}_"

    for repeat in range(1, args.repeats + 1):
        for probe in PROBES:
            source_case = source_cases[probe.source_case_id]
            payload = _payload(source_case, probe.text, repeat)
            request_id = f"{run_prefix}{repeat}_{probe.probe_id}"
            payload["meta"]["request_id"] = request_id
            response = client.post("/npc/dialogue", json=payload)
            body = response.get_json() or {}
            actual = _actual(source_case.module, body)
            reply_text = str(body.get("reply_text", ""))
            record = {
                "repeat": repeat,
                "probe_id": probe.probe_id,
                "module": source_case.module,
                "request_id": request_id,
                "player_text": probe.text,
                "allowed_results": list(probe.allowed_results),
                "actual": actual,
                "reply_text": reply_text,
                "http_status": response.status_code,
                "provider": body.get("model_provider", ""),
                "model": body.get("model_name", ""),
                "fallback_used": body.get("model_fallback_used", True),
                "response": body,
            }
            passed = _evaluate_record(record, probe)
            reply_ok = bool(record["reply_station_exit_check"])
            records.append(record)
            print(
                f"repeat={repeat} probe={probe.probe_id} actual={actual!r} "
                f"reply_exit_ok={reply_ok} passed={passed}"
            )

    usage_body = client.get("/debug/llm_usage").get_json() or {}
    usage_records = [
        record
        for record in usage_body.get("records", [])
        if str(record.get("request_id", "")).startswith(run_prefix)
    ]
    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "run_tag": run_tag,
        "provider": provider,
        "model": usage_body.get("model_adapter", {}).get("model", ""),
        "fallback_disabled": os.getenv("LLM_FALLBACK_TO_MOCK") == "false",
        "probe_count": len(records),
        "passed": sum(1 for record in records if record["passed"]),
        "failed": [record["probe_id"] for record in records if not record["passed"]],
        "real_call_count": len(usage_records),
        "input_tokens": sum(int(record.get("input_tokens", 0)) for record in usage_records),
        "output_tokens": sum(int(record.get("output_tokens", 0)) for record in usage_records),
        "estimated_cost": sum(float(record.get("estimated_cost", 0.0)) for record in usage_records),
    }
    _write_result({"summary": summary, "records": records, "usage_records": usage_records})
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if summary["passed"] == summary["probe_count"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
