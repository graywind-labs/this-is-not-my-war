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
		push_error("Armed combatants should prevent no-combatant failure before rally or contact")
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

	if not bool(game_state.get("game_over")):
		push_error("All available combatants gone should set GameState.game_over")
		quit(1)
		return
	if str(game_state.get("game_result")) != "failure":
		push_error("Game result should be failure")
		quit(1)
		return
	if str(game_state.get("failure_reason")) != "no_available_combatants":
		push_error("Failure reason should be no_available_combatants, got: %s" % str(game_state.get("failure_reason")))
		quit(1)
		return
	if int(game_state.get("game_over_day")) != 5 or int(game_state.get("game_over_hour")) != 20:
		push_error("Failure timestamp should use current game time")
		quit(1)
		return
	if not bool(time_system.is_gameplay_paused()):
		push_error("TimeSystem should pause gameplay after no-combatant failure")
		quit(1)
		return

	var final_snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	var failure_result: Dictionary = final_snapshot.get("last_failure_result", {}) if final_snapshot.get("last_failure_result", {}) is Dictionary else {}
	if str(failure_result.get("reason", "")) != "no_available_combatants":
		push_error("Combat snapshot should expose no-combatant failure: %s" % JSON.stringify(failure_result))
		quit(1)
		return
	var final_availability: Dictionary = failure_result.get("combatant_availability", {}) if failure_result.get("combatant_availability", {}) is Dictionary else {}
	if int(final_availability.get("available_combatant_count", -1)) != 0:
		push_error("Failure availability should have zero available combatants: %s" % JSON.stringify(final_availability))
		quit(1)
		return
	if _find_unavailable_reason(final_availability, "stableman_01") != "escaping":
		push_error("Failure should record escaping combatant")
		quit(1)
		return
	if _find_unavailable_reason(final_availability, "veteran_deputy_01") != "unconscious":
		push_error("Failure should record unconscious combatant")
		quit(1)
		return

	var game_over_panel := hud.get_node_or_null("GameOverPanel") as PanelContainer
	if game_over_panel == null or not game_over_panel.visible:
		push_error("HUD should display game-over panel for no-combatant failure")
		quit(1)
		return
	var reason_label := game_over_panel.find_child("GameOverReasonLabel", true, false) as Label
	if reason_label == null or not reason_label.text.contains("无可战斗人员"):
		push_error("HUD should show readable no-combatant failure reason")
		quit(1)
		return

	print("No available combatants failure verification passed.")
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
