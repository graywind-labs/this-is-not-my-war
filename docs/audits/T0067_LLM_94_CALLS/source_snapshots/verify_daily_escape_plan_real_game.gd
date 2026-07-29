extends SceneTree

const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const REAL_REQUEST_TIMEOUT_SECONDS := 180.0
const REAL_BATCH_TIMEOUT_MSEC := 300000

var _main_scene: PackedScene


func _init() -> void:
	_main_scene = load("res://scenes/main/Main.tscn") as PackedScene
	if _main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var baseline: Dictionary = await _run_plan_scenario({
		"id": "daily_escape_baseline",
		"npc_id": "stableman_01",
		"pressure": false,
		"attempt": 1
	})
	print("REAL_DAILY_ESCAPE_SCENARIO ", JSON.stringify(baseline))
	if not bool(baseline.get("real_llm_ok", false)):
		_fail("Baseline daily-plan request failed: %s" % JSON.stringify(baseline))
		return

	var max_pressure_attempts := clampi(
		int(OS.get_environment("REAL_DAILY_ESCAPE_MAX_ATTEMPTS")),
		1,
		5
	) if not OS.get_environment("REAL_DAILY_ESCAPE_MAX_ATTEMPTS").is_empty() else 3
	var pressure_results: Array[Dictionary] = []
	var selected_escape := false
	for attempt in range(1, max_pressure_attempts + 1):
		var pressure_result: Dictionary = await _run_plan_scenario({
			"id": "daily_escape_high_pressure_%d" % attempt,
			"npc_id": "engineer_01",
			"pressure": true,
			"attempt": attempt
		})
		pressure_results.append(pressure_result)
		print("REAL_DAILY_ESCAPE_SCENARIO ", JSON.stringify(pressure_result))
		if not bool(pressure_result.get("real_llm_ok", false)):
			_fail("High-pressure daily-plan request failed: %s" % JSON.stringify(pressure_result))
			return
		if bool(pressure_result.get("escape_selected", false)):
			selected_escape = true
			break

	print("REAL_DAILY_ESCAPE_MATRIX ", JSON.stringify({
		"ok": true,
		"baseline": baseline,
		"pressure_attempts": pressure_results,
		"high_pressure_escape_selected": selected_escape
	}))
	quit(0)


func _run_plan_scenario(config: Dictionary) -> Dictionary:
	var main := _main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if (
		daily_plan_system == null
		or npc_system == null
		or resource_system == null
		or building_system == null
		or combat_system == null
		or memory_system == null
		or llm_bridge == null
		or time_system == null
	):
		main.queue_free()
		await process_frame
		return _failure(config, "required_system_missing")

	time_system.set_current_time(1, 6, 0, 0)
	time_system.set_paused(true)
	llm_bridge.set_backend_base_url(_backend_url())
	llm_bridge.request_timeout_seconds = REAL_REQUEST_TIMEOUT_SECONDS
	var health: Dictionary = llm_bridge.check_health()
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {})
	if (
		not bool(health.get("ok", false))
		or not bool(adapter.get("configured", false))
		or str(adapter.get("provider", "")) == "mock"
		or bool(adapter.get("fallback_to_mock", true))
	):
		main.queue_free()
		await process_frame
		return _failure(config, "real_provider_not_ready", {"health": health})

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()
	var npc_id := str(config.get("npc_id", ""))
	if bool(config.get("pressure", false)):
		_apply_high_pressure_state(
			npc_id,
			npc_system,
			resource_system,
			building_system,
			combat_system
		)

	var payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(npc_id, {
		"reason": str(config.get("id", "real_daily_escape"))
	})
	var escape_candidate_present := false
	for raw_candidate in payload.get("allowed_actions", []):
		var candidate: Dictionary = raw_candidate if raw_candidate is Dictionary else {}
		if (
			str(candidate.get("action_id", "")) == "escaping_station"
			and str(candidate.get("action_kind", "")) == "escape"
		):
			escape_candidate_present = true
			break
	if not escape_candidate_present:
		main.queue_free()
		await process_frame
		return _failure(config, "escaping_station_candidate_missing")

	daily_plan_system.begin_new_day_planning_for_npc(
		npc_id,
		str(config.get("id", "real_daily_escape"))
	)
	var requested_npc_ids: Array[String] = [npc_id]
	var request_result: Dictionary = daily_plan_system.request_daily_plans_async(
		requested_npc_ids,
		str(config.get("id", "real_daily_escape")),
		false,
		1,
		true,
		1
	)
	if not bool(request_result.get("ok", false)):
		main.queue_free()
		await process_frame
		return _failure(config, "plan_request_not_started", {
			"request_result": request_result
		})
	var batch: Dictionary = await _wait_for_plan_batch(daily_plan_system)
	var npc_result: Dictionary = batch.get("results", {}).get(npc_id, {})
	var plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
	var escape_hours: Array[int] = []
	var action_counts: Dictionary = {}
	for raw_item in plan:
		var item: Dictionary = raw_item if raw_item is Dictionary else {}
		var action_id := str(item.get("action_id", ""))
		action_counts[action_id] = int(action_counts.get(action_id, 0)) + 1
		if action_id == "escaping_station":
			escape_hours.append(int(item.get("hour", -1)))

	var execution_result: Dictionary = {}
	var state_after_execution: Dictionary = {}
	if not escape_hours.is_empty():
		time_system.set_current_time(
			1,
			escape_hours[0],
			0,
			0
		)
		execution_result = daily_plan_system.debug_execute_current_plan(npc_id, true)
		state_after_execution = npc_system.get_npc_state(npc_id)

	var request_payload_result: Dictionary = (
		npc_result.get("request_result", {})
		if npc_result.get("request_result", {}) is Dictionary
		else {}
	)
	var daily_plan_body: Dictionary = (
		request_payload_result.get("daily_plan", {})
		if request_payload_result.get("daily_plan", {}) is Dictionary
		else {}
	)
	var result := {
		"scenario_id": str(config.get("id", "")),
		"npc_id": npc_id,
		"pressure": bool(config.get("pressure", false)),
		"attempt": int(config.get("attempt", 1)),
		"candidate_present": escape_candidate_present,
		"real_llm_ok": (
			str(batch.get("status", "")) == "completed"
			and int(batch.get("failed_count", 0)) == 0
			and bool(npc_result.get("ok", false))
			and str(daily_plan_body.get("model_provider", "")) != "mock"
			and not bool(daily_plan_body.get("model_fallback_used", true))
		),
		"batch_status": str(batch.get("status", "")),
		"plan_size": plan.size(),
		"escape_selected": not escape_hours.is_empty(),
		"escape_hours": escape_hours,
		"action_counts": action_counts,
		"plan_summary": str(daily_plan_body.get("summary", "")),
		"plan_debug_reason": str(daily_plan_body.get("debug_reason", "")),
		"model_provider": str(daily_plan_body.get("model_provider", "")),
		"model_name": str(daily_plan_body.get("model_name", "")),
		"model_fallback_used": bool(daily_plan_body.get("model_fallback_used", false)),
		"execution_ok": bool(execution_result.get("ok", false)) if not escape_hours.is_empty() else false,
		"execution_result": execution_result,
		"behavior_mode_after_execution": str(state_after_execution.get("behavior_mode", "")),
		"escape_status_after_execution": str(state_after_execution.get("escape_intent", {}).get("status", ""))
	}
	main.queue_free()
	await process_frame
	await process_frame
	return result


func _apply_high_pressure_state(
	npc_id: String,
	npc_system: Node,
	resource_system: Node,
	building_system: Node,
	combat_system: Node
) -> void:
	npc_system.set_npc_recruited(npc_id, true)
	npc_system.publish_npc_order(
		npc_id,
		"取消所有复检，材料减半也必须赶工；结构裂缝不准上报，失败由你负责。"
	)
	npc_system.update_npc_state(npc_id, {
		"hp": 70,
		"satiety": 35,
		"fatigue": 76,
		"unconscious": false,
		"behavior_mode": "work",
		"combat_mode": "",
		"current_action": "idle"
	})
	npc_system.apply_damage_to_npc(
		npc_id,
		27,
		"guard_officer",
		"local_public",
		{
			"player_attack": true,
			"request_plan_reevaluation": false
		}
	)
	for victim_id in ["veteran_deputy_01", "blacksmith_01"]:
		var victim_state: Dictionary = npc_system.get_npc_state(victim_id)
		npc_system.apply_damage_to_npc(
			victim_id,
			maxi(1, int(victim_state.get("hp", 100))),
			"enemy_raider_pressure",
			"local_public",
			{"request_plan_reevaluation": false}
		)
	combat_system.start_npc_escape("cook_01", "", "fear_after_attack", {
		"interaction_context": "work"
	})
	building_system.apply_damage_to_building(
		"front_gate",
		999,
		"enemy_raider_pressure",
		"local_public"
	)
	building_system.apply_damage_to_building(
		"warehouse",
		120,
		"enemy_raider_pressure",
		"local_public"
	)
	building_system.apply_damage_to_building(
		"workshop",
		100,
		"enemy_raider_pressure",
		"local_public"
	)
	for resource_id in ["meal", "wood", "stone", "iron"]:
		resource_system.add_resource(
			resource_id,
			-resource_system.get_resource(resource_id)
		)
	resource_system.add_resource(
		"grain",
		-resource_system.get_resource("grain") + 2
	)


func _wait_for_plan_batch(daily_plan_system: Node) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec < REAL_BATCH_TIMEOUT_MSEC:
		var batch: Dictionary = daily_plan_system.get_async_plan_batch_snapshot()
		if str(batch.get("status", "")) in ["completed", "failed"]:
			return batch
		await create_timer(0.05).timeout
	return {
		"ok": false,
		"status": "timeout",
		"failed_count": 1,
		"results": {}
	}


func _backend_url() -> String:
	var configured := OS.get_environment("REAL_LLM_BACKEND_URL").strip_edges()
	return DEFAULT_BACKEND_URL if configured.is_empty() else configured.trim_suffix("/")


func _failure(config: Dictionary, reason: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"scenario_id": str(config.get("id", "")),
		"npc_id": str(config.get("npc_id", "")),
		"pressure": bool(config.get("pressure", false)),
		"attempt": int(config.get("attempt", 1)),
		"real_llm_ok": false,
		"reason": reason
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
