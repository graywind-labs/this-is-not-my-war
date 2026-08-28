extends SceneTree


const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _frame in 30:
		await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if combat_system == null or time_system == null:
		_fail("Enemy mounted verification systems are missing")
		return
	if time_system.has_method("set_paused"):
		time_system.set_paused(false)

	var wave_four: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(4)
	if not bool(wave_four.get("ok", false)):
		_fail("Could not spawn wave four: %s" % JSON.stringify(wave_four))
		return
	for _frame in 30:
		await process_frame

	var cavalry_id := _find_enemy_id(combat_system, "cavalry")
	if cavalry_id.is_empty():
		_fail("Wave four has no cavalry enemy")
		return
	var mounted_art := _get_enemy_art(combat_system, cavalry_id)
	if mounted_art == null:
		_fail("Cavalry enemy has no mounted art wrapper")
		return
	var mounted_snapshot: Dictionary = mounted_art.debug_get_snapshot()
	if not bool(mounted_snapshot.get("mounted_enemy_wrapper", false)) or not bool(mounted_snapshot.get("horse_visible", false)):
		_fail("Cavalry did not spawn as a visible rider and horse: %s" % str(mounted_snapshot))
		return
	if bool(mounted_snapshot.get("horse_has_independent_hp", true)) or str(mounted_snapshot.get("damage_routing", "")) != "enemy_unit_only":
		_fail("Enemy horse incorrectly exposes an independent damage pool")
		return
	if str(mounted_snapshot.get("desired_state", "")) not in ["vehicle_seated", "mounted_walk"]:
		_fail("Cavalry rider did not enter the mounted pose: %s" % str(mounted_snapshot))
		return
	if not Vector3(mounted_snapshot.get("horse_local_position", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.ENEMY_HORSE_LOCAL_POSITION) or not Vector3(mounted_snapshot.get("horse_scale", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.ENEMY_HORSE_SCALE):
		_fail("Main enemy mount diverged from the shared NPCDevLab reference: %s" % str(mounted_snapshot))
		return
	if float(mounted_snapshot.get("mounted_forward_dot", -1.0)) < 0.99:
		_fail("Main enemy rider and horse facing diverged during movement: %s" % str(mounted_snapshot))
		return

	var cavalry: Dictionary = combat_system.get_enemy(cavalry_id)
	var hp_before := int(cavalry.get("hp", 0))
	var hit: Dictionary = combat_system.apply_enemy_area_damage(
		cavalry.get("position", Vector3.ZERO),
		0.2,
		9999.0,
		{"max_targets": 1, "source_type": "enemy_mounted_verification"}
	)
	var hits: Array = hit.get("hits", [])
	if hits.size() != 1:
		_fail("Cavalry verification damage did not hit exactly one unit: %s" % str(hit))
		return
	var damage_result: Dictionary = hits[0]
	if str(damage_result.get("enemy_id", "")) != cavalry_id or int(damage_result.get("hp_before", -1)) != hp_before or int(damage_result.get("hp_after", -1)) != 0:
		_fail("Damage was not applied directly to the cavalry unit: %s" % str(damage_result))
		return
	if combat_system.get_active_enemy_ids().has(cavalry_id):
		_fail("Defeated cavalry remained in combat while its animation played")
		return
	await process_frame

	var defeat_state: Dictionary = combat_system.debug_get_enemy_mounted_defeat_snapshots()
	var escaping := _find_escape(defeat_state.get("active", []), cavalry_id)
	if escaping.is_empty():
		_fail("Defeated cavalry did not preserve a mounted fall / escaping horse presentation")
		return
	if str(escaping.get("escape_phase", "")) != "fleeing_to_map_edge" or not bool(escaping.get("mounted_fall_active", false)):
		_fail("Mounted defeat did not start both rider fall and horse escape: %s" % str(escaping))
		return
	var controller := root.get_node("Main/Presentation/StationLayoutController")
	var route: Dictionary = controller.get_enemy_route_world()
	var front_gate := _find_route_stage_position(route.get("stages", []), "front_gate")
	var escape_start: Vector3 = escaping.get("escape_start", Vector3.ZERO)
	var escape_target: Vector3 = escaping.get("escape_target", Vector3.ZERO)
	if escape_target.distance_to(front_gate) <= escape_start.distance_to(front_gate):
		_fail("Enemy horse did not turn back toward the front map boundary: %s" % str(escaping))
		return
	if str(escaping.get("current_clip", "")) != "Death_A":
		_fail("Enemy rider did not reuse the agreed Death_A fall clip")
		return

	await create_timer(0.46).timeout
	defeat_state = combat_system.debug_get_enemy_mounted_defeat_snapshots()
	escaping = _find_escape(defeat_state.get("active", []), cavalry_id)
	if escaping.is_empty() or float(escaping.get("mounted_fall_progress", 0.0)) < 0.35 or float(escaping.get("escape_distance", 0.0)) <= 2.0:
		_fail("Enemy fall / escape did not visibly advance together: %s" % str(escaping))
		return

	var escaping_node := _find_mounted_art_node(cavalry_id)
	if escaping_node == null:
		_fail("Escaping horse presentation node disappeared before the map edge")
		return
	escaping_node.debug_advance_escape(60.0)
	await process_frame
	defeat_state = combat_system.debug_get_enemy_mounted_defeat_snapshots()
	var completed: Dictionary = defeat_state.get("last_completed", {})
	if str(completed.get("enemy_id", "")) != cavalry_id or str(completed.get("escape_phase", "")) != "released_outside_map":
		_fail("Enemy horse was not released at the configured map edge: %s" % str(completed))
		return
	if _find_mounted_art_node(cavalry_id) != null:
		_fail("Enemy mounted presentation remained after outside-map release")
		return

	var infantry_id := _find_enemy_id(combat_system, "melee_infantry")
	if infantry_id.is_empty():
		_fail("Wave four has no ordinary infantry isolation sample")
		return
	var infantry: Dictionary = combat_system.get_enemy(infantry_id)
	combat_system.apply_enemy_area_damage(
		infantry.get("position", Vector3.ZERO),
		0.2,
		9999.0,
		{"max_targets": 1, "source_type": "enemy_mounted_isolation_verification"}
	)
	await process_frame
	if _find_mounted_art_node(infantry_id) != null:
		_fail("Ordinary infantry incorrectly created an escaping horse")
		return

	var wave_five: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(5)
	if not bool(wave_five.get("ok", false)):
		_fail("Could not spawn wave five mounted-ranged sample")
		return
	await process_frame
	await process_frame
	var mounted_ranged_id := _find_enemy_id(combat_system, "mounted_ranged")
	var mounted_ranged_art := _get_enemy_art(combat_system, mounted_ranged_id)
	var mounted_ranged_snapshot: Dictionary = mounted_ranged_art.debug_get_snapshot() if mounted_ranged_art != null else {}
	if mounted_ranged_id.is_empty() or not bool(mounted_ranged_snapshot.get("mounted_enemy_wrapper", false)) or not bool(mounted_ranged_snapshot.get("horse_visible", false)):
		_fail("Mounted ranged enemy did not use the same mounted presentation contract")
		return
	if bool(mounted_ranged_snapshot.get("horse_has_independent_hp", true)):
		_fail("Mounted ranged horse incorrectly gained independent HP")
		return

	print("T0139 enemy mounted defeat and horse escape verification passed.")
	quit(0)


func _find_enemy_id(combat_system: Node, unit_type: String) -> String:
	for raw_id in combat_system.get_active_enemy_ids():
		var enemy_id := str(raw_id)
		if str(combat_system.get_enemy(enemy_id).get("unit_type", "")) == unit_type:
			return enemy_id
	return ""


func _get_enemy_art(combat_system: Node, enemy_id: String) -> Node:
	var paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_node := combat_system.get_node_or_null(paths.get(enemy_id, NodePath("")))
	return enemy_node.get_node_or_null("EnemyArtView") if enemy_node != null else null


func _find_escape(raw_snapshots: Array, enemy_id: String) -> Dictionary:
	for raw_snapshot in raw_snapshots:
		var snapshot: Dictionary = raw_snapshot if raw_snapshot is Dictionary else {}
		if str(snapshot.get("enemy_id", "")) == enemy_id:
			return snapshot
	return {}


func _find_mounted_art_node(enemy_id: String) -> Node:
	for raw_node in get_nodes_in_group("enemy_mounted_art"):
		var node := raw_node as Node
		if node != null and node.has_method("debug_get_snapshot"):
			var snapshot: Dictionary = node.debug_get_snapshot()
			if str(snapshot.get("enemy_id", "")) == enemy_id:
				return node
	return null


func _find_route_stage_position(raw_stages: Array, stage_id: String) -> Vector3:
	for raw_stage in raw_stages:
		var stage: Dictionary = raw_stage if raw_stage is Dictionary else {}
		if str(stage.get("id", "")) == stage_id:
			return stage.get("position", Vector3.ZERO)
	return Vector3.ZERO


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
