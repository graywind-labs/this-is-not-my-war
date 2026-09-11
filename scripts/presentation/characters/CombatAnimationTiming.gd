class_name CombatAnimationTiming
extends RefCounted


# Shared timing contract for the four NPCDevLab-approved combat animations.
# `authored_cycle_seconds` describes the unscaled visible sequence. The impact
# point is the first frame where the weapon reaches the target or the projectile
# leaves the weapon. CombatSystem and ChibiCharacterPilot both consume this file
# so gameplay timing cannot drift away from the approved presentation.
const DEFAULT_WEAPON_ID := "sword_shield"
const MIN_CYCLE_SECONDS := 0.1
const WEAPON_TIMINGS := {
	"sword_shield": {
		"authored_cycle_seconds": 1.3333334,
		"impact_authored_seconds": 0.2666667,
		"mounted_impact_authored_seconds": 0.0666667,
		"impact_kind": "melee_contact",
	},
	"polearm": {
		"authored_cycle_seconds": 1.3333334,
		"impact_authored_seconds": 0.6666667,
		"mounted_impact_authored_seconds": 0.6333334,
		"impact_kind": "melee_contact",
	},
	"bow": {
		"authored_cycle_seconds": 2.9066668,
		"impact_authored_seconds": 1.6933334,
		"impact_kind": "projectile_release",
	},
	"crossbow": {
		"authored_cycle_seconds": 4.2666667,
		"impact_authored_seconds": 1.92,
		"impact_kind": "projectile_release",
	},
}


static func normalize_weapon_id(raw_weapon_id: String) -> String:
	var weapon_id := raw_weapon_id.strip_edges()
	return weapon_id if WEAPON_TIMINGS.has(weapon_id) else DEFAULT_WEAPON_ID


static func get_timing(raw_weapon_id: String, requested_cycle_seconds: float, mounted: bool = false) -> Dictionary:
	var weapon_id := normalize_weapon_id(raw_weapon_id)
	var source: Dictionary = WEAPON_TIMINGS[weapon_id]
	var authored_cycle_seconds := maxf(
		MIN_CYCLE_SECONDS,
		float(source.get("authored_cycle_seconds", 1.3333334))
	)
	var impact_authored_seconds := clampf(
		float(source.get("mounted_impact_authored_seconds", source.get("impact_authored_seconds", authored_cycle_seconds * 0.5))) if mounted else float(source.get("impact_authored_seconds", authored_cycle_seconds * 0.5)),
		0.0,
		authored_cycle_seconds
	)
	var cycle_seconds := maxf(MIN_CYCLE_SECONDS, requested_cycle_seconds)
	var impact_ratio := clampf(impact_authored_seconds / authored_cycle_seconds, 0.0, 1.0)
	return {
		"weapon_id": weapon_id,
		"authored_cycle_seconds": authored_cycle_seconds,
		"impact_authored_seconds": impact_authored_seconds,
		"impact_ratio": impact_ratio,
		"cycle_seconds": cycle_seconds,
		"impact_seconds": cycle_seconds * impact_ratio,
		"recovery_seconds": cycle_seconds * (1.0 - impact_ratio),
		"playback_multiplier": authored_cycle_seconds / cycle_seconds,
		"impact_kind": str(source.get("impact_kind", "melee_contact")),
		"mounted": mounted,
	}
