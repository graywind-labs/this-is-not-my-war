extends SceneTree


const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")
const POSITION_TOLERANCE := 0.001


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
		_fail("T0242 systems are missing")
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
	var mounted_art := _get_enemy_art(combat_system, cavalry_id)
	var mounted_snapshot: Dictionary = mounted_art.debug_get_snapshot() if mounted_art != null else {}
	if cavalry_id.is_empty() or mounted_snapshot.is_empty():
		_fail("Wave four has no formal mounted cavalry")
		return
	if not bool(mounted_snapshot.get("horse_visible", false)) or bool(mounted_snapshot.get("horse_has_independent_hp", true)):
		_fail("Mounted cavalry did not preserve the shared no-independent-HP horse: %s" % str(mounted_snapshot))
		return
	if not Vector3(mounted_snapshot.get("horse_local_position", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.ENEMY_HORSE_LOCAL_POSITION):
		_fail("Mounted horse diverged from the shared presentation reference")
		return
	if not bool(mounted_snapshot.get("horse_death_clip_available", false)) or float(mounted_snapshot.get("horse_death_clip_length", 0.0)) <= 0.0:
		_fail("Merchant horse has no usable Death animation: %s" % str(mounted_snapshot))
		return

	var cavalry: Dictionary = combat_system.get_enemy(cavalry_id)
	var hit: Dictionary = combat_system.apply_enemy_area_damage(
		cavalry.get("position", Vector3.ZERO),
		0.2,
		9999.0,
		{"max_targets": 1, "source_type": "t0242_enemy_mounted_shared_defeat"}
	)
	if (hit.get("hits", []) as Array).size() != 1 or combat_system.get_active_enemy_ids().has(cavalry_id):
		_fail("Mounted cavalry defeat authority failed: %s" % str(hit))
		return
	await process_frame

	var defeat_state: Dictionary = combat_system.debug_get_enemy_mounted_defeat_snapshots()
	var defeat := _find_defeat(defeat_state.get("active", []), cavalry_id)
	if defeat.is_empty():
		_fail("Mounted rider and horse corpse presentation was not preserved")
		return
	if str(defeat.get("defeat_phase", "")) != "bodies_lingering":
		_fail("Mounted defeat did not enter the shared body linger phase: %s" % str(defeat))
		return
	if str(defeat.get("current_clip", "")) != "Death_A" or str(defeat.get("horse_animation", "")) != "Death":
		_fail("Rider and horse did not start their respective death clips: %s" % str(defeat))
		return
	if not bool(defeat.get("rider_body_visible", false)) or not bool(defeat.get("horse_visible", false)):
		_fail("One of the mounted bodies was hidden before shared cleanup")
		return
	var defeat_root_origin := Vector3(defeat.get("defeat_world_origin", Vector3.ZERO))
	var horse_origin := Vector3(defeat.get("horse_defeat_world_origin", Vector3.ZERO))

	await create_timer(0.55).timeout
	defeat_state = combat_system.debug_get_enemy_mounted_defeat_snapshots()
	defeat = _find_defeat(defeat_state.get("active", []), cavalry_id)
	if defeat.is_empty():
		_fail("Mounted corpses were cleaned before the configured linger time")
		return
	if Vector3(defeat.get("root_world_position", Vector3.ZERO)).distance_to(defeat_root_origin) > POSITION_TOLERANCE:
		_fail("Mounted corpse root moved after defeat: %s" % str(defeat))
		return
	if Vector3(defeat.get("horse_world_position", Vector3.ZERO)).distance_to(horse_origin) > POSITION_TOLERANCE:
		_fail("Horse moved or escaped after defeat: %s" % str(defeat))
		return
	if float(defeat.get("mounted_fall_progress", 0.0)) < 0.35:
		_fail("Rider Death_A did not visibly advance while both bodies stayed still: %s" % str(defeat))
		return
	if str(defeat.get("horse_animation", "")) != "Death":
		_fail("Horse returned to locomotion during corpse linger: %s" % str(defeat))
		return
	await create_timer(0.70).timeout
	defeat_state = combat_system.debug_get_enemy_mounted_defeat_snapshots()
	defeat = _find_defeat(defeat_state.get("active", []), cavalry_id)
	if defeat.is_empty() or not bool(defeat.get("horse_death_pose_held", false)):
		_fail("Horse Death animation did not hold its final corpse pose: %s" % str(defeat))
		return
	if Vector3(defeat.get("horse_world_position", Vector3.ZERO)).distance_to(horse_origin) > POSITION_TOLERANCE:
		_fail("Horse moved while settling into its final death pose: %s" % str(defeat))
		return

	var defeat_node := _find_mounted_art_node(cavalry_id)
	if defeat_node == null:
		_fail("Mounted defeat presentation node disappeared early")
		return
	var elapsed := float(defeat.get("defeat_elapsed", 0.0))
	var linger := float(defeat.get("corpse_linger_seconds", 0.0))
	if not is_equal_approx(linger, 8.0):
		_fail("Mounted corpse linger duration is not the shared 8-second contract: %s" % str(defeat))
		return
	defeat_node.debug_advance_defeat(maxf(0.0, linger - elapsed - 0.02))
	defeat = defeat_node.debug_get_snapshot()
	if str(defeat.get("defeat_phase", "")) != "bodies_lingering" or float(defeat.get("horse_position_drift", INF)) > POSITION_TOLERANCE:
		_fail("Mounted bodies did not stay together through the end of corpse linger: %s" % str(defeat))
		return
	defeat_node.debug_advance_defeat(0.04)
	await process_frame
	defeat_state = combat_system.debug_get_enemy_mounted_defeat_snapshots()
	var completed: Dictionary = defeat_state.get("last_completed", {})
	if str(completed.get("enemy_id", "")) != cavalry_id or str(completed.get("defeat_phase", "")) != "cleaned_up":
		_fail("Mounted bodies did not report one shared cleanup: %s" % str(completed))
		return
	if _find_mounted_art_node(cavalry_id) != null:
		_fail("Rider or horse remained after shared corpse cleanup")
		return
	if float(completed.get("root_position_drift", INF)) > POSITION_TOLERANCE or float(completed.get("horse_position_drift", INF)) > POSITION_TOLERANCE:
		_fail("Mounted bodies drifted before shared cleanup: %s" % str(completed))
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
	if mounted_ranged_id.is_empty() or not bool(mounted_ranged_snapshot.get("horse_death_clip_available", false)):
		_fail("Mounted ranged enemy did not share the same horse death contract")
		return
	if mounted_ranged_snapshot.has("escape_speed_mps") or mounted_ranged_snapshot.has("escape_target"):
		_fail("Retired enemy horse escape authority leaked into the mounted wrapper")
		return

	print("T0242 enemy mounted shared defeat verification passed.")
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


func _find_defeat(raw_snapshots: Array, enemy_id: String) -> Dictionary:
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
