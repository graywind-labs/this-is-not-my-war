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
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var game_state := root.get_node_or_null("/root/GameState")
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or time_system == null
		or hud == null
		or game_state == null
	):
		push_error("No-available-combatants verification required nodes not found")
		quit(1)
		return

	time_system.set_current_time(5, 20, 10, 0)
	time_system.set_paused(false)
	npc_system.set_npc_recruited("stableman_01", true)
	npc_system.set_npc_recruited("veteran_deputy_01", true)
	resource_system.add_resource("item_sword_shield", 1)
	resource_system.add_resource("item_bow", 1)
	var stableman_weapon: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	var veteran_weapon: Dictionary = equipment_system.equip_npc_main_weapon("veteran_deputy_01", "bow", "private")
	if not bool(stableman_weapon.get("ok", false)) or not bool(veteran_weapon.get("ok", false)):
		push_error("Failed to equip combatants: %s / %s" % [JSON.stringify(stableman_weapon), JSON.stringify(veteran_weapon)])
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	if bool(game_state.get("game_over")):
		push_error("Spawning a wave must not end the game before the main hall is destroyed")
		quit(1)
		return
	if _mode(npc_system, "stableman_01") != "work" or _mode(npc_system, "veteran_deputy_01") != "work":
		push_error("Verification setup expects combatants to still be in work mode before contact")
		quit(1)
		return

	var initial_availability: Dictionary = _availability(combat_system)
	if int(initial_availability.get("total_combatant_count", 0)) < 2:
		push_error("Availability snapshot should count both armed combatants: %s" % JSON.stringify(initial_availability))
		quit(1)
		return
	if int(initial_availability.get("available_combatant_count", 0)) < 2:
		push_error("Unrallied armed combatants should still be available: %s" % JSON.stringify(initial_availability))
		quit(1)
		return

	var escape_result: Dictionary = combat_system.start_npc_escape("stableman_01", "", "verify_escape", {
		"trigger": "verify_escape",
		"interaction_context": "verify_no_available_combatants"
	})
	if not bool(escape_result.get("ok", false)):
		push_error("Combatant escape setup failed: %s" % JSON.stringify(escape_result))
		quit(1)
		return
	if bool(game_state.get("game_over")):
		push_error("One escaping combatant should not fail while another combatant is available")
		quit(1)
		return
	var after_escape_availability: Dictionary = _availability(combat_system)
	if int(after_escape_availability.get("available_combatant_count", 0)) != 1:
		push_error("Exactly one combatant should remain available after first escape: %s" % JSON.stringify(after_escape_availability))
		quit(1)
		return
	if _find_unavailable_reason(after_escape_availability, "stableman_01") != "escaping":
		push_error("Escaping combatant should be marked unavailable because of escaping")
		quit(1)
		return

	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var damage_result: Dictionary = npc_system.apply_damage_to_npc("veteran_deputy_01", 999, enemy_id, "local_public", {
		"request_plan_reevaluation": false
	})
	if not bool(damage_result.get("unconscious", false)):
		push_error("Second combatant should become unconscious: %s" % JSON.stringify(damage_result))
		quit(1)
		return
	await process_frame

	if bool(game_state.get("game_over")):
		push_error("All combatants unavailable must not end the game while the main hall survives")
		quit(1)
		return
	if str(game_state.get("game_result")) != "":
		push_error("Removing the legacy no-combatant ending must leave the game result unset")
		quit(1)
		return
	if not str(game_state.get("failure_reason")).is_empty():
		push_error("Removing the legacy no-combatant ending must leave failure_reason empty")
		quit(1)
		return
	if bool(time_system.is_gameplay_paused()):
		push_error("Gameplay must continue after all combatants become unavailable")
		quit(1)
		return

	var combat_step: Dictionary = combat_system.debug_step_enemy_ai(1.0)
	if combat_step.is_empty() or combat_system.get_active_enemy_count() <= 0:
		push_error("Enemy and defense-device battle flow should continue without available NPC combatants")
		quit(1)
		return

	var final_snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	var failure_result: Dictionary = final_snapshot.get("last_failure_result", {}) if final_snapshot.get("last_failure_result", {}) is Dictionary else {}
	if not failure_result.is_empty():
		push_error("Combat snapshot must not contain a legacy no-combatant failure: %s" % JSON.stringify(failure_result))
		quit(1)
		return
	var final_availability: Dictionary = _availability(combat_system)
	if int(final_availability.get("available_combatant_count", -1)) != 0:
		push_error("Diagnostic availability should still report zero available combatants: %s" % JSON.stringify(final_availability))
		quit(1)
		return
	if _find_unavailable_reason(final_availability, "stableman_01") != "escaping":
		push_error("Diagnostic availability should record the escaping combatant")
		quit(1)
		return
	if _find_unavailable_reason(final_availability, "veteran_deputy_01") != "unconscious":
		push_error("Diagnostic availability should record the unconscious combatant")
		quit(1)
		return

	var game_over_panel := hud.get_node_or_null("GameOverPanel") as PanelContainer
	if game_over_panel == null or game_over_panel.visible:
		push_error("HUD must stay out of game-over state while the main hall survives")
		quit(1)
		return

	print("Main-hall-only failure contract verification passed.")
	quit(0)


func _availability(combat_system: Node) -> Dictionary:
	var snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	return snapshot.get("combatant_availability", {}) if snapshot.get("combatant_availability", {}) is Dictionary else {}


func _find_unavailable_reason(availability: Dictionary, npc_id: String) -> String:
	for raw_entry in (availability.get("unavailable_combatants", []) as Array):
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if str(entry.get("npc_id", "")) == npc_id:
			return str(entry.get("unavailable_reason", ""))
	return ""


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.debug_get_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))
