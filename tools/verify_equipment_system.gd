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

	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if equipment_system == null or npc_system == null or resource_system == null or memory_system == null or npc_panel == null:
		push_error("T0901 required systems are missing")
		quit(1)
		return

	var target_id := "veteran_deputy_01"
	var witness_id := "doctor_01"
	var unrecruited_id := "cook_01"
	if not bool(npc_system.get_npc(target_id).get("recruited", false)):
		push_error("Veteran deputy should start recruited for equipment verification")
		quit(1)
		return

	var weapon_ids: Array = equipment_system.get_weapon_ids()
	for expected_weapon_id in ["sword_shield", "polearm", "bow", "crossbow"]:
		if not weapon_ids.has(expected_weapon_id):
			push_error("Weapon definitions should include %s" % expected_weapon_id)
			quit(1)
			return
	if weapon_ids.has("short_sword"):
		push_error("Weapon definitions should not include removed short_sword")
		quit(1)
		return
	if not equipment_system.get_armor_slot_ids().has("chest"):
		push_error("Armor slots should include chest")
		quit(1)
		return
	if equipment_system.get_mount_ids().is_empty():
		push_error("Mount definitions should not be empty")
		quit(1)
		return

	resource_system.add_resource("weapons", 5)
	resource_system.add_resource("armor", 3)
	resource_system.add_resource("horse_readiness", 2)
	await process_frame

	var rejected: Dictionary = equipment_system.equip_npc_main_weapon(unrecruited_id, "sword_shield", "local_public")
	if bool(rejected.get("ok", false)) or str(rejected.get("error", "")) != "npc_not_recruited":
		push_error("Unrecruited NPC should not accept direct equipment assignment: %s" % JSON.stringify(rejected))
		quit(1)
		return

	npc_system.debug_select_npc(target_id)
	await process_frame
	if not npc_panel.visible:
		push_error("NPCPanel should open for recruited target")
		quit(1)
		return

	var weapon_select := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCInteractionButtonRow/NPCWeaponSelect") as OptionButton
	var weapon_button := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCInteractionButtonRow/NPCGiveWeaponButton") as Button
	var equipment_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCEquipmentLabel") as Label
	if weapon_select == null or weapon_button == null or equipment_label == null:
		push_error("NPCPanel formal equipment controls are missing")
		quit(1)
		return
	if not _select_option_by_id(weapon_select, "sword_shield"):
		push_error("NPC weapon selector should include sword_shield")
		quit(1)
		return

	var weapons_before := int(resource_system.get_resource("weapons"))
	weapon_button.pressed.emit()
	await process_frame
	var equipment: Dictionary = npc_system.get_npc(target_id).get("equipment", {})
	if str(equipment.get("main_weapon", {}).get("id", "")) != "sword_shield":
		push_error("NPCPanel did not equip selected sword_shield")
		quit(1)
		return
	if int(resource_system.get_resource("weapons")) != weapons_before - 1:
		push_error("Equipping a main weapon should consume one weapons inventory item")
		quit(1)
		return
	if str(equipment_system.get_npc_unit_type(target_id)) != "melee_infantry":
		push_error("Sword and shield should classify as melee infantry")
		quit(1)
		return
	if not equipment_label.text.contains("剑盾") or not equipment_label.text.contains("近战步兵"):
		push_error("NPCPanel did not display weapon and unit type: %s" % equipment_label.text)
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "equipment_given"):
		push_error("Initial equipment assignment should write equipment_given")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_witness_events(witness_id), "equipment_given"):
		push_error("Public equipment event should reach same-location witness")
		quit(1)
		return

	var after_first_weapon := int(resource_system.get_resource("weapons"))
	var changed: Dictionary = equipment_system.equip_npc_main_weapon(target_id, "bow", "local_public")
	if not bool(changed.get("ok", false)):
		push_error("Failed to replace main weapon with bow: %s" % JSON.stringify(changed))
		quit(1)
		return
	if int(resource_system.get_resource("weapons")) != after_first_weapon:
		push_error("Replacing a weapon should spend the new item and return the previous generic weapon inventory")
		quit(1)
		return
	if str(equipment_system.get_npc_unit_type(target_id)) != "archer":
		push_error("Bow should classify as archer before mount")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "equipment_changed"):
		push_error("Replacing equipment should write equipment_changed")
		quit(1)
		return

	var mount_result: Dictionary = equipment_system.equip_npc_mount(target_id, "", "local_public")
	if not bool(mount_result.get("ok", false)):
		push_error("Failed to equip mount: %s" % JSON.stringify(mount_result))
		quit(1)
		return
	if str(npc_system.get_npc(target_id).get("equipment", {}).get("mount", {}).get("id", "")) != "riding_horse":
		push_error("Mount slot should contain riding_horse")
		quit(1)
		return
	if str(equipment_system.get_npc_unit_type(target_id)) != "mounted_ranged":
		push_error("Bow plus mount should classify as mounted ranged")
		quit(1)
		return

	var armor_before := int(resource_system.get_resource("armor"))
	var armor_result: Dictionary = equipment_system.equip_npc_armor(target_id, "chest", "", "local_public")
	if not bool(armor_result.get("ok", false)):
		push_error("Failed to equip chest armor: %s" % JSON.stringify(armor_result))
		quit(1)
		return
	if int(resource_system.get_resource("armor")) != armor_before - 1:
		push_error("Equipping armor should consume one armor inventory item")
		quit(1)
		return
	if str(npc_system.get_npc(target_id).get("equipment", {}).get("chest", {}).get("id", "")) != "mail_chest":
		push_error("Chest armor slot should contain mail_chest")
		quit(1)
		return

	npc_system.debug_select_npc(target_id)
	await process_frame
	if not equipment_label.text.contains("锁子甲") or not equipment_label.text.contains("整备马匹") or not equipment_label.text.contains("骑射单位"):
		push_error("NPCPanel should display armor, mount and mounted unit type: %s" % equipment_label.text)
		quit(1)
		return

	var crossbow_result: Dictionary = equipment_system.equip_npc_main_weapon(target_id, "crossbow", "private")
	if not bool(crossbow_result.get("ok", false)) or str(equipment_system.get_npc_unit_type(target_id)) != "mounted_ranged":
		push_error("Crossbow plus mount should remain mounted ranged: %s" % JSON.stringify(crossbow_result))
		quit(1)
		return

	print("T0901 equipment system verification passed.")
	quit(0)


func _select_option_by_id(select: OptionButton, expected_id: String) -> bool:
	for index in range(select.get_item_count()):
		if str(select.get_item_metadata(index)) == expected_id:
			select.select(index)
			return true
	return false


func _has_event(events: Array, event_type: String) -> bool:
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) == event_type:
			return true
	return false
