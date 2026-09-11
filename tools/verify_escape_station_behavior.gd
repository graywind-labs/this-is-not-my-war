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
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var game_state := root.get_node_or_null("GameState")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var escape_alert_dialog := root.get_node_or_null("Main/UI/HUD/EscapeStartedAlertDialog") as AcceptDialog
	var cook_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01") as Node3D
	if (
		combat_system == null
		or npc_system == null
		or memory_system == null
		or action_system == null
		or daily_plan_system == null
		or game_state == null
		or gm_panel == null
		or escape_alert_dialog == null
		or cook_node == null
	):
		push_error("Escape verification required nodes not found")
		quit(1)
		return
	if escape_alert_dialog.get_ok_button().text != "好的":
		push_error("Escape alert must use the 好的 confirmation button")
		quit(1)
		return

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()

	npc_system.update_npc_state("engineer_01", {
		"first_sleep_summary_active": true,
		"current_action": "first_sleep_summary"
	})
	var escape_started_before := _count_events(memory_system.get_plaza_events(), "escape_started")
	var blocked_escape: Dictionary = combat_system.debug_start_npc_escape("engineer_01", "verify_movement_preflight")
	if bool(blocked_escape.get("ok", false)) or str(blocked_escape.get("error", "")) != "movement_unavailable":
		push_error("Movement preflight should reject escape before state mutation: %s" % JSON.stringify(blocked_escape))
		quit(1)
		return
	var engineer_state: Dictionary = npc_system.get_npc_state("engineer_01")
	if (
		str(engineer_state.get("behavior_mode", "work")) != "work"
		or not (engineer_state.get("escape_intent", {}) as Dictionary).is_empty()
		or _count_events(memory_system.get_plaza_events(), "escape_started") != escape_started_before
	):
		push_error("Rejected escape must not leave mode, intent, or public-event side effects: %s" % JSON.stringify(engineer_state))
		quit(1)
		return
	if escape_alert_dialog.visible:
		push_error("Rejected escape preflight must not display the global escape alert")
		quit(1)
		return
	npc_system.update_npc_state("engineer_01", {
		"first_sleep_summary_active": false,
		"current_action": "idle"
	})

	var current_hour := int(game_state.get("current_hour"))
	var escape_plan: Array = []
	for hour in range(24):
		escape_plan.append({
			"hour": hour,
			"action_id": "escaping_station" if hour == current_hour else "idle",
			"reason": "压力已经超过承受极限，决定从后门离开。" if hour == current_hour else "等待。",
			"source": "llm"
		})
	if not daily_plan_system.set_npc_daily_plan("engineer_01", escape_plan, false, "llm"):
		push_error("Daily escape plan should pass the authoritative plan contract")
		quit(1)
		return
	var daily_escape_result: Dictionary = daily_plan_system.debug_execute_current_plan("engineer_01", true)
	engineer_state = npc_system.get_npc_state("engineer_01")
	if (
		not bool(daily_escape_result.get("ok", false))
		or str(daily_escape_result.get("action_id", "")) != "escaping_station"
		or str(engineer_state.get("behavior_mode", "")) != "escaped"
		or str((engineer_state.get("escape_intent", {}) as Dictionary).get("trigger", "")) != "daily_plan"
	):
		push_error("A selected daily-plan escape must start the real escape flow: %s / %s" % [
			JSON.stringify(daily_escape_result),
			JSON.stringify(engineer_state)
		])
		quit(1)
		return
	if not escape_alert_dialog.visible or not escape_alert_dialog.dialog_text.contains("欧文正在逃离驿站"):
		push_error("A real daily-plan escape did not display the centered global alert")
		quit(1)
		return
	escape_alert_dialog.get_ok_button().pressed.emit()
	await process_frame
	if escape_alert_dialog.visible:
		push_error("Escape alert did not close through the 好的 button")
		quit(1)
		return

	var revive_escape: Dictionary = combat_system.debug_start_npc_escape("gardener_01", "verify_revive_resume")
	if not bool(revive_escape.get("ok", false)):
		push_error("Gardener escape should start before revive-resume verification: %s" % JSON.stringify(revive_escape))
		quit(1)
		return
	if not escape_alert_dialog.visible or not escape_alert_dialog.dialog_text.contains("伊沃正在逃离驿站"):
		push_error("Direct escape start did not display the global alert for the correct NPC")
		quit(1)
		return
	escape_alert_dialog.get_ok_button().pressed.emit()
	await process_frame
	var gardener_hp := int(npc_system.get_npc_state("gardener_01").get("hp", 100))
	npc_system.apply_damage_to_npc(
		"gardener_01",
		maxi(1, gardener_hp),
		"guard_officer",
		"local_public",
		{"request_plan_reevaluation": false}
	)
	var paused_gardener_state: Dictionary = npc_system.get_npc_state("gardener_01")
	if str((paused_gardener_state.get("escape_intent", {}) as Dictionary).get("status", "")) != "paused_unconscious":
		push_error("Unconscious escaping NPC should pause escape before revive: %s" % JSON.stringify(paused_gardener_state))
		quit(1)
		return
	npc_system.update_npc_state("gardener_01", {
		"hp": 30,
		"unconscious": false
	})
	var gardener_node_path: NodePath = npc_system._npc_nodes.get("gardener_01", NodePath(""))
	npc_system._npc_nodes.erase("gardener_01")
	var failed_resume_route: Dictionary = combat_system._route_revived_npc("gardener_01")
	npc_system._npc_nodes["gardener_01"] = gardener_node_path
	var gardener_state: Dictionary = npc_system.get_npc_state("gardener_01")
	var gardener_intent: Dictionary = gardener_state.get("escape_intent", {})
	if (
		not bool(failed_resume_route.get("ok", false))
		or str(gardener_state.get("behavior_mode", "")) != "work"
		or bool(gardener_intent.get("active", true))
		or str(gardener_intent.get("status", "")) != "resume_failed"
	):
		push_error("Unavailable revive escape must cancel the intent and route NPC normally: %s / %s" % [
			JSON.stringify(failed_resume_route),
			JSON.stringify(gardener_state)
		])
		quit(1)
		return

	cook_node.global_position = Vector3(-10.0, 0.0, -22.7)
	var escape_result: Dictionary = combat_system.debug_start_npc_escape("cook_01", "verify_debug")
	if not bool(escape_result.get("ok", false)):
		push_error("Debug escape should start: %s" % JSON.stringify(escape_result))
		quit(1)
		return
	if not escape_alert_dialog.visible or not escape_alert_dialog.dialog_text.contains("布鲁诺正在逃离驿站"):
		push_error("Cook escape start did not display the global alert")
		quit(1)
		return
	escape_alert_dialog.get_ok_button().pressed.emit()
	await process_frame

	var state: Dictionary = npc_system.get_npc_state("cook_01")
	var intent: Dictionary = state.get("escape_intent", {})
	if str(state.get("behavior_mode", "")) != "escaped":
		push_error("Escaping NPC should leave work/combat behavior immediately: %s" % JSON.stringify(state))
		quit(1)
		return
	if bool(state.get("escaped", false)):
		push_error("NPC should not be marked escaped before reaching the exit")
		quit(1)
		return
	if not bool(intent.get("active", false)) or str(intent.get("status", "")) != "escaping":
		push_error("Escape intent should be active and escaping: %s" % JSON.stringify(intent))
		quit(1)
		return
	if str(state.get("movement_target", "")) != "back_gate_escape_exit":
		push_error("Escaping NPC should move to back gate exit: %s" % JSON.stringify(state))
		quit(1)
		return
	if npc_system.can_npc_act("cook_01"):
		push_error("Escaping NPC should not accept normal actions")
		quit(1)
		return
	if action_system.debug_assign_action("cook_01", "eat_at_dining_hall"):
		push_error("ActionSystem should reject an escaping NPC")
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "escape_started").is_empty():
		push_error("Escape start should be public in plaza events")
		quit(1)
		return

	var snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	if _find_npc_entry(snapshot.get("active_escapes", []), "cook_01").is_empty():
		push_error("Combat snapshot should expose active escape: %s" % JSON.stringify(snapshot))
		quit(1)
		return

	for _i in range(120):
		await process_frame
		state = npc_system.get_npc_state("cook_01")
		if bool(state.get("escaped", false)):
			break

	state = npc_system.get_npc_state("cook_01")
	if not bool(state.get("escaped", false)):
		push_error("NPC should be marked escaped after reaching exit: %s" % JSON.stringify(state))
		quit(1)
		return
	if str(state.get("current_action", "")) != "escaped" or str(state.get("current_location", "")) != "outside_station":
		push_error("Escaped NPC should have final escaped action and outside location: %s" % JSON.stringify(state))
		quit(1)
		return
	intent = state.get("escape_intent", {})
	if bool(intent.get("active", true)) or str(intent.get("status", "")) != "escaped":
		push_error("Escape intent should be completed after leaving map: %s" % JSON.stringify(intent))
		quit(1)
		return
	if cook_node.visible or cook_node.input_ray_pickable:
		push_error("Escaped NPC node should be hidden and unpickable")
		quit(1)
		return
	if not _find_npc_entry(combat_system.debug_get_combat_snapshot().get("active_escapes", []), "cook_01").is_empty():
		push_error("Completed escape should be removed from active escape snapshot")
		quit(1)
		return
	if _last_event(memory_system.get_plaza_events(), "escaped").is_empty():
		push_error("Escaped event should be public in plaza events")
		quit(1)
		return
	if (memory_system.get_location_snapshot("plaza").get("people_present", []) as Array).has("cook_01"):
		push_error("Escaped NPC should be removed from plaza people_present")
		quit(1)
		return
	var escaped_witness_count := int(memory_system.get_npc_witness_events("cook_01").size())
	memory_system.set_plaza_notice("离站者不应再收到这条通告。", "guard_officer")
	if memory_system.get_npc_witness_events("cook_01").size() != escaped_witness_count:
		push_error("Escaped NPC should not receive later notice-board witnesses")
		quit(1)
		return

	gm_panel._execute_command("escape_npc priest_01")
	await process_frame
	var priest_state: Dictionary = npc_system.get_npc_state("priest_01")
	if str(priest_state.get("escape_intent", {}).get("status", "")) != "escaping":
		push_error("GM escape command should call CombatSystem escape entry: %s" % JSON.stringify(priest_state))
		quit(1)
		return
	if not escape_alert_dialog.visible or not escape_alert_dialog.dialog_text.contains("马塞尔正在逃离驿站"):
		push_error("GM-triggered real escape did not display the global alert")
		quit(1)
		return

	print("Escape station behavior verification passed.")
	quit(0)


func _last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == event_type:
			return event
	return {}


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) == event_type:
			count += 1
	return count


func _find_npc_entry(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if str(entry.get("npc_id", "")) == npc_id:
			return entry
	return {}
