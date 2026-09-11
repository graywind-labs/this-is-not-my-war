extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const FRIENDLY_NPC_ID := "doctor_01"
const ENEMY_TARGET_NPC_ID := "veteran_deputy_01"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame

	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(station_controller != null, "T0210 station controller missing")
	_check(npc_system != null and combat_system != null, "T0210 NPC or combat system missing")
	_check(time_system != null, "T0210 time system missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(false)

	var clinic_route: Dictionary = station_controller.get_building_spatial_route("clinic", "treatment_bed_01")
	var clinic_route_2: Dictionary = station_controller.get_building_spatial_route("clinic", "treatment_bed_02")
	var plaza_position: Variant = station_controller.get_public_location_world_position("plaza")
	_check(not clinic_route.is_empty() and not clinic_route_2.is_empty(), "T0210 clinic route data missing")
	_check(plaza_position is Vector3, "T0210 plaza world position missing")
	if not _failures.is_empty():
		_finish()
		return
	var indoor_position: Vector3 = clinic_route.get("interior_target_position", Vector3.ZERO)
	var same_building_target: Vector3 = clinic_route_2.get("interior_target_position", Vector3.ZERO)
	var outdoor_position: Vector3 = plaza_position

	var prefix: Dictionary = station_controller.get_indoor_exit_navigation_prefix(
		indoor_position,
		outdoor_position,
		0.45
	)
	_check(str(prefix.get("building_id", "")) == "clinic", "T0210 did not identify clinic origin: %s" % prefix)
	_check(
		prefix.get("point_ids", []) == ["interior", "door_inside", "door_outside", "entry_outside"],
		"T0210 clinic prefix order mismatch: %s" % prefix
	)
	_check(
		station_controller.get_indoor_exit_navigation_prefix(indoor_position, same_building_target, 0.45).is_empty(),
		"T0210 same-building movement incorrectly received an exit prefix"
	)
	var door_inside: Vector3 = clinic_route.get("door_inside_position", Vector3.ZERO)
	var doorway_prefix: Dictionary = station_controller.get_indoor_exit_navigation_prefix(
		door_inside,
		outdoor_position,
		0.45
	)
	_check(
		doorway_prefix.get("point_ids", []) == ["door_outside", "entry_outside"],
		"T0210 authored door_inside continuation backtracked: %s" % doorway_prefix
	)
	_check(
		station_controller.get_indoor_exit_navigation_prefix(Vector3(0.0, 0.0, -8.0), outdoor_position, 0.45).is_empty(),
		"T0210 solid main hall incorrectly produced an enterable exit prefix"
	)

	var friendly_actor := _get_npc_actor(npc_system, FRIENDLY_NPC_ID)
	_check(friendly_actor != null, "T0210 friendly actor missing")
	if friendly_actor != null:
		friendly_actor.stop_movement()
		friendly_actor.apply_external_displacement(indoor_position, "t0210_friendly_indoor_fixture")
		var friendly_requested: bool = npc_system.move_npc_to_world_position(
			FRIENDLY_NPC_ID,
			"plaza",
			"T0210 广场目标",
			outdoor_position,
			{},
			{"movement_purpose": "t0210_friendly_exit", "persistent_repath": true}
		)
		_check(friendly_requested, "T0210 friendly NPC movement request failed")
		var friendly_initial: Dictionary = friendly_actor.debug_get_motion_snapshot()
		_check(bool(friendly_initial.get("indoor_exit_prefix_active", false)), "T0210 friendly NPC did not activate prefix: %s" % friendly_initial)
		_check(str(friendly_initial.get("indoor_exit_prefix_building_id", "")) == "clinic", "T0210 friendly prefix building mismatch: %s" % friendly_initial)
		var friendly_request_id := str(friendly_initial.get("request_id", ""))
		var friendly_leg: Vector3 = friendly_initial.get("navigation_leg_target_position", Vector3.ZERO)
		var moved_outdoor_target := outdoor_position + Vector3(4.0, 0.0, 2.0)
		friendly_actor.update_motion_target(moved_outdoor_target, "t0210_target_moved")
		var friendly_updated: Dictionary = friendly_actor.debug_get_motion_snapshot()
		_check(str(friendly_updated.get("request_id", "")) == friendly_request_id, "T0210 friendly target update replaced request id")
		_check(_horizontal_distance(friendly_updated.get("navigation_leg_target_position", Vector3.ZERO), friendly_leg) <= 0.01, "T0210 friendly target update bypassed current prefix leg: %s" % friendly_updated)
		_check(_horizontal_distance(friendly_updated.get("target_position", Vector3.ZERO), moved_outdoor_target) <= 0.01, "T0210 friendly final target was not updated")
		npc_system.set_process(false)
		var friendly_finished_prefix := await _wait_for_prefix_exit(friendly_actor, station_controller, "clinic", 1800)
		_check(friendly_finished_prefix, "T0210 friendly NPC did not leave clinic through prefix: %s" % friendly_actor.debug_get_motion_snapshot())
		var friendly_after: Dictionary = friendly_actor.debug_get_motion_snapshot()
		_check(int(friendly_after.get("indoor_exit_prefix_completed_point_count", 0)) >= int(friendly_after.get("indoor_exit_prefix_point_count", 0)), "T0210 friendly NPC did not complete all active prefix points: %s" % friendly_after)
		_check(str(friendly_after.get("request_id", "")) == friendly_request_id, "T0210 friendly prefix completion replaced request id")
		friendly_actor.stop_movement()

	combat_system.set_process(false)
	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0210 formal enemy spawn failed: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0210 no formal enemy available")
	if not enemy_ids.is_empty():
		for index in range(1, enemy_ids.size()):
			combat_system._remove_enemy_from_combat(enemy_ids[index])
		var enemy_id := enemy_ids[0]
		var enemy_actor := _get_enemy_actor(combat_system, enemy_id)
		var target_actor := _get_npc_actor(npc_system, ENEMY_TARGET_NPC_ID)
		_check(enemy_actor != null and target_actor != null, "T0210 enemy or outdoor target actor missing")
		if enemy_actor != null and target_actor != null:
			enemy_actor.cancel_motion("t0210_enemy_indoor_fixture")
			enemy_actor.apply_external_displacement(same_building_target, "t0210_enemy_indoor_fixture")
			target_actor.stop_movement()
			target_actor.apply_external_displacement(outdoor_position + Vector3(-5.0, 0.0, 4.0), "t0210_enemy_target_fixture")
			var combat_target := {
				"id": ENEMY_TARGET_NPC_ID,
				"type": "npc",
				"position": target_actor.global_position,
			}
			combat_system._ensure_formal_dynamic_pressure_motion(enemy_id, combat_target)
			var enemy_initial: Dictionary = enemy_actor.debug_get_motion_snapshot()
			_check(bool(enemy_initial.get("indoor_exit_prefix_active", false)), "T0210 combat pursuit did not activate enemy prefix: %s" % enemy_initial)
			_check(str(enemy_initial.get("indoor_exit_prefix_building_id", "")) == "clinic", "T0210 enemy prefix building mismatch: %s" % enemy_initial)
			var enemy_request_id := str(enemy_initial.get("request_id", ""))
			var enemy_leg: Vector3 = enemy_initial.get("navigation_leg_target_position", Vector3.ZERO)
			target_actor.apply_external_displacement(outdoor_position + Vector3(-8.0, 0.0, 1.0), "t0210_enemy_target_moved")
			combat_target["position"] = target_actor.global_position
			combat_system._ensure_formal_dynamic_pressure_motion(enemy_id, combat_target)
			var enemy_updated: Dictionary = enemy_actor.debug_get_motion_snapshot()
			_check(str(enemy_updated.get("request_id", "")) == enemy_request_id, "T0210 enemy target update replaced pursuit request id")
			_check(_horizontal_distance(enemy_updated.get("navigation_leg_target_position", Vector3.ZERO), enemy_leg) <= 0.01, "T0210 enemy target update bypassed current prefix leg: %s" % enemy_updated)
			var enemy_finished_prefix := await _wait_for_prefix_exit(enemy_actor, station_controller, "clinic", 1800)
			_check(enemy_finished_prefix, "T0210 enemy remained stuck inside clinic: %s" % enemy_actor.debug_get_motion_snapshot())
			var enemy_after: Dictionary = enemy_actor.debug_get_motion_snapshot()
			_check(int(enemy_after.get("indoor_exit_prefix_completed_point_count", 0)) >= int(enemy_after.get("indoor_exit_prefix_point_count", 0)), "T0210 enemy did not complete all active prefix points: %s" % enemy_after)
			_check(str(enemy_after.get("request_id", "")) == enemy_request_id, "T0210 enemy prefix completion replaced pursuit request id")
			_check(float(enemy_after.get("maximum_frame_displacement", 0.0)) <= 0.30, "T0210 enemy exit contained teleport-like displacement: %s" % enemy_after)

	print("T0210_INDOOR_EXIT_PREFIX_DIAGNOSTICS %s" % JSON.stringify({
		"controller_prefix": prefix,
		"friendly_motion": friendly_actor.debug_get_motion_snapshot() if friendly_actor != null else {},
		"enemy_ids": enemy_ids,
	}))
	combat_system.clear_spawned_enemies()
	_finish()


func _wait_for_prefix_exit(actor: Node, station_controller: Node, building_id: String, maximum_frames: int) -> bool:
	for _frame in range(maximum_frames):
		await physics_frame
		await process_frame
		var snapshot: Dictionary = actor.debug_get_motion_snapshot()
		if (
			not bool(snapshot.get("indoor_exit_prefix_active", false))
			and not station_controller.is_world_position_inside_enterable_building(building_id, actor.global_position)
			and int(snapshot.get("indoor_exit_prefix_completed_point_count", 0)) > 0
		):
			return true
		if str(snapshot.get("state", "")) == "failed":
			return false
	return false


func _get_npc_actor(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _get_enemy_actor(combat_system: Node, enemy_id: String) -> Node:
	var paths: Dictionary = combat_system.get("_formal_first_wave_node_paths")
	return combat_system.get_node_or_null(paths.get(enemy_id, NodePath("")))


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0210_INDOOR_EXIT_PREFIX_NAVIGATION_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
