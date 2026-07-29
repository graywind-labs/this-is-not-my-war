from __future__ import annotations

import json
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]


def build_station_context(
    resident_roster: list[dict[str, Any]],
    *,
    setting_summary: str | None = None,
    basic_resource_amounts: dict[str, int] | None = None,
) -> dict[str, Any]:
    context_config = _load_json(REPO_ROOT / "data/station_context.json")
    building_defs = _load_json(REPO_ROOT / "data/building_defs.json")
    action_defs = _load_json(REPO_ROOT / "data/action_defs.json")
    resource_defs = _load_json(REPO_ROOT / "data/resource_defs.json")
    npc_profiles = _load_json(REPO_ROOT / "data/npc_profiles.json")
    recruited_by_npc_id = {
        str(profile["id"]): bool(profile.get("recruited", False))
        for profile in npc_profiles
    }
    public_resource_ids = ("grain", "meal", "wood", "stone", "iron")
    resource_defs_by_id = {
        str(resource["id"]): resource
        for resource in resource_defs
    }
    resource_amounts = basic_resource_amounts or {}
    return {
        "setting_summary": setting_summary or str(context_config["setting_summary"]),
        "resident_roster": [
            {
                **resident,
                "recruited": bool(resident.get(
                    "recruited",
                    recruited_by_npc_id.get(str(resident.get("npc_id", "")), False),
                )),
                "in_station": bool(resident.get("in_station", True)),
            }
            for resident in resident_roster
        ],
        "building_roster": [
            {"building_id": str(building["id"]), "name": str(building["name"])}
            for building in building_defs
        ],
        "work_mode_actions": [
            {
                "action_id": str(action["id"]),
                "name": str(action["name"]),
                "action_kind": _action_kind(action),
                "description": str(action.get("description", "")),
            }
            for action in action_defs
            if _is_work_mode_action(action)
        ],
        "basic_resource_reserves": [
            {
                "resource_id": resource_id,
                "name": str(resource_defs_by_id[resource_id]["name"]),
                "amount": int(resource_amounts.get(
                    resource_id,
                    resource_defs_by_id[resource_id]["initial_amount"],
                )),
            }
            for resource_id in public_resource_ids
        ],
        "station_rules": [str(rule) for rule in context_config["station_rules"]],
    }


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _is_work_mode_action(action: dict[str, Any]) -> bool:
    if not bool(action.get("plan_selectable", True)):
        return False
    return str(action.get("type", "")) != "system" or str(action.get("id", "")) == "escaping_station"


def _action_kind(action: dict[str, Any]) -> str:
    action_id = str(action.get("id", ""))
    action_type = str(action.get("type", ""))
    type_kinds = {
        "work": "work",
        "clinic_doctor": "work",
        "eat": "eat",
        "drink": "drink",
        "sleep": "sleep",
        "training_instructor": "train",
        "training_student": "train",
        "clinic_patient": "assist_heal",
        "targeted_heal": "assist_heal",
        "pray": "pray",
        "npc_dialogue": "chat",
        "visit": "visit",
        "proactive_talk": "seek_guard_officer",
    }
    if action_id == "escaping_station":
        return "escape"
    if action_id in {"assist_repair", "assist_upgrade", "assist_heal"}:
        return action_id
    return type_kinds.get(action_type, "idle")
