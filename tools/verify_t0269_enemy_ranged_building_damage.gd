extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const BUILDING_IDS := ["front_gate", "warehouse", "main_hall"]

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	_check(combat != null and npc_system != null and building_system != null, "T0269 dependencies missing")
	if not _failures.is_empty():
		_finish([])
		return

	# Keep residents outside the unified awareness radius so the production
	# selector reaches the strategic building sequence without a fake target API.
	for index in range(npc_system.get_npc_ids().size()):
		var npc_id := str(npc_system.get_npc_ids()[index])
		var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(-90.0 + float(index), 0.04, -90.0)

	var spawned: Dictionary = combat.debug_run_formal_dynamic_wave_slice(5, true)
	_check(bool(spawned.get("ok", false)), "T0269 formal fifth wave failed: %s" % spawned)
	var ranged_enemy_ids: Dictionary = {}
	for raw_enemy_id in combat.get_active_enemy_ids():
		var enemy_id := str(raw_enemy_id)
		var weapon_type := str(combat.get_enemy(enemy_id).get("weapon_type", ""))
		if weapon_type in ["bow", "crossbow"] and not ranged_enemy_ids.has(weapon_type):
			ranged_enemy_ids[weapon_type] = enemy_id
	_check(ranged_enemy_ids.has("bow"), "T0269 formal archer missing")
	_check(ranged_enemy_ids.has("crossbow"), "T0269 formal crossbowman missing")
	if not ranged_enemy_ids.has("bow") or not ranged_enemy_ids.has("crossbow"):
		_finish([])
		return
	for raw_enemy_id in combat.get_active_enemy_ids().duplicate():
		var enemy_id := str(raw_enemy_id)
		if not ranged_enemy_ids.values().has(enemy_id):
			combat._remove_enemy_from_combat(enemy_id)
	await process_frame
	await physics_frame

	var diagnostics: Array[Dictionary] = []
	for building_id in BUILDING_IDS:
		for weapon_type in ["bow", "crossbow"]:
			var active_enemy_id := str(ranged_enemy_ids.get(weapon_type, ""))
			for raw_other_id in ranged_enemy_ids.values():
				var other_id := str(raw_other_id)
				var other: Dictionary = combat.get_enemy(other_id)
				other["alive"] = other_id == active_enemy_id
				combat._active_enemies[other_id] = other
			var item := await _verify_natural_ranged_building_hit(
				combat,
				building_system,
				active_enemy_id,
				building_id
			)
			diagnostics.append(item)
		if building_id != "main_hall":
			var building: Dictionary = building_system.get_building(building_id)
			building_system.apply_damage_to_building(
				building_id,
				maxi(1, int(building.get("hp", 1))),
				"t0269_stage_setup",
				"private",
				{"attacker_name": "T0269 阶段夹具"}
			)
			await process_frame
			await physics_frame

	combat.clear_spawned_enemies()
	_finish(diagnostics)


func _verify_natural_ranged_building_hit(
	combat: Node,
	building_system: Node,
	enemy_id: String,
	building_id: String
) -> Dictionary:
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	var actor := root.get_node_or_null(combat._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	var target: Dictionary = combat._make_building_target(building_id)
	_check(actor != null, "T0269 formal archer actor missing for %s" % building_id)
	_check(not target.is_empty(), "T0269 target missing for %s" % building_id)
	if actor == null or target.is_empty():
		return {"building_id": building_id, "setup_failed": true}

	combat.debug_release_enemy_attack_position(enemy_id, "t0269_reposition_%s" % building_id)
	var resolved_position := {}
	var candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(enemy_id, enemy, target)
	for candidate in candidates:
		if int(candidate.get("range_row_index", -1)) != 2:
			continue
		resolved_position = combat._resolve_reachable_enemy_attack_position(enemy_id, candidate)
		if not resolved_position.is_empty():
			break
	if resolved_position.is_empty():
		for candidate in candidates:
			resolved_position = combat._resolve_reachable_enemy_attack_position(enemy_id, candidate)
			if not resolved_position.is_empty():
				break
	_check(not resolved_position.is_empty(), "T0269 no reachable ranged attack position for %s" % building_id)
	if resolved_position.is_empty():
		return {"building_id": building_id, "position_failed": true}

	actor.cancel_motion("superseded")
	actor.global_position = resolved_position.get("position", actor.global_position)
	actor.velocity = Vector3.ZERO
	enemy["position"] = actor.global_position
	enemy["target"] = target.duplicate(true)
	enemy["current_action"] = "combat_ready"
	combat._cancel_enemy_attack_timeline(enemy)
	combat._active_enemies[enemy_id] = enemy
	combat._mark_formal_dynamic_contact(enemy_id, target)
	combat._refresh_enemy_node(enemy_id)
	await process_frame
	await physics_frame

	var hp_before := int(building_system.get_building(building_id).get("hp", 0))
	var selected := false
	var released := false
	var damage_step := -1
	for step_index in range(100):
		combat.debug_step_enemy_ai(0.1)
		var current_enemy: Dictionary = combat.get_enemy(enemy_id)
		var current_target: Dictionary = current_enemy.get("target", {}) if current_enemy.get("target", {}) is Dictionary else {}
		if str(current_target.get("type", "")) == "building" and str(current_target.get("id", "")) == building_id:
			selected = true
		for projectile in combat.get_active_projectile_snapshots():
			var released_target: Dictionary = projectile.get("target_at_release", {}) if projectile.get("target_at_release", {}) is Dictionary else {}
			if str(projectile.get("source_id", "")) == enemy_id and str(released_target.get("id", "")) == building_id:
				released = true
		combat.debug_advance_combat_projectiles(0.1)
		if int(building_system.get_building(building_id).get("hp", hp_before)) < hp_before:
			damage_step = step_index
			break
	var hp_after := int(building_system.get_building(building_id).get("hp", 0))
	var last: Dictionary = combat.debug_get_combat_snapshot().get("last_projectile_result", {})
	var hit_fact: Dictionary = last.get("hit_fact", {}) if last.get("hit_fact", {}) is Dictionary else {}
	var item := {
		"building_id": building_id,
		"weapon_type": str(enemy.get("weapon_type", "")),
		"selected": selected,
		"released": released,
		"damage_step": damage_step,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"projectile_status": str(last.get("status", "")),
		"aim_target_source": str(last.get("aim_target_source", "")),
		"aim_position_at_release": last.get("aim_position_at_release", Vector3.ZERO),
		"collision_position": last.get("collision_position", Vector3.ZERO),
		"actual_target_type": str(hit_fact.get("actual_target_type", "")),
		"actual_target_id": str(hit_fact.get("actual_target_id", "")),
		"collision_identity": hit_fact.get("collision_identity", {}),
		"transparent_skips": last.get("transparent_building_skipped_ids", PackedStringArray())
	}
	_check(selected, "T0269 production selector did not choose %s: %s" % [building_id, item])
	_check(released, "T0269 formal archer did not release at %s: %s" % [building_id, item])
	_check(hp_after < hp_before, "T0269 formal arrow did not damage %s: %s" % [building_id, item])
	_check(str(hit_fact.get("actual_target_type", "")) == "building", "T0269 %s hit wrong target type: %s" % [building_id, item])
	_check(str(hit_fact.get("actual_target_id", "")) == building_id, "T0269 %s hit wrong target id: %s" % [building_id, item])
	return item


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish(diagnostics: Array[Dictionary]) -> void:
	print("T0269_ENEMY_RANGED_BUILDING_DAMAGE_DIAGNOSTICS=%s" % JSON.stringify(diagnostics))
	if _failures.is_empty():
		print("T0269 enemy ranged building damage verification passed.")
		quit(0)
		return
	quit(1)
