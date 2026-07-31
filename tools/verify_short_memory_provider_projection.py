from __future__ import annotations

import json
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402


CAUSAL_MARKER = "缺铁后改去菜园的旧因果仍应可见"
RAW_ONLY_MARKER = "RAW_ITEMS_AND_SNAPSHOTS_MUST_NEVER_REACH_PROVIDER"
FORMAL_PROMPTS = (
    "dialogue_system_prompt.txt",
    "daily_plan_system_prompt.txt",
    "plan_revision_judgement_system_prompt.txt",
    "plan_revision_system_prompt.txt",
    "battle_judgement_system_prompt.txt",
    "daily_reflection_system_prompt.txt",
)


def _event(index: int, *, memory_kind: str | None = None) -> dict[str, Any]:
    event = {
        "event_id": f"evt_{index:02d}",
        "type": "plan_revised" if index == 0 else "work_started",
        "summary": CAUSAL_MARKER if index == 0 else f"后续事件{index}",
        "importance": 95 if index == 0 else 30,
        "day": 1,
        "time": f"11:{index:02d}:00",
        "details": (
            {"reason": "铁储备为0，无法继续打铁", "source": "llm_plan_revision"}
            if index == 0
            else {"action_id": "work_garden", "technical_sequence": index}
        ),
        "payload": {
            "items": [{"hour": hour, "raw_marker": RAW_ONLY_MARKER} for hour in range(24)],
            "location_snapshot": {"raw_marker": RAW_ONLY_MARKER},
        },
        "raw_marker": RAW_ONLY_MARKER,
    }
    if memory_kind is not None:
        event["memory_kind"] = memory_kind
    return event


def _short_memory() -> dict[str, Any]:
    return {
        "experienced_events": [_event(index) for index in range(13)],
        "witnessed_events": [
            {
                **_event(index + 20),
                "type": "resource_changed",
                "summary": f"见闻事件{index}",
            }
            for index in range(13)
        ],
        "unexpected_raw_bucket": [RAW_ONLY_MARKER],
    }


def _npc() -> dict[str, Any]:
    return {
        "identity": {"npc_id": "blacksmith_01", "name": "格伦"},
        "state": {"hp": 100, "max_hp": 100},
        "current_order": {},
        "short_term_memory": _short_memory(),
        "long_term_memory": {
            "knowledge_graph": {},
            "diary": ["第1天：记下今天发生的事情。"],
        },
        "knowledge_graph": {},
        "location_context": {"location_id": "garden"},
        "plaza_context": {},
    }


def _station_context() -> dict[str, Any]:
    return {
        "basic_resource_reserves": [
            {"resource_id": "iron", "amount": 20},
            {"resource_id": "grain", "amount": 30},
        ]
    }


def _source_payload(call_type: str) -> dict[str, Any]:
    source: dict[str, Any] = {
        "meta": {
            "request_id": f"verify_{call_type}",
            "call_type": call_type,
            "source": "backend_test",
        },
        "game_time": {"day": 1, "time": "12:00:00", "hour": 12},
        "station_context": _station_context(),
        "npc": _npc(),
    }
    if call_type == "dialogue":
        source |= {
            "npc_id": "blacksmith_01",
            "npc_name": "格伦",
            "short_memory": _short_memory(),
            "target_npc": _npc(),
            "speaker_npc": None,
            "speaker_name": "守备官",
            "speaker_context": {"speaker_name": "守备官", "state": {}},
            "dialogue_state": {},
        }
    elif call_type in {"plan_day", "revise_plan", "plan_revision_judgement"}:
        source["current_resource_states"] = {"iron": 20, "grain": 30}
        if call_type == "plan_revision_judgement":
            source |= {
                "npc_id": "blacksmith_01",
                "npc_name": "格伦",
                "trigger_kind": "dialogue",
                "dialogue_history": [{"speaker_name": "守备官", "text": "为什么改计划？"}],
                "failed_plan_item": {},
                "failure_type": "",
                "failure_summary": "",
                "failure_context": {},
            }
        if call_type == "revise_plan":
            source["revision_scope"] = "selected_hours"
    elif call_type == "battle_judgement":
        battlefield = {"active_enemy_count": 2, "summary": "两名敌人在城门外。"}
        source["battlefield_context"] = deepcopy(battlefield)
        source["combat_context"] = deepcopy(battlefield) | {
            "battlefield_context": deepcopy(battlefield),
            "hp_after": 20,
        }
    elif call_type == "daily_reflection":
        source["day_events"] = [
            _event(index, memory_kind="experienced" if index < 7 else "witnessed")
            for index in range(13)
        ]
        source["existing_diary_entries"] = ["第1天：记下今天发生的事情。"]
    return source


def _assert_compact_events(events: list[dict[str, Any]], expected_count: int) -> None:
    assert len(events) == expected_count
    assert events[0]["summary"] == CAUSAL_MARKER
    assert events[0]["details"]["reason"] == "铁储备为0，无法继续打铁"
    for event in events:
        assert "event_id" not in event
        assert "payload" not in event
        assert "raw_marker" not in event


def main() -> None:
    adapter = ModelAdapter(
        ModelAdapterConfig(
            provider="mock",
            cost_ledger_enabled=False,
            audit_log_enabled=False,
        )
    )
    call_types = (
        "dialogue",
        "plan_day",
        "plan_revision_judgement",
        "revise_plan",
        "battle_judgement",
        "daily_reflection",
    )
    for call_type in call_types:
        projected = adapter._provider_request_payload(
            call_type,
            _source_payload(call_type),
        )
        serialized = json.dumps(projected, ensure_ascii=False)
        assert RAW_ONLY_MARKER not in serialized, call_type
        assert '"payload"' not in serialized, call_type
        assert '"event_id"' not in serialized, call_type
        if call_type == "dialogue":
            _assert_compact_events(
                projected["short_memory"]["experienced_events"],
                13,
            )
            assert "target_npc" not in projected
        elif call_type == "daily_reflection":
            _assert_compact_events(projected["day_events"], 13)
            assert all(
                event["memory_kind"] in {"experienced", "witnessed"}
                for event in projected["day_events"]
            )
            assert "short_term_memory" not in projected["npc"]
            assert "existing_diary_entries" not in projected
        else:
            _assert_compact_events(
                projected["npc"]["short_term_memory"]["experienced_events"],
                13,
            )
        if call_type in {"plan_day", "plan_revision_judgement", "revise_plan"}:
            assert "current_resource_states" not in projected
        if call_type == "battle_judgement":
            assert "battlefield_context" not in projected["combat_context"]
            assert "active_enemy_count" not in projected["combat_context"]
            assert projected["combat_context"]["hp_after"] == 20

    prompt_dir = ROOT / "data" / "prompts"
    for prompt_name in FORMAL_PROMPTS:
        prompt_text = (prompt_dir / prompt_name).read_text(encoding="utf-8")
        assert "不是“最近若干条”抽样" in prompt_text, prompt_name
        assert "details" in prompt_text, prompt_name
        assert "地点快照" in prompt_text, prompt_name
        assert "阵容" in prompt_text, prompt_name
    reflection_prompt = (prompt_dir / "daily_reflection_system_prompt.txt").read_text(
        encoding="utf-8"
    )
    assert "唯一且完整的短期记忆输入" in reflection_prompt
    legacy_prompt = (
        prompt_dir / "dialogue_plan_revision_judgement_system_prompt.txt"
    ).read_text(encoding="utf-8")
    assert "兼容占位，不参与运行" in legacy_prompt
    assert "不得重新接入" in legacy_prompt

    print("T0106 short-memory provider projection verification passed.")


if __name__ == "__main__":
    main()
