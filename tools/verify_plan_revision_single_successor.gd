extends SceneTree


class FakeRealRevisionBridge:
	extends Node

	signal plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_async_response_received(result: Dictionary)

	var requests: Array[Dictionary] = []
	var judgement_requests: Array[Dictionary] = []

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_npc_plan_revision_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "fake_revision_%d" % (requests.size() + 1)
		requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {
			"ok": true,
			"pending": true,
			"request_id": request_id
		}

	func request_plan_revision_judgement_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "fake_failure_judgement_%d" % (judgement_requests.size() + 1)
		var failed_item: Dictionary = options.get("failed_plan_item", {})
		var hour := int(failed_item.get("hour", 0))
		judgement_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		call_deferred("_emit_judgement", request_id, npc_id, hour)
		return {"ok": true, "pending": true, "request_id": request_id}

	func _emit_judgement(request_id: String, npc_id: String, hour: int) -> void:
		plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": request_id,
			"npc_id": npc_id,
			"plan_revision_judgement": {
				"ok": true,
				"npc_id": npc_id,
				"needs_revision": true,
				"revision_hours": [hour],
				"summary": "专项测试选择失败阶段。",
				"debug_reason": "verification",
				"model_provider": "deepseek",
				"model_name": "fake-real-provider",
				"model_fallback_used": false
			}
		})

	func emit_success(request_id: String, npc_id: String, hour: int) -> void:
		var revised_plan: Array[Dictionary] = []
		var revision_hours: Array = [hour]
		for request in requests:
			if str(request.get("request_id", "")) == request_id:
				revision_hours = (request.get("options", {}).get("revision_hours", [hour]) as Array).duplicate()
				break
		for raw_plan_hour in revision_hours:
			var plan_hour := int(raw_plan_hour)
			revised_plan.append({
				"hour": plan_hour,
				"action_kind": "work",
				"action_id": "work_clinic_doctor" if plan_hour == hour else "work_garden",
				"location_id": "clinic" if plan_hour == hour else "garden",
				"target_id": null,
				"dialogue_goal": "",
				"reason": "尝试诊所工位" if plan_hour == hour else "继续园艺工作",
				"priority": 90 if plan_hour == hour else 60
			})
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": request_id,
			"npc_id": npc_id,
			"plan_revision": {
				"immediate_action": revised_plan[0].duplicate(true) if revision_hours.has(hour) else null,
				"revised_plan": revised_plan,
				"summary": "返回一个会在即时执行阶段同步失败的真实修订。",
				"model_provider": "deepseek",
				"model_name": "fake-real-provider",
				"model_fallback_used": false
			}
		})

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "deepseek",
					"model": "fake-real-provider",
					"configured": true,
					"fallback_to_mock": false
				}
			}
		}


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var systems := root.get_node_or_null("Main/Systems")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [systems, time_system, npc_system, action_system, building_system, daily_plan_system, original_bridge].has(null):
		_fail("Revision single-successor verification requires all scene systems")
		return

	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var fake_bridge := FakeRealRevisionBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)
	fake_bridge.plan_revision_judgement_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_judgement_async_response")
	)
	fake_bridge.plan_revision_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_async_response")
	)

	const NPC_ID := "doctor_01"
	const BLOCKER_ID := "priest_01"
	time_system.set_current_time(1, 8, 0, 0)
	daily_plan_system.set_auto_execution_enabled(true)
	if not npc_system.debug_enter_location_immediately(BLOCKER_ID, "clinic"):
		_fail("Could not place workstation blocker in clinic")
		return
	if not action_system.debug_assign_action(BLOCKER_ID, "work_clinic_doctor"):
		_fail("Could not occupy clinic doctor workstation")
		return
	if not _workstation_owned_by(building_system.get_building("clinic"), BLOCKER_ID):
		_fail("Clinic workstation precondition did not take effect")
		return
	if not npc_system.debug_enter_location_immediately(NPC_ID, "clinic"):
		_fail("Could not place revision actor in clinic")
		return
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_revision_ready"
	})
	var current_hour := int(root.get_node("GameState").current_hour)
	var initial_plan := _make_work_plan("work_garden")
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, initial_plan, false, "verify_revision_chain"):
		_fail("Could not install initial 24-hour work plan")
		return

	var first_launch: Dictionary = daily_plan_system.request_plan_reevaluation(
		NPC_ID,
		"verify_initial_failure",
		daily_plan_system.get_current_plan_item(NPC_ID),
		"验证真实修订后即时执行失败的单后继链。"
	)
	if (
		str(first_launch.get("status", "")) != "pending_async"
		or fake_bridge.requests.size() != 1
	):
		_fail("Initial real-provider revision request did not launch exactly once: %s" % str(first_launch))
		return
	var first_request_id := str(fake_bridge.requests[0].get("request_id", ""))
	fake_bridge.emit_success(first_request_id, NPC_ID, current_hour)

	# The immediate work assignment fails synchronously while the first response still
	# owns _reevaluating_npcs. Its npc_state_changed trigger must be the sole queued
	# successor; a second generic deferred retry would create a parallel chain.
	for _index in range(6):
		await process_frame
	var failed_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if str(failed_state.get("last_action_result", "")) != "clinic_doctor_failed_no_workstation":
		_fail("Revision immediate action did not synchronously fail on occupied workstation: %s" % str(failed_state))
		return
	if fake_bridge.requests.size() != 2:
		_fail("Exactly one successor revision must launch; request count=%d" % fake_bridge.requests.size())
		return
	if fake_bridge.judgement_requests.size() != 1:
		_fail("The authoritative execution failure did not pass through exactly one judgement")
		return

	var retry_counts: Dictionary = daily_plan_system.get("_revision_execution_retry_counts")
	if int(retry_counts.get(NPC_ID, 0)) != 1:
		_fail("Queued successor reset or lost the execution retry count: %s" % str(retry_counts))
		return
	var queued_by_npc: Dictionary = daily_plan_system.get("_queued_reevaluation_by_npc")
	if queued_by_npc.has(NPC_ID):
		_fail("A duplicate queued chain remained after the single successor launched: %s" % str(queued_by_npc))
		return
	var reevaluating_npcs: Dictionary = daily_plan_system.get("_reevaluating_npcs")
	var second_request_id := str(fake_bridge.requests[1].get("request_id", ""))
	if str(reevaluating_npcs.get(NPC_ID, "")) != second_request_id:
		_fail("The sole successor is not the active revision owner: %s" % str(reevaluating_npcs))
		return
	var async_requests: Dictionary = daily_plan_system.get("_async_revision_requests")
	if async_requests.size() != 1 or not async_requests.has(second_request_id):
		_fail("Revision request registry contains a double chain: %s" % str(async_requests.keys()))
		return
	var second_options: Dictionary = fake_bridge.requests[1].get("options", {})
	if str(second_options.get("failure_type", "")) != "workstation_occupied":
		_fail("Successor did not preserve the authoritative queued failure: %s" % str(second_options))
		return
	var second_summary := str(second_options.get("failure_summary", ""))
	if not second_summary.contains("马塞尔") or not second_summary.contains("占用"):
		_fail("Successor lost the workstation blocker context: %s" % second_summary)
		return

	# Give every deferred callback another chance; no hidden generic retry may launch.
	for _index in range(6):
		await process_frame
	if fake_bridge.requests.size() != 2:
		_fail("A delayed duplicate successor created a second revision chain")
		return
	queued_by_npc = daily_plan_system.get("_queued_reevaluation_by_npc")
	if queued_by_npc.has(NPC_ID):
		_fail("A delayed duplicate successor re-populated the queued chain")
		return

	print("T0025 revision single-successor verification passed.")
	quit(0)


func _make_work_plan(action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0025 revision chain verification",
			"priority": 60,
			"target": {}
		})
	return plan


func _workstation_owned_by(building: Dictionary, npc_id: String) -> bool:
	for raw_workstation in building.get("workstations", []):
		if raw_workstation is Dictionary and str((raw_workstation as Dictionary).get("occupied_by", "")) == npc_id:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
