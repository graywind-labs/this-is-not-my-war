from __future__ import annotations

from pathlib import Path
import sys

from pydantic import ValidationError


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


from backend.schemas import (  # noqa: E402
    BattleJudgementRequest,
    DailyPlanRequest,
    DailyReflectionRequest,
    KnowledgeGraphUpdateRequest,
    NPCContext,
    NPCDialogueRequest,
    PlanRevisionJudgementRequest,
    PlanRevisionRequest,
    PlayerStrategyClassificationRequest,
    ProactiveIntentionRequest,
    StationBasicResourceReserveContext,
    StationBuildingContext,
    StationResidentContext,
    StationSceneContext,
    StationWorkModeActionContext,
)
from tools.station_context_fixture import build_station_context  # noqa: E402


REQUEST_TYPES = (
    NPCDialogueRequest,
    DailyPlanRequest,
    PlanRevisionJudgementRequest,
    PlanRevisionRequest,
    BattleJudgementRequest,
    DailyReflectionRequest,
    KnowledgeGraphUpdateRequest,
    ProactiveIntentionRequest,
    PlayerStrategyClassificationRequest,
)

PROMPT_PATHS = (
    REPO_ROOT / "data/prompts/dialogue_system_prompt.txt",
    REPO_ROOT / "data/prompts/daily_plan_system_prompt.txt",
    REPO_ROOT / "data/prompts/plan_revision_judgement_system_prompt.txt",
    REPO_ROOT / "data/prompts/plan_revision_system_prompt.txt",
    REPO_ROOT / "data/prompts/battle_judgement_system_prompt.txt",
    REPO_ROOT / "data/prompts/daily_reflection_system_prompt.txt",
)


def main() -> None:
    station_context = StationSceneContext.model_validate(build_station_context([
        {"npc_id": "stableman_01", "name": "托马", "identity": "马夫"},
        {"npc_id": "doctor_01", "name": "莉娜", "identity": "医生"},
    ]))
    dumped_context = station_context.model_dump()
    assert "小型边境驿站" in dumped_context["setting_summary"]
    assert dumped_context["resident_roster"][0] == {
        "npc_id": "stableman_01",
        "name": "托马",
        "identity": "马夫",
        "recruited": False,
        "in_station": True,
    }
    assert dumped_context["building_roster"][0] == {
        "building_id": "main_hall",
        "name": "主厅",
    }
    assert any(
        item["action_id"] == "talk_to_npc" and item["action_kind"] == "chat"
        for item in dumped_context["work_mode_actions"]
    )
    assert any(
        item == {
            "action_id": "assist_upgrade",
            "name": "协助升级建筑",
            "action_kind": "assist_upgrade",
            "description": "",
        }
        for item in dumped_context["work_mode_actions"]
    )
    drink_action = next(
        item for item in dumped_context["work_mode_actions"]
        if item["action_id"] == "drink_wine"
    )
    assert drink_action["action_kind"] == "drink"
    assert "本人当前确实持有" in drink_action["description"]
    assert "过去的伤痛暂时淡化" in drink_action["description"]
    assert dumped_context["basic_resource_reserves"] == [
        {"resource_id": "grain", "name": "粮食", "amount": 18},
        {"resource_id": "meal", "name": "餐食", "amount": 0},
        {"resource_id": "wood", "name": "木材", "amount": 12},
        {"resource_id": "stone", "name": "石料", "amount": 8},
        {"resource_id": "iron", "name": "铁", "amount": 5},
    ]
    assert any("临阵脱逃" in rule for rule in dumped_context["station_rules"])
    assert len(dumped_context["station_rules"]) == 6
    assert any(
        "持续参与" in rule and "完成相应周期" in rule and "自行继续产出" in rule
        for rule in dumped_context["station_rules"]
    )
    assert any(
        "建筑开始升级" in rule and "协助" in rule and "加快升级进度" in rule
        for rule in dumped_context["station_rules"]
    )
    assert StationBasicResourceReserveContext(
        resource_id="grain",
        name="粮食",
        amount=18,
    ).amount == 18
    assert StationBuildingContext(building_id="main_hall", name="主厅").name == "主厅"
    assert StationResidentContext(
        npc_id="veteran_deputy_01",
        name="艾达",
        identity="老兵副官",
        recruited=True,
        in_station=True,
    ).recruited is True
    assert StationWorkModeActionContext(
        action_id="work_garden",
        name="照料菜园",
        action_kind="work",
    ).action_kind == "work"

    for request_type in REQUEST_TYPES:
        assert "station_context" in request_type.model_fields, request_type.__name__
        assert request_type.model_fields["station_context"].is_required(), request_type.__name__

    try:
        StationSceneContext.model_validate({
            **build_station_context([
                {"npc_id": "stableman_01", "name": "托马", "identity": "马夫"}
            ]),
            "resident_roster": [],
        })
    except ValidationError:
        pass
    else:
        raise AssertionError("station_context resident_roster must not be empty")

    invalid_resident_tags = build_station_context([
        {"npc_id": "stableman_01", "name": "托马", "identity": "马夫"}
    ])
    invalid_resident_tags["resident_roster"][0].pop("recruited")
    try:
        StationSceneContext.model_validate(invalid_resident_tags)
    except ValidationError:
        pass
    else:
        raise AssertionError("station_context resident rows must require recruited and in_station")

    for empty_field in (
        "building_roster",
        "work_mode_actions",
        "basic_resource_reserves",
        "station_rules",
    ):
        invalid_context = build_station_context([
            {"npc_id": "stableman_01", "name": "托马", "identity": "马夫"}
        ])
        invalid_context[empty_field] = []
        try:
            StationSceneContext.model_validate(invalid_context)
        except ValidationError:
            pass
        else:
            raise AssertionError(f"station_context {empty_field} must not be empty")

    invalid_resources = build_station_context([
        {"npc_id": "stableman_01", "name": "托马", "identity": "马夫"}
    ])
    invalid_resources["basic_resource_reserves"][-1] = {
        "resource_id": "money",
        "name": "第纳尔",
        "amount": 30,
    }
    try:
        StationSceneContext.model_validate(invalid_resources)
    except ValidationError:
        pass
    else:
        raise AssertionError("station_context must reject non-public resource reserves")

    try:
        StationSceneContext.model_validate({
            **build_station_context([
                {"npc_id": "stableman_01", "name": "托马", "identity": "马夫"}
            ]),
            "setting_summary": "",
        })
    except ValidationError:
        pass
    else:
        raise AssertionError("station_context setting_summary must not be empty")

    # The shared scene is request-level, never repeated in nested speaker/target NPC contexts.
    assert "station_context" not in NPCContext.model_fields

    for prompt_path in PROMPT_PATHS:
        prompt_text = prompt_path.read_text(encoding="utf-8")
        for required_text in (
            "station_context",
            "setting_summary",
            "resident_roster",
            "building_roster",
            "work_mode_actions",
            "basic_resource_reserves",
            "station_rules",
        ):
            assert required_text in prompt_text, f"{prompt_path.name} missing {required_text}"
        assert "未完成周期" in prompt_text or "未完成" in prompt_text, (
            f"{prompt_path.name} missing incomplete-cycle guidance"
        )
        assert "升级" in prompt_text and "协助" in prompt_text, (
            f"{prompt_path.name} missing building-upgrade assistance guidance"
        )

    print("verify_station_context_schema: ok")


if __name__ == "__main__":
    main()
