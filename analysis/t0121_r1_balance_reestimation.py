"""Mechanism-aware screening model for T0121-R1.

This model is intentionally subordinate to the Godot runtime. It is used to:
1. audit discrete shots-to-kill and overkill instead of comparing raw DPS only;
2. represent approach/contact timing, physical hit rates, target allocation and
   the existing damage-driven windup/recovery interruption;
3. compare the pre-change BASELINE contract with the current IMPLEMENTED
   authority data after the approved change is applied.

It does not claim to estimate human pass rates. Those remain Main.tscn cohort
and blind-test metrics.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import random
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFENSE_CURVE_SCALE = 20.0

RECRUIT_BY_WAVE = {
    1: ["veteran_deputy_01", "cook_01"],
    2: ["veteran_deputy_01", "cook_01", "stableman_01"],
    3: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01"],
    4: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01", "gardener_01"],
    5: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01", "gardener_01", "doctor_01"],
}
WEAPON_PLAN = {
    "veteran_deputy_01": "sword_shield",
    "cook_01": "polearm",
    "stableman_01": "bow",
    "blacksmith_01": "sword_shield",
    "engineer_01": "crossbow",
    "gardener_01": "polearm",
    "doctor_01": "bow",
}
ARMOR_PLAN = [
    (3, "veteran_deputy_01", "iron_helmet"),
    (3, "blacksmith_01", "iron_helmet"),
    (4, "veteran_deputy_01", "mail_chest"),
    (4, "veteran_deputy_01", "iron_bracers"),
    (4, "blacksmith_01", "iron_bracers"),
    (4, "veteran_deputy_01", "iron_greaves"),
    (5, "cook_01", "iron_helmet"),
    (5, "cook_01", "iron_greaves"),
]
DEVICE_PLAN = {
    1: ["wall_arrow_tower"],
    2: ["wall_arrow_tower"],
    3: ["wall_arrow_tower", "wall_ballista"],
    4: ["wall_arrow_tower", "wall_arrow_tower", "wall_ballista"],
    5: ["wall_arrow_tower", "wall_arrow_tower", "wall_arrow_tower", "wall_ballista"],
}

BASELINE_DEVICE_OVERRIDES: dict[str, dict[str, float]] = {}
BASELINE_WAVE_OVERRIDES = {
    1: {"raider_sword": {"hp": 32, "max_hp": 32}},
}

EXECUTION_PROFILES = {
    # These bands are sensitivity cohorts, not measured player distributions.
    "prepared": {
        "friendly_melee_contact": (3.5, 5.5),
        "friendly_ranged_contact": (1.5, 3.0),
        "enemy_melee_contact": (5.0, 7.0),
        "enemy_ranged_contact": (3.5, 5.5),
        "friendly_melee_hit": (0.84, 0.95),
        "friendly_ranged_hit": (0.78, 0.92),
        "device_hit": (0.90, 0.98),
        "enemy_melee_hit": (0.76, 0.90),
        "enemy_ranged_hit": (0.68, 0.84),
    },
    "ordinary": {
        "friendly_melee_contact": (5.0, 8.0),
        "friendly_ranged_contact": (2.5, 5.0),
        "enemy_melee_contact": (4.5, 7.0),
        "enemy_ranged_contact": (3.0, 5.0),
        "friendly_melee_hit": (0.78, 0.92),
        "friendly_ranged_hit": (0.72, 0.88),
        "device_hit": (0.86, 0.96),
        "enemy_melee_hit": (0.76, 0.92),
        "enemy_ranged_hit": (0.68, 0.86),
    },
    "late": {
        "friendly_melee_contact": (8.0, 13.0),
        "friendly_ranged_contact": (6.0, 10.0),
        "enemy_melee_contact": (3.5, 6.0),
        "enemy_ranged_contact": (2.5, 4.5),
        "friendly_melee_hit": (0.72, 0.88),
        "friendly_ranged_hit": (0.65, 0.82),
        "device_hit": (0.82, 0.94),
        "enemy_melee_hit": (0.80, 0.94),
        "enemy_ranged_hit": (0.72, 0.88),
    },
}


def load_json(relative_path: str) -> Any:
    with (PROJECT_ROOT / relative_path).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def damage_after_defense(raw_damage: float, defense: float, penetration: float) -> int:
    effective_defense = max(0.0, defense - penetration)
    return max(1, round(raw_damage * DEFENSE_CURVE_SCALE / (DEFENSE_CURVE_SCALE + effective_defense)))


def npc_combat_stats(wave: int) -> list[dict[str, Any]]:
    npc_defs = {row["id"]: row for row in load_json("data/npc_profiles.json")}
    weapon_defs = {row["id"]: row for row in load_json("data/weapon_defs.json")}
    armor_defs = {row["id"]: row for row in load_json("data/armor_defs.json")}
    output: list[dict[str, Any]] = []
    for npc_id in RECRUIT_BY_WAVE[wave]:
        npc = npc_defs[npc_id]
        weapon = weapon_defs[WEAPON_PLAN[npc_id]]
        equipped_armor = [
            armor_defs[armor_id]
            for unlock_wave, wearer_id, armor_id in ARMOR_PLAN
            if unlock_wave <= wave and wearer_id == npc_id
        ]
        strength = int(npc["stats"]["strength"])
        strength_multiplier = min(1.45, max(0.65, 1.0 + (strength - 5) * 0.08))
        equipment_attack = sum(float(item.get("attack_power_modifier", 0.0)) for item in equipped_armor)
        attack = (float(weapon["damage"]) + float(npc["combat_base"]["attack_power"]) + equipment_attack) * strength_multiplier
        equipment_defense = float(weapon.get("defense", 0.0)) + sum(float(item.get("armor_value", 0.0)) for item in equipped_armor)
        defense = float(npc["combat_base"]["defense"]) + equipment_defense + max(0, strength - 5) * 0.15
        penetration = (
            float(npc["combat_base"]["penetration"])
            + float(weapon.get("penetration", 0.0))
            + sum(float(item.get("penetration_modifier", 0.0)) for item in equipped_armor)
            + max(0, strength - 5) * 0.08
        )
        skill = int(npc["skills"].get(weapon["required_skill"], 0))
        equipment_speed_multiplier = max(
            0.2,
            1.0
            + float(weapon.get("attack_speed_modifier", 0.0))
            + sum(float(item.get("attack_speed_modifier", 0.0)) for item in equipped_armor),
        )
        speed_multiplier = (
            float(npc["combat_base"]["attack_speed_multiplier"])
            * (1.0 + skill / 100.0 * 0.35)
            * equipment_speed_multiplier
        )
        interval = max(0.25, float(weapon["attack_interval"]) / speed_multiplier)
        output.append(
            {
                "id": npc_id,
                "name": npc["name"],
                "kind": "npc",
                "role": "ranged" if weapon["type"] == "ranged" else "melee",
                "hp": float(npc["states"]["max_hp"]),
                "max_hp": float(npc["states"]["max_hp"]),
                "defense": defense,
                "damage": attack,
                "penetration": penetration,
                "interval": interval,
                "windup": interval * (0.42 if weapon["type"] == "ranged" else 0.36),
                "weapon": weapon["id"],
            }
        )
    return output


def device_stats(wave: int, implemented: bool) -> list[dict[str, Any]]:
    definitions = {row["id"]: row for row in load_json("data/defense_device_defs.json")["devices"]}
    output: list[dict[str, Any]] = []
    counts: dict[str, int] = {}
    for device_id in DEVICE_PLAN[wave]:
        counts[device_id] = counts.get(device_id, 0) + 1
        definition = copy.deepcopy(definitions[device_id])
        effect = definition["effect"]
        if not implemented:
            effect.update(BASELINE_DEVICE_OVERRIDES.get(device_id, {}))
        output.append(
            {
                "id": f"{device_id}_{counts[device_id]}",
                "device_id": device_id,
                "name": definition["name"],
                "kind": "device",
                "role": "ranged",
                "hp": float(definition["max_hp"]),
                "max_hp": float(definition["max_hp"]),
                "defense": float(definition["defense"]),
                "damage": float(effect["damage"]),
                "penetration": float(effect["penetration"]),
                "interval": float(effect["attack_interval"]),
                "windup": float(effect["attack_timing"]["release_authored_seconds"]),
                "weapon": device_id,
            }
        )
    return output


def enemy_stats(wave: int, implemented: bool = True) -> list[dict[str, Any]]:
    wave_row = load_json("data/enemy_waves.json")[wave - 1]
    output: list[dict[str, Any]] = []
    for group in wave_row["enemies"]:
        group = copy.deepcopy(group)
        if not implemented:
            group.update(BASELINE_WAVE_OVERRIDES.get(wave, {}).get(str(group["enemy_type_id"]), {}))
        for index in range(int(group["count"])):
            weapon_type = str(group["weapon_type"])
            role = "ranged" if weapon_type in {"bow", "crossbow"} else "melee"
            output.append(
                {
                    "id": f"{group['enemy_type_id']}_{index + 1}",
                    "type": group["enemy_type_id"],
                    "name": group["name"],
                    "kind": "enemy",
                    "role": role,
                    "hp": float(group["max_hp"]),
                    "max_hp": float(group["max_hp"]),
                    "defense": float(group["defense"]),
                    "damage": float(group["attack_power"]),
                    "penetration": float(group["penetration"]),
                    "interval": float(group["attack_interval"]),
                    "windup": float(group["attack_windup"]),
                    "weapon": weapon_type,
                }
            )
    return output


@dataclass
class Actor:
    id: str
    side: str
    kind: str
    role: str
    hp: float
    max_hp: float
    defense: float
    damage: float
    penetration: float
    interval: float
    windup: float
    contact_at: float
    hit_chance: float
    next_ready: float = 0.0
    impact_at: float | None = None
    cycle_end: float = 0.0
    target_id: str = ""
    damage_done: float = 0.0
    landed_hits: int = 0
    attacks_started: int = 0
    attacks_interrupted: int = 0
    windups_interrupted: int = 0

    @property
    def alive(self) -> bool:
        return self.hp > 0.0


def make_actor(source: dict[str, Any], side: str, contact_at: float, hit_chance: float) -> Actor:
    return Actor(
        id=str(source["id"]),
        side=side,
        kind=str(source["kind"]),
        role=str(source["role"]),
        hp=float(source["hp"]),
        max_hp=float(source["max_hp"]),
        defense=float(source["defense"]),
        damage=float(source["damage"]),
        penetration=float(source["penetration"]),
        interval=float(source["interval"]),
        windup=float(source["windup"]),
        contact_at=contact_at,
        hit_chance=hit_chance,
    )


def _choice(rng: random.Random, actors: list[Actor], weights: list[float]) -> Actor:
    return rng.choices(actors, weights=weights, k=1)[0]


def _select_target(rng: random.Random, actor: Actor, candidates: list[Actor]) -> Actor | None:
    alive = [candidate for candidate in candidates if candidate.alive]
    if not alive:
        return None
    if actor.side == "friendly":
        # Low-HP focus approximates nearest-target persistence without giving the
        # model perfect global focus fire.
        weights = [1.0 + (1.0 - candidate.hp / candidate.max_hp) * 1.5 for candidate in alive]
    else:
        # Current high-threat targeting makes deployed devices more likely, but
        # does not guarantee that every attacker can occupy the same position.
        weights = [1.75 if candidate.kind == "device" else 1.0 for candidate in alive]
    return _choice(rng, alive, weights)


def simulate_battle(
    wave: int,
    implemented: bool,
    execution: str,
    seed_value: int,
    tower_only: bool = False,
    ada_only: bool = False,
) -> dict[str, Any]:
    rng = random.Random(seed_value)
    profile = EXECUTION_PROFILES[execution]
    if tower_only:
        defenders_source = []
    elif ada_only:
        defenders_source = npc_combat_stats(wave)[:1]
    else:
        defenders_source = npc_combat_stats(wave)
    if not ada_only:
        defenders_source += device_stats(wave, implemented)
    attackers_source = enemy_stats(wave, implemented)
    defenders: list[Actor] = []
    for source in defenders_source:
        if source["kind"] == "device":
            contact_at = 0.0
            hit = rng.uniform(*profile["device_hit"])
        else:
            key = "friendly_ranged_contact" if source["role"] == "ranged" else "friendly_melee_contact"
            hit_key = "friendly_ranged_hit" if source["role"] == "ranged" else "friendly_melee_hit"
            contact_at = rng.uniform(*profile[key])
            hit = rng.uniform(*profile[hit_key])
        defenders.append(make_actor(source, "friendly", contact_at, hit))
    # Main hall is the only loss condition and begins taking fire when combatants
    # can no longer provide a valid target in this screening abstraction.
    hall_hp = 180.0 if wave < 5 else 250.0
    main_hall = Actor("main_hall", "friendly", "building", "static", hall_hp, hall_hp, 3.0, 0, 0, 999, 0, 0, 1.0)
    attackers: list[Actor] = []
    for source in attackers_source:
        key = "enemy_ranged_contact" if source["role"] == "ranged" else "enemy_melee_contact"
        hit_key = "enemy_ranged_hit" if source["role"] == "ranged" else "enemy_melee_hit"
        attackers.append(make_actor(source, "enemy", rng.uniform(*profile[key]), rng.uniform(*profile[hit_key])))

    # 0.1 s is smaller than every authored windup and keeps the screening matrix
    # cheap enough to rerun; exact impact/contact timing remains a Godot gate.
    dt = 0.10
    max_seconds = 180.0
    time_value = 0.0
    target_residence = {"npc": 0.0, "device": 0.0, "building": 0.0, "none": 0.0}
    while time_value < max_seconds and any(actor.alive for actor in attackers) and main_hall.alive:
        live_defenders = [actor for actor in defenders if actor.alive]
        available_targets = live_defenders if live_defenders else [main_hall]
        for actor in [*defenders, *attackers]:
            if not actor.alive or time_value + 1e-9 < actor.contact_at:
                continue
            if actor.impact_at is not None and time_value + 1e-9 >= actor.impact_at:
                opposing = attackers if actor.side == "friendly" else available_targets
                target = next((candidate for candidate in opposing if candidate.id == actor.target_id and candidate.alive), None)
                if target is not None and rng.random() <= actor.hit_chance:
                    dealt = min(target.hp, float(damage_after_defense(actor.damage, target.defense, actor.penetration)))
                    target.hp = max(0.0, target.hp - dealt)
                    actor.damage_done += dealt
                    actor.landed_hits += 1
                    # Both BASELINE and IMPLEMENTED preserve the authored damage
                    # reaction: any ordinary damaging hit resets windup/recovery.
                    # The implementation changes only the first-wave enemy HP breakpoint.
                    if target.kind in {"npc", "enemy"} and target.alive:
                        in_windup = target.impact_at is not None and time_value < target.impact_at
                        in_recovery = target.impact_at is None and time_value < target.cycle_end
                        interrupts = in_windup or in_recovery
                        if interrupts:
                            target.attacks_interrupted += 1
                            target.windups_interrupted += int(in_windup)
                            target.impact_at = None
                            target.target_id = ""
                            target.cycle_end = time_value
                            target.next_ready = time_value + dt
                actor.impact_at = None
                actor.target_id = ""
            if actor.impact_at is None and time_value + 1e-9 >= max(actor.next_ready, actor.cycle_end):
                opposing = attackers if actor.side == "friendly" else available_targets
                target = _select_target(rng, actor, opposing)
                if target is not None:
                    actor.attacks_started += 1
                    actor.target_id = target.id
                    actor.impact_at = time_value + actor.windup
                    actor.cycle_end = time_value + actor.interval
                    actor.next_ready = actor.cycle_end
        for enemy in attackers:
            if not enemy.alive:
                continue
            target_kind = "none"
            if enemy.target_id:
                target = next((candidate for candidate in [*defenders, main_hall] if candidate.id == enemy.target_id), None)
                if target is not None:
                    target_kind = target.kind
            target_residence[target_kind] += dt
        time_value += dt

    devices = [actor for actor in defenders if actor.kind == "device"]
    npcs = [actor for actor in defenders if actor.kind == "npc"]
    enemy_count = len(attackers)
    defeated = sum(not actor.alive for actor in attackers)
    friendly_damage = sum(actor.damage_done for actor in defenders)
    device_damage = sum(actor.damage_done for actor in devices)
    target_total = max(1e-9, sum(target_residence.values()))
    return {
        "wave": wave,
        "contract": "IMPLEMENTED" if implemented else "BASELINE",
        "execution": execution,
        "tower_only": tower_only,
        "ada_only": ada_only,
        "cleared": defeated == enemy_count,
        "main_hall_survived": main_hall.alive,
        "elapsed_seconds": time_value,
        "enemy_defeated": defeated,
        "enemy_count": enemy_count,
        "npc_missing_hp": sum(actor.max_hp - actor.hp for actor in npcs),
        "npc_unconscious": sum(not actor.alive for actor in npcs),
        "device_missing_hp": sum(actor.max_hp - actor.hp for actor in devices),
        "devices_destroyed": sum(not actor.alive for actor in devices),
        "main_hall_hp": main_hall.hp,
        "device_damage_share": device_damage / friendly_damage if friendly_damage > 0 else 0.0,
        "enemy_attack_interrupts": sum(actor.attacks_interrupted for actor in attackers),
        "enemy_windup_interrupts": sum(actor.windups_interrupted for actor in attackers),
        "npc_attack_interrupts": sum(actor.attacks_interrupted for actor in npcs),
        "enemy_device_target_share": target_residence["device"] / target_total,
    }


def breakpoint_table() -> pd.DataFrame:
    device_defs = {row["id"]: row for row in load_json("data/defense_device_defs.json")["devices"]}
    rows: list[dict[str, Any]] = []
    for wave in range(1, 6):
        for group in load_json("data/enemy_waves.json")[wave - 1]["enemies"]:
            for contract in ["BASELINE", "IMPLEMENTED"]:
                effective_group = copy.deepcopy(group)
                if contract == "BASELINE":
                    effective_group.update(BASELINE_WAVE_OVERRIDES.get(wave, {}).get(str(group["enemy_type_id"]), {}))
                for device_id in ["wall_arrow_tower", "wall_ballista"]:
                    definition = copy.deepcopy(device_defs[device_id])
                    damage = float(definition["effect"]["damage"])
                    if contract == "BASELINE":
                        damage = float(BASELINE_DEVICE_OVERRIDES.get(device_id, {}).get("damage", damage))
                    resolved = damage_after_defense(damage, float(effective_group["defense"]), float(definition["effect"]["penetration"]))
                    shots = math.ceil(float(effective_group["max_hp"]) / resolved)
                    rows.append(
                        {
                            "wave": wave,
                            "enemy_type": group["enemy_type_id"],
                            "count": int(group["count"]),
                            "enemy_hp": int(effective_group["max_hp"]),
                            "contract": contract,
                            "device": device_id,
                            "damage_per_hit": resolved,
                            "shots_to_kill": shots,
                            "overkill_efficiency": float(effective_group["max_hp"]) / float(shots * resolved),
                        }
                    )
    return pd.DataFrame(rows)


def input_curve_table() -> pd.DataFrame:
    rows: list[dict[str, Any]] = []
    for wave in range(1, 6):
        npc_raw_dps = sum(actor["damage"] / actor["interval"] for actor in npc_combat_stats(wave))
        for implemented in [False, True]:
            enemies = enemy_stats(wave, implemented)
            enemy_hp = sum(actor["max_hp"] for actor in enemies)
            enemy_raw_dps = sum(actor["damage"] / actor["interval"] for actor in enemies)
            devices = device_stats(wave, implemented)
            device_raw_dps = sum(actor["damage"] / actor["interval"] for actor in devices)
            rows.append(
                {
                    "wave": wave,
                    "contract": "IMPLEMENTED" if implemented else "BASELINE",
                    "enemy_hp": enemy_hp,
                    "enemy_raw_dps": enemy_raw_dps,
                    "npc_raw_dps": npc_raw_dps,
                    "device_raw_dps": device_raw_dps,
                    "device_raw_share": device_raw_dps / (npc_raw_dps + device_raw_dps),
                    "raw_clear_seconds": enemy_hp / (npc_raw_dps + device_raw_dps),
                }
            )
    return pd.DataFrame(rows)


def run_matrix(iterations: int) -> pd.DataFrame:
    rows: list[dict[str, Any]] = []
    for wave in range(1, 6):
        for implemented in [False, True]:
            for execution in EXECUTION_PROFILES:
                for iteration in range(iterations):
                    rows.append(simulate_battle(wave, implemented, execution, 121_000 + wave * 10_000 + iteration))
    for implemented in [False, True]:
        for execution in EXECUTION_PROFILES:
            for iteration in range(iterations):
                rows.append(simulate_battle(1, implemented, execution, 921_000 + iteration, tower_only=True))
                rows.append(simulate_battle(1, implemented, execution, 951_000 + iteration, ada_only=True))
    return pd.DataFrame(rows)


def summarize_matrix(matrix: pd.DataFrame) -> pd.DataFrame:
    group_columns = ["wave", "contract", "execution", "tower_only", "ada_only"]
    return (
        matrix.groupby(group_columns, as_index=False)
        .agg(
            model_clear_rate=("cleared", "mean"),
            duration_p10=("elapsed_seconds", lambda series: np.quantile(series, 0.10)),
            duration_p50=("elapsed_seconds", "median"),
            duration_p90=("elapsed_seconds", lambda series: np.quantile(series, 0.90)),
            npc_missing_hp_p50=("npc_missing_hp", "median"),
            npc_unconscious_p50=("npc_unconscious", "median"),
            device_missing_hp_p50=("device_missing_hp", "median"),
            devices_destroyed_p50=("devices_destroyed", "median"),
            device_damage_share_p50=("device_damage_share", "median"),
            enemy_interrupts_p50=("enemy_attack_interrupts", "median"),
            npc_interrupts_p50=("npc_attack_interrupts", "median"),
            enemy_device_target_share_p50=("enemy_device_target_share", "median"),
        )
        .sort_values(group_columns)
        .reset_index(drop=True)
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=300)
    parser.add_argument("--output-dir", type=Path, default=PROJECT_ROOT / "artifacts" / "analysis" / "t0121_r1")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    breakpoints = breakpoint_table()
    curve = input_curve_table()
    matrix = run_matrix(args.iterations)
    summary = summarize_matrix(matrix)
    breakpoints.to_csv(args.output_dir / "breakpoints.csv", index=False, encoding="utf-8-sig")
    curve.to_csv(args.output_dir / "input_curve.csv", index=False, encoding="utf-8-sig")
    matrix.to_csv(args.output_dir / "screening_samples.csv", index=False, encoding="utf-8-sig")
    summary.to_csv(args.output_dir / "screening_summary.csv", index=False, encoding="utf-8-sig")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
