extends SceneTree

const CLOSED_BACKEND_URL := "http://127.0.0.1:5999"
const WITNESS_ID := "priest_01"
const COMBATANT_ID := "stableman_01"
const AVOIDER_ID := "blacksmith_01"
const LOW_HP_ID := "cook_01"
const HEALER_ID := "doctor_01"
const UNCONSCIOUS_ID := "gardener_01"
const ESCAPER_ID := "engineer_01"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
		or llm_bridge == null
		or building_system == null
		or action_system == null
		or npc_panel == null
	):
		_fail("Battlefield public info verification required nodes not found")
		return

	llm_bridge.set_backend_base_url(CLOSED_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 0.1

	var plaza_ids := [
		WITNESS_ID,
		COMBATANT_ID,
		AVOIDER_ID,
		LOW_HP_ID,
		HEALER_ID,
		UNCONSCIOUS_ID,
		ESCAPER_ID
	]
	for raw_npc_id in plaza_ids:
		var npc_id := str(raw_npc_id)
		if not npc_system.debug_enter_location_immediately(npc_id, "plaza"):
			_fail("Failed to place NPC in plaza: %s" % npc_id)
			return
		npc_system.update_npc_state(npc_id, {
			"hp": 100,
			"max_hp": 100,
			"unconscious": false,
			"escaped": false,
			"current_action": "idle",
			"behavior_mode": "work",
			"movement_target": "",
			"movement_target_name": "",
			"escape_intent": {},
			"morale_boost": {}
		})

	_set_npc_position(npc_system, WITNESS_ID, Vector3(0.0, 0.0, 0.0))
	_set_npc_position(npc_system, COMBATANT_ID, Vector3(0.5, 0.0, 0.0))
	_set_npc_position(npc_system, AVOIDER_ID, Vector3(1.0, 0.0, 0.0))
	_set_npc_position(npc_system, LOW_HP_ID, Vector3(1.5, 0.0, 0.0))
	_set_npc_position(npc_system, HEALER_ID, Vector3(2.0, 0.0, 0.0))
	_set_npc_position(npc_system, UNCONSCIOUS_ID, Vector3(2.5, 0.0, 0.0))
	_set_npc_position(npc_system, ESCAPER_ID, Vector3(-10.0, 0.0, -22.7))

	npc_system.set_npc_recruited(COMBATANT_ID, true)
	resource_system.add_resource("item_sword_shield", 1)
	var weapon_result: Dictionary = equipment_system.equip_npc_main_weapon(COMBATANT_ID, "sword_shield", "private")
	if not bool(weapon_result.get("ok", false)):
		_fail("Failed to equip combatant for verification: %s" % JSON.stringify(weapon_result))
		return

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		return

	var combat_started := _last_event(memory_system.get_plaza_events(), "combat_started")
	if not _expect(not combat_started.is_empty(), "Wave spawn should write combat_started to plaza events"):
		return
	var start_payload: Dictionary = combat_started.get("payload", {})
	if not _expect(int(start_payload.get("enemy_count", 0)) > 0, "combat_started should include enemy_count"):
		return
	if not _expect(int(start_payload.get("friendly_combatant_count", 0)) > 0, "combat_started should include friendly_combatant_count"):
		return
	if not _expect(str(combat_started.get("summary", "")).contains("敌军来袭"), "combat_started summary should announce enemy arrival"):
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "combat_started"), "Plaza witness should receive combat_started"):
		return

	var dialogue_payload: Dictionary = llm_bridge.build_npc_dialogue_payload(WITNESS_ID, "刚才广场发生了什么？", {
		"visibility": "private"
	})
	var short_memory: Dictionary = dialogue_payload.get("short_memory", {})
	if not _expect(_summaries_have_type(short_memory.get("witnessed_events", []), "combat_started"), "Dialogue payload should include public witnessed combat_started"):
		return
	var target_npc: Dictionary = dialogue_payload.get("target_npc", {})
	var target_memory: Dictionary = target_npc.get("short_term_memory", {})
	if not _expect(_summaries_have_type(target_memory.get("witnessed_events", []), "combat_started"), "Target NPC context should include witnessed combat_started"):
		return

	npc_panel.show_npc(WITNESS_ID)
	await process_frame
	var witness_log_text := npc_panel.find_child("NPCWitnessLogText", true, false) as TextEdit
	if not _expect(witness_log_text != null and witness_log_text.text.contains("敌军来袭"), "NPC panel witness log should display recent public combat info"):
		return

	var alarm_result: Dictionary = combat_system.debug_trigger_combat_alarm()
	if not bool(alarm_result.get("ok", false)):
		_fail("Combat alarm should trigger rally: %s" % JSON.stringify(alarm_result))
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "combat_rally_started", COMBATANT_ID), "Witness should receive combat_rally_started"):
		return
	if not _expect(not _has_event(memory_system.get_all_events(), "npc_mode_changed"), "Internal rally mode changes must stay out of event memory"):
		return

	var avoid_result: Dictionary = combat_system.debug_trigger_npc_avoidance(AVOIDER_ID)
	if not bool(avoid_result.get("ok", false)):
		_fail("Avoidance should start for noncombatant: %s" % JSON.stringify(avoid_result))
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "avoidance_started", AVOIDER_ID), "Witness should receive avoidance_started"):
		return

	var enemy_id := _first_enemy_id(combat_system)
	if enemy_id.is_empty():
		_fail("Spawned wave should expose at least one enemy id")
		return
	var combatant_position: Vector3 = npc_system.get_npc_world_position(COMBATANT_ID)
	_place_enemy(combat_system, enemy_id, combatant_position + Vector3(0.5, 0.0, 0.6), 1, 999.0)
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(COMBATANT_ID, "combat", "verify_battlefield_public_attack", {
		"state_changes": {
			"current_action": "combat_ready",
			"current_location": "plaza",
			"current_location_name": "广场",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0
		},
		"request_plan_reevaluation": false
	})
	if not bool(mode_result.get("ok", false)):
		_fail("Failed to set combatant to combat mode: %s" % JSON.stringify(mode_result))
		return
	combat_system.debug_step_enemy_ai(60.0)
	await process_frame
	var attack_event := _last_event(memory_system.get_plaza_events(), "attack_made", COMBATANT_ID)
	if not _expect(not attack_event.is_empty(), "NPC attack should write attack_made to plaza events"):
		return
	if not _expect(bool(attack_event.get("payload", {}).get("defeated", false)), "attack_made should record enemy defeat"):
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "attack_made", COMBATANT_ID), "Witness should receive attack_made"):
		return

	var remaining_enemy_id := _first_enemy_id(combat_system)
	if remaining_enemy_id.is_empty():
		_fail("Expected at least one enemy to remain for low HP and unconscious checks")
		return
	var remaining_enemy: Dictionary = combat_system.get_enemy(remaining_enemy_id)
	var enemy_name := str(remaining_enemy.get("name", remaining_enemy_id))
	var low_hp_damage: Dictionary = npc_system.apply_damage_to_npc(LOW_HP_ID, 75, remaining_enemy_id, "local_public", {
		"enemy_attack": true,
		"enemy_id": remaining_enemy_id,
		"enemy_name": enemy_name,
		"request_plan_reevaluation": false
	})
	if not bool(low_hp_damage.get("ok", false)):
		_fail("Failed to damage NPC for low HP check")
		return
	if not await _wait_for_low_hp_result(combat_system, LOW_HP_ID):
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "low_hp_triggered", LOW_HP_ID), "Witness should receive low_hp_triggered"):
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "battle_psychology_result", LOW_HP_ID), "Witness should receive low HP battle_psychology_result"):
		return

	var unconscious_damage: Dictionary = npc_system.apply_damage_to_npc(UNCONSCIOUS_ID, 150, remaining_enemy_id, "local_public", {
		"enemy_attack": true,
		"enemy_id": remaining_enemy_id,
		"enemy_name": enemy_name,
		"request_plan_reevaluation": false
	})
	if not bool(unconscious_damage.get("ok", false)):
		_fail("Failed to make NPC unconscious")
		return
	await process_frame
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "unconscious_started", UNCONSCIOUS_ID), "Witness should receive unconscious_started"):
		return
	action_system.interrupt_npc_action(HEALER_ID, "verify_battlefield_healer_ready")
	var healer_mode_result: Dictionary = npc_system.set_npc_behavior_mode(HEALER_ID, "work", "verify_battlefield_healer_ready", {
		"force_idle": true,
		"request_plan_reevaluation": false
	})
	if not bool(healer_mode_result.get("ok", false)):
		_fail("Failed to reset healer before assisted recovery: %s" % JSON.stringify(healer_mode_result))
		return
	if not action_system.debug_assign_heal_assist(HEALER_ID, UNCONSCIOUS_ID):
		_fail("Healer should be able to assist unconscious NPC")
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "healing_started"), "Witness should receive healing_started"):
		return
	var recovery: Dictionary = npc_system.assist_unconscious_recovery(UNCONSCIOUS_ID, 8.0 * 3600.0, HEALER_ID, 100)
	if not bool(recovery.get("revived", false)):
		_fail("Assisted recovery should revive unconscious NPC: %s" % JSON.stringify(recovery))
		return
	await process_frame
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "revived", UNCONSCIOUS_ID), "Witness should receive revived"):
		return

	var escape_result: Dictionary = combat_system.debug_start_npc_escape(ESCAPER_ID, "verify_battlefield_public_info")
	if not bool(escape_result.get("ok", false)):
		_fail("Debug escape should start: %s" % JSON.stringify(escape_result))
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "escape_started", ESCAPER_ID), "Witness should receive escape_started"):
		return
	var escape_target := _dict_to_vector3(escape_result.get("target_position", {}))
	var escape_frame_budget := 1200 if absf(escape_target.z) > 200.0 else 160
	for _i in range(escape_frame_budget):
		await physics_frame
		var escaper_state: Dictionary = npc_system.get_npc_state(ESCAPER_ID)
		if bool(escaper_state.get("escaped", false)):
			break
	var final_escape_state: Dictionary = npc_system.get_npc_state(ESCAPER_ID)
	if not _expect(
		bool(final_escape_state.get("escaped", false)),
		"Escaper should leave station after reaching exit: %s" % JSON.stringify(final_escape_state)
	):
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "escaped", ESCAPER_ID), "Witness should receive escaped"):
		return

	if not building_system.debug_damage_building("front_gate", 5):
		_fail("Building damage debug call should succeed")
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "building_damaged"), "Witness should receive building_damaged"):
		return

	combat_system.debug_clear_enemies()
	await process_frame
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "avoidance_ended", AVOIDER_ID), "Witness should receive avoidance_ended when enemies are cleared"):
		return
	if not _expect(_has_event(memory_system.get_npc_witness_events(WITNESS_ID), "combat_ended"), "Witness should receive combat_ended"):
		return
	if not _expect(not _has_event(memory_system.get_all_events(), "npc_mode_changed"), "No behavior mode transition should broadcast npc_mode_changed"):
		return
	if not await _wait_for_llm_cleanup(llm_bridge):
		return

	print("T1205 battlefield public info verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true


func _dict_to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		var data := value as Dictionary
		return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
	return Vector3.ZERO


func _wait_for_low_hp_result(combat_system: Node, npc_id: String) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		var result: Dictionary = combat_system.debug_get_combat_snapshot().get("last_low_hp_judgement_result", {})
		if str(result.get("npc_id", "")) == npc_id and str(result.get("status", "")) != "pending":
			return true
	_fail("Timed out waiting for async low HP judgement for %s" % npc_id)
	return false


func _wait_for_llm_cleanup(llm_bridge: Node) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		if int(llm_bridge.debug_get_llm_runtime_snapshot().get("async_request_count", 0)) == 0:
			return true
	_fail("Timed out waiting for battlefield LLM async cleanup")
	return false


func _first_enemy_id(combat_system: Node) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		return ""
	return str(enemy_ids[0])


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var npc_nodes: Dictionary = npc_system.get("_npc_nodes")
	var node_path := NodePath(str(npc_nodes.get(npc_id, "")))
	var npc_node := root.get_node_or_null(node_path) as Node3D
	if npc_node != null:
		npc_node.global_position = position


func _place_enemy(combat_system: Node, enemy_id: String, position: Vector3, hp: int = -1, attack_cooldown: float = -1.0) -> void:
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	if enemy.is_empty():
		return
	enemy["position"] = position
	if hp >= 0:
		enemy["hp"] = hp
	if attack_cooldown >= 0.0:
		enemy["attack_cooldown"] = attack_cooldown
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	if combat_system.has_method("_refresh_enemy_node"):
		combat_system._refresh_enemy_node(enemy_id)


func _last_event(events: Array, event_type: String, subject_npc_id: String = "") -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) != event_type:
			continue
		if not subject_npc_id.is_empty() and str(event.get("subject_npc_id", "")) != subject_npc_id:
			continue
		return event
	return {}


func _has_event(events: Array, event_type: String, subject_npc_id: String = "") -> bool:
	return not _last_event(events, event_type, subject_npc_id).is_empty()


func _summaries_have_type(raw_entries: Variant, event_type: String) -> bool:
	var entries: Array = raw_entries if raw_entries is Array else []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get("type", "")) == event_type:
			return true
	return false
