extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var game_state := root.get_node_or_null("/root/GameState")
	if combat_system == null or time_system == null or hud == null or game_state == null:
		push_error("Five-wave victory verification required nodes not found")
		quit(1)
		return

	if int(combat_system.get_wave_count()) < 5:
		push_error("Victory verification requires at least 5 configured waves")
		quit(1)
		return

	for _index in range(5):
		var trigger_result: Dictionary = combat_system.trigger_next_scheduled_wave("verify_five_wave_victory", false)
		if not bool(trigger_result.get("ok", false)):
			push_error("Failed to trigger next wave: %s" % JSON.stringify(trigger_result))
			quit(1)
			return

	var before_clear_schedule: Dictionary = combat_system.get_wave_schedule_snapshot()
	if not bool(before_clear_schedule.get("all_waves_triggered", false)):
		push_error("All five waves should be marked triggered before victory: %s" % JSON.stringify(before_clear_schedule))
		quit(1)
		return
	if int(before_clear_schedule.get("active_enemy_count", 0)) <= 0:
		push_error("Victory verification should have active enemies before clearing")
		quit(1)
		return

	time_system.set_current_time(7, 21, 15, 0)
	await process_frame

	var clear_result: Dictionary = combat_system.debug_clear_enemies()
	if not bool(clear_result.get("ok", false)):
		push_error("Clearing final wave enemies failed: %s" % JSON.stringify(clear_result))
		quit(1)
		return
	await process_frame

	if not bool(game_state.get("game_over")):
		push_error("Clearing wave 5 should set GameState.game_over: %s" % JSON.stringify(clear_result))
		quit(1)
		return
	if str(game_state.get("game_result")) != "victory":
		push_error("Game result should be victory, got: %s" % str(game_state.get("game_result")))
		quit(1)
		return
	if str(game_state.get("game_over_reason")) != "five_waves_survived":
		push_error("Victory reason should be five_waves_survived, got: %s" % str(game_state.get("game_over_reason")))
		quit(1)
		return
	if not str(game_state.get("failure_reason")).is_empty():
		push_error("Victory should not leave a failure_reason")
		quit(1)
		return
	if int(game_state.get("game_over_day")) != 7 or int(game_state.get("game_over_hour")) != 21:
		push_error("Victory timestamp should use current game time")
		quit(1)
		return

	var settlement: Dictionary = game_state.get("settlement_snapshot") if game_state.get("settlement_snapshot") is Dictionary else {}
	if settlement.is_empty():
		push_error("Victory should record a settlement snapshot")
		quit(1)
		return
	if not _has_snapshot_section(settlement, "resources", "items"):
		push_error("Victory settlement snapshot missing resources.items")
		quit(1)
		return
	if not _has_snapshot_section(settlement, "buildings", "items"):
		push_error("Victory settlement snapshot missing buildings.items")
		quit(1)
		return
	if not _has_snapshot_section(settlement, "npcs", "items"):
		push_error("Victory settlement snapshot missing npcs.items")
		quit(1)
		return
	var npc_section: Dictionary = settlement.get("npcs", {}) if settlement.get("npcs", {}) is Dictionary else {}
	var npc_items: Array = npc_section.get("items", []) if npc_section.get("items", []) is Array else []
	if npc_items.size() < 8:
		push_error("Victory NPC snapshot should include the initial NPC roster")
		quit(1)
		return
	for raw_npc in npc_items:
		var npc_entry: Dictionary = raw_npc if raw_npc is Dictionary else {}
		var final_status := str(npc_entry.get("final_status_label", ""))
		if not ["可行动", "昏迷", "逃离"].has(final_status):
			push_error("NPC ending should use allowed final status labels, got: %s" % JSON.stringify(npc_entry))
			quit(1)
			return
		if str(npc_entry.get("final_opinion", "")).is_empty() or str(npc_entry.get("fate_summary", "")).is_empty():
			push_error("NPC ending should include mock final opinion and fate summary: %s" % JSON.stringify(npc_entry))
			quit(1)
			return
		var forbidden_text := "%s %s" % [str(npc_entry.get("final_opinion", "")), str(npc_entry.get("fate_summary", ""))]
		if forbidden_text.contains("阵亡") or forbidden_text.contains("死亡"):
			push_error("NPC ending summary must not use death wording: %s" % forbidden_text)
			quit(1)
			return
	var building_section: Dictionary = settlement.get("buildings", {}) if settlement.get("buildings", {}) is Dictionary else {}
	if not bool(building_section.get("station_operational", false)):
		push_error("Victory snapshot should record the station as operational when main hall survives")
		quit(1)
		return

	if not bool(time_system.is_gameplay_paused()):
		push_error("TimeSystem should pause gameplay after victory")
		quit(1)
		return
	var before_time := _state_time(game_state)
	time_system._process(10.0)
	if _state_time(game_state) != before_time:
		push_error("Game time should not advance after victory")
		quit(1)
		return

	var spawn_after_result: Dictionary = combat_system.debug_spawn_wave(1, false)
	if bool(spawn_after_result.get("ok", false)) or str(spawn_after_result.get("error", "")) != "game_over":
		push_error("CombatSystem should reject new wave spawning after victory: %s" % JSON.stringify(spawn_after_result))
		quit(1)
		return
	if int(combat_system.get_active_enemy_count()) != 0:
		push_error("No enemies should remain or spawn after victory")
		quit(1)
		return

	var combat_snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	var victory_result: Dictionary = combat_snapshot.get("last_victory_result", {}) if combat_snapshot.get("last_victory_result", {}) is Dictionary else {}
	if str(victory_result.get("reason", "")) != "five_waves_survived":
		push_error("Combat snapshot should expose five-wave victory: %s" % JSON.stringify(victory_result))
		quit(1)
		return

	var game_over_panel := hud.get_node_or_null("GameOverPanel") as PanelContainer
	if game_over_panel == null or not game_over_panel.visible:
		push_error("HUD should display a victory placeholder panel")
		quit(1)
		return
	var title_label := game_over_panel.find_child("GameOverTitleLabel", true, false) as Label
	var wave_label := game_over_panel.find_child("GameOverWaveLabel", true, false) as Label
	if title_label == null or title_label.text != "胜 利":
		push_error("Victory panel should show a success title")
		quit(1)
		return
	if wave_label == null or wave_label.text != "守住 5 波敌人":
		push_error("Victory panel should show the five-wave subtitle")
		quit(1)
		return
	if game_over_panel.find_children("NPCEndingCard_*", "PanelContainer", true, false).size() != 8:
		push_error("Victory panel should show eight portrait-and-story cards")
		quit(1)
		return
	if game_over_panel.find_child("GameOverReasonLabel", true, false) != null or game_over_panel.find_child("GameOverDetailLabel", true, false) != null:
		push_error("Victory panel should not show legacy reason or aggregate detail fields")
		quit(1)
		return

	print("Five-wave victory verification passed.")
	quit(0)


func _has_snapshot_section(snapshot: Dictionary, section_name: String, list_name: String) -> bool:
	var section: Dictionary = snapshot.get(section_name, {}) if snapshot.get(section_name, {}) is Dictionary else {}
	var items: Array = section.get(list_name, []) if section.get(list_name, []) is Array else []
	return not items.is_empty()


func _state_time(game_state: Node) -> String:
	return "%d-%02d:%02d:%02d" % [
		int(game_state.get("current_day")),
		int(game_state.get("current_hour")),
		int(game_state.get("current_minute")),
		int(game_state.get("current_second"))
	]
