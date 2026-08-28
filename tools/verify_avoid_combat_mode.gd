extends SceneTree

var _reevaluation_signal_count := 0


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
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var event_bus := root.get_node_or_null("EventBus")
	if (
		combat_system == null
		or npc_system == null
		or memory_system == null
		or equipment_system == null
		or resource_system == null
		or gm_panel == null
		or daily_plan_system == null
		or event_bus == null
	):
		push_error("Avoid-combat verification required nodes not found")
		quit(1)
		return

	for raw_connection in event_bus.npc_plan_reevaluation_requested.get_connections():
		var connection: Dictionary = raw_connection
		var callable: Callable = connection.get("callable", Callable())
		if callable.get_object() == daily_plan_system:
			event_bus.npc_plan_reevaluation_requested.disconnect(callable)
	event_bus.npc_plan_reevaluation_requested.connect(func(_npc_id: String, _reason: String) -> void:
		if ["cook_01", "engineer_01"].has(_npc_id):
			_reevaluation_signal_count += 1
	)

	var cook_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01") as Node3D
	if cook_node == null:
		push_error("Cook node missing")
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var contact_position: Vector3 = npc_system.get_npc_world_position("cook_01")
	var enemy_position := contact_position + Vector3(0.0, 0.0, 2.5)
	var enemy_id := _place_first_enemy(combat_system, enemy_position)

	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	if _mode(npc_system, "cook_01") != "avoid_combat":
		push_error("Unrecruited working NPC should enter avoid_combat on enemy proximity")
		quit(1)
		return
	var cook_state: Dictionary = npc_system.get_npc_state("cook_01")
	if str(cook_state.get("combat_mode", "")) != "":
		push_error("Avoiding unrecruited NPC should not be marked as combat personnel")
		quit(1)
		return
	if str(cook_state.get("current_action", "")).begins_with("attacking_") or str(cook_state.get("current_action", "")) == "combat_ready":
		push_error("Avoiding unrecruited NPC should not attack or enter combat_ready")
		quit(1)
		return
	var cook_avoidance := _find_avoidance(combat_system.get_active_avoidances(), "cook_01")
	if cook_avoidance.is_empty():
		push_error("Avoiding NPC should have an active avoidance target")
		quit(1)
		return
	var target_position := _dict_to_vector3(cook_avoidance.get("target_position", {}))
	var travel_distance := target_position.distance_to(contact_position)
	if not _inside_station_avoidance_bounds(target_position):
		push_error("Avoidance target should stay inside the station bounds: %s" % str(target_position))
		quit(1)
		return
	if travel_distance < 0.8 or travel_distance > 4.1:
		push_error("Avoidance should move in a short step instead of jumping to a corner: %s" % str(travel_distance))
		quit(1)
		return
	if target_position.distance_to(enemy_position) <= contact_position.distance_to(enemy_position):
		push_error("Avoidance target should be farther from the enemy than the contact position")
		quit(1)
		return
	if _npc_has_mode_event(memory_system, "cook_01", "work", "avoid_combat"):
		push_error("Work-to-avoid_combat should not write npc_mode_changed")
		quit(1)
		return
	if not _npc_has_event(memory_system, "cook_01", "avoidance_started"):
		push_error("Avoidance start should write avoidance_started")
		quit(1)
		return
	print("[T1103B] proximity avoidance checked")

	var engineer_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Engineer01") as Node3D
	if engineer_node == null:
		push_error("Engineer node missing")
		quit(1)
		return
	gm_panel._execute_command("avoid_npc engineer_01")
	await process_frame
	var engineer_avoidance := _find_avoidance(combat_system.get_active_avoidances(), "engineer_01")
	if engineer_avoidance.is_empty():
		push_error("GM avoid_npc command should expose avoidance trigger and target snapshot")
		quit(1)
		return
	var engineer_target := _dict_to_vector3(engineer_avoidance.get("target_position", {}))
	if engineer_target.distance_to(target_position) <= 0.35:
		push_error("Avoidance targets should scatter instead of sending all NPCs to the same point")
		quit(1)
		return

	var reevaluations_before_clear := _reevaluation_signal_count
	combat_system.debug_clear_enemies()
	await process_frame
	if _mode(npc_system, "cook_01") != "work" or _mode(npc_system, "engineer_01") != "work":
		push_error("Avoiding NPCs should return to work when enemies are cleared")
		quit(1)
		return
	if _reevaluation_signal_count != reevaluations_before_clear:
		push_error("Avoidance exit should not request plan reevaluation")
		quit(1)
		return
	if not _npc_has_event(memory_system, "cook_01", "avoidance_ended"):
		push_error("Avoidance end should write avoidance_ended")
		quit(1)
		return
	if _npc_has_mode_event(memory_system, "cook_01", "avoid_combat", "work"):
		push_error("Avoid_combat-to-work should not write npc_mode_changed")
		quit(1)
		return
	print("[T1103B] avoidance clear checked")

	spawn_result = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn for unarmed recruited avoidance failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var stableman_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	if stableman_node == null:
		push_error("Stableman node missing")
		quit(1)
		return
	npc_system.set_npc_recruited("stableman_01", true)
	npc_system.set_npc_equipment_slot("stableman_01", "main_weapon", {})
	var stableman_position: Vector3 = npc_system.get_npc_world_position("stableman_01")
	enemy_position = stableman_position + Vector3(0.0, 0.0, 2.5)
	enemy_id = _place_first_enemy(combat_system, enemy_position)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	if _mode(npc_system, "stableman_01") != "avoid_combat":
		push_error("Recruited NPC without main weapon should enter avoid_combat on enemy proximity")
		quit(1)
		return
	if str(npc_system.get_npc_state("stableman_01").get("combat_mode", "")) != "":
		push_error("Unarmed recruited avoiding NPC should not be marked as combat personnel")
		quit(1)
		return
	print("[T1103C] unarmed recruited proximity avoidance checked")

	spawn_result = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn for sleep test failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var doctor_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Doctor01") as Node3D
	var gardener_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Gardener01") as Node3D
	if doctor_node == null or gardener_node == null:
		push_error("Doctor or gardener node missing")
		quit(1)
		return
	npc_system.set_npc_recruited("doctor_01", true)
	npc_system.set_npc_equipment_slot("doctor_01", "main_weapon", {})
	npc_system.update_npc_state("doctor_01", {"current_action": "sleep_in_dormitory"})
	var doctor_position: Vector3 = npc_system.get_npc_world_position("doctor_01")
	enemy_position = doctor_position + Vector3(0.0, 0.0, 3.0)
	enemy_id = _place_first_enemy(combat_system, enemy_position)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	if _mode(npc_system, "doctor_01") == "avoid_combat":
		push_error("Sleeping unarmed recruited NPC should not avoid from proximity alone")
		quit(1)
		return
	npc_system.apply_damage_to_npc("doctor_01", 1, enemy_id, "local_public", {
		"enemy_attack": true,
		"request_plan_reevaluation": false
	})
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	if _mode(npc_system, "doctor_01") != "avoid_combat":
		push_error("Sleeping unarmed recruited NPC should enter avoid_combat when attacked")
		quit(1)
		return
	npc_system.update_npc_state("gardener_01", {"current_action": "sleep_in_dormitory"})
	npc_system.apply_damage_to_npc("gardener_01", 1, enemy_id, "local_public", {
		"enemy_attack": true,
		"request_plan_reevaluation": false
	})
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	if _mode(npc_system, "gardener_01") != "avoid_combat":
		push_error("Sleeping unrecruited NPC should enter avoid_combat when attacked")
		quit(1)
		return
	if _find_avoidance(combat_system.get_active_avoidances(), "gardener_01").is_empty():
		push_error("Attacked sleeping NPC should receive an avoidance target after mode switch")
		quit(1)
		return
	print("[T1103B] sleeping exception checked")

	combat_system.debug_clear_enemies()
	spawn_result = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn for recruitment routing failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var priest_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Priest01") as Node3D
	if priest_node == null:
		push_error("Priest node missing")
		quit(1)
		return
	var priest_position: Vector3 = npc_system.get_npc_world_position("priest_01")
	enemy_position = priest_position + Vector3(0.0, 0.0, 2.8)
	enemy_id = _place_first_enemy(combat_system, enemy_position)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	if _mode(npc_system, "priest_01") != "avoid_combat":
		push_error("Priest should be avoiding before recruitment routing test")
		quit(1)
		return
	npc_system.set_npc_recruited("priest_01", true)
	await process_frame
	if _mode(npc_system, "priest_01") != "avoid_combat":
		push_error("NPC recruited during avoidance should keep avoiding until assigned a main weapon")
		quit(1)
		return
	if _find_avoidance(combat_system.get_active_avoidances(), "priest_01").is_empty():
		push_error("Avoidance snapshot should remain for recruited NPC without a main weapon")
		quit(1)
		return
	resource_system.add_resource("item_sword_shield", 1)
	var wartime_locked: Dictionary = equipment_system.equip_npc_main_weapon("priest_01", "sword_shield", "private")
	if bool(wartime_locked.get("ok", false)) or str(wartime_locked.get("error", "")) != "loadout_locked_in_wartime":
		push_error("Avoidance must keep the current work-mode-only equipment lock: %s" % JSON.stringify(wartime_locked))
		quit(1)
		return
	npc_system.set_npc_behavior_mode("priest_01", "work", "verify_prepare_wartime_equip", {
		"state_changes": {"current_action": "idle"},
		"request_plan_reevaluation": false
	})
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon("priest_01", "sword_shield", "private")
	if not bool(equip_result.get("ok", false)):
		push_error("Weapon equip after explicitly returning to work failed: %s" % JSON.stringify(equip_result))
		quit(1)
		return
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame
	if _mode(npc_system, "priest_01") != "combat":
		push_error("NPC armed during avoidance should enter combat while enemies remain")
		quit(1)
		return
	if not _find_avoidance(combat_system.get_active_avoidances(), "priest_01").is_empty():
		push_error("Avoidance snapshot should be cleared after armed NPC enters combat")
		quit(1)
		return
	print("[T1103C] recruitment and arming routing checked")

	combat_system.debug_clear_enemies()
	npc_system.set_npc_behavior_mode("blacksmith_01", "avoid_combat", "verify_no_enemy_recruit", {
		"state_changes": {"current_action": "avoid_combat"},
		"request_plan_reevaluation": false
	})
	npc_system.set_npc_recruited("blacksmith_01", true)
	await process_frame
	if _mode(npc_system, "blacksmith_01") != "work":
		push_error("NPC recruited during avoidance with no enemies should return to work")
		quit(1)
		return

	print("T1103B avoid-combat mode verification passed.")
	quit(0)


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))


func _find_avoidance(avoidances: Array, npc_id: String) -> Dictionary:
	for raw_avoidance in avoidances:
		var avoidance: Dictionary = raw_avoidance
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


func _place_first_enemy(combat_system: Node, position: Vector3) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		return ""
	var enemy_id := str(enemy_ids[0])
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["position"] = position
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnemies")
	if formal_root != null:
		for child in formal_root.get_children():
			if str(child.get_meta("enemy_id", "")) == enemy_id and child is Node3D:
				(child as Node3D).global_position = position
				if child.has_method("set_motion_paused"):
					child.set_motion_paused(true)
				break
	elif combat_system.has_method("_refresh_enemy_node"):
		combat_system._refresh_enemy_node(enemy_id)
	return enemy_id


func _dict_to_vector3(raw_value: Variant) -> Vector3:
	if raw_value is Vector3:
		return raw_value
	var data: Dictionary = raw_value if raw_value is Dictionary else {}
	return Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)


func _inside_station_avoidance_bounds(position: Vector3) -> bool:
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if controller != null and controller.has_method("get_production_navigation_map_rid"):
		var navigation_map: RID = controller.get_production_navigation_map_rid()
		if navigation_map.is_valid():
			return NavigationServer3D.map_get_closest_point(navigation_map, position).distance_to(position) <= 0.2
	return absf(position.x) <= 13.0 and position.z >= -12.5 and position.z <= 6.5


func _npc_has_event(memory_system: Node, npc_id: String, event_type: String) -> bool:
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type:
			return true
	return false


func _npc_has_mode_event(memory_system: Node, npc_id: String, from_mode: String, to_mode: String) -> bool:
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) != "npc_mode_changed":
			continue
		var payload: Dictionary = event.get("payload", {})
		if str(payload.get("from_mode", "")) == from_mode and str(payload.get("to_mode", "")) == to_mode:
			return true
	return false
