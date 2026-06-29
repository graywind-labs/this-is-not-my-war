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

	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	var public_toggle := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/Header/DialogHeaderToggles/DialogPublicToggle") as CheckButton
	if (
		dialog_system == null
		or llm_bridge == null
		or combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
		or dialog_panel == null
		or public_toggle == null
	):
		push_error("Wartime dialogue verification required nodes not found")
		quit(1)
		return

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()
	llm_bridge.set_backend_base_url(CLOSED_BACKEND_URL)
	llm_bridge.request_timeout_seconds = 0.1

	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("weapons", 2)
	var weapon_result: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	if not bool(weapon_result.get("ok", false)):
		push_error("Failed to equip stableman: %s" % JSON.stringify(weapon_result))
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Failed to spawn enemies: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var alarm_result: Dictionary = combat_system.debug_trigger_combat_alarm()
	if not bool(alarm_result.get("ok", false)):
		push_error("Failed to trigger rally: %s" % JSON.stringify(alarm_result))
		quit(1)
		return

	var start_result: Dictionary = dialog_system.start_player_dialogue("stableman_01", "private")
	if not bool(start_result.get("ok", false)):
		push_error("Failed to start wartime dialogue: %s" % JSON.stringify(start_result))
		quit(1)
		return
	var state: Dictionary = dialog_system.get_dialogue_state()
	if str(state.get("visibility", "")) != "local_public" or not bool(state.get("force_local_public", false)):
		push_error("Rally dialogue should force local_public visibility: %s" % JSON.stringify(state))
		quit(1)
		return
	if str(state.get("interaction_context", "")) != "rally":
		push_error("Rally dialogue should carry interaction_context=rally")
		quit(1)
		return
	if not public_toggle.button_pressed or not public_toggle.disabled:
		push_error("Dialog public toggle should be on and disabled during wartime dialogue")
		quit(1)
		return
	var visibility_result: Dictionary = dialog_system.set_dialogue_visibility("private")
	if bool(visibility_result.get("ok", false)) or str(dialog_system.get_dialogue_state().get("visibility", "")) != "local_public":
		push_error("Wartime visibility should reject private toggle and stay local_public")
		quit(1)
		return

	var payload: Dictionary = llm_bridge.build_npc_dialogue_payload("stableman_01", "我们一起守住城门。", {
		"interaction_context": "rally",
		"is_recruitment_request": false,
		"dialogue_state": {
			"visibility": "private",
			"participants": ["guard_officer", "stableman_01"]
		}
	})
	if str(payload.get("interaction_context", "")) != "rally":
		push_error("LLM payload should include interaction_context=rally")
		quit(1)
		return
	if str(payload.get("dialogue_state", {}).get("visibility", "")) != "local_public":
		push_error("LLM payload should force local_public visibility in wartime")
		quit(1)
		return
	var battlefield_context: Dictionary = payload.get("battlefield_context", {})
	if battlefield_context.is_empty() or int(battlefield_context.get("active_enemy_count", 0)) <= 0:
		push_error("LLM payload should include battlefield_context with active enemies: %s" % JSON.stringify(payload))
		quit(1)
		return
	if not payload.has("current_order") or not payload.has("short_memory") or not payload.has("location_context"):
		push_error("LLM payload should keep T0603 current_order, short_memory and location_context")
		quit(1)
		return

	var fallback_result: Dictionary = dialog_system.send_player_message("我们一起守住城门。", false, false)
	if not bool(fallback_result.get("ok", false)):
		push_error("Wartime backend failure should use rule fallback: %s" % JSON.stringify(fallback_result))
		quit(1)
		return
	if not bool(fallback_result.get("dialogue", {}).get("rule_fallback", false)):
		push_error("Wartime dialogue should mark rule fallback when backend is unavailable")
		quit(1)
		return
	var morale_result: Dictionary = fallback_result.get("wartime_result", {})
	if not bool(morale_result.get("ok", false)) or str(morale_result.get("reaction", "")) != "morale_boost":
		push_error("Fallback wartime message should apply morale boost: %s" % JSON.stringify(fallback_result))
		quit(1)
		return
	var stableman_state: Dictionary = npc_system.get_npc_state("stableman_01")
	var morale: Dictionary = stableman_state.get("morale_boost", {})
	if not bool(morale.get("active", false)) or int(round(float(morale.get("remaining_game_seconds", 0.0)))) != 7200:
		push_error("Morale boost should last 7200 game seconds: %s" % JSON.stringify(morale))
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "battle_psychology_result").is_empty():
		push_error("Morale reaction should write battle_psychology_result")
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "morale_boost_started").is_empty():
		push_error("Morale reaction should write morale_boost_started")
		quit(1)
		return
	var snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	if str(snapshot.get("last_wartime_dialogue_result", {}).get("reaction", "")) != "morale_boost":
		push_error("Combat snapshot should expose last wartime dialogue result")
		quit(1)
		return

	combat_system._advance_morale_boosts(7200.0)
	stableman_state = npc_system.get_npc_state("stableman_01")
	morale = stableman_state.get("morale_boost", {})
	if bool(morale.get("active", false)):
		push_error("Morale boost should expire after 7200 game seconds")
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "morale_boost_ended").is_empty():
		push_error("Morale expiration should write morale_boost_ended")
		quit(1)
		return

	var escape_result: Dictionary = combat_system.apply_wartime_dialogue_reaction("stableman_01", "escape", {
		"source_event_id": "verify_escape_dialogue_event",
		"dialogue_id": "verify_escape_dialogue",
		"interaction_context": "rally"
	})
	if not bool(escape_result.get("ok", false)):
		push_error("Escape reaction should start station escape: %s" % JSON.stringify(escape_result))
		quit(1)
		return
	stableman_state = npc_system.get_npc_state("stableman_01")
	var escape_intent: Dictionary = stableman_state.get("escape_intent", {})
	if not bool(escape_intent.get("active", false)) or str(escape_intent.get("status", "")) != "escaping":
		push_error("Escape reaction should start escaping for T1203: %s" % JSON.stringify(escape_intent))
		quit(1)
		return
	if str(stableman_state.get("behavior_mode", "")) != "escaped" or str(stableman_state.get("movement_target", "")) != "back_gate_escape_exit":
		push_error("Escaping NPC should be routed to the back gate exit: %s" % JSON.stringify(stableman_state))
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "escape_started").is_empty():
		push_error("Escape reaction should write escape_started event")
		quit(1)
		return

	dialog_system.end_dialogue()
	npc_system.update_npc_state("cook_01", {
		"behavior_mode": "avoid_combat",
		"combat_mode": "avoid_combat",
		"current_action": "avoiding_enemy"
	})
	var avoid_start: Dictionary = dialog_system.start_player_dialogue("cook_01", "private")
	if not bool(avoid_start.get("ok", false)):
		push_error("Failed to start avoid_combat dialogue: %s" % JSON.stringify(avoid_start))
		quit(1)
		return
	state = dialog_system.get_dialogue_state()
	if str(state.get("visibility", "")) != "local_public" or str(state.get("interaction_context", "")) != "avoid_combat":
		push_error("Avoid combat dialogue should also force local_public with avoid_combat context: %s" % JSON.stringify(state))
		quit(1)
		return
	var recruit_apply: Dictionary = dialog_system._apply_player_message_response({
		"ok": true,
		"dialogue": {
			"replyer_id": "cook_01",
			"reply_text": "守备官，我会帮忙，但我还没有武器。",
			"emotion": "tense",
			"recruitment_result": "accept",
			"wartime_reaction": "none",
			"should_end_dialogue": false
		}
	}, {
		"clean_text": "请应征，帮大家守住驿站。",
		"next_round": 1,
		"effective_recruitment_request": true
	})
	if not bool(recruit_apply.get("ok", false)):
		push_error("Avoid combat recruitment dialogue response should apply: %s" % JSON.stringify(recruit_apply))
		quit(1)
		return
	if not bool(npc_system.get_npc("cook_01").get("recruited", false)):
		push_error("Avoid combat recruitment should set recruited when response accepts")
		quit(1)
		return
	if str(npc_system.get_npc_state("cook_01").get("behavior_mode", "")) != "avoid_combat":
		push_error("Recruited but unarmed avoid_combat NPC should stay in avoid_combat")
		quit(1)
		return

	print("Wartime dialogue verification passed.")
	quit(0)


func _last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == event_type:
			return event
	return {}
