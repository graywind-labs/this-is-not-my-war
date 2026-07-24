extends SceneTree


class FakeRealRevisionBridge:
	extends Node

	signal plan_revision_judgement_async_response_received(result: Dictionary)

	var request_count := 0
	var judgement_count := 0

	func get_cached_health(_max_age_msec: int = 5000) -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "deepseek",
					"model": "verify-real-provider",
					"configured": true,
					"fallback_to_mock": false,
				}
			}
		}

	func check_health() -> Dictionary:
		return get_cached_health()

	func request_npc_plan_revision_async(_npc_id: String, _options: Dictionary = {}) -> Dictionary:
		request_count += 1
		return {
			"ok": false,
			"error_code": "verify_launch_failure",
			"message": "专项测试阻止真实网络请求。",
		}

	func request_plan_revision_judgement_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		judgement_count += 1
		var request_id := "verify_failure_judgement_%d" % judgement_count
		var failed_item: Dictionary = options.get("failed_plan_item", {})
		var hour := int(failed_item.get("hour", 0))
		call_deferred("_answer_judgement", request_id, npc_id, hour)
		return {"ok": true, "pending": true, "request_id": request_id}

	func _answer_judgement(request_id: String, npc_id: String, hour: int) -> void:
		plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": request_id,
			"npc_id": npc_id,
			"plan_revision_judgement": {
				"ok": true,
				"npc_id": npc_id,
				"needs_revision": true,
				"revision_hours": [hour],
				"summary": "专项测试选择当前阶段。",
				"debug_reason": "verification",
				"model_provider": "deepseek",
				"model_name": "verify-real-provider",
				"model_fallback_used": false,
			}
		})


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
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	if systems == null or original_bridge == null or npc_system == null or daily_plan_system == null:
		_fail("Late revision failure bound verification requires all systems")
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

	var npc_id := "doctor_01"
	var hour := int(root.get_node("GameState").current_hour)
	if not daily_plan_system.set_npc_daily_plan(npc_id, _make_plan(hour), false, "verify_late_failure_bound"):
		_fail("Could not install revision bound plan")
		return

	# Model a revision that initially returned started/pending, then failed only after
	# movement. Each authoritative late failure consumes one semantic landing retry.
	for index in range(3):
		daily_plan_system.call("_mark_revision_applied", npc_id)
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": "work_failed_after_revision_%d" % index,
			"last_action_failure_context": {"action_id": "work_clinic_doctor"},
		})
		await process_frame

	if int(daily_plan_system.call("_get_revision_cycle_count", npc_id)) != 3:
		_fail("Late revision failures did not accumulate the bounded semantic cycle")
		return
	var exhausted: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if str(exhausted.get("status", "")) != "revision_cycle_exhausted":
		_fail("Third late failure did not stop further automatic LLM revision: %s" % str(exhausted))
		return
	if fake_bridge.request_count != 6:
		_fail("Exhausted third cycle still launched model attempts: %d" % fake_bridge.request_count)
		return
	if fake_bridge.judgement_count != 2:
		_fail("Action failures did not pass through exactly two pre-exhaustion judgements")
		return

	# A genuinely new guard-officer order is a new decision cycle and must not be
	# blocked by failures from the old plan.
	var order_result: Dictionary = daily_plan_system.request_plan_reevaluation(
		npc_id,
		"order_changed",
		daily_plan_system.get_current_plan_item(npc_id),
		"守备官发布了新指令。"
	)
	if str(order_result.get("status", "")) == "revision_cycle_exhausted":
		_fail("A new guard-officer order did not reset the old failure cycle")
		return
	if int(daily_plan_system.call("_get_revision_cycle_count", npc_id)) != 0:
		_fail("New order left the old revision failure count active")
		return

	print("T0025 late revision failure bound verification passed.")
	quit(0)


func _make_plan(_current_hour: int) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": "work_clinic_doctor",
			"action_name": "诊所工作",
			"source": "verify_late_failure_bound",
			"target": {},
			"priority": 60,
			"reason": "验证异步落地失败上限。",
			"dialogue_goal": "",
		})
	return plan


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
