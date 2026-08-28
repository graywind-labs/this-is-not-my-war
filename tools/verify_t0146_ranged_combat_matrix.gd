extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const COMBAT_ANIMATION_TIMING := preload("res://scripts/presentation/characters/CombatAnimationTiming.gd")
const FRIENDLY_VARIANTS := [
	{"npc_id": "stableman_01", "weapon": "bow"},
	{"npc_id": "engineer_01", "weapon": "crossbow"},
]
const ENEMY_VARIANTS := [
	{"wave": 3, "enemy_type_id": "raider_archer", "weapon": "bow", "mounted": false},
	{"wave": 4, "enemy_type_id": "raider_crossbow", "weapon": "crossbow", "mounted": false},
	{"wave": 5, "enemy_type_id": "raider_mounted_archer", "weapon": "bow", "mounted": true},
	# The current waves do not define a mounted crossbow archetype, but friendly
	# loadouts and the shared production wrapper support this legal combination.
	# Re-profile the existing mounted-ranged actor to lock that compatibility
	# branch without adding a new enemy type to game data.
	{"wave": 5, "enemy_type_id": "raider_mounted_archer", "weapon": "crossbow", "mounted": true, "compatibility_variant": true},
]
const EPSILON_SECONDS := 0.001
const PROJECTILE_STEP_SECONDS := 0.05

var _failures: PackedStringArray = []
var _sequence := 14600


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and npc_system != null, "T0146 combat/NPC dependencies missing")
	_check(equipment_system != null and resource_system != null and horse_system != null and time_system != null, "T0146 equipment/horse/time dependencies missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	for variant in FRIENDLY_VARIANTS:
		var npc_id := str(variant.get("npc_id", ""))
		var weapon := str(variant.get("weapon", ""))
		npc_system.set_npc_recruited(npc_id, true)
		resource_system.add_resource("item_%s" % weapon, 3)
		npc_system.set_npc_behavior_mode(npc_id, "work", "verify_t0146_equip", {"request_plan_reevaluation": false})
		var equipped: Dictionary = equipment_system.equip_npc_main_weapon(npc_id, weapon, "private")
		_check(bool(equipped.get("ok", false)), "T0146 could not equip %s on %s" % [weapon, npc_id])

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawn_result.get("ok", false)), "T0146 could not spawn friendly target")
	var target_enemy_id := _keep_one_enemy(combat_system)
	_check(not target_enemy_id.is_empty(), "T0146 friendly target missing")
	if target_enemy_id.is_empty():
		_finish()
		return

	# Foot ranged matrix.
	for variant in FRIENDLY_VARIANTS:
		await _verify_friendly_variant(combat_system, npc_system, str(variant.get("npc_id", "")), str(variant.get("weapon", "")), false, target_enemy_id)

	# Attack-speed increase must shorten the full bow period and accelerate the
	# same production animation by the reciprocal factor.
	var bow_before: Dictionary = combat_system._calculate_npc_attack_context("stableman_01", npc_system.get_npc("stableman_01"), npc_system.get_npc_state("stableman_01"))
	npc_system.increase_npc_skill("stableman_01", "弓", 12)
	var bow_after: Dictionary = combat_system._calculate_npc_attack_context("stableman_01", npc_system.get_npc("stableman_01"), npc_system.get_npc_state("stableman_01"))
	_check(float(bow_after.get("attack_interval", INF)) < float(bow_before.get("attack_interval", 0.0)), "T0146 bow skill did not shorten the authoritative period")
	_check(float(bow_after.get("attack_playback_multiplier", 0.0)) > float(bow_before.get("attack_playback_multiplier", INF)), "T0146 bow skill did not accelerate the production animation")

	# Real HorseSystem assignments drive the mounted matrix; no direct state-only
	# mount flag is used for this acceptance path.
	combat_system.debug_clear_enemies()
	var horse_ids: Array = horse_system.get_horse_ids()
	_check(horse_ids.size() >= FRIENDLY_VARIANTS.size(), "T0146 mounted matrix needs two living horses")
	if horse_ids.size() >= FRIENDLY_VARIANTS.size():
		for index in range(FRIENDLY_VARIANTS.size()):
			var variant: Dictionary = FRIENDLY_VARIANTS[index]
			var npc_id := str(variant.get("npc_id", ""))
			npc_system.set_npc_behavior_mode(npc_id, "work", "verify_t0146_mount_assign", {"request_plan_reevaluation": false})
			var assigned: Dictionary = horse_system.assign_horse_to_npc(npc_id, str(horse_ids[index]), "private")
			_check(bool(assigned.get("ok", false)), "T0146 could not assign horse to %s" % npc_id)
			npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_t0146_mount", {
				"state_changes": {"current_action": "combat_ready"},
				"request_plan_reevaluation": false,
			})
			var completed: Dictionary = horse_system.debug_complete_horse_transition(str(horse_ids[index]))
			_check(bool(completed.get("ok", false)), "T0146 could not complete mount pickup for %s" % npc_id)
			_check(bool(npc_system.get_npc_state(npc_id).get("combat_mounted", false)), "T0146 %s did not enter real mounted combat" % npc_id)

		spawn_result = combat_system.debug_spawn_wave(1, true)
		target_enemy_id = _keep_one_enemy(combat_system)
		for variant in FRIENDLY_VARIANTS:
			await _verify_friendly_variant(combat_system, npc_system, str(variant.get("npc_id", "")), str(variant.get("weapon", "")), true, target_enemy_id)

	# Enemy foot/mounted bow/crossbow matrix, including the supported mounted
	# crossbow compatibility profile that is not currently present in wave data.
	for raw_variant in ENEMY_VARIANTS:
		await _verify_enemy_variant(combat_system, npc_system, raw_variant as Dictionary)

	# A missing production wrapper must fail closed. This explicitly guards the
	# removed body-height compatibility shot from returning later.
	var projectile_count_before: int = combat_system.get_active_projectile_snapshots().size()
	var rejected: Dictionary = combat_system._spawn_combat_projectile(
		"friendly",
		"missing_formal_actor",
		"missing",
		"bow",
		{"type": "enemy", "id": "missing_target", "position": Vector3(0.0, 0.0, 8.0)},
		{"weapon_id": "bow", "attack_sequence": 14699},
		{}
	)
	var rejected_snapshot: Dictionary = combat_system.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(rejected.is_empty(), "T0146 missing formal wrapper still created a body-height projectile")
	_check(combat_system.get_active_projectile_snapshots().size() == projectile_count_before, "T0146 rejected release changed the active projectile set")
	_check(str(rejected_snapshot.get("status", "")) == "release_rejected", "T0146 rejected release did not publish an observable failure")

	combat_system.debug_clear_enemies()
	await process_frame
	_finish()


func _verify_friendly_variant(combat_system: Node, npc_system: Node, npc_id: String, weapon: String, mounted: bool, enemy_id: String) -> void:
	combat_system._clear_combat_projectiles("verify_t0146_friendly_variant")
	_move_all_npcs_except(npc_system, npc_id, Vector3(40.0, 0.0, -40.0))
	_set_npc_position(npc_system, npc_id, Vector3.ZERO)
	_set_enemy_fixture(combat_system, enemy_id, Vector3(0.0, 0.0, 8.0), 10000)
	npc_system.update_npc_state(npc_id, {
		"behavior_mode": "combat",
		"combat_mode": "combat",
		"combat_mounted": mounted,
		"current_action": "combat_ready",
		"combat_attack_cooldown": 0.0,
		"combat_attack_phase": "idle",
		"combat_attack_elapsed_seconds": 0.0,
		"combat_attack_cycle_seconds": 0.0,
		"combat_attack_impact_seconds": 0.0,
		"combat_attack_target_enemy_id": "",
		"combat_attack_impact_committed": false,
	})
	await process_frame
	var context: Dictionary = combat_system._calculate_npc_attack_context(npc_id, npc_system.get_npc(npc_id), npc_system.get_npc_state(npc_id))
	var timing: Dictionary = context.get("animation_timing", {}) if context.get("animation_timing", {}) is Dictionary else {}
	var impact_seconds := float(timing.get("impact_seconds", 0.0))
	var hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var before: Dictionary = combat_system._advance_single_npc_combat_attack(npc_id, maxf(0.001, impact_seconds - EPSILON_SECONDS))
	await process_frame
	_check(combat_system.get_active_projectile_snapshots().is_empty(), "T0146 %s %s released before authored frame" % ["mounted" if mounted else "foot", weapon])
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_before, "T0146 friendly %s dealt release-time damage" % weapon)
	_check(int(before.get("attack_count", -1)) == 0, "T0146 friendly %s reported early attack" % weapon)
	var windup_art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(npc_id)
	_check(str(windup_art.get("current_state", "")) == ("mounted_attack" if mounted else "attack"), "T0146 friendly %s used wrong foot/mounted animation" % weapon)
	_check(absf(float(windup_art.get("combat_attack_playback_multiplier", 0.0)) - float(timing.get("playback_multiplier", 1.0))) <= 0.02, "T0146 friendly %s animation speed drifted from period" % weapon)
	var target_facing: Vector3 = windup_art.get("target_facing_direction", Vector3.ZERO)
	_check(target_facing.dot(Vector3.BACK) >= 0.995, "T0146 friendly %s did not face target during windup" % weapon)

	var impact: Dictionary = combat_system._advance_single_npc_combat_attack(npc_id, EPSILON_SECONDS * 2.0)
	var attacks: Array = impact.get("attacks", [])
	var attack: Dictionary = attacks[0] if not attacks.is_empty() else {}
	var projectiles: Array[Dictionary] = combat_system.get_active_projectile_snapshots()
	_check(projectiles.size() == 1, "T0146 friendly %s did not create exactly one projectile" % weapon)
	var projectile: Dictionary = projectiles[0] if projectiles.size() == 1 else {}
	_check(str(projectile.get("release_origin_source", "")) in ["formal_loaded_arrow", "formal_loaded_bolt"], "T0146 friendly %s did not use the formal weapon origin" % weapon)
	_check(bool(projectile.get("source_mounted", not mounted)) == mounted, "T0146 friendly %s lost mounted origin state" % weapon)
	_check(not str(projectile.get("release_origin_node_path", "")).is_empty(), "T0146 friendly %s has no loaded projectile node path" % weapon)
	_check(str(projectile.get("attack_id", "")) == str(attack.get("attack_id", "")), "T0146 friendly %s timeline/projectile ID mismatch" % weapon)
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_before, "T0146 friendly %s damaged at release" % weapon)
	_advance_until_resolved(combat_system)
	var result: Dictionary = combat_system.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(str(result.get("status", "")) == "hit", "T0146 friendly %s did not physically hit: %s" % [weapon, JSON.stringify(result)])
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) < hp_before, "T0146 friendly %s physical hit applied no damage" % weapon)


func _verify_enemy_variant(combat_system: Node, npc_system: Node, variant: Dictionary) -> void:
	combat_system._clear_combat_projectiles("verify_t0146_enemy_variant")
	var wave_number := int(variant.get("wave", 0))
	var spawn: Dictionary = combat_system.spawn_wave(wave_number, true, "verify_t0146_enemy_matrix", "front_gate")
	_check(bool(spawn.get("ok", false)), "T0146 could not spawn wave %d" % wave_number)
	var enemy_id := _find_enemy_by_type(combat_system, str(variant.get("enemy_type_id", "")))
	_check(not enemy_id.is_empty(), "T0146 enemy variant missing: %s" % JSON.stringify(variant))
	if enemy_id.is_empty():
		return
	for raw_id in combat_system.get_active_enemy_ids():
		if str(raw_id) != enemy_id:
			combat_system._remove_enemy_from_combat(str(raw_id))

	var weapon := str(variant.get("weapon", ""))
	var mounted := bool(variant.get("mounted", false))
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["weapon_type"] = weapon
	enemy["unit_type"] = "mounted_ranged" if mounted else ("archer" if weapon == "bow" else "crossbowman")
	enemy["attack_power"] = 4
	enemy["penetration"] = 1.0
	# Exercise a boosted enemy period so release time and animation speed are
	# verified under the same scaling rule rather than only at authored speed.
	var authored_cycle := float(COMBAT_ANIMATION_TIMING.WEAPON_TIMINGS[weapon].get("authored_cycle_seconds", 1.0))
	enemy["attack_interval"] = authored_cycle * 0.72
	enemy["attack_speed"] = 1.0 / float(enemy.get("attack_interval", 1.0))
	combat_system._cancel_enemy_attack_timeline(enemy)
	_set_active_enemy(combat_system, enemy_id, enemy)
	_set_enemy_fixture(combat_system, enemy_id, Vector3(0.0, 0.0, 7.0), 10000)
	_move_all_npcs_except(npc_system, "stableman_01", Vector3(40.0, 0.0, -40.0))
	_set_npc_position(npc_system, "stableman_01", Vector3.ZERO)
	npc_system.update_npc_state("stableman_01", {"hp": 1000, "max_hp": 1000, "unconscious": false, "escaped": false})
	var target := {"type": "npc", "id": "stableman_01", "name": "托马", "position": Vector3.ZERO, "distance": 7.0}
	enemy = combat_system.get_enemy(enemy_id)
	enemy["target"] = target.duplicate(true)
	_set_active_enemy(combat_system, enemy_id, enemy)
	combat_system._refresh_enemy_node(enemy_id)
	await process_frame

	var timing := COMBAT_ANIMATION_TIMING.get_timing(weapon, float(enemy.get("attack_interval", 1.0)), mounted)
	var impact_seconds := float(timing.get("impact_seconds", 0.0))
	var npc_hp_before := int(npc_system.get_npc_state("stableman_01").get("hp", 0))
	var before: Dictionary = combat_system._advance_enemy_attack(enemy, target, maxf(0.001, impact_seconds - EPSILON_SECONDS))
	_set_active_enemy(combat_system, enemy_id, enemy)
	combat_system._refresh_enemy_node(enemy_id)
	await process_frame
	_check(combat_system.get_active_projectile_snapshots().is_empty(), "T0146 enemy %s/%s released before authored frame" % [weapon, "mounted" if mounted else "foot"])
	_check(int(before.get("attack_count", -1)) == 0, "T0146 enemy %s reported early attack" % weapon)
	var enemy_art := _enemy_art_snapshot(combat_system, enemy_id)
	_check(str(enemy_art.get("current_state", "")) == ("mounted_attack" if mounted else "attack"), "T0146 enemy %s used wrong foot/mounted animation" % weapon)
	_check(absf(float(enemy_art.get("combat_attack_playback_multiplier", 0.0)) - float(timing.get("playback_multiplier", 1.0))) <= 0.02, "T0146 enemy %s animation speed drifted from boosted period" % weapon)
	var target_facing: Vector3 = enemy_art.get("target_facing_direction", Vector3.ZERO)
	_check(target_facing.dot(Vector3.FORWARD) >= 0.995, "T0146 enemy %s did not face target during windup" % weapon)

	var impact: Dictionary = combat_system._advance_enemy_attack(enemy, target, EPSILON_SECONDS * 2.0)
	_set_active_enemy(combat_system, enemy_id, enemy)
	var attacks: Array = impact.get("attacks", [])
	var attack: Dictionary = attacks[0] if not attacks.is_empty() else {}
	var projectiles: Array[Dictionary] = combat_system.get_active_projectile_snapshots()
	_check(projectiles.size() == 1, "T0146 enemy %s did not create exactly one projectile" % weapon)
	var projectile: Dictionary = projectiles[0] if projectiles.size() == 1 else {}
	_check(str(projectile.get("release_origin_source", "")) in ["formal_loaded_arrow", "formal_loaded_bolt"], "T0146 enemy %s did not use formal weapon origin" % weapon)
	_check(bool(projectile.get("source_mounted", not mounted)) == mounted, "T0146 enemy %s lost mounted origin state" % weapon)
	_check(str(projectile.get("attack_id", "")) == str(attack.get("attack_id", "")), "T0146 enemy %s timeline/projectile ID mismatch" % weapon)
	_check(int(npc_system.get_npc_state("stableman_01").get("hp", 0)) == npc_hp_before, "T0146 enemy %s damaged at release" % weapon)
	_advance_until_resolved(combat_system)
	var result: Dictionary = combat_system.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(str(result.get("status", "")) == "hit", "T0146 enemy %s did not physically hit: %s" % [weapon, JSON.stringify(result)])
	_check(int(npc_system.get_npc_state("stableman_01").get("hp", 0)) < npc_hp_before, "T0146 enemy %s physical hit applied no damage" % weapon)


func _keep_one_enemy(combat_system: Node) -> String:
	var ids: Array = combat_system.get_active_enemy_ids()
	if ids.is_empty():
		return ""
	var keep := str(ids[0])
	for index in range(1, ids.size()):
		combat_system._remove_enemy_from_combat(str(ids[index]))
	return keep


func _find_enemy_by_type(combat_system: Node, enemy_type_id: String) -> String:
	for raw_id in combat_system.get_active_enemy_ids():
		var enemy_id := str(raw_id)
		if str(combat_system.get_enemy(enemy_id).get("enemy_type_id", "")) == enemy_type_id:
			return enemy_id
	return ""


func _enemy_art_snapshot(combat_system: Node, enemy_id: String) -> Dictionary:
	for entry in combat_system.debug_get_enemy_art_snapshots():
		if str(entry.get("enemy_id", "")) == enemy_id:
			return entry.get("art", {}) as Dictionary
	return {}


func _set_enemy_fixture(combat_system: Node, enemy_id: String, position: Vector3, hp: int) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["alive"] = true
	_set_active_enemy(combat_system, enemy_id, enemy)
	var paths: Dictionary = combat_system.get("_enemy_nodes")
	var node := combat_system.get_node_or_null(paths.get(enemy_id, NodePath())) as Node3D if paths.has(enemy_id) else null
	if node != null:
		node.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _set_active_enemy(combat_system: Node, enemy_id: String, enemy: Dictionary) -> void:
	var active: Dictionary = combat_system.get("_active_enemies")
	active[enemy_id] = enemy
	combat_system.set("_active_enemies", active)


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	var node := npc_system.get_node_or_null(paths.get(npc_id, NodePath())) as Node3D if paths.has(npc_id) else null
	if node != null:
		node.global_position = position


func _move_all_npcs_except(npc_system: Node, keep_npc_id: String, base_position: Vector3) -> void:
	var index := 0
	for npc_id in npc_system.get_npc_ids():
		if npc_id == keep_npc_id:
			continue
		_set_npc_position(npc_system, npc_id, base_position + Vector3(float(index) * 2.0, 0.0, 0.0))
		index += 1


func _advance_until_resolved(combat_system: Node) -> void:
	for _step in range(120):
		if combat_system.get_active_projectile_snapshots().is_empty():
			return
		combat_system.debug_advance_combat_projectiles(PROJECTILE_STEP_SECONDS)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0146_RANGED_COMBAT_MATRIX PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0146_RANGED_COMBAT_MATRIX FAIL count=%d" % _failures.size())
	quit(1)
