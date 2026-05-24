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
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	if npc_system == null or memory_system == null or building_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	var plaza_npc_id := "priest_01"
	var indoor_npc_id := "doctor_01"
	if not npc_system.debug_enter_location_immediately(plaza_npc_id, "plaza"):
		push_error("Failed to move priest into plaza")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately(indoor_npc_id, "clinic"):
		push_error("Failed to move doctor into clinic")
		quit(1)
		return

	var plaza_snapshot: Dictionary = memory_system.debug_get_location_snapshot("plaza")
	if plaza_snapshot.get("building", {}) != {}:
		push_error("Plaza snapshot should not expose plaza building HP")
		quit(1)
		return
	if not plaza_snapshot.get("key_entities", {}).has("main_hall"):
		push_error("Plaza snapshot missing main hall key entity")
		quit(1)
		return
	if not plaza_snapshot.has("current_npc_count") or not plaza_snapshot.has("current_enemy_count"):
		push_error("Plaza snapshot missing current NPC/enemy counts")
		quit(1)
		return

	var plaza_witness_before: int = memory_system.get_npc_witness_events(plaza_npc_id).size()
	var indoor_witness_before: int = memory_system.get_npc_witness_events(indoor_npc_id).size()
	var public_event: Dictionary = memory_system.add_event({
		"type": "combat_started",
		"subject_npc_id": indoor_npc_id,
		"actor_ids": ["system"],
		"target_ids": ["debug_wave"],
		"visibility": "plaza_public",
		"importance": 80,
		"payload": {"wave_id": "debug_wave"}
	})
	if public_event.is_empty():
		push_error("Failed to create plaza_public event")
		quit(1)
		return
	if str(public_event.get("location_id", "")) != "plaza":
		push_error("plaza_public event without location did not default to plaza")
		quit(1)
		return
	if memory_system.get_npc_witness_events(plaza_npc_id).size() <= plaza_witness_before:
		push_error("plaza_public event was not broadcast to plaza NPC")
		quit(1)
		return
	if memory_system.get_npc_witness_events(indoor_npc_id).size() != indoor_witness_before:
		push_error("plaza_public event leaked to NPC outside plaza")
		quit(1)
		return

	var notice_witness_before: int = memory_system.get_npc_witness_events(plaza_npc_id).size()
	memory_system.debug_set_plaza_notice("Debug notice")
	if memory_system.debug_get_location_snapshot("plaza").get("current_notice", "") != "Debug notice":
		push_error("Plaza notice did not update current snapshot")
		quit(1)
		return
	if memory_system.get_npc_witness_events(plaza_npc_id).size() <= notice_witness_before:
		push_error("Plaza notice change was not written to plaza NPC witness log")
		quit(1)
		return

	var status_witness_before: int = memory_system.get_npc_witness_events(plaza_npc_id).size()
	if not building_system.debug_damage_building("wall", 5):
		push_error("Failed to damage wall")
		quit(1)
		return
	if memory_system.get_npc_witness_events(plaza_npc_id).size() <= status_witness_before:
		push_error("Key entity state change was not broadcast to plaza NPC")
		quit(1)
		return

	print("T0404 plaza public broadcast verification passed.")
	quit(0)
