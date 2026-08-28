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
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var alarm_button := root.get_node_or_null("Main/UI/HUD/AlarmButton") as Button
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or horse_system == null
		or memory_system == null
		or gm_panel == null
		or alarm_button == null
	):
		push_error("Combat alarm rally verification required nodes not found")
		quit(1)
		return

	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("item_sword_shield", 1)
	resource_system.add_resource("item_bow", 1)
	if not bool(equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private").get("ok", false)):
		push_error("Failed to equip stableman for rally verification")
		quit(1)
		return
	if not bool(equipment_system.equip_npc_main_weapon("veteran_deputy_01", "bow", "private").get("ok", false)):
		push_error("Failed to equip veteran for rally verification")
		quit(1)
		return
	var available_horses: Array = horse_system.get_available_horses_for_npc("veteran_deputy_01")
	if available_horses.is_empty():
		push_error("No initial adult horse available for rally verification")
		quit(1)
		return
	var horse_id := str((available_horses[0] as Dictionary).get("horse_id", ""))
	if not bool(equipment_system.equip_npc_mount("veteran_deputy_01", horse_id, "private").get("ok", false)):
		push_error("Failed to equip veteran mount for rally verification")
		quit(1)
		return

	alarm_button.pressed.emit()
	await process_frame

	var alarm_result: Dictionary = combat_system.get_last_alarm_result()
	if not bool(alarm_result.get("ok", false)):
		push_error("HUD alarm should trigger CombatSystem: %s" % JSON.stringify(alarm_result))
		quit(1)
		return
	if int(alarm_result.get("heard_count", 0)) != int(npc_system.get_npc_count()):
		push_error("Combat alarm should write one alarm event for every NPC")
		quit(1)
		return
	if int(alarm_result.get("rallied_count", 0)) != 2:
		push_error("Only recruited armed NPCs should rally. result=%s" % JSON.stringify(alarm_result))
		quit(1)
		return
	if not _ignored_reason(alarm_result, "cook_01", "not_recruited"):
		push_error("Unrecruited cook should not respond to alarm")
		quit(1)
		return

	var stableman_state: Dictionary = npc_system.get_npc_state("stableman_01")
	var veteran_state: Dictionary = npc_system.get_npc_state("veteran_deputy_01")
	if str(stableman_state.get("combat_mode", "")) != "rally" or str(veteran_state.get("combat_mode", "")) != "rally":
		push_error("Armed recruited NPCs should enter rally mode")
		quit(1)
		return
	if bool(stableman_state.get("combat_mounted", true)):
		push_error("Weapon-only NPC should not show mounted combat visual")
		quit(1)
		return
	if bool(veteran_state.get("combat_mounted", false)) or str(veteran_state.get("combat_mount_phase", "")) != "going_to_stable_horse":
		push_error("Assigned rider should walk to the stable horse before becoming mounted")
		quit(1)
		return
	var meeting_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var meeting_movement: Dictionary = meeting_horse.get("movement_state", {})
	if str(meeting_horse.get("location", "")) != "stable" or str(meeting_movement.get("phase", "")) != "waiting_for_rider_at_stable" or not bool(meeting_movement.get("horse_stationary", false)):
		push_error("Assigned horse should remain stationary in its stable during rally")
		quit(1)
		return
	if not bool(horse_system.debug_complete_horse_transition(horse_id).get("ok", false)):
		push_error("Could not complete horse-rider rendezvous in rally verification")
		quit(1)
		return
	await process_frame
	veteran_state = npc_system.get_npc_state("veteran_deputy_01")
	if not bool(veteran_state.get("combat_mounted", false)):
		push_error("NPC should become mounted after meeting the assigned horse")
		quit(1)
		return

	var rallies: Array = combat_system.get_active_rallies()
	var stableman_rally := _find_rally(rallies, "stableman_01")
	var veteran_rally := _find_rally(rallies, "veteran_deputy_01")
	if stableman_rally.is_empty() or veteran_rally.is_empty():
		push_error("Active rally snapshot should include both responding NPCs")
		quit(1)
		return
	if (
		str(stableman_rally.get("formation_row", "")) != "melee_front"
		or not str(veteran_rally.get("formation_row", "")).begins_with("cavalry_")
	):
		push_error("Melee should rally in the center front and mounted units on a wing: %s" % JSON.stringify(rallies))
		quit(1)
		return
	var stable_pos: Dictionary = stableman_rally.get("position", {})
	var veteran_pos: Dictionary = veteran_rally.get("position", {})
	if (
		float(stable_pos.get("z", 0.0)) <= float(veteran_pos.get("z", 0.0))
		or absf(float(veteran_pos.get("x", 0.0)) - 5.0) < 4.0
	):
		push_error("Frontline should face the enemy while the mounted unit holds a side wing")
		quit(1)
		return

	if not _npc_has_event(memory_system, "cook_01", "combat_alarm_rang"):
		push_error("Combat alarm event should be written to all NPC event logs")
		quit(1)
		return
	if not _npc_has_event(memory_system, "stableman_01", "combat_rally_started"):
		push_error("Responding NPC should receive combat_rally_started event")
		quit(1)
		return

	var npc_node_paths: Dictionary = npc_system.get("_npc_nodes")
	var veteran_node := npc_system.get_node_or_null(npc_node_paths.get("veteran_deputy_01", NodePath("")))
	var art_snapshot: Dictionary = veteran_node.debug_get_character_art_snapshot() if veteran_node != null and veteran_node.has_method("debug_get_character_art_snapshot") else {}
	if not bool(art_snapshot.get("combat_mount_visual_visible", false)) or not bool(art_snapshot.get("combat_mount_uses_imported_horse", false)):
		push_error("Mounted NPC should display the formal imported horse during rally: %s" % JSON.stringify(art_snapshot))
		quit(1)
		return

	combat_system.debug_clear_enemies()
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Failed to spawn enemies for encounter verification")
		quit(1)
		return
	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var stableman_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	stableman_node.global_position = enemy_position + Vector3(0.0, 0.0, -1.0)
	combat_system.debug_trigger_combat_alarm()
	combat_system.debug_step_enemy_ai(0.1)
	stableman_state = npc_system.get_npc_state("stableman_01")
	var encounter_action := str(stableman_state.get("current_action", ""))
	if (
		str(stableman_state.get("combat_mode", "")) != "combat"
		or (
			encounter_action != "combat_ready"
			and not encounter_action.begins_with("attacking_")
			and not encounter_action.begins_with("winding_up_")
		)
	):
		push_error("NPC encountering enemy during rally should switch to combat readiness or attack: %s" % JSON.stringify(stableman_state))
		quit(1)
		return
	if not _npc_has_event(memory_system, "stableman_01", "combat_rally_encountered_enemy"):
		push_error("Rally encounter should write a structured event")
		quit(1)
		return

	gm_panel._execute_command("rally")
	if not bool(combat_system.get_last_alarm_result().get("ok", false)):
		push_error("GM rally command should trigger combat alarm")
		quit(1)
		return

	print("Combat alarm rally verification passed.")
	quit(0)


func _ignored_reason(alarm_result: Dictionary, npc_id: String, reason: String) -> bool:
	for raw_item in alarm_result.get("ignored", []):
		var item: Dictionary = raw_item
		if str(item.get("npc_id", "")) == npc_id and str(item.get("reason", "")) == reason:
			return true
	return false


func _find_rally(rallies: Array, npc_id: String) -> Dictionary:
	for raw_rally in rallies:
		var rally: Dictionary = raw_rally
		if str(rally.get("npc_id", "")) == npc_id:
			return rally
	return {}


func _npc_has_event(memory_system: Node, npc_id: String, event_type: String) -> bool:
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type:
			return true
	return false
