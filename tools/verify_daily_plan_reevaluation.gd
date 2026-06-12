extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const CLOSED_BACKEND_URL := "http://127.0.0.1:5999"
const DEFAULT_LIVE_BACKEND_URL := "http://127.0.0.1:5000"


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
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if (
		time_system == null
		or npc_system == null
		or resource_system == null
		or memory_system == null
		or daily_plan_system == null
		or llm_bridge == null
	):
		push_error("Required systems not found")
		quit(1)
		return

	if not await _verify_rule_fallback(time_system, npc_system, resource_system, memory_system, daily_plan_system, llm_bridge):
		quit(1)
		return
	if not await _verify_live_mock_if_available(time_system, npc_system, daily_plan_system, llm_bridge):
		quit(1)
		return

	print("T1002 daily plan reevaluation verification passed.")
	quit(0)


func _verify_rule_fallback(
	time_system: Node,
	npc_system: Node,
	resource_system: Node,
	memory_system: Node,
	daily_plan_system: Node,
	llm_bridge: Node
) -> bool:
	llm_bridge.set_backend_base_url(CLOSED_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 0.25
	time_system.set_time_scale(4.0)
	time_system.set_current_time(1, 8, 0, 0)

	var npc_id := "blacksmith_01"
	_set_debug_move_speed(npc_id, 120.0)
	daily_plan_system.generate_rule_plan_for_npc(npc_id)
	if not npc_system.debug_enter_location_immediately(npc_id, "blacksmith"):
		push_error("Failed to place blacksmith at blacksmith")
		return false
	var iron := int(resource_system.get_resource("iron"))
	if iron > 0 and not resource_system.debug_spend_resources({"iron": iron}):
		push_error("Failed to spend iron before resource failure verification")
		return false

	daily_plan_system.execute_current_plan_for_npc(npc_id, true)
	await process_frame
	await process_frame

	var result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if str(result.get("npc_id", "")) != npc_id:
		push_error("Reevaluation result npc mismatch: %s" % str(result))
		return false
	if str(result.get("failure_type", "")) != "resource_insufficient":
		push_error("Resource failure should map to resource_insufficient: %s" % str(result))
		return false
	if str(result.get("status", "")) != "rule_fallback_applied" or not bool(result.get("fallback_used", false)):
		push_error("Closed backend should apply rule fallback: %s" % str(result))
		return false
	if llm_bridge.get_pending_slowdown_count() != 0 or not llm_bridge.debug_was_slowdown_registered():
		push_error("Plan revision fallback should register and release LLM slowdown")
		return false
	if absf(time_system.get_effective_time_scale() - 4.0) > 0.001:
		push_error("Plan revision fallback did not restore player time scale")
		return false

	var plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
	var current_item: Dictionary = plan[8]
	if str(current_item.get("source", "")) != "rule_revision_fallback":
		push_error("Fallback plan item should be marked as rule_revision_fallback")
		return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_action", "")) == "work_blacksmith":
		push_error("Blacksmith should not keep executing failed blacksmith work")
		return false
	var revised_event := _find_latest_event(memory_system.get_npc_daily_events(npc_id), "plan_revised")
	if revised_event.is_empty():
		push_error("Plan reevaluation should write plan_revised event")
		return false
	return true


func _verify_live_mock_if_available(time_system: Node, npc_system: Node, daily_plan_system: Node, llm_bridge: Node) -> bool:
	llm_bridge.set_backend_base_url(_get_live_backend_url())
	llm_bridge.request_timeout_seconds = 4.0
	var health: Dictionary = llm_bridge.check_health()
	if not bool(health.get("ok", false)):
		print("T1002 live mock revision skipped because backend is not running.")
		return true

	var npc_id := "veteran_deputy_01"
	time_system.set_current_time(1, 10, 0, 0)
	daily_plan_system.generate_rule_plan_for_npc(npc_id)
	var order_text := "今天优先训练和修补防线，但不要把自己耗垮。"
	var order_result: Dictionary = npc_system.publish_npc_order(npc_id, order_text)
	if not bool(order_result.get("ok", false)) or not bool(order_result.get("changed", false)):
		push_error("Failed to publish order before live mock revision: %s" % str(order_result))
		return false
	await process_frame

	var result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if (
		str(result.get("status", "")) == "rule_fallback_applied"
		and str(result.get("request_result", {}).get("error_code", "")) == "provider_unavailable"
	):
		print("T1002 live mock revision skipped because port 5000 is using a non-mock provider.")
		return true
	if str(result.get("npc_id", "")) != npc_id or str(result.get("status", "")) != "mock_revision_applied":
		push_error("Live backend should apply mock revision: %s" % str(result))
		return false
	if bool(result.get("fallback_used", true)):
		push_error("Live backend mock revision should not use fallback: %s" % str(result))
		return false
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Live mock revision left pending slowdown ids")
		return false
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	if str(injection.get("call_type", "")) != "revise_plan":
		push_error("Plan revision should record revise_plan context injection")
		return false
	if str(injection.get("current_order", {}).get("text", "")) != order_text:
		push_error("Plan revision request must include latest current_order")
		return false
	return true


func _get_live_backend_url() -> String:
	var env_url := OS.get_environment("T1002_BACKEND_URL").strip_edges()
	return DEFAULT_LIVE_BACKEND_URL if env_url.is_empty() else env_url


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return
	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return
