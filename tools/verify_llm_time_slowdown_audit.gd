extends SceneTree

const CLOSED_BACKEND_URL := "http://127.0.0.1:5999"
const FORMAL_CALL_TYPES: Array[String] = [
	"dialogue",
	"plan_day",
	"revise_plan",
	"battle_judgement",
	"daily_reflection"
]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if llm_bridge == null or time_system == null:
		push_error("LLM slowdown audit required nodes not found")
		quit(1)
		return

	llm_bridge.set_backend_base_url(CLOSED_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 0.2
	time_system.set_paused(false)
	time_system.set_time_scale(4.0)
	if int(llm_bridge.call("_make_optional_timeout_at", 0.0)) != 0:
		push_error("Business LLM requests must not use a fixed total response timeout")
		quit(1)
		return
	if int(llm_bridge.call("_make_optional_timeout_at", -1.0)) <= Time.get_ticks_msec():
		push_error("Read-only requests should retain their short response timeout")
		quit(1)
		return

	var result: Dictionary = llm_bridge.request_npc_dialogue("cook_01", "验证对话降速。")
	if not _assert_failed_and_released(result, llm_bridge, time_system, "dialogue"):
		quit(1)
		return
	result = llm_bridge.request_npc_daily_plan("cook_01")
	if not _assert_failed_and_released(result, llm_bridge, time_system, "plan_day"):
		quit(1)
		return
	result = llm_bridge.request_npc_plan_revision("cook_01", {
		"failure_type": "unknown",
		"failure_summary": "验证计划修订降速。"
	})
	if not _assert_failed_and_released(result, llm_bridge, time_system, "revise_plan"):
		quit(1)
		return
	result = llm_bridge.request_npc_battle_judgement("cook_01", {
		"trigger": "low_hp",
		"allowed_decisions": ["avoid_battle", "escape_station"]
	})
	if not _assert_failed_and_released(result, llm_bridge, time_system, "battle_judgement"):
		quit(1)
		return
	result = llm_bridge.request_npc_daily_reflection("cook_01", {
		"day": 1,
		"day_events": []
	})
	if not _assert_failed_and_released(result, llm_bridge, time_system, "daily_reflection"):
		quit(1)
		return

	var last_audit_before_read_only: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot().get("last_slowdown_audit", {})
	llm_bridge.check_health()
	llm_bridge.request_llm_usage()
	var read_only_snapshot: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
	if read_only_snapshot.get("last_slowdown_audit", {}) != last_audit_before_read_only:
		push_error("Health or usage read-only requests must not register LLM slowdown")
		quit(1)
		return
	if int(read_only_snapshot.get("pending_slowdown_count", -1)) != 0:
		push_error("Read-only backend requests left a slowdown pending")
		quit(1)
		return

	# 自主 NPC-NPC 对话会逐轮调用同一异步入口；抽查连续三轮都必须独立登记并释放慢速。
	var async_result: Dictionary = {}
	for dialogue_round in range(1, 4):
		async_result = llm_bridge.request_npc_dialogue_async("cook_01", "验证异步对话第 %d 轮降速。" % dialogue_round, {
			"request_id": "verify_async_dialogue_slowdown_round_%d" % dialogue_round,
			"requires_time_slowdown": true
		})
		if not await _assert_async_slowdown(async_result, llm_bridge, time_system, "dialogue"):
			quit(1)
			return
	async_result = llm_bridge.request_npc_daily_plan_async("gardener_01", {
		"request_id": "verify_async_plan_day_slowdown"
	})
	if not await _assert_async_slowdown(async_result, llm_bridge, time_system, "plan_day"):
		quit(1)
		return
	async_result = llm_bridge.request_npc_plan_revision_async("blacksmith_01", {
		"request_id": "verify_async_revise_plan_slowdown",
		"failure_type": "unknown",
		"failure_summary": "验证异步计划修订降速。"
	})
	if not await _assert_async_slowdown(async_result, llm_bridge, time_system, "revise_plan"):
		quit(1)
		return
	async_result = llm_bridge.request_npc_battle_judgement_async("veteran_deputy_01", {
		"request_id": "verify_async_battle_judgement_slowdown",
		"trigger": "low_hp",
		"allowed_decisions": ["continue_fighting", "escape_station", "inspired"]
	})
	if not await _assert_async_slowdown(async_result, llm_bridge, time_system, "battle_judgement"):
		quit(1)
		return
	async_result = llm_bridge.request_npc_daily_reflection_async("doctor_01", {
		"request_id": "verify_async_daily_reflection_slowdown",
		"day": 1,
		"day_events": []
	})
	if not await _assert_async_slowdown(async_result, llm_bridge, time_system, "daily_reflection"):
		quit(1)
		return

	var startup_plan: Dictionary = llm_bridge.request_npc_daily_plan_async("doctor_01", {
		"requires_time_slowdown": false,
		"request_id": "verify_startup_plan_without_duplicate_slowdown"
	})
	if not bool(startup_plan.get("ok", false)):
		push_error("Failed to start startup-plan slowdown exception check")
		quit(1)
		return
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Startup batch plan must rely on GameStartupSystem pause without duplicate slowdown")
		quit(1)
		return
	if not await _wait_for_async_requests(llm_bridge):
		quit(1)
		return
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Startup batch plan left a slowdown pending")
		quit(1)
		return

	print("T0020 LLM time slowdown audit verification passed.")
	quit(0)


func _assert_released_slowdown(llm_bridge: Node, time_system: Node, call_type: String) -> bool:
	var snapshot: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
	var audit: Dictionary = snapshot.get("last_slowdown_audit", {})
	if str(audit.get("call_type", "")) != call_type:
		push_error("Slowdown audit call_type mismatch for %s: %s" % [call_type, JSON.stringify(audit)])
		return false
	if not bool(audit.get("registered", false)) or not bool(audit.get("released", false)):
		push_error("Slowdown was not registered and released for %s: %s" % [call_type, JSON.stringify(audit)])
		return false
	if int(snapshot.get("pending_slowdown_count", -1)) != 0:
		push_error("Pending slowdown remained after %s" % call_type)
		return false
	if absf(float(time_system.get_effective_time_scale()) - 4.0) > 0.001:
		push_error("Player time scale was not restored after %s" % call_type)
		return false
	return true


func _assert_failed_and_released(
	result: Dictionary,
	llm_bridge: Node,
	time_system: Node,
	call_type: String
) -> bool:
	if bool(result.get("ok", false)):
		push_error("Closed backend request unexpectedly succeeded for %s" % call_type)
		return false
	return _assert_released_slowdown(llm_bridge, time_system, call_type)


func _wait_for_async_requests(llm_bridge: Node) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		var snapshot: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
		if int(snapshot.get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for async LLM request cleanup")
	return false


func _assert_async_slowdown(
	start_result: Dictionary,
	llm_bridge: Node,
	time_system: Node,
	call_type: String
) -> bool:
	if not bool(start_result.get("ok", false)) or not bool(start_result.get("pending", false)):
		push_error("Failed to start async %s request: %s" % [call_type, JSON.stringify(start_result)])
		return false
	if llm_bridge.get_pending_slowdown_count() != 1:
		push_error("Async %s request did not register slowdown before returning" % call_type)
		return false
	if float(time_system.get_effective_time_scale()) >= 1.0:
		push_error("Async %s request did not reduce effective time scale" % call_type)
		return false
	if not await _wait_for_async_requests(llm_bridge):
		return false
	return _assert_released_slowdown(llm_bridge, time_system, call_type)
