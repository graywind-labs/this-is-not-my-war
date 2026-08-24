extends SceneTree


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
		var request_id := "upgrade_judgement_%d" % (judgement_requests.size() + 1)
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
		var request_id := "upgrade_revision_%d" % (revision_requests.size() + 1)
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
				"summary": "deterministic building-upgrade judgement",
				"debug_reason": "verification",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})


	func answer_revision(request: Dictionary, revised_items: Array) -> void:
		var immediate_action: Variant = revised_items[0].duplicate(true) if not revised_items.is_empty() else null
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision": {
				"ok": true,
				"npc_id": str(request.get("npc_id", "")),
				"revised_plan": revised_items.duplicate(true),
				"immediate_action": immediate_action,
				"summary": "deterministic building-upgrade revision",
				"debug_reason": "verification",
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


const CURRENT_HOUR := 8
const TRAVEL_NPC_ID := "cook_01"
const ACTIVE_NPC_ID := "gardener_01"
const COMPLETION_NPC_ID := "doctor_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var systems := root.get_node_or_null("Main/Systems")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [
		systems,
		time_system,
		resource_system,
		building_system,
		npc_system,
		action_system,
		daily_plan_system,
		original_bridge
	].has(null):
		_fail("Required runtime nodes are missing")
		return

	time_system.set_current_time(1, CURRENT_HOUR, 0, 0)
	daily_plan_system.set_auto_execution_enabled(false)
	for resource_id in ["wood", "stone", "money", "grain", "meal"]:
		resource_system.add_resource(resource_id, 100)

	var assist_work_plan := _make_upgrade_assist_plan("clinic", 6)
	var assist_schema_plan: Array = original_bridge._plan_items_to_schema(assist_work_plan)
	if (
		int(original_bridge._count_schema_work_phases(assist_schema_plan)) != 6
		or str(assist_schema_plan[0].get("location_id", "")) != "plaza"
		or str(assist_schema_plan[0].get("target_id", "")) != "clinic"
	):
		_fail(
			"LLMBridge lost upgrade-assist work count or outdoor location: %s"
			% JSON.stringify(assist_schema_plan)
		)
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
	if int(daily_plan_system._count_work_phases(assist_work_plan)) != 6:
		_fail("assist_upgrade was not counted as a work phase by DailyPlanSystem")
		return

	if not await _verify_travel_failure(
		bridge,
		daily_plan_system,
		action_system,
		npc_system,
		building_system
	):
		return
	if not await _verify_active_failure(
		bridge,
		daily_plan_system,
		action_system,
		npc_system,
		building_system
	):
		return
	if not await _verify_completed_upgrade_followup(
		bridge,
		daily_plan_system,
		action_system,
		npc_system,
		building_system
	):
		return

	print("T0057/T0085 building-upgrade action-failure verification passed.")
	quit(0)


func _verify_travel_failure(
	bridge: CapturingLLMBridge,
	daily_plan_system: Node,
	action_system: Node,
	npc_system: Node,
	building_system: Node
) -> bool:
	if not _prepare_plan(
		daily_plan_system,
		TRAVEL_NPC_ID,
		"work_dining_hall",
		"dining_hall"
	):
		return false
	action_system.interrupt_npc_action(TRAVEL_NPC_ID, "t0057_travel_reset", true)
	npc_system.debug_enter_location_immediately(TRAVEL_NPC_ID, "plaza")
	daily_plan_system.set_auto_execution_enabled(true)
	if not action_system.debug_assign_action(TRAVEL_NPC_ID, "work_dining_hall"):
		_fail("Could not start the travel-phase dining action")
		return false
	var before_upgrade: Dictionary = action_system.get_runtime_action_snapshot(TRAVEL_NPC_ID)
	if str(before_upgrade.get("phase", "")) != "pending":
		_fail("Dining action was not pending while travelling: %s" % JSON.stringify(before_upgrade))
		return false
	for frame in range(12):
		await physics_frame
		if str(npc_system.get_npc_state(TRAVEL_NPC_ID).get("movement_target", "")) == "dining_hall":
			break
	if not building_system.upgrade_building("dining_hall"):
		_fail("Could not start dining hall upgrade")
		return false
	var travelling_after_upgrade: Dictionary = action_system.get_runtime_action_snapshot(TRAVEL_NPC_ID)
	var travelling_state: Dictionary = npc_system.get_npc_state(TRAVEL_NPC_ID)
	if (
		str(travelling_after_upgrade.get("phase", "")) != "pending"
		or str(travelling_state.get("movement_target", "")) != "dining_hall"
		or str(travelling_state.get("last_action_result", "")).contains("failed_building_upgrading")
		or bridge.judgement_requests.size() != 0
	):
		_fail(
			"Pending action learned about the upgrade before reaching the door: %s"
			% JSON.stringify({
				"runtime": travelling_after_upgrade,
				"state": travelling_state,
				"judgements": bridge.judgement_requests
			})
		)
		return false
	if not _force_formal_entry_check(npc_system, TRAVEL_NPC_ID):
		_fail("Could not advance the formal dining route to its door-entry check")
		return false
	if not _assert_upgrade_failure(
		TRAVEL_NPC_ID,
		"work_dining_hall",
		"dining_hall",
		"pending",
		npc_system,
		action_system
	):
		return false
	if bridge.judgement_requests.size() != 1:
		_fail("Door rejection did not start exactly one failure judgement")
		return false
	var request: Dictionary = bridge.judgement_requests.back()
	if not _assert_judgement_request(request, TRAVEL_NPC_ID, "dining_hall", "pending"):
		return false
	bridge.answer_judgement(request, [])
	if str(daily_plan_system.get_last_reevaluation_result().get("status", "")) != "action_failure_plan_unchanged":
		_fail("Travel failure zero-stage judgement did not finish cleanly")
		return false
	return true


func _verify_active_failure(
	bridge: CapturingLLMBridge,
	daily_plan_system: Node,
	action_system: Node,
	npc_system: Node,
	building_system: Node
) -> bool:
	daily_plan_system.set_auto_execution_enabled(false)
	if not _prepare_plan(
		daily_plan_system,
		ACTIVE_NPC_ID,
		"work_garden",
		"garden"
	):
		return false
	action_system.interrupt_npc_action(ACTIVE_NPC_ID, "t0057_active_reset", true)
	npc_system.debug_enter_location_immediately(ACTIVE_NPC_ID, "garden")
	daily_plan_system.set_auto_execution_enabled(true)
	_set_debug_move_speed(npc_system, ACTIVE_NPC_ID, 8.0)
	if not action_system.debug_assign_action(ACTIVE_NPC_ID, "work_garden"):
		_fail("Could not start the active garden action")
		return false
	var before_upgrade: Dictionary = {}
	for frame in range(1800):
		await physics_frame
		before_upgrade = action_system.get_runtime_action_snapshot(ACTIVE_NPC_ID)
		if str(before_upgrade.get("phase", "")) == "active":
			break
	if str(before_upgrade.get("phase", "")) != "active":
		_fail("Garden action did not become active: %s" % JSON.stringify(before_upgrade))
		return false
	if not building_system.upgrade_building("garden"):
		_fail("Could not start garden upgrade")
		return false
	if not _assert_upgrade_failure(
		ACTIVE_NPC_ID,
		"work_garden",
		"garden",
		"active",
		npc_system,
		action_system
	):
		return false
	if bridge.judgement_requests.size() != 2:
		_fail("Active interruption did not start exactly one additional failure judgement")
		return false
	var judgement_request: Dictionary = bridge.judgement_requests.back()
	if not _assert_judgement_request(judgement_request, ACTIVE_NPC_ID, "garden", "active"):
		return false
	bridge.answer_judgement(judgement_request, [CURRENT_HOUR])
	if bridge.revision_requests.size() != 1:
		_fail("Non-empty building-upgrade judgement did not launch stage two")
		return false
	var revision_request: Dictionary = bridge.revision_requests.back()
	var revision_options: Dictionary = revision_request.get("options", {})
	var revision_context: Dictionary = revision_options.get("failure_context", {})
	if (
		revision_options.get("revision_hours", []) != [CURRENT_HOUR]
		or str(revision_options.get("failure_type", "")) != "target_unavailable"
		or str(revision_context.get("failure_reason", "")) != "building_upgrading"
		or str(revision_context.get("interrupted_phase", "")) != "active"
	):
		_fail("Stage two lost the building-upgrade failure context: %s" % JSON.stringify(revision_options))
		return false
	bridge.answer_revision(
		revision_request,
		[_item(CURRENT_HOUR, "idle", "idle", "")]
	)
	var applied_result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if not bool(applied_result.get("plan_applied", false)):
		_fail("Building-upgrade stage-two revision was not applied: %s" % JSON.stringify(applied_result))
		return false
	return true


func _verify_completed_upgrade_followup(
	bridge: CapturingLLMBridge,
	daily_plan_system: Node,
	action_system: Node,
	npc_system: Node,
	building_system: Node
) -> bool:
	daily_plan_system.set_auto_execution_enabled(false)
	action_system.interrupt_npc_action(COMPLETION_NPC_ID, "t0085_completion_reset", true)
	npc_system.debug_enter_location_immediately(COMPLETION_NPC_ID, "plaza")
	npc_system.update_npc_state(COMPLETION_NPC_ID, {
		"last_action_result": "work_clinic_doctor_failed_building_upgrading",
		"last_action_failure_context": {
			"action_id": "work_clinic_doctor",
			"building_id": "clinic",
			"condition": "upgrading",
			"failure_reason": "building_upgrading",
			"failure_summary": "陈旧的诊所升级中断上下文。"
		}
	})
	if not building_system.upgrade_building("clinic"):
		_fail("Could not start clinic upgrade for completion follow-up")
		return false
	if not daily_plan_system.set_npc_daily_plan(
		COMPLETION_NPC_ID,
		_make_upgrade_assist_plan("clinic", 1),
		false,
		"verify_upgrade_completion"
	):
		_fail("Could not install upgrade-assist completion plan")
		return false
	if not action_system.debug_assign_upgrade_assist(COMPLETION_NPC_ID, "clinic"):
		_fail("Doctor could not start assisting the clinic upgrade")
		return false
	_snap_formal_actor_to_service_target(npc_system, COMPLETION_NPC_ID)
	for frame in range(6):
		await physics_frame
	if str(npc_system.get_npc_state(COMPLETION_NPC_ID).get("last_action_result", "")) != "assist_upgrade_started_clinic":
		_fail("Doctor did not physically commit at the clinic construction slot")
		return false
	building_system._finish_upgrade("clinic")
	var completed_state: Dictionary = npc_system.get_npc_state(COMPLETION_NPC_ID)
	if (
		str(completed_state.get("current_action", "")) != "idle"
		or not str(completed_state.get("last_action_result", "")).begins_with(
			"completed_assist_upgrade_clinic"
		)
		or not (completed_state.get("last_action_failure_context", {}) as Dictionary).is_empty()
	):
		_fail(
			"Upgrade completion did not clear stale action failure context: %s"
			% JSON.stringify(completed_state)
		)
		return false

	var judgement_count_before := bridge.judgement_requests.size()
	daily_plan_system.set_auto_execution_enabled(true)
	daily_plan_system.execute_current_plan_for_npc(COMPLETION_NPC_ID, true)
	if bridge.judgement_requests.size() != judgement_count_before + 1:
		_fail("Resolved upgrade target did not start exactly one follow-up judgement")
		return false
	var judgement_request: Dictionary = bridge.judgement_requests.back()
	var judgement_options: Dictionary = judgement_request.get("options", {})
	var judgement_context: Dictionary = judgement_options.get("failure_context", {})
	if (
		str(judgement_options.get("failure_type", "")) != "target_unavailable"
		or str(judgement_context.get("failure_reason", "")) != "no_active_upgrade"
		or str(judgement_context.get("building_id", "")) != "clinic"
		or str(judgement_context.get("action_id", "")) != "assist_upgrade"
		or str(judgement_context.get("failure_summary", "")).contains("正在升级")
	):
		_fail(
			"Upgrade completion reused stale failure context: %s"
			% JSON.stringify(judgement_request)
		)
		return false

	bridge.answer_judgement(judgement_request, [CURRENT_HOUR])
	if bridge.revision_requests.is_empty():
		_fail("Upgrade completion judgement did not launch the selected-hour revision")
		return false
	var revision_request: Dictionary = bridge.revision_requests.back()
	bridge.answer_revision(
		revision_request,
		[{
			"hour": CURRENT_HOUR,
			"action_kind": "work",
			"action_id": "work_clinic_doctor",
			"location_id": "clinic",
			"target_id": null,
			"priority": 80,
			"reason": "恢复坐诊",
			"dialogue_goal": ""
		}]
	)
	var result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	var current_item: Dictionary = daily_plan_system.get_current_plan_item(COMPLETION_NPC_ID)
	if (
		not bool(result.get("plan_applied", false))
		or str(current_item.get("action_id", "")) != "work_clinic_doctor"
		or int(daily_plan_system._count_work_phases(
			daily_plan_system.get_npc_daily_plan(COMPLETION_NPC_ID)
		)) != 1
	):
		_fail(
			"Soft work minimum blocked the valid clinic follow-up revision: %s"
			% JSON.stringify({
				"result": result,
				"current_item": current_item,
				"plan": daily_plan_system.get_npc_daily_plan(COMPLETION_NPC_ID)
			})
		)
		return false
	return true


func _prepare_plan(
	daily_plan_system: Node,
	npc_id: String,
	action_id: String,
	location_id: String
) -> bool:
	if daily_plan_system.set_npc_daily_plan(
		npc_id,
		_make_plan(action_id, location_id),
		false,
		"verify_building_upgrade_failure"
	):
		return true
	_fail("Could not install deterministic plan for %s" % npc_id)
	return false


func _assert_upgrade_failure(
	npc_id: String,
	action_id: String,
	building_id: String,
	expected_phase: String,
	npc_system: Node,
	action_system: Node
) -> bool:
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var result_id := str(state.get("last_action_result", ""))
	var context: Dictionary = state.get("last_action_failure_context", {})
	if (
		result_id != "%s_failed_building_upgrading" % action_id
		or str(state.get("current_action", "")) != "idle"
		or str(state.get("current_location", "")) != "plaza"
		or str(state.get("movement_target", "")) != ""
		or not action_system.get_runtime_action_snapshot(npc_id).is_empty()
		or str(context.get("action_id", "")) != action_id
		or str(context.get("building_id", "")) != building_id
		or str(context.get("condition", "")) != "upgrading"
		or str(context.get("failure_reason", "")) != "building_upgrading"
		or str(context.get("unavailable_reason", "")) != "建筑正在升级"
		or str(context.get("interrupted_phase", "")) != expected_phase
		or (
			expected_phase == "pending"
			and (
				not bool(context.get("arrival_check_failed", false))
				or not str(context.get("failure_summary", "")).contains("入口后")
			)
		)
		or (
			expected_phase == "active"
			and not str(context.get("failure_summary", "")).contains("开始升级")
		)
	):
		_fail("Upgrade interruption did not produce the expected failure: %s" % JSON.stringify(state))
		return false
	return true


func _assert_judgement_request(
	request: Dictionary,
	npc_id: String,
	building_id: String,
	expected_phase: String
) -> bool:
	var options: Dictionary = request.get("options", {})
	var context: Dictionary = options.get("failure_context", {})
	if (
		str(request.get("npc_id", "")) != npc_id
		or str(options.get("trigger_kind", "")) != "action_failure"
		or str(options.get("failure_type", "")) != "target_unavailable"
		or str(context.get("building_id", "")) != building_id
		or str(context.get("failure_reason", "")) != "building_upgrading"
		or str(context.get("interrupted_phase", "")) != expected_phase
		or (
			expected_phase == "pending"
			and (
				not bool(context.get("arrival_check_failed", false))
				or not str(options.get("failure_summary", "")).contains("入口后")
			)
		)
		or (
			expected_phase == "active"
			and not str(options.get("failure_summary", "")).contains("开始升级")
		)
	):
		_fail("Failure judgement lost the building-upgrade facts: %s" % JSON.stringify(request))
		return false
	return true


func _make_plan(action_id: String, location_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		if hour >= CURRENT_HOUR and hour < CURRENT_HOUR + 7:
			plan.append(_item(hour, "work", action_id, location_id))
		else:
			plan.append(_item(hour, "idle", "idle", ""))
	return plan


func _make_upgrade_assist_plan(building_id: String, work_phase_count: int) -> Array:
	var plan: Array = []
	for hour in range(24):
		if hour == CURRENT_HOUR or hour < maxi(0, work_phase_count - 1):
			plan.append({
				"hour": hour,
				"action_kind": "assist_upgrade",
				"action_id": "assist_upgrade",
				"location_id": "",
				"target_id": building_id,
				"priority": 80,
				"reason": "协助升级",
				"expected_outcome": "推进升级",
				"target": {
					"target_id": building_id,
					"building_id": building_id,
					"location_id": "plaza"
				}
			})
		else:
			plan.append(_item(hour, "idle", "idle", ""))
	return plan


func _item(hour: int, action_kind: String, action_id: String, location_id: String) -> Dictionary:
	return {
		"hour": hour,
		"action_kind": action_kind,
		"action_id": action_id,
		"location_id": location_id,
		"target_id": "",
		"priority": 60,
		"reason": "verification",
		"expected_outcome": "verification",
		"target": {}
	}


func _snap_formal_actor_to_service_target(npc_system: Node, npc_id: String) -> void:
	var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(npc_id)
	var session: Dictionary = formal.get("session", {}) if formal.get("session", {}) is Dictionary else {}
	var target_position: Variant = session.get("service_target_position")
	var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
	if npc_node != null and target_position is Vector3:
		npc_node.global_position = target_position


func _set_debug_move_speed(npc_system: Node, npc_id: String, speed: float) -> void:
	var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath()))
	if npc_node != null:
		npc_node.move_speed = speed


func _force_formal_entry_check(npc_system: Node, npc_id: String) -> bool:
	if not npc_system._building_interior_routes.has(npc_id):
		return false
	var route: Dictionary = npc_system._building_interior_routes[npc_id]
	var steps: Array = route.get("steps", [])
	for index in range(steps.size()):
		if steps[index] is Dictionary and bool((steps[index] as Dictionary).get("check_entry", false)):
			route["step_index"] = index
			npc_system._building_interior_routes[npc_id] = route
			npc_system._on_building_interior_route_arrived(npc_id, str((steps[index] as Dictionary).get("id", "")))
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
