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
		var request_id := "failure_judgement_%d" % (judgement_requests.size() + 1)
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
		var request_id := "failure_revision_%d" % (revision_requests.size() + 1)
		revision_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_judgement(request: Dictionary, revision_hours: Array, needs_revision: bool) -> void:
		plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision_judgement": {
				"ok": true,
				"npc_id": str(request.get("npc_id", "")),
				"needs_revision": needs_revision,
				"revision_hours": revision_hours.duplicate(),
				"summary": "deterministic action-failure judgement",
				"debug_reason": "verification",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func answer_revision(
		request: Dictionary,
		revised_items: Array,
		immediate_action: Variant
	) -> void:
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision": {
				"ok": true,
				"npc_id": str(request.get("npc_id", "")),
				"revised_plan": revised_items.duplicate(true),
				"immediate_action": immediate_action,
				"summary": "deterministic selected-hour revision",
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


const NPC_ID := "cook_01"
const CURRENT_HOUR := 8


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
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [systems, time_system, npc_system, daily_plan_system, original_bridge].has(null):
		_fail("Required runtime nodes are missing")
		return

	time_system.set_current_time(1, CURRENT_HOUR, 0, 0)
	daily_plan_system.set_auto_execution_enabled(false)
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, _make_plan(), false, "verify_failure_judgement"):
		_fail("Could not install deterministic plan")
		return
	var builder_failure_context := {
		"building_id": "dining_hall",
		"workstation_type": "cooking_station",
		"blocked_by_npc_ids": ["priest_01"]
	}
	var builder_payload: Dictionary = original_bridge.build_plan_revision_judgement_payload(
		NPC_ID,
		{
			"trigger_kind": "action_failure",
			"current_plan": daily_plan_system.get_npc_daily_plan(NPC_ID),
			"failed_plan_item": daily_plan_system.get_current_plan_item(NPC_ID),
			"failure_type": "workstation_occupied",
			"failure_summary": "食堂工作位被占用。",
			"failure_context": builder_failure_context
		}
	)
	if (
		str(builder_payload.get("trigger_kind", "")) != "action_failure"
		or str(builder_payload.get("failure_type", "")) != "workstation_occupied"
		or int(builder_payload.get("current_work_phase_count", -1)) != 6
		or not bool(builder_payload.get("replacement_work_phase_required_if_non_work", false))
		or not (builder_payload.get("dialogue_history", []) as Array).is_empty()
	):
		_fail("LLMBridge action-failure judgement payload is incomplete: %s" % JSON.stringify(builder_payload))
		return
	for required_field in [
		"station_context",
		"npc",
		"allowed_actions",
		"current_building_states",
		"current_resource_states"
	]:
		if not builder_payload.has(required_field):
			_fail("Action-failure judgement payload lost context field '%s'" % required_field)
			return
	var judgement_npc: Dictionary = builder_payload.get("npc", {})
	for required_npc_field in [
		"identity",
		"state",
		"current_order",
		"short_term_memory",
		"long_term_memory",
		"location_context"
	]:
		if not judgement_npc.has(required_npc_field):
			_fail("Action-failure judgement lost NPC context '%s'" % required_npc_field)
			return
	var builder_revision_payload: Dictionary = original_bridge.build_npc_plan_revision_payload(
		NPC_ID,
		{
			"current_plan": daily_plan_system.get_npc_daily_plan(NPC_ID),
			"failed_plan_item": daily_plan_system.get_current_plan_item(NPC_ID),
			"revision_hours": [CURRENT_HOUR, 14],
			"failure_type": "workstation_occupied",
			"failure_summary": "食堂工作位被占用。",
			"failure_context": builder_failure_context
		}
	)
	var revision_npc: Dictionary = builder_revision_payload.get("npc", {})
	if (
		str(builder_revision_payload.get("failure_type", "")) != "workstation_occupied"
		or builder_revision_payload.get("failure_context", {}) != builder_failure_context
		or not revision_npc.has("identity")
		or not revision_npc.has("short_term_memory")
		or not revision_npc.has("long_term_memory")
		or not revision_npc.has("current_order")
	):
		_fail("Formal revision payload lost failure or character context: %s" % JSON.stringify(builder_revision_payload))
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

	var failed_item: Dictionary = daily_plan_system.get_current_plan_item(NPC_ID)
	var failure_context := builder_failure_context.duplicate(true)
	var no_change_start: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"work_failed_no_workstation",
		failed_item,
		"食堂工作位被占用。",
		failure_context
	)
	if str(no_change_start.get("status", "")) != "plan_revision_judgement_pending":
		_fail("Action failure did not start stage-one judgement: %s" % JSON.stringify(no_change_start))
		return
	if bridge.judgement_requests.size() != 1 or not bridge.revision_requests.is_empty():
		_fail("Action failure skipped or duplicated stage one")
		return
	if not bool(daily_plan_system.call("_has_pending_dialogue_plan_chain", NPC_ID)):
		_fail("Pending action-failure judgement did not retain an existing dialogue dispatch barrier")
		return
	var first_request: Dictionary = bridge.judgement_requests.back()
	var first_options: Dictionary = first_request.get("options", {})
	if (
		str(first_options.get("trigger_kind", "")) != "action_failure"
		or str(first_options.get("failure_type", "")) != "workstation_occupied"
		or (first_options.get("current_plan", []) as Array).size() != 24
		or not first_options.get("dialogue_history", []).is_empty()
	):
		_fail("Action-failure judgement payload lost its lightweight failure facts: %s" % JSON.stringify(first_options))
		return
	bridge.answer_judgement(first_request, [], false)
	if not bridge.revision_requests.is_empty():
		_fail("Zero selected stages unexpectedly launched stage two")
		return
	var unchanged: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if str(unchanged.get("status", "")) != "action_failure_plan_unchanged":
		_fail("Zero-stage judgement was not terminal: %s" % JSON.stringify(unchanged))
		return
	if bool(daily_plan_system.call("_has_pending_dialogue_plan_chain", NPC_ID)):
		_fail("Terminal zero-stage judgement left the dispatch barrier blocked")
		return
	# The same failure may be ignored only within the current plan stage. A new
	# hour represents a new action attempt and must be eligible for judgement.
	daily_plan_system.set("_last_failure_result_by_npc", {NPC_ID: "work_failed_no_workstation"})
	daily_plan_system.call("_on_hour_started", 1, CURRENT_HOUR + 1)
	var failure_cache: Dictionary = daily_plan_system.get("_last_failure_result_by_npc")
	if failure_cache.has(NPC_ID):
		_fail("Action-failure duplicate suppression leaked into the next plan stage")
		return

	var revision_start: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"work_failed_no_workstation",
		failed_item,
		"食堂工作位被占用。",
		failure_context
	)
	if str(revision_start.get("status", "")) != "plan_revision_judgement_pending":
		_fail("Second action failure did not restart stage one")
		return
	var second_request: Dictionary = bridge.judgement_requests.back()
	bridge.answer_judgement(second_request, [CURRENT_HOUR, 14], true)
	if bridge.revision_requests.size() != 1:
		_fail("Non-empty judgement did not launch exactly one stage-two revision")
		return
	var stage_one_result: Dictionary = daily_plan_system.get_last_plan_revision_judgement_result()
	if (
		str(stage_one_result.get("status", "")) != "action_failure_plan_revision_requested"
		or not bool(stage_one_result.get("revision_requested", false))
	):
		_fail("Stage one treated a successfully launched stage two as failed: %s" % JSON.stringify(stage_one_result))
		return
	var revision_request: Dictionary = bridge.revision_requests.back()
	var revision_options: Dictionary = revision_request.get("options", {})
	if revision_options.get("revision_hours", []) != [CURRENT_HOUR, 14]:
		_fail("Stage two did not preserve exact selected hours: %s" % JSON.stringify(revision_options))
		return
	var stage_two_context: Dictionary = revision_options.get("failure_context", {})
	if (
		str(stage_two_context.get("building_id", "")) != "dining_hall"
		or not stage_two_context.get("plan_revision_judgement", {}) is Dictionary
	):
		_fail("Stage two lost the original failure context or judgement result")
		return
	var current_idle := _item(CURRENT_HOUR, "idle", "idle", "")
	var future_work := _item(14, "work", "work_dining_hall", "dining_hall")
	bridge.answer_revision(
		revision_request,
		[current_idle, future_work],
		current_idle.duplicate(true)
	)
	var revised_plan: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	if (
		str((revised_plan[CURRENT_HOUR] as Dictionary).get("action_id", "")) != "idle"
		or str((revised_plan[14] as Dictionary).get("action_id", "")) != "work_dining_hall"
	):
		_fail("Stage two modified the wrong plan hours")
		return
	var applied: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if not bool(applied.get("plan_applied", false)) or str(applied.get("source", "")) != "llm_plan_revision":
		_fail("Selected-hour action-failure revision was not applied: %s" % JSON.stringify(applied))
		return

	print("T0050 action-failure plan revision judgement verification passed.")
	quit(0)


func _make_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		if hour >= 8 and hour <= 13:
			plan.append(_item(hour, "work", "work_dining_hall", "dining_hall"))
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
		"dialogue_goal": "",
		"source": "verify_failure_judgement"
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
