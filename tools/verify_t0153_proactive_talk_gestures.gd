extends SceneTree


const NPC_ID := "cook_01"
const INTERVAL := 5.0


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
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if [npc_system, dialog_system, daily_plan_system, time_system, llm_bridge, camera].has(null):
		_fail("T0153 runtime dependencies unavailable")
		return
	daily_plan_system.set_auto_execution_enabled(false)
	for _frame in range(8):
		await process_frame
		await physics_frame
	for raw_npc_id in npc_system.get_npc_ids():
		var fixture_npc_id := str(raw_npc_id)
		llm_bridge.cancel_npc_llm_requests(fixture_npc_id, "verify_t0153_isolation")
		if str(npc_system.get_npc_state(fixture_npc_id).get("current_action", "")) == "planning_day":
			npc_system.update_npc_state(fixture_npc_id, {
				"current_action": "idle",
				"last_action_result": "t0153_fixture_ready"
			})
	time_system.set_time_scale(1.0)
	time_system.set_paused(false)

	var npc_position: Vector3 = npc_system.get_npc_world_position(NPC_ID)
	camera.global_position = npc_position + Vector3(10.0, 8.0, 0.0)
	var request_counter_before := int(llm_bridge.get("_request_counter"))
	var start_result: Dictionary = npc_system.start_proactive_talk(NPC_ID, "守备官，我有事情要和你谈。", 3600.0)
	if not bool(start_result.get("ok", false)) or not bool((start_result.get("presentation", {}) as Dictionary).get("ok", false)):
		_fail("Proactive talk did not start its first presentation gesture")
		return
	var events := _proactive_events(npc_system)
	if events.size() != 1 or int(events[0].get("gesture_index", 0)) != 1:
		_fail("Bubble appearance must emit exactly one immediate gesture")
		return
	var first_direction: Vector3 = events[0].get("facing_direction", Vector3.ZERO)
	if first_direction.dot(Vector3.RIGHT) < 0.99:
		_fail("First proactive gesture did not face the current camera")
		return

	npc_system.call("_advance_proactive_talk_presentations", INTERVAL - 0.1)
	if _proactive_events(npc_system).size() != 1:
		_fail("Gesture repeated before the configured real-time interval")
		return
	camera.global_position = npc_position + Vector3(0.0, 8.0, 10.0)
	npc_system.call("_advance_proactive_talk_presentations", 0.2)
	events = _proactive_events(npc_system)
	if events.size() != 2:
		_fail("Gesture did not repeat at the configured real-time interval")
		return
	var second_direction: Vector3 = events[1].get("facing_direction", Vector3.ZERO)
	if second_direction.dot(Vector3.BACK) < 0.99 or first_direction.dot(second_direction) > 0.1:
		_fail("Repeated gesture did not resample the moved game camera")
		return

	for speed in [1.0, 2.0, 4.0]:
		time_system.set_time_scale(speed)
		var count_before := _proactive_events(npc_system).size()
		npc_system.call("_advance_proactive_talk_presentations", INTERVAL)
		if _proactive_events(npc_system).size() != count_before + 1:
			_fail("Player speed x%.0f changed proactive real-time gesture frequency" % speed)
			return
	if int(llm_bridge.get("_request_counter")) != request_counter_before:
		_fail("Presentation loop created an LLM request")
		return

	time_system.set_paused(true)
	var paused_count := _proactive_events(npc_system).size()
	var paused_snapshot: Dictionary = npc_system.get_proactive_talk_presentation_snapshot(NPC_ID)
	var paused_remaining := float(paused_snapshot.get("remaining_real_seconds", -1.0))
	npc_system.call("_advance_proactive_talk_presentations", 50.0)
	var frozen_snapshot: Dictionary = npc_system.get_proactive_talk_presentation_snapshot(NPC_ID)
	if (
		_proactive_events(npc_system).size() != paused_count
		or not is_equal_approx(float(frozen_snapshot.get("remaining_real_seconds", -2.0)), paused_remaining)
	):
		_fail("Pause did not freeze proactive presentation time")
		return
	time_system.set_paused(false)
	npc_system.call("_advance_proactive_talk_presentations", paused_remaining - 0.05)
	if _proactive_events(npc_system).size() != paused_count:
		_fail("Resume caught up a proactive gesture too early")
		return
	npc_system.call("_advance_proactive_talk_presentations", 0.1)
	if _proactive_events(npc_system).size() != paused_count + 1:
		_fail("Resume did not continue from the frozen normal cycle")
		return

	if not npc_system.handle_npc_clicked(NPC_ID):
		_fail("Player acceptance did not consume proactive interaction")
		return
	await process_frame
	if not npc_system.get_proactive_talk_presentation_snapshot(NPC_ID).is_empty():
		_fail("Player acceptance left a gesture loop behind")
		return
	if dialog_system.has_active_dialogue():
		dialog_system.end_dialogue("verify_t0153_accept_cleanup", {"skip_plan_reevaluation": true})

	if not _verify_actor_termination(npc_system, "doctor_01", {"unconscious": true}, "unconscious"):
		return
	if not _verify_actor_termination(npc_system, "gardener_01", {"escaped": true}, "escaped"):
		return
	var cancel_start: Dictionary = npc_system.start_proactive_talk("blacksmith_01", "请看向守备官。", 3600.0)
	if not bool(cancel_start.get("ok", false)):
		_fail("Cancellation fixture could not start")
		return
	npc_system.cancel_proactive_talk("blacksmith_01", "verify_cancelled")
	if not npc_system.get_proactive_talk_presentation_snapshot("blacksmith_01").is_empty():
		_fail("Explicit cancellation left a gesture loop behind")
		return
	var expiry_start: Dictionary = npc_system.start_proactive_talk("stableman_01", "这个请求很快过期。", 1.0)
	if not bool(expiry_start.get("ok", false)):
		_fail("Expiry fixture could not start")
		return
	root.get_node("EventBus").logical_time_tick.emit(1.1, 1.0)
	await process_frame
	if not npc_system.get_proactive_talk_presentation_snapshot("stableman_01").is_empty():
		_fail("Expired proactive request left a gesture loop behind")
		return

	print("T0153 proactive talk gesture verification passed.")
	quit(0)


func _verify_actor_termination(npc_system: Node, npc_id: String, changes: Dictionary, label: String) -> bool:
	var start_result: Dictionary = npc_system.start_proactive_talk(npc_id, "守备官，请听我说。", 3600.0)
	if not bool(start_result.get("ok", false)):
		_fail("%s fixture could not start" % label)
		return false
	npc_system.update_npc_state(npc_id, changes)
	npc_system.call("_advance_proactive_talk_presentations", 0.0)
	if not npc_system.get_proactive_talk_presentation_snapshot(npc_id).is_empty():
		_fail("%s transition left a gesture loop behind" % label)
		return false
	var restore := {"unconscious": false, "escaped": false, "behavior_mode": "work", "current_action": "idle"}
	npc_system.update_npc_state(npc_id, restore)
	return true


func _proactive_events(npc_system: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var snapshot: Dictionary = npc_system.get_temporary_presentation_event_snapshot()
	for raw_event in snapshot.get("events", []):
		if raw_event is Dictionary and str(raw_event.get("event_kind", "")) == "proactive_talk_gesture":
			result.append((raw_event as Dictionary).duplicate(true))
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
