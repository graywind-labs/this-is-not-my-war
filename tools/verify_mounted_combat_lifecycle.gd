extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var horse_presenters: Array[Node] = get_nodes_in_group("horse_world_presentation")
	var horse_presenter: Node = horse_presenters[0] if not horse_presenters.is_empty() else null
	if horse_system == null or equipment_system == null or npc_system == null or combat_system == null or memory_system == null or npc_panel == null or horse_presenter == null:
		_fail("Mounted-combat verification systems are missing")
		return

	var npc_id := "veteran_deputy_01"
	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.size() < 2:
		_fail("Mounted-combat verification requires two initial horses")
		return
	var first_horse_id := str(horse_ids[0])
	var second_horse_id := str(horse_ids[1])
	npc_system.set_npc_behavior_mode(npc_id, "work", "mounted_combat_test_reset", {"force_idle": true})

	var assigned: Dictionary = horse_system.assign_horse_to_npc(npc_id, first_horse_id, "private")
	if not bool(assigned.get("ok", false)):
		_fail("Could not assign the first horse: %s" % JSON.stringify(assigned))
		return
	var unassigned: Dictionary = horse_system.unassign_horse_from_npc(npc_id, "manual", "private")
	if not bool(unassigned.get("ok", false)):
		_fail("Could not manually reclaim the horse: %s" % JSON.stringify(unassigned))
		return
	var latest_event := _latest_event_of_type(memory_system.get_npc_daily_events(npc_id), "equipment_changed")
	if str(latest_event.get("summary", "")) != "守备官收回了分配给艾达的马匹。":
		_fail("Horse reclaim summary is incorrect: %s" % JSON.stringify(latest_event))
		return
	npc_system.set_npc_behavior_mode(npc_id, "avoid_combat", "mounted_combat_avoid_lock_test", {"force_idle": true})
	var avoid_horse_change: Dictionary = horse_system.assign_horse_to_npc(npc_id, first_horse_id, "private")
	var avoid_weapon_change: Dictionary = equipment_system.unequip_npc_slot(npc_id, "main_weapon", "private")
	if str(avoid_horse_change.get("reason", "")) != "loadout_locked_in_wartime" or str(avoid_weapon_change.get("error", "")) != "loadout_locked_in_wartime":
		_fail("Avoid-combat mode must reject horse and equipment changes: horse=%s equipment=%s" % [JSON.stringify(avoid_horse_change), JSON.stringify(avoid_weapon_change)])
		return
	npc_system.set_npc_behavior_mode(npc_id, "work", "mounted_combat_avoid_lock_reset", {"force_idle": true})
	assigned = horse_system.assign_horse_to_npc(npc_id, first_horse_id, "private")
	if not bool(assigned.get("ok", false)):
		_fail("Could not reassign the first horse")
		return
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, "combat", "mounted_combat_test", {
		"state_changes": {"current_action": "combat_ready"},
		"request_plan_reevaluation": false
	})
	if not bool(mode_result.get("ok", false)):
		_fail("Could not enter combat mode")
		return
	var first_horse: Dictionary = horse_system.get_horse_snapshot(first_horse_id)
	var rider_state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(first_horse.get("location", "")) != "stable" or bool(rider_state.get("combat_mounted", true)):
		_fail("Entering combat must leave the horse in its stable while the rider approaches: horse=%s state=%s" % [JSON.stringify(first_horse), JSON.stringify(rider_state)])
		return
	var pickup_movement: Dictionary = first_horse.get("movement_state", {})
	if str(pickup_movement.get("phase", "")) != "waiting_for_rider_at_stable" or not bool(pickup_movement.get("horse_stationary", false)):
		_fail("Stable horse pickup waiting phase is missing")
		return
	if (first_horse.get("world_position", Vector3.ZERO) as Vector3).distance_to(pickup_movement.get("started_position", Vector3.ZERO) as Vector3) > 0.001:
		_fail("Assigned horse moved when combat pickup started")
		return
	var art_snapshot: Dictionary = horse_presenter.get_art_slice_snapshot()
	var moving_visual: Dictionary = (art_snapshot.get("horse_visuals", {}) as Dictionary).get(first_horse_id, {})
	if bool(moving_visual.get("moving_animation", true)) or not str(moving_visual.get("motion_animation", "")).ends_with("Idle"):
		_fail("The assigned horse must remain idle in its stable while waiting: %s" % JSON.stringify(moving_visual))
		return
	var locked_armor: Dictionary = equipment_system.equip_npc_armor(npc_id, "chest", "mail_chest", "private")
	var locked_horse: Dictionary = horse_system.unassign_horse_from_npc(npc_id, "manual", "private")
	if str(locked_armor.get("error", "")) != "loadout_locked_in_wartime" or str(locked_horse.get("reason", "")) != "loadout_locked_in_wartime":
		_fail("Wartime loadout mutations must be rejected: armor=%s horse=%s" % [JSON.stringify(locked_armor), JSON.stringify(locked_horse)])
		return
	npc_panel.show_npc(npc_id)
	await process_frame
	var equipment_button := npc_panel.find_child("NPCGiveWeaponButton", true, false) as Button
	if equipment_button == null or equipment_button.disabled or equipment_button.text != "装备":
		_fail("NPCPanel equipment window entry must remain available during combat")
		return
	var equipment_snapshot: Dictionary = npc_panel.debug_toggle_equipment_window()
	if not bool(equipment_snapshot.get("visible", false)) or not bool(equipment_snapshot.get("locked", false)):
		_fail("NPCPanel equipment window did not open in locked combat state")
		return
	for raw_slot in (equipment_snapshot.get("slots", {}) as Dictionary).values():
		var slot: Dictionary = raw_slot if raw_slot is Dictionary else {}
		if not bool(slot.get("clickable", false)) or not bool(slot.get("dimmed", false)):
			_fail("Locked equipment slots must remain clickable for the refusal notice")
			return
	var locked_press: Dictionary = npc_panel.debug_press_equipment_slot("main_weapon")
	if not bool(locked_press.get("notice_visible", false)):
		_fail("Combat equipment slot click did not show the lock notice")
		return

	if not bool(horse_system.debug_complete_horse_transition(first_horse_id).get("ok", false)):
		_fail("Could not complete the first horse rendezvous")
		return
	first_horse = horse_system.get_horse_snapshot(first_horse_id)
	rider_state = npc_system.get_npc_state(npc_id)
	if str(first_horse.get("location", "")) != "ridden" or str(first_horse.get("ridden_by_npc_id", "")) != npc_id or not bool(rider_state.get("combat_mounted", false)):
		_fail("Rendezvous completion did not enter mounted combat")
		return

	horse_system.debug_set_random_seed(8138)
	var npc_hp_before := int(rider_state.get("hp", 0))
	var horse_hp_before := float(first_horse.get("hp", 0.0))
	var split_attack: Dictionary = combat_system._apply_enemy_attack_to_npc(
		{"id": "test_enemy", "name": "测试敌军"}, npc_id, 20, 20.0, 0.0, 0.0, 0.0
	)
	var horse_damage := int(split_attack.get("horse_damage", -1))
	var npc_damage := int(split_attack.get("npc_damage", -1))
	if horse_damage + npc_damage != 20 or horse_damage < 6 or horse_damage > 10:
		_fail("Mounted damage was not split in the 30%-50% range: %s" % JSON.stringify(split_attack))
		return
	if absf(float(horse_system.get_horse_snapshot(first_horse_id).get("hp", 0.0)) - (horse_hp_before - horse_damage)) > 0.001:
		_fail("Horse HP did not receive its allocated damage before rider HP")
		return
	if int(npc_system.get_npc_state(npc_id).get("hp", 0)) != npc_hp_before - npc_damage:
		_fail("Rider HP did not receive only the remaining damage")
		return

	npc_system.set_npc_behavior_mode(npc_id, "work", "mounted_combat_normal_return_test", {"force_idle": true})
	first_horse = horse_system.get_horse_snapshot(first_horse_id)
	if str(first_horse.get("location", "")) != "returning_stable" or str(first_horse.get("assigned_npc_id", "")) != npc_id:
		_fail("Normal combat exit must start a return while retaining the assignment")
		return
	if not bool(horse_system.debug_complete_horse_transition(first_horse_id).get("ok", false)):
		_fail("Could not complete normal return to stable")
		return
	first_horse = horse_system.get_horse_snapshot(first_horse_id)
	if str(first_horse.get("location", "")) != "stable" or str(first_horse.get("assigned_npc_id", "")) != npc_id:
		_fail("Normal return must leave the horse assigned in its stable")
		return
	npc_system.set_npc_behavior_mode(npc_id, "combat", "mounted_combat_remount_test", {"request_plan_reevaluation": false})
	if not bool(horse_system.debug_complete_horse_transition(first_horse_id).get("ok", false)):
		_fail("Could not remount after a normal stable return")
		return

	first_horse = horse_system.get_horse_snapshot(first_horse_id)
	horse_system.debug_damage(first_horse_id, maxf(0.1, float(first_horse.get("hp", 0.0)) - 1.0))
	var lethal_mount_attack: Dictionary = combat_system._apply_enemy_attack_to_npc(
		{"id": "test_enemy", "name": "测试敌军"}, npc_id, 20, 20.0, 0.0, 0.0, 0.0
	)
	first_horse = horse_system.get_horse_snapshot(first_horse_id)
	if bool(first_horse.get("alive", true)) or str(first_horse.get("location", "")) != "dead":
		_fail("Lethal horse damage did not leave a dead horse record")
		return
	if not horse_system.get_assigned_horse_for_npc(npc_id).is_empty() or not (npc_system.get_npc(npc_id).get("equipment", {}).get("mount", {}) as Dictionary).is_empty():
		_fail("Horse death did not clear both assignment projections")
		return
	if bool(npc_system.get_npc_state(npc_id).get("combat_mounted", true)) or int(lethal_mount_attack.get("npc_damage", 0)) <= 0:
		_fail("Rider did not switch to foot combat after horse death")
		return

	npc_system.set_npc_behavior_mode(npc_id, "work", "mounted_combat_second_reset", {"force_idle": true})
	npc_system.update_npc_state(npc_id, {"hp": 1, "unconscious": false})
	var second_assignment: Dictionary = horse_system.assign_horse_to_npc(npc_id, second_horse_id, "private")
	if not bool(second_assignment.get("ok", false)):
		_fail("Could not assign the surviving second horse: %s" % JSON.stringify(second_assignment))
		return
	npc_system.set_npc_behavior_mode(npc_id, "combat", "mounted_combat_unconscious_test", {"request_plan_reevaluation": false})
	horse_system.debug_complete_horse_transition(second_horse_id)
	var second_hp_before := float(horse_system.get_horse_snapshot(second_horse_id).get("hp", 0.0))
	combat_system._apply_enemy_attack_to_npc(
		{"id": "test_enemy", "name": "测试敌军"}, npc_id, 20, 20.0, 0.0, 0.0, 0.0
	)
	rider_state = npc_system.get_npc_state(npc_id)
	var second_horse: Dictionary = horse_system.get_horse_snapshot(second_horse_id)
	if not bool(rider_state.get("unconscious", false)) or str(second_horse.get("location", "")) != "returning_stable":
		_fail("Rider unconsciousness did not release the surviving horse toward the stable: state=%s horse=%s" % [JSON.stringify(rider_state), JSON.stringify(second_horse)])
		return
	if not str(second_horse.get("assigned_npc_id", "")).is_empty() or not str(second_horse.get("ridden_by_npc_id", "")).is_empty():
		_fail("Rider unconsciousness must immediately clear both sides of the assignment")
		return
	if not bool(second_horse.get("alive", false)) or float(second_horse.get("hp", 0.0)) >= second_hp_before:
		_fail("The surviving horse should retain its battle damage while returning")
		return
	horse_system.debug_complete_horse_transition(second_horse_id)
	second_horse = horse_system.get_horse_snapshot(second_horse_id)
	if str(second_horse.get("location", "")) != "stable" or not str(second_horse.get("assigned_npc_id", "")).is_empty():
		_fail("Released horse did not finish its return as an unassigned stable horse")
		return

	print("T0138 mounted combat lifecycle verification passed.")
	quit(0)


func _latest_event_of_type(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		if str(event.get("type", "")) == event_type:
			return event
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
