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
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var cook_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var dialogue_button := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCDialogueButton") as Button
	var hud_warning := root.get_node_or_null("Main/UI/HUD/EscapeWarningLabel") as Label
	if (
		combat_system == null
		or npc_system == null
		or dialog_system == null
		or llm_bridge == null
		or memory_system == null
		or resource_system == null
		or cook_node == null
		or npc_panel == null
		or dialog_panel == null
		or dialogue_button == null
		or hud_warning == null
	):
		push_error("Escape intervention verification required nodes not found")
		quit(1)
		return

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()

	var escape_result: Dictionary = combat_system.debug_start_npc_escape("cook_01", "verify_intervention")
	if not bool(escape_result.get("ok", false)):
		push_error("Cook escape should start: %s" % JSON.stringify(escape_result))
		quit(1)
		return
	await process_frame

	var marker := cook_node.get_node_or_null("EscapeWarningMarker") as Label3D
	if marker == null or not marker.visible:
		push_error("Escaping NPC should show overhead escape warning marker")
		quit(1)
		return
	if not hud_warning.visible or hud_warning.text.find("布鲁诺") < 0:
		push_error("HUD should warn about active escape: %s" % hud_warning.text)
		quit(1)
		return

	if npc_system.handle_npc_clicked("cook_01"):
		push_error("Clicking an escaping NPC should not directly open escape intervention dialogue")
		quit(1)
		return
	if not npc_system.debug_select_npc("cook_01"):
		push_error("Selecting an escaping NPC should open NPC panel")
		quit(1)
		return
	await process_frame
	if not npc_panel.visible or dialog_panel.visible:
		push_error("Escaping NPC click path should show NPC panel before dialogue")
		quit(1)
		return
	if dialogue_button.disabled:
		push_error("Dialogue button should be enabled while escape rounds remain")
		quit(1)
		return

	dialogue_button.pressed.emit()
	await process_frame
	var dialogue_state: Dictionary = dialog_system.get_dialogue_state()
	if str(dialogue_state.get("dialogue_kind", "")) != "escape_intervention":
		push_error("Dialogue button should start escape_intervention dialogue: %s" % JSON.stringify(dialogue_state))
		quit(1)
		return
	if int(dialogue_state.get("max_rounds", 0)) != 5 or str(dialogue_state.get("visibility", "")) != "local_public":
		push_error("Escape intervention should be local_public with 5 max rounds: %s" % JSON.stringify(dialogue_state))
		quit(1)
		return
	if not _assert_escape_paused(npc_system, "cook_01", "Dialogue opening should pause escape movement"):
		quit(1)
		return

	var payload: Dictionary = llm_bridge.build_npc_dialogue_payload("cook_01", "别走，我会给你补偿。", {
		"dialogue_kind": "escape_intervention",
		"current_round": 1,
		"max_rounds": 5,
		"escape_intervention_round": 1,
		"dialogue_state": {
			"visibility": "local_public",
			"participants": ["guard_officer", "cook_01"]
		},
		"interaction_context": "escape_intervention"
	})
	if str(payload.get("dialogue_kind", "")) != "escape_intervention" or int(payload.get("escape_intervention_round", 0)) != 1:
		push_error("LLM payload should carry escape intervention kind and round: %s" % JSON.stringify(payload))
		quit(1)
		return
	if str(payload.get("interaction_context", "")) != "escape_intervention":
		push_error("LLM payload should carry escape_intervention context: %s" % JSON.stringify(payload))
		quit(1)
		return

	var stay_apply: Dictionary = dialog_system._apply_player_message_response({
		"ok": true,
		"dialogue": _make_escape_dialogue_response("cook_01", "我留下。", "stay_after_intervention")
	}, {
		"clean_text": "别走，我会给你补偿。",
		"next_round": 1,
		"effective_recruitment_request": false,
		"dialogue_kind": "escape_intervention"
	})
	if not bool(stay_apply.get("ok", false)):
		push_error("Stay intervention response should apply: %s" % JSON.stringify(stay_apply))
		quit(1)
		return
	if not dialog_system.get_dialogue_state().is_empty() or dialog_panel.visible:
		push_error("Stay decision should close escape intervention dialogue")
		quit(1)
		return
	var cook_state: Dictionary = npc_system.get_npc_state("cook_01")
	var cook_intent: Dictionary = cook_state.get("escape_intent", {})
	if bool(cook_intent.get("active", true)) or str(cook_intent.get("status", "")) != "stayed":
		push_error("Stay decision should cancel escape intent: %s" % JSON.stringify(cook_state))
		quit(1)
		return
	if str(cook_state.get("behavior_mode", "")) != "work":
		push_error("Stay decision should return NPC to work mode: %s" % JSON.stringify(cook_state))
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "escape_intervention_result").is_empty():
		push_error("Stay decision should write public escape_intervention_result")
		quit(1)
		return

	var doctor_escape: Dictionary = combat_system.debug_start_npc_escape("doctor_01", "verify_reopen")
	if not bool(doctor_escape.get("ok", false)):
		push_error("Doctor escape should start: %s" % JSON.stringify(doctor_escape))
		quit(1)
		return
	var doctor_opened: bool = await _open_escape_dialogue_from_panel(npc_system, dialogue_button, "doctor_01")
	if not doctor_opened:
		quit(1)
		return
	var doctor_round: Dictionary = dialog_system._apply_player_message_response({
		"ok": true,
		"dialogue": _make_escape_dialogue_response("doctor_01", "我还是要走。", "leave_after_intervention")
	}, {
		"clean_text": "先留下听我说。",
		"next_round": 1,
		"effective_recruitment_request": false,
		"dialogue_kind": "escape_intervention"
	})
	if not bool(doctor_round.get("ok", false)):
		push_error("Doctor first leave round should apply: %s" % JSON.stringify(doctor_round))
		quit(1)
		return
	if dialog_system.get_dialogue_state().is_empty():
		push_error("Escape dialogue should stay open before the fifth non-stay round")
		quit(1)
		return
	if not _assert_escape_paused(npc_system, "doctor_01", "Escape should remain paused while intervention panel is open"):
		quit(1)
		return
	dialog_system.end_dialogue()
	await process_frame
	if not _assert_escape_resumed(npc_system, "doctor_01", "Closing before five rounds should resume escape movement"):
		quit(1)
		return
	doctor_opened = await _open_escape_dialogue_from_panel(npc_system, dialogue_button, "doctor_01")
	if not doctor_opened:
		quit(1)
		return
	dialogue_state = dialog_system.get_dialogue_state()
	if int(dialogue_state.get("current_round", 0)) != 1:
		push_error("Reopened escape dialogue should preserve used rounds: %s" % JSON.stringify(dialogue_state))
		quit(1)
		return
	if not _assert_escape_paused(npc_system, "doctor_01", "Reopening should pause escape movement again"):
		quit(1)
		return
	dialog_system.end_dialogue()
	await process_frame

	var priest_escape: Dictionary = combat_system.debug_start_npc_escape("priest_01", "verify_continue")
	if not bool(priest_escape.get("ok", false)):
		push_error("Priest escape should start: %s" % JSON.stringify(priest_escape))
		quit(1)
		return
	var priest_opened: bool = await _open_escape_dialogue_from_panel(npc_system, dialogue_button, "priest_01")
	if not priest_opened:
		quit(1)
		return
	for round_number in range(1, 6):
		var apply_result: Dictionary = dialog_system._apply_player_message_response({
			"ok": true,
			"dialogue": _make_escape_dialogue_response("priest_01", "我还是要走。", "leave_after_intervention")
		}, {
			"clean_text": "你想走就走吧。",
			"next_round": round_number,
			"effective_recruitment_request": false,
			"dialogue_kind": "escape_intervention"
		})
		if not bool(apply_result.get("ok", false)):
			push_error("Continue intervention round should apply: %s" % JSON.stringify(apply_result))
			quit(1)
			return
		if round_number < 5 and dialog_system.get_dialogue_state().is_empty():
			push_error("Escape intervention should remain open before round 5")
			quit(1)
			return
	if not dialog_system.get_dialogue_state().is_empty() or dialog_panel.visible:
		push_error("Fifth non-stay round should auto-close dialogue")
		quit(1)
		return
	var priest_state: Dictionary = npc_system.get_npc_state("priest_01")
	var priest_intent: Dictionary = priest_state.get("escape_intent", {})
	if not bool(priest_intent.get("active", false)) or str(priest_intent.get("status", "")) != "escaping":
		push_error("Continue decision should keep escape active: %s" % JSON.stringify(priest_state))
		quit(1)
		return
	if int(priest_intent.get("intervention_rounds_used", 0)) != 5:
		push_error("Escape intervention should record 5 used rounds: %s" % JSON.stringify(priest_intent))
		quit(1)
		return
	if not _assert_escape_resumed(npc_system, "priest_01", "Fifth non-stay round should resume escape movement"):
		quit(1)
		return
	var limit_result: Dictionary = dialog_system.start_escape_intervention_dialogue("priest_01")
	if bool(limit_result.get("ok", false)) or str(limit_result.get("error_code", "")) != "round_limit_reached":
		push_error("Escape intervention should reject reopening after five rounds: %s" % JSON.stringify(limit_result))
		quit(1)
		return
	npc_system.debug_select_npc("priest_01")
	if not dialogue_button.disabled:
		push_error("Dialogue button should be disabled after five escape intervention rounds")
		quit(1)
		return

	resource_system.add_resource("money", 20)
	var engineer_escape: Dictionary = combat_system.debug_start_npc_escape("engineer_01", "verify_money")
	if not bool(engineer_escape.get("ok", false)):
		push_error("Engineer escape should start: %s" % JSON.stringify(engineer_escape))
		quit(1)
		return
	var engineer_before: float = float(npc_system.get_npc_state("engineer_01").get("escape_intent", {}).get("speed_multiplier", 1.0))
	var money_result: Dictionary = npc_system.give_money_to_npc("engineer_01", 5, "local_public")
	if not bool(money_result.get("ok", false)):
		push_error("Giving money to escaping NPC should still succeed: %s" % JSON.stringify(money_result))
		quit(1)
		return
	var engineer_after: float = float(npc_system.get_npc_state("engineer_01").get("escape_intent", {}).get("speed_multiplier", 1.0))
	if engineer_after >= engineer_before:
		push_error("Money should slow escape speed: before=%f after=%f" % [engineer_before, engineer_after])
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "escape_speed_changed").is_empty():
		push_error("Money slow should write escape_speed_changed")
		quit(1)
		return

	var gardener_escape: Dictionary = combat_system.debug_start_npc_escape("gardener_01", "verify_attack")
	if not bool(gardener_escape.get("ok", false)):
		push_error("Gardener escape should start: %s" % JSON.stringify(gardener_escape))
		quit(1)
		return
	var gardener_opened: bool = await _open_escape_dialogue_from_panel(npc_system, dialogue_button, "gardener_01")
	if not gardener_opened:
		quit(1)
		return
	var attack_before: float = float(npc_system.get_npc_state("gardener_01").get("escape_intent", {}).get("speed_multiplier", 1.0))
	var dialogue_turns_before := _count_events(memory_system.get_npc_daily_events("gardener_01"), "dialogue_turn")
	var intervention_results_before := _count_events(memory_system.get_npc_daily_events("gardener_01"), "escape_intervention_result")
	var attack_result: Dictionary = dialog_system.attack_target_npc(10, true)
	if not bool(attack_result.get("ok", false)):
		push_error("Escape dialogue attack should apply without LLM: %s" % JSON.stringify(attack_result))
		quit(1)
		return
	if bool(attack_result.get("llm_requested", true)):
		push_error("Escape dialogue attack should not request NPC LLM reply: %s" % JSON.stringify(attack_result))
		quit(1)
		return
	await process_frame
	var attack_state: Dictionary = npc_system.get_npc_state("gardener_01")
	var attack_intent: Dictionary = attack_state.get("escape_intent", {})
	var attack_after: float = float(attack_intent.get("speed_multiplier", 1.0))
	if not dialog_system.get_dialogue_state().is_empty() or dialog_panel.visible:
		push_error("Escape dialogue attack should close dialogue panel")
		quit(1)
		return
	if int(attack_intent.get("intervention_rounds_used", 0)) != 1:
		push_error("Escape dialogue attack should count as one intervention round: %s" % JSON.stringify(attack_intent))
		quit(1)
		return
	if attack_after <= attack_before:
		push_error("Escape dialogue attack should speed escape: before=%f after=%f" % [attack_before, attack_after])
		quit(1)
		return
	if _count_events(memory_system.get_npc_daily_events("gardener_01"), "dialogue_turn") != dialogue_turns_before:
		push_error("Escape dialogue attack should not record a dialogue_turn reply")
		quit(1)
		return
	if _count_events(memory_system.get_npc_daily_events("gardener_01"), "escape_intervention_result") != intervention_results_before:
		push_error("Escape dialogue attack should not record an escape_intervention_result")
		quit(1)
		return
	if not _assert_escape_resumed(npc_system, "gardener_01", "Escape dialogue attack should resume escape movement"):
		quit(1)
		return

	var knock_result: Dictionary = npc_system.apply_damage_to_npc("gardener_01", 200, "guard_officer", "local_public", {"request_plan_reevaluation": false})
	if not bool(knock_result.get("ok", false)) or not bool(knock_result.get("unconscious", false)):
		push_error("Heavy guard attack should knock escaping NPC unconscious: %s" % JSON.stringify(knock_result))
		quit(1)
		return
	var paused_state: Dictionary = npc_system.get_npc_state("gardener_01")
	if str(paused_state.get("escape_intent", {}).get("status", "")) != "paused_unconscious":
		push_error("Unconscious escaping NPC should pause escape intent: %s" % JSON.stringify(paused_state))
		quit(1)
		return
	npc_system.debug_advance_unconscious_recovery("gardener_01", 3600.0 * 100.0)
	await process_frame
	var revived_state: Dictionary = npc_system.get_npc_state("gardener_01")
	if bool(revived_state.get("unconscious", true)):
		push_error("Recovery should revive gardener")
		quit(1)
		return
	if str(revived_state.get("escape_intent", {}).get("status", "")) != "escaping" or str(revived_state.get("movement_target", "")) != "back_gate_escape_exit":
		push_error("Revived escaping NPC should continue toward exit: %s" % JSON.stringify(revived_state))
		quit(1)
		return

	print("Escape intervention dialogue verification passed.")
	quit(0)


func _open_escape_dialogue_from_panel(npc_system: Node, dialogue_button: Button, npc_id: String) -> bool:
	if not npc_system.debug_select_npc(npc_id):
		push_error("Could not select NPC for escape dialogue: %s" % npc_id)
		return false
	await process_frame
	if dialogue_button.disabled:
		push_error("Dialogue button should be enabled for escaping NPC with remaining rounds: %s" % npc_id)
		return false
	dialogue_button.pressed.emit()
	await process_frame
	return true


func _assert_escape_paused(npc_system: Node, npc_id: String, message: String) -> bool:
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent: Dictionary = state.get("escape_intent", {})
	if (
		str(state.get("current_action", "")) != "escape_intervention_dialogue"
		or not bool(intent.get("movement_paused_for_dialogue", false))
		or not str(state.get("movement_target", "")).is_empty()
	):
		push_error("%s: %s" % [message, JSON.stringify(state)])
		return false
	return true


func _assert_escape_resumed(npc_system: Node, npc_id: String, message: String) -> bool:
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent: Dictionary = state.get("escape_intent", {})
	if (
		str(state.get("current_action", "")) != "escaping_station"
		or bool(intent.get("movement_paused_for_dialogue", false))
		or str(state.get("movement_target", "")) != "back_gate_escape_exit"
	):
		push_error("%s: %s" % [message, JSON.stringify(state)])
		return false
	return true


func _make_escape_dialogue_response(npc_id: String, reply_text: String, intent: String) -> Dictionary:
	return {
		"replyer_id": npc_id,
		"reply_text": reply_text,
		"response_kind": "reply_to_player",
		"intent": intent,
		"emotion": "tense",
		"recruitment_result": "none",
		"wartime_reaction": "none",
		"should_end_dialogue": intent == "stay_after_intervention"
	}


func _last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == event_type:
			return event
	return {}


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type:
			count += 1
	return count
