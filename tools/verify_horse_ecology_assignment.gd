extends SceneTree

const EPSILON := 0.001


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if horse_system == null or building_system == null or resource_system == null or npc_system == null or action_system == null or equipment_system == null or memory_system == null or building_panel == null or npc_panel == null:
		_fail("Required horse integration nodes are missing")
		return

	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.size() != 2:
		_fail("A new game must start with exactly two horses")
		return
	var first_id := str(horse_ids[0])
	var second_id := str(horse_ids[1])
	var first: Dictionary = horse_system.get_horse_snapshot(first_id)
	var second: Dictionary = horse_system.get_horse_snapshot(second_id)
	if not bool(first.get("is_adult", false)) or not bool(second.get("is_adult", false)):
		_fail("Both initial horses must be adult")
		return
	if [str(first.get("name", "")), str(second.get("name", ""))] != ["栗风", "灰鬃"]:
		_fail("Initial horse names/config order mismatch")
		return
	if not _assert_stable_special(building_system, 2, 2, 0):
		return

	var hp_before := float(first.get("hp", 0.0))
	var satiety_before := float(first.get("satiety", 0.0))
	if not bool(horse_system.debug_damage(first_id, 10.0).get("ok", false)):
		_fail("Could not damage the first horse")
		return
	horse_system.debug_advance(3600.0)
	first = horse_system.get_horse_snapshot(first_id)
	if absf(float(first.get("hp", 0.0)) - (hp_before - 9.8)) > EPSILON:
		_fail("Stable natural healing should restore exactly 0.2 HP per hour")
		return
	if absf(float(first.get("satiety", 0.0)) - (satiety_before - 0.6)) > EPSILON:
		_fail("Stable horse satiety must combine 0.5 upkeep and 0.1 healing cost")
		return

	resource_system.add_resource("grain", -999999)
	resource_system.add_resource("grain", 5)
	var grain_before := int(resource_system.get_resource("grain"))
	_set_horse_runtime_value(horse_system, first_id, "satiety", 60.0)
	horse_system.debug_advance(60.0)
	first = horse_system.get_horse_snapshot(first_id)
	if not bool((first.get("feeding", {}) as Dictionary).get("active", false)):
		_fail("A stable horse with at least 20% satiety missing must start feeding")
		return
	horse_system.debug_advance(1140.0)
	if int(resource_system.get_resource("grain")) != grain_before:
		_fail("Horse feeding must not spend grain before the full cycle finishes")
		return
	horse_system.debug_advance(60.0)
	first = horse_system.get_horse_snapshot(first_id)
	if int(resource_system.get_resource("grain")) != grain_before - 1 or bool((first.get("feeding", {}) as Dictionary).get("active", false)):
		_fail("Horse feeding must atomically spend one grain at cycle completion")
		return

	var stable_observer_id := "stableman_01"
	var outside_observer_id := "cook_01"
	var stable_entry_witness_start := int(memory_system.get_npc_witness_events(stable_observer_id).size())
	if not npc_system.debug_enter_location_immediately(stable_observer_id, "stable"):
		_fail("Could not move the horse-state observer into the stable")
		return
	var entry_witnesses := _events_after(
		memory_system.get_npc_witness_events(stable_observer_id),
		stable_entry_witness_start
	)
	var stable_entry_snapshot_event := _find_location_state_event(entry_witnesses, "location_entry_snapshot")
	if stable_entry_snapshot_event.is_empty():
		_fail("Entering the stable must create a location_entry_snapshot witness event")
		return
	var stable_entry_snapshot: Dictionary = stable_entry_snapshot_event.get("payload", {}).get("location_snapshot", {})
	if not _assert_horse_special_state_shape(
		stable_entry_snapshot.get("special_state", {}),
		{"total": 2, "adult": 2, "foal": 0},
		"stable entry snapshot special_state"
	):
		return
	if not _assert_horse_special_state_shape(
		stable_entry_snapshot.get("internal_state", {}).get("special_state", {}),
		{"total": 2, "adult": 2, "foal": 0},
		"stable entry snapshot internal_state.special_state"
	):
		return
	if not _assert_horse_special_state_shape(
		stable_entry_snapshot.get("building", {}).get("special_state", {}),
		{"total": 2, "adult": 2, "foal": 0},
		"stable entry snapshot building.special_state"
	):
		return
	if not _assert_horse_special_state_shape(
		stable_entry_snapshot.get("building", {}).get("internal_state", {}).get("special_state", {}),
		{"total": 2, "adult": 2, "foal": 0},
		"stable entry snapshot building.internal_state.special_state"
	):
		return

	var stable_witnesses_before_birth := int(memory_system.get_npc_witness_events(stable_observer_id).size())
	var outside_witnesses_before_birth := int(memory_system.get_npc_witness_events(outside_observer_id).size())
	var birth: Dictionary = horse_system.debug_force_birth()
	if not bool(birth.get("ok", false)):
		_fail("Could not create a verification foal")
		return
	var stable_birth_witnesses := _events_after(
		memory_system.get_npc_witness_events(stable_observer_id),
		stable_witnesses_before_birth
	)
	var stable_horse_delta_event := _find_location_state_event(
		stable_birth_witnesses,
		"building_internal_special_state_changed"
	)
	if stable_horse_delta_event.is_empty():
		_fail("A present stable NPC must receive the horse-count special-state delta")
		return
	var changed_special_state: Dictionary = stable_horse_delta_event.get("payload", {}).get("changed_special_state", {})
	if not _assert_horse_special_state_shape(
		changed_special_state,
		{"total": 3, "foal": 1},
		"stable horse-count delta"
	):
		return
	var outside_birth_witnesses := _events_after(
		memory_system.get_npc_witness_events(outside_observer_id),
		outside_witnesses_before_birth
	)
	if not _find_location_state_event(
		outside_birth_witnesses,
		"building_internal_special_state_changed"
	).is_empty():
		_fail("An NPC outside the stable must not receive its internal horse-count delta")
		return
	var foal_id := str(birth.get("horse_id", ""))
	var foal: Dictionary = horse_system.get_horse_snapshot(foal_id)
	if bool(foal.get("is_adult", true)) or absf(float(foal.get("natural_max_hp", 0.0)) - 40.0) > EPSILON or absf(float(foal.get("max_satiety", 0.0)) - 50.0) > EPSILON:
		_fail("A newborn must be a 40 HP / 50 satiety-cap foal")
		return
	if not _assert_stable_special(building_system, 3, 2, 1):
		return
	horse_system.debug_advance(600.0)
	if float(horse_system.get_horse_snapshot(foal_id).get("growth", -1.0)) != 0.0:
		_fail("Foals must not grow without an active stable caretaker")
		return

	var stableman_id := "stableman_01"
	action_system.interrupt_npc_action(stableman_id, "horse_verification_reset")
	npc_system.debug_enter_location_immediately(stableman_id, "stable")
	npc_system.update_npc_state(stableman_id, {"satiety": 90, "fatigue": 0})
	if not action_system.debug_assign_work(stableman_id, "stable"):
		_fail("Could not start work_stable for care verification")
		return
	if not await _wait_until_current_action(npc_system, stableman_id, "work_stable"):
		_fail("Stable caretaker never entered active work")
		return
	horse_system.debug_advance(600.0)
	foal = horse_system.get_horse_snapshot(foal_id)
	first = horse_system.get_horse_snapshot(first_id)
	if float(foal.get("growth", 0.0)) <= 0.0:
		_fail("Active horsemanship care must advance foal growth")
		return
	if float(first.get("care_bonus_cap", 0.0)) <= 0.0:
		_fail("Active horsemanship care must cultivate a skill-scaled bonus HP cap")
		return
	action_system.interrupt_npc_action(stableman_id, "horse_verification_care_complete")

	var rider_id := "veteran_deputy_01"
	var rider: Dictionary = npc_system.get_npc(rider_id)
	if not bool(rider.get("recruited", false)) or (rider.get("equipment", {}).get("main_weapon", {}) as Dictionary).is_empty():
		_fail("Verification rider must start recruited with story sword-shield")
		return
	var foal_assignment: Dictionary = horse_system.assign_horse_to_npc(rider_id, foal_id, "private")
	if bool(foal_assignment.get("ok", false)) or str(foal_assignment.get("reason", "")) != "horse_not_adult":
		_fail("A foal must never be assignable: %s" % JSON.stringify(foal_assignment))
		return
	npc_panel.show_npc(rider_id)
	await process_frame
	var horse_select := npc_panel.find_child("NPCHorseSelect", true, false) as OptionButton
	var horse_assign_button := npc_panel.find_child("NPCAssignHorseButton", true, false) as Button
	var horse_status_label := npc_panel.find_child("NPCHorseStatusLabel", true, false) as Label
	if horse_select == null or horse_assign_button == null or horse_status_label == null:
		_fail("NPCPanel concrete horse assignment controls are missing")
		return
	if horse_status_label.visible or not horse_status_label.text.is_empty():
		_fail("An eligible NPC with no assigned horse should not show redundant explanatory copy")
		return
	var adult_horse_index := _find_option_by_metadata(horse_select, first_id)
	if adult_horse_index < 0 or _find_option_by_metadata(horse_select, foal_id) >= 0:
		_fail("NPCPanel must list the available adult horse and exclude foals")
		return
	horse_select.select(adult_horse_index)
	horse_select.item_selected.emit(adult_horse_index)
	await process_frame
	if horse_assign_button.disabled:
		_fail("Selecting an eligible adult horse must immediately enable the assign button")
		return
	horse_assign_button.pressed.emit()
	await process_frame
	if horse_system.get_assigned_horse_for_npc(rider_id).is_empty():
		_fail("NPCPanel failed to assign the selected adult horse")
		return
	first = horse_system.get_horse_snapshot(first_id)
	if str(first.get("location", "")) != "stable" or str(first.get("assigned_npc_id", "")) != rider_id:
		_fail("An assigned horse must remain physically in the stable during work mode")
		return
	if not _assert_stable_special(building_system, 3, 2, 1):
		return

	npc_system.update_npc_state(rider_id, {"behavior_mode": "rally"})
	await process_frame
	first = horse_system.get_horse_snapshot(first_id)
	var pickup_movement: Dictionary = first.get("movement_state", {})
	if str(first.get("location", "")) != "stable" or str(pickup_movement.get("phase", "")) != "waiting_for_rider_at_stable" or not bool(pickup_movement.get("horse_stationary", false)) or bool(npc_system.get_npc_state(rider_id).get("combat_mounted", true)):
		_fail("Assigned horse must wait in the stable while its rider approaches")
		return
	if not bool(horse_system.debug_complete_horse_transition(first_id).get("ok", false)):
		_fail("Could not complete the horse-rider rendezvous")
		return
	first = horse_system.get_horse_snapshot(first_id)
	if str(first.get("location", "")) != "ridden" or str(first.get("ridden_by_npc_id", "")) != rider_id:
		_fail("Assigned adult horse must become ridden after the rendezvous")
		return
	if not _assert_stable_special(building_system, 2, 1, 1):
		return
	var ridden_satiety_cap := float(first.get("max_satiety", 0.0))
	_set_horse_runtime_value(horse_system, first_id, "satiety", ridden_satiety_cap)
	var ridden_hp_before := float(first.get("hp", 0.0))
	horse_system.debug_damage(first_id, 10.0)
	horse_system.debug_advance(3600.0)
	first = horse_system.get_horse_snapshot(first_id)
	if absf(float(first.get("hp", 0.0)) - (ridden_hp_before - 9.8)) > EPSILON:
		_fail("Ridden horses must retain slow natural healing")
		return
	if absf(float(first.get("satiety", 0.0)) - (ridden_satiety_cap - 2.1)) > EPSILON:
		_fail("Ridden horse satiety must combine 2.0 outside upkeep and 0.1 healing cost")
		return
	if bool((first.get("feeding", {}) as Dictionary).get("active", false)):
		_fail("A horse must never start feeding outside the stable")
		return

	npc_system.update_npc_state(rider_id, {"behavior_mode": "work"})
	await process_frame
	if str(horse_system.get_horse_snapshot(first_id).get("location", "")) != "returning_stable":
		_fail("Horse must run back toward the stable when wartime mode ends")
		return
	if not bool(horse_system.debug_complete_horse_transition(first_id).get("ok", false)):
		_fail("Could not complete the horse return transition")
		return
	if str(horse_system.get_horse_snapshot(first_id).get("location", "")) != "stable":
		_fail("Horse must reach the stable after its return transition")
		return
	var unequip_result: Dictionary = equipment_system.unequip_npc_slot(rider_id, "main_weapon", "private")
	if not bool(unequip_result.get("ok", false)):
		_fail("Could not reclaim the rider's main weapon: %s" % JSON.stringify(unequip_result))
		return
	if not horse_system.get_assigned_horse_for_npc(rider_id).is_empty():
		_fail("Reclaiming the main weapon must automatically unassign the horse entity")
		return
	var rider_equipment: Dictionary = npc_system.get_npc(rider_id).get("equipment", {})
	if not (rider_equipment.get("mount", {}) as Dictionary).is_empty():
		_fail("Automatic horse unassignment must also clear the NPC mount projection")
		return

	building_panel.show_building("stable")
	npc_panel.show_npc(rider_id)
	await process_frame
	if not building_panel.visible or not npc_panel.visible:
		_fail("Stable and NPC horse panels must be reachable from Main UI")
		return
	if horse_status_label == null or not horse_status_label.text.contains("没有主武器"):
		_fail("NPCPanel must explain why a recruited but unarmed NPC cannot receive a horse")
		return
	npc_panel.show_npc("cook_01")
	await process_frame
	if horse_status_label.visible or not horse_status_label.text.is_empty():
		_fail("An unrecruited NPC should not show the redundant horse-assignment explanation")
		return

	print("T0037/T0038 horse ecology and assignment verification passed.")
	quit(0)


func _assert_stable_special(building_system: Node, total: int, adult: int, foal: int) -> bool:
	var state: Dictionary = building_system.get_building_special_state_section("stable", "horses")
	if int(state.get("total", -1)) != total or int(state.get("adult", -1)) != adult or int(state.get("foal", -1)) != foal:
		_fail("Stable special-state count mismatch: %s" % JSON.stringify(state))
		return false
	return true


func _set_horse_runtime_value(horse_system: Node, horse_id: String, key: String, value: Variant) -> void:
	var horse: Dictionary = horse_system._horses.get(horse_id, {}).duplicate(true)
	horse[key] = value
	horse_system._horses[horse_id] = horse


func _find_option_by_metadata(select: OptionButton, expected: String) -> int:
	for index in range(select.item_count):
		if str(select.get_item_metadata(index)) == expected:
			return index
	return -1


func _assert_horse_special_state_shape(raw_state: Variant, expected_horses: Dictionary, context: String) -> bool:
	if not raw_state is Dictionary:
		_fail("%s must be a dictionary" % context)
		return false
	var special_state: Dictionary = raw_state
	if special_state.size() != 1 or not special_state.has("horses") or not special_state.get("horses") is Dictionary:
		_fail("%s must expose only the horses section: %s" % [context, JSON.stringify(special_state)])
		return false
	var horses: Dictionary = special_state.get("horses", {})
	if horses.size() != expected_horses.size():
		_fail("%s leaked fields or repeated unchanged fields: %s" % [context, JSON.stringify(horses)])
		return false
	for raw_key in horses.keys():
		var key := str(raw_key)
		if not ["total", "adult", "foal"].has(key) or not expected_horses.has(key):
			_fail("%s exposed forbidden horse field '%s': %s" % [context, key, JSON.stringify(horses)])
			return false
	for raw_key in expected_horses.keys():
		var key := str(raw_key)
		if int(horses.get(key, -1)) != int(expected_horses.get(key, -1)):
			_fail("%s horse-count mismatch: %s" % [context, JSON.stringify(horses)])
			return false
	return true


func _find_location_state_event(events: Array, reason: String) -> Dictionary:
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		if str(event.get("type", "")) != "location_status_changed":
			continue
		if str(event.get("payload", {}).get("reason", "")) == reason:
			return event
	return {}


func _events_after(events: Array, start_index: int) -> Array:
	var result: Array = []
	for index in range(start_index, events.size()):
		result.append(events[index])
	return result


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for _frame in range(600):
		await process_frame
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) == expected_action:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
