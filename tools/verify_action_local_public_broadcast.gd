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

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if action_system == null or npc_system == null or memory_system == null or resource_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	if not await _verify_action_broadcast(
		action_system,
		npc_system,
		memory_system,
		"gardener_01",
		"doctor_01",
		"garden",
		"work_garden",
		["work_started", "work_completed"]
	):
		quit(1)
		return

	resource_system.add_resource("meal", 1)
	npc_system.update_npc_state("cook_01", {"satiety": 40, "last_action_result": ""})
	if not await _verify_action_broadcast(
		action_system,
		npc_system,
		memory_system,
		"cook_01",
		"veteran_deputy_01",
		"dining_hall",
		"eat_at_dining_hall",
		["eat_started", "eat_completed"]
	):
		quit(1)
		return

	npc_system.update_npc_state("priest_01", {"fatigue": 70, "last_action_result": ""})
	if not await _verify_action_broadcast(
		action_system,
		npc_system,
		memory_system,
		"priest_01",
		"engineer_01",
		"dormitory",
		"sleep_in_dormitory",
		["sleep_started", "sleep_ended"]
	):
		quit(1)
		return

	print("Action local_public broadcast verification passed.")
	quit(0)


func _verify_action_broadcast(
	action_system: Node,
	npc_system: Node,
	memory_system: Node,
	actor_id: String,
	witness_id: String,
	location_id: String,
	action_id: String,
	expected_event_types: Array[String]
) -> bool:
	if not npc_system.debug_enter_location_immediately(witness_id, location_id):
		push_error("Failed to place witness %s in %s" % [witness_id, location_id])
		return false
	if not npc_system.debug_enter_location_immediately(actor_id, location_id):
		push_error("Failed to place actor %s in %s" % [actor_id, location_id])
		return false

	var witness_before: int = memory_system.get_npc_witness_events(witness_id).size()
	var actor_witness_before: int = memory_system.get_npc_witness_events(actor_id).size()
	if not action_system.debug_assign_action(actor_id, action_id):
		push_error("Failed to assign action %s to %s" % [action_id, actor_id])
		return false
	await process_frame
	var duration_seconds := _duration_for_action(action_id)
	action_system._on_logical_time_tick(duration_seconds, 1.0)
	await process_frame

	var witness_events: Array = memory_system.get_npc_witness_events(witness_id)
	for event_type in expected_event_types:
		if not _has_new_witness_event(witness_events, witness_before, actor_id, location_id, event_type):
			push_error("%s did not receive %s from %s at %s" % [witness_id, event_type, actor_id, location_id])
			return false

	var actor_witness_events: Array = memory_system.get_npc_witness_events(actor_id)
	if actor_witness_events.size() > actor_witness_before:
		for index in range(actor_witness_before, actor_witness_events.size()):
			var event: Dictionary = actor_witness_events[index]
			if str(event.get("subject_npc_id", "")) == actor_id and expected_event_types.has(str(event.get("type", ""))):
				push_error("Actor %s received own action event as witness" % actor_id)
				return false

	return true


func _duration_for_action(action_id: String) -> float:
	match action_id:
		"eat_at_dining_hall":
			return 1200.0
		"sleep_in_dormitory":
			return 23400.0
		_:
			return 3600.0


func _has_new_witness_event(
	events: Array,
	start_index: int,
	subject_npc_id: String,
	location_id: String,
	event_type: String
) -> bool:
	for index in range(start_index, events.size()):
		var event: Dictionary = events[index]
		if (
			str(event.get("type", "")) == event_type
			and str(event.get("subject_npc_id", "")) == subject_npc_id
			and str(event.get("location_id", "")) == location_id
			and str(event.get("visibility", "")) == "local_public"
		):
			return true
	return false
