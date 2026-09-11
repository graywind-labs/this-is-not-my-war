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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var game_state := root.get_node_or_null("/root/GameState")
	if combat_system == null or building_system == null or npc_system == null or time_system == null or hud == null or game_state == null:
		push_error("Main hall failure verification required nodes not found")
		quit(1)
		return

	time_system.set_current_time(4, 19, 12, 30)
	npc_system.update_npc_state("priest_01", {
		"escaped": true,
		"behavior_mode": "escaped",
		"current_location": "outside_station",
		"current_location_name": "驿站外"
	})
	await process_frame

	var main_hall: Dictionary = building_system.get_building("main_hall")
	var hp := int(main_hall.get("hp", 0))
	if hp <= 0:
		push_error("Main hall should start with positive HP")
		quit(1)
		return

	var attack_result: Dictionary = combat_system._apply_enemy_attack_to_building({
		"id": "verify_enemy_01",
		"name": "验收敌人"
	}, "main_hall", hp + 5)
	var damage_result: Dictionary = attack_result.get("result", {}) if attack_result.get("result", {}) is Dictionary else {}
	if not bool(damage_result.get("destroyed", false)):
		push_error("Main hall attack should destroy the building: %s" % JSON.stringify(attack_result))
		quit(1)
		return

	if not bool(game_state.get("game_over")):
		push_error("Main hall destruction should set GameState.game_over")
		quit(1)
		return
	if str(game_state.get("game_result")) != "failure":
		push_error("Game result should be failure, got: %s" % str(game_state.get("game_result")))
		quit(1)
		return
	if str(game_state.get("failure_reason")) != "main_hall_destroyed":
		push_error("Failure reason should be main_hall_destroyed")
		quit(1)
		return
	if int(game_state.get("game_over_day")) != 4 or int(game_state.get("game_over_hour")) != 19:
		push_error("Failure timestamp should use current game time")
		quit(1)
		return
	var settlement: Dictionary = game_state.get("settlement_snapshot") if game_state.get("settlement_snapshot") is Dictionary else {}
	var npc_section: Dictionary = settlement.get("npcs", {}) if settlement.get("npcs", {}) is Dictionary else {}
	var npc_items: Array = npc_section.get("items", []) if npc_section.get("items", []) is Array else []
	if npc_items.size() < 8:
		push_error("Failure settlement should record NPC ending summaries")
		quit(1)
		return
	var voluntary_escape_count := 0
	var forced_evacuation_count := 0
	for raw_npc in npc_items:
		var npc_entry: Dictionary = raw_npc if raw_npc is Dictionary else {}
		var final_status := str(npc_entry.get("final_status_label", ""))
		if final_status != "逃离" or not bool(npc_entry.get("escaped", false)) or bool(npc_entry.get("unconscious", false)):
			push_error("Every NPC must enter the failure epilogue as escaped: %s" % JSON.stringify(npc_entry))
			quit(1)
			return
		if str(npc_entry.get("current_location", "")) != "outside_station" or str(npc_entry.get("current_location_name", "")) != "驿站外":
			push_error("Failure escape settlement must place every NPC outside the station: %s" % JSON.stringify(npc_entry))
			quit(1)
			return
		var circumstance := str(npc_entry.get("escape_circumstance", ""))
		if str(npc_entry.get("id", "")) == "priest_01":
			if circumstance != "before_fall_voluntary":
				push_error("NPC who escaped before the fall must retain voluntary timing: %s" % JSON.stringify(npc_entry))
				quit(1)
				return
			voluntary_escape_count += 1
		elif circumstance == "after_fall_forced":
			forced_evacuation_count += 1
		else:
			push_error("NPCs still present at the fall must be marked as forced evacuees: %s" % JSON.stringify(npc_entry))
			quit(1)
			return
		if str(npc_entry.get("final_opinion", "")).is_empty() or str(npc_entry.get("fate_summary", "")).is_empty():
			push_error("Failure NPC ending should include final opinion and fate summary: %s" % JSON.stringify(npc_entry))
			quit(1)
			return
	if voluntary_escape_count != 1 or forced_evacuation_count != npc_items.size() - 1:
		push_error("Failure escape timing groups are incorrect")
		quit(1)
		return
	if not npc_section.get("active_npcs", []).is_empty() or not npc_section.get("unconscious_npcs", []).is_empty() or npc_section.get("escaped_npcs", []).size() != npc_items.size():
		push_error("Failure NPC groups must contain only escaped NPCs: %s" % JSON.stringify(npc_section))
		quit(1)
		return

	if not bool(time_system.is_gameplay_paused()):
		push_error("TimeSystem should pause gameplay after game over")
		quit(1)
		return
	var before_time := _state_time(game_state)
	time_system._process(10.0)
	if _state_time(game_state) != before_time:
		push_error("Game time should not advance after game over")
		quit(1)
		return

	await process_frame
	var game_over_panel := hud.get_node_or_null("GameOverPanel") as PanelContainer
	if game_over_panel == null or not game_over_panel.visible:
		push_error("HUD should display a game-over placeholder panel")
		quit(1)
		return
	var title_label := game_over_panel.find_child("GameOverTitleLabel", true, false) as Label
	var wave_label := game_over_panel.find_child("GameOverWaveLabel", true, false) as Label
	if title_label == null or title_label.text != "失 败":
		push_error("Failure panel should show the stylized failure title")
		quit(1)
		return
	if wave_label == null or not wave_label.text.begins_with("守住 "):
		push_error("Failure panel should show the survived-wave subtitle")
		quit(1)
		return
	var cards := game_over_panel.find_children("NPCEndingCard_*", "PanelContainer", true, false)
	if cards.size() != 8:
		push_error("Failure panel should show one ending card for every NPC")
		quit(1)
		return
	var visible_status_texts: Array[String] = []
	for raw_label in game_over_panel.find_children("*", "Label", true, false):
		visible_status_texts.append((raw_label as Label).text.strip_edges())
	if not visible_status_texts.has("失守前主动逃离") or not visible_status_texts.has("失守后被迫撤离"):
		push_error("Failure cards should distinguish voluntary escape from forced evacuation: %s" % JSON.stringify(visible_status_texts))
		quit(1)
		return
	if game_over_panel.find_child("GameOverReasonLabel", true, false) != null or game_over_panel.find_child("GameOverDetailLabel", true, false) != null:
		push_error("Failure panel should not restore the old reason/detail summary fields")
		quit(1)
		return

	var snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	var failure_result: Dictionary = snapshot.get("last_failure_result", {}) if snapshot.get("last_failure_result", {}) is Dictionary else {}
	if str(failure_result.get("reason", "")) != "main_hall_destroyed":
		push_error("Combat snapshot should expose main hall failure result")
		quit(1)
		return

	print("Main hall failure verification passed.")
	quit(0)


func _state_time(game_state: Node) -> String:
	return "%d-%02d:%02d:%02d" % [
		int(game_state.get("current_day")),
		int(game_state.get("current_hour")),
		int(game_state.get("current_minute")),
		int(game_state.get("current_second"))
	]
