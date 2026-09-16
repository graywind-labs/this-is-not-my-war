extends SceneTree

const SKIP_STEPS := [
	"intro",
	"battlefield_explain",
	"select_slot",
	"select_device",
	"camera_controls",
	"wait_tower",
	"tower_destroyed",
	"select_ada",
	"equipment_button",
	"main_weapon",
	"sword_shield",
	"equip_showcase",
	"alarm",
	"battle",
	"battle_health",
	"victory",
	"post_battle",
	"ada_return",
	"handoff_card",
]

const PLAYER_WAIT_STEPS := [
	"intro",
	"battlefield_explain",
	"select_slot",
	"select_device",
	"camera_controls",
	"tower_destroyed",
	"select_ada",
	"equipment_button",
	"main_weapon",
	"sword_shield",
	"alarm",
	"post_battle",
]

const TARGET_STEPS := [
	"select_slot",
	"select_device",
	"select_ada",
	"equipment_button",
	"main_weapon",
	"sword_shield",
	"alarm",
]

const PROHIBITED_TUTORIAL_EVENT_TYPES := [
	"defense_device_deployed",
	"defense_device_triggered",
	"equipment_changed",
	"equipment_given",
	"npc_damaged",
	"combat_started",
	"combat_ended",
]

var _main_scene: PackedScene


func _init() -> void:
	_main_scene = load("res://scenes/main/Main.tscn") as PackedScene
	if _main_scene == null:
		_fail("T1505 boundary verification could not load Main.tscn")
		return
	if OS.get_cmdline_user_args().has("--safety-only"):
		var baseline_case: Dictionary = await _create_tutorial_case()
		if baseline_case.is_empty():
			return
		var baseline_handoff: Dictionary = (baseline_case.get("tutorial") as Node).debug_skip_tutorial()
		await process_frame
		if not _verify_formal_handoff(baseline_case, baseline_handoff, true, true):
			return
		var focused_baseline := _capture_formal_baseline(baseline_case)
		await _destroy_case(baseline_case)
		if not await _verify_tower_timeout_recovery(focused_baseline):
			return
		if not await _verify_battle_and_return_timeout_recovery(focused_baseline):
			return
		print("T1505 focused recovery verification passed.")
		quit(0)
		return
	var normal_case: Dictionary = await _create_tutorial_case()
	if normal_case.is_empty():
		return
	if not await _drive_to_step(normal_case, "handoff_card"):
		return
	var normal_tutorial := normal_case.get("tutorial") as Node
	var normal_handoff: Dictionary = normal_tutorial.debug_complete_handoff_card()
	await process_frame
	if not _verify_formal_handoff(normal_case, normal_handoff, true, false):
		return
	var normal_baseline := _capture_formal_baseline(normal_case)
	await _destroy_case(normal_case)

	for target_step in SKIP_STEPS:
		print("T1505 boundary case: skip at %s" % target_step)
		var tutorial_case: Dictionary = await _create_tutorial_case()
		if tutorial_case.is_empty():
			return
		if not await _drive_to_step(tutorial_case, target_step):
			return
		var tutorial := tutorial_case.get("tutorial") as Node
		var time_system := tutorial_case.get("time_system") as Node
		var llm_bridge := tutorial_case.get("llm_bridge") as Node
		if target_step in PLAYER_WAIT_STEPS:
			var request_count_before_wait := int(llm_bridge.get("_request_counter"))
			tutorial.call("_process", 300.0)
			if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != target_step:
				_fail("T1505 player wait advanced step %s" % target_step)
				return
			if not bool(time_system.is_paused) or int(tutorial_case.get("game_state").current_day) != 1 or int(tutorial_case.get("game_state").current_hour) != 1:
				_fail("T1505 five-minute wait advanced formal time at %s" % target_step)
				return
			if int(llm_bridge.get("_request_counter")) != request_count_before_wait:
				_fail("T1505 five-minute wait requested LLM at %s" % target_step)
				return
		if target_step in TARGET_STEPS:
			var step_before_wrong_input := str(tutorial.get_tutorial_snapshot().get("step_id", ""))
			tutorial.call("_on_target_pressed", "invalid_tutorial_target")
			tutorial.debug_continue()
			if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != step_before_wrong_input:
				_fail("T1505 invalid input advanced target step %s" % target_step)
				return
		var handoff: Dictionary = tutorial.debug_skip_tutorial()
		await process_frame
		if not _verify_formal_handoff(tutorial_case, handoff, true, true):
			return
		var skip_baseline := _capture_formal_baseline(tutorial_case)
		if skip_baseline != normal_baseline:
			_fail(
				"T1505 formal baseline differs after skipping at %s: %s"
				% [target_step, _describe_dictionary_difference(normal_baseline, skip_baseline)]
			)
			return
		await _destroy_case(tutorial_case)

	if not await _verify_tower_timeout_recovery(normal_baseline):
		return
	if not await _verify_battle_and_return_timeout_recovery(normal_baseline):
		return

	print("T1505 tutorial boundary, skip, wait, LLM-isolation, and recovery verification passed.")
	quit(0)


func _create_tutorial_case() -> Dictionary:
	var main := _main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var tutorial_case := {
		"main": main,
		"startup": main.get_node_or_null("Systems/GameStartupSystem"),
		"tutorial": main.get_node_or_null("Systems/TutorialDirector"),
		"time_system": main.get_node_or_null("Systems/TimeSystem"),
		"resource_system": main.get_node_or_null("Systems/ResourceSystem"),
		"building_system": main.get_node_or_null("Systems/BuildingSystem"),
		"crafting_system": main.get_node_or_null("Systems/CraftingSystem"),
		"horse_system": main.get_node_or_null("Systems/HorseSystem"),
		"npc_system": main.get_node_or_null("Systems/NPCSystem"),
		"memory_system": main.get_node_or_null("Systems/MemorySystem"),
		"equipment_system": main.get_node_or_null("Systems/EquipmentSystem"),
		"defense_system": main.get_node_or_null("Systems/DefenseDeviceSystem"),
		"combat_system": main.get_node_or_null("Systems/CombatSystem"),
		"daily_plan_system": main.get_node_or_null("Systems/DailyPlanSystem"),
		"llm_bridge": main.get_node_or_null("Systems/LLMBridge"),
		"game_state": root.get_node_or_null("GameState"),
	}
	for key in tutorial_case.keys():
		if key != "main" and tutorial_case.get(key) == null:
			_fail("T1505 boundary verification missing node: %s" % key)
			return {}
	var startup := tutorial_case.get("startup") as Node
	var result: Dictionary = startup.debug_apply_startup_mode(2, true, false)
	await process_frame
	if not bool(result.get("tutorial_requested", false)):
		_fail("T1505 boundary case did not request tutorial startup")
		return {}
	var tutorial := tutorial_case.get("tutorial") as Node
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "intro":
		_fail("T1505 boundary case did not enter intro")
		return {}
	return tutorial_case


func _destroy_case(tutorial_case: Dictionary) -> void:
	var main := tutorial_case.get("main") as Node
	if main != null and is_instance_valid(main):
		main.queue_free()
	await process_frame
	await process_frame


func _drive_to_step(tutorial_case: Dictionary, target_step: String) -> bool:
	var tutorial := tutorial_case.get("tutorial") as Node
	var defense_system := tutorial_case.get("defense_system") as Node
	var npc_system := tutorial_case.get("npc_system") as Node
	for _iteration in range(80):
		var step := str(tutorial.get_tutorial_snapshot().get("step_id", ""))
		if step == target_step:
			return true
		match step:
			"intro", "battlefield_explain", "camera_controls", "tower_destroyed", "post_battle":
				tutorial.debug_continue()
			"select_slot", "select_device", "select_ada", "equipment_button", "main_weapon", "sword_shield", "alarm":
				tutorial.debug_press_current_target()
			"wait_tower":
				var destroy_result: Dictionary = defense_system.debug_destroy_first_device()
				if not bool(destroy_result.get("ok", false)):
					_fail("T1505 could not drive tower destruction: %s" % str(destroy_result))
					return false
			"equip_showcase":
				tutorial.call("_process", 1.1)
			"battle":
				if target_step == "battle_health":
					var state: Dictionary = npc_system.get_npc_state("veteran_deputy_01")
					var damage_result: Dictionary = npc_system.apply_damage_to_npc(
						"veteran_deputy_01",
						1,
						"tutorial_boundary_fixture",
						"private",
						{
							"skip_memory_event": true,
							"tutorial_scope": true,
							"skip_low_hp_judgement": true,
						}
					)
					if not bool(damage_result.get("ok", false)) or int(state.get("hp", 0)) <= int(damage_result.get("hp_after", 0)):
						_fail("T1505 could not drive the health hint fixture")
						return false
					tutorial.call("_process", 0.1)
				else:
					tutorial.debug_finish_tutorial_battle()
			"battle_health":
				tutorial.debug_finish_tutorial_battle()
			"victory":
				tutorial.debug_acknowledge_victory()
			"ada_return":
				tutorial.debug_finish_ada_return()
			_:
				_fail("T1505 cannot drive from step %s toward %s" % [step, target_step])
				return false
		await process_frame
	_fail("T1505 timed out driving to tutorial step %s" % target_step)
	return false


func _verify_formal_handoff(
	tutorial_case: Dictionary,
	handoff: Dictionary,
	expect_diary: bool,
	expect_skipped: bool
) -> bool:
	if not bool(handoff.get("ok", false)) or bool(handoff.get("skipped", not expect_skipped)) != expect_skipped:
		_fail("T1505 handoff result mismatch: %s" % str(handoff))
		return false
	var startup := tutorial_case.get("startup") as Node
	var tutorial := tutorial_case.get("tutorial") as Node
	var time_system := tutorial_case.get("time_system") as Node
	var daily_plan_system := tutorial_case.get("daily_plan_system") as Node
	var resource_system := tutorial_case.get("resource_system") as Node
	var defense_system := tutorial_case.get("defense_system") as Node
	var combat_system := tutorial_case.get("combat_system") as Node
	var npc_system := tutorial_case.get("npc_system") as Node
	var memory_system := tutorial_case.get("memory_system") as Node
	var llm_bridge := tutorial_case.get("llm_bridge") as Node
	var game_state := tutorial_case.get("game_state") as Node
	var startup_snapshot: Dictionary = startup.debug_get_startup_snapshot()
	if (
		not bool(startup_snapshot.get("formal_loop_started", false))
		or str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "finished"
		or bool(time_system.is_paused)
		or not bool(daily_plan_system.auto_execution_enabled)
		or int(game_state.current_day) != 1
		or int(game_state.current_hour) != 6
	):
		_fail("T1505 formal handoff state mismatch: %s" % str(startup_snapshot))
		return false
	if (
		resource_system.get_resource("item_wall_arrow_tower") != 0
		or resource_system.get_resource("item_sword_shield") != 0
		or not defense_system.get_deployments().is_empty()
		or not defense_system.get_device_ruins().is_empty()
		or combat_system.get_active_enemy_count() != 0
	):
		_fail("T1505 temporary combat state leaked after handoff")
		return false
	var wave: Dictionary = combat_system.get_wave_schedule_snapshot()
	if (
		not (wave.get("triggered_wave_numbers", []) as Array).is_empty()
		or int(wave.get("active_enemy_count", -1)) != 0
		or int((wave.get("next_wave", {}) as Dictionary).get("trigger_day", -1)) != 1
		or int((wave.get("next_wave", {}) as Dictionary).get("trigger_hour", -1)) != 23
	):
		_fail("T1505 formal wave baseline mismatch: %s" % str(wave))
		return false
	var ada_state: Dictionary = npc_system.get_npc_state("veteran_deputy_01")
	var ada_profile: Dictionary = npc_system.get_npc_combat_profile_snapshot("veteran_deputy_01")
	if (
		int(ada_state.get("hp", 0)) != int(ada_state.get("max_hp", -1))
		or str((((ada_profile.get("equipment", {}) as Dictionary).get("main_weapon", {})) as Dictionary).get("id", "")) != "sword_shield"
	):
		_fail("T1505 Ada did not return to full HP with sword shield")
		return false
	var expected_beds := {
		"veteran_deputy_01": "dormitory_bed_01",
		"stableman_01": "dormitory_bed_02",
		"cook_01": "dormitory_bed_03",
		"gardener_01": "dormitory_bed_04",
		"blacksmith_01": "dormitory_bed_05",
		"engineer_01": "dormitory_bed_06",
		"priest_01": "dormitory_bed_07",
		"doctor_01": "dormitory_bed_08"
	}
	var formal_start_beds: Dictionary = handoff.get("formal_start_beds", {})
	var bed_items: Dictionary = formal_start_beds.get("items", {})
	var formal_start_positions: Dictionary = handoff.get("formal_start_positions", {})
	var position_items: Dictionary = formal_start_positions.get("items", {})
	if (
		not bool(formal_start_beds.get("ok", false))
		or not bool(formal_start_positions.get("ok", false))
		or bed_items.size() != expected_beds.size()
		or position_items.size() != expected_beds.size()
	):
		_fail("T1505 handoff did not stage all eight assigned beds: %s" % str(formal_start_beds))
		return false
	for raw_npc_id in expected_beds.keys():
		var npc_id := str(raw_npc_id)
		var bed_item: Dictionary = bed_items.get(npc_id, {})
		var position_item: Dictionary = position_items.get(npc_id, {})
		var staged_position: Vector3 = position_item.get("world_position", Vector3.INF)
		if (
			str(bed_item.get("workstation_id", "")) != str(expected_beds[npc_id])
			or staged_position == Vector3.INF
			or npc_system.get_npc_world_position(npc_id).distance_to(staged_position) > 2.5
		):
			_fail("T1505 handoff did not originate %s at assigned bed: %s" % [npc_id, str(bed_item)])
			return false
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
		if plan.size() != 24:
			_fail("T1505 preset plan length mismatch for %s" % npc_id)
			return false
		for hour in range(24):
			var item: Dictionary = plan[hour]
			if int(item.get("hour", -1)) != hour or str(item.get("source", "")) != "tutorial_day1_preset" or str(item.get("action_id", "")).is_empty():
				_fail("T1505 preset plan item invalid for %s hour %d" % [npc_id, hour])
				return false
	var diary_count := 0
	for raw_record in npc_system.get_npc("veteran_deputy_01").get("diary", []):
		if (
			raw_record is Dictionary
			and str((raw_record as Dictionary).get("source", "")) == "initial_long_memory"
			and str((raw_record as Dictionary).get("record_label", "")) == "接到守备命令的前一天"
		):
			diary_count += 1
			if expect_diary and (
				int((raw_record as Dictionary).get("day", -1)) != 0
				or str((raw_record as Dictionary).get("time", "")) != "02:00:00"
				or str((raw_record as Dictionary).get("record_label", "")) != "接到守备命令的前一天"
			):
				_fail("T1505 tutorial diary chronology mismatch: %s" % str(raw_record))
				return false
	if diary_count != (1 if expect_diary else 0):
		_fail("T1505 tutorial diary count mismatch: %d" % diary_count)
		return false
	for event in memory_system.get_all_events():
		if str(event.get("type", "")) in PROHIBITED_TUTORIAL_EVENT_TYPES:
			_fail("T1505 tutorial event leaked after handoff: %s" % str(event))
			return false
	if int(llm_bridge.get("_request_counter")) != 0:
		_fail("T1505 tutorial or preset handoff requested LLM: %d" % int(llm_bridge.get("_request_counter")))
		return false
	return true


func _capture_formal_baseline(tutorial_case: Dictionary) -> Dictionary:
	var game_state := tutorial_case.get("game_state") as Node
	var time_system := tutorial_case.get("time_system") as Node
	var resource_system := tutorial_case.get("resource_system") as Node
	var building_system := tutorial_case.get("building_system") as Node
	var crafting_system := tutorial_case.get("crafting_system") as Node
	var horse_system := tutorial_case.get("horse_system") as Node
	var defense_system := tutorial_case.get("defense_system") as Node
	var combat_system := tutorial_case.get("combat_system") as Node
	var npc_system := tutorial_case.get("npc_system") as Node
	var daily_plan_system := tutorial_case.get("daily_plan_system") as Node
	var npc_ids: Array = npc_system.get_npc_ids()
	npc_ids.sort()
	var npc_numeric_baseline := {}
	var plans := {}
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var profile: Dictionary = npc_system.get_npc_combat_profile_snapshot(npc_id)
		npc_numeric_baseline[npc_id] = {
			"hp": int(state.get("hp", 0)),
			"max_hp": int(state.get("max_hp", 0)),
			"satiety": int(state.get("satiety", 0)),
			"fatigue": int(state.get("fatigue", 0)),
			"money": int(state.get("money", 0)),
			"wine": int(state.get("wine", 0)),
			"unconscious": bool(state.get("unconscious", false)),
			"escaped": bool(state.get("escaped", false)),
			"recruited": bool(profile.get("recruited", false)),
			"equipment": (profile.get("equipment", {}) as Dictionary).duplicate(true),
			"skills": (profile.get("skills", {}) as Dictionary).duplicate(true),
			"stats": (profile.get("stats", {}) as Dictionary).duplicate(true),
			"progression": (profile.get("progression", {}) as Dictionary).duplicate(true),
		}
		plans[npc_id] = daily_plan_system.get_npc_daily_plan(npc_id)
	var wave: Dictionary = combat_system.get_wave_schedule_snapshot()
	var next_wave: Dictionary = wave.get("next_wave", {}) if wave.get("next_wave", {}) is Dictionary else {}
	return {
		"clock": {
			"day": int(game_state.current_day),
			"hour": int(game_state.current_hour),
			"minute": int(game_state.current_minute),
			"paused": bool(time_system.is_paused),
		},
		"resources": resource_system.get_resource_snapshot(),
		"buildings": building_system.get_building_snapshot(),
		"crafting": crafting_system.get_all_project_snapshots(),
		"horses": horse_system.get_horse_state_snapshot(),
		"horse_balance": horse_system.get_balance_snapshot(),
		"defense": _capture_defense_formal_state(defense_system),
		"npcs": npc_numeric_baseline,
		"plans": plans,
		"formal_wave": {
			"triggered_wave_numbers": (wave.get("triggered_wave_numbers", []) as Array).duplicate(),
			"active_enemy_count": int(wave.get("active_enemy_count", 0)),
			"next_wave": {
				"wave_number": int(next_wave.get("wave_number", 0)),
				"trigger_day": int(next_wave.get("trigger_day", 0)),
				"trigger_hour": int(next_wave.get("trigger_hour", 0)),
				"trigger_minute": int(next_wave.get("trigger_minute", 0)),
			},
		},
	}


func _capture_defense_formal_state(defense_system: Node) -> Dictionary:
	var slot_ids: Array = defense_system.get_slot_ids()
	slot_ids.sort()
	var slots := {}
	for raw_slot_id in slot_ids:
		var slot_id := str(raw_slot_id)
		slots[slot_id] = defense_system.get_slot(slot_id)
	return {
		"slots": slots,
		"deployments": defense_system.get_deployments(),
		"ruins": defense_system.get_device_ruins(),
	}


func _verify_tower_timeout_recovery(formal_baseline: Dictionary) -> bool:
	var tutorial_case: Dictionary = await _create_tutorial_case()
	if tutorial_case.is_empty() or not await _drive_to_step(tutorial_case, "wait_tower"):
		return false
	var tutorial := tutorial_case.get("tutorial") as Node
	var time_system := tutorial_case.get("time_system") as Node
	var llm_bridge := tutorial_case.get("llm_bridge") as Node
	tutorial.call("_process", 25.1)
	var snapshot: Dictionary = tutorial.get_tutorial_snapshot()
	if (
		str(snapshot.get("step_id", "")) != "tower_destroyed"
		or str((snapshot.get("recovery", {}) as Dictionary).get("reason", "")) != "tower_phase_timeout"
		or not bool(time_system.is_paused)
		or int(llm_bridge.get("_request_counter")) != 0
	):
		_fail("T1505 stalled tower phase did not recover safely: %s" % str(snapshot))
		return false
	var handoff: Dictionary = tutorial.debug_skip_tutorial()
	await process_frame
	if not _verify_formal_handoff(tutorial_case, handoff, true, true):
		return false
	if _capture_formal_baseline(tutorial_case) != formal_baseline:
		_fail("T1505 tower timeout recovery changed the formal baseline")
		return false
	await _destroy_case(tutorial_case)
	return true


func _verify_battle_and_return_timeout_recovery(formal_baseline: Dictionary) -> bool:
	var tutorial_case: Dictionary = await _create_tutorial_case()
	if tutorial_case.is_empty() or not await _drive_to_step(tutorial_case, "battle"):
		return false
	var tutorial := tutorial_case.get("tutorial") as Node
	var time_system := tutorial_case.get("time_system") as Node
	tutorial.call("_process", 91.0)
	await process_frame
	var timeout_snapshot: Dictionary = tutorial.get_tutorial_snapshot()
	if str(timeout_snapshot.get("step_id", "")) != "victory" or not bool(time_system.is_paused):
		_fail(
			"T1505 battle timeout did not enter tutorial victory safely: paused=%s step=%s enemies=%d"
			% [
				str(time_system.is_paused),
				str(timeout_snapshot.get("step_id", "")),
				int((timeout_snapshot.get("combat", {}) as Dictionary).get("active_enemy_count", -1)),
			]
		)
		return false
	tutorial.debug_acknowledge_victory()
	if not await _drive_to_step(tutorial_case, "ada_return"):
		return false
	tutorial.call("_process", 8.1)
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "handoff_card":
		_fail("T1505 Ada return timeout did not reach the handoff card")
		return false
	var handoff_duration := float(tutorial.get_tutorial_snapshot().get("handoff_card_duration_seconds", 5.0))
	tutorial.call("_process", handoff_duration + 0.1)
	await process_frame
	var handoff: Dictionary = tutorial.get_tutorial_snapshot().get("handoff", {})
	if not _verify_formal_handoff(tutorial_case, handoff, true, false):
		return false
	if _capture_formal_baseline(tutorial_case) != formal_baseline:
		_fail("T1505 battle/return timeout recovery changed the formal baseline")
		return false
	var diary_count_before := int((tutorial_case.get("npc_system") as Node).get_npc("veteran_deputy_01").get("diary", []).size())
	var repeated: Dictionary = tutorial.debug_skip_tutorial()
	if not bool(repeated.get("ok", false)) or (tutorial_case.get("npc_system") as Node).get_npc("veteran_deputy_01").get("diary", []).size() != diary_count_before:
		_fail("T1505 automatic handoff was not idempotent")
		return false
	await _destroy_case(tutorial_case)
	return true


func _describe_dictionary_difference(expected: Dictionary, actual: Dictionary) -> String:
	var differences: Array[String] = []
	var keys: Array = expected.keys()
	for key in actual.keys():
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	for raw_key in keys:
		var key := str(raw_key)
		if not expected.has(key):
			differences.append("%s only_actual" % key)
		elif not actual.has(key):
			differences.append("%s only_expected" % key)
		elif expected.get(key) != actual.get(key):
			differences.append(
				"%s expected_hash=%d actual_hash=%d"
				% [key, hash(expected.get(key)), hash(actual.get(key))]
			)
	return ", ".join(differences)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
