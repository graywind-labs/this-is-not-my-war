extends SceneTree


class CapturingLLMBridge:
	extends Node

	signal plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_async_response_received(result: Dictionary)

	var judgement_requests: Array[Dictionary] = []
	var revision_requests: Array[Dictionary] = []

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return {"ok": true, "body": {"model_adapter": {"provider": "deepseek", "model": "capture-real-provider", "configured": true, "fallback_to_mock": false}}}

	func check_health() -> Dictionary:
		return get_cached_health()

	func request_plan_revision_judgement_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "hunger_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({"request_id": request_id, "npc_id": npc_id, "options": options.duplicate(true)})
		return {"ok": true, "pending": true, "request_id": request_id}

	func request_npc_plan_revision_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "hunger_revision_%d" % (revision_requests.size() + 1)
		revision_requests.append({"request_id": request_id, "npc_id": npc_id, "options": options.duplicate(true)})
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_judgement(request: Dictionary, revision_hours: Array) -> void:
		plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision_judgement": {
				"ok": true,
				"npc_id": str(request.get("npc_id", "")),
				"needs_revision": true,
				"revision_hours": revision_hours.duplicate(),
				"summary": "零饱食后需要进食。",
				"debug_reason": "verification",
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
				"summary": "因饥饿改为吃饭。",
				"debug_reason": "verification",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})


const MAIN_SCENE := "res://scenes/main/Main.tscn"
const NPC_ID := "stableman_01"
const EXPECTED_SUMMARY := "你当前非常饥饿，继续工作或战斗会损伤身体。"

var _failures: Array[String] = []
var _reevaluation_requests: Array[Dictionary] = []


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	check(packed != null, "Main.tscn could not be loaded")
	if packed == null:
		finish()
		return
	root.add_child(packed.instantiate())
	for _frame in 8:
		await physics_frame
		await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	check(npc_system != null and needs_system != null and memory_system != null and daily_plan_system != null and horse_system != null and time_system != null and event_bus != null, "T0081-R2 runtime dependencies are missing")
	if not _failures.is_empty():
		finish()
		return
	time_system.set_paused(true)
	var horse_before: Dictionary = horse_system.get_horse_state_snapshot()

	var production_callback := Callable(daily_plan_system, "_on_plan_reevaluation_requested")
	if event_bus.npc_plan_reevaluation_requested.is_connected(production_callback):
		event_bus.npc_plan_reevaluation_requested.disconnect(production_callback)
	event_bus.npc_plan_reevaluation_requested.connect(_on_plan_reevaluation_requested)
	needs_system.initialize()
	memory_system.clear_event_log()
	check(is_equal_approx(needs_system.get_zero_satiety_hp_cost_per_missing_satiety(), 2.0), "Configured hunger-to-HP ratio is not 2")
	check(needs_system.get_zero_satiety_hp_categories() == ["work", "training", "combat"], "Hunger-to-HP categories mismatch")

	# Crossing from 2 to 0 during one hour of light work leaves 2.5 unpaid
	# satiety points, therefore exactly five HP damage.
	_set_state(npc_system, 2, 100)
	var presentation_before := int(npc_system.get_temporary_presentation_event_snapshot().get("sequence", 0))
	var crossing: Dictionary = needs_system.debug_advance_profile(NPC_ID, "light_work", 3600.0)
	var crossing_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	check(int(crossing_state.get("satiety", -1)) == 0, "Light work did not clamp satiety to zero")
	check(int(crossing_state.get("hp", -1)) == 95, "Only the unpaid satiety deficit was not converted to five HP")
	check(is_equal_approx(float(crossing.get("unpaid_satiety_points", -1.0)), 2.5), "Crossing result did not expose the 2.5-point deficit")
	check(_reevaluation_requests.size() == 1 and str(_reevaluation_requests[0].get("reason", "")) == "low_satiety", "Zero satiety did not emit exactly one low_satiety reevaluation")
	check(bool(daily_plan_system.call("_should_use_action_failure_plan_judgement", "low_satiety", {})), "low_satiety does not enter stage-one judgement")
	check(int(npc_system.get_temporary_presentation_event_snapshot().get("sequence", 0)) == presentation_before, "Hunger damage played a combat hit presentation")
	var hunger_events := _get_hunger_events(memory_system)
	check(hunger_events.size() == 1, "Zero satiety did not create exactly one personal event")
	if hunger_events.size() == 1:
		check(str(hunger_events[0].get("summary", "")) == EXPECTED_SUMMARY, "Zero-satiety event summary mismatch")
		check(str(hunger_events[0].get("visibility", "")) == "private", "Zero-satiety event was not private")
	check(_count_event_type(memory_system, "damage_taken") == 0, "Hunger damage spammed ordinary damage_taken memory")

	# Remaining at zero does damage but does not repeat the episode event.
	needs_system.debug_advance_profile(NPC_ID, "light_work", 3600.0)
	check(int(npc_system.get_npc_state(NPC_ID).get("hp", -1)) == 86, "One hour of empty-stomach light work did not deal nine HP")
	check(_get_hunger_events(memory_system).size() == 1 and _reevaluation_requests.size() == 1, "Zero-satiety episode repeated while capped")

	# Each configured affected profile maps to its exact documented hourly rate.
	var expected_damage := {
		"light_work": 9,
		"heavy_work": 11,
		"training_instructor": 4,
		"training_student": 8,
		"combat": 16
	}
	for profile_id in expected_damage:
		needs_system.initialize()
		_set_state(npc_system, 0, 100)
		needs_system.debug_advance_profile(NPC_ID, str(profile_id), 3600.0)
		check(int(npc_system.get_npc_state(NPC_ID).get("hp", -1)) == 100 - int(expected_damage[profile_id]), "%s hunger damage rate mismatch" % profile_id)

	# Fractional simulation is deterministic, and restoring positive satiety clears
	# any pending HP remainder before a later episode.
	needs_system.initialize()
	_set_state(npc_system, 0, 100)
	needs_system.debug_advance_profile(NPC_ID, "light_work", 600.0)
	check(int(npc_system.get_npc_state(NPC_ID).get("hp", -1)) == 99, "First fractional light-work step did not preserve the correct HP remainder")
	needs_system.debug_advance_profile(NPC_ID, "light_work", 600.0)
	check(int(npc_system.get_npc_state(NPC_ID).get("hp", -1)) == 97, "Two 10-minute steps did not equal three HP damage")
	npc_system.update_npc_state(NPC_ID, {"satiety": 1})
	needs_system.debug_advance_profile(NPC_ID, "light_work", 60.0)
	check(is_equal_approx(float((needs_system.get_npc_needs_snapshot(NPC_ID).get("zero_satiety_hp", {}) as Dictionary).get("damage_remainder", -1.0)), 0.0), "Positive satiety did not clear the hunger damage remainder")

	# Excluded profiles retain their ordinary need rules without HP conversion.
	for profile_id in ["idle", "dialogue", "movement", "rally", "avoid_combat", "escape", "eat", "sleep", "clinic_rest", "prayer_rest", "drink_rest", "unconscious_rest"]:
		needs_system.initialize()
		_set_state(npc_system, 0, 100)
		needs_system.debug_advance_profile(NPC_ID, profile_id, 3600.0)
		check(int(npc_system.get_npc_state(NPC_ID).get("hp", -1)) == 100, "%s incorrectly converted hunger into HP damage" % profile_id)

	# HP zero still uses the existing authoritative unconscious transition.
	needs_system.initialize()
	_set_state(npc_system, 0, 1)
	needs_system.debug_advance_profile(NPC_ID, "heavy_work", 900.0)
	var unconscious_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	check(int(unconscious_state.get("hp", -1)) == 0 and bool(unconscious_state.get("unconscious", false)), "Hunger HP loss did not enter the normal unconscious flow")

	# Restoring satiety permits a fresh zero-satiety episode.
	needs_system.initialize()
	_set_state(npc_system, 1, 100)
	needs_system.debug_advance_profile(NPC_ID, "light_work", 1200.0)
	check(_get_hunger_events(memory_system).size() == 2 and _reevaluation_requests.size() == 2, "A later zero-satiety episode did not trigger again")

	# Exercise the production signal through both provider-shaped stages.
	var systems := root.get_node("Main/Systems")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if original_bridge != null:
		systems.remove_child(original_bridge)
		original_bridge.queue_free()
		await process_frame
	var bridge := CapturingLLMBridge.new()
	bridge.name = "LLMBridge"
	systems.add_child(bridge)
	bridge.plan_revision_judgement_async_response_received.connect(Callable(daily_plan_system, "_on_plan_revision_judgement_async_response"))
	bridge.plan_revision_async_response_received.connect(Callable(daily_plan_system, "_on_plan_revision_async_response"))
	if event_bus.npc_plan_reevaluation_requested.is_connected(_on_plan_reevaluation_requested):
		event_bus.npc_plan_reevaluation_requested.disconnect(_on_plan_reevaluation_requested)
	if not event_bus.npc_plan_reevaluation_requested.is_connected(production_callback):
		event_bus.npc_plan_reevaluation_requested.connect(production_callback)
	time_system.set_current_time(1, 8, 0, 0)
	daily_plan_system.set_auto_execution_enabled(false)
	check(daily_plan_system.set_npc_daily_plan(NPC_ID, _make_plan(), false, "verify_zero_satiety"), "Could not install hunger verification plan")
	needs_system.initialize()
	_set_state(npc_system, 1, 100)
	needs_system.debug_advance_profile(NPC_ID, "light_work", 1200.0)
	check(bridge.judgement_requests.size() == 1 and bridge.revision_requests.is_empty(), "Zero-satiety signal did not stop at stage one")
	if bridge.judgement_requests.size() == 1:
		var judgement_request: Dictionary = bridge.judgement_requests[0]
		var options: Dictionary = judgement_request.get("options", {})
		var context: Dictionary = options.get("failure_context", {})
		check(str(options.get("failure_type", "")) == "low_satiety", "Stage one lost low_satiety")
		check(str(context.get("condition", "")) == "zero_satiety", "Stage one lost zero-satiety context")
		check((options.get("required_revision_hours", []) as Array) == [8], "Current hour was not required")
		bridge.answer_judgement(judgement_request, [8])
	check(bridge.revision_requests.size() == 1, "Stage one did not launch formal revision")
	if bridge.revision_requests.size() == 1:
		var revision_request: Dictionary = bridge.revision_requests[0]
		check((revision_request.get("options", {}) as Dictionary).get("revision_hours", []) == [8], "Formal revision lost selected hour")
		bridge.answer_revision(revision_request, _plan_item(8, "eat", "eat_at_dining_hall", "dining_hall"))
	var revised_plan: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	check(revised_plan.size() == 24 and str((revised_plan[8] as Dictionary).get("action_id", "")) == "eat_at_dining_hall", "Zero satiety did not complete the selected-hour meal revision")

	check(horse_system.get_horse_state_snapshot() == horse_before, "NPC hunger implementation changed horse state")
	finish()


func _set_state(npc_system: Node, satiety: int, hp: int) -> void:
	npc_system.update_npc_state(NPC_ID, {
		"satiety": satiety,
		"hp": hp,
		"max_hp": 100,
		"fatigue": 0,
		"unconscious": false,
		"escaped": false,
		"current_action": "idle",
		"behavior_mode": "work"
	})


func _on_plan_reevaluation_requested(npc_id: String, reason: String) -> void:
	_reevaluation_requests.append({"npc_id": npc_id, "reason": reason})


func _get_hunger_events(memory_system: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in memory_system.get_npc_daily_events(NPC_ID):
		if str(event.get("type", "")) == "zero_satiety_triggered":
			result.append(event)
	return result


func _count_event_type(memory_system: Node, event_type: String) -> int:
	var count := 0
	for event in memory_system.get_npc_daily_events(NPC_ID):
		if str(event.get("type", "")) == event_type:
			count += 1
	return count


func _make_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append(_plan_item(hour, "work", "work_stable", "stable") if hour >= 8 and hour <= 13 else _plan_item(hour, "idle", "idle", ""))
	return plan


func _plan_item(hour: int, action_kind: String, action_id: String, location_id: String) -> Dictionary:
	return {"hour": hour, "action_kind": action_kind, "action_id": action_id, "location_id": location_id, "target_id": "", "reason": "T0081-R2 verification"}


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0081-R2 zero-satiety HP and plan verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
