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
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if equipment_system == null or npc_system == null or resource_system == null or memory_system == null or horse_system == null or npc_panel == null:
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
	var initial_sword_shield_count := int(resource_system.get_resource("item_sword_shield"))
	var initial_equipment: Dictionary = npc_system.get_npc(target_id).get("equipment", {})
	if str(initial_equipment.get("main_weapon", {}).get("id", "")) != "sword_shield":
		push_error("Ada should start with the canonical sword_shield equipped")
		quit(1)
		return
	if str(equipment_system.get_npc_unit_type(target_id)) != "melee_infantry":
		push_error("Ada's initial sword_shield should classify her as melee infantry")
		quit(1)
		return
	if int(resource_system.get_resource("item_sword_shield")) != initial_sword_shield_count:
		push_error("Ada's story loadout must not consume item_sword_shield inventory")
		quit(1)
		return
	if _has_event(memory_system.get_npc_daily_events(target_id), "equipment_given"):
		push_error("Ada's story loadout must not be recorded as a player equipment gift")
		quit(1)
		return

	for weapon_id in weapon_ids:
		var weapon_definition: Dictionary = equipment_system.get_weapon_def(str(weapon_id))
		if str(weapon_definition.get("source_resource_id", "")) != "item_%s" % str(weapon_id):
			push_error("Weapon %s does not consume its exact item inventory: %s" % [weapon_id, JSON.stringify(weapon_definition)])
			quit(1)
			return
	for armor_id in equipment_system.get_armor_ids():
		var armor_definition: Dictionary = equipment_system.get_armor_def(str(armor_id))
		if str(armor_definition.get("source_resource_id", "")) != "item_%s" % str(armor_id):
			push_error("Armor %s does not consume its exact item inventory: %s" % [armor_id, JSON.stringify(armor_definition)])
			quit(1)
			return

	# Legacy aggregate amounts are sentinels: no formal equipment operation may consume them.
	resource_system.add_resource("weapons", 5)
	resource_system.add_resource("armor", 3)
	resource_system.add_resource("horse_readiness", 2)
	resource_system.add_resource("item_polearm", 1)
	resource_system.add_resource("item_bow", 1)
	resource_system.add_resource("item_crossbow", 1)
	resource_system.add_resource("item_mail_chest", 1)
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

	var weapon_select := npc_panel.find_child("NPCWeaponSelect", true, false) as OptionButton
	var weapon_button := npc_panel.find_child("NPCGiveWeaponButton", true, false) as Button
	var equipment_label := npc_panel.find_child("NPCEquipmentLabel", true, false) as Label
	if weapon_select == null or weapon_button == null or equipment_label == null:
		push_error("NPCPanel formal equipment controls are missing: select=%s button=%s label=%s" % [weapon_select != null, weapon_button != null, equipment_label != null])
		quit(1)
		return
	if not equipment_label.text.contains("剑盾") or not equipment_label.text.contains("近战步兵"):
		push_error("NPCPanel did not display Ada's initial sword and shield: %s" % equipment_label.text)
		quit(1)
		return
	if not _select_option_by_id(weapon_select, "polearm"):
		push_error("NPC weapon selector should include polearm")
		quit(1)
		return
	weapon_select.item_selected.emit(weapon_select.selected)
	await process_frame
	if weapon_button.disabled:
		push_error("Selecting an in-stock concrete weapon must immediately enable the NPCPanel equip button")
		quit(1)
		return

	var polearm_before := int(resource_system.get_resource("item_polearm"))
	var sword_shield_before := int(resource_system.get_resource("item_sword_shield"))
	weapon_button.pressed.emit()
	await process_frame
	var equipment: Dictionary = npc_system.get_npc(target_id).get("equipment", {})
	if str(equipment.get("main_weapon", {}).get("id", "")) != "polearm":
		push_error("NPCPanel did not replace Ada's initial weapon with the selected polearm")
		quit(1)
		return
	if int(resource_system.get_resource("item_polearm")) != polearm_before - 1:
		push_error("Replacing Ada's initial weapon did not consume item_polearm")
		quit(1)
		return
	if int(resource_system.get_resource("item_sword_shield")) != sword_shield_before + 1:
		push_error("Replacing Ada's initial weapon did not return item_sword_shield")
		quit(1)
		return
	if str(equipment_system.get_npc_unit_type(target_id)) != "polearm_infantry":
		push_error("Polearm should classify as polearm infantry")
		quit(1)
		return
	if not equipment_label.text.contains("长杆武器") or not equipment_label.text.contains("长杆步兵"):
		push_error("NPCPanel did not display weapon and unit type: %s" % equipment_label.text)
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "equipment_changed"):
		push_error("Replacing Ada's initial weapon should write equipment_changed")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_witness_events(witness_id), "equipment_changed"):
		push_error("Public equipment change should reach same-location witness")
		quit(1)
		return

	var bow_before := int(resource_system.get_resource("item_bow"))
	var polearm_return_before := int(resource_system.get_resource("item_polearm"))
	var changed: Dictionary = equipment_system.equip_npc_main_weapon(target_id, "bow", "local_public")
	if not bool(changed.get("ok", false)):
		push_error("Failed to replace main weapon with bow: %s" % JSON.stringify(changed))
		quit(1)
		return
	if int(resource_system.get_resource("item_bow")) != bow_before - 1:
		push_error("Replacing polearm with bow did not consume item_bow")
		quit(1)
		return
	if int(resource_system.get_resource("item_polearm")) != polearm_return_before + 1:
		push_error("Replacing polearm with bow did not return item_polearm")
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

	var available_horses: Array = horse_system.get_available_horses_for_npc(target_id)
	if available_horses.is_empty():
		push_error("Stable should provide an initial adult horse for assignment")
		quit(1)
		return
	var assigned_horse_id := str(available_horses[0].get("horse_id", ""))
	var assigned_horse_name := str(available_horses[0].get("name", assigned_horse_id))
	var mount_result: Dictionary = horse_system.assign_horse_to_npc(target_id, assigned_horse_id, "local_public")
	if not bool(mount_result.get("ok", false)):
		push_error("Failed to assign initial adult horse: %s" % JSON.stringify(mount_result))
		quit(1)
		return
	if str(npc_system.get_npc(target_id).get("equipment", {}).get("mount", {}).get("horse_id", "")) != assigned_horse_id:
		push_error("Mount slot should reference the assigned concrete horse")
		quit(1)
		return
	if int(resource_system.get_resource("horse_readiness")) != 2:
		push_error("Horse assignment must not consume deprecated horse_readiness")
		quit(1)
		return
	if str(equipment_system.get_npc_unit_type(target_id)) != "mounted_ranged":
		push_error("Bow plus mount should classify as mounted ranged")
		quit(1)
		return

	var armor_before := int(resource_system.get_resource("item_mail_chest"))
	var legacy_armor_before := int(resource_system.get_resource("armor"))
	var armor_result: Dictionary = equipment_system.equip_npc_armor(target_id, "chest", "", "local_public")
	if not bool(armor_result.get("ok", false)):
		push_error("Failed to equip chest armor: %s" % JSON.stringify(armor_result))
		quit(1)
		return
	if int(resource_system.get_resource("item_mail_chest")) != armor_before - 1:
		push_error("Equipping mail chest should consume one item_mail_chest")
		quit(1)
		return
	if int(resource_system.get_resource("armor")) != legacy_armor_before:
		push_error("Equipping mail chest must not consume deprecated armor inventory")
		quit(1)
		return
	if str(npc_system.get_npc(target_id).get("equipment", {}).get("chest", {}).get("id", "")) != "mail_chest":
		push_error("Chest armor slot should contain mail_chest")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "equipment_given"):
		push_error("Filling Ada's empty armor slot should still write equipment_given")
		quit(1)
		return

	var unequip_armor_result: Dictionary = equipment_system.unequip_npc_slot(target_id, "chest", "local_public")
	if not bool(unequip_armor_result.get("ok", false)):
		push_error("Failed to unequip concrete chest armor: %s" % JSON.stringify(unequip_armor_result))
		quit(1)
		return
	if int(resource_system.get_resource("item_mail_chest")) != armor_before:
		push_error("Unequipping chest armor did not return item_mail_chest")
		quit(1)
		return
	if not (npc_system.get_npc(target_id).get("equipment", {}).get("chest", {}) as Dictionary).is_empty():
		push_error("Chest slot was not cleared after unequip")
		quit(1)
		return
	var re_equip_armor_result: Dictionary = equipment_system.equip_npc_armor(target_id, "chest", "mail_chest", "local_public")
	if not bool(re_equip_armor_result.get("ok", false)) or int(resource_system.get_resource("item_mail_chest")) != armor_before - 1:
		push_error("Re-equipping chest armor did not consume the returned exact item: %s" % JSON.stringify(re_equip_armor_result))
		quit(1)
		return

	npc_system.debug_select_npc(target_id)
	await process_frame
	if not equipment_label.text.contains("锁子甲") or not equipment_label.text.contains(assigned_horse_name) or not equipment_label.text.contains("骑射单位"):
		push_error("NPCPanel should display armor, mount and mounted unit type: %s" % equipment_label.text)
		quit(1)
		return

	var crossbow_before := int(resource_system.get_resource("item_crossbow"))
	var bow_return_before := int(resource_system.get_resource("item_bow"))
	var crossbow_result: Dictionary = equipment_system.equip_npc_main_weapon(target_id, "crossbow", "private")
	if not bool(crossbow_result.get("ok", false)) or str(equipment_system.get_npc_unit_type(target_id)) != "mounted_ranged":
		push_error("Crossbow plus mount should remain mounted ranged: %s" % JSON.stringify(crossbow_result))
		quit(1)
		return
	if int(resource_system.get_resource("item_crossbow")) != crossbow_before - 1 or int(resource_system.get_resource("item_bow")) != bow_return_before + 1:
		push_error("Crossbow replacement did not consume/return exact inventories")
		quit(1)
		return

	var unequip_weapon_result: Dictionary = equipment_system.unequip_npc_slot(target_id, "main_weapon", "private")
	if not bool(unequip_weapon_result.get("ok", false)):
		push_error("Failed to unequip concrete main weapon: %s" % JSON.stringify(unequip_weapon_result))
		quit(1)
		return
	if int(resource_system.get_resource("item_crossbow")) != crossbow_before:
		push_error("Unequipping crossbow did not return item_crossbow")
		quit(1)
		return
	var final_equipment: Dictionary = npc_system.get_npc(target_id).get("equipment", {})
	if not (final_equipment.get("main_weapon", {}) as Dictionary).is_empty():
		push_error("Main weapon slot was not cleared")
		quit(1)
		return
	if not (final_equipment.get("mount", {}) as Dictionary).is_empty() or not horse_system.get_assigned_horse_for_npc(target_id).is_empty():
		push_error("Removing the main weapon did not automatically unassign the concrete horse")
		quit(1)
		return
	if int(resource_system.get_resource("weapons")) != 5 or int(resource_system.get_resource("armor")) != 3 or int(resource_system.get_resource("horse_readiness")) != 2:
		push_error("Formal equipment operations changed deprecated aggregate inventory")
		quit(1)
		return

	print("T0036 concrete equipment inventory verification passed.")
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
