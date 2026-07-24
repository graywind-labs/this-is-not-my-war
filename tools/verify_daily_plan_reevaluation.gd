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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	if (
		time_system == null
		or npc_system == null
		or resource_system == null
		or building_system == null
		or memory_system == null
		or daily_plan_system == null
		or llm_bridge == null
		or crafting_system == null
	):
		push_error("Required systems not found")
		quit(1)
		return

	if not await _verify_failures_trigger_real_only(time_system, npc_system, resource_system, building_system, memory_system, daily_plan_system, llm_bridge, crafting_system):
		quit(1)
		return
	if not await _verify_live_real_if_available(time_system, npc_system, memory_system, daily_plan_system, llm_bridge):
		quit(1)
		return

	print("T1002 daily plan reevaluation verification passed.")
	quit(0)


func _verify_failures_trigger_real_only(
	time_system: Node,
	npc_system: Node,
	resource_system: Node,
	building_system: Node,
	memory_system: Node,
	daily_plan_system: Node,
	llm_bridge: Node,
	crafting_system: Node
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
	var crafting_target: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", true)
	if not bool(crafting_target.get("ok", false)):
		push_error("Failed to set blacksmith crafting target: %s" % str(crafting_target))
		return false
	var iron := int(resource_system.get_resource("iron"))
	if iron > 0 and not resource_system.debug_spend_resources({"iron": iron}):
		push_error("Failed to spend iron before resource failure verification")
		return false

	daily_plan_system.execute_current_plan_for_npc(npc_id, true)
	var event_count_before: int = int(memory_system.get_npc_daily_events(npc_id).size())
	var result: Dictionary = await _wait_for_reevaluation(daily_plan_system, npc_id, 5.0)
	if str(result.get("npc_id", "")) != npc_id:
		push_error("Reevaluation result npc mismatch: %s" % str(result))
		return false
	if str(result.get("failure_type", "")) != "resource_insufficient":
		push_error("Resource failure should map to resource_insufficient: %s" % str(result))
		return false
	if bool(result.get("ok", true)) or bool(result.get("fallback_used", true)) or str(result.get("source", "")) != "":
		push_error("Closed backend must leave the failed plan untouched without Mock or rule fallback: %s" % str(result))
		return false
	if str(result.get("status", "")) != "backend_health_failed":
		push_error("Closed backend should expose the real provider health failure: %s" % str(result))
		return false
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Provider preflight failure must not leave pending slowdown ids")
		return false
	if absf(time_system.get_effective_time_scale() - 4.0) > 0.001:
		push_error("Plan revision fallback did not restore player time scale")
		return false

	var plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
	var current_item: Dictionary = plan[8]
	if str(current_item.get("source", "")) != "rule_default":
		push_error("Failed real-only revision must not overwrite the current plan")
		return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_action", "")) == "work_blacksmith":
		push_error("Blacksmith should not keep executing failed blacksmith work")
		return false
	if memory_system.get_npc_daily_events(npc_id).size() != event_count_before:
		push_error("Failed real-only revision must not write plan_revised")
		return false

	var occupied_npc_id := "engineer_01"
	time_system.set_current_time(1, 8, 0, 0)
	daily_plan_system.generate_rule_plan_for_npc(occupied_npc_id)
	if not npc_system.debug_enter_location_immediately(occupied_npc_id, "workshop"):
		push_error("Failed to place engineer at workshop")
		return false
	var workshop_target: Dictionary = crafting_system.set_target("workshop", "craft_arrow_bundle", true)
	if not bool(workshop_target.get("ok", false)):
		push_error("Failed to set workshop crafting target: %s" % str(workshop_target))
		return false
	var claim_result: Dictionary = building_system.claim_workstation("workshop", "cook_01", "engineering")
	if not bool(claim_result.get("ok", false)):
		push_error("Failed to occupy workshop before workstation failure verification: %s" % str(claim_result))
		return false
	daily_plan_system.execute_current_plan_for_npc(occupied_npc_id, true)
	var occupied_result: Dictionary = await _wait_for_reevaluation(daily_plan_system, occupied_npc_id, 5.0)
	building_system.release_workstation("workshop", "cook_01", str(claim_result.get("workstation_id", "")))
	if str(occupied_result.get("failure_type", "")) != "workstation_occupied":
		push_error("Occupied workstation failure should trigger real-only reevaluation: %s" % str(occupied_result))
		return false
	if bool(occupied_result.get("fallback_used", true)) or not str(occupied_result.get("source", "")).is_empty():
		push_error("Occupied workstation failure must not apply Mock or rule fallback: %s" % str(occupied_result))
		return false
	return true


func _verify_live_real_if_available(time_system: Node, npc_system: Node, memory_system: Node, daily_plan_system: Node, llm_bridge: Node) -> bool:
	llm_bridge.set_backend_base_url(_get_live_backend_url())
	llm_bridge.request_timeout_seconds = 4.0
	var health: Dictionary = llm_bridge.check_health()
	if not bool(health.get("ok", false)):
		print("T0023 live real revision skipped because backend is not running.")
		return true
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {})
	var provider := str(adapter.get("provider", "")).to_lower()

	var npc_id := "blacksmith_01"
	time_system.set_current_time(1, 8, 0, 0)
	npc_system.update_npc_state(npc_id, {
		"current_action": "idle",
		"last_action_result": "ready_for_live_resource_failure"
	})
	daily_plan_system.generate_rule_plan_for_npc(npc_id)
	if not npc_system.debug_enter_location_immediately(npc_id, "blacksmith"):
		push_error("Failed to place blacksmith before live resource failure revision")
		return false
	daily_plan_system.execute_current_plan_for_npc(npc_id, true)

	var result: Dictionary = await _wait_for_reevaluation(daily_plan_system, npc_id, 240.0)
	if provider == "mock" or not bool(adapter.get("configured", false)) or bool(adapter.get("fallback_to_mock", false)):
		if not ["real_provider_required", "mock_fallback_enabled"].has(str(result.get("status", ""))):
			push_error("Formal revision should reject a Mock or fallback-enabled provider before applying a plan: %s" % str(result))
			return false
		return true
	var revised_event := _find_latest_event(memory_system.get_npc_daily_events(npc_id), "plan_revised")
	if str(revised_event.get("payload", {}).get("source", "")) != "llm_plan_revision":
		push_error("Live real selected-hour revision should write an llm_plan_revision event: %s; result=%s" % [str(revised_event), str(result)])
		return false
	var revised_items: Array = revised_event.get("payload", {}).get("items", [])
	if revised_items.size() != 24:
		push_error("Live real selected-hour revision event must retain the merged 24-hour plan")
		return false
	if (
		str(result.get("npc_id", "")) != npc_id
		or not [
			"llm_revision_applied",
			"revision_execution_failed",
			"revision_execution_retry_exhausted",
			"revision_cycle_exhausted",
			"stale_queued_reevaluation_discarded"
		].has(str(result.get("status", "")))
	):
		push_error("Live resource failure did not complete a real two-stage revision cycle: %s" % str(result))
		return false
	if str(result.get("status", "")) == "llm_revision_applied":
		if bool(result.get("fallback_used", true)) or str(result.get("source", "")) != "llm_plan_revision":
			push_error("Live real revision source/fallback mismatch: %s" % str(result))
			return false
		if str(result.get("model_provider", "")).is_empty() or str(result.get("model_provider", "")).to_lower() == "mock":
			push_error("Live real revision must preserve provider metadata: %s" % str(result))
			return false
	var slowdown_deadline := Time.get_ticks_msec() + 2000
	while llm_bridge.get_pending_slowdown_count() != 0 and Time.get_ticks_msec() < slowdown_deadline:
		await create_timer(0.05).timeout
	if llm_bridge.get_pending_slowdown_count() != 0 or not llm_bridge.debug_was_slowdown_registered():
		push_error("Live real revision must register and release its TimeSystem slowdown")
		return false
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	if str(injection.get("call_type", "")) != "revise_plan":
		push_error("Plan revision should record revise_plan context injection")
		return false
	return true


func _wait_for_reevaluation(daily_plan_system: Node, npc_id: String, timeout_seconds: float) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var result: Dictionary = daily_plan_system.get_last_reevaluation_result()
		if (
			str(result.get("npc_id", "")) == npc_id
			and str(result.get("status", "")) not in [
				"pending",
				"pending_async",
				"plan_revision_judgement_pending",
				"action_failure_plan_revision_requested"
			]
		):
			return result
		await create_timer(0.05).timeout
	return daily_plan_system.get_last_reevaluation_result()


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
