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
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if action_system == null or npc_system == null or memory_system == null or resource_system == null or time_system == null:
		push_error("Required systems not found")
		quit(1)
		return
	time_system.set_paused(false)

	if not await _verify_action_broadcast(
		action_system,
		npc_system,
		memory_system,
		time_system,
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
		time_system,
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
		time_system,
		"priest_01",
		"engineer_01",
		"dormitory",
		"sleep_in_dormitory",
		["sleep_started", "sleep_ended"]
	):
		quit(1)
		return

	if not await _verify_sleep_blocks_witness_then_restores(action_system, npc_system, memory_system, time_system):
		quit(1)
		return

	print("Action local_public broadcast verification passed.")
	quit(0)


func _verify_action_broadcast(
	action_system: Node,
	npc_system: Node,
	memory_system: Node,
	time_system: Node,
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
	if not await _wait_for_active(action_system, time_system, actor_id, action_id):
		push_error("Action %s for %s did not reach its formal workstation" % [action_id, actor_id])
		return false
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


func _verify_sleep_blocks_witness_then_restores(
	action_system: Node,
	npc_system: Node,
	memory_system: Node,
	time_system: Node
) -> bool:
	var sleeper_id := "stableman_01"
	var actor_id := "blacksmith_01"
	var location_id := "dormitory"
	if not npc_system.debug_enter_location_immediately(sleeper_id, location_id):
		push_error("Failed to place sleeper in dormitory")
		return false
	if not npc_system.debug_enter_location_immediately(actor_id, location_id):
		push_error("Failed to place dormitory actor")
		return false
	npc_system.update_npc_state(sleeper_id, {"fatigue": 70, "last_action_result": ""})

	if not action_system.debug_assign_sleep(sleeper_id):
		push_error("Failed to assign sleep action for witness blocking test")
		return false
	if not await _wait_for_active(action_system, time_system, sleeper_id, "sleep_in_dormitory"):
		push_error("Sleeper did not reach the assigned bed")
		return false

	if str(npc_system.get_npc_state(sleeper_id).get("current_action", "")) != "sleep_in_dormitory":
		push_error("Sleeper did not enter sleep action")
		return false

	var witness_before: int = memory_system.get_npc_witness_events(sleeper_id).size()
	_emit_manual_public_work_event(memory_system, actor_id, location_id)
	if memory_system.get_npc_witness_events(sleeper_id).size() != witness_before:
		push_error("Sleeping NPC should not receive same-location local_public witness events")
		return false

	action_system._on_logical_time_tick(23400.0, 1.0)
	await process_frame
	if str(npc_system.get_npc_state(sleeper_id).get("current_action", "")) != "idle":
		push_error("Sleeper should return to idle after sleep completes")
		return false

	witness_before = memory_system.get_npc_witness_events(sleeper_id).size()
	_emit_manual_public_work_event(memory_system, actor_id, location_id)
	if memory_system.get_npc_witness_events(sleeper_id).size() <= witness_before:
		push_error("NPC should receive witness events again after waking")
		return false

	return true


func _wait_for_active(
	action_system: Node,
	time_system: Node,
	npc_id: String,
	action_id: String,
	max_frames: int = 1800
) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _emit_manual_public_work_event(memory_system: Node, actor_id: String, location_id: String) -> void:
	memory_system.add_event({
		"type": "work_started",
		"subject_npc_id": actor_id,
		"actor_ids": [actor_id],
		"target_ids": [location_id, "work_garden"],
		"location_id": location_id,
		"visibility": "local_public",
		"importance": 20,
		"payload": {
			"action_id": "work_garden",
			"workstation_id": location_id
		}
	})


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
