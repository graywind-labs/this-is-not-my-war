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
	if npc_system == null:
		push_error("NPCSystem not found")
		quit(1)
		return

	if npc_system.get_npc_count() != 8:
		push_error("Expected 8 NPCs, got %d" % npc_system.get_npc_count())
		quit(1)
		return

	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null or npc_root.get_child_count() != 8:
		push_error("Expected 8 spawned NPC nodes")
		quit(1)
		return

	var signal_state := {"clicked_id": ""}
	var event_bus := root.get_node_or_null("/root/EventBus")
	if event_bus == null:
		push_error("EventBus autoload not found")
		quit(1)
		return

	if event_bus != null:
		event_bus.npc_clicked.connect(func(npc_id: String) -> void:
			signal_state["clicked_id"] = npc_id
		)

	var expected_id := "veteran_deputy_01"
	if not npc_system.debug_select_npc(expected_id):
		push_error("debug_select_npc failed")
		quit(1)
		return

	if str(signal_state["clicked_id"]) != expected_id:
		push_error("Expected npc_clicked for %s, got %s" % [expected_id, str(signal_state["clicked_id"])])
		quit(1)
		return

	print("T0302 NPC generation and click verification passed.")
	quit(0)
