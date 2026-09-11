extends SceneTree


const NPC_ID := "blacksmith_01"
const SAMPLE_FRAMES := 40


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if [npc_system, daily_plan_system, action_system, time_system, station_controller].has(null):
		_fail("T0155 runtime dependencies unavailable")
		return
	daily_plan_system.set_auto_execution_enabled(false)
	action_system.interrupt_npc_action(NPC_ID, "verify_t0155_fixture")
	var npc := _get_npc_node(npc_system, NPC_ID)
	if npc == null:
		_fail("T0155 NPC fixture unavailable")
		return
	npc.configure_navigation_motion(false)

	var work := await _sample_route(npc_system, npc, "work", {}, "moving_to_blacksmith_workstation")
	if not _assert_route(work, "walk", 3.2, "work"):
		return
	var dialogue := await _sample_route(npc_system, npc, "work", {}, "moving_to_dialogue_partner")
	if not _assert_route(dialogue, "walk", 3.2, "non-emergency dialogue"):
		return

	var emergency_samples: Array[Dictionary] = []
	for mode in ["rally", "combat", "avoid_combat"]:
		var sample := await _sample_route(npc_system, npc, mode, {}, "moving_to_%s_fixture" % mode)
		if not _assert_route(sample, "run", 5.0, mode):
			return
		emergency_samples.append(sample)
	var escape := await _sample_route(npc_system, npc, "work", {
		"active": true,
		"status": "escaping",
		"speed_multiplier": 1.0
	}, "moving_to_escape_edge")
	if not _assert_route(escape, "run", 5.0, "escape"):
		return

	if float(work.get("measured_speed", 0.0)) >= float(emergency_samples[0].get("measured_speed", 0.0)):
		_fail("Emergency displacement is not faster than daily work displacement")
		return
	if not await _verify_player_speed_independence(npc_system, npc, time_system):
		return
	if not await _verify_pause_resume(npc_system, npc, time_system):
		return
	if not await _verify_mounted_state(npc_system, npc):
		return
	if not await _verify_navigation_profile_hot_switch(npc_system, npc, station_controller):
		return

	print("T0155 NPC locomotion mode verification passed.")
	quit(0)


func _sample_route(npc_system: Node, npc: Node, behavior_mode: String, escape_intent: Dictionary, action: String) -> Dictionary:
	npc.stop_movement()
	npc.global_position = Vector3(-40.0, 3.0, -40.0)
	npc_system.update_npc_state(NPC_ID, {
		"behavior_mode": behavior_mode,
		"current_action": action,
		"movement_target": "t0155_target",
		"movement_target_name": "T0155 Target",
		"unconscious": false,
		"escaped": false,
		"combat_mounted": false,
		"escape_intent": escape_intent
	})
	await process_frame
	var start: Vector3 = npc.global_position
	npc.move_to_location("t0155_target", start + Vector3(50.0, 0.0, 0.0))
	for _frame in range(SAMPLE_FRAMES):
		await physics_frame
	var elapsed := float(SAMPLE_FRAMES) / float(Engine.physics_ticks_per_second)
	var measured := Vector2(npc.global_position.x - start.x, npc.global_position.z - start.z).length() / elapsed
	var snapshot: Dictionary = npc.debug_get_character_art_snapshot()
	npc.stop_movement()
	await process_frame
	var stopped: Dictionary = npc.debug_get_character_art_snapshot()
	return {
		"measured_speed": measured,
		"moving": snapshot,
		"stopped": stopped
	}


func _assert_route(sample: Dictionary, expected_state: String, expected_speed: float, label: String) -> bool:
	var moving: Dictionary = sample.get("moving", {})
	var stopped: Dictionary = sample.get("stopped", {})
	var measured := float(sample.get("measured_speed", 0.0))
	if (
		str(moving.get("locomotion_state", "")) != expected_state
		or str(moving.get("desired_state", "")) != expected_state
		or absf(float(moving.get("authoritative_move_speed", 0.0)) - expected_speed) > 0.02
		# The movement request begins between physics ticks, so the wall-clock
		# sample may contain one setup tick without displacement.
		or absf(measured - expected_speed) > 0.16
	):
		_fail("%s route did not align authority speed and %s presentation: %s" % [label, expected_state, str(sample)])
		return false
	var cadence := float(moving.get("locomotion_animation_speed_scale", 0.0))
	var actual_speed := float(moving.get("actual_horizontal_speed", 0.0))
	var reference_speed := float(moving.get("locomotion_reference_speed", 0.0))
	if absf(cadence - actual_speed / maxf(0.01, reference_speed)) > 0.06:
		_fail("%s animation cadence is not driven by actual displacement: %s" % [label, str(moving)])
		return false
	if bool(stopped.get("logical_moving", true)) or str(stopped.get("desired_state", "")) != "idle":
		_fail("%s route did not return to idle after stopping: %s" % [label, str(stopped)])
		return false
	return true


func _verify_player_speed_independence(npc_system: Node, npc: Node, time_system: Node) -> bool:
	var speeds: Array[float] = []
	for scale in [1.0, 2.0, 4.0]:
		time_system.set_time_scale(scale)
		var sample := await _sample_route(npc_system, npc, "combat", {}, "moving_to_combat_fixture")
		speeds.append(float(sample.get("measured_speed", 0.0)))
	time_system.set_time_scale(1.0)
	if absf(speeds[0] - speeds[1]) > 0.12 or absf(speeds[0] - speeds[2]) > 0.12:
		_fail("Player x2/x4 directly changed combat displacement speed: %s" % str(speeds))
		return false
	return true


func _verify_pause_resume(npc_system: Node, npc: Node, time_system: Node) -> bool:
	npc.stop_movement()
	npc.global_position = Vector3(-40.0, 3.0, -40.0)
	npc_system.update_npc_state(NPC_ID, {
		"behavior_mode": "combat", "current_action": "moving_to_pause_fixture", "escape_intent": {}, "combat_mounted": false
	})
	await process_frame
	npc.move_to_location("pause_fixture", npc.global_position + Vector3(50.0, 0.0, 0.0))
	for _frame in range(8):
		await physics_frame
	time_system.set_paused(true)
	var paused_position: Vector3 = npc.global_position
	for _frame in range(12):
		await physics_frame
	if npc.global_position.distance_to(paused_position) > 0.001:
		_fail("NPC moved while gameplay was paused")
		return false
	time_system.set_paused(false)
	for _frame in range(8):
		await physics_frame
	if npc.global_position.distance_to(paused_position) <= 0.1:
		_fail("NPC did not resume authoritative movement after pause")
		return false
	npc.stop_movement()
	return true


func _verify_mounted_state(npc_system: Node, npc: Node) -> bool:
	npc.stop_movement()
	npc.global_position = Vector3(-40.0, 3.0, -40.0)
	npc_system.update_npc_state(NPC_ID, {
		"behavior_mode": "combat",
		"current_action": "moving_to_mounted_fixture",
		"combat_mounted": true,
		"escape_intent": {}
	})
	await process_frame
	npc.move_to_location("mounted_fixture", npc.global_position + Vector3(50.0, 0.0, 0.0))
	for _frame in range(12):
		await physics_frame
	var moving: Dictionary = npc.debug_get_character_art_snapshot()
	npc.stop_movement()
	await process_frame
	var stopped: Dictionary = npc.debug_get_character_art_snapshot()
	if str(moving.get("desired_state", "")) != "mounted_walk" or not bool(moving.get("combat_mount_visual_visible", false)):
		_fail("Mounted NPC did not retain mounted locomotion: %s" % str(moving))
		return false
	if str(stopped.get("desired_state", "")) != "vehicle_seated":
		_fail("Mounted NPC did not return to mounted idle: %s" % str(stopped))
		return false
	npc_system.update_npc_state(NPC_ID, {"combat_mounted": false, "behavior_mode": "work", "current_action": "idle"})
	return true


func _verify_navigation_profile_hot_switch(npc_system: Node, npc: Node, station_controller: Node) -> bool:
	var navigation_map: RID = station_controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		_fail("Production navigation map unavailable for locomotion hot switch")
		return false
	var start: Vector3 = station_controller.get_npc_initial_world_position(NPC_ID)
	start = NavigationServer3D.map_get_closest_point(navigation_map, start)
	var target := NavigationServer3D.map_get_closest_point(navigation_map, start + Vector3(8.0, 0.0, 0.0))
	npc.global_position = start
	if not npc.configure_navigation_motion(true, navigation_map):
		_fail("NPC could not enter production navigation for locomotion hot switch")
		return false
	npc_system.update_npc_state(NPC_ID, {
		"behavior_mode": "work", "current_action": "moving_to_hot_switch", "combat_mounted": false, "escape_intent": {}
	})
	await process_frame
	npc.move_to_location("hot_switch", target)
	await physics_frame
	npc_system.update_npc_state(NPC_ID, {"behavior_mode": "combat"})
	await process_frame
	var motion: Dictionary = npc.debug_get_motion_snapshot()
	var art: Dictionary = npc.debug_get_character_art_snapshot()
	if absf(float(motion.get("profile_base_speed", 0.0)) - 5.0) > 0.02 or str(art.get("locomotion_state", "")) != "run":
		_fail("Active NavigationAgent did not hot-switch from walk to run: %s / %s" % [str(motion), str(art)])
		return false
	npc.stop_movement()
	npc.configure_navigation_motion(false)
	npc_system.update_npc_state(NPC_ID, {"behavior_mode": "work", "current_action": "idle"})
	return true


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
