extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var controller := main.get_node("Presentation/WorkAudioController")
	var npc_system := main.get_node("Systems/NPCSystem")
	var action_system := main.get_node("Systems/ActionSystem")
	var horse_system := main.get_node("Systems/HorseSystem")
	var audio_manager := root.get_node("AudioManager")
	action_system.set("_pending_actions", {})
	_assert_config_assets_exist(audio_manager)
	_assert(bool(controller.get_debug_snapshot().get("initialized", false)), "controller did not initialize")
	_assert(int(controller.get_debug_snapshot().get("active_loop_count", -1)) == 0, "work audio should start silent")

	var active_actions: Dictionary = action_system.get("_active_actions")
	active_actions["blacksmith_01"] = _active_record(action_system, "work_blacksmith", "work", "blacksmith")
	action_system.set("_active_actions", active_actions)
	npc_system.update_npc_state("blacksmith_01", {
		"current_action": "work_blacksmith",
		"current_location": "blacksmith",
	})
	await process_frame
	await process_frame
	_assert_loop(controller, "blacksmith_work", "sfx_work_blacksmith_loop")
	_assert_all_work_players_are_positional(audio_manager)

	active_actions.erase("blacksmith_01")
	active_actions["stableman_01"] = _active_record(action_system, "work_stable", "work", "stable")
	action_system.set("_active_actions", active_actions)
	npc_system.update_npc_state("blacksmith_01", {"current_action": "idle"})
	npc_system.update_npc_state("stableman_01", {
		"current_action": "work_stable",
		"current_location": "stable",
	})
	await process_frame
	await process_frame
	var expected_stable_asset := (
		"sfx_work_stable_with_horse_loop"
		if int(horse_system.get_stable_horse_summary().get("total", 0)) > 0
		else "sfx_work_stable_without_horse_loop"
	)
	_assert_loop(controller, "stable_care", expected_stable_asset)
	var original_horses: Dictionary = (horse_system.get("_horses") as Dictionary).duplicate(true)
	var empty_horses := original_horses.duplicate(true)
	for raw_horse_id in empty_horses.keys():
		var horse: Dictionary = (empty_horses.get(raw_horse_id, {}) as Dictionary).duplicate(true)
		horse["alive"] = false
		empty_horses[raw_horse_id] = horse
	horse_system.set("_horses", empty_horses)
	root.get_node("EventBus").horse_state_changed.emit("audio_test")
	await process_frame
	await process_frame
	_assert_loop(controller, "stable_care", "sfx_work_stable_without_horse_loop")
	horse_system.set("_horses", original_horses)

	active_actions.clear()
	active_actions["doctor_01"] = _active_record(action_system, "work_clinic_doctor", "clinic_doctor", "clinic")
	action_system.set("_active_actions", active_actions)
	npc_system.update_npc_state("stableman_01", {"current_action": "idle"})
	npc_system.update_npc_state("doctor_01", {
		"current_action": "work_clinic_doctor",
		"current_location": "clinic",
		"presentation_clinic_duty_mode": "study",
	})
	await process_frame
	await process_frame
	_assert_loop(controller, "clinic_reading", "sfx_work_clinic_doctor_reading_loop")

	npc_system.update_npc_state("doctor_01", {"presentation_clinic_duty_mode": "treatment"})
	await process_frame
	await process_frame
	_assert_loop(controller, "clinic_treatment", "sfx_work_clinic_treatment_and_assist_loop")
	_assert(not (controller.get_debug_snapshot().get("active_loops", {}) as Dictionary).has("clinic_reading"), "clinic reading must yield to treatment")

	active_actions.clear()
	active_actions["priest_01"] = _active_record(action_system, "lead_mass", "lead_mass", "chapel")
	action_system.set("_active_actions", active_actions)
	var one_shots_before_mass := int(audio_manager.debug_get_snapshot().get("active_one_shots", 0))
	npc_system.update_npc_state("doctor_01", {"current_action": "idle", "presentation_clinic_duty_mode": "study"})
	npc_system.update_npc_state("engineer_01", {"current_action": "idle"})
	npc_system.update_npc_state("priest_01", {
		"current_action": "lead_mass",
		"current_location": "chapel",
	})
	await process_frame
	await process_frame
	var mass_start_snapshot: Dictionary = controller.get_debug_snapshot()
	_assert(bool(mass_start_snapshot.get("mass_active", false)), "mass edge was not detected")
	_assert(not bool(mass_start_snapshot.get("mass_chant_ready", true)), "mass chant started before five-second bell")
	_assert(int(audio_manager.debug_get_snapshot().get("active_one_shots", 0)) > one_shots_before_mass, "mass start one-shot did not play")
	controller.debug_advance_audio_seconds(5.1)
	_assert_loop(controller, "chapel_mass", "sfx_chapel_mass_in_progress_loop")
	active_actions["priest_01"] = _active_record(action_system, "pray_at_chapel", "pray", "chapel")
	action_system.set("_active_actions", active_actions)
	npc_system.update_npc_state("priest_01", {"current_action": "pray_at_chapel"})
	await process_frame
	await process_frame
	_assert_loop(controller, "chapel_prayer", "sfx_chapel_prayer_presence_loop")
	_assert(not bool(controller.get_debug_snapshot().get("mass_active", true)), "mass state did not clear")

	active_actions.clear()
	active_actions["cook_01"] = _active_record(action_system, "drink_wine", "drink", "")
	action_system.set("_active_actions", active_actions)
	var one_shots_before_drink := int(audio_manager.debug_get_snapshot().get("active_one_shots", 0))
	npc_system.update_npc_state("priest_01", {"current_action": "idle"})
	npc_system.update_npc_state("cook_01", {"current_action": "drink_wine"})
	await process_frame
	await process_frame
	_assert(int(audio_manager.debug_get_snapshot().get("active_one_shots", 0)) > one_shots_before_drink, "drink action edge did not play")
	var one_shots_after_drink := int(audio_manager.debug_get_snapshot().get("active_one_shots", 0))
	controller.debug_force_refresh()
	_assert(int(audio_manager.debug_get_snapshot().get("active_one_shots", 0)) == one_shots_after_drink, "drink one-shot replayed during the same action")

	active_actions.clear()
	action_system.set("_active_actions", active_actions)
	npc_system.update_npc_state("cook_01", {"current_action": "idle"})
	npc_system.update_npc_state("engineer_01", {
		"current_action": "assist_repair_wall",
		"current_location": "plaza",
	})
	await process_frame
	await process_frame
	_assert_loop(controller, "construction_wall", "sfx_work_repair_and_upgrade_loop")

	var pending_actions: Dictionary = action_system.get("_pending_actions")
	pending_actions["gardener_01"] = "work_garden"
	action_system.set("_pending_actions", pending_actions)
	npc_system.update_npc_state("gardener_01", {"current_action": "moving_to_garden"})
	await process_frame
	await process_frame
	_assert(not (controller.get_debug_snapshot().get("active_loops", {}) as Dictionary).has("garden"), "pending travel incorrectly started work audio")

	main.queue_free()
	await process_frame
	await process_frame
	for raw_key in audio_manager.get_loop_snapshot().keys():
		_assert(not str(raw_key).begins_with("work_action_"), "work loop survived Main teardown: %s" % str(raw_key))

	print("T0135_P10C_WORK_AUDIO_PASS positional=pass active_only=pass clinic=pass chapel=pass one_shot_edges=pass")
	quit(0)


func _active_record(action_system: Node, action_id: String, kind: String, building_id: String) -> Dictionary:
	return {
		"kind": kind,
		"action": action_system.get_action(action_id),
		"building_id": building_id,
		"workstation_id": "audio_test_station",
		"prayer_mode": "personal",
	}


func _assert_loop(controller: Node, semantic_key: String, asset_id: String) -> void:
	var loops: Dictionary = controller.get_debug_snapshot().get("active_loops", {})
	_assert(loops.has(semantic_key), "missing loop: %s" % semantic_key)
	_assert(str((loops.get(semantic_key, {}) as Dictionary).get("asset_id", "")) == asset_id, "wrong asset for %s" % semantic_key)


func _assert_all_work_players_are_positional(audio_manager: Node) -> void:
	for raw_key in audio_manager.get_loop_snapshot().keys():
		var loop_key := str(raw_key)
		if not loop_key.begins_with("work_action_"):
			continue
		var loop: Dictionary = audio_manager.get_loop_snapshot().get(loop_key, {})
		_assert(str(loop.get("player_type", "")) == "AudioStreamPlayer3D", "work loop is not positional")
		_assert(str(loop.get("bus", "")) == "Work", "work loop is not routed to Work bus")


func _assert_config_assets_exist(audio_manager: Node) -> void:
	var file := FileAccess.open("res://data/presentation/action_audio.json", FileAccess.READ)
	_assert(file != null, "action audio config could not be opened")
	if file == null:
		return
	var config: Dictionary = JSON.parse_string(file.get_as_text())
	var asset_ids := {}
	for raw_rule in config.get("loop_rules", []):
		var rule := raw_rule as Dictionary
		for field in ["asset_id", "asset_id_with_horse", "asset_id_without_horse"]:
			var asset_id := str(rule.get(field, ""))
			if not asset_id.is_empty():
				asset_ids[asset_id] = true
	for section_name in ["clinic", "chapel"]:
		var section: Dictionary = config.get(section_name, {})
		for raw_value in section.values():
			var value := str(raw_value)
			if value.begins_with("sfx_"):
				asset_ids[value] = true
	for raw_rule in config.get("one_shots", []):
		asset_ids[str((raw_rule as Dictionary).get("asset_id", ""))] = true
	var building_jobs: Dictionary = config.get("building_jobs", {})
	asset_ids[str(building_jobs.get("start_asset_id", ""))] = true
	asset_ids[str(building_jobs.get("loop_asset_id", ""))] = true
	var crafting_selection: Dictionary = config.get("crafting_target_selection", {})
	asset_ids[str(crafting_selection.get("asset_id", ""))] = true
	asset_ids.erase("")
	_assert(asset_ids.size() == 18, "unexpected P10C asset count: %d" % asset_ids.size())
	for raw_asset_id in asset_ids.keys():
		_assert(audio_manager.has_asset(str(raw_asset_id)), "missing manifest asset: %s" % str(raw_asset_id))
	_assert((config.get("excluded_actions", []) as Array).has("sleep_in_dormitory"), "sleep exclusion is missing")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("T0135 P10C verification failed: %s" % message)
	quit(1)
