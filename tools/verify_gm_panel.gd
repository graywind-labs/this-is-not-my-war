extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_button := root.get_node_or_null("Main/UI/GMPanel/GMButton") as Button
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var game_state := root.get_node_or_null("GameState")
	if (
		gm_panel == null
		or gm_button == null
		or gm_window == null
		or resource_system == null
		or building_system == null
		or npc_system == null
		or memory_system == null
		or game_state == null
	):
		push_error("GM verification required nodes not found")
		quit(1)
		return

	if not gm_panel.visible:
		push_error("GMPanel should be visible while GM_ENABLED is true")
		quit(1)
		return
	if gm_button.text != "GM":
		push_error("GM button was not created")
		quit(1)
		return
	if gm_window.visible:
		push_error("GM window should be hidden before the GM button is pressed")
		quit(1)
		return

	gm_button.pressed.emit()
	if not gm_window.visible:
		push_error("GM button did not open the GM window")
		quit(1)
		return

	var money_before := int(resource_system.get_resource("money"))
	gm_panel._execute_command("add_resource money 3")
	if int(resource_system.get_resource("money")) != money_before + 3:
		push_error("GM add_resource command failed")
		quit(1)
		return

	var wall_before := int(building_system.get_building("wall").get("hp", 0))
	gm_panel._execute_command("damage_building wall 5")
	if int(building_system.get_building("wall").get("hp", 0)) != maxi(0, wall_before - 5):
		push_error("GM damage_building command failed")
		quit(1)
		return

	gm_panel._execute_command("set_time 2 9 10 11")
	if (
		int(game_state.current_day) != 2
		or int(game_state.current_hour) != 9
		or int(game_state.current_minute) != 10
		or int(game_state.current_second) != 11
	):
		push_error("GM set_time command failed")
		quit(1)
		return

	gm_panel._execute_command("enter_location cook_01 dining_hall")
	var cook_state: Dictionary = npc_system.get_npc_state("cook_01")
	if str(cook_state.get("current_location", "")) != "dining_hall":
		push_error("GM enter_location command failed")
		quit(1)
		return

	var event_count_before := int(memory_system.get_event_count())
	gm_panel._execute_command("give_money cook_01 2 local_public")
	if int(memory_system.get_event_count()) <= event_count_before:
		push_error("GM give_money command did not write an event")
		quit(1)
		return

	gm_panel._execute_command("plaza_notice Verify GM panel")
	var plaza_snapshot: Dictionary = memory_system.debug_get_location_snapshot("plaza")
	if str(plaza_snapshot.get("current_notice", "")) != "Verify GM panel":
		push_error("GM plaza_notice command failed")
		quit(1)
		return

	gm_panel._execute_command("memory cook_01")
	gm_panel._execute_command("location plaza")
	gm_panel._execute_command("events")

	print("GM panel verification passed.")
	quit(0)
