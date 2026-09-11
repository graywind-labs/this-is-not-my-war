extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var game_state := root.get_node_or_null("GameState")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var panel := hud.get_node_or_null("GameOverPanel") if hud != null else null
	_check(game_state != null and panel != null, "Required GameState/HUD epilogue panel is missing")
	if _failed:
		quit(1)
		return

	game_state.set_game_over("victory", "five_waves_survived", {"wave_number": 5})
	await process_frame
	await process_frame
	panel.present("victory", game_state.settlement_snapshot)
	await process_frame
	_check_panel_contract(panel, "victory", "胜 利", "守住 5 波敌人")

	panel.present("failure", game_state.settlement_snapshot)
	await process_frame
	_check_panel_contract(panel, "failure", "失 败", "守住 ")
	var first_card := panel.find_child("NPCEndingCard_*", true, false) as PanelContainer
	if first_card != null:
		var portrait := first_card.find_child("EndingPortrait", true, false) as Control
		var story := first_card.find_child("EndingStory", true, false) as Control
		_check(portrait != null and story != null, "NPC card must contain portrait and story columns")
		if portrait != null and story != null:
			var portrait_column := first_card.find_child("EndingPortraitColumn", true, false) as Control
			_check(portrait_column != null and is_equal_approx(portrait_column.size_flags_stretch_ratio, 1.0), "Portrait column stretch ratio should be 1")
			_check(is_equal_approx(story.size_flags_stretch_ratio, 2.0), "Story column stretch ratio should be 2")

	if _failed:
		main.queue_free()
		await process_frame
		quit(1)
		return
	print("T0388_EPILOGUE_PANEL_OK")
	main.queue_free()
	await process_frame
	quit(0)


func _check_panel_contract(panel: Control, expected_result: String, expected_title: String, wave_prefix: String) -> void:
	var snapshot: Dictionary = panel.debug_get_layout_snapshot()
	_check(str(snapshot.get("result", "")) == expected_result, "Result theme did not switch")
	_check(str(snapshot.get("theme_variant", "")) == ("victory_gold" if expected_result == "victory" else "failure_gray"), "Result palette did not switch")
	_check(str(snapshot.get("title", "")) == expected_title, "Large result title mismatch")
	_check(str(snapshot.get("wave_subtitle", "")).begins_with(wave_prefix), "Wave subtitle mismatch")
	_check(snapshot.get("metadata_values", []) == ["时间", "结局标题", "主题"], "Metadata values must remain time/title/theme")
	_check(snapshot.get("visible_metadata_captions", []) == ["时间"], "Only the time caption should remain visible")
	_check(snapshot.get("viewport_fraction", Vector2.ZERO).is_equal_approx(Vector2(2.0 / 3.0, 2.0 / 3.0)), "Panel should occupy about two thirds of the viewport")
	_check(panel.find_child("结局标题Value", true, false) != null and panel.find_child("主题Value", true, false) != null, "Ending title and theme values must remain visible")
	for caption in panel.find_children("MetadataCaption", "Label", true, false):
		_check(not (caption as Label).text in ["结局标题", "主题"], "Redundant ending-title/theme captions must be removed")
	_check(int(snapshot.get("card_count", 0)) == 8, "Settlement should render eight NPC cards")
	_check(not bool(snapshot.get("shows_reason", true)), "Reason field must not be shown")
	_check(not bool(snapshot.get("shows_resources", true)), "Resource field must not be shown")
	_check(not bool(snapshot.get("shows_npc_heading", true)), "Redundant NPC ending heading must not be shown")
	for card in panel.find_children("NPCEndingCard_*", "PanelContainer", true, false):
		var portrait := card.find_child("EndingPortrait", true, false)
		_check(portrait != null, "Every NPC card needs a portrait")
		if portrait != null and portrait.has_method("debug_get_snapshot"):
			_check(bool(portrait.debug_get_snapshot().get("allow_escaped_portrait", false)), "Ending portraits must remain available for escaped NPCs")
		_check(card.find_child("NPCFinalStatus", true, false) != null, "Every NPC card needs final status chips")
		_check(card.find_child("NPCFateStory", true, false) != null, "Every NPC card needs the generated story")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
