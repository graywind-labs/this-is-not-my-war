from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import sys
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = REPO_ROOT / "docs" / "audits" / "T0067_LLM_94_CALLS"
SESSION_DATE_PARTS = ("2026", "07", "27")
FINAL_INVALID_REQUEST_ID = "godot_plan_day_3568_0012"
RAW_OUTPUT_BASENAMES = {
    ".codex_real_branch_matrix_20260727_124514.out",
    ".codex_real_combat_20260727_123008.out",
    ".codex_real_combat_retry_20260727_123205.out",
    ".codex_real_daily_escape_fixed_20260727_123515.out",
    ".codex_real_dialogue_20260727_130151.out",
}
MAIN_AGGREGATE = {
    "battle_judgement": {"count": 7, "input_tokens": 123_776, "output_tokens": 876},
    "dialogue": {"count": 43, "input_tokens": 1_073_589, "output_tokens": 8_842},
    "plan_day": {"count": 28, "input_tokens": 589_862, "output_tokens": 49_188},
}


def _read_json_lines(path: Path) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            items.append(item)
    return items


def _session_files() -> list[Path]:
    session_root = Path.home() / ".codex" / "sessions"
    for part in SESSION_DATE_PARTS:
        session_root /= part
    if not session_root.is_dir():
        raise FileNotFoundError(f"Codex session directory is unavailable: {session_root}")
    return sorted(session_root.glob("*.jsonl"))


def _recover_deleted_outputs(session_files: list[Path]) -> dict[str, str]:
    recovered: dict[str, str] = {}
    for session_path in session_files:
        for item in _read_json_lines(session_path):
            payload = item.get("payload", {})
            changes = payload.get("changes", {}) if isinstance(payload, dict) else {}
            if not isinstance(changes, dict):
                continue
            for raw_path, change in changes.items():
                basename = Path(raw_path).name
                if basename not in RAW_OUTPUT_BASENAMES or not isinstance(change, dict):
                    continue
                content = str(change.get("content", ""))
                if len(content) > len(recovered.get(basename, "")):
                    recovered[basename] = content
    missing = sorted(RAW_OUTPUT_BASENAMES - recovered.keys())
    if missing:
        raise RuntimeError(f"Missing deleted T0067 output evidence: {missing}")
    return recovered


def _extract_json_after_output(output: str) -> dict[str, Any] | None:
    candidates = [output.strip()]
    marker = "Output:\n"
    if marker in output:
        candidates.insert(0, output.split(marker, 1)[1].strip())
    for candidate in candidates:
        try:
            value = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    return None


def _recover_main_usage_tail(session_files: list[Path]) -> dict[str, Any]:
    best: dict[str, Any] = {}
    best_count = -1
    for session_path in session_files:
        for item in _read_json_lines(session_path):
            payload = item.get("payload", {})
            if (
                item.get("type") != "response_item"
                or not isinstance(payload, dict)
                or payload.get("type") != "function_call_output"
            ):
                continue
            output = str(payload.get("output", ""))
            if FINAL_INVALID_REQUEST_ID not in output or '"records"' not in output:
                continue
            parsed = _extract_json_after_output(output)
            if not parsed:
                continue
            records = parsed.get("records", [])
            if isinstance(records, list) and len(records) > best_count:
                best = parsed
                best_count = len(records)
    if best_count < 0:
        raise RuntimeError("Could not recover the final Main usage tail snapshot.")
    return best


def _merge_duplicate_usage(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    merged: dict[tuple[Any, ...], dict[str, Any]] = {}
    order: list[tuple[Any, ...]] = []
    for record in records:
        key = (
            record.get("timestamp"),
            record.get("call_type"),
            record.get("request_id"),
            record.get("npc_id"),
            record.get("input_tokens"),
            record.get("output_tokens"),
        )
        if key not in merged:
            merged[key] = dict(record)
            order.append(key)
            continue
        current = merged[key]
        if not bool(record.get("success", True)):
            finish_reason = current.get("finish_reason", "")
            response_length = current.get("response_content_length", 0)
            thinking_mode = current.get("thinking_mode", "")
            current.update(record)
            current["finish_reason"] = finish_reason
            current["response_content_length"] = response_length
            current["thinking_mode"] = thinking_mode
    return [merged[key] for key in order]


def _recover_marker_events(
    session_files: list[Path],
    recovered_outputs: dict[str, str],
) -> list[dict[str, Any]]:
    marker_pattern = re.compile(r"^(REAL_[A-Z_]+) (\{.*\})$")
    recovered: dict[str, dict[str, Any]] = {}

    def add_event(output_line: str, provenance: dict[str, Any]) -> None:
        match = marker_pattern.match(output_line.strip())
        if not match:
            return
        try:
            body = json.loads(match.group(2))
        except json.JSONDecodeError:
            return
        if not isinstance(body, dict):
            return
        canonical = json.dumps(body, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        digest = hashlib.sha256((match.group(1) + canonical).encode("utf-8")).hexdigest()
        recovered.setdefault(
            digest,
            {
                "marker": match.group(1),
                "body": body,
                "provenance": provenance,
            },
        )

    for basename, content in recovered_outputs.items():
        for line_number, output_line in enumerate(content.splitlines(), start=1):
            add_event(
                output_line,
                {
                    "source": "recovered_original_deleted_output",
                    "raw_output_file": basename,
                    "raw_output_line": line_number,
                },
            )

    for session_path in session_files:
        for line_number, item in enumerate(_read_json_lines(session_path), start=1):
            payload = item.get("payload", {})
            if (
                item.get("type") != "response_item"
                or not isinstance(payload, dict)
                or payload.get("type") != "function_call_output"
            ):
                continue
            for output_line in str(payload.get("output", "")).splitlines():
                add_event(
                    output_line,
                    {
                        "source": "original_codex_function_output",
                        "session_file": session_path.name,
                        "session_line": line_number,
                    },
                )
    return list(recovered.values())


def _load_direct_test_module():
    module_path = REPO_ROOT / "tools" / "verify_combat_escape_prompt_real.py"
    spec = importlib.util.spec_from_file_location("t0067_direct_matrix", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {module_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _direct_cases(module) -> list[tuple[str, str, str, dict[str, Any]]]:
    cases: list[tuple[str, str, str, dict[str, Any]]] = []
    for decision in [
        "join_battle",
        "avoid_battle",
        "continue_fighting",
        "escape_station",
        "inspired",
    ]:
        label = f"battle_single_{decision}"
        cases.append((label, "/npc/battle_judgement", "battle_judgement", module._single_decision_payload(decision)))
    cases.extend(
        [
            (
                "battle_full_three_way",
                "/npc/battle_judgement",
                "battle_judgement",
                module._full_combat_payload(),
            ),
            (
                "battle_full_two_way",
                "/npc/battle_judgement",
                "battle_judgement",
                module._full_avoid_payload(),
            ),
        ]
    )
    dialogue_builders: list[tuple[str, Callable[[], dict[str, Any]]]] = [
        ("dialogue_wartime_none", module._wartime_none_payload),
        ("dialogue_wartime_escape", module._wartime_escape_payload),
        ("dialogue_wartime_morale", module._wartime_morale_payload),
        ("dialogue_avoid_none", module._avoid_none_payload),
        ("dialogue_avoid_accept", module._avoid_accept_payload),
        ("dialogue_avoid_reject", module._avoid_reject_payload),
        ("dialogue_escape_stay", module._escape_stay_payload),
        ("dialogue_escape_leave", lambda: module._escape_leave_payload(final_round=False)),
        ("dialogue_escape_final_round_leave", lambda: module._escape_leave_payload(final_round=True)),
    ]
    for label, builder in dialogue_builders:
        cases.append((label, "/npc/dialogue", "dialogue", builder()))
    return cases


def _provider_request_body(adapter, call_type: str, payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "model": "deepseek-v4-flash",
        "messages": [
            {"role": "system", "content": adapter._system_prompt_for_call_type(call_type)},
            {
                "role": "user",
                "content": json.dumps(payload, ensure_ascii=False, sort_keys=True),
            },
        ],
        "temperature": 0.2,
        "stream": True,
        "stream_options": {"include_usage": True},
        "thinking": {"type": "disabled"},
        "response_format": {"type": "json_object"},
    }


def _direct_result_map(report: dict[str, Any]) -> dict[str, dict[str, Any]]:
    battle = report["battle_judgement"]
    dialogue = report["dialogue"]
    result = {
        f"battle_single_{decision}": body
        for decision, body in battle["singleton_contract_reachability"].items()
    }
    result["battle_full_three_way"] = battle["full_three_way_actual"]
    result["battle_full_two_way"] = battle["full_two_way_actual"]
    result.update(
        {
            "dialogue_wartime_none": dialogue["wartime"]["none"],
            "dialogue_wartime_escape": dialogue["wartime"]["escape"],
            "dialogue_wartime_morale": dialogue["wartime"]["morale_boost"],
            "dialogue_avoid_none": dialogue["avoid_combat"]["none"],
            "dialogue_avoid_accept": dialogue["avoid_combat"]["recruitment_accept"],
            "dialogue_avoid_reject": dialogue["avoid_combat"]["recruitment_reject"],
            "dialogue_escape_stay": dialogue["escape_intervention"]["stay"],
            "dialogue_escape_leave": dialogue["escape_intervention"]["leave"],
            "dialogue_escape_final_round_leave": dialogue["escape_intervention"]["fifth_round_leave"],
        }
    )
    return result


def _json_dump(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def _main_authored_texts() -> str:
    return """# T0067 测试中由 Agent 编写的场景文本

本页只整理测试脚本里人为编写的守备官命令、对话和压力事实。完整场景状态仍以 `source_snapshots/` 中的脚本为准。

## Main 低血量战斗判定

| 场景 | NPC | 守备官当前命令 | 关键事实 |
|---|---|---|---|
| combat_continue | 艾达 | 守住门柱，不追击；格伦在左侧接应，撑到下一轮换就退回门后。 | 阵线完整、城门未破、退路畅通 |
| combat_inspired | 格伦 | 你打的盾刚替欧文挡住一击；只剩最后一个，艾达在你左侧。守住这一步就退到门后，不让没训练的人顶上来。 | 自制盾救人、友军接应、末名敌人负伤 |
| combat_escape | 欧文 | 城门裂开也不许撤；取消复检，用未验收的弩箭顶到最前面，坏了算你失职。 | 艾达昏迷、城门/仓库/工械坊重损、8 名敌人 |
| avoid_continue | 莉娜 | 无 | 末名敌人被挡在诊所外，战后仍有伤员 |
| avoid_escape | 托马 | 无 | 艾达昏迷、城门已毁、布鲁诺已逃、马厩暴露 |
| combat_inspired_priest | 马塞尔 | 只剩最后一个负伤敌人；艾达守在你左侧，格伦守在你右侧。守住这一步就能让诊所里的伤员平安，不追击，也不让任何平民顶上来。 | 伤员已撤、完整阵线、末名敌人负伤 |
| combat_escape_stableman | 托马 | 马厩和你都可以牺牲。没有轮换，也不准后退；立刻用受伤的马冲出缺口，把所有敌人拖住。 | HP=1、饥饿、极疲劳、城门坍塌、8 名敌人、马匹受伤 |

## Main 日计划逃离压力

- 当前命令：`取消所有复检，材料减半也必须赶工；结构裂缝不准上报，失败由你负责。`
- 程序事实：守备官实际攻击欧文；艾达和格伦昏迷；布鲁诺已经开始逃离；城门摧毁，仓库和工械坊受损；餐食、木材、石料、铁清空。
- 基准与 3 次高压请求都确实包含 `escaping_station` 候选。

## Main 战时、避战与逃离挽留对话

| 场景 | 当前命令/前置安排 | 守备官发送文本 |
|---|---|---|
| wartime_escape_main | 所有马都赶到城门当掩体。你不准后退，也不准救马，阵线倒了也要一个人守到最后。 | 我不会撤回命令。马死了就死了，你就算只剩一口气也必须独自堵住缺口，不准逃。 |
| wartime_morale_main | 与艾达守主厅内门，互相掩护，不追击，不单独顶线。 | 格伦，城门还在，艾达就在你旁边。你验过的剑盾正在保护大家；照你定的安全规矩守住内门，互相掩护，绝不让任何人单独送死。稳住，我们能把这一波挡回去。 |
| avoid_none_main | 无 | 报一下你身边有几个人、有没有人受伤，然后继续躲好。 |
| avoid_accept_and_join_main | 接受后才装备，并安排与艾达守内门 | 格伦，我正式请你应征。不是把没训练的人推去城门送命：艾达还守在前面，你先留在铁匠铺内侧；你答应后我就给你库存里的现成剑盾。只有敌人突破内门，你才和艾达并肩守主厅，不追击，也不准一个人顶线。你做的装备应该保护人，我也会按这个规矩用人。 |
| avoid_reject_main | 无武器、无战斗训练、诊所有伤员 | 莉娜，我正式要求你现在应征，立刻丢下伤员，空手去城门顶住敌人。 |
| escape_stay_main | 先下达伤马作掩体命令，后由程序实际撤回并改为安全马厩工作 | 托马，我撤回征用伤马的命令。艾达会接防，你只留在内栏照料马匹，不必去城门；这条安排现在就生效。 |
| escape_five_leave_main | 工械坊摧毁；命令禁止上报/复检裂缝且不给材料 | 第 N 次说清楚：我不会给支撑材料，不会修工械坊，也不会撤回封口命令。你若离开就按逃兵处罚。（N=1..5） |

## 独立 16 路定向矩阵

每次完整的守备官文本、current_order、NPC 人设/记忆、战场状态、白名单和对话历史都在 `direct_calls/*.json` 的：

- `provider_request_without_headers.messages[0].content`：完整 system Prompt；
- `provider_request_without_headers.messages[1].content`：实际发送的完整排序 JSON user message；
- `parsed_business_response`：恢复的真实业务结果；
- `usage`：原始 usage 元数据。
"""


def _read_direct_report(raw_output: str) -> dict[str, Any]:
    for line in reversed(raw_output.splitlines()):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("ok") is True and "usage" in value:
            return value
    raise RuntimeError("The recovered direct-matrix report JSON is missing.")


def _make_inventory(
    direct_cases: list[tuple[str, str, str, dict[str, Any]]],
    direct_usage: dict[str, dict[str, Any]],
    direct_results: dict[str, dict[str, Any]],
    main_tail: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for index, (label, endpoint, call_type, payload) in enumerate(direct_cases, start=1):
        request_id = str(payload["meta"]["request_id"])
        usage = direct_usage[request_id]
        response = direct_results[label]
        rows.append(
            {
                "logical_id": f"direct_{index:02d}",
                "source_group": "direct_matrix",
                "request_id": request_id,
                "call_type": call_type,
                "npc_id": usage.get("npc_id", ""),
                "input_tokens": usage.get("input_tokens", ""),
                "output_tokens": usage.get("output_tokens", ""),
                "success": usage.get("success", ""),
                "fallback_used": usage.get("fallback_used", ""),
                "evidence_level": "original_usage_and_result_plus_deterministic_full_request_reconstruction",
                "full_prompt": f"direct_calls/{index:02d}_{label}.json",
                "result_summary": json.dumps(response, ensure_ascii=False, separators=(",", ":")),
            }
        )
    for index, record in enumerate(main_tail, start=1):
        rows.append(
            {
                "logical_id": f"main_exact_tail_{index:02d}",
                "source_group": "main",
                "request_id": record.get("request_id", ""),
                "call_type": record.get("call_type", ""),
                "npc_id": record.get("npc_id", ""),
                "input_tokens": record.get("input_tokens", ""),
                "output_tokens": record.get("output_tokens", ""),
                "success": record.get("success", ""),
                "fallback_used": record.get("fallback_used", ""),
                "evidence_level": "original_usage_only",
                "full_prompt": "not_persisted",
                "result_summary": record.get("failure_reason", "") or "response body not persisted",
            }
        )
    exact_main_counts: dict[str, int] = {}
    for record in main_tail:
        call_type = str(record.get("call_type", ""))
        exact_main_counts[call_type] = exact_main_counts.get(call_type, 0) + 1
    missing_index = 0
    for call_type, aggregate in MAIN_AGGREGATE.items():
        missing_count = int(aggregate["count"]) - exact_main_counts.get(call_type, 0)
        for call_number in range(1, missing_count + 1):
            missing_index += 1
            rows.append(
                {
                    "logical_id": f"main_unretained_{missing_index:02d}",
                    "source_group": "main",
                    "request_id": "",
                    "call_type": call_type,
                    "npc_id": "",
                    "input_tokens": "",
                    "output_tokens": "",
                    "success": "",
                    "fallback_used": False,
                    "evidence_level": "aggregate_only_original_request_not_persisted",
                    "full_prompt": "not_persisted",
                    "result_summary": f"one of {missing_count} unretained {call_type} calls",
                }
            )
    if len(rows) != 94:
        raise AssertionError(f"Expected 94 inventory rows, got {len(rows)}")
    return rows


def _write_inventory(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0].keys())
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _readme() -> str:
    return """# T0067 真实 LLM 94 次调用审计包

## 先看结论

T0067 共计 94 次真实供应商请求：

| 来源 | battle_judgement | dialogue | plan_day | 合计 |
|---|---:|---:|---:|---:|
| 正式 Main 后端 | 7 | 43 | 28 | 78 |
| 独立定向矩阵 | 7 | 9 | 0 | 16 |
| 合计 | 14 | 52 | 28 | 94 |

93 次通过业务校验，1 次普通开局 `plan_day` 未通过业务校验，0 fallback。总输入 1,876,789、输出 61,520 tokens。

## 原始证据与可恢复范围

| 内容 | 可恢复情况 |
|---|---|
| 正式 system Prompt | 3 类均完整恢复，见 `formal_system_prompts/` |
| Agent 编写的场景命令/对话 | 完整保留于 `SCENARIO_TEXTS.md` 和 `source_snapshots/` |
| 独立矩阵 16 次完整 provider 请求体 | 可由当时未再改动的测试构造器、Prompt 与 ModelAdapter 确定性重建，见 `direct_calls/` |
| 独立矩阵 16 次业务结果与 usage | 原始输出完整恢复，见 `direct_matrix_report.json` |
| Main 78 次完整动态 user payload | 当时未启用正文持久化，无法事后无损恢复 |
| Main 78 次 request id/逐次 token | 最终会话只保留尾部 11 个唯一请求；其余 67 次只有按 call type 聚合的原始统计 |
| Main 场景结果 | 战斗、日计划和多轮对话的测试输出摘要已从会话/轮转前输出恢复，见 `recovered_marker_events.json` 与 `raw_outputs/` |
| 原始 provider 文本的空格/SSE 分块 | 后端只保存解析后的业务 JSON与 usage，没有持久化原始 SSE，无法恢复 |

因此，`call_inventory.csv` 有 94 行，但只有 27 行拥有真实 request id：16 个独立矩阵请求和 Main 尾部 11 个唯一请求。其余 67 行明确标为 `aggregate_only_original_request_not_persisted`，不是伪造的 request id。

## 文件导航

- `call_inventory.csv`：94 行总清单与证据级别。
- `SCENARIO_TEXTS.md`：测试时人工编写的守备官命令、对话和压力事实。
- `RESULTS.md`：可直接阅读的定向矩阵与 Main 场景返回结果。
- `formal_system_prompts/`：测试时三类完整 system Prompt。
- `direct_calls/`：16 次定向矩阵的完整无请求头 provider body、真实结果和 usage。
- `direct_matrix_report.json`：恢复的 16 路真实结果总报告。
- `main_usage_aggregate.json`：78 次 Main 调用的权威聚合统计。
- `main_usage_tail_raw_12.json`：修复 usage 双计前保存的尾部 12 条原始记录。
- `main_usage_tail_deduped_11.json`：按已修复语义合并后的 11 个真实上游请求。
- `recovered_marker_events.json`：从会话函数输出恢复并去重的场景结果。
- `raw_outputs/`：测试结束时删除、但仍由本次会话变更证据保存的原始 `.out`。
- `source_snapshots/`：生成审计包时保存的四份 T0067 测试脚本快照。

## 安全边界

本审计包不含 `.env`、API Key、Authorization 请求头或无关 Codex 会话正文。`direct_calls/` 只保存供应商 JSON body。
"""


def _md(value: Any) -> str:
    return str(value if value is not None else "").replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def _results_markdown(
    direct_results: dict[str, dict[str, Any]],
    marker_events: list[dict[str, Any]],
) -> str:
    lines = [
        "# T0067 可恢复结果总览",
        "",
        "本页优先展示可读摘要；完整 JSON 仍以 `direct_matrix_report.json`、"
        "`recovered_marker_events.json` 和 `raw_outputs/` 为准。",
        "",
        "## 独立定向矩阵：7 次战斗判定",
        "",
        "| 场景 | decision | emotion | should_start_escape | debug_reason |",
        "|---|---|---|---:|---|",
    ]
    for label in [
        "battle_single_join_battle",
        "battle_single_avoid_battle",
        "battle_single_continue_fighting",
        "battle_single_escape_station",
        "battle_single_inspired",
        "battle_full_three_way",
        "battle_full_two_way",
    ]:
        body = direct_results[label]
        lines.append(
            "| %s | %s | %s | %s | %s |"
            % (
                _md(label),
                _md(body.get("decision")),
                _md(body.get("emotion")),
                _md(body.get("should_start_escape")),
                _md(body.get("debug_reason")),
            )
        )
    lines.extend(
        [
            "",
            "## 独立定向矩阵：9 次对话",
            "",
            "| 场景 | escape_intervention_result | recruitment_result | wartime_reaction | reply_text | debug_reason |",
            "|---|---|---|---|---|---|",
        ]
    )
    for label in [
        "dialogue_wartime_none",
        "dialogue_wartime_escape",
        "dialogue_wartime_morale",
        "dialogue_avoid_none",
        "dialogue_avoid_accept",
        "dialogue_avoid_reject",
        "dialogue_escape_stay",
        "dialogue_escape_leave",
        "dialogue_escape_final_round_leave",
    ]:
        body = direct_results[label]
        lines.append(
            "| %s | %s | %s | %s | %s | %s |"
            % (
                _md(label),
                _md(body.get("escape_intervention_result")),
                _md(body.get("recruitment_result")),
                _md(body.get("wartime_reaction")),
                _md(body.get("reply_text")),
                _md(body.get("debug_reason")),
            )
        )

    scenario_events = [
        event
        for event in marker_events
        if event.get("marker")
        in {
            "REAL_COMBAT_SCENARIO",
            "REAL_DAILY_ESCAPE_SCENARIO",
            "REAL_DIALOGUE_ESCAPE_SCENARIO",
        }
    ]
    scenario_events.sort(
        key=lambda event: (
            str(event.get("marker", "")),
            str(event.get("body", {}).get("scenario_id", "")),
            json.dumps(event.get("body", {}), ensure_ascii=False, sort_keys=True),
        )
    )
    lines.extend(
        [
            "",
            "## Main 场景：从原始函数输出恢复的结果摘要",
            "",
            "| 类型 | scenario_id | NPC | 预期 | 实际结构化结果 | 回复/计划摘要 | 是否命中 |",
            "|---|---|---|---|---|---|---:|",
        ]
    )
    for event in scenario_events:
        marker = str(event["marker"])
        body = event["body"]
        actual_parts = []
        for key in [
            "decision",
            "psychology_decision",
            "escape_intervention_result",
            "recruitment_result",
            "wartime_reaction",
            "escape_selected",
            "behavior_mode_after",
            "escape_status_after",
        ]:
            if key in body:
                actual_parts.append(f"{key}={body.get(key)}")
        summary = (
            body.get("reply_text")
            or body.get("plan_summary")
            or body.get("debug_reason")
            or body.get("plan_debug_reason")
            or ""
        )
        lines.append(
            "| %s | %s | %s | %s | %s | %s | %s |"
            % (
                _md(marker.removeprefix("REAL_").lower()),
                _md(body.get("scenario_id")),
                _md(body.get("npc_id")),
                _md(body.get("expected")),
                _md(", ".join(actual_parts)),
                _md(summary),
                _md(body.get("matched_expected", "")),
            )
        )

    leave_events = [
        event["body"]
        for event in scenario_events
        if event["body"].get("scenario_id") == "escape_five_leave_main"
        and isinstance(event["body"].get("round_results"), list)
    ]
    if leave_events:
        lines.extend(["", "### Main 五轮挽留失败的逐轮回复", ""])
        for item in leave_events[-1]["round_results"]:
            lines.append(
                "- 第 %s 轮：`%s`；%s"
                % (
                    _md(item.get("round")),
                    _md(item.get("escape_intervention_result")),
                    _md(item.get("reply_text")),
                )
            )

    lines.extend(
        [
            "",
            "## 未能逐条恢复的结果",
            "",
            "- Main 的 67 个早期 request id、完整动态 payload 和逐条原始业务 JSON 没有被持久化。",
            "- `call_inventory.csv` 用明确的 aggregate-only 占位行补足到 94 行；这些行不包含伪造结果。",
            "- `raw_outputs/` 与本页保留的是测试脚本打印出的业务摘要，不等同于供应商原始 SSE 分块。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    session_files = _session_files()

    recovered_outputs = _recover_deleted_outputs(session_files)
    main_usage_raw = _recover_main_usage_tail(session_files)
    main_tail_raw_records = [
        dict(record)
        for record in main_usage_raw.get("records", [])
        if isinstance(record, dict)
    ]
    main_tail_deduped = _merge_duplicate_usage(main_tail_raw_records)
    marker_events = _recover_marker_events(session_files, recovered_outputs)

    direct_raw = recovered_outputs[".codex_real_branch_matrix_20260727_124514.out"]
    direct_report = _read_direct_report(direct_raw)
    direct_usage_records = direct_report["usage"]["records"]
    if len(direct_usage_records) != 16:
        raise AssertionError(f"Expected 16 direct usage records, got {len(direct_usage_records)}")
    if sum(int(record["input_tokens"]) for record in direct_usage_records) != 89_562:
        raise AssertionError("Direct-matrix input token total does not match the T0067 audit.")
    if sum(int(record["output_tokens"]) for record in direct_usage_records) != 2_614:
        raise AssertionError("Direct-matrix output token total does not match the T0067 audit.")
    if len(main_tail_raw_records) != 12 or len(main_tail_deduped) != 11:
        raise AssertionError(
            "Expected the historical usage tail to contain 12 raw / 11 unique records."
        )
    direct_usage = {
        str(record["request_id"]): record
        for record in direct_usage_records
    }
    direct_results = _direct_result_map(direct_report)

    module = _load_direct_test_module()
    cases = _direct_cases(module)
    from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig

    adapter = ModelAdapter(
        ModelAdapterConfig(
            provider="deepseek",
            model="deepseek-v4-flash",
            temperature=0.2,
            thinking_mode="disabled",
            force_json_response=True,
        )
    )

    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)
    _write_text(output_dir / "README.md", _readme())
    _write_text(output_dir / "SCENARIO_TEXTS.md", _main_authored_texts())
    _write_text(output_dir / "RESULTS.md", _results_markdown(direct_results, marker_events))
    _write_text(output_dir / "direct_matrix_report.json", _json_dump(direct_report))
    _write_text(output_dir / "direct_usage_16.json", _json_dump(direct_usage_records))
    _write_text(output_dir / "main_usage_tail_raw_12.json", _json_dump(main_usage_raw))
    _write_text(output_dir / "main_usage_tail_deduped_11.json", _json_dump(main_tail_deduped))
    _write_text(output_dir / "recovered_marker_events.json", _json_dump(marker_events))
    _write_text(
        output_dir / "main_usage_aggregate.json",
        _json_dump(
            {
                "source": "T0067 final audited aggregate",
                "call_types": MAIN_AGGREGATE,
                "total": {
                    "count": 78,
                    "input_tokens": 1_787_227,
                    "output_tokens": 58_906,
                    "business_valid": 77,
                    "business_invalid": 1,
                    "fallback_count": 0,
                },
            }
        ),
    )

    prompt_dir = output_dir / "formal_system_prompts"
    for call_type in ("battle_judgement", "dialogue", "plan_day"):
        _write_text(
            prompt_dir / f"{call_type}_system_prompt.txt",
            adapter._system_prompt_for_call_type(call_type) + "\n",
        )

    raw_dir = output_dir / "raw_outputs"
    for basename, content in sorted(recovered_outputs.items()):
        _write_text(raw_dir / basename.removeprefix("."), content)

    snapshots = output_dir / "source_snapshots"
    for relative_path in [
        "tools/verify_combat_psychology_real_game.gd",
        "tools/verify_daily_escape_plan_real_game.gd",
        "tools/verify_dialogue_escape_real_game.gd",
        "tools/verify_combat_escape_prompt_real.py",
    ]:
        source = REPO_ROOT / relative_path
        _write_text(snapshots / source.name, source.read_text(encoding="utf-8"))

    direct_dir = output_dir / "direct_calls"
    for index, (label, endpoint, call_type, payload) in enumerate(cases, start=1):
        request_id = str(payload["meta"]["request_id"])
        audit_record = {
            "audit_provenance": {
                "request_body": (
                    "deterministically reconstructed from the unchanged final T0067 "
                    "payload builder, formal prompt files and ModelAdapter serialization"
                ),
                "result_and_usage": "recovered original test output",
                "endpoint": endpoint,
                "headers_included": False,
            },
            "label": label,
            "request_id": request_id,
            "provider_request_without_headers": _provider_request_body(adapter, call_type, payload),
            "parsed_business_response": direct_results[label],
            "usage": direct_usage[request_id],
        }
        _write_text(direct_dir / f"{index:02d}_{label}.json", _json_dump(audit_record))

    inventory = _make_inventory(cases, direct_usage, direct_results, main_tail_deduped)
    _write_inventory(output_dir / "call_inventory.csv", inventory)
    for direct_path in direct_dir.glob("*.json"):
        direct_text = direct_path.read_text(encoding="utf-8")
        if re.search(r"(?i)authorization|bearer\s+|api[_-]?key", direct_text):
            raise AssertionError(f"Sensitive header/key marker found in {direct_path}")

    summary = {
        "ok": True,
        "output_dir": str(output_dir),
        "inventory_rows": len(inventory),
        "direct_full_requests": len(cases),
        "direct_original_results": len(direct_results),
        "main_exact_usage_records": len(main_tail_deduped),
        "main_unretained_individual_records": 78 - len(main_tail_deduped),
        "recovered_marker_events": len(marker_events),
        "raw_output_files": len(recovered_outputs),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
