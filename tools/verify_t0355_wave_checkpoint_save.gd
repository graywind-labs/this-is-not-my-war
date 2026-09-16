extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const GameSaveStore = preload("res://scripts/systems/GameSaveStore.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GameSaveStore.set_storage_root_for_tests("user://t0355_verify_wave_checkpoint")
	root.size = Vector2i(1280, 720)
	set_meta("main_launch_request", {"source": "verify_t0355", "startup_mode": 0})
	root.add_child(MAIN_SCENE.instantiate())
	await process_frame
	await physics_frame
	var save_system := root.get_node_or_null("Main/Systems/GameSaveSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var buildings := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npcs := root.get_node_or_null("Main/Systems/NPCSystem")
	var needs := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var plans := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var memory := root.get_node_or_null("Main/Systems/MemorySystem")
	var piety := root.get_node_or_null("Main/Systems/PietySystem")
	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var crafting := root.get_node_or_null("Main/Systems/CraftingSystem")
	var horses := root.get_node_or_null("Main/Systems/HorseSystem")
	var defense := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	if [save_system, resources, buildings, npcs, needs, plans, memory, piety, combat, crafting, horses, defense].has(null):
		_fail("save dependencies unavailable")
		return

	var resource_snapshot: Dictionary = resources.create_game_save_snapshot()
	var amounts: Dictionary = resource_snapshot["amounts"]
	var resource_id := str(resources.get_resource_ids()[0])
	amounts[resource_id] = int(amounts[resource_id]) + 17
	resources.restore_game_save_snapshot({"amounts": amounts})
	var building_snapshot: Dictionary = buildings.create_game_save_snapshot()
	var building_id := "warehouse"
	var building_state: Dictionary = building_snapshot["buildings"][building_id]
	building_state["hp"] = maxi(1, int(building_state["max_hp"]) - 9)
	building_snapshot["buildings"][building_id] = building_state
	building_snapshot["active_repairs"] = {building_id: {
		"building_id": building_id, "duration_seconds": 600.0, "remaining_seconds": 420.0,
		"start_hp": int(building_state["hp"]), "target_hp": int(building_state["max_hp"]),
		"missing_hp": 9, "repair_batches": 1, "hp_restore": 9,
		"cost": {resource_id: 3}, "helpers": {"stableman_01": {"speed_bonus": 9.0}},
	}}
	buildings.restore_game_save_snapshot(building_snapshot)
	var crafting_snapshot: Dictionary = crafting.create_game_save_snapshot()
	var crafting_building := "blacksmith"
	var recipe_ids: Array[String] = crafting.get_recipe_ids_for_building(crafting_building)
	var output_item_id := str(crafting.get_recipe(recipe_ids[0]).get("output_item_id", ""))
	crafting_snapshot["pending_outputs"][crafting_building] = {output_item_id: 2}
	crafting_snapshot["latest_pending_output_item_ids"][crafting_building] = output_item_id
	crafting.restore_game_save_snapshot(crafting_snapshot)
	var birth_result: Dictionary = horses.debug_force_birth()
	if not bool(birth_result.get("ok", false)):
		_fail("could not establish pending foal transaction")
		return
	var pending_birth_id := str(birth_result.get("request_id", ""))
	npcs.update_npc_state("stableman_01", {"satiety": 41, "fatigue": 63})
	needs.restore_game_save_snapshot({"remainders_by_npc": {"stableman_01": {"satiety": 0.375, "fatigue": 0.625}}})
	plans.restore_game_save_snapshot({
		"plans_by_npc": {}, "plan_version_by_npc": {"stableman_01": 7},
		"one_shot_execution_keys_by_npc": {"stableman_01": {"1:6:eat_at_dining_hall": true}},
	})
	memory.add_event({
		"type": "resource_changed", "subject_npc_id": "stableman_01",
		"actor_ids": ["stableman_01"], "location_id": "plaza",
		"visibility": "private", "payload": {"resource_id": resource_id, "amount": 17},
	})
	piety.debug_set_piety(37.5)
	var expected_resource: int = int(resources.get_resource(resource_id))
	var expected_hp := int(buildings.get_building(building_id).get("hp", 0))
	var expected_event_count: int = int(memory.get_event_count())
	var expected_event_ids: Array[String] = []
	for event: Dictionary in memory.get_all_events():
		expected_event_ids.append(str(event.get("event_id", "")))
	var expected_repair_cost: int = int(buildings.get_repair_status(building_id).get("cost", {}).get(resource_id, 0))
	var archive_id := str(save_system.get_archive_id())
	var save_result: Dictionary = save_system.capture_automatic_checkpoint(1, "verification")
	if not bool(save_result.get("ok", false)):
		_fail("automatic checkpoint failed: %s" % JSON.stringify(save_result))
		return
	if DisplayServer.get_name() != "headless" and not bool(save_result.get("thumbnail_written", false)):
		_fail("rendered automatic checkpoint did not write a thumbnail")
		return
	var automatic := GameSaveStore.inspect_restore_point(archive_id, "auto")
	if not bool(automatic.get("loadable", false)):
		_fail("automatic checkpoint is not loadable: %s" % JSON.stringify(automatic))
		return
	var replay_fixture_result := _install_in_flight_breakfast_fixture(archive_id, automatic)
	if not bool(replay_fixture_result.get("ok", false)):
		_fail("could not install in-flight breakfast fixture: %s" % JSON.stringify(replay_fixture_result))
		return
	automatic = GameSaveStore.inspect_restore_point(archive_id, "auto")
	var source_thumbnail := GameSaveStore.read_thumbnail_bytes(archive_id, "auto")
	var decoded_thumbnail := Image.new()
	if (
		not bool(automatic.get("has_thumbnail", false))
		or source_thumbnail.is_empty()
		or decoded_thumbnail.load_webp_from_buffer(source_thumbnail) != OK
		or decoded_thumbnail.get_size() != Vector2i(480, 270)
	):
		_fail("automatic thumbnail fixture is invalid")
		return
	if not _verify_rejected_restore_points():
		return
	var pin_result: Dictionary = save_system.pin_latest_checkpoint("slot_01", "验证固定点")
	if not bool(pin_result.get("ok", false)):
		_fail("manual pin failed: %s" % JSON.stringify(pin_result))
		return
	archive_id = str(pin_result.get("archive_id", archive_id))
	var manual_before := GameSaveStore.inspect_restore_point(archive_id, "manual")
	if (
		not bool(manual_before.get("has_thumbnail", false))
		or GameSaveStore.read_thumbnail_bytes(archive_id, "manual") != source_thumbnail
		or GameSaveStore.read_thumbnail_bytes(archive_id, "auto") != source_thumbnail
	):
		_fail("automatic/manual thumbnail copy failed")
		return
	var save_browser := root.get_node("Main").find_child("SaveBrowserPanel", true, false)
	if save_browser == null:
		_fail("save browser unavailable for thumbnail verification")
		return
	save_browser.open_panel(0, false)
	save_browser.debug_select_slot("slot_01")
	await process_frame
	var preview_texture := save_browser.find_child("SaveThumbnail", true, false) as TextureRect
	var point_selector := save_browser.find_child("RestorePointSelector", true, false) as OptionButton
	if preview_texture == null or preview_texture.texture == null or not preview_texture.visible:
		_fail("save browser did not display automatic thumbnail")
		return
	point_selector.select(1)
	point_selector.item_selected.emit(1)
	await process_frame
	if preview_texture.texture == null or not preview_texture.visible:
		_fail("save browser did not display manual thumbnail")
		return
	save_browser.close_panel()
	var manual_hash := str(manual_before.get("state_sha256", ""))
	resources.add_resource(resource_id, 1)
	var overwrite_auto: Dictionary = save_system.capture_automatic_checkpoint(2, "verification_second")
	var automatic_after := GameSaveStore.inspect_restore_point(archive_id, "auto")
	var manual_after := GameSaveStore.inspect_restore_point(archive_id, "manual")
	if (
		not bool(overwrite_auto.get("ok", false))
		or str(automatic_after.get("state_sha256", "")) == manual_hash
		or str(manual_after.get("state_sha256", "")) != manual_hash
		or GameSaveStore.read_thumbnail_bytes(archive_id, "manual") != source_thumbnail
		or (DisplayServer.get_name() == "headless" and bool(automatic_after.get("has_thumbnail", true)))
		or (DisplayServer.get_name() != "headless" and not bool(automatic_after.get("has_thumbnail", false)))
	):
		_fail("auto/manual isolation failed")
		return
	var manual_thumbnail_path := GameSaveStore.get_point_dir(archive_id, "manual") + "/thumbnail.webp"
	var damaged_thumbnail := FileAccess.open(manual_thumbnail_path, FileAccess.WRITE)
	if damaged_thumbnail == null:
		_fail("could not create damaged thumbnail fixture")
		return
	damaged_thumbnail.store_string("not-a-webp")
	damaged_thumbnail.close()
	if not bool(GameSaveStore.inspect_restore_point(archive_id, "manual").get("loadable", false)):
		_fail("damaged thumbnail incorrectly blocked state loading")
		return
	save_browser.open_panel(0, false)
	save_browser.debug_select_slot("slot_01")
	point_selector.select(1)
	point_selector.item_selected.emit(1)
	await process_frame
	var preview_label := save_browser.find_child("SaveThumbnailPlaceholder", true, false) as Label
	if preview_texture.texture != null or preview_texture.visible or preview_label == null or not preview_label.visible:
		_fail("damaged thumbnail did not fall back to placeholder")
		return
	save_browser.close_panel()
	var original_archive_id := archive_id
	var original_auto_hash := str(automatic_after.get("state_sha256", ""))
	var branch_result: Dictionary = save_system.pin_latest_checkpoint("slot_02", "验证分支档")
	var branch_archive_id := str(branch_result.get("archive_id", ""))
	if not bool(branch_result.get("ok", false)) or branch_archive_id.is_empty() or branch_archive_id == original_archive_id:
		_fail("save-as did not create an isolated archive id")
		return
	resources.add_resource(resource_id, 1)
	var branch_auto_result: Dictionary = save_system.capture_automatic_checkpoint(3, "verification_branch")
	if (
		not bool(branch_auto_result.get("ok", false))
		or str(GameSaveStore.inspect_restore_point(original_archive_id, "auto").get("state_sha256", "")) != original_auto_hash
	):
		_fail("branch autosave crossed archive ids")
		return
	var birth_dialog := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/HorseBirthNamingDialog") as Window
	if birth_dialog != null:
		birth_dialog.hide()
	root.get_node("EventBus").combat_wave_cleared.emit(4)
	await process_frame
	await process_frame
	if int(GameSaveStore.inspect_restore_point(branch_archive_id, "auto").get("checkpoint_wave", 0)) != 4:
		_fail("combat_wave_cleared did not commit the deferred automatic checkpoint")
		return
	archive_id = original_archive_id

	var old_main := root.get_node("Main")
	old_main.queue_free()
	await process_frame
	await process_frame
	set_meta("main_launch_request", {"source": "verify", "startup_mode": 3, "archive_id": archive_id, "restore_point": "manual"})
	root.add_child(MAIN_SCENE.instantiate())
	for _index in range(4):
		await process_frame
	await physics_frame
	save_system = root.get_node_or_null("Main/Systems/GameSaveSystem")
	var startup := root.get_node_or_null("Main/Systems/GameStartupSystem")
	var startup_snapshot: Dictionary = startup.get_startup_snapshot() if startup != null else {}
	var restore_result: Dictionary = startup_snapshot.get("restore_result", {}) if startup_snapshot.get("restore_result", {}) is Dictionary else {}
	if not bool(restore_result.get("ok", false)):
		_fail("LOAD startup restore failed: %s" % JSON.stringify(startup_snapshot))
		return
	resources = root.get_node("Main/Systems/ResourceSystem")
	buildings = root.get_node("Main/Systems/BuildingSystem")
	npcs = root.get_node("Main/Systems/NPCSystem")
	needs = root.get_node("Main/Systems/NPCNeedsSystem")
	memory = root.get_node("Main/Systems/MemorySystem")
	piety = root.get_node("Main/Systems/PietySystem")
	combat = root.get_node("Main/Systems/CombatSystem")
	crafting = root.get_node("Main/Systems/CraftingSystem")
	horses = root.get_node("Main/Systems/HorseSystem")
	var plan_replay: Dictionary = restore_result.get("plan_replay", {}) if restore_result.get("plan_replay", {}) is Dictionary else {}
	var execute_results: Dictionary = restore_result.get("execute_results", {}) if restore_result.get("execute_results", {}) is Dictionary else {}
	var stableman_execution: Dictionary = execute_results.get("stableman_01", {}) if execute_results.get("stableman_01", {}) is Dictionary else {}
	var cook_execution: Dictionary = execute_results.get("cook_01", {}) if execute_results.get("cook_01", {}) is Dictionary else {}
	var restored_event_ids: Array[String] = []
	for event: Dictionary in memory.get_all_events():
		restored_event_ids.append(str(event.get("event_id", "")))
	if (
		resources.get_resource(resource_id) != expected_resource
		or int(buildings.get_building(building_id).get("hp", 0)) < expected_hp
		or int(npcs.get_npc_state("stableman_01").get("satiety", 0)) != 41
		or int(npcs.get_npc_state("stableman_01").get("fatigue", 0)) != 63
		or absf(float(needs.get_npc_needs_snapshot("stableman_01").get("remainders", {}).get("satiety", 0.0)) - 0.375) > 0.01
		or memory.get_event_count() < expected_event_count
		or restored_event_ids.slice(0, expected_event_count) != expected_event_ids
		or absf(piety.get_current_piety() - 37.5) > 0.001
		or combat.get_active_enemy_count() != 0
		or int(buildings.get_repair_status(building_id).get("cost", {}).get(resource_id, 0)) != expected_repair_cost
		or int(crafting.get_pending_outputs(crafting_building).get(output_item_id, 0)) != 2
		or str(horses.get_pending_birth_snapshot().get("request_id", "")) != pending_birth_id
		or not (plan_replay.get("replayed_npc_ids", []) as Array).has("stableman_01")
		or not bool(stableman_execution.get("ok", false))
		or str(npcs.get_npc_state("stableman_01").get("current_action", "idle")) == "idle"
		or (plan_replay.get("replayed_npc_ids", []) as Array).has("cook_01")
		or str(cook_execution.get("status", "")) != "already_executed_once_per_plan_hour"
		or str(npcs.get_npc_state("cook_01").get("current_action", "idle")) != "idle"
	):
		_fail("restored authority mismatch: %s" % JSON.stringify({
			"resource": [resources.get_resource(resource_id), expected_resource],
			"building_hp": [buildings.get_building(building_id).get("hp", 0), expected_hp],
			"npc_state": npcs.get_npc_state("stableman_01"),
			"needs": needs.get_npc_needs_snapshot("stableman_01"),
			"events": [memory.get_event_count(), expected_event_count],
			"piety": piety.get_current_piety(), "enemies": combat.get_active_enemy_count(),
			"plan_replay": plan_replay,
			"stableman_execution": stableman_execution,
			"cook_execution": cook_execution,
			"cook_action": npcs.get_npc_state("cook_01").get("current_action", ""),
		}))
		return
	print("T0355_WAVE_CHECKPOINT_SAVE_PASS")
	root.get_node("Main").queue_free()
	await process_frame
	await process_frame
	quit(0)


func _install_in_flight_breakfast_fixture(archive_id: String, inspection: Dictionary) -> Dictionary:
	var state: Dictionary = inspection.get("state", {}).duplicate(true) if inspection.get("state", {}) is Dictionary else {}
	var plans: Array = []
	for hour in range(24):
		plans.append({"hour": hour, "action_id": "eat_at_dining_hall" if hour == 6 else "idle", "target": {}})
	var plan_item: Dictionary = plans[6]
	var execution_key := "1:6:%s" % JSON.stringify(["eat_at_dining_hall", "", ""])
	state["daily_plans"] = {
		"plans_by_npc": {"stableman_01": plans, "cook_01": plans.duplicate(true)},
		"plan_version_by_npc": {"stableman_01": 1, "cook_01": 1},
		"one_shot_execution_keys_by_npc": {
			"stableman_01": {execution_key: true},
			"cook_01": {execution_key: true},
		},
	}
	var spatial: Dictionary = state.get("spatial", {}) if state.get("spatial", {}) is Dictionary else {}
	var npc_spatial: Dictionary = spatial.get("npc", {}) if spatial.get("npc", {}) is Dictionary else {}
	var actors: Array = npc_spatial.get("actors", []) if npc_spatial.get("actors", []) is Array else []
	var fixture_installed := false
	for index in range(actors.size()):
		if not actors[index] is Dictionary or str((actors[index] as Dictionary).get("npc_id", "")) != "stableman_01":
			continue
		var actor: Dictionary = (actors[index] as Dictionary).duplicate(true)
		actor["in_flight_action"] = {
			"active": true,
			"action_id": str(plan_item.get("action_id", "")),
			"building_id": "dining_hall",
			"workstation_id": "",
			"restore_policy": "rollback",
		}
		actors[index] = actor
		fixture_installed = true
		break
	if not fixture_installed:
		return {"ok": false, "reason": "stableman_spatial_actor_missing"}
	npc_spatial["actors"] = actors
	spatial["npc"] = npc_spatial
	state["spatial"] = spatial
	var thumbnail := Image.create(480, 270, false, Image.FORMAT_RGB8)
	thumbnail.fill(Color(0.24, 0.42, 0.18, 1.0))
	var thumbnail_bytes := thumbnail.save_webp_to_buffer(true, 0.82)
	return GameSaveStore.write_checkpoint(archive_id, "auto", state, {
		"display_name": inspection.get("display_name", "正式开局"),
		"checkpoint_wave": inspection.get("checkpoint_wave", 0),
		"day": inspection.get("day", 1),
		"game_time": inspection.get("game_time", "06:00:00"),
		"checkpoint_reason": inspection.get("checkpoint_reason", "verification"),
		"game_version": inspection.get("game_version", "test"),
	}, thumbnail_bytes)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _verify_rejected_restore_points() -> bool:
	var corrupt_id := GameSaveStore.create_archive_id()
	var corrupt_write: Dictionary = GameSaveStore.write_checkpoint(corrupt_id, "auto", {"fixture": true}, {"display_name": "损坏档"})
	if not bool(corrupt_write.get("ok", false)):
		_fail("could not create corruption fixture")
		return false
	var corrupt_state_path := GameSaveStore.get_point_dir(corrupt_id, "auto") + "/state.json"
	var corrupt_file := FileAccess.open(corrupt_state_path, FileAccess.WRITE)
	if corrupt_file == null:
		_fail("could not open corruption fixture")
		return false
	corrupt_file.store_string("{broken")
	corrupt_file.close()
	var corrupt_inspection: Dictionary = GameSaveStore.inspect_restore_point(corrupt_id, "auto")
	if bool(corrupt_inspection.get("loadable", false)) or str(corrupt_inspection.get("reason", "")) != "state_checksum_mismatch":
		_fail("corrupted checkpoint was not rejected: %s" % JSON.stringify(corrupt_inspection))
		return false

	var newer_id := GameSaveStore.create_archive_id()
	var newer_write: Dictionary = GameSaveStore.write_checkpoint(newer_id, "auto", {"fixture": true}, {"display_name": "高版本档"})
	if not bool(newer_write.get("ok", false)):
		_fail("could not create newer-version fixture")
		return false
	var meta_path := GameSaveStore.get_point_dir(newer_id, "auto") + "/meta.json"
	var meta_file := FileAccess.open(meta_path, FileAccess.READ)
	var parsed_meta: Variant = JSON.parse_string(meta_file.get_as_text()) if meta_file != null else null
	if meta_file != null:
		meta_file.close()
	if not parsed_meta is Dictionary:
		_fail("could not read newer-version fixture")
		return false
	(parsed_meta as Dictionary)["save_version"] = GameSaveStore.SAVE_VERSION + 1
	meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
	if meta_file == null:
		_fail("could not update newer-version fixture")
		return false
	meta_file.store_string(JSON.stringify(parsed_meta, "\t"))
	meta_file.close()
	var newer_inspection: Dictionary = GameSaveStore.inspect_restore_point(newer_id, "auto")
	if bool(newer_inspection.get("loadable", false)) or str(newer_inspection.get("reason", "")) != "save_version_too_new":
		_fail("newer checkpoint was not rejected: %s" % JSON.stringify(newer_inspection))
		return false
	return true
