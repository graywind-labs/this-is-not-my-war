extends SceneTree


class ControlledDialogueBridge:
	extends Node

	signal dialogue_async_response_received(result: Dictionary)
	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)

	var invitation_request: Dictionary = {}
	var conversation_requests: Array[Dictionary] = []

	func request_npc_dialogue_async(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
		var request_id := str(options.get("request_id", "verify_dialogue_%d" % (conversation_requests.size() + 1)))
		var request := {
			"request_id": request_id,
			"npc_id": npc_id,
			"speaker_text": speaker_text,
			"options": options.duplicate(true)
		}
		if str(options.get("dialogue_phase", "conversation")) == "invitation":
			invitation_request = request
		else:
			conversation_requests.append(request)
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_invitation_accept() -> void:
		if invitation_request.is_empty():
			return
		var request := invitation_request.duplicate(true)
		invitation_request.clear()
		dialogue_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"dialogue": {
				"ok": true,
				"replyer_id": str(request.get("npc_id", "")),
				"reply_text": "好，我们就在这里说。",
				"response_kind": "reply_to_npc",
				"invitation_result": "accept",
				"emotion": "neutral",
				"should_end_dialogue": false,
				"suggested_event_type": "dialogue_turn",
				"debug_reason": "a5_p6c_controlled_accept",
				"model_provider": "fake_real_provider",
				"model_name": "functional-test",
				"model_fallback_used": false
			}
		})

	func cancel_npc_llm_requests(_npc_id: String, _reason: String = "cancelled") -> Dictionary:
		return {"ok": true, "cancelled": false, "reason": "no_active_request"}

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_dialogue_plan_revision_judgement_async(npc_id: String, _options: Dictionary = {}) -> Dictionary:
		return {"ok": true, "pending": true, "request_id": "a5_p6c_judgement_%s" % npc_id}

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {"model_adapter": {
				"provider": "fake_real_provider",
				"model": "functional-test",
				"configured": true,
				"fallback_to_mock": false
			}}
		}


const SPEAKER_ID := "stableman_01"
const TARGET_ID := "doctor_01"
const TARGET_ACTION_ID := "work_clinic_doctor"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var systems := root.get_node_or_null("Main/Systems")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var run_button := gm_window.find_child("FormalNpcDialogueButton", true, false) as Button if gm_window != null else null
	var stop_button := gm_window.find_child("FormalNpcDialogueStopButton", true, false) as Button if gm_window != null else null
	var snapshot_button := gm_window.find_child("FormalNpcDialogueSnapshotButton", true, false) as Button if gm_window != null else null
	if [systems, npc_system, action_system, building_system, dialog_system, daily_plan_system, time_system, gm_panel, gm_window, original_bridge, run_button, stop_button, snapshot_button].has(null):
		_fail("A5-P6c runtime or GM dependencies unavailable")
		return
	var action: Dictionary = action_system.get_action("talk_to_npc")
	if not bool(action.get("formal_spatial_route", false)) or absf(float(action.get("approach_distance", 0.0)) - 1.35) > 0.001:
		_fail("talk_to_npc formal route configuration missing")
		return

	time_system.set_time_scale(0.0)
	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	for raw_npc_id in npc_system.get_npc_ids():
		original_bridge.cancel_npc_llm_requests(str(raw_npc_id), "verify_a5_p6c_isolation")
	daily_plan_system.set("_async_plan_queue", [])
	daily_plan_system.set("_async_plan_requests", {})
	systems.remove_child(original_bridge)
	original_bridge.name = "PayloadLLMBridge"
	main.add_child(original_bridge)
	var fake_bridge := ControlledDialogueBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)
	fake_bridge.dialogue_async_response_received.connect(Callable(dialog_system, "_on_dialogue_async_response_received"))

	_set_move_speed(npc_system, SPEAKER_ID, 5.0)
	_set_move_speed(npc_system, TARGET_ID, 5.0)
	npc_system.debug_enter_location_immediately(SPEAKER_ID, "plaza")
	npc_system.debug_enter_location_immediately(TARGET_ID, "clinic")
	if not action_system.debug_assign_action(TARGET_ID, TARGET_ACTION_ID):
		_fail("Could not start target clinic work")
		return
	if not await _wait_for_action_phase(action_system, TARGET_ID, TARGET_ACTION_ID, "active", 1800):
		_fail("Target did not reach the formal clinic workstation: %s" % JSON.stringify({
			"runtime": action_system.get_runtime_action_snapshot(TARGET_ID),
			"state": npc_system.get_npc_state(TARGET_ID),
			"spatial": npc_system.debug_get_spatial_migration_snapshot(TARGET_ID),
			"formal": npc_system.get_formal_workstation_action_snapshot(TARGET_ID)
		}))
		return
	if not _workstation_owned_by(building_system.get_building("clinic"), TARGET_ID):
		_fail("Target clinic workstation ownership missing")
		return
	var target_work_position: Variant = npc_system.get_npc_world_position(TARGET_ID)

	var npc_select := gm_panel.get("_npc_select") as OptionButton
	var target_select := gm_panel.get("_npc_dialogue_target_select") as OptionButton
	if not _select_id(npc_select, SPEAKER_ID) or not _select_id(target_select, TARGET_ID):
		_fail("Could not select formal dialogue participants in GM")
		return
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	if gm_window.visible:
		_fail("Successful GM formal dialogue did not close the panel")
		return
	var pending: Dictionary = action_system.get_runtime_action_snapshot(SPEAKER_ID)
	if (
		str(pending.get("phase", "")) != "pending"
		or not bool((pending.get("options", {}) as Dictionary).get("formal_dialogue_authority", false))
		or not bool(npc_system.get_formal_dialogue_approach_snapshot(SPEAKER_ID).get("active", false))
		or not fake_bridge.invitation_request.is_empty()
	):
		_fail("Formal dialogue did not begin as a physical pending route")
		return

	if not await _wait_for_invitation(dialog_system, fake_bridge, 2400):
		_fail("Speaker did not physically reach the target: %s" % JSON.stringify({
			"runtime": action_system.get_runtime_action_snapshot(SPEAKER_ID),
			"speaker": npc_system.debug_get_spatial_migration_snapshot(SPEAKER_ID),
			"target": npc_system.debug_get_spatial_migration_snapshot(TARGET_ID),
			"formal": npc_system.get_formal_dialogue_approach_snapshot(SPEAKER_ID)
		}))
		return
	var speaker_position: Variant = npc_system.get_npc_world_position(SPEAKER_ID)
	var target_position: Variant = npc_system.get_npc_world_position(TARGET_ID)
	var distance := _horizontal_distance(speaker_position, target_position)
	if (
		distance < 0.85
		or distance > 1.7
		or not _workstation_owned_by(building_system.get_building("clinic"), TARGET_ID)
		or str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != TARGET_ACTION_ID
		or not target_work_position is Vector3
		or not target_position is Vector3
		or target_position.distance_to(target_work_position) > 0.01
	):
		_fail("Invitation-pending spatial/work ownership contract failed: distance=%.3f" % distance)
		return

	fake_bridge.answer_invitation_accept()
	if not await _wait_for_dialogue_status(dialog_system, "active", 120):
		_fail("Accepted invitation did not activate formal dialogue")
		return
	var accepted_target_position: Variant = npc_system.get_npc_world_position(TARGET_ID)
	if (
		_workstation_owned_by(building_system.get_building("clinic"), TARGET_ID)
		or str(npc_system.get_npc_state(SPEAKER_ID).get("current_action", "")) != "talk_to_npc"
		or str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != "talk_to_npc"
		or not accepted_target_position is Vector3
		or accepted_target_position.distance_to(target_work_position) > 0.01
	):
		_fail("Invitation acceptance did not transfer target spatial ownership atomically")
		return

	dialog_system.end_dialogue("verify_a5_p6c_completed")
	await process_frame
	await physics_frame
	if (
		dialog_system.has_active_dialogue()
		or bool(npc_system.get_formal_dialogue_approach_snapshot(SPEAKER_ID).get("active", true))
		or str(npc_system.get_npc_state(SPEAKER_ID).get("current_action", "")) != "idle"
		or str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != "idle"
	):
		_fail("Dialogue completion left formal spatial authority behind")
		return
	snapshot_button.pressed.emit()
	stop_button.pressed.emit()
	print("T0129C A5-P6c formal NPC dialogue verification passed")
	quit(0)


func _wait_for_invitation(dialog_system: Node, fake_bridge: Node, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		if (
			str(dialog_system.get_dialogue_state().get("session_status", "")) == "invitation_pending"
			and not fake_bridge.get("invitation_request").is_empty()
		):
			return true
	return false


func _wait_for_dialogue_status(dialog_system: Node, expected_status: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await process_frame
		if str(dialog_system.get_dialogue_state().get("session_status", "")) == expected_status:
			return true
	return false


func _wait_for_action_phase(action_system: Node, npc_id: String, action_id: String, phase: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		var snapshot: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(snapshot.get("action_id", "")) == action_id and str(snapshot.get("phase", "")) == phase:
			return true
	return false


func _set_move_speed(npc_system: Node, npc_id: String, speed: float) -> void:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	var npc_node := npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))
	if npc_node != null and "move_speed" in npc_node:
		npc_node.move_speed = speed


func _select_id(select: OptionButton, expected_id: String) -> bool:
	if select == null:
		return false
	for index in range(select.item_count):
		if str(select.get_item_metadata(index)) == expected_id:
			select.select(index)
			return true
	return false


func _workstation_owned_by(building: Dictionary, npc_id: String) -> bool:
	for raw_workstation in building.get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("occupied_by", "")) == npc_id:
			return true
	return false


func _horizontal_distance(a: Variant, b: Variant) -> float:
	if not a is Vector3 or not b is Vector3:
		return INF
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
