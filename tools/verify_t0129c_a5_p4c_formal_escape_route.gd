extends SceneTree


const ESCAPER_ID := "cook_01"
const EXPECTED_ROUTE_LENGTH := 261.3016
const ROUTE_LENGTH_TOLERANCE := 0.05
const COMPLETION_TOLERANCE := 0.55


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if combat_system == null or npc_system == null or time_system == null or controller == null:
		_fail("C4-P2 required systems are missing")
		return

	var route := controller.get_formal_escape_route_world() as Dictionary
	var points := route.get("path_points", []) as Array
	if points.size() != 6:
		_fail("Formal escape route does not expose six points: %s" % JSON.stringify(route))
		return
	if absf(float(route.get("route_length", 0.0)) - EXPECTED_ROUTE_LENGTH) > ROUTE_LENGTH_TOLERANCE:
		_fail("Formal escape route length drifted: %s" % JSON.stringify(route))
		return
	var production := controller.debug_get_production_navigation_snapshot() as Dictionary
	if (
		not bool(production.get("rear_escape_region_available", false))
		or not bool(production.get("rear_escape_link_available", false))
		or int(production.get("rear_escape_vertex_count", 0)) != 12
		or int(production.get("rear_escape_polygon_count", 0)) != 5
	):
		_fail("Rear escape NavigationRegion contract is incomplete: %s" % JSON.stringify(production))
		return

	var spawn_result := combat_system.spawn_wave(1, true, "a5_p4c_verification") as Dictionary
	if not bool(spawn_result.get("ok", false)):
		_fail("Default formal wave failed to start: %s" % JSON.stringify(spawn_result))
		return
	# Keep authoritative combat time still while physics advances the route.
	time_system.set_process(false)
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10.0
	var escape_result := combat_system.debug_start_npc_escape(ESCAPER_ID, "a5_p4c_verification") as Dictionary
	if not bool(escape_result.get("ok", false)):
		_fail("Formal NPC escape failed to start: %s" % JSON.stringify(escape_result))
		return
	var initial_intent := npc_system.get_npc_state(ESCAPER_ID).get("escape_intent", {}) as Dictionary
	if (
		int(initial_intent.get("route_point_count", 0)) != 6
		or absf(float(initial_intent.get("route_length", 0.0)) - EXPECTED_ROUTE_LENGTH) > ROUTE_LENGTH_TOLERANCE
		or bool(npc_system.get_npc_state(ESCAPER_ID).get("escaped", false))
	):
		_fail("Escape intent did not retain the formal long-route contract: %s" % JSON.stringify(initial_intent))
		return

	var reached_intervention_window := false
	for _frame in range(3600):
		await physics_frame
		var position: Vector3 = npc_system.get_npc_world_position(ESCAPER_ID)
		if position.z < -115.0:
			reached_intervention_window = true
			break
	if not reached_intervention_window:
		_fail("Escaping NPC never reached the long rear corridor: position=%s world=%s" % [
			str(npc_system.get_npc_world_position(ESCAPER_ID)),
			JSON.stringify(combat_system.debug_get_default_formal_combat_world_snapshot())
		])
		return
	var mid_state := npc_system.get_npc_state(ESCAPER_ID) as Dictionary
	var mid_intent := mid_state.get("escape_intent", {}) as Dictionary
	if bool(mid_state.get("escaped", false)) or str(mid_intent.get("status", "")) != "escaping":
		_fail("NPC committed escape before reaching the map edge: %s" % JSON.stringify(mid_state))
		return
	if not bool((combat_system.get_escape_intervention_state(ESCAPER_ID) as Dictionary).get("can_dialogue", false)):
		_fail("Long-route NPC lost the intervention window before completion")
		return

	var pause_result := combat_system.pause_escape_for_dialogue(ESCAPER_ID, "a5_p4c_pause") as Dictionary
	if not bool(pause_result.get("ok", false)):
		_fail("Escape dialogue pause failed: %s" % JSON.stringify(pause_result))
		return
	var paused_position: Vector3 = npc_system.get_npc_world_position(ESCAPER_ID)
	for _frame in range(20):
		await physics_frame
	if npc_system.get_npc_world_position(ESCAPER_ID).distance_to(paused_position) > 0.01:
		_fail("NPC drifted while the escape intervention dialogue was open")
		return
	var resume_result := combat_system.resume_escape_after_dialogue(ESCAPER_ID, "a5_p4c_resume") as Dictionary
	if not bool(resume_result.get("ok", false)):
		_fail("Escape dialogue resume failed: %s" % JSON.stringify(resume_result))
		return

	# Ending combat must restore everyone else but keep this one body and the
	# formal rear NavigationRegion alive until the physical escape completes.
	var clear_result := combat_system.clear_spawned_enemies() as Dictionary
	var mode_exit := clear_result.get("mode_exit_result", {}) as Dictionary
	var formal_exit := mode_exit.get("formal_world_exit_result", {}) as Dictionary
	if (
		not bool(formal_exit.get("escape_world_hold", false))
		or not (formal_exit.get("preserved_escape_npc_ids", []) as Array).has(ESCAPER_ID)
		or not npc_system.is_npc_in_formal_combat_world(ESCAPER_ID)
	):
		_fail("Battle cleanup did not preserve the active long escape: %s" % JSON.stringify(clear_result))
		return

	var completed := false
	for _frame in range(5000):
		await physics_frame
		if bool(npc_system.get_npc_state(ESCAPER_ID).get("escaped", false)):
			completed = true
			break
	if not completed:
		_fail("NPC did not physically complete the map-edge escape")
		return
	var final_state := npc_system.get_npc_state(ESCAPER_ID) as Dictionary
	var final_intent := final_state.get("escape_intent", {}) as Dictionary
	var completed_position: Vector3 = final_intent.get("completed_world_position", Vector3.INF)
	var completion: Vector3 = route.get("completion", Vector3.ZERO)
	if (
		str(final_intent.get("status", "")) != "escaped"
		or str(final_state.get("current_location", "")) != "outside_station"
		or completed_position.distance_to(completion) > COMPLETION_TOLERANCE
	):
		_fail("Escape completion was not atomically committed at the map edge: %s" % JSON.stringify(final_state))
		return
	await process_frame
	await process_frame
	var world_snapshot := combat_system.debug_get_default_formal_combat_world_snapshot() as Dictionary
	if bool(world_snapshot.get("escape_world_hold", true)) or npc_system.is_npc_in_formal_combat_world(ESCAPER_ID):
		_fail("Formal escape world lease was not released after completion: %s" % JSON.stringify(world_snapshot))
		return

	print(
		"A5-P4c / C4-P2 formal escape route verification passed: points=%d length=%.3f completion_error=%.3f"
		% [points.size(), float(route.get("route_length", 0.0)), completed_position.distance_to(completion)]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
