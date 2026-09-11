extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const BUILDING_IDS := ["front_gate", "warehouse", "main_hall"]
const EXPECTED_RATIOS := [0.90, 0.76, 0.62, 0.48, 0.34, 0.20]

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and time_system != null, "T0220 combat/time systems missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(3, true)
	_check(bool(started.get("ok", false)), "T0220 wave 3 failed to spawn: %s" % started)
	await physics_frame

	var ranged_enemy_id := ""
	for raw_enemy_id in combat_system.get_active_enemy_ids():
		var enemy_id := str(raw_enemy_id)
		if str(combat_system.get_enemy(enemy_id).get("weapon_type", "")) == "bow":
			ranged_enemy_id = enemy_id
			break
	_check(not ranged_enemy_id.is_empty(), "T0220 spawned no ranged enemy")
	if ranged_enemy_id.is_empty():
		combat_system.clear_spawned_enemies()
		_finish()
		return

	for raw_enemy_id in combat_system.get_active_enemy_ids().duplicate():
		var enemy_id := str(raw_enemy_id)
		if enemy_id != ranged_enemy_id:
			combat_system._remove_enemy_from_combat(enemy_id)
	await process_frame
	var enemy: Dictionary = combat_system.get_enemy(ranged_enemy_id)
	var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(ranged_enemy_id, NodePath())) as ActorMotionBody
	_check(actor != null, "T0220 ranged actor missing")

	for building_id in BUILDING_IDS:
		var target: Dictionary = combat_system._make_building_target(building_id)
		_check(not target.is_empty(), "T0220 building target missing: %s" % building_id)
		if target.is_empty():
			continue
		var candidates: Array[Dictionary] = combat_system._get_enemy_attack_position_candidates(ranged_enemy_id, enemy, target)
		_verify_multirank_candidates(combat_system, enemy, building_id, candidates)
		if actor != null:
			await _verify_near_enemy_prefers_inner_row(combat_system, ranged_enemy_id, enemy, actor, target, candidates)

	_verify_ranged_weapon_variants(combat_system, ranged_enemy_id, enemy)
	_verify_melee_and_device_capacity_contracts(combat_system, ranged_enemy_id, enemy)
	combat_system.clear_spawned_enemies()
	_finish()


func _verify_multirank_candidates(combat_system: Node, enemy: Dictionary, building_id: String, candidates: Array[Dictionary]) -> void:
	var expected_per_row := 5 if building_id == "front_gate" else 32
	_check(candidates.size() == expected_per_row * EXPECTED_RATIOS.size(), "T0220/T0233 %s expected %d ranged positions, got %d" % [building_id, expected_per_row * EXPECTED_RATIOS.size(), candidates.size()])
	var rows: Dictionary = {}
	for candidate in candidates:
		var row_index := int(candidate.get("range_row_index", -1))
		var row_candidates := rows.get(row_index, []) as Array
		row_candidates.append(candidate)
		rows[row_index] = row_candidates
		_check(int(candidate.get("range_row_count", 0)) == EXPECTED_RATIOS.size(), "T0220/T0233 %s candidate omitted expanded-row metadata: %s" % [building_id, candidate])
		_check(str(candidate.get("slot_id", "")).contains("row_"), "T0220 %s ranged slot id has no row identity: %s" % [building_id, candidate])
	_check(rows.size() == EXPECTED_RATIOS.size(), "T0220/T0233 %s expected %d distinct rows, got %s" % [building_id, EXPECTED_RATIOS.size(), rows.keys()])
	var previous_standoff := INF
	var enemy_radius: float = combat_system._get_enemy_attack_position_radius(enemy)
	var safety: float = float(combat_system._formal_attack_position_policy.get("safety_margin", 0.08))
	for row_index in range(EXPECTED_RATIOS.size()):
		var row_candidates := rows.get(row_index, []) as Array
		_check(row_candidates.size() == expected_per_row, "T0220 %s row %d expected %d positions, got %d" % [building_id, row_index, expected_per_row, row_candidates.size()])
		if row_candidates.is_empty():
			continue
		var first := row_candidates[0] as Dictionary
		var ratio := float(first.get("range_row_ratio", -1.0))
		var standoff := float(first.get("standoff", -1.0))
		_check(is_equal_approx(ratio, EXPECTED_RATIOS[row_index]), "T0220 %s row %d ratio mismatch: %.3f" % [building_id, row_index, ratio])
		_check(standoff < float(enemy.get("attack_range", 0.0)), "T0220 %s row %d lies outside weapon range: %.3f" % [building_id, row_index, standoff])
		if row_index > 0:
			_check(previous_standoff > standoff, "T0220 %s row depths are not outer-to-inner: %.3f <= %.3f" % [building_id, previous_standoff, standoff])
			_check(previous_standoff - standoff + 0.001 >= enemy_radius * 2.0 + safety, "T0220 %s adjacent rows physically overlap: gap=%.3f" % [building_id, previous_standoff - standoff])
		previous_standoff = standoff


func _verify_near_enemy_prefers_inner_row(
	combat_system: Node,
	enemy_id: String,
	enemy: Dictionary,
	actor: ActorMotionBody,
	target: Dictionary,
	candidates: Array[Dictionary]
) -> void:
	combat_system.debug_release_enemy_attack_position(enemy_id, "t0220_reposition")
	var inner_resolved: Dictionary = {}
	for candidate in candidates:
		if int(candidate.get("range_row_index", -1)) != EXPECTED_RATIOS.size() - 1:
			continue
		inner_resolved = combat_system._resolve_reachable_enemy_attack_position(enemy_id, candidate)
		if not inner_resolved.is_empty():
			break
	_check(not inner_resolved.is_empty(), "T0220 no inner-row candidate is reachable for %s" % target.get("id", ""))
	if inner_resolved.is_empty():
		return
	var inner_position: Vector3 = inner_resolved.get("position", actor.global_position)
	actor.cancel_motion("superseded")
	actor.global_position = inner_position
	actor.velocity = Vector3.ZERO
	enemy["position"] = inner_position
	combat_system._active_enemies[enemy_id] = enemy
	var assigned: Dictionary = combat_system._ensure_enemy_attack_position(enemy_id, enemy, target, true)
	var expected_status := "guiding" if str(combat_system._formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2" else "reserved"
	_check(str(assigned.get("attack_position_status", "")) == expected_status, "T0220 near enemy failed to acquire %s guidance for %s: %s" % [expected_status, target.get("id", ""), assigned])
	_check(int(assigned.get("attack_position_range_row_index", -1)) == EXPECTED_RATIOS.size() - 1, "T0220/T0233 enemy already near %s retreated to a farther row: %s" % [target.get("id", ""), assigned])
	_check(is_equal_approx(float(assigned.get("attack_position_range_row_ratio", -1.0)), EXPECTED_RATIOS[-1]), "T0220/T0233 %s near assignment did not expose inner-row ratio" % target.get("id", ""))
	combat_system.debug_release_enemy_attack_position(enemy_id, "t0220_next_building")


func _verify_ranged_weapon_variants(combat_system: Node, enemy_id: String, base_enemy: Dictionary) -> void:
	var target: Dictionary = combat_system._make_building_target("front_gate")
	var variants: Array[Dictionary] = [
		{"weapon_type": "bow", "unit_type": "archer", "attack_range": 9.5},
		{"weapon_type": "crossbow", "unit_type": "crossbowman", "attack_range": 11.5},
		{"weapon_type": "bow", "unit_type": "mounted_ranged", "attack_range": 10.0}
	]
	for variant in variants:
		var enemy := base_enemy.duplicate(true)
		for key in variant.keys():
			enemy[key] = variant[key]
		var candidates: Array[Dictionary] = combat_system._get_enemy_attack_position_candidates(enemy_id, enemy, target)
		var guided_schema := str(combat_system._formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2"
		var mounted_variant := str(variant.get("unit_type", "")) == "mounted_ranged"
		_check(not candidates.is_empty(), "T0220/T0233 %s/%s received no gate guidance zones" % [variant.get("unit_type", ""), variant.get("weapon_type", "")])
		if not guided_schema or not mounted_variant:
			_check(candidates.size() == 30, "T0220/T0233 %s/%s did not receive 30 gate positions" % [variant.get("unit_type", ""), variant.get("weapon_type", "")])
		var row_ids: Dictionary = {}
		for candidate in candidates:
			row_ids[int(candidate.get("range_row_index", -1))] = true
			if guided_schema:
				_check(str(candidate.get("guidance_class", "")) == "ranged", "T0220/T0243 ranged variant lost guidance class: %s" % candidate)
		# Mounted bodies use larger circles, so T0243 deliberately removes rows that
		# would overlap vertically; foot ranged variants retain all authored rows.
		if not guided_schema or not mounted_variant:
			_check(row_ids.size() == EXPECTED_RATIOS.size(), "T0220/T0233 %s/%s did not receive all expanded rows" % [variant.get("unit_type", ""), variant.get("weapon_type", "")])


func _verify_melee_and_device_capacity_contracts(combat_system: Node, enemy_id: String, base_enemy: Dictionary) -> void:
	var melee := base_enemy.duplicate(true)
	melee["weapon_type"] = "sword_shield"
	melee["unit_type"] = "melee_infantry"
	melee["attack_range"] = 1.5
	var gate_target: Dictionary = combat_system._make_building_target("front_gate")
	var melee_candidates: Array[Dictionary] = combat_system._get_enemy_attack_position_candidates(enemy_id, melee, gate_target)
	_check(melee_candidates.size() == 5, "T0220 melee gate capacity changed: %d" % melee_candidates.size())
	for candidate in melee_candidates:
		_check(int(candidate.get("range_row_count", 0)) == 1, "T0220 melee candidate unexpectedly became multirank")
		_check(not str(candidate.get("slot_id", "")).contains("row_"), "T0220 melee slot identity changed: %s" % candidate)

	var device_target := {
		"type": "defense_device",
		"id": "t0220_device",
		"position": gate_target.get("position", Vector3.ZERO),
		"facing_direction": Vector3.FORWARD,
		"contact_radius": 0.6,
		"host_proxy_hit_radius": 1.2
	}
	var ranged_device_candidates: Array[Dictionary] = combat_system._get_enemy_attack_position_candidates(enemy_id, base_enemy, device_target)
	_check(not ranged_device_candidates.is_empty(), "T0220 defense-device candidates disappeared")
	for candidate in ranged_device_candidates:
		_check(int(candidate.get("range_row_count", 0)) == EXPECTED_RATIOS.size(), "T0220/T0233 defense-device positions did not receive expanded rows")
		_check(str(candidate.get("slot_id", "")).contains("row_"), "T0220/T0233 defense-device row identity missing: %s" % candidate)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0220_ENEMY_RANGED_MULTIRANK_BUILDING_POSITIONS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
