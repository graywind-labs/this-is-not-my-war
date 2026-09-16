extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("T1505 natural combat verification could not load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	var tutorial := main.get_node_or_null("Systems/TutorialDirector")
	var time_system := main.get_node_or_null("Systems/TimeSystem")
	var defense_system := main.get_node_or_null("Systems/DefenseDeviceSystem")
	var combat_system := main.get_node_or_null("Systems/CombatSystem")
	var npc_system := main.get_node_or_null("Systems/NPCSystem")
	var memory_system := main.get_node_or_null("Systems/MemorySystem")
	var llm_bridge := main.get_node_or_null("Systems/LLMBridge")
	var game_state := root.get_node_or_null("GameState")
	if [startup, tutorial, time_system, defense_system, combat_system, npc_system, memory_system, llm_bridge, game_state].has(null):
		_fail("T1505 natural combat verification is missing required runtime nodes")
		return
	startup.debug_apply_startup_mode(2, true, false)
	await process_frame
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "intro":
		_fail("T1505 natural combat case did not enter intro")
		return

	for _page in range(9):
		tutorial.debug_continue()
	tutorial.debug_press_current_target()
	tutorial.debug_press_current_target()
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "camera_controls":
		_fail("T0431 natural combat case did not enter the camera controls page")
		return
	tutorial.debug_continue()
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "wait_tower":
		_fail("T1505 natural combat case did not deploy the tutorial tower")
		return
	if not await _wait_for_step(tutorial, "tower_destroyed", 30.0):
		_fail("T1505 tutorial tower did not leave the natural tower phase within 30 seconds")
		return
	var tower_metrics: Dictionary = (tutorial.get_tutorial_snapshot().get("phase_metrics", {}) as Dictionary).get("tower_phase", {})
	var tower_duration := float(tower_metrics.get("duration_seconds", -1.0))
	if (
		bool(tower_metrics.get("safety_used", true))
		or tower_duration <= 0.0
		or tower_duration > 15.0
		or int(tower_metrics.get("total_attacks", 0)) <= 0
		or int(tower_metrics.get("total_damage", 0)) <= 0
		or int(tower_metrics.get("remaining_enemy_count", 0)) != 5
		or int((tower_metrics.get("ruin", {}) as Dictionary).get("max_hp", 0)) != 15
		or int(((tower_metrics.get("ruin", {}) as Dictionary).get("last_damage_result", {}) as Dictionary).get("damage", 0)) != 5
		or not defense_system.get_deployments().is_empty()
	):
		_fail("T1505 natural tower phase contract failed: %s" % str(tower_metrics))
		return

	tutorial.debug_continue()
	for _target in range(4):
		tutorial.debug_press_current_target()
	tutorial.call("_process", 1.1)
	tutorial.debug_press_current_target()
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "battle":
		_fail("T1505 natural combat case did not start Ada's battle")
		return
	if not await _wait_for_step(tutorial, "victory", 90.0):
		_fail("T1505 Ada did not win the natural tutorial battle within 90 seconds")
		return
	var battle_metrics: Dictionary = (tutorial.get_tutorial_snapshot().get("phase_metrics", {}) as Dictionary).get("battle_phase", {})
	var recovery: Dictionary = tutorial.get_tutorial_snapshot().get("recovery", {})
	var battle_duration := float(battle_metrics.get("duration_seconds", -1.0))
	var hp_ratio := float(battle_metrics.get("ada_hp_ratio", -1.0))
	if (
		battle_duration < 15.0
		or battle_duration > 85.0
		or hp_ratio < 0.40
		or hp_ratio > 0.85
		or bool(battle_metrics.get("ada_unconscious", true))
		or not bool(battle_metrics.get("health_hint_shown", false))
		or not recovery.is_empty()
		or combat_system.get_active_enemy_count() != 0
	):
		_fail("T1505 natural Ada battle contract failed: %s" % str(battle_metrics))
		return
	if not bool(time_system.is_paused) or int(game_state.current_day) != 1 or int(game_state.current_hour) != 1:
		_fail("T1505 natural tutorial combat advanced the formal calendar")
		return
	if not bool(tutorial.get_tutorial_snapshot().get("detached_simulation_running", false)) or bool(time_system.is_gameplay_paused()):
		_fail("T1505 natural victory paused the isolated presentation clock")
		return
	if int(llm_bridge.get("_request_counter")) != 0:
		_fail("T1505 natural tutorial combat requested LLM")
		return
	var wave: Dictionary = combat_system.get_wave_schedule_snapshot()
	if not (wave.get("triggered_wave_numbers", []) as Array).is_empty() or bool(game_state.game_over):
		_fail("T1505 natural tutorial combat changed formal waves or settlement")
		return
	for event in memory_system.get_all_events():
		if str(event.get("type", "")) in [
			"defense_device_deployed",
			"defense_device_triggered",
			"equipment_changed",
			"equipment_given",
			"npc_damaged",
			"combat_started",
			"combat_ended",
		]:
			_fail("T1505 natural tutorial combat leaked a formal event: %s" % str(event))
			return

	tutorial.debug_acknowledge_victory()
	for _page in range(5):
		tutorial.debug_continue()
	# Return-to-bed and handoff-card timing are covered by the boundary suite. This
	# natural-combat suite closes through the shared handoff authority directly so
	# a debug teleport cannot emit unrelated sleep-path warnings into its log.
	var handoff: Dictionary = tutorial.call("_complete_handoff", false)
	await process_frame
	var ada_state: Dictionary = npc_system.get_npc_state("veteran_deputy_01")
	if (
		not bool(handoff.get("ok", false))
		or bool(handoff.get("skipped", true))
		or int(ada_state.get("hp", 0)) != int(ada_state.get("max_hp", -1))
		or int(game_state.current_day) != 1
		or int(game_state.current_hour) != 6
	):
		_fail("T1505 natural combat handoff did not restore the formal baseline: %s" % str(handoff))
		return

	print(
		"T1505 natural combat verification passed: tower %.2fs, %d damage, %d enemies remained; Ada battle %.2fs, HP %.0f%%."
		% [
			tower_duration,
			int(tower_metrics.get("total_damage", 0)),
			int(tower_metrics.get("remaining_enemy_count", 0)),
			battle_duration,
			hp_ratio * 100.0,
		]
	)
	quit(0)


func _wait_for_step(tutorial: Node, target_step: String, timeout_seconds: float) -> bool:
	var started_msec := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started_msec) / 1000.0 < timeout_seconds:
		if str(tutorial.get_tutorial_snapshot().get("step_id", "")) == target_step:
			return true
		await process_frame
	return str(tutorial.get_tutorial_snapshot().get("step_id", "")) == target_step


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
