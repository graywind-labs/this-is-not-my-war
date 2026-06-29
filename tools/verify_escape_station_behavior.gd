extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var cook_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01") as Node3D
	if (
		combat_system == null
		or npc_system == null
		or memory_system == null
		or action_system == null
		or gm_panel == null
		or cook_node == null
	):
		push_error("Escape verification required nodes not found")
		quit(1)
		return

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()

	cook_node.global_position = Vector3(-10.0, 0.0, -22.7)
	var escape_result: Dictionary = combat_system.debug_start_npc_escape("cook_01", "verify_debug")
	if not bool(escape_result.get("ok", false)):
		push_error("Debug escape should start: %s" % JSON.stringify(escape_result))
		quit(1)
		return

	var state: Dictionary = npc_system.get_npc_state("cook_01")
	var intent: Dictionary = state.get("escape_intent", {})
	if str(state.get("behavior_mode", "")) != "escaped":
		push_error("Escaping NPC should leave work/combat behavior immediately: %s" % JSON.stringify(state))
		quit(1)
		return
	if bool(state.get("escaped", false)):
		push_error("NPC should not be marked escaped before reaching the exit")
		quit(1)
		return
	if not bool(intent.get("active", false)) or str(intent.get("status", "")) != "escaping":
		push_error("Escape intent should be active and escaping: %s" % JSON.stringify(intent))
		quit(1)
		return
	if str(state.get("movement_target", "")) != "back_gate_escape_exit":
		push_error("Escaping NPC should move to back gate exit: %s" % JSON.stringify(state))
		quit(1)
		return
	if npc_system.can_npc_act("cook_01"):
		push_error("Escaping NPC should not accept normal actions")
		quit(1)
		return
	if action_system.debug_assign_action("cook_01", "eat_at_dining_hall"):
		push_error("ActionSystem should reject an escaping NPC")
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "escape_started").is_empty():
		push_error("Escape start should be public in plaza events")
		quit(1)
		return

	var snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	if _find_npc_entry(snapshot.get("active_escapes", []), "cook_01").is_empty():
		push_error("Combat snapshot should expose active escape: %s" % JSON.stringify(snapshot))
		quit(1)
		return

	for _i in range(120):
		await process_frame
		state = npc_system.get_npc_state("cook_01")
		if bool(state.get("escaped", false)):
			break

	state = npc_system.get_npc_state("cook_01")
	if not bool(state.get("escaped", false)):
		push_error("NPC should be marked escaped after reaching exit: %s" % JSON.stringify(state))
		quit(1)
		return
	if str(state.get("current_action", "")) != "escaped" or str(state.get("current_location", "")) != "outside_station":
		push_error("Escaped NPC should have final escaped action and outside location: %s" % JSON.stringify(state))
		quit(1)
		return
	intent = state.get("escape_intent", {})
	if bool(intent.get("active", true)) or str(intent.get("status", "")) != "escaped":
		push_error("Escape intent should be completed after leaving map: %s" % JSON.stringify(intent))
		quit(1)
		return
	if cook_node.visible or cook_node.input_ray_pickable:
		push_error("Escaped NPC node should be hidden and unpickable")
		quit(1)
		return
	if not _find_npc_entry(combat_system.debug_get_combat_snapshot().get("active_escapes", []), "cook_01").is_empty():
		push_error("Completed escape should be removed from active escape snapshot")
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "escaped").is_empty():
		push_error("Escaped event should be public in plaza events")
		quit(1)
		return

	gm_panel._execute_command("escape_npc priest_01")
	await process_frame
	var priest_state: Dictionary = npc_system.get_npc_state("priest_01")
	if str(priest_state.get("escape_intent", {}).get("status", "")) != "escaping":
		push_error("GM escape command should call CombatSystem escape entry: %s" % JSON.stringify(priest_state))
		quit(1)
		return

	print("Escape station behavior verification passed.")
	quit(0)


func _last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == event_type:
			return event
	return {}


func _find_npc_entry(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if str(entry.get("npc_id", "")) == npc_id:
			return entry
	return {}
