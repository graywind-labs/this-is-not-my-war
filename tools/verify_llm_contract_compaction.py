from __future__ import annotations

import json
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.services.model_adapter import ModelAdapter, ModelAdapterConfig  # noqa: E402
from tools.verify_battle_judgement_prompt import (  # noqa: E402
    _payload as battle_payload,
    _valid_response as battle_output,
)
from tools.verify_daily_reflection_prompt import (  # noqa: E402
    _payload as reflection_payload,
    _valid_reflection as reflection_output,
)
from tools.verify_dialogue_plan_revision_judgement import (  # noqa: E402
    _payload as judgement_payload,
    _valid_response as judgement_output,
)
from tools.verify_dialogue_prompt import (  # noqa: E402
    _base_payload as dialogue_payload,
    _valid_player_response as dialogue_output,
)
from tools.verify_plan_day_prompt import (  # noqa: E402
    _base_payload as plan_day_payload,
    _valid_plan as plan_day_output,
)
from tools.verify_plan_revision_prompt import (  # noqa: E402
    _payload as revision_payload,
    _valid_revision as revision_output,
)


def _compact_size(payload: dict) -> int:
    return len(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def _contains_none(value: object) -> bool:
    if value is None:
        return True
    if isinstance(value, dict):
        return any(_contains_none(item) for item in value.values())
    if isinstance(value, list):
        return any(_contains_none(item) for item in value)
    return False


def main() -> None:
    adapter = ModelAdapter(ModelAdapterConfig(provider="mock"))
    cases = [
        ("dialogue", dialogue_payload(), dialogue_output()),
        ("plan_day", plan_day_payload(), plan_day_output()),
        (
            "plan_revision_judgement",
            judgement_payload(),
            judgement_output(),
        ),
        ("revise_plan", revision_payload(), revision_output()),
        (
            "battle_judgement",
            battle_payload(["continue_fighting", "escape_station", "inspired"]),
            battle_output(),
        ),
        ("daily_reflection", reflection_payload(), reflection_output()),
    ]
    report: dict[str, dict[str, int | float]] = {}
    for call_type, source, provider_output in cases:
        projected = adapter._provider_request_payload(call_type, source)
        source_size = _compact_size(source)
        projected_size = _compact_size(projected)
        hydrated_output = adapter._hydrate_model_output(
            call_type,
            source,
            provider_output,
        )
        provider_output_size = _compact_size(provider_output)
        stable_output_size = _compact_size(hydrated_output)
        assert projected_size < source_size, call_type
        assert provider_output_size < stable_output_size, call_type
        assert "meta" not in projected, call_type
        assert "station_context" in projected, call_type
        assert not _contains_none(projected), call_type
        report[call_type] = {
            "source_chars": source_size,
            "provider_chars": projected_size,
            "saved_chars": source_size - projected_size,
            "saved_percent": round(
                (source_size - projected_size) * 100.0 / source_size,
                2,
            ),
            "provider_output_chars": provider_output_size,
            "stable_response_chars": stable_output_size,
            "saved_output_chars": stable_output_size - provider_output_size,
            "saved_output_percent": round(
                (stable_output_size - provider_output_size)
                * 100.0
                / stable_output_size,
                2,
            ),
        }

    assert "speaker_npc" not in adapter._provider_request_payload(
        "dialogue",
        dialogue_payload(),
    )
    assert "current_resource_states" not in adapter._provider_request_payload(
        "plan_day",
        plan_day_payload(),
    )
    judgement = adapter._provider_request_payload(
        "plan_revision_judgement",
        judgement_payload(),
    )
    assert "failed_plan_item" not in judgement
    assert "failure_context" not in judgement
    assert "revision_scope" not in adapter._provider_request_payload(
        "revise_plan",
        revision_payload(),
    )
    assert "knowledge_graph" not in adapter._provider_request_payload(
        "battle_judgement",
        battle_payload(["continue_fighting", "escape_station", "inspired"]),
    )["npc"]
    assert "existing_diary_entries" not in adapter._provider_request_payload(
        "daily_reflection",
        reflection_payload(),
    )

    print(json.dumps(report, ensure_ascii=False, indent=2))
    print("verify_llm_contract_compaction: ok")


if __name__ == "__main__":
    main()
