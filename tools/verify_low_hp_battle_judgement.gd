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
	resource_system.add_resource("item_sword_shield", 1)
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
	if not await _wait_for_low_hp_result(combat_system, "stableman_01"):
		quit(1)
		return

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
	if not await _wait_for_low_hp_result(combat_system, "cook_01"):
		quit(1)
		return
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
	var dialogue_activation: Dictionary = dialog_system._activate_player_dialogue_draft("verify_low_hp_interruption")
	if not bool(dialogue_activation.get("ok", false)):
		push_error("Failed to activate doctor dialogue before low HP: %s" % JSON.stringify(dialogue_activation))
		quit(1)
		return
	var dialogue_effect: Dictionary = dialog_system._ensure_player_dialogue_effect_started("verify_low_hp_interruption")
	if not bool(dialogue_effect.get("ok", false)):
		push_error("Failed to apply doctor dialogue effect before low HP: %s" % JSON.stringify(dialogue_effect))
		quit(1)
		return
	npc_system.apply_damage_to_npc("doctor_01", 75, enemy_id, "local_public", {
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"request_plan_reevaluation": false
	})
	if not await _wait_for_low_hp_result(combat_system, "doctor_01"):
		quit(1)
		return
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

	npc_system.apply_damage_to_npc("doctor_01", 25, enemy_id, "local_public", {
		"enemy_attack": true,
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"request_plan_reevaluation": false
	})
	var psychology_count_before_stale := _count_events(
		memory_system.get_plaza_events(),
		"battle_psychology_result",
		"doctor_01"
	)
	var stale_apply: Dictionary = combat_system._apply_low_hp_judgement_result("doctor_01", {
		"ok": true,
		"npc_id": "doctor_01",
		"decision": "inspired",
		"emotion": "defiant",
		"morale_delta_intent": 1,
		"should_start_escape": false
	}, {
		"allowed_decisions": ["continue_fighting", "escape_station", "inspired"],
		"behavior_mode": "combat",
		"combatant_decisions_allowed": true,
		"llm_result": {
			"ok": true,
			"request_id": "verify_stale_low_hp_response"
		}
	})
	if (
		str(stale_apply.get("status", "")) != "discarded"
		or str(stale_apply.get("reason", "")) != "npc_unconscious"
	):
		push_error("Stale low HP response should be discarded after NPC became unconscious: %s" % JSON.stringify(stale_apply))
		quit(1)
		return
	if (
		_count_events(memory_system.get_plaza_events(), "battle_psychology_result", "doctor_01")
		!= psychology_count_before_stale
		or bool(npc_system.get_npc_state("doctor_01").get("morale_boost", {}).get("active", false))
	):
		push_error("Discarded low HP response must not write psychology event or apply morale")
		quit(1)
		return

	var restart_guard_battle: Dictionary = (
		combat_system.debug_get_combat_snapshot().get("active_battle", {})
	)
	combat_system._pending_low_hp_judgement_by_request["verify_same_wave_restart"] = {
		"npc_id": "stableman_01",
		"context": {
			"battle_wave_id": str(restart_guard_battle.get("wave_id", "")),
			"battle_started_event_id": "superseded_battle_started_event"
		}
	}
	combat_system._on_battle_judgement_async_response_received({
		"ok": true,
		"request_id": "verify_same_wave_restart",
		"npc_id": "stableman_01",
		"battle_judgement": {
			"ok": true,
			"npc_id": "stableman_01",
			"decision": "escape_station",
			"emotion": "afraid",
			"morale_delta_intent": -1,
			"should_start_escape": true
		}
	})
	var restart_guard_result: Dictionary = (
		combat_system.debug_get_combat_snapshot().get("last_low_hp_judgement_result", {})
	)
	if (
		str(restart_guard_result.get("status", "")) != "discarded"
		or str(restart_guard_result.get("reason", "")) != "battle_restarted_before_llm_response"
	):
		push_error(
			"Low HP response from an earlier instance of the same wave must be discarded: %s"
			% JSON.stringify(restart_guard_result)
		)
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


func _count_events(events: Array, event_type: String, npc_id: String) -> int:
	var count := 0
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) == event_type and str(event.get("subject_npc_id", "")) == npc_id:
			count += 1
	return count


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))


func _wait_for_low_hp_result(combat_system: Node, npc_id: String) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		var result: Dictionary = combat_system.debug_get_combat_snapshot().get("last_low_hp_judgement_result", {})
		if str(result.get("npc_id", "")) == npc_id and str(result.get("status", "")) != "pending":
			return true
	push_error("Timed out waiting for async low HP judgement for %s" % npc_id)
	return false
