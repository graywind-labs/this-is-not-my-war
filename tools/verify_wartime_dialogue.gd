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
	var public_toggle := dialog_panel.find_child("DialogPublicToggle", true, false) as CheckBox if dialog_panel != null else null
	var private_visibility_radio := dialog_panel.find_child("DialogPrivateRadio", true, false) as CheckBox if dialog_panel != null else null
	var status_label := dialog_panel.find_child("DialogStatusLabel", true, false) as Label if dialog_panel != null else null
	var round_label := dialog_panel.find_child("DialogRoundLabel", true, false) as Label if dialog_panel != null else null
	var morale_toggle := dialog_panel.find_child("DialogMoraleEncouragementToggle", true, false) as CheckButton if dialog_panel != null else null
	var strategy_toggle := dialog_panel.find_child("DialogCombatStrategyToggle", true, false) as CheckButton if dialog_panel != null else null
	var history_text := dialog_panel.find_child("DialogHistoryText", true, false) as RichTextLabel if dialog_panel != null else null
	var special_success_dialog := dialog_panel.find_child("DialogSpecialSuccessDialog", true, false) as AcceptDialog if dialog_panel != null else null
	var escape_alert_dialog := root.get_node_or_null("Main/UI/HUD/EscapeStartedAlertDialog") as AcceptDialog
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
		or private_visibility_radio == null
		or status_label == null
		or round_label == null
		or morale_toggle == null
		or strategy_toggle == null
		or history_text == null
		or special_success_dialog == null
		or escape_alert_dialog == null
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
	var rally_runtime_before_dialogue: Dictionary = npc_system.get_npc_state("stableman_01")

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
	if not public_toggle.button_pressed or not public_toggle.disabled or not private_visibility_radio.disabled:
		push_error("Dialog public toggle should be on and disabled during wartime dialogue")
		quit(1)
		return
	if private_visibility_radio.button_pressed or round_label.visible or status_label.text in ["战时公开对话", "公开对话", "私下对话"]:
		push_error("Forced-public wartime dialogue should be expressed only by locked radio selection")
		quit(1)
		return
	if morale_toggle.disabled or not bool(state.get("morale_encouragement_eligible", false)):
		push_error("Eligible rally dialogue should enable morale encouragement toggle: %s" % JSON.stringify(state))
		quit(1)
		return
	if strategy_toggle.disabled or not bool(state.get("combat_strategy_request_eligible", false)):
		push_error("Eligible rally dialogue should enable combat strategy toggle: %s" % JSON.stringify(state))
		quit(1)
		return
	var morale_arm_for_mutex: Dictionary = dialog_system.set_morale_encouragement_request_pending(true)
	var strategy_arm_for_mutex: Dictionary = dialog_system.set_combat_strategy_request_pending(true)
	state = dialog_system.get_dialogue_state()
	if (
		not bool(morale_arm_for_mutex.get("ok", false))
		or not bool(strategy_arm_for_mutex.get("ok", false))
		or bool(state.get("morale_encouragement_request_pending", false))
		or not bool(state.get("combat_strategy_request_pending", false))
		or morale_toggle.button_pressed
		or not strategy_toggle.button_pressed
	):
		push_error("Combat strategy toggle should turn off morale toggle: %s" % JSON.stringify(state))
		quit(1)
		return
	var unrelated_strategy_result: Dictionary = dialog_system.send_player_message("今晚食堂准备吃什么？", false, false)
	var rally_runtime_during_dialogue: Dictionary = npc_system.get_npc_state("stableman_01")
	if (
		str(rally_runtime_during_dialogue.get("behavior_mode", ""))
		!= str(rally_runtime_before_dialogue.get("behavior_mode", ""))
		or str(rally_runtime_during_dialogue.get("current_action", ""))
		!= str(rally_runtime_before_dialogue.get("current_action", ""))
		or str(rally_runtime_during_dialogue.get("movement_target", ""))
		!= str(rally_runtime_before_dialogue.get("movement_target", ""))
		or str(rally_runtime_during_dialogue.get("last_action_result", ""))
		!= str(rally_runtime_before_dialogue.get("last_action_result", ""))
	):
		push_error("Rally dialogue must not overwrite or interrupt rally runtime state: before=%s during=%s" % [
			JSON.stringify(rally_runtime_before_dialogue),
			JSON.stringify(rally_runtime_during_dialogue)
		])
		quit(1)
		return
	state = dialog_system.get_dialogue_state()
	if (
		not bool(unrelated_strategy_result.get("ok", false))
		or not bool(state.get("combat_strategy_request_pending", false))
		or str(combat_system.get_npc_combat_strategy("stableman_01").get("id", "")) != "attack"
		or not history_text.text.contains("• 托马保持当前战斗策略：“主动进攻”")
	):
		push_error("Unrelated strategy request should keep attack and preserve toggle: %s" % JSON.stringify(unrelated_strategy_result))
		quit(1)
		return
	var strategy_context: Dictionary = state.get("combat_strategy_context", {}) if state.get("combat_strategy_context", {}) is Dictionary else {}
	var strategy_change_result: Dictionary = dialog_system._apply_player_message_response({
		"ok": true,
		"dialogue": {
			"replyer_id": "stableman_01",
			"reply_text": "明白，我会避开正面接敌，先保存力量。",
			"recruitment_result": "none",
			"wartime_reaction": "none",
			"combat_strategy_decision": {"decision": "change", "strategy_id": "avoid"}
		}
	}, {
		"kind": "player_message",
		"clean_text": "改成避战，先保存力量。",
		"next_round": int(state.get("current_round", 0)) + 1,
		"effective_recruitment_request": false,
		"effective_morale_encouragement_request": false,
		"effective_combat_strategy_request": true,
		"combat_strategy_context": strategy_context,
		"dialogue_kind": "player_npc"
	})
	if (
		not bool(strategy_change_result.get("ok", false))
		or str(combat_system.get_npc_combat_strategy("stableman_01").get("id", "")) != "avoid"
		or not history_text.text.contains("✓ 托马将战斗策略从“主动进攻”调整为“避战”")
		or strategy_toggle.button_pressed
	):
		push_error("Dialogue strategy change did not apply or report feedback: %s" % JSON.stringify(strategy_change_result))
		quit(1)
		return
	if special_success_dialog.visible:
		special_success_dialog.get_ok_button().pressed.emit()
		await process_frame
	var morale_rearm_for_mutex: Dictionary = dialog_system.set_morale_encouragement_request_pending(true)
	state = dialog_system.get_dialogue_state()
	if not bool(morale_rearm_for_mutex.get("ok", false)) or bool(state.get("combat_strategy_request_pending", false)) or strategy_toggle.button_pressed:
		push_error("Morale toggle should turn off combat strategy toggle: %s" % JSON.stringify(state))
		quit(1)
		return
	dialog_system.set_morale_encouragement_request_pending(false)
	var visibility_result: Dictionary = dialog_system.set_dialogue_visibility("private")
	if bool(visibility_result.get("ok", false)) or str(dialog_system.get_dialogue_state().get("visibility", "")) != "local_public":
		push_error("Wartime visibility should reject private toggle and stay local_public")
		quit(1)
		return

	var payload: Dictionary = llm_bridge.build_npc_dialogue_payload("stableman_01", "我们一起守住城门。", {
		"interaction_context": "rally",
		"is_recruitment_request": false,
		"is_morale_encouragement_request": true,
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
	if not bool(payload.get("is_morale_encouragement_request", false)):
		push_error("Morale toggle must reach LLMBridge payload")
		quit(1)
		return

	var plain_result: Dictionary = dialog_system.send_player_message("我们一起守住城门。", false, false)
	if (
		not bool(plain_result.get("ok", false))
		or str(plain_result.get("dialogue", {}).get("wartime_reaction", "")) != "none"
	):
		push_error("Wartime dialogue without morale toggle must remain ordinary: %s" % JSON.stringify(plain_result))
		quit(1)
		return
	var arm_result: Dictionary = dialog_system.set_morale_encouragement_request_pending(true)
	if not bool(arm_result.get("ok", false)) or not morale_toggle.button_pressed:
		push_error("Failed to arm morale encouragement toggle: %s" % JSON.stringify(arm_result))
		quit(1)
		return
	var unrelated_result: Dictionary = dialog_system.send_player_message("今晚食堂准备吃什么？", false, false)
	if (
		not bool(unrelated_result.get("ok", false))
		or str(unrelated_result.get("dialogue", {}).get("wartime_reaction", "")) != "none"
		or not bool(dialog_system.get_dialogue_state().get("morale_encouragement_request_pending", false))
		or not morale_toggle.button_pressed
	):
		push_error("Unrelated message must not gain buff and toggle must remain armed: %s" % JSON.stringify(unrelated_result))
		quit(1)
		return
	if not history_text.text.contains("• 托马未受到鼓舞，继续参战"):
		push_error("Unrelated morale request should show continue-fighting feedback: %s" % history_text.text)
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
	if morale_toggle.button_pressed or not morale_toggle.disabled:
		push_error("Successful morale response should turn off and lock the toggle")
		quit(1)
		return
	if not history_text.text.contains("[color=#63D471]✓ 守备官成功鼓舞了托马；持续至当天24:00，攻击力和移动速度提升15%[/color]"):
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
	if special_success_dialog.visible:
		special_success_dialog.get_ok_button().pressed.emit()
		await process_frame
	var stableman_state: Dictionary = npc_system.get_npc_state("stableman_01")
	var morale: Dictionary = stableman_state.get("morale_boost", {})
	var game_state := root.get_node_or_null("GameState")
	var expected_until_midnight := 86400
	if game_state != null:
		expected_until_midnight -= int(game_state.current_hour) * 3600 + int(game_state.current_minute) * 60 + int(game_state.current_second)
	if (
		not bool(morale.get("active", false))
		or int(round(float(morale.get("remaining_game_seconds", 0.0)))) != expected_until_midnight
		or int(morale.get("expires_day", 0)) != int(morale.get("started_day", 0)) + 1
	):
		push_error("Morale boost should last until the next midnight: %s" % JSON.stringify(morale))
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

	var active_buff_dialogue: Dictionary = dialog_system.start_player_dialogue("stableman_01", "private")
	if not bool(active_buff_dialogue.get("ok", false)) or not morale_toggle.disabled or morale_toggle.modulate.a > 0.5:
		push_error("Active morale buff must keep the toggle disabled and translucent")
		quit(1)
		return
	dialog_system.cancel_displayed_dialogue()

	# A live combat dialogue owns only the session lock. Attack and tactical movement
	# fields must survive activation, suspension, resumption and cancellation exactly.
	npc_system.update_npc_state("stableman_01", {
		"behavior_mode": "combat",
		"combat_mode": "combat",
		"current_action": "combat_attack_windup",
		"last_action_result": "combat_attack_windup_started",
		"combat_attack_phase": "windup",
		"combat_attack_cooldown": 0.75,
		"combat_attack_target_enemy_id": "verify_enemy",
		"combat_strategy_move_target_id": "verify_flank_point",
		"movement_target": "combat_strategy_verify_flank_point"
	})
	var combat_runtime_before_dialogue: Dictionary = npc_system.get_npc_state("stableman_01")
	var combat_dialogue_start: Dictionary = dialog_system.start_player_dialogue("stableman_01", "private")
	if not bool(combat_dialogue_start.get("ok", false)):
		push_error("Failed to open parallel combat dialogue: %s" % JSON.stringify(combat_dialogue_start))
		quit(1)
		return
	var combat_activation: Dictionary = dialog_system._activate_player_dialogue_draft("verify_parallel_combat")
	var combat_effect: Dictionary = dialog_system._ensure_player_dialogue_effect_started("verify_parallel_combat")
	var combat_llm_guard: Dictionary = combat_effect.get("cancel_result", {}) if combat_effect.get("cancel_result", {}) is Dictionary else {}
	if (
		not bool(combat_activation.get("ok", false))
		or not bool(combat_effect.get("ok", false))
		or not bool(combat_effect.get("parallel_wartime", false))
		or bool(combat_effect.get("interrupted_action", true))
		or bool(combat_llm_guard.get("cancelled", true))
		or str(combat_llm_guard.get("reason", "")) != "player_dialogue_parallel_with_combat"
	):
		push_error("Combat dialogue did not enter the non-interrupting path: activation=%s effect=%s" % [
			JSON.stringify(combat_activation),
			JSON.stringify(combat_effect)
		])
		quit(1)
		return
	var combat_runtime_active: Dictionary = npc_system.get_npc_state("stableman_01")
	if not _combat_runtime_fields_match(combat_runtime_before_dialogue, combat_runtime_active):
		push_error("Combat dialogue activation overwrote attack or tactical movement state: before=%s active=%s" % [
			JSON.stringify(combat_runtime_before_dialogue),
			JSON.stringify(combat_runtime_active)
		])
		quit(1)
		return
	var suspend_result: Dictionary = dialog_system.suspend_displayed_dialogue()
	var combat_runtime_suspended: Dictionary = npc_system.get_npc_state("stableman_01")
	if not bool(suspend_result.get("ok", false)) or not _combat_runtime_fields_match(combat_runtime_before_dialogue, combat_runtime_suspended):
		push_error("Suspending combat dialogue changed combat runtime: result=%s state=%s" % [
			JSON.stringify(suspend_result),
			JSON.stringify(combat_runtime_suspended)
		])
		quit(1)
		return
	var resume_result: Dictionary = dialog_system.resume_suspended_player_dialogue("stableman_01")
	var combat_runtime_resumed: Dictionary = npc_system.get_npc_state("stableman_01")
	if not bool(resume_result.get("ok", false)) or not _combat_runtime_fields_match(combat_runtime_before_dialogue, combat_runtime_resumed):
		push_error("Resuming combat dialogue changed combat runtime: result=%s state=%s" % [
			JSON.stringify(resume_result),
			JSON.stringify(combat_runtime_resumed)
		])
		quit(1)
		return
	dialog_system.cancel_displayed_dialogue()
	var combat_runtime_after_cancel: Dictionary = npc_system.get_npc_state("stableman_01")
	if not _combat_runtime_fields_match(combat_runtime_before_dialogue, combat_runtime_after_cancel):
		push_error("Closing combat dialogue wrote idle over combat runtime: %s" % JSON.stringify(combat_runtime_after_cancel))
		quit(1)
		return

	# Rally-to-combat handoff is a CombatSystem/NPCSystem transition, not a reason
	# to terminate the parallel player dialogue or cancel its request ownership.
	npc_system.update_npc_state("stableman_01", {
		"behavior_mode": "rally",
		"combat_mode": "rally",
		"current_action": "rallying_defense_line",
		"last_action_result": "rally_waiting"
	})
	var transition_dialogue_start: Dictionary = dialog_system.start_player_dialogue("stableman_01", "private")
	dialog_system._activate_player_dialogue_draft("verify_parallel_mode_transition")
	dialog_system._ensure_player_dialogue_effect_started("verify_parallel_mode_transition")
	var transition_dialogue_id := str(dialog_system.get_dialogue_state().get("dialogue_id", ""))
	var transition_result: Dictionary = npc_system.set_npc_behavior_mode(
		"stableman_01",
		"combat",
		"verify_rally_to_combat_during_dialogue",
		{
			"interrupt": true,
			"request_plan_reevaluation": false,
			"state_changes": {
				"current_action": "combat_ready",
				"last_action_result": "enemy_contact"
			}
		}
	)
	state = dialog_system.get_dialogue_state()
	var transition_interrupt: Dictionary = (
		transition_result.get("interrupt_result", {})
		if transition_result.get("interrupt_result", {}) is Dictionary
		else {}
	)
	var transition_dialogue_guard: Dictionary = (
		transition_interrupt.get("dialogue", {})
		if transition_interrupt.get("dialogue", {}) is Dictionary
		else {}
	)
	var transition_llm_guard: Dictionary = (
		transition_interrupt.get("llm", {})
		if transition_interrupt.get("llm", {}) is Dictionary
		else {}
	)
	if (
		not bool(transition_dialogue_start.get("ok", false))
		or not bool(transition_result.get("ok", false))
		or str(state.get("dialogue_id", "")) != transition_dialogue_id
		or str(state.get("interaction_context", "")) != "combat"
		or str(npc_system.get_npc_state("stableman_01").get("current_action", "")) != "combat_ready"
		or bool(transition_dialogue_guard.get("ended", true))
		or str(transition_dialogue_guard.get("reason", "")) != "player_dialogue_parallel_with_combat"
		or bool(transition_llm_guard.get("cancelled", true))
		or str(transition_llm_guard.get("reason", "")) != "player_dialogue_parallel_with_combat"
	):
		push_error("Rally-to-combat transition interrupted dialogue or lost combat authority: start=%s transition=%s dialogue=%s npc=%s" % [
			JSON.stringify(transition_dialogue_start),
			JSON.stringify(transition_result),
			JSON.stringify(state),
			JSON.stringify(npc_system.get_npc_state("stableman_01"))
		])
		quit(1)
		return
	dialog_system.cancel_displayed_dialogue()
	combat_system._advance_morale_boosts(float(expected_until_midnight) - 1.0)
	if not bool(npc_system.get_npc_state("stableman_01").get("morale_boost", {}).get("active", false)):
		push_error("Morale boost expired before midnight")
		quit(1)
		return
	combat_system._advance_morale_boosts(1.0)
	stableman_state = npc_system.get_npc_state("stableman_01")
	morale = stableman_state.get("morale_boost", {})
	if bool(morale.get("active", false)):
		push_error("Morale boost should expire at midnight")
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
	var arm_escape_result: Dictionary = dialog_system.set_morale_encouragement_request_pending(true)
	if not bool(arm_escape_result.get("ok", false)):
		push_error("Failed to arm morale toggle for escape result: %s" % JSON.stringify(arm_escape_result))
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
	if escape_alert_dialog.visible:
		escape_alert_dialog.get_ok_button().pressed.emit()
		await process_frame

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
	if not morale_toggle.disabled or morale_toggle.modulate.a > 0.5:
		push_error("Avoid-combat dialogue must disable and fade morale toggle")
		quit(1)
		return
	var avoid_activation: Dictionary = dialog_system._activate_player_dialogue_draft("verify_avoid_recruitment")
	if not bool(avoid_activation.get("ok", false)):
		push_error("Failed to activate avoid_combat dialogue draft: %s" % JSON.stringify(avoid_activation))
		quit(1)
		return
	var avoid_effect: Dictionary = dialog_system._ensure_player_dialogue_effect_started("verify_avoid_recruitment")
	if (
		not bool(avoid_effect.get("ok", false))
		or not bool(avoid_effect.get("parallel_wartime", false))
		or bool(avoid_effect.get("interrupted_action", true))
		or str(npc_system.get_npc_state("cook_01").get("current_action", "")) != "avoiding_enemy"
	):
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


func _combat_runtime_fields_match(expected: Dictionary, actual: Dictionary) -> bool:
	for field_name in [
		"behavior_mode",
		"combat_mode",
		"current_action",
		"last_action_result",
		"combat_attack_phase",
		"combat_attack_cooldown",
		"combat_attack_target_enemy_id",
		"combat_strategy_move_target_id",
		"movement_target"
	]:
		if actual.get(field_name) != expected.get(field_name):
			return false
	return true


func _wait_for_llm_cleanup(llm_bridge: Node) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		if int(llm_bridge.debug_get_llm_runtime_snapshot().get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for wartime dialogue LLM async cleanup")
	return false
