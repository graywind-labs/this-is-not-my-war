extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ARMED_NPC_ID := "veteran_deputy_01"
const CIVILIAN_NPC_ID := "cook_01"
const INTRUDER_POSITION := Vector3(0.0, 0.0, 40.0)

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var reflection_system := root.get_node_or_null("Main/Systems/DailyReflectionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(not [combat_system, npc_system, action_system, reflection_system, memory_system, station_controller, time_system].has(null), "T0427 runtime dependencies unavailable")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)
	_check(station_controller.is_world_position_inside_station(INTRUDER_POSITION), "T0427 intruder fixture is outside the station")
	if OS.get_cmdline_user_args().has("--real"):
		await _run_real_verification(
			combat_system,
			npc_system,
			action_system,
			reflection_system,
			memory_system,
			root.get_node_or_null("Main/Systems/LLMBridge")
		)
		return

	var armed_sleep: Dictionary = action_system.stage_npc_sleep_for_tutorial(ARMED_NPC_ID)
	var civilian_sleep: Dictionary = action_system.stage_npc_sleep_for_tutorial(CIVILIAN_NPC_ID)
	_check(bool(armed_sleep.get("ok", false)) and bool(civilian_sleep.get("ok", false)), "T0427 could not stage both sleepers")
	_stage_reflection_lock(reflection_system, npc_system, ARMED_NPC_ID)
	_stage_reflection_lock(reflection_system, npc_system, CIVILIAN_NPC_ID)
	var armed_position_before: Vector3 = npc_system.get_npc_world_position(ARMED_NPC_ID)
	var civilian_position_before: Vector3 = npc_system.get_npc_world_position(CIVILIAN_NPC_ID)

	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true, true)
	_check(bool(spawn.get("ok", false)), "T0427 enemy spawn failed: %s" % spawn)
	var preservation: Dictionary = spawn.get("reflection_interrupt_result", {})
	_check(int(preservation.get("interrupted_count", -1)) == 0, "T0427 enemy spawn interrupted reflection")
	_check(int(preservation.get("deferred_count", 0)) == 2, "T0427 enemy spawn did not report both deferred responders")
	_check(_reflection_is_pending(reflection_system, ARMED_NPC_ID), "T0427 armed reflection request disappeared on spawn")
	_check(_reflection_is_pending(reflection_system, CIVILIAN_NPC_ID), "T0427 civilian reflection request disappeared on spawn")

	var alarm: Dictionary = combat_system.trigger_combat_alarm("verify_t0424")
	var alarm_preservation: Dictionary = alarm.get("reflection_interrupt_result", {})
	_check(int(alarm_preservation.get("interrupted_count", -1)) == 0, "T0427 alarm interrupted reflection")
	_check(npc_system.is_first_sleep_summary_locked(ARMED_NPC_ID), "T0427 alarm released armed reflection lock")
	_check(npc_system.is_first_sleep_summary_locked(CIVILIAN_NPC_ID), "T0427 alarm released civilian reflection lock")

	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	_set_enemy_position(combat_system, enemy_id, INTRUDER_POSITION)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	_check(_still_reflecting_in_bed(npc_system, ARMED_NPC_ID, armed_position_before), "T0427 station breach moved the armed reflecting sleeper")
	_check(_still_reflecting_in_bed(npc_system, CIVILIAN_NPC_ID, civilian_position_before), "T0427 station breach moved the civilian reflecting sleeper")
	_check(_count_event(memory_system, ARMED_NPC_ID, "enemy_breach_combat_response") == 0, "T0427 armed breach event was written before reflection completed")
	_check(_count_event(memory_system, CIVILIAN_NPC_ID, "enemy_breach_noncombat_response") == 0, "T0427 civilian breach event was written before reflection completed")

	_complete_reflection_lock(reflection_system, npc_system, ARMED_NPC_ID)
	_complete_reflection_lock(reflection_system, npc_system, CIVILIAN_NPC_ID)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	_check(str(npc_system.get_npc_state(ARMED_NPC_ID).get("behavior_mode", "")) == "combat", "T0427 armed NPC did not respond after reflection completed")
	_check(str(npc_system.get_npc_state(CIVILIAN_NPC_ID).get("behavior_mode", "")) == "avoid_combat", "T0427 civilian did not respond after reflection completed")
	_check(not _attachment_active(npc_system, ARMED_NPC_ID), "T0427 armed NPC remained attached after deferred response")
	_check(not _attachment_active(npc_system, CIVILIAN_NPC_ID), "T0427 civilian remained attached after deferred response")
	_check(_count_event(memory_system, ARMED_NPC_ID, "enemy_breach_combat_response") == 1, "T0427 armed deferred response event count is incorrect")
	_check(_count_event(memory_system, CIVILIAN_NPC_ID, "enemy_breach_noncombat_response") == 1, "T0427 civilian deferred response event count is incorrect")

	print("T0427_REFLECTION_DEFERRED_BREACH_OK")
	combat_system.debug_clear_enemies()
	_finish()


func _run_real_verification(
	combat_system: Node,
	npc_system: Node,
	action_system: Node,
	reflection_system: Node,
	memory_system: Node,
	llm_bridge: Node
) -> void:
	_check(llm_bridge != null, "T0427 real LLMBridge is unavailable")
	if not _failures.is_empty():
		_finish()
		return
	var health: Dictionary = llm_bridge.debug_check_health()
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {}) if health.get("body", {}) is Dictionary else {}
	_check(
		bool(health.get("ok", false))
		and str(adapter.get("provider", "")).to_lower() != "mock"
		and bool(adapter.get("configured", false))
		and not bool(adapter.get("fallback_to_mock", false)),
		"T0427 real provider is unavailable: %s" % health
	)
	var sleep: Dictionary = action_system.stage_npc_sleep_for_tutorial(ARMED_NPC_ID)
	_check(bool(sleep.get("ok", false)), "T0427 could not stage real reflection sleeper")
	memory_system.add_event({
		"type": "work_started",
		"subject_npc_id": ARMED_NPC_ID,
		"actor_ids": [ARMED_NPC_ID],
		"target_ids": [],
		"location_id": "dormitory",
		"visibility": "private",
		"importance": 60,
		"summary": "艾达在睡前回想驿站的防务安排。",
		"payload": {
			"action_id": "verify_t0427_real_reflection",
			"building_id": "dormitory",
			"workstation_id": str(sleep.get("workstation_id", ""))
		}
	})
	var start: Dictionary = reflection_system.generate_daily_reflection_for_npc(ARMED_NPC_ID, {
		"day": 1,
		"force": true,
		"lock_summary": true,
		"trigger": "verify_t0427_real"
	})
	_check(bool(start.get("ok", false)) and bool(start.get("pending", false)), "T0427 real reflection did not start asynchronously: %s" % start)
	if not _failures.is_empty():
		_finish()
		return

	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true, true)
	var preservation: Dictionary = spawn.get("reflection_interrupt_result", {})
	_check(int(preservation.get("interrupted_count", -1)) == 0, "T0427 real reflection was interrupted by spawn")
	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	_set_enemy_position(combat_system, enemy_id, INTRUDER_POSITION)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	_check(npc_system.is_first_sleep_summary_locked(ARMED_NPC_ID), "T0427 real reflection lock was released by station breach")
	_check(_attachment_active(npc_system, ARMED_NPC_ID), "T0427 real reflection sleeper left bed before completion")
	_check(_count_event(memory_system, ARMED_NPC_ID, "enemy_breach_combat_response") == 0, "T0427 real path wrote breach response before reflection completion")

	var deadline := Time.get_ticks_msec() + 120000
	while npc_system.is_first_sleep_summary_locked(ARMED_NPC_ID) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_check(not npc_system.is_first_sleep_summary_locked(ARMED_NPC_ID), "T0427 real reflection timed out")
	var final_reflection: Dictionary = reflection_system.get_last_reflection_result()
	_check(bool(final_reflection.get("ok", false)), "T0427 real reflection did not complete successfully: %s" % final_reflection)
	_check(str(final_reflection.get("source", "")) == "llm_daily_reflection", "T0427 real reflection used a non-LLM source: %s" % final_reflection)
	_check(not bool(final_reflection.get("model_fallback_used", true)), "T0427 real reflection used fallback")
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	_check(str(npc_system.get_npc_state(ARMED_NPC_ID).get("behavior_mode", "")) == "combat", "T0427 real path did not respond after reflection completion")
	_check(_count_event(memory_system, ARMED_NPC_ID, "enemy_breach_combat_response") == 1, "T0427 real path response event count is incorrect")
	print("T0427_REFLECTION_DEFERRED_BREACH_REAL_OK provider=%s model=%s" % [
		str(final_reflection.get("model_provider", "")),
		str(final_reflection.get("model_name", ""))
	])
	combat_system.debug_clear_enemies()
	_finish()


func _stage_reflection_lock(reflection_system: Node, npc_system: Node, npc_id: String) -> void:
	var request_id := "verify_t0427_%s" % npc_id
	reflection_system._pending_reflection_by_request[request_id] = {
		"npc_id": npc_id,
		"summary_window_key": "verify_t0427_window",
		"should_lock_summary": true
	}
	reflection_system._pending_request_by_npc[npc_id] = request_id
	npc_system.set_first_sleep_summary_lock(npc_id, true, request_id)


func _complete_reflection_lock(reflection_system: Node, npc_system: Node, npc_id: String) -> void:
	var request_id := str(reflection_system._pending_request_by_npc.get(npc_id, ""))
	reflection_system._pending_reflection_by_request.erase(request_id)
	reflection_system._pending_request_by_npc.erase(npc_id)
	npc_system.set_first_sleep_summary_lock(npc_id, false, request_id)


func _reflection_is_pending(reflection_system: Node, npc_id: String) -> bool:
	var request_id := str(reflection_system._pending_request_by_npc.get(npc_id, ""))
	return not request_id.is_empty() and reflection_system._pending_reflection_by_request.has(request_id)


func _still_reflecting_in_bed(npc_system: Node, npc_id: String, expected_position: Vector3) -> bool:
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	return (
		npc_system.is_first_sleep_summary_locked(npc_id)
		and str(state.get("current_action", "")) == "sleep_in_dormitory"
		and str(state.get("behavior_mode", "")) == "work"
		and npc_system.get_npc_world_position(npc_id).distance_to(expected_position) <= 0.01
		and _attachment_active(npc_system, npc_id)
	)


func _attachment_active(npc_system: Node, npc_id: String) -> bool:
	var actor := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath()))
	return actor != null and bool(actor.debug_get_spatial_attachment_snapshot().get("active", false))


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	combat_system._active_enemies[enemy_id] = enemy
	var actor := combat_system.get_node_or_null(combat_system._enemy_nodes.get(enemy_id, NodePath())) as Node3D
	if actor != null:
		if actor.has_method("stop_movement"):
			actor.stop_movement()
		actor.global_position = position


func _count_event(memory_system: Node, npc_id: String, event_type: String) -> int:
	var count := 0
	for event in memory_system.get_npc_daily_events(npc_id):
		if str(event.get("type", "")) == event_type:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
