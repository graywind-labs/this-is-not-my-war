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

	var work_audio := main.get_node("Presentation/WorkAudioController")
	var interaction_audio := main.get_node("Presentation/InteractionAudioController")
	var building_system := main.get_node("Systems/BuildingSystem")
	var crafting_system := main.get_node("Systems/CraftingSystem")
	var resource_system := main.get_node("Systems/ResourceSystem")
	var building_panel := main.get_node("UI/BuildingPanel")
	var audio_manager := root.get_node("AudioManager")
	var event_bus := root.get_node("EventBus")

	_assert(audio_manager.has_asset("sfx_work_repair_and_upgrade_start"), "confirmed short wood asset missing")
	_assert(audio_manager.has_asset("sfx_work_repair_and_upgrade_loop"), "confirmed construction loop missing")
	_assert(audio_manager.has_asset("sfx_work_blacksmith_target_selected"), "confirmed blacksmith strike missing")
	_assert(audio_manager.has_asset("sfx_ui_interaction_success_resource_collect"), "level-up completion asset missing")
	_assert(bool(building_panel.repair_button.get_meta("ui_audio_silent", false)), "repair button still emits generic UI click")
	_assert(bool(building_panel.upgrade_button.get_meta("ui_audio_silent", false)), "upgrade button still emits generic UI click")

	var loop_info: Dictionary = audio_manager.get_asset_info("sfx_work_repair_and_upgrade_loop")
	_assert(str(loop_info.get("loop", "false")).to_lower() == "true", "construction asset is not marked as a loop")
	_assert(int(loop_info.get("runtime_fade_in_ms", 0)) == 350, "construction loop fade-in changed")
	_assert(int(loop_info.get("runtime_fade_out_ms", 0)) == 350, "construction loop fade-out changed")

	for resource_id in ["wood", "stone", "iron", "money"]:
		resource_system.debug_add_resource(resource_id, 100)

	work_audio.debug_clear_recent_one_shots()
	_assert(building_system.debug_damage_building("wall", 25), "could not damage wall for repair test")
	_assert(building_system.repair_building("wall"), "repair job did not start")
	await process_frame
	await process_frame
	_assert_recent_work_one_shot(work_audio, "building_job_started", "sfx_work_repair_and_upgrade_start", "wall")
	_assert_construction_loop(work_audio, audio_manager, building_system, "wall")
	var repair_sound_count := (work_audio.get_debug_snapshot().get("recent_one_shots", []) as Array).size()
	event_bus.building_state_changed.emit("wall")
	_assert((work_audio.get_debug_snapshot().get("recent_one_shots", []) as Array).size() == repair_sound_count, "repair refresh replayed start sound")

	var active_repairs: Dictionary = building_system.get("_active_repairs")
	var repair_job: Dictionary = (active_repairs.get("wall", {}) as Dictionary).duplicate(true)
	repair_job["remaining_seconds"] = 0.0
	active_repairs["wall"] = repair_job
	building_system.set("_active_repairs", active_repairs)
	event_bus.logical_time_tick.emit(1.0, 1.0)
	await process_frame
	await process_frame
	_assert(not _has_construction_loop(work_audio, "wall"), "repair completion did not stop construction loop")

	interaction_audio.debug_clear_history()
	work_audio.debug_clear_recent_one_shots()
	_assert(building_system.upgrade_building("wall"), "upgrade job did not start")
	await process_frame
	await process_frame
	_assert_recent_work_one_shot(work_audio, "building_job_started", "sfx_work_repair_and_upgrade_start", "wall")
	_assert_construction_loop(work_audio, audio_manager, building_system, "wall")
	var active_upgrades: Dictionary = building_system.get("_active_upgrades")
	var upgrade_job: Dictionary = (active_upgrades.get("wall", {}) as Dictionary).duplicate(true)
	upgrade_job["remaining_seconds"] = 0.0
	active_upgrades["wall"] = upgrade_job
	building_system.set("_active_upgrades", active_upgrades)
	event_bus.logical_time_tick.emit(1.0, 1.0)
	await process_frame
	await process_frame
	_assert_ui_semantic(interaction_audio, "level_up", "sfx_ui_interaction_success_resource_collect")
	_assert(not _has_construction_loop(work_audio, "wall"), "upgrade completion did not stop construction loop")

	work_audio.debug_clear_recent_one_shots()
	var current_target := str(crafting_system.get_project_snapshot("blacksmith").get("target_recipe_id", ""))
	var selected_target := ""
	for recipe_id in crafting_system.get_recipe_ids_for_building("blacksmith"):
		if str(recipe_id) != current_target:
			selected_target = str(recipe_id)
			break
	_assert(not selected_target.is_empty(), "no alternate blacksmith target available")
	var select_result: Dictionary = crafting_system.set_target("blacksmith", selected_target, true)
	_assert(bool(select_result.get("ok", false)) and bool(select_result.get("changed", false)), "blacksmith target did not change")
	_assert_recent_work_one_shot(work_audio, "crafting_target_selected", "sfx_work_blacksmith_target_selected", "blacksmith")
	var selected_sound_count := (work_audio.get_debug_snapshot().get("recent_one_shots", []) as Array).size()
	var unchanged_result: Dictionary = crafting_system.set_target("blacksmith", selected_target, true)
	_assert(bool(unchanged_result.get("ok", false)) and not bool(unchanged_result.get("changed", true)), "same target was not unchanged")
	_assert((work_audio.get_debug_snapshot().get("recent_one_shots", []) as Array).size() == selected_sound_count, "unchanged target replayed strike")
	var clear_result: Dictionary = crafting_system.set_target("blacksmith", "", true)
	_assert(bool(clear_result.get("ok", false)), "blacksmith target clear failed")
	_assert((work_audio.get_debug_snapshot().get("recent_one_shots", []) as Array).size() == selected_sound_count, "empty target played strike")

	work_audio.debug_clear_recent_one_shots()
	var workshop_recipes: Array = crafting_system.get_recipe_ids_for_building("workshop")
	_assert(not workshop_recipes.is_empty(), "no workshop target available")
	var workshop_result: Dictionary = crafting_system.set_target("workshop", str(workshop_recipes[0]), true)
	_assert(bool(workshop_result.get("ok", false)) and bool(workshop_result.get("changed", false)), "workshop target did not change")
	_assert_recent_work_one_shot(work_audio, "crafting_target_selected", "sfx_work_blacksmith_target_selected", "workshop")

	main.queue_free()
	await process_frame
	await process_frame
	print("T0393_BUILDING_CRAFT_AUDIO_PASS start=global_click loop=positional_faded completion=level_up blacksmith_workshop=global_click")
	quit(0)


func _assert_recent_work_one_shot(controller: Node, kind: String, asset_id: String, building_id: String) -> void:
	var history: Array = controller.get_debug_snapshot().get("recent_one_shots", [])
	_assert(not history.is_empty(), "work one-shot history is empty")
	var entry: Dictionary = history.back()
	_assert(str(entry.get("kind", "")) == kind, "wrong work one-shot kind")
	_assert(str(entry.get("asset_id", "")) == asset_id, "wrong work one-shot asset")
	_assert(str(entry.get("building_id", "")) == building_id, "wrong work one-shot building")
	_assert(str(entry.get("player_type", "")) == "AudioStreamPlayer", "building click is not global 2D")
	_assert(str(entry.get("bus", "")) == "UI", "building click is not controlled by click volume")
	_assert(str(entry.get("spatial_profile", "")) == "global_2d", "building click still uses distance attenuation")
	_assert(is_equal_approx(float(entry.get("gain_db", 0.0)), 4.0), "selected building one-shot gain is not +4 dB")


func _assert_construction_loop(controller: Node, audio_manager: Node, building_system: Node, building_id: String) -> void:
	var semantic_key := "construction_%s" % building_id
	var loops: Dictionary = controller.get_debug_snapshot().get("active_loops", {})
	_assert(loops.has(semantic_key), "construction loop did not follow building job")
	var entry: Dictionary = loops.get(semantic_key, {})
	_assert(str(entry.get("asset_id", "")) == "sfx_work_repair_and_upgrade_loop", "wrong construction loop asset")
	var expected_position: Variant = building_system.get_building_entry_position(building_id)
	_assert(expected_position is Vector3, "building has no positional audio anchor")
	var actual_position: Vector3 = entry.get("world_position", Vector3.ZERO)
	_assert(actual_position.distance_to((expected_position as Vector3) + Vector3.UP * 1.15) < 0.01, "construction loop is not at building position")
	var loop_key := str(entry.get("loop_key", ""))
	var runtime_loop: Dictionary = audio_manager.get_loop_snapshot().get(loop_key, {})
	_assert(str(runtime_loop.get("player_type", "")) == "AudioStreamPlayer3D", "construction runtime player is not 3D")
	_assert(str(runtime_loop.get("bus", "")) == "Work", "construction runtime player is not on Work bus")
	_assert(str(runtime_loop.get("spatial_profile", "")) == "local", "construction loop does not use local distance attenuation")
	_assert(is_equal_approx(float(runtime_loop.get("unit_size_m", 0.0)), 12.0), "construction loop local reference distance changed")
	_assert(is_equal_approx(float(runtime_loop.get("max_distance_m", 0.0)), 112.0), "construction loop hearing range changed")
	_assert(is_equal_approx(float(entry.get("gain_db", 0.0)), 4.0), "construction request gain is not +4 dB")
	_assert(is_equal_approx(float(runtime_loop.get("target_gain_db", 0.0)), 4.0), "construction runtime gain is not +4 dB")


func _has_construction_loop(controller: Node, building_id: String) -> bool:
	return (controller.get_debug_snapshot().get("active_loops", {}) as Dictionary).has("construction_%s" % building_id)


func _assert_ui_semantic(controller: Node, semantic: String, asset_id: String) -> void:
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	for raw_entry in history:
		var entry: Dictionary = raw_entry
		if str(entry.get("semantic", "")) == semantic and str(entry.get("asset_id", "")) == asset_id:
			_assert(str(entry.get("player_type", "")) == "AudioStreamPlayer", "completion sound is not global 2D")
			_assert(str(entry.get("bus", "")) == "UI", "completion sound is not controlled by click volume")
			return
	_assert(false, "completion level-up semantic did not play")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("T0393 verification failed: %s" % message)
	quit(1)
