extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn")
	if main_scene == null:
		push_error("Main scene failed to load.")
		quit(1)
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if building_system == null or resource_system == null or memory_system == null or llm_bridge == null or time_system == null or panel == null:
		push_error("Required systems or building panel are missing.")
		quit(1)
		return

	var building_id := "wall"
	var original: Dictionary = building_system.get_building(building_id)
	var original_stone: int = resource_system.get_resource("stone")
	if original.is_empty() or original_stone < 8:
		push_error("Verify precondition failed.")
		quit(1)
		return
	for raw_building_id in building_system.get_building_ids():
		var current_id := str(raw_building_id)
		var current_building: Dictionary = building_system.get_building(current_id)
		if current_building.get("repair", {}).is_empty():
			push_error("Every building should be repairable, missing: %s" % current_id)
			quit(1)
			return
		if current_building.get("upgrade", {}).is_empty():
			push_error("Every building should have upgrade potential, missing: %s" % current_id)
			quit(1)
			return

	if not building_system.debug_damage_building(building_id, 40):
		push_error("Failed to damage building.")
		quit(1)
		return

	panel.show_building(building_id)
	panel.debug_set_layout_viewport_override(Vector2(1152.0, 648.0))
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not _panel_matches_content_height(panel):
		push_error("Building panel should initially match its visible content height.")
		quit(1)
		return
	# Switching/closing during an unfinished transparent measurement must not
	# leave the fit queue stuck or let an obsolete coroutine reveal old content.
	panel.show_building("stable")
	panel._on_close_pressed()
	panel.show_building(building_id)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not panel.visible or panel.modulate.a < 0.99 or not _panel_matches_content_height(panel):
		push_error("Interrupted panel measurement should recover on the next building selection.")
		quit(1)
		return
	var location_label := panel.find_child("BuildingLocationLabel", true, false) as Label
	if location_label == null:
		push_error("Building location label is missing.")
		quit(1)
		return
	if location_label.text.contains("消耗"):
		push_error("Building panel should not show repair or upgrade costs inline.")
		quit(1)
		return
	var repair_hint := str(panel._format_repair_hint())
	if not repair_hint.contains("消耗："):
		push_error("Repair cost hint should be available from the repair button hover content.")
		quit(1)
		return
	var edge_anchor := Button.new()
	edge_anchor.text = "边缘按钮"
	edge_anchor.custom_minimum_size = Vector2(80, 30)
	panel.add_child(edge_anchor)
	await process_frame
	var viewport_size := root.get_viewport().get_visible_rect().size
	edge_anchor.global_position = Vector2(viewport_size.x - edge_anchor.size.x - 2.0, 48.0)
	var panel_height_before_hint: float = panel.size.y
	panel._show_action_hint(edge_anchor, "升级\n消耗：石料 x3\n条件：可执行")
	await process_frame
	var hint_panel: Control = panel._action_hint_panel
	if hint_panel.get_parent() != panel.get_parent():
		push_error("Building action hint should live on the UI overlay, outside BuildingPanel content sizing.")
		quit(1)
		return
	if absf(panel.size.y - panel_height_before_hint) > 1.0:
		push_error("Building action hint should not change panel height or create a flashing dark block.")
		quit(1)
		return
	if hint_panel.global_position.x + hint_panel.size.x > viewport_size.x:
		push_error("Building action hint should stay inside the viewport near screen edges.")
		quit(1)
		return
	panel._hide_action_hint()
	edge_anchor.queue_free()
	if not building_system.can_repair_building(building_id):
		push_error("Damaged building should be repairable.")
		quit(1)
		return
	if building_system.can_upgrade_building(building_id):
		push_error("Damaged building should not be upgradeable.")
		quit(1)
		return

	if not building_system.repair_building(building_id):
		push_error("Repair did not start.")
		quit(1)
		return
	if panel.size.y >= 615.0:
		push_error("Repair start should not flash a viewport-height empty panel.")
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not _panel_matches_content_height(panel):
		push_error("Repair panel should settle to its visible content height.")
		quit(1)
		return
	if building_system.can_upgrade_building(building_id):
		push_error("Building under repair should not be upgradeable.")
		quit(1)
		return

	var started: Dictionary = building_system.get_building(building_id)
	if int(started.get("hp", 0)) != int(original.get("hp", 0)) - 40:
		push_error("Repair should not restore HP immediately.")
		quit(1)
		return
	if not building_system.is_repair_in_progress(building_id):
		push_error("Repair status was not created.")
		quit(1)
		return
	if resource_system.get_resource("stone") != original_stone - 1:
		push_error("Repair did not spend stone up front.")
		quit(1)
		return
	var repair_status: Dictionary = started.get("repair_status", {})
	if (
		not str(repair_status.get("duration_text", "")).contains("小时")
		or not str(repair_status.get("duration_text", "")).contains("分")
		or not str(repair_status.get("duration_text", "")).contains("秒")
		or not str(repair_status.get("remaining_text", "")).ends_with("00秒")
	):
		push_error("Repair status should expose readable total and stable remaining duration: %s" % repair_status)
		quit(1)
		return
	var plaza_snapshot: Dictionary = memory_system.get_location_snapshot("plaza")
	var external_states: Dictionary = plaza_snapshot.get("building_external_states", {})
	var wall_external: Dictionary = external_states.get(building_id, {})
	if (
		str(wall_external.get("active_job", "")) != "repair"
		or str(wall_external.get("job_total_duration_text", "")) != str(repair_status.get("duration_text", ""))
	):
		push_error("Repair start propagation should include readable total duration: %s" % wall_external)
		quit(1)
		return
	var repair_sentence := str(memory_system._format_external_state_sentence(
		str(started.get("name", building_id)),
		wall_external
	))
	if not repair_sentence.contains("本次修复预计需要"):
		push_error("NPC-readable repair information should explain total duration: %s" % repair_sentence)
		quit(1)
		return
	var propagated_repair_event_found := false
	for event in memory_system.get_plaza_events():
		var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
		if (
			str(payload.get("building_id", "")) == building_id
			and str(event.get("summary", "")).contains("本次修复预计需要")
			and str(event.get("summary", "")).contains(str(repair_status.get("duration_text", "")))
		):
			propagated_repair_event_found = true
	if not propagated_repair_event_found:
		push_error("Repair start should emit a propagated NPC-readable duration event")
		quit(1)
		return
	var building_context: Dictionary = llm_bridge._build_building_state_context()
	var wall_context: Dictionary = building_context.get(building_id, {})
	var repair_job_context: Dictionary = wall_context.get("repair_job", {})
	if (
		str(repair_job_context.get("total_duration", "")).is_empty()
		or repair_job_context.has("duration_seconds")
		or repair_job_context.has("remaining_seconds")
	):
		push_error("LLM building context should carry readable repair time without naked seconds: %s" % repair_job_context)
		quit(1)
		return
	var location_label_during_repair := panel.find_child("BuildingLocationLabel", true, false) as Label
	var repair_button := panel.find_child("RepairButton", true, false) as Button
	if (
		location_label_during_repair == null
		or repair_button == null
		or not location_label_during_repair.text.contains("剩余 0小时")
		or not location_label_during_repair.text.contains("00秒")
		or not repair_button.text.contains("小时")
	):
		push_error("Building panel should show readable repair remaining time.")
		quit(1)
		return
	building_system._on_logical_time_tick(1.5, 1.0)
	time_system.request_time_slowdown("verify_building_duration", -1.0, "llm_wait")
	await process_frame
	var precise_repair: Dictionary = building_system.get_repair_status(building_id)
	if str(precise_repair.get("remaining_text", "")).ends_with("00秒"):
		push_error("Building remaining time should reveal precise seconds during LLM slowdown: %s" % precise_repair)
		quit(1)
		return
	time_system.release_time_slowdown("verify_building_duration")
	await process_frame
	var stable_repair: Dictionary = building_system.get_repair_status(building_id)
	if not str(stable_repair.get("remaining_text", "")).ends_with("00秒"):
		push_error("Building remaining time should return to stable minutes after LLM slowdown: %s" % stable_repair)
		quit(1)
		return

	building_system._on_logical_time_tick(600.0, 1.0)
	var halfway: Dictionary = building_system.get_building(building_id)
	if int(halfway.get("hp", 0)) <= int(started.get("hp", 0)):
		push_error("Repair progress did not restore HP over time.")
		quit(1)
		return
	if not building_system.is_repair_in_progress(building_id):
		push_error("Repair finished too early.")
		quit(1)
		return

	building_system._on_logical_time_tick(600.0, 1.0)
	var repaired: Dictionary = building_system.get_building(building_id)
	if int(repaired.get("hp", 0)) != int(repaired.get("max_hp", 0)):
		push_error("Repair did not finish at max HP.")
		quit(1)
		return
	if building_system.is_repair_in_progress(building_id):
		push_error("Repair status did not clear after completion.")
		quit(1)
		return

	var before_upgrade_stone: int = resource_system.get_resource("stone")
	var before_upgrade_workstations: Array = repaired.get("workstations", [])
	if not before_upgrade_workstations.is_empty():
		push_error("Non-enterable wall should not expose internal workstations.")
		quit(1)
		return
	if not building_system.upgrade_building(building_id):
		push_error("Upgrade did not start.")
		quit(1)
		return
	if panel.size.y >= 615.0:
		push_error("Upgrade start should not flash a viewport-height empty panel.")
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not _panel_matches_content_height(panel):
		push_error("Upgrade panel should settle to its visible content height.")
		quit(1)
		return

	var upgrade_started: Dictionary = building_system.get_building(building_id)
	if int(upgrade_started.get("level", 0)) != int(repaired.get("level", 0)):
		push_error("Upgrade should not increase level immediately.")
		quit(1)
		return
	if not building_system.is_upgrade_in_progress(building_id):
		push_error("Upgrade status was not created.")
		quit(1)
		return
	if str(upgrade_started.get("condition", "")) != "upgrading":
		push_error("Building condition should be upgrading during upgrade countdown.")
		quit(1)
		return
	if resource_system.get_resource("stone") != before_upgrade_stone - 3:
		push_error("Upgrade did not spend stone up front.")
		quit(1)
		return
	if building_system.can_repair_building(building_id):
		push_error("Building under upgrade should not be repairable.")
		quit(1)
		return
	var upgrade_status: Dictionary = upgrade_started.get("upgrade_status", {})
	var upgraded_plaza_snapshot: Dictionary = memory_system.get_location_snapshot("plaza")
	var upgraded_external_states: Dictionary = upgraded_plaza_snapshot.get("building_external_states", {})
	var upgrade_external: Dictionary = upgraded_external_states.get(building_id, {})
	var upgrade_context: Dictionary = llm_bridge._build_building_state_context().get(building_id, {})
	if (
		str(upgrade_status.get("duration_text", "")).is_empty()
		or str(upgrade_external.get("active_job", "")) != "upgrade"
		or str(upgrade_external.get("job_total_duration_text", "")) != str(upgrade_status.get("duration_text", ""))
		or str(upgrade_context.get("upgrade_job", {}).get("total_duration", "")).is_empty()
	):
		push_error("Upgrade start should propagate readable total duration to NPC context.")
		quit(1)
		return

	building_system._on_logical_time_tick(1800.0, 1.0)
	var upgrade_halfway: Dictionary = building_system.get_building(building_id)
	if int(upgrade_halfway.get("level", 0)) != int(repaired.get("level", 0)) or not building_system.is_upgrade_in_progress(building_id):
		push_error("Upgrade should still be in progress halfway.")
		quit(1)
		return

	building_system._on_logical_time_tick(1800.0, 1.0)
	var upgraded: Dictionary = building_system.get_building(building_id)
	var upgraded_workstations: Array = upgraded.get("workstations", [])
	if int(upgraded.get("level", 0)) != int(repaired.get("level", 0)) + 1:
		push_error("Upgrade completion did not increase level.")
		quit(1)
		return
	if int(upgraded.get("max_hp", 0)) <= int(repaired.get("max_hp", 0)):
		push_error("Upgrade did not increase max HP.")
		quit(1)
		return
	if upgraded_workstations.size() != before_upgrade_workstations.size():
		push_error("Non-enterable wall upgrade should not add internal workstations.")
		quit(1)
		return
	if building_system.is_upgrade_in_progress(building_id):
		push_error("Upgrade status did not clear after completion.")
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not _panel_matches_content_height(panel):
		push_error("Upgrade completion should shrink the panel back to current content.")
		quit(1)
		return

	if int(upgraded.get("upgrade", {}).get("max_level", 0)) != 6:
		push_error("Wall upgrade cap should be Lv.6.")
		quit(1)
		return
	resource_system.add_resources({"stone": 100, "wood": 30})
	for target_level in range(3, 7):
		var level_effect: Dictionary = building_system.get_upgrade_level_effect(building_id, target_level)
		var level_cost: Dictionary = level_effect.get("cost", {})
		var resources_before := {}
		for raw_resource_id in level_cost.keys():
			var resource_id := str(raw_resource_id)
			resources_before[resource_id] = resource_system.get_resource(resource_id)
		var max_hp_before := int(building_system.get_building(building_id).get("max_hp", 0))
		if not building_system.upgrade_building(building_id):
			push_error("Wall should support upgrade to Lv.%d." % target_level)
			quit(1)
			return
		for raw_resource_id in level_cost.keys():
			var resource_id := str(raw_resource_id)
			if resource_system.get_resource(resource_id) != int(resources_before.get(resource_id, 0)) - int(level_cost.get(resource_id, 0)):
				push_error("Wall Lv.%d upgrade did not spend configured %s cost." % [
					target_level,
					resource_id
				])
				quit(1)
				return
		var level_status: Dictionary = building_system.get_upgrade_status(building_id)
		if not is_equal_approx(
			float(level_status.get("duration_seconds", 0.0)),
			float(level_effect.get("duration_seconds", 0.0))
		):
			push_error("Wall Lv.%d upgrade duration did not use its level effect." % target_level)
			quit(1)
			return
		building_system._on_logical_time_tick(
			float(level_status.get("remaining_seconds", 0.0)) + 1.0,
			1.0
		)
		var level_building: Dictionary = building_system.get_building(building_id)
		if (
			int(level_building.get("level", 0)) != target_level
			or building_system.is_upgrade_in_progress(building_id)
		):
			push_error("Wall upgrade should complete at Lv.%d." % target_level)
			quit(1)
			return
		if int(level_building.get("max_hp", 0)) != max_hp_before + int(level_effect.get("max_hp_bonus", 0)):
			push_error("Wall Lv.%d did not apply configured Max HP benefit." % target_level)
			quit(1)
			return

	var maximized: Dictionary = building_system.get_building(building_id)
	if int(maximized.get("level", 0)) != 6:
		push_error("Wall should reach Lv.6.")
		quit(1)
		return
	if building_system.can_upgrade_building(building_id):
		push_error("Lv.6 wall should be at its configured upgrade cap.")
		quit(1)
		return

	var stone_before_failed_upgrade: int = resource_system.get_resource("stone")
	if building_system.upgrade_building(building_id):
		push_error("Upgrade should fail when the wall is already Lv.6.")
		quit(1)
		return
	if resource_system.get_resource("stone") != stone_before_failed_upgrade:
		push_error("Failed max-level upgrade changed stone.")
		quit(1)
		return

	print("T0205 repair and upgrade verification passed.")
	quit(0)


func _panel_matches_content_height(panel: Control) -> bool:
	var location_label := panel.find_child("BuildingLocationLabel", true, false) as Label
	if location_label == null:
		return false
	var content := location_label.get_parent() as VBoxContainer
	if content == null:
		return false
	var available_height := 648.0 - 32.0
	var expected_height := minf(available_height, content.get_combined_minimum_size().y + 24.0)
	return absf(panel.size.y - expected_height) <= 2.0
