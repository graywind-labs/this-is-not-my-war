extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var expected_result := str(args[0]).strip_edges().to_lower() if not args.is_empty() else "victory"
	if not expected_result in ["victory", "failure"]:
		_fail("Expected victory or failure argument")
		return
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Could not load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var game_state := root.get_node_or_null("/root/GameState")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	if gm_window == null or llm_bridge == null or game_state == null or building_system == null:
		_fail("Required GM epilogue nodes are missing")
		return
	llm_bridge.set_backend_base_url("gm-epilogue-invalid://backend")
	llm_bridge.request_timeout_seconds = 0.2
	var victory_button := gm_window.find_child("TriggerEpilogueVictoryButton", true, false) as Button
	var failure_button := gm_window.find_child("TriggerEpilogueFailureButton", true, false) as Button
	var status_button := gm_window.find_child("RefreshEpilogueStatusButton", true, false) as Button
	var status_label := gm_window.find_child("EpilogueStatusLabel", true, false) as Label
	if victory_button == null or failure_button == null or status_button == null or status_label == null:
		_fail("GM epilogue controls are incomplete")
		return
	var selected_button := victory_button if expected_result == "victory" else failure_button
	selected_button.pressed.emit()
	await process_frame
	if not bool(game_state.game_over) or str(game_state.game_result) != expected_result:
		_fail("GM button did not commit expected %s outcome" % expected_result)
		return
	if expected_result == "failure":
		var main_hall: Dictionary = building_system.get_building("main_hall")
		if int(main_hall.get("hp", -1)) != 0:
			_fail("GM failure button did not destroy main hall through BuildingSystem")
			return
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		var epilogue: Dictionary = game_state.settlement_snapshot.get("epilogue", {})
		if str(epilogue.get("status", "")) == "template_fallback":
			break
	status_button.pressed.emit()
	var final_epilogue: Dictionary = game_state.settlement_snapshot.get("epilogue", {})
	if str(final_epilogue.get("status", "")) != "template_fallback":
		_fail("GM outcome did not reach explicit fallback in offline test")
		return
	if not status_label.text.contains("模板降级"):
		_fail("GM status label did not expose epilogue source")
		return
	var npc_data: Dictionary = game_state.settlement_snapshot.get("npcs", {})
	if not npc_data.get("items", []) is Array or (npc_data.get("items", []) as Array).size() != 8:
		_fail("GM outcome did not preserve eight NPC endings")
		return
	print("T0387_GM_EPILOGUE_%s_OK" % expected_result.to_upper())
	main.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
