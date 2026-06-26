extends SceneTree

const CLOSED_BACKEND_URL := "http://127.0.0.1:5999"


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
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
		or llm_bridge == null
		or dialog_system == null
	):
		push_error("Low HP judgement verification required nodes not found")
		quit(1)
		return

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()
	llm_bridge.set_backend_base_url(CLOSED_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 0.1

	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("weapons", 1)
	var weapon_result: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	if not bool(weapon_result.get("ok", false)):
		push_error("Failed to equip stableman: %s" % JSON.stringify(weapon_result))
		quit(1)
		return
	var order_result: Dictionary = npc_system.publish_npc_order("stableman_01", "守住城门，但受伤时先活下来。")
	if not bool(order_result.get("ok", false)):
		push_error("Failed to publish stableman order: %s" % JSON.stringify(order_result))
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Failed to spawn enemies: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var enemy_id := _first_enemy_id(combat_system)
	if enemy_id.is_empty():
		push_error("Spawned wave should expose at least one enemy id")
		quit(1)
		return
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var enemy_name := str(enemy.get("name", enemy_id))

	var mode_result: Dictionary = npc_system.set_npc_behavior_mode("stableman_01", "combat", "verify_low_hp_combat", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id
		},
		"request_plan_reevaluation": false
	})
	if not bool(mode_result.get("ok", false)):
		push_error("Failed to set stableman combat mode: %s" % JSON.stringify(mode_result))
		quit(1)
		return

	var combat_damage: Dictionary = npc_system.apply_damage_to_npc("stableman_01", 75, enemy_id, "local_public", {
		"enemy_attack": true,
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"request_plan_reevaluation": false
	})
	if not bool(combat_damage.get("ok", false)):
		push_error("Failed to damage combat NPC")
		quit(1)
		return
	await process_frame
	await process_frame

	var snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	var low_hp_result: Dictionary = snapshot.get("last_low_hp_judgement_result", {})
	if not bool(low_hp_result.get("triggered", false)):
		push_error("Combat NPC low HP should trigger judgement: %s" % JSON.stringify(low_hp_result))
		quit(1)
		return
	if str(low_hp_result.get("npc_id", "")) != "stableman_01":
		push_error("Last low HP result should belong to stableman: %s" % JSON.stringify(low_hp_result))
		quit(1)
		return
	if str(low_hp_result.get("decision", "")) != "continue_fighting":
		push_error("Combat fallback should continue fighting as first allowed decision: %s" % JSON.stringify(low_hp_result))
		quit(1)
		return
	if not bool(low_hp_result.get("combatant_decisions_allowed", false)):
		push_error("Combat eligible NPC should allow combat decisions")
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "low_hp_triggered", "stableman_01").is_empty():
		push_error("Combat low HP should write low_hp_triggered plaza event")
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "battle_psychology_result", "stableman_01").is_empty():
		push_error("Combat low HP should write battle_psychology_result plaza event")
		quit(1)
		return
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	if str(injection.get("call_type", "")) != "battle_judgement" or str(injection.get("npc_id", "")) != "stableman_01":
		push_error("Low HP judgement should expose battle_judgement context injection: %s" % JSON.stringify(injection))
		quit(1)
		return
	if str(injection.get("current_order", {}).get("text", "")) != "守住城门，但受伤时先活下来。":
		push_error("Battle judgement payload should include latest current_order: %s" % JSON.stringify(injection))
		quit(1)
		return
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Combat low HP judgement left pending slowdown request")
		quit(1)
		return

	npc_system.apply_damage_to_npc("stableman_01", 1, enemy_id, "local_public", {
		"enemy_attack": true,
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"request_plan_reevaluation": false
	})
	await process_frame
	await process_frame
	var active_battle: Dictionary = combat_system.debug_get_combat_snapshot().get("active_battle", {})
	var judgements: Dictionary = active_battle.get("low_hp_judgements", {})
	if judgements.size() != 1 or not judgements.has("stableman_01"):
		push_error("Same NPC should not trigger low HP judgement twice in one battle: %s" % JSON.stringify(judgements))
		quit(1)
		return

	var avoid_damage: Dictionary = npc_system.apply_damage_to_npc("cook_01", 75, enemy_id, "local_public", {
		"enemy_attack": true,
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"request_plan_reevaluation": false
	})
	if not bool(avoid_damage.get("ok", false)):
		push_error("Failed to damage avoid NPC")
		quit(1)
		return
	await process_frame
	await process_frame
	snapshot = combat_system.debug_get_combat_snapshot()
	low_hp_result = snapshot.get("last_low_hp_judgement_result", {})
	if str(low_hp_result.get("npc_id", "")) != "cook_01":
		push_error("Avoid NPC low HP result should belong to cook: %s" % JSON.stringify(low_hp_result))
		quit(1)
		return
	if str(low_hp_result.get("decision", "")) != "avoid_battle":
		push_error("Avoid NPC fallback should continue avoiding as first allowed decision: %s" % JSON.stringify(low_hp_result))
		quit(1)
		return
	if bool(low_hp_result.get("combatant_decisions_allowed", true)):
		push_error("Avoid NPC must not allow combat decisions: %s" % JSON.stringify(low_hp_result))
		quit(1)
		return
	if _mode(npc_system, "cook_01") != "avoid_combat":
		push_error("Avoid NPC should stay in avoid_combat after low HP judgement")
		quit(1)
		return
	var cook_morale: Dictionary = npc_system.get_npc_state("cook_01").get("morale_boost", {})
	if bool(cook_morale.get("active", false)):
		push_error("Avoid NPC must not receive morale boost")
		quit(1)
		return
	var cook_event := _last_event(memory_system.get_plaza_events(), "battle_psychology_result", "cook_01")
	if str(cook_event.get("payload", {}).get("decision", "")) != "avoid_battle":
		push_error("Avoid NPC psychology event should record avoid_battle: %s" % JSON.stringify(cook_event))
		quit(1)
		return

	var dialogue_start: Dictionary = dialog_system.start_player_dialogue("doctor_01", "private")
	if not bool(dialogue_start.get("ok", false)):
		push_error("Failed to start doctor dialogue before low HP: %s" % JSON.stringify(dialogue_start))
		quit(1)
		return
	npc_system.apply_damage_to_npc("doctor_01", 75, enemy_id, "local_public", {
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"request_plan_reevaluation": false
	})
	await process_frame
	await process_frame
	if dialog_system.is_dialogue_active():
		push_error("Low HP judgement should force-end active dialogue with target NPC")
		quit(1)
		return
	low_hp_result = combat_system.debug_get_combat_snapshot().get("last_low_hp_judgement_result", {})
	var dialogue_result: Dictionary = low_hp_result.get("dialogue_result", {})
	if str(low_hp_result.get("npc_id", "")) != "doctor_01" or not bool(dialogue_result.get("ended", false)):
		push_error("Doctor low HP result should include forced dialogue end: %s" % JSON.stringify(low_hp_result))
		quit(1)
		return
	if llm_bridge.get_pending_slowdown_count() != 0:
		push_error("Low HP judgement left pending slowdown after dialogue interruption")
		quit(1)
		return

	print("Low HP battle judgement verification passed.")
	quit(0)


func _first_enemy_id(combat_system: Node) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		return ""
	return str(enemy_ids[0])


func _last_event(events: Array, event_type: String, npc_id: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == event_type and str(event.get("subject_npc_id", "")) == npc_id:
			return event
	return {}


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))
