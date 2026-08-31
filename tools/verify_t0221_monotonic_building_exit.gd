extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const TEST_NPC_ID := "doctor_01"

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
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(station_controller != null and npc_system != null, "T0221 runtime dependencies missing")
	if not _failures.is_empty():
		_finish({})
		return
	if time_system != null:
		time_system.set_paused(false)

	var building_results := _verify_all_building_prefixes(station_controller)
	var actor_result := _verify_live_actor_monotonicity(station_controller, npc_system)
	print("T0221_MONOTONIC_BUILDING_EXIT_DIAGNOSTICS %s" % JSON.stringify({
		"buildings": building_results,
		"actor": actor_result,
	}))
	_finish({"buildings": building_results, "actor": actor_result})


func _verify_all_building_prefixes(station_controller: Node) -> Dictionary:
	var layout: Dictionary = station_controller.get("_layout")
	var spatial_contracts := layout.get("building_spatial", {}) as Dictionary
	var results := {}
	var verified_count := 0
	for raw_building_id in spatial_contracts.keys():
		var building_id := str(raw_building_id)
		var route: Dictionary = station_controller.get_building_spatial_route(building_id)
		if route.is_empty():
			continue
		var interior: Vector3 = route.get("interior_position", Vector3.ZERO)
		var door_inside: Vector3 = route.get("door_inside_position", Vector3.ZERO)
		var door_outside: Vector3 = route.get("door_outside_position", Vector3.ZERO)
		var entry_outside: Vector3 = route.get("entry_outside_position", Vector3.ZERO)
		var forward := entry_outside - interior
		forward.y = 0.0
		if forward.length_squared() <= 0.0001:
			_check(false, "T0221 %s has no outward route direction" % building_id)
			continue
		forward = forward.normalized()
		var lateral := Vector3(-forward.z, 0.0, forward.x)
		var outdoor_target := entry_outside + forward * 8.0
		var deep_inside := interior - forward * 0.65
		var initial: Dictionary = station_controller.get_indoor_exit_navigation_prefix(
			deep_inside,
			outdoor_target,
			0.45
		)
		# Non-enterable solid blockers intentionally do not participate in the
		# shared exit-prefix contract (currently the main hall).
		if initial.is_empty():
			results[building_id] = {"eligible": false}
			continue
		verified_count += 1
		_check(
			initial.get("point_ids", []) == ["interior", "door_inside", "door_outside", "entry_outside"],
			"T0221 %s initial exit order mismatch: %s" % [building_id, initial]
		)

		# This body has crossed the door-inside plane but is deliberately more
		# than a body radius off the authored centre point, reproducing doorway
		# avoidance. It must never be sent back to the room merge or door-inside.
		var passed_door_inside := door_inside + forward * 0.40 + lateral * 1.10
		var rebuilt_inside: Dictionary = station_controller.get_indoor_exit_navigation_prefix(
			passed_door_inside,
			outdoor_target,
			0.65
		)
		var rebuilt_ids: Array = rebuilt_inside.get("point_ids", [])
		_check(not rebuilt_inside.is_empty(), "T0221 %s passed-inside fixture left containment unexpectedly" % building_id)
		_check(
			not rebuilt_ids.has("interior") and not rebuilt_ids.has("door_inside"),
			"T0221 %s rebuilt to an earlier indoor stage: %s" % [building_id, rebuilt_inside]
		)

		# At or beyond the door-outside plane the result may already be empty if
		# containment has ended; if still classified inside, only entry_outside is
		# allowed to remain.
		var passed_door_outside := door_outside + forward * 0.35 + lateral * 0.85
		var rebuilt_outer: Dictionary = station_controller.get_indoor_exit_navigation_prefix(
			passed_door_outside,
			outdoor_target,
			0.65
		)
		var outer_ids: Array = rebuilt_outer.get("point_ids", [])
		_check(
			rebuilt_outer.is_empty() or outer_ids == ["entry_outside"],
			"T0221 %s outer doorway fixture regressed: %s" % [building_id, rebuilt_outer]
		)
		results[building_id] = {
			"eligible": true,
			"initial_ids": initial.get("point_ids", []),
			"passed_inside_ids": rebuilt_ids,
			"passed_outer_ids": outer_ids,
		}
	_check(verified_count >= 10, "T0221 expected at least ten shared enterable building routes, got %d" % verified_count)
	return results


func _verify_live_actor_monotonicity(station_controller: Node, npc_system: Node) -> Dictionary:
	var actor := _get_npc_actor(npc_system, TEST_NPC_ID)
	_check(actor != null, "T0221 live NPC actor missing")
	if actor == null:
		return {}
	var route: Dictionary = station_controller.get_building_spatial_route("clinic")
	var interior: Vector3 = route.get("interior_position", Vector3.ZERO)
	var door_inside: Vector3 = route.get("door_inside_position", Vector3.ZERO)
	var entry_outside: Vector3 = route.get("entry_outside_position", Vector3.ZERO)
	var forward := entry_outside - interior
	forward.y = 0.0
	forward = forward.normalized()
	var lateral := Vector3(-forward.z, 0.0, forward.x)
	var outdoor_target := entry_outside + forward * 8.0

	actor.stop_movement()
	actor.apply_external_displacement(interior - forward * 0.65, "t0221_actor_inside")
	var requested: bool = npc_system.move_npc_to_world_position(
		TEST_NPC_ID,
		"plaza",
		"T0221 室外目标",
		outdoor_target,
		{},
		{"movement_purpose": "t0221_monotonic_exit", "persistent_repath": true}
	)
	_check(requested, "T0221 live NPC motion request failed")
	var initial: Dictionary = actor.debug_get_motion_snapshot()
	var initial_point_id := str(initial.get("indoor_exit_prefix_current_point_id", ""))
	var generation_before := int(initial.get("indoor_exit_prefix_generation_count", 0))
	_check(initial_point_id == "interior", "T0221 live NPC did not start at interior: %s" % initial)

	var moved_target := outdoor_target + lateral * 4.0
	actor.update_motion_target(moved_target, "t0221_outdoor_target_refresh")
	var target_updated: Dictionary = actor.debug_get_motion_snapshot()
	_check(
		int(target_updated.get("indoor_exit_prefix_generation_count", 0)) == generation_before,
		"T0221 outdoor target refresh rebuilt the fixed exit prefix: %s" % target_updated
	)
	_check(
		str(target_updated.get("indoor_exit_prefix_current_point_id", "")) == initial_point_id,
		"T0221 outdoor target refresh changed the current exit stage: %s" % target_updated
	)
	_check(
		int(target_updated.get("indoor_exit_prefix_target_update_preserved_count", 0)) == 1,
		"T0221 target-update preservation diagnostic missing: %s" % target_updated
	)

	actor.apply_external_displacement(
		door_inside + forward * 0.40 + lateral * 1.10,
		"t0221_lateral_passed_door_inside"
	)
	var rebuilt: Dictionary = actor.debug_get_motion_snapshot()
	var rebuilt_ids: Array = rebuilt.get("indoor_exit_prefix_point_ids", [])
	_check(
		not rebuilt_ids.has("interior") and not rebuilt_ids.has("door_inside"),
		"T0221 displaced live NPC rebuilt to an earlier stage: %s" % rebuilt
	)

	var current_point: Vector3 = rebuilt.get("navigation_leg_target_position", Vector3.ZERO)
	var point_before_pass := str(rebuilt.get("indoor_exit_prefix_current_point_id", ""))
	actor.global_position = current_point + forward * 0.25 + lateral * 1.0
	actor._advance_passed_indoor_exit_prefix_points()
	var passed: Dictionary = actor.debug_get_motion_snapshot()
	_check(
		str(passed.get("indoor_exit_prefix_current_point_id", "")) != point_before_pass,
		"T0221 live actor crossed a route plane without advancing: %s" % passed
	)

	actor.update_motion_target(interior, "t0221_target_returned_inside")
	var returned_inside: Dictionary = actor.debug_get_motion_snapshot()
	_check(
		not bool(returned_inside.get("indoor_exit_prefix_active", true))
		and str(returned_inside.get("indoor_exit_prefix_last_result", "")) == "target_returned_inside",
		"T0221 same-building target did not cancel the exit prefix: %s" % returned_inside
	)
	actor.stop_movement()
	return {
		"initial": _motion_summary(initial),
		"target_updated": _motion_summary(target_updated),
		"rebuilt_after_lateral_pass": _motion_summary(rebuilt),
		"passed_current_plane": _motion_summary(passed),
		"returned_inside": _motion_summary(returned_inside),
	}


func _motion_summary(snapshot: Dictionary) -> Dictionary:
	return {
		"current_point_id": snapshot.get("indoor_exit_prefix_current_point_id", ""),
		"point_ids": snapshot.get("indoor_exit_prefix_point_ids", []),
		"generation_count": snapshot.get("indoor_exit_prefix_generation_count", 0),
		"completed_count": snapshot.get("indoor_exit_prefix_completed_point_count", 0),
		"target_update_preserved_count": snapshot.get("indoor_exit_prefix_target_update_preserved_count", 0),
		"last_result": snapshot.get("indoor_exit_prefix_last_result", ""),
	}


func _get_npc_actor(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(_diagnostics: Dictionary) -> void:
	if _failures.is_empty():
		print("T0221_MONOTONIC_BUILDING_EXIT_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
