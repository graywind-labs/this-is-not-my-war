extends SceneTree


func _init() -> void:
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	var systems := Node.new()
	systems.name = "Systems"
	main.add_child(systems)

	var time_system_script := load("res://scripts/systems/TimeSystem.gd") as Script
	var npc_scene := load("res://scenes/npc/NPC.tscn") as PackedScene
	if time_system_script == null or npc_scene == null:
		_fail("Movement slowdown verification resources could not be loaded")
		return

	var time_system := time_system_script.new() as Node
	time_system.name = "TimeSystem"
	systems.add_child(time_system)
	time_system.set_process(false)
	time_system.seconds_per_game_minute = 1.0
	time_system.set_time_scale(4.0)
	time_system.set_paused(false)

	var npc_root := Node3D.new()
	npc_root.name = "NPCs"
	main.add_child(npc_root)
	var first_npc := _spawn_npc(npc_scene, npc_root, "slowdown_first")
	var second_npc := _spawn_npc(npc_scene, npc_root, "slowdown_second")
	if first_npc == null or second_npc == null:
		_fail("Movement slowdown verification NPCs could not be spawned")
		return
	await process_frame

	first_npc.move_to_location("first_target", Vector3(20.0, 0.0, 0.0))
	if not _assert_snapshot(time_system, 1, 1.0 / 60.0, ["npc_movement:slowdown_first"]):
		return
	if absf(float(time_system.get_game_delta_seconds(1.0)) - 1.0) > 0.001:
		_fail("Movement slowdown should make one real second equal one logical game second")
		return

	var logical_ticks: Array[Dictionary] = []
	var event_bus := root.get_node_or_null("EventBus")
	if event_bus == null:
		_fail("EventBus autoload is missing")
		return
	event_bus.logical_time_tick.connect(func(game_delta_seconds: float, numeric_multiplier: float) -> void:
		logical_ticks.append({
			"game_delta_seconds": game_delta_seconds,
			"numeric_multiplier": numeric_multiplier
		})
	)
	time_system.call("_process", 1.0)
	if (
		logical_ticks.size() != 1
		or absf(float(logical_ticks[0].get("game_delta_seconds", 0.0)) - 1.0) > 0.001
		or absf(float(logical_ticks[0].get("numeric_multiplier", 0.0)) - (1.0 / 60.0)) > 0.001
	):
		_fail("Movement slowdown did not reach logical-time production consumers: %s" % logical_ticks)
		return

	second_npc.move_to_location("second_target", Vector3(-20.0, 0.0, 0.0))
	if not _assert_snapshot(
		time_system,
		2,
		1.0 / 60.0,
		["npc_movement:slowdown_first", "npc_movement:slowdown_second"]
	):
		return
	first_npc.stop_movement()
	if not _assert_snapshot(time_system, 1, 1.0 / 60.0, ["npc_movement:slowdown_second"]):
		return
	second_npc.stop_movement()
	if not _assert_snapshot(time_system, 0, 4.0, []):
		return

	time_system.request_time_slowdown("verify_llm_overlap", -1.0, "llm_wait")
	first_npc.move_to_location("overlap_target", Vector3(10.0, 0.0, 0.0))
	if not _assert_snapshot(
		time_system,
		2,
		1.0 / 60.0,
		["verify_llm_overlap", "npc_movement:slowdown_first"]
	):
		return
	first_npc.stop_movement()
	if not _assert_snapshot(time_system, 1, 1.0 / 60.0, ["verify_llm_overlap"]):
		return
	time_system.release_time_slowdown("verify_llm_overlap")
	if not _assert_snapshot(time_system, 0, 4.0, []):
		return

	first_npc.move_speed = 100.0
	first_npc.move_to_location("arrival_target", first_npc.global_position + Vector3(1.0, 0.0, 0.0))
	first_npc.call("_physics_process", 1.0)
	if not _assert_snapshot(time_system, 0, 4.0, []):
		return

	first_npc.move_to_location("pause_target", first_npc.global_position + Vector3(10.0, 0.0, 0.0))
	time_system.set_paused(true)
	var paused_snapshot: Dictionary = time_system.get_time_scale_snapshot()
	if (
		absf(float(paused_snapshot.get("effective_scale", 0.0)) - (1.0 / 60.0)) > 0.001
		or not is_zero_approx(float(paused_snapshot.get("numeric_multiplier", -1.0)))
	):
		_fail("Pause should override numeric progress while retaining movement slowdown: %s" % paused_snapshot)
		return
	time_system.set_paused(false)
	first_npc.stop_movement()

	second_npc.move_to_location("exit_target", Vector3(-10.0, 0.0, 0.0))
	second_npc.queue_free()
	await process_frame
	if not _assert_snapshot(time_system, 0, 4.0, []):
		return

	print("T0137 NPC movement time slowdown verification passed.")
	quit(0)


func _spawn_npc(npc_scene: PackedScene, npc_root: Node3D, npc_id: String) -> Node:
	var npc := npc_scene.instantiate()
	npc_root.add_child(npc)
	npc.setup({
		"id": npc_id,
		"name": npc_id,
		"states": {
			"hp": 100,
			"max_hp": 100,
			"current_action": "idle"
		}
	})
	npc.set_physics_process(false)
	return npc


func _assert_snapshot(
	time_system: Node,
	expected_count: int,
	expected_scale: float,
	expected_request_ids: Array[String]
) -> bool:
	var snapshot: Dictionary = time_system.get_time_scale_snapshot()
	var requests: Dictionary = snapshot.get("slowdown_requests", {})
	if int(snapshot.get("slowdown_count", -1)) != expected_count:
		_fail("Unexpected movement slowdown count: %s" % snapshot)
		return false
	if absf(float(snapshot.get("effective_scale", -1.0)) - expected_scale) > 0.001:
		_fail("Unexpected effective movement time scale: %s" % snapshot)
		return false
	for request_id in expected_request_ids:
		if not requests.has(request_id):
			_fail("Expected slowdown request is missing: %s snapshot=%s" % [request_id, snapshot])
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
