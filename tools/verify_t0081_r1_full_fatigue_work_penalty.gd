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

	func request_plan_revision_judgement_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "fatigue_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({"request_id": request_id, "npc_id": npc_id, "options": options.duplicate(true)})
		return {"ok": true, "pending": true, "request_id": request_id}

	func request_npc_plan_revision_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "fatigue_revision_%d" % (revision_requests.size() + 1)
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
				"summary": "满疲劳后需要安排休息。",
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
				"summary": "因满疲劳改为睡觉。",
				"debug_reason": "verification",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {"model_adapter": {"provider": "deepseek", "model": "capture-real-provider", "configured": true, "fallback_to_mock": false}}
		}


const MAIN_SCENE := "res://scenes/main/Main.tscn"
const NPC_ID := "stableman_01"
const TARGET_ID := "cook_01"
const EXPECTED_MULTIPLIER := 0.5
const EXPECTED_SUMMARY := "你当前很疲惫，工作效率大幅下降。"

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
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	check(
		npc_system != null and needs_system != null and action_system != null
		and building_system != null and horse_system != null and memory_system != null
		and daily_plan_system != null and time_system != null and event_bus != null,
		"T0081-R1 runtime dependencies are missing"
	)
	if not _failures.is_empty():
		finish()
		return
	time_system.set_paused(true)

	# Capture the trigger without launching a paid/provider-dependent request. The
	# routing predicate below separately verifies that production sends it through
	# stage one judgement rather than directly to stage two.
	var production_callback := Callable(daily_plan_system, "_on_plan_reevaluation_requested")
	if event_bus.npc_plan_reevaluation_requested.is_connected(production_callback):
		event_bus.npc_plan_reevaluation_requested.disconnect(production_callback)
	event_bus.npc_plan_reevaluation_requested.connect(_on_plan_reevaluation_requested)

	needs_system.initialize()
	memory_system.clear_event_log()
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 99,
		"satiety": 100,
		"current_location": "stable",
		"unconscious": false,
		"escaped": false,
		"behavior_mode": "work",
		"work_encouragement_boost": {}
	})
	check(is_equal_approx(npc_system.get_npc_work_output_multiplier(NPC_ID), 1.0), "Penalty applied before fatigue reached its maximum")

	needs_system.debug_advance_profile(NPC_ID, "light_work", 600.0)
	check(int(npc_system.get_npc_state(NPC_ID).get("fatigue", -1)) == 100, "Light work did not reach full fatigue")
	check(is_equal_approx(needs_system.get_fatigue_work_output_multiplier(NPC_ID), EXPECTED_MULTIPLIER), "Needs authority did not expose the configured full-fatigue multiplier")
	check(is_equal_approx(npc_system.get_npc_work_output_multiplier(NPC_ID), EXPECTED_MULTIPLIER), "NPC work output did not receive the full-fatigue penalty")
	check(_reevaluation_requests.size() == 1 and str(_reevaluation_requests[0].get("reason", "")) == "high_fatigue", "Full fatigue did not emit exactly one high_fatigue reevaluation request")
	check(bool(daily_plan_system.call("_should_use_action_failure_plan_judgement", "high_fatigue", {})), "high_fatigue does not route through stage-one plan revision judgement")
	check(str(daily_plan_system.call("_normalize_failure_type", "high_fatigue")) == "high_fatigue", "high_fatigue failure type normalization is missing")

	var fatigue_events := _get_fatigue_events(memory_system)
	check(fatigue_events.size() == 1, "Full fatigue did not create exactly one personal event")
	if fatigue_events.size() == 1:
		check(str(fatigue_events[0].get("summary", "")) == EXPECTED_SUMMARY, "Full-fatigue event summary mismatch")
		check(str(fatigue_events[0].get("visibility", "")) == "private", "Full-fatigue event was not personal/private")

	# Staying at the cap must not spam the event or reevaluation. Recovering below
	# the cap and reaching it again starts a new episode and may trigger once more.
	needs_system.debug_advance_profile(NPC_ID, "light_work", 3600.0)
	check(_get_fatigue_events(memory_system).size() == 1 and _reevaluation_requests.size() == 1, "Full fatigue repeated while fatigue remained capped")
	needs_system.debug_advance_profile(NPC_ID, "sleep", 300.0)
	check(int(npc_system.get_npc_state(NPC_ID).get("fatigue", 100)) < 100, "Sleep did not clear the full-fatigue episode")
	npc_system.update_npc_state(NPC_ID, {"fatigue": 99})
	needs_system.debug_advance_profile(NPC_ID, "light_work", 1200.0)
	check(_get_fatigue_events(memory_system).size() == 2 and _reevaluation_requests.size() == 2, "A later full-fatigue episode did not trigger again")

	# Existing encouragement composes multiplicatively instead of erasing either
	# effect: 1.2 encouragement x 0.5 fatigue = 0.6 final output.
	npc_system.update_npc_state(NPC_ID, {
		"work_encouragement_boost": {"active": true, "output_multiplier": 1.2}
	})
	check(is_equal_approx(npc_system.get_npc_work_output_multiplier(NPC_ID), 0.6), "Encouragement and fatigue did not compose multiplicatively")
	npc_system.update_npc_state(NPC_ID, {"work_encouragement_boost": {}})

	# The shared multiplier must remain below 1 through every consumer wrapper.
	check(is_equal_approx(action_system.call("_get_npc_work_output_multiplier", NPC_ID), EXPECTED_MULTIPLIER), "ActionSystem clamped the fatigue penalty away")
	check(is_equal_approx(building_system.call("_get_npc_work_output_multiplier", NPC_ID), EXPECTED_MULTIPLIER), "BuildingSystem clamped the fatigue penalty away")
	var repair_job := {"helpers": {NPC_ID: {"speed_bonus": 0.5}}}
	check(is_equal_approx(float(building_system.call("_get_repair_speed_multiplier", repair_job)), 1.25), "Repair/upgrade helper contribution did not halve at full fatigue")

	# Ordinary production progress is halved for the same logical time.
	action_system._active_actions[NPC_ID] = {
		"kind": "work_garden",
		"action": {"id": "work_garden", "type": "work"},
		"duration_seconds": 1000.0,
		"elapsed_seconds": 0.0,
		"state_deltas": {},
		"applied_state_deltas": {}
	}
	action_system.call("_advance_active_action", NPC_ID, 100.0)
	check(is_equal_approx(float(action_system._active_actions.get(NPC_ID, {}).get("elapsed_seconds", -1.0)), 50.0), "Ordinary work progress was not halved")
	action_system._active_actions.erase(NPC_ID)

	# Healing rate and stable care both consume the same authority.
	action_system._healing_helpers_by_target[TARGET_ID] = [NPC_ID]
	action_system._active_actions[NPC_ID] = {"kind": "assist_heal", "target_npc_id": TARGET_ID, "medical_skill": 80}
	var fatigued_healing: Dictionary = action_system.get_healing_assist_rate_snapshot(TARGET_ID)
	npc_system.update_npc_state(NPC_ID, {"fatigue": 99})
	var rested_healing: Dictionary = action_system.get_healing_assist_rate_snapshot(TARGET_ID)
	check(is_equal_approx(float(fatigued_healing.get("hp_per_game_hour", 0.0)) * 2.0, float(rested_healing.get("hp_per_game_hour", -1.0))), "Healing assistance did not use the full-fatigue penalty")
	action_system._active_actions.erase(NPC_ID)
	action_system._healing_helpers_by_target.erase(TARGET_ID)

	_set_skill(npc_system, NPC_ID, 80)
	action_system._active_actions[NPC_ID] = {"kind": "work_stable"}
	var rested_care: Dictionary = horse_system.get_horse_care_rate_snapshot("horse_chestnut_wind")
	npc_system.update_npc_state(NPC_ID, {"fatigue": 100})
	var fatigued_care: Dictionary = horse_system.get_horse_care_rate_snapshot("horse_chestnut_wind")
	var rested_growth := float((rested_care.get("rates_per_game_second", {}) as Dictionary).get("growth", 0.0))
	var fatigued_growth := float((fatigued_care.get("rates_per_game_second", {}) as Dictionary).get("growth", 0.0))
	check(rested_growth > 0.0 and is_equal_approx(fatigued_growth * 2.0, rested_growth), "Stable care output did not halve at full fatigue")
	action_system._active_actions.erase(NPC_ID)

	# Run the production signal through both real plan stages with a deterministic
	# provider-shaped bridge: scope judgement first, selected-hour revision second.
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
	check(daily_plan_system.set_npc_daily_plan(NPC_ID, _make_plan(), false, "verify_full_fatigue"), "Could not install the full-fatigue verification plan")
	needs_system.initialize()
	npc_system.update_npc_state(NPC_ID, {"fatigue": 99, "work_encouragement_boost": {}})
	needs_system.debug_advance_profile(NPC_ID, "light_work", 600.0)
	check(bridge.judgement_requests.size() == 1 and bridge.revision_requests.is_empty(), "Full-fatigue signal did not stop at stage-one judgement")
	if bridge.judgement_requests.size() == 1:
		var judgement_request: Dictionary = bridge.judgement_requests[0]
		var judgement_options: Dictionary = judgement_request.get("options", {})
		check(str(judgement_options.get("failure_type", "")) == "high_fatigue", "Stage one lost the high_fatigue failure type")
		check(str((judgement_options.get("failure_context", {}) as Dictionary).get("condition", "")) == "full_fatigue", "Stage one lost the authoritative fatigue context")
		bridge.answer_judgement(judgement_request, [8])
	check(bridge.revision_requests.size() == 1, "Stage-one fatigue judgement did not launch exactly one formal revision")
	if bridge.revision_requests.size() == 1:
		var revision_request: Dictionary = bridge.revision_requests[0]
		check((revision_request.get("options", {}) as Dictionary).get("revision_hours", []) == [8], "Formal fatigue revision did not preserve selected hours")
		bridge.answer_revision(revision_request, _plan_item(8, "sleep", "sleep_in_dormitory", "dormitory"))
	var revised_plan: Array = daily_plan_system.get_npc_daily_plan(NPC_ID)
	check(revised_plan.size() == 24 and str((revised_plan[8] as Dictionary).get("action_id", "")) == "sleep_in_dormitory", "Full fatigue did not complete the formal selected-hour plan revision")

	finish()


func _on_plan_reevaluation_requested(npc_id: String, reason: String) -> void:
	_reevaluation_requests.append({"npc_id": npc_id, "reason": reason})


func _get_fatigue_events(memory_system: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in memory_system.get_npc_daily_events(NPC_ID):
		if str(event.get("type", "")) == "full_fatigue_triggered":
			result.append(event)
	return result


func _set_skill(npc_system: Node, npc_id: String, value: int) -> void:
	var profile: Dictionary = npc_system._profiles.get(npc_id, {})
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["养马"] = value
	profile["skills"] = skills
	npc_system._profiles[npc_id] = profile


func _make_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		if hour >= 8 and hour <= 13:
			plan.append(_plan_item(hour, "work", "work_stable", "stable"))
		else:
			plan.append(_plan_item(hour, "idle", "idle", ""))
	return plan


func _plan_item(hour: int, action_kind: String, action_id: String, location_id: String) -> Dictionary:
	return {
		"hour": hour,
		"action_kind": action_kind,
		"action_id": action_id,
		"location_id": location_id,
		"target_id": "",
		"reason": "T0081-R1 verification"
	}


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0081-R1 full-fatigue work penalty verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
