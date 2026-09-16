extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	set_meta("main_launch_request", {"source": "verify_t0355_r3", "startup_mode": 0})
	root.add_child(MAIN_SCENE.instantiate())
	for _index in range(4):
		await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if npc_system == null or time_system == null or controller == null:
		_fail("save-location restore dependencies unavailable")
		return
	time_system.set_paused(true)

	var npc_ids: Array = npc_system.get_npc_ids()
	var expected_locations: Dictionary = {}
	for index in range(npc_ids.size()):
		var raw_npc_id: Variant = npc_ids[index]
		var npc_id := str(raw_npc_id)
		var location_id := "plaza" if index < 4 else "dining_hall"
		expected_locations[npc_id] = location_id
		npc_system.update_npc_state(npc_id, {
			"current_location": location_id,
			"current_location_name": "广场" if location_id == "plaza" else "食堂",
		})
		npc_system.restore_npc_world_position_after_system_interrupt(npc_id, Vector3(200.0, 0.0, 200.0))

	var checkpoint: Dictionary = npc_system.create_formal_spatial_checkpoint()
	if str(checkpoint.get("schema", "")) != "formal_npc_spatial_checkpoint_v2" or checkpoint.has("world_origin"):
		_fail("new NPC spatial checkpoint did not use location-only v2")
		return
	for raw_actor in checkpoint.get("actors", []):
		if not raw_actor is Dictionary or (raw_actor as Dictionary).has("position"):
			_fail("new NPC spatial checkpoint still contains an actor coordinate")
			return

	if not _restore_and_verify(npc_system, controller, checkpoint, npc_ids, expected_locations, "v2"):
		return

	var legacy_checkpoint := checkpoint.duplicate(true)
	legacy_checkpoint["schema"] = "formal_npc_spatial_checkpoint_v1"
	legacy_checkpoint["world_origin"] = {"x": 1000.0, "y": 0.0, "z": 1000.0}
	var legacy_actors: Array = legacy_checkpoint.get("actors", [])
	for index in range(legacy_actors.size()):
		var legacy_actor: Dictionary = (legacy_actors[index] as Dictionary).duplicate(true)
		legacy_actor["position"] = {"x": -999.0, "y": 20.0, "z": -999.0}
		legacy_actors[index] = legacy_actor
	legacy_checkpoint["actors"] = legacy_actors
	if not _restore_and_verify(npc_system, controller, legacy_checkpoint, npc_ids, expected_locations, "v1 compatibility"):
		return

	var first_npc_id := str(npc_ids[0])
	var fallback_checkpoint := checkpoint.duplicate(true)
	var fallback_actors: Array = fallback_checkpoint.get("actors", [])
	var fallback_actor: Dictionary = (fallback_actors[0] as Dictionary).duplicate(true)
	fallback_actor["information_location_id"] = "missing_test_location"
	fallback_actors[0] = fallback_actor
	fallback_checkpoint["actors"] = fallback_actors
	var fallback_result: Dictionary = npc_system.restore_formal_spatial_checkpoint(fallback_checkpoint)
	var initial_position: Variant = controller.get_npc_initial_world_position(first_npc_id)
	var fallback_position: Variant = npc_system.get_npc_world_position(first_npc_id)
	if (
		not bool(fallback_result.get("ok", false))
		or not (fallback_result.get("fallback_npc_ids", []) as Array).has(first_npc_id)
		or not initial_position is Vector3
		or not fallback_position is Vector3
		or (fallback_position as Vector3).distance_to(initial_position as Vector3) > 0.01
	):
		_fail("missing stay-position config did not report and use the personal initial fallback")
		return

	var escaped_checkpoint := checkpoint.duplicate(true)
	var escaped_actors: Array = escaped_checkpoint.get("actors", [])
	var escaped_actor: Dictionary = (escaped_actors[0] as Dictionary).duplicate(true)
	escaped_actor["escaped"] = true
	escaped_actor["information_location_id"] = "outside_station"
	escaped_actors[0] = escaped_actor
	escaped_checkpoint["actors"] = escaped_actors
	var escaped_result: Dictionary = npc_system.restore_formal_spatial_checkpoint(escaped_checkpoint)
	var escaped_state: Dictionary = npc_system.get_npc_state(first_npc_id)
	if (
		not bool(escaped_result.get("ok", false))
		or not (escaped_result.get("escaped_npc_ids", []) as Array).has(first_npc_id)
		or str(escaped_state.get("current_location", "")) != "outside_station"
	):
		_fail("escaped NPC was incorrectly restored into a station location")
		return

	print("T0355_R3_LOCATION_STAY_RESTORE_PASS")
	root.get_node("Main").queue_free()
	await process_frame
	quit(0)


func _restore_and_verify(
	npc_system: Node,
	controller: Node,
	checkpoint: Dictionary,
	npc_ids: Array,
	expected_locations: Dictionary,
	label: String
) -> bool:
	for raw_npc_id in npc_ids:
		npc_system.restore_npc_world_position_after_system_interrupt(
			str(raw_npc_id),
			Vector3(-150.0, 0.0, -150.0)
		)
	var restore_result: Dictionary = npc_system.restore_formal_spatial_checkpoint(checkpoint)
	if not bool(restore_result.get("ok", false)) or not (restore_result.get("fallback_npc_ids", []) as Array).is_empty():
		_fail("%s restore failed or used fallback: %s" % [label, JSON.stringify(restore_result)])
		return false
	var restored_positions: Array[Vector3] = []
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		var location_id := str(expected_locations.get(npc_id, "plaza"))
		var expected: Variant = controller.get_npc_stay_world_position(location_id, npc_id)
		var actual: Variant = npc_system.get_npc_world_position(npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if (
			not expected is Vector3
			or not actual is Vector3
			or (actual as Vector3).distance_to(expected as Vector3) > 0.01
			or str(state.get("current_location", "")) != location_id
			or str(state.get("spatial_route_phase", "")) != "save_restored_location_stay_position"
		):
			_fail("%s did not restore %s to its assigned %s stay point" % [label, npc_id, location_id])
			return false
		for other_position in restored_positions:
			if (actual as Vector3).distance_to(other_position) < 0.5:
				_fail("%s restored multiple NPCs to an overlapping stay point" % label)
				return false
		restored_positions.append(actual as Vector3)
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
