extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	if npc_system == null or building_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	var npc_id := "veteran_deputy_01"
	_set_debug_move_speed(npc_id, 60.0)
	for building_id in ["dining_hall", "dormitory", "warehouse"]:
		if not npc_system.debug_move_npc_to_building(npc_id, building_id):
			push_error("debug_move_npc_to_building failed for %s" % building_id)
			quit(1)
			return

		var moving_state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(moving_state.get("current_action", "")) != "moving_to_%s" % building_id:
			push_error("NPC did not enter moving state for %s" % building_id)
			quit(1)
			return

		if not await _wait_until_npc_reaches(npc_system, npc_id, building_id):
			push_error("NPC did not reach %s before timeout" % building_id)
			quit(1)
			return

		var arrived_state: Dictionary = npc_system.get_npc_state(npc_id)
		var location_context: Dictionary = arrived_state.get("location_context", {})
		if str(arrived_state.get("current_action", "")) != "idle":
			push_error("NPC did not return to idle after arrival at %s" % building_id)
			quit(1)
			return
		var expected_context_id: String = building_id
		if building_id == "warehouse":
			expected_context_id = "plaza"
		if str(location_context.get("id", "")) != expected_context_id:
			push_error("NPC location context missing for %s" % building_id)
			quit(1)
			return

	print("T0304 NPC movement and location verification passed.")
	quit(0)


func _wait_until_npc_reaches(npc_system: Node, npc_id: String, building_id: String) -> bool:
	for frame in range(480):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("current_location", "")) == building_id:
			return true
	return false


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return

	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return
