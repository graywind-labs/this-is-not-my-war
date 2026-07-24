extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const CLOSED_BACKEND_URL := "http://127.0.0.1:5999"
const DEFAULT_LIVE_BACKEND_URL := "http://127.0.0.1:5056"


func _init() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if (
		time_system == null
		or npc_system == null
		or memory_system == null
		or daily_plan_system == null
		or llm_bridge == null
	):
		push_error("Required systems not found")
		quit(1)
		return

	if not await _verify_real_failure_without_fallback(time_system, npc_system, memory_system, daily_plan_system, llm_bridge):
		quit(1)
		return
	if not await _verify_live_mock_if_available(time_system, npc_system, memory_system, daily_plan_system, llm_bridge):
		quit(1)
		return

	print("T1003 daily plan LLM/mock verification passed.")
	quit(0)


func _verify_real_failure_without_fallback(
	time_system: Node,
	npc_system: Node,
	memory_system: Node,
	daily_plan_system: Node,
	llm_bridge: Node
) -> bool:
	llm_bridge.set_backend_base_url(CLOSED_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 0.25
	time_system.set_time_scale(4.0)
	time_system.set_current_time(1, 7, 0, 0)

	var npc_id := "gardener_01"
	var result: Dictionary = daily_plan_system.generate_daily_plan_for_npc(npc_id, false)
	if bool(result.get("ok", true)) or str(result.get("status", "")) != "backend_health_failed":
		push_error("Closed backend should fail real daily planning: %s" % str(result))
		return false
	if bool(result.get("fallback_used", true)) or not str(result.get("source", "")).is_empty():
		push_error("Closed backend must not use Mock or rule fallback")
		return false
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Failed provider preflight left pending slowdown")
		return false
	if absf(time_system.get_effective_time_scale() - 4.0) > 0.001:
		push_error("Daily plan fallback did not restore player time scale")
		return false

	var plan: Array = npc_system.get_npc_plan(npc_id)
	if not plan.is_empty():
		push_error("Failed real daily planning must not write any executable plan")
		return false
	var plan_event := _find_latest_event(memory_system.get_npc_daily_events(npc_id), "plan_created")
	if not plan_event.is_empty():
		push_error("Failed real daily planning must not write plan_created")
		return false
	return true


func _verify_live_mock_if_available(
	time_system: Node,
	npc_system: Node,
	memory_system: Node,
	daily_plan_system: Node,
	llm_bridge: Node
) -> bool:
	llm_bridge.set_backend_base_url(_get_live_backend_url())
	llm_bridge.request_timeout_seconds = 4.0
	var health: Dictionary = llm_bridge.check_health()
	if not bool(health.get("ok", false)):
		print("T1003 live mock daily plan skipped because backend is not running.")
		return true

	var npc_id := "gardener_01"
	_set_debug_move_speed(npc_id, 120.0)
	time_system.set_current_time(1, 8, 0, 0)
	if not npc_system.debug_enter_location_immediately(npc_id, "garden"):
		push_error("Failed to place gardener at garden")
		return false
	if not npc_system.set_npc_recruited(npc_id, true):
		push_error("Failed to recruit gardener for current_order verification")
		return false
	var order_text := "今天尽量多准备粮食，但别把自己累倒。"
	var order_result: Dictionary = npc_system.debug_publish_npc_order(npc_id, order_text)
	if not bool(order_result.get("ok", false)):
		push_error("Failed to publish order before plan_day context verification")
		return false
	# Publishing an order intentionally starts an async revision request. Let that
	# independent request release its slowdown before auditing the plan_day call.
	if not await _wait_until_no_pending_slowdown(llm_bridge):
		push_error("Order-triggered revision did not release slowdown: %s" % str(llm_bridge.debug_get_llm_runtime_snapshot()))
		return false

	var result: Dictionary = daily_plan_system.generate_daily_plan_for_npc(npc_id, true, true)
	if str(result.get("status", "")) != "mock_plan_applied":
		push_error("Live backend should apply mock daily plan: %s" % str(result))
		return false
	if bool(result.get("fallback_used", true)):
		push_error("Live mock daily plan should not use fallback: %s" % str(result))
		return false
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Live mock daily plan left pending slowdown ids: %s" % str(llm_bridge.debug_get_llm_runtime_snapshot()))
		return false
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	if str(injection.get("call_type", "")) != "plan_day":
		push_error("Daily plan should record plan_day context injection")
		return false
	if str(injection.get("current_order", {}).get("text", "")) != order_text:
		push_error("Daily plan request must include latest current_order")
		return false

	var plan: Array = npc_system.get_npc_plan(npc_id)
	if plan.size() != 24 or str(plan[8].get("source", "")) != "mock_plan_day":
		push_error("Mock daily plan should write 24 items marked mock_plan_day")
		return false
	if not await _wait_until_current_action(npc_system, npc_id, "work_garden"):
		push_error("Mock daily plan should execute the current hour work action: result=%s state=%s item=%s" % [
			str(result),
			str(npc_system.get_npc_state(npc_id)),
			str(plan[8])
		])
		return false
	var plan_event := _find_latest_event(memory_system.get_npc_daily_events(npc_id), "plan_created")
	if str(plan_event.get("payload", {}).get("source", "")) != "mock_plan_day":
		push_error("Mock plan_created event should record source")
		return false
	return true


func _get_live_backend_url() -> String:
	var env_url := OS.get_environment("T1003_BACKEND_URL").strip_edges()
	return DEFAULT_LIVE_BACKEND_URL if env_url.is_empty() else env_url


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("current_action", "")) == expected_action:
			return true
	return false


func _wait_until_no_pending_slowdown(llm_bridge: Node) -> bool:
	for frame in range(600):
		if llm_bridge.get_pending_slowdown_count() == 0:
			return true
		await process_frame
	return false


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return
	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return
