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
	var history_text := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/DialogHistoryText") as RichTextLabel
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
		or history_text == null
	):
		push_error("Wartime dialogue verification required nodes not found")
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
	if not (fallback_result.get("wartime_result", {}) as Dictionary).is_empty():
		push_error("Wartime reaction must remain staged until dialogue completion")
		quit(1)
		return
	var staged_history: Array = dialog_system.get_dialogue_state().get("history", [])
	var staged_npc_turn: Dictionary = staged_history.back() if not staged_history.is_empty() and staged_history.back() is Dictionary else {}
	if str(staged_npc_turn.get("wartime_reaction", "")) != "morale_boost":
		push_error("Morale boost feedback should stay attached to the NPC turn: %s" % JSON.stringify(staged_history))
		quit(1)
		return
	if not history_text.text.contains("[color=#63D471]↑ 托马受到了激励，进入斗志激昂状态[/color]"):
		push_error("Wartime morale reply did not show the requested green feedback line: %s" % history_text.text)
		quit(1)
		return
	var fallback_completion: Dictionary = dialog_system.complete_displayed_dialogue()
	var deferred_effects: Dictionary = fallback_completion.get("deferred_effect_results", {}) if fallback_completion.get("deferred_effect_results", {}) is Dictionary else {}
	var morale_result: Dictionary = deferred_effects.get("wartime_result", {}) if deferred_effects.get("wartime_result", {}) is Dictionary else {}
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

	var escape_dialogue_start: Dictionary = dialog_system.start_player_dialogue("stableman_01", "private")
	if not bool(escape_dialogue_start.get("ok", false)):
		push_error("Failed to start staged escape wartime dialogue: %s" % JSON.stringify(escape_dialogue_start))
		quit(1)
		return
	var escape_reply: Dictionary = dialog_system.send_player_message(
		"城门守不住了，别管阵线，你快逃命。",
		false,
		false
	)
	if (
		not bool(escape_reply.get("ok", false))
		or str(escape_reply.get("dialogue", {}).get("wartime_reaction", "")) != "escape"
		or not bool(escape_reply.get("dialogue", {}).get("rule_fallback", false))
	):
		push_error("Closed-backend wartime escape should be staged by rule fallback: %s" % JSON.stringify(escape_reply))
		quit(1)
		return
	if str(npc_system.get_npc_state("stableman_01").get("behavior_mode", "")) == "escaped":
		push_error("Wartime escape reaction must remain staged until completion")
		quit(1)
		return
	var escape_completion: Dictionary = dialog_system.complete_displayed_dialogue()
	var escape_effects: Dictionary = (
		escape_completion.get("deferred_effect_results", {})
		if escape_completion.get("deferred_effect_results", {}) is Dictionary
		else {}
	)
	var escape_result: Dictionary = (
		escape_effects.get("wartime_result", {})
		if escape_effects.get("wartime_result", {}) is Dictionary
		else {}
	)
	if not bool(escape_result.get("ok", false)):
		push_error("Completed wartime dialogue should start station escape: %s" % JSON.stringify(escape_completion))
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
	var avoid_activation: Dictionary = dialog_system._activate_player_dialogue_draft("verify_avoid_recruitment")
	if not bool(avoid_activation.get("ok", false)):
		push_error("Failed to activate avoid_combat dialogue draft: %s" % JSON.stringify(avoid_activation))
		quit(1)
		return
	var avoid_effect: Dictionary = dialog_system._ensure_player_dialogue_effect_started("verify_avoid_recruitment")
	if not bool(avoid_effect.get("ok", false)):
		push_error("Failed to start avoid_combat dialogue effect: %s" % JSON.stringify(avoid_effect))
		quit(1)
		return
	var recruit_apply: Dictionary = dialog_system.send_player_message(
		"请应征，和我们一起守住这里。",
		true,
		false
	)
	if not bool(recruit_apply.get("ok", false)):
		push_error("Avoid combat recruitment fallback should apply: %s" % JSON.stringify(recruit_apply))
		quit(1)
		return
	var avoid_dialogue_response: Dictionary = recruit_apply.get("dialogue", {})
	if (
		not bool(avoid_dialogue_response.get("rule_fallback", false))
		or str(avoid_dialogue_response.get("recruitment_result", "")) != "accept"
		or str(avoid_dialogue_response.get("wartime_reaction", "")) != "none"
	):
		push_error("Avoid combat fallback must keep recruitment but suppress wartime reaction: %s" % JSON.stringify(recruit_apply))
		quit(1)
		return
	if not bool(npc_system.get_npc("cook_01").get("recruited", false)):
		push_error("Avoid combat recruitment acceptance should apply immediately")
		quit(1)
		return
	dialog_system.complete_displayed_dialogue()
	if not bool(npc_system.get_npc("cook_01").get("recruited", false)):
		push_error("Completing avoid combat dialogue rolled back immediate recruitment")
		quit(1)
		return
	if str(npc_system.get_npc_state("cook_01").get("behavior_mode", "")) != "avoid_combat":
		push_error("Recruited but unarmed avoid_combat NPC should stay in avoid_combat")
		quit(1)
		return
	if not await _wait_for_llm_cleanup(llm_bridge):
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


func _wait_for_llm_cleanup(llm_bridge: Node) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		if int(llm_bridge.debug_get_llm_runtime_snapshot().get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for wartime dialogue LLM async cleanup")
	return false
