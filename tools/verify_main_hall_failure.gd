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
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var game_state := root.get_node_or_null("/root/GameState")
	if combat_system == null or building_system == null or time_system == null or hud == null or game_state == null:
		push_error("Main hall failure verification required nodes not found")
		quit(1)
		return

	time_system.set_current_time(4, 19, 12, 30)
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
	for raw_npc in npc_items:
		var npc_entry: Dictionary = raw_npc if raw_npc is Dictionary else {}
		var final_status := str(npc_entry.get("final_status_label", ""))
		if not ["可行动", "昏迷", "逃离"].has(final_status):
			push_error("Failure NPC ending should use allowed final status labels, got: %s" % JSON.stringify(npc_entry))
			quit(1)
			return
		if str(npc_entry.get("final_opinion", "")).is_empty() or str(npc_entry.get("fate_summary", "")).is_empty():
			push_error("Failure NPC ending should include final opinion and fate summary: %s" % JSON.stringify(npc_entry))
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
	var reason_label := game_over_panel.find_child("GameOverReasonLabel", true, false) as Label
	var detail_label := game_over_panel.find_child("GameOverDetailLabel", true, false) as Label
	if reason_label == null or not reason_label.text.contains("主厅被摧毁"):
		push_error("Failure panel should show the main hall destruction reason")
		quit(1)
		return
	if detail_label == null or not detail_label.text.contains("停止正常推进"):
		push_error("Failure panel should state that normal progression stopped")
		quit(1)
		return
	if not detail_label.text.contains("NPC 结局") or not detail_label.text.contains("对守备官最终看法") or not detail_label.text.contains("后续命运"):
		push_error("Failure panel should show NPC ending summaries")
		quit(1)
		return
	if detail_label.text.contains("阵亡") or detail_label.text.contains("死亡"):
		push_error("Failure panel should not use death wording for NPC endings")
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
