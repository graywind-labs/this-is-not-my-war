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

	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_button := root.get_node_or_null("Main/UI/GMPanel/GMButton") as Button
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var game_state := root.get_node_or_null("GameState")
	if (
		gm_panel == null
		or gm_button == null
		or gm_window == null
		or resource_system == null
		or building_system == null
		or npc_system == null
		or action_system == null
		or memory_system == null
		or llm_bridge == null
		or equipment_system == null
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
	if not _panel_inside_viewport(gm_window, gm_panel._get_usable_viewport_size()):
		push_error("GM window should stay inside the viewport after opening. panel=%s viewport=%s" % [
			str(gm_window.get_global_rect()),
			str(gm_panel._get_usable_viewport_size())
		])
		quit(1)
		return
	if not _panel_tracks_button(gm_window, gm_button):
		push_error("GM window should open near the GM button")
		quit(1)
		return
	var viewport_size: Vector2 = gm_panel._get_usable_viewport_size()
	gm_button.position = Vector2(
		maxf(0.0, viewport_size.x - gm_button.size.x - 4.0),
		maxf(0.0, viewport_size.y - gm_button.size.y - 4.0)
	)
	gm_panel._position_panel_near_button()
	await process_frame
	if not _panel_inside_viewport(gm_window, viewport_size):
		push_error("GM window should remain inside the viewport when the GM button is near the edge")
		quit(1)
		return
	var repair_building_select := gm_window.find_child("RepairBuildingSelect", true, false) as OptionButton
	var assist_repair_button := gm_window.find_child("AssistRepairButton", true, false) as Button
	if repair_building_select == null or assist_repair_button == null:
		push_error("GM assist repair controls should include a target building selector and button")
		quit(1)
		return
	var upgrade_building_select := gm_window.find_child("UpgradeBuildingSelect", true, false) as OptionButton
	var assist_upgrade_button := gm_window.find_child("AssistUpgradeButton", true, false) as Button
	if upgrade_building_select == null or assist_upgrade_button == null:
		push_error("GM assist upgrade controls should include a target building selector and button")
		quit(1)
		return
	var action_select := gm_window.find_child("ActionSelect", true, false) as OptionButton
	var assign_action_button := gm_window.find_child("AssignActionButton", true, false) as Button
	if action_select == null or assign_action_button == null:
		push_error("GM action controls should keep action selector and assign button")
		quit(1)
		return
	for redundant_text in ["工作", "当教官", "当受训者", "吃饭", "睡觉"]:
		if _has_button_text(gm_window, redundant_text):
			push_error("GM action section should not keep redundant '%s' button" % redundant_text)
			quit(1)
			return
	if not _select_option_by_id(repair_building_select, "wall"):
		push_error("GM repair target selector should include wall")
		quit(1)
		return
	if not _select_option_by_id(upgrade_building_select, "garden"):
		push_error("GM upgrade target selector should include garden")
		quit(1)
		return
	var equipment_weapon_select := gm_window.find_child("EquipmentWeaponSelect", true, false) as OptionButton
	var equipment_armor_slot_select := gm_window.find_child("EquipmentArmorSlotSelect", true, false) as OptionButton
	if equipment_weapon_select == null or equipment_armor_slot_select == null:
		push_error("GM equipment controls should include weapon and armor slot selectors")
		quit(1)
		return
	var recruit_button := gm_window.find_child("RecruitNpcButton", true, false) as Button
	if recruit_button == null:
		push_error("GM NPC section should include a recruit button")
		quit(1)
		return
	if not _select_option_by_id(equipment_weapon_select, "bow"):
		push_error("GM weapon selector should include bow")
		quit(1)
		return
	if not _select_option_by_id(equipment_armor_slot_select, "chest"):
		push_error("GM armor selector should include chest")
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
	if not building_system.repair_building("wall"):
		push_error("Failed to start wall repair for GM assist test")
		quit(1)
		return
	if bool(npc_system.get_npc("priest_01").get("recruited", false)):
		push_error("Priest should start unrecruited for GM recruit test")
		quit(1)
		return
	if not _select_option_by_id(gm_panel._npc_select, "priest_01"):
		push_error("GM NPC selector should include priest_01")
		quit(1)
		return
	recruit_button.pressed.emit()
	await process_frame
	if not bool(npc_system.get_npc("priest_01").get("recruited", false)):
		push_error("GM recruit button should set selected NPC recruited")
		quit(1)
		return
	var priest_order: Dictionary = npc_system.debug_publish_npc_order("priest_01", "协助守备。")
	if not bool(priest_order.get("ok", false)):
		push_error("GM-recruited NPC should be able to receive orders")
		quit(1)
		return
	if not _select_option_by_id(gm_panel._npc_select, "engineer_01"):
		push_error("GM NPC selector should include engineer_01")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately("engineer_01", "plaza"):
		push_error("Failed to place engineer at plaza for GM assist test")
		quit(1)
		return
	assist_repair_button.pressed.emit()
	if not await _wait_until_action_result(npc_system, "engineer_01", "assist_repair_started_wall"):
		push_error("GM assist repair button did not use the selected repair target building")
		quit(1)
		return
	if not building_system.upgrade_building("garden"):
		push_error("Failed to start garden upgrade for GM assist test")
		quit(1)
		return
	if not _select_option_by_id(gm_panel._npc_select, "doctor_01"):
		push_error("GM NPC selector should include doctor_01")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately("doctor_01", "plaza"):
		push_error("Failed to place doctor at plaza for GM assist upgrade test")
		quit(1)
		return
	assist_upgrade_button.pressed.emit()
	if not await _wait_until_action_result(npc_system, "doctor_01", "assist_upgrade_started_garden"):
		push_error("GM assist upgrade button did not use the selected upgrade target building")
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

	gm_panel._execute_command("attack_npc stableman_01 150 local_public")
	var stableman_state: Dictionary = npc_system.get_npc_state("stableman_01")
	if int(stableman_state.get("hp", -1)) != 0 or not bool(stableman_state.get("unconscious", false)):
		push_error("GM attack_npc command should deduct HP and set unconscious")
		quit(1)
		return
	gm_panel._execute_command("recover_npc stableman_01 54000")
	stableman_state = npc_system.get_npc_state("stableman_01")
	if int(stableman_state.get("hp", -1)) != 30 or bool(stableman_state.get("unconscious", true)):
		push_error("GM recover_npc command should advance natural recovery and revive NPC")
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
	gm_panel._execute_command("publish_order veteran_deputy_01 Hold the gate")
	if str(npc_system.get_current_order("veteran_deputy_01").get("text", "")) != "Hold the gate":
		push_error("GM publish_order command failed")
		quit(1)
		return
	gm_panel._execute_command("order veteran_deputy_01")
	gm_panel._execute_command("plan_request")
	llm_bridge.debug_build_npc_context("veteran_deputy_01", "gm_verify")
	gm_panel._execute_command("last_order_injection")
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	if str(injection.get("npc_id", "")) != "veteran_deputy_01" or str(injection.get("current_order", {}).get("text", "")) != "Hold the gate":
		push_error("GM last_order_injection command did not expose the latest current_order")
		quit(1)
		return

	resource_system.add_resource("weapons", 2)
	resource_system.add_resource("armor", 1)
	resource_system.add_resource("horse_readiness", 1)
	gm_panel._execute_command("equip_weapon veteran_deputy_01 bow local_public")
	if str(equipment_system.get_npc_unit_type("veteran_deputy_01")) != "archer":
		push_error("GM equip_weapon command should equip bow and classify archer")
		quit(1)
		return
	gm_panel._execute_command("equip_armor veteran_deputy_01 chest local_public")
	if str(npc_system.get_npc("veteran_deputy_01").get("equipment", {}).get("chest", {}).get("id", "")) != "mail_chest":
		push_error("GM equip_armor command should equip chest armor")
		quit(1)
		return
	gm_panel._execute_command("equip_mount veteran_deputy_01 local_public")
	if str(equipment_system.get_npc_unit_type("veteran_deputy_01")) != "mounted_ranged":
		push_error("GM equip_mount command should update mounted unit type")
		quit(1)
		return
	gm_panel._execute_command("unit_type veteran_deputy_01")

	if not npc_system.debug_enter_location_immediately("veteran_deputy_01", "training_ground"):
		push_error("Failed to place veteran at training ground for GM training test")
		quit(1)
		return
	gm_panel._execute_command("train_instructor veteran_deputy_01")
	if str(npc_system.get_npc_state("veteran_deputy_01").get("last_action_result", "")) != "started_work_training_instructor":
		push_error("GM train_instructor command should start instructor action")
		quit(1)
		return
	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("weapons", 1)
	var stableman_weapon: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "bow", "private")
	if not bool(stableman_weapon.get("ok", false)):
		push_error("Failed to equip stableman for GM training test")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately("stableman_01", "training_ground"):
		push_error("Failed to place stableman at training ground for GM training test")
		quit(1)
		return
	gm_panel._execute_command("train_student stableman_01")
	if str(npc_system.get_npc_state("stableman_01").get("last_action_result", "")) != "started_receive_weapon_training":
		push_error("GM train_student command should start student action")
		quit(1)
		return

	if action_system.get_action_ids().has("work_repair_wall"):
		push_error("GM action list should not expose fixed wall repair action")
		quit(1)
		return

	print("GM panel verification passed.")
	quit(0)


func _select_option_by_id(select: OptionButton, expected_id: String) -> bool:
	if select == null:
		return false
	for index in range(select.get_item_count()):
		if str(select.get_item_metadata(index)) == expected_id:
			select.select(index)
			return true
	return false


func _has_button_text(root_node: Node, text: String) -> bool:
	for child in root_node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.text == text:
			return true
	return false


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("last_action_result", "")) == expected_result:
			return true
	return false


func _panel_tracks_button(panel: Control, button: Control) -> bool:
	var panel_rect := panel.get_global_rect()
	var button_rect := button.get_global_rect()
	var expected_y := button_rect.position.y + button_rect.size.y
	return (
		absf(panel_rect.position.x - button_rect.position.x) <= 2.0
		and panel_rect.position.y >= expected_y
		and panel_rect.position.y <= expected_y + 16.0
	)


func _panel_inside_viewport(panel: Control, viewport_size: Vector2) -> bool:
	var panel_rect := panel.get_global_rect()
	return (
		panel_rect.position.x >= 0.0
		and panel_rect.position.y >= 0.0
		and panel_rect.position.x + panel_rect.size.x <= viewport_size.x + 1.0
		and panel_rect.position.y + panel_rect.size.y <= viewport_size.y + 1.0
	)
