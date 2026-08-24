extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const PRAYER_NPC_ID := "blacksmith_01"
const CURRENT_HOUR := 8


class CapturingLLMBridge:
	extends Node

	signal plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_async_response_received(result: Dictionary)

	var judgement_requests: Array[Dictionary] = []
	var revision_requests: Array[Dictionary] = []

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func check_health() -> Dictionary:
		return _real_health()

	func request_plan_revision_judgement_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "t0094_mass_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func request_npc_plan_revision_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "t0094_mass_revision_%d" % (revision_requests.size() + 1)
		revision_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_judgement(request: Dictionary, revision_hours: Array) -> void:
		plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision_judgement": {
				"ok": true,
				"npc_id": str(request.get("npc_id", "")),
				"needs_revision": not revision_hours.is_empty(),
				"revision_hours": revision_hours.duplicate(),
				"summary": "当前宗教活动需要调整。",
				"debug_reason": "T0094 deterministic judgement",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func answer_revision(request: Dictionary, revised_item: Dictionary) -> void:
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision": {
				"ok": true,
				"npc_id": str(request.get("npc_id", "")),
				"revised_plan": [revised_item.duplicate(true)],
				"immediate_action": revised_item.duplicate(true),
				"summary": "改为前往小教堂祈祷。",
				"debug_reason": "T0098 deterministic revision",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "deepseek",
					"model": "capture-real-provider",
					"configured": true,
					"fallback_to_mock": false
				}
			}
		}


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await process_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var systems := root.get_node_or_null("Main/Systems")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [
		action_system,
		building_system,
		memory_system,
		npc_system,
		daily_plan_system,
		time_system,
		systems,
		original_bridge
	].has(null):
		_fail("Required systems are missing")
		return
	daily_plan_system.set_auto_execution_enabled(false)

	if not await _verify_prayer_requires_arrival(
		action_system,
		building_system,
		memory_system,
		npc_system
	):
		return

	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var bridge := CapturingLLMBridge.new()
	bridge.name = "LLMBridge"
	systems.add_child(bridge)
	bridge.plan_revision_judgement_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_judgement_async_response")
	)
	bridge.plan_revision_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_async_response")
	)

	time_system.set_current_time(1, CURRENT_HOUR, 0, 0)
	if not await _verify_mass_transition_without_revision(
		action_system,
		building_system,
		npc_system,
		daily_plan_system,
		bridge
	):
		return
	if not await _verify_dialogue_commitment_revision(
		action_system,
		npc_system,
		daily_plan_system,
		bridge
	):
		return

	print("T0098 merged Mass/prayer runtime verification passed.")
	quit(0)


func _verify_prayer_requires_arrival(
	action_system: Node,
	building_system: Node,
	memory_system: Node,
	npc_system: Node
) -> bool:
	action_system.interrupt_npc_action(PRAYER_NPC_ID, "t0094_prayer_transit_setup", true)
	if not npc_system.debug_enter_location_immediately(PRAYER_NPC_ID, "chapel"):
		_fail("Could not place prayer transit actor in chapel")
		return false
	if not npc_system.move_npc_to_building(PRAYER_NPC_ID, "plaza"):
		_fail("Could not start outbound movement from chapel")
		return false
	var outbound_state: Dictionary = npc_system.get_npc_state(PRAYER_NPC_ID)
	if (
		str(outbound_state.get("current_location", "")) != "chapel"
		or str(outbound_state.get("movement_target", "")) != "plaza"
	):
		_fail("Transit setup did not preserve the old logical location")
		return false
	if not action_system.debug_assign_action(PRAYER_NPC_ID, "pray_at_chapel"):
		_fail("Prayer assignment should be accepted and reroute the NPC to chapel")
		return false
	if action_system.get_active_action_id(PRAYER_NPC_ID) == "pray_at_chapel":
		_fail("Prayer became active while the NPC was still travelling outside chapel")
		return false
	if action_system.get_pending_action_id(PRAYER_NPC_ID) != "pray_at_chapel":
		_fail("Prayer should remain pending until chapel arrival")
		return false
	if _is_occupied_by(
		building_system.get_building("chapel").get("workstations", []),
		PRAYER_NPC_ID
	):
		_fail("Prayer claimed a seat before chapel arrival")
		return false

	if not action_system.interrupt_npc_action(
		PRAYER_NPC_ID,
		"t0094_prayer_transit_interrupted",
		true
	):
		_fail("Could not interrupt the rerouted prayer movement")
		return false
	var interrupted_state: Dictionary = npc_system.get_npc_state(PRAYER_NPC_ID)
	if (
		str(interrupted_state.get("current_location", "")) != "chapel"
		or not str(interrupted_state.get("movement_target", "")).is_empty()
		or bool(npc_system.get_formal_workstation_action_snapshot(PRAYER_NPC_ID).get("active", true))
	):
		_fail("Interrupted formal prayer route did not restore its pre-session location")
		return false
	if (
		not memory_system.get_location_people_present("chapel").has(PRAYER_NPC_ID)
		or memory_system.get_location_people_present("plaza").has(PRAYER_NPC_ID)
	):
		_fail("Interrupted travel left the location information nodes inconsistent")
		return false
	if bool(action_system.call("_execute_action", PRAYER_NPC_ID, "pray_at_chapel")):
		_fail("Private execution bypass started prayer outside chapel")
		return false
	if (
		action_system.get_active_action_id(PRAYER_NPC_ID) == "pray_at_chapel"
		or _is_occupied_by(
			building_system.get_building("chapel").get("workstations", []),
			PRAYER_NPC_ID
		)
	):
		_fail("Prayer guard changed active state or claimed a seat outside chapel")
		return false
	action_system.interrupt_npc_action(PRAYER_NPC_ID, "t0094_prayer_guard_cleanup", true)
	return true


func _verify_mass_transition_without_revision(
	action_system: Node,
	building_system: Node,
	npc_system: Node,
	daily_plan_system: Node,
	bridge: CapturingLLMBridge
) -> bool:
	var priest_id := "priest_01"
	var prayer_ids := ["gardener_01", "blacksmith_01"]
	var pending_prayer_id := "stableman_01"
	var interrupted_prayer_ids := prayer_ids + [pending_prayer_id]
	for npc_id in [priest_id] + interrupted_prayer_ids:
		action_system.interrupt_npc_action(npc_id, "t0094_mass_setup", true)
		var setup_location := "plaza" if npc_id == pending_prayer_id else "chapel"
		if not npc_system.debug_enter_location_immediately(npc_id, setup_location):
			_fail("Could not place Mass actor in chapel: %s" % npc_id)
			return false
	for npc_id in prayer_ids:
		if not daily_plan_system.set_npc_daily_plan(
			npc_id,
			_make_plan("pray_at_chapel", "pray", "chapel"),
			false,
			"verify_t0094_mass"
		):
			_fail("Could not install prayer plan for %s" % npc_id)
			return false
		var start_result: Dictionary = daily_plan_system.execute_current_plan_for_npc(
			npc_id,
			true
		)
		if not bool(start_result.get("ok", false)) or not await _wait_for_active(action_system, npc_id, "pray_at_chapel"):
			_fail("Could not start planned prayer for %s: %s" % [
				npc_id,
				JSON.stringify(start_result)
			])
			return false

	if not daily_plan_system.set_npc_daily_plan(
		pending_prayer_id,
		_make_plan("pray_at_chapel", "pray", "chapel"),
		false,
		"verify_t0094_pending_mass"
	):
		_fail("Could not install pending prayer plan")
		return false
	var pending_start: Dictionary = daily_plan_system.execute_current_plan_for_npc(
		pending_prayer_id,
		true
	)
	var pending_state_before_mass: Dictionary = npc_system.get_npc_state(
		pending_prayer_id
	)
	if (
		not bool(pending_start.get("ok", false))
		or action_system.get_pending_action_id(pending_prayer_id)
		!= "pray_at_chapel"
		or action_system.has_active_action(pending_prayer_id)
		or not bool(npc_system.get_formal_workstation_action_snapshot(pending_prayer_id).get("active", false))
	):
		_fail("Could not keep planned prayer pending while travelling to chapel")
		return false

	daily_plan_system.set_auto_execution_enabled(true)
	var judgement_start_index := bridge.judgement_requests.size()
	if not action_system.debug_assign_action(priest_id, "lead_mass"):
		_fail("Priest could not start Mass")
		return false
	if not await _wait_for_active(action_system, priest_id, "lead_mass"):
		_fail("Priest did not physically reach the altar")
		return false
	var new_judgements := bridge.judgement_requests.slice(judgement_start_index)
	if not new_judgements.is_empty():
		_fail("Mass start must not launch plan revision for merged prayer")
		return false
	for npc_id in prayer_ids:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if (
			str(runtime.get("action_id", "")) != "pray_at_chapel"
			or str(runtime.get("prayer_mode", "")) != "mass_attendance"
			or not state.get("last_action_failure_context", {}).is_empty()
			or not _is_occupied_by(
				building_system.get_building("chapel").get("workstations", []),
				npc_id
			)
		):
			_fail("Mass start did not preserve and convert prayer: %s" % npc_id)
			return false
	var pending_state_after_mass: Dictionary = npc_system.get_npc_state(pending_prayer_id)
	if (
		action_system.get_pending_action_id(pending_prayer_id) != "pray_at_chapel"
		or action_system.has_active_action(pending_prayer_id)
		or not bool(npc_system.get_formal_workstation_action_snapshot(pending_prayer_id).get("active", false))
	):
		_fail("Mass start must preserve prayer that is still travelling")
		return false
	if not await _wait_for_active(action_system, pending_prayer_id, "pray_at_chapel"):
		_fail("Pending prayer did not physically reach its seat during Mass")
		return false
	var arrived_runtime: Dictionary = action_system.get_runtime_action_snapshot(
		pending_prayer_id
	)
	if (
		str(arrived_runtime.get("action_id", "")) != "pray_at_chapel"
		or str(arrived_runtime.get("prayer_mode", "")) != "mass_attendance"
	):
		_fail("Prayer arriving during Mass should immediately attend it")
		return false
	action_system.interrupt_npc_action(priest_id, "t0098_mass_stopped", true)
	if bridge.judgement_requests.size() != judgement_start_index:
		_fail("Mass end must not launch plan revision for merged prayer")
		return false
	for npc_id in interrupted_prayer_ids:
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if (
			str(runtime.get("action_id", "")) != "pray_at_chapel"
			or str(runtime.get("prayer_mode", "")) != "personal_prayer"
			or not npc_system.get_npc_state(npc_id).get(
				"last_action_failure_context",
				{}
			).is_empty()
		):
			_fail("Mass end did not resume the original prayer: %s" % npc_id)
			return false
	return true


func _verify_dialogue_commitment_revision(
	action_system: Node,
	npc_system: Node,
	daily_plan_system: Node,
	bridge: CapturingLLMBridge
) -> bool:
	var npc_id := "veteran_deputy_01"
	var priest_id := "priest_01"
	for actor_id in [npc_id, priest_id]:
		action_system.interrupt_npc_action(actor_id, "t0098_dialogue_mass_setup", true)
		if not npc_system.debug_enter_location_immediately(actor_id, "chapel"):
			_fail("Could not place dialogue Mass actor in chapel")
			return false
	if not action_system.debug_assign_action(priest_id, "lead_mass"):
		_fail("Could not start Mass for dialogue commitment verification")
		return false
	if not await _wait_for_active(action_system, priest_id, "lead_mass"):
		_fail("Mass leader did not reach the altar for dialogue verification")
		return false
	if str(npc_system.get_npc_state(npc_id).get("current_location", "")) != "chapel":
		_fail("Could not place dialogue actor in chapel")
		return false
	if not daily_plan_system.set_npc_daily_plan(
		npc_id,
		_make_plan("idle", "idle", ""),
		false,
		"verify_t0094_dialogue_mass"
	):
		_fail("Could not install dialogue commitment plan")
		return false
	var dialogue_history := [
		{
			"speaker_type": "player",
			"speaker_id": "guard_officer",
			"speaker_name": "守备官",
			"text": "弥撒已经开始了，请你现在去小教堂参加弥撒。"
		},
		{
			"speaker_type": "npc",
			"speaker_id": npc_id,
			"speaker_name": "艾达",
			"text": "明白，我现在就去参加弥撒。"
		}
	]
	var judgement_count_before := bridge.judgement_requests.size()
	var judgement_start: Dictionary = (
		daily_plan_system.request_dialogue_plan_revision_judgement(
			npc_id,
			{
				"dialogue_id": "t0094_dialogue_mass_commitment",
				"dialogue_kind": "player_npc",
				"dialogue_end_reason": "dialogue_completed",
				"dialogue_history": dialogue_history,
				"dialogue_initiator": "player",
				"visibility": "private",
				"location_id": "chapel",
				"location_name": "小教堂",
				"participant_npc_ids": [npc_id],
				"target_npc_id": npc_id
			}
		)
	)
	if (
		str(judgement_start.get("status", "")) != "dialogue_plan_judgement_pending"
		or bridge.judgement_requests.size() != judgement_count_before + 1
	):
		_fail("Explicit Mass commitment did not enter normal dialogue judgement")
		return false
	var judgement_request: Dictionary = bridge.judgement_requests.back()
	var judgement_options: Dictionary = judgement_request.get("options", {})
	if (
		str(judgement_options.get("trigger_kind", "")) != "dialogue"
		or judgement_options.get("dialogue_history", []) != dialogue_history
	):
		_fail("Dialogue Mass commitment history did not reach stage one")
		return false
	var revision_count_before := bridge.revision_requests.size()
	bridge.answer_judgement(judgement_request, [CURRENT_HOUR])
	if bridge.revision_requests.size() != revision_count_before + 1:
		_fail("Dialogue Mass commitment did not launch formal revision")
		return false
	var revision_request: Dictionary = bridge.revision_requests.back()
	var revision_context: Dictionary = (
		(revision_request.get("options", {}) as Dictionary).get("failure_context", {})
	)
	if (
		str(revision_request.get("npc_id", "")) != npc_id
		or (revision_request.get("options", {}) as Dictionary).get(
			"revision_hours",
			[]
		) != [CURRENT_HOUR]
		or revision_context.get("dialogue_history", []) != dialogue_history
	):
		_fail("Dialogue Mass commitment lost history or exact current hour in stage two")
		return false
	bridge.answer_revision(
		revision_request,
		_item(CURRENT_HOUR, "pray_at_chapel", "pray", "chapel")
	)
	if not await _wait_for_active(action_system, npc_id, "pray_at_chapel"):
		_fail("Revised prayer did not physically reach a seat during Mass")
		return false
	var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
	if (
		str(runtime.get("action_id", "")) != "pray_at_chapel"
		or str(runtime.get("prayer_mode", "")) != "mass_attendance"
	):
		_fail("Accepted current Mass commitment was revised but did not execute immediately")
		return false
	return true


func _make_plan(
	current_action_id: String,
	current_action_kind: String,
	current_location_id: String
) -> Array:
	var plan: Array = []
	for hour in range(24):
		if hour == CURRENT_HOUR:
			plan.append(_item(
				hour,
				current_action_id,
				current_action_kind,
				current_location_id
			))
		else:
			plan.append(_item(hour, "idle", "idle", ""))
	return plan


func _item(
	hour: int,
	action_id: String,
	action_kind: String,
	location_id: String
) -> Dictionary:
	return {
		"hour": hour,
		"action_kind": action_kind,
		"action_id": action_id,
		"location_id": location_id,
		"target_id": "",
		"priority": 60,
		"reason": "T0094 verification",
		"dialogue_goal": "",
		"source": "verify_t0094_mass"
	}


func _is_occupied_by(raw_workstations: Variant, npc_id: String) -> bool:
	if not raw_workstations is Array:
		return false
	for raw_workstation in raw_workstations:
		if (
			raw_workstation is Dictionary
			and str((raw_workstation as Dictionary).get("occupied_by", "")) == npc_id
		):
			return true
	return false


func _wait_for_active(action_system: Node, npc_id: String, action_id: String, max_frames: int = 1800) -> bool:
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	for _frame in range(max_frames):
		if time_system != null:
			time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
